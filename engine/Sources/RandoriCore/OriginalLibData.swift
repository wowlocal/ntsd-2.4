/// The bundled lib.dll's extensions to LF2 2.0a (ENGINE_SPLIT E6d). NTSD 2.4.exe
/// is LF2 2.0a's lf2.exe plus a loader for lib.dll, whose twelve jumps and
/// two-byte patch (docs/research/LIB_RUNTIME.md) the engine implements as its
/// library paths. The application's sessions are modelled only with the
/// library so far: they read this value at their entries and, without it, stop
/// with `Required` (the input session keeps the word-1 path instead of the
/// library's commands). The passes choose their paths from their own arguments
/// (`bundledLibrary`, `Library?`, `libraryCommands`), not from this value.
public struct OriginalLibData: Equatable, Sendable {
    /// The labels lib.dll's loading routine (424352 -> 10001236) draws at 608,60,
    /// one per colour branch of the signed phase remainder (LIB_LOADING): DLL data
    /// 10003040 (below 2, negative ones included, 00ffffff), 1000304e (5-7, 00000099) and 1000305c (the
    /// others, 000000ff). The game's text (E6d-2); the colours stay the library's code.
    public struct LoadingLabels: Equatable, Sendable {
        public let belowTwo: [UInt8], fiveToSeven: [UInt8], others: [UInt8]
        public init(belowTwo: [UInt8], fiveToSeven: [UInt8], others: [UInt8]) {
            self.belowTwo = belowTwo; self.fiveToSeven = fiveToSeven; self.others = others
        }
    }
    public let loadingLabels: LoadingLabels
    public init(loadingLabels: LoadingLabels) { self.loadingLabels = loadingLabels }
    /// A session path modelled only with the library: the typed boundary a
    /// game without it reaches instead of unverified behaviour.
    public struct Required: Error, Equatable, Sendable {
        public let site: String
        public init(site: String) { self.site = site }
    }
}
