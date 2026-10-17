import SwiftUI

/// Speech bubbles, name tags and building banners pinned to 3D positions.
struct WorldOverlay: View {
    let model: WorldModel
    let projector: Projector
    var onSelect: (String) -> Void

    var body: some View {
        ZStack {
            ForEach(StationKind.allCases, id: \.self) { s in
                if let p = projector.stationPoints[s] {
                    StationBanner(station: s)
                        .scaleEffect(max(0.6, projector.agentScale * 0.85))
                        .position(p)
                        .allowsHitTesting(false)
                }
            }
            ForEach(model.agents) { a in
                if let p = projector.agentPoints[a.id] {
                    AgentTag(agent: a, selected: model.selectedID == a.id)
                        .scaleEffect(projector.agentScale, anchor: .bottom)
                        .onTapGesture { onSelect(a.id) }
                        .frame(width: 1, height: 1)
                        .position(p)
                        .zIndex(model.selectedID == a.id ? 2 : (a.bubble != nil ? 1 : 0))
                }
            }
        }
    }
}

private struct AgentTag: View {
    let agent: AgentState
    let selected: Bool

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .overlay(alignment: .bottom) {
                VStack(spacing: 6) {
                    if let b = agent.bubble {
                        SpeechBubble(bubble: b, accent: agent.persona.auraColor)
                            .id(b.id)
                            .transition(.scale(scale: 0.4, anchor: .bottom).combined(with: .opacity))
                    }
                    NameTag(agent: agent, selected: selected)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: agent.bubble?.id)
                .fixedSize()
            }
    }
}

private struct NameTag: View {
    let agent: AgentState
    let selected: Bool
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 5) {
            if agent.mode == .awaitingApproval {
                Text("!")
                    .font(Theme.title(15))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Theme.gold))
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2))
                    .offset(y: bounce ? -4 : 2)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.4).repeatForever()) { bounce = true }
                    }
            } else {
                Image(systemName: agent.mode.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(agent.mode.tint)
            }
            Text(agent.persona.name)
                .font(Theme.title(13))
                .foregroundStyle(.white)
            if agent.mode == .working {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: 34, height: 5)
                    .overlay(alignment: .leading) {
                        Capsule().fill(agent.persona.auraColor).frame(width: 34 * agent.progress, height: 5)
                    }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.ink.opacity(0.82)))
        .overlay(Capsule().strokeBorder(selected ? AnyShapeStyle(Theme.edge) : AnyShapeStyle(agent.persona.auraColor.opacity(0.9)), lineWidth: selected ? 2.5 : 1.5))
        .shadow(color: agent.persona.auraColor.opacity(selected ? 0.9 : 0.4), radius: selected ? 10 : 5)
    }
}

/// Manga-style speech balloon: speech, shout or thought.
struct SpeechBubble: View {
    let bubble: Bubble
    let accent: Color

    var body: some View {
        let shout = bubble.style == .shout
        let thought = bubble.style == .thought
        VStack(spacing: -1) {
            Text(bubble.text)
                .font(.system(size: shout ? 14 : 13, weight: shout ? .heavy : .bold, design: .rounded))
                .italic(thought)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 190)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: thought ? 22 : 14, style: .continuous)
                        .fill(shout ? AnyShapeStyle(LinearGradient(colors: [.white, Color(hex: 0xFFF3B0)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: thought ? 22 : 14, style: .continuous)
                        .strokeBorder(Theme.ink, style: StrokeStyle(lineWidth: shout ? 3 : 2.2, dash: thought ? [5, 3] : []))
                }
                .overlay(alignment: .topTrailing) {
                    if shout {
                        Image(systemName: "sparkle")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(accent)
                            .offset(x: 8, y: -8)
                    }
                }
            if thought {
                HStack(spacing: 0) {
                    Circle().fill(.white).overlay(Circle().strokeBorder(Theme.ink, lineWidth: 1.8)).frame(width: 9, height: 9)
                }
                .padding(.top, 4)
            } else {
                BubbleTail()
                    .fill(.white)
                    .overlay(BubbleTail().stroke(Theme.ink, lineWidth: 2.2))
                    .frame(width: 16, height: 10)
                    .offset(y: -1)
            }
        }
        .shadow(color: accent.opacity(0.5), radius: 8)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
    }
}

private struct BubbleTail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + 2, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}

private struct StationBanner: View {
    let station: StationKind

    var icon: String {
        switch station {
        case .postOffice: "envelope.fill"
        case .forge: "hammer.fill"
        case .library: "books.vertical.fill"
        case .observatory: "sparkles"
        case .questBoard: "scroll.fill"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(station.title.uppercased()).font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.ink.opacity(0.55)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
        .fixedSize()
    }
}
