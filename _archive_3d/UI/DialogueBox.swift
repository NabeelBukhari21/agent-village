import SwiftUI

/// Visual-novel style dialogue with the selected agent.
struct DialogueBox: View {
    let agent: AgentState
    let model: WorldModel
    var compact: Bool
    var onClose: () -> Void

    @State private var line = ""
    @State private var lineID = UUID()

    var body: some View {
        let p = agent.persona
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(p.name)
                        .font(Theme.title(compact ? 18 : 22))
                        .foregroundStyle(.white)
                        .outlinedText(p.accentColor.opacity(0.9), width: 1)
                    Text(p.title.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(p.auraColor)
                    Spacer()
                    Label(agent.mode.label, systemImage: agent.mode.symbol)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(agent.mode.tint)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.08)))
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, portraitInset)

                if let task = agent.task {
                    HStack(spacing: 8) {
                        Image(systemName: "scroll.fill").foregroundStyle(Theme.gold)
                        Text(task.title).font(Theme.body(12)).foregroundStyle(.white.opacity(0.9)).lineLimit(1)
                        Spacer(minLength: 4)
                        ProgressBar(value: agent.progress, color: p.auraColor).frame(width: compact ? 70 : 120)
                    }
                    .padding(.leading, portraitInset)
                }

                TypewriterText(text: line, id: lineID)
                    .font(Theme.body(compact ? 15 : 17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: compact ? 44 : 52, alignment: .topLeading)

                choices
            }
            .padding(compact ? 14 : 18)
            .gamePanel(radius: 22, glow: p.auraColor)
            .padding(.top, compact ? 34 : 46)

            Portraits.image(p, portraitExpression)
                .resizable()
                .interpolation(.high)
                .frame(width: compact ? 92 : 124, height: compact ? 92 : 124)
                .background(
                    Circle()
                        .fill(RadialGradient(colors: [p.auraColor.opacity(0.8), p.auraColor.opacity(0)], center: .center, startRadius: 4, endRadius: 64))
                )
                .overlay(Circle().strokeBorder(Theme.edge, lineWidth: 3).padding(6))
                .shadow(color: p.auraColor, radius: 12)
                .offset(x: compact ? 4 : 10, y: compact ? -6 : -8)
        }
        .onAppear { say(agent.mode == .awaitingApproval ? model.statusReply(for: agent) : p.greeting) }
        .onChange(of: agent.mode) { _, m in
            if m == .awaitingApproval { say(model.statusReply(for: agent)) }
        }
    }

    private var portraitInset: CGFloat { compact ? 88 : 122 }

    private var portraitExpression: Expression {
        switch agent.mode {
        case .celebrating, .chatting: .happy
        case .awaitingApproval: .surprised
        case .paused: .blink
        case .working: .focused
        default: .normal
        }
    }

    @ViewBuilder private var choices: some View {
        let cols = [GridItem(.adaptive(minimum: compact ? 140 : 170), spacing: 8)]
        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            if agent.mode == .awaitingApproval {
                ChoiceButton(title: "Approve", icon: "checkmark.seal.fill", tint: Color(hex: 0x4ADE80), primary: true) {
                    model.approve(agent)
                    say("Yatta~! Thank you, boss! I'll take care of it right away!")
                }
                ChoiceButton(title: "Deny", icon: "xmark.octagon.fill", tint: Color(hex: 0xFF5C7A)) {
                    model.deny(agent)
                    say("Understood… I'll drop it. Maybe next time!")
                }
            }
            ChoiceButton(title: "What are you doing?", icon: "questionmark.bubble.fill", tint: Theme.cyan) {
                say(model.statusReply(for: agent))
            }
            ChoiceButton(title: agent.mode == .paused ? "Wake up!" : "Take a break", icon: agent.mode == .paused ? "sun.max.fill" : "moon.zzz.fill", tint: Theme.violet) {
                let wasPaused = agent.mode == .paused
                model.togglePause(agent)
                say(wasPaused ? "Waah! I'm up, I'm up! Back to work~" : "A break? Don't mind if I do… zzz")
            }
        }
    }

    private func say(_ text: String) {
        line = text
        lineID = UUID()
    }
}

private struct ChoiceButton: View {
    let title: String
    let icon: String
    let tint: Color
    var primary = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill").font(.system(size: 8, weight: .black)).foregroundStyle(tint).opacity(hover ? 1 : 0.6)
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(Theme.body(13)).foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(primary ? AnyShapeStyle(LinearGradient(colors: [tint.opacity(0.45), tint.opacity(0.15)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.white.opacity(hover ? 0.16 : 0.07)))
            )
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(tint.opacity(primary ? 0.9 : 0.35), lineWidth: 1.5))
            .shadow(color: primary ? tint.opacity(0.6) : .clear, radius: 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .scaleEffect(hover ? 1.03 : 1)
        .animation(.spring(response: 0.25), value: hover)
    }
}

struct ProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.4))
                Capsule()
                    .fill(LinearGradient(colors: [color, .white.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, g.size.width * value))
                    .shadow(color: color, radius: 4)
            }
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
        }
        .frame(height: 8)
    }
}

/// Reveals text one character at a time, like a JRPG.
struct TypewriterText: View {
    let text: String
    let id: UUID
    @State private var shown = 0

    var body: some View {
        (Text(text.prefix(shown)) + Text(shown < text.count ? "▍" : " ").foregroundStyle(Theme.pink))
            .task(id: id) {
                shown = 0
                while shown < text.count {
                    try? await Task.sleep(for: .milliseconds(22))
                    if Task.isCancelled { return }
                    shown += 1
                }
            }
    }
}
