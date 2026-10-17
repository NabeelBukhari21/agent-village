import RealityKit
import simd

/// Builds the floating island, its buildings and ambient effects.
/// Holds references to everything that animates.
@MainActor
final class Island {
    let root = Entity()

    // Animated pieces
    var sky: ModelEntity!
    var skyTexture: TextureResource?
    let sun = Entity()
    let cloudRing = Entity()
    var floaters: [(Entity, Float)] = []
    var lanternLights: [PointLightComponent] = []
    var lanternEntities: [Entity] = []
    var windowEntities: [ModelEntity] = []
    let forgeFire = Entity()
    let forgeSparks = Entity()
    let chimneySmoke = Entity()
    let libraryBooks = Entity()
    var hologramBars: [ModelEntity] = []
    let hologram = Entity()
    let mailLetters = Entity()
    let questMarker = Entity()
    let petals = Entity()
    let fireflies = Entity()

    private var rng = SeededRandom(42)

    init() {
        buildSky()
        buildLighting()
        buildGround()
        buildPlaza()
        buildPostOffice()
        buildForge()
        buildLibrary()
        buildObservatory()
        buildQuestBoard()
        buildTorii()
        buildNature()
        buildClouds()
        buildEffects()
    }

    // MARK: Sky & light

    private func buildSky() {
        let img = FaceArt.sky(top: 0x6FA8FF, horizon: 0xFFD9E8, bottom: 0xB9C7FF, stars: 0)
        skyTexture = Toon.texture(img)
        var m = skyTexture.map { Toon.textured($0, transparent: false) } ?? Toon.unlit(0x9CC4FF)
        m.faceCulling = .front
        sky = ModelEntity(mesh: .generateSphere(radius: 140), materials: [m])
        root.addChild(sky)
    }

    private func buildLighting() {
        var light = DirectionalLightComponent(color: PlatformColor(hex: 0xFFF1E0), intensity: 2600)
        light.isRealWorldProxy = false
        sun.components.set(light)
        sun.components.set(DirectionalLightComponent.Shadow(maximumDistance: 40, depthBias: 3))
        sun.look(at: .zero, from: [8, 14, 10], relativeTo: nil)
        root.addChild(sun)
    }

    // MARK: Ground

    private func buildGround() {
        let R = VillageLayout.islandRadius
        // Grass top
        Toon.part(Toon.cylinder(0.5, R), Toon.mat(0x86D46B, rough: 0.95, glow: 0.18), at: [0, -0.25, 0], in: root)
        // Grass lip and dirt band
        Toon.part(Toon.cylinder(0.25, R + 0.12), Toon.mat(0x5DB04F, rough: 1, glow: 0.12), at: [0, -0.45, 0], outline: 0.01, in: root)
        Toon.part(Toon.cylinder(0.7, R - 0.1), Toon.mat(0xA0754F, rough: 1, glow: 0.1), at: [0, -0.9, 0], in: root)
        // Rocky underside: stacked inverted cones
        let rock = Toon.mat(0x8C6B53, rough: 1, glow: 0.08)
        let rock2 = Toon.mat(0x6E5444, rough: 1, glow: 0.06)
        Toon.part(Toon.cone(7.5, R - 0.3), rock, at: [0, -4.95, 0], rotation: .pitch(.pi), outline: 0.012, in: root)
        for i in 0..<6 {
            let a = Float(i) * 60 + 20
            let p = polar(a, R * 0.55)
            Toon.part(Toon.cone(rng.range(3, 5), rng.range(2.2, 3.4)), i % 2 == 0 ? rock2 : rock,
                      at: [p.x, -2.4 - rng.range(0, 1.5), p.z], rotation: .pitch(.pi), outline: 0.015, in: root)
        }
        // Hanging crystals for some sparkle
        for i in 0..<5 {
            let p = polar(Float(i) * 72 + 5, rng.range(3, 7))
            Toon.part(Toon.cone(1.2, 0.25), Toon.mat(0x9FE8FF, rough: 0.1, glow: 0.9), at: [p.x, -3.5 - rng.range(0, 2), p.z],
                      rotation: .pitch(.pi) * .roll(rng.range(-0.3, 0.3)), outline: 0.06, in: root)
        }
    }

    private func buildPlaza() {
        let sand = Toon.mat(0xF2DFB4, rough: 1, glow: 0.18)
        // Ring path and inner lawn
        Toon.part(Toon.cylinder(0.04, VillageLayout.ringRadius + 0.75), sand, at: [0, 0.01, 0], in: root)
        Toon.part(Toon.cylinder(0.06, VillageLayout.ringRadius - 0.65), Toon.mat(0x95DD74, rough: 1, glow: 0.18), at: [0, 0.02, 0], in: root)
        // Radial paths to every station
        for s in StationKind.allCases {
            let len: Float = s == .questBoard ? 5.4 : s.buildingRadius - 1.6 - VillageLayout.ringRadius
            let mid = polar(s.angle, VillageLayout.ringRadius + len / 2 + 0.3)
            Toon.part(Toon.box(1.1, 0.04, len, r: 0.02), sand, at: [mid.x, 0.012, mid.z], rotation: .yaw(s.angle * .pi / 180), in: root)
            // Stepping stones
            for k in 0..<3 {
                let p = polar(s.angle + (k % 2 == 0 ? 6 : -6), VillageLayout.ringRadius + 1 + Float(k) * 0.9)
                Toon.part(Toon.cylinder(0.05, 0.16), Toon.mat(0xD8C9A8), at: [p.x, 0.03, p.z], in: root)
            }
        }

        // The great sakura tree
        let tree = Entity()
        root.addChild(tree)
        let bark = Toon.mat(0x7A4E3A, rough: 1, glow: 0.1)
        Toon.part(Toon.cylinder(2.8, 0.36), bark, at: [0, 1.4, 0], outline: 0.06, in: tree)
        for (a, tilt) in [(Float(0), Float(0.7)), (2.1, 0.8), (4.2, 0.65)] {
            Toon.part(Toon.cylinder(1.6, 0.14), bark, at: [sin(a) * 0.5, 2.6, cos(a) * 0.5],
                      rotation: .yaw(a) * .pitch(tilt), outline: 0.08, in: tree)
        }
        let pinks: [UInt32] = [0xFFB7D5, 0xFFA3C8, 0xFFC8E0, 0xFF92BD]
        for i in 0..<11 {
            let a = Float(i) / 11 * 2 * .pi
            let r = i == 0 ? 0 : rng.range(0.7, 1.5)
            Toon.part(Toon.sphere(rng.range(0.9, 1.35)), Toon.mat(pinks[i % pinks.count], rough: 0.9, glow: 0.3),
                      at: [sin(a) * r, 3.3 + rng.range(-0.3, 0.6), cos(a) * r], outline: 0.035, outlineColor: 0xB84A7A, in: tree)
        }
        // Stone ring around the trunk
        for i in 0..<10 {
            let p = polar(Float(i) * 36, 0.85)
            Toon.part(Toon.sphere(0.18), Toon.mat(0xC9C2B8), at: [p.x, 0.08, p.z], scale: [1, 0.6, 1], in: tree)
        }

        // Benches at the rest spots
        for a in VillageLayout.restAngles {
            let p = polar(a, VillageLayout.ringRadius + 1.15)
            let bench = Entity()
            bench.position = p
            bench.orientation = .yaw(a * .pi / 180)
            root.addChild(bench)
            let wood = Toon.mat(0xB5784A)
            Toon.part(Toon.box(0.9, 0.08, 0.32, r: 0.03), wood, at: [0, 0.3, 0], outline: 0.04, in: bench)
            Toon.part(Toon.box(0.9, 0.25, 0.06, r: 0.03), wood, at: [0, 0.5, -0.15], outline: 0.04, in: bench)
            for s: Float in [-1, 1] { Toon.part(Toon.box(0.07, 0.3, 0.28), Toon.mat(0x5A4A42), at: [s * 0.38, 0.15, 0], in: bench) }
        }

        // Stone lanterns along the ring
        for (i, a) in [Float(24), 88, 150, 205, 268, 335].enumerated() {
            lantern(at: polar(a, VillageLayout.ringRadius + 0.95), light: i % 2 == 0)
        }
    }

    private func lantern(at p: SIMD3<Float>, light: Bool) {
        let l = Entity()
        l.position = p
        root.addChild(l)
        let stone = Toon.mat(0xB8B2A8, rough: 1)
        Toon.part(Toon.box(0.34, 0.12, 0.34, r: 0.03), stone, at: [0, 0.06, 0], outline: 0.05, in: l)
        Toon.part(Toon.cylinder(0.5, 0.07), stone, at: [0, 0.37, 0], in: l)
        let lamp = Toon.part(Toon.box(0.3, 0.26, 0.3, r: 0.04), Toon.mat(0xFFD27A, rough: 0.4, glow: 1.2), at: [0, 0.75, 0], outline: 0.05, in: l)
        Toon.part(Toon.cone(0.22, 0.3), Toon.mat(0x7E7468), at: [0, 1.0, 0], outline: 0.05, in: l)
        windowEntities.append(lamp)
        if light {
            var pl = PointLightComponent(color: PlatformColor(hex: 0xFFB866), intensity: 0, attenuationRadius: 4)
            pl.attenuationFalloffExponent = 2
            lamp.components.set(pl)
            lanternEntities.append(lamp)
        }
    }

    // MARK: Buildings

    /// A building root at a station, rotated so its front (+z) faces the plaza.
    private func site(_ s: StationKind) -> Entity {
        let e = Entity()
        e.position = polar(s.angle, s.buildingRadius)
        e.orientation = .yaw(s.angle * .pi / 180 + .pi)
        root.addChild(e)
        return e
    }

    private func window(_ at: SIMD3<Float>, in parent: Entity, w: Float = 0.42, h: Float = 0.5) {
        Toon.part(Toon.box(w + 0.1, h + 0.1, 0.05, r: 0.02), Toon.mat(0x5A3E2E), at: at - [0, 0, 0.01], in: parent)
        let glass = Toon.part(Toon.box(w, h, 0.06, r: 0.02), Toon.mat(0xFFE7A8, rough: 0.3, glow: 0.4), at: at, in: parent)
        windowEntities.append(glass)
    }

    private func door(_ at: SIMD3<Float>, in parent: Entity, color: UInt32 = 0x7A4B33) {
        Toon.part(Toon.box(0.62, 0.95, 0.08, r: 0.06), Toon.mat(color), at: at, outline: 0.03, in: parent)
        Toon.part(Toon.sphere(0.04), Toon.mat(0xF5D76E, glow: 0.6), at: at + [0.2, 0, 0.05], in: parent)
    }

    private func roof(_ parent: Entity, y: Float, radius: Float, height: Float, color: UInt32, squash: Float = 0.85) {
        Toon.part(Toon.cone(height, radius), Toon.mat(color, rough: 0.6, glow: 0.18), at: [0, y + height / 2, 0],
                  scale: [1, 1, squash], outline: 0.025, in: parent)
        Toon.part(Toon.sphere(0.12), Toon.mat(0xF5D76E, glow: 0.6), at: [0, y + height + 0.05, 0], in: parent)
    }

    private func buildPostOffice() {
        let b = site(.postOffice)
        Toon.part(Toon.box(2.6, 1.7, 2.0, r: 0.1), Toon.mat(0xFFF2E2, rough: 0.9, glow: 0.2), at: [0, 0.85, 0], outline: 0.015, in: b)
        Toon.part(Toon.box(2.75, 0.18, 2.15, r: 0.06), Toon.mat(0xE8366E), at: [0, 1.65, 0], outline: 0.02, in: b)
        roof(b, y: 1.7, radius: 1.95, height: 1.25, color: 0xFF6F91)
        door([0, 0.48, 1.0], in: b, color: 0xC2415F)
        window([-0.8, 1.0, 1.01], in: b)
        window([0.8, 1.0, 1.01], in: b)
        // Sign
        let sign = Toon.part(Toon.box(0.9, 0.4, 0.06, r: 0.05), Toon.mat(0xE8366E, glow: 0.3), at: [0, 1.95, 1.05], outline: 0.04, in: b)
        Toon.part(Toon.box(0.4, 0.26, 0.02, r: 0.01), Toon.mat(0xFFFFFF, glow: 0.6), at: [0, 0, 0.04], in: sign)
        // Red mailbox where letters are posted
        let box = Entity()
        box.position = [1.25, 0, 1.6]
        b.addChild(box)
        Toon.part(Toon.cylinder(0.75, 0.24), Toon.mat(0xE53950, rough: 0.5, glow: 0.2), at: [0, 0.38, 0], outline: 0.05, in: box)
        Toon.part(Toon.sphere(0.24), Toon.mat(0xE53950, rough: 0.5, glow: 0.2), at: [0, 0.76, 0], scale: [1, 0.6, 1], outline: 0.05, in: box)
        Toon.part(Toon.box(0.26, 0.04, 0.05), Toon.mat(0x2A1A33), at: [0, 0.6, 0.23], in: box)
        // Sorting table
        Toon.part(Toon.box(1.0, 0.08, 0.5, r: 0.02), Toon.mat(0xB5784A), at: [-0.2, 0.55, 1.65], outline: 0.04, in: b)
        for s: Float in [-1, 1] { Toon.part(Toon.box(0.06, 0.55, 0.4), Toon.mat(0x8B5A3C), at: [-0.2 + s * 0.42, 0.27, 1.65], in: b) }
        for i in 0..<5 {
            Toon.part(Toon.box(0.16, 0.012, 0.11), Toon.mat(i % 2 == 0 ? 0xFFF8EC : 0xFFE3EE), at: [-0.45 + Float(i) * 0.12, 0.6 + Float(i % 3) * 0.012, 1.62],
                      rotation: .yaw(rng.range(-0.4, 0.4)), in: b)
        }
        mailLetters.position = [0, 0, 0]
        b.addChild(mailLetters)
        for _ in 0..<4 {
            let l = Toon.part(Toon.box(0.17, 0.012, 0.12, r: 0.003), Toon.mat(0xFFFFFF, glow: 0.5), outline: 0.1, in: mailLetters)
            l.isEnabled = false
        }
    }

    private func buildForge() {
        let b = site(.forge)
        let stone = Toon.mat(0xA3A9B3, rough: 1, glow: 0.14)
        Toon.part(Toon.box(2.5, 1.6, 2.0, r: 0.12), stone, at: [0, 0.8, 0], outline: 0.015, in: b)
        // Stone blocks texture
        for i in 0..<8 {
            Toon.part(Toon.box(0.4, 0.22, 0.04, r: 0.04), Toon.mat(0x8E95A1), at: [-1.0 + Float(i % 4) * 0.66, 0.3 + Float(i / 4) * 0.8, 1.01], in: b)
        }
        roof(b, y: 1.6, radius: 1.9, height: 0.95, color: 0x475569)
        door([-0.6, 0.48, 1.0], in: b, color: 0x3F3A36)
        window([0.6, 1.05, 1.01], in: b)
        // Chimney
        Toon.part(Toon.box(0.45, 1.4, 0.45, r: 0.05), Toon.mat(0x7C5A4A), at: [0.7, 2.4, -0.4], outline: 0.04, in: b)
        chimneySmoke.position = [0.7, 3.2, -0.4]
        b.addChild(chimneySmoke)

        // Anvil + fire pit in front, where Ren works
        let iron = Toon.mat(0x3B3F4A, rough: 0.35, glow: 0.1, metal: 0.7)
        let anvil = Entity()
        anvil.position = [0, 0, 1.9 - 0.55]
        b.addChild(anvil)
        Toon.part(Toon.box(0.3, 0.3, 0.25, r: 0.03), iron, at: [0, 0.15, 0], outline: 0.06, in: anvil)
        Toon.part(Toon.box(0.62, 0.16, 0.3, r: 0.04), iron, at: [0, 0.38, 0], outline: 0.06, in: anvil)
        Toon.part(Toon.cone(0.3, 0.1), iron, at: [0.4, 0.38, 0], rotation: .roll(-.pi / 2), in: anvil)

        let pit = Entity()
        pit.position = [-1.15, 0, 1.45]
        b.addChild(pit)
        Toon.part(Toon.cylinder(0.4, 0.45), stone, at: [0, 0.2, 0], outline: 0.04, in: pit)
        Toon.part(Toon.cylinder(0.05, 0.36), Toon.mat(0xFF7A1A, rough: 0.2, glow: 2.2), at: [0, 0.4, 0], in: pit)
        forgeFire.position = [0, 0.5, 0]
        pit.addChild(forgeFire)
        for i in 0..<3 {
            let f = Toon.part(Toon.cone(0.45 - Float(i) * 0.1, 0.18 - Float(i) * 0.03), Toon.unlit(i == 2 ? 0xFFF3B0 : (i == 1 ? 0xFFB13B : 0xFF5E1A), alpha: 0.9),
                              at: [Float(i - 1) * 0.08, 0.15, 0], in: forgeFire)
            f.name = "flame\(i)"
        }
        var fireLight = PointLightComponent(color: PlatformColor(hex: 0xFF8A3D), intensity: 6000, attenuationRadius: 5)
        fireLight.attenuationFalloffExponent = 2
        forgeFire.components.set(fireLight)
        forgeSparks.position = [0, 0.55, 0]
        anvil.addChild(forgeSparks)
    }

    private func buildLibrary() {
        let b = site(.library)
        Toon.part(Toon.box(2.8, 2.2, 2.2, r: 0.1), Toon.mat(0xE9D8C4, rough: 0.9, glow: 0.18), at: [0, 1.1, 0], outline: 0.015, in: b)
        Toon.part(Toon.box(3.0, 0.2, 2.4, r: 0.06), Toon.mat(0x6C5CE7, glow: 0.2), at: [0, 2.2, 0], outline: 0.02, in: b)
        roof(b, y: 2.25, radius: 2.1, height: 1.5, color: 0x7E68D8)
        for x: Float in [-1.05, -0.45, 0.45, 1.05] {
            Toon.part(Toon.cylinder(2.0, 0.11), Toon.mat(0xFFFFFF, glow: 0.25), at: [x, 1.0, 1.15], outline: 0.06, in: b)
        }
        door([0, 0.48, 1.11], in: b, color: 0x4B3A8C)
        window([-0.75, 1.55, 1.11], in: b, w: 0.36, h: 0.55)
        window([0.75, 1.55, 1.11], in: b, w: 0.36, h: 0.55)
        // Bookshelves out front
        let colors: [UInt32] = [0xE8366E, 0x27C2E8, 0xF5D76E, 0x4ADE80, 0xA78BFA, 0xFF8A3D]
        for s: Float in [-1, 1] {
            let shelf = Entity()
            shelf.position = [s * 0.95, 0, 1.75]
            b.addChild(shelf)
            Toon.part(Toon.box(0.8, 1.1, 0.32, r: 0.03), Toon.mat(0x8B5A3C), at: [0, 0.55, 0], outline: 0.04, in: shelf)
            for row in 0..<3 {
                for k in 0..<5 {
                    let h = rng.range(0.18, 0.26)
                    Toon.part(Toon.box(0.11, h, 0.22), Toon.mat(colors[(row * 5 + k + (s > 0 ? 2 : 0)) % colors.count], glow: 0.25),
                              at: [-0.27 + Float(k) * 0.135, 0.2 + Float(row) * 0.33 + h / 2 - 0.1, 0.06], in: shelf)
                }
            }
        }
        // Orbiting magic books (shown while researching)
        libraryBooks.position = [0, 1.6, 2.6]
        b.addChild(libraryBooks)
        for i in 0..<5 {
            let a = Float(i) / 5 * 2 * .pi
            let book = Toon.part(Toon.box(0.2, 0.26, 0.06, r: 0.015), Toon.mat(colors[i], glow: 0.6),
                                 at: [sin(a) * 0.9, sin(a * 2) * 0.15, cos(a) * 0.9], rotation: .yaw(a), outline: 0.06, in: libraryBooks)
            Toon.part(Toon.box(0.18, 0.24, 0.065), Toon.mat(0xFFF6E0, glow: 0.3), in: book)
        }
        libraryBooks.isEnabled = false
    }

    private func buildObservatory() {
        let b = site(.observatory)
        Toon.part(Toon.cylinder(2.3, 1.15), Toon.mat(0xE3EAF7, rough: 0.9, glow: 0.2), at: [0, 1.15, 0], outline: 0.015, in: b)
        Toon.part(Toon.cylinder(0.2, 1.28), Toon.mat(0x3B4A7A), at: [0, 2.3, 0], outline: 0.02, in: b)
        Toon.part(Toon.sphere(1.15), Toon.mat(0x5B6C9C, rough: 0.35, glow: 0.2, metal: 0.4), at: [0, 2.35, 0], scale: [1, 0.9, 1], outline: 0.015, in: b)
        Toon.part(Toon.box(0.3, 1.2, 0.2, r: 0.02), Toon.mat(0x23304F), at: [0, 2.9, 0.75], rotation: .pitch(0.55), in: b)
        // Telescope poking out
        Toon.part(Toon.cylinder(1.8, 0.16), Toon.mat(0xD4A84B, rough: 0.3, glow: 0.3, metal: 0.8), at: [0, 3.4, 0.6],
                  rotation: .pitch(0.9), outline: 0.06, in: b)
        door([0, 0.48, 1.13], in: b, color: 0x3B4A7A)
        window([-0.7, 1.4, 0.92], in: b, w: 0.3, h: 0.45)
        window([0.7, 1.4, 0.92], in: b, w: 0.3, h: 0.45)

        // Hologram chart in front of the tower
        hologram.position = [0, 0.15, 2.05]
        b.addChild(hologram)
        Toon.part(Toon.cylinder(0.08, 0.8), Toon.mat(0x23304F, rough: 0.3, metal: 0.5), at: [0, 0.04, 0], outline: 0.05, in: hologram)
        Toon.part(Toon.cylinder(0.02, 0.72), Toon.unlit(0x5CF2FF, alpha: 0.7), at: [0, 0.09, 0], in: hologram)
        for i in 0..<6 {
            let bar = Toon.part(Toon.box(0.14, 1, 0.14, r: 0.02), Toon.unlit(i == 4 ? 0xFF6FA5 : 0x5CF2FF, alpha: 0.55),
                                at: [-0.45 + Float(i) * 0.18, 0.6, 0], scale: [1, 0.5, 1], in: hologram)
            hologramBars.append(bar)
        }
    }

    private func buildQuestBoard() {
        let s = StationKind.questBoard
        let b = Entity()
        b.position = polar(s.angle, s.buildingRadius)
        root.addChild(b)
        let wood = Toon.mat(0xB07A4A, rough: 0.95)
        for x: Float in [-0.85, 0.85] { Toon.part(Toon.box(0.14, 1.9, 0.14, r: 0.03), wood, at: [x, 0.95, 0], outline: 0.05, in: b) }
        Toon.part(Toon.box(1.9, 1.05, 0.1, r: 0.04), Toon.mat(0xD9A066, rough: 0.95, glow: 0.12), at: [0, 1.2, 0.02], outline: 0.03, in: b)
        Toon.part(Toon.box(2.1, 0.14, 0.3, r: 0.04), Toon.mat(0xC2415F), at: [0, 1.85, 0], outline: 0.05, in: b)
        let papers: [UInt32] = [0xFFF8EC, 0xFFF1B8, 0xFFE3EE, 0xE6F7FF]
        for i in 0..<6 {
            Toon.part(Toon.box(0.34, 0.42, 0.012), Toon.mat(papers[i % 4], glow: 0.3),
                      at: [-0.6 + Float(i % 3) * 0.6, 1.0 + Float(i / 3) * 0.42 - 0.18, 0.09], rotation: .roll(rng.range(-0.15, 0.15)), in: b)
        }
        // Floating "!" marker for pending approvals
        questMarker.position = [0, 2.75, 0]
        b.addChild(questMarker)
        let gold = Toon.mat(0xFFD23F, rough: 0.2, glow: 1.4)
        Toon.part(Toon.box(0.16, 0.48, 0.16, r: 0.06), gold, at: [0, 0.18, 0], outline: 0.12, in: questMarker)
        Toon.part(Toon.sphere(0.1), gold, at: [0, -0.22, 0], outline: 0.12, in: questMarker)
        questMarker.isEnabled = false
    }

    private func buildTorii() {
        let g = Entity()
        g.position = polar(0, 9.1)
        root.addChild(g)
        let red = Toon.mat(0xE5383B, rough: 0.6, glow: 0.25)
        let black = Toon.mat(0x2B2530, rough: 0.6)
        for x: Float in [-1.3, 1.3] {
            Toon.part(Toon.cylinder(2.9, 0.15), red, at: [x, 1.45, 0], outline: 0.05, in: g)
            Toon.part(Toon.cylinder(0.25, 0.22), black, at: [x, 0.12, 0], in: g)
        }
        Toon.part(Toon.box(3.6, 0.22, 0.34, r: 0.05), black, at: [0, 3.05, 0], outline: 0.03, in: g)
        Toon.part(Toon.box(3.3, 0.22, 0.3, r: 0.04), red, at: [0, 2.83, 0], outline: 0.03, in: g)
        Toon.part(Toon.box(3.0, 0.15, 0.2, r: 0.03), red, at: [0, 2.35, 0], outline: 0.03, in: g)
        Toon.part(Toon.box(0.2, 0.5, 0.12), black, at: [0, 2.58, 0], in: g)
    }

    // MARK: Nature

    private func buildNature() {
        let greens: [UInt32] = [0x5CBF5A, 0x4FAE57, 0x72CF63, 0x3E9E57]
        let pinks: [UInt32] = [0xFFB7D5, 0xFFA3C8]
        let avoid = StationKind.allCases.map { polar($0.angle, $0.buildingRadius) } + [polar(0, 9.1), polar(180, 8.4)]
        var placed = 0, tries = 0
        while placed < 26, tries < 400 {
            tries += 1
            let a = rng.range(0, 360), r = rng.range(5.2, VillageLayout.islandRadius - 0.6)
            let p = polar(a, r)
            if avoid.contains(where: { simd_distance($0, p) < 2.3 }) { continue }
            if StationKind.allCases.contains(where: { abs(angleDiff($0.angle, a)) < 9 }) { continue }
            placed += 1
            let kind = Int(rng.next() * 3)
            let tree = Entity()
            tree.position = p
            tree.scale = .init(repeating: rng.range(0.75, 1.2))
            root.addChild(tree)
            if kind == 0 {
                // Pine
                Toon.part(Toon.cylinder(0.6, 0.12), Toon.mat(0x7A4E3A), at: [0, 0.3, 0], in: tree)
                for k in 0..<3 {
                    Toon.part(Toon.cone(0.9, 0.7 - Float(k) * 0.17), Toon.mat(greens[(k + placed) % 4], rough: 0.9, glow: 0.18),
                              at: [0, 0.85 + Float(k) * 0.45, 0], outline: 0.04, outlineColor: 0x24563A, in: tree)
                }
            } else {
                let color = kind == 2 ? pinks[placed % 2] : greens[placed % 4]
                Toon.part(Toon.cylinder(0.9, 0.11), Toon.mat(0x7A4E3A), at: [0, 0.45, 0], outline: 0.08, in: tree)
                for k in 0..<3 {
                    Toon.part(Toon.sphere(rng.range(0.45, 0.65)), Toon.mat(color, rough: 0.9, glow: 0.22),
                              at: [rng.range(-0.3, 0.3), 1.2 + rng.range(0, 0.45), rng.range(-0.3, 0.3)],
                              outline: 0.04, outlineColor: kind == 2 ? 0xB84A7A : 0x24563A, in: tree)
                    _ = k
                }
            }
        }
        // Flowers & bushes
        let flowerColors: [UInt32] = [0xFFFFFF, 0xFFD23F, 0xFF6F91, 0xA78BFA, 0x7FE3FF]
        for i in 0..<70 {
            let p = polar(rng.range(0, 360), rng.range(4.4, VillageLayout.islandRadius - 0.3))
            if StationKind.allCases.contains(where: { simd_distance(polar($0.angle, $0.buildingRadius), p) < 1.8 }) { continue }
            if i % 5 == 0 {
                Toon.part(Toon.sphere(rng.range(0.25, 0.4)), Toon.mat(greens[i % 4], rough: 1, glow: 0.2), at: p + [0, 0.12, 0],
                          scale: [1, 0.75, 1], outline: 0.05, outlineColor: 0x24563A, in: root)
            } else {
                Toon.part(Toon.sphere(0.06), Toon.mat(flowerColors[i % flowerColors.count], glow: 0.5), at: p + [0, 0.07, 0], in: root)
            }
        }
        // Pond and waterfall off the back edge
        let pond = polar(180, 8.4)
        Toon.part(Toon.cylinder(0.06, 1.5), Toon.mat(0x4FC3F7, rough: 0.05, glow: 0.45), at: pond + [0, 0.02, 0], outline: 0.02, outlineColor: 0x2B7FA8, in: root)
        let streamMid = polar(180, 9.8)
        Toon.part(Toon.box(0.8, 0.06, 2.0), Toon.mat(0x4FC3F7, rough: 0.05, glow: 0.45), at: streamMid + [0, 0.02, 0], in: root)
        for i in 0..<8 {
            let p = polar(180 + Float(i) * 45, 1.65)
            Toon.part(Toon.sphere(0.22), Toon.mat(0xA9A39A), at: pond + p + [0, 0.05, 0], scale: [1, 0.55, 1], outline: 0.06, in: root)
        }
        let fall = Entity()
        fall.position = polar(180, VillageLayout.islandRadius + 0.1) + [0, -0.1, 0]
        root.addChild(fall)
        var water = ParticleEmitterComponent()
        water.emitterShape = .box
        water.emitterShapeSize = [0.7, 0.05, 0.1]
        water.birthDirection = .world
        water.emissionDirection = [0, -1, -0.3]
        water.speed = 0.6
        water.mainEmitter.birthRate = 260
        water.mainEmitter.lifeSpan = 3
        water.mainEmitter.size = 0.09
        water.mainEmitter.acceleration = [0, -2.5, 0]
        water.mainEmitter.color = .evolving(start: .single(PlatformColor(hex: 0xBFF0FF)), end: .single(PlatformColor(hex: 0x4FC3F7, alpha: 0)))
        water.mainEmitter.blendMode = .additive
        fall.components.set(water)
    }

    private func angleDiff(_ a: Float, _ b: Float) -> Float {
        var d = (a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    private func buildClouds() {
        root.addChild(cloudRing)
        let white = Toon.mat(0xFFFFFF, rough: 1, glow: 0.45)
        for i in 0..<14 {
            let c = Entity()
            let a = Float(i) / 14 * 360 + rng.range(-10, 10)
            c.position = polar(a, rng.range(15, 30)) + [0, rng.range(-7, 3), 0]
            c.scale = .init(repeating: rng.range(0.8, 1.8))
            cloudRing.addChild(c)
            for k in 0..<5 {
                Toon.part(Toon.sphere(rng.range(0.8, 1.3)), white, at: [Float(k) * 0.9 - 1.8, rng.range(-0.2, 0.5), rng.range(-0.5, 0.5)],
                          scale: [1, 0.7, 1], in: c)
            }
        }
        // Small floating islets
        for i in 0..<4 {
            let islet = Entity()
            islet.position = polar(Float(i) * 90 + 45, rng.range(14, 18)) + [0, rng.range(-3, 1.5), 0]
            root.addChild(islet)
            let s = rng.range(0.8, 1.4)
            Toon.part(Toon.cylinder(0.3, 1.3 * s), Toon.mat(0x86D46B, glow: 0.18), in: islet)
            Toon.part(Toon.cone(2.2 * s, 1.25 * s), Toon.mat(0x8C6B53), at: [0, -1.25 * s, 0], rotation: .pitch(.pi), outline: 0.02, in: islet)
            Toon.part(Toon.sphere(0.6 * s), Toon.mat(i % 2 == 0 ? 0xFFB7D5 : 0x5CBF5A, glow: 0.25), at: [0, 0.9 * s, 0], outline: 0.04, in: islet)
            Toon.part(Toon.cylinder(0.6 * s, 0.08), Toon.mat(0x7A4E3A), at: [0, 0.4 * s, 0], in: islet)
            floaters.append((islet, rng.range(0, 6)))
        }
    }

    // MARK: Effects

    private func buildEffects() {
        // Drifting sakura petals over the whole island
        petals.position = [0, 7, 0]
        root.addChild(petals)
        var p = ParticleEmitterComponent()
        p.emitterShape = .box
        p.emitterShapeSize = [24, 1, 24]
        p.birthDirection = .world
        p.emissionDirection = [0.3, -1, 0.1]
        p.speed = 0.25
        p.mainEmitter.birthRate = 45
        p.mainEmitter.lifeSpan = 12
        p.mainEmitter.size = 0.07
        p.mainEmitter.sizeVariation = 0.03
        p.mainEmitter.acceleration = [0.12, -0.12, 0.05]
        p.mainEmitter.angularSpeed = 2
        p.mainEmitter.angularSpeedVariation = 2
        p.mainEmitter.noiseStrength = 0.15
        p.mainEmitter.noiseScale = 1
        p.mainEmitter.billboardMode = .free(axis: [0.3, 1, 0.2], variation: 1)
        p.mainEmitter.opacityCurve = .gradualFadeInOut
        p.mainEmitter.color = .constant(.random(a: PlatformColor(hex: 0xFFB7D5), b: PlatformColor(hex: 0xFFE4EF)))
        petals.components.set(p)

        // Fireflies (fade in at night)
        fireflies.position = [0, 1.2, 0]
        root.addChild(fireflies)
        var f = ParticleEmitterComponent()
        f.emitterShape = .cylinder
        f.emitterShapeSize = [18, 1.5, 18]
        f.speed = 0.05
        f.mainEmitter.birthRate = 0
        f.mainEmitter.lifeSpan = 5
        f.mainEmitter.size = 0.05
        f.mainEmitter.noiseStrength = 0.4
        f.mainEmitter.noiseScale = 2
        f.mainEmitter.opacityCurve = .quickFadeInOut
        f.mainEmitter.blendMode = .additive
        f.mainEmitter.color = .constant(.single(PlatformColor(hex: 0xFFF3A0)))
        fireflies.components.set(f)

        // Forge sparks (enabled while coding)
        var s = ParticleEmitterComponent.Presets.sparks
        s.mainEmitter.birthRate = 0
        s.speed = 1.6
        s.mainEmitter.size = 0.02
        s.mainEmitter.lifeSpan = 0.8
        s.mainEmitter.color = .evolving(start: .single(PlatformColor(hex: 0xFFF3B0)), end: .single(PlatformColor(hex: 0xFF5E1A)))
        forgeSparks.components.set(s)

        // Chimney smoke
        var smoke = ParticleEmitterComponent()
        smoke.emitterShape = .sphere
        smoke.emitterShapeSize = [0.15, 0.15, 0.15]
        smoke.birthDirection = .world
        smoke.emissionDirection = [0.2, 1, 0]
        smoke.speed = 0.4
        smoke.mainEmitter.birthRate = 6
        smoke.mainEmitter.lifeSpan = 4
        smoke.mainEmitter.size = 0.25
        smoke.mainEmitter.sizeMultiplierAtEndOfLifespan = 4
        smoke.mainEmitter.opacityCurve = .gradualFadeInOut
        smoke.mainEmitter.color = .constant(.single(PlatformColor(hex: 0xE6E2F0, alpha: 0.5)))
        chimneySmoke.components.set(smoke)

        // Magic sparkles around the library while researching
        var magic = ParticleEmitterComponent.Presets.magic
        magic.mainEmitter.birthRate = 0
        magic.mainEmitter.color = .constant(.random(a: PlatformColor(hex: 0xA78BFA), b: PlatformColor(hex: 0xF5D76E)))
        libraryBooks.components.set(magic)
    }
}
