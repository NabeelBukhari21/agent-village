import SpriteKit

enum Facing: Int { case down, up, side }

/// Hand-authored 16x24 chibi sprite parts, composed per agent with palette swaps.
@MainActor
enum CharacterSprites {
    static let frameW = 20, frameH = 27
    static let ox = 2, oy = 2

    // MARK: Base bodies

    static let downHead = [
        "................",
        "................",
        ".....SSSSSS.....",
        "...SSSSSSSSSS...",
        "..SSSSSSSSSSSS..",
        "..SSSSSSSSSSSS..",
        "..SSSSSSSSSSSS..",
        "..SSKKSSSSKKSS..",
        "..SSWeSSSSeWSS..",
        "..SSelSSSSleSS..",
        "..sBSSSMMSSSBs..",
        "...sSSSSSSSSs...",
        "....ssSSSSss....",
    ]
    static let downBody = [
        "......sSSs......",
        "....ACCAACCA....",
        "...CCCCAACCCC...",
        "...CcCCCCCCcC...",
        "...ScCCCCCCcS...",
        "....AAAAAAAA....",
        "....CCCCCCCC....",
        "....cCCccCCc....",
    ]
    static let upHead = [
        "................",
        "................",
        ".....SSSSSS.....",
        "...SSSSSSSSSS...",
        "..SSSSSSSSSSSS..",
        "..SSSSSSSSSSSS..",
        "..SSSSSSSSSSSS..",
        "..SSSSSSSSSSSS..",
        "..SSSSSSSSSSSS..",
        "..SSSSSSSSSSSS..",
        "..sSSSSSSSSSSs..",
        "...sSSSSSSSSs...",
        "....ssSSSSss....",
    ]
    static let upBody = [
        "......sSSs......",
        "....CCCCCCCC....",
        "...CCCCCCCCCC...",
        "...CcCCCCCCcC...",
        "...ScCCCCCCcS...",
        "....AAAAAAAA....",
        "....CCCCCCCC....",
        "....cCCCCCCc....",
    ]
    static let sideHead = [
        "................",
        "................",
        ".....SSSSSS.....",
        "....SSSSSSSSS...",
        "...SSSSSSSSSSS..",
        "...SSSSSSSSSSS..",
        "...SSSSSSSSSSS..",
        "...SSSSSSSKKSS..",
        "...SSSSSSSWeSS..",
        "...SSSSSSSelSS..",
        "...sSSSSSSSSBS..",
        "....sSSSSSSMSS..",
        ".....ssSSSSs....",
    ]
    static let sideBody = [
        ".......sSs......",
        "......ACCCA.....",
        "......CCCCC.....",
        "......CCSCC.....",
        "......cCSCc.....",
        "......AAAAA.....",
        "......CCCCC.....",
        "......cCCCc.....",
    ]
    static let downLegs = [
        [".....PP..PP.....", ".....PP..PP.....", "....FFF..FFF...."],
        [".....PP..PP.....", "....FFF..PP.....", ".........FFF...."],
        [".....PP..PP.....", ".....PP..FFF....", "....FFF........."],
    ]
    static let sideLegs = [
        [".......PPP......", ".......PPP......", ".......PFFF....."],
        ["......PP.PP.....", ".....PP...PP....", "....FF.....FF..."],
        [".......PPP......", "......PP.PP.....", ".....FF..FFF...."],
    ]

    // MARK: Hair (rows 0...17 over the head)

    static func hair(_ style: HairStyle, _ f: Facing) -> [String] {
        switch (style, f) {
        case (.twinTails, .down): return [
            "................",
            ".....hHHHHh..AA.",
            "...hHHLLHHHHAaA.",
            "..hHHLLHHHHHHAh.",
            ".hHHHHHHHHHHHHh.",
            ".HHHHhHHHHhHHHH.",
            "AHHhH.HhhH.HhHHA",
            "HHh..........hHH",
            "HH............HH",
            "HH............HH",
            "hH............Hh",
            "hH............Hh",
            ".h............h.",
            ".h............h.",
        ]
        case (.twinTails, .up): return [
            "................",
            ".....hHHHHh..AA.",
            "...hHHHHHHHHAaA.",
            "..hHHHLLHHHHHAh.",
            ".hHHHHLHHHHHHHh.",
            ".HHHHHHHHHHHHHH.",
            "AHHHHHHHHHHHHHHA",
            "HHHHHHHHHHHHHHHH",
            "HHHHHHHHHHHHHHHH",
            "HHhHHHHHHHHHHhHH",
            "hH.hHHHHHHHHh.Hh",
            "hH..hhHHHHhh..Hh",
            ".h............h.",
            ".h............h.",
        ]
        case (.twinTails, .side): return [
            "................",
            ".....hHHHHh.....",
            "...hHHLLHHHh....",
            "..hHHLLHHHHHh...",
            ".hHHHHHHHHHHHh..",
            ".HHHHHHHHHhHHHh.",
            "AHHHHHHHHh.Hh.h.",
            "HHHHHHHh........",
            "HHhHHHh.........",
            "HH.hHh..........",
            "hH..............",
            "hH..............",
            ".h..............",
            ".h..............",
        ]
        case (.spiky, .down): return [
            "..h..hH..Hh..h..",
            "..Hh.HHhhHH.hH..",
            "..HHhHHHHHHhHH..",
            ".hHHHHLLHHHHHHh.",
            "hHAAAAGGGGAAAAHh",
            ".HHHHhHHHHhHHHH.",
            ".HH.HH.HH.HH.HH.",
            ".Hh..H....H..hH.",
            ".h............h.",
        ]
        case (.spiky, .up): return [
            "..h..hH..Hh..h..",
            "..Hh.HHhhHH.hH..",
            "..HHhHHHHHHhHH..",
            ".hHHHHLLHHHHHHh.",
            "hHAAAAAAAAAAAAHh",
            ".HHHHHHHHHHHHHH.",
            "hHHHHHHHHHHHHHHh",
            ".HHHHHHHHHHHHHH.",
            ".hHHhHHHHHHhHHh.",
            "..h..HhHHhH..h..",
            "......A..A......",
            ".....A....A.....",
        ]
        case (.spiky, .side): return [
            "...h..Hh..h.....",
            "..hHhHHHhHH.....",
            ".hHHHHHHHHHh....",
            "hHHHHLLHHHHHh...",
            "HHAAAAAAAGGGh...",
            "hHHHHHHHHHhHHh..",
            ".HHHHHHHH.H.H...",
            ".hHHHHHh........",
            "..hHHHh.........",
            "..A.hh..........",
            ".A..............",
        ]
        case (.longStraight, .down): return [
            ".......Hh.......",
            ".....hHHHHh.....",
            "...hHHHLLHHHh...",
            "..hHHHLLHHHHHh..",
            ".hHHHHHHHHHHHHh.",
            ".HHHHHHHHHHHHHH.",
            ".HHhHHHhhHHHhHH.",
            ".HH..........HH.",
            ".HH..........HH.",
            ".HH..........HH.",
            ".HH..........HH.",
            ".Hh..........hH.",
            ".Hh..........hH.",
            ".HH..........HH.",
            ".Hh..........hH.",
            ".h............h.",
        ]
        case (.longStraight, .up): return [
            ".......Hh.......",
            ".....hHHHHh.....",
            "...hHHHHHHHHh...",
            "..hHHHLLHHHHHh..",
            ".hHHHHLHHHHHHHh.",
            ".HHHHHHHHHHHHHH.",
            ".HHHHHHHHHHHHHH.",
            ".HHHHHHHHHHHHHH.",
            ".HHhHHHHHHHHhHH.",
            ".HHHHHHHHHHHHHH.",
            ".HHHHHHHHHHHHHH.",
            ".HHHhHHHHHHhHHH.",
            ".HHHHHHHHHHHHHH.",
            ".HHHHHHHHHHHHHH.",
            ".HHHHHHHHHHHHHH.",
            ".HhHHHHHHHHHHhH.",
            ".hHHhHHHHHHhHHh.",
            "..h.hh.hh.hh.h..",
        ]
        case (.longStraight, .side): return [
            "......Hh........",
            ".....hHHHHh.....",
            "...hHHHLLHHh....",
            "..hHHHLLHHHHh...",
            ".hHHHHHHHHHHHh..",
            ".HHHHHHHHHHHHHh.",
            ".HHHHHHHHHh.hHh.",
            ".HHHHHHH........",
            ".HHHHHH.........",
            ".HHHHH..........",
            ".HHHHH..........",
            ".HHHHH..........",
            ".HHhHH..........",
            ".HHHHH..........",
            ".HHHHH..........",
            ".hHHHh..........",
            ".hHHh...........",
        ]
        case (.messy, .down): return [
            "...h.hHh.Hh.h...",
            "..hHhHHHhHHhHh..",
            ".hHHHHLLHHHHHHh.",
            ".HHGGGHHHHGGGHH.",
            "hHGgggGGGGgggGHh",
            ".HHGGGhHHhGGGHH.",
            ".HHhH.HhhH.HhHH.",
            ".Hh..........hH.",
            ".h............h.",
        ]
        case (.messy, .up): return [
            "...h.hHh.Hh.h...",
            "..hHhHHHhHHhHh..",
            ".hHHHHLLHHHHHHh.",
            ".HHHHHHHHHHHHHH.",
            "hHGGGGGGGGGGGGHh",
            ".HHHHHHHHHHHHHH.",
            "hHHHHHHHHHHHHHHh",
            ".HHhHHHHHHHHhHH.",
            ".hH.hHHHHHHh.Hh.",
            "..h..h.hh.h..h..",
        ]
        case (.messy, .side): return [
            "....h.hHh.h.....",
            "..hHhHHHhHHh....",
            ".hHHHHLLHHHHh...",
            ".HHHHHHHHGGGGh..",
            "hHHGGGGGGGgggG..",
            ".HHHHHHHHhGGGHh.",
            ".HHHHHHHh.H.h...",
            ".hHHHHHh........",
            "..hHHh..........",
        ]
        }
    }

    // MARK: Palettes

    static func palette(_ p: Persona) -> [Character: PixelColor] {
        let skin = PixelColor(p.skin), hair = PixelColor(p.hair), outfit = PixelColor(p.outfit), accent = PixelColor(p.outfitAccent)
        return [
            "S": skin, "s": skin.darker(0.22),
            "H": hair, "h": PixelColor(p.hairShade), "L": hair.lighter(0.45),
            "K": PixelColor(0x2A1A33), "W": PixelColor(0xFFFFFF),
            "e": PixelColor(p.eye), "l": PixelColor(p.eye).lighter(0.45),
            "B": PixelColor(0xFF8FA3), "M": PixelColor(0xA8405A), "R": PixelColor(0xC23B57), "r": PixelColor(0xFF8FA3),
            "C": outfit, "c": outfit.darker(0.28),
            "A": accent, "a": accent.darker(0.3),
            "P": outfit.darker(0.55), "F": accent.darker(0.35),
            "G": PixelColor(0x6B4F2F), "g": PixelColor(0x7FE3FF),
        ]
    }

    // MARK: Composition

    private static var cache: [String: SKTexture] = [:]

    /// One animation frame. `step`: 0 stand, 1/2 walk.
    static func frame(_ p: Persona, facing f: Facing, step: Int, expression e: Expression) -> SKTexture {
        let key = "\(p.id)-\(f)-\(step)-\(e)"
        if let t = cache[key] { return t }
        let c = PixelCanvas(frameW, frameH)
        let pal = palette(p)
        let head: [String], body: [String], legs: [[String]]
        switch f {
        case .down: head = downHead; body = downBody; legs = downLegs
        case .up: head = upHead; body = upBody; legs = downLegs
        case .side: head = sideHead; body = sideBody; legs = sideLegs
        }
        // Long hair in back view sits over the body, so body first.
        c.draw(legs[step], at: ox, oy + 21, palette: pal)
        c.draw(body, at: ox, oy + 13, palette: pal)
        c.draw(head, at: ox, oy, palette: pal)
        if f != .up { applyExpression(e, c, facing: f, pal: pal) }
        if p.accessory == .glasses, f != .up { glasses(c, facing: f) }
        c.draw(hair(p.hairStyle, f), at: ox, oy, palette: pal)
        c.outline()
        let t = c.texture()
        cache[key] = t
        return t
    }

    private static func applyExpression(_ e: Expression, _ c: PixelCanvas, facing f: Facing, pal: [Character: PixelColor]) {
        let eyes = f == .down ? [4, 10] : [10]
        let skin = pal["S"]!, ink = pal["K"]!
        let mouth: (Int, Int) = f == .down ? (7, 10) : (11, 11)
        func px(_ x: Int, _ y: Int, _ col: PixelColor) { c.set(ox + x, oy + y, col) }
        switch e {
        case .normal: break
        case .blink, .happy:
            for x in eyes {
                for dx in 0...1 { px(x + dx, 7, skin); px(x + dx, 8, ink); px(x + dx, 9, skin) }
            }
            if e == .happy {
                // Little ^ ^ arch and an open smile
                for x in eyes { px(x, 8, skin); px(x, 9, ink); px(x + 1, 8, ink); px(x + 1, 9, skin) }
                if f == .down { px(7, 10, pal["R"]!); px(8, 10, pal["R"]!); px(7, 11, pal["r"]!); px(8, 11, pal["R"]!) }
                else { px(11, 11, pal["R"]!); px(12, 11, pal["R"]!) }
            }
        case .focused:
            for x in eyes { for dx in 0...1 { px(x + dx, 8, ink) } }
        case .surprised:
            for x in eyes { px(x, 8, pal["W"]!); px(x + 1, 8, pal["W"]!); px(x, 9, pal["e"]!); px(x + 1, 9, pal["e"]!) }
            px(mouth.0, mouth.1, pal["M"]!); px(mouth.0, mouth.1 + 1, pal["M"]!)
            if f == .down { px(8, 10, skin) }
        case .sad:
            if f == .down { px(7, 10, skin); px(8, 10, skin); px(7, 11, pal["M"]!); px(8, 11, pal["M"]!) }
            px(eyes[0] - 1, 10, pal["l"]!)
        }
    }

    private static func glasses(_ c: PixelCanvas, facing f: Facing) {
        let frame = PixelColor(0x3B2E5A)
        let eyes = f == .down ? [4, 10] : [10]
        for x in eyes {
            c.set(ox + x - 1, oy + 7, frame); c.set(ox + x + 2, oy + 7, frame)
            c.set(ox + x - 1, oy + 8, frame); c.set(ox + x + 2, oy + 8, frame)
            c.set(ox + x - 1, oy + 9, frame); c.set(ox + x + 2, oy + 9, frame)
            c.set(ox + x, oy + 10, frame); c.set(ox + x + 1, oy + 10, frame)
        }
        if f == .down { c.set(ox + 7, oy + 7, frame); c.set(ox + 8, oy + 7, frame) }
    }

    // MARK: Held props (8x8)

    static func prop(_ prop: HeldProp) -> SKTexture {
        let key = "prop-\(prop)"
        if let t = cache[key] { return t }
        let c = PixelCanvas(12, 12)
        let pal: [Character: PixelColor] = [
            "w": PixelColor(0xFFF8EC), "x": PixelColor(0xE3D3C0), "r": PixelColor(0xE8366E),
            "b": PixelColor(0x8B5A2B), "m": PixelColor(0xB8C2D3), "M": PixelColor(0x7A8499),
            "p": PixelColor(0x7E3FB3), "P": PixelColor(0x5A2A86), "y": PixelColor(0xF5D76E),
            "k": PixelColor(0x1E2433), "c": PixelColor(0x5CF2FF), "C": PixelColor(0xB8FAFF),
        ]
        let rows: [String]
        switch prop {
        case .letter: rows = ["........", "wwwwwwww", "wxwwwwxw", "wwxwwxww", "wwwrrwww", "wwwrrwww", "xxxxxxxx", "........"]
        case .hammer: rows = ["mmmmmm..", "mMmmmM..", "MMMMMM..", "..bb....", "..bb....", "..bb....", "..bb....", "..bb...."]
        case .book: rows = ["pppppppp", "pPyyyyPp", "pPywwyPp", "pPyyyyPp", "pPPPPPPp", "pwwwwwwp", "pppppppp", "........"]
        case .tablet: rows = ["kkkkkkkk", "kccCcccc", "kcCccCck", "kccccCck", "kcCcCccc", "kkkkkkkk", "........", "........"]
        }
        c.draw(rows, at: 2, 2, palette: pal)
        c.outline()
        let t = c.texture()
        cache[key] = t
        return t
    }
}
