import AppKit
import NTSDCore
import NTSDMacPlatform

/// `--original`: run the recovered WinMain on the real Mac services and runtime
/// providers, then the front menu with live keyboard/mouse and clock input until
/// the first loading request or an unsupported boundary, which is reported.
/// Options: `--exit-after-startup`, `--capture-after N PATH` (window PNG after N
/// committed menu iterations), `--exit-after-capture`, `--click-at N X Y`
/// (scripted left click at client point X,Y after N committed iterations).
/// `--script "N action args; ..."` runs scripted input at committed iteration N:
/// `click X Y` (button held 10 iterations), `key VK` (held 10 iterations),
/// `capture PATH`, `musicend` (the current track ends now), `answer yes|no|ok`
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
/// Application Support, for automated runs.
/// START runs the whole loading once (blocking, progress frames not shown);
/// later screens return through cached loaded cycles.
final class OriginalRuntimeDelegate: NSObject, NSApplicationDelegate {
    let exitAfterStartup: Bool
    private var started: OriginalMacRuntimeStartup.Started?
    private var menu: OriginalMacRuntimeMenu?
    private var loading: OriginalMacRuntimeLoading?
    private var captureAfter: (count: Int,path: String)?
    private var clickAt: (count: Int,x: Int32,y: Int32)?
    private var cycles = 0, gameplayBodies = 0
    private var script: [Int:[[String]]] = [:]
    private var pressedModifiers: Set<UInt16> = []
    private var committed = 0, steps = 0, stopped = false, gameplayClock: (steps: Int,committed: Int)?,
        busy = 0.0, waited = 0
    /// Windows does not throttle a background game's Sleep loop; App Nap would
    /// stretch every scheduled iteration once the window is not frontmost.
    private var activity: NSObjectProtocol?
    private var music: OriginalMacMusicOutput?
    /// DirectSound buffer voices (APPLICATION_SOUND_EFFECTS_PLAN.md) and their
    /// output; a missing output device leaves the voices running silently.
    private var sounds: OriginalMacSoundEffects?
    private var soundOutput: OriginalMacSoundOutput?, soundOutputError: String?
    init(exitAfterStartup: Bool) {
        self.exitAfterStartup = exitAfterStartup
        if let i = arguments.firstIndex(of:"--capture-after"),i+2 < arguments.count,let n = Int(arguments[i+1]) {
            captureAfter = (n,arguments[i+2])
        }
        if let i = arguments.firstIndex(of:"--script"),i+1 < arguments.count {
            for entry in arguments[i+1].split(separator:";") {
                let words = entry.split(separator:" ").map(String.init)
                if let n = words.first.flatMap({ Int($0) }),words.count > 1 { script[n,default:[]].append(Array(words.dropFirst())) }
            }
        }
        if let i = arguments.firstIndex(of:"--click-at"),i+3 < arguments.count,let n = Int(arguments[i+1]),
           let x = Int32(arguments[i+2]),let y = Int32(arguments[i+3]) { clickAt = (n,x,y) }
    }
    static func emit(_ value: [String:Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]) else { return }
        print(String(decoding:data,as:UTF8.self)); fflush(stdout)
    }
    static func milliseconds() throws -> UInt32 { try OriginalMacStartupClock.milliseconds(OriginalMacStartupClock.monotonicSample()) }
    private lazy var virtualClock: (base: UInt32,step: UInt32)? = {
        guard let i = arguments.firstIndex(of:"--virtual-clock"),i+2 < arguments.count,
              let base = UInt32(arguments[i+1]),let step = UInt32(arguments[i+2]) else { return nil }
        return (base,step)
    }()
    static let virtualDate = Date(timeIntervalSince1970:1_767_225_600)
    private func clock() throws -> UInt32 {
        guard let v = virtualClock else { return try Self.milliseconds() }
        return v.base &+ v.step &* UInt32(truncatingIfNeeded:steps)
    }
    private func startupEnvironment() -> OriginalMacRuntimeStartupService.Environment {
        guard let v = virtualClock else { return .init() }
        let fixed = OriginalMacStartupClock.Sample(seconds:Int64(Self.virtualDate.timeIntervalSince1970),nanoseconds:0)
        return .init(monotonic:{ .init(seconds:Int64(v.base/1000),nanoseconds:Int64(v.base%1000)*1_000_000) },realtime:{ fixed })
    }
    private func cursor() -> (Int32,Int32) { virtualClock == nil ? Self.cursorPoint() : (0,0) }
    /// GetMessagePos: desktop coordinates with the main screen's top-left origin.
    static func cursorPoint() -> (Int32,Int32) {
        let p = NSEvent.mouseLocation,height = NSScreen.screens.first?.frame.maxY ?? 0
        return (Int32(p.x.rounded(.down)),Int32((height-p.y).rounded(.down)))
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            do {
                activity = ProcessInfo.processInfo.beginActivity(options:[.userInitiated,.latencyCritical],
                                                                  reason:"Original game loop timing")
                let package = try OriginalApplicationStartupInputs.bundled()
                let overlay = try overlayRoot()
                let started = try OriginalMacRuntimeStartup.run(inputs:package,overlay:overlay,environment:startupEnvironment())
                self.started = started
                while try started.host.takeCommitted() != nil {}
                let music = try OriginalMacMusicOutput.bundled()
                music.muted = arguments.contains("--mute-music"); self.music = music
                try music.present(started.runtime.music.presented())
                let sounds = OriginalMacSoundEffects.backed(by:started.audio); self.sounds = sounds
                do {
                    let output = try OriginalMacSoundOutput(effects:sounds)
                    output.muted = arguments.contains("--mute-sounds"); output.focused = NSApp.isActive; soundOutput = output
                    // DirectSound focus (see OriginalMacSoundOutput): the app's
                    // single window is foreground exactly while the app is active.
                    for (name,active) in [(NSApplication.didBecomeActiveNotification,true),(NSApplication.didResignActiveNotification,false)] {
                        NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                            MainActor.assumeIsolated { self?.soundOutput?.focused = active }
                        }
                    }
                } catch { soundOutputError = String(reflecting:error) }
                let dates = started.host.snapshot.startup?.dates?.dates.map { String(decoding:$0.dropLast(),as:UTF8.self) } ?? []
                let owners = Dictionary(grouping:started.requests,by:\.owner).mapValues(\.count)
                Self.emit(["event":"started","sequence":started.sequence,"window":started.window,"requests":started.requests.count,
                    "owners":owners,"attempts":started.attempts,"dates":dates,"overlay":overlay.root.path,
                    "musicOutput":"packaged ALAC tracks; graph-event looping",
                    "soundOutput":soundOutputError ?? (soundOutput?.muted == true ? "muted" : "default output"),
                    "backingScale":(try? started.windows.observation(started.window).backingScale) ?? 0,
                    "resources":[(try? OriginalApplicationCatalogInputs.bundledDirectory().path) ?? "",OriginalMacMusicOutput.directory()?.path ?? ""]])
                if exitAfterStartup { NSApp.terminate(nil); return }
                let menu = try OriginalMacRuntimeMenu(started,inputs:package,clock:{ [unowned self] in try self.clock() },
                                                      point:{ [unowned self] in self.cursor() })
                self.menu = menu; menu.sounds = sounds
                menu.messages.messageBox = { [unowned self] text,caption,type in try self.messageBox(text,caption,type) }
                menu.messages.destroyedWindow = { [unowned self] in
                    Self.emit(["event":"windowDestroyed","iterations":self.committed])
                    try? started.windows.hide(started.window)
                }
                try started.windows.setInput(started.window) { [weak self] event in self?.input(event) ?? false }
                // The close button is the game's WM_SYSCOMMAND(SC_CLOSE); after a
                // boundary stop it closes the app directly.
                try started.windows.setCloseRequest(started.window) { [weak self] in
                    guard let self,!self.stopped else { return true }
                    self.menu?.messages.close(); return false
                }
                NSApp.activate(ignoringOtherApps:true)
                schedule(0)
            } catch { stop(error) }
        }
    }
    @MainActor private func input(_ event: NSEvent) -> Bool {
        guard let menu,let started,!stopped else { return false }
        let messages = menu.messages
        switch event.type {
        case .keyDown,.keyUp:
            guard let key = OriginalMacRuntimeKey.table[event.keyCode] else { return true }
            messages.key(key,down:event.type == .keyDown,repeated:event.isARepeat,characters:event.characters)
        case .flagsChanged:
            guard let key = OriginalMacRuntimeKey.table[event.keyCode] else { return true }
            let down = !pressedModifiers.contains(event.keyCode)
            if down { pressedModifiers.insert(event.keyCode) } else { pressedModifiers.remove(event.keyCode) }
            messages.key(key,down:down)
        case .mouseMoved,.leftMouseDragged,.rightMouseDragged,.leftMouseDown,.leftMouseUp,.rightMouseDown,.rightMouseUp:
            guard let (x,y) = try? started.windows.clientPoint(started.window,event) else { return true }
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
    @MainActor private func schedule(_ milliseconds: UInt32) {
        DispatchQueue.main.asyncAfter(deadline:.now() + .milliseconds(Int(milliseconds))) { [weak self] in
            MainActor.assumeIsolated { self?.iterate() }
        }
    }
    @MainActor private func iterate() {
        guard let menu,let started,!stopped else { return }
        let sleeps = menu.messages.sleeps.count
        do {
            switch try menu.step() {
            case .committed(_,let result):
                if case .quit(let code) = result {
                    // The loop returned WM_QUIT's wParam: WinMain ends.
                    Self.emit(["event":"quit","code":code,"iterations":committed,"uptime":ProcessInfo.processInfo.systemUptime])
                    stopped = true; exit(Int32(bitPattern:code))
                }
                committed += 1
                if let click = clickAt,committed == click.count {
                    menu.messages.mouse(0x200,x:click.x,y:click.y,buttons:0)
                    menu.messages.mouse(0x201,x:click.x,y:click.y,buttons:1)
                }
                // Default clock: committed message-loop iterations. `--script-clock all`
                // counts every iteration, so input keeps flowing during gameplay ticks.
                steps += 1
                if let n = scriptStep(committedBranch:true) { try runScript(n,menu,started) }
                // Hold the button across game ticks, as a player's click does.
                if let click = clickAt,committed == click.count+15 { menu.messages.mouse(0x202,x:click.x,y:click.y,buttons:0) }
                if let capture = captureAfter,committed == capture.count {
                    try started.windows.snapshotPNG(started.window).write(to:URL(fileURLWithPath:capture.path))
                    Self.emit(["event":"captured","iterations":committed,"path":capture.path,"permits":menu.requests,
                        "getDCFailures":menu.textRequests,"emptyBlits":menu.emptyBlits])
                    if arguments.contains("--exit-after-capture") { NSApp.terminate(nil); return }
                }
                try presentMusic(started,menu)
                let delay = menu.messages.queue.isEmpty ? (menu.messages.sleeps.count > sleeps ? menu.messages.sleeps.last! : 1) : 0
                schedule(delay)
            case .loading:
                let begin = Date(),first = loading == nil
                steps += 1
                if let n = scriptStep(committedBranch:false) { try runScript(n,menu,started) }
                if first {
                    loading = try OriginalMacRuntimeLoading.bundled(started,startupInputs:try OriginalApplicationStartupInputs.bundled(),
                                                                    clock:{ [unowned self] in try self.clock() })
                    loading?.overlay = try overlayRoot()
                    loading?.stageCheckpoints = arguments.contains("--stage-checkpoints")
                    loading?.sounds = sounds
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
                    if gameplayBodies % 300 == 0 {
                        var event: [String:Any] = ["event":"progress","gameplayBodies":gameplayBodies,"cycles":cycles,"iterations":committed,
                            "characterAI":loading.counts.characterAI,"objectInputs":loading.counts.objectInputs,"uptime":ProcessInfo.processInfo.systemUptime,
                            "busySeconds":busy,"waitedMilliseconds":waited,"lastSleeps":Array(loading.sleeps.suffix(6)),"music":musicReport(),
                            "sounds":soundReport()]
                        if let i = arguments.firstIndex(of:"--body-captures"),i+1 < arguments.count {
                            let path = "\(arguments[i+1])/b\(String(format:"%06d",gameplayBodies)).png"
                            try started.windows.snapshotPNG(started.window).write(to:URL(fileURLWithPath:path)); event["path"] = path
                        }
                        Self.emit(event)
                    }
                    if let i = arguments.firstIndex(of:"--exit-after-bodies"),i+1 < arguments.count,let n = Int(arguments[i+1]),gameplayBodies >= n {
                        NSApp.terminate(nil); return
                    }
                case .menu:
                    // The first loaded menu step after a match (epilogue, selection).
                    if inMatch {
                        inMatch = false
                        let c = loading.counts
                        Self.emit(["event":"menu","cycles":cycles,"iterations":committed,"gameplayBodies":gameplayBodies,
                            "epilogues":c.epilogues,"replayFiles":loading.savedReplays.map { "\($0.path) \($0.bytes.count)" },
                            "refusedReplays":loading.refusedReplayOpens,"uptime":ProcessInfo.processInfo.systemUptime])
                    }
                }
                if loading.playbackDialogs.count > reportedDialogs {
                    for answer in loading.playbackDialogs[reportedDialogs...] { Self.emit(["event":"playbackDialog","file":answer ?? "","iterations":committed]) }
                    reportedDialogs = loading.playbackDialogs.count
                }
                if loading.playbackAlerts.count > reportedAlerts {
                    for text in loading.playbackAlerts[reportedAlerts...] { Self.emit(["event":"playbackAlert","text":text,"iterations":committed]) }
                    reportedAlerts = loading.playbackAlerts.count
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
                let delay = loading.sleeps.count > sleeps ? loading.sleeps.last! : 1
                waited += Int(delay); schedule(delay)
            }
        } catch { stop(error) }
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
    @MainActor private func runScript(_ n: Int,_ menu: OriginalMacRuntimeMenu,_ started: OriginalMacRuntimeStartup.Started) throws {
        for words in script[n] ?? [] {
            switch words[0] {
            case "click" where words.count == 3:
                guard let x = Int32(words[1]),let y = Int32(words[2]) else { continue }
                menu.messages.mouse(0x200,x:x,y:y,buttons:0); menu.messages.mouse(0x201,x:x,y:y,buttons:1)
                script[n+10,default:[]].append(["release",words[1],words[2]])
            case "release" where words.count == 3:
                guard let x = Int32(words[1]),let y = Int32(words[2]) else { continue }
                menu.messages.mouse(0x202,x:x,y:y,buttons:0)
            case "key" where words.count == 2,"keyup" where words.count == 2:
                guard let vk = UInt32(words[1]),let key = OriginalMacRuntimeKey.table.values.first(where: { $0.vk == vk }) else { continue }
                if words[0] == "key" { menu.messages.key(key,down:true); script[n+10,default:[]].append(["keyup",words[1]]) }
                else { menu.messages.key(key,down:false) }
            case "hold" where words.count == 3:
                guard let vk = UInt32(words[1]),let n2 = Int(words[2]),let key = OriginalMacRuntimeKey.table.values.first(where: { $0.vk == vk }) else { continue }
                menu.messages.key(key,down:true); script[n+n2,default:[]].append(["keyup",words[1]])
            case "capture" where words.count == 2:
                try started.windows.snapshotPNG(started.window).write(to:URL(fileURLWithPath:words[1]))
                Self.emit(["event":"captured","iterations":n,"cycles":cycles,"gameplayBodies":gameplayBodies,
                    "lastSleeps":Array(loading?.sleeps.suffix(8) ?? []),"menuSleeps":Array(menu.messages.sleeps.suffix(8)),"objectInputs":loading?.counts.objectInputs ?? 0,"characterAI":loading?.counts.characterAI ?? 0,
            "replayFiles":loading?.savedReplays.map { "\($0.path) \($0.bytes.count)" } ?? [],"refusedReplays":loading?.refusedReplayOpens ?? [],
                    "uptime":ProcessInfo.processInfo.systemUptime,"path":words[1],"music":musicReport(),"sounds":soundReport()])
            case "musicend": music?.finishTrack()
            case "answer" where words.count == 2 && ["yes","no","ok"].contains(words[1]): messageAnswers.append(words[1])
            case "close": menu.messages.close()
            case "exit": NSApp.terminate(nil)
            default: Self.emit(["event":"scriptIgnored","entry":words.joined(separator:" ")])
            }
        }
    }
    private var musicEnds = 0, musicNotifications = 0, inMatch = false, reportedAlerts = 0, reportedDialogs = 0
    /// Committed graph state to the output; a finished track queues EC_COMPLETE
    /// and posts the registered notification for the next iteration's WndProc.
    @MainActor private func presentMusic(_ started: OriginalMacRuntimeStartup.Started,_ menu: OriginalMacRuntimeMenu) throws {
        guard let music else { return }
        try music.present(started.runtime.music.presented())
        guard let graph = music.takeEnded() else { return }
        musicEnds += 1
        guard let n = started.runtime.music.complete(graph) else { return }
        guard n.window == menu.messages.window else { throw OriginalMacRuntimeMessages.Boundary.arguments("graph notify window") }
        menu.messages.post(n.message,0,n.lParam); musicNotifications += 1
    }
    private func overlayRoot() throws -> OriginalMacRuntimeOverlay {
        guard let i = arguments.firstIndex(of:"--overlay"),i+1 < arguments.count else { return try .standard() }
        return .init(root:URL(fileURLWithPath:arguments[i+1],isDirectory:true))
    }
    /// Scripted MessageBoxA buttons, in order (`answer` script action).
    private var messageAnswers: [String] = []
    /// MessageBoxA: MB_OK → IDOK, MB_YESNO → IDYES/IDNO (declared Windows
    /// return values). Interactive runs show an alert with those buttons.
    @MainActor private func messageBox(_ text: [UInt8],_ caption: [UInt8],_ type: UInt32) throws -> Int32 {
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
            let alert = NSAlert(); alert.messageText = String(decoding:caption,as:UTF8.self)
            alert.informativeText = String(decoding:text,as:UTF8.self)
            for (title,_) in buttons { alert.addButton(withTitle:title.capitalized == "Ok" ? "OK" : title.capitalized) }
            let index = alert.runModal().rawValue-NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            answer = buttons[max(0,min(buttons.count-1,index))].1
        }
        Self.emit(["event":"messageBox","text":String(decoding:text,as:UTF8.self),"caption":String(decoding:caption,as:UTF8.self),
                   "type":type,"answer":answer,"iterations":committed])
        return answer
    }
    @MainActor private func soundReport() -> [String:Any] {
        let r = sounds?.rendered ?? .init(),a = sounds?.activity ?? (playing:0,looping:0)
        return ["performed":sounds?.performed ?? 0,"rejected":sounds?.rejected ?? 0,"playing":a.playing,"looping":a.looping,
                "renderedFrames":r.frames,"audibleFrames":r.audible,"peak":(Double(r.peak)*1000).rounded()/1000]
    }
    @MainActor private func musicReport() -> [String:Any] {
        guard let s = music?.state else { return [:] }
        return ["graph":s.graph,"track":s.track ?? "","playing":s.playing,"ended":s.ended,"gain":s.gain,
                "volume":started?.runtime.music.presented()?.volume ?? 0,"ends":musicEnds,"notifications":musicNotifications,
                "graphRequests":started?.runtime.music.graphOperations.count ?? 0,
                "time":(s.time*1000).rounded()/1000,"unresolved":music?.unresolved.map { String(decoding:$0,as:UTF8.self) } ?? []]
    }
    @MainActor private func stop(_ error: Error) {
        stopped = true
        Self.emit(["event":"boundary","error":String(reflecting:error),"iterations":committed,
            "objectInputs":loading?.counts.objectInputs ?? 0,"characterAI":loading?.counts.characterAI ?? 0,
            "replayFiles":loading?.savedReplays.map { "\($0.path) \($0.bytes.count)" } ?? [],"refusedReplays":loading?.refusedReplayOpens ?? [],
            "request":menu?.lastRequest.map { String(describing:$0).prefix(400) }.map(String.init) ?? ""])
        // Scripted runs report the boundary and end; only interactive runs show it.
        if exitAfterStartup || arguments.contains("--exit-after-capture") || arguments.contains("--script") { exit(1) }
        let alert = NSAlert(); alert.messageText = "NTSD stopped at an unsupported boundary"
        alert.informativeText = String(reflecting:error); alert.runModal()
    }
    /// The game ends at its own WM_QUIT (after DestroyWindow hid the window);
    /// only a run stopped at a boundary ends with its window.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        MainActor.assumeIsolated { stopped }
    }
}
