import NTSDContent
import NTSDUIKitHost

// NTSDiOS (P8, docs/research/CROSS_PLATFORM.md): the original game on an iPad
// or Apple TV through the engine's UIKit host (ENGINE_SPLIT E4b), whose run
// documents the launch arguments.
NTSDUIKitHost.run(game: NTSDContent.runtimeGame)
