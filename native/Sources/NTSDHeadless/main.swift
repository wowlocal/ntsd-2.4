import Foundation
import NTSDContent
import NTSDHeadlessHost

// NTSD on the engine's headless host (ENGINE_SPLIT E4b); without --music-dir the
// source tree's packaged tracks.
NTSDHeadlessHost.run(arguments:CommandLine.arguments,game:NTSDContent.runtimeGame,
                     defaultMusicDirectory:URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
                         .appendingPathComponent("NTSDContent/Resources/OriginalMusic").path)
