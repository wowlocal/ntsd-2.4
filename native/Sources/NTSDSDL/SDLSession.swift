import CSDL3
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import NTSDCore
import NTSDRuntime
#if canImport(NTSDMacPlatform)
import NTSDMacPlatform
#endif

/// Feeds the sound-effect mixer to an SDL audio stream from SDL's audio thread.
final class SDLAudioFeed: @unchecked Sendable {
    let effects: OriginalMacSoundEffects, rate: Double
    private var left: [Float] = [], right: [Float] = [], interleaved: [Float] = []
    init(effects: OriginalMacSoundEffects,rate: Double) { self.effects = effects; self.rate = rate }
    func fill(_ stream: OpaquePointer,bytes: Int) {
        let frames = bytes/8
        guard frames > 0 else { return }
        if left.count < frames { left = .init(repeating:0,count:frames); right = left; interleaved = .init(repeating:0,count:frames*2) }
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                effects.render(frames:frames,rate:rate,left:l.baseAddress!,right:r.baseAddress!)
                for i in 0..<frames { interleaved[2*i] = l[i]; interleaved[2*i+1] = r[i] }
            }
        }
        interleaved.withUnsafeBytes { _ = SDL_PutAudioStreamData(stream,$0.baseAddress,Int32(frames*8)) }
    }
}

/// The SDL session host: SDL windows, keyboard, mouse, gamepads, audio and
/// message boxes. Music plays the packaged ALAC tracks decoded without
/// AVFoundation; sockets are the shared BSD Winsock; on macOS, text uses the
/// AppKit host's CoreText masks, so frames match the AppKit app.
@MainActor final class SDLSessionHost: OriginalRuntimeSessionHost {
    let arguments: [String], windows: SDLWindowHost, musicDirectory: String
    weak var session: OriginalRuntimeSession?
    private weak var backend: OriginalRuntimeWindowBackend?
    private var gamepads: [OpaquePointer] = [], timers: [Timer] = []
    private var stream: OpaquePointer?, feed: Unmanaged<SDLAudioFeed>?
    private var muted = false, focused = true
    private var activity: NSObjectProtocol?
    var scripted: Bool { arguments.contains("--script") }
    /// Glyph masks on hosts without CoreText; reported once at launch.
    private lazy var glyphs: (mask: ([UInt8]) -> OriginalMacDisplayBackend.TextMask,font: String?) = {
        let made = SDLGlyphs.make()
        Self.report(["event":"sdlText","font":made.font ?? NSNull()])
        return made
    }()
    init(arguments: [String],windows: SDLWindowHost,musicDirectory: String) {
        self.arguments = arguments; self.windows = windows; self.musicDirectory = musicDirectory
    }
    static func report(_ value: [String:Any]) { OriginalRuntimeSession.emit(value) }
    private func box(_ flags: SDL_MessageBoxFlags,_ title: String,_ text: String) {
        if scripted { Self.report(["event":"sdlMessageBox","title":title,"text":text]); return }
        _ = SDL_ShowSimpleMessageBox(flags,title,text,nil)
    }
    var startupHost: OriginalRuntimeStartupHost {
        #if canImport(NTSDMacPlatform)
        let textMask = OriginalMacDisplayBackend.textMask
        #else
        let textMask = glyphs.mask
        #endif
        return .init(windows:windows,textMask:textMask,messageBox:{ [weak self] text,caption in
            self?.box(NTSD_SDL_MESSAGEBOX_WARNING,String(decoding:caption,as:UTF8.self),String(decoding:text,as:UTF8.self))
        })
    }
    func capsLock() -> Int32 { SDL_GetModState() & NTSD_SDL_KMOD_CAPS != 0 ? 1 : 0 }
    /// BSD sockets on Darwin and Linux (`OriginalMacWinsock`), real Winsock on Windows.
    func makeSockets() -> any OriginalRuntimeSockets {
        #if os(Windows)
        return OriginalWindowsWinsock()
        #else
        return OriginalMacWinsock()
        #endif
    }
    var loadingDialogs: OriginalRuntimeLoadingDialogs {
        .init(chooseRecording:{ _ in nil },
              alert:{ [weak self] text in self?.box(NTSD_SDL_MESSAGEBOX_ERROR,"Error",text) },
              open:{ path in _ = SDL_OpenURL(URL(fileURLWithPath:path).absoluteString) })
    }
    func standardOverlay() throws -> OriginalMacRuntimeOverlay {
        #if canImport(NTSDMacPlatform)
        return try .standard()
        #else
        guard let path = SDL_GetPrefPath("","NTSD Native") else { throw SDLWindowHost.Failure.sdl(String(cString:SDL_GetError())) }
        defer { SDL_free(path) }
        return .init(root:URL(fileURLWithPath:String(cString:path),isDirectory:true))
        #endif
    }
    func beginTimingActivity() {
        #if os(macOS)
        activity = ProcessInfo.processInfo.beginActivity(options:[.userInitiatedAllowingIdleSystemSleep,.latencyCritical],
                                                          reason:"Original game loop timing")
        #endif
    }
    /// The first two gamepads at launch; the original probes its joysticks once.
    func connectedJoysticks() -> Int {
        if gamepads.isEmpty {
            let deadline = Date().addingTimeInterval(0.5)
            repeat {
                SDL_PumpEvents()
                var count: Int32 = 0
                if let ids = SDL_GetGamepads(&count) {
                    gamepads = (0..<Int(count)).prefix(2).compactMap { SDL_OpenGamepad(ids[$0]) }
                    SDL_free(ids)
                }
                if gamepads.isEmpty { SDL_Delay(50) }
            } while gamepads.isEmpty && Date() < deadline
        }
        return gamepads.count
    }
    func startJoystickSampling(_ session: OriginalRuntimeSession) {
        let timer = Timer(timeInterval:0.025,repeats:true) { [weak self] _ in MainActor.assumeIsolated { self?.sampleGamepads() } }
        RunLoop.main.add(timer,forMode:.common); timers.append(timer)
    }
    /// joySetCapture's 25 ms period, mapped as the AppKit host maps controllers.
    private func sampleGamepads() {
        guard let session,let messages = session.messages,!session.stopped else { return }
        for (id,pad) in gamepads.enumerated() {
            func axis(_ a: SDL_GamepadAxis) -> Float { Float(SDL_GetGamepadAxis(pad,a))/32767 }
            func pressed(_ b: SDL_GamepadButton) -> Bool { SDL_GetGamepadButton(pad,b) }
            var dx = axis(SDL_GAMEPAD_AXIS_LEFTX),dy = axis(SDL_GAMEPAD_AXIS_LEFTY)
            if pressed(SDL_GAMEPAD_BUTTON_DPAD_LEFT) != pressed(SDL_GAMEPAD_BUTTON_DPAD_RIGHT) { dx = pressed(SDL_GAMEPAD_BUTTON_DPAD_LEFT) ? -1 : 1 }
            if pressed(SDL_GAMEPAD_BUTTON_DPAD_UP) != pressed(SDL_GAMEPAD_BUTTON_DPAD_DOWN) { dy = pressed(SDL_GAMEPAD_BUTTON_DPAD_UP) ? -1 : 1 }
            func word(_ v: Float) -> UInt32 { UInt32(((max(-1,min(1,v))+1)/2*65535).rounded()) }
            let buttons = [SDL_GAMEPAD_BUTTON_SOUTH,SDL_GAMEPAD_BUTTON_EAST,SDL_GAMEPAD_BUTTON_WEST,SDL_GAMEPAD_BUTTON_NORTH]
                .enumerated().reduce(UInt32(0)) { $0 | (pressed($1.element) ? 1 << UInt32($1.offset) : 0) }
            messages.joystick(UInt32(id),x:word(dx),y:word(dy),buttons:buttons)
        }
    }
    /// The packaged tracks, decoded and played through SDL (`SDLMusicPlayer`).
    func makeMusicOutput() throws -> OriginalMacMusicOutput {
        let directory = URL(fileURLWithPath:musicDirectory,isDirectory:true)
        guard let manifest = try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("manifest.json"))) as? [String:Any],
              let entries = manifest["entries"] as? [[String:Any]] else { throw OriginalMacMusicOutput.Boundary.manifest }
        var tracks: [String:URL] = [:]
        for entry in entries {
            guard let name = entry["name"] as? String,let resource = entry["resource"] as? String else { throw OriginalMacMusicOutput.Boundary.manifest }
            let url = directory.appendingPathComponent(resource)
            guard FileManager.default.fileExists(atPath:url.path) else { throw OriginalMacMusicOutput.Boundary.missingTrack(resource) }
            tracks[name.lowercased()] = url
        }
        return .init(tracks:tracks) { url,ended in try SDLMusicPlayer(url,ended:ended) }
    }
    func startSoundOutput(_ effects: OriginalMacSoundEffects,muted: Bool) throws -> String {
        var spec = SDL_AudioSpec(),frames: Int32 = 0
        let rate = SDL_GetAudioDeviceFormat(NTSD_SDL_DEFAULT_PLAYBACK,&spec,&frames) && spec.freq > 0 ? spec.freq : 48000
        var wanted = SDL_AudioSpec(format:NTSD_SDL_AUDIO_F32,channels:2,freq:rate)
        let feed = Unmanaged.passRetained(SDLAudioFeed(effects:effects,rate:Double(rate)))
        guard let stream = SDL_OpenAudioDeviceStream(NTSD_SDL_DEFAULT_PLAYBACK,&wanted,{ userdata,stream,additional,_ in
            guard let userdata,let stream,additional > 0 else { return }
            Unmanaged<SDLAudioFeed>.fromOpaque(userdata).takeUnretainedValue().fill(stream,bytes:Int(additional))
        },feed.toOpaque()) else { feed.release(); throw SDLWindowHost.Failure.sdl(String(cString:SDL_GetError())) }
        self.stream = stream; self.feed = feed; self.muted = muted; applyGain()
        _ = SDL_ResumeAudioStreamDevice(stream)
        return muted ? "muted" : "SDL default output \(rate) Hz"
    }
    /// DirectSound silences the game's buffers while its window is not foreground.
    private func applyGain() { if let stream { _ = SDL_SetAudioStreamGain(stream,muted || !focused ? 0 : 1) } }
    func backingScale(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) -> Double {
        guard let w = try? windows.lease(window).window as? SDLWindow else { return 0 }
        return Double(SDL_GetWindowDisplayScale(w.window))
    }
    func cursorPoint() -> (Int32,Int32) {
        var x: Float = 0,y: Float = 0; _ = SDL_GetGlobalMouseState(&x,&y)
        return (Int32(x.rounded(.down)),Int32(y.rounded(.down)))
    }
    func attach(_ window: UInt32,in windows: OriginalRuntimeWindowBackend,session: OriginalRuntimeSession) throws {
        backend = windows; self.session = session
        if timers.count < 2 {
            let pump = Timer(timeInterval:0.002,repeats:true) { [weak self] _ in MainActor.assumeIsolated { self?.pump() } }
            RunLoop.main.add(pump,forMode:.common); timers.append(pump)
        }
    }
    private func gameWindow() -> SDLWindow? {
        guard let session,let backend else { return nil }
        return try? backend.lease(session.gameWindow).window as? SDLWindow
    }
    private func pump() {
        var event = SDL_Event()
        while SDL_PollEvent(&event) { handle(event) }
    }
    private var mouseButtons: UInt32 {
        let mask = SDL_GetMouseState(nil,nil)
        return (mask & NTSD_SDL_BUTTON_LMASK != 0 ? 1 : 0) | (mask & NTSD_SDL_BUTTON_RMASK != 0 ? 2 : 0)
    }
    private func handle(_ event: SDL_Event) {
        let type = SDL_EventType(rawValue:.init(truncatingIfNeeded:event.type))
        if type == SDL_EVENT_QUIT { if session?.closeRequested() ?? true { terminate() }; return }
        guard let session,let game = gameWindow() else { return }
        switch type {
        case SDL_EVENT_WINDOW_FOCUS_GAINED where event.window.windowID == game.id: focused = true; applyGain(); return
        case SDL_EVENT_WINDOW_FOCUS_LOST where event.window.windowID == game.id: focused = false; applyGain(); return
        case SDL_EVENT_WINDOW_CLOSE_REQUESTED where event.window.windowID == game.id:
            if session.closeRequested() { terminate() }
            return
        default: break
        }
        guard let messages = session.messages,!session.stopped else { return }
        // Scripted runs take keyboard and mouse input from their script only.
        if session.scripted { return }
        switch type {
        case SDL_EVENT_KEY_DOWN,SDL_EVENT_KEY_UP:
            guard event.key.windowID == game.id,let key = SDLKeys.key(event.key.scancode) else { return }
            #if os(macOS)
            // Cocoa reports Caps Lock once per toggle; each is a whole press, as on the AppKit host.
            if key.vk == 0x14 { messages.key(key,down:true); messages.key(key,down:false); return }
            #endif
            let down = type == SDL_EVENT_KEY_DOWN
            messages.key(key,down:down,repeated:event.key.repeat,characters:down ? SDLKeys.characters(event.key.scancode,event.key.mod) : nil)
        case SDL_EVENT_MOUSE_MOTION,SDL_EVENT_MOUSE_BUTTON_DOWN,SDL_EVENT_MOUSE_BUTTON_UP:
            let isMotion = type == SDL_EVENT_MOUSE_MOTION
            guard (isMotion ? event.motion.windowID : event.button.windowID) == game.id else { return }
            let frame = game.textureSize == .zero ? game.client : game.textureSize
            let (x,y) = isMotion ? windows.clientPoint(game,x:event.motion.x,y:event.motion.y,frame:frame)
                                 : windows.clientPoint(game,x:event.button.x,y:event.button.y,frame:frame)
            var message: UInt32 = 0x200
            if !isMotion {
                let left = Int32(event.button.button) == SDL_BUTTON_LEFT,right = Int32(event.button.button) == SDL_BUTTON_RIGHT
                guard left || right else { return }
                message = type == SDL_EVENT_MOUSE_BUTTON_DOWN ? (left ? 0x201 : 0x204) : (left ? 0x202 : 0x205)
            }
            messages.mouse(message,x:x,y:y,buttons:mouseButtons)
        default: break
        }
    }
    func snapshotPNG(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws -> Data { try windows.presentedPNG(window) }
    /// Declared: the presented framebuffer, not a read-back of the scaled view.
    func viewPNG(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws -> Data { try windows.presentedPNG(window) }
    func toggleFullScreen(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws {
        throw OriginalRuntimeWindowBackend.Boundary.unsupported("SDL host full screen")
    }
    func hide(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws {
        if let w = try windows.lease(window).window as? SDLWindow { _ = SDL_HideWindow(w.window); w.visible = false }
    }
    func askMessageBox(text: String,caption: String,buttons: [String]) -> Int {
        let titles = buttons.map { strdup($0) }
        defer { titles.forEach { free($0) } }
        var data = titles.enumerated().map { SDL_MessageBoxButtonData(flags:$0.offset == 0 ? NTSD_SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT : 0,
                                                                      buttonID:Int32($0.offset),text:UnsafePointer($0.element)) }
        var chosen: Int32 = 0
        let shown = caption.withCString { c in text.withCString { t in
            data.withUnsafeMutableBufferPointer { b in
                var box = SDL_MessageBoxData(flags:NTSD_SDL_MESSAGEBOX_WARNING,window:gameWindow()?.window,title:c,message:t,
                                             numbuttons:Int32(b.count),buttons:b.baseAddress,colorScheme:nil)
                return SDL_ShowMessageBox(&box,&chosen)
            }
        } }
        return shown && chosen >= 0 ? Int(chosen) : 0
    }
    func open(_ url: URL) { _ = SDL_OpenURL(url.absoluteString) }
    func showStop(title: String,text: String) { box(NTSD_SDL_MESSAGEBOX_ERROR,title,text) }
    func didStart() {
        if !arguments.contains("--no-activate"),let game = gameWindow() { _ = SDL_RaiseWindow(game.window) }
    }
    func terminate() { SDL_Quit(); Foundation.exit(0) }
    func exit(_ code: Int32) -> Never { SDL_Quit(); Foundation.exit(code) }
}
