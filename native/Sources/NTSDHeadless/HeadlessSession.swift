import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import NTSDCore
import NTSDRuntime

/// The headless session host: offscreen windows, framebuffer PNG captures,
/// silent music and sound, no sockets and scripted input only.
@MainActor final class HeadlessSessionHost: OriginalRuntimeSessionHost {
    let arguments: [String], windows: HeadlessWindowHost, musicDirectory: String
    weak var session: OriginalRuntimeSession?
    init(arguments: [String],screen: CGSize,caption: CGFloat,musicDirectory: String) {
        self.arguments = arguments; windows = HeadlessWindowHost(screen:screen,caption:caption); self.musicDirectory = musicDirectory
    }
    static func report(_ value: [String:Any]) { OriginalRuntimeSession.emit(value) }
    var startupHost: OriginalRuntimeStartupHost {
        // Declared headless stand-in: no glyph rasteriser yet, so TextOutA draws
        // nothing (game state is unaffected; text pixels differ from the Mac).
        .init(windows:windows,textMask:{ _ in .init(advance:0,originX:0,originY:0,width:0,height:0,bits:[]) },
              messageBox:{ text,caption in Self.report(["event":"headlessMessageBox","text":String(decoding:text,as:UTF8.self),
                                                         "caption":String(decoding:caption,as:UTF8.self)]) })
    }
    func capsLock() -> Int32 { 0 }
    func makeSockets() -> any OriginalRuntimeSockets { preconditionFailure("headless runs need --no-network") }
    var loadingDialogs: OriginalRuntimeLoadingDialogs {
        .init(chooseRecording:{ _ in nil },alert:{ text in Self.report(["event":"headlessAlert","text":text]) },
              open:{ path in Self.report(["event":"headlessOpen","path":path]) })
    }
    func standardOverlay() throws -> OriginalMacRuntimeOverlay {
        .init(root:FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-headless-"+UUID().uuidString,isDirectory:true))
    }
    func beginTimingActivity() {}
    func connectedJoysticks() -> Int { 0 }
    func startJoystickSampling(_ session: OriginalRuntimeSession) {}
    func makeMusicOutput() throws -> OriginalMacMusicOutput { try .silent(directory:URL(fileURLWithPath:musicDirectory,isDirectory:true)) }
    func startSoundOutput(_ effects: OriginalMacSoundEffects,muted: Bool) throws -> String { "headless (no output)" }
    func backingScale(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) -> Double { 1 }
    func cursorPoint() -> (Int32,Int32) { (0,0) }
    func attach(_ window: UInt32,in windows: OriginalRuntimeWindowBackend,session: OriginalRuntimeSession) throws {}
    func snapshotPNG(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws -> Data { try backend.presentedPNG(window) }
    func viewPNG(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws -> Data { try snapshotPNG(window,in:backend) }
    func toggleFullScreen(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws {
        throw OriginalRuntimeWindowBackend.Boundary.unsupported("host full screen")
    }
    func hide(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws {
        (try backend.lease(window).window as? HeadlessWindow)?.visible = false
    }
    func askMessageBox(text: String,caption: String,buttons: [String]) -> Int { 0 }
    func open(_ url: URL) { Self.report(["event":"headlessOpen","path":url.absoluteString]) }
    func showStop(title: String,text: String) {}
    func didStart() {}
    func terminate() { Foundation.exit(0) }
    func exit(_ code: Int32) -> Never { Foundation.exit(code) }
}
