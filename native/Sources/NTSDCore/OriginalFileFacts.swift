import Foundation
#if os(Windows)
import WinSDK
#endif

/// The file facts the package input loaders check (directory, regular file,
/// symbolic link, size), with `URLResourceValues`' optional semantics. Other
/// hosts read them through `resourceValues(forKeys:)` with the caller's keys,
/// exactly as before. Windows reads GetFileAttributesExW instead: Foundation
/// there derives every attribute for any key, including the executable bit
/// through SaferiIsExecutableFileType, which Wine (the Windows test harness)
/// lacks; a reparse point counts as a symbolic link.
struct OriginalFileFacts {
    let isDirectory: Bool?, isRegularFile: Bool?, isSymbolicLink: Bool?, fileSize: Int?

    static func of(_ url: URL,_ keys: Set<URLResourceKey>) throws -> OriginalFileFacts {
        #if os(Windows)
        var data = WIN32_FILE_ATTRIBUTE_DATA()
        let path = url.withUnsafeFileSystemRepresentation { $0.map { String(cString:$0) } } ?? url.path
        let found = path.withCString(encodedAs:UTF16.self) { GetFileAttributesExW($0,GetFileExInfoStandard,&data) }
        guard found != false else { throw CocoaError(.fileReadNoSuchFile,userInfo:[NSFilePathErrorKey:url.path]) }
        let directory = data.dwFileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0
        let reparse = data.dwFileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0
        let size = Int(UInt64(data.nFileSizeHigh) << 32 | UInt64(data.nFileSizeLow))
        return .init(isDirectory:keys.contains(.isDirectoryKey) ? directory && !reparse : nil,
                     isRegularFile:keys.contains(.isRegularFileKey) ? !directory && !reparse : nil,
                     isSymbolicLink:keys.contains(.isSymbolicLinkKey) ? reparse : nil,
                     fileSize:keys.contains(.fileSizeKey) && !directory && !reparse ? size : nil)
        #else
        let v = try url.resourceValues(forKeys:keys)
        return .init(isDirectory:v.isDirectory,isRegularFile:v.isRegularFile,isSymbolicLink:v.isSymbolicLink,fileSize:v.fileSize)
        #endif
    }
}
