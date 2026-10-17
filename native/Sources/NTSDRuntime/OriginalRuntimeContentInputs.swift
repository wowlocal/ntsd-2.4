import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
import NTSDCore

/// A session's immutable acquisition origin. This owns raw target bytes; it
/// supplies no inferred target globals, parser state, device replies or rules.
public final class OriginalRuntimeContentInputs {
    public enum Boundary: Error, Equatable, CustomStringConvertible {
        case missing(String), empty(String), corrupt(String), unsupportedName(String)
        case mixedOrigin, unsupportedTargetStartup, conflictingResources
        public var description: String {
            switch self {
            case .missing(let path): return "missing target input: \(path)"
            case .empty(let path): return "empty target input: \(path)"
            case .corrupt(let path): return "corrupt target input: \(path)"
            case .unsupportedName(let path): return "unsupported target input name: \(path)"
            case .mixedOrigin: return "startup/loading content origins differ"
            case .unsupportedTargetStartup: return "unsupported target startup contract (2.8.3.3)"
            case .conflictingResources: return "explicit content inputs conflict with --resources"
            }
        }
    }
    public static let targetManifestSHA256 = "c0ef67b9ee7d49b5efec4e98a3830395ecb8942136dd6e0784f66ac479688899"
    private struct Manifest: Decodable {
        struct Entry: Decodable { let path: String, count: Int, sha256: String }
        let version: Int, identity: String, partial: Bool, archiveSHA256: String, exeSHA256: String, entries: [Entry]
    }
    private enum Source {
        case baseline(Bundle)
        case target(files: [String:[UInt8]], overlay: URL)
    }
    /// These tickets retain their owner. Equal package bytes in two owners do
    /// not allow a startup ticket to consume the other owner's read-ahead.
    public struct Startup {
        fileprivate let owner: OriginalRuntimeContentInputs
        public let inputs: OriginalApplicationStartupInputs
    }
    public struct Loading {
        fileprivate let owner: OriginalRuntimeContentInputs
        fileprivate let packages: OriginalRuntimeLoadingPackages
    }
    public let identity: String
    private let source: Source
    private init(identity: String,source: Source) { self.identity = identity; self.source = source }

    public static func baseline(in bundle: Bundle = .main) -> OriginalRuntimeContentInputs {
        .init(identity:"NTSD-2.4-2.0a",source:.baseline(bundle))
    }
    /// Reads only the separately packaged nine ordinary ZIP members. No ZIP,
    /// Windows executable or packed-resource reader is needed at runtime.
    public static func targetPartial(directory: URL,writableParent: URL) throws -> OriginalRuntimeContentInputs {
        let fm = FileManager.default
        func facts(_ url: URL) throws -> URLResourceValues {
            guard fm.fileExists(atPath:url.path) else { throw Boundary.missing(url.lastPathComponent) }
            return try url.resourceValues(forKeys:[.isDirectoryKey,.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
        }
        let root = try facts(directory)
        guard root.isDirectory == true,root.isSymbolicLink != true else { throw Boundary.corrupt("package root") }
        func read(_ name: String,maximum: Int) throws -> [UInt8] {
            let parts = name.split(separator:"/",omittingEmptySubsequences:false)
            guard !name.contains("\\"),!parts.isEmpty,parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
                throw Boundary.corrupt("package path")
            }
            var url = directory
            for (index,part) in parts.enumerated() {
                url.appendPathComponent(String(part))
                guard fm.fileExists(atPath:url.path) else { throw Boundary.missing(name) }
                let v = try facts(url)
                guard v.isSymbolicLink != true else { throw Boundary.corrupt(name) }
                if index+1 == parts.count {
                    guard v.isRegularFile == true,let count = v.fileSize,count <= maximum else { throw Boundary.corrupt(name) }
                    guard count > 0 else { throw Boundary.empty(name) }
                } else if v.isDirectory != true { throw Boundary.corrupt(name) }
            }
            return Array(try Data(contentsOf:url))
        }
        func digest(_ bytes: [UInt8]) -> String { SHA256.hash(data:Data(bytes)).map { String(format:"%02x",$0) }.joined() }
        let raw = try read("manifest.json",maximum:16_384)
        guard digest(raw) == targetManifestSHA256 else { throw Boundary.corrupt("manifest.json") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:Data(raw))
        guard manifest.version == 1,manifest.identity == "NTSD-2.8.3.3-partial",manifest.partial,
              manifest.entries.count == 9,Set(manifest.entries.map(\.path)).count == 9,
              manifest.entries.reduce(0,{ $0+$1.count }) == 161_202 else { throw Boundary.corrupt("manifest contract") }
        var files: [String:[UInt8]] = [:],directories = Set<String>()
        for entry in manifest.entries {
            let bytes = try read(entry.path,maximum:entry.count)
            guard bytes.count == entry.count,digest(bytes) == entry.sha256 else { throw Boundary.corrupt(entry.path) }
            files[entry.path] = bytes
            let parts = entry.path.split(separator:"/")
            for end in 1..<parts.count { directories.insert(parts.prefix(end).joined(separator:"/")) }
        }
        let rootPath = directory.standardizedFileURL.resolvingSymlinksInPath().path
        var actualFiles = Set<String>(),actualDirectories = Set<String>(),enumerationError: Error?
        guard let iterator = fm.enumerator(at:directory,includingPropertiesForKeys:[.isDirectoryKey,.isRegularFileKey,.isSymbolicLinkKey],errorHandler:{ _,error in
            enumerationError = error;return false
        }) else { throw Boundary.missing("package directory") }
        for case let url as URL in iterator {
            let v = try facts(url)
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard path.hasPrefix(rootPath+"/") else { throw Boundary.corrupt("package root") }
            let name = String(path.dropFirst(rootPath.count+1))
            guard v.isSymbolicLink != true else { throw Boundary.corrupt(name) }
            if v.isDirectory == true { actualDirectories.insert(name) }
            else if v.isRegularFile == true { actualFiles.insert(name) }
            else { throw Boundary.corrupt(name) }
        }
        if let error = enumerationError { throw error }
        guard actualFiles == Set(files.keys).union(["manifest.json"]),actualDirectories == directories else { throw Boundary.corrupt("package composition") }
        return .init(identity:manifest.identity,source:.target(files:files,overlay:writableParent.appendingPathComponent("NTSD-2.8.3.3",isDirectory:true)))
    }
    /// Exact, case-sensitive package names; unknown is distinct from empty.
    public func rawTargetFile(_ name: String) throws -> [UInt8] {
        guard case .target(let files,_) = source,let bytes = files[name] else { throw Boundary.unsupportedName(name) }
        return bytes
    }
    /// The ready target loading consumer: one owned ordinary input becomes an
    /// owned in-place-decoded buffer with its separate source cursor. Unknown
    /// packed paths cannot reach this adapter. Startup still stops below.
    public func decodedTargetFile(_ name: String) throws -> NTSD2833FileBytes {
        let raw = try rawTargetFile(name)
        return try .init(raw:raw,fileName:Array(name.replacingOccurrences(of:"/",with:"\\").utf8))
    }
    public func acquireStartup() throws -> Startup {
        switch source {
        case .baseline(let bundle): return .init(owner:self,inputs:try .bundled(in:bundle))
        case .target: throw Boundary.unsupportedTargetStartup
        }
    }
    public func acquireLoading(for startup: Startup) throws -> Loading {
        guard startup.owner === self else { throw Boundary.mixedOrigin }
        guard case .baseline(let bundle) = source else { throw Boundary.unsupportedTargetStartup }
        return .init(owner:self,packages:.init(in:bundle))
    }
    @MainActor func makeLoading(_ started: OriginalMacRuntimeStartup.Started,startup: Startup,packages: Loading,
        clock: @escaping () throws -> UInt32,dialogs: OriginalRuntimeLoadingDialogs) throws -> OriginalMacRuntimeLoading {
        try validateOrigin(startup:startup,packages:packages)
        return try .bundled(started,startupInputs:startup.inputs,packages:packages.packages,clock:clock,dialogs:dialogs)
    }
    func validateOrigin(startup: Startup,packages: Loading) throws {
        guard startup.owner === self,packages.owner === self else { throw Boundary.mixedOrigin }
    }
    @MainActor func overlay(baseline: () throws -> OriginalMacRuntimeOverlay) rethrows -> OriginalMacRuntimeOverlay {
        switch source {
        case .baseline: return try baseline()
        case .target(_,let root): return .init(root:root)
        }
    }
    func catalogDirectory() throws -> URL {
        guard case .baseline(let bundle) = source else { throw Boundary.unsupportedTargetStartup }
        return try OriginalApplicationCatalogInputs.bundledDirectory(in:bundle)
    }
}
