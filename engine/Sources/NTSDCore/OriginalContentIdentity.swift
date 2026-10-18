/// The exact content packages a game ships (ENGINE_SPLIT E2): the reference EXE
/// they were made from, each package's manifest digest and the counts its
/// manifest must declare. The loaders check a package against the identity the
/// game supplies with its OriginalContentLocation; the names the EXE loads, the
/// manifest format and the global record's layout stay the engine's. The engine
/// still models one EXE (globals at 0x44d000, its load lists), so `exeSHA256`
/// must name that EXE until a game profile (E5) describes another.
public struct OriginalContentIdentity: Equatable, Sendable {
    public struct Catalog: Equatable, Sendable {
        public let manifestSHA256: String
        /// Manifest entries (unique paths and names), then the file, bitmap and music roles.
        public let entries: Int, files: Int, bitmaps: Int, music: Int
        public init(manifestSHA256: String,entries: Int,files: Int,bitmaps: Int,music: Int) {
            self.manifestSHA256 = manifestSHA256; self.entries = entries; self.files = files; self.bitmaps = bitmaps; self.music = music
        }
    }
    public struct Startup: Equatable, Sendable {
        public let manifestSHA256: String
        /// Manifest entries, and the startup files the package declares absent.
        public let entries: Int, absentFiles: [String]
        public init(manifestSHA256: String,entries: Int,absentFiles: [String]) {
            self.manifestSHA256 = manifestSHA256; self.entries = entries; self.absentFiles = absentFiles
        }
    }
    public let exeSHA256: String
    public let catalog: Catalog, startup: Startup
    public let loadingManifestSHA256: String, interfaceManifestSHA256: String, menuManifestSHA256: String
    public let warMenuManifestSHA256: String, arenaManifestSHA256: String

    public init(exeSHA256: String,catalog: Catalog,startup: Startup,loadingManifestSHA256: String,interfaceManifestSHA256: String,
                menuManifestSHA256: String,warMenuManifestSHA256: String,arenaManifestSHA256: String) {
        self.exeSHA256 = exeSHA256; self.catalog = catalog; self.startup = startup
        self.loadingManifestSHA256 = loadingManifestSHA256; self.interfaceManifestSHA256 = interfaceManifestSHA256
        self.menuManifestSHA256 = menuManifestSHA256; self.warMenuManifestSHA256 = warMenuManifestSHA256
        self.arenaManifestSHA256 = arenaManifestSHA256
    }
}
