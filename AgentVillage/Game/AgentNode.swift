import SpriteKit

/// One villager on the map: sprite, shadow, held prop, name plate, speech bubble and emotes.
@MainActor
final class AgentNode: SKNode {
    let persona: Persona
    private let shadowNode: SKSpriteNode
    let sprite = SKSpriteNode()
    private let prop: SKSpriteNode
    private let plate = SKSpriteNode()
    private let bubble = SKSpriteNode()
    private let emote: SKSpriteNode
    private let ring = SKSpriteNode()
    private let arrow: SKSpriteNode
    private var ringFrames: [SKTexture] = []
    private var shownBubble: UUID?
    private var shownPlate = ""
    private var lastHammerPhase: Double = 0
    var onStrike: (() -> Void)?
    var onStep: (() -> Void)?
    private var lastStep = 0

    init(persona p: Persona) {
        persona = p
        shadowNode = SKSpriteNode(texture: PixelUI.shadow().texture())
        prop = SKSpriteNode(texture: CharacterSprites.prop(p.prop))
        emote = SKSpriteNode(texture: PixelUI.emoteBang().texture())
        arrow = SKSpriteNode(texture: PixelUI.selectArrow().texture())
        super.init()

        let accent = PixelColor(p.aura)
        ringFrames = (0..<2).map { PixelUI.selectionRing(accent, phase: $0).texture() }
        ring.texture = ringFrames[0]
        ring.size = ringFrames[0].size()
        ring.zPosition = -0.2
        ring.run(.repeatForever(.animate(with: ringFrames, timePerFrame: 0.2)))
        addChild(ring)

        shadowNode.zPosition = -0.1
        shadowNode.position = CGPoint(x: 0, y: 1)
        addChild(shadowNode)

        sprite.anchorPoint = CGPoint(x: 0.5, y: 2.0 / 27.0)
        sprite.size = CGSize(width: CharacterSprites.frameW, height: CharacterSprites.frameH)
        addChild(sprite)
        prop.zPosition = 0.05
        sprite.addChild(prop)

        plate.anchorPoint = CGPoint(x: 0.5, y: 0)
        plate.zPosition = 60
        addChild(plate)
        bubble.anchorPoint = CGPoint(x: 0.5, y: 0)
        bubble.zPosition = 70
        addChild(bubble)
        emote.anchorPoint = CGPoint(x: 0.5, y: 0)
        emote.zPosition = 71
        addChild(emote)
        arrow.zPosition = 72
        addChild(arrow)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func update(_ a: AgentState, selected: Bool, time: Double, overlayZ: CGFloat) {
        // Pixel-snapped map position
        let x = (Double(a.position.x) * 16).rounded(), y = (-Double(a.position.z) * 16).rounded()
        position = CGPoint(x: x, y: y)
        zPosition = 5 + (1000 - y) / 200

        // Facing
        let dx = sin(Double(a.yaw)), dz = cos(Double(a.yaw))
        var facing: Facing = abs(dx) > abs(dz) * 0.9 ? .side : (dz > 0 ? .down : .up)
        var flip = facing == .side && dx < 0
        let t = Double(a.animTime)
        var lift: Double = 0
        var step = 0

        switch a.mode {
        case .walking:
            step = [1, 0, 2, 0][Int(t * 9) % 4]
            if step != 0, step != lastStep { onStep?() }
        case .celebrating:
            if a.stateTime < 0.6 {
                let spin = Int(a.stateTime * 14) % 4
                facing = [.down, .side, .up, .side][spin]
                flip = spin == 3
            } else {
                facing = .down; flip = false
                lift = abs(sin(t * 9)) * 9
            }
        case .awaitingApproval:
            facing = .down; flip = false
            lift = abs(sin(t * 7)) * 3
        case .working:
            if persona.motion == .hammer {
                let phase = (t * 1.7).truncatingRemainder(dividingBy: 1)
                if phase < lastHammerPhase { onStrike?() }
                lastHammerPhase = phase
                lift = phase > 0.85 ? 1 : 0
            } else {
                lift = Int(t * 2.5) % 2 == 0 ? 0 : 1
            }
        case .chatting:
            lift = Int(t * 4) % 2 == 0 ? 0 : 1
        case .paused:
            lift = -1
        case .resting:
            lift = Int(t * 1.4) % 2 == 0 ? 0 : 1
        }
        lastStep = step

        sprite.texture = CharacterSprites.frame(persona, facing: facing, step: step, expression: a.expression)
        sprite.xScale = flip ? -1 : 1
        sprite.position = CGPoint(x: 0, y: lift.rounded())
        shadowNode.setScale(lift > 3 ? 0.8 : 1)

        updateProp(a, facing: facing, time: t)

        // Name plate
        let plateKey = "\(selected)"
        if plateKey != shownPlate {
            shownPlate = plateKey
            let tex = PixelUI.namePlate(persona.name, color: PixelColor(persona.aura), selected: selected).texture()
            plate.setScale(1)
            plate.texture = tex
            plate.size = tex.size()
        }
        plate.position = CGPoint(x: 0, y: 29 + lift.rounded())

        // Speech bubble
        if let b = a.bubble {
            if b.id != shownBubble {
                shownBubble = b.id
                let tex = PixelUI.bubble(b.text, style: b.style, accent: PixelColor(persona.aura)).texture()
                bubble.removeAllActions()
                bubble.setScale(1)
                bubble.texture = tex
                bubble.size = tex.size()
                bubble.setScale(0.2)
                bubble.alpha = 1
                bubble.run(.sequence([.scale(to: 1.15, duration: 0.09), .scale(to: 1, duration: 0.06)]))
            }
            bubble.isHidden = false
        } else if shownBubble != nil {
            shownBubble = nil
            bubble.run(.sequence([.scale(to: 0.1, duration: 0.08), .hide()]))
        }
        bubble.position = CGPoint(x: 0, y: 43 + lift.rounded())

        // Emote and selection
        let calling = a.mode == .awaitingApproval
        emote.isHidden = !calling
        if calling {
            let bubbleH = bubble.isHidden ? 0 : bubble.size.height
            emote.position = CGPoint(x: 0, y: 45 + bubbleH + (Int(time * 5) % 2 == 0 ? 0 : 2))
        }
        ring.isHidden = !(selected || calling)
        arrow.isHidden = !selected
        arrow.position = CGPoint(x: -PixelFont.measure(persona.name) / 2 - 10, y: 34 + (Int(time * 4) % 2 == 0 ? 0 : 1))
        arrow.zRotation = .pi / 2
    }

    private func updateProp(_ a: AgentState, facing: Facing, time t: Double) {
        let holding = a.task != nil || a.mode == .celebrating
        prop.isHidden = !holding || facing == .up
        guard holding else { return }
        prop.zRotation = 0
        switch facing {
        case .side:
            prop.position = CGPoint(x: 6, y: 9)
        case .down:
            prop.position = CGPoint(x: persona.prop == .book || persona.prop == .tablet ? 0 : -6, y: 8)
        case .up:
            prop.position = CGPoint(x: -6, y: 8)
        }
        guard a.mode == .working else { return }
        switch persona.motion {
        case .hammer:
            let phase = (t * 1.7).truncatingRemainder(dividingBy: 1)
            prop.zRotation = phase < 0.75 ? CGFloat(phase / 0.75 * 1.8) : CGFloat((1 - (phase - 0.75) / 0.25) * 1.8)
            prop.position = CGPoint(x: 7, y: 12)
        case .sort:
            prop.position.y += CGFloat(Int(t * 5) % 2 == 0 ? 0 : 2)
        case .read:
            prop.position = CGPoint(x: 5, y: 10 + (Int(t * 1.5) % 2 == 0 ? 0 : 1))
        case .observe:
            prop.position = CGPoint(x: 6, y: 11)
        }
    }
}
