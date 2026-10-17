import SwiftUI

/// Title plate with the day and clock.
struct TitlePlate: View {
    let model: WorldModel
    var compact: Bool

    var body: some View {
        let night = model.timeOfDay < 0.23 || model.timeOfDay > 0.8
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(night ? Color(hex: 0x3B3F8F) : Theme.gold).frame(width: 30, height: 30)
                Image(systemName: night ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(night ? Color(hex: 0xFFF3A0) : Color(hex: 0xFF7A1A))
            }
            .shadow(color: night ? Theme.violet : Theme.gold, radius: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text("AGENT VILLAGE")
                    .font(Theme.title(compact ? 15 : 19))
                    .tracking(1.5)
                    .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFFD6E8)], startPoint: .top, endPoint: .bottom))
                    .outlinedText(Color(hex: 0xC2185B), width: 1)
                Text("Day \(model.day) · \(model.clockString)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .gamePanel(radius: 16)
    }
}

/// Gold, mana and quest counters.
struct ResourceBar: View {
    let model: WorldModel
    var compact: Bool

    var body: some View {
        HStack(spacing: compact ? 6 : 10) {
            Resource(icon: "dollarsign.circle.fill", tint: Theme.gold, value: String(format: "$%.2f", model.totalCost), label: "Gold")
            Resource(icon: "sparkles", tint: Theme.cyan, value: formatTokens(model.totalTokens), label: "Mana")
            Resource(icon: "flag.checkered", tint: Theme.pink, value: "\(model.questsDone)", label: "Quests")
        }
    }

    private func formatTokens(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }

    private struct Resource: View {
        let icon: String, tint: Color, value: String, label: String
        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .shadow(color: tint, radius: 6)
                VStack(alignment: .leading, spacing: -1) {
                    Text(value).font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(label.uppercased()).font(.system(size: 8, weight: .heavy, design: .rounded)).tracking(1).foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .gamePanel(radius: 12, glow: tint)
        }
    }
}

/// RPG party frames: one per agent.
struct PartyFrames: View {
    let model: WorldModel
    var horizontal: Bool
    var onSelect: (String) -> Void

    var body: some View {
        let layout = horizontal ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 8))
        layout {
            ForEach(model.agents) { a in
                PartyFrame(agent: a, selected: model.selectedID == a.id, compact: horizontal)
                    .onTapGesture { onSelect(a.id) }
            }
        }
    }
}

private struct PartyFrame: View {
    let agent: AgentState
    let selected: Bool
    let compact: Bool
    @State private var pulse = false

    var body: some View {
        let p = agent.persona
        let calling = agent.mode == .awaitingApproval
        Group {
            if compact {
                VStack(spacing: 4) {
                    portrait(size: 46)
                    ProgressBar(value: agent.task == nil ? 0 : agent.progress, color: p.auraColor).frame(width: 46)
                }
                .padding(6)
            } else {
                HStack(spacing: 10) {
                    portrait(size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(p.name).font(Theme.title(14)).foregroundStyle(.white)
                            Text("Lv.\(agent.tasksDone + 1)").font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(p.auraColor)
                        }
                        Text(agent.task?.title ?? agent.mode.label)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .frame(width: 140, alignment: .leading)
                        ProgressBar(value: agent.task == nil ? 0 : agent.progress, color: p.auraColor).frame(width: 140)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .gamePanel(radius: 14, glow: calling ? Theme.gold : (selected ? p.auraColor : .clear))
        .overlay {
            if calling {
                RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.gold, lineWidth: 2.5)
                    .opacity(pulse ? 1 : 0.2)
                    .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever()) { pulse = true } }
            }
        }
        .scaleEffect(selected ? 1.04 : 1)
        .animation(.spring(response: 0.3), value: selected)
        .contentShape(Rectangle())
    }

    private func portrait(size: CGFloat) -> some View {
        Portraits.image(agent.persona, agent.mode == .awaitingApproval ? .surprised : (agent.mode == .celebrating ? .happy : .normal))
            .resizable()
            .frame(width: size, height: size)
            .background(Circle().fill(agent.persona.auraColor.opacity(0.35)))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(agent.persona.auraColor, lineWidth: 2))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: agent.mode.symbol)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(agent.mode == .awaitingApproval ? Theme.gold : agent.persona.auraColor))
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 1.5))
                    .offset(x: 3, y: 3)
            }
    }
}

/// Flashing call-to-action when an agent needs the player.
struct ApprovalBanner: View {
    let agent: AgentState
    var onTap: () -> Void
    @State private var glow = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Portraits.image(agent.persona, .surprised)
                    .resizable().frame(width: 34, height: 34).clipShape(Circle())
                    .overlay(Circle().strokeBorder(Theme.gold, lineWidth: 2))
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(agent.persona.name) requests your seal!")
                        .font(Theme.title(14)).foregroundStyle(.white)
                    Text(agent.task?.title ?? "")
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right.circle.fill").foregroundStyle(Theme.gold).font(.system(size: 18))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .gamePanel(radius: 16, glow: Theme.gold)
            .scaleEffect(glow ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever()) { glow = true } }
    }
}

/// Latest events, like an MMO chat log.
struct QuestTicker: View {
    let model: WorldModel
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("QUEST LOG", systemImage: "scroll.fill")
                        .font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.2)
                        .foregroundStyle(Theme.gold)
                    Spacer()
                    Image(systemName: "chevron.up").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                }
                ForEach(model.feed.prefix(3)) { e in
                    FeedRow(entry: e, model: model, compact: true)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4), value: model.feed.first?.id)
            .padding(12)
            .frame(maxWidth: 380, alignment: .leading)
            .gamePanel(radius: 16, glow: Theme.violet)
        }
        .buttonStyle(.plain)
    }
}

struct FeedRow: View {
    let entry: FeedEntry
    let model: WorldModel
    var compact = false

    var body: some View {
        let p = model.agent(entry.agentID)?.persona
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: compact ? 9 : 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 14)
                .padding(.top, 2)
            (Text(p.map { "\($0.name) " } ?? "").foregroundStyle(p?.auraColor ?? .white).bold()
             + Text(entry.text).foregroundStyle(.white.opacity(0.85)))
                .font(.system(size: compact ? 11 : 13, weight: .medium, design: .rounded))
                .lineLimit(compact ? 1 : 3)
        }
    }

    private var icon: String {
        switch entry.kind {
        case .start: "play.circle.fill"
        case .done: "checkmark.seal.fill"
        case .approval: "exclamationmark.triangle.fill"
        case .chat: "bubble.left.fill"
        case .info: "info.circle.fill"
        }
    }

    private var tint: Color {
        switch entry.kind {
        case .done: Color(hex: 0x4ADE80)
        case .approval: Theme.gold
        case .chat: Theme.pink
        case .start: Theme.cyan
        case .info: .white.opacity(0.7)
        }
    }
}

struct QuestLogSheet: View {
    let model: WorldModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Quest Log", systemImage: "scroll.fill")
                    .font(Theme.title(22)).foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.feed) { e in
                        HStack(alignment: .top, spacing: 10) {
                            Text(stamp(e.time))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                            FeedRow(entry: e, model: model)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 420)
        .background(LinearGradient(colors: [Color(hex: 0x241B4F), Color(hex: 0x120D2E)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private func stamp(_ t: Double) -> String {
        let tod = (t / model.dayLength + 0.32).truncatingRemainder(dividingBy: 1)
        let m = Int(tod * 24 * 60)
        return String(format: "%02d:%02d", m / 60, m % 60)
    }
}

/// Camera and time controls.
struct ControlDock: View {
    let model: WorldModel
    var onZoomIn: () -> Void
    var onZoomOut: () -> Void
    var onHome: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            dockButton("plus.magnifyingglass", action: onZoomIn)
            dockButton("minus.magnifyingglass", action: onZoomOut)
            dockButton("house.fill", action: onHome)
            Divider().frame(height: 20).overlay(.white.opacity(0.2))
            Button {
                model.timeScale = model.timeScale >= 4 ? 1 : model.timeScale * 2
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "forward.fill").font(.system(size: 11, weight: .bold))
                    Text("\(Int(model.timeScale))×").font(.system(size: 12, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(model.timeScale > 1 ? Theme.gold : .white)
                .frame(width: 50, height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .gamePanel(radius: 14, glow: Theme.cyan)
    }

    private func dockButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
