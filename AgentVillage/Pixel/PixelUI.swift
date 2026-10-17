import SwiftUI
import SpriteKit

/// Pixel-art UI pieces: bubbles, plates, icons, window frames and portraits.
@MainActor
enum PixelUI {
    static let ink = PixelColor(0x2A1A33)

    // MARK: In-world bubbles

    static func bubble(_ text: String, style: Bubble.Style, accent: PixelColor) -> PixelCanvas {
        let lines = PixelFont.wrap(text, maxWidth: 104)
        let textW = lines.map(PixelFont.measure).max() ?? 0
        let w = textW + 12, h = lines.count * 10 + 8
        let tail = style == .thought ? 7 : 5
        let c = PixelCanvas(w + 3, h + tail + 3)
        let fill = style == .shout ? PixelColor(0xFFF8D6) : PixelColor(0xFFFFFF)
        let border = style == .shout ? accent.darker(0.35) : ink

        func box(_ ox: Int, _ oy: Int, _ col: PixelColor) {
            c.rect(ox + 2, oy, w - 4, h, col)
            c.rect(ox + 1, oy + 1, w - 2, h - 2, col)
            c.rect(ox, oy + 2, w, h - 4, col)
        }
        // Soft drop shadow, border, fill
        box(2, 2, PixelColor(0x100A1E).alpha(90))
        box(0, 0, border)
        c.rect(2, 1, w - 4, h - 2, fill); c.rect(1, 2, w - 2, h - 4, fill)
        // Bottom inner shade and top highlight
        c.hline(2, h - 2, w - 4, fill.darker(0.08))
        if style == .shout {
            c.hline(3, 1, w - 6, accent.lighter(0.55))
            c.rect(w - 6, 3, 2, 2, accent)
        }
        let cx = w / 2
        if style == .thought {
            c.ellipse(Double(cx) - 2, Double(h + 2), 2.5, 2, border)
            c.ellipse(Double(cx) - 2, Double(h + 2), 1.5, 1, fill)
            c.ellipse(Double(cx) - 5, Double(h + 6), 1.5, 1.2, border)
        } else {
            for i in 0..<tail {
                let half = tail - i
                c.hline(cx - half, h - 1 + i, half * 2, border)
                if half > 1 { c.hline(cx - half + 1, h - 1 + i, half * 2 - 2, fill) }
            }
        }
        for (i, l) in lines.enumerated() {
            PixelFont.draw(l, on: c, x: 6, y: 4 + i * 10, color: ink)
        }
        return c
    }

    static func namePlate(_ name: String, color: PixelColor, selected: Bool) -> PixelCanvas {
        let tw = PixelFont.measure(name)
        let w = tw + 10, h = 11
        let c = PixelCanvas(w + 2, h + 2)
        c.rect(1, 1, w, h, PixelColor(0x1B1640).alpha(225))
        c.rect(1, 1, 3, h, color)
        let border = selected ? PixelColor(0xFFD23F) : color.darker(0.2)
        c.hline(2, 0, w - 2, border); c.hline(2, h + 1, w - 2, border)
        c.vline(0, 2, h - 2, border); c.vline(w + 1, 2, h - 2, border)
        c.set(1, 1, border); c.set(w, 1, border); c.set(1, h, border); c.set(w, h, border)
        PixelFont.draw(name, on: c, x: 6, y: 2, color: PixelColor(0xFFFFFF), shadow: PixelColor(0x000000).alpha(140))
        return c
    }

    static func emoteBang() -> PixelCanvas {
        let c = PixelCanvas(11, 15)
        c.draw([
            "..yyyyyyy..",
            ".yYYYYYYYy.",
            "yYYYkkkYYYy",
            "yYYYkkkYYYy",
            "yYYYkkkYYYy",
            "yYYYkkkYYYy",
            "yYYYYkYYYYy",
            "yYYYYYYYYYy",
            "yYYYkkkYYYy",
            ".yYYYYYYYy.",
            "..yyyyyyy..",
            "....yYy....",
            ".....y.....",
        ], at: 0, 1, palette: ["y": PixelColor(0xC98A00), "Y": PixelColor(0xFFD23F), "k": ink])
        c.outline()
        return c
    }

    static func selectArrow() -> PixelCanvas {
        let c = PixelCanvas(9, 7)
        c.draw(["YYYYYYY", ".YYYYY.", "..YYY..", "...Y..."], at: 1, 1, palette: ["Y": PixelColor(0xFFD23F)])
        c.set(2, 1, PixelColor(0xFFF3A0)); c.set(3, 1, PixelColor(0xFFF3A0))
        c.outline()
        return c
    }

    static func shadow() -> PixelCanvas {
        let c = PixelCanvas(14, 5)
        c.ellipse(7, 2.5, 6.5, 2.2, PixelColor(0x1A0F24).alpha(90))
        return c
    }

    static func selectionRing(_ color: PixelColor, phase: Int) -> PixelCanvas {
        let c = PixelCanvas(22, 9)
        for i in 0..<64 {
            let a = Double(i) / 64 * 2 * .pi
            let x = 11 + cos(a) * 10, y = 4.5 + sin(a) * 3.8
            if (i / 4 + phase) % 2 == 0 { c.set(Int(x), Int(y), color) }
        }
        return c
    }

    // MARK: HUD icons (drawn at 1x, displayed with integer scaling)

    static func icon(_ name: String) -> PixelCanvas {
        let pal: [Character: PixelColor] = [
            "y": PixelColor(0xFFD23F), "Y": PixelColor(0xFFF3A0), "o": PixelColor(0xC98A00),
            "c": PixelColor(0x5CF2FF), "C": PixelColor(0xD6FCFF), "b": PixelColor(0x2B8FC9),
            "r": PixelColor(0xE8366E), "R": PixelColor(0xFF8FB0), "w": PixelColor(0xFFFFFF), "k": ink,
            "g": PixelColor(0x4ADE80), "G": PixelColor(0xB4F5C8), "p": PixelColor(0xA78BFA), "P": PixelColor(0xD8CCFF),
            "n": PixelColor(0x8B5A3C), "N": PixelColor(0xD9A066), "s": PixelColor(0xB8C2D3),
        ]
        let rows: [String]
        switch name {
        case "coin": rows = ["..oooo..", ".oyyyyo.", "oyYyyoyo", "oyYoyoyo", "oyYoyoyo", "oyyyyoyo", ".oyyyyo.", "..oooo.."]
        case "mana": rows = ["...cc...", "..cCCc..", ".cCCcCc.", "cCCccCcb", "cCccccbb", ".ccccbb.", "..cbbb..", "...bb..."]
        case "flag": rows = ["nrrrrr..", "nrRRrrr.", "nrRrrrrr", "nrrrrrr.", "nrrrr...", "n.......", "n.......", "n......."]
        case "sun": rows = ["y..y..y.", ".y.yy.y.", "..yYYy..", "yyYYYYyy", "..yYYy..", ".y.yy.y.", "y..y..y.", "........"]
        case "moon": rows = ["..PPPP..", ".PPpp...", "PPpp....", "PPp.....", "PPp.....", "PPpp...P", ".PPpppP.", "..PPPP.."]
        case "scroll": rows = ["NNNNNNN.", "NwwwwwnN", ".wkkkwn.", ".wwwwwn.", ".wkkkwn.", ".wwwwwn.", "NwwwwwnN", ".NNNNNN."]
        case "plus": rows = ["...ww...", "...ww...", "...ww...", "wwwwwwww", "wwwwwwww", "...ww...", "...ww...", "...ww..."]
        case "minus": rows = ["........", "........", "........", "wwwwwwww", "wwwwwwww", "........", "........", "........"]
        case "home": rows = ["...ww...", "..wwww..", ".wwwwww.", "wwwwwwww", ".wwkkww.", ".wwkkww.", ".wwkkww.", "........"]
        case "fast": rows = ["w...w...", "ww..ww..", "www.www.", "wwwwwwww", "www.www.", "ww..ww..", "w...w...", "........"]
        case "sound": rows = ["...w..w.", "..ww...w", "wwww.w.w", "wwww.w.w", "wwww.w.w", "..ww...w", "...w..w.", "........"]
        case "mute": rows = ["...w....", "..ww....", "wwww.r.r", "wwww..r.", "wwww.r.r", "..ww....", "...w....", "........"]
        case "check": rows = [".......g", "......gg", ".....gg.", "g...gg..", "gg.gg...", ".ggg....", "..g.....", "........"]
        case "cross": rows = ["r.....r.", ".r...r..", "..r.r...", "...r....", "..r.r...", ".r...r..", "r.....r.", "........"]
        case "ask": rows = [".cccc...", "c....c..", ".....c..", "....c...", "...c....", "........", "...c....", "........"]
        case "zzz": rows = ["pppp....", "...p....", "..p.....", ".p..PPP.", "pppp..P.", ".....P..", "....PPP.", "........"]
        case "sword": rows = [".......s", "......ss", ".....ss.", "y...ss..", ".yyss...", "..yy....", ".y.y....", "y......."]
        case "inbox": rows = ["wwwwwwww", "ww....ww", "w.w..w.w", "w..ww..w", "w......w", "wwwwwwww", "........", "........"]
        case "chart": rows = [".......g", "....c..g", "....c..g", ".y..c..g", ".y..c..g", ".y..c..g", "wwwwwwww", "........"]
        case "gear": rows = ["...ss...", ".s.ss.s.", "..ssss..", "sss..sss", "sss..sss", "..ssss..", ".s.ss.s.", "...ss..."]
        case "list": rows = ["y.wwwwww", "........", "y.wwwww.", "........", "y.wwwwww", "........", "y.wwww..", "........"]
        case "quest": rows = ["NNNNNN..", "NwwwwnN.", ".wkkwn..", ".wwwwn.y", ".wkkwnyy", ".wwwwn.y", "NwwwwnN.", ".NNNNN.."]
        case "music": rows = ["...wwwww", "...w...w", "...w...w", "...w...w", ".www.www", "wwww.www", ".ww..ww.", "........"]
        case "musicoff": rows = ["...wwwwr", "...w..rw", "...w.r.w", "...wr..w", ".wwr.www", "wwrw.www", ".rw..ww.", "r......."]
        case "play": rows = ["g.......", "ggg.....", "ggggg...", "ggggggg.", "ggggg...", "ggg.....", "g.......", "........"]
        case "pausei": rows = ["pp..pp..", "pp..pp..", "pp..pp..", "pp..pp..", "pp..pp..", "pp..pp..", "pp..pp..", "........"]
        case "clock": rows = ["..wwww..", ".w..k.w.", "w...k..w", "w...kk.w", "w......w", ".w....w.", "..wwww..", "........"]
        case "work": rows = ["..cc....", ".c..c...", ".c..c...", "..cccc..", "....ccc.", ".....ccc", "......cc", "........"]
        case "heart": rows = [".rr.rr..", "rRrrrrr.", "rRrrrrr.", "rrrrrrr.", ".rrrrr..", "..rrr...", "...r....", "........"]
        default: rows = ["wwwwwwww"]
        }
        let c = PixelCanvas(10, 10)
        c.draw(rows, at: 1, 1, palette: pal)
        c.outline()
        return c
    }

    // MARK: Window frame (9-slice)

    /// Classic JRPG window border; center is transparent so a gradient can show through.
    static func windowFrame(accent: PixelColor = PixelColor(0xF4E9D0)) -> PixelCanvas {
        let c = PixelCanvas(12, 12)
        let outer = PixelColor(0x0C0818), light = accent, inner = PixelColor(0x0C0818).alpha(150)
        for i in 1..<11 {
            c.set(i, 0, outer); c.set(i, 11, outer); c.set(0, i, outer); c.set(11, i, outer)
            c.set(i, 1, light); c.set(1, i, light); c.set(i, 10, light.darker(0.3)); c.set(10, i, light.darker(0.3))
            c.set(i, 2, inner); c.set(2, i, inner)
        }
        c[1, 1] = outer; c[10, 1] = outer; c[1, 10] = outer; c[10, 10] = outer
        // Gold corner studs
        let gold = PixelColor(0xFFD23F)
        c[2, 2] = gold; c[9, 2] = gold; c[2, 9] = gold; c[9, 9] = gold.darker(0.2)
        return c
    }

    // MARK: Portraits (40x40 bust)

    private static var portraitCache: [String: CGImage] = [:]

    static func portrait(_ p: Persona, _ e: Expression = .normal) -> CGImage {
        let key = "\(p.id)-\(e)"
        if let i = portraitCache[key] { return i }
        let c = PixelCanvas(44, 44)
        let skin = PixelColor(p.skin), hair = PixelColor(p.hair), shade = PixelColor(p.hairShade)
        let outfit = PixelColor(p.outfit), accent = PixelColor(p.outfitAccent), eye = PixelColor(p.eye)
        let cx = 22.0

        // Back hair
        switch p.hairStyle {
        case .longStraight:
            c.rect(6, 14, 32, 30, shade)
            for x in stride(from: 7, to: 37, by: 4) { c.vline(x, 18, 24, shade.darker(0.15)) }
        case .twinTails:
            c.ellipse(5, 30, 5, 11, hair, shade: true)
            c.ellipse(39, 30, 5, 11, hair, shade: true)
        default: break
        }
        c.ellipse(cx, 18, 17, 15, shade)

        // Shoulders and collar
        c.ellipse(cx, 46, 19, 11, outfit, shade: true)
        c.rect(18, 33, 8, 4, skin.darker(0.2))
        for i in 0..<5 { c.hline(Int(cx) - 5 + i, 36 + i, 10 - i * 2, accent) }

        // Face
        c.ellipse(cx, 22, 13.5, 13, skin)
        for y in 26..<35 { for x in 9...34 where !c[x, y].isClear && c[x, y] == skin && (x > 29 || y > 32) { c[x, y] = skin.darker(0.12) } }
        let ink = PixelUI.ink
        let eyeY = 22
        for ex in [13, 26] {
            switch e {
            case .blink, .happy:
                let up = e == .happy
                c.hline(ex, eyeY + 3, 5, ink)
                c.set(ex - 1, eyeY + (up ? 4 : 2), ink); c.set(ex + 5, eyeY + (up ? 4 : 2), ink)
            default:
                let h = e == .focused ? 4 : 6
                let top = eyeY + 6 - h
                c.rect(ex, top, 5, h, eye)
                c.hline(ex, top, 5, eye.darker(0.5))
                c.hline(ex, top + 1, 5, eye.darker(0.3))
                c.hline(ex, eyeY + 5, 5, eye.lighter(0.4))
                if e != .surprised { c.rect(ex + 1, top + 2, 3, 2, eye.darker(0.65)) }
                c.rect(ex + 1, top + 1, 2, 2, PixelColor(0xFFFFFF))
                c.set(ex + 3, eyeY + 4, PixelColor(0xFFFFFF))
                c.hline(ex - 1, top - 1, 7, ink)
                c.set(ex + (ex < 20 ? -1 : 5), top, ink)
            }
            c.hline(ex - 1, eyeY + 8, 3, PixelColor(0xFF8FA3))
            c.hline(ex + 3, eyeY + 8, 3, PixelColor(0xFF8FA3))
        }
        if p.accessory == .glasses {
            for ex in [13, 26] {
                c.hline(ex - 2, eyeY - 1, 9, PixelColor(0x3B2E5A)); c.hline(ex - 2, eyeY + 7, 9, PixelColor(0x3B2E5A))
                c.vline(ex - 2, eyeY - 1, 9, PixelColor(0x3B2E5A)); c.vline(ex + 6, eyeY - 1, 9, PixelColor(0x3B2E5A))
            }
            c.hline(19, eyeY + 1, 6, PixelColor(0x3B2E5A))
        }
        // Mouth
        switch e {
        case .happy:
            c.rect(20, 31, 4, 2, PixelColor(0xA8405A)); c.hline(21, 32, 2, PixelColor(0xFF8FA3))
        case .surprised:
            c.rect(21, 30, 2, 3, PixelColor(0xA8405A))
        case .sad:
            c.hline(20, 32, 4, PixelColor(0xA8405A)); c.set(19, 33, PixelColor(0xA8405A)); c.set(24, 33, PixelColor(0xA8405A))
        default:
            c.set(20, 31, PixelColor(0xA8405A)); c.set(21, 32, PixelColor(0xA8405A)); c.set(22, 32, PixelColor(0xA8405A)); c.set(23, 31, PixelColor(0xA8405A))
        }

        // Fringe and top hair
        for y in 3..<18 {
            for x in 4..<40 {
                let dx = (Double(x) - cx) / 16.5, dy = (Double(y) - 15) / 13
                guard dx * dx + dy * dy < 1 else { continue }
                // Bangs: jagged lower edge
                let jag = Double((x * 7) % 9) / 9 * 4
                let edge = 16 + jag - abs(Double(x) - cx) * 0.12
                guard Double(y) < edge else { continue }
                var col = hair
                if y < 8 && x < 22 { col = hair.lighter(0.3) }
                if (x + y) % 6 == 0 { col = shade }
                if x > 33 { col = shade }
                c.set(x, y, col)
            }
        }
        // Side locks
        for s in [-1.0, 1.0] { c.ellipse(cx + s * 14, 26, 3, 8, hair, shade: true) }
        // Shine band
        for x in 11..<20 { c.set(x, 8 + (x - 11) / 4, PixelColor(0xFFFFFF).alpha(170)) }

        switch p.hairStyle {
        case .spiky:
            for i in 0..<6 {
                let bx = 7 + i * 6
                for k in 0..<7 { c.hline(bx + k / 2, 4 - k + (i % 2) * 2, 5 - k, i % 2 == 0 ? hair : shade) }
            }
            c.rect(6, 12, 32, 3, accent); c.hline(6, 12, 32, accent.lighter(0.3))
            c.rect(18, 11, 8, 5, PixelColor(0xC9D3E0)); c.hline(18, 11, 8, PixelColor(0xFFFFFF))
        case .twinTails:
            c.ellipse(34, 5, 4, 3, accent, shade: true); c.ellipse(40, 7, 4, 3, accent, shade: true)
            c.rect(36, 5, 3, 3, accent.darker(0.3))
        case .messy:
            for (bx, by) in [(10, 3), (18, 1), (27, 2), (34, 6)] { c.ellipse(Double(bx), Double(by) + 2, 4, 3, hair, shade: true) }
            for gx in [12, 28] {
                c.ellipse(Double(gx), 10, 4, 3.5, PixelColor(0x6B4F2F))
                c.ellipse(Double(gx), 10, 2.5, 2, PixelColor(0x7FE3FF))
                c.set(gx - 1, 9, PixelColor(0xFFFFFF))
            }
            c.hline(16, 10, 8, PixelColor(0x6B4F2F))
        case .longStraight:
            c.vline(22, 0, 4, hair); c.set(23, 0, hair); c.set(24, 1, hair)
        }
        c.outline()
        let img = c.cgImage()
        portraitCache[key] = img
        return img
    }

    static func portraitImage(_ p: Persona, _ e: Expression = .normal) -> Image {
        Image(decorative: portrait(p, e), scale: 1).interpolation(.none)
    }
}
