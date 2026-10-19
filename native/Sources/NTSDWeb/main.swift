import NTSDContent
import NTSDWebHost

// NTSD in the engine's browser host (ENGINE_SPLIT E4b); without --music-dir the
// page's /music mount.
NTSDWebHost.run(arguments:CommandLine.arguments,game:NTSDContent.runtimeGame,defaultMusicDirectory:"/music")
