import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Original deferred arena BMP files of all 17 registered backgrounds
/// (tools/package_match_arenas.py); the launch reads the selected one's.
/// Loading this package performs no game logic or platform bitmap requests.
public struct OriginalApplicationArenaInputs {
    public let bitmaps: [String:OriginalApplicationStartupInputs.Bitmap]
    public static let manifestSHA256 = "60652ed8df36c7ff0bbaa167dcf1dd7be07140dac766c529d275f0705fc40519"
    private struct Manifest: Decodable {
        struct Entry: Decodable { let name: String,path: String,bytes: Int,sha256: String }
        let version: Int,exeSHA256: String,entries: [Entry]
    }
    public static func bundled(in bundle: Bundle = .main) throws -> Self {
        if let resources = bundle.resourceURL {
            let directory = resources.appendingPathComponent("OriginalMatchArenas",isDirectory:true)
            if bundle.bundleURL.pathExtension == "app" || FileManager.default.fileExists(atPath:directory.path) {
                return try load(directory:directory)
            }
        }
        guard let directory = Bundle.module.url(forResource:"OriginalMatchArenas",withExtension:nil) else {
            throw OriginalStateError.invalidStorage("Missing arena input package")
        }
        return try load(directory:directory)
    }
    public static func load(directory: URL) throws -> Self {
        func error(_ text: String) -> OriginalStateError { .invalidStorage("Arena inputs: "+text) }
        func digest(_ bytes: Data) -> String { OriginalConcurrentInputs.hex(SHA256.hash(data:bytes)) }
        func read(_ path: String) throws -> Data {
            guard !path.hasPrefix("/"),!path.split(separator:"/").contains("..") else { throw error("Relative file path") }
            let url = directory.appendingPathComponent(path),values = try OriginalFileFacts.of(url,[.isRegularFileKey,.isSymbolicLinkKey])
            guard values.isRegularFile == true,values.isSymbolicLink != true else { throw error("Ordinary packaged file") }
            return try Data(contentsOf:url)
        }
        let data = try read("manifest.json")
        guard digest(data) == manifestSHA256 else { throw error("Manifest digest") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:data)
        guard manifest.version == 1,manifest.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c" else { throw error("Reference identity") }
        // Each file is read, checked and decoded concurrently; the checks that
        // depend on earlier entries (name, duplicate) and every error keep the
        // manifest order: read error, then the guard, then the decode's.
        enum Loaded { case mismatch,decoded(Result<OriginalApplicationStartupInputs.Bitmap,Error>) }
        let loaded = OriginalConcurrentInputs.map(manifest.entries) { item -> Loaded in
            let bytes = try read(item.path)
            guard bytes.count == item.bytes,digest(bytes) == item.sha256 else { return .mismatch }
            return .decoded(Result { try .init(bitmapFile:Array(bytes)) })
        }
        var bitmaps: [String:OriginalApplicationStartupInputs.Bitmap] = [:]
        for (item,result) in zip(manifest.entries,loaded) {
            let outcome = try result.get()
            guard item.name == item.path.replacingOccurrences(of:"/",with:"\\"),bitmaps[item.name] == nil,
                  case .decoded(let bitmap) = outcome else { throw error(item.path) }
            bitmaps[item.name] = try bitmap.get()
        }
        return .init(bitmaps:bitmaps)
    }
}
