import Foundation

/// Resource keys to prefetch while enumerating a package directory. Prefetching
/// is only a performance hint: callers read every value they use through
/// `resourceValues(forKeys:)`. On Windows the hint is dropped, because
/// Foundation's enumerator then derives extra attributes through
/// SaferiIsExecutableFileType, which Wine (the Windows test harness) lacks.
enum OriginalDirectoryPrefetch {
    static func keys(_ keys: [URLResourceKey]) -> [URLResourceKey]? {
        #if os(Windows)
        return nil
        #else
        return keys
        #endif
    }
}
