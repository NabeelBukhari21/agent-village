import SwiftUI

enum DashPanel: Hashable, Identifiable {
    case log, inbox, quest, stats, menu
    case report(String)
    var id: String { "\(self)" }
}

/// Day + clock chip.
struct ClockChip: View {
    let model: WorldModel
    var showTitle: Bool
    @Environment(\.pixelScale) private var ps

    var body: some View {
        let night = model.timeOfDay < 0.24 || model.timeOfDay > 0.78
        HStack(spacing: 3 * ps.ui) {
            PixelIcon(name: night ? "moon" : "sun")
            VStack(alignment: .leading, spacing: 1 * ps.small) {
                if showTitle {
                    PixelText(text: "AGENT VILLAGE", color: 0xFFD23F, outline: 0x3A1A08)
                }
                if showTitle {
                    PixelText(text: "DAY \(model.day)  \(model.clockString)", color: 0xC9D2FF, size: ps.small)
                } else {
                    PixelText(text: model.clockString, color: 0xFFFFFF)
                }
                PixelText(text: model.isLive ? "LIVE ON MAC" : (showTitle ? "DEMO MODE" : "DAY \(model.day)"),
                          color: model.isLive ? 0x7DFFA8 : 0x9AA3D6, shadow: nil, size: ps.small)
            }
        }
        .padding(.horizontal, 5 * ps.ui)
        .padding(.vertical, 3 * ps.ui)
        .pixelWindow()
    }
}

/// The four numbers that matter: who's busy, who needs you, what's done, what it cost.
struct StatusStrip: View {
    let model: WorldModel
    var compact = false
    var onInbox: () -> Void
    var onStats: () -> Void
    @Environment(\.pixelScale) private var ps

    var body: some View {
        let pending = model.pending.count
        HStack(spacing: 3 * ps.ui) {
            StatChip(icon: "work", value: "\(model.workingCount)/\(model.agents.count)", label: compact ? "" : "WORKING", color: 0x9EF6FF)
                .onTapGesture(perform: onStats)
            StatChip(icon: "ask", value: "\(pending)", label: compact ? "" : "NEED YOU", color: pending > 0 ? 0xFFD23F : 0xFFFFFF, alert: pending > 0)
                .onTapGesture(perform: onInbox)
            StatChip(icon: "check", value: "\(model.questsDone)", label: compact ? "" : "DONE", color: 0x9BFFC0)
                .onTapGesture(perform: onStats)
            StatChip(icon: model.isLive ? "mana" : "coin",
                     value: model.isLive ? tokenString(model.totalTokens) : String(format: "$%.2f", model.totalCost),
                     label: compact ? "" : (model.isLive ? "TOKENS" : "SPENT"), color: 0xFFE9A8)
                .onTapGesture(perform: onStats)
        }
    }
}

/// RPG party frames.
struct PartyBar: View {
    let model: WorldModel
    var vertical: Bool
    var onSelect: (String) -> Void
    @Environment(\.pixelScale) private var ps

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3 * ps.ui)) : AnyLayout(HStackLayout(spacing: 3 * ps.ui))
        layout {
            ForEach(model.agents) { a in
                PartyMember(agent: a, selected: model.selectedID == a.id, compact: !vertical)
                    .onTapGesture { onSelect(a.id) }
            }
        }
    }
}

private struct PartyMember: View {
    let agent: AgentState
    let selected: Bool
    let compact: Bool
    @Environment(\.pixelScale) private var ps
    @State private var blink = false

    var body: some View {
        let p = agent.persona
        let calling = agent.mode == .awaitingApproval
        HStack(spacing: 4 * ps.ui) {
            ZStack(alignment: .bottomTrailing) {
                PixelUI.portraitImage(p, calling ? .surprised : (agent.mode == .celebrating ? .happy : (agent.mode == .paused ? .blink : .normal)))
                    .resizable()
                    .interpolation(.none)
                    .frame(width: (compact ? 36 : 40) * ps.small, height: (compact ? 36 : 40) * ps.small)
                statusBadge
            }
            if !compact {
                VStack(alignment: .leading, spacing: 2 * ps.ui) {
                    HStack(spacing: 3 * ps.ui) {
                        PixelText(text: p.name.uppercased(), color: selected ? 0xFFD23F : 0xFFFFFF)
                        PixelText(text: p.title.uppercased(), color: p.aura, shadow: nil, size: ps.small)
                    }
                    PixelText(text: status, color: calling ? 0xFFD23F : 0xC9D2FF, shadow: nil, size: ps.small)
                    HStack(spacing: 3 * ps.ui) {
                        PixelBar(value: agent.task == nil ? 0 : agent.progress, color: p.aura, width: 52)
                        if !agent.queue.isEmpty {
                            PixelText(text: "+\(agent.queue.count)", color: 0xFFD23F, shadow: nil, size: ps.small)
                        }
                    }
                }
                .frame(width: 92 * ps.ui, alignment: .leading)
            }
        }
        .padding(3 * ps.ui)
        .overlay(alignment: .bottom) {
            if compact {
                PixelBar(value: agent.task == nil ? 0 : agent.progress, color: p.aura, width: 26).padding(.bottom, 2 * ps.ui)
            }
        }
        .pixelWindow(top: selected ? 0x4A3A8C : 0x2A2D6E, bottom: selected ? 0x261C58 : 0x15173D,
                     accent: calling ? (blink ? 0xFFD23F : 0xF4E9D0) : (selected ? 0xFFD23F : 0xF4E9D0))
        .onAppear { withAnimation(.linear(duration: 0.4).repeatForever()) { blink.toggle() } }
        .contentShape(Rectangle())
    }

    private var statusBadge: some View {
        let icon: String = switch agent.mode {
        case .awaitingApproval: "ask"
        case .working: "work"
        case .paused: "zzz"
        case .celebrating: "check"
        case .chatting: "heart"
        default: ""
        }
        return Group {
            if !icon.isEmpty {
                PixelIcon(name: icon, scale: ps.small)
                    .padding(1 * ps.small)
                    .background(Color(hex: 0x0C0818, opacity: 0.85))
                    .opacity(agent.mode == .awaitingApproval && !blink ? 0.4 : 1)
            }
        }
    }

    private var status: String {
        if let t = agent.task, agent.mode == .working || agent.mode == .walking {
            let title = t.title.count > 20 ? String(t.title.prefix(19)) + "." : t.title
            return title.uppercased()
        }
        return agent.mode.label.uppercased()
    }
}

/// Pop-up alerts for finished quests and approval requests.
struct ToastStack: View {
    let model: WorldModel
    var onTap: (Toast) -> Void
    @Environment(\.pixelScale) private var ps

    var body: some View {
        VStack(spacing: 3 * ps.ui) {
            ForEach(model.toasts) { t in
                if let a = model.agent(t.agentID) {
                    Button { onTap(t) } label: {
                        HStack(spacing: 4 * ps.ui) {
                            PixelUI.portraitImage(a.persona, t.kind == .done ? .happy : .surprised)
                                .resizable().interpolation(.none)
                                .frame(width: 26 * ps.small, height: 26 * ps.small)
                            VStack(alignment: .leading, spacing: 1 * ps.ui) {
                                PixelText(text: t.kind == .done ? "QUEST COMPLETE" : "\(a.persona.name.uppercased()) NEEDS YOU",
                                          color: t.kind == .done ? 0x9BFFC0 : 0xFFD23F)
                                PixelText(text: shorten(a.task?.title ?? t.text.replacingOccurrences(of: "Quest clear: ", with: "")), color: 0xE6ECFF, shadow: nil, size: ps.small)
                            }
                        }
                        .padding(.horizontal, 6 * ps.ui)
                        .padding(.vertical, 3 * ps.ui)
                        .pixelWindow(top: t.kind == .done ? 0x1F5A3C : 0x6A2038, bottom: t.kind == .done ? 0x0F3020 : 0x3A0E20)
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.toasts)
    }

    private func shorten(_ s: String) -> String { s.count > 34 ? String(s.prefix(33)) + "." : s }
}

/// Bottom navigation for the dashboard panels.
struct NavBar: View {
    let model: WorldModel
    var current: DashPanel?
    var onOpen: (DashPanel) -> Void
    @Environment(\.pixelScale) private var ps

    var body: some View {
        HStack(spacing: 2 * ps.ui) {
            item(.log, "list", "LOG")
            item(.inbox, "inbox", "INBOX", badge: model.pending.count)
            item(.quest, "quest", "QUEST")
            item(.stats, "chart", "STATS")
            item(.menu, "gear", "MENU")
        }
        .padding(2 * ps.ui)
        .pixelWindow(top: 0x1E1F4E, bottom: 0x101230)
    }

    private func item(_ p: DashPanel, _ icon: String, _ label: String, badge: Int = 0) -> some View {
        Button {
            Chiptune.shared.play(.select)
            onOpen(p)
        } label: {
            VStack(spacing: 2 * ps.small) {
                PixelIcon(name: icon)
                PixelText(text: label, color: current == p ? 0xFFD23F : 0xC9D2FF, shadow: nil, size: ps.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3 * ps.ui)
            .background(current == p ? Color(hex: 0x4A3A8C) : .clear)
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    PixelText(text: "\(badge)", color: 0xFFFFFF, shadow: nil, size: ps.small)
                        .padding(.horizontal, 2 * ps.small)
                        .background(Color(hex: 0xE8366E))
                        .offset(x: -2 * ps.ui, y: 1 * ps.ui)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Camera zoom/recenter cluster.
struct ZoomCluster: View {
    var onZoomIn: () -> Void
    var onZoomOut: () -> Void
    var onHome: () -> Void
    @Environment(\.pixelScale) private var ps

    var body: some View {
        VStack(spacing: 2 * ps.ui) {
            PixelButton(icon: "plus", action: onZoomIn)
            PixelButton(icon: "minus", action: onZoomOut)
            PixelButton(icon: "home", action: onHome)
        }
    }
}

func tokenString(_ n: Int) -> String {
    n >= 1_000_000 ? String(format: "%.1fM", Double(n) / 1_000_000) : (n >= 1000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)")
}
