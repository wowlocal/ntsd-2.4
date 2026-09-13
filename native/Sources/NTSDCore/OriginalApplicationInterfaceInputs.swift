import Foundation
import CryptoKit

/// Immutable embedded game DIBs. Package IO completes before the tentative pool
/// continuation; expected pixels, EXE execution and platform writes are absent.
public struct OriginalApplicationInterfaceInputs: Equatable {
    public enum Boundary: Error, Equatable { case missing(String), invalid(String) }
    public static let manifestSHA256 = "9f8cb29ac2546c0718e7c83541972b6e4589c64488ec057027b4fe4edd55af82"
    public let bitmaps: [String:OriginalApplicationStartupInputs.Bitmap]
    private struct Manifest: Decodable {
        struct Entry: Decodable { let name: String,path: String,count: Int,sha256: String }
        let version: Int,exeSHA256: String,entries: [Entry]
    }
    public static func bundledDirectory(in appBundle: Bundle = .main) throws -> URL {
        if let resources = appBundle.resourceURL {
            let directory = resources.appendingPathComponent("OriginalLoadingInterface",isDirectory:true)
            if appBundle.bundleURL.pathExtension == "app" || FileManager.default.fileExists(atPath:directory.path) { return directory }
        }
        guard let directory = Bundle.module.url(forResource:"OriginalLoadingInterface",withExtension:nil) else {
            throw Boundary.missing("OriginalLoadingInterface")
        }
        return directory
    }
    public static func bundled(in appBundle: Bundle = .main) throws -> Self { try load(directory:bundledDirectory(in:appBundle)) }
    public static func load(directory: URL) throws -> Self {
        func read(_ path: String) throws -> Data {
            let url = directory.appendingPathComponent(path)
            guard FileManager.default.fileExists(atPath:url.path) else { throw Boundary.missing(path) }
            let v = try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
            guard v.isRegularFile == true,v.isSymbolicLink != true else { throw Boundary.invalid(path) }
            return try Data(contentsOf:url)
        }
        func digest(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
        let data = try read("manifest.json")
        guard digest(data) == manifestSHA256 else { throw Boundary.invalid("Manifest digest") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:data)
        guard manifest.version == 1,
              manifest.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
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
