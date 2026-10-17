import SwiftUI
import simd

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformColor = UIColor
#endif

extension PlatformColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension CGColor {
    static func hex(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Small math helpers

func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }

func lerpAngle(_ a: Float, _ b: Float, _ t: Float) -> Float {
    var d = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
    if d > .pi { d -= 2 * .pi }
    if d < -.pi { d += 2 * .pi }
    return a + d * t
}

func smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
    let t = simd_clamp((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)
}

extension SIMD3 where Scalar == Float {
    var xz: SIMD2<Float> { SIMD2(x, z) }
    static func onGround(_ x: Float, _ z: Float) -> SIMD3<Float> { SIMD3(x, 0, z) }
}

func polar(_ angleDegrees: Float, _ radius: Float) -> SIMD3<Float> {
    let a = angleDegrees * .pi / 180
    return SIMD3(sin(a) * radius, 0, cos(a) * radius)
}
