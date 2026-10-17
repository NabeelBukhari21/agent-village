import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: Inbox — every approval in one place

struct InboxPanel: View {
    let model: WorldModel
    var onGoTo: (String) -> Void
    var onClose: () -> Void
    @Environment(\.pixelScale) private var ps

    var body: some View {
        PixelPanel(title: "INBOX  (\(model.pending.count))", icon: "inbox", onClose: onClose) {
            VStack(alignment: .leading, spacing: 6 * ps.ui) {
                if model.pending.isEmpty {
                    HStack(spacing: 4 * ps.ui) {
                        PixelIcon(name: "check", scale: ps.title)
                        VStack(alignment: .leading, spacing: 2 * ps.ui) {
                            PixelText(text: "ALL CLEAR!", color: 0x9BFFC0)
                            PixelText(text: "No one is waiting on you right now.", color: 0xC9D2FF, shadow: nil, size: ps.small)
                        }
                    }
                    .padding(.vertical, 6 * ps.ui)
                }
                ForEach(model.pending) { a in
                    VStack(alignment: .leading, spacing: 4 * ps.ui) {
                        HStack(alignment: .top, spacing: 4 * ps.ui) {
                            PixelUI.portraitImage(a.persona, .surprised).resizable().interpolation(.none)
                                .frame(width: 34 * ps.small, height: 34 * ps.small)
                            VStack(alignment: .leading, spacing: 2 * ps.ui) {
                                HStack(spacing: 3 * ps.ui) {
                                    PixelText(text: a.persona.name.uppercased(), color: a.persona.aura)
                                    PixelText(text: (a.task?.title ?? "").uppercased(), color: 0xFFD23F, shadow: nil, size: ps.small)
                                }
                                ProposalText(text: a.task?.approvalPrompt ?? "Needs your approval.")
                            }
                        }
                        HStack(spacing: 3 * ps.ui) {
                            PixelActionButton(title: "APPROVE", icon: "check", style: .good) { model.approve(a) }
                            PixelActionButton(title: "DENY", icon: "cross", style: .bad) { model.deny(a) }
                            PixelActionButton(title: "VISIT", icon: "home") { onGoTo(a.id) }
                        }
                    }
                    .padding(5 * ps.ui)
                    .background(Color(hex: 0x0C0818, opacity: 0.35))
                }
            }
        }
    }
}

// MARK: New quest — assign work to an agent

struct NewQuestPanel: View {
    let model: WorldModel
    @Binding var agentID: String
    var onClose: () -> Void
    @Environment(\.pixelScale) private var ps
    @State private var title = ""
    @State private var needsApproval = false
    @FocusState private var focused: Bool

    var body: some View {
        let agent = model.agent(agentID) ?? model.agents[0]
        PixelPanel(title: "NEW QUEST", icon: "quest", onClose: onClose) {
            VStack(alignment: .leading, spacing: 6 * ps.ui) {
                PixelText(text: "WHO SHOULD DO IT?", color: 0x9AA3D6, shadow: nil, size: ps.small)
                HStack(spacing: 3 * ps.ui) {
                    ForEach(model.agents) { a in
                        Button { Chiptune.shared.play(.select); agentID = a.id } label: {
                            VStack(spacing: 2 * ps.small) {
                                PixelUI.portraitImage(a.persona, a.id == agentID ? .happy : .normal).resizable().interpolation(.none)
                                    .frame(width: 34 * ps.small, height: 34 * ps.small)
                                PixelText(text: a.persona.name.uppercased(), color: a.id == agentID ? 0xFFD23F : 0xC9D2FF, shadow: nil, size: ps.small)
                            }
                            .padding(3 * ps.ui)
                            .pixelWindow(top: a.id == agentID ? 0x4A3A8C : 0x2A2D6E, bottom: a.id == agentID ? 0x261C58 : 0x15173D,
                                         accent: a.id == agentID ? 0xFFD23F : 0xF4E9D0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                PixelText(text: agent.persona.role.uppercased(), color: agent.persona.aura, shadow: nil, size: ps.small)

                PixelText(text: "WRITE A QUEST", color: 0x9AA3D6, shadow: nil, size: ps.small)
                TextField("", text: $title, prompt: Text("e.g. Summarize my unread emails").foregroundStyle(Color(hex: 0x6A6F96)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .focused($focused)
                    .padding(.horizontal, 6 * ps.ui)
                    .padding(.vertical, 5 * ps.ui)
                    .pixelWindow(top: 0x0F1030, bottom: 0x0F1030, accent: focused ? 0xFFD23F : 0xF4E9D0)
                    .onSubmit(add)
                Button { needsApproval.toggle(); Chiptune.shared.play(.select) } label: {
                    HStack(spacing: 3 * ps.ui) {
                        PixelIcon(name: needsApproval ? "check" : "cross", scale: ps.small)
                        PixelText(text: "ASK ME BEFORE FINISHING", color: needsApproval ? 0xFFFFFF : 0x9AA3D6)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                PixelActionButton(title: "ADD TO \(agent.persona.name.uppercased())'S QUEUE", icon: "plus", style: .accent,
                                  disabled: title.trimmingCharacters(in: .whitespaces).isEmpty, action: add)

                PixelText(text: model.isLive ? "OR PICK A REAL TASK (RUNS ON YOUR MAC)" : "OR PICK A COMMON QUEST", color: model.isLive ? 0x7DFFA8 : 0x9AA3D6, shadow: nil, size: ps.small)
                    .padding(.top, 2 * ps.ui)
                if model.isLive {
                    VStack(alignment: .leading, spacing: 3 * ps.ui) {
                        ForEach(Array(agent.persona.liveIdeas.enumerated()), id: \.offset) { _, idea in
                            Button {
                                Chiptune.shared.play(.select)
                                model.enqueue(model.customTask(for: agent.persona, title: idea.0, needsApproval: idea.1), for: agent)
                            } label: {
                                HStack(alignment: .top, spacing: 3 * ps.ui) {
                                    PixelIcon(name: "plus", scale: ps.small)
                                    PixelParagraph(text: idea.0, maxWidth: 270, color: 0xE6ECFF, size: ps.small)
                                    if idea.1 { PixelIcon(name: "ask", scale: ps.small) }
                                }
                                .padding(.vertical, 2 * ps.ui)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                VStack(alignment: .leading, spacing: 2 * ps.ui) {
                    ForEach(agent.persona.tasks) { t in
                        Button {
                            Chiptune.shared.play(.select)
                            var copy = t
                            copy.id = UUID()
                            model.enqueue(copy, for: agent)
                        } label: {
                            HStack(spacing: 3 * ps.ui) {
                                PixelIcon(name: "plus", scale: ps.small)
                                PixelText(text: t.title, color: 0xE6ECFF)
                                if t.approvalPrompt != nil { PixelIcon(name: "ask", scale: ps.small) }
                            }
                            .padding(.vertical, 2 * ps.ui)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                }

                QueueList(model: model, agent: agent)
            }
        }
    }

    private func add() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let a = model.agent(agentID) else { return }
        model.enqueue(model.customTask(for: a.persona, title: t, needsApproval: needsApproval), for: a)
        title = ""
        focused = false
    }
}

/// An agent's upcoming quests, removable.
struct QueueList: View {
    let model: WorldModel
    let agent: AgentState
    @Environment(\.pixelScale) private var ps

    var body: some View {
        VStack(alignment: .leading, spacing: 2 * ps.ui) {
            PixelText(text: "UP NEXT FOR \(agent.persona.name.uppercased())", color: 0x9AA3D6, shadow: nil, size: ps.small)
            if agent.queue.isEmpty {
                PixelText(text: "Nothing queued - they'll pick their own work.", color: 0x6A6F96, shadow: nil, size: ps.small)
            }
            ForEach(Array(agent.queue.enumerated()), id: \.element.id) { i, t in
                HStack(spacing: 3 * ps.ui) {
                    PixelText(text: "\(i + 1).", color: 0xFFD23F)
                    PixelText(text: t.title, color: 0xFFFFFF)
                    Spacer(minLength: 2)
                    Button { Chiptune.shared.play(.select); model.removeFromQueue(t.id, of: agent) } label: {
                        PixelIcon(name: "cross", scale: ps.small).padding(2 * ps.ui).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 3 * ps.ui)
    }
}

// MARK: Stats

struct StatsPanel: View {
    let model: WorldModel
    var onClose: () -> Void
    @Environment(\.pixelScale) private var ps

    var body: some View {
        PixelPanel(title: "STATS", icon: "chart", onClose: onClose) {
            VStack(alignment: .leading, spacing: 6 * ps.ui) {
                HStack(spacing: 3 * ps.ui) {
                    tile("QUESTS DONE", "\(model.questsDone)", 0x9BFFC0)
                    tile("APPROVED", "\(model.approvalsGranted)", 0x9EF6FF)
                    tile("DENIED", "\(model.approvalsDenied)", 0xFF9EB0)
                }
                HStack(spacing: 3 * ps.ui) {
                    tile("SPENT", String(format: "$%.2f", model.totalCost), 0xFFE9A8)
                    tile("TOKENS", tokens(model.totalTokens), 0xD8CCFF)
                    tile("QUEUED", "\(model.agents.reduce(0) { $0 + $1.queue.count })", 0xFFD23F)
                }
                PixelText(text: "BY AGENT", color: 0x9AA3D6, shadow: nil, size: ps.small).padding(.top, 2 * ps.ui)
                let maxTokens = max(1, model.agents.map(\.tokens).max() ?? 1)
                ForEach(model.agents) { a in
                    HStack(spacing: 4 * ps.ui) {
                        PixelUI.portraitImage(a.persona).resizable().interpolation(.none)
                            .frame(width: 30 * ps.small, height: 30 * ps.small)
                        VStack(alignment: .leading, spacing: 2 * ps.ui) {
                            HStack(spacing: 3 * ps.ui) {
                                PixelText(text: a.persona.name.uppercased(), color: a.persona.aura)
                                PixelText(text: "LV\(a.tasksDone + 1)  \(a.tasksDone) DONE  \(String(format: "$%.2f", a.spent))", color: 0xE6ECFF, shadow: nil, size: ps.small)
                            }
                            PixelBar(value: Double(a.tokens) / Double(maxTokens), color: a.persona.aura, width: 90)
                            PixelText(text: "\(tokens(a.tokens)) TOKENS  -  \(a.mode.label.uppercased())", color: 0x9AA3D6, shadow: nil, size: ps.small)
                        }
                    }
                }
            }
        }
    }

    private func tile(_ label: String, _ value: String, _ color: UInt32) -> some View {
        VStack(alignment: .leading, spacing: 1 * ps.ui) {
            PixelText(text: value, color: color)
            PixelText(text: label, color: 0x9AA3D6, shadow: nil, size: ps.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(4 * ps.ui)
        .background(Color(hex: 0x0C0818, opacity: 0.35))
    }

    private func tokens(_ n: Int) -> String { n >= 1000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)" }
}

// MARK: Quest log with filters

struct LogPanel: View {
    let model: WorldModel
    var onRead: (String) -> Void = { _ in }
    var onClose: () -> Void
    @Environment(\.pixelScale) private var ps
    @State private var kind: String = "ALL"
    @State private var agentFilter: String?

    var body: some View {
        PixelPanel(title: "QUEST LOG", icon: "list", onClose: onClose) {
            VStack(alignment: .leading, spacing: 5 * ps.ui) {
                HStack(spacing: 2 * ps.ui) {
                    ForEach(["ALL", "RESULTS", "DONE", "ASKS", "CHATS"], id: \.self) { k in
                        Button { Chiptune.shared.play(.select); kind = k } label: {
                            PixelText(text: k, color: kind == k ? 0xFFD23F : 0xC9D2FF, shadow: nil)
                                .padding(.horizontal, 4 * ps.ui).padding(.vertical, 2 * ps.ui)
                                .background(kind == k ? Color(hex: 0x4A3A8C) : Color(hex: 0x0C0818, opacity: 0.35))
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(spacing: 2 * ps.ui) {
                    ForEach(model.agents) { a in
                        Button { Chiptune.shared.play(.select); agentFilter = agentFilter == a.id ? nil : a.id } label: {
                            PixelUI.portraitImage(a.persona).resizable().interpolation(.none)
                                .frame(width: 22 * ps.small, height: 22 * ps.small)
                                .opacity(agentFilter == nil || agentFilter == a.id ? 1 : 0.35)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if kind == "RESULTS" {
                    if model.results.isEmpty {
                        PixelText(text: "No results yet. Finished real tasks appear here.", color: 0x6A6F96, shadow: nil, size: ps.small)
                    }
                    ForEach(model.results.filter { agentFilter == nil || $0.agentID == agentFilter }) { r in
                        Button { Chiptune.shared.play(.select); onRead(r.id) } label: {
                            HStack(spacing: 4 * ps.ui) {
                                if let a = model.agent(r.agentID) {
                                    PixelUI.portraitImage(a.persona, .happy).resizable().interpolation(.none)
                                        .frame(width: 22 * ps.small, height: 22 * ps.small)
                                }
                                PixelParagraph(text: r.title, maxWidth: 220, color: 0xFFFFFF, size: ps.small)
                                Spacer(minLength: 2)
                                PixelText(text: "READ", color: 0xFFD23F)
                            }
                            .padding(3 * ps.ui)
                            .background(Color(hex: 0x0C0818, opacity: 0.35))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                let entries = kind == "RESULTS" ? [] : filtered
                if entries.isEmpty && kind != "RESULTS" {
                    PixelText(text: "Nothing here yet.", color: 0x6A6F96, shadow: nil, size: ps.small)
                }
                ForEach(entries) { e in
                    HStack(alignment: .top, spacing: 4 * ps.ui) {
                        PixelText(text: stamp(e.time), color: 0x6A6F96, shadow: nil, size: ps.small)
                        FeedLine(entry: e, model: model)
                    }
                }
            }
        }
    }

    private var filtered: [FeedEntry] {
        model.feed.filter { e in
            let k: Bool = switch kind {
            case "DONE": e.kind == .done
            case "ASKS": e.kind == .approval
            case "CHATS": e.kind == .chat
            default: true
            }
            return k && (agentFilter == nil || e.agentID == agentFilter)
        }
    }

    private func stamp(_ t: Double) -> String {
        let tod = (t / model.dayLength + 0.32).truncatingRemainder(dividingBy: 1)
        let m = Int(tod * 24 * 60)
        return String(format: "%02d:%02d", m / 60, m % 60)
    }
}

struct FeedLine: View {
    let entry: FeedEntry
    let model: WorldModel
    @Environment(\.pixelScale) private var ps

    var body: some View {
        let p = model.agent(entry.agentID)?.persona
        HStack(alignment: .top, spacing: 3 * ps.ui) {
            PixelIcon(name: icon, scale: ps.small)
            PixelText(text: (p?.name ?? "").uppercased(), color: p?.aura ?? 0xFFFFFF, shadow: nil, size: ps.small)
            PixelParagraph(text: entry.text, maxWidth: 250, color: 0xE6ECFF, size: ps.small)
        }
    }

    private var icon: String {
        switch entry.kind {
        case .start: "sword"
        case .done: "check"
        case .approval: "ask"
        case .chat: "heart"
        case .info: "scroll"
        }
    }
}

// MARK: Menu / settings

struct MenuPanel: View {
    let model: WorldModel
    let link: LiveLink
    var onRecenter: () -> Void
    var onClose: () -> Void
    @Environment(\.pixelScale) private var ps
    @State private var music = Chiptune.shared.isMusicOn
    @State private var sfx = Chiptune.shared.isSFXOn

    var body: some View {
        PixelPanel(title: "MENU", icon: "gear", onClose: onClose) {
            VStack(alignment: .leading, spacing: 5 * ps.ui) {
                MacConnectSection(link: link)
                row("music", "MUSIC", music ? "ON" : "OFF") {
                    music.toggle(); Chiptune.shared.setMusic(music)
                }
                row("sound", "SOUND EFFECTS", sfx ? "ON" : "OFF") {
                    sfx.toggle(); Chiptune.shared.setSFX(sfx)
                }
                row("fast", "GAME SPEED", "\(Int(model.timeScale))X") {
                    model.timeScale = model.timeScale >= 4 ? 1 : model.timeScale * 2
                }
                row(model.allPaused ? "play" : "pausei", model.allPaused ? "WAKE EVERYONE" : "PAUSE EVERYONE", "") {
                    model.allPaused ? model.resumeAll() : model.pauseAll()
                }
                row("home", "RECENTER CAMERA", "") { onRecenter() }
                PixelText(text: "Tip: tap an agent to talk. Drag to look around, pinch to zoom.", color: 0x6A6F96, shadow: nil, size: ps.small)
                    .padding(.top, 3 * ps.ui)
            }
        }
    }

    private func row(_ icon: String, _ title: String, _ value: String, action: @escaping () -> Void) -> some View {
        Button { Chiptune.shared.play(.select); action() } label: {
            HStack(spacing: 4 * ps.ui) {
                PixelIcon(name: icon)
                PixelText(text: title, color: 0xFFFFFF)
                Spacer()
                if !value.isEmpty { PixelText(text: value, color: value == "OFF" ? 0xFF9EB0 : 0xFFD23F) }
            }
            .padding(5 * ps.ui)
            .background(Color(hex: 0x0C0818, opacity: 0.35))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Mac connection

struct MacConnectSection: View {
    let link: LiveLink
    @Environment(\.pixelScale) private var ps
    @State private var address = ""
    @State private var code = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * ps.ui) {
            HStack(spacing: 3 * ps.ui) {
                PixelIcon(name: "work")
                PixelText(text: "YOUR MAC", color: 0xFFD23F)
                Spacer()
                PixelText(text: link.isConnected ? "LIVE" : "DEMO", color: link.isConnected ? 0x7DFFA8 : 0x9AA3D6)
            }
            PixelParagraph(text: link.status.label, maxWidth: 300, color: statusColor, size: ps.small)
            if !link.isConnected {
                if !link.found.isEmpty {
                    PixelText(text: "FOUND ON YOUR WI-FI", color: 0x9AA3D6, shadow: nil, size: ps.small)
                    ForEach(link.found) { f in
                        Button { Chiptune.shared.play(.select); address = f.address } label: {
                            HStack(spacing: 3 * ps.ui) {
                                PixelText(text: address == f.address ? "▶" : " ", color: 0xFFD23F)
                                PixelText(text: f.name, color: 0xFFFFFF, size: ps.small)
                                PixelText(text: f.address, color: 0x9AA3D6, shadow: nil, size: ps.small)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                field("Mac address (e.g. 10.0.0.236)", text: $address)
                field("Pairing code from your Mac", text: $code)
                PixelActionButton(title: "CONNECT", icon: "check", style: .good,
                                  disabled: address.isEmpty || code.isEmpty) {
                    link.address = address
                    link.code = code
                    link.connect()
                }
                PixelText(text: "On your Mac run: python3 server/village_server.py", color: 0x6A6F96, shadow: nil, size: ps.small)
            } else {
                PixelActionButton(title: "DISCONNECT", icon: "cross", style: .bad) { link.disconnect() }
            }
        }
        .padding(5 * ps.ui)
        .background(Color(hex: 0x0C0818, opacity: 0.35))
        .onAppear {
            address = link.address
            code = link.code
            link.startBrowsing()
        }
        .onChange(of: link.address) { _, a in if address.isEmpty { address = a } }
    }

    private var statusColor: UInt32 {
        switch link.status {
        case .connected: 0x7DFFA8
        case .failed: 0xFF9EB0
        default: 0xC9D2FF
        }
    }

    private func field(_ prompt: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(prompt).foregroundStyle(Color(hex: 0x6A6F96)))
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .padding(.horizontal, 6 * ps.ui)
            .padding(.vertical, 4 * ps.ui)
            .pixelWindow(top: 0x0F1030, bottom: 0x0F1030)
    }
}

// MARK: Reading results

/// Readable (non-pixel) rendering of an agent's Markdown answer.
struct ReadableMarkdown: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, raw in
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.isEmpty {
                    Color.clear.frame(height: 2)
                } else if line.hasPrefix("#") {
                    Text(line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xFFD23F))
                        .padding(.top, 4)
                } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.first?.isNumber == true && line.contains(". ") {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(line.hasPrefix("- ") || line.hasPrefix("* ") ? "•" : "")
                            .foregroundStyle(Color(hex: 0xFF8FB8))
                        Text(inline(line.hasPrefix("- ") || line.hasPrefix("* ") ? String(line.dropFirst(2)) : line))
                    }
                } else {
                    Text(inline(line))
                }
            }
        }
        .font(.system(size: 14, weight: .regular, design: .rounded))
        .foregroundStyle(Color(hex: 0xE6ECFF))
        .textSelection(.enabled)
    }

    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
    }
}

struct ProposalText: View {
    let text: String
    var body: some View {
        ScrollView {
            ReadableMarkdown(text: text).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 180)
        .padding(8)
        .background(Color(hex: 0x0C0818, opacity: 0.55))
    }
}

struct ReportPanel: View {
    let model: WorldModel
    let resultID: String
    var onClose: () -> Void
    @Environment(\.pixelScale) private var ps

    var body: some View {
        let r = model.results.first { $0.id == resultID }
        PixelPanel(title: "REPORT", icon: "scroll", onClose: onClose) {
            VStack(alignment: .leading, spacing: 6 * ps.ui) {
                if let r, let a = model.agent(r.agentID) {
                    HStack(spacing: 4 * ps.ui) {
                        PixelUI.portraitImage(a.persona, .happy).resizable().interpolation(.none)
                            .frame(width: 30 * ps.small, height: 30 * ps.small)
                        VStack(alignment: .leading, spacing: 2 * ps.ui) {
                            PixelText(text: a.persona.name.uppercased(), color: a.persona.aura)
                            PixelParagraph(text: r.title, maxWidth: 260, color: 0xFFFFFF, size: ps.small)
                        }
                    }
                    ReadableMarkdown(text: r.text)
                    PixelActionButton(title: "COPY", icon: "scroll") {
                        #if os(iOS)
                        UIPasteboard.general.string = r.text
                        #else
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(r.text, forType: .string)
                        #endif
                    }
                } else {
                    PixelText(text: "This report isn't available.", color: 0x9AA3D6)
                }
            }
        }
    }
}
