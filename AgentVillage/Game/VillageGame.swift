import SpriteKit
import simd
import SwiftUI

/// The pixel-art village: map, buildings, villagers, effects and the day/night cycle.
@MainActor
final class VillageGame: SKScene {
    let model: WorldModel
    let cam = SKCameraNode()
    private let world = SKNode()
    private var agentNodes: [String: AgentNode] = [:]
    private var lastTime: TimeInterval = 0
    private var time: Double = 0

    // Camera
    var zoom: CGFloat = 2
    private var zoomTarget: CGFloat = 2
    var displayScale: CGFloat = 2
    private var camTarget = CGPoint.zero
    private var followSelected = true

    // Lighting
    private let overlay = SKSpriteNode(color: .white, size: CGSize(width: 4000, height: 4000))
    private var glows: [(SKSpriteNode, CGFloat)] = []
    private var fireflies: SKEmitterNode?

    // Station effects
    private var hologramBars: [SKSpriteNode] = []
    private var books: [SKSpriteNode] = []
    private let booksRoot = SKNode()
    private var questMarker = SKSpriteNode()
    private var letterTimer: Double = 0
    private var sparkleTimer: Double = 0

    private static let tile: CGFloat = 16

    init(model: WorldModel) {
        self.model = model
        super.init(size: CGSize(width: 800, height: 600))
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = PlatformColor(hex: 0x24452C)
        addChild(world)
        addChild(cam)
        camera = cam
        build()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    // MARK: Coordinates

    static func scenePoint(_ x: Double, _ z: Double) -> CGPoint { CGPoint(x: x * tile, y: -z * tile) }

    /// Map pixel (y down) → scene point.
    static func mapPoint(_ px: Double, _ py: Double) -> CGPoint {
        CGPoint(x: px - Double(MapArt.originX) * tile, y: -(py - Double(MapArt.originZ) * tile))
    }

    private func depth(_ y: CGFloat) -> CGFloat { 5 + (1000 - y) / 200 }

    // MARK: Build

    private func build() {
        // Ground + animated water
        let ground = SKSpriteNode(texture: MapArt.ground().texture())
        ground.anchorPoint = CGPoint(x: 0, y: 1)
        ground.position = Self.mapPoint(0, 0)
        ground.zPosition = 0
        world.addChild(ground)

        let waterTex = MapArt.waterFrames().map { $0.texture() }
        let water = SKSpriteNode(texture: waterTex[0])
        water.anchorPoint = CGPoint(x: 0, y: 1)
        water.position = ground.position
        water.zPosition = 1
        water.run(.repeatForever(.animate(with: waterTex, timePerFrame: 0.35)))
        world.addChild(water)

        // Buildings (anchored at their front wall)
        place(Props.library(), at: StationKind.library.buildingPosition, frontOffset: 2.0)
        place(Props.forge(), at: StationKind.forge.buildingPosition, frontOffset: 2.0)
        place(Props.postOffice(), at: StationKind.postOffice.buildingPosition, frontOffset: 2.0)
        place(Props.observatory(), at: StationKind.observatory.buildingPosition, frontOffset: 2.0)

        // Center sakura tree and plaza furniture
        place(Props.sakura(big: true, seed: 3), at: [0, 0, 0.3])
        for (a, i) in zip([Float(-150), -110, -70, 70, 110, 150], 0...) {
            let p = polar(a, 6.4)
            let n = place(Props.lantern(), at: p)
            addGlow(at: n.position + CGPoint(x: 0, y: 17), radius: 18, color: PixelColor(0xFFC266), strength: i % 2 == 0 ? 1 : 0.8)
        }
        place(Props.bench(), at: [-3.2, 0, 4.4])
        place(Props.bench(), at: [3.2, 0, 4.4])

        // Workstations
        let forgeAnvil = StationKind.forge.workSpot + [1.2, 0, 0.05]
        place(Props.anvil(), at: forgeAnvil)
        let fireFrames = (0..<3).map { Props.firePit(frame: $0).texture() }
        let fire = place(Props.firePit(frame: 0), at: StationKind.forge.workSpot + [2.4, 0, -0.6])
        fire.run(.repeatForever(.animate(with: fireFrames, timePerFrame: 0.12)))
        addGlow(at: fire.position + CGPoint(x: 0, y: 10), radius: 26, color: PixelColor(0xFF8A3D), strength: 1, always: 0.35)

        place(Props.sortingTable(), at: StationKind.postOffice.workSpot + [1.3, 0, 0.05])
        place(Props.mailbox(), at: StationKind.postOffice.workSpot + [2.8, 0, -0.3])

        place(Props.bookshelf(), at: StationKind.library.workSpot + [-1.3, 0, -0.1])
        booksRoot.position = Self.scenePoint(Double(StationKind.library.workSpot.x) - 1.3, Double(StationKind.library.workSpot.z) - 2.4)
        booksRoot.zPosition = 30
        world.addChild(booksRoot)
        let bookColors: [UInt32] = [0xE8366E, 0x27C2E8, 0xF5D76E, 0x4ADE80]
        for (i, col) in bookColors.enumerated() {
            let c = PixelCanvas(8, 7)
            c.rect(1, 1, 6, 5, PixelColor(col)); c.vline(1, 1, 5, PixelColor(col).lighter(0.3)); c.rect(2, 2, 4, 3, PixelColor(0xFFF6E0))
            c.outline()
            let b = SKSpriteNode(texture: c.texture())
            b.alpha = 0
            booksRoot.addChild(b)
            books.append(b)
            _ = i
        }

        let telescope = place(Props.telescope(), at: StationKind.observatory.workSpot + [-1.4, 0, -0.4])
        _ = telescope
        let holo = place(Props.hologramBase(), at: StationKind.observatory.workSpot + [-1.2, 0, 0.7])
        for i in 0..<5 {
            let bar = SKSpriteNode(color: i == 3 ? PlatformColor(hex: 0xFF6FA5) : PlatformColor(hex: 0x5CF2FF), size: CGSize(width: 3, height: 1))
            bar.anchorPoint = CGPoint(x: 0.5, y: 0)
            bar.alpha = 0.75
            bar.blendMode = .add
            bar.position = holo.position + CGPoint(x: CGFloat(i * 5 - 10), y: 6)
            bar.zPosition = holo.zPosition + 0.01
            world.addChild(bar)
            hologramBars.append(bar)
        }

        let board = place(Props.questBoard(), at: StationKind.questBoard.buildingPosition)
        questMarker = SKSpriteNode(texture: PixelUI.emoteBang().texture())
        questMarker.position = board.position + CGPoint(x: 0, y: 48)
        questMarker.zPosition = 75
        questMarker.isHidden = true
        world.addChild(questMarker)

        place(Props.torii(), at: [0, 0, 13.2])
        place(Props.signpost(), at: [2.4, 0, 12.4])

        // Clutter
        for p in [SIMD3<Float>(-1.6, 0, -8.0), [-2.4, 0, -7.6], [7.9, 0, -7.9]] { place(Props.barrel(), at: p) }
        for p in [SIMD3<Float>(-7.5, 0, -7.4), [8.6, 0, -7.6], [-9.8, 0, -3.8]] { place(Props.crate(), at: p) }

        // Window glows (night)
        for (s, offs) in [(StationKind.postOffice, [(-1.6, -1.2), (1.6, -1.2)]), (.forge, [(1.6, -1.1)]), (.library, [(-2.6, -1.6), (2.6, -1.6)]), (.observatory, [(-1.0, -2.2), (1.0, -2.2)])] {
            for (ox, oz) in offs {
                let b = s.buildingPosition
                addGlow(at: Self.scenePoint(Double(b.x) + ox, Double(b.z) + 2 + oz), radius: 14, color: PixelColor(0xFFD27A), strength: 0.9)
            }
        }

        scatterNature()
        buildAmbient()

        for a in model.agents {
            let n = AgentNode(persona: a.persona)
            agentNodes[a.id] = n
            world.addChild(n)
            n.onStrike = { [weak self, weak n] in
                guard let self, let n else { return }
                self.burst(at: n.position + CGPoint(x: 18, y: 8), colors: [0xFFF3B0, 0xFFB13B, 0xFF5E1A], count: 7, speed: 26, gravity: -50)
                if self.model.selectedID == n.persona.id { Chiptune.shared.play(.clank) }
            }
            n.onStep = { [weak self, weak n] in
                guard let self, let n, Int.random(in: 0..<3) == 0 else { return }
                self.burst(at: n.position + CGPoint(x: 0, y: 1), colors: [0xE8D2A8, 0xD9C090], count: 2, speed: 6, gravity: 8, life: 0.35)
            }
        }

        // Day/night overlay rides on the camera
        overlay.blendMode = .multiply
        overlay.zPosition = 50
        cam.addChild(overlay)

        model.onEvent = { [weak self] e in self?.handle(e) }
    }

    @discardableResult
    private func place(_ art: PixelCanvas, at p: SIMD3<Float>, frontOffset: Float = 0) -> SKSpriteNode {
        let n = SKSpriteNode(texture: art.texture())
        n.anchorPoint = CGPoint(x: 0.5, y: 2.0 / CGFloat(art.height))
        let pos = Self.scenePoint(Double(p.x), Double(p.z + frontOffset))
        n.position = CGPoint(x: pos.x.rounded(), y: pos.y.rounded())
        n.zPosition = depth(n.position.y)
        world.addChild(n)
        return n
    }

    private func addGlow(at p: CGPoint, radius: Int, color: PixelColor, strength: CGFloat, always: CGFloat = 0) {
        let g = SKSpriteNode(texture: Props.glow(radius: radius, color: color).texture())
        g.position = p
        g.blendMode = .add
        g.zPosition = 55
        g.alpha = always
        world.addChild(g)
        glows.append((g, strength))
        if always > 0 { g.userData = ["always": always] }
    }

    private func scatterNature() {
        var rng = PixelRandom(99)
        var occupied: [SIMD2<Double>] = []
        func free(_ x: Double, _ z: Double, _ r: Double) -> Bool {
            if hypot(x, z) < MapArt.plazaRadius + 1.6 { return false }
            if MapArt.waterValue(x, z) > -0.5 { return false }
            for (a, b, w) in MapArt.paths {
                let p = SIMD2(x, z), ab = b - a
                let t = max(0, min(1, simd_dot(p - a, ab) / simd_length_squared(ab)))
                if simd_length(p - (a + ab * t)) < w + 1.1 { return false }
            }
            for s in StationKind.allCases {
                let b = s.buildingPosition
                if abs(x - Double(b.x)) < 4.6 && z > Double(b.z) - 4 && z < Double(b.z) + 3.4 { return false }
                let w = s.workSpot
                if hypot(x - Double(w.x), z - Double(w.z)) < 3.2 { return false }
            }
            if abs(x) < 3.5 && z > 11 && z < 14.5 { return false }
            return !occupied.contains { simd_distance($0, SIMD2(x, z)) < r }
        }
        // Dense forest border, lighter scatter inside
        for _ in 0..<900 {
            let x = rng.next() * 40 - 20, z = rng.next() * 34 - 17
            let border = abs(x) > 15.5 || z < -12.5 || z > 12.5
            guard rng.chance(border ? 0.55 : 0.07), free(x, z, border ? 1.7 : 2.4) else { continue }
            occupied.append(SIMD2(x, z))
            let kind = rng.next()
            let art: PixelCanvas
            if kind < 0.42 { art = Props.tree(seed: UInt64(rng.int(0, 999)), pine: true) }
            else if kind < 0.84 { art = Props.tree(seed: UInt64(rng.int(0, 999)), pine: false) }
            else { art = Props.sakura(big: false, seed: UInt64(rng.int(0, 999))) }
            place(art, at: [Float(x), 0, Float(z)])
        }
        for _ in 0..<300 {
            let x = rng.next() * 38 - 19, z = rng.next() * 32 - 16
            guard rng.chance(0.25), free(x, z, 1.0) else { continue }
            occupied.append(SIMD2(x, z))
            place(rng.chance(0.65) ? Props.bush(seed: UInt64(rng.int(0, 99))) : Props.rock(seed: UInt64(rng.int(0, 9))), at: [Float(x), 0, Float(z)])
        }
    }

    private func buildAmbient() {
        // Sakura petals drifting over the whole map
        let petals = SKEmitterNode()
        petals.particleTexture = Props.particle("petal").texture()
        petals.particleBirthRate = 5
        petals.particleLifetime = 26
        petals.particlePositionRange = CGVector(dx: Double(MapArt.pixelWidth), dy: 40)
        petals.position = CGPoint(x: 0, y: Double(MapArt.originZ) * 16 + 10)
        petals.emissionAngle = -.pi / 2
        petals.emissionAngleRange = 0.6
        petals.particleSpeed = 16
        petals.particleSpeedRange = 8
        petals.xAcceleration = 3
        petals.yAcceleration = -1.2
        petals.particleRotationRange = .pi
        petals.particleRotationSpeed = 1.2
        petals.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 1, 0], times: [0, 0.05, 0.9, 1])
        petals.zPosition = 45
        petals.advanceSimulationTime(30)
        world.addChild(petals)

        // Fireflies near the pond and plaza (only at night)
        let ff = SKEmitterNode()
        ff.particleTexture = Props.particle("spark").texture()
        ff.particleBirthRate = 0
        ff.particleLifetime = 5
        ff.particleLifetimeRange = 2
        ff.particlePositionRange = CGVector(dx: 420, dy: 300)
        ff.position = Self.scenePoint(3, 2)
        ff.particleSpeed = 4
        ff.particleSpeedRange = 4
        ff.emissionAngleRange = .pi * 2
        ff.particleColor = PlatformColor(hex: 0xFFF3A0)
        ff.particleColorBlendFactor = 1
        ff.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 0.3, 1, 0], times: [0, 0.2, 0.5, 0.7, 1])
        ff.particleBlendMode = .add
        ff.zPosition = 58
        world.addChild(ff)
        fireflies = ff

        // Chimney smoke
        let smoke = SKEmitterNode()
        smoke.particleTexture = Props.particle("smoke").texture()
        smoke.particleBirthRate = 2.2
        smoke.particleLifetime = 4
        smoke.position = Self.scenePoint(Double(StationKind.forge.buildingPosition.x) + 1.0, Double(StationKind.forge.buildingPosition.z) - 3.4)
        smoke.emissionAngle = .pi / 2
        smoke.emissionAngleRange = 0.3
        smoke.particleSpeed = 12
        smoke.xAcceleration = 4
        smoke.particleScale = 0.8
        smoke.particleScaleSpeed = 0.5
        smoke.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.75, 0], times: [0, 0.2, 1])
        smoke.zPosition = 44
        world.addChild(smoke)

        // Butterflies fluttering around the meadow
        for i in 0..<5 {
            let colors: [UInt32] = [0xFFD23F, 0xFFFFFF, 0xA78BFA, 0xFF8FB0, 0x7FE3FF]
            let frames = (0..<2).map { f -> SKTexture in
                let c = PixelCanvas(7, 5)
                let col = PixelColor(colors[i])
                if f == 0 { c.draw(["cc.cc", "ccWcc", ".c.c."], at: 1, 1, palette: ["c": col, "W": PixelColor(0x2A1A33)]) }
                else { c.draw([".c.c.", ".cWc.", "..c.."], at: 1, 1, palette: ["c": col, "W": PixelColor(0x2A1A33)]) }
                return c.texture()
            }
            let b = SKSpriteNode(texture: frames[0])
            b.zPosition = 40
            b.position = Self.scenePoint(Double(i * 7 - 14), Double(i % 2 == 0 ? 3 : -3))
            b.run(.repeatForever(.animate(with: frames, timePerFrame: 0.12)))
            world.addChild(b)
            wander(b, around: b.position)
        }

        // Soft cloud shadows sliding across
        for i in 0..<3 {
            let c = PixelCanvas(120, 70)
            for k in 0..<5 { c.ellipse(25 + Double(k) * 17, 35 + Double(k % 2) * 6 - 3, 26, 20, PixelColor(0x1A2A40).alpha(255)) }
            let shadowNode = SKSpriteNode(texture: c.texture())
            shadowNode.alpha = 0.13
            shadowNode.setScale(2)
            shadowNode.zPosition = 42
            let y = CGFloat(i * 170 - 170)
            shadowNode.position = CGPoint(x: -500 + CGFloat(i * 330), y: y)
            world.addChild(shadowNode)
            let dur = 90.0 + Double(i) * 20
            shadowNode.run(.repeatForever(.sequence([
                .moveTo(x: 620, duration: dur * Double(620 - shadowNode.position.x) / 1240),
                .moveTo(x: -620, duration: 0),
                .moveTo(x: 620, duration: dur),
            ])))
        }
    }

    private func wander(_ node: SKNode, around home: CGPoint) {
        let target = home + CGPoint(x: CGFloat.random(in: -60...60), y: CGFloat.random(in: -40...40))
        node.run(.sequence([.move(to: target, duration: Double.random(in: 2...4)), .wait(forDuration: 0.3)])) { [weak self, weak node] in
            guard let self, let node else { return }
            self.wander(node, around: home)
        }
    }

    // MARK: Effects

    func burst(at p: CGPoint, colors: [UInt32], count: Int, speed: CGFloat, gravity: CGFloat, life: Double = 0.6, size: CGFloat = 2) {
        for _ in 0..<count {
            let s = SKSpriteNode(color: PlatformColor(hex: colors.randomElement()!), size: CGSize(width: size, height: size))
            s.position = p
            s.zPosition = 46
            world.addChild(s)
            let a = CGFloat.random(in: 0...(2 * .pi))
            let v = CGFloat.random(in: speed * 0.4...speed)
            let dx = cos(a) * v * CGFloat(life), dy = sin(a) * v * CGFloat(life) + gravity * CGFloat(life * life) / 2
            s.run(.sequence([.group([.moveBy(x: dx, y: dy, duration: life), .sequence([.wait(forDuration: life * 0.6), .fadeOut(withDuration: life * 0.4)])]), .removeFromParent()]))
        }
    }

    private func floatingText(_ text: String, at p: CGPoint, color: PixelColor) {
        let tex = PixelFont.render(text, color: color, outline: PixelUI.ink).texture()
        let n = SKSpriteNode(texture: tex)
        n.position = p
        n.zPosition = 80
        world.addChild(n)
        n.run(.sequence([.group([.moveBy(x: 0, y: 24, duration: 1.4), .sequence([.wait(forDuration: 1), .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
    }

    private func handle(_ e: GameEvent) {
        let sound = Chiptune.shared
        switch e {
        case .questStart(let id):
            if model.selectedID == id { sound.play(.questStart) }
        case .questDone(let id):
            sound.play(.questDone)
            if let n = agentNodes[id] {
                burst(at: n.position + CGPoint(x: 0, y: 14), colors: [0xFFD23F, 0xFF6FA5, 0x5CF2FF, 0x4ADE80, 0xFFFFFF], count: 26, speed: 70, gravity: -90, life: 1.0)
                floatingText("QUEST CLEAR!", at: n.position + CGPoint(x: 0, y: 60), color: PixelColor(0xFFD23F))
            }
        case .approvalNeeded:
            sound.play(.alert)
        case .approved(let id):
            sound.play(.approved)
            if let n = agentNodes[id] { burst(at: n.position + CGPoint(x: 0, y: 16), colors: [0x4ADE80, 0xB4F5C8, 0xFFFFFF], count: 16, speed: 50, gravity: -40) }
        case .denied:
            sound.play(.denied)
        case .chat(let id):
            if let n = agentNodes[id] { floatingText("♥", at: n.position + CGPoint(x: 10, y: 30), color: PixelColor(0xFF6F91)) }
        case .speak(let id, let style):
            if model.selectedID == id || style == .shout {
                let pitch: [String: Double] = ["hana": 880, "ren": 440, "yuki": 660, "kaito": 520]
                sound.play(.voice(pitch: pitch[id] ?? 600))
            }
        case .pause: sound.play(.pause)
        case .wake: sound.play(.wake)
        }
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 1.0 / 60 : min(0.1, currentTime - lastTime)
        lastTime = currentTime
        time += dt
        model.tick(dt)

        for a in model.agents {
            agentNodes[a.id]?.update(a, selected: model.selectedID == a.id, time: time, overlayZ: 50)
        }
        updateStations(dt)
        updateLighting()
        updateCamera(dt)
    }

    private func working(_ s: StationKind) -> Bool {
        model.agents.contains { $0.persona.station == s && $0.mode == .working }
    }

    private func updateStations(_ dt: Double) {
        // Orbiting magic books + sparkles while researching
        let reading = working(.library)
        for (i, b) in books.enumerated() {
            let a = time * 1.6 + Double(i) * .pi / 2
            b.position = CGPoint(x: (cos(a) * 16).rounded(), y: (sin(a) * 6 + sin(time * 3 + Double(i)) * 2).rounded())
            b.zPosition = sin(a) > 0 ? -1 : 1
            b.alpha = reading ? min(1, b.alpha + CGFloat(dt) * 2) : max(0, b.alpha - CGFloat(dt) * 2)
        }
        sparkleTimer -= dt
        if reading, sparkleTimer <= 0 {
            sparkleTimer = 0.35
            burst(at: booksRoot.position + CGPoint(x: CGFloat.random(in: -14...14), y: CGFloat.random(in: -6...8)), colors: [0xA78BFA, 0xF5D76E, 0xFFFFFF], count: 3, speed: 12, gravity: 10, life: 0.8)
        }

        // Hologram bars bounce while analyzing
        let analyzing = working(.observatory)
        for (i, bar) in hologramBars.enumerated() {
            let target: CGFloat = analyzing ? CGFloat(6 + 14 * abs(sin(time * 1.4 + Double(i) * 0.9))) : 2
            bar.size.height = (bar.size.height + (target - bar.size.height) * CGFloat(min(1, dt * 5))).rounded()
        }

        // Letters fly into the mailbox while mailing
        letterTimer -= dt
        if working(.postOffice), letterTimer <= 0 {
            letterTimer = 1.2
            let from = Self.scenePoint(Double(StationKind.postOffice.workSpot.x) + 1.3, Double(StationKind.postOffice.workSpot.z) - 0.4)
            let to = Self.scenePoint(Double(StationKind.postOffice.workSpot.x) + 2.8, Double(StationKind.postOffice.workSpot.z) - 1.4)
            let l = SKSpriteNode(texture: CharacterSprites.prop(.letter))
            l.position = from
            l.zPosition = 46
            l.setScale(0.8)
            world.addChild(l)
            let path = CGMutablePath()
            path.move(to: from)
            path.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2, y: max(from.y, to.y) + 30))
            l.run(.sequence([.follow(path, asOffset: false, orientToPath: false, duration: 0.9), .scale(to: 0, duration: 0.1), .removeFromParent()]))
        }

        // Quest marker
        questMarker.isHidden = model.pending.isEmpty
        questMarker.position.y = questMarker.position.y.rounded()
        if !questMarker.isHidden {
            let board = Self.scenePoint(Double(StationKind.questBoard.buildingPosition.x), Double(StationKind.questBoard.buildingPosition.z))
            questMarker.position = CGPoint(x: board.x, y: board.y + 48 + (Int(time * 4) % 2 == 0 ? 0 : 2))
        }
    }

    private func updateLighting() {
        let t = model.timeOfDay
        let keys: [(Double, UInt32)] = [(0, 0x5A62B0), (0.2, 0x6A6AB8), (0.26, 0xF0B8C8), (0.33, 0xFFFFFF), (0.68, 0xFFFFFF), (0.75, 0xFFB890), (0.8, 0x8A6AB8), (0.86, 0x5A62B0), (1, 0x5A62B0)]
        var col: UInt32 = 0xFFFFFF
        for i in 0..<(keys.count - 1) where t >= keys[i].0 && t <= keys[i + 1].0 {
            let u = (t - keys[i].0) / (keys[i + 1].0 - keys[i].0)
            col = PixelColor(keys[i].1).mix(PixelColor(keys[i + 1].1), u).hex
        }
        overlay.color = PlatformColor(hex: col)
        overlay.colorBlendFactor = 1
        let night: CGFloat = (t < 0.24 || t > 0.78) ? 1 : (t < 0.3 ? CGFloat((0.3 - t) / 0.06) : (t > 0.72 ? CGFloat((t - 0.72) / 0.06) : 0))
        for (g, s) in glows {
            let base = (g.userData?["always"] as? CGFloat) ?? 0
            g.alpha = max(base, night * s)
        }
        if let ff = fireflies { ff.particleBirthRate = night > 0.5 ? 14 : 0 }
    }

    // MARK: Camera

    func setDefaultZoom(viewSize: CGSize) {
        let phone = viewSize.width < 700
        zoomTarget = (phone ? 4 : 4) / displayScale
        if phone { zoomTarget = 5 / displayScale } else { zoomTarget = max(4, (viewSize.width / 520 * displayScale).rounded()) / displayScale }
        zoom = zoomTarget
        cam.setScale(1 / zoom)
    }

    func pan(dx: CGFloat, dy: CGFloat) {
        followSelected = false
        camTarget.x -= dx / zoom
        camTarget.y += dy / zoom
    }

    func zoomBy(_ f: CGFloat) {
        let device = (zoomTarget * displayScale * f).rounded()
        zoomTarget = max(2, min(12, device)) / displayScale
    }

    func recenter() {
        camTarget = .zero
        followSelected = true
        setDefaultZoom(viewSize: size)
    }

    func focusSelected() {
        followSelected = true
        let device = max(zoomTarget * displayScale, size.width < 700 ? 8 : 6)
        zoomTarget = device / displayScale
    }

    /// Agent under a point in view coordinates (origin top-left).
    func agent(atView p: CGPoint) -> String? {
        let sp = CGPoint(x: cam.position.x + (p.x - size.width / 2) / zoom, y: cam.position.y - (p.y - size.height / 2) / zoom)
        var best: (String, CGFloat)?
        for (id, n) in agentNodes {
            let c = n.position + CGPoint(x: 0, y: 12)
            let d = hypot(c.x - sp.x, (c.y - sp.y) * 0.8)
            if d < 18, d < (best?.1 ?? .infinity) { best = (id, d) }
        }
        return best?.0
    }

    private func updateCamera(_ dt: Double) {
        if followSelected, let a = model.selected {
            camTarget = Self.scenePoint(Double(a.position.x), Double(a.position.z)) + CGPoint(x: 0, y: size.width < 700 ? -110 / zoom : -60 / zoom)
        }
        // Keep the view inside the map
        let halfW = size.width / zoom / 2, halfH = size.height / zoom / 2
        let margin: CGFloat = 48
        let mapHalfW = CGFloat(MapArt.pixelWidth) / 2 + margin, top = CGFloat(MapArt.originZ) * 16 + margin, bottom = CGFloat(MapArt.rows - MapArt.originZ) * 16 + margin
        let cx = CGFloat(MapArt.pixelWidth) / 2 - CGFloat(MapArt.originX) * 16
        camTarget.x = halfW >= mapHalfW ? cx : min(max(camTarget.x, cx - mapHalfW + halfW), cx + mapHalfW - halfW)
        camTarget.y = halfH * 2 >= top + bottom ? (top - bottom) / 2 : min(max(camTarget.y, -bottom + halfH), top - halfH)

        let k = CGFloat(1 - exp(-dt * 6))
        zoom += (zoomTarget - zoom) * k
        if abs(zoom - zoomTarget) < 0.002 { zoom = zoomTarget }
        cam.setScale(1 / zoom)
        var p = cam.position + (camTarget - cam.position) * k
        // Snap to the device pixel grid so pixel art stays crisp
        let grid = 1 / (zoom * displayScale)
        p.x = (p.x / grid).rounded() * grid
        p.y = (p.y / grid).rounded() * grid
        cam.position = p
    }
}

// MARK: CGPoint math

func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
func * (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }
