import Foundation
import CryptoKit

/// Immutable original-derived data for the declared WinMain entry. Loading the
/// package is host IO before a Core attempt; subsequent access reads owned bytes.
/// No executable, saved after-state or platform response tape belongs here.
public struct OriginalApplicationStartupInputs: Equatable {
    public enum Boundary: Error, Equatable {
        case missing(String), invalid(String), unsupportedName(String)
    }
    public struct Bitmap: Equatable {
        public let dib: [UInt8]
        public let pixels: OriginalDIBPixels
        public let width: Int32, height: Int32, rowBytes: Int32
        public let planes: UInt16, bitsPerPixel: UInt16
        init(_ dib: [UInt8]) throws {
            guard dib.count >= 40 else { throw Boundary.invalid("DIB header") }
            let r = try OriginalStateRecord(bytes:dib,defined:[Bool](repeating:true,count:dib.count))
            let header: UInt32 = try r.integer(at:0,as:UInt32.self),w: Int32 = try r.integer(at:4,as:Int32.self),h: Int32 = try r.integer(at:8,as:Int32.self)
            let planes: UInt16 = try r.integer(at:12,as:UInt16.self),bits: UInt16 = try r.integer(at:14,as:UInt16.self),compression: UInt32 = try r.integer(at:16,as:UInt32.self)
            guard header == 40,w > 0,h > 0,planes == 1,
                  (bits == 24 && compression == 0) || (bits == 8 && compression == 1) else {
                throw Boundary.invalid("Declared DIB format")
            }
            let stride = ((Int64(w)*Int64(bits)+31)/32)*4
            guard stride <= Int64(Int32.max) else { throw Boundary.invalid("DIB row extent") }
            self.dib = dib;width = w;height = h;rowBytes = Int32(stride);self.planes = planes;bitsPerPixel = bits
            pixels = try OriginalDIBPixels(dib:dib)
        }
        /// Win32 BITMAP fields at the declared image boundary, not pixels or a
        /// host graphics object. Source colors/masks remain separate from surfaces.
        public func objectBytes() throws -> [UInt8] {
            var r = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:24),defined:[Bool](repeating:true,count:24))
            try r.write(width,at:4);try r.write(height,at:8);try r.write(rowBytes,at:12)
            try r.write(planes,at:16);try r.write(bitsPerPixel,at:18)
            return r.bytes
        }
    }
    private struct Manifest: Decodable {
        struct Entry: Decodable { let path: String,count: Int,sha256: String }
        let version: Int,globalAddress: Int,globalCount: Int,exeSHA256: String,absentFiles: [String],entries: [Entry]
    }
    public static let manifestSHA256 = "f67aff089a95f230b4e7f5c381ac92b420a5541f7fea6b6a268986aa6b7ef177"
    public let initial: OriginalStateRecord
    public let bitmaps: [String:Bitmap]
    private let files: [String:[UInt8]]
    private let fileNames: Set<String>

    public static func bundled(in appBundle: Bundle = .main) throws -> Self { try load(directory:bundledDirectory(in:appBundle)) }
    public static func bundledDirectory(in appBundle: Bundle = .main) throws -> URL {
        // build-native.sh/package_assets.py install ordinary files at this path.
        // SwiftPM command-line/test clients use the same package via .module.
        if let resources = appBundle.resourceURL {
            let directory = resources.appendingPathComponent("OriginalStartup",isDirectory:true)
            if appBundle.bundleURL.pathExtension == "app" || FileManager.default.fileExists(atPath:directory.path) { return directory }
        }
        guard let directory = Bundle.module.url(forResource:"OriginalStartup",withExtension:nil) else {
            throw Boundary.missing("OriginalStartup bundle resource")
        }
        return directory
    }
    public static func load(directory: URL) throws -> Self {
        func read(_ path: String) throws -> [UInt8] {
            let url = directory.appendingPathComponent(path)
            guard FileManager.default.fileExists(atPath:url.path) else { throw Boundary.missing(path) }
            let values = try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
            guard values.isRegularFile == true,values.isSymbolicLink != true else { throw Boundary.invalid(path) }
            return Array(try Data(contentsOf:url))
        }
        func digest(_ bytes: [UInt8]) -> String { SHA256.hash(data:Data(bytes)).map { String(format:"%02x",$0) }.joined() }
        let raw = try read("manifest.json")
        guard digest(raw) == manifestSHA256 else { throw Boundary.invalid("Manifest digest") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:Data(raw))
        guard manifest.version == 1,manifest.globalAddress == 0x44d000,manifest.globalCount == 0xc3a8,
              manifest.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              manifest.absentFiles == ["data/ad0.txt"],manifest.entries.count == 45 else { throw Boundary.invalid("Manifest contract") }
        var payload: [String:[UInt8]] = [:]
        for e in manifest.entries {
            guard !e.path.hasPrefix("/"),!e.path.split(separator:"/").contains(".."),payload[e.path] == nil else {
                throw Boundary.invalid("Manifest path")
            }
            let bytes = try read(e.path)
            guard bytes.count == e.count,digest(bytes) == e.sha256 else { throw Boundary.invalid(e.path) }
            payload[e.path] = bytes
        }
        let rootPath = directory.standardizedFileURL.resolvingSymlinksInPath().path
        var actual = Set<String>()
        guard let iterator = FileManager.default.enumerator(at:directory,includingPropertiesForKeys:[.isDirectoryKey,.isSymbolicLinkKey]) else {
            throw Boundary.missing("Package directory")
        }
        for case let url as URL in iterator {
            let values = try url.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw Boundary.invalid("Package symlink") }
            if values.isDirectory != true {
                let path = url.standardizedFileURL.resolvingSymlinksInPath().path
                guard path.hasPrefix(rootPath+"/") else { throw Boundary.invalid("Package root") }
                actual.insert(String(path.dropFirst(rootPath.count+1)))
            }
        }
        guard actual == Set(payload.keys).union(["manifest.json"]),let bytes = payload["initial.bin"],let mask = payload["initial.mask"],
              bytes.count == 0xc3a8,mask.count == bytes.count,mask.allSatisfy({ $0 == 1 }) else { throw Boundary.invalid("Package composition or PE masks") }
        let initial = try OriginalStateRecord(bytes:bytes,defined:mask.map { $0 == 1 })
        var bitmaps: [String:Bitmap] = [:],files: [String:[UInt8]] = [:]
        for (path,bytes) in payload {
            if path.hasPrefix("bitmaps/") {
                let name = String(path.dropFirst(8).dropLast(4));bitmaps[name] = try Bitmap(bytes)
            } else if path.hasPrefix("data/") { files[path.replacingOccurrences(of:"/",with:"\\")] = bytes }
        }
        return .init(initial:initial,bitmaps:bitmaps,files:files,fileNames:Set(files.keys).union(["data\\ad0.txt"]))
    }
    public func file(_ name: String) throws -> [UInt8]? {
        guard fileNames.contains(name) else { throw Boundary.unsupportedName(name) }
        return files[name]
    }
    /// A declared input overlay creates a separate value. Missing is distinct
    /// from empty; this does not write the original/bundle or model host errors.
    public func replacingFile(_ name: String,with bytes: [UInt8]?) throws -> Self {
        guard fileNames.contains(name) else { throw Boundary.unsupportedName(name) }
        var files = files;files[name] = bytes
        return .init(initial:initial,bitmaps:bitmaps,files:files,fileNames:fileNames)
    }
    /// Exactly the baseline control.txt CRLF-to-LF projection. General Windows
    /// text mode, Ctrl-Z, locale and live filesystem stream behavior remain open.
    public func controlBytes() throws -> [UInt8] {
        guard let raw = try file("data\\control.txt") else { throw Boundary.missing("data\\control.txt") }
        var result: [UInt8] = [],index = 0
        while index < raw.count {
            if raw[index] == 13,index+1 < raw.count,raw[index+1] == 10 { index += 1 }
            result.append(raw[index]);index += 1
        }
        return result
    }
}
