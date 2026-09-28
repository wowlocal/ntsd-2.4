import Foundation
import CryptoKit

/// Original catalog/media bytes acquired before a Core attempt. Device replies,
/// decoded DAT state and comparison records are not part of this package.
public struct OriginalApplicationCatalogInputs: Equatable {
    public enum Boundary: Error, Equatable { case missing(String), invalid(String), unsupportedName(String) }
    public static let manifestSHA256 = "fd42d041549f00f5ba715063d7e560a9e2b01ab720017d1da5e032c34ca9451d"
    private struct Manifest: Decodable {
        struct Entry: Decodable {
            let name: String, kind: String, path: String, count: Int, sha256: String
        }
        let version: Int, exeSHA256: String, entries: [Entry]
    }
    public let files: [String:[UInt8]]
    public let bitmaps: [String:OriginalApplicationStartupInputs.Bitmap]
    public let music: [String:[UInt8]]
    private let fileNames: Set<String>

    public static func bundled(in appBundle: Bundle = .main) throws -> Self {
        try load(directory:bundledDirectory(in:appBundle))
    }
    public static func bundledDirectory(in appBundle: Bundle = .main) throws -> URL {
        if let resources = appBundle.resourceURL {
            let directory = resources.appendingPathComponent("OriginalCatalog",isDirectory:true)
            if appBundle.bundleURL.pathExtension == "app" || FileManager.default.fileExists(atPath:directory.path) {
                return directory
            }
        }
        guard let directory = Bundle.module.url(forResource:"OriginalCatalog",withExtension:nil) else {
            throw Boundary.missing("OriginalCatalog bundle resource")
        }
        return directory
    }
    public static func load(directory: URL) throws -> Self {
        let fm = FileManager.default
        guard fm.fileExists(atPath:directory.path) else { throw Boundary.missing("OriginalCatalog") }
        let root = try directory.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
        guard root.isDirectory == true,root.isSymbolicLink != true else { throw Boundary.invalid("Package root") }
        func read(_ path: String, count: Int? = nil) throws -> [UInt8] {
            var url = directory
            let parts = path.split(separator:"/",omittingEmptySubsequences:false)
            guard !parts.isEmpty,!path.contains("\\"),parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
                throw Boundary.invalid("Package path")
            }
            for (i,part) in parts.enumerated() {
                url.appendPathComponent(String(part))
                guard fm.fileExists(atPath:url.path) else { throw Boundary.missing(path) }
                let v = try url.resourceValues(forKeys:[.isDirectoryKey,.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
                guard v.isSymbolicLink != true else { throw Boundary.invalid(path) }
                if i+1 == parts.count {
                    guard v.isRegularFile == true,let size = v.fileSize,
                          size <= (count ?? 2_097_152),count == nil || size == count else { throw Boundary.invalid(path) }
                } else if v.isDirectory != true { throw Boundary.invalid(path) }
            }
            return Array(try Data(contentsOf:url))
        }
        func digest(_ bytes: [UInt8]) -> String { SHA256.hash(data:Data(bytes)).map { String(format:"%02x",$0) }.joined() }
        let raw = try read("manifest.json")
        guard digest(raw) == manifestSHA256 else { throw Boundary.invalid("Manifest digest") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:Data(raw))
        guard manifest.version == 1,manifest.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              manifest.entries.count == 1198,Set(manifest.entries.map(\.path)).count == 1198,
              Set(manifest.entries.map(\.name)).count == 1198 else { throw Boundary.invalid("Manifest contract") }
        let rootPath = directory.standardizedFileURL.resolvingSymlinksInPath().path
        var expectedDirectories = Set<String>()
        for e in manifest.entries {
            let parts = e.path.split(separator:"/")
            for end in 1..<parts.count { expectedDirectories.insert(parts.prefix(end).joined(separator:"/")) }
        }
        var actualFiles = Set<String>(),actualDirectories = Set<String>()
        var enumerationError: Error?
        guard let iterator = fm.enumerator(at:directory,includingPropertiesForKeys:[.isDirectoryKey,.isRegularFileKey,.isSymbolicLinkKey],errorHandler:{ _,error in
            enumerationError = error;return false
        }) else { throw Boundary.missing("Package directory") }
        for case let url as URL in iterator {
            let v = try url.resourceValues(forKeys:[.isDirectoryKey,.isRegularFileKey,.isSymbolicLinkKey])
            guard v.isSymbolicLink != true else { throw Boundary.invalid("Package symlink") }
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard path.hasPrefix(rootPath+"/") else { throw Boundary.invalid("Package root") }
            let name = String(path.dropFirst(rootPath.count+1))
            if v.isDirectory == true { actualDirectories.insert(name) }
            else if v.isRegularFile == true { actualFiles.insert(name) }
            else { throw Boundary.invalid("Nonregular package member") }
        }
        if let error = enumerationError { throw error }
        guard actualFiles == Set(manifest.entries.map(\.path)).union(["manifest.json"]),actualDirectories == expectedDirectories else {
            throw Boundary.invalid("Package composition")
        }
        var files: [String:[UInt8]] = [:],bitmaps: [String:OriginalApplicationStartupInputs.Bitmap] = [:],music: [String:[UInt8]] = [:]
        for e in manifest.entries {
            guard (0...100_000_000).contains(e.count) else { throw Boundary.invalid("Input extent") }
            let bytes = try read(e.path,count:e.count)
            guard bytes.count == e.count,digest(bytes) == e.sha256 else { throw Boundary.invalid(e.name) }
            switch e.kind {
            case "file": files[e.name] = bytes
            case "bitmapFile": bitmaps[e.name] = try .init(bitmapFile:bytes)
            case "dib": bitmaps[e.name] = try .init(dib:bytes)
            case "music": music[e.name] = bytes
            default: throw Boundary.invalid("Input role")
            }
        }
        guard files.count == 521,bitmaps.count == 669,music.count == 8 else { throw Boundary.invalid("Input roles") }
        return .init(files:files,bitmaps:bitmaps,music:music,fileNames:Set(files.keys))
    }
    public func file(_ name: String) throws -> [UInt8]? {
        guard fileNames.contains(name) else { throw Boundary.unsupportedName(name) }
        return files[name]
    }
    public func musicFile(_ name: String) throws -> [UInt8] {
        guard let bytes = music[name] else { throw Boundary.unsupportedName(name) }
        return bytes
    }
    /// A separate declared resource overlay; no writes to the bundle or source.
    public func replacingFile(_ name: String,with bytes: [UInt8]?) throws -> Self {
        guard fileNames.contains(name) else { throw Boundary.unsupportedName(name) }
        var changed = files;changed[name] = bytes
        return .init(files:changed,bitmaps:bitmaps,music:music,fileNames:fileNames)
    }
}
