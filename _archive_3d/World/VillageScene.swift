import RealityKit
import SwiftUI
import simd

/// Screen-space positions of things the SwiftUI overlay draws (bubbles, name tags).
@MainActor
@Observable
final class Projector {
    var agentPoints: [String: CGPoint] = [:]
    var stationPoints: [StationKind: CGPoint] = [:]
    var agentScale: CGFloat = 1
    @ObservationIgnored var viewSize: CGSize = CGSize(width: 1200, height: 800)
}

/// Orbit camera that can follow an agent.
struct CameraState {
    var yaw: Float = 0.35
    var pitch: Float = 0.62
    var distance: Float = 24
    var target: SIMD3<Float> = [0, 0.8, 0]
    var userDistance: Float = 24
    var lastInteraction: Double = 0
}

@MainActor
final class VillageScene {
    let model: WorldModel
    let projector: Projector
    let root = Entity()
    let island = Island()
    let camera = Entity()
    var cam = CameraState()
    private var rigs: [String: ChibiRig] = [:]
    private var updateSub: EventSubscription?
    private var time: Float = 0
    private var skyTimer: Float = 0
    private var lastSkyKey = -1
    private var fov: Float = 40
    private var horizontalFOV = false
    private var letterFlights: [(Entity, Float)] = []
    private var letterTimer: Float = 0

    init(model: WorldModel, projector: Projector) {
        self.model = model
        self.projector = projector
        root.addChild(island.root)
        for a in model.agents {
            let rig = ChibiRig(persona: a.persona)
            rigs[a.id] = rig
            root.addChild(rig.root)
        }
        camera.components.set(PerspectiveCameraComponent(near: 0.1, far: 500, fieldOfViewInDegrees: fov))
        root.addChild(camera)
    }

    func install(in content: inout RealityViewCameraContent) {
        content.add(root)
        if let env = try? EnvironmentResource(equirectangular: FaceArt.lightingEnvironment(), withName: "village-sky") {
            content.environment = .skybox(env)
        }
        updateSub = content.subscribe(to: SceneEvents.Update.self) { [weak self] e in
            MainActor.assumeIsolated { self?.update(dt: Float(e.deltaTime)) }
        }
    }

    // MARK: Camera input

    func orbit(dx: CGFloat, dy: CGFloat) {
        cam.yaw -= Float(dx) * 0.006
        cam.pitch = simd_clamp(cam.pitch + Float(dy) * 0.004, 0.18, 1.35)
        cam.lastInteraction = model.clock
    }

    func zoom(by factor: CGFloat) {
        cam.userDistance = simd_clamp(cam.userDistance / Float(factor), 6, 48)
        cam.lastInteraction = model.clock
    }

    func recenter() {
        model.selectedID = nil
        cam.userDistance = defaultDistance
        cam.yaw = 0.35
        cam.pitch = 0.62
    }

    private var defaultDistance: Float {
        let s = projector.viewSize
        return s.width < s.height ? 27 : 24
    }

    /// The agent closest to a tap, if any is near enough.
    func agent(near point: CGPoint) -> String? {
        var best: (String, CGFloat)?
        for a in model.agents {
            for h: Float in [0.5, 1.3] {
                guard let p = project(a.position + [0, h, 0]) else { continue }
                let d = hypot(p.x - point.x, p.y - point.y)
                if d < 70 * projector.agentScale + 24, d < (best?.1 ?? .infinity) { best = (a.id, d) }
            }
        }
        return best?.0
    }

    // MARK: Frame update

    private func update(dt: Float) {
        let dt = min(dt, 0.1)
        time += dt
        model.tick(Double(dt))

        for a in model.agents {
            rigs[a.id]?.update(a, selected: model.selectedID == a.id, time: time)
        }
        updateCamera(dt)
        updateStations(dt)
        updateEnvironment(dt)
        updateProjection()
    }

    private func updateCamera(_ dt: Float) {
        let size = projector.viewSize
        let portrait = size.width < size.height
        if portrait != horizontalFOV {
            horizontalFOV = portrait
            fov = portrait ? 62 : 40
            camera.components.set(PerspectiveCameraComponent(near: 0.1, far: 500, fieldOfViewInDegrees: fov,
                                                             fieldOfViewOrientation: portrait ? .horizontal : .vertical))
            cam.userDistance = defaultDistance
        }

        var target: SIMD3<Float> = [0, 0.8, 0]
        var distance = cam.userDistance
        if let a = model.selected {
            target = a.position + [0, 1.0, 0]
            distance = min(cam.userDistance, portrait ? 7.5 : 7)
            // Swing around to a 3/4 front view so we can see their face.
            if model.clock - cam.lastInteraction > 3 {
                cam.yaw = lerpAngle(cam.yaw, a.yaw + 0.5, 1 - exp(-dt * 1.6))
                cam.pitch = lerp(cam.pitch, 0.38, 1 - exp(-dt * 1.6))
            }
        } else if model.clock - cam.lastInteraction > 12 {
            cam.yaw += dt * 0.03 // gentle cinematic drift when idle
        }
        let k = 1 - exp(-dt * 3.5)
        cam.target = simd_mix(cam.target, target, .init(repeating: k))
        cam.distance = lerp(cam.distance, distance, k)
        let off = SIMD3<Float>(sin(cam.yaw) * cos(cam.pitch), sin(cam.pitch), cos(cam.yaw) * cos(cam.pitch)) * cam.distance
        camera.look(at: cam.target, from: cam.target + off, relativeTo: nil)
    }

    private func updateStations(_ dt: Float) {
        func working(_ s: StationKind) -> Bool {
            model.agents.contains { $0.persona.station == s && $0.mode == .working }
        }
        let forging = working(.forge)
        if var sparks = island.forgeSparks.components[ParticleEmitterComponent.self] {
            let rate: Float = forging ? (sin(time * 8.4) > 0.6 ? 900 : 0) : 0
            if sparks.mainEmitter.birthRate != rate {
                sparks.mainEmitter.birthRate = rate
                island.forgeSparks.components.set(sparks)
            }
        }
        for (i, f) in island.forgeFire.children.enumerated() {
            let s = 1 + sin(time * (9 + Float(i) * 3)) * (forging ? 0.25 : 0.1)
            f.scale = [1, s * (forging ? 1.3 : 1), 1]
        }
        if var light = island.forgeFire.components[PointLightComponent.self] {
            light.intensity = (forging ? 14000 : 5000) * (0.85 + 0.15 * sin(time * 13))
            island.forgeFire.components.set(light)
        }

        let researching = working(.library)
        island.libraryBooks.isEnabled = researching
        if researching {
            island.libraryBooks.orientation = .yaw(time * 0.8)
            for (i, b) in island.libraryBooks.children.enumerated() {
                b.position.y = sin(time * 2 + Float(i)) * 0.18
            }
            if var m = island.libraryBooks.components[ParticleEmitterComponent.self], m.mainEmitter.birthRate == 0 {
                m.mainEmitter.birthRate = 60
                island.libraryBooks.components.set(m)
            }
        }

        let analyzing = working(.observatory)
        for (i, bar) in island.hologramBars.enumerated() {
            let target: Float = analyzing ? 0.35 + 0.65 * abs(sin(time * 1.3 + Float(i) * 0.9)) : 0.15
            bar.scale.y = lerp(bar.scale.y, target, 1 - exp(-dt * 4))
            bar.position.y = 0.12 + bar.scale.y / 2
        }
        island.hologram.orientation = .yaw(analyzing ? sin(time * 0.5) * 0.3 : 0)

        // Letters fly from the sorting table into the mailbox while Hana works.
        let mailing = working(.postOffice)
        letterTimer -= dt
        if mailing, letterTimer <= 0, let l = island.mailLetters.children.first(where: { !$0.isEnabled }) {
            l.isEnabled = true
            letterFlights.append((l, 0))
            letterTimer = 1.1
        }
        letterFlights = letterFlights.compactMap { entity, t in
            let t = t + dt / 1.1
            if t >= 1 { entity.isEnabled = false; return nil }
            let from = SIMD3<Float>(-0.2, 0.65, 1.65), to = SIMD3<Float>(1.25, 0.62, 1.85)
            entity.position = simd_mix(from, to, .init(repeating: t)) + [0, sin(t * .pi) * 0.8, 0]
            entity.orientation = .yaw(t * 6) * .roll(sin(t * 12) * 0.4)
            return (entity, t)
        }

        // Quest marker bobs while anyone is waiting on the player.
        let waiting = !model.pending.isEmpty
        island.questMarker.isEnabled = waiting
        if waiting {
            island.questMarker.position.y = 2.75 + sin(time * 3) * 0.15
            island.questMarker.orientation = .yaw(time * 2)
        }
    }

    private func updateEnvironment(_ dt: Float) {
        island.cloudRing.orientation = .yaw(time * 0.01)
        for (e, phase) in island.floaters {
            e.position.y += sin(time * 0.6 + phase) * 0.003
        }

        // Day / night cycle
        let tod = Float(model.timeOfDay)
        let sunAngle = (tod - 0.25) * 2 * .pi // 0.25 = sunrise, 0.5 = noon
        let elevation = sin(sunAngle)
        let daylight = smoothstep(-0.15, 0.25, elevation)
        let sunDir = simd_normalize(SIMD3<Float>(cos(sunAngle) * 0.8, max(0.35, abs(elevation)), 0.6))
        island.sun.look(at: .zero, from: sunDir * 20, relativeTo: nil)
        if var light = island.sun.components[DirectionalLightComponent.self] {
            light.intensity = 500 + 2600 * daylight
            let warm = 1 - smoothstep(0.2, 0.6, elevation)
            light.color = daylight > 0.05
                ? PlatformColor(hex: FaceArt.mix(0xFFF6EC, 0xFFB27A, CGFloat(warm)))
                : PlatformColor(hex: 0x9FB4FF)
            island.sun.components.set(light)
        }
        let night = 1 - daylight
        for l in island.lanternEntities {
            if var pl = l.components[PointLightComponent.self] {
                pl.intensity = 12000 * night
                l.components.set(pl)
            }
        }

        if var f = island.fireflies.components[ParticleEmitterComponent.self] {
            let rate: Float = night > 0.5 ? 40 : 0
            if f.mainEmitter.birthRate != rate { f.mainEmitter.birthRate = rate; island.fireflies.components.set(f) }
        }

        skyTimer -= dt
        let key = Int(tod * 200)
        if skyTimer <= 0, key != lastSkyKey {
            skyTimer = 0.5
            lastSkyKey = key
            let (top, horizon, bottom) = skyColors(tod)
            let img = FaceArt.sky(top: top, horizon: horizon, bottom: bottom, stars: CGFloat(night))
            try? island.skyTexture?.replace(withImage: img, options: .init(semantic: .color))
        }
    }

    private func skyColors(_ t: Float) -> (UInt32, UInt32, UInt32) {
        // Keyframes across the day: night, dawn, day, dusk, night.
        let keys: [(Float, UInt32, UInt32, UInt32)] = [
            (0.00, 0x0B1033, 0x2A2560, 0x141A40),
            (0.20, 0x1C2366, 0x6B4C8F, 0x2A2F6A),
            (0.27, 0x7C8CE0, 0xFFB3A7, 0xC6A6E8),
            (0.36, 0x6FA8FF, 0xFFE0EC, 0xB9C7FF),
            (0.64, 0x5E9BFF, 0xFFE9F2, 0xB0C4FF),
            (0.74, 0x6A5BC7, 0xFF9E7A, 0xC77DB5),
            (0.82, 0x231E5E, 0x8A4C8F, 0x2C2766),
            (1.00, 0x0B1033, 0x2A2560, 0x141A40),
        ]
        for i in 0..<(keys.count - 1) where t >= keys[i].0 && t <= keys[i + 1].0 {
            let u = CGFloat((t - keys[i].0) / (keys[i + 1].0 - keys[i].0))
            return (FaceArt.mix(keys[i].1, keys[i + 1].1, u), FaceArt.mix(keys[i].2, keys[i + 1].2, u), FaceArt.mix(keys[i].3, keys[i + 1].3, u))
        }
        return (keys[0].1, keys[0].2, keys[0].3)
    }

    // MARK: Projection

    /// World point → view point, using the camera's own transform and lens.
    func project(_ p: SIMD3<Float>) -> CGPoint? {
        let size = projector.viewSize
        guard size.width > 0, size.height > 0 else { return nil }
        let view = camera.transformMatrix(relativeTo: nil).inverse
        let c = view * SIMD4<Float>(p, 1)
        guard c.z < -0.1 else { return nil }
        let aspect = Float(size.width / size.height)
        let half = tan(fov * .pi / 360)
        let tx = horizontalFOV ? half : half * aspect
        let ty = horizontalFOV ? half / aspect : half
        let nx = (c.x / -c.z) / tx, ny = (c.y / -c.z) / ty
        return CGPoint(x: CGFloat((nx + 1) / 2) * size.width, y: CGFloat((1 - ny) / 2) * size.height)
    }

    private func updateProjection() {
        var pts: [String: CGPoint] = [:]
        for a in model.agents {
            let lift: Float = a.mode == .celebrating ? 0.25 : 0
            if let p = project(a.position + [0, ChibiRig.bubbleHeight + lift, 0]) { pts[a.id] = p }
        }
        var st: [StationKind: CGPoint] = [:]
        for s in StationKind.allCases {
            let h: Float = s == .questBoard ? 2.2 : (s == .library ? 4.2 : 3.6)
            if let p = project(polar(s.angle, s.buildingRadius) + [0, h, 0]) { st[s] = p }
        }
        projector.agentPoints = pts
        projector.stationPoints = st
        projector.agentScale = CGFloat(simd_clamp(14 / cam.distance, 0.55, 1.25))
    }
}
