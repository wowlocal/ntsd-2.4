import Foundation

/// Original 40c160 metadata parse, 40c030 layer allocation and 40c0e0 release.
/// Bitmap pixels and real device ownership are supplied by a future adapter.
/// References use session bitmap index + 1 (0 is null), as in OriginalObjectLoader.
public struct OriginalBackgroundLoader {
    public static let recordSize = 0x990
    var resources = OriginalLoaderResources()
    public private(set) var checksum: UInt32 {
        get { resources.checksum } set { resources.checksum = newValue }
    }
    public private(set) var bitmaps: [OriginalLoadedBitmap] {
        get { resources.bitmaps } set { resources.bitmaps = newValue }
    }
    /// Records remain available for evidence after their original release/free.
    public private(set) var releasedBitmaps: Set<Int> = []
    public private(set) var outerTokens: [String] = []

    public init(initialChecksum: UInt32 = 0) { checksum = initialChecksum }

    /// The original's source ID argument is unused; its ordinal selects the
    /// supplied catalog record. Existing bytes AND provenance survive sparse writes.
    /// State is committed only after a complete supported parse succeeds.
    public mutating func parse(decoded: String, backing: OriginalStateRecord, bitmapFill: UInt8 = 0xa5,
                               constructBitmap: OriginalLoadedBitmap.Constructor? = nil,
                               onRead: ((Int) throws -> Void)? = nil,
                               onChecksum: (UInt32) throws -> Void = { _ in },
                               bitmapSource: (String) throws -> OriginalBitmapInput) throws -> OriginalStateRecord {
        var candidate = self
        let result = try candidate.consume(decoded: decoded, backing: backing, bitmapFill: bitmapFill, source: bitmapSource, constructBitmap: constructBitmap, onRead: onRead, onChecksum: onChecksum)
        self = candidate
        return result
    }

    private mutating func consume(decoded: String, backing: OriginalStateRecord, bitmapFill: UInt8,
                                  source: (String) throws -> OriginalBitmapInput,
                                  constructBitmap: OriginalLoadedBitmap.Constructor?,
                                  onRead: ((Int) throws -> Void)?, onChecksum: (UInt32) throws -> Void) throws -> OriginalStateRecord {
        guard backing.bytes.count == Self.recordSize else { throw Self.error("BG storage size") }
        guard !decoded.unicodeScalars.contains(where: { $0.value == 0 || $0.value == 0x1a }) else { throw Self.error("NUL/DOS EOF in decoded source") }
        var input = try OriginalFrameScanner(decoded, observeRead: onRead), record = backing
        for offset in [0x1c, 0xc, 0x10] { try record.write(Int32(0), at: offset) }
        outerTokens = []
        var token: String?
        while !input.eof {
            if let next = try input.observedToken() { token = try Self.bounded(next, limit: 100) }
            guard let current = token else { throw Self.error("Uninitialized outer token") }
            outerTokens.append(current)
            for (index, scalar) in current.unicodeScalars.enumerated() {
                checksum &+= UInt32(bitPattern: Int32(Int8(bitPattern: UInt8(scalar.value)))) &* UInt32(index)
            }
            try onChecksum(checksum)
            if current == "name:" {
                let name = try Self.bounded(input.token(), limit: 100)
                let bytes = name.unicodeScalars.prefix(29).map { UInt8($0.value) == 95 ? UInt8(32) : UInt8($0.value) }
                try Self.writeString(bytes, at: 0x3cc, in: &record)
            }
            if current == "width:", let value = try input.integer() { try record.write(value, at: 0) }
            if current == "zboundary:" || current == "perspective:" {
                let offset = current == "zboundary:" ? 4 : 0xc
                // A single %d %d call stops on the first matching failure.
                if let first = try input.integer() {
                    try record.write(first, at: offset)
                    if let second = try input.integer() { try record.write(second, at: offset + 4) }
                }
            }
            if current == "shadow:" {
                let path = try Self.bounded(input.token(), limit: 40)
                try Self.writeString(path.unicodeScalars.map { UInt8($0.value) }, at: 0x3a4, in: &record)
                _ = try Self.bounded(input.token(), limit: 100) // %s label, deliberately not validated
                if let x = try input.integer() {
                    try record.write(x, at: 0x14)
                    if let y = try input.integer() { try record.write(y, at: 0x18) }
                }
                let bitmap = try appendBitmap(path, fill: bitmapFill, source: source, constructBitmap: constructBitmap)
                try record.write(UInt32(bitmap + 1), at: 0x98c)
            }
            if current == "layer:" {
                let index = Int(try record.integer(at: 0x1c, as: Int32.self))
                guard (0..<30).contains(index) else { throw Self.error("Layer table overflow is not recovered") }
                let path = try Self.bounded(input.token(), limit: 30)
                try Self.writeString(path.unicodeScalars.map { UInt8($0.value) }, at: 0x20 + index*30, in: &record)
                for offset in Self.layerDefaults { try record.write(Int32(0), at: offset + index*4) }
                token = try Self.bounded(input.token(), limit: 100)
                while token != "layer_end" {
                    if let offset = Self.layerFields[token!], let value = try input.integer() {
                        try record.write(value, at: offset + index*4)
                    }
                    if token == "rect:" {
                        // Conversion runs even after a failed %ld, on the old value.
                        let offset = 0x89c + index*4
                        if let value = try input.integer() { try record.write(value, at: offset) }
                        let value = try record.integer(at: offset, as: UInt32.self)
                        let red = (value >> 11) & 31, green = (value >> 5) & 63, blue = value & 31
                        let color = ((((red << 9) &+ green) << 7) &+ blue) &* 8 &+ 0x70707
                        try record.write(color, at: offset)
                    }
                    token = try Self.bounded(input.token(), limit: 100)
                }
                try record.write(Int32(index + 1), at: 0x1c)
            }
        }
        return record
    }

    /// 40c030 creates every layer wrapper in file order, including repeated paths.
    /// Caller decides when to invoke this; parsing metadata does not load the layers.
    public mutating func loadLayers(in record: inout OriginalStateRecord, bitmapFill: UInt8 = 0xa5,
                                    constructBitmap: OriginalLoadedBitmap.Constructor? = nil,
                                    bitmapSource: (String) throws -> OriginalBitmapInput) throws {
        var candidate = self, storage = record
        let count = try Self.layerCount(storage)
        for index in 0..<count {
            let path = try Self.readString(storage, at: 0x20 + index*30, limit: 30)
            let bitmap = try candidate.appendBitmap(path, fill: bitmapFill, source: bitmapSource, constructBitmap: constructBitmap)
            try storage.write(UInt32(bitmap + 1), at: 0x914 + index*4)
        }
        self = candidate; record = storage
    }

    /// Returns ordered surface Release + wrapper free requests. Only the first pointer
    /// is cleared by the original; the other slots retain dangling references.
    /// Repeated release uses that first pointer sentinel and produces no requests.
    @discardableResult
    public mutating func releaseLayers(in record: inout OriginalStateRecord) throws -> [Int] {
        guard record.bytes.count == Self.recordSize else { throw Self.error("BG storage size") }
        var released: [Int] = []
        if try record.integer(at: 0x914, as: UInt32.self) != 0 {
            let count = try Self.layerCount(record)
            for index in 0..<count {
                let pointer = try record.integer(at: 0x914 + index*4, as: UInt32.self)
                guard pointer > 0, Int(pointer) <= bitmaps.count else { throw Self.error("Unknown layer bitmap reference") }
                let bitmap = Int(pointer) - 1
                guard !releasedBitmaps.contains(bitmap), !released.contains(bitmap), bitmaps[bitmap].input.present else {
                    throw Self.error("Original would release an unavailable/aliased surface")
                }
                released.append(bitmap)
            }
        }
        try record.write(UInt32(0), at: 0x914)
        releasedBitmaps.formUnion(released)
        return released
    }

    private mutating func appendBitmap(_ path: String, fill: UInt8, source: (String) throws -> OriginalBitmapInput,
                                       constructBitmap: OriginalLoadedBitmap.Constructor?) throws -> Int {
        let bitmap: OriginalLoadedBitmap
        if let constructBitmap {
            bitmap = try .checkedConstruction(constructBitmap(path, false, Array(repeating: fill, count: 0x1f50)), path: path, optional: false)
        } else {
            let input = try source(path)
            guard input.path == path else { throw Self.error("Bitmap provider returned a different path") }
            bitmap = try .construct(input, optional: false, fill: fill)
        }
        let index = bitmaps.count
        bitmaps.append(bitmap)
        return index
    }

    private static let layerDefaults = [0x89c, 0x4dc, 0x554, 0x464, 0x5cc, 0x644, 0x3ec, 0x7ac, 0x6bc, 0x734, 0x824, 0x914]
    private static let layerFields = ["transparency:": 0x3ec, "width:": 0x464, "x:": 0x4dc, "y:": 0x554,
                                      "height:": 0x5cc, "rect32:": 0x89c, "loop:": 0x644, "cc:": 0x7ac, "c1:": 0x6bc, "c2:": 0x734]
    private static func error(_ text: String) -> OriginalLoaderError { .outsideVerifiedDomain("Background loader: \(text)") }
    private static func bounded(_ text: String, limit: Int) throws -> String {
        guard text.unicodeScalars.count < limit else { throw error("String exceeds verified storage") }
        return text
    }
    private static func writeString(_ bytes: [UInt8], at offset: Int, in record: inout OriginalStateRecord) throws {
        for (index, byte) in (bytes + [0]).enumerated() { try record.write(byte, at: offset + index) }
    }
    private static func readString(_ record: OriginalStateRecord, at offset: Int, limit: Int) throws -> String {
        var bytes: [UInt8] = []
        for index in 0..<limit {
            let byte = try record.integer(at: offset + index, as: UInt8.self)
            if byte == 0 { return String(String.UnicodeScalarView(bytes.map { UnicodeScalar($0) })) }
            bytes.append(byte)
        }
        throw error("Unterminated layer filename")
    }
    private static func layerCount(_ record: OriginalStateRecord) throws -> Int {
        guard record.bytes.count == Self.recordSize else { throw error("BG storage size") }
        let count = try record.integer(at: 0x1c, as: Int32.self)
        guard (0...30).contains(count) else { throw error("Unverified layer count") }
        return Int(count)
    }
}
