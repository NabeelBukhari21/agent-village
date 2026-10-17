import SwiftUI

/// Size of one art pixel in points, chosen so it maps to whole device pixels.
struct PixelScale {
    let display: CGFloat
    var phone: Bool
    /// Text and UI chrome.
    var ui: CGFloat { (display >= 3 ? 6 : 4) / display }
    /// Large titles.
    var title: CGFloat { (display >= 3 ? 9 : 6) / display }
    /// Small portraits.
    var small: CGFloat { (display >= 3 ? 4 : 3) / display }
}

private struct PixelScaleKey: EnvironmentKey {
    static let defaultValue = PixelScale(display: 2, phone: false)
}

extension EnvironmentValues {
    var pixelScale: PixelScale {
        get { self[PixelScaleKey.self] }
        set { self[PixelScaleKey.self] = newValue }
    }
}

/// Bitmap-font text rendered as a crisp image.
struct PixelText: View {
    let text: String
    var color: UInt32 = 0xFFFFFF
    var shadow: UInt32? = 0x100A1E
    var outline: UInt32? = nil
    var size: CGFloat? = nil
    @Environment(\.pixelScale) private var ps

    var body: some View {
        let canvas: PixelCanvas
        if let outline {
            canvas = PixelFont.render(text, color: PixelColor(color), outline: PixelColor(outline), shadow: nil)
        } else {
            canvas = PixelFont.render(text, color: PixelColor(color), shadow: shadow.map { PixelColor($0) })
        }
        return canvas.image(scale: size ?? ps.ui).interpolation(.none)
    }
}

/// Multi-line wrapped pixel text (for dialogue).
struct PixelParagraph: View {
    let text: String
    let maxWidth: CGFloat
    var color: UInt32 = 0xFFFFFF
    var size: CGFloat? = nil
    @Environment(\.pixelScale) private var ps

    var body: some View {
        let scale = size ?? ps.ui
        let lines = PixelFont.wrap(text, maxWidth: max(40, Int(maxWidth / scale)))
        let w = max(1, lines.map(PixelFont.measure).max() ?? 1)
        let c = PixelCanvas(w + 1, max(1, lines.count) * 11 + 2)
        for (i, l) in lines.enumerated() {
            PixelFont.draw(l, on: c, x: 0, y: i * 11, color: PixelColor(color), shadow: PixelColor(0x100A1E))
        }
        return c.image(scale: scale).interpolation(.none)
    }
}

struct PixelIcon: View {
    let name: String
    var scale: CGFloat? = nil
    @Environment(\.pixelScale) private var ps
    var body: some View {
        PixelUI.icon(name).image(scale: scale ?? ps.ui).interpolation(.none)
    }
}

/// JRPG window: dithered gradient fill with a crisp beveled border.
struct PixelWindow: ViewModifier {
    var top: UInt32 = 0x2A2D6E
    var bottom: UInt32 = 0x15173D
    var accent: UInt32 = 0xF4E9D0
    @Environment(\.pixelScale) private var ps

    func body(content: Content) -> some View {
        let frame = PixelUI.windowFrame(accent: PixelColor(accent)).cgImage()
        let inset = 4 * ps.ui
        content
            .background {
                LinearGradient(colors: [Color(hex: top, opacity: 0.94), Color(hex: bottom, opacity: 0.94)], startPoint: .top, endPoint: .bottom)
                    .padding(ps.ui)
            }
            .overlay {
                Image(decorative: frame, scale: 1 / ps.ui)
                    .resizable(capInsets: EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset), resizingMode: .stretch)
                    .interpolation(.none)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func pixelWindow(top: UInt32 = 0x2A2D6E, bottom: UInt32 = 0x15173D, accent: UInt32 = 0xF4E9D0) -> some View {
        modifier(PixelWindow(top: top, bottom: bottom, accent: accent))
    }
}

/// Chunky pixel progress bar.
struct PixelBar: View {
    let value: Double
    let color: UInt32
    var width: Int = 40
    @Environment(\.pixelScale) private var ps

    var body: some View {
        let c = PixelCanvas(width + 2, 6)
        c.rect(0, 0, width + 2, 6, PixelColor(0x100A1E))
        c.rect(1, 1, width, 4, PixelColor(0x3A3060))
        let filled = Int((Double(width) * max(0, min(1, value))).rounded())
        if filled > 0 {
            c.rect(1, 1, filled, 4, PixelColor(color))
            c.hline(1, 1, filled, PixelColor(color).lighter(0.45))
            c.hline(1, 4, filled, PixelColor(color).darker(0.3))
        }
        return c.image(scale: ps.small).interpolation(.none)
    }
}

/// Little pixel button with an icon.
struct PixelButton: View {
    let icon: String
    var label: String? = nil
    var tint: UInt32 = 0xFFFFFF
    let action: () -> Void
    @Environment(\.pixelScale) private var ps
    @State private var pressed = false

    var body: some View {
        Button {
            Chiptune.shared.play(.select)
            action()
        } label: {
            HStack(spacing: 2 * ps.ui) {
                PixelIcon(name: icon)
                if let label { PixelText(text: label, color: tint) }
            }
            .padding(.horizontal, 5 * ps.ui)
            .padding(.vertical, 4 * ps.ui)
            .pixelWindow(top: 0x34306E, bottom: 0x1E1B48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Faint CRT scanlines and vignette for a retro handheld feel.
struct RetroScreen: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.07)))
                y += 3
            }
        }
        .overlay(
            RadialGradient(colors: [.clear, .black.opacity(0.35)], center: .center, startRadius: 200, endRadius: 900)
        )
        .allowsHitTesting(false)
    }
}

/// Icon + big number + tiny label, used for the top stats.
struct StatChip: View {
    let icon: String
    let value: String
    let label: String
    var color: UInt32 = 0xFFFFFF
    var alert = false
    @Environment(\.pixelScale) private var ps
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 3 * ps.ui) {
            PixelIcon(name: icon)
            VStack(alignment: .leading, spacing: 1 * ps.small) {
                PixelText(text: value, color: color)
                if !label.isEmpty { PixelText(text: label, color: 0x9AA3D6, shadow: nil, size: ps.small) }
            }
        }
        .padding(.horizontal, 4 * ps.ui)
        .padding(.vertical, 3 * ps.ui)
        .pixelWindow(top: alert ? 0x7A2440 : 0x2A2D6E, bottom: alert ? 0x3E1028 : 0x15173D, accent: alert && pulse ? 0xFFD23F : 0xF4E9D0)
        .onAppear { if alert { withAnimation(.linear(duration: 0.45).repeatForever()) { pulse.toggle() } } }
        .onChange(of: alert) { _, a in if a { withAnimation(.linear(duration: 0.45).repeatForever()) { pulse.toggle() } } }
    }
}

/// Text-only pixel button with an optional icon; `style` sets the color scheme.
struct PixelActionButton: View {
    enum Style { case normal, good, bad, accent }
    let title: String
    var icon: String? = nil
    var style: Style = .normal
    var disabled = false
    let action: () -> Void
    @Environment(\.pixelScale) private var ps
    @State private var hover = false

    var body: some View {
        Button {
            guard !disabled else { return }
            Chiptune.shared.play(.select)
            action()
        } label: {
            HStack(spacing: 3 * ps.ui) {
                if let icon { PixelIcon(name: icon, scale: ps.small) }
                PixelText(text: title, color: disabled ? 0x6A6F96 : 0xFFFFFF)
            }
            .padding(.horizontal, 6 * ps.ui)
            .padding(.vertical, 3 * ps.ui)
            .pixelWindow(top: colors.0, bottom: colors.1, accent: hover && !disabled ? 0xFFD23F : 0xF4E9D0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }

    private var colors: (UInt32, UInt32) {
        if disabled { return (0x2A2A40, 0x1A1A2C) }
        switch style {
        case .normal: return (0x34306E, 0x1E1B48)
        case .good: return (0x2E8A55, 0x175234)
        case .bad: return (0x9A3048, 0x5A1628)
        case .accent: return (0x7A4FD0, 0x45288A)
        }
    }
}

/// Container for dashboard panels: title bar with close button, scrolling body.
struct PixelPanel<Content: View>: View {
    let title: String
    let icon: String
    var onClose: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.pixelScale) private var ps

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4 * ps.ui) {
                PixelIcon(name: icon)
                PixelText(text: title, color: 0xFFD23F, outline: 0x3A1A08)
                Spacer()
                Button(action: { Chiptune.shared.play(.select); onClose() }) {
                    PixelIcon(name: "cross").padding(4 * ps.ui).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8 * ps.ui)
            .padding(.top, 6 * ps.ui)
            .padding(.bottom, 4 * ps.ui)
            Rectangle().fill(Color(hex: 0xF4E9D0, opacity: 0.25)).frame(height: ps.ui).padding(.horizontal, 6 * ps.ui)
            ViewThatFits(in: .vertical) {
                body(content)
                ScrollView { body(content) }.scrollIndicators(.hidden)
            }
        }
        .pixelWindow()
    }

    private func body(_ c: Content) -> some View {
        c.padding(8 * ps.ui).frame(maxWidth: .infinity, alignment: .leading)
    }
}
