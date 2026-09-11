/// The inline40c114..40c125 arena-layer release: surface Release, then wrapper
/// free, ignoring the numeric Release result. Tokens come from retained native
/// resource owners. The enclosing caller buffers platform effects until commit.
public enum OriginalBitmapRelease {
    public static func release<Context>(_ bitmap: OriginalLoadedBitmap,
        wrapper: UInt32, surface: UInt32, context: inout Context,
        perform: (OriginalBitmapSurfaceLoading.Request,inout Context) throws -> OriginalBitmapSurfaceLoading.Response) throws {
        guard wrapper != 0,surface != 0,
              try bitmap.storage.integer(at:0,as:UInt32.self)==1 else {
            throw OriginalStateError.invalidStorage("Arena bitmap release ownership")
        }
        var candidate=context
        _ = try perform(.init("release",[surface]),&candidate)
        _ = try perform(.init("free",[wrapper]),&candidate)
        context=candidate
    }
}
