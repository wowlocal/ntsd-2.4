import AppKit
import SpriteKit
import NTSDCore

let arguments = CommandLine.arguments
func argument(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}
let resources = Bundle.main.resourceURL ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let dataURL = argument("--data").map { URL(fileURLWithPath: $0) } ?? resources.appendingPathComponent("game.json")
let assetsURL = argument("--assets").map { URL(fileURLWithPath: $0) } ?? resources.appendingPathComponent("Assets")

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let game: GameData
    let objects: [ObjectDefinition]
    var window: NSWindow!
    var scene: OriginalScene!
    var skView: SKView!
    let objectPicker = NSPopUpButton(), framePicker = NSPopUpButton()
    let metadata = NSTextView()
    let sourceLabel = NSTextField(wrappingLabelWithString: "")
    var choices: [FrameOccurrence] = []
    var movementView: MovementView?
    var meleeView: MeleeView?

    init(game: GameData) {
        self.game = game
        objects = game.objects.sorted { ($0.type, $0.id) < ($1.type, $1.id) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let assets = Assets(game: game, root: assetsURL)
        if !arguments.contains("--inspect") {
            do {
                if arguments.contains("--movement") { try launchMovement(assets: assets) }
                else { try launchMelee(assets: assets) }
            }
            catch {
                let alert = NSAlert(error: error); alert.runModal(); NSApp.terminate(nil)
            }
            return
        }
        scene = OriginalScene(assets: assets)
        skView = SKView(frame: .zero); skView.presentScene(scene)
        // Static rendering: redraw only when source selection changes.
        skView.isPaused = true
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "NTSD Native Lab — оригинальные данные Windows"
        window.minSize = NSSize(width: 1000, height: 670)
        window.isReleasedWhenClosed = false
        let content = NSView(); window.contentView = content
        let title = NSTextField(labelWithString: "NTSD 2.4 · лаборатория нативного переноса")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Просмотр оригинальных кадров. Игровой движок ещё не перенесён.")
        subtitle.textColor = .secondaryLabelColor
        let header = NSStackView(views: [title, subtitle]); header.orientation = .vertical; header.alignment = .leading; header.spacing = 6
        for v in [header, skView!, sourceLabel] { v.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(v) }
        objectPicker.addItems(withTitles: objects.map { "\($0.id) · \($0.name)" })
        objectPicker.target = self; objectPicker.action = #selector(selectObject)
        framePicker.target = self; framePicker.action = #selector(selectFrame)
        let previous = NSButton(title: "←", target: self, action: #selector(previousFrame))
        let next = NSButton(title: "→", target: self, action: #selector(nextFrame))
        let sound = NSButton(title: "Звук кадра", target: self, action: #selector(playSound))
        let buttons = NSStackView(views: [previous, next, sound]); buttons.distribution = .fillEqually
        let boxes = NSButton(checkboxWithTitle: "bdy / itr из DAT", target: self, action: #selector(toggleBoxes)); boxes.state = .on
        let mirror = NSButton(checkboxWithTitle: "Отразить спрайт", target: self, action: #selector(toggleMirror))
        let column = NSStackView(views: [NSTextField(labelWithString: "Объект"), objectPicker,
                                      NSTextField(labelWithString: "Определение кадра"), framePicker, buttons, boxes, mirror])
        column.orientation = .vertical; column.alignment = .leading; column.spacing = 10
        column.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(column)
        metadata.isEditable = false; metadata.isRichText = false
        metadata.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        metadata.textContainerInset = NSSize(width: 10, height: 10)
        metadata.autoresizingMask = [.width]; metadata.isVerticallyResizable = true
        metadata.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView(); scroll.documentView = metadata; scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder; scroll.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(scroll)
        sourceLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular); sourceLabel.textColor = .secondaryLabelColor
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 20), header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            column.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 20), column.leadingAnchor.constraint(equalTo: header.leadingAnchor), column.widthAnchor.constraint(equalToConstant: 280),
            objectPicker.widthAnchor.constraint(equalTo: column.widthAnchor), framePicker.widthAnchor.constraint(equalTo: column.widthAnchor),
            scroll.topAnchor.constraint(equalTo: column.bottomAnchor, constant: 14), scroll.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            scroll.widthAnchor.constraint(equalTo: column.widthAnchor), scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            skView.topAnchor.constraint(equalTo: column.topAnchor), skView.leadingAnchor.constraint(equalTo: column.trailingAnchor, constant: 20),
            skView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20), skView.bottomAnchor.constraint(equalTo: sourceLabel.topAnchor, constant: -14),
            sourceLabel.leadingAnchor.constraint(equalTo: skView.leadingAnchor), sourceLabel.trailingAnchor.constraint(equalTo: skView.trailingAnchor),
            sourceLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20), sourceLabel.heightAnchor.constraint(equalToConstant: 36)
        ])
        objectPicker.selectItem(at: objects.firstIndex { $0.id == 2 } ?? 0)
        selectObject()
        let bar = NSMenu(); let item = NSMenuItem(); bar.addItem(item)
        let menu = NSMenu(); item.submenu = menu
        menu.addItem(withTitle: "Завершить NTSD Native Lab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = bar
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if let screenshot = argument("--screenshot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.capture(to: screenshot) }
        }
    }

    private func launchMovement(assets: Assets) throws {
        let scene = try MovementScene(assets: assets)
        let view = MovementView(frame: NSRect(x: 0, y: 50, width: 794, height: 550))
        movementView = view; view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true; view.presentScene(scene)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 794, height: 600),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "NTSD 2.4 — Naruto · District"
        window.minSize = NSSize(width: 600, height: 460); window.isReleasedWhenClosed = false
        window.delegate = self
        let content = NSView(); window.contentView = content
        view.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(view)
        let controls = NSTextField(labelWithString: "Стрелки / WASD — движение · Двойное нажатие ← / → — бег · Пробел — прыжок")
        controls.font = .systemFont(ofSize: 11)
        let status = NSTextField(labelWithString: "Esc — пауза · R — заново · M — звук     |     Первая версия: движение Наруто")
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor
        for label in [controls, status] { label.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(label) }
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: content.topAnchor), view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: content.trailingAnchor), view.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -50),
            controls.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12), controls.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -4),
            status.leadingAnchor.constraint(equalTo: controls.leadingAnchor), status.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -9)
        ])
        let bar = NSMenu(); let item = NSMenuItem(); bar.addItem(item)
        let menu = NSMenu(); item.submenu = menu
        menu.addItem(withTitle: "Завершить NTSD", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = bar
        window.center(); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(view)
        NSApp.activate(ignoringOtherApps: true)
        if let screenshot = argument("--screenshot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.capture(to: screenshot) }
        }
        if let statePath = argument("--capture-state") {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in scene.writeState(to: statePath) }
        }
    }
    private func launchMelee(assets: Assets) throws {
        let scene = try MeleeScene(assets: assets)
        if argument("--screenshot") != nil, let preview = argument("--practice-preview") { try scene.preview(preview) }
        let view = MeleeView(frame: NSRect(x: 0, y: 50, width: 794, height: 550))
        meleeView = view; view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true; view.presentScene(scene)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 794, height: 600),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "NTSD 2.4 — Naruto / Sasuke · District"
        window.minSize = NSSize(width: 600, height: 460); window.isReleasedWhenClosed = false
        window.delegate = self
        let content = NSView(); window.contentView = content
        view.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(view)
        let controls = NSTextField(labelWithString: "Tab — сменить бойца · Стрелки / WASD · Пробел — прыжок · J — удар · K — блок · I / O — удар / блок второго")
        controls.font = .systemFont(ofSize: 11)
        let status = NSTextField(labelWithString: "Саске: K, затем ←/→, затем J — иглы Чидори (100 чакры)    |    Esc — пауза · R — заново · M — звук")
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor
        for label in [controls, status] { label.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(label) }
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: content.topAnchor), view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: content.trailingAnchor), view.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -50),
            controls.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12), controls.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -4),
            status.leadingAnchor.constraint(equalTo: controls.leadingAnchor), status.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -9)
        ])
        let bar = NSMenu(); let item = NSMenuItem(); bar.addItem(item)
        let menu = NSMenu(); item.submenu = menu
        menu.addItem(withTitle: "Завершить NTSD", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = bar
        window.center(); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(view)
        NSApp.activate(ignoringOtherApps: true)
        if let screenshot = argument("--screenshot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.capture(to: screenshot) }
        }
        if let statePath = argument("--capture-state") {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in scene.writeState(to: statePath) }
        }
    }
    func windowDidResignKey(_ notification: Notification) {
        movementView?.clearInput(); movementView?.movementScene.setActive(false)
        meleeView?.clearInput(); meleeView?.meleeScene.setActive(false)
    }
    func windowDidBecomeKey(_ notification: Notification) {
        movementView?.clearInput(); movementView?.movementScene.setActive(true)
        meleeView?.clearInput(); meleeView?.meleeScene.setActive(true)
        if let view = meleeView { window.makeFirstResponder(view) }
        if let view = movementView { window.makeFirstResponder(view) }
    }

    @objc func selectObject() {
        let object = objects[objectPicker.indexOfSelectedItem]
        choices = object.frameOccurrences ?? []
        framePicker.removeAllItems()
        var counts: [Int: Int] = [:]
        for occurrence in choices {
            counts[occurrence.number, default: 0] += 1
            let count = counts[occurrence.number]!
            framePicker.addItem(withTitle: "\(occurrence.number) · \(occurrence.frame.name)\(count > 1 ? " [повтор \(count)]" : "")")
        }
        framePicker.selectItem(at: 0); selectFrame()
    }
    @objc func selectFrame() {
        guard choices.indices.contains(framePicker.indexOfSelectedItem) else { return }
        let object = objects[objectPicker.indexOfSelectedItem], choice = choices[framePicker.indexOfSelectedItem]
        scene.display(object, occurrence: choice)
        skView.isPaused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.skView.isPaused = true }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        metadata.string = (try? encoder.encode(choice)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        sourceLabel.stringValue = "\(object.source)\nВсе повторы сохранены; удалённые зоны попаданий видны в исходных значениях слева."
    }
    @objc func previousFrame() { framePicker.selectItem(at: max(0, framePicker.indexOfSelectedItem - 1)); selectFrame() }
    @objc func nextFrame() { framePicker.selectItem(at: min(choices.count - 1, framePicker.indexOfSelectedItem + 1)); selectFrame() }
    @objc func toggleBoxes(_ sender: NSButton) { scene.showBoxes = sender.state == .on; selectFrame() }
    @objc func toggleMirror(_ sender: NSButton) { scene.mirrored = sender.state == .on; selectFrame() }
    @objc func playSound() {
        guard choices.indices.contains(framePicker.indexOfSelectedItem),
              let path = choices[framePicker.indexOfSelectedItem].frame.fields["sound"] else { return }
        scene.assets.sound(path)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    private func capture(to path: String) {
        guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            fputs("Cannot allocate screenshot bitmap\n", stderr); exit(1)
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        // AppKit's cacheDisplay omits the Metal-backed SKView. Render its scene
        // through SpriteKit, then place it in the window-content bitmap.
        let spriteView: SKView? = meleeView ?? movementView ?? skView
        if let spriteView, let scene = spriteView.scene {
            guard let texture = spriteView.texture(from: scene, crop: scene.frame),
                  let context = NSGraphicsContext(bitmapImageRep: rep) else {
                fputs("Cannot capture SpriteKit scene\n", stderr); exit(1)
            }
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            let region = spriteView.convert(spriteView.bounds, to: view)
            let factor = min(region.width / scene.size.width, region.height / scene.size.height)
            let size = NSSize(width: scene.size.width * factor, height: scene.size.height * factor)
            let rect = NSRect(x: region.midX - size.width / 2, y: region.midY - size.height / 2,
                              width: size.width, height: size.height)
            NSImage(cgImage: texture.cgImage(), size: scene.size).draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()
        }
        do {
            guard let data = rep.representation(using: .png, properties: [:]) else {
                fputs("Cannot encode screenshot\n", stderr); exit(1)
            }
            try data.write(to: URL(fileURLWithPath: path))
        } catch { fputs("Cannot save screenshot: \(error)\n", stderr); exit(1) }
        NSApp.terminate(nil)
    }
}

do {
    let game = try GameData.load(from: dataURL)
    if arguments.contains("--verify-data") {
        let count = game.objects.reduce(0) { $0 + ($1.frameOccurrences?.count ?? 0) }
        guard count > 0 else { throw NSError(domain: "NTSD", code: 1, userInfo: [NSLocalizedDescriptionKey: "No original frame occurrences"]) }
        print("Loaded \(game.objects.count) objects, \(count) source frame definitions and \(game.backgrounds.count) backgrounds in native Swift.")
    } else {
        let app = NSApplication.shared; app.setActivationPolicy(.regular)
        let delegate = AppDelegate(game: game); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
} catch {
    fputs("Cannot open original data: \(error)\nRun ./run-native.sh --build to prepare the native laboratory.\n", stderr)
    exit(1)
}
