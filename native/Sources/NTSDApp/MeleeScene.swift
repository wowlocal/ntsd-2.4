import AppKit
import SpriteKit
import NTSDCore

final class MeleeScene: SKScene {
    let assets: Assets
    let characters: [ObjectDefinition]
    let voices: ObjectDefinition
    let projectileAssets: [Int: ObjectDefinition]
    let arena: BackgroundDefinition
    private(set) var engine: OriginalMelee
    private var clock = OriginalClock()
    private var layers: [(OriginalBackgroundLayer, SKSpriteNode)] = []
    private let actors = [SKSpriteNode(), SKSpriteNode()], shadows = [SKSpriteNode(), SKSpriteNode()]
    private let hpBars = [SKSpriteNode(), SKSpriteNode()], redBars = [SKSpriteNode(), SKSpriteNode()]
    private var projectileNodes: [Int: (sprite: SKSpriteNode, shadow: SKSpriteNode)] = [:]
    private let mpBars = [SKSpriteNode(), SKSpriteNode()]
    private let mpLabels = [SKLabelNode(fontNamed: "Menlo"), SKLabelNode(fontNamed: "Menlo")]
    private let hpLabels = [SKLabelNode(fontNamed: "Menlo"), SKLabelNode(fontNamed: "Menlo")]
    private var unavailable = false
    private var previewing = false
    private let pauseShade = SKSpriteNode(color: NSColor.black.withAlphaComponent(0.55), size: CGSize(width: 794, height: 550))
    private let pauseText = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    var input: FighterInput = []
    var opponentInput: FighterInput = []
    private(set) var manuallyPaused = false
    private var active = true
    var isRunning: Bool { active && !manuallyPaused && !unavailable }
    var onPauseChange: ((Bool) -> Void)?

    init(assets: Assets) throws {
        self.assets = assets
        guard let naruto = assets.game.object(2), let sasuke = assets.game.object(11),
              let voices = assets.game.object(203), let snake = assets.game.object(224),
              let needles = assets.game.object(440), let random = assets.game.practiceRandom,
              naruto.originalText != nil, sasuke.originalText != nil, voices.originalText != nil,
              snake.originalText != nil, needles.originalText != nil,
              let arena = assets.game.backgrounds.first(where: { $0.id == 0 }) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Original Naruto / Sasuke / District data is missing")
        }
        self.characters = [naruto, sasuke]; self.voices = voices; self.arena = arena
        projectileAssets = [224: snake, 440: needles]
        engine = try Self.makeEngine(characters: characters, voices: voices, projectiles: projectileAssets, random: random)
        super.init(size: CGSize(width: 794, height: 550))
        scaleMode = .aspectFit; backgroundColor = .black
        for (index, fields) in arena.layers.enumerated() {
            guard let path = fields["file"], let texture = assets.texture(path, transparent: fields.integer("transparency") == 1) else {
                throw OriginalLoaderError.outsideVerifiedDomain("Original District bitmap is missing")
            }
            let node = SKSpriteNode(texture: texture)
            node.anchorPoint = CGPoint(x: 0, y: 1); node.zPosition = CGFloat(index)
            layers.append((OriginalBackgroundLayer(fields: fields), node)); addChild(node)
        }
        // Source bitmap has its original 37 × 9 size; original rendering uses
        // integer halves of shadowsize as offsets, with no jump-height scaling.
        for i in characters.indices {
            let shadow = shadows[i], actor = actors[i]
            shadow.texture = assets.texture(arena.header["shadow"]!)
            shadow.size = shadow.texture?.size() ?? .zero; shadow.anchorPoint = CGPoint(x: 0, y: 1)
            shadow.zPosition = 50; addChild(shadow)
            actor.anchorPoint = CGPoint(x: 0, y: 1); addChild(actor)
            for record in engine.fighters[i].frames.values {
                _ = assets.sprite(characters[i], picture: Int(record.field("pic")!))
            }
            let panel = SKSpriteNode(color: NSColor(calibratedWhite: 0.08, alpha: 0.84), size: CGSize(width: 204, height: 67))
            panel.anchorPoint = CGPoint(x: 0, y: 1); panel.position = CGPoint(x: 14 + i * 562, y: 536)
            panel.zPosition = 90; addChild(panel)
            let portrait = SKSpriteNode(texture: assets.texture(characters[i].header["small"]!, transparent: false))
            portrait.anchorPoint = CGPoint(x: 0, y: 1); portrait.position = CGPoint(x: 7, y: -7)
            panel.addChild(portrait)
            let label = hpLabels[i]; label.fontSize = 11; label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: 45, y: -18); panel.addChild(label)
            let empty = SKSpriteNode(color: .black, size: CGSize(width: 150, height: 9))
            empty.anchorPoint = CGPoint(x: 0, y: 0); empty.position = CGPoint(x: 45, y: -35); panel.addChild(empty)
            for (bar, color) in [(redBars[i], NSColor(calibratedRed: 0.5, green: 0.16, blue: 0.13, alpha: 1)),
                                 (hpBars[i], NSColor(calibratedRed: 0.92, green: 0.38, blue: 0.19, alpha: 1))] {
                bar.color = color; bar.anchorPoint = CGPoint(x: 0, y: 0); bar.position = CGPoint(x: 45, y: -35)
                bar.zPosition = bar === hpBars[i] ? 2 : 1; panel.addChild(bar)
            }
            let mp = mpBars[i]
            mp.color = NSColor(calibratedRed: 0.24, green: 0.57, blue: 0.96, alpha: 1)
            mp.anchorPoint = CGPoint(x: 0, y: 0); mp.position = CGPoint(x: 45, y: -49); panel.addChild(mp)
            let mpLabel = mpLabels[i]; mpLabel.fontSize = 9; mpLabel.horizontalAlignmentMode = .left
            mpLabel.position = CGPoint(x: 45, y: -61); panel.addChild(mpLabel)
        }
        for object in projectileAssets.values {
            for number in ProjectileDefinition.frameNumbers(id: object.id) {
                if let frame = engine.projectileFrame(id: object.id, frame: number) {
                    _ = assets.sprite(object, picture: Int(frame.field("pic")!))
                }
            }
        }
        pauseShade.position = CGPoint(x: 397, y: 275); pauseShade.zPosition = 100
        pauseShade.isHidden = true; addChild(pauseShade)
        pauseText.text = "Пауза"; pauseText.fontSize = 27; pauseText.verticalAlignmentMode = .center
        pauseShade.addChild(pauseText)
        renderState()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func update(_ currentTime: TimeInterval) {
        guard isRunning && !previewing else { return }
        let now = UInt32(truncatingIfNeeded: UInt64(ProcessInfo.processInfo.systemUptime * 1000))
        let ticks = clock.ticks(at: now)
        guard ticks > 0 else { return }
        for _ in 0..<ticks {
            do {
                let state = try engine.tick(engine.localPlayer == 0 ? [input, opponentInput] : [opponentInput, input])
                for index in layers.indices { layers[index].0.tick() }
                let builtins = ["builtin:0":"data/001.wav", "builtin:1":"data/002.wav", "builtin:2":"data/006.wav",
                                "builtin:6":"data/016.wav", "builtin:7":"data/017.wav", "builtin:11":"data/032.wav", "builtin:12":"data/033.wav"]
                for sound in state.sounds { assets.sound(builtins[sound] ?? sound) }
            } catch {
                unavailable = true; input = []; opponentInput = []
                pauseText.text = "Приём пока недоступен · R — заново"; pauseText.fontSize = 19
                fputs("Melee practice boundary: \(error)\n", stderr)
                pauseChanged(); break
            }
        }
        renderState()
    }
    private func renderState() {
        let world = engine.state
        for (layer, node) in layers {
            node.position = CGPoint(x: layer.x(camera: world.cameraX), y: 550 - layer.fields.integer("y"))
            node.isHidden = !layer.visible
        }
        for i in characters.indices {
            let state = world.actors[i], frame = engine.fighters[i].frames[state.renderFrame]!
            let actor = actors[i], shadow = shadows[i]
            actor.texture = assets.sprite(characters[i], picture: Int(frame.field("pic")!))
            actor.size = actor.texture?.size() ?? .zero
            actor.xScale = state.renderFacing == 0 ? 1 : -1
            actor.zPosition = 51 + CGFloat(state.renderZ - 450) * 0.1 + CGFloat(i) * 0.001
            let center = Int(frame.field("centerx")!)
            actor.position = CGPoint(x: state.renderX - world.cameraX + (state.renderFacing == 0 ? -center : center),
                                     y: 550 - (state.renderZ + state.renderY - Int(frame.field("centery")!)))
            shadow.position = CGPoint(x: state.renderX - world.cameraX - 18, y: 550 - (state.renderZ - 4))
            hpLabels[i].text = "\(engine.localPlayer == i ? "› " : "")\(characters[i].name)  \(max(0,state.hp))/500"
            hpBars[i].size = CGSize(width: 150 * Double(max(0,min(500,state.hp))) / 500, height: 9)
            redBars[i].size = CGSize(width: 150 * Double(max(0,min(500,state.redHP))) / 500, height: 9)
            mpBars[i].size = CGSize(width: 150 * Double(max(0,min(500,state.mp))) / 500, height: 6)
            mpLabels[i].text = "Чакра  \(max(0,state.mp))/500"
        }
        let poses = world.projectileDraws ?? []
        let visibleSlots = Set(poses.map(\.slot))
        for slot in Array(projectileNodes.keys) where !visibleSlots.contains(slot) {
            projectileNodes[slot]!.sprite.removeFromParent(); projectileNodes[slot]!.shadow.removeFromParent()
            projectileNodes.removeValue(forKey: slot)
        }
        for pose in poses {
            guard let object = projectileAssets[pose.id], let frame = engine.projectileFrame(id: pose.id, frame: pose.frame) else { continue }
            if projectileNodes[pose.slot] == nil {
                let sprite = SKSpriteNode(), shadow = SKSpriteNode(texture: assets.texture(arena.header["shadow"]!))
                sprite.anchorPoint = CGPoint(x: 0, y: 1); shadow.anchorPoint = CGPoint(x: 0, y: 1)
                shadow.zPosition = 50; addChild(shadow); addChild(sprite)
                projectileNodes[pose.slot] = (sprite, shadow)
            }
            let nodes = projectileNodes[pose.slot]!, center = Int(frame.field("centerx")!)
            nodes.sprite.texture = assets.sprite(object, picture: Int(frame.field("pic")!))
            nodes.sprite.size = nodes.sprite.texture?.size() ?? .zero
            nodes.sprite.xScale = pose.facing == 0 ? 1 : -1
            nodes.sprite.zPosition = 51 + CGFloat(pose.z - 450) * 0.1 + CGFloat(pose.slot) * 0.001
            nodes.sprite.position = CGPoint(x: pose.x - world.cameraX + (pose.facing == 0 ? -center : center),
                                            y: 550 - (pose.z + pose.y - Int(frame.field("centery")!)))
            // 0x41a690: snake ID 224 has no shadow; airborne shots at y<=-70 also omit it.
            nodes.shadow.isHidden = pose.id == 224 || pose.y <= -70
            nodes.shadow.position = CGPoint(x: pose.x - world.cameraX - 18, y: 550 - (pose.z - 4))
        }
    }
    private static func makeEngine(characters: [ObjectDefinition], voices: ObjectDefinition, projectiles: [Int: ObjectDefinition], random: OriginalRandom, initial: [FighterState]? = nil) throws -> OriginalMelee {
        try OriginalMelee(headers: characters.map(\.header),
                          definitions: characters.map { OriginalFighter.sections(in: $0.originalText!, name: $0.name) },
                          voiceDefinitions: OriginalFighter.sections(in: voices.originalText!, name: voices.name, numbers: [200,201,207,208,334]),
                          random: random, initial: initial, projectileDefinitions: projectiles.keys.sorted().map { id in
                              let object = projectiles[id]!
                              return ProjectileDefinition(id: id, definitions: OriginalFighter.sections(in: object.originalText!, name: object.name, numbers: ProjectileDefinition.frameNumbers(id: id)))
                          })
    }
    func setActive(_ value: Bool) { active = value; input = []; opponentInput = []; pauseChanged() }
    func togglePause() { manuallyPaused.toggle(); input = []; opponentInput = []; pauseChanged() }
    private func pauseChanged() {
        clock.reset(); assets.stopSounds(); pauseShade.isHidden = previewing || isRunning
        onPauseChange?(!isRunning)
    }
    func restart() {
        do {
            let selected = engine.localPlayer
            engine = try Self.makeEngine(characters: characters, voices: voices, projectiles: projectileAssets, random: assets.game.practiceRandom!)
            engine.selectPlayer(selected)
            unavailable = false; previewing = false; pauseText.text = "Пауза"; pauseText.fontSize = 27
            for index in layers.indices { layers[index].0 = OriginalBackgroundLayer(fields: layers[index].0.fields) }
            input = []; opponentInput = []; clock.reset(); manuallyPaused = false
            pauseChanged(); renderState()
        } catch { assertionFailure("Previously validated melee data: \(error)") }
    }
    func switchPlayer() {
        input = []; opponentInput = []; engine.selectPlayer(1 - engine.localPlayer); renderState()
    }
    func toggleMute() { assets.muted.toggle(); if assets.muted { assets.stopSounds() } }
    // Deterministic renderer check, invoked only alongside --screenshot. These
    // are input/initial-condition cases from the x86 corpus, not scripted poses.
    func preview(_ kind: String) throws {
        guard ["snake", "needles"].contains(kind) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Unknown projectile preview: \(kind)")
        }
        var naruto = FighterState(), sasuke = FighterState()
        naruto.x = kind == "snake" ? 360 : 400; naruto.ix = Int(naruto.x)
        sasuke.x = kind == "snake" ? 450 : 580; sasuke.ix = Int(sasuke.x)
        sasuke.facing = 1; sasuke.renderFacing = 1
        if kind == "snake" { sasuke.frame = 70; sasuke.renderFrame = 70 }
        engine = try Self.makeEngine(characters: characters, voices: voices, projectiles: projectileAssets,
                                     random: assets.game.practiceRandom!, initial: [naruto, sasuke])
        for tick in 0..<(kind == "snake" ? 10 : 26) {
            let key: FighterInput = kind == "snake" || tick > 2 ? [] : [.defend, .left, .attack][tick]
            try engine.tick([[], key])
            for index in layers.indices { layers[index].0.tick() }
        }
        previewing = true; renderState()
    }
    // Explicit developer capture only, useful for checking actual AppKit input.
    func writeState(to path: String) {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(engine.state) { try? data.write(to: URL(fileURLWithPath: path)) }
    }
}

final class MeleeView: SKView {
    var meleeScene: MeleeScene { scene as! MeleeScene }
    private var held: Set<UInt16> = []
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) {
        guard !event.modifierFlags.contains(.command) else { super.keyDown(with: event); return }
        guard !event.isARepeat else { return }
        switch event.keyCode {
        case 48: clearInput(); meleeScene.switchPlayer()
        case 53: clearInput(); meleeScene.togglePause()
        case 15: clearInput(); meleeScene.restart()
        case 46: meleeScene.toggleMute()
        default: held.insert(event.keyCode); sample()
        }
    }
    override func keyUp(with event: NSEvent) {
        held.remove(event.keyCode); sample()
    }
    func clearInput() { held.removeAll(); meleeScene.input = []; meleeScene.opponentInput = [] }
    private func sample() {
        guard meleeScene.isRunning else { return }
        var input: FighterInput = [], opponentInput: FighterInput = []
        if !held.isDisjoint(with: [126, 13]) { input.insert(.up) }
        if !held.isDisjoint(with: [125, 1]) { input.insert(.down) }
        if !held.isDisjoint(with: [123, 0]) { input.insert(.left) }
        if !held.isDisjoint(with: [124, 2]) { input.insert(.right) }
        if held.contains(49) { input.insert(.jump) }
        if held.contains(38) { input.insert(.attack) }
        if held.contains(40) { input.insert(.defend) }
        if held.contains(34) { opponentInput.insert(.attack) }
        if held.contains(31) { opponentInput.insert(.defend) }
        meleeScene.input = input; meleeScene.opponentInput = opponentInput
    }
}
