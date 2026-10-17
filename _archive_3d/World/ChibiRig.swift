import RealityKit
import simd

/// A chibi anime character built from primitives, animated procedurally every frame.
@MainActor
final class ChibiRig {
    let persona: Persona
    let root = Entity()
    private let body = Entity()
    private let torso = Entity()
    private let headPivot = Entity()
    private let leftArm = Entity(), rightArm = Entity()
    private let leftLeg = Entity(), rightLeg = Entity()
    private let propHolder = Entity()
    private let face: ModelEntity
    private let aura: ModelEntity
    private var tails: [Entity] = []
    private var faceMaterials: [Expression: UnlitMaterial] = [:]
    private var shownExpression: Expression?

    static let headRadius: Float = 0.27
    /// Height above the agent's feet where speech bubbles anchor.
    static let bubbleHeight: Float = 2.2
    static let scale: Float = 1.45

    init(persona p: Persona) {
        persona = p
        let R = Self.headRadius
        let skin = Toon.mat(p.skin, rough: 0.9, glow: 0.22)
        let outfit = Toon.mat(p.outfit, rough: 0.8, glow: 0.14)
        let accent = Toon.mat(p.outfitAccent, rough: 0.6, glow: 0.2)
        let hair = Toon.mat(p.hair, rough: 0.45, glow: 0.2)
        let hairShade = Toon.mat(p.hairShade, rough: 0.5, glow: 0.16)
        let ol: Float = 0.07

        root.name = "agent-\(p.id)"
        root.scale = .init(repeating: Self.scale)
        root.addChild(body)

        // Aura disc under the feet
        let ringTex = Toon.texture(FaceArt.auraRing(p.aura))
        aura = ModelEntity(mesh: Toon.plane(1.3, 1.3), materials: [ringTex.map { Toon.textured($0) } ?? Toon.unlit(p.aura, alpha: 0.4)])
        aura.position.y = 0.015
        root.addChild(aura)

        // Legs
        for (leg, x) in [(leftLeg, Float(0.08)), (rightLeg, Float(-0.08))] {
            leg.position = [x, 0.27, 0]
            body.addChild(leg)
            Toon.part(Toon.cylinder(0.2, 0.06), Toon.mat(FaceArt.darken(p.outfit, 0.35)), at: [0, -0.1, 0], outline: ol, in: leg)
            Toon.part(Toon.box(0.13, 0.08, 0.17, r: 0.035), accent, at: [0, -0.22, 0.025], outline: ol, in: leg)
        }

        // Torso with a flared coat/skirt
        torso.position = [0, 0.27, 0]
        body.addChild(torso)
        Toon.part(Toon.box(0.34, 0.3, 0.25, r: 0.11), outfit, at: [0, 0.16, 0], outline: ol, in: torso)
        Toon.part(Toon.cone(0.32, 0.25), outfit, at: [0, 0.08, 0], outline: 0.05, in: torso)
        Toon.part(Toon.cylinder(0.05, 0.175), accent, at: [0, 0.06, 0], in: torso)
        Toon.part(Toon.cylinder(0.06, 0.13), accent, at: [0, 0.3, 0], outline: 0.06, in: torso)
        // Bow / emblem on the chest
        Toon.part(Toon.sphere(0.045), accent, at: [0, 0.22, 0.125], in: torso)

        // Arms (pivot at the shoulder)
        for (arm, x) in [(leftArm, Float(0.2)), (rightArm, Float(-0.2))] {
            arm.position = [x, 0.27 + 0.27, 0]
            body.addChild(arm)
            Toon.part(Toon.cylinder(0.22, 0.05), outfit, at: [0, -0.1, 0], outline: ol, in: arm)
            Toon.part(Toon.cylinder(0.04, 0.056), accent, at: [0, -0.19, 0], in: arm)
            Toon.part(Toon.sphere(0.058), skin, at: [0, -0.24, 0], outline: ol, in: arm)
        }
        propHolder.position = [0, -0.26, 0.03]
        rightArm.addChild(propHolder)
        Self.buildProp(p.prop, in: propHolder)

        // Head
        headPivot.position = [0, 0.86, 0]
        body.addChild(headPivot)
        let head = Entity()
        head.position = [0, R * 0.95, 0]
        headPivot.addChild(head)
        Toon.part(Toon.sphere(R), skin, outline: 0.045, in: head)

        // Face decal, conformed to the front of the head sphere
        face = ModelEntity(mesh: Self.faceMesh(radius: R), materials: [Toon.unlit(0xFFFFFF, alpha: 0)])
        head.addChild(face)
        for e in Expression.allCases {
            if let tex = Toon.texture(FaceArt.face(p, e)) { faceMaterials[e] = Toon.textured(tex) }
        }

        // Ears
        for s: Float in [-1, 1] {
            Toon.part(Toon.sphere(0.06), skin, at: [s * R * 0.98, -0.02, 0], scale: [0.6, 1, 0.8], in: head)
        }

        buildHair(p, in: head, R: R, hair: hair, shade: hairShade, accent: accent)

        root.components.set(InputTargetComponent())
        root.components.set(CollisionComponent(shapes: [.generateBox(width: 0.7, height: 1.4, depth: 0.7).offsetBy(translation: [0, 0.7, 0])]))
    }

    // MARK: Hair & accessories

    private func buildHair(_ p: Persona, in head: Entity, R: Float, hair: PhysicallyBasedMaterial, shade: PhysicallyBasedMaterial, accent: PhysicallyBasedMaterial) {
        // Skull cap, pushed back so the face stays clear
        Toon.part(Toon.sphere(R * 1.07), hair, at: [0, R * 0.1, -R * 0.12], outline: 0.035, in: head)

        // Bangs: soft locks around the hairline
        let lockCount = p.hairStyle == .spiky ? 6 : 7
        for i in 0..<lockCount {
            let t = Float(i) / Float(lockCount - 1)
            let phi = (t - 0.5) * 2 * 1.05
            let pos = SIMD3<Float>(sin(phi) * R * 0.86, R * 0.52 - abs(t - 0.5) * R * 0.25, cos(phi) * R * 0.78)
            let tilt = simd_quatf.yaw(phi) * simd_quatf.pitch(0.42)
            if p.hairStyle == .spiky {
                Toon.part(Toon.cone(R * 0.75, R * 0.22), hair, at: pos + [0, -R * 0.05, 0],
                          rotation: tilt * simd_quatf.pitch(.pi), outline: 0.06, in: head)
            } else {
                Toon.part(Toon.sphere(R * 0.3), i % 2 == 0 ? hair : shade, at: pos,
                          scale: [0.72, 1.35, 0.5], rotation: tilt, outline: 0.06, in: head)
            }
        }

        switch p.hairStyle {
        case .twinTails:
            for s: Float in [-1, 1] {
                let tail = Entity()
                tail.position = [s * R * 1.0, R * 0.2, -R * 0.3]
                head.addChild(tail)
                Toon.part(Toon.sphere(R * 0.38), hair, at: [s * R * 0.25, -R * 0.75, 0], scale: [0.75, 2.0, 0.75],
                          rotation: .roll(s * 0.25), outline: 0.05, in: tail)
                Toon.part(Toon.sphere(R * 0.14), accent, in: tail)
                tails.append(tail)
            }
            // Ribbon bow
            let bow = Entity()
            bow.position = [R * 0.5, R * 0.95, -R * 0.05]
            bow.orientation = .roll(-0.4)
            head.addChild(bow)
            for s: Float in [-1, 1] {
                Toon.part(Toon.sphere(R * 0.22), accent, at: [s * R * 0.24, 0, 0], scale: [1.2, 0.8, 0.45],
                          rotation: .roll(s * 0.35), outline: 0.08, in: bow)
            }
            Toon.part(Toon.sphere(R * 0.1), Toon.mat(FaceArt.darken(p.outfitAccent, 0.25)), in: bow)

        case .spiky:
            var rng = SeededRandom(11)
            for i in 0..<11 {
                let az = Float(i) / 11 * 2 * .pi + rng.range(-0.15, 0.15)
                let el = rng.range(0.25, 1.15)
                let n = SIMD3<Float>(sin(az) * cos(el), sin(el), cos(az) * cos(el) * 0.6 - 0.35)
                let dir = simd_normalize(n + [0, 0.5, -0.4])
                Toon.part(Toon.cone(R * rng.range(0.6, 0.9), R * 0.24), i % 3 == 0 ? shade : hair,
                          at: simd_normalize(n) * R * 0.9 + [0, R * 0.1, -R * 0.1], rotation: .pointing(dir), outline: 0.06, in: head)
            }
            // Headband with a metal plate
            Toon.part(Toon.cylinder(R * 0.2, R * 1.04), accent, at: [0, R * 0.42, -R * 0.04], rotation: .pitch(-0.18), in: head)
            Toon.part(Toon.box(R * 0.55, R * 0.24, R * 0.08, r: R * 0.03), Toon.mat(0xC9D3E0, rough: 0.25, glow: 0.2, metal: 0.8),
                      at: [0, R * 0.5, R * 0.98], rotation: .pitch(-0.25), outline: 0.08, in: head)

        case .longStraight:
            Toon.part(Toon.sphere(R * 0.95), hair, at: [0, -R * 0.65, -R * 0.5], scale: [1.12, 1.55, 0.6], outline: 0.035, in: head)
            for s: Float in [-1, 1] {
                Toon.part(Toon.sphere(R * 0.3), shade, at: [s * R * 0.9, -R * 0.5, R * 0.18], scale: [0.7, 2.3, 0.6], outline: 0.06, in: head)
            }
            // Ahoge
            Toon.part(Toon.cone(R * 0.6, R * 0.08), hair, at: [0, R * 1.25, 0], rotation: .roll(0.5) * .pitch(-0.3), in: head)

        case .messy:
            var rng = SeededRandom(23)
            for i in 0..<9 {
                let az = Float(i) / 9 * 2 * .pi
                let n = simd_normalize(SIMD3<Float>(sin(az), rng.range(0.3, 0.9), cos(az) * 0.7 - 0.45))
                Toon.part(Toon.sphere(R * 0.36), i % 2 == 0 ? hair : shade, at: n * R * 0.92 + [0, R * 0.12, -R * 0.08],
                          scale: [1, 0.8, 1], rotation: .pointing(n), outline: 0.05, in: head)
            }
            // Goggles on the forehead
            Toon.part(Toon.cylinder(R * 0.14, R * 1.06), Toon.mat(0x6B4F2F), at: [0, R * 0.52, -R * 0.06], rotation: .pitch(-0.25), in: head)
            for s: Float in [-1, 1] {
                let lens = Toon.part(Toon.cylinder(R * 0.14, R * 0.2), Toon.mat(0x6B4F2F, metal: 0.4), at: [s * R * 0.32, R * 0.62, R * 0.86],
                                     rotation: .pitch(.pi / 2 - 0.5), outline: 0.08, in: head)
                Toon.part(Toon.cylinder(R * 0.02, R * 0.15), Toon.mat(0x7FE3FF, rough: 0.1, glow: 0.8), at: [0, R * 0.075, 0], in: lens)
            }
        }
    }

    private static func buildProp(_ prop: HeldProp, in holder: Entity) {
        switch prop {
        case .letter:
            let env = Toon.part(Toon.box(0.17, 0.12, 0.012, r: 0.004), Toon.mat(0xFFF8EC), rotation: .pitch(-0.4), outline: 0.08, in: holder)
            Toon.part(Toon.cylinder(0.006, 0.024), Toon.mat(0xE8366E, glow: 0.4), at: [0, 0, 0.008], rotation: .pitch(.pi / 2), in: env)
        case .hammer:
            let h = Entity()
            h.orientation = .pitch(-.pi / 2)
            holder.addChild(h)
            Toon.part(Toon.cylinder(0.3, 0.02), Toon.mat(0x8B5A2B), at: [0, 0.1, 0], outline: 0.15, in: h)
            Toon.part(Toon.box(0.17, 0.08, 0.08, r: 0.012), Toon.mat(0x9AA4B5, rough: 0.3, glow: 0.12, metal: 0.8), at: [0, 0.25, 0], outline: 0.08, in: h)
        case .book:
            let b = Toon.part(Toon.box(0.16, 0.21, 0.05, r: 0.012), Toon.mat(0x7E3FB3, glow: 0.2), at: [0, 0, 0.04], rotation: .pitch(-0.6), outline: 0.06, in: holder)
            Toon.part(Toon.box(0.145, 0.195, 0.052), Toon.mat(0xFFF6E0), at: [0.008, 0, 0], in: b)
            Toon.part(Toon.box(0.05, 0.05, 0.054), Toon.mat(0xF5D76E, glow: 0.5), at: [0, 0.04, 0], in: b)
        case .tablet:
            let t = Toon.part(Toon.box(0.2, 0.14, 0.016, r: 0.01), Toon.mat(0x1E2433), at: [0, 0, 0.05], rotation: .pitch(-0.9), outline: 0.06, in: holder)
            Toon.part(Toon.box(0.175, 0.115, 0.004), Toon.unlit(0x5CF2FF), at: [0, 0, 0.009], in: t)
        }
    }

    /// A spherical patch matching the front of the head, UV-mapped for the face decal.
    private static func faceMesh(radius R: Float) -> MeshResource {
        Toon.mesh("face\(R)") {
            let cols = 24, rows = 20
            let halfW = R * 0.75, halfH = R * 0.6
            var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = []
            var indices: [UInt32] = []
            for j in 0...rows {
                for i in 0...cols {
                    let u = Float(i) / Float(cols), v = Float(j) / Float(rows)
                    let x = -halfW + u * 2 * halfW
                    let y = -halfH + v * 2 * halfH
                    let z = sqrt(max(0, R * R - x * x - y * y))
                    let p = SIMD3<Float>(x, y, z) * 1.012
                    positions.append(p)
                    normals.append(simd_normalize(p))
                    uvs.append([u, v])
                }
            }
            for j in 0..<rows {
                for i in 0..<cols {
                    let a = UInt32(j * (cols + 1) + i), b = a + 1
                    let c = a + UInt32(cols + 1), d = c + 1
                    indices += [a, b, d, a, d, c]
                }
            }
            var desc = MeshDescriptor(name: "face")
            desc.positions = MeshBuffers.Positions(positions)
            desc.normals = MeshBuffers.Normals(normals)
            desc.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
            desc.primitives = .triangles(indices)
            return (try? MeshResource.generate(from: [desc])) ?? .generateSphere(radius: 0.01)
        }
    }

    // MARK: Animation

    func update(_ a: AgentState, selected: Bool, time: Float) {
        root.position = a.position
        root.orientation = .yaw(a.yaw)

        if shownExpression != a.expression, let m = faceMaterials[a.expression] {
            face.model?.materials = [m]
            shownExpression = a.expression
        }

        let t = a.animTime
        var bob: Float = 0, lean: Float = 0, twist: Float = 0, squash: Float = 1
        var la = (x: Float(0), z: Float(0.08)), ra = (x: Float(0), z: Float(-0.08))
        var ll: Float = 0, rl: Float = 0
        var headPitch: Float = 0, headYaw: Float = 0, headRoll: Float = 0

        switch a.mode {
        case .walking:
            let ph = t * 10
            ll = sin(ph) * 0.7; rl = -ll
            la.x = -sin(ph) * 0.6; ra.x = sin(ph) * 0.6
            bob = abs(sin(ph)) * 0.05
            lean = 0.1
            headRoll = sin(ph) * 0.05
        case .working:
            switch persona.motion {
            case .hammer:
                let s = pow(abs(sin(t * 4.2)), 0.55)
                ra.x = -2.7 + 2.1 * s
                la.x = -0.7
                lean = 0.12 * s
                headPitch = 0.25
                bob = -0.02 * s
            case .read:
                la = (-1.15, 0.35); ra = (-1.15, -0.35)
                headPitch = 0.3 + sin(t * 1.3) * 0.05
                headYaw = sin(t * 0.7) * 0.15
                bob = sin(t * 2) * 0.01
            case .sort:
                la.x = -1.3 + sin(t * 5) * 0.55
                ra.x = -1.3 + sin(t * 5 + .pi) * 0.55
                twist = sin(t * 2.5) * 0.35
                headYaw = twist * 0.5
                bob = abs(sin(t * 5)) * 0.02
            case .observe:
                ra = (-2.6 + sin(t * 1.5) * 0.15, -0.25)
                la.x = -1.1
                headPitch = -0.35
                headYaw = sin(t * 0.8) * 0.3
            }
        case .celebrating:
            let ph = t * 7.5
            bob = abs(sin(ph)) * 0.28
            squash = 1 - 0.06 * cos(ph * 2)
            la = (-0.3, 2.6 + sin(ph) * 0.2); ra = (-0.3, -2.6 - sin(ph) * 0.2)
            twist = sin(t * 3) * 0.2
            headPitch = -0.15
        case .awaitingApproval:
            ra = (-0.2, -2.5 + sin(t * 11) * 0.35)
            la.z = 0.15
            bob = abs(sin(t * 5)) * 0.04
            headRoll = sin(t * 2) * 0.12
            headPitch = -0.1
        case .chatting:
            la.z = 0.2 + sin(t * 3) * 0.1
            ra = (-0.6 + sin(t * 4) * 0.3, -0.25)
            headRoll = sin(t * 2.2) * 0.15
            bob = sin(t * 4) * 0.015
        case .paused:
            bob = -0.1
            squash = 0.95
            headRoll = 0.35
            headPitch = 0.2
            ll = -1.1; rl = -1.1
        case .resting:
            bob = sin(t * 2) * 0.008
            la.z = 0.1 + sin(t * 1.6) * 0.04
            ra.z = -0.1 - sin(t * 1.6) * 0.04
            headYaw = sin(t * 0.5) * 0.4
            headPitch = sin(t * 0.37) * 0.08
        }

        body.position.y = bob
        body.orientation = .yaw(twist) * .pitch(lean)
        body.scale = [1 / squash.squareRoot(), squash, 1 / squash.squareRoot()]
        leftArm.orientation = .roll(la.z) * .pitch(la.x)
        rightArm.orientation = .roll(ra.z) * .pitch(ra.x)
        leftLeg.orientation = .pitch(ll)
        rightLeg.orientation = .pitch(rl)
        headPivot.orientation = .yaw(headYaw) * .pitch(headPitch) * .roll(headRoll)
        for (i, tail) in tails.enumerated() {
            tail.orientation = .roll(sin(t * 6 + Float(i) * 2) * (a.speed > 0 ? 0.18 : 0.05))
        }

        // Aura: bright when selected or calling for the player
        let hot = selected || a.mode == .awaitingApproval
        let pulse = 1 + sin(time * (hot ? 5 : 2)) * (hot ? 0.12 : 0.04)
        aura.scale = .init(repeating: (hot ? 1.25 : 0.9) * pulse)
        aura.orientation = .yaw(time * 0.6)
        aura.isEnabled = hot || a.mode == .working || a.mode == .celebrating
    }
}
