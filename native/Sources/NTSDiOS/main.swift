import UIKit

// NTSDiOS (P8, docs/research/CROSS_PLATFORM.md): the original game through
// OriginalRuntimeSession on an iPad. Launch arguments are the session options
// (e.g. --script and --virtual-clock for scripted checks in the simulator).
// `--events-file PATH` sends the session's event lines (stdout) to a file:
// simctl does not reliably forward an app's stdout.
if let i = CommandLine.arguments.firstIndex(of:"--events-file"),i+1 < CommandLine.arguments.count {
    freopen(CommandLine.arguments[i+1],"w",stdout); setvbuf(stdout,nil,_IOLBF,0)
}
UIApplicationMain(CommandLine.argc,CommandLine.unsafeArgv,nil,NSStringFromClass(NTSDAppDelegate.self))
