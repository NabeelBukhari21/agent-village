import CoreGraphics
import SpriteKit
import SwiftUI

/// RGBA color packed as 0xRRGGBB plus alpha, the currency of all pixel art here.
struct PixelColor: Equatable, Hashable {
    var r: UInt8, g: UInt8, b: UInt8, a: UInt8

    init(_ hex: UInt32, _ alpha: UInt8 = 255) {
        r = UInt8((hex >> 16) & 0xFF); g = UInt8((hex >> 8) & 0xFF); b = UInt8(hex & 0xFF); a = alpha
    }
    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) { self.r = r; self.g = g; self.b = b; self.a = a }

    static let clear = PixelColor(r: 0, g: 0, b: 0, a: 0)
    var isClear: Bool { a == 0 }
    var hex: UInt32 { UInt32(r) << 16 | UInt32(g) << 8 | UInt32(b) }

    func mix(_ o: PixelColor, _ t: Double) -> PixelColor {
        func m(_ x: UInt8, _ y: UInt8) -> UInt8 { UInt8(max(0, min(255, Double(x) + (Double(y) - Double(x)) * t))) }
        return PixelColor(r: m(r, o.r), g: m(g, o.g), b: m(b, o.b), a: a)
    }
    func darker(_ t: Double = 0.25) -> PixelColor {
        // Hue-shift shadows toward purple for a painterly pixel-art look.
        mix(PixelColor(0x2A1440), t)
    }
    func lighter(_ t: Double = 0.25) -> PixelColor { mix(PixelColor(0xFFF6D8), t) }
    func alpha(_ a: UInt8) -> PixelColor { var c = self; c.a = a; return c }
}

/// A small mutable bitmap with drawing helpers tuned for pixel art.
final class PixelCanvas {
    let width: Int, height: Int
    private(set) var pixels: [PixelColor]

    init(_ w: Int, _ h: Int, fill: PixelColor = .clear) {
        width = w; height = h
        pixels = Array(repeating: fill, count: w * h)
    }

    subscript(x: Int, y: Int) -> PixelColor {
        get { (x >= 0 && y >= 0 && x < width && y < height) ? pixels[y * width + x] : .clear }
        set { if x >= 0 && y >= 0 && x < width && y < height { pixels[y * width + x] = newValue } }
    }

    func set(_ x: Int, _ y: Int, _ c: PixelColor) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        if c.a == 255 || pixels[y * width + x].a == 0 { pixels[y * width + x] = c; return }
        let base = pixels[y * width + x]
        pixels[y * width + x] = base.mix(c, Double(c.a) / 255).alpha(max(base.a, c.a))
    }

    func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: PixelColor) {
        guard w > 0, h > 0 else { return }
        for j in y..<(y + h) { for i in x..<(x + w) { set(i, j, c) } }
    }

    func clear(_ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        guard w > 0, h > 0 else { return }
        for j in y..<(y + h) { for i in x..<(x + w) { self[i, j] = .clear } }
    }

    func hline(_ x: Int, _ y: Int, _ w: Int, _ c: PixelColor) { rect(x, y, w, 1, c) }
    func vline(_ x: Int, _ y: Int, _ h: Int, _ c: PixelColor) { rect(x, y, 1, h, c) }

    func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ c: PixelColor) {
        var x0 = x0, y0 = y0
        let dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1
        let dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        while true {
            set(x0, y0, c)
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
        }
    }

    /// Filled ellipse with optional top-left highlight and bottom-right shadow bands.
    func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ c: PixelColor, shade: Bool = false) {
        guard rx > 0, ry > 0 else { return }
        let x0 = Int(floor(cx - rx)), x1 = Int(ceil(cx + rx)), y0 = Int(floor(cy - ry)), y1 = Int(ceil(cy + ry))
        for y in y0...y1 {
            for x in x0...x1 {
                let dx = (Double(x) + 0.5 - cx) / rx, dy = (Double(y) + 0.5 - cy) / ry
                let d = dx * dx + dy * dy
                guard d <= 1 else { continue }
                var col = c
                if shade {
                    let light = -dx * 0.55 - dy * 0.75
                    if light > 0.55 { col = c.lighter(0.28) }
                    else if light < -0.45 { col = c.darker(0.32) }
                    else if light < -0.1, (x + y) % 2 == 0 { col = c.darker(0.16) }
                }
                set(x, y, col)
            }
        }
    }

    /// Vertical gradient with ordered (Bayer) dithering between bands.
    func gradient(_ x: Int, _ y: Int, _ w: Int, _ h: Int, top: PixelColor, bottom: PixelColor, steps: Int = 4) {
        for j in 0..<h {
            let t = Double(j) / Double(max(1, h - 1)) * Double(steps)
            let band = floor(t), frac = t - band
            for i in 0..<w {
                let th = Self.bayer[(j % 4) * 4 + (i % 4)]
                let level = min(Double(steps), band + (frac > th ? 1 : 0))
                set(x + i, y + j, top.mix(bottom, level / Double(steps)))
            }
        }
    }

    static let bayer: [Double] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map { ($0 + 0.5) / 16 }

    /// Adds a 1px outline around all opaque pixels (selective outline: darker version of neighbor).
    func outline(_ color: PixelColor? = nil, diagonal: Bool = false) {
        let src = pixels
        func at(_ x: Int, _ y: Int) -> PixelColor {
            (x >= 0 && y >= 0 && x < width && y < height) ? src[y * width + x] : .clear
        }
        for y in 0..<height {
            for x in 0..<width where at(x, y).isClear {
                var n: PixelColor?
                for (dx, dy) in [(0, -1), (0, 1), (-1, 0), (1, 0)] + (diagonal ? [(1, 1), (-1, -1), (1, -1), (-1, 1)] : []) {
                    let p = at(x + dx, y + dy)
                    if p.a > 128 { n = p; break }
                }
                if let n { pixels[y * width + x] = color ?? n.mix(PixelColor(0x1A0F24), 0.78) }
            }
        }
    }

    /// Draws a palette-keyed sprite. Unknown keys and "." are skipped.
    func draw(_ rows: [String], at ox: Int = 0, _ oy: Int = 0, palette: [Character: PixelColor], flipX: Bool = false) {
        for (j, row) in rows.enumerated() {
            let chars = Array(row)
            for (i, ch) in chars.enumerated() {
                guard ch != ".", let c = palette[ch] else { continue }
                let x = flipX ? ox + chars.count - 1 - i : ox + i
                set(x, oy + j, c)
            }
        }
    }

    func blit(_ other: PixelCanvas, _ ox: Int, _ oy: Int, flipX: Bool = false) {
        for y in 0..<other.height {
            for x in 0..<other.width {
                let c = other[x, y]
                guard !c.isClear else { continue }
                set(flipX ? ox + other.width - 1 - x : ox + x, oy + y, c)
            }
        }
    }

    func flippedX() -> PixelCanvas {
        let c = PixelCanvas(width, height)
        c.blit(self, 0, 0, flipX: true)
        return c
    }

    // MARK: Output

    func cgImage() -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for (i, p) in pixels.enumerated() {
            let a = Double(p.a) / 255
            bytes[i * 4] = UInt8(Double(p.r) * a)
            bytes[i * 4 + 1] = UInt8(Double(p.g) * a)
            bytes[i * 4 + 2] = UInt8(Double(p.b) * a)
            bytes[i * 4 + 3] = p.a
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }

    func texture() -> SKTexture {
        let t = SKTexture(cgImage: cgImage())
        t.filteringMode = .nearest
        return t
    }

    /// SwiftUI image where each art pixel is `scale` points.
    func image(scale: CGFloat) -> Image {
        Image(decorative: cgImage(), scale: 1 / scale)
    }
}

/// Small deterministic RNG for repeatable art.
struct PixelRandom {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
    mutating func int(_ lo: Int, _ hi: Int) -> Int { lo + Int(next() * Double(hi - lo + 1)) }
    mutating func chance(_ p: Double) -> Bool { next() < p }
}

/// Cheap value noise for organic terrain variation.
func valueNoise(_ x: Double, _ y: Double, seed: Int = 0) -> Double {
    func h(_ i: Int, _ j: Int) -> Double {
        var n = UInt64(bitPattern: Int64(i &* 374761393 &+ j &* 668265263 &+ seed &* 1442695041))
        n = (n ^ (n >> 13)) &* 1274126177
        return Double((n ^ (n >> 16)) & 0xFFFF) / 65535
    }
    let xi = Int(floor(x)), yi = Int(floor(y))
    let xf = x - floor(x), yf = y - floor(y)
    let u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf)
    let a = h(xi, yi), b = h(xi + 1, yi), c = h(xi, yi + 1), d = h(xi + 1, yi + 1)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
}

func fractalNoise(_ x: Double, _ y: Double, seed: Int = 0) -> Double {
    valueNoise(x, y, seed: seed) * 0.6 + valueNoise(x * 2.1, y * 2.1, seed: seed + 7) * 0.3 + valueNoise(x * 4.3, y * 4.3, seed: seed + 13) * 0.1
}
