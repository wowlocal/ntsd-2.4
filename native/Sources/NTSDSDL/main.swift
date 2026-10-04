import CSDL3
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import NTSDRuntime
#if canImport(NTSDMacPlatform)
import NTSDMacPlatform
#endif

// `NTSDSDL [--music-dir DIR] [--caption N] [session options]`: the original
// game through OriginalRuntimeSession on SDL3 (P6, docs/research/CROSS_PLATFORM.md).
let arguments = CommandLine.arguments
func option(_ name: String,_ count: Int) -> [String]? {
    guard let i = arguments.firstIndex(of:name),i+count < arguments.count else { return nil }
    return Array(arguments[(i+1)...(i+count)])
}
#if os(Windows)
guard arguments.contains("--no-network") else {
    FileHandle.standardError.write(Data("NTSDSDL on Windows needs --no-network until a real-Winsock adapter exists\n".utf8))
    exit(2)
}
#endif
_ = SDL_SetHint("SDL_VIDEO_MAC_FULLSCREEN_SPACES","0")
guard SDL_Init(NTSD_SDL_INIT) else {
    FileHandle.standardError.write(Data("SDL_Init: \(String(cString:SDL_GetError()))\n".utf8)); exit(1)
}
// The packaged tracks: --music-dir, else OriginalMusic beside the executable
// (the Linux package), else the source tree's copy.
let besideExecutable = URL(fileURLWithPath:CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent()
    .appendingPathComponent("OriginalMusic").path
let musicDirectory = option("--music-dir",1)?[0]
    ?? (FileManager.default.fileExists(atPath:besideExecutable+"/manifest.json") ? besideExecutable
        : URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("NTSDMacPlatform/Resources/OriginalMusic").path)
let session: OriginalRuntimeSession = MainActor.assumeIsolated {
    // The window metrics the game is told: on macOS the AppKit host's (SDL cannot
    // report Cocoa borders), so client sizes and frames match the AppKit app.
    var caption = option("--caption",1).flatMap { Double($0[0]) }.map { CGFloat($0) }
    #if canImport(NTSDMacPlatform)
    let mac = OriginalMacWindowHost()
    let metrics = ((try? mac.frameMetric(7)) ?? 0,(try? mac.frameMetric(8)) ?? 0,caption ?? ((try? mac.frameMetric(4)) ?? 0))
    #else
    caption = caption ?? 0
    let metrics: (CGFloat,CGFloat,CGFloat) = (0,0,caption!)
    #endif
    let host = SDLSessionHost(arguments:arguments,windows:SDLWindowHost(metrics:metrics),musicDirectory:musicDirectory)
    let session = OriginalRuntimeSession(arguments:arguments,host:host)
    host.session = session; retainedHost = host
    session.start()
    return session
}
nonisolated(unsafe) var retainedHost: AnyObject?
// The session's iterations are scheduled on the main queue: the main run loop
// drains it, and a timer pumps SDL events once a window is attached.
RunLoop.main.add(Timer(timeInterval:86400,repeats:true) { _ in },forMode:.default)
RunLoop.main.run()
