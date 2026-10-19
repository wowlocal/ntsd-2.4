import Foundation
import UIKit
import NTSDCore

/// The UIKit host (ENGINE_SPLIT E4b): the original game through
/// OriginalRuntimeSession on an iPad (P8, docs/research/CROSS_PLATFORM.md) or an
/// Apple TV (TVOS_WEB T0).
public enum NTSDUIKitHost {
    /// Runs `game` as the app (the former NTSDiOS main). Launch arguments are the
    /// session options (e.g. --script and --virtual-clock for scripted checks in
    /// the simulator). `--events-file PATH` sends the session's event lines
    /// (stdout) to a file: simctl does not reliably forward an app's stdout.
    public static func run(game: OriginalGame) -> Never {
        if let i = CommandLine.arguments.firstIndex(of:"--events-file"),i+1 < CommandLine.arguments.count {
            freopen(CommandLine.arguments[i+1],"w",stdout); setvbuf(stdout,nil,_IOLBF,0)
        }
        launchedGame = game
        _ = UIApplicationMain(CommandLine.argc,CommandLine.unsafeArgv,nil,NSStringFromClass(NTSDAppDelegate.self))
        exit(0)
    }
}

/// The game `run` was given, for the scene delegate UIKit creates.
nonisolated(unsafe) var launchedGame: OriginalGame?
