import Foundation
import Network
import Observation

/// Connection to the Agent Village server running on the user's Mac.
/// Sends tasks and approvals, and turns the server's event stream into village actions.
@MainActor
@Observable
final class LiveLink {
    enum Status: Equatable {
        case off, connecting, connected(String), failed(String)

        var label: String {
            switch self {
            case .off: "Not connected"
            case .connecting: "Connecting..."
            case .connected(let name): "Connected to \(name)"
            case .failed(let why): why
            }
        }
    }

    struct Found: Identifiable, Hashable {
        let name: String
        let address: String
        var id: String { address }
    }

    var status: Status = .off
    var found: [Found] = []
    var address: String
    var code: String

    @ObservationIgnored private let model: WorldModel
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private var resolvers: [NWConnection] = []
    @ObservationIgnored private var seq = 0
    @ObservationIgnored private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 40
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    var isConnected: Bool { if case .connected = status { true } else { false } }

    init(model: WorldModel) {
        self.model = model
        let d = UserDefaults.standard
        address = d.string(forKey: "macAddress") ?? ""
        code = d.string(forKey: "macCode") ?? ""
        model.onLiveCreate = { [weak self] agent, prompt, ask in self?.create(agent: agent.id, prompt: prompt, needsApproval: ask) }
        model.onLiveDecision = { [weak self] id, ok in self?.decide(id, ok) }
        model.onLiveCancel = { [weak self] id in self?.post("/api/tasks/\(id)/cancel", body: [:]) }
    }

    // MARK: Discovery (Bonjour on the local Wi-Fi)

    func startBrowsing() {
        guard browser == nil else { return }
        let b = NWBrowser(for: .bonjour(type: "_agentvillage._tcp", domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in self?.resolve(results) }
        }
        b.start(queue: .main)
        browser = b
    }

    private func resolve(_ results: Set<NWBrowser.Result>) {
        for r in results {
            guard case let .service(name, _, _, _) = r.endpoint else { continue }
            let params = NWParameters.tcp
            if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options { ip.version = .v4 }
            let conn = NWConnection(to: r.endpoint, using: params)
            conn.stateUpdateHandler = { [weak self, weak conn] state in
                guard case .ready = state, let conn,
                      case let .hostPort(host, port)? = conn.currentPath?.remoteEndpoint else { return }
                var h = "\(host)"
                if let pct = h.firstIndex(of: "%") { h = String(h[..<pct]) }
                let found = Found(name: name, address: "\(h):\(port)")
                conn.cancel()
                Task { @MainActor in
                    guard let self else { return }
                    if !self.found.contains(found) { self.found.append(found) }
                    if self.address.isEmpty { self.address = found.address }
                }
            }
            conn.start(queue: .main)
            resolvers.append(conn)
        }
    }

    // MARK: Connect

    func connect() {
        let addr = address.trimmingCharacters(in: .whitespaces)
        let c = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !addr.isEmpty, !c.isEmpty else { status = .failed("Enter your Mac's address and pairing code."); return }
        address = addr
        code = c
        UserDefaults.standard.set(addr, forKey: "macAddress")
        UserDefaults.standard.set(c, forKey: "macCode")
        pollTask?.cancel()
        status = .connecting
        pollTask = Task { await run() }
    }

    func disconnect() {
        pollTask?.cancel()
        pollTask = nil
        status = .off
        model.setLive(false)
    }

    /// Reconnects automatically at launch if we've paired before.
    func autoConnect() {
        startBrowsing()
        if !address.isEmpty, !code.isEmpty, !isConnected { connect() }
    }

    private func run() async {
        var failures = 0
        while !Task.isCancelled {
            do {
                let state: StateResponse = try await get("/api/state")
                seq = state.seq
                status = .connected(state.machine.replacingOccurrences(of: ".local", with: ""))
                model.setLive(true)
                apply(state.tasks)
                failures = 0
                while !Task.isCancelled {
                    let ev: EventsResponse = try await get("/api/events?after=\(seq)&wait=20")
                    for e in ev.events { await handle(e) }
                    seq = max(seq, ev.seq)
                }
            } catch is CancellationError {
                return
            } catch let e as LinkError {
                status = .failed(e.message)
                if case .unauthorized = e { model.setLive(false); return }
                failures += 1
            } catch {
                failures += 1
                status = .failed(failures > 2 ? "Can't reach your Mac. Is the server running?" : "Reconnecting...")
            }
            try? await Task.sleep(for: .seconds(min(10, 1 + failures * 2)))
        }
    }

    /// Sync from a full snapshot (on connect).
    private func apply(_ tasks: [ServerTask]) {
        for t in tasks {
            switch t.status {
            case "queued": model.liveQueued(t.agent, serverID: t.id, title: t.title)
            case "running", "approved": model.liveStarted(t.agent, serverID: t.id, title: t.title)
            case "awaiting_approval": model.liveApproval(t.agent, serverID: t.id, title: t.title, proposal: t.proposal ?? "")
            default: break
            }
        }
    }

    private func handle(_ e: ServerEvent) async {
        guard let agent = e.agent, let id = e.taskId else { return }
        let title = e.title ?? ""
        switch e.type {
        case "task_created": model.liveQueued(agent, serverID: id, title: title)
        case "task_started": model.liveStarted(agent, serverID: id, title: title)
        case "activity": model.liveActivity(agent, serverID: id, title: title, text: e.text ?? "", steps: e.steps ?? 0)
        case "approval_needed":
            let full: ServerTask? = try? await get("/api/tasks/\(id)")
            model.liveApproval(agent, serverID: id, title: title, proposal: full?.proposal ?? e.text ?? "")
        case "task_done":
            let full: ServerTask? = try? await get("/api/tasks/\(id)")
            model.liveDone(agent, serverID: id, title: title, result: full?.result ?? e.text ?? "", tokens: full?.tokens ?? 0)
        case "task_failed": model.liveFailed(agent, serverID: id, text: e.text ?? "Something went wrong.")
        case "cancelled", "denied": model.liveCancelled(agent, serverID: id)
        default: break
        }
    }

    // MARK: Actions

    func create(agent: String, prompt: String, needsApproval: Bool) {
        post("/api/tasks", body: ["agent": agent, "prompt": prompt, "needsApproval": needsApproval])
    }

    func decide(_ id: String, _ approve: Bool) {
        post("/api/tasks/\(id)/\(approve ? "approve" : "deny")", body: [:])
    }

    // MARK: HTTP

    enum LinkError: Error {
        case unauthorized, server(String)
        var message: String {
            switch self {
            case .unauthorized: "Wrong pairing code. Check the code shown on your Mac."
            case .server(let s): s
            }
        }
    }

    private func url(_ path: String) -> URL? {
        let base = address.hasPrefix("http") ? address : "http://\(address)"
        let withPort = base.split(separator: ":").count > 2 ? base : base + ":8787"
        return URL(string: withPort + path)
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let u = url(path) else { throw LinkError.server("Invalid Mac address.") }
        var req = URLRequest(url: u)
        req.setValue(code, forHTTPHeaderField: "X-Village-Token")
        let (data, resp) = try await session.data(for: req)
        if (resp as? HTTPURLResponse)?.statusCode == 401 { throw LinkError.unauthorized }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post(_ path: String, body: [String: Any]) {
        guard let u = url(path) else { return }
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue(code, forHTTPHeaderField: "X-Village-Token")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Task { _ = try? await session.data(for: req) }
    }
}

// MARK: Wire types

private struct StateResponse: Decodable {
    let seq: Int
    let tasks: [ServerTask]
    let machine: String
}

private struct EventsResponse: Decodable {
    let seq: Int
    let events: [ServerEvent]
}

struct ServerTask: Decodable {
    let id: String
    let agent: String
    let title: String
    let status: String
    let proposal: String?
    let result: String?
    let tokens: Int?
}

private struct ServerEvent: Decodable {
    let seq: Int
    let type: String
    let taskId: String?
    let agent: String?
    let title: String?
    let text: String?
    let steps: Int?
}
