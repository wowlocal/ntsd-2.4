import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
import NTSDCore

/// What a platform supplies to run the original game as an app: its startup
/// host, user data, timing, joysticks, music and sound output, window captures
/// and input, interactive dialogs and process control.
@MainActor public protocol OriginalRuntimeSessionHost: AnyObject {
    var startupHost: OriginalRuntimeStartupHost { get }
    /// GetKeyState(VK_CAPITAL): the Caps Lock toggle (1 on, 0 off).
    func capsLock() -> Int32
    /// The host's sockets for ONLINE GAME.
    func makeSockets() -> any OriginalRuntimeSockets
    /// Interactive playback and document dialogs.
    var loadingDialogs: OriginalRuntimeLoadingDialogs { get }
    /// Writable user data when no `--overlay` is given.
    func standardOverlay() throws -> OriginalMacRuntimeOverlay
    /// Keeps the game loop's timer precision for the session's life.
    func beginTimingActivity()
    /// Joysticks connected at launch (0...2); the original probes only once.
    func connectedJoysticks() -> Int
    /// Samples connected joysticks every 25 ms while the session runs.
    func startJoystickSampling(_ session: OriginalRuntimeSession)
    /// The packaged original tracks and their player.
    func makeMusicOutput() throws -> OriginalMacMusicOutput
    var musicDirectory: String { get }
    /// Starts output of the sound-effect mixer; returns its report text.
    func startSoundOutput(_ effects: OriginalMacSoundEffects,muted: Bool) throws -> String
    func backingScale(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) -> Double
    /// GetMessagePos: desktop coordinates with the main screen's top-left origin.
    func cursorPoint() -> (Int32,Int32)
    /// Routes the window's input and close button to the session.
    func attach(_ window: UInt32,in windows: OriginalRuntimeWindowBackend,session: OriginalRuntimeSession) throws
    func snapshotPNG(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws -> Data
    func viewPNG(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws -> Data
    func toggleFullScreen(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws
    func hide(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws
    /// An interactive MessageBoxA with these button titles; the chosen index.
    func askMessageBox(text: String,caption: String,buttons: [String]) -> Int
    /// ShellExecute "open"/"explore" of a URL or folder.
    func open(_ url: URL)
    /// Shows why an interactive run stopped.
    func showStop(title: String,text: String)
    /// The window exists and input is attached (menus, activation).
    func didStart()
    /// A normal end (quit menu, script exit, captures): the app terminates.
    func terminate()
    /// WinMain's return or a scripted boundary: the process exits now.
    func exit(_ code: Int32) -> Never
}

/// `--original`: run the recovered WinMain on the host's services and runtime
/// providers, then the front menu with live keyboard/mouse and clock input until
/// the first loading request or an unsupported boundary, which is reported.
/// Options: `--exit-after-startup`, `--capture-after N PATH` (window PNG after N
/// committed menu iterations), `--exit-after-capture`, `--click-at N X Y`
/// (scripted left click at client point X,Y after N committed iterations).
/// `--script "N action args; ..."` runs scripted input at committed iteration N:
/// `click X Y` (button held 10 iterations), `key VK` (held 10 iterations),
/// `capture PATH`, `frame PATH` (the last presented framebuffer as written by
/// `OriginalFramebufferPNG`, identical on every host), `musicend` (the current track ends now), `answer yes|no|ok`
/// (the next MessageBoxA's button; scripted runs never show the box and stop
/// at a boundary without one), `close` (the window's close button), `exit`.
/// Counting uses committed outer iterations.
/// `--virtual-clock BASE STEP` makes runs reproducible: timeGetTime answers
/// BASE + STEP × iterations started, startup FILETIME and GetLocalTime use a
/// fixed date (2026-01-01 00:00 UTC) and GetMessagePos answers (0,0).
/// `--stage-checkpoints` builds the per-stage snapshots the app never uses.
/// `--mute-music` plays the original tracks at zero output gain.
/// `--mute-sounds` keeps the WAV sound-effect voices at zero output gain.
/// `--overlay DIR` keeps user files (settings, replays) in DIR instead of
/// the host's user data, for automated runs.
/// `--network-loopback` supplies 127.0.0.1 as the local hostname's address for
/// controlled two-process checks. All socket IO remains real localhost TCP.
/// `--network-ready-state PATH` records owned state once at the first connected
/// loading boundary; `--exit-after-network-ready` stops there before loading.
/// `--loaded-script "N action args; ..."` uses completed loaded cycles as its
/// clock, independently of the front-menu handshake's scripted iterations.
/// `--network-trace PATH` streams socket replies and committed loaded-state
/// digests; `--summary-capture PATH --exit-after-summary` ends on the result.
/// `--no-activate` leaves the frontmost app active, for runs beside the
/// CrossOver original, which takes keys only while its window is in front.
/// `--network-state-cycles N,N` adds full owned Actor/global bytes and masks
/// to those trace checkpoints when diagnosing a state difference.
/// START runs the whole loading once (blocking, progress frames not shown);
/// later screens return through cached loaded cycles.
/// Session-level input errors (not game behaviour).
public enum OriginalRuntimeSessionBoundary: Error, Equatable {
    /// `--resources DIR` names no readable bundle.
    case resources(String)
}

@MainActor public final class OriginalRuntimeSession {
    public let arguments: [String]
    public let exitAfterStartup: Bool
    private unowned let host: any OriginalRuntimeSessionHost
    private var started: OriginalMacRuntimeStartup.Started?
    private var menu: OriginalMacRuntimeMenu?
    private var loading: OriginalMacRuntimeLoading?
    private var captureAfter: (count: Int,path: String)?
    private var clickAt: (count: Int,x: Int32,y: Int32)?
    private var cycles = 0, gameplayBodies = 0
    private var networkReadyRecorded = false
    private var script: [Int:[[String]]] = [:]
    private var loadedScript: [Int:[[String]]] = [:]
    private var networkTrace: FileHandle?
    private var networkStateCycles: Set<Int> = []
    private var committed = 0, steps = 0, gameplayClock: (steps: Int,committed: Int)?,
        busy = 0.0, waited = 0
    public private(set) var stopped = false
    private var music: OriginalMacMusicOutput?
    /// DirectSound buffer voices (APPLICATION_SOUND_EFFECTS_PLAN.md) and their
    /// output; a missing output device leaves the voices running silently.
    private var sounds: OriginalMacSoundEffects?
    private var soundOutput: String?, soundOutputError: String?
    /// The menu runtime's window messages, for host input.
    public var messages: OriginalMacRuntimeMessages? { menu?.messages }
    /// Scripted runs take keyboard and mouse input from their script only.
    public var scripted: Bool { arguments.contains("--script") }
    /// `--resources DIR`: the game's resource bundle at DIR (a host whose data is
    /// not beside its executable, e.g. extracted by an Android app); otherwise
    /// the loaders' usual places, starting from the main bundle.
    func resourceBundle() throws -> Bundle {
        guard let i = arguments.firstIndex(of:"--resources"),i+1 < arguments.count else { return .main }
        guard let bundle = Bundle(path:arguments[i+1]) else { throw OriginalRuntimeSessionBoundary.resources(arguments[i+1]) }
        return bundle
    }
    /// The current original window (replaced by an Alt+Enter recreation).
    public private(set) var gameWindow: UInt32 = 0
    public init(arguments: [String],host: any OriginalRuntimeSessionHost) {
        self.arguments = arguments; self.host = host
        exitAfterStartup = arguments.contains("--exit-after-startup")
        if let i = arguments.firstIndex(of:"--capture-after"),i+2 < arguments.count,let n = Int(arguments[i+1]) {
            captureAfter = (n,arguments[i+2])
        }
        if let i = arguments.firstIndex(of:"--script"),i+1 < arguments.count {
            for entry in arguments[i+1].split(separator:";") {
                let words = entry.split(separator:" ").map(String.init)
                if let n = words.first.flatMap({ Int($0) }),words.count > 1 { script[n,default:[]].append(Array(words.dropFirst())) }
            }
        }
        if let i = arguments.firstIndex(of:"--loaded-script"),i+1 < arguments.count {
            for entry in arguments[i+1].split(separator:";") {
                let words = entry.split(separator:" ").map(String.init)
                if let n = words.first.flatMap({ Int($0) }),words.count > 1 { loadedScript[n,default:[]].append(Array(words.dropFirst())) }
            }
        }
        if let i = arguments.firstIndex(of:"--network-state-cycles"),i+1 < arguments.count {
            networkStateCycles = Set(arguments[i+1].split(separator:",").compactMap { Int($0) })
        }
        if let i = arguments.firstIndex(of:"--click-at"),i+3 < arguments.count,let n = Int(arguments[i+1]),
           let x = Int32(arguments[i+2]),let y = Int32(arguments[i+3]) { clickAt = (n,x,y) }
    }
    /// The key a script VK names: of several Mac keys with one VK (left/right
    /// Shift, Control, Option; Return/Enter) the lowest key code, so runs repeat.
    public static func scriptKey(_ vk: UInt32) -> OriginalMacRuntimeKey? {
        OriginalMacRuntimeKey.table.filter { $0.value.vk == vk }.min { $0.key < $1.key }?.value
    }
    public static func emit(_ value: [String:Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]) else { return }
        print(String(decoding:data,as:UTF8.self)); fflush(stdout)
    }
    static func milliseconds() throws -> UInt32 { try OriginalMacStartupClock.milliseconds(OriginalMacStartupClock.monotonicSample()) }
    private lazy var virtualClock: (base: UInt32,step: UInt32)? = {
        guard let i = arguments.firstIndex(of:"--virtual-clock"),i+2 < arguments.count,
              let base = UInt32(arguments[i+1]),let step = UInt32(arguments[i+2]) else { return nil }
        return (base,step)
    }()
    public static let virtualDate = Date(timeIntervalSince1970:1_767_225_600)
    private func clock() throws -> UInt32 {
        guard let v = virtualClock else { return try Self.milliseconds() }
        return v.base &+ v.step &* UInt32(truncatingIfNeeded:steps)
    }
    /// Joysticks connected at launch (APPLICATION_JOYSTICKS_PLAN.md): the
    /// host's, or `--joysticks N` (0...2) for scripted runs.
    private var joystickCount: Int {
        if arguments.contains("--script") {
            guard let i = arguments.firstIndex(of:"--joysticks"),i+1 < arguments.count,let n = Int(arguments[i+1]) else { return 0 }
            return max(0,min(2,n))
        }
        return host.connectedJoysticks()
    }
    private func startupEnvironment() -> OriginalMacRuntimeStartupService.Environment {
        guard let v = virtualClock else { return .init(joysticks:joystickCount) }
        let fixed = OriginalMacStartupClock.Sample(seconds:Int64(Self.virtualDate.timeIntervalSince1970),nanoseconds:0)
        return .init(monotonic:{ .init(seconds:Int64(v.base/1000),nanoseconds:Int64(v.base%1000)*1_000_000) },realtime:{ fixed },joysticks:joystickCount)
    }
    private func cursor() -> (Int32,Int32) { virtualClock == nil ? host.cursorPoint() : (0,0) }
    /// The window's close button: the game's WM_SYSCOMMAND(SC_CLOSE). After a
    /// boundary stop it closes the app (returns true).
    public func closeRequested() -> Bool {
        guard !stopped else { return true }
        menu?.messages.close(); return false
    }
    public func start() {
        do {
            // Timer precision without throttling, but the machine may still idle-sleep:
            // the original never calls SetThreadExecutionState.
            host.beginTimingActivity()
            let resources = try resourceBundle()
            let package = try OriginalApplicationStartupInputs.bundled(in:resources)
            let overlay = try overlayRoot()
            let started = try OriginalMacRuntimeStartup.run(inputs:package,overlay:overlay,environment:startupEnvironment(),host:host.startupHost)
            self.started = started
            started.display.pipelinesBackFill = !arguments.contains("--synchronous-render") && started.windows.presentsConcurrently
            while try started.host.takeCommitted() != nil {}
            let music = try host.makeMusicOutput()
            music.muted = arguments.contains("--mute-music"); self.music = music
            if virtualClock != nil { music.virtualSeconds = { [unowned self] in Double((try? self.clock()) ?? 0)/1000 } }
            try music.present(started.runtime.music.presented())
            let sounds = OriginalMacSoundEffects.backed(by:started.audio); self.sounds = sounds
            do { soundOutput = try host.startSoundOutput(sounds,muted:arguments.contains("--mute-sounds")) }
            catch { soundOutputError = String(reflecting:error) }
            let dates = started.host.snapshot.startup?.dates?.dates.map { String(decoding:$0.dropLast(),as:UTF8.self) } ?? []
            let owners = Dictionary(grouping:started.requests,by:\.owner).mapValues(\.count)
            Self.emit(["event":"started","sequence":started.sequence,"window":started.window,"requests":started.requests.count,
                "owners":owners,"attempts":started.attempts,"dates":dates,"overlay":overlay.root.path,
                "musicOutput":"packaged ALAC tracks; graph-event looping",
                "soundOutput":soundOutputError ?? soundOutput ?? "",
                "backingScale":host.backingScale(started.window,in:started.windows),
                "resources":[(try? OriginalApplicationCatalogInputs.bundledDirectory(in:resources).path) ?? "",host.musicDirectory]])
            if exitAfterStartup { flushBeforeExit(); host.terminate(); return }
            let menu = try OriginalMacRuntimeMenu(started,inputs:package,clock:{ [unowned self] in try self.clock() },
                                                  point:{ [unowned self] in self.cursor() },overlay:overlay,
                                                  capsLock:{ [unowned host] in host.capsLock() },messageBox:host.startupHost.messageBox)
            // Scripted runs answer GetKeyState(VK_CAPITAL) with Caps Lock off.
            if arguments.contains("--script") { menu.capsLock = { 0 } }
            self.menu = menu; menu.sounds = sounds
            // Live Winsock for ONLINE GAME (NETWORK_PLAY_PLAN.md); --no-network
            // keeps the declared stand-in (WSAStartup answers wVersion 0).
            if !arguments.contains("--no-network") {
                let network = OriginalMacRuntimeNetwork(localAddresses:arguments.contains("--network-loopback") ? [0x0100007f] : nil,
                                                        sockets:host.makeSockets()); menu.network = network
                network.winsock.post = { [weak menu] n in menu?.messages.post(n.message,n.socket,n.lParam) }
                if let i = arguments.firstIndex(of:"--network-trace"),i+1 < arguments.count {
                    let url = URL(fileURLWithPath:arguments[i+1])
                    try Data().write(to:url,options:.withoutOverwriting)
                    networkTrace = try FileHandle(forWritingTo:url)
                    network.observeControl = { [unowned self] q,r in
                        try self.trace(["kind":"io","cycle":self.cycles,"request":q.kind.rawValue,
                            "arguments":q.arguments,"data":q.data,"result":r.result,"bytes":r.bytes])
                    }
                    network.observeExit = { [unowned self,weak network] q,r in
                        try self.trace(["kind":"exit","cycle":self.cycles,"request":q.kind.rawValue,
                            "arguments":q.arguments,"bytes":q.bytes,"result":r,
                            "openHandles":network?.winsock.openHandles.sorted() ?? [],"started":network?.winsock.started ?? false])
                    }
                }
            }
            menu.messages.capturedJoysticks = UInt32(joystickCount)
            if !arguments.contains("--script") && joystickCount > 0 { host.startJoystickSampling(self) }
            menu.messages.messageBox = { [unowned self] text,caption,type in try self.messageBox(text,caption,type) }
            // "open" of a URL (OFFICIAL WEBSITE and the other links): the default
            // browser opens it. "explore" of a game-directory folder (RECORDING
            // INFO's "recording"): the file manager opens that overlay folder, created
            // as the shipped game has it. Scripted runs only report either.
            menu.messages.shell = { [unowned self] verb,file,delay in
                let text = String(decoding:file,as:UTF8.self),action = String(decoding:verb,as:UTF8.self)
                Self.emit(["event":"shellOpen","verb":action,"file":text,"afterMilliseconds":delay,"iterations":self.committed])
                if self.arguments.contains("--script") { return }
                let target: URL
                if action == "explore" {
                    target = try overlay.url(text)
                    try FileManager.default.createDirectory(at:target,withIntermediateDirectories:true)
                } else if let url = URL(string:text) { target = url } else { return }
                // The original's Sleep before ShellExecuteA (the click sound plays meanwhile).
                let host = self.host
                DispatchQueue.main.asyncAfter(deadline:.now() + .milliseconds(Int(delay))) { MainActor.assumeIsolated { host.open(target) } }
            }
            menu.messages.destroyedWindow = { [unowned self] in
                Self.emit(["event":"windowDestroyed","iterations":self.committed])
                try? self.host.hide(self.gameWindow,in:started.windows)
            }
            gameWindow = started.window
            try host.attach(started.window,in:started.windows,session:self)
            // Alt+Enter's recreation (APPLICATION_FULL_SCREEN_PLAN.md): the new
            // window becomes the game's, for messages, input and captures.
            started.windows.created = { [weak self] token in
                guard let self else { return }
                self.gameWindow = token; self.menu?.messages.window = token
                Self.emit(["event":"windowCreated","window":token,"iterations":self.committed])
                do { try self.host.attach(token,in:started.windows,session:self) } catch { self.stop(error) }
            }
            host.didStart()
            schedule(0)
        } catch { stop(error) }
    }
    private func schedule(_ milliseconds: UInt32) {
        DispatchQueue.main.asyncAfter(deadline:.now() + .milliseconds(Int(milliseconds))) { [weak self] in
            MainActor.assumeIsolated { self?.iterate() }
        }
    }
    private func iterate() {
        guard let menu,let started,!stopped else { return }
        let sleeps = menu.messages.sleeps.count
        do {
            switch try menu.step() {
            case .committed(_,let result):
                if case .quit(let code) = result {
                    // The loop returned WM_QUIT's wParam: WinMain ends.
                    Self.emit(["event":"quit","code":code,"iterations":committed,"uptime":ProcessInfo.processInfo.systemUptime])
                    stopped = true; flushBeforeExit(); host.exit(Int32(bitPattern:code))
                }
                committed += 1
                if let click = clickAt,committed == click.count {
                    menu.messages.mouse(0x200,x:click.x,y:click.y,buttons:0)
                    menu.messages.mouse(0x201,x:click.x,y:click.y,buttons:1)
                }
                // Default clock: committed message-loop iterations. `--script-clock all`
                // counts every iteration, so input keeps flowing during gameplay ticks.
                steps += 1
                if let n = scriptStep(committedBranch:true) { try runScript(n,menu,started,timeline:&script) }
                // Hold the button across game ticks, as a player's click does.
                if let click = clickAt,committed == click.count+15 { menu.messages.mouse(0x202,x:click.x,y:click.y,buttons:0) }
                if let capture = captureAfter,committed == capture.count {
                    try started.windows.flushPresents(); try host.snapshotPNG(gameWindow,in:started.windows).write(to:URL(fileURLWithPath:capture.path))
                    Self.emit(["event":"captured","iterations":committed,"path":capture.path,"permits":menu.requests,
                        "getDCFailures":menu.textRequests,"emptyBlits":menu.emptyBlits])
                    if arguments.contains("--exit-after-capture") { flushBeforeExit(); host.terminate(); return }
                }
                try presentMusic(started,menu)
                // The original's thread slept every Sleep of the iteration (a menu's
                // Sleep(300) as well as the loop's own), so the next one waits their sum.
                let slept = menu.messages.sleeps.dropFirst(sleeps).reduce(UInt32(0),&+)
                // An iteration that slept keeps its Sleep even if a message is now queued.
                let delay = menu.messages.sleeps.count > sleeps ? slept : (menu.messages.queue.isEmpty ? 1 : 0)
                schedule(delay)
            case .loading:
                if try recordNetworkReady(started,menu) { return }
                let begin = Date(),first = loading == nil
                steps += 1
                if let n = scriptStep(committedBranch:false) { try runScript(n,menu,started,timeline:&script) }
                try runScript(cycles,menu,started,timeline:&loadedScript)
                if first {
                    let resources = try resourceBundle()
                    loading = try OriginalMacRuntimeLoading.bundled(started,startupInputs:try OriginalApplicationStartupInputs.bundled(in:resources),
                                                                    clock:{ [unowned self] in try self.clock() },dialogs:host.loadingDialogs,in:resources)
                    loading?.overlay = try overlayRoot()
                    loading?.stageCheckpoints = arguments.contains("--stage-checkpoints")
                    loading?.pipelinesRendering = !arguments.contains("--synchronous-render")
                    loading?.sounds = sounds
                    loading?.shell = menu.messages.shell
                    loading?.network = menu.network
                    loading?.messageBox = menu.messages.messageBox
                    loading?.postMessage = { [weak menu] message,wParam,lParam in menu?.messages.post(message,wParam,lParam) }
                    loading?.presentControlMusic = { [weak self] in
                        try self?.music?.present(started.runtime.music.presented())
                    }
                    // Playback Recording: `--playback-file PATH` answers the open
                    // dialog once; scripted runs never show panels or alerts.
                    if let i = arguments.firstIndex(of:"--playback-file"),i+1 < arguments.count { loading?.playbackFile = arguments[i+1] }
                    loading?.playbackInteractive = !arguments.contains("--script")
                    if virtualClock != nil { loading?.localDate = { Self.virtualDate } }
                }
                guard let loading else { return }
                let sleeps = loading.sleeps.count
                let started0 = Date()
                let completed = try loading.complete(first:first); cycles += 1
                busy += Date().timeIntervalSince(started0)
                switch completed {
                case .launched: Self.emit(["event":"matchLaunched","iterations":committed,"cycles":cycles])
                case .gameplay:
                    gameplayBodies += 1; inMatch = true
                    if gameplayBodies == 1 {
                        gameplayClock = (steps,committed)
                        Self.emit(["event":"gameplay","cycles":cycles,"uptime":ProcessInfo.processInfo.systemUptime])
                    }
                    // Script actions count committed menu iterations; long matches report by ticks.
                    // `--body-captures DIR` writes the window every 300 bodies, or
                    // every N with `--body-capture-every N` (frames for a side-by-side).
                    let every = arguments.firstIndex(of:"--body-capture-every").flatMap { $0+1 < arguments.count ? Int(arguments[$0+1]) : nil } ?? 300
                    if gameplayBodies % every == 0,gameplayBodies % 300 != 0,
                       let i = arguments.firstIndex(of:"--body-captures"),i+1 < arguments.count {
                        let path = "\(arguments[i+1])/b\(String(format:"%06d",gameplayBodies)).png"
                        try started.windows.flushPresents(); try host.snapshotPNG(gameWindow,in:started.windows).write(to:URL(fileURLWithPath:path))
                    }
                    // `--body-frames DIR` writes the presented framebuffer every 300 bodies,
                    // or every N with `--body-frame-every N`, the same on every host.
                    if let i = arguments.firstIndex(of:"--body-frames"),i+1 < arguments.count {
                        let frameEvery = arguments.firstIndex(of:"--body-frame-every").flatMap { $0+1 < arguments.count ? Int(arguments[$0+1]) : nil } ?? 300
                        if frameEvery > 0,gameplayBodies % frameEvery == 0 {
                            try started.windows.presentedPNG(gameWindow).write(to:URL(fileURLWithPath:"\(arguments[i+1])/f\(String(format:"%06d",gameplayBodies)).png"))
                        }
                    }
                    // `--body-frame-digests` reports every presented frame's SHA-256 (XRGB
                    // pixels), so hosts compare whole matches frame by frame.
                    if arguments.contains("--body-frame-digests"),let frame = try started.windows.presentedFrame(gameWindow) {
                        Self.emit(["event":"frameDigest","gameplayBodies":gameplayBodies,"size":[frame.width,frame.height],
                                   "sha256":PortableSHA256.hash(data:frame.pixels).map { String(format:"%02x",$0) }.joined()])
                    }
                    if gameplayBodies % 300 == 0 {
                        var event: [String:Any] = ["event":"progress","gameplayBodies":gameplayBodies,"cycles":cycles,"iterations":committed,
                            "characterAI":loading.counts.characterAI,"objectInputs":loading.counts.objectInputs,"uptime":ProcessInfo.processInfo.systemUptime,
                            "busySeconds":busy,"waitedMilliseconds":waited,"lastSleeps":Array(loading.sleeps.suffix(6)),"music":musicReport(),
                            "sounds":soundReport()]
                        if gameplayBodies % every == 0,let i = arguments.firstIndex(of:"--body-captures"),i+1 < arguments.count {
                            let path = "\(arguments[i+1])/b\(String(format:"%06d",gameplayBodies)).png"
                            try started.windows.flushPresents(); try host.snapshotPNG(gameWindow,in:started.windows).write(to:URL(fileURLWithPath:path)); event["path"] = path
                        }
                        Self.emit(event)
                    }
                    if let i = arguments.firstIndex(of:"--exit-after-bodies"),i+1 < arguments.count,let n = Int(arguments[i+1]),gameplayBodies >= n {
                        flushBeforeExit(); host.terminate(); return
                    }
                case .menu:
                    // The first loaded menu step after a match (epilogue, selection).
                    if inMatch {
                        inMatch = false
                        let c = loading.counts
                        Self.emit(["event":"menu","cycles":cycles,"iterations":committed,"gameplayBodies":gameplayBodies,
                            "epilogues":c.epilogues,"replayFiles":loading.savedReplays.map { "\($0.path) \($0.bytes.count)" },
                            "refusedReplays":loading.refusedReplayOpens,"failedReplayWrites":loading.failedReplayWrites,"heapBytes":started.runtime.heap.used,"uptime":ProcessInfo.processInfo.systemUptime])
                    }
                }
                try traceLoaded(started,menu,completed)
                if try captureSummary(started) { return }
                if loading.playbackDialogs.count > reportedDialogs {
                    for answer in loading.playbackDialogs[reportedDialogs...] { Self.emit(["event":"playbackDialog","file":answer ?? "","iterations":committed]) }
                    reportedDialogs = loading.playbackDialogs.count
                }
                if loading.playbackAlerts.count > reportedAlerts {
                    for text in loading.playbackAlerts[reportedAlerts...] { Self.emit(["event":"playbackAlert","text":text,"iterations":committed]) }
                    reportedAlerts = loading.playbackAlerts.count
                }
                if loading.openedDocuments.count > reportedDocuments {
                    for path in loading.openedDocuments[reportedDocuments...] { Self.emit(["event":"playbackOpen","file":path,"iterations":committed]) }
                    reportedDocuments = loading.openedDocuments.count
                }
                if first {
                    let c = loading.counts
                    Self.emit(["event":"loaded","seconds":Date().timeIntervalSince(begin),"allocations":c.allocations,
                        "bitmapRequests":c.bitmapRequests,"files":c.files,"audioRequests":c.audioRequests])
                }
                try presentMusic(started,menu)
                // PostQuitMessage: WM_QUIT behind the already posted messages.
                for code in loading.quitCodes { menu.messages.post(0x12,code,0) }
                loading.quitCodes = []
                // Every Sleep of the iteration (the Host tail's and a screen's own).
                let delay = loading.sleeps.count > sleeps ? loading.sleeps.dropFirst(sleeps).reduce(UInt32(0),&+) : 1
                waited += Int(delay); schedule(delay)
            }
        } catch { stop(error) }
    }
    /// A single bounded diagnostic of committed owned state. It never supplies
    /// game inputs or another process's expected state.
    private func recordNetworkReady(_ started: OriginalMacRuntimeStartup.Started,_ menu: OriginalMacRuntimeMenu) throws -> Bool {
        guard !networkReadyRecorded,let i = arguments.firstIndex(of:"--network-ready-state"),i+1 < arguments.count,
              let state = started.host.snapshot.session?.state else { return false }
        let base = OriginalMatchPreparation.globalBase
        let role = try state.full.integer(at:0x44f1af-base,as:UInt8.self)
        guard role == 1 || role == 2 else { return false }
        func bytes(_ address: Int,_ count: Int) throws -> [UInt8] {
            let range = (address-base)..<(address-base+count)
            guard state.full.defined[range].allSatisfy({ $0 }) else { throw OriginalStateError.invalidStorage("Network ready diagnostic: undefined bytes") }
            return Array(state.full.bytes[range])
        }
        let value: [String:Any] = ["role":role,"iterations":committed,
            "world":try state.full.integer(at:0x458b00-base,as:UInt32.self),
            "selector":try state.full.integer(at:0x44d064-base,as:UInt32.self),
            "socket":try state.full.integer(at:0x44f46c-base,as:UInt32.self),
            "localAddress":try bytes(0x44f590,4),"names":try bytes(0x44fcc0,88),
            "seats":try (0..<8).map { try state.full.integer(at:0x450b4c-base+4*$0,as:Int32.self) },
            "rng":try bytes(0x44ff90,3001),"notificationRequests":menu.network?.notificationRequestCount ?? 0,
            "clientRequests":menu.network?.clientRequestCount ?? 0]
        let path = arguments[i+1]
        try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]).write(to:URL(fileURLWithPath:path),options:.atomic)
        networkReadyRecorded = true
        Self.emit(["event":"networkReady","role":role,"path":path,"iterations":committed])
        if arguments.contains("--exit-after-network-ready") { stopped = true; flushBeforeExit(); host.terminate(); return true }
        return false
    }
    /// `committed` (default): committed message-loop iterations, which stop
    /// while gameplay ticks run without queued input. `all`: every iteration.
    /// `gameplay`: committed until the first gameplay tick, then every iteration.
    private var scriptClock: String {
        guard let i = arguments.firstIndex(of:"--script-clock"),i+1 < arguments.count else { return "committed" }
        return arguments[i+1]
    }
    private func scriptStep(committedBranch: Bool) -> Int? {
        switch scriptClock {
        case "all": return steps
        case "gameplay":
            if let start = gameplayClock { return start.committed + (steps - start.steps) }
            return committedBranch ? committed : nil
        default: return committedBranch ? committed : nil
        }
    }
    private func runScript(_ n: Int,_ menu: OriginalMacRuntimeMenu,_ started: OriginalMacRuntimeStartup.Started,timeline: inout [Int:[[String]]]) throws {
        for words in timeline[n] ?? [] {
            switch words[0] {
            case "click" where words.count == 3:
                guard let x = Int32(words[1]),let y = Int32(words[2]) else { continue }
                menu.messages.mouse(0x200,x:x,y:y,buttons:0); menu.messages.mouse(0x201,x:x,y:y,buttons:1)
                timeline[n+10,default:[]].append(["release",words[1],words[2]])
            case "release" where words.count == 3:
                guard let x = Int32(words[1]),let y = Int32(words[2]) else { continue }
                menu.messages.mouse(0x202,x:x,y:y,buttons:0)
            case "key" where words.count == 2,"keyup" where words.count == 2:
                guard let vk = UInt32(words[1]),let key = Self.scriptKey(vk) else { continue }
                if words[0] == "key" { menu.messages.key(key,down:true); timeline[n+10,default:[]].append(["keyup",words[1]]) }
                else { menu.messages.key(key,down:false) }
            case "hold" where words.count == 3:
                guard let vk = UInt32(words[1]),let n2 = Int(words[2]),let key = Self.scriptKey(vk) else { continue }
                menu.messages.key(key,down:true); timeline[n+n2,default:[]].append(["keyup",words[1]])
            case "joy" where words.count == 5:
                // A joystick sample (id x y buttons), as joySetCapture reports one.
                guard let id = UInt32(words[1]),let x = UInt32(words[2]),let y = UInt32(words[3]),let b = UInt32(words[4]) else { continue }
                menu.messages.joystick(id,x:x,y:y,buttons:b)
            case "capture" where words.count == 2:
                try started.windows.flushPresents(); try host.snapshotPNG(gameWindow,in:started.windows).write(to:URL(fileURLWithPath:words[1]))
                Self.emit(["event":"captured","iterations":n,"cycles":cycles,"gameplayBodies":gameplayBodies,
                    "lastSleeps":Array(loading?.sleeps.suffix(8) ?? []),"menuSleeps":Array(menu.messages.sleeps.suffix(8)),"objectInputs":loading?.counts.objectInputs ?? 0,"characterAI":loading?.counts.characterAI ?? 0,
            "replayFiles":loading?.savedReplays.map { "\($0.path) \($0.bytes.count)" } ?? [],"refusedReplays":loading?.refusedReplayOpens ?? [],
                    "uptime":ProcessInfo.processInfo.systemUptime,"path":words[1],"music":musicReport(),"sounds":soundReport()])
            case "frame" where words.count == 2:
                try started.windows.presentedPNG(gameWindow).write(to:URL(fileURLWithPath:words[1]))
            case "musicend": music?.finishTrack()
            case "answer" where words.count == 2 && ["yes","no","ok"].contains(words[1]): messageAnswers.append(words[1])
            case "close": menu.messages.close()
            case "fullscreen": try host.toggleFullScreen(gameWindow,in:started.windows)
            case "captureview" where words.count == 2:
                try host.viewPNG(gameWindow,in:started.windows).write(to:URL(fileURLWithPath:words[1]))
                Self.emit(["event":"capturedView","iterations":n,"path":words[1]])
            case "exit": flushBeforeExit(); host.terminate()
            default: Self.emit(["event":"scriptIgnored","entry":words.joined(separator:" ")])
            }
        }
    }
    private func trace(_ value: [String:Any]) throws {
        guard let networkTrace else { return }
        var data = try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]);data.append(10)
        try networkTrace.write(contentsOf:data)
    }
    private func traceLoaded(_ started: OriginalMacRuntimeStartup.Started,_ menu: OriginalMacRuntimeMenu,_ completed: OriginalMacRuntimeLoading.Completed) throws {
        guard networkTrace != nil,let model = started.host.snapshot.session?.loadedOwners?.match else { return }
        let base = OriginalMatchPreparation.globalBase
        func digest(_ records: [OriginalStateRecord]) -> String {
            // SHA-256 over each record's bytes then its definedness mask, in order.
            var data = Data()
            for record in records {
                data.append(contentsOf:record.bytes);data.append(contentsOf:record.defined.map { $0 ? UInt8(1) : 0 })
            }
            return SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()
        }
        var fighters: [[String:Int]] = []
        for seat in 0..<20 where try model.world.integer(at:4+seat,as:UInt8.self) != 0 {
            let slot = Int(try model.world.integer(at:0x194+4*seat,as:UInt32.self))
            guard model.actors.indices.contains(slot) else { throw OriginalStateError.invalidStorage("Network trace Actor binding") }
            let actor = model.actors[slot],object = Int(try actor.integer(at:0x368,as:UInt32.self))
            guard model.loadedObjects.indices.contains(object) else { throw OriginalStateError.invalidStorage("Network trace Object binding") }
            fighters.append(["seat":seat,"actor":slot,"id":Int(try model.loadedObjects[object].header.integer(at:0x6f4,as:Int32.self)),
                             "frame":Int(try actor.integer(at:0x70,as:Int32.self)),"hp":Int(try actor.integer(at:0x2fc,as:Int32.self))])
        }
        var value: [String:Any] = ["kind":"state","cycle":cycles,"completion":String(describing:completed),"bodies":gameplayBodies,
            "worldSHA256":digest([model.world]),"actorsSHA256":digest(model.actors),"fighters":fighters,
            "worldBytes":Data(model.world.bytes).base64EncodedString(),"worldDefined":Data(model.world.defined.map { $0 ? UInt8(1) : 0 }).base64EncodedString(),
            "sentPackets":menu.network?.sentControlPackets ?? 0,"receivedBytes":menu.network?.receivedControlBytes ?? 0]
        for (name,address) in [("mode",0x451160),("menu",0x44d020),("phase",0x450b90),("rngIndex",0x450bcc),
                               ("rngCounter",0x450c34),("roundTimer",0x450bdc),("winner",0x450bf8),("arena",0x44fb6c),("inputSequence",0x450bf0),
                               ("clock",0x450bbc),("phase12",0x450bd0),("phase3",0x450bd4),("phase2",0x450bd8)] {
            value[name] = try model.globals.integer(at:address-base,as:Int32.self)
        }
        if networkStateCycles.contains(cycles) {
            func record(_ r: OriginalStateRecord) -> [String:String] {
                ["bytes":Data(r.bytes).base64EncodedString(),"defined":Data(r.defined.map { $0 ? UInt8(1) : 0 }).base64EncodedString()]
            }
            value["actors"] = model.actors.map(record);value["globals"] = record(model.globals)
        }
        try trace(value)
    }
    private func captureSummary(_ started: OriginalMacRuntimeStartup.Started) throws -> Bool {
        guard arguments.contains("--exit-after-summary"),gameplayBodies > 0,
              let model = started.host.snapshot.session?.loadedOwners?.match,
              try (144..<350).contains(model.globals.integer(at:0x450bdc-OriginalMatchPreparation.globalBase,as:Int32.self)) else { return false }
        if let i = arguments.firstIndex(of:"--summary-capture"),i+1 < arguments.count {
            try started.windows.flushPresents(); try host.snapshotPNG(gameWindow,in:started.windows).write(to:URL(fileURLWithPath:arguments[i+1]))
        }
        let values = try Self.summaryValues(model)
        if let i = arguments.firstIndex(of:"--summary-json"),i+1 < arguments.count {
            try JSONSerialization.data(withJSONObject:values,options:[.sortedKeys]).write(to:URL(fileURLWithPath:arguments[i+1]),options:.atomic)
        }
        Self.emit(["event":"summary","cycles":cycles,"gameplayBodies":gameplayBodies,"values":values,
            "replayFiles":loading?.savedReplays.map { "\($0.path) \($0.bytes.count)" } ?? []])
        stopped = true;flushBeforeExit(); host.terminate();return true
    }
    /// The Summary's sources (OriginalResultLayout): per active seat the object
    /// id, Kill +358, Attack +348, HP Lost +34c, MP Usage +350, Picking +35c,
    /// team +364 and HP +2fc; time 450bbc, winner 450bf8, mode 451160 and the
    /// War totals 451b64..451b70. The same fields are read from the original
    /// (tools/crossover_drive/summary_original.py; CROSSPLAY_LOOP.md).
    public static func summaryValues(_ model: OriginalMatchPreparation) throws -> [String:Any] {
        let base = OriginalMatchPreparation.globalBase
        func g(_ address: Int) throws -> Int { Int(try model.globals.integer(at:address-base,as:Int32.self)) }
        var seats: [[String:Int]] = []
        for seat in 0..<20 where try model.world.integer(at:4+seat,as:UInt8.self) != 0 {
            let slot = Int(try model.world.integer(at:0x194+4*seat,as:UInt32.self))
            guard model.actors.indices.contains(slot) else { throw OriginalStateError.invalidStorage("Summary Actor binding") }
            let actor = model.actors[slot],object = Int(try actor.integer(at:0x368,as:UInt32.self))
            guard model.loadedObjects.indices.contains(object) else { throw OriginalStateError.invalidStorage("Summary Object binding") }
            func a(_ offset: Int) throws -> Int { Int(try actor.integer(at:offset,as:Int32.self)) }
            seats.append(["seat":seat,"id":Int(try model.loadedObjects[object].header.integer(at:0x6f4,as:Int32.self)),
                          "kill":try a(0x358),"attack":try a(0x348),"hpLost":try a(0x34c),"mp":try a(0x350),"picking":try a(0x35c),
                          "team":try a(0x364),"hp":try a(0x2fc)])
        }
        return ["seats":seats,"ticks":try g(0x450bbc),"winner":try g(0x450bf8),"mode":try g(0x451160),
                "war":try [0x451b64,0x451b68,0x451b6c,0x451b70].map(g)]
    }
    private var musicEnds = 0, musicNotifications = 0, inMatch = false, reportedAlerts = 0, reportedDialogs = 0, reportedDocuments = 0
    /// Committed graph state to the output; a finished track queues EC_COMPLETE
    /// and posts the registered notification for the next iteration's WndProc.
    private func presentMusic(_ started: OriginalMacRuntimeStartup.Started,_ menu: OriginalMacRuntimeMenu) throws {
        guard let music else { return }
        try music.present(started.runtime.music.presented())
        guard let graph = music.takeEnded() else { return }
        musicEnds += 1
        guard let n = started.runtime.music.complete(graph) else { return }
        guard n.window == menu.messages.window else { throw OriginalMacRuntimeMessages.Boundary.arguments("graph notify window") }
        menu.messages.post(n.message,0,n.lParam); musicNotifications += 1
    }
    private func overlayRoot() throws -> OriginalMacRuntimeOverlay {
        guard let i = arguments.firstIndex(of:"--overlay"),i+1 < arguments.count else { return try host.standardOverlay() }
        return .init(root:URL(fileURLWithPath:arguments[i+1],isDirectory:true))
    }
    /// Scripted MessageBoxA buttons, in order (`answer` script action).
    private var messageAnswers: [String] = []
    /// MessageBoxA: MB_OK → IDOK, MB_YESNO → IDYES/IDNO (declared Windows
    /// return values). Interactive runs ask the host with those buttons.
    private func messageBox(_ text: [UInt8],_ caption: [UInt8],_ type: UInt32) throws -> Int32 {
        struct Unanswered: Error { let text: String, type: UInt32 }
        let buttons: [(String,Int32)]
        switch type & 0xf {
        case 0: buttons = [("ok",1)]
        case 4: buttons = [("yes",6),("no",7)]
        default: throw Unanswered(text:String(decoding:text,as:UTF8.self),type:type)
        }
        let answer: Int32
        if arguments.contains("--script") {
            guard !messageAnswers.isEmpty,let chosen = buttons.first(where: { $0.0 == messageAnswers[0] }) else {
                throw Unanswered(text:String(decoding:text,as:UTF8.self),type:type)
            }
            messageAnswers.removeFirst(); answer = chosen.1
        } else {
            let index = host.askMessageBox(text:String(decoding:text,as:UTF8.self),caption:String(decoding:caption,as:UTF8.self),
                                           buttons:buttons.map { $0.0.capitalized == "Ok" ? "OK" : $0.0.capitalized })
            answer = buttons[max(0,min(buttons.count-1,index))].1
        }
        Self.emit(["event":"messageBox","text":String(decoding:text,as:UTF8.self),"caption":String(decoding:caption,as:UTF8.self),
                   "type":type,"answer":answer,"iterations":committed])
        return answer
    }
    private func soundReport() -> [String:Any] {
        let r = sounds?.rendered ?? .init(),a = sounds?.activity ?? (playing:0,looping:0)
        return ["performed":sounds?.performed ?? 0,"rejected":sounds?.rejected ?? 0,"playing":a.playing,"looping":a.looping,
                "renderedFrames":r.frames,"audibleFrames":r.audible,"peak":(Double(r.peak)*1000).rounded()/1000]
    }
    private func musicReport() -> [String:Any] {
        guard let s = music?.state else { return [:] }
        return ["graph":s.graph,"track":s.track ?? "","playing":s.playing,"ended":s.ended,"gain":s.gain,
                "volume":started?.runtime.music.presented()?.volume ?? 0,"ends":musicEnds,"notifications":musicNotifications,
                "graphRequests":started?.runtime.music.graphOperations.count ?? 0,
                "time":(s.time*1000).rounded()/1000,"unresolved":music?.unresolved.map { String(decoding:$0,as:UTF8.self) } ?? []]
    }
    /// Waits for pipelined pixel work before the game ends, so the last frame
    /// is shown (CORE_REALTIME 1c); a held host failure no longer matters here.
    private func flushBeforeExit() { try? started?.windows.flushPresents() }
    private func stop(_ error: Error) {
        stopped = true
        Self.emit(["event":"boundary","error":String(reflecting:error),"iterations":committed,
            "objectInputs":loading?.counts.objectInputs ?? 0,"characterAI":loading?.counts.characterAI ?? 0,
            "replayFiles":loading?.savedReplays.map { "\($0.path) \($0.bytes.count)" } ?? [],"refusedReplays":loading?.refusedReplayOpens ?? [],
            "request":menu?.lastRequest.map { String(describing:$0).prefix(400) }.map(String.init) ?? ""])
        // Scripted runs report the boundary and end; only interactive runs show it.
        if exitAfterStartup || arguments.contains("--exit-after-capture") || arguments.contains("--script") { flushBeforeExit(); host.exit(1) }
        let text = String(reflecting:error)
        // A source fault is the original's own crash at this point, reproduced
        // as a stop; anything else is a part of the game not yet supported.
        host.showStop(title:text.contains("Source fault") ? "The original game crashes here" : "NTSD stopped at an unsupported boundary",text:text)
    }
}
