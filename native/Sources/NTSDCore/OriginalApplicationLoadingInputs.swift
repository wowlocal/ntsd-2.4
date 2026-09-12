import Foundation
import CryptoKit

/// Immutable original common WAV bytes, acquired before the Core attempt.
/// Platform replies and loaded PCM/after-state never enter this resource package.
public struct OriginalApplicationLoadingInputs: Equatable {
    public enum Boundary: Error, Equatable { case missing(String), invalid(String), unsupportedName(String) }
    public static let manifestSHA256 = "b1a519e2db09f18aa0d2bbaf29aa44226fba6a04852f8a4062778ae7d8e8a2f3"
    private struct Manifest: Decodable {
        struct Entry: Decodable { let name: String,count: Int,sha256: String }
        let version: Int,exeSHA256: String,entries: [Entry]
    }
    private let files: [String:[UInt8]]
    public static func bundled(in appBundle: Bundle = .main) throws -> Self {
        try load(directory:bundledDirectory(in:appBundle))
    }
    public static func bundledDirectory(in appBundle: Bundle = .main) throws -> URL {
        if let resources = appBundle.resourceURL {
            let directory = resources.appendingPathComponent("OriginalCommonSounds",isDirectory:true)
            if appBundle.bundleURL.pathExtension == "app" || FileManager.default.fileExists(atPath:directory.path) { return directory }
        }
        guard let directory = Bundle.module.url(forResource:"OriginalCommonSounds",withExtension:nil) else {
            throw Boundary.missing("OriginalCommonSounds bundle resource")
        }
        return directory
    }
    public static func load(directory: URL) throws -> Self {
        guard FileManager.default.fileExists(atPath:directory.path) else { throw Boundary.missing("OriginalCommonSounds") }
        let root = try directory.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
        guard root.isDirectory == true,root.isSymbolicLink != true else { throw Boundary.invalid("Package directory") }
        func read(_ name: String) throws -> [UInt8] {
            let url = directory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath:url.path) else { throw Boundary.missing(name) }
            let values = try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
            guard values.isRegularFile == true,values.isSymbolicLink != true else { throw Boundary.invalid(name) }
            return [UInt8](try Data(contentsOf:url))
        }
        func digest(_ bytes: [UInt8]) -> String { SHA256.hash(data:Data(bytes)).map { String(format:"%02x",$0) }.joined() }
        let raw = try read("manifest.json")
        guard digest(raw) == manifestSHA256 else { throw Boundary.invalid("Manifest digest") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:Data(raw))
        guard manifest.version == 1,manifest.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              manifest.entries.map(\.name) == OriginalInitialSoundLoading.paths else { throw Boundary.invalid("Manifest contract") }
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
        return .init(files:files)
    }
    public func file(_ name: String) throws -> [UInt8] {
        guard let bytes = files[name] else { throw Boundary.unsupportedName(name) }
        return bytes
    }
}
