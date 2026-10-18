import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Original deferred arena BMP files of all 17 registered backgrounds
/// (tools/package_match_arenas.py); the launch reads the selected one's.
/// Loading this package performs no game logic or platform bitmap requests.
public struct OriginalApplicationArenaInputs {
    public let bitmaps: [String:OriginalApplicationStartupInputs.Bitmap]
    private struct Manifest: Decodable {
        struct Entry: Decodable { let name: String,path: String,bytes: Int,sha256: String }
        let version: Int,exeSHA256: String,entries: [Entry]
    }
    public static func bundled(in content: OriginalContentLocation) throws -> Self {
        guard let directory = content.directory("OriginalMatchArenas") else {
            throw OriginalStateError.invalidStorage("Missing arena input package")
        }
        return try load(directory:directory,identity:content.identity)
    }
    public static func load(directory: URL,identity: OriginalContentIdentity) throws -> Self {
        func error(_ text: String) -> OriginalStateError { .invalidStorage("Arena inputs: "+text) }
        func digest(_ bytes: Data) -> String { OriginalConcurrentInputs.hex(SHA256.hash(data:bytes)) }
        func read(_ path: String) throws -> Data {
            guard !path.hasPrefix("/"),!path.split(separator:"/").contains("..") else { throw error("Relative file path") }
            let url = directory.appendingPathComponent(path),values = try OriginalFileFacts.of(url,[.isRegularFileKey,.isSymbolicLinkKey])
            guard values.isRegularFile == true,values.isSymbolicLink != true else { throw error("Ordinary packaged file") }
            return try Data(contentsOf:url)
        }
        /// The size `read` would return, after `read`'s own checks and errors.
        func size(_ path: String) throws -> Int? {
            guard !path.hasPrefix("/"),!path.split(separator:"/").contains("..") else { throw error("Relative file path") }
            let url = directory.appendingPathComponent(path)
            let values = try OriginalFileFacts.of(url,[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
            guard values.isRegularFile == true,values.isSymbolicLink != true else { throw error("Ordinary packaged file") }
            return values.fileSize
        }
        let data = try read("manifest.json")
        guard digest(data) == identity.arenaManifestSHA256 else { throw error("Manifest digest") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:data)
        guard manifest.version == 1,manifest.exeSHA256 == identity.exeSHA256 else { throw error("Reference identity") }
        // Each file is read, checked and decoded concurrently; the checks that
        // depend on earlier entries (name, duplicate) and every error keep the
        // manifest order: read error, then the guard, then the decode's. A file
        // whose facts or size are not as declared is left unread here and takes
        // the sequential path in manifest order, as before: a damaged package
        // cannot make every core read a huge file before the first error.
        enum Loaded { case unread,mismatch,decoded(Result<OriginalApplicationStartupInputs.Bitmap,Error>) }
        let loaded = OriginalConcurrentInputs.map(manifest.entries) { item -> Loaded in
            guard let size = try? size(item.path),size == item.bytes else { return .unread }
            let bytes = try read(item.path)
            guard bytes.count == item.bytes,digest(bytes) == item.sha256 else { return .mismatch }
            return .decoded(Result { try .init(bitmapFile:Array(bytes)) })
        }
        var bitmaps: [String:OriginalApplicationStartupInputs.Bitmap] = [:]
        for (item,result) in zip(manifest.entries,loaded) {
            let outcome = try result.get()
            if case .unread = outcome {
                let bytes = try read(item.path)
                guard item.name == item.path.replacingOccurrences(of:"/",with:"\\"),bitmaps[item.name] == nil,
                      bytes.count == item.bytes,digest(bytes) == item.sha256 else { throw error(item.path) }
                bitmaps[item.name] = try .init(bitmapFile:Array(bytes))
                continue
            }
            guard item.name == item.path.replacingOccurrences(of:"/",with:"\\"),bitmaps[item.name] == nil,
                  case .decoded(let bitmap) = outcome else { throw error(item.path) }
            bitmaps[item.name] = try bitmap.get()
        }
        return .init(bitmaps:bitmaps)
    }
}
