import Foundation
import Observation
import simd

enum AgentMode: Equatable {
    case resting, walking, working, awaitingApproval, chatting, celebrating, paused

    var label: String {
        switch self {
        case .resting: "Resting"
        case .walking: "On the move"
        case .working: "Working"
        case .awaitingApproval: "Needs you!"
        case .chatting: "Chatting"
        case .celebrating: "Quest clear!"
        case .paused: "Napping"
        }
    }
}

enum Expression: CaseIterable { case normal, blink, happy, focused, surprised, sad }

struct Bubble: Equatable {
    enum Style { case speech, thought, shout }
    var text: String
    var style: Style
    var expires: Double
    var id = UUID()
}

struct Toast: Identifiable, Equatable {
    enum Kind { case done, approval, info }
    let id = UUID()
    let agentID: String
    let text: String
    let kind: Kind
    let expires: Double
}

struct FeedEntry: Identifiable {
    enum Kind { case start, done, approval, chat, info }
    let id = UUID()
    let time: Double
    let agentID: String
    let text: String
    let kind: Kind
    var resultID: String? = nil
}

/// A finished real task's full answer, readable in the app.
struct LiveResult: Identifiable {
    let id: String
    let agentID: String
    let title: String
    let text: String
    let date: Date
}

private enum Arrival { case work, approval, rest }

@Observable
final class AgentState: Identifiable {
    let persona: Persona
    var id: String { persona.id }

    // Observed by the HUD.
    var mode: AgentMode = .resting
    var task: AgentTask?
    var progress: Double = 0
    var bubble: Bubble?
    var tasksDone = 0
    var tokens = 0
    /// Quests the player assigned, done before the agent's own routine.
    var queue: [AgentTask] = []
    var approvalsAsked = 0

    var spent: Double { Double(tokens) / 1_000_000 * WorldModel.dollarsPerMillionTokens }

    /// Seconds of game time left on the current quest, if working.
    var remaining: Double? {
        guard let t = task else { return nil }
        return max(0, (1 - progress) * t.duration)
    }

    // Simulation internals, read every frame by the 3D scene.
    @ObservationIgnored var position: SIMD3<Float>
    @ObservationIgnored var yaw: Float = 0
    @ObservationIgnored var speed: Float = 0
    @ObservationIgnored var expression: Expression = .normal
    @ObservationIgnored var animTime: Float = 0
    @ObservationIgnored var stateTime: Double = 0
    @ObservationIgnored fileprivate var path: [SIMD3<Float>] = []
    @ObservationIgnored fileprivate var arrival: Arrival = .rest
    @ObservationIgnored fileprivate var targetYaw: Float?
    @ObservationIgnored fileprivate var timer: Double = 0
    @ObservationIgnored fileprivate var nextLineAt: Double = 0
    @ObservationIgnored fileprivate var lineIndex = 0
    @ObservationIgnored fileprivate var taskIndex: Int
    @ObservationIgnored fileprivate var approved = false
    @ObservationIgnored fileprivate var chatCooldown: Double = 8
    @ObservationIgnored fileprivate var modeBeforePause: AgentMode = .resting
    @ObservationIgnored fileprivate var blinkAt: Double = 2
    @ObservationIgnored fileprivate var blinkUntil: Double = 0
    @ObservationIgnored fileprivate var chatPartner: String?
    @ObservationIgnored fileprivate var restSpot: Float

    init(persona: Persona, start: Float) {
        self.persona = persona
        self.restSpot = start
        self.position = polar(start, VillageLayout.restRadius)
        self.taskIndex = Int.random(in: 0..<persona.tasks.count)
        self.timer = Double.random(in: 1...4)
    }

    var isWorkingAtStation: Bool { mode == .working }
}

enum VillageLayout {
    static let ringRadius: Float = 4.6
    static let restRadius: Float = 3.1
    /// Rest spots under the sakura tree (south side so agents stay visible).
    static let restAngles: [Float] = [-62, -30, 0, 30, 62, -48]
}

enum GameEvent {
    case questStart(String), questDone(String), approvalNeeded(String), approved(String), denied(String)
    case chat(String), speak(String, Bubble.Style), pause(String), wake(String)
}

@MainActor
@Observable
final class WorldModel {
    let agents: [AgentState]
    var feed: [FeedEntry] = []
    var toasts: [Toast] = []
    var approvalsGranted = 0
    var approvalsDenied = 0
    var selectedID: String?

    static let dollarsPerMillionTokens: Double = 9
    var clock: Double = 0
    var timeScale: Double = 1
    /// Length of one in-game day, in real seconds.
    let dayLength: Double = 300

    @ObservationIgnored private var paused = false

    // Live mode: agents are driven by real tasks on the Mac server.
    var isLive = false
    var results: [LiveResult] = []
    @ObservationIgnored var onLiveCreate: ((AgentState, String, Bool) -> Void)?
    @ObservationIgnored var onLiveDecision: ((String, Bool) -> Void)?
    @ObservationIgnored var onLiveCancel: ((String) -> Void)?
    /// Hook for sound effects and visual bursts.
    @ObservationIgnored var onEvent: ((GameEvent) -> Void)?

    init() {
        agents = Persona.roster.enumerated().map { i, p in
            AgentState(persona: p, start: VillageLayout.restAngles[i])
        }
        log("hana", "The village wakes up. 4 agents ready for adventure!", .info)
    }

    // MARK: Derived state

    var timeOfDay: Double { (clock / dayLength + 0.32).truncatingRemainder(dividingBy: 1) }
    var day: Int { Int(clock / dayLength + 0.32) + 1 }
    var totalTokens: Int { agents.reduce(0) { $0 + $1.tokens } }
    var totalCost: Double { Double(totalTokens) / 1_000_000 * Self.dollarsPerMillionTokens }
    var workingCount: Int { agents.filter { $0.mode == .working }.count }
    var allPaused: Bool { agents.allSatisfy { $0.mode == .paused } }
    var questsDone: Int { agents.reduce(0) { $0 + $1.tasksDone } }
    var pending: [AgentState] { agents.filter { $0.mode == .awaitingApproval } }
    var selected: AgentState? { agents.first { $0.id == selectedID } }

    func agent(_ id: String) -> AgentState? { agents.first { $0.id == id } }

    var clockString: String {
        let minutes = Int(timeOfDay * 24 * 60)
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    // MARK: Player actions

    func approve(_ agent: AgentState) {
        guard agent.mode == .awaitingApproval else { return }
        if isLive, let sid = agent.task?.serverID {
            approvalsGranted += 1
            say(agent, "Yatta! On it!", .shout, for: 2.5)
            log(agent.id, "Approved: \(agent.task?.title ?? "")", .info)
            onEvent?(.approved(agent.id))
            onLiveDecision?(sid, true)
            walk(agent, to: agent.persona.station, then: .work)
            return
        }
        agent.approved = true
        approvalsGranted += 1
        say(agent, "Yatta! On it!", .shout, for: 2.5)
        log(agent.id, "Approved: \(agent.task?.title ?? "")", .info)
        onEvent?(.approved(agent.id))
        celebrate(agent)
    }

    func deny(_ agent: AgentState) {
        guard agent.mode == .awaitingApproval else { return }
        if isLive, let sid = agent.task?.serverID { onLiveDecision?(sid, false) }
        say(agent, "Okay... I'll scrap that one.", .speech, for: 3)
        agent.expression = .sad
        approvalsDenied += 1
        log(agent.id, "Declined: \(agent.task?.title ?? "")", .info)
        onEvent?(.denied(agent.id))
        agent.task = nil
        agent.progress = 0
        goRest(agent)
    }

    // MARK: Player quests

    func enqueue(_ task: AgentTask, for agent: AgentState) {
        if isLive {
            onLiveCreate?(agent, task.title, task.approvalPrompt != nil)
            say(agent, "Got it! Sending that to my desk!", .shout, for: 3)
            return
        }
        agent.queue.append(task)
        log(agent.id, "New quest from you: \(task.title)", .info)
        say(agent, "Got it! I'll do \"\(task.title)\" next!", .shout, for: 3)
        if agent.mode == .resting { agent.timer = min(agent.timer, 0.8) }
    }

    func removeFromQueue(_ taskID: UUID, of agent: AgentState) {
        if isLive, let sid = agent.queue.first(where: { $0.id == taskID })?.serverID { onLiveCancel?(sid) }
        agent.queue.removeAll { $0.id == taskID }
    }

    func customTask(for p: Persona, title: String, needsApproval: Bool) -> AgentTask {
        let lines: [String] = switch p.station {
        case .postOffice: ["Opening the mailbag...", "Sorting it out~", "Almost there!"]
        case .forge: ["Firing up the forge...", "Hammering it into shape.", "Testing it..."]
        case .library: ["Gathering sources...", "Taking careful notes.", "Cross-checking facts..."]
        case .observatory: ["Pulling the data...", "Crunching numbers...", "Plotting it out."]
        case .questBoard: ["Working on it..."]
        }
        return AgentTask(isCustom: true, title: title, lines: lines, doneLine: "Your quest is done!", duration: 16, tokens: 6000,
                         approvalPrompt: needsApproval ? "\"\(title)\" is ready. Can I go ahead and finish it?" : nil)
    }

    func pauseAll() { for a in agents where a.mode != .paused { togglePause(a) } }
    func resumeAll() { for a in agents where a.mode == .paused { togglePause(a) } }

    func togglePause(_ agent: AgentState) {
        if agent.mode == .paused {
            agent.mode = agent.modeBeforePause == .paused ? .resting : agent.modeBeforePause
            say(agent, "Back to work!", .shout, for: 2)
            onEvent?(.wake(agent.id))
        } else {
            agent.modeBeforePause = agent.mode == .chatting ? .walking : agent.mode
            agent.mode = .paused
            agent.bubble = Bubble(text: "Zzz...", style: .thought, expires: .infinity)
            onEvent?(.pause(agent.id))
        }
    }

    func statusReply(for agent: AgentState) -> String {
        switch agent.mode {
        case .awaitingApproval:
            return agent.task?.approvalPrompt ?? "I need your seal of approval!"
        case .working, .walking where agent.task != nil:
            let pct = Int(agent.progress * 100)
            return "I'm on \"\(agent.task?.title ?? "")\". About \(pct)% done! \(agent.persona.idleLines.randomElement() ?? "")"
        case .paused:
            return "Mmh... five more minutes... I'm on a break until you wake me."
        default:
            return "Taking a breather between quests. \(agent.persona.idleLines.randomElement() ?? "")"
        }
    }

    // MARK: Simulation

    func tick(_ realDT: Double) {
        let dt = min(realDT, 0.1) * timeScale
        clock += dt
        if toasts.contains(where: { $0.expires < clock }) { toasts.removeAll { $0.expires < clock } }
        for a in agents { step(a, dt: dt) }
        checkEncounters(dt)
    }

    private func step(_ a: AgentState, dt: Double) {
        a.stateTime += dt
        a.animTime += Float(dt)
        if let b = a.bubble, clock > b.expires { a.bubble = nil }
        updateBlink(a)

        switch a.mode {
        case .paused:
            a.speed = 0
            a.expression = .blink
            return
        case .resting:
            a.speed = 0
            a.timer -= dt
            if !a.queue.isEmpty, !isLive { a.timer = min(a.timer, 1) }
            if a.timer <= 0 {
                if isLive { a.timer = Double.random(in: 6...12) } else { startNextTask(a) }
            }
            else if a.timer < 2.5, a.bubble == nil, Int.random(in: 0..<400) == 0 {
                say(a, a.persona.idleLines.randomElement()!, .thought, for: 2.5)
            }
        case .walking:
            walk(a, dt: dt)
        case .working:
            work(a, dt: dt)
        case .awaitingApproval:
            a.speed = 0
            a.yaw = lerpAngle(a.yaw, StationKind.questBoard.workYaw, Float(dt) * 6)
            if a.bubble == nil || a.stateTime.truncatingRemainder(dividingBy: 9) < dt {
                say(a, a.stateTime < 2 ? "I need your approval!" : "Psst! Over here, boss!", .shout, for: 4)
            }
        case .chatting:
            a.speed = 0
            a.timer -= dt
            if a.timer <= 0 {
                a.mode = .walking
                a.chatPartner = nil
            }
        case .celebrating:
            a.speed = 0
            a.timer -= dt
            if a.timer <= 0 { finishTask(a) }
        }
    }

    private func updateBlink(_ a: AgentState) {
        let base: Expression = switch a.mode {
        case .working: .focused
        case .celebrating, .chatting: .happy
        case .awaitingApproval: a.stateTime.truncatingRemainder(dividingBy: 3) < 1.2 ? .surprised : .normal
        default: a.expression == .sad && a.stateTime < 3 ? .sad : .normal
        }
        if clock > a.blinkAt {
            a.blinkUntil = clock + 0.14
            a.blinkAt = clock + Double.random(in: 2.2...5)
        }
        a.expression = clock < a.blinkUntil && base != .happy ? .blink : base
    }

    private func startNextTask(_ a: AgentState) {
        let task: AgentTask
        if !a.queue.isEmpty {
            task = a.queue.removeFirst()
        } else {
            task = a.persona.tasks[a.taskIndex % a.persona.tasks.count]
            a.taskIndex += Int.random(in: 1...2)
        }
        a.task = task
        a.progress = 0
        a.lineIndex = 0
        a.approved = false
        log(a.id, "Accepted quest: \(task.title)", .start)
        onEvent?(.questStart(a.id))
        say(a, ["Off to work!", "New quest!", "Let's go!", "Leave it to me!"].randomElement()!, .speech, for: 2)
        walk(a, to: a.persona.station, then: .work)
    }

    private func work(_ a: AgentState, dt: Double) {
        guard let task = a.task else { goRest(a); return }
        a.speed = 0
        a.yaw = lerpAngle(a.yaw, a.persona.station.workYaw, Float(dt) * 6)
        if isLive { return } // progress and speech come from the real agent
        let before = a.progress
        a.progress = min(1, a.progress + dt / task.duration)
        a.tokens += Int(Double(task.tokens) * (a.progress - before))

        if clock >= a.nextLineAt, !task.lines.isEmpty {
            say(a, task.lines[a.lineIndex % task.lines.count], .speech, for: 3.2)
            a.lineIndex += 1
            a.nextLineAt = clock + Double.random(in: 4.5...6.5)
        }

        if task.approvalPrompt != nil, !a.approved, a.progress >= 0.75 {
            say(a, "I need the boss's seal for this...", .thought, for: 2.5)
            walk(a, to: .questBoard, then: .approval)
        } else if a.progress >= 1 {
            celebrate(a)
        }
    }

    private func celebrate(_ a: AgentState) {
        a.mode = .celebrating
        a.stateTime = 0
        a.timer = 2.6
        if let t = a.task { say(a, t.doneLine, .shout, for: 2.6) }
    }

    private func finishTask(_ a: AgentState) {
        if let t = a.task {
            a.tasksDone += 1
            a.progress = 1
            log(a.id, "Quest clear: \(t.title)", .done, resultID: t.serverID)
            onEvent?(.questDone(a.id))
        }
        a.task = nil
        goRest(a)
    }

    private func goRest(_ a: AgentState) {
        a.restSpot = VillageLayout.restAngles.randomElement()!
        a.timer = Double.random(in: 3...7)
        a.arrival = .rest
        a.path = route(from: a.position, toAngle: a.restSpot, endRadius: VillageLayout.restRadius)
        a.targetYaw = nil
        a.mode = .walking
        a.stateTime = 0
    }

    private func walk(_ a: AgentState, to station: StationKind, then arrival: Arrival) {
        a.arrival = arrival
        var spot = station.workSpot
        if station == .questBoard, let i = agents.firstIndex(where: { $0 === a }) {
            spot.x = -2.6 + Float(i) * 1.0 // queue up side by side
        }
        a.path = route(from: a.position, toAngle: station.angle, endRadius: nil) + [spot]
        a.targetYaw = station.workYaw
        a.mode = .walking
        a.stateTime = 0
    }

    private func walk(_ a: AgentState, dt: Double) {
        guard let next = a.path.first else { arrive(a); return }
        let to = next - a.position
        let dist = simd_length(to.xz)
        let speed: Float = a.arrival == .approval ? 3.4 : 2.4
        if dist < 0.08 {
            a.path.removeFirst()
            return
        }
        let dir = to / dist
        let stepLen = min(dist, speed * Float(dt))
        a.position += SIMD3(dir.x, 0, dir.z) * stepLen
        a.speed = speed
        a.yaw = lerpAngle(a.yaw, atan2(dir.x, dir.z), Float(dt) * 10)
    }

    private func arrive(_ a: AgentState) {
        a.speed = 0
        a.stateTime = 0
        switch a.arrival {
        case .work:
            a.mode = .working
            a.nextLineAt = clock + 0.6
        case .approval:
            a.mode = .awaitingApproval
            a.approvalsAsked += 1
            log(a.id, "Requests your approval: \(a.task?.title ?? "")", .approval)
            onEvent?(.approvalNeeded(a.id))
        case .rest:
            a.mode = .resting
        }
    }

    /// Paths go inward to the plaza ring, around it, then out to the destination.
    private func route(from p: SIMD3<Float>, toAngle target: Float, endRadius: Float?) -> [SIMD3<Float>] {
        let r = VillageLayout.ringRadius
        var pts: [SIMD3<Float>] = []
        var startAngle = atan2(p.x, p.z) * 180 / .pi
        if simd_length(p.xz) < 0.5 { startAngle = target }
        pts.append(polar(startAngle, r))
        var delta = (target - startAngle).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        let steps = max(1, Int(abs(delta) / 12))
        for i in 1...steps {
            pts.append(polar(startAngle + delta * Float(i) / Float(steps), r))
        }
        if let endRadius { pts.append(polar(target, endRadius)) }
        return pts
    }

    private func checkEncounters(_ dt: Double) {
        for a in agents { a.chatCooldown -= dt }
        for i in agents.indices {
            for j in agents.indices where j > i {
                let a = agents[i], b = agents[j]
                guard a.mode == .walking, b.mode == .walking,
                      a.chatCooldown <= 0, b.chatCooldown <= 0,
                      a.arrival != .approval, b.arrival != .approval,
                      simd_distance(a.position, b.position) < 1.6 else { continue }
                startChat(a, b)
            }
        }
    }

    private func startChat(_ a: AgentState, _ b: AgentState) {
        let (lineA, lineB) = Banter.pairs.randomElement()!
        for (x, y) in [(a, b), (b, a)] {
            x.mode = .chatting
            x.timer = 4.2
            x.chatCooldown = Double.random(in: 25...40)
            x.chatPartner = y.id
            let d = y.position - x.position
            x.yaw = atan2(d.x, d.z)
            x.speed = 0
        }
        say(a, lineA, .speech, for: 2.2)
        let delayed = clock + 2.0
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.0 / max(self?.timeScale ?? 1, 0.1)))
            guard let self, b.mode == .chatting, self.clock >= delayed - 0.5 else { return }
            self.say(b, lineB, .speech, for: 2.2)
        }
        log(a.id, "& \(b.persona.name): \"\(lineA)\" - \"\(lineB)\"", .chat)
        onEvent?(.chat(a.id))
    }

    // MARK: Helpers

    private func pushToast(_ t: Toast) {
        toasts.append(t)
        if toasts.count > 2 { toasts.removeFirst() }
    }

    func say(_ a: AgentState, _ text: String, _ style: Bubble.Style, for seconds: Double) {
        a.bubble = Bubble(text: text, style: style, expires: clock + seconds)
        onEvent?(.speak(a.id, style))
    }

    private func log(_ id: String, _ text: String, _ kind: FeedEntry.Kind, resultID: String? = nil) {
        switch kind {
        case .done: pushToast(Toast(agentID: id, text: text, kind: .done, expires: clock + 4 * timeScale))
        case .approval: pushToast(Toast(agentID: id, text: text, kind: .approval, expires: clock + 5 * timeScale))
        default: break
        }
        feed.insert(FeedEntry(time: clock, agentID: id, text: text, kind: kind, resultID: resultID), at: 0)
        if feed.count > 80 { feed.removeLast() }
    }

    // MARK: Live agents (events from the Mac server)

    func setLive(_ on: Bool) {
        guard on != isLive else { return }
        isLive = on
        for a in agents {
            a.queue.removeAll()
            if a.mode == .awaitingApproval || a.mode == .working || a.task != nil {
                a.task = nil
                a.progress = 0
                goRest(a)
            }
        }
        log("hana", on ? "Connected to your Mac. Real agents are on duty!" : "Disconnected from your Mac. Demo mode.", .info)
    }

    private func liveTask(_ title: String, _ serverID: String) -> AgentTask {
        AgentTask(isCustom: true, title: title, lines: [], doneLine: "Quest complete!", duration: 60, tokens: 0,
                  approvalPrompt: nil, serverID: serverID)
    }

    func liveQueued(_ agentID: String, serverID: String, title: String) {
        guard let a = agent(agentID), a.task?.serverID != serverID,
              !a.queue.contains(where: { $0.serverID == serverID }) else { return }
        a.queue.append(liveTask(title, serverID))
    }

    func liveStarted(_ agentID: String, serverID: String, title: String) {
        guard let a = agent(agentID) else { return }
        a.queue.removeAll { $0.serverID == serverID }
        if a.task?.serverID != serverID {
            a.task = liveTask(title, serverID)
            a.progress = 0.03
            log(a.id, "Accepted quest: \(title)", .start)
            onEvent?(.questStart(a.id))
            say(a, ["On it!", "New quest!", "Leave it to me!"].randomElement()!, .speech, for: 2)
        }
        if a.mode != .working || a.arrival != .work { walk(a, to: a.persona.station, then: .work) }
    }

    func liveActivity(_ agentID: String, serverID: String, title: String, text: String, steps: Int) {
        guard let a = agent(agentID) else { return }
        if a.task?.serverID != serverID { liveStarted(agentID, serverID: serverID, title: title) }
        say(a, text, .speech, for: 7)
        a.progress = min(0.92, 1 - exp(-Double(steps + 1) / 7))
    }

    func liveApproval(_ agentID: String, serverID: String, title: String, proposal: String) {
        guard let a = agent(agentID) else { return }
        a.queue.removeAll { $0.serverID == serverID }
        if a.task?.serverID != serverID { a.task = liveTask(title, serverID) }
        a.task?.approvalPrompt = proposal
        a.progress = max(a.progress, 0.8)
        if a.mode != .awaitingApproval {
            say(a, "I need your approval for this...", .thought, for: 2.5)
            walk(a, to: .questBoard, then: .approval)
        }
    }

    func liveDone(_ agentID: String, serverID: String, title: String, result: String, tokens: Int) {
        guard let a = agent(agentID) else { return }
        if !results.contains(where: { $0.id == serverID }) {
            results.insert(LiveResult(id: serverID, agentID: agentID, title: title, text: result, date: Date()), at: 0)
        }
        a.tokens += tokens
        a.queue.removeAll { $0.serverID == serverID }
        if a.task?.serverID != serverID { a.task = liveTask(title, serverID) }
        a.progress = 1
        celebrate(a)
    }

    func liveFailed(_ agentID: String, serverID: String, text: String) {
        guard let a = agent(agentID) else { return }
        a.queue.removeAll { $0.serverID == serverID }
        if a.task?.serverID == serverID || a.task == nil {
            a.task = nil
            a.progress = 0
            a.expression = .sad
            say(a, "Oops... that didn't work.", .speech, for: 4)
            log(a.id, "Couldn't finish: \(text)", .info)
            goRest(a)
        }
    }

    func liveCancelled(_ agentID: String, serverID: String) {
        guard let a = agent(agentID) else { return }
        a.queue.removeAll { $0.serverID == serverID }
        if a.task?.serverID == serverID {
            a.task = nil
            a.progress = 0
            goRest(a)
        }
    }
}
