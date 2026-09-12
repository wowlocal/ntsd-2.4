/// The two recovered bitmap field lifetimes across War menu and preparation.
/// A menu descriptor supplies the later loader dimensions; the menu GetDC
/// output/result supplies the later copy dimensions. Preparation GetObject and
/// description writes then update these same fields. Preparation GetDC has a
/// different lifetime and does not replace them. This is a bounded caller
/// contract, not a model of a private stack or of other menu depths.
public struct OriginalWarBitmapScratch: Equatable, Sendable {
    public internal(set) var loaderDimensions: OriginalStateRecord?
    public internal(set) var copyDimensions: OriginalStateRecord?
    /// Source bytes remain defined after reuse by music call ABI. Their bitmap
    /// interpretation is no longer supported; this is not a source unknown mask.
    public internal(set) var loaderInvalidatedByPreparationMusicFormat = false
    public init() {}

    /// Uses only this owner's retained fields; new API request structures still
    /// begin unknown. Commit fields and buffered context together on success.
    public mutating func constructPreparationBitmap<Context>(path: String,optional: Bool,
        backing: [UInt8],device: UInt32,flags: UInt32,context: inout Context,
        perform: (OriginalBitmapSurfaceLoading.Request,inout Context) throws -> OriginalBitmapSurfaceLoading.Response) throws -> OriginalLoadedBitmap {
        var copy = try OriginalBitmapSurfaceLoading.CopyScratch()
        var loader = try OriginalBitmapSurfaceLoading.LoaderScratch()
        if let copyDimensions { copy.dimensions = copyDimensions }
        if let loaderDimensions { loader.dimensions = loaderDimensions }
        let bitmap = try OriginalBitmapConstructor.constructWithSurfaceLoading(path:path,optional:optional,
            backing:backing,device:device,flags:flags,context:&context,
            copyScratch:&copy,loaderScratch:&loader,perform:perform)
        copyDimensions = copy.dimensions
        // A missing image does not restore the expired field lifetime.
        if !loaderInvalidatedByPreparationMusicFormat || loader.dimensions.defined.contains(true) {
            loaderDimensions = loader.dimensions
        }
        if loader.dimensions.defined.allSatisfy({ $0 }) { loaderInvalidatedByPreparationMusicFormat = false }
        return bitmap
    }

    /// Preparation music reuses the loader field lifetime when it formats its
    /// graph log path. Observe the real operation; skipped or cached music does
    /// not cause this transition. Do not retain call arguments/return addresses
    /// as bitmap dimensions. A later loader needs its own new metadata writes.
    public mutating func resumePreparationMusic(globals: inout OriginalStateRecord,
        memory: inout OriginalMusicMemory,store: OriginalWindowInput.Store = { _,_ in },
        request: OriginalMusicPlayback.Request) throws {
        var candidate=self,state=globals,owned=memory
        try OriginalMusicPlayback.resumeMatch(globals:&state,memory:&owned,store:store) { event in
            if event.kind == .format,event.strings.first == Array("%s\\graph.log".utf8) {
                candidate.loaderDimensions=nil
                candidate.loaderInvalidatedByPreparationMusicFormat=true
            }
            return try request(event)
        }
        self=candidate;globals=state;memory=owned
    }
}
