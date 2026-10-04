import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import NTSDCore
import NTSDRuntime

/// A track that never sounds: scripted runs end it by the virtual clock against
/// its packaged frame count (equal to AVAudioPlayer's duration for every track).
@MainActor final class HeadlessMusicPlayer: OriginalMacMusicOutput.Player {
    let duration: TimeInterval
    var currentTime: TimeInterval = 0, volume: Float = 1
    private(set) var isPlaying = false
    init(duration: TimeInterval) { self.duration = duration }
    func play() { isPlaying = true }
    func pause() { isPlaying = false }
}

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
    func makeMusicOutput() throws -> OriginalMacMusicOutput {
        let directory = URL(fileURLWithPath:musicDirectory,isDirectory:true)
        guard let manifest = try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("manifest.json"))) as? [String:Any],
              let rate = (manifest["sampleRate"] as? NSNumber)?.doubleValue,rate > 0,
              let entries = manifest["entries"] as? [[String:Any]] else { throw OriginalMacMusicOutput.Boundary.manifest }
        var tracks: [String:URL] = [:],durations: [URL:TimeInterval] = [:]
        for entry in entries {
            guard let name = entry["name"] as? String,let resource = entry["resource"] as? String,
                  let frames = (entry["frames"] as? NSNumber)?.doubleValue else { throw OriginalMacMusicOutput.Boundary.manifest }
            let url = directory.appendingPathComponent(resource)
            tracks[name.lowercased()] = url; durations[url] = frames/rate
        }
        return .init(tracks:tracks) { url,_ in HeadlessMusicPlayer(duration:durations[url] ?? 0) }
    }
    func startSoundOutput(_ effects: OriginalMacSoundEffects,muted: Bool) throws -> String { "headless (no output)" }
    func backingScale(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) -> Double { 1 }
    func cursorPoint() -> (Int32,Int32) { (0,0) }
    func attach(_ window: UInt32,in windows: OriginalRuntimeWindowBackend,session: OriginalRuntimeSession) throws {}
    func snapshotPNG(_ window: UInt32,in backend: OriginalRuntimeWindowBackend) throws -> Data {
        HeadlessPNG.encode(try windows.frame(window,in:backend))
    }
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
