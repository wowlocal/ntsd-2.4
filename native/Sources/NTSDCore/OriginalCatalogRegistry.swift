import Foundation

/// A call issued by the original catalog parent. These are load requests, not
/// proof that the requested Object, Background, Stage, or bitmap has been loaded.
public struct OriginalCatalogLoadRequest: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case bitmap, progress, object, background, stages }
    public let kind: Kind
    public let index: Int?
    public let id: Int32?
    public let objectType: Int32?
    /// Latin-1 is used as a reversible byte representation, not a filesystem encoding decision.
    public let path: String?

    init(_ kind: Kind, index: Int? = nil, id: Int32? = nil, objectType: Int32? = nil, path: String? = nil) {
        self.kind = kind; self.index = index; self.id = id; self.objectType = objectType; self.path = path
    }
}

/// Parent-owned behavior of EXE 0x4122f0. onLoad supplies child work at each call
/// boundary; its default only records requests. OriginalLoadedCatalog composes
/// the actual native children. A registry alone is not loaded or match state.
/// The modeled CRT domain is C-locale %s and in-range %d with complete sections.
public struct OriginalCatalogRegistry: Equatable, Sendable {
    public static let regionSizes = [0: 0x7d0, 0x4d81060: 0x990, 0x4d819f0: 0x990, 0x4d82380: 0x28]
    public let records: [Int: OriginalStateRecord]
    public let requests: [OriginalCatalogLoadRequest]
    /// Initial value plus ONLY parent token contributions. Children also modify
    /// the original global +0x44f620; this is not a full-game checksum.
    public let parentChecksum: UInt32
    /// Includes effects returned by onLoad, in the original call order.
    public let checksum: UInt32
    public let outerTokens: [[UInt8]]

    /// Records preserve supplied bytes/masks. Only established pointers are bound
    /// to non-null ordinals: object entries -> object request index; built-in bitmap
    /// pointers -> bitmap request index. Ordinal zero is a valid bound reference.
    public init(source: [UInt8], fileName: [UInt8], initialChecksum: UInt32,
                backing: [Int: OriginalStateRecord],
                beforeRead: () throws -> Void = {},
                onRead: ((Int) throws -> Void)? = nil,
                onChecksum: (UInt32) throws -> Void = { _ in },
                onClose: () throws -> Void = {},
                onLoad: (OriginalCatalogLoadRequest, UInt32) throws -> UInt32 = { _, checksum in checksum }) throws {
        try self.init(source: { source }, fileName: fileName, initialChecksum: initialChecksum,
                      backing: backing, beforeRead: beforeRead, onRead: onRead,
                      onChecksum: onChecksum, onClose: onClose, onLoad: onLoad)
    }

    /// The real parent constructs four embedded bitmaps and samples time before
    /// opening its catalog file. A throwing provider preserves that call order;
    /// callers stage external resource effects until the enclosing load commits.
    public init(source: () throws -> [UInt8], fileName: [UInt8], initialChecksum: UInt32,
                backing: [Int: OriginalStateRecord],
                beforeRead: () throws -> Void = {},
                onRead: ((Int) throws -> Void)? = nil,
                onChecksum: (UInt32) throws -> Void = { _ in },
                onClose: () throws -> Void = {},
                onLoad: (OriginalCatalogLoadRequest, UInt32) throws -> UInt32 = { _, checksum in checksum }) throws {
        guard Set(backing.keys) == Set(Self.regionSizes.keys), Self.regionSizes.allSatisfy({ backing[$0.key]?.bytes.count == $0.value }) else {
            throw OriginalStateError.invalidStorage("Catalog parent region sizes differ")
        }
        guard !fileName.isEmpty, fileName.count < 32, !fileName.contains(0) else {
            throw OriginalStateError.invalidStorage("Catalog filename exceeds the verified 31-byte domain")
        }
        var records = backing, requests: [OriginalCatalogLoadRequest] = [], checksum = initialChecksum
        var parentChecksum = initialChecksum
        var outerTokens: [[UInt8]] = []
        func request(_ item: OriginalCatalogLoadRequest) throws {
            requests.append(item)
            checksum = try onLoad(item, checksum)
        }
        func write<T: FixedWidthInteger>(_ value: T, region: Int, at offset: Int) throws {
            try records[region]!.write(value, at: offset)
        }
        func writeString(_ bytes: [UInt8], region: Int, at offset: Int) throws {
            for (i, byte) in (bytes + [0]).enumerated() { try write(byte, region: region, at: offset + i) }
        }
        // 41233b..41251c: deliberately sparse writes into built-in backgrounds.
        let builtIn = 0x4d81060
        for (offset, value) in [(0, 2400), (4, 350), (8, 470), (0x14, 37), (0x18, 9)] {
            try write(Int32(value), region: builtIn, at: offset)
        }
        try writeString(Array("Lee On Road".utf8), region: builtIn, at: 0x3cc)
        for (index, item) in [("shadow1", 0x3a4, 0x98c), ("back99_1", 0x20, 0x914),
                              ("back99_2", 0x3e, 0x918), ("back99_3", 0x5c, 0x91c)].enumerated() {
            try writeString(Array(item.0.utf8), region: builtIn, at: item.1)
            try request(.init(.bitmap, index: index, path: item.0))
            try write(UInt32(index), region: builtIn, at: item.2)
        }
        try writeString(Array("Random".utf8), region: 0x4d819f0, at: 0x3cc)
        try writeString(fileName, region: 0x4d82380, at: 8)
        try write(Int32(0), region: 0x4d82380, at: 0)
        try write(Int32(0), region: 0x4d82380, at: 4)

        try beforeRead() //412549: timeGetTime result is discarded before fopen
        var scanner = try CatalogScanner(source(), observeRead: onRead)
        var token: [UInt8]?, objectCount = 0, backgroundCount = 0
        while !scanner.eof {
            // At outer EOF fscanf leaves the existing token unchanged. Inner
            // sections without a closing marker are outside the supported domain.
            if let next = try scanner.string() { token = next }
            guard let current = token else { throw CatalogScanner.error("No initialized outer token") }
            outerTokens.append(current)
            for (index, byte) in current.enumerated() {
                let contribution = UInt32(bitPattern: Int32(Int8(bitPattern: byte))) &* UInt32(index)
                checksum &+= contribution
                parentChecksum &+= contribution
            }
            try onChecksum(checksum)
            if token == Array("<object>".utf8) {
                token = try scanner.requiredString()
                while token != Array("<object_end>".utf8) {
                    if token == Array("id:".utf8) {
                        // 412648: %d %s %d %s %s; labels share the token buffer.
                        let id = try scanner.integer()
                        token = try scanner.requiredString()
                        let type = try scanner.integer()
                        token = try scanner.requiredString()
                        let path = CatalogScanner.byteString(try scanner.requiredString())
                        guard objectCount < 500 else { throw CatalogScanner.error("Object table capacity exceeded") }
                        try request(.init(.progress, path: path))
                        try request(.init(.object, index: objectCount, id: id, objectType: type, path: path))
                        try write(UInt32(objectCount), region: 0, at: objectCount * 4)
                        objectCount += 1
                        try write(Int32(objectCount), region: 0x4d82380, at: 0)
                    }
                    token = try scanner.requiredString()
                }
            }
            if token == Array("<background>".utf8) {
                token = try scanner.requiredString()
                while token != Array("<background_end>".utf8) {
                    if token == Array("id:".utf8) {
                        // 41275c: source ID and path; 41277b receives a separate ordinal.
                        let id = try scanner.integer()
                        token = try scanner.requiredString()
                        let path = CatalogScanner.byteString(try scanner.requiredString(limit: 180))
                        guard backgroundCount < 99 else { throw CatalogScanner.error("Unverified collision with built-in backgrounds") }
                        try request(.init(.background, index: backgroundCount, id: id, path: path))
                        backgroundCount += 1
                        try write(Int32(backgroundCount), region: 0x4d82380, at: 4)
                    }
                    token = try scanner.requiredString()
                }
            }
        }
        try onClose() //4127c2 closes the registry before the Stage caller.
        try request(.init(.stages))
        self.records = records; self.requests = requests
        self.parentChecksum = parentChecksum; self.checksum = checksum; self.outerTokens = outerTokens
    }
}

/// Restricted scanner matching the declared oracle's CRT boundary. Unsupported
/// input throws instead of inventing original overflow/buffer-overwrite behavior.
private struct CatalogScanner {
    private let bytes: [UInt8]
    private var position = 0
    private(set) var eof = false
    private let observeRead: ((Int) throws -> Void)?
    private static let whitespace: Set<UInt8> = [9, 10, 11, 12, 13, 32]
    static func error(_ detail: String) -> OriginalStateError { .invalidStorage("Catalog registry: \(detail)") }

    init(_ source: [UInt8], observeRead: ((Int) throws -> Void)?) throws {
        guard !source.isEmpty, !source.contains(0), !source.contains(0x1a) else {
            throw Self.error("Empty/NUL/DOS-EOF source outside verified scanner domain")
        }
        // CRLF and LF both delimit tokens; no literal text-mode positions escape this scanner.
        bytes = source
        self.observeRead = observeRead
    }

    private mutating func skipSpace() {
        while position < bytes.count, Self.whitespace.contains(bytes[position]) { position += 1 }
        if position == bytes.count { eof = true }
    }

    mutating func string(limit: Int = 200) throws -> [UInt8]? {
        skipSpace()
        guard !eof else { try observeRead?(position); return nil }
        let start = position
        while position < bytes.count, !Self.whitespace.contains(bytes[position]) { position += 1 }
        guard position - start < limit else { throw Self.error("Token exceeds the original scratch buffer") }
        if position == bytes.count { eof = true }
        try observeRead?(position)
        return Array(bytes[start..<position])
    }

    mutating func requiredString(limit: Int = 200) throws -> [UInt8] {
        guard let value = try string(limit: limit) else { throw Self.error("Truncated entry or section") }
        return value
    }

    mutating func integer() throws -> Int32 {
        skipSpace()
        guard !eof else { throw Self.error("Missing integer") }
        let negative = bytes[position] == 45
        if negative || bytes[position] == 43 { position += 1 }
        let start = position
        var number: Int64 = 0
        while position < bytes.count, (48...57).contains(bytes[position]) {
            number = number * 10 + Int64(bytes[position] - 48)
            guard number <= (negative ? 2147483648 : 2147483647) else { throw Self.error("Unverified MSVCR80 integer overflow") }
            position += 1
        }
        guard position != start else { throw Self.error("Integer matching failure outside verified entry domain") }
        if position == bytes.count { eof = true }
        try observeRead?(position)
        return Int32(negative ? -number : number)
    }

    static func byteString(_ bytes: [UInt8]) -> String {
        String(String.UnicodeScalarView(bytes.map { UnicodeScalar(UInt32($0))! }))
    }
}
