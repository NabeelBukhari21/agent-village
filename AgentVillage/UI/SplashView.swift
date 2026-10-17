import SpriteKit
import SwiftUI

/// Shows the loading screen first, builds the game behind it, then dissolves into the village.
struct RootView: View {
    @State private var showGame = false
    @State private var splashDone = false

    var body: some View {
        ZStack {
            Color(hex: 0x07061A).ignoresSafeArea()
            if showGame { GameView() }
            if !splashDone {
                SplashView(ready: showGame) { splashDone = true }
            }
        }
        .onOpenURL { DeepLink.shared.receive($0) }
        .task {
            // Generate the heavy map art in the background while the splash animates,
            // then build the scene (which is quick once the art is cached).
            await Task.detached(priority: .userInitiated) { ArtCache.warm() }.value
            try? await Task.sleep(for: .milliseconds(100))
            showGame = true
        }
    }
}

/// Animated pixel-art title / loading screen.
struct SplashView: View {
    var ready: Bool
    var onFinish: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var start = Date()
    @State private var finishing: Date?

    private static let minimum: Double = 3.0
    private static let dissolve: Double = 0.9
    private static let tips = [
        "WAKING UP THE AGENTS...", "PLANTING SAKURA TREES...", "TUNING THE LO-FI RADIO...",
        "SHARPENING REN'S HAMMER...", "SORTING HANA'S MAIL...", "DUSTING YUKI'S BOOKS...",
        "ALIGNING KAITO'S TELESCOPE...", "POLISHING THE QUEST BOARD...", "LIGHTING THE LANTERNS...",
    ]

    var body: some View {
        let ps = PixelScale(display: displayScale, phone: true)
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start)
            let progress = ready ? min(1, t / Self.minimum) : min(0.88, t / Self.minimum)
            let out = finishing.map { min(1, tl.date.timeIntervalSince($0) / Self.dissolve) } ?? 0

            GeometryReader { geo in
                ZStack {
                    LinearGradient(colors: [Color(hex: 0x07061A), Color(hex: 0x1A1040), Color(hex: 0x3A1F6A)],
                                   startPoint: .top, endPoint: .bottom)
                    SkyLayer(t: t)
                    VStack(spacing: 18) {
                        Spacer()
                        title(t: t)
                        Spacer().frame(height: 6)
                        runners(t: t, width: geo.size.width)
                        loadingBar(progress: progress, t: t, ps: ps)
                        Spacer()
                        Text("POWERED BY CLAUDE CODE")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(Color(hex: 0x6A6F96))
                            .padding(.bottom, 30)
                    }
                    .frame(maxWidth: .infinity)
                }
                .mask(DissolveMask(progress: out))
            }
            .ignoresSafeArea()
            .onChange(of: progress >= 1) { _, done in
                guard done, finishing == nil else { return }
                finishing = Date()
                Chiptune.shared.play(.approved)
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.dissolve + 0.05) { onFinish() }
            }
        }
        .onAppear { start = Date() }
        .allowsHitTesting(finishing == nil)
    }

    // MARK: Pieces

    private func title(t: Double) -> some View {
        VStack(spacing: 6) {
            SplashArt.title("AGENT", hue: 0)
                .offset(y: sin(t * 2.2) * 4)
            SplashArt.title("VILLAGE", hue: 1)
                .offset(y: sin(t * 2.2 + 0.6) * 4)
        }
        .scaleEffect(t < 0.6 ? 0.6 + 0.4 * easeOutBack(t / 0.6) : 1)
        .opacity(min(1, t * 3))
    }

    private func runners(t: Double, width: CGFloat) -> some View {
        let step = Int(t * 9) % 4
        let frame = [1, 0, 2, 0][step]
        return ZStack(alignment: .bottom) {
            SplashArt.ground(offset: t * 60, width: width)
            HStack(spacing: 14) {
                ForEach(Array(Persona.roster.enumerated()), id: \.offset) { i, p in
                    SplashArt.walker(p, step: (frame + i) % 3)
                        .offset(y: -abs(sin(t * 9 + Double(i))) * 3 - 14)
                }
            }
        }
        .frame(height: 130)
    }

    private func loadingBar(progress: Double, t: Double, ps: PixelScale) -> some View {
        let tip = Self.tips[Int(t / 0.75) % Self.tips.count]
        return VStack(spacing: 10) {
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(hex: 0x0C0818)).frame(width: 248, height: 18)
                Rectangle().fill(Color(hex: 0x2A2D6E)).frame(width: 244, height: 14).padding(.leading, 2)
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { i in
                        Rectangle()
                            .fill(Double(i) / 20 < progress
                                  ? Color(hex: [0xFF6FA5, 0xFF8FB8, 0xFFD23F, 0x7DFFA8][(i + Int(t * 8)) % 4])
                                  : .clear)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.leading, 4)
            }
            .overlay(Rectangle().strokeBorder(Color(hex: 0xF4E9D0), lineWidth: 2))
            HStack(spacing: 8) {
                PixelText(text: progress >= 1 ? "READY!" : tip, color: progress >= 1 ? 0x7DFFA8 : 0xC9D2FF, size: ps.ui)
                PixelText(text: "\(Int(progress * 100))%", color: 0xFFD23F, size: ps.ui)
            }
            .environment(\.pixelScale, ps)
        }
    }

    private func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}

/// Stars, a moon and drifting petals.
private struct SkyLayer: View {
    let t: Double

    var body: some View {
        Canvas { ctx, size in
            var rng = PixelRandom(9)
            for i in 0..<70 {
                let x = rng.next() * size.width, y = rng.next() * size.height * 0.75
                let tw = 0.5 + 0.5 * sin(t * (1.5 + rng.next() * 3) + Double(i))
                let s: CGFloat = i % 9 == 0 ? 3 : 2
                ctx.fill(Path(CGRect(x: x, y: y, width: s, height: s)), with: .color(.white.opacity(0.25 + 0.75 * tw)))
            }
            // Pixel crescent moon
            let m = CGPoint(x: size.width * 0.8, y: size.height * 0.12)
            ctx.fill(Path(ellipseIn: CGRect(x: m.x - 22, y: m.y - 22, width: 44, height: 44)), with: .color(Color(hex: 0xFFE9A8)))
            ctx.fill(Path(ellipseIn: CGRect(x: m.x - 12, y: m.y - 28, width: 44, height: 44)), with: .color(Color(hex: 0x0E0B28)))
            // Falling sakura petals
            for i in 0..<26 {
                let speed = 30 + Double(i % 5) * 9
                let x = (Double(i) * 53).truncatingRemainder(dividingBy: size.width) + sin(t * 1.3 + Double(i)) * 18
                let y = (Double(i) * 97 + t * speed).truncatingRemainder(dividingBy: size.height + 20) - 10
                ctx.fill(Path(CGRect(x: x, y: y, width: 4, height: 3)), with: .color(Color(hex: i % 3 == 0 ? 0xFFFFFF : 0xFFB7D5, opacity: 0.85)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Pixel dissolve: blocks vanish in random order as progress goes 0 → 1.
private struct DissolveMask: View {
    let progress: Double

    var body: some View {
        Canvas { ctx, size in
            let cell: CGFloat = 22
            let cols = Int(size.width / cell) + 1, rows = Int(size.height / cell) + 1
            for r in 0..<rows {
                for c in 0..<cols {
                    var h = UInt64(r * 73856093 ^ c * 19349663)
                    h = (h ^ (h >> 13)) &* 1274126177
                    let threshold = Double(h & 0xFFFF) / 65535 * 0.7 + Double(r) / Double(rows) * 0.3
                    if threshold >= progress {
                        ctx.fill(Path(CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell + 0.5, height: cell + 0.5)), with: .color(.black))
                    }
                }
            }
        }
    }
}

/// Pixel art used only by the splash screen.
@MainActor
enum SplashArt {
    private static var cache: [String: Image] = [:]

    /// Big arcade-style word with a 3D extrusion.
    static func title(_ word: String, hue: Int) -> Image {
        let key = "title-\(word)"
        if let i = cache[key] { return i }
        let text = PixelCanvas(PixelFont.measure(word) + 4, 12)
        PixelFont.draw(word, on: text, x: 2, y: 2, color: PixelColor(0xFFFFFF))
        let ramp: [UInt32] = hue == 0 ? [0xFFF3A0, 0xFFD23F, 0xFF9E2C] : [0xFFD6E8, 0xFF8FB8, 0xE8366E]
        for y in 0..<text.height { for x in 0..<text.width where !text[x, y].isClear {
            text[x, y] = PixelColor(y < 5 ? ramp[0] : (y < 7 ? ramp[1] : ramp[2]))
        }}
        text.outline(PixelColor(0x1A0A2E), diagonal: true)
        let k = 3
        let out = PixelCanvas(text.width * k, text.height * k + 9)
        let extrude: [(Int, UInt32)] = hue == 0
            ? [(9, 0x5A1440), (6, 0xB0306E), (3, 0xFF4FA3)]
            : [(9, 0x1A2A6A), (6, 0x3A5ACF), (3, 0x7FB4FF)]
        for (dy, col) in extrude {
            for y in 0..<text.height { for x in 0..<text.width where !text[x, y].isClear {
                out.rect(x * k, y * k + dy, k, k, PixelColor(col))
            }}
        }
        for y in 0..<text.height { for x in 0..<text.width where !text[x, y].isClear {
            out.rect(x * k, y * k, k, k, text[x, y])
        }}
        let img = out.image(scale: 2).interpolation(.none)
        cache[key] = img
        return img
    }

    static func walker(_ p: Persona, step: Int) -> Image {
        let key = "walk-\(p.id)-\(step)"
        if let i = cache[key] { return i }
        let tex = CharacterSprites.frame(p, facing: .side, step: step, expression: .happy)
        let img = Image(decorative: tex.cgImage(), scale: 1 / 4).interpolation(.none)
        cache[key] = img
        return img
    }

    /// A strip of grass and a scrolling dirt path for the runners.
    static func ground(offset: Double, width: CGFloat) -> some View {
        Canvas { ctx, size in
            let y = size.height - 34
            ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 34)), with: .color(Color(hex: 0x3E8A3A)))
            ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 6)), with: .color(Color(hex: 0x6FC453)))
            ctx.fill(Path(CGRect(x: 0, y: y + 12, width: size.width, height: 14)), with: .color(Color(hex: 0xC99A5B)))
            let shift = offset.truncatingRemainder(dividingBy: 24)
            var x = -shift
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: y + 17, width: 6, height: 3)), with: .color(Color(hex: 0xE8C58A)))
                ctx.fill(Path(CGRect(x: x + 12, y: y + 3, width: 3, height: 3)), with: .color(Color(hex: 0x86D466)))
                x += 24
            }
        }
        .frame(width: width, height: 130)
    }
}
