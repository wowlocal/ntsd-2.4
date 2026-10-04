import AVFoundation
import CoreText
import Foundation
import UIKit
import NTSDCore
import NTSDRuntime

/// A virtual original window: the iPad has one view, which shows the window
/// that presents last.
final class NTSDiOSWindow {
    let popup: Bool, client: CGSize, origin: CGPoint
    var visible = false, closed = false
    init(popup: Bool,client: CGSize,origin: CGPoint) { self.popup = popup; self.client = client; self.origin = origin }
}
final class NTSDiOSCursor {}

/// The original's windows on an iPad: the screen is the scene's in points, no
/// frame or caption (the game derives its client size), windows centred.
@MainActor final class NTSDiOSWindowHost: OriginalRuntimeWindowHost {
    let screen: CGSize, view: NTSDGameView
    /// The window that presented last (the one the view shows).
    private(set) var shown: NTSDiOSWindow?
    init(screen: CGSize,view: NTSDGameView) { self.screen = screen; self.view = view }
    private static func window(_ object: AnyObject) -> NTSDiOSWindow { object as! NTSDiOSWindow }
    func screenSize() throws -> CGSize { screen }
    func frameMetric(_ index: UInt32) throws -> CGFloat { 0 }
    func arrowCursor() -> AnyObject { NTSDiOSCursor() }
    func createWindow(popup: Bool,width: CGFloat,height: CGFloat,title: String,cursor: AnyObject) throws -> AnyObject {
        let client = popup ? screen : CGSize(width:width,height:height)
        guard client.width > 0,client.height > 0 else { throw OriginalRuntimeWindowBackend.Boundary.geometry }
        let origin = popup ? .zero : CGPoint(x:((screen.width-width)/2).rounded(.down),y:((screen.height-height)/2).rounded(.down))
        return NTSDiOSWindow(popup:popup,client:client,origin:origin)
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
        guard let provider = CGDataProvider(data:frame.pixels as CFData),let space = CGColorSpace(name:CGColorSpace.sRGB),
              let image = CGImage(width:frame.width,height:frame.height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:frame.width*4,space:space,
                                  bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.noneSkipFirst.rawValue).union(.byteOrder32Little),
                                  provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)
        else { throw OriginalRuntimeWindowBackend.Boundary.geometry }
        view.show(image,size:CGSize(width:frame.width,height:frame.height)); shown = Self.window(window)
    }
}

/// AVAudioPlayer behind `OriginalMacMusicOutput.Player`, as on the macOS host:
/// iOS plays the packaged ALAC tracks natively.
@MainActor final class NTSDiOSMusicPlayer: NSObject, OriginalMacMusicOutput.Player, AVAudioPlayerDelegate {
    let player: AVAudioPlayer, ended: () -> Void
    init(_ url: URL,ended: @escaping () -> Void) throws {
        player = try AVAudioPlayer(contentsOf:url); self.ended = ended
        super.init(); player.delegate = self; player.prepareToPlay()
    }
    var currentTime: TimeInterval { get { player.currentTime } set { player.currentTime = newValue } }
    var duration: TimeInterval { player.duration }
    var volume: Float { get { player.volume } set { player.volume = newValue } }
    var isPlaying: Bool { player.isPlaying }
    func play() { player.play() }
    func pause() { player.pause() }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,successfully flag: Bool) {
        if Thread.isMainThread { MainActor.assumeIsolated { self.ended() } }
        else { DispatchQueue.main.async { MainActor.assumeIsolated { self.ended() } } }
    }
}

/// The iPad session host: one view, touch and keyboard input, AVAudioEngine
/// for the effects mixer, the packaged tracks through AVAudioPlayer (as on
/// macOS), CoreText glyph masks with the iOS system font as macOS uses its
/// system font, Darwin sockets, and the app's Documents folder as the overlay.
@MainActor final class NTSDiOSSessionHost: OriginalRuntimeSessionHost {
    let arguments: [String], windows: NTSDiOSWindowHost, musicDirectory: String
    weak var session: OriginalRuntimeSession?
    private let engine = AVAudioEngine()
    private var activity: NSObjectProtocol?
    /// The last touch as a desktop point: the game reads it with GetCursorPos.
    private var cursor: (Int32,Int32) = (0,0)
    /// Touches as player-like clicks (hover, then a held press).
    lazy var touch = OriginalRuntimeTouchMouse { [unowned self] message,x,y,buttons in self.mouse(message,x:x,y:y,buttons:buttons) }
    init(arguments: [String],view: NTSDGameView,screen: CGSize) {
        self.arguments = arguments; windows = NTSDiOSWindowHost(screen:screen,view:view)
        musicDirectory = Bundle.main.bundleURL.appendingPathComponent("OriginalMusic").path
    }
    var scripted: Bool { arguments.contains("--script") }
    func mouse(_ message: UInt32,x: Int32,y: Int32,buttons: UInt32) {
        if let w = windows.shown { cursor = (Int32(w.origin.x)+x,Int32(w.origin.y)+y) }
        guard let session,let messages = session.messages,!session.stopped,!session.scripted else { return }
        messages.mouse(message,x:x,y:y,buttons:buttons)
    }
    func key(_ key: OriginalMacRuntimeKey,down: Bool,characters: String?) {
        guard let session,let messages = session.messages,!session.stopped,!session.scripted else { return }
        messages.key(key,down:down,characters:characters)
    }
    /// Declared stand-in for SYSTEM_FONT, as on macOS: the system font, bold,
    /// 13 px em, baseline at the cell's +13, no smoothing.
    static func textMask(_ bytes: [UInt8]) -> OriginalMacDisplayBackend.TextMask {
        let cell = OriginalMacDisplayBackend.textCell,ascent = OriginalMacDisplayBackend.textAscent
        let font = UIFont.systemFont(ofSize:CGFloat(cell-3),weight:.bold)
        let attributes: [NSAttributedString.Key:Any] = [.font:font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:1,alpha:1)]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string:String(decoding:bytes,as:UTF8.self),attributes:attributes))
        let advance = max(0,Int(CTLineGetTypographicBounds(line,nil,nil,nil).rounded()))
        let margin = 4,width = advance+2*margin,height = cell+2*margin
        var bits = [UInt8](repeating:0,count:width*height)
        bits.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data:raw.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width,
                                          space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue) else { return }
            context.setAllowsAntialiasing(false); context.setShouldAntialias(false)
            context.setAllowsFontSmoothing(false); context.setShouldSmoothFonts(false)
            context.textPosition = CGPoint(x:margin,y:margin+cell-ascent)
            CTLineDraw(line,context)
        }
        return .init(advance:advance,originX:margin,originY:margin,width:width,height:height,bits:bits.map { $0 >= 128 ? 1 : 0 })
    }
    var startupHost: OriginalRuntimeStartupHost {
        .init(windows:windows,textMask:Self.textMask,messageBox:{ text,caption in
            OriginalRuntimeSession.emit(["event":"iosMessageBox","caption":String(decoding:caption,as:UTF8.self),"text":String(decoding:text,as:UTF8.self)])
        })
    }
    func capsLock() -> Int32 { 0 }
    func makeSockets() -> any OriginalRuntimeSockets { OriginalMacWinsock() }
    var loadingDialogs: OriginalRuntimeLoadingDialogs {
        .init(chooseRecording:{ _ in nil },alert:{ text in OriginalRuntimeSession.emit(["event":"iosAlert","text":text]) },open:{ _ in })
    }
    func standardOverlay() throws -> OriginalMacRuntimeOverlay {
        let documents = try FileManager.default.url(for:.documentDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
        return .init(root:documents.appendingPathComponent("NTSD Native",isDirectory:true))
    }
    func beginTimingActivity() {
        activity = ProcessInfo.processInfo.beginActivity(options:[.userInitiated,.latencyCritical],reason:"Original game loop timing")
    }
    func connectedJoysticks() -> Int { 0 }
    func startJoystickSampling(_ session: OriginalRuntimeSession) {}
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
        return .init(tracks:tracks) { url,ended in try NTSDiOSMusicPlayer(url,ended:ended) }
    }
    func startSoundOutput(_ effects: OriginalMacSoundEffects,muted: Bool) throws -> String {
        // Scripted muted checks open no output (declared): with the Mac's screen
        // locked the simulator's CoreAudio aborted the app at engine setup ("RPC
        // timeout ... deadlocked"; unlocked it starts), and game state does not
        // depend on an output pulling the mixer (the headless host has none).
        if muted && scripted { return "muted (no output: scripted)" }
        // iOS needs an active audio session before the engine touches its output
        // (without one, CoreAudio deadlocked and aborted the app in the simulator).
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.ambient,mode:.default,options:[.mixWithOthers])
        try audio.setActive(true)
        let rate = engine.outputNode.outputFormat(forBus:0).sampleRate
        guard rate > 0,let format = AVAudioFormat(standardFormatWithSampleRate:rate,channels:2) else { return "no output" }
        let node = AVAudioSourceNode(format:format) { _,_,frameCount,list -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            guard buffers.count == 2,let l = buffers[0].mData?.assumingMemoryBound(to:Float.self),
                  let r = buffers[1].mData?.assumingMemoryBound(to:Float.self) else { return noErr }
            effects.render(frames:Int(frameCount),rate:rate,left:l,right:r)
            return noErr
        }
        engine.attach(node); engine.connect(node,to:engine.mainMixerNode,format:format)
        engine.mainMixerNode.outputVolume = muted ? 0 : 1
        try engine.start()
        return muted ? "muted" : "AVAudioEngine \(Int(rate)) Hz"
    }
    func backingScale(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) -> Double { Double(UIScreen.main.scale) }
    func cursorPoint() -> (Int32,Int32) { cursor }
    func attach(_ window: UInt32,in windows: OriginalRuntimeWindowBackend,session: OriginalRuntimeSession) throws {}
    func snapshotPNG(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws -> Data { try windows.presentedPNG(window) }
    func viewPNG(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws -> Data { try windows.presentedPNG(window) }
    func toggleFullScreen(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws {
        throw OriginalRuntimeWindowBackend.Boundary.unsupported("iPad host full screen")
    }
    func hide(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws {}
    func askMessageBox(text: String,caption: String,buttons: [String]) -> Int { 0 }
    func open(_ url: URL) { UIApplication.shared.open(url) }
    func showStop(title: String,text: String) { OriginalRuntimeSession.emit(["event":"iosStop","title":title,"text":text]) }
    func didStart() {}
    func terminate() { Foundation.exit(0) }
    func exit(_ code: Int32) -> Never { Foundation.exit(code) }
}
