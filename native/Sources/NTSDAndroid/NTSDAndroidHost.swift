import CAndroidNative
import Foundation
import NTSDCore
import NTSDRuntime
#if canImport(NTSDFreeTypeText)
import NTSDFreeTypeText
#endif

/// A virtual original window: the Android surface shows the window that presents last.
final class NTSDAndroidWindow {
    let popup: Bool, client: CGSize, origin: CGPoint
    var visible = false, closed = false
    init(popup: Bool,client: CGSize,origin: CGPoint) { self.popup = popup; self.client = client; self.origin = origin }
}
final class NTSDAndroidCursor {}

/// The original's windows on Android: the screen is the surface in density-
/// independent pixels, no frame or caption (as on the iPad), windows centred.
/// Frames go to the ANativeWindow letterboxed into the surface's aspect.
@MainActor final class NTSDAndroidWindowHost: OriginalRuntimeWindowHost {
    let screen: CGSize
    weak var app: NTSDAndroidApp?
    /// The last presented frame (redrawn when the surface comes back) and its window.
    private(set) var frame: OriginalFramebuffer?, shown: NTSDAndroidWindow?
    /// The buffer geometry last set; a new surface (after the app returns from
    /// the background, possibly at the same address) starts with its own
    /// defaults, so the app clears this whenever the surface changes.
    private var geometry: (width: Int32,height: Int32)?
    func surfaceChanged() { geometry = nil }
    init(screen: CGSize) { self.screen = screen }
    private static func window(_ object: AnyObject) -> NTSDAndroidWindow { object as! NTSDAndroidWindow }
    func screenSize() throws -> CGSize { screen }
    func frameMetric(_ index: UInt32) throws -> CGFloat { 0 }
    func arrowCursor() -> AnyObject { NTSDAndroidCursor() }
    func createWindow(popup: Bool,width: CGFloat,height: CGFloat,title: String,cursor: AnyObject) throws -> AnyObject {
        let client = popup ? screen : CGSize(width:width,height:height)
        guard client.width > 0,client.height > 0 else { throw OriginalRuntimeWindowBackend.Boundary.geometry }
        let origin = popup ? .zero : CGPoint(x:((screen.width-width)/2).rounded(.down),y:((screen.height-height)/2).rounded(.down))
        return NTSDAndroidWindow(popup:popup,client:client,origin:origin)
    }
    func windowCreated(_ lease: OriginalRuntimeWindowBackend.WindowLease,popup: Bool,backend: OriginalRuntimeWindowBackend) {}
    func orderFront(_ window: AnyObject) { Self.window(window).visible = true }
    func update(_ window: AnyObject) {}
    func show(_ window: AnyObject) -> Bool { let w = Self.window(window),was = w.visible; w.visible = true; return was }
    func close(_ window: AnyObject) { let w = Self.window(window); w.closed = true; w.visible = false }
    nonisolated func released(_ window: AnyObject,closed: Bool,platformState: AnyObject?) {}
    func clientBounds(_ window: AnyObject) throws -> CGRect { CGRect(origin:.zero,size:Self.window(window).client) }
    func clientFrame(_ window: AnyObject) throws -> CGRect { CGRect(origin:.zero,size:Self.window(window).client) }
    func displayGeometry(_ window: AnyObject) throws -> OriginalRuntimeDisplayGeometry {
        let w = Self.window(window)
        return .init(screen:CGRect(origin:.zero,size:screen),
                     clientOnScreen:CGRect(x:w.origin.x,y:screen.height-w.origin.y-w.client.height,width:w.client.width,height:w.client.height))
    }
    func desktopPoint(_ window: AnyObject,client point: CGPoint) throws -> CGPoint {
        let w = Self.window(window); return CGPoint(x:w.origin.x+point.x,y:w.origin.y+point.y)
    }
    func present(_ frame: OriginalFramebuffer,in window: AnyObject) throws {
        self.frame = frame; shown = Self.window(window)
        if let surface = app?.surface { draw(surface) }
    }
    /// The buffer size that fits the frame into the surface's aspect.
    private func buffer(_ surface: OpaquePointer,_ frame: OriginalFramebuffer) -> (Int32,Int32) {
        let sw = Int(ANativeWindow_getWidth(surface)),sh = Int(ANativeWindow_getHeight(surface))
        guard sw > 0,sh > 0 else { return (Int32(frame.width),Int32(frame.height)) }
        if sw*frame.height > sh*frame.width { return (Int32((frame.height*sw+sh-1)/sh),Int32(frame.height)) }
        return (Int32(frame.width),Int32((frame.width*sh+sw-1)/sw))
    }
    /// Copies the last frame into the surface, centred on black. The game's
    /// pixels are B,G,R,X bytes; the surface buffer is R,G,B,X.
    func draw(_ surface: OpaquePointer) {
        guard let frame else { return }
        let (bw,bh) = buffer(surface,frame)
        if geometry == nil || geometry! != (bw,bh) {
            _ = ANativeWindow_setBuffersGeometry(surface,bw,bh,Int32(WINDOW_FORMAT_RGBX_8888.rawValue)); geometry = (bw,bh)
        }
        var out = ANativeWindow_Buffer()
        guard ANativeWindow_lock(surface,&out,nil) == 0 else { return }
        // Only a 32-bit buffer takes these pixels.
        guard let bits = out.bits,out.format == Int32(WINDOW_FORMAT_RGBX_8888.rawValue) || out.format == Int32(WINDOW_FORMAT_RGBA_8888.rawValue) else {
            _ = ANativeWindow_unlockAndPost(surface); geometry = nil; return
        }
        let stride = Int(out.stride),width = Int(out.width),height = Int(out.height)
        let dst = bits.assumingMemoryBound(to:UInt32.self)
        let x0 = max(0,(width-frame.width)/2),y0 = max(0,(height-frame.height)/2)
        let w = min(frame.width,width),h = min(frame.height,height)
        // Black outside the frame only; the frame's own pixels are written below
        // (CORE_REALTIME phase 1a: one pass per pixel instead of two).
        for y in 0..<height {
            let row = dst+y*stride
            if y < y0 || y >= y0+h { row.update(repeating:0xFF00_0000,count:width); continue }
            if x0 > 0 { row.update(repeating:0xFF00_0000,count:x0) }
            if x0+w < width { (row+x0+w).update(repeating:0xFF00_0000,count:width-x0-w) }
        }
        if w > 0 && h > 0 {
            frame.pixels.withUnsafeBytes { raw in
                let src = raw.baseAddress!.assumingMemoryBound(to:UInt32.self)
                for y in 0..<h { Self.swapChannels(src+y*frame.width,dst+(y0+y)*stride+x0,w) }
            }
        }
        _ = ANativeWindow_unlockAndPost(surface)
    }
    /// B,G,R,X words to R,G,B,X with X = 0xFF (little-endian), four at a time.
    static func swapChannels(_ from: UnsafePointer<UInt32>,_ to: UnsafeMutablePointer<UInt32>,_ count: Int) {
        var i = 0
        while i+4 <= count {
            let v = UnsafeRawPointer(from+i).loadUnaligned(as:SIMD4<UInt32>.self)
            let rgb = ((v &>> 16) & 0xFF) | (v & 0xFF00) | ((v & 0xFF) &<< 16) | 0xFF00_0000
            UnsafeMutableRawPointer(to+i).storeBytes(of:rgb,as:SIMD4<UInt32>.self)
            i += 4
        }
        while i < count {
            let v = from[i]
            to[i] = ((v >> 16) & 0xFF) | (v & 0xFF00) | ((v & 0xFF) << 16) | 0xFF00_0000
            i += 1
        }
    }
    /// A surface pixel as the drawn frame's client point.
    func clientPoint(_ x: Float,_ y: Float,surface: OpaquePointer) -> (Int32,Int32)? {
        guard let frame else { return nil }
        let sw = Float(ANativeWindow_getWidth(surface)),sh = Float(ANativeWindow_getHeight(surface))
        guard sw > 0,sh > 0 else { return nil }
        let (bw,bh) = buffer(surface,frame)
        let bx = x*Float(bw)/sw,by = y*Float(bh)/sh
        return (Int32((bx-Float((Int(bw)-frame.width)/2)).rounded(.down)),Int32((by-Float((Int(bh)-frame.height)/2)).rounded(.down)))
    }
}

/// The Android session host: one surface, touch as the mouse, hardware keys
/// through the shared HID table, the shared BSD sockets, text through FreeType
/// with Android's system sans-serif, AAudio for the effects mixer and the
/// packaged music decoded by NTSDMusicDecoder (as on Linux).
@MainActor final class NTSDAndroidSessionHost: OriginalRuntimeSessionHost {
    let arguments: [String], windows: NTSDAndroidWindowHost, musicDirectory: String, files: URL, density: Double
    weak var session: OriginalRuntimeSession?
    private var effects: NTSDAndroidStream?, feed: NTSDAndroidEffectsFeed?, effectsMuted = false
    private var players: [() -> NTSDAndroidMusicPlayer?] = [], focused = true
    /// The last touch as a desktop point: the game reads it with GetCursorPos.
    private var cursor: (Int32,Int32) = (0,0)
    /// Touches as player-like clicks (hover, then a held press).
    lazy var touch = OriginalRuntimeTouchMouse { [unowned self] message,x,y,buttons in self.mouse(message,x:x,y:y,buttons:buttons) }
    init(arguments: [String],screen: CGSize,density: Double,musicDirectory: String,files: URL) {
        self.arguments = arguments; windows = NTSDAndroidWindowHost(screen:screen)
        self.musicDirectory = musicDirectory; self.files = files; self.density = density
    }
    static func report(_ value: [String:Any]) { OriginalRuntimeSession.emit(value) }
    func mouse(_ message: UInt32,x: Int32,y: Int32,buttons: UInt32) {
        if let w = windows.shown { cursor = (Int32(w.origin.x)+x,Int32(w.origin.y)+y) }
        guard let session,let messages = session.messages,!session.stopped,!session.scripted else { return }
        messages.mouse(message,x:x,y:y,buttons:buttons)
    }
    func key(_ key: OriginalMacRuntimeKey,down: Bool,characters: String?) {
        guard let session,let messages = session.messages,!session.stopped,!session.scripted else { return }
        messages.key(key,down:down,characters:characters)
    }
    /// TextOutA's glyph masks: Android's system sans-serif (Roboto, weight 700),
    /// else Droid Sans Bold, through FreeType, as Linux uses its standard bold
    /// (user decision 2026-10-01: the platform font as a declared stand-in for
    /// the original's SYSTEM_FONT). Reported once at launch.
    private lazy var textMask: ([UInt8]) -> OriginalMacDisplayBackend.TextMask = {
        #if canImport(NTSDFreeTypeText)
        for (path,weight) in [("/system/fonts/Roboto-Regular.ttf",700.0 as Double?),("/system/fonts/DroidSans-Bold.ttf",nil)] {
            if let face = OriginalFreeTypeFace(path:path,weight:weight) {
                Self.report(["event":"androidText","font":path,"weight":weight ?? NSNull()]); return { face.mask($0) }
            }
        }
        #endif
        Self.report(["event":"androidText","font":NSNull()])
        return { _ in .init(advance:0,originX:0,originY:0,width:0,height:0,bits:[]) }
    }()
    var startupHost: OriginalRuntimeStartupHost {
        .init(windows:windows,textMask:textMask,
              messageBox:{ text,caption in Self.report(["event":"androidMessageBox","text":String(decoding:text,as:UTF8.self),
                                                         "caption":String(decoding:caption,as:UTF8.self)]) })
    }
    func capsLock() -> Int32 { 0 }
    func makeSockets() -> any OriginalRuntimeSockets { OriginalMacWinsock() }
    var loadingDialogs: OriginalRuntimeLoadingDialogs {
        .init(chooseRecording:{ _ in nil },alert:{ text in Self.report(["event":"androidAlert","text":text]) },
              open:{ path in Self.report(["event":"androidOpen","path":path]) })
    }
    func standardOverlay() throws -> OriginalMacRuntimeOverlay { .init(root:files.appendingPathComponent("NTSD Native",isDirectory:true)) }
    func beginTimingActivity() {}
    func connectedJoysticks() -> Int { 0 }
    func startJoystickSampling(_ session: OriginalRuntimeSession) {}
    var scripted: Bool { arguments.contains("--script") }
    func makeMusicOutput() throws -> OriginalMacMusicOutput {
        let directory = URL(fileURLWithPath:musicDirectory,isDirectory:true)
        // Scripted muted checks use the silent manifest players (declared harness
        // guard: the emulator runs without audio; the decoder is checked on Linux).
        if scripted && arguments.contains("--mute-music") { return try .silent(directory:directory) }
        guard let manifest = try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("manifest.json"))) as? [String:Any],
              let entries = manifest["entries"] as? [[String:Any]] else { throw OriginalMacMusicOutput.Boundary.manifest }
        var tracks: [String:URL] = [:]
        for entry in entries {
            guard let name = entry["name"] as? String,let resource = entry["resource"] as? String else { throw OriginalMacMusicOutput.Boundary.manifest }
            let url = directory.appendingPathComponent(resource)
            guard FileManager.default.fileExists(atPath:url.path) else { throw OriginalMacMusicOutput.Boundary.missingTrack(resource) }
            tracks[name.lowercased()] = url
        }
        return .init(tracks:tracks) { [weak self] url,ended in
            let player = try NTSDAndroidMusicPlayer(url,ended:ended)
            self?.players.append { [weak player] in player }
            return player
        }
    }
    func startSoundOutput(_ effects: OriginalMacSoundEffects,muted: Bool) throws -> String {
        if muted && scripted { return "muted (no output: scripted)" }   // as on the iPad host
        let feed = NTSDAndroidEffectsFeed(effects:effects)
        var rate = 48000.0
        let stream = try NTSDAndroidStream(float:true,rate:nil,lowLatency:true) { data,frames in feed.fill(data,frames:frames,rate:rate) }
        rate = Double(stream.rate); self.effects = stream; self.feed = feed; effectsMuted = muted; applyGain(); stream.start()
        return muted ? "muted" : "AAudio \(stream.rate) Hz"
    }
    /// DirectSound silences the game's buffers while its window is not
    /// foreground (as the SDL host follows).
    private func applyGain() { feed?.silent.store(effectsMuted || !focused,ordering:.relaxed) }
    func setFocused(_ value: Bool) { focused = value; applyGain() }
    /// Declared Android convention: in the background the app's audio output
    /// stops (the game keeps running); it resumes where it was.
    func setForeground(_ value: Bool) {
        players.removeAll { $0() == nil }
        if value { effects?.start(); players.forEach { $0()?.resume() } }
        else { effects?.pause(); players.forEach { $0()?.suspend() } }
    }
    func backingScale(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) -> Double { density }
    func cursorPoint() -> (Int32,Int32) { cursor }
    func attach(_ window: UInt32,in windows: OriginalRuntimeWindowBackend,session: OriginalRuntimeSession) throws {}
    func snapshotPNG(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws -> Data { try backend.presentedPNG(window) }
    func viewPNG(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws -> Data { try backend.presentedPNG(window) }
    func toggleFullScreen(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws {
        throw OriginalRuntimeWindowBackend.Boundary.unsupported("Android host full screen")
    }
    func hide(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws {}
    func askMessageBox(text: String,caption: String,buttons: [String]) -> Int { 0 }
    func open(_ url: URL) { Self.report(["event":"androidOpen","path":url.absoluteString]) }
    func showStop(title: String,text: String) { Self.report(["event":"androidStop","title":title,"text":text]) }
    func didStart() {}
    func terminate() { Foundation.exit(0) }
    func exit(_ code: Int32) -> Never { Foundation.exit(code) }
}

/// Android key codes as USB HID usages (the table `OriginalHIDKeys` maps).
enum NTSDAndroidKeys {
    static func usage(_ code: Int32) -> UInt32? {
        switch code {
        case 29...54: return UInt32(0x04+code-29)                  // A-Z
        case 8...16: return UInt32(0x1E+code-8)                    // 1-9
        case 7: return 0x27                                         // 0
        case 66: return 0x28                                        // Enter
        case 111, 4: return 0x29                                    // Escape; Back acts as Escape
        case 67: return 0x2A                                        // Backspace
        case 61: return 0x2B                                        // Tab
        case 62: return 0x2C                                        // Space
        case 69: return 0x2D; case 70: return 0x2E                  // - =
        case 71: return 0x2F; case 72: return 0x30; case 73: return 0x31  // [ ] \
        case 74: return 0x33; case 75: return 0x34; case 68: return 0x35  // ; ' `
        case 55: return 0x36; case 56: return 0x37; case 76: return 0x38  // , . /
        case 115: return 0x39                                       // Caps Lock
        case 131...142: return UInt32(0x3A+code-131)               // F1-F12
        case 124: return 0x49; case 122: return 0x4A; case 92: return 0x4B   // Insert Home PageUp
        case 112: return 0x4C; case 123: return 0x4D; case 93: return 0x4E   // Delete End PageDown
        case 22: return 0x4F; case 21: return 0x50; case 20: return 0x51; case 19: return 0x52  // arrows
        case 143: return 0x53; case 154: return 0x54; case 155: return 0x55   // NumLock / *
        case 156: return 0x56; case 157: return 0x57; case 160: return 0x58   // - + Enter (keypad)
        case 145...153: return UInt32(0x59+code-145)               // keypad 1-9
        case 144: return 0x62; case 158: return 0x63                // keypad 0 .
        case 113: return 0xE0; case 59: return 0xE1; case 57: return 0xE2; case 117: return 0xE3  // left Ctrl Shift Alt Meta
        case 114: return 0xE4; case 60: return 0xE5; case 58: return 0xE6; case 118: return 0xE7  // right Ctrl Shift Alt Meta
        default: return nil
        }
    }
    /// The typed character for letters, digits and space (declared: the NDK
    /// gives no Unicode character without Java; other keys send none).
    static func characters(_ code: Int32,shift: Bool) -> String? {
        switch code {
        case 29...54: let c = Character(Unicode.Scalar(UInt8(0x61+code-29))); return shift ? c.uppercased() : String(c)
        case 7...16: return String(code-7)
        case 62: return " "
        default: return nil
        }
    }
}
