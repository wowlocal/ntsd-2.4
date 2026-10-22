import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Immutable original common WAV bytes, acquired before the Core attempt.
/// Platform replies and loaded PCM/after-state never enter this resource package.
public struct OriginalApplicationLoadingInputs: Equatable {
    public enum Boundary: Error, Equatable { case missing(String), invalid(String), unsupportedName(String) }
    private struct Manifest: Decodable {
        struct Entry: Decodable { let name: String,count: Int,sha256: String }
        let version: Int,exeSHA256: String,entries: [Entry]
    }
    private let files: [String:[UInt8]]
    /// The game's rules, from the content identity (ENGINE_SPLIT E5f-2a: the
    /// common WAVs' names come from `rules.interface.commonSounds`).
    public let rules: OriginalGameRules
    public static func bundled(in content: OriginalContentLocation) throws -> Self {
        try load(directory:bundledDirectory(in:content),identity:content.identity)
    }
    public static func bundledDirectory(in content: OriginalContentLocation) throws -> URL {
        guard let directory = content.directory("OriginalCommonSounds") else {
            throw Boundary.missing("OriginalCommonSounds bundle resource")
        }
        return directory
    }
    public static func load(directory: URL,identity: OriginalContentIdentity) throws -> Self {
        guard FileManager.default.fileExists(atPath:directory.path) else { throw Boundary.missing("OriginalCommonSounds") }
        let root = try OriginalFileFacts.of(directory,[.isDirectoryKey,.isSymbolicLinkKey])
        guard root.isDirectory == true,root.isSymbolicLink != true else { throw Boundary.invalid("Package directory") }
        func read(_ name: String) throws -> [UInt8] {
            let url = directory.appendingPathComponent(name)
            guard OriginalFileFacts.exists(url) else { throw Boundary.missing(name) }
            let values = try OriginalFileFacts.of(url,[.isRegularFileKey,.isSymbolicLinkKey])
            guard values.isRegularFile == true,values.isSymbolicLink != true else { throw Boundary.invalid(name) }
            return [UInt8](try Data(contentsOf:url))
        }
        func digest(_ bytes: [UInt8]) -> String { SHA256.hash(data:Data(bytes)).map { String(format:"%02x",$0) }.joined() }
        let raw = try read("manifest.json")
        guard digest(raw) == identity.loadingManifestSHA256 else { throw Boundary.invalid("Manifest digest") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:Data(raw))
        guard manifest.version == 1,manifest.exeSHA256 == identity.exeSHA256,
              manifest.entries.map(\.name) == identity.rules.interface.commonSounds else { throw Boundary.invalid("Manifest contract") }
        var files: [String:[UInt8]] = [:],names = Set(["manifest.json"])
        for item in manifest.entries {
            let filename = String(item.name.dropFirst(5))
            guard !filename.contains("/"),!filename.contains("\\"),names.insert(filename).inserted else { throw Boundary.invalid("Package name") }
            let bytes = try read(filename)
            guard bytes.count == item.count,digest(bytes) == item.sha256 else { throw Boundary.invalid(item.name) }
            files[item.name] = bytes
        }
        let actual = try FileManager.default.contentsOfDirectory(atPath:directory.path)
        guard Set(actual) == names else { throw Boundary.invalid("Package composition") }
        return .init(files:files,rules:identity.rules)
    }
    public func file(_ name: String) throws -> [UInt8] {
        guard let bytes = files[name] else { throw Boundary.unsupportedName(name) }
        return bytes
    }
}
