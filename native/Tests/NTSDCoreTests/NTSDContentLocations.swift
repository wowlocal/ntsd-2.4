import Foundation
import NTSDCore
import NTSDContent
import NTSDRuntime
#if canImport(NTSDMacPlatform)
import NTSDMacPlatform
#endif

// ENGINE_SPLIT E1/E2: the engine finds content through OriginalContentLocation
// and checks it against an OriginalContentIdentity; these tests read NTSD's
// packages with their Bundle and directory arguments (default the main bundle)
// as before, the game's resource bundle being the fallback and NTSD 2.4's
// identity the one checked.
extension OriginalApplicationCatalogInputs {
    static func load(directory: URL) throws -> Self { try load(directory:directory,identity:NTSDContent.identity) }
    static func bundled(in appBundle: Bundle = .main) throws -> Self { try bundled(in:NTSDContent.location(in:appBundle)) }
    static func bundledDirectory(in appBundle: Bundle = .main) throws -> URL { try bundledDirectory(in:NTSDContent.location(in:appBundle)) }
}
extension OriginalApplicationStartupInputs {
    static func load(directory: URL) throws -> Self { try load(directory:directory,identity:NTSDContent.identity) }
    static func bundled(in appBundle: Bundle = .main) throws -> Self { try bundled(in:NTSDContent.location(in:appBundle)) }
    static func bundledDirectory(in appBundle: Bundle = .main) throws -> URL { try bundledDirectory(in:NTSDContent.location(in:appBundle)) }
}
extension OriginalApplicationLoadingInputs {
    static func load(directory: URL) throws -> Self { try load(directory:directory,identity:NTSDContent.identity) }
    static func bundled(in appBundle: Bundle = .main) throws -> Self { try bundled(in:NTSDContent.location(in:appBundle)) }
    static func bundledDirectory(in appBundle: Bundle = .main) throws -> URL { try bundledDirectory(in:NTSDContent.location(in:appBundle)) }
}
extension OriginalApplicationInterfaceInputs {
    static func load(directory: URL) throws -> Self { try load(directory:directory,identity:NTSDContent.identity) }
    static func bundled(in appBundle: Bundle = .main) throws -> Self { try bundled(in:NTSDContent.location(in:appBundle)) }
    static func bundledDirectory(in appBundle: Bundle = .main) throws -> URL { try bundledDirectory(in:NTSDContent.location(in:appBundle)) }
}
extension OriginalApplicationArenaInputs {
    static func load(directory: URL) throws -> Self { try load(directory:directory,identity:NTSDContent.identity) }
    static func bundled(in bundle: Bundle = .main) throws -> Self { try bundled(in:NTSDContent.location(in:bundle)) }
}
extension OriginalApplicationMenuInputs {
    static func load(directory: URL) throws -> Self { try load(directory:directory,identity:NTSDContent.identity) }
    static func bundledDirectory(_ name: String = "OriginalCharacterMenu",in appBundle: Bundle = .main) throws -> URL {
        try bundledDirectory(name,in:NTSDContent.location(in:appBundle))
    }
    static func bundled(in appBundle: Bundle = .main) throws -> Self { try bundled(in:NTSDContent.location(in:appBundle)) }
    static func bundledWithWar(in appBundle: Bundle = .main) throws -> Self { try bundledWithWar(in:NTSDContent.location(in:appBundle)) }
}
extension OriginalRuntimeLoadingPackages {
    init(in bundle: Bundle) { self.init(in:NTSDContent.location(in:bundle)) }
}
#if canImport(NTSDMacPlatform)
extension OriginalMacRuntimeLoading {
    static func bundled(_ started: OriginalMacRuntimeStartup.Started,startupInputs: OriginalApplicationStartupInputs,
        clock: @escaping () throws -> UInt32) throws -> OriginalMacRuntimeLoading {
        try bundled(started,startupInputs:startupInputs,clock:clock,in:NTSDContent.location())
    }
}
extension OriginalMacMusicOutput {
    static func directory(in appBundle: Bundle = .main) -> URL? { directory(in:NTSDContent.location(in:appBundle)) }
    static func bundled() throws -> OriginalMacMusicOutput { try bundled(in:NTSDContent.location()) }
}
#endif
