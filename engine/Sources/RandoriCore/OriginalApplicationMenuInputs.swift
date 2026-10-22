import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Immutable embedded game DIBs. Package IO completes before the tentative menu
/// continuation; expected pixels, EXE execution and platform writes are absent.
public struct OriginalApplicationMenuInputs: Equatable {
    public enum Boundary: Error, Equatable { case missing(String), invalid(String) }
    public let bitmaps: [String:OriginalApplicationStartupInputs.Bitmap]
    private struct Manifest: Decodable {
        struct Entry: Decodable { let name: String,path: String,count: Int,sha256: String }
        let version: Int,exeSHA256: String,entries: [Entry]
    }
    public static func bundledDirectory(_ name: String = "OriginalCharacterMenu",in content: OriginalContentLocation) throws -> URL {
        guard let directory = content.directory(name) else {
            throw Boundary.missing(name)
        }
        return directory
    }
    public static func bundled(in content: OriginalContentLocation) throws -> Self { try load(directory:bundledDirectory(in:content),identity:content.identity) }
    /// Character-menu and War-menu DIBs as one resource set for the loaded menu.
    public static func bundledWithWar(in content: OriginalContentLocation) throws -> Self {
        let menu = try bundled(in:content)
        let war = try load(directory:bundledDirectory("OriginalWarMenu",in:content),identity:content.identity,
                           manifest:content.identity.warMenuManifestSHA256,names:content.identity.rules.interface.warBitmaps)
        return .init(bitmaps:menu.bitmaps.merging(war.bitmaps) { a,_ in a })
    }
    /// These inputs plus other packaged bitmaps: War start (43a21f) loads the
    /// arena layers inside the menu call.
    public func adding(_ other: [String:OriginalApplicationStartupInputs.Bitmap]) throws -> Self {
        var next = bitmaps
        for (name,bitmap) in other {
            guard next[name] == nil || next[name] == bitmap else { throw Boundary.invalid("Bitmap conflict "+name) }
            next[name] = bitmap
        }
        return .init(bitmaps:next)
    }
    /// `manifest` defaults to the identity's character-menu digest, `names` to its
    /// rules' menu bitmaps (ENGINE_SPLIT E5f-2b).
    public static func load(directory: URL,identity: OriginalContentIdentity,manifest manifestDigest: String? = nil,
                            names suppliedNames: [String]? = nil) throws -> Self {
        let names = suppliedNames ?? identity.rules.interface.menuBitmaps
        func read(_ path: String) throws -> Data {
            let url = directory.appendingPathComponent(path)
            guard OriginalFileFacts.exists(url) else { throw Boundary.missing(path) }
            let v = try OriginalFileFacts.of(url,[.isRegularFileKey,.isSymbolicLinkKey])
            guard v.isRegularFile == true,v.isSymbolicLink != true else { throw Boundary.invalid(path) }
            return try Data(contentsOf:url)
        }
        func digest(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
        let data = try read("manifest.json")
        guard digest(data) == (manifestDigest ?? identity.menuManifestSHA256) else { throw Boundary.invalid("Manifest digest") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:data)
        guard manifest.version == 1,
              manifest.exeSHA256 == identity.exeSHA256,
              manifest.entries.map(\.name) == names else { throw Boundary.invalid("Manifest contract") }
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
