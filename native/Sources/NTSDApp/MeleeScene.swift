import AppKit
import SpriteKit
import NTSDCore

final class MeleeScene: SKScene {
    let assets: Assets
    let characters: [ObjectDefinition]
    let voices: ObjectDefinition
    let arena: BackgroundDefinition
    private(set) var engine: OriginalMelee
    private var clock = OriginalClock()
    private var layers: [(OriginalBackgroundLayer, SKSpriteNode)] = []
    private let actors = [SKSpriteNode(), SKSpriteNode()], shadows = [SKSpriteNode(), SKSpriteNode()]
    private let hpBars = [SKSpriteNode(), SKSpriteNode()], redBars = [SKSpriteNode(), SKSpriteNode()]
    private let hpLabels = [SKLabelNode(fontNamed: "Menlo"), SKLabelNode(fontNamed: "Menlo")]
    private var unavailable = false
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
              let voices = assets.game.object(203), let random = assets.game.practiceRandom,
              naruto.originalText != nil, sasuke.originalText != nil, voices.originalText != nil,
              let arena = assets.game.backgrounds.first(where: { $0.id == 0 }) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Original Naruto / Sasuke / District data is missing")
        }
        self.characters = [naruto, sasuke]; self.voices = voices; self.arena = arena
        engine = try Self.makeEngine(characters: characters, voices: voices, random: random)
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
            let panel = SKSpriteNode(color: NSColor(calibratedWhite: 0.08, alpha: 0.84), size: CGSize(width: 204, height: 47))
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
        }
        pauseShade.position = CGPoint(x: 397, y: 275); pauseShade.zPosition = 100
        pauseShade.isHidden = true; addChild(pauseShade)
        pauseText.text = "Пауза"; pauseText.fontSize = 27; pauseText.verticalAlignmentMode = .center
        pauseShade.addChild(pauseText)
        renderState()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func update(_ currentTime: TimeInterval) {
        guard isRunning else { return }
        let now = UInt32(truncatingIfNeeded: UInt64(ProcessInfo.processInfo.systemUptime * 1000))
        let ticks = clock.ticks(at: now)
        guard ticks > 0 else { return }
        for _ in 0..<ticks {
            do {
                let state = try engine.tick([input, opponentInput])
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
            hpLabels[i].text = "\(characters[i].name)  \(max(0,state.hp))/500"
            hpBars[i].size = CGSize(width: 150 * Double(max(0,min(500,state.hp))) / 500, height: 9)
            redBars[i].size = CGSize(width: 150 * Double(max(0,min(500,state.redHP))) / 500, height: 9)
        }
    }
    private static func makeEngine(characters: [ObjectDefinition], voices: ObjectDefinition, random: OriginalRandom) throws -> OriginalMelee {
        try OriginalMelee(headers: characters.map(\.header),
                          definitions: characters.map { OriginalFighter.sections(in: $0.originalText!, name: $0.name) },
                          voiceDefinitions: OriginalFighter.sections(in: voices.originalText!, name: voices.name, numbers: [200,201,207,208]),
                          random: random)
    }
    func setActive(_ value: Bool) { active = value; input = []; opponentInput = []; pauseChanged() }
    func togglePause() { manuallyPaused.toggle(); input = []; opponentInput = []; pauseChanged() }
    private func pauseChanged() {
        clock.reset(); assets.stopSounds(); pauseShade.isHidden = isRunning
        onPauseChange?(!isRunning)
    }
    func restart() {
        do {
            engine = try Self.makeEngine(characters: characters, voices: voices, random: assets.game.practiceRandom!)
            unavailable = false; pauseText.text = "Пауза"; pauseText.fontSize = 27
            for index in layers.indices { layers[index].0 = OriginalBackgroundLayer(fields: layers[index].0.fields) }
            input = []; opponentInput = []; clock.reset(); manuallyPaused = false
            pauseChanged(); renderState()
        } catch { assertionFailure("Previously validated melee data: \(error)") }
    }
    func toggleMute() { assets.muted.toggle(); if assets.muted { assets.stopSounds() } }
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
