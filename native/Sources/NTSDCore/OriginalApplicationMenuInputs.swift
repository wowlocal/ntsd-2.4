import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Immutable embedded game DIBs. Package IO completes before the tentative menu
/// continuation; expected pixels, EXE execution and platform writes are absent.
public struct OriginalApplicationMenuInputs: Equatable {
    public enum Boundary: Error, Equatable { case missing(String), invalid(String) }
    public static let manifestSHA256 = "f0c363739088e477c8b51b597374f29bccae9f63d7d09f7169128c57b01b1161"
    /// War setup bitmaps constructed by438b40 (tools/package_war_menu.py).
    public static let warManifestSHA256 = "784c222b2313833f37219eae36b2424a61d4d0f2f257e5aaff083a82aaa5406a"
    public static let warPaths = ["BATTLEMODE","BATTLETROOPS"]
    public let bitmaps: [String:OriginalApplicationStartupInputs.Bitmap]
    private struct Manifest: Decodable {
        struct Entry: Decodable { let name: String,path: String,count: Int,sha256: String }
        let version: Int,exeSHA256: String,entries: [Entry]
    }
    public static func bundledDirectory(_ name: String = "OriginalCharacterMenu",in appBundle: Bundle = .main) throws -> URL {
        if let resources = appBundle.resourceURL {
            let directory = resources.appendingPathComponent(name,isDirectory:true)
            if appBundle.bundleURL.pathExtension == "app" || FileManager.default.fileExists(atPath:directory.path) { return directory }
        }
        guard let directory = Bundle.module.url(forResource:name,withExtension:nil) else {
            throw Boundary.missing(name)
        }
        return directory
    }
    public static func bundled(in appBundle: Bundle = .main) throws -> Self { try load(directory:bundledDirectory(in:appBundle)) }
    /// Character-menu and War-menu DIBs as one resource set for the loaded menu.
    public static func bundledWithWar(in appBundle: Bundle = .main) throws -> Self {
        let menu = try bundled(in:appBundle)
        let war = try load(directory:bundledDirectory("OriginalWarMenu",in:appBundle),manifest:warManifestSHA256,names:warPaths)
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
    public static func load(directory: URL,manifest manifestDigest: String = manifestSHA256,
                            names: [String] = OriginalMenuResourceLoading.paths) throws -> Self {
        func read(_ path: String) throws -> Data {
            let url = directory.appendingPathComponent(path)
            guard FileManager.default.fileExists(atPath:url.path) else { throw Boundary.missing(path) }
            let v = try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
            guard v.isRegularFile == true,v.isSymbolicLink != true else { throw Boundary.invalid(path) }
            return try Data(contentsOf:url)
        }
        func digest(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
        let data = try read("manifest.json")
        guard digest(data) == manifestDigest else { throw Boundary.invalid("Manifest digest") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:data)
        guard manifest.version == 1,
              manifest.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
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
