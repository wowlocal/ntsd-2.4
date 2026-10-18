import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Immutable embedded game DIBs. Package IO completes before the tentative pool
/// continuation; expected pixels, EXE execution and platform writes are absent.
public struct OriginalApplicationInterfaceInputs: Equatable {
    public enum Boundary: Error, Equatable { case missing(String), invalid(String) }
    public let bitmaps: [String:OriginalApplicationStartupInputs.Bitmap]
    private struct Manifest: Decodable {
        struct Entry: Decodable { let name: String,path: String,count: Int,sha256: String }
        let version: Int,exeSHA256: String,entries: [Entry]
    }
    public static func bundledDirectory(in content: OriginalContentLocation) throws -> URL {
        guard let directory = content.directory("OriginalLoadingInterface") else {
            throw Boundary.missing("OriginalLoadingInterface")
        }
        return directory
    }
    public static func bundled(in content: OriginalContentLocation) throws -> Self { try load(directory:bundledDirectory(in:content),identity:content.identity) }
    public static func load(directory: URL,identity: OriginalContentIdentity) throws -> Self {
        func read(_ path: String) throws -> Data {
            let url = directory.appendingPathComponent(path)
            guard OriginalFileFacts.exists(url) else { throw Boundary.missing(path) }
            let v = try OriginalFileFacts.of(url,[.isRegularFileKey,.isSymbolicLinkKey])
            guard v.isRegularFile == true,v.isSymbolicLink != true else { throw Boundary.invalid(path) }
            return try Data(contentsOf:url)
        }
        func digest(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
        let data = try read("manifest.json")
        guard digest(data) == identity.interfaceManifestSHA256 else { throw Boundary.invalid("Manifest digest") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:data)
        guard manifest.version == 1,
              manifest.exeSHA256 == identity.exeSHA256,
              manifest.entries.map(\.name) == OriginalInitialInterfaceLoading.paths else { throw Boundary.invalid("Manifest contract") }
        var bitmaps: [String:OriginalApplicationStartupInputs.Bitmap] = [:]
        for entry in manifest.entries {
            guard entry.path == entry.name+".dib" else { throw Boundary.invalid("Resource path") }
            let bytes = try read(entry.path)
            guard bytes.count == entry.count,digest(bytes) == entry.sha256 else { throw Boundary.invalid(entry.path) }
            bitmaps[entry.name] = try .init(dib:Array(bytes))
        }
        let actual = try FileManager.default.contentsOfDirectory(atPath:directory.path)
        guard Set(actual) == Set(manifest.entries.map(\.path)).union(["manifest.json"]) else { throw Boundary.invalid("Package composition") }
        return .init(bitmaps:bitmaps)
    }
}
