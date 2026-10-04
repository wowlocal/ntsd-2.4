import AppKit
import GameController
import NTSDCore
import NTSDMacPlatform

/// `--original` on macOS: the portable `OriginalRuntimeSession` (options in its
/// documentation) on AppKit windows, AVFoundation output, GameController
/// joysticks and Darwin sockets.
final class OriginalRuntimeDelegate: NSObject, NSApplicationDelegate {
    let exitAfterStartup: Bool
    private var host: OriginalMacSessionHost?
    private var session: OriginalRuntimeSession?
    init(exitAfterStartup: Bool) { self.exitAfterStartup = exitAfterStartup }
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            let host = OriginalMacSessionHost(arguments:arguments)
            let session = OriginalRuntimeSession(arguments:arguments,host:host)
            host.session = session; self.host = host; self.session = session
            session.start()
        }
    }
    /// The game ends at its own WM_QUIT (after DestroyWindow hid the window);
    /// only a run stopped at a boundary ends with its window.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        MainActor.assumeIsolated { session?.stopped ?? false }
    }
}

/// The macOS session host.
@MainActor final class OriginalMacSessionHost: OriginalRuntimeSessionHost {
    let arguments: [String]
    weak var session: OriginalRuntimeSession?
    private var pressedModifiers: Set<UInt16> = []
    /// Windows does not throttle a background game's Sleep loop; App Nap would
    /// stretch every scheduled iteration once the window is not frontmost.
    private var activity: NSObjectProtocol?
    private var soundOutput: OriginalMacSoundOutput?
    init(arguments: [String]) { self.arguments = arguments }
    var startupHost: OriginalRuntimeStartupHost { .mac }
    func capsLock() -> Int32 { NSEvent.modifierFlags.contains(.capsLock) ? 1 : 0 }
    func makeSockets() -> any OriginalRuntimeSockets { OriginalMacWinsock() }
    var loadingDialogs: OriginalRuntimeLoadingDialogs { .mac }
    func standardOverlay() throws -> OriginalMacRuntimeOverlay { try .standard() }
    func beginTimingActivity() {
        // Timer precision without App Nap, but the Mac may still idle-sleep: the
        // original never calls SetThreadExecutionState.
        activity = ProcessInfo.processInfo.beginActivity(options:[.userInitiatedAllowingIdleSystemSleep,.latencyCritical],
                                                          reason:"Original game loop timing")
    }
    /// Joysticks connected at launch (APPLICATION_JOYSTICKS_PLAN.md): the first
    /// two extended game controllers. The original probes its joysticks only at
    /// startup, so this is fixed.
    private lazy var controllers: [GCController] = {
        // Already-connected controllers are enumerated asynchronously after launch;
        // give GameController up to 0.5 s to report one before 43bf10's single probe.
        func found() -> [GCController] { GCController.controllers().filter { $0.extendedGamepad != nil } }
        let deadline = Date().addingTimeInterval(0.5)
        while found().isEmpty && Date() < deadline { RunLoop.current.run(mode:.default,before:Date().addingTimeInterval(0.05)) }
        return Array(found().prefix(2))
    }()
    func connectedJoysticks() -> Int { controllers.count }
    func startJoystickSampling(_ session: OriginalRuntimeSession) {
        // Common modes: sampling continues while a window is dragged or a menu tracks.
        let timer = Timer(timeInterval:0.025,repeats:true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleControllers() }
        }
        RunLoop.main.add(timer,forMode:.common)
    }
    /// joySetCapture's 25 ms period: sample each controller and let the runtime
    /// post the MM_JOY messages its threshold and button changes call for.
    private func sampleControllers() {
        guard let session,let messages = session.messages,!session.stopped else { return }
        for (id,controller) in controllers.enumerated() {
            guard let pad = controller.extendedGamepad else { continue }
            var dx = pad.leftThumbstick.xAxis.value,dy = pad.leftThumbstick.yAxis.value
            if pad.dpad.xAxis.value != 0 { dx = pad.dpad.xAxis.value }
            if pad.dpad.yAxis.value != 0 { dy = pad.dpad.yAxis.value }
            func axis(_ v: Float) -> UInt32 { UInt32(((max(-1,min(1,v))+1)/2*65535).rounded()) }
            let buttons = [pad.buttonA,pad.buttonB,pad.buttonX,pad.buttonY].enumerated().reduce(UInt32(0)) { $0 | ($1.element.isPressed ? 1 << UInt32($1.offset) : 0) }
            messages.joystick(UInt32(id),x:axis(dx),y:axis(-dy),buttons:buttons)
        }
    }
    func makeMusicOutput() throws -> OriginalMacMusicOutput { try .bundled() }
    var musicDirectory: String { OriginalMacMusicOutput.directory()?.path ?? "" }
    func startSoundOutput(_ effects: OriginalMacSoundEffects,muted: Bool) throws -> String {
        let output = try OriginalMacSoundOutput(effects:effects)
        output.muted = muted; output.focused = NSApp.isActive; soundOutput = output
        // DirectSound focus (see OriginalMacSoundOutput): the app's
        // single window is foreground exactly while the app is active.
        for (name,active) in [(NSApplication.didBecomeActiveNotification,true),(NSApplication.didResignActiveNotification,false)] {
            NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated { self?.soundOutput?.focused = active }
            }
        }
        return output.muted ? "muted" : "default output"
    }
    func backingScale(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) -> Double {
        Double((try? windows.observation(window).backingScale) ?? 0)
    }
    /// GetMessagePos: desktop coordinates with the main screen's top-left origin.
    func cursorPoint() -> (Int32,Int32) {
        let p = NSEvent.mouseLocation,height = NSScreen.screens.first?.frame.maxY ?? 0
        return (Int32(p.x.rounded(.down)),Int32((height-p.y).rounded(.down)))
    }
    /// The original window's input and close handling: the close button is the
    /// game's WM_SYSCOMMAND(SC_CLOSE); after a boundary stop it closes the app.
    func attach(_ window: UInt32,in windows: OriginalRuntimeWindowBackend,session: OriginalRuntimeSession) throws {
        try windows.setInput(window) { [weak self] event in self?.input(event,windows) ?? false }
        try windows.setCloseRequest(window) { [weak session] in session?.closeRequested() ?? true }
    }
    private func input(_ event: NSEvent,_ windows: OriginalRuntimeWindowBackend) -> Bool {
        guard let session,let messages = session.messages,!session.stopped else { return false }
        // Scripted runs take keyboard and mouse input from their script only:
        // a real pointer crossing the window would otherwise move the game's
        // cursor and change the run (seen as rare e2e capture mismatches).
        if session.scripted { return true }
        switch event.type {
        case .keyDown,.keyUp:
            guard let key = OriginalMacRuntimeKey.table[event.keyCode] else { return true }
            // With Option (Alt) held, WM_SYSCHAR carries the unmodified character.
            messages.key(key,down:event.type == .keyDown,repeated:event.isARepeat,
                         characters:event.modifierFlags.contains(.option) ? event.charactersIgnoringModifiers : event.characters)
        case .flagsChanged:
            guard let key = OriginalMacRuntimeKey.table[event.keyCode] else { return true }
            // Caps Lock reports one flagsChanged per toggle and none on release: each
            // is a whole physical press (down, then up), as Windows sees the key.
            if key.vk == 0x14 { messages.key(key,down:true); messages.key(key,down:false); return true }
            let down = !pressedModifiers.contains(event.keyCode)
            if down { pressedModifiers.insert(event.keyCode) } else { pressedModifiers.remove(event.keyCode) }
            messages.key(key,down:down)
        case .mouseMoved,.leftMouseDragged,.rightMouseDragged,.leftMouseDown,.leftMouseUp,.rightMouseDown,.rightMouseUp:
            guard let (x,y) = try? windows.clientPoint(session.gameWindow,event) else { return true }
            let pressed = NSEvent.pressedMouseButtons
            let buttons = UInt32(pressed & 1 != 0 ? 1 : 0) | UInt32(pressed & 2 != 0 ? 2 : 0)
            let message: UInt32
            switch event.type {
            case .leftMouseDown: message = 0x201
            case .leftMouseUp: message = 0x202
            case .rightMouseDown: message = 0x204
            case .rightMouseUp: message = 0x205
            default: message = 0x200
            }
            messages.mouse(message,x:x,y:y,buttons:buttons)
        default: return false
        }
        return true
    }
    func snapshotPNG(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws -> Data { try windows.snapshotPNG(window) }
    func viewPNG(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws -> Data { try windows.viewPNG(window) }
    func toggleFullScreen(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws { try windows.toggleMacFullScreen(window) }
    func hide(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws { try windows.hide(window) }
    func askMessageBox(text: String,caption: String,buttons: [String]) -> Int {
        let alert = NSAlert(); alert.messageText = caption; alert.informativeText = text
        for title in buttons { alert.addButton(withTitle:title) }
        return alert.runModal().rawValue-NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    }
    func open(_ url: URL) { NSWorkspace.shared.open(url) }
    func showStop(title: String,text: String) {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = text; alert.runModal()
    }
    func didStart() {
        Self.installMenu()
        if !arguments.contains("--no-activate") { NSApp.activate(ignoringOtherApps:true) }
    }
    func terminate() { NSApp.terminate(nil) }
    func exit(_ code: Int32) -> Never { Darwin.exit(code) }
    /// The app menu and a View menu with the standard macOS full-screen toggle
    /// (⌃⌘F; APPLICATION_MAC_FULL_SCREEN_PLAN.md). The game takes no part in it.
    private static func installMenu() {
        let bar = NSMenu(),app = NSMenuItem(),view = NSMenuItem(title:"View",action:nil,keyEquivalent:"")
        app.submenu = NSMenu(); bar.addItem(app)
        let viewMenu = NSMenu(title:"View"); view.submenu = viewMenu; bar.addItem(view)
        let toggle = NSMenuItem(title:"Enter Full Screen",action:#selector(NSWindow.toggleFullScreen(_:)),keyEquivalent:"f")
        toggle.keyEquivalentModifierMask = [.control,.command]; viewMenu.addItem(toggle)
        NSApp.mainMenu = bar
        for (name,entered) in [(NSWindow.didEnterFullScreenNotification,true),(NSWindow.didExitFullScreenNotification,false)] {
            NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { note in
                let size = (note.object as? NSWindow)?.contentView?.bounds.size ?? .zero
                OriginalRuntimeSession.emit(["event":"macFullScreen","entered":entered,"client":[Int(size.width),Int(size.height)]])
            }
        }
    }
}
