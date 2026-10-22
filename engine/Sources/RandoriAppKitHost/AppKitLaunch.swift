import AppKit
import RandoriCore

/// The AppKit host (ENGINE_SPLIT E4b): `--original` on macOS, the portable
/// OriginalRuntimeSession on AppKit windows, AVFoundation output, GameController
/// joysticks and Darwin sockets.
public enum RandoriAppKitHost {
    /// Runs `game` as a Mac app with these arguments (the former runtime branch
    /// of NTSDApp's main.swift).
    public static func run(arguments: [String],game: OriginalGame) -> Never {
        let app = NSApplication.shared; app.setActivationPolicy(.regular)
        let delegate = OriginalRuntimeDelegate(arguments:arguments,game:game,exitAfterStartup:arguments.contains("--exit-after-startup"))
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
        exit(0)
    }
}
