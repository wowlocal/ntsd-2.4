/// The bundled lib.dll's extensions to LF2 2.0a (ENGINE_SPLIT E6d). NTSD 2.4.exe
/// is LF2 2.0a's lf2.exe plus a loader for lib.dll, whose twelve jumps and
/// two-byte patch (docs/research/LIB_RUNTIME.md) the engine implements as its
/// library paths. The application's sessions are modelled only with the
/// library so far: they read this value at their entries and, without it, stop
/// with `Required` (the input session keeps the word-1 path instead of the
/// library's commands). The passes choose their paths from their own arguments
/// (`bundledLibrary`, `Library?`, `libraryCommands`), not from this value.
public struct OriginalLibData: Equatable, Sendable {
    public init() {}
    /// A session path modelled only with the library: the typed boundary a
    /// game without it reaches instead of unverified behaviour.
    public struct Required: Error, Equatable, Sendable {
        public let site: String
        public init(site: String) { self.site = site }
    }
}
