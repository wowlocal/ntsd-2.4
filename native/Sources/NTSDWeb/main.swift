import Foundation
import NTSDRuntime

// `NTSDWeb --script "…" --virtual-clock BASE STEP --no-network [--screen W H]
//  [--caption N] [--music-dir DIR] [session options]`: the original game in a
// browser page (TVOS_WEB W2b). Built for wasm32-unknown-wasip1 and started in
// a worker by tools/crossplatform/web/wasi-worker.js, which provides the
// "ntsd" imports (the page's canvas) beside WASI. The worker's main loop is
// the runtime's queue of deferred calls; its sleeps block the worker, never
// the page. Scripted runs only until the page gives input, message boxes and
// storage (the next steps), as the headless host.
let arguments = CommandLine.arguments
nonisolated(unsafe) var retained: (AnyObject,AnyObject)?
func option(_ name: String,_ count: Int) -> [String]? {
    guard let i = arguments.firstIndex(of:name),i+count < arguments.count else { return nil }
    return Array(arguments[(i+1)...(i+count)])
}
guard arguments.contains("--script"),arguments.contains("--no-network"),option("--virtual-clock",2) != nil else {
    FileHandle.standardError.write(Data("NTSDWeb needs --script, --virtual-clock BASE STEP and --no-network until the page gives input\n".utf8))
    exit(2)
}
let screen = option("--screen",2).flatMap { w in Double(w[0]).flatMap { x in Double(w[1]).map { CGSize(width:x,height:$0) } } } ?? CGSize(width:3008,height:1692)
let caption = option("--caption",1).flatMap { Double($0[0]) }.map { CGFloat($0) } ?? 32
let musicDirectory = option("--music-dir",1)?[0] ?? "/music"
MainActor.assumeIsolated {
    let host = WebSessionHost(arguments:arguments,screen:screen,caption:caption,musicDirectory:musicDirectory)
    let session = OriginalRuntimeSession(arguments:arguments,host:host)
    host.session = session; retained = (host,session)
    session.start()
}
MainActor.assumeIsolated { OriginalMainQueue.run() }
