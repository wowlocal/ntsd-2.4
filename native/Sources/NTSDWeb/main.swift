import NTSDContent
import RandoriWebHost

// NTSD in the engine's browser host (ENGINE_SPLIT E4b); without --music-dir the
// page's /music mount.
RandoriWebHost.run(arguments:CommandLine.arguments,game:NTSDContent.runtimeGame,defaultMusicDirectory:"/music")
