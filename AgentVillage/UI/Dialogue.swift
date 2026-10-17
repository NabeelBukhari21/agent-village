import SwiftUI

/// JRPG dialogue window with a TALK tab (conversation + choices) and an INFO tab (agent card).
struct DialogueWindow: View {
    let agent: AgentState
    let model: WorldModel
    var width: CGFloat
    var onNewQuest: (String) -> Void
    var onRead: (String) -> Void = { _ in }
    var onClose: () -> Void
    @Environment(\.pixelScale) private var ps
    @State private var line = ""
    @State private var shown = 0
    @State private var lineID = UUID()
    @State private var tab = 0
    @State private var cursorOn = true

    var body: some View {
        let p = agent.persona
        VStack(alignment: .leading, spacing: 0) {
            // Name tab + tabs
            HStack(spacing: 3 * ps.ui) {
                HStack(spacing: 3 * ps.ui) {
                    PixelText(text: p.name.uppercased(), color: 0xFFFFFF, outline: 0x100A1E)
                    PixelText(text: p.title.uppercased(), color: 0xFFF3C8, shadow: 0x100A1E, size: ps.small)
                }
                .padding(.horizontal, 6 * ps.ui)
                .padding(.vertical, 3 * ps.ui)
                .pixelWindow(top: p.aura, bottom: FaceShade.darken(p.aura))
                Spacer(minLength: 0)
                tabButton("TALK", 0)
                tabButton("INFO", 1)
                Button { Chiptune.shared.play(.select); onClose() } label: {
                    PixelIcon(name: "cross").padding(4 * ps.ui).pixelWindow().contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .offset(y: 3 * ps.ui)
            .zIndex(1)

            Group {
                if tab == 0 { talk } else { info }
            }
            .padding(7 * ps.ui)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelWindow()
        }
        .task(id: lineID) {
            shown = 0
            while shown < line.count {
                try? await Task.sleep(for: .milliseconds(22))
                if Task.isCancelled { return }
                shown += 1
                if shown % 4 == 0 { Chiptune.shared.play(.blip) }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(450))
                cursorOn.toggle()
            }
        }
        .onAppear { say(agent.mode == .awaitingApproval ? model.statusReply(for: agent) : p.greeting) }
        .onChange(of: agent.mode) { _, m in
            if m == .awaitingApproval { say(model.statusReply(for: agent)) }
        }
    }

    private func tabButton(_ title: String, _ i: Int) -> some View {
        Button { Chiptune.shared.play(.select); tab = i } label: {
            PixelText(text: title, color: tab == i ? 0xFFD23F : 0x9AA3D6)
                .padding(.horizontal, 5 * ps.ui)
                .padding(.vertical, 3 * ps.ui)
                .pixelWindow(top: tab == i ? 0x4A3A8C : 0x1E1F4E, bottom: tab == i ? 0x261C58 : 0x101230,
                             accent: tab == i ? 0xFFD23F : 0xF4E9D0)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Talk

    private var talk: some View {
        let p = agent.persona
        return HStack(alignment: .top, spacing: 6 * ps.ui) {
            PixelUI.portraitImage(p, expression)
                .resizable()
                .interpolation(.none)
                .frame(width: 44 * ps.ui, height: 44 * ps.ui)
                .background(Color(hex: p.aura, opacity: 0.25))
                .padding(2 * ps.ui)
                .pixelWindow(top: 0x34306E, bottom: 0x1E1B48, accent: p.aura)

            VStack(alignment: .leading, spacing: 5 * ps.ui) {
                ZStack(alignment: .bottomTrailing) {
                    PixelParagraph(text: String(line.prefix(shown)), maxWidth: textWidth)
                        .frame(width: textWidth, alignment: .topLeading)
                        .frame(minHeight: 34 * ps.ui, alignment: .topLeading)
                    if shown >= line.count {
                        PixelText(text: "▶", color: 0xFFD23F)
                            .rotationEffect(.degrees(90))
                            .opacity(cursorOn ? 1 : 0)
                    }
                }
                if let t = agent.task {
                    HStack(spacing: 3 * ps.ui) {
                        PixelIcon(name: "scroll", scale: ps.small)
                        PixelText(text: t.title.uppercased(), color: 0xFFD23F, size: ps.small)
                        PixelBar(value: agent.progress, color: p.aura, width: 40)
                    }
                }
                choices
            }
        }
    }

    private var textWidth: CGFloat { max(120, min(width, 720) - 48 * ps.ui - 14 * ps.ui - 6 * ps.ui - 4) }

    private var expression: Expression {
        switch agent.mode {
        case .celebrating, .chatting: .happy
        case .awaitingApproval: .surprised
        case .paused: .blink
        default: shown < line.count && shown % 6 < 3 ? .happy : .normal
        }
    }

    private struct Choice: Identifiable {
        let id: String
        let label: String
        let icon: String
        let style: PixelActionButton.Style
        let run: () -> Void
    }

    private var options: [Choice] {
        var c: [Choice] = []
        if agent.mode == .awaitingApproval {
            c.append(Choice(id: "ok", label: "APPROVE", icon: "check", style: .good) {
                model.approve(agent); say("Yatta~! Thank you, boss! I'll take care of it right away!")
            })
            c.append(Choice(id: "no", label: "DENY", icon: "cross", style: .bad) {
                model.deny(agent); say("Understood... I'll drop it. Maybe next time!")
            })
        }
        c.append(Choice(id: "ask", label: "STATUS?", icon: "ask", style: .normal) {
            say(model.statusReply(for: agent))
        })
        c.append(Choice(id: "quest", label: "NEW QUEST", icon: "quest", style: .accent) {
            onNewQuest(agent.id)
        })
        let paused = agent.mode == .paused
        c.append(Choice(id: "rest", label: paused ? "WAKE UP" : "BREAK", icon: paused ? "sun" : "zzz", style: .normal) {
            model.togglePause(agent)
            say(paused ? "Waah! I'm up, I'm up! Back to work~" : "A break? Don't mind if I do... zzz")
        })
        return c
    }

    private var choices: some View {
        let cols = [GridItem(.adaptive(minimum: 58 * ps.ui), spacing: 3 * ps.ui, alignment: .leading)]
        return LazyVGrid(columns: cols, alignment: .leading, spacing: 3 * ps.ui) {
            ForEach(options) { o in
                PixelActionButton(title: o.label, icon: o.icon, style: o.style, action: o.run)
            }
        }
    }

    // MARK: Info

    private var info: some View {
        let p = agent.persona
        let recent = model.feed.filter { $0.agentID == agent.id }.prefix(3)
        return VStack(alignment: .leading, spacing: 5 * ps.ui) {
            HStack(alignment: .top, spacing: 6 * ps.ui) {
                PixelUI.portraitImage(p, .happy).resizable().interpolation(.none)
                    .frame(width: 34 * ps.small, height: 34 * ps.small)
                VStack(alignment: .leading, spacing: 2 * ps.ui) {
                    PixelText(text: p.role.uppercased(), color: p.aura)
                    PixelText(text: "LV\(agent.tasksDone + 1)  -  \(agent.tasksDone) QUESTS DONE  -  \(agent.approvalsAsked) ASKS", color: 0xE6ECFF, shadow: nil, size: ps.small)
                    PixelText(text: String(format: "SPENT $%.2f  -  %@ TOKENS", agent.spent, tokenString(agent.tokens)), color: 0xFFE9A8, shadow: nil, size: ps.small)
                }
            }
            VStack(alignment: .leading, spacing: 2 * ps.ui) {
                PixelText(text: "NOW", color: 0x9AA3D6, shadow: nil, size: ps.small)
                if let t = agent.task {
                    HStack(spacing: 3 * ps.ui) {
                        PixelText(text: t.title, color: 0xFFFFFF)
                        PixelBar(value: agent.progress, color: p.aura, width: 40)
                        if let r = agent.remaining, agent.mode == .working {
                            PixelText(text: "~\(max(1, Int(r / model.timeScale)))S LEFT", color: 0x9EF6FF, shadow: nil, size: ps.small)
                        }
                    }
                } else {
                    PixelText(text: agent.mode.label, color: 0xC9D2FF)
                }
            }
            QueueList(model: model, agent: agent)
            if let r = model.results.first(where: { $0.agentID == agent.id }) {
                Button { Chiptune.shared.play(.select); onRead(r.id) } label: {
                    HStack(spacing: 3 * ps.ui) {
                        PixelIcon(name: "scroll", scale: ps.small)
                        PixelText(text: "LAST RESULT:", color: 0x9AA3D6, shadow: nil, size: ps.small)
                        PixelText(text: String(r.title.prefix(24)), color: 0xFFFFFF, size: ps.small)
                        PixelText(text: "READ ▶", color: 0xFFD23F)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2 * ps.ui) {
                PixelText(text: "RECENTLY", color: 0x9AA3D6, shadow: nil, size: ps.small)
                ForEach(Array(recent)) { e in FeedLine(entry: e, model: model) }
            }
            PixelActionButton(title: "ASSIGN A QUEST", icon: "quest", style: .accent) { onNewQuest(agent.id) }
        }
    }

    private func tokenString(_ n: Int) -> String { n >= 1000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)" }

    private func say(_ text: String) {
        line = PixelFont.normalize(text)
        lineID = UUID()
    }
}

enum FaceShade {
    static func darken(_ hex: UInt32) -> UInt32 { PixelColor(hex).darker(0.45).hex }
}
