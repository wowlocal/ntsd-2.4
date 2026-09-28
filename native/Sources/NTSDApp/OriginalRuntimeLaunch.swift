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
/// `capture PATH`, `exit`. Counting uses committed outer iterations.
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
    private var committed = 0, stopped = false
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
    /// GetMessagePos: desktop coordinates with the main screen's top-left origin.
    static func cursorPoint() -> (Int32,Int32) {
        let p = NSEvent.mouseLocation,height = NSScreen.screens.first?.frame.maxY ?? 0
        return (Int32(p.x.rounded(.down)),Int32((height-p.y).rounded(.down)))
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            do {
                let package = try OriginalApplicationStartupInputs.bundled()
                let overlay = try OriginalMacRuntimeOverlay.standard()
                let started = try OriginalMacRuntimeStartup.run(inputs:package,overlay:overlay)
                self.started = started
                while try started.host.takeCommitted() != nil {}
                let dates = started.host.snapshot.startup?.dates?.dates.map { String(decoding:$0.dropLast(),as:UTF8.self) } ?? []
                let owners = Dictionary(grouping:started.requests,by:\.owner).mapValues(\.count)
                Self.emit(["event":"started","sequence":started.sequence,"window":started.window,"requests":started.requests.count,
                    "owners":owners,"attempts":started.attempts,"dates":dates,"overlay":overlay.root.path,
                    "musicOutput":"silent (WMA playback not implemented)"])
                if exitAfterStartup { NSApp.terminate(nil); return }
                let menu = try OriginalMacRuntimeMenu(started,inputs:package,clock:Self.milliseconds,point:Self.cursorPoint)
                self.menu = menu
                try started.windows.setInput(started.window) { [weak self] event in self?.input(event) ?? false }
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
            case .committed:
                committed += 1
                if let click = clickAt,committed == click.count {
                    menu.messages.mouse(0x200,x:click.x,y:click.y,buttons:0)
                    menu.messages.mouse(0x201,x:click.x,y:click.y,buttons:1)
                }
                try runScript(committed,menu,started)
                // Hold the button across game ticks, as a player's click does.
                if let click = clickAt,committed == click.count+15 { menu.messages.mouse(0x202,x:click.x,y:click.y,buttons:0) }
                if let capture = captureAfter,committed == capture.count {
                    try started.windows.snapshotPNG(started.window).write(to:URL(fileURLWithPath:capture.path))
                    Self.emit(["event":"captured","iterations":committed,"path":capture.path,"permits":menu.requests,
                        "getDCFailures":menu.textRequests,"emptyBlits":menu.emptyBlits])
                    if arguments.contains("--exit-after-capture") { NSApp.terminate(nil); return }
                }
                let delay = menu.messages.queue.isEmpty ? (menu.messages.sleeps.count > sleeps ? menu.messages.sleeps.last! : 1) : 0
                schedule(delay)
            case .loading:
                let begin = Date(),first = loading == nil
                if first { loading = try OriginalMacRuntimeLoading.bundled(started,startupInputs:try OriginalApplicationStartupInputs.bundled(),clock:Self.milliseconds) }
                guard let loading else { return }
                let sleeps = loading.sleeps.count
                let completed = try loading.complete(first:first); cycles += 1
                switch completed {
                case .launched: Self.emit(["event":"matchLaunched","iterations":committed,"cycles":cycles])
                case .gameplay: gameplayBodies += 1; if gameplayBodies == 1 { Self.emit(["event":"gameplay","cycles":cycles,"uptime":ProcessInfo.processInfo.systemUptime]) }
                case .menu: break
                }
                if first {
                    let c = loading.counts
                    Self.emit(["event":"loaded","seconds":Date().timeIntervalSince(begin),"allocations":c.allocations,
                        "bitmapRequests":c.bitmapRequests,"files":c.files,"audioRequests":c.audioRequests])
                }
                schedule(loading.sleeps.count > sleeps ? loading.sleeps.last! : 1)
            }
        } catch { stop(error) }
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
                    "uptime":ProcessInfo.processInfo.systemUptime,"path":words[1]])
            case "exit": NSApp.terminate(nil)
            default: Self.emit(["event":"scriptIgnored","entry":words.joined(separator:" ")])
            }
        }
    }
    @MainActor private func stop(_ error: Error) {
        stopped = true
        Self.emit(["event":"boundary","error":String(reflecting:error),"iterations":committed,
            "request":menu?.lastRequest.map { String(describing:$0).prefix(400) }.map(String.init) ?? ""])
        if exitAfterStartup || arguments.contains("--exit-after-capture") { exit(1) }
        let alert = NSAlert(); alert.messageText = "NTSD stopped at an unsupported boundary"
        alert.informativeText = String(reflecting:error); alert.runModal()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
