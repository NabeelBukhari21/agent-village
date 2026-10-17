import RealityKit
import CoreGraphics
import simd

/// Materials and primitive builders for the cel-shaded, toy-like look.
@MainActor
enum Toon {
    nonisolated static let ink: UInt32 = 0x2A1A33

    static func mat(_ hex: UInt32, rough: Float = 0.75, glow: Float = 0.12, metal: Float = 0) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: PlatformColor(hex: hex))
        m.roughness = .init(floatLiteral: rough)
        m.metallic = .init(floatLiteral: metal)
        m.emissiveColor = .init(color: PlatformColor(hex: hex))
        m.emissiveIntensity = glow
        return m
    }

    static func unlit(_ hex: UInt32, alpha: Float = 1) -> UnlitMaterial {
        var m = UnlitMaterial(color: PlatformColor(hex: hex))
        if alpha < 1 { m.blending = .transparent(opacity: .init(floatLiteral: alpha)) }
        return m
    }

    /// Inverted-hull outline: drawn on back faces only, slightly larger than the mesh.
    static func outline(_ hex: UInt32 = ink) -> UnlitMaterial {
        var m = UnlitMaterial(color: PlatformColor(hex: hex))
        m.faceCulling = .front
        return m
    }

    static func textured(_ texture: TextureResource, transparent: Bool = true, tint: PlatformColor = .white) -> UnlitMaterial {
        var m = UnlitMaterial()
        m.color = .init(tint: tint, texture: .init(texture))
        if transparent { m.blending = .transparent(opacity: .init(floatLiteral: 1)) }
        return m
    }

    static func texture(_ image: CGImage) -> TextureResource? {
        try? TextureResource(image: image, options: .init(semantic: .color))
    }

    // MARK: Mesh cache

    private static var meshes: [String: MeshResource] = [:]

    static func mesh(_ key: String, _ make: () -> MeshResource) -> MeshResource {
        if let m = meshes[key] { return m }
        let m = make()
        meshes[key] = m
        return m
    }

    static func sphere(_ r: Float) -> MeshResource { mesh("s\(r)") { .generateSphere(radius: r) } }
    static func box(_ w: Float, _ h: Float, _ d: Float, r: Float = 0) -> MeshResource {
        mesh("b\(w)-\(h)-\(d)-\(r)") { .generateBox(width: w, height: h, depth: d, cornerRadius: r) }
    }
    static func cylinder(_ h: Float, _ r: Float) -> MeshResource { mesh("c\(h)-\(r)") { .generateCylinder(height: h, radius: r) } }
    static func cone(_ h: Float, _ r: Float) -> MeshResource { mesh("k\(h)-\(r)") { .generateCone(height: h, radius: r) } }
    static func plane(_ w: Float, _ d: Float) -> MeshResource { mesh("p\(w)-\(d)") { .generatePlane(width: w, depth: d) } }

    /// A model part with an optional ink outline.
    @discardableResult
    static func part(
        _ mesh: MeshResource,
        _ material: some Material,
        at position: SIMD3<Float> = .zero,
        scale: SIMD3<Float> = .one,
        rotation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0]),
        outline: Float = 0,
        outlineColor: UInt32 = ink,
        in parent: Entity? = nil
    ) -> ModelEntity {
        let e = ModelEntity(mesh: mesh, materials: [material])
        e.position = position
        e.scale = scale
        e.orientation = rotation
        if outline > 0 {
            let o = ModelEntity(mesh: mesh, materials: [Toon.outline(outlineColor)])
            o.scale = .init(repeating: 1 + outline)
            e.addChild(o)
        }
        parent?.addChild(e)
        return e
    }
}

extension simd_quatf {
    static func yaw(_ a: Float) -> simd_quatf { simd_quatf(angle: a, axis: [0, 1, 0]) }
    static func pitch(_ a: Float) -> simd_quatf { simd_quatf(angle: a, axis: [1, 0, 0]) }
    static func roll(_ a: Float) -> simd_quatf { simd_quatf(angle: a, axis: [0, 0, 1]) }
    static func pointing(_ dir: SIMD3<Float>) -> simd_quatf { simd_quatf(from: [0, 1, 0], to: simd_normalize(dir)) }
}

/// Deterministic random numbers so the village looks the same every launch.
struct SeededRandom {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> Float {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Float(state >> 40) / Float(1 << 24)
    }
    mutating func range(_ a: Float, _ b: Float) -> Float { a + (b - a) * next() }
}
