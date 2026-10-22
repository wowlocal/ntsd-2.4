import Foundation
import NTSDContent
import RandoriSDLHost

// NTSD on the engine's SDL3 host (ENGINE_SPLIT E4b); without --music-dir or the
// packaged OriginalMusic beside the executable, the source tree's tracks.
RandoriSDLHost.run(arguments:CommandLine.arguments,game:NTSDContent.runtimeGame,
                defaultMusicDirectory:URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
                    .appendingPathComponent("NTSDContent/Resources/OriginalMusic").path)
