import CoreGraphics
import Foundation

/// Hand-drawn (in code) 2D art: anime faces, portraits, glow rings and skies.
enum FaceArt {
    static let faceSize = CGSize(width: 512, height: 410)

    static func context(_ w: Int, _ h: Int) -> CGContext {
        let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high
        return ctx
    }

    // MARK: Faces

    /// Face decal: eyes, brows, blush and mouth on a transparent background.
    /// Laid out so the head's center is the image center and the head radius is ~341px.
    static func face(_ p: Persona, _ e: Expression) -> CGImage {
        let ctx = context(Int(faceSize.width), Int(faceSize.height))
        drawFace(ctx, p, e, center: CGPoint(x: 256, y: 205), unit: 341)
        return ctx.makeImage()!
    }

    /// Draws a face where `unit` is the head radius in pixels (CG coordinates, y up).
    static func drawFace(_ ctx: CGContext, _ p: Persona, _ e: Expression, center c: CGPoint, unit R: CGFloat) {
        let eyeY = c.y - 0.06 * R
        let eyeDX = 0.36 * R
        let eyeW = 0.27 * R, eyeH = 0.37 * R

        // Blush
        for s: CGFloat in [-1, 1] {
            let bc = CGPoint(x: c.x + s * 0.56 * R, y: c.y - 0.3 * R)
            let g = CGGradient(colorsSpace: nil, colors: [CGColor.hex(0xFF6F91, alpha: 0.55), CGColor.hex(0xFF6F91, alpha: 0)] as CFArray, locations: [0, 1])!
            ctx.saveGState()
            ctx.translateBy(x: bc.x, y: bc.y)
            ctx.scaleBy(x: 1.6, y: 0.75)
            ctx.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 0.13 * R, options: [])
            ctx.restoreGState()
            // Little blush hatch lines
            ctx.setStrokeColor(CGColor.hex(0xF0507A, alpha: 0.6))
            ctx.setLineWidth(0.018 * R)
            ctx.setLineCap(.round)
            for i in 0..<3 {
                let x = bc.x - 0.07 * R + CGFloat(i) * 0.07 * R
                ctx.move(to: CGPoint(x: x, y: bc.y - 0.03 * R))
                ctx.addLine(to: CGPoint(x: x + 0.04 * R, y: bc.y + 0.03 * R))
            }
            ctx.strokePath()
        }

        // Eyes
        for s: CGFloat in [-1, 1] {
            let ec = CGPoint(x: c.x + s * eyeDX, y: eyeY)
            switch e {
            case .blink:
                closedEye(ctx, ec, eyeW, R, happy: false)
            case .happy:
                closedEye(ctx, ec, eyeW, R, happy: true)
            case .focused:
                openEye(ctx, p, ec, eyeW, eyeH * 0.92, R, side: s, lid: 0.62)
            case .surprised:
                openEye(ctx, p, ec, eyeW * 1.05, eyeH * 1.08, R, side: s, lid: 1, smallPupil: true)
            case .sad:
                openEye(ctx, p, ec, eyeW, eyeH, R, side: s, lid: 0.85)
            case .normal:
                openEye(ctx, p, ec, eyeW, eyeH, R, side: s, lid: 1)
            }
            brow(ctx, ec, eyeW, eyeH, R, side: s, e: e)
        }

        if p.accessory == .glasses { glasses(ctx, c, eyeDX, eyeY, eyeW, eyeH, R) }
        mouth(ctx, CGPoint(x: c.x, y: c.y - 0.4 * R), R, e)
    }

    private static func openEye(_ ctx: CGContext, _ p: Persona, _ c: CGPoint, _ w: CGFloat, _ h: CGFloat, _ R: CGFloat, side: CGFloat, lid: CGFloat, smallPupil: Bool = false) {
        let rect = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
        ctx.saveGState()
        // Clip the top of the eye for a heavy-lidded look.
        let visibleTop = rect.minY + h * lid
        ctx.clip(to: CGRect(x: rect.minX - 20, y: rect.minY - 20, width: w + 40, height: visibleTop - rect.minY + 20))

        // White of the eye
        ctx.setFillColor(CGColor.hex(0xFFFFFF))
        ctx.fillEllipse(in: rect.insetBy(dx: -0.05 * w, dy: -0.02 * h))

        // Iris gradient: dark at top, bright at the bottom.
        ctx.saveGState()
        ctx.addEllipse(in: rect)
        ctx.clip()
        let top = darken(p.eye, 0.45), bottom = lighten(p.eye, 0.35)
        let g = CGGradient(colorsSpace: nil, colors: [CGColor.hex(bottom), CGColor.hex(p.eye), CGColor.hex(top)] as CFArray, locations: [0, 0.45, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: c.x, y: rect.minY), end: CGPoint(x: c.x, y: rect.maxY), options: [])
        // Bottom glow arc
        ctx.setFillColor(CGColor.hex(lighten(p.eye, 0.65), alpha: 0.75))
        ctx.fillEllipse(in: CGRect(x: c.x - w * 0.32, y: rect.minY + h * 0.06, width: w * 0.64, height: h * 0.28))
        // Pupil
        let ps: CGFloat = smallPupil ? 0.22 : 0.42
        ctx.setFillColor(CGColor.hex(darken(p.eye, 0.75)))
        ctx.fillEllipse(in: CGRect(x: c.x - w * ps / 2, y: c.y - h * ps * 0.45, width: w * ps, height: h * ps * 1.15))
        ctx.restoreGState()

        // Iris outline
        ctx.setStrokeColor(CGColor.hex(darken(p.eye, 0.7)))
        ctx.setLineWidth(0.012 * R)
        ctx.strokeEllipse(in: rect)

        // Highlights
        ctx.setFillColor(CGColor.hex(0xFFFFFF))
        ctx.fillEllipse(in: CGRect(x: c.x - side * w * 0.12 - w * 0.17, y: c.y + h * 0.06, width: w * 0.34, height: h * 0.3))
        ctx.fillEllipse(in: CGRect(x: c.x + side * w * 0.2 - w * 0.07, y: c.y - h * 0.28, width: w * 0.14, height: h * 0.12))
        ctx.setFillColor(CGColor.hex(0xFFFFFF, alpha: 0.8))
        ctx.fillEllipse(in: CGRect(x: c.x + side * w * 0.05 - w * 0.04, y: c.y - h * 0.05, width: w * 0.08, height: h * 0.07))
        ctx.restoreGState()

        // Upper lash line, thick with a flick at the outer corner.
        let lashY = visibleTop - h * 0.02
        let outer = CGPoint(x: c.x + side * w * 0.62, y: lashY - h * 0.02)
        let inner = CGPoint(x: c.x - side * w * 0.5, y: lashY - h * 0.12)
        ctx.setFillColor(CGColor.hex(0x2A1A33))
        ctx.move(to: inner)
        ctx.addQuadCurve(to: outer, control: CGPoint(x: c.x, y: lashY + h * (lid < 1 ? 0.02 : 0.14)))
        ctx.addLine(to: CGPoint(x: outer.x + side * w * 0.12, y: outer.y + h * 0.1))
        ctx.addLine(to: CGPoint(x: outer.x - side * w * 0.02, y: outer.y - h * 0.08))
        ctx.addQuadCurve(to: CGPoint(x: inner.x, y: inner.y - h * 0.06), control: CGPoint(x: c.x, y: lashY + h * (lid < 1 ? -0.07 : 0.04)))
        ctx.closePath()
        ctx.fillPath()

        // Lower lash hint
        ctx.setStrokeColor(CGColor.hex(0x2A1A33, alpha: 0.7))
        ctx.setLineWidth(0.012 * R)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: c.x + side * w * 0.42, y: rect.minY + h * 0.12))
        ctx.addQuadCurve(to: CGPoint(x: c.x + side * w * 0.08, y: rect.minY - h * 0.02), control: CGPoint(x: c.x + side * w * 0.3, y: rect.minY))
        ctx.strokePath()
    }

    private static func closedEye(_ ctx: CGContext, _ c: CGPoint, _ w: CGFloat, _ R: CGFloat, happy: Bool) {
        ctx.setStrokeColor(CGColor.hex(0x2A1A33))
        ctx.setLineWidth(0.04 * R)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: c.x - w * 0.55, y: c.y))
        let bend: CGFloat = happy ? 0.45 : -0.28
        ctx.addQuadCurve(to: CGPoint(x: c.x + w * 0.55, y: c.y), control: CGPoint(x: c.x, y: c.y + w * bend))
        ctx.strokePath()
    }

    private static func brow(_ ctx: CGContext, _ c: CGPoint, _ w: CGFloat, _ h: CGFloat, _ R: CGFloat, side: CGFloat, e: Expression) {
        let y = c.y + h * 0.78
        var innerLift: CGFloat = 0
        switch e {
        case .sad: innerLift = 0.1 * R
        case .focused: innerLift = -0.05 * R
        case .surprised: innerLift = 0.05 * R
        default: break
        }
        ctx.setStrokeColor(CGColor.hex(0x3A2440, alpha: 0.85))
        ctx.setLineWidth(0.022 * R)
        ctx.setLineCap(.round)
        let lift: CGFloat = e == .surprised ? 0.06 * R : 0
        ctx.move(to: CGPoint(x: c.x + side * w * 0.5, y: y + lift))
        ctx.addQuadCurve(to: CGPoint(x: c.x - side * w * 0.45, y: y + innerLift + lift), control: CGPoint(x: c.x, y: y + 0.05 * R + lift))
        ctx.strokePath()
    }

    private static func glasses(_ ctx: CGContext, _ c: CGPoint, _ dx: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ R: CGFloat) {
        ctx.setStrokeColor(CGColor.hex(0x3B2E5A))
        ctx.setLineWidth(0.025 * R)
        for s: CGFloat in [-1, 1] {
            ctx.strokeEllipse(in: CGRect(x: c.x + s * dx - w * 0.8, y: y - h * 0.62, width: w * 1.6, height: h * 1.25))
            ctx.setFillColor(CGColor.hex(0xFFFFFF, alpha: 0.12))
            ctx.fillEllipse(in: CGRect(x: c.x + s * dx - w * 0.8, y: y - h * 0.62, width: w * 1.6, height: h * 1.25))
        }
        ctx.move(to: CGPoint(x: c.x - dx + w * 0.8, y: y + h * 0.1))
        ctx.addQuadCurve(to: CGPoint(x: c.x + dx - w * 0.8, y: y + h * 0.1), control: CGPoint(x: c.x, y: y + h * 0.25))
        ctx.strokePath()
    }

    private static func mouth(_ ctx: CGContext, _ m: CGPoint, _ R: CGFloat, _ e: Expression) {
        ctx.setStrokeColor(CGColor.hex(0x7A2E3A))
        ctx.setLineWidth(0.022 * R)
        ctx.setLineCap(.round)
        switch e {
        case .happy:
            ctx.setFillColor(CGColor.hex(0x8C2F45))
            ctx.move(to: CGPoint(x: m.x - 0.09 * R, y: m.y + 0.03 * R))
            ctx.addQuadCurve(to: CGPoint(x: m.x + 0.09 * R, y: m.y + 0.03 * R), control: CGPoint(x: m.x, y: m.y - 0.17 * R))
            ctx.closePath()
            ctx.fillPath()
            ctx.setFillColor(CGColor.hex(0xFF8FA3))
            ctx.fillEllipse(in: CGRect(x: m.x - 0.045 * R, y: m.y - 0.08 * R, width: 0.09 * R, height: 0.05 * R))
        case .surprised:
            ctx.setFillColor(CGColor.hex(0x8C2F45))
            ctx.fillEllipse(in: CGRect(x: m.x - 0.035 * R, y: m.y - 0.05 * R, width: 0.07 * R, height: 0.09 * R))
        case .sad:
            ctx.move(to: CGPoint(x: m.x - 0.06 * R, y: m.y - 0.02 * R))
            ctx.addQuadCurve(to: CGPoint(x: m.x + 0.06 * R, y: m.y - 0.02 * R), control: CGPoint(x: m.x, y: m.y + 0.04 * R))
            ctx.strokePath()
        case .focused:
            ctx.move(to: CGPoint(x: m.x - 0.045 * R, y: m.y))
            ctx.addLine(to: CGPoint(x: m.x + 0.045 * R, y: m.y - 0.005 * R))
            ctx.strokePath()
        default:
            // Cat-like "w" smile
            ctx.move(to: CGPoint(x: m.x - 0.08 * R, y: m.y + 0.02 * R))
            ctx.addQuadCurve(to: CGPoint(x: m.x, y: m.y + 0.01 * R), control: CGPoint(x: m.x - 0.04 * R, y: m.y - 0.05 * R))
            ctx.addQuadCurve(to: CGPoint(x: m.x + 0.08 * R, y: m.y + 0.02 * R), control: CGPoint(x: m.x + 0.04 * R, y: m.y - 0.05 * R))
            ctx.strokePath()
        }
    }

    // MARK: Portrait (2D bust for the HUD and dialogue box)

    static func portrait(_ p: Persona, _ e: Expression = .normal, size: Int = 320) -> CGImage {
        let S = CGFloat(size)
        let ctx = context(size, size)
        let R = S * 0.3
        let c = CGPoint(x: S / 2, y: S * 0.52)
        let ink = CGColor.hex(0x2A1A33)
        ctx.setLineJoin(.round)

        func fillStroke(_ path: CGPath, _ color: UInt32, width: CGFloat = S * 0.012) {
            ctx.addPath(path); ctx.setFillColor(CGColor.hex(color)); ctx.fillPath()
            ctx.addPath(path); ctx.setStrokeColor(ink); ctx.setLineWidth(width); ctx.strokePath()
        }
        func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
            CGPath(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2), transform: nil)
        }

        // Back hair
        switch p.hairStyle {
        case .longStraight:
            let path = CGMutablePath()
            path.addRoundedRect(in: CGRect(x: c.x - R * 1.15, y: 0, width: R * 2.3, height: c.y + R * 0.3), cornerWidth: R * 0.5, cornerHeight: R * 0.5)
            fillStroke(path, p.hairShade)
        case .twinTails:
            for s: CGFloat in [-1, 1] {
                fillStroke(ellipse(c.x + s * R * 1.3, c.y - R * 0.55, R * 0.42, R * 1.05), p.hair)
            }
        default: break
        }
        fillStroke(ellipse(c.x, c.y + R * 0.08, R * 1.1, R * 1.08), p.hairShade)

        // Shoulders
        let body = CGMutablePath()
        body.move(to: CGPoint(x: c.x - R * 1.15, y: 0))
        body.addQuadCurve(to: CGPoint(x: c.x + R * 1.15, y: 0), control: CGPoint(x: c.x, y: c.y - R * 0.2))
        body.closeSubpath()
        fillStroke(body, p.outfit)
        let collar = CGMutablePath()
        collar.move(to: CGPoint(x: c.x - R * 0.35, y: c.y - R * 0.95))
        collar.addLine(to: CGPoint(x: c.x, y: c.y - R * 1.35))
        collar.addLine(to: CGPoint(x: c.x + R * 0.35, y: c.y - R * 0.95))
        collar.closeSubpath()
        fillStroke(collar, p.outfitAccent)

        // Face
        fillStroke(ellipse(c.x, c.y, R, R * 0.98), p.skin)
        drawFace(ctx, p, e, center: c, unit: R)

        // Bangs
        let bangs = CGMutablePath()
        let n = p.hairStyle == .spiky ? 6 : 5
        bangs.move(to: CGPoint(x: c.x - R * 1.06, y: c.y + R * 0.05))
        bangs.addQuadCurve(to: CGPoint(x: c.x + R * 1.06, y: c.y + R * 0.05), control: CGPoint(x: c.x, y: c.y + R * 1.75))
        for i in (0...n).reversed() {
            let t = CGFloat(i) / CGFloat(n)
            let x = c.x - R * 1.06 + t * R * 2.12
            let tipY = c.y + R * (0.18 + 0.12 * abs(t - 0.5) * 2)
            if i < n {
                let mid = x + R * 2.12 / CGFloat(n) / 2
                bangs.addQuadCurve(to: CGPoint(x: x, y: c.y + R * 0.62), control: CGPoint(x: mid, y: tipY))
            }
            bangs.addLine(to: CGPoint(x: x, y: c.y + R * 0.62))
        }
        bangs.closeSubpath()
        fillStroke(bangs, p.hair)

        // Spikes / volume on top
        if p.hairStyle == .spiky || p.hairStyle == .messy {
            for i in 0..<5 {
                let a = CGFloat.pi * (0.2 + 0.15 * CGFloat(i))
                let base = CGPoint(x: c.x + cos(a) * R * 0.9, y: c.y + sin(a) * R * 0.9)
                let tip = CGPoint(x: c.x + cos(a) * R * (p.hairStyle == .spiky ? 1.55 : 1.3), y: c.y + sin(a) * R * (p.hairStyle == .spiky ? 1.55 : 1.3))
                let spike = CGMutablePath()
                spike.move(to: CGPoint(x: base.x - sin(a) * R * 0.25, y: base.y + cos(a) * R * 0.25))
                spike.addLine(to: tip)
                spike.addLine(to: CGPoint(x: base.x + sin(a) * R * 0.25, y: base.y - cos(a) * R * 0.25))
                spike.closeSubpath()
                fillStroke(spike, p.hair)
            }
        }
        // Shine band on the hair
        ctx.setStrokeColor(CGColor.hex(0xFFFFFF, alpha: 0.55))
        ctx.setLineWidth(S * 0.018)
        ctx.setLineCap(.round)
        ctx.addArc(center: CGPoint(x: c.x, y: c.y + R * 0.1), radius: R * 0.82, startAngle: .pi * 0.62, endAngle: .pi * 0.78, clockwise: false)
        ctx.strokePath()

        // Accessories
        switch p.accessory {
        case .ribbon:
            for s: CGFloat in [-1, 1] {
                fillStroke(ellipse(c.x + R * 0.62 + s * R * 0.25, c.y + R * 0.98, R * 0.24, R * 0.16), p.outfitAccent)
            }
            fillStroke(ellipse(c.x + R * 0.62, c.y + R * 0.98, R * 0.09, R * 0.09), darken(p.outfitAccent, 0.2))
        case .headband:
            let band = CGMutablePath()
            band.addRoundedRect(in: CGRect(x: c.x - R * 1.04, y: c.y + R * 0.55, width: R * 2.08, height: R * 0.2), cornerWidth: R * 0.08, cornerHeight: R * 0.08)
            fillStroke(band, p.outfitAccent)
            let plate = CGMutablePath()
            plate.addRoundedRect(in: CGRect(x: c.x - R * 0.28, y: c.y + R * 0.52, width: R * 0.56, height: R * 0.26), cornerWidth: R * 0.05, cornerHeight: R * 0.05)
            fillStroke(plate, 0xC9D3E0)
        case .goggles:
            for s: CGFloat in [-1, 1] {
                fillStroke(ellipse(c.x + s * R * 0.38, c.y + R * 0.78, R * 0.26, R * 0.2), 0x6B4F2F)
                fillStroke(ellipse(c.x + s * R * 0.38, c.y + R * 0.78, R * 0.18, R * 0.13), 0x7FE3FF)
            }
        case .glasses:
            break
        }
        return ctx.makeImage()!
    }

    // MARK: Effects textures

    /// A soft glowing ring for the aura disc under an agent's feet.
    static func auraRing(_ hex: UInt32) -> CGImage {
        let s = 256
        let ctx = context(s, s)
        let c = CGPoint(x: 128, y: 128)
        let g = CGGradient(colorsSpace: nil, colors: [
            CGColor.hex(hex, alpha: 0), CGColor.hex(hex, alpha: 0.25), CGColor.hex(0xFFFFFF, alpha: 0.95),
            CGColor.hex(hex, alpha: 0.6), CGColor.hex(hex, alpha: 0),
        ] as CFArray, locations: [0, 0.6, 0.78, 0.84, 1])!
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: 128, options: [])
        // Rune ticks around the ring
        ctx.setStrokeColor(CGColor.hex(0xFFFFFF, alpha: 0.85))
        ctx.setLineWidth(3)
        for i in 0..<12 {
            let a = CGFloat(i) / 12 * .pi * 2
            ctx.move(to: CGPoint(x: c.x + cos(a) * 88, y: c.y + sin(a) * 88))
            ctx.addLine(to: CGPoint(x: c.x + cos(a) * 96, y: c.y + sin(a) * 96))
        }
        ctx.strokePath()
        return ctx.makeImage()!
    }

    /// Vertical sky gradient with optional stars, sampled by the inside of the sky dome.
    static func sky(top: UInt32, horizon: UInt32, bottom: UInt32, stars: CGFloat) -> CGImage {
        let w = 256, h = 256
        let ctx = context(w, h)
        // Sphere UVs: v = 0 at the bottom pole in CG space (y up). Horizon sits at the middle.
        let g = CGGradient(colorsSpace: nil, colors: [
            CGColor.hex(bottom), CGColor.hex(horizon), CGColor.hex(horizon), CGColor.hex(top),
        ] as CFArray, locations: [0.0, 0.46, 0.53, 1.0])!
        ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: h), options: [])
        if stars > 0.01 {
            var rng = SeededRandom(7)
            for _ in 0..<180 {
                let x = CGFloat(rng.next()) * CGFloat(w)
                let y = CGFloat(h) * (0.56 + 0.44 * CGFloat(rng.next()))
                let r = CGFloat(rng.range(0.3, 1.1))
                ctx.setFillColor(CGColor.hex(0xFFFFFF, alpha: stars * CGFloat(rng.range(0.4, 1))))
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
        }
        return ctx.makeImage()!
    }

    /// Wide image used for image-based lighting (soft sky + warm ground bounce).
    static func lightingEnvironment() -> CGImage {
        let w = 512, h = 256
        let ctx = context(w, h)
        let g = CGGradient(colorsSpace: nil, colors: [
            CGColor.hex(0x8B7A6A), CGColor.hex(0xF5E6D8), CGColor.hex(0xFFF3F8), CGColor.hex(0xBFD8FF),
        ] as CFArray, locations: [0, 0.45, 0.55, 1])!
        ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: h), options: [])
        return ctx.makeImage()!
    }

    // MARK: Color helpers

    static func lighten(_ hex: UInt32, _ t: CGFloat) -> UInt32 { mix(hex, 0xFFFFFF, t) }
    static func darken(_ hex: UInt32, _ t: CGFloat) -> UInt32 { mix(hex, 0x000000, t) }

    static func mix(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> UInt32 {
        func ch(_ v: UInt32, _ s: UInt32) -> CGFloat { CGFloat((v >> s) & 0xFF) }
        func m(_ s: UInt32) -> UInt32 { UInt32(max(0, min(255, ch(a, s) + (ch(b, s) - ch(a, s)) * t))) }
        return (m(16) << 16) | (m(8) << 8) | m(0)
    }
}
