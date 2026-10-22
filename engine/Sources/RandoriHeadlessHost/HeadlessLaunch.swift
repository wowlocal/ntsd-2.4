import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import RandoriCore
import RandoriRuntime

// `NTSDHeadless --script "…" --virtual-clock BASE STEP (--no-network | --network-loopback)
//  [--screen W H] [--caption N] [--music-dir DIR] [session options]`: the original
// game through OriginalRuntimeSession without a display or audio device. Scripted,
// reproducible runs only; captures are framebuffer PNGs (no host scaling).
// --network-loopback (127.0.0.1 as the local address) lets two processes play
// ONLINE GAME over the shared sockets, as tools/crossplatform/pair_probe.py does.
public enum RandoriHeadlessHost {
    /// Runs `game` headless with these arguments (ENGINE_SPLIT E4b: the body of
    /// the former NTSDHeadless main.swift); `defaultMusicDirectory` applies
    /// without `--music-dir`.
    public static func run(arguments: [String],game: OriginalGame,defaultMusicDirectory: @autoclosure () -> String) -> Never {
        func option(_ name: String,_ count: Int) -> [String]? {
            guard let i = arguments.firstIndex(of:name),i+count < arguments.count else { return nil }
            return Array(arguments[(i+1)...(i+count)])
        }
        guard arguments.contains("--script"),arguments.contains("--no-network") || arguments.contains("--network-loopback"),
              option("--virtual-clock",2) != nil else {
            FileHandle.standardError.write(Data("NTSDHeadless needs --script, --virtual-clock BASE STEP and --no-network or --network-loopback\n".utf8))
            exit(2)
        }
        let screen = option("--screen",2).flatMap { w in Double(w[0]).flatMap { x in Double(w[1]).map { CGSize(width:x,height:$0) } } } ?? CGSize(width:3008,height:1692)
        let caption = option("--caption",1).flatMap { Double($0[0]) }.map { CGFloat($0) } ?? 32
        let musicDirectory = option("--music-dir",1)?[0] ?? defaultMusicDirectory()
        MainActor.assumeIsolated {
            let host = HeadlessSessionHost(arguments:arguments,screen:screen,caption:caption,musicDirectory:musicDirectory,game:game)
            let session = OriginalRuntimeSession(arguments:arguments,host:host)
            host.session = session; retainedHost = host; retainedSession = session
            session.start()
        }
        // The session schedules its iterations on the main queue and asserts MainActor
        // isolation, so the main thread must drain that queue: a run loop does on macOS
        // and Linux (dispatchMain() would hand the queue to worker threads).
        #if os(WASI)
        // No main queue without threads: the runtime's own queue of deferred calls
        // (TVOS_WEB W0).
        MainActor.assumeIsolated { OriginalMainQueue.run() }
        #else
        RunLoop.main.add(Timer(timeInterval:86400,repeats:true) { _ in },forMode:.default)
        RunLoop.main.run()
        #endif
        exit(0)
    }
}
nonisolated(unsafe) private var retainedHost: AnyObject?
nonisolated(unsafe) private var retainedSession: AnyObject?
