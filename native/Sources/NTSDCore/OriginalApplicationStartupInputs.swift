import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Immutable original-derived data for the declared WinMain entry. Loading the
/// package is host IO before a Core attempt; subsequent access reads owned bytes.
/// No executable, saved after-state or platform response tape belongs here.
public struct OriginalApplicationStartupInputs: Equatable {
    public enum Boundary: Error, Equatable {
        case missing(String), invalid(String), unsupportedName(String)
    }
    public struct Bitmap: Equatable {
        /// The DIB bytes, kept compressed for a large image (OriginalBitmapBytes)
        /// and decompressed on each read.
        public var dib: [UInt8] { bytes.dib }
        private let bytes: OriginalBitmapBytes
        /// Exact file header distinguishes a file image from an embedded DIB.
        public let bitmapFileHeader: [UInt8]?
        /// Where the pixel data starts in `dib`, as resolved when the bitmap loaded.
        public let pixelOffset: Int
        /// The decoded source colours, decoded on each read rather than kept: every
        /// bitmap was decoded (so validated) when it loaded, and decoding is a pure
        /// function of `dib` and the declared offset. A kept copy of each bitmap
        /// (three colour bytes and a definedness byte per pixel) held about 1 GB
        /// over the game's images (MEMORY_FOOTPRINT step 1).
        public var pixels: OriginalDIBPixels { try! OriginalDIBPixels(dib:dib,pixelOffset:declaredPixelOffset) }
        /// The offset the bitmap was decoded with: the file header's for a file
        /// image, nil (just after the palette) for an embedded DIB.
        private let declaredPixelOffset: Int?
        public let width: Int32, height: Int32, rowBytes: Int32
        public let planes: UInt16, bitsPerPixel: UInt16
        init(_ dib: [UInt8]) throws { try self.init(dib:dib) }
        public init(dib: [UInt8]) throws { try self.init(dib:dib,fileHeader:nil,pixelOffset:nil) }
        public init(bitmapFile: [UInt8]) throws {
            guard bitmapFile.count >= 54,bitmapFile[0] == 0x42,bitmapFile[1] == 0x4d else {
                throw Boundary.invalid("BMP header")
            }
            func word(_ at: Int) -> UInt32 {
                UInt32(bitmapFile[at]) | UInt32(bitmapFile[at+1]) << 8 |
                    UInt32(bitmapFile[at+2]) << 16 | UInt32(bitmapFile[at+3]) << 24
            }
            let offset = Int(word(10))
            guard Int(word(2)) == bitmapFile.count,word(6) == 0,offset >= 54,offset <= bitmapFile.count else {
                throw Boundary.invalid("BMP file extent or reserved fields")
            }
            try self.init(dib:Array(bitmapFile.dropFirst(14)),fileHeader:Array(bitmapFile.prefix(14)),pixelOffset:offset-14)
        }
        private init(dib: [UInt8],fileHeader: [UInt8]?,pixelOffset: Int?) throws {
            guard dib.count >= 40 else { throw Boundary.invalid("DIB header") }
            // The header's little-endian fields, read in place: a whole-file
            // record (and a definedness byte per file byte) was built for them
            // (MEMORY_LOADING L4).
            func word(_ at: Int) -> UInt32 {
                UInt32(dib[at]) | UInt32(dib[at+1]) << 8 | UInt32(dib[at+2]) << 16 | UInt32(dib[at+3]) << 24
            }
            let header = word(0),w = Int32(bitPattern:word(4)),h = Int32(bitPattern:word(8))
            let planes = UInt16(dib[12]) | UInt16(dib[13]) << 8,bits = UInt16(dib[14]) | UInt16(dib[15]) << 8,compression = word(16)
            guard header == 40,w > 0,h > 0,planes == 1,
                  ([4,8,24].contains(bits) && compression == 0) || (bits == 8 && compression == 1) else {
                throw Boundary.invalid("Declared DIB format")
            }
            let stride = ((Int64(w)*Int64(bits)+31)/32)*4
            guard stride <= Int64(Int32.max) else { throw Boundary.invalid("DIB row extent") }
            width = w;height = h;rowBytes = Int32(stride);self.planes = planes;bitsPerPixel = bits
            bitmapFileHeader = fileHeader
            if let pixelOffset {
                let colors = Int(word(32))
                let count = bits == 24 ? colors : (colors == 0 ? 1 << Int(bits) : colors)
                guard count <= (dib.count-40)/4,pixelOffset >= 40+count*4 else {
                    throw Boundary.invalid("BMP pixel offset or palette")
                }
            }
            // Validated here as the decoder would decode it, so an invalid image
            // still fails at load with the decoder's error.
            self.pixelOffset = try OriginalDIBPixels.validate(dib:dib,pixelOffset:pixelOffset)
            declaredPixelOffset = pixelOffset
            bytes = OriginalBitmapBytes(dib)
        }
        /// Every field as before; the bytes compare by content unless shared.
        public static func == (a: Bitmap,b: Bitmap) -> Bool {
            a.bitmapFileHeader == b.bitmapFileHeader && a.pixelOffset == b.pixelOffset && a.declaredPixelOffset == b.declaredPixelOffset
                && a.width == b.width && a.height == b.height && a.rowBytes == b.rowBytes && a.planes == b.planes
                && a.bitsPerPixel == b.bitsPerPixel && (a.bytes === b.bytes || a.dib == b.dib)
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
            guard OriginalFileFacts.exists(url) else { throw Boundary.missing(path) }
            let values = try OriginalFileFacts.of(url,[.isRegularFileKey,.isSymbolicLinkKey])
            guard values.isRegularFile == true,values.isSymbolicLink != true else { throw Boundary.invalid(path) }
            return Array(try Data(contentsOf:url))
        }
        func digest(_ bytes: [UInt8]) -> String { OriginalConcurrentInputs.hex(SHA256.hash(data:bytes)) }
        let raw = try read("manifest.json")
        guard digest(raw) == manifestSHA256 else { throw Boundary.invalid("Manifest digest") }
        let manifest = try JSONDecoder().decode(Manifest.self,from:Data(raw))
        guard manifest.version == 1,manifest.globalAddress == 0x44d000,manifest.globalCount == 0xc3a8,
              manifest.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              manifest.absentFiles == ["data/ad0.txt"],manifest.entries.count == 45 else { throw Boundary.invalid("Manifest contract") }
        // Entries are read and verified on all cores and taken in manifest
        // order (MEMORY_LOADING L3, M1): the first failing entry in that order
        // still fails first with its own error. A path the order check would
        // refuse is never read.
        // refuse is never read, and a file whose facts or size differ from the
        // manifest's is read only in its turn, as before.
        func permitted(_ path: String) -> Bool { !path.hasPrefix("/") && !path.split(separator:"/").contains("..") }
        func declared(_ e: Manifest.Entry) -> Bool {
            let url = directory.appendingPathComponent(e.path)
            guard let values = try? OriginalFileFacts.of(url,[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey]) else { return false }
            return values.isRegularFile == true && values.isSymbolicLink != true && values.fileSize == e.count
        }
        func verified(_ e: Manifest.Entry) throws -> [UInt8] {
            let bytes = try read(e.path)
            guard bytes.count == e.count,digest(bytes) == e.sha256 else { throw Boundary.invalid(e.path) }
            return bytes
        }
        let loaded = OriginalConcurrentInputs.map(manifest.entries) { e -> [UInt8]? in
            guard permitted(e.path),declared(e) else { return nil }
            return try verified(e)
        }
        var payload: [String:[UInt8]] = [:]
        for (e,result) in zip(manifest.entries,loaded) {
            guard permitted(e.path),payload[e.path] == nil else { throw Boundary.invalid("Manifest path") }
            payload[e.path] = try result.get() ?? verified(e)
        }
        let rootPath = directory.standardizedFileURL.resolvingSymlinksInPath().path
        var actual = Set<String>()
        guard let iterator = FileManager.default.enumerator(at:directory,includingPropertiesForKeys:OriginalDirectoryPrefetch.keys([.isDirectoryKey,.isSymbolicLinkKey])) else {
            throw Boundary.missing("Package directory")
        }
        for case let url as URL in iterator {
            let values = try OriginalFileFacts.of(url,[.isDirectoryKey,.isSymbolicLinkKey])
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
        // The bitmaps decode (and compress, OriginalBitmapBytes) on all cores and
        // are taken in the payload's own order, as the loop took them.
        let entries = Array(payload)
        let decoded = OriginalConcurrentInputs.map(entries) { entry -> Bitmap? in
            entry.key.hasPrefix("bitmaps/") ? try Bitmap(entry.value) : nil
        }
        for ((path,bytes),bitmap) in zip(entries,decoded) {
            if path.hasPrefix("bitmaps/") {
                let name = String(path.dropFirst(8).dropLast(4));bitmaps[name] = try bitmap.get()!
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
