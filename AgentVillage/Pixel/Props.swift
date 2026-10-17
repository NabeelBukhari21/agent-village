import Foundation

/// Pixel-art buildings and scenery, generated procedurally.
enum Props {
    // MARK: Building kit

    struct Style {
        var wall: PixelColor
        var trim: PixelColor
        var roof: PixelColor
        var stone = false
        var timber = false
    }

    /// A 3/4-view building: shingled roof on top, front wall below. Returns canvas and door x.
    static func building(widthTiles: Int, wallH: Int, roofH: Int, style s: Style, rng: inout PixelRandom) -> PixelCanvas {
        let W = widthTiles * 16 + 8
        let H = roofH + wallH + 6
        let c = PixelCanvas(W, H)
        let wx0 = 6, wx1 = W - 7
        let wallTop = roofH - 4, wallBottom = H - 3

        // Front wall
        for y in wallTop..<wallBottom {
            for x in wx0...wx1 {
                var col = s.wall
                if s.stone {
                    let row = (y - wallTop) / 5, off = (row % 2) * 4
                    let lx = (x + off) % 9, ly = (y - wallTop) % 5
                    if lx == 0 || ly == 0 { col = s.wall.darker(0.35) }
                    else if lx == 1 && ly == 1 { col = s.wall.lighter(0.2) }
                    else if (x * 7 + y * 3) % 11 == 0 { col = s.wall.darker(0.12) }
                } else {
                    if (x - wx0) % 5 == 0 { col = s.wall.darker(0.12) }
                    if (y + x / 5 * 3) % 13 == 0 && (x - wx0) % 5 != 0 { col = s.wall.darker(0.08) }
                }
                if x == wx0 { col = col.lighter(0.15) }
                if x >= wx1 - 1 { col = col.darker(0.2) }
                c.set(x, y, col)
            }
        }
        if s.timber {
            for x in stride(from: wx0, through: wx1, by: (wx1 - wx0) / 4) { c.vline(x, wallTop, wallBottom - wallTop, s.trim) }
            c.hline(wx0, wallTop + (wallBottom - wallTop) / 2, wx1 - wx0 + 1, s.trim)
        }
        // Foundation
        for x in (wx0 - 1)...(wx1 + 1) {
            for y in (wallBottom - 3)..<(wallBottom + 1) {
                c.set(x, y, ((x / 4 + y) % 2 == 0) ? PixelColor(0x8E8577) : PixelColor(0xA39A8C))
            }
        }
        // Shadow under the eaves
        c.rect(wx0, wallTop, wx1 - wx0 + 1, 3, s.wall.darker(0.45).alpha(200))

        // Roof: trapezoid with shingles, ridge highlight and upturned corners
        for y in 0..<roofH {
            let t = Double(y) / Double(roofH)
            let inset = Int((1 - t) * 10)
            let x0 = inset, x1 = W - 1 - inset
            for x in x0...x1 {
                let row = y / 4, off = (row % 2) * 3
                var col = s.roof
                if t < 0.2 { col = s.roof.lighter(0.18) }
                if (x + off) % 6 == 0 { col = s.roof.darker(0.25) }
                if y % 4 == 3 { col = s.roof.darker(0.32) }
                if y % 4 == 0 && (x + off) % 6 == 1 { col = col.lighter(0.25) }
                if x <= x0 + 1 { col = col.lighter(0.12) }
                if x >= x1 - 1 { col = col.darker(0.18) }
                c.set(x, y, col)
            }
        }
        c.hline(10, 0, W - 20, s.roof.lighter(0.4))
        c.hline(0, roofH - 1, W, s.roof.darker(0.5))
        c.hline(0, roofH, W, s.roof.darker(0.65).alpha(160))
        for (cx, dir) in [(0, 1), (W - 1, -1)] {
            c.set(cx, roofH - 2, s.roof.darker(0.3)); c.set(cx, roofH - 3, s.roof.darker(0.3))
            c.set(cx + dir, roofH - 4, s.roof.lighter(0.1))
        }
        return c
    }

    static func door(_ c: PixelCanvas, x: Int, bottom: Int, color: PixelColor, open: PixelColor? = nil) {
        let w = 12, h = 17
        let y = bottom - h
        c.rect(x - 1, y - 1, w + 2, h + 1, PixelColor(0x4A3226))
        if let open {
            c.rect(x, y, w, h, open)
            c.gradient(x, y, w, h, top: open.darker(0.5), bottom: open, steps: 3)
        } else {
            c.rect(x, y, w, h, color)
            for i in stride(from: 3, to: w, by: 4) { c.vline(x + i, y, h, color.darker(0.25)) }
            c.hline(x, y + 1, w, color.lighter(0.2))
            c.set(x + w - 3, y + h / 2 + 1, PixelColor(0xF5D76E))
            c.set(x + w - 3, y + h / 2, PixelColor(0xFFF3A0))
        }
        // Stone step
        c.rect(x - 2, bottom, w + 4, 2, PixelColor(0xB8B0A2))
        c.hline(x - 2, bottom, w + 4, PixelColor(0xD6CEC0))
    }

    static func window(_ c: PixelCanvas, x: Int, y: Int, w: Int = 10, h: Int = 11, lit: PixelColor = PixelColor(0x9ED6FF), flowers: PixelColor? = nil) {
        c.rect(x - 1, y - 1, w + 2, h + 2, PixelColor(0x5A3E2E))
        c.gradient(x, y, w, h, top: lit.lighter(0.35), bottom: lit, steps: 2)
        c.vline(x + w / 2, y, h, PixelColor(0x5A3E2E))
        c.hline(x, y + h / 2, w, PixelColor(0x5A3E2E))
        c.set(x + 1, y + 1, PixelColor(0xFFFFFF)); c.set(x + 2, y + 1, PixelColor(0xFFFFFF)); c.set(x + 1, y + 2, PixelColor(0xFFFFFF))
        if let flowers {
            c.rect(x - 2, y + h + 1, w + 4, 3, PixelColor(0x8B5A3C))
            for i in stride(from: x - 1, to: x + w + 2, by: 2) {
                c.set(i, y + h, i % 4 == 1 ? flowers : PixelColor(0x5DB447))
                c.set(i + 1, y + h, PixelColor(0x4E9F3D))
            }
        }
    }

    static func sign(_ c: PixelCanvas, cx: Int, y: Int, bg: PixelColor, icon: [String], iconColor: PixelColor) {
        let w = 18, h = 12
        c.rect(cx - w / 2 - 1, y - 1, w + 2, h + 2, PixelColor(0x3A2430))
        c.rect(cx - w / 2, y, w, h, bg)
        c.hline(cx - w / 2, y, w, bg.lighter(0.3))
        c.hline(cx - w / 2, y + h - 1, w, bg.darker(0.3))
        c.draw(icon, at: cx - icon[0].count / 2, y + 2, palette: ["#": iconColor, "o": iconColor.darker(0.3)])
    }

    // MARK: Buildings

    static func postOffice() -> PixelCanvas {
        var rng = PixelRandom(1)
        let c = building(widthTiles: 5, wallH: 38, roofH: 34, style: Style(wall: PixelColor(0xFFF0DC), trim: PixelColor(0xC2415F), roof: PixelColor(0xE8577A)), rng: &rng)
        let bottom = c.height - 3
        door(c, x: c.width / 2 - 6, bottom: bottom, color: PixelColor(0xC2415F))
        window(c, x: 12, y: bottom - 26, flowers: PixelColor(0xFF6F91))
        window(c, x: c.width - 22, y: bottom - 26, flowers: PixelColor(0xFFD23F))
        sign(c, cx: c.width / 2, y: 30, bg: PixelColor(0xE8366E), icon: ["#########", "##.....##", "#.#...#.#", "#..#.#..#", "#...#...#", "#########"], iconColor: PixelColor(0xFFFFFF))
        c.outline()
        return c
    }

    static func forge() -> PixelCanvas {
        var rng = PixelRandom(2)
        let base = building(widthTiles: 5, wallH: 36, roofH: 30, style: Style(wall: PixelColor(0x9AA0AC), trim: PixelColor(0x4A3A33), roof: PixelColor(0x4A5568), stone: true), rng: &rng)
        // Chimney poking above the roof
        let c = PixelCanvas(base.width, base.height + 14)
        c.blit(base, 0, 14)
        for y in 0..<30 {
            for x in 58..<70 {
                let lx = (x + (y / 4 % 2) * 3) % 6, ly = y % 4
                c.set(x, y, (lx == 0 || ly == 0) ? PixelColor(0x6E4A3A) : (x == 58 ? PixelColor(0xB97A5E) : PixelColor(0x9C5F48)))
            }
        }
        c.rect(56, 0, 16, 3, PixelColor(0x5A4038))
        let bottom = c.height - 3
        door(c, x: 14, bottom: bottom, color: PixelColor(0x3F3A36), open: PixelColor(0xFF8A3D))
        window(c, x: c.width - 26, y: bottom - 25, lit: PixelColor(0xFFB25E))
        sign(c, cx: c.width / 2 + 4, y: 44, bg: PixelColor(0x3B3F4A), icon: ["#######", "#######", "..###..", "...#...", "...#...", "...#..."], iconColor: PixelColor(0xD6DCE6))
        c.outline()
        return c
    }

    static func library() -> PixelCanvas {
        var rng = PixelRandom(3)
        let c = building(widthTiles: 7, wallH: 46, roofH: 40, style: Style(wall: PixelColor(0xEFE0CC), trim: PixelColor(0x7A4E3A), roof: PixelColor(0x7E68D8), timber: true), rng: &rng)
        let bottom = c.height - 3
        // Columns
        for x in [c.width / 2 - 20, c.width / 2 + 16] {
            c.rect(x, bottom - 40, 5, 40, PixelColor(0xFFFFFF))
            c.vline(x + 3, bottom - 40, 40, PixelColor(0xD8D0E6))
            c.vline(x + 4, bottom - 40, 40, PixelColor(0xB9AFCF))
            c.rect(x - 1, bottom - 42, 7, 3, PixelColor(0xE6E0F0))
        }
        door(c, x: c.width / 2 - 6, bottom: bottom, color: PixelColor(0x4B3A8C))
        window(c, x: 12, y: bottom - 32, w: 10, h: 14, lit: PixelColor(0xB8A6FF))
        window(c, x: c.width - 22, y: bottom - 32, w: 10, h: 14, lit: PixelColor(0xB8A6FF))
        // Round rose window
        c.ellipse(Double(c.width) / 2, 30, 7, 7, PixelColor(0x5A3E2E))
        c.ellipse(Double(c.width) / 2, 30, 5.5, 5.5, PixelColor(0xF5D76E), shade: true)
        c.line(c.width / 2 - 5, 30, c.width / 2 + 5, 30, PixelColor(0x5A3E2E))
        c.line(c.width / 2, 25, c.width / 2, 35, PixelColor(0x5A3E2E))
        c.outline()
        return c
    }

    static func observatory() -> PixelCanvas {
        let W = 72, H = 112
        let c = PixelCanvas(W, H)
        let wall = PixelColor(0xE3EAF7)
        let towerTop = 40, bottom = H - 3
        // Dome (drawn first, lower half cleared before the tower goes on)
        c.ellipse(Double(W) / 2, Double(towerTop), 27, 30, PixelColor(0x5B6C9C), shade: true)
        c.clear(0, towerTop + 1, W, 32)
        // Tower body with cylindrical shading
        for y in towerTop..<bottom {
            for x in 10..<(W - 10) {
                let t = Double(x - 10) / Double(W - 21)
                var col = wall
                if t < 0.15 { col = wall.lighter(0.3) } else if t > 0.8 { col = wall.darker(0.3) } else if t > 0.62 { col = wall.darker(0.14) }
                if (y - towerTop) % 10 == 0 { col = col.darker(0.15) }
                c.set(x, y, col)
            }
        }
        c.rect(8, towerTop - 2, W - 16, 5, PixelColor(0x3B4A7A))
        c.hline(8, towerTop - 2, W - 16, PixelColor(0x6577B0))
        c.rect(W / 2 - 3, 14, 6, towerTop - 16, PixelColor(0x23304F))
        // Telescope
        c.line(W / 2 + 2, 22, W - 4, 4, PixelColor(0xD4A84B))
        c.line(W / 2 + 2, 23, W - 4, 5, PixelColor(0xB0873A))
        c.line(W / 2 + 3, 23, W - 3, 5, PixelColor(0xD4A84B))
        c.rect(W - 6, 2, 4, 4, PixelColor(0xF5D76E))
        // Stars painted on the dome
        for (x, y) in [(20, 26), (26, 18), (46, 24), (40, 14), (52, 34)] {
            c.set(x, y, PixelColor(0xFFF3A0)); c.set(x + 1, y, PixelColor(0xFFF3A0).darker(0.3))
        }
        door(c, x: W / 2 - 6, bottom: bottom, color: PixelColor(0x3B4A7A))
        window(c, x: 16, y: bottom - 40, w: 8, h: 10, lit: PixelColor(0x9ED6FF))
        window(c, x: W - 24, y: bottom - 40, w: 8, h: 10, lit: PixelColor(0x9ED6FF))
        c.rect(9, bottom - 3, W - 18, 4, PixelColor(0xA39A8C))
        c.outline()
        return c
    }

    // MARK: Trees

    static func sakura(big: Bool, seed: UInt64) -> PixelCanvas {
        var rng = PixelRandom(seed)
        let W = big ? 104 : 40, H = big ? 112 : 48
        let c = PixelCanvas(W, H)
        let trunk = PixelColor(0x7A4E3A)
        let tw = big ? 12 : 5
        let cx = W / 2
        // Trunk with roots and bark lines
        for y in (H / 2)..<(H - 2) {
            let spread = y > H - 8 ? (y - (H - 8)) : 0
            for x in (cx - tw / 2 - spread)...(cx + tw / 2 + spread) {
                var col = trunk
                if x < cx - tw / 4 { col = trunk.lighter(0.15) }
                if x > cx + tw / 4 { col = trunk.darker(0.25) }
                if (x * 3 + y) % 7 == 0 { col = trunk.darker(0.35) }
                c.set(x, y, col)
            }
        }
        if big {
            for (dx, len) in [(-1, 22), (1, 24), (-1, 14)] {
                for i in 0..<len { c.rect(cx + dx * i, H / 2 - i / 2 + 6, 4, 4, trunk.darker(Double(i) / 80)) }
            }
        }
        // Canopy: many shaded blobs
        let pinks = [PixelColor(0xFFB7D5), PixelColor(0xFFA3C8), PixelColor(0xFFC8E0), PixelColor(0xFF92BD)]
        let blobs = big ? 26 : 7
        let cy = Double(big ? 42 : 17)
        for i in 0..<blobs {
            let a = Double(i) / Double(blobs) * 2 * .pi + rng.next()
            let rr = rng.next() * (big ? 30 : 9)
            let r = big ? 10 + rng.next() * 9 : 6 + rng.next() * 4
            c.ellipse(Double(cx) + cos(a) * rr * 1.3, cy + sin(a) * rr * 0.75, r * 1.1, r, pinks[i % 4], shade: true)
        }
        c.ellipse(Double(cx), cy - (big ? 6 : 2), big ? 16 : 7, big ? 12 : 5, pinks[2], shade: true)
        // Blossom speckles
        for _ in 0..<(big ? 260 : 40) {
            let x = rng.int(0, W - 1), y = rng.int(0, H / 2 + 10)
            if !c[x, y].isClear, pinks.contains(where: { $0 == c[x, y] || $0.darker(0.32) == c[x, y] || $0.lighter(0.28) == c[x, y] || $0.darker(0.16) == c[x, y] }) {
                c[x, y] = rng.chance(0.5) ? PixelColor(0xFFFFFF) : PixelColor(0xE0558F)
            }
        }
        c.outline()
        return c
    }

    static func tree(seed: UInt64, pine: Bool) -> PixelCanvas {
        var rng = PixelRandom(seed)
        let W = 36, H = 48
        let c = PixelCanvas(W, H)
        let trunk = PixelColor(0x6E4632)
        c.rect(W / 2 - 3, H - 14, 6, 12, trunk)
        c.vline(W / 2 - 3, H - 14, 12, trunk.lighter(0.2))
        c.vline(W / 2 + 2, H - 14, 12, trunk.darker(0.3))
        let greens = [PixelColor(0x3E9E57), PixelColor(0x4FAE57), PixelColor(0x5CBF5A), PixelColor(0x72CF63)]
        if pine {
            for k in 0..<4 {
                let top = 2 + k * 8, h = 16
                let half = 7 + k * 3
                for y in 0..<h {
                    let w = Int(Double(half) * Double(y) / Double(h))
                    for x in (W / 2 - w)...(W / 2 + w) {
                        var col = greens[1]
                        if x < W / 2 - w / 3 { col = greens[2] }
                        if x > W / 2 + w / 3 { col = greens[0] }
                        if y > h - 3 { col = col.darker(0.25) }
                        if (x + y) % 5 == 0, x < W / 2 { col = greens[3] }
                        c.set(x, top + y, col)
                    }
                }
            }
        } else {
            for i in 0..<7 {
                let a = Double(i) / 7 * 2 * .pi + rng.next()
                c.ellipse(Double(W) / 2 + cos(a) * 7, 17 + sin(a) * 6, 8 + rng.next() * 3, 7 + rng.next() * 2, greens[i % 4], shade: true)
            }
            c.ellipse(Double(W) / 2 - 2, 13, 8, 6, greens[3], shade: true)
            for _ in 0..<14 {
                let x = rng.int(6, W - 7), y = rng.int(5, 28)
                if !c[x, y].isClear { c[x, y] = greens[3].lighter(0.3) }
            }
            if seed % 3 == 0 {
                for _ in 0..<5 {
                    let x = rng.int(8, W - 9), y = rng.int(8, 26)
                    if !c[x, y].isClear { c[x, y] = PixelColor(0xE84855); c[x + 1, y] = PixelColor(0xFF7B7B) }
                }
            }
        }
        c.outline()
        return c
    }

    static func bush(seed: UInt64) -> PixelCanvas {
        var rng = PixelRandom(seed)
        let c = PixelCanvas(20, 15)
        let g = [PixelColor(0x4FAE57), PixelColor(0x5CBF5A), PixelColor(0x3E9E57)]
        for i in 0..<4 { c.ellipse(5 + Double(i) * 3.3, 9 - Double(i % 2) * 2, 5, 4.5, g[i % 3], shade: true) }
        if rng.chance(0.5) {
            for _ in 0..<4 {
                let x = rng.int(3, 16), y = rng.int(4, 10)
                if !c[x, y].isClear { c[x, y] = [PixelColor(0xFFFFFF), PixelColor(0xFF6F91), PixelColor(0xFFD23F)][rng.int(0, 2)] }
            }
        }
        c.outline()
        return c
    }

    static func rock(seed: UInt64) -> PixelCanvas {
        let c = PixelCanvas(14, 11)
        c.ellipse(7, 6.5, 6, 4.5, PixelColor(0xA8A196), shade: true)
        if seed % 2 == 0 { c.ellipse(4, 7.5, 3, 2.5, PixelColor(0x9A9388), shade: true) }
        c.set(5, 4, PixelColor(0x5DB447)); c.set(6, 4, PixelColor(0x6FC453))
        c.outline()
        return c
    }

    // MARK: Village furniture

    static func lantern() -> PixelCanvas {
        let c = PixelCanvas(14, 26)
        let stone = PixelColor(0xB8B2A8)
        c.rect(3, 20, 8, 4, stone); c.hline(3, 20, 8, stone.lighter(0.2))
        c.rect(5, 12, 4, 8, stone.darker(0.1)); c.vline(5, 12, 8, stone.lighter(0.15))
        c.rect(2, 6, 10, 7, stone)
        c.rect(4, 8, 6, 4, PixelColor(0xFFD27A)); c.rect(5, 9, 4, 2, PixelColor(0xFFF3C0))
        c.rect(1, 3, 12, 3, stone.darker(0.2)); c.hline(1, 3, 12, stone.lighter(0.1))
        c.rect(5, 1, 4, 2, stone.darker(0.3))
        c.outline()
        return c
    }

    static func bench() -> PixelCanvas {
        let c = PixelCanvas(28, 16)
        let wood = PixelColor(0xB5784A)
        c.rect(2, 2, 24, 5, wood); c.hline(2, 2, 24, wood.lighter(0.25)); c.hline(2, 4, 24, wood.darker(0.2))
        c.rect(2, 8, 24, 3, wood.darker(0.1)); c.hline(2, 8, 24, wood.lighter(0.15))
        for x in [4, 22] { c.rect(x, 7, 2, 7, PixelColor(0x5A4A42)) }
        c.outline()
        return c
    }

    static func torii() -> PixelCanvas {
        let c = PixelCanvas(80, 66)
        let red = PixelColor(0xE5383B), black = PixelColor(0x2B2530)
        for x in [14, 61] {
            c.rect(x, 14, 6, 50, red)
            c.vline(x, 14, 50, red.lighter(0.25)); c.vline(x + 5, 14, 50, red.darker(0.3))
            c.rect(x - 1, 58, 8, 6, black)
        }
        c.rect(2, 4, 76, 6, black); c.hline(2, 4, 76, PixelColor(0x4A4050))
        c.set(0, 2, black); c.set(1, 3, black); c.set(79, 2, black); c.set(78, 3, black)
        c.rect(6, 10, 68, 5, red); c.hline(6, 10, 68, red.lighter(0.3)); c.hline(6, 14, 68, red.darker(0.35))
        c.rect(10, 24, 60, 4, red); c.hline(10, 24, 60, red.lighter(0.3))
        c.rect(36, 14, 8, 10, black)
        c.rect(37, 15, 6, 8, PixelColor(0xF5D76E))
        c.outline()
        return c
    }

    static func questBoard() -> PixelCanvas {
        let c = PixelCanvas(48, 40)
        let wood = PixelColor(0xB07A4A)
        for x in [5, 40] { c.rect(x, 6, 4, 33, wood.darker(0.15)); c.vline(x, 6, 33, wood.lighter(0.15)) }
        c.rect(3, 10, 42, 22, PixelColor(0xD9A066))
        for y in stride(from: 12, to: 32, by: 5) { c.hline(3, y, 42, PixelColor(0xC48A55)) }
        c.rect(1, 3, 46, 5, PixelColor(0xC2415F)); c.hline(1, 3, 46, PixelColor(0xE8667F))
        let papers = [PixelColor(0xFFF8EC), PixelColor(0xFFF1B8), PixelColor(0xFFE3EE), PixelColor(0xE6F7FF)]
        for (i, (x, y)) in [(6, 12), (17, 13), (29, 12), (10, 22), (23, 22), (34, 21)].enumerated() {
            c.rect(x, y, 9, 8, papers[i % 4])
            c.hline(x + 1, y + 2, 6, PixelColor(0xB0A090)); c.hline(x + 1, y + 4, 5, PixelColor(0xB0A090))
            c.set(x + 4, y, PixelColor(0xE84855))
        }
        c.outline()
        return c
    }

    static func anvil() -> PixelCanvas {
        let c = PixelCanvas(22, 14)
        let iron = PixelColor(0x4A5060)
        c.rect(7, 8, 8, 5, iron.darker(0.2))
        c.rect(3, 3, 15, 5, iron); c.hline(3, 3, 15, PixelColor(0x8A92A6))
        c.rect(18, 4, 3, 2, iron)
        c.rect(5, 12, 12, 2, PixelColor(0x6E4632))
        c.outline()
        return c
    }

    static func firePit(frame f: Int) -> PixelCanvas {
        let c = PixelCanvas(18, 22)
        c.rect(2, 16, 14, 5, PixelColor(0x8E8577)); c.hline(2, 16, 14, PixelColor(0xB8B0A2))
        let flames = [PixelColor(0xFF5E1A), PixelColor(0xFFB13B), PixelColor(0xFFF3B0)]
        let hs = [[8, 12, 9], [11, 8, 12], [9, 13, 8]][f % 3]
        for (k, (x, h)) in zip([5, 9, 13], hs).enumerated() {
            for y in 0..<h {
                let w = max(0, 2 - y * 2 / h)
                for dx in -w...w { c.set(x + dx, 16 - y, flames[min(2, (y * 3) / h + (k == 1 ? 0 : 0))]) }
            }
            c.set(x, 16 - h, flames[2])
        }
        c.outline()
        return c
    }

    static func sortingTable() -> PixelCanvas {
        let c = PixelCanvas(28, 18)
        let wood = PixelColor(0xB5784A)
        c.rect(1, 6, 26, 4, wood); c.hline(1, 6, 26, wood.lighter(0.25))
        for x in [3, 23] { c.rect(x, 10, 2, 7, wood.darker(0.3)) }
        for (i, x) in [3, 8, 13, 18].enumerated() {
            c.rect(x, 3 - i % 2, 6, 4, i % 2 == 0 ? PixelColor(0xFFF8EC) : PixelColor(0xFFE3EE))
            c.set(x + 2, 4 - i % 2, PixelColor(0xE8366E))
        }
        c.outline()
        return c
    }

    static func mailbox() -> PixelCanvas {
        let c = PixelCanvas(14, 26)
        let red = PixelColor(0xE53950)
        c.rect(5, 14, 3, 11, PixelColor(0x5A4A42))
        c.rect(1, 4, 12, 11, red)
        c.ellipse(7, 4.5, 6, 3.5, red, shade: true)
        c.vline(1, 4, 11, red.lighter(0.3)); c.vline(12, 4, 11, red.darker(0.3))
        c.rect(4, 8, 6, 2, PixelColor(0x2A1A33))
        c.set(11, 3, PixelColor(0xF5D76E)); c.set(11, 2, PixelColor(0xF5D76E))
        c.outline()
        return c
    }

    static func bookshelf() -> PixelCanvas {
        let c = PixelCanvas(26, 30)
        let wood = PixelColor(0x8B5A3C)
        c.rect(1, 1, 24, 28, wood)
        c.rect(3, 3, 20, 24, wood.darker(0.35))
        let colors = [PixelColor(0xE8366E), PixelColor(0x27C2E8), PixelColor(0xF5D76E), PixelColor(0x4ADE80), PixelColor(0xA78BFA), PixelColor(0xFF8A3D)]
        var rng = PixelRandom(17)
        for row in 0..<3 {
            var x = 3
            let shelfY = 3 + row * 8
            while x < 22 {
                let w = rng.int(2, 3), h = rng.int(5, 7)
                let col = colors[rng.int(0, colors.count - 1)]
                c.rect(x, shelfY + 7 - h, w, h, col)
                c.vline(x, shelfY + 7 - h, h, col.lighter(0.3))
                x += w
            }
            c.hline(2, shelfY + 7, 22, wood.lighter(0.15))
        }
        c.outline()
        return c
    }

    static func telescope() -> PixelCanvas {
        let c = PixelCanvas(24, 26)
        let brass = PixelColor(0xD4A84B)
        c.line(12, 14, 4, 24, PixelColor(0x5A4A42)); c.line(12, 14, 20, 24, PixelColor(0x5A4A42)); c.line(12, 14, 12, 24, PixelColor(0x5A4A42))
        for i in 0..<14 { c.rect(4 + i, 12 - i * 2 / 3, 4 - i / 6, 4 - i / 6, i < 3 ? brass.lighter(0.3) : brass) }
        c.rect(18, 1, 5, 5, brass.lighter(0.2))
        c.outline()
        return c
    }

    static func hologramBase() -> PixelCanvas {
        let c = PixelCanvas(30, 8)
        c.ellipse(15, 4, 14, 3.5, PixelColor(0x23304F), shade: true)
        c.ellipse(15, 3.5, 11, 2, PixelColor(0x5CF2FF))
        c.outline()
        return c
    }

    static func barrel() -> PixelCanvas {
        let c = PixelCanvas(14, 16)
        let wood = PixelColor(0xA0683F)
        c.ellipse(7, 8, 6, 7, wood, shade: true)
        c.hline(1, 4, 12, PixelColor(0x5A4A42)); c.hline(1, 11, 12, PixelColor(0x5A4A42))
        c.ellipse(7, 2.5, 5, 1.5, wood.lighter(0.2))
        c.outline()
        return c
    }

    static func crate() -> PixelCanvas {
        let c = PixelCanvas(15, 15)
        let wood = PixelColor(0xC48A55)
        c.rect(1, 1, 13, 13, wood)
        c.rect(1, 1, 13, 2, wood.lighter(0.2)); c.rect(1, 12, 13, 2, wood.darker(0.25))
        c.line(2, 3, 12, 11, wood.darker(0.3)); c.line(2, 11, 12, 3, wood.darker(0.3))
        c.outline()
        return c
    }

    static func signpost() -> PixelCanvas {
        let c = PixelCanvas(26, 24)
        c.rect(11, 6, 3, 17, PixelColor(0x6E4632))
        c.rect(2, 3, 22, 7, PixelColor(0xD9A066)); c.hline(2, 3, 22, PixelColor(0xEBC08A))
        PixelFont.draw("INN", on: c, x: 6, y: 3, color: PixelColor(0x5A3E2E))
        c.outline()
        return c
    }

    // MARK: Glows & particles

    static func glow(radius r: Int, color: PixelColor) -> PixelCanvas {
        let c = PixelCanvas(r * 2, r * 2)
        for y in 0..<(r * 2) {
            for x in 0..<(r * 2) {
                let d = hypot(Double(x - r) + 0.5, Double(y - r) + 0.5) / Double(r)
                guard d < 1 else { continue }
                let th = PixelCanvas.bayer[(y % 4) * 4 + (x % 4)]
                let level = (1 - d) * 3 + th * 0.9
                let a: UInt8 = level > 2.4 ? 150 : level > 1.6 ? 95 : level > 0.8 ? 50 : 0
                if a > 0 { c[x, y] = color.alpha(a) }
            }
        }
        return c
    }

    static func particle(_ kind: String) -> PixelCanvas {
        switch kind {
        case "petal":
            let c = PixelCanvas(4, 3)
            c.draw([".pp.", "pPpp", ".pp."], palette: ["p": PixelColor(0xFFB7D5), "P": PixelColor(0xFFFFFF)])
            return c
        case "spark":
            let c = PixelCanvas(2, 2, fill: PixelColor(0xFFF3B0)); return c
        case "smoke":
            let c = PixelCanvas(6, 6)
            c.ellipse(3, 3, 3, 3, PixelColor(0xE6E2F0))
            c.set(2, 1, PixelColor(0xFFFFFF))
            return c
        case "sparkle":
            let c = PixelCanvas(5, 5)
            c.draw(["..#..", "..#..", "##W##", "..#..", "..#.."], palette: ["#": PixelColor(0xFFFFFF).alpha(200), "W": PixelColor(0xFFFFFF)])
            return c
        case "dust":
            let c = PixelCanvas(3, 3)
            c.draw([".d.", "ddd", ".d."], palette: ["d": PixelColor(0xE8D2A8)])
            return c
        default:
            return PixelCanvas(2, 2, fill: PixelColor(0xFFFFFF))
        }
    }
}
