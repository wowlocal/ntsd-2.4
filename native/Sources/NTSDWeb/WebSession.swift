import Foundation
import NTSDCore
import NTSDRuntime

/// The browser session host (TVOS_WEB W2b): the original game in a page, run
/// by a worker that draws each presented crop on the page's canvas. This first
/// step has the headless host's services otherwise: scripted input, silent
/// music and sound, no glyph rasteriser (the `none` text group), no sockets
/// (WASI has none) and the overlay in the worker's files.
@MainActor final class WebSessionHost: OriginalRuntimeSessionHost {
    let arguments: [String], windows: WebWindowHost, musicDirectory: String
    weak var session: OriginalRuntimeSession?
    init(arguments: [String],screen: CGSize,caption: CGFloat,musicDirectory: String) {
        self.arguments = arguments; windows = WebWindowHost(screen:screen,caption:caption); self.musicDirectory = musicDirectory
    }
    static func report(_ value: [String:Any]) { OriginalRuntimeSession.emit(value) }
    var startupHost: OriginalRuntimeStartupHost {
        // No glyph rasteriser yet: TextOutA draws nothing, as on the headless host.
        .init(windows:windows,textMask:{ _ in .init(advance:0,originX:0,originY:0,width:0,height:0,bits:[]) },
              messageBox:{ text,caption in Self.report(["event":"webMessageBox","text":String(decoding:text,as:UTF8.self),
                                                         "caption":String(decoding:caption,as:UTF8.self)]) })
    }
    func capsLock() -> Int32 { 0 }
    func makeSockets() -> any OriginalRuntimeSockets { OriginalUnavailableSockets() }
    var loadingDialogs: OriginalRuntimeLoadingDialogs {
        .init(chooseRecording:{ _ in nil },alert:{ text in Self.report(["event":"webAlert","text":text]) },
              open:{ path in Self.report(["event":"webOpen","path":path]) })
    }
    func standardOverlay() throws -> OriginalMacRuntimeOverlay {
        .init(root:FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-web-"+UUID().uuidString,isDirectory:true))
    }
    func beginTimingActivity() {}
    func connectedJoysticks() -> Int { 0 }
    func startJoystickSampling(_ session: OriginalRuntimeSession) {}
    func makeMusicOutput() throws -> OriginalMacMusicOutput { try .silent(directory:URL(fileURLWithPath:musicDirectory,isDirectory:true)) }
    func startSoundOutput(_ effects: OriginalMacSoundEffects,muted: Bool) throws -> String { "web (no output yet)" }
    func backingScale(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) -> Double { 1 }
    func cursorPoint() -> (Int32,Int32) { (0,0) }
    func attach(_ window: UInt32,in windows: OriginalRuntimeWindowBackend,session: OriginalRuntimeSession) throws {}
    func snapshotPNG(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws -> Data { try backend.presentedPNG(window) }
    func viewPNG(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws -> Data { try snapshotPNG(window,in:backend) }
    func toggleFullScreen(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws {
        throw OriginalRuntimeWindowBackend.Boundary.unsupported("web host full screen")
    }
    func hide(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws {
        (try backend.lease(window).window as? WebWindow)?.visible = false
    }
    func askMessageBox(text: String,caption: String,buttons: [String]) -> Int { 0 }
    func open(_ url: URL) { Self.report(["event":"webOpen","path":url.absoluteString]) }
    func showStop(title: String,text: String) {}
    func didStart() {}
    func terminate() { Foundation.exit(0) }
    func exit(_ code: Int32) -> Never { Foundation.exit(code) }
}
