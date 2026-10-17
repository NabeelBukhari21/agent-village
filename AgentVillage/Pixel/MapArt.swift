import Foundation
import simd

/// The village ground: grass, paths, plaza and water, painted pixel by pixel.
enum MapArt {
    static let tile = 16
    static let cols = 42, rows = 36
    static let originX = 21, originZ = 18 // tile at world (0, 0)
    static var pixelWidth: Int { cols * tile }
    static var pixelHeight: Int { rows * tile }

    static let plazaRadius: Double = 5.6
    static let pond = SIMD2<Double>(9.5, 7.5)
    static let pondRadii = SIMD2<Double>(3.0, 2.1)

    /// World tile coordinates → map pixel coordinates (y down).
    static func px(_ x: Double, _ z: Double) -> (Double, Double) {
        ((x + Double(originX)) * Double(tile), (z + Double(originZ)) * Double(tile))
    }

    /// Path centerlines in world tiles, with half-widths.
    static var paths: [(SIMD2<Double>, SIMD2<Double>, Double)] {
        var p: [(SIMD2<Double>, SIMD2<Double>, Double)] = []
        func seg(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ w: Double = 0.85) { p.append((a, b, w)) }
        for s in StationKind.allCases where s != .questBoard {
            let w = s.workSpot, b = s.buildingPosition
            let a = atan2(Double(w.x), Double(w.z))
            let ring = SIMD2(sin(a) * 4.8, cos(a) * 4.8)
            seg(ring, SIMD2(Double(w.x), Double(w.z)))
            seg(SIMD2(Double(w.x), Double(w.z)), SIMD2(Double(b.x), Double(b.z) + 2.2), 0.75)
        }
        seg(SIMD2(0, 4.8), SIMD2(0, 18), 1.0)            // south road through the torii
        seg(SIMD2(3.6, 5.2), SIMD2(7.0, 6.0), 0.6)        // little trail to the pond
        return p
    }

    static func waterValue(_ x: Double, _ z: Double) -> Double {
        // > 0 inside water. Pond ellipse plus a wavy stream to the east edge.
        let d = pow((x - pond.x) / pondRadii.x, 2) + pow((z - pond.y) / pondRadii.y, 2)
        var v = 1 - d
        if x > pond.x {
            let center = pond.y + 0.6 + sin(x * 0.55) * 0.7
            v = max(v, 0.7 - abs(z - center) / 0.75)
        }
        return v
    }

    static func ground() -> PixelCanvas {
        let W = pixelWidth, H = pixelHeight
        let c = PixelCanvas(W, H)
        let grass = [PixelColor(0x3F8A3A), PixelColor(0x4E9F3D), PixelColor(0x5DB447), PixelColor(0x6FC453), PixelColor(0x86D466)]
        let dirt = [PixelColor(0xB07F4A), PixelColor(0xC99A5B), PixelColor(0xD9AE6E), PixelColor(0xE8C58A)]
        let sand = PixelColor(0xE8D29A)
        let paths = Self.paths
        var rng = PixelRandom(5)

        for y in 0..<H {
            for x in 0..<W {
                let wx = Double(x) / Double(tile) - Double(originX)
                let wz = Double(y) / Double(tile) - Double(originZ)
                let th = PixelCanvas.bayer[(y % 4) * 4 + (x % 4)]

                // Grass with soft noise bands and dithered transitions
                let n = fractalNoise(Double(x) / 46, Double(y) / 46, seed: 3)
                let edgeDark = max(0, (abs(wx) - 16) / 5) + max(0, (abs(wz) - 13) / 5)
                var g = n * 3.2 + 0.6 - edgeDark * 1.2 + th * 0.9
                g = max(0, min(Double(grass.count - 1), g))
                var col = grass[Int(g)]

                // Paths
                var pathD = Double.infinity
                for (a, b, w) in paths {
                    let p = SIMD2(wx, wz), ab = b - a
                    let t = max(0, min(1, simd_dot(p - a, ab) / simd_length_squared(ab)))
                    pathD = min(pathD, simd_length(p - (a + ab * t)) - w)
                }
                let r = simd_length(SIMD2(wx, wz))
                let plazaD = r - plazaRadius

                let wobble = (valueNoise(Double(x) / 5, Double(y) / 5, seed: 9) - 0.5) * 0.25
                if plazaD + wobble < 0 {
                    col = cobble(x, y, r)
                    if r < 2.1 { col = grass[3] } // lawn under the tree
                    if abs(r - 2.1) < 0.07 { col = PixelColor(0xA89F92) }
                } else if pathD + wobble < 0 {
                    let dn = fractalNoise(Double(x) / 9, Double(y) / 9, seed: 21) * 2.6 + th * 0.8
                    col = dirt[max(0, min(3, Int(dn)))]
                    if pathD + wobble > -0.12 { col = dirt[0] }
                } else if pathD + wobble < 0.12 || (plazaD + wobble < 0.1) {
                    col = grass[0].mix(dirt[0], 0.35)
                }

                // Water banks
                let wv = waterValue(wx, wz)
                if wv > -0.18 { col = sand.mix(dirt[1], th * 0.4) }
                if wv > -0.06 { col = PixelColor(0x8C6B4A) }

                c[x, y] = col
            }
        }

        // Grass tufts, flowers and pebbles
        let flowerColors = [PixelColor(0xFFFFFF), PixelColor(0xFFD23F), PixelColor(0xFF6F91), PixelColor(0xB18CFF), PixelColor(0x7FE3FF)]
        for _ in 0..<1600 {
            let x = rng.int(2, W - 3), y = rng.int(2, H - 3)
            let base = c[x, y]
            guard grass.contains(base) else { continue }
            if rng.chance(0.78) {
                let d = base.darker(0.28)
                c[x, y] = d; c[x - 1, y - 1] = d; c[x + 1, y - 1] = d
                c[x, y - 1] = base.lighter(0.2)
            } else {
                let f = flowerColors[rng.int(0, flowerColors.count - 1)]
                c[x, y] = PixelColor(0xFFF3A0)
                c[x - 1, y] = f; c[x + 1, y] = f; c[x, y - 1] = f; c[x, y + 1] = f
                c[x, y + 2] = grass[0]
            }
        }
        for _ in 0..<500 {
            let x = rng.int(2, W - 3), y = rng.int(2, H - 3)
            guard dirt.contains(c[x, y]) else { continue }
            c[x, y] = PixelColor(0x9C7346); c[x + 1, y] = PixelColor(0xE8D2A8)
        }
        // Flower beds around the tree lawn
        for i in 0..<28 {
            let a = Double(i) / 28 * 2 * .pi
            let (fx, fy) = px(sin(a) * 1.7, cos(a) * 1.7)
            let f = flowerColors[i % flowerColors.count]
            c.ellipse(fx, fy, 2, 1.5, f.darker(0.2))
            c[Int(fx), Int(fy) - 1] = f.lighter(0.3)
        }
        return c
    }

    private static func cobble(_ x: Int, _ y: Int, _ r: Double) -> PixelColor {
        let row = y / 6
        let ox = (row % 2) * 4
        let cx = (x + ox) / 8
        var h = UInt64(bitPattern: Int64(cx &* 73856093 ^ row &* 19349663))
        h = (h ^ (h >> 13)) &* 1274126177
        let v = Double(h & 0xFF) / 255
        let stones = [PixelColor(0xC9C0B2), PixelColor(0xD6CEC0), PixelColor(0xBDB3A4), PixelColor(0xE0D8CB)]
        var s = stones[Int(v * 3.99)]
        let lx = (x + ox) % 8, ly = y % 6
        if lx == 0 || ly == 0 { return PixelColor(0x8E8577) }
        if lx == 1 && ly == 1 { s = s.lighter(0.3) }
        if lx == 7 || ly == 5 { s = s.darker(0.15) }
        // Decorative ring of darker stones
        if abs(r - 4.6) < 0.18 { s = s.mix(PixelColor(0xA58C78), 0.5) }
        return s
    }

    /// Animated water layer frames (transparent outside the water).
    static func waterFrames() -> [PixelCanvas] {
        let W = pixelWidth, H = pixelHeight
        return (0..<4).map { f in
            let c = PixelCanvas(W, H)
            let deep = PixelColor(0x2F6FB8), mid = PixelColor(0x3F8FD6), light = PixelColor(0x62B4EE), foam = PixelColor(0xC8F0FF)
            let (x0, y0) = px(pond.x - pondRadii.x - 1, pond.y - pondRadii.y - 2)
            for y in max(0, Int(y0))..<H {
                for x in max(0, Int(x0))..<W {
                    let wx = Double(x) / Double(tile) - Double(originX)
                    let wz = Double(y) / Double(tile) - Double(originZ)
                    let v = MapArt.waterValue(wx, wz)
                    guard v > 0 else { continue }
                    let th = PixelCanvas.bayer[(y % 4) * 4 + (x % 4)]
                    var col = v > 0.45 ? deep : (v > 0.18 ? mid : light)
                    if v < 0.18 + th * 0.12, v > 0.12 { col = mid }
                    if v < 0.05 { col = foam }
                    // Moving wave glints
                    let wave = sin(Double(x) * 0.35 + Double(y) * 0.9 + Double(f) * .pi / 2) + sin(Double(x) * 0.13 - Double(f) * .pi / 2)
                    if wave > 1.55, v > 0.1 { col = foam }
                    else if wave > 1.25, v > 0.1 { col = light }
                    c[x, y] = col
                }
            }
            // Lily pads
            for (lx, lz) in [(8.6, 7.0), (10.4, 8.1), (9.7, 6.6)] {
                let (x, y) = px(lx, lz)
                c.ellipse(x, y, 3.5, 2.5, PixelColor(0x4FAE57), shade: true)
                c[Int(x) + 1, Int(y) - 1] = PixelColor(0x3F8A3A)
                if lx > 10 { c[Int(x), Int(y) - 1] = PixelColor(0xFF9EC4); c[Int(x) - 1, Int(y) - 1] = PixelColor(0xFFC8E0) }
            }
            return c
        }
    }
}
