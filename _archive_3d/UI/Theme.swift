import SwiftUI

enum Theme {
    static let ink = Color(hex: 0x1A1030)
    static let panel = Color(hex: 0x1B1640, opacity: 0.78)
    static let pink = Color(hex: 0xFF6FA5)
    static let cyan = Color(hex: 0x5CF2FF)
    static let gold = Color(hex: 0xFFD23F)
    static let violet = Color(hex: 0xA78BFA)

    static let edge = LinearGradient(colors: [pink, violet, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
}

/// Glassy anime game panel with a glowing gradient edge.
struct GamePanel: ViewModifier {
    var radius: CGFloat = 18
    var glow: Color = Theme.pink

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.panel))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top, endPoint: .center))
                    )
            }
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.edge, lineWidth: 2))
            .overlay(
                RoundedRectangle(cornerRadius: radius - 3, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    .padding(3)
            )
            .shadow(color: glow.opacity(0.45), radius: 14)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
    }
}

extension View {
    func gamePanel(radius: CGFloat = 18, glow: Color = Theme.pink) -> some View {
        modifier(GamePanel(radius: radius, glow: glow))
    }

    /// Bold outlined game text.
    func outlinedText(_ color: Color = Theme.ink, width: CGFloat = 1.5) -> some View {
        self
            .shadow(color: color, radius: 0, x: width, y: 0)
            .shadow(color: color, radius: 0, x: -width, y: 0)
            .shadow(color: color, radius: 0, x: 0, y: width)
            .shadow(color: color, radius: 0, x: 0, y: -width)
    }
}

/// Cached portrait images drawn by `FaceArt`.
@MainActor
enum Portraits {
    private static var cache: [String: Image] = [:]

    static func image(_ p: Persona, _ e: Expression = .normal) -> Image {
        let key = "\(p.id)-\(e)"
        if let i = cache[key] { return i }
        let i = Image(decorative: FaceArt.portrait(p, e), scale: 2)
        cache[key] = i
        return i
    }
}

extension Persona {
    var auraColor: Color { Color(hex: aura) }
    var accentColor: Color { Color(hex: outfitAccent) }
}

extension AgentMode {
    var symbol: String {
        switch self {
        case .resting: "cup.and.saucer.fill"
        case .walking: "figure.walk"
        case .working: "sparkles"
        case .awaitingApproval: "exclamationmark.bubble.fill"
        case .chatting: "bubble.left.and.bubble.right.fill"
        case .celebrating: "star.fill"
        case .paused: "moon.zzz.fill"
        }
    }

    var tint: Color {
        switch self {
        case .awaitingApproval: Theme.gold
        case .working: Theme.cyan
        case .celebrating: Theme.pink
        case .paused: Theme.violet
        default: .white.opacity(0.8)
        }
    }
}
