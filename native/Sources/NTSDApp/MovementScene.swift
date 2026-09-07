import AppKit
import SpriteKit
import NTSDCore

final class MovementScene: SKScene {
    let assets: Assets
    let character: ObjectDefinition
    let arena: BackgroundDefinition
    private(set) var engine: OriginalMovement
    private var clock = OriginalClock()
    private var layers: [(OriginalBackgroundLayer, SKSpriteNode)] = []
    private let actor = SKSpriteNode(), shadow = SKSpriteNode()
    private let pauseShade = SKSpriteNode(color: NSColor.black.withAlphaComponent(0.55), size: CGSize(width: 794, height: 550))
    private let pauseText = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    var input: MovementInput = []
    private(set) var manuallyPaused = false
    private var active = true
    var isRunning: Bool { active && !manuallyPaused }
    var onPauseChange: ((Bool) -> Void)?

    init(assets: Assets) throws {
        self.assets = assets
        guard let character = assets.game.object(2), let text = character.originalText,
              let arena = assets.game.backgrounds.first(where: { $0.id == 0 }) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Original Naruto / District data is missing")
        }
        self.character = character; self.arena = arena
        engine = try OriginalMovement(header: character.header, definitions: OriginalMovement.sections(in: text))
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
        shadow.texture = assets.texture(arena.header["shadow"]!)
        shadow.size = shadow.texture?.size() ?? .zero; shadow.anchorPoint = CGPoint(x: 0, y: 1)
        shadow.zPosition = 50; addChild(shadow)
        actor.anchorPoint = CGPoint(x: 0, y: 1); actor.zPosition = 51; addChild(actor)
        // Preload this milestone's small set of pictures to avoid first-use disk
        // stalls during a jump or double tap.
        for record in engine.frames.values { _ = assets.sprite(character, picture: Int(record.field("pic")!)) }
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
            let state = engine.tick(input)
            for index in layers.indices { layers[index].0.tick() }
            for sound in state.sounds { assets.sound(sound == "builtin:7" ? "data/017.wav" : sound) }
        }
        renderState()
    }
    private func renderState() {
        let state = engine.state, frame = engine.frames[engine.state.renderFrame]!
        for (layer, node) in layers {
            node.position = CGPoint(x: layer.x(camera: state.cameraX), y: 550 - layer.fields.integer("y"))
            node.isHidden = !layer.visible
        }
        actor.texture = assets.sprite(character, picture: Int(frame.field("pic")!))
        actor.size = actor.texture?.size() ?? .zero
        actor.xScale = state.renderFacing == 0 ? 1 : -1
        let center = Int(frame.field("centerx")!)
        actor.position = CGPoint(x: state.ix - state.cameraX + (state.renderFacing == 0 ? -center : center),
                                 y: 550 - (state.iz + state.iy - Int(frame.field("centery")!)))
        shadow.position = CGPoint(x: state.ix - state.cameraX - 18, y: 550 - (state.iz - 4))
    }
    func setActive(_ value: Bool) { active = value; input = []; pauseChanged() }
    func togglePause() { manuallyPaused.toggle(); input = []; pauseChanged() }
    private func pauseChanged() {
        clock.reset(); assets.stopSounds(); pauseShade.isHidden = isRunning
        onPauseChange?(!isRunning)
    }
    func restart() {
        do {
            engine = try OriginalMovement(header: character.header, definitions: OriginalMovement.sections(in: character.originalText!))
            for index in layers.indices { layers[index].0 = OriginalBackgroundLayer(fields: layers[index].0.fields) }
            input = []; clock.reset(); manuallyPaused = false
            pauseChanged(); renderState()
        } catch { assertionFailure("Previously validated movement data: \(error)") }
    }
    func toggleMute() { assets.muted.toggle(); if assets.muted { assets.stopSounds() } }
    // Explicit developer capture only, useful for checking actual AppKit input.
    func writeState(to path: String) {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(engine.state) { try? data.write(to: URL(fileURLWithPath: path)) }
    }
}

final class MovementView: SKView {
    var movementScene: MovementScene { scene as! MovementScene }
    private var held: Set<UInt16> = []
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) {
        guard !event.modifierFlags.contains(.command) else { super.keyDown(with: event); return }
        guard !event.isARepeat else { return }
        switch event.keyCode {
        case 53: clearInput(); movementScene.togglePause()
        case 15: clearInput(); movementScene.restart()
        case 46: movementScene.toggleMute()
        default: held.insert(event.keyCode); sample()
        }
    }
    override func keyUp(with event: NSEvent) { held.remove(event.keyCode); sample() }
    func clearInput() { held.removeAll(); movementScene.input = [] }
    private func sample() {
        guard movementScene.isRunning else { return }
        var input: MovementInput = []
        if !held.isDisjoint(with: [126, 13]) { input.insert(.up) }
        if !held.isDisjoint(with: [125, 1]) { input.insert(.down) }
        if !held.isDisjoint(with: [123, 0]) { input.insert(.left) }
        if !held.isDisjoint(with: [124, 2]) { input.insert(.right) }
        if held.contains(49) { input.insert(.jump) }
        movementScene.input = input
    }
}
