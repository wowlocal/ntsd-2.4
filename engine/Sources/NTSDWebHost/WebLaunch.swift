import Foundation
import NTSDCore
import NTSDRuntime

// `NTSDWeb [--screen W H] [--caption N] [--music-dir DIR] [session options]`:
// the original game in a browser page (TVOS_WEB W2b). Built for
// wasm32-unknown-wasip1 and started in a worker by
// tools/crossplatform/web/wasi-worker.js, which provides the "ntsd" imports
// (the page's canvas, input and questions) beside WASI. The worker's main loop
// is the runtime's queue of deferred calls; its sleeps block the worker, never
// the page. A scripted run (`--script`) needs `--virtual-clock BASE STEP` and
// `--no-network`, as on the headless host.
public enum NTSDWebHost {
    /// Runs `game` in the page with these arguments (ENGINE_SPLIT E4b: the body
    /// of the former NTSDWeb main.swift); `defaultMusicDirectory` applies
    /// without `--music-dir`.
    public static func run(arguments: [String],game: OriginalGame,defaultMusicDirectory: @autoclosure () -> String) -> Never {
        func option(_ name: String,_ count: Int) -> [String]? {
            guard let i = arguments.firstIndex(of:name),i+count < arguments.count else { return nil }
            return Array(arguments[(i+1)...(i+count)])
        }
        if arguments.contains("--script"),!arguments.contains("--no-network") || option("--virtual-clock",2) == nil {
            FileHandle.standardError.write(Data("NTSDWeb --script needs --virtual-clock BASE STEP and --no-network\n".utf8))
            exit(2)
        }
        let screen = option("--screen",2).flatMap { w in Double(w[0]).flatMap { x in Double(w[1]).map { CGSize(width:x,height:$0) } } } ?? CGSize(width:3008,height:1692)
        let caption = option("--caption",1).flatMap { Double($0[0]) }.map { CGFloat($0) } ?? 32
        let musicDirectory = option("--music-dir",1)?[0] ?? defaultMusicDirectory()
        MainActor.assumeIsolated {
            let host = WebSessionHost(arguments:arguments,screen:screen,caption:caption,musicDirectory:musicDirectory,game:game)
            let session = OriginalRuntimeSession(arguments:arguments,host:host)
            host.session = session; retained = (host,session)
            session.start()
        }
        MainActor.assumeIsolated { OriginalMainQueue.run() }
        // The queue drains only after a stop (a quit ends the process in terminate):
        // end as a scripted boundary ends, not as a quit.
        if MainActor.assumeIsolated({ (retained?.1 as? OriginalRuntimeSession)?.stopped == true }) { exit(1) }
        exit(0)
    }
}
nonisolated(unsafe) private var retained: (AnyObject,AnyObject)?
