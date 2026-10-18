import Foundation
import NTSDCore
import NTSDContent
import NTSDRuntime

/// The browser session host (TVOS_WEB W2b): the original game in a page, run
/// by a worker that hands each presented crop to the page's canvas. Input
/// (W2b-2): keyboard, mouse and gamepads come from the page, drained every
/// 2 ms as the SDL host pumps its events, gamepads sampled at joySetCapture's
/// 25 ms; message boxes and alerts are asked on the page. Scripted runs take
/// input from their script only and answer as the headless host. Sound
/// (W2b-3): the effects mixer and the packaged tracks rendered into the
/// page's ring (`WebAudioMixer`). Still to come: a glyph rasteriser (the
/// `none` text group); no sockets (WASI has none); the overlay in /save when
/// the page mounts one.
@MainActor final class WebSessionHost: OriginalRuntimeSessionHost {
    let arguments: [String], windows: WebWindowHost, musicDirectory: String
    func contentLocation(in appBundle: Bundle) -> OriginalContentLocation { NTSDContent.location(in:appBundle) }
    weak var session: OriginalRuntimeSession?
    var scripted: Bool { arguments.contains("--script") }
    private var caps = false, cursor: (Int32,Int32) = (0,0), pumping = false, gamepadCount = -1
    /// The page's sound output; none in a scripted run or without an AudioContext.
    private lazy var mixer: WebAudioMixer? = scripted ? nil : WebAudioMixer()
    init(arguments: [String],screen: CGSize,caption: CGFloat,musicDirectory: String) {
        self.arguments = arguments; windows = WebWindowHost(screen:screen,caption:caption); self.musicDirectory = musicDirectory
    }
    static func report(_ value: [String:Any]) { OriginalRuntimeSession.emit(value) }
    var startupHost: OriginalRuntimeStartupHost {
        .init(windows:windows,textMask:WebGlyphs.mask,
              messageBox:{ [weak self] text,caption in
                  let text = String(decoding:text,as:UTF8.self),caption = String(decoding:caption,as:UTF8.self)
                  Self.report(["event":"webMessageBox","text":text,"caption":caption])
                  if self?.scripted == false { _ = WebInput.ask(text:text,caption:caption,buttons:["OK"]) }
              })
    }
    func capsLock() -> Int32 { caps ? 1 : 0 }
    func makeSockets() -> any OriginalRuntimeSockets { OriginalUnavailableSockets() }
    var loadingDialogs: OriginalRuntimeLoadingDialogs {
        .init(chooseRecording:{ _ in nil },
              alert:{ [weak self] text in
                  Self.report(["event":"webAlert","text":text])
                  if self?.scripted == false { _ = WebInput.ask(text:text,caption:"Error",buttons:["OK"]) }
              },
              open:{ path in Self.report(["event":"webOpen","path":path]) })
    }
    /// The page's persistent folder when it mounts one at /save, else a
    /// temporary one.
    func standardOverlay() throws -> OriginalMacRuntimeOverlay {
        if FileManager.default.fileExists(atPath:"/save") { return .init(root:URL(fileURLWithPath:"/save/NTSD Native",isDirectory:true)) }
        return .init(root:FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-web-"+UUID().uuidString,isDirectory:true))
    }
    func beginTimingActivity() {}
    /// The gamepads the page sees at launch (the first two); the original
    /// probes its joysticks once.
    func connectedJoysticks() -> Int {
        if gamepadCount < 0 { gamepadCount = scripted ? 0 : max(0,min(2,Int(ntsdGamepads()))) }
        return gamepadCount
    }
    func startJoystickSampling(_ session: OriginalRuntimeSession) { every(25) { [weak self] in self?.sampleGamepads() } }
    /// joySetCapture's 25 ms period, mapped as the SDL host maps controllers
    /// (the page puts the d-pad over the left stick).
    private func sampleGamepads() {
        guard let session,let messages = session.messages,!session.stopped else { return }
        func word(_ v: Int32) -> UInt32 { UInt32(((max(-1,min(1,Float(v)/32767))+1)/2*65535).rounded()) }
        for id in 0..<max(0,gamepadCount) {
            // A pad that went away reads centred with no buttons, as the SDL host's does.
            let pad = WebInput.gamepad(id)
            messages.joystick(UInt32(id),x:word(pad.connected ? pad.x : 0),y:word(pad.connected ? pad.y : 0),buttons:pad.connected ? pad.buttons & 15 : 0)
        }
    }
    /// A recurring call on the main queue: the WASI loop has no run-loop
    /// timers. It ends with the session, so the loop (and the worker) can end.
    private func every(_ milliseconds: Int,_ body: @escaping @MainActor () -> Void) {
        OriginalMainQueue.after(milliseconds:milliseconds) { [weak self] in
            guard let self,self.session?.stopped != true else { return }
            body(); self.every(milliseconds,body)
        }
    }
    /// The page's keyboard and mouse events since the last pump.
    private func pump() {
        guard let session else { return }
        for event in WebInput.drain() {
            switch event.kind {
            case 1:
                caps = event.d != 0
                guard let messages = session.messages,!session.stopped,!session.scripted,
                      let key = OriginalHIDKeys.key(usage:UInt32(bitPattern:event.a)) else { continue }
                let down = event.b & 1 != 0
                let characters = down && event.c > 0 ? Unicode.Scalar(UInt32(event.c)).map { String(Character($0)) } : nil
                messages.key(key,down:down,repeated:event.b & 2 != 0,characters:characters)
            case 3: caps = event.a != 0   // a modifier-state report (pointer events carry it too)
            case 4: mixer?.focused = event.a != 0
            case 2:
                if let origin = WebWindowHost.presentedOrigin { cursor = (Int32(origin.x)+event.b,Int32(origin.y)+event.c) }
                guard let messages = session.messages,!session.stopped,!session.scripted else { continue }
                messages.mouse(UInt32(bitPattern:event.a),x:event.b,y:event.c,buttons:UInt32(bitPattern:event.d))
            default: break
            }
        }
    }
    /// The packaged tracks, decoded in the worker and mixed into the page's
    /// sound ring; scripted runs and pages without sound use the silent
    /// manifest players (the headless host's). Each track's frame count from
    /// the manifest lets a player keep time before its file has arrived (W5).
    func makeMusicOutput() throws -> OriginalMacMusicOutput {
        let directory = URL(fileURLWithPath:musicDirectory,isDirectory:true)
        guard let mixer else { return try .silent(directory:directory) }
        guard let manifest = try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("manifest.json"))) as? [String:Any],
              let entries = manifest["entries"] as? [[String:Any]] else { throw OriginalMacMusicOutput.Boundary.manifest }
        var tracks: [String:URL] = [:],frames: [URL:Int] = [:]
        for entry in entries {
            guard let name = entry["name"] as? String,let resource = entry["resource"] as? String else { throw OriginalMacMusicOutput.Boundary.manifest }
            let url = directory.appendingPathComponent(resource)
            guard FileManager.default.fileExists(atPath:url.path) else { throw OriginalMacMusicOutput.Boundary.missingTrack(resource) }
            tracks[name.lowercased()] = url
            frames[url] = (entry["frames"] as? NSNumber)?.intValue
        }
        return .init(tracks:tracks) { url,ended in try WebMusicPlayer(url,frames:frames[url],mixer:mixer,ended:ended) }
    }
    func startSoundOutput(_ effects: OriginalMacSoundEffects,muted: Bool) throws -> String {
        guard let mixer else { return scripted ? "web (no output: scripted)" : "web (no output: the page has no audio)" }
        mixer.effects = effects; mixer.effectsMuted = muted
        every(10) { [weak self] in self?.mixer?.fill() }
        return muted ? "muted" : "web audio \(Int(mixer.rate)) Hz"
    }
    func backingScale(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) -> Double { 1 }
    /// The last mouse position on the page, in desktop coordinates.
    func cursorPoint() -> (Int32,Int32) { cursor }
    func attach(_ window: UInt32,in windows: OriginalRuntimeWindowBackend,session: OriginalRuntimeSession) throws {
        guard !pumping,!scripted else { return }
        pumping = true; every(2) { [weak self] in self?.pump() }
    }
    func snapshotPNG(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws -> Data { try backend.presentedPNG(window) }
    func viewPNG(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws -> Data { try snapshotPNG(window,in:backend) }
    func toggleFullScreen(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws {
        throw OriginalRuntimeWindowBackend.Boundary.unsupported("web host full screen")
    }
    func hide(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws {
        (try backend.lease(window).window as? WebWindow)?.visible = false
    }
    /// Asked on the page; a scripted run answers the first button, as the headless host.
    func askMessageBox(text: String,caption: String,buttons: [String]) -> Int {
        scripted ? 0 : WebInput.ask(text:text,caption:caption,buttons:buttons)
    }
    /// A web link opens on the page; a folder of the game's (RECORDING INFO's
    /// "explore") lives in the worker's files, which the player cannot open.
    func open(_ url: URL) {
        Self.report(["event":"webOpen","path":url.absoluteString])
        if !scripted,["http","https"].contains(url.scheme?.lowercased() ?? "") { WebInput.open(url.absoluteString) }
    }
    func showStop(title: String,text: String) { if !scripted { _ = WebInput.ask(text:text,caption:title,buttons:["OK"]) } }
    func didStart() {}
    func terminate() { Foundation.exit(0) }
    func exit(_ code: Int32) -> Never { Foundation.exit(code) }
}
