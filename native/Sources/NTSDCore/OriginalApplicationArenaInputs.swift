import Foundation
import CryptoKit

/// Original deferred arena BMP files. Currently the pinned District package;
/// other arenas can supply their ordinary file inputs to the same launch API.
/// Loading this package performs no game logic or platform bitmap requests.
public struct OriginalApplicationArenaInputs {
    public let bitmaps: [String:OriginalApplicationStartupInputs.Bitmap]
    public static let manifestSHA256 = "1e52d2fabb7eeedd9b9dd5ed3df1c70a8112091109107d98917e2b93144824fd"
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
        func digest(_ bytes: Data) -> String { SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined() }
        func read(_ path: String) throws -> Data {
            guard !path.hasPrefix("/"),!path.split(separator:"/").contains("..") else { throw error("Relative file path") }
            let url = directory.appendingPathComponent(path),values = try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
            guard values.isRegularFile == true,values.isSymbolicLink != true else { throw error("Ordinary packaged file") }
            return try Data(contentsOf:url)
        }
        let data = try read("manifest.json")
        guard digest(data) == manifestSHA256 else { throw error("Manifest digest") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:data)
        guard manifest.version == 1,manifest.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c" else { throw error("Reference identity") }
        var bitmaps: [String:OriginalApplicationStartupInputs.Bitmap] = [:]
        for item in manifest.entries {
            let bytes = try read(item.path)
            guard item.name == item.path.replacingOccurrences(of:"/",with:"\\"),bitmaps[item.name] == nil,
                  bytes.count == item.bytes,digest(bytes) == item.sha256 else { throw error(item.path) }
            bitmaps[item.name] = try .init(bitmapFile:Array(bytes))
        }
        return .init(bitmaps:bitmaps)
    }
}
