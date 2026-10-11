import Foundation
#if os(Windows)
import WinSDK
#elseif canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

/// The file facts the package input loaders check (directory, regular file,
/// symbolic link, size), with `URLResourceValues`' optional semantics. Darwin
/// reads them through `resourceValues(forKeys:)` with the caller's keys, Linux
/// and Android through lstat (`posix`, MEMORY_LOADING L17). Windows reads GetFileAttributesExW instead: Foundation
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
        #elseif os(Linux) || os(Android)
        return try posix(url,keys)
        #else
        let v = try url.resourceValues(forKeys:keys)
        return .init(isDirectory:v.isDirectory,isRegularFile:v.isRegularFile,isSymbolicLink:v.isSymbolicLink,fileSize:v.fileSize)
        #endif
    }
    /// `FileManager.default.fileExists(atPath:url.path)`: stat, following links.
    static func exists(_ url: URL) -> Bool {
        #if os(Linux) || os(Android)
        return posixExists(url)
        #else
        return FileManager.default.fileExists(atPath:url.path)
        #endif
    }
    #if !os(Windows)
    /// lstat's answer with the semantics the loaders read from
    /// `resourceValues` (the entry itself, not a link's target; the size of a
    /// regular file: no caller reads another's), on Linux and Android, where
    /// `resourceValues` builds a whole attribute dictionary per call: ~1.8 ms
    /// per packaged file on the A12, a fifth of the read-ahead's work
    /// (MEMORY_LOADING L17). When lstat fails, `resourceValues` answers, so a
    /// failure throws its own error. Compiled on every POSIX host, so the Mac
    /// tests compare it with `resourceValues`.
    static func posix(_ url: URL,_ keys: Set<URLResourceKey>) throws -> OriginalFileFacts {
        var info = stat()
        let found = url.withUnsafeFileSystemRepresentation { path in path.map { lstat($0,&info) == 0 } ?? false }
        guard found else {
            let v = try url.resourceValues(forKeys:keys)
            return .init(isDirectory:v.isDirectory,isRegularFile:v.isRegularFile,isSymbolicLink:v.isSymbolicLink,fileSize:v.fileSize)
        }
        let type = Int(info.st_mode) & Int(S_IFMT)
        return .init(isDirectory:keys.contains(.isDirectoryKey) ? type == Int(S_IFDIR) : nil,
                     isRegularFile:keys.contains(.isRegularFileKey) ? type == Int(S_IFREG) : nil,
                     isSymbolicLink:keys.contains(.isSymbolicLinkKey) ? type == Int(S_IFLNK) : nil,
                     fileSize:keys.contains(.fileSizeKey) && type == Int(S_IFREG) ? Int(exactly:info.st_size) : nil)
    }
    static func posixExists(_ url: URL) -> Bool {
        var info = stat()
        return url.withUnsafeFileSystemRepresentation { path in path.map { stat($0,&info) == 0 } ?? false }
    }
    #endif
}
