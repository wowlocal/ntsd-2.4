import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import NTSDCore
@testable import NTSDRuntime

/// ENGINE_SPLIT E7d: windows without a display for the synthetic pack's runs,
/// the declared policy of NTSDHeadlessHost's HeadlessWindowHost (that target is
/// not linked into the tests, so the same policy is written here): a titled
/// window has no side or bottom frame and a `caption`-point title bar, the
/// popup covers the screen, windows are centred; presents stay on the main
/// thread (`presentsConcurrently` false), so a presented crop is final when
/// a step returns. Screen and caption are invented sizes (integers, as the
/// runtime requires of frame metrics, OriginalRuntimeWindowBackend.swift:276-279).
@MainActor final class SyntheticWindowHost: OriginalRuntimeWindowHost {
    final class Window {
        let popup: Bool, title: String, client: CGSize, origin: CGPoint
        var visible = false, closed = false, presents = 0
        init(popup: Bool, title: String, client: CGSize, origin: CGPoint) {
            self.popup = popup; self.title = title; self.client = client; self.origin = origin
        }
    }
    final class Cursor {}
    static let screen = CGSize(width: 1440, height: 900), caption: CGFloat = 28
    private(set) var windows: [Window] = []
    private static func window(_ object: AnyObject) -> Window { object as! Window }
    func screenSize() throws -> CGSize { Self.screen }
    func frameMetric(_ index: UInt32) throws -> CGFloat { index == 4 ? Self.caption : 0 }
    func arrowCursor() -> AnyObject { Cursor() }
    func createWindow(popup: Bool, width: CGFloat, height: CGFloat, title: String, cursor: AnyObject) throws -> AnyObject {
        let client = popup ? Self.screen : CGSize(width: width, height: height - Self.caption)
        guard client.width > 0, client.height > 0 else { throw OriginalRuntimeWindowBackend.Boundary.geometry }
        let origin = popup ? CGPoint.zero : CGPoint(x: ((Self.screen.width - width)/2).rounded(.down),
                                                    y: ((Self.screen.height - height)/2).rounded(.down) + Self.caption)
        let window = Window(popup: popup, title: title, client: client, origin: origin)
        windows.append(window)
        return window
    }
    func windowCreated(_ lease: OriginalRuntimeWindowBackend.WindowLease, popup: Bool, backend: OriginalRuntimeWindowBackend) {}
    func orderFront(_ window: AnyObject) { Self.window(window).visible = true }
    func update(_ window: AnyObject) {}
    func show(_ window: AnyObject) -> Bool {
        let w = Self.window(window), wasVisible = w.visible
        w.visible = true; return wasVisible
    }
    func close(_ window: AnyObject) { let w = Self.window(window); w.closed = true; w.visible = false }
    nonisolated func released(_ window: AnyObject, closed: Bool, platformState: AnyObject?) {}
    func clientBounds(_ window: AnyObject) throws -> CGRect { CGRect(origin: .zero, size: Self.window(window).client) }
    func clientFrame(_ window: AnyObject) throws -> CGRect { CGRect(origin: .zero, size: Self.window(window).client) }
    func displayGeometry(_ window: AnyObject) throws -> OriginalRuntimeDisplayGeometry {
        let w = Self.window(window)
        return .init(screen: CGRect(origin: .zero, size: Self.screen),
                     clientOnScreen: CGRect(x: w.origin.x, y: Self.screen.height - w.origin.y - w.client.height,
                                            width: w.client.width, height: w.client.height))
    }
    func desktopPoint(_ window: AnyObject, client point: CGPoint) throws -> CGPoint {
        let w = Self.window(window); return CGPoint(x: w.origin.x + point.x, y: w.origin.y + point.y)
    }
    /// The backend keeps the presented crop (`WindowLease.presented`).
    func present(_ frame: OriginalFramebuffer, in window: AnyObject) throws { Self.window(window).presents += 1 }
}

/// ENGINE_SPLIT E7d: the runtime's start of a game on the synthetic pack, run
/// synchronously in a test. It composes what `OriginalRuntimeSession.start`
/// and `iterate` compose (OriginalRuntimeSession.swift:236-335, 339-470):
/// `OriginalMacRuntimeStartup.run`, the silent music output, the sound-effect
/// voices and `OriginalMacRuntimeMenu`, then, when the menu asks to load,
/// `OriginalMacRuntimeLoading` over the packages `OriginalRuntimeLoadingPackages`
/// reads from the pack's content location (the catalog through
/// `OriginalApplicationCatalogSession`, the pool, the loaded menu) and its
/// cached cycles: menus, the match launch and gameplay bodies. Time is the
/// session's `--virtual-clock BASE STEP` (BASE + STEP × iterations started);
/// input is put on the menu's message queue as the session's `--script`
/// (committed menu iterations) and `--loaded-script` (loaded cycles) do. The
/// session's state is private (OriginalRuntimeSession.swift:114-116), so a test
/// cannot read the loaded cycles it would need; the composition is written here
/// (about 70 lines of the session's glue, in its order) and checked against the
/// session only up to the front menu (SyntheticSessionHost runs the session itself).
/// The session's `host.exit` (:757) applies only to scripted or exit-after runs. No network
/// (WSAStartup's declared stand-in), no joysticks, no message box answered
/// (one stops the run), presents on the main thread.
@MainActor final class SyntheticRun {
    let root: URL, pack: SyntheticContentPack
    let content: OriginalContentLocation, startupInputs: OriginalApplicationStartupInputs
    let overlay: OriginalMacRuntimeOverlay
    let windowHost = SyntheticWindowHost()
    let started: OriginalMacRuntimeStartup.Started
    let menu: OriginalMacRuntimeMenu
    let music: OriginalMacMusicOutput
    let sounds: OriginalMacSoundEffects
    private(set) var loading: OriginalMacRuntimeLoading?
    /// Virtual clock: invented base and step (milliseconds).
    static let clockBase: UInt32 = 90_000, clockStep: UInt32 = 20
    /// The fixed date startup's FILETIME reads (the session's virtual date,
    /// OriginalRuntimeSession.swift:202), in UTC.
    static let fixedRealtime = OriginalMacStartupClock.Sample(seconds: Int64(OriginalRuntimeSession.virtualDate.timeIntervalSince1970), nanoseconds: 0)
    private(set) var steps = 0, committed = 0, cycles = 0, gameplayBodies = 0, musicEnds = 0
    /// MessageBoxA, ShellExecuteA and dialog requests of the run, in order.
    final class Log { var shown: [String] = [] }
    let log = Log()

    /// Scripted input: a key (by VK, the lowest Mac key with it, as
    /// `OriginalRuntimeSession.scriptKey`) or a mouse message at a client point.
    enum Action: Equatable { case key(UInt32, down: Bool), mouse(UInt32, x: Int32, y: Int32, buttons: UInt32) }
    /// Actions at committed menu iterations and at loaded cycles.
    var script: [Int: [Action]] = [:], loadedScript: [Int: [Action]] = [:]

    func clock() -> UInt32 { Self.clockBase &+ Self.clockStep &* UInt32(truncatingIfNeeded: steps) }
    /// GetLocalTime's source date (`OriginalMacRuntimeLoading.localDate`), E7f:
    /// the instant whose wall-clock time in the host's zone is the virtual
    /// date's in UTC (2026-01-01 00:00:00). The runtime converts the date in
    /// the host's zone (OriginalMacRuntimeLoading.swift:414-419), so the
    /// prelude's replay name, and the recording notices that show it
    /// (OriginalMenuPresentation.swift:286-291), are then the same on every
    /// host. E7d passed the virtual date itself, whose name varied with the
    /// zone (only globals held it; no E7d pin reads them).
    static let localVirtualDate: Date = {
        var utc = Calendar(identifier: .gregorian), local = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!; local.timeZone = .current
        let wall = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: OriginalRuntimeSession.virtualDate)
        return local.date(from: wall)!
    }()

    /// `glyphs` (E7f): TextOutA draws with the authored glyph source
    /// (SyntheticGlyphs); without it every string's mask is empty, so no text
    /// pixel is drawn (E7d's runs).
    init(root: URL, pack: SyntheticContentPack, glyphs: Bool = false) throws {
        self.root = root; self.pack = pack
        guard let bundle = Bundle(path: root.path) else { throw SyntheticRunError.noBundle(root.path) }
        content = OriginalContentLocation(appBundle: bundle, identity: pack.identity, fallback: { nil })
        startupInputs = try OriginalApplicationStartupInputs.bundled(in: content)
        overlay = OriginalMacRuntimeOverlay(root: root.appendingPathComponent("overlay", isDirectory: true))
        let base = Self.clockBase, realtime = Self.fixedRealtime
        let environment = OriginalMacRuntimeStartupService.Environment(
            monotonic: { .init(seconds: Int64(base/1000), nanoseconds: Int64(base%1000)*1_000_000) },
            realtime: { realtime }, zone: { TimeZone(secondsFromGMT: 0)! }, joysticks: 0)
        let log = self.log
        func box(_ text: [UInt8], _ caption: [UInt8]) { log.shown.append("box " + String(decoding: caption, as: UTF8.self) + ": " + String(decoding: text, as: UTF8.self)) }
        let host = OriginalRuntimeStartupHost(windows: windowHost,
            textMask: glyphs ? SyntheticGlyphs.mask : { _ in .init(advance: 0, originX: 0, originY: 0, width: 0, height: 0, bits: []) },
            messageBox: { box($0, $1) })
        started = try OriginalMacRuntimeStartup.run(inputs: startupInputs, overlay: overlay, environment: environment, host: host)
        started.display.pipelinesBackFill = false
        while try started.host.takeCommitted() != nil {}
        music = try OriginalMacMusicOutput.silent(directory: root.appendingPathComponent(SyntheticContentPack.music, isDirectory: true))
        music.muted = true
        sounds = OriginalMacSoundEffects.backed(by: started.audio)
        started.audio.recordsOperations = false
        weak var clockSelf: SyntheticRun?
        menu = try OriginalMacRuntimeMenu(started, inputs: startupInputs, clock: { clockSelf?.clock() ?? base },
                                          point: { (0, 0) }, overlay: overlay, capsLock: { 0 }, messageBox: { box($0, $1) })
        menu.sounds = sounds
        menu.messages.messageBox = { text, caption, _ in box(text, caption); throw SyntheticRunError.messageBox(String(decoding: text, as: UTF8.self)) }
        menu.messages.shell = { verb, file, _ in log.shown.append("shell " + String(decoding: verb, as: UTF8.self) + " " + String(decoding: file, as: UTF8.self)) }
        clockSelf = self
        music.virtualSeconds = { [unowned self] in Double(self.clock())/1000 }
        try music.present(started.runtime.music.presented())
    }

    enum Stepped: Equatable { case committed, loaded(OriginalMacRuntimeLoading.Completed), quit(UInt32) }
    /// One iteration of the session's loop: a committed menu iteration (script
    /// input, then music) or one loading request (first load or cached cycle).
    func step() throws -> Stepped {
        switch try menu.step() {
        case .committed(_, let result):
            if case .quit(let code) = result { return .quit(code) }
            committed += 1; steps += 1
            try perform(script[committed] ?? [])
            try presentMusic()
            return .committed
        case .loading:
            steps += 1
            try perform(loadedScript[cycles] ?? [])
            let first = loading == nil
            if first {
                let loading = try OriginalMacRuntimeLoading.bundled(started, startupInputs: startupInputs,
                    packages: OriginalRuntimeLoadingPackages(in: content), clock: { [unowned self] in self.clock() },
                    dialogs: .init(chooseRecording: { _ in nil }, alert: { [log] in log.shown.append("alert " + $0) },
                                   open: { [log] in log.shown.append("open " + $0) }))
                loading.overlay = overlay
                loading.pipelinesRendering = false
                loading.sounds = sounds
                loading.shell = menu.messages.shell
                loading.messageBox = menu.messages.messageBox
                loading.postMessage = { [weak menu] message, wParam, lParam in menu?.messages.post(message, wParam, lParam) }
                loading.presentControlMusic = { [unowned self] in try self.music.present(self.started.runtime.music.presented()) }
                loading.playbackInteractive = false
                loading.localDate = { Self.localVirtualDate }
                self.loading = loading
            }
            let completed = try loading!.complete(first: first); cycles += 1
            if completed == .gameplay { gameplayBodies += 1 }
            try presentMusic()
            for code in loading!.quitCodes { menu.messages.post(0x12, code, 0) }
            loading!.quitCodes = []
            return .loaded(completed)
        }
    }
    /// Steps until `done` holds after a step, at most `limit` steps.
    func run(limit: Int, until done: () throws -> Bool) throws {
        for _ in 0..<limit {
            if case .quit(let code) = try step() { throw SyntheticRunError.quit(code) }
            if try done() { return }
        }
        throw SyntheticRunError.stepBound(limit)
    }
    private func perform(_ actions: [Action]) throws {
        for action in actions {
            switch action {
            case .key(let vk, let down):
                guard let k = OriginalRuntimeSession.scriptKey(vk) else { throw SyntheticRunError.noKey(vk) }
                menu.messages.key(k, down: down)
            case .mouse(let message, let x, let y, let buttons): menu.messages.mouse(message, x: x, y: y, buttons: buttons)
            }
        }
    }
    /// A left click at committed iteration `at`, the button held `frames`
    /// iterations, as the session's `click X Y` (held 10).
    func click(x: Int32, y: Int32, at: Int, frames: Int = 10) {
        script[at, default: []] += [.mouse(0x200, x: x, y: y, buttons: 0), .mouse(0x201, x: x, y: y, buttons: 1)]
        script[at + frames, default: []].append(.mouse(0x202, x: x, y: y, buttons: 0))
    }
    /// A key held from loaded cycle `at` for `cycles` cycles, as `--loaded-script`'s `hold VK N`.
    func hold(_ vk: UInt32, atCycle at: Int, cycles: Int = 2) {
        loadedScript[at, default: []].append(.key(vk, down: true)); loadedScript[at + cycles, default: []].append(.key(vk, down: false))
    }
    func tap(_ player: Int, _ key: SyntheticContentPack.Key, atCycle at: Int) {
        hold(SyntheticContentPack.vk(player: player, key), atCycle: at)
    }
    private func presentMusic() throws {
        try music.present(started.runtime.music.presented())
        guard let graph = music.takeEnded() else { return }
        musicEnds += 1
        guard let n = started.runtime.music.complete(graph) else { return }
        menu.messages.post(n.message, 0, n.lParam)
    }

    /// Committed globals (World+0 0x458b00, selector 0x44d064, ...).
    func global(_ address: Int) throws -> Int32 {
        guard let state = started.host.snapshot.session?.state else { throw SyntheticRunError.noState }
        return try state.full.integer(at: address - OriginalMatchPreparation.globalBase, as: Int32.self)
    }
    /// The loaded match's owned state (World, Actors, globals, catalog), once loaded.
    var match: OriginalMatchPreparation? { started.host.snapshot.session?.loadedOwners?.match }
    /// The game window's last presented crop.
    func presented() throws -> OriginalFramebuffer? {
        try started.windows.flushPresents()
        return try started.windows.presentedFrame(started.window)
    }

    // MARK: The scripted VS match (rungs 1 and 3)

    /// The front menu's START row (OriginalMainMenu.swift:155-163: x 276-520,
    /// y [0x453da4]+202+15...39), clicked at committed iteration 8.
    func clickStart() throws {
        click(x: 398, y: try global(0x453da4) &+ 202 &+ 27, at: 8)
    }
    /// The loaded cycles of the scripted VS start, found by running it and
    /// pinned in SyntheticVSMatchTests. Player 1 confirms VS on the mode screen
    /// (0x451160 0, OriginalModeSelection.swift:46-61); both players join,
    /// choose ordinals 0 and 1 and get ready (OriginalCharacterScreen.swift:220-286);
    /// after the ready countdown (150 cycles) player 1 confirms no computer
    /// players and moves the settings to option 0, the start (OriginalMatchSelection.swift:102-214).
    func scriptVSStart() {
        tap(0, .attack, atCycle: 4)                                       // mode screen: VS
        tap(0, .attack, atCycle: 10); tap(1, .attack, atCycle: 10)        // join
        tap(0, .right, atCycle: 14); tap(1, .right, atCycle: 14)          // ordinal 0
        tap(0, .attack, atCycle: 18); tap(1, .right, atCycle: 18)         // player 1: team; player 2: ordinal 1
        tap(0, .attack, atCycle: 22); tap(1, .attack, atCycle: 22)        // player 1 ready; player 2: team
        tap(1, .attack, atCycle: 26)                                      // player 2 ready
        tap(0, .attack, atCycle: 182)                                     // no computer players
        tap(0, .up, atCycle: 188); tap(0, .up, atCycle: 192)              // settings option 2 -> 0
        tap(0, .attack, atCycle: 196)                                     // start
    }
    /// The fight: player 2 walks up to player 1's depth, player 1 punches four times.
    func scriptFight() {
        hold(SyntheticContentPack.vk(player: 1, .up), atCycle: 205, cycles: 36)
        for c in [250, 262, 274, 286] { tap(0, .attack, atCycle: c) }
    }

    // MARK: E7f: a match against a computer player, to its end

    /// The loaded cycles of the scripted start against one computer player,
    /// found by running it and pinned in SyntheticComputerMatchTests. Player 1
    /// alone joins, takes ordinal 0 and gets ready (as in `scriptVSStart`);
    /// after the ready countdown (cycle 173) one team of humans makes the
    /// computer count's minimum 1 (OriginalMatchSelection.swift:114-118), which
    /// player 1 confirms: seat 1 becomes the computer to choose
    /// (:145-151, OriginalComputerSelection.swift:141-207). Player 1 steps its
    /// character from Random to ordinal 2 (SyThree, of the pack's harder-hitting
    /// characters 3-8), confirms it and its team (Independent); the remaining
    /// seats are drawn from Random (OriginalComputerSelection.swift:97-114, 199);
    /// the settings go from option 2 to 0, the start.
    func scriptComputerStart() {
        tap(0, .attack, atCycle: 4)                                       // mode screen: VS
        tap(0, .attack, atCycle: 10)                                      // join
        tap(0, .right, atCycle: 14)                                       // ordinal 0
        tap(0, .attack, atCycle: 18); tap(0, .attack, atCycle: 22)        // character, team: ready
        tap(0, .attack, atCycle: 182)                                     // one computer player
        for c in [188, 192, 196] { tap(0, .right, atCycle: c) }           // its character: Random -> ordinal 2
        tap(0, .attack, atCycle: 200); tap(0, .attack, atCycle: 204)      // its character, its team
        tap(0, .up, atCycle: 210); tap(0, .up, atCycle: 214)              // settings option 2 -> 0
        tap(0, .attack, atCycle: 218)                                     // start
    }
    /// The loaded cycle at which player 1 leaves the result screen: the
    /// round waits at timer 144 until a seat 0-7 Actor holds attack or jump
    /// (OriginalMatchRound.swift:121-152), which this run reaches at cycle 663.
    static let leaveResultCycle = 680
    func scriptLeaveResult() { tap(0, .attack, atCycle: Self.leaveResultCycle) }

    /// The match's computer players: active slots 10-17 whose Object is a
    /// character (type 0), the slots the local input hands to the character
    /// AI (OriginalLocalInput.swift:114-127; a computer chosen for seat s plays in slot
    /// s+10, OriginalMatchPreparation.swift:180-182).
    func computerSlots() throws -> [Int] {
        guard let m = match else { throw SyntheticRunError.noState }
        return try (10..<18).filter { slot in
            guard try m.world.integer(at: 4 + slot, as: UInt8.self) != 0 else { return false }
            let a = m.actors[Int(try m.world.integer(at: 0x194 + 4*slot, as: UInt32.self))]
            return try m.loadedObjects[Int(try a.integer(at: 0x368, as: UInt32.self))].header.integer(at: 0x6f8, as: Int32.self) == 0
        }
    }
    /// A slot's current buttons (Actor +0xcd up, down, left, right, attack,
    /// jump, defend; OriginalCharacterAI.swift:7-8, 58): after a body, the ones
    /// the character AI chose for it.
    func buttons(slot: Int) throws -> [UInt8] {
        guard let m = match else { throw SyntheticRunError.noState }
        let a = m.actors[Int(try m.world.integer(at: 0x194 + 4*slot, as: UInt32.self))]
        return try (0..<7).map { try a.integer(at: 0xcd + $0, as: UInt8.self) }
    }

    /// One active seat of the match: its Actor's object ID (header +0x6f4),
    /// frame +0x70, integer position +0x10/+0x14/+0x18, HP +0x2fc, facing +0x80.
    struct Fighter: Equatable, CustomStringConvertible {
        let seat: Int, id: Int32, frame: Int32, x: Int32, y: Int32, z: Int32, hp: Int32, facing: UInt8
        var description: String { "s\(seat) id\(id) f\(frame) (\(x),\(y),\(z)) hp\(hp) face\(facing)" }
    }
    func fighters() throws -> [Fighter] {
        guard let m = match else { throw SyntheticRunError.noState }
        var result: [Fighter] = []
        for seat in 0..<400 where try m.world.integer(at: 4 + seat, as: UInt8.self) != 0 {
            let a = m.actors[Int(try m.world.integer(at: 0x194 + 4*seat, as: UInt32.self))]
            let object = Int(try a.integer(at: 0x368, as: UInt32.self))
            result.append(.init(seat: seat, id: try m.loadedObjects[object].header.integer(at: 0x6f4, as: Int32.self),
                frame: try a.integer(at: 0x70, as: Int32.self), x: try a.integer(at: 0x10, as: Int32.self),
                y: try a.integer(at: 0x14, as: Int32.self), z: try a.integer(at: 0x18, as: Int32.self),
                hp: try a.integer(at: 0x2fc, as: Int32.self), facing: try a.integer(at: 0x80, as: UInt8.self)))
        }
        return result
    }
}

enum SyntheticRunError: Error, Equatable { case noBundle(String), noState, noKey(UInt32), messageBox(String), quit(UInt32), stepBound(Int), unexpected(String) }

/// Integer digests that are the same on every little-endian host.
enum SyntheticDigest {
    /// SHA-256 of a frame's XRGB words, as the session's `--body-frame-digests` reports it.
    static func sha256(_ frame: OriginalFramebuffer) -> String { SyntheticContentPack.digest(Array(frame.pixels)) }
    /// A cheap word-wise variant of 64-bit FNV-1a (one step per little-endian
    /// 64-bit word of the frame's pixels, not per byte as standard FNV-1a)
    /// (a frame is a whole number of words), for every body of a run: the debug
    /// build's SHA-256 takes about a third of a second per 800×600 frame.
    static func fnv64(_ frame: OriginalFramebuffer, into hash: inout UInt64) {
        frame.pixels.withUnsafeBytes { raw in
            precondition(raw.count % 8 == 0)
            // E7f: aligned storage (the usual case) is read as words through a
            // pointer: the same values, about seven times as fast in a debug build.
            if let base = raw.baseAddress, Int(bitPattern: base) % MemoryLayout<UInt64>.alignment == 0 {
                raw.withMemoryRebound(to: UInt64.self) { words in
                    guard var word = words.baseAddress else { return }
                    let end = word + words.count
                    var h = hash
                    while word < end { h = (h ^ UInt64(littleEndian: word.pointee)) &* 0x100000001b3; word += 1 }
                    hash = h
                }
                return
            }
            for offset in stride(from: 0, to: raw.count, by: 8) {
                hash = (hash ^ UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: offset, as: UInt64.self))) &* 0x100000001b3
            }
        }
    }
    static let fnvBasis: UInt64 = 0xcbf29ce484222325
    /// The word-wise FNV-1a over one frame (`fnv64` from the basis), as 16 hex digits: the
    /// cheap pin for frames beyond the few digested with SHA-256.
    static func fnv64(_ frame: OriginalFramebuffer) -> String {
        var hash = fnvBasis; fnv64(frame, into: &hash); return hex64(hash)
    }
    /// FNV-1a over bytes, byte by byte, as 16 hex digits (E7f: the 6.5 MB replay
    /// recording, whose SHA-256 takes about a second in a debug build).
    static func fnv64(_ bytes: [UInt8]) -> String {
        var hash = fnvBasis
        for byte in bytes { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return hex64(hash)
    }
    static func hex64(_ value: UInt64) -> String {
        let digits = String(value, radix: 16)
        return String(repeating: "0", count: 16 - digits.count) + digits
    }
    /// SHA-256 over records' bytes then their definedness, in order (the
    /// session's `--network-trace` digest, OriginalRuntimeSession.swift:617-625).
    static func records(_ records: [OriginalStateRecord]) -> String {
        var data: [UInt8] = []
        for record in records { data += record.bytes; data += record.defined.map { $0 ? 1 : 0 } }
        return SyntheticContentPack.digest(data)
    }
}

/// ENGINE_SPLIT E7d: an `OriginalRuntimeSessionHost` for the session itself,
/// modelled on NTSDHeadlessHost's HeadlessSessionHost (not linked into the
/// tests): the pack as the content, SyntheticWindowHost windows, silent music
/// and sound, `--no-network`. Iterations the session schedules are queued here and
/// run by the test (`runScheduled`), not by a run loop. Its runs are not
/// `--script`ed, so a boundary reaches `showStop` (recorded) instead of `exit`;
/// but under `--exit-after-startup` a startup failure reaches `exit(1)`, which
/// here is a fatalError that ends the whole test bundle (a failing pack shows up
/// as a crash, not a test failure).
@MainActor final class SyntheticSessionHost: OriginalRuntimeSessionHost {
    let pack: SyntheticContentPack, root: URL
    let windowHost = SyntheticWindowHost()
    private(set) var backend: OriginalRuntimeWindowBackend?
    private(set) var terminated = false, didStartCalls = 0, stops: [String] = []
    private var queue: [@MainActor () -> Void] = []
    init(pack: SyntheticContentPack, root: URL) { self.pack = pack; self.root = root }
    var startupHost: OriginalRuntimeStartupHost {
        .init(windows: windowHost, textMask: { _ in .init(advance: 0, originX: 0, originY: 0, width: 0, height: 0, bits: []) },
              messageBox: { _, _ in })
    }
    func capsLock() -> Int32 { 0 }
    /// As the headless host's; the session asks only without `--no-network`, which every test passes.
    func makeSockets() -> any OriginalRuntimeSockets {
        #if os(Windows)
        return OriginalWindowsWinsock()
        #else
        return OriginalMacWinsock()
        #endif
    }
    var loadingDialogs: OriginalRuntimeLoadingDialogs { .init(chooseRecording: { _ in nil }, alert: { _ in }, open: { _ in }) }
    var game: OriginalGameIdentity { .init(name: "Synthetic pack", userDataFolder: "NTSD engine tests synthetic pack") }
    func standardOverlay() throws -> OriginalMacRuntimeOverlay { .init(root: root.appendingPathComponent("session-overlay", isDirectory: true)) }
    func beginTimingActivity() {}
    func connectedJoysticks() -> Int { 0 }
    func startJoystickSampling(_ session: OriginalRuntimeSession) {}
    func makeMusicOutput() throws -> OriginalMacMusicOutput { try .silent(directory: URL(fileURLWithPath: musicDirectory, isDirectory: true)) }
    var musicDirectory: String { root.appendingPathComponent(SyntheticContentPack.music, isDirectory: true).path }
    func contentLocation(in appBundle: Bundle) -> OriginalContentLocation {
        OriginalContentLocation(appBundle: appBundle, identity: pack.identity, fallback: { nil })
    }
    func startSoundOutput(_ effects: OriginalMacSoundEffects, muted: Bool) throws -> String { "synthetic (no output)" }
    func backingScale(_ window: UInt32, in windows: OriginalRuntimeWindowBackend) -> Double { 1 }
    func cursorPoint() -> (Int32, Int32) { (0, 0) }
    func attach(_ window: UInt32, in windows: OriginalRuntimeWindowBackend, session: OriginalRuntimeSession) throws { backend = windows }
    func snapshotPNG(_ window: UInt32, in windows: OriginalRuntimeWindowBackend) throws -> Data { try windows.presentedPNG(window) }
    func viewPNG(_ window: UInt32, in windows: OriginalRuntimeWindowBackend) throws -> Data { try snapshotPNG(window, in: windows) }
    func toggleFullScreen(_ window: UInt32, in windows: OriginalRuntimeWindowBackend) throws {
        throw OriginalRuntimeWindowBackend.Boundary.unsupported("host full screen")
    }
    func hide(_ window: UInt32, in windows: OriginalRuntimeWindowBackend) throws {}
    func askMessageBox(text: String, caption: String, buttons: [String]) -> Int { 0 }
    func open(_ url: URL) {}
    func showStop(title: String, text: String) { stops.append(title + ": " + text) }
    func didStart() { didStartCalls += 1 }
    func terminate() { terminated = true }
    func exit(_ code: Int32) -> Never { fatalError("SyntheticSessionHost: the session exited with \(code)") }
    func scheduleIteration(after milliseconds: UInt32, _ body: @escaping @MainActor () -> Void) { queue.append(body) }
    /// Runs the queued iterations in order, one per call of `count`.
    func runScheduled(_ count: Int) -> Int {
        var ran = 0
        while ran < count, !queue.isEmpty { queue.removeFirst()(); ran += 1 }
        return ran
    }
}

/// Diagnostic output of the synthetic tests (the values they pin), printed only
/// when SYNTHETIC_VERBOSE is set.
func syntheticLog(_ message: @autoclosure () -> String) {
    if ProcessInfo.processInfo.environment["SYNTHETIC_VERBOSE"] != nil { print(message()) }
}
