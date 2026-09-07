import Foundation

/// The recovered numerical part of the original 0x178-byte frame record.
/// Keys are byte offsets from the record, not object offsets. Absent words were
/// not initialized by the original constructor and must not acquire defaults.
/// Pointers and name bytes are represented separately; no x86 code runs here.
public struct OriginalFrameRecord: Codable, Equatable, Sendable {
    public let number: Int
    public internal(set) var name: String
    public internal(set) var words: [String: Int32]
    public internal(set) var sound: String?
    public internal(set) var interactions: [[Int32]] = []
    public internal(set) var bodies: [[Int32]] = []

    init(number: Int) {
        self.number = number; name = ""; words = ["0": 0, "372": -1]
        // Original constructor 0x40bbf0–0x40bd83. In particular c4–d4 are unset.
        for range in [0x04...0xc0, 0xd8...0x12c, 0x138...0x158] {
            for offset in stride(from: range.lowerBound, through: range.upperBound, by: 4) {
                words[String(offset)] = 0
            }
        }
    }
    public subscript(offset: Int) -> Int32? { words[String(offset)] }
    public func field(_ name: String) -> Int32? {
        guard let offset = OriginalFrameLoader.frameFields[name + ":"] else { return nil }
        return self[offset]
    }
}

public enum OriginalLoaderError: Error, CustomStringConvertible {
    case outsideVerifiedDomain(String)
    public var description: String {
        switch self { case .outsideVerifiedDomain(let message): return message }
    }
}

/// Decoded <frame> sections only. This is not yet the object/header loader.
/// Int32 overflow and original buffer overruns are rejected pending recovery.
/// Reference: docs/FRAME_LOADER.md, original EXE constructor and frame branch.
public struct OriginalFrameLoader {
    public private(set) var frames: [Int: OriginalFrameRecord] = [:]
    var sounds = OriginalSoundRegistry()
    public init() {}

    static let frameFields: [String: Int] = [
        "pic:": 0x04, "state:": 0x08, "wait:": 0x0c, "next:": 0x10,
        "dvx:": 0x14, "dvy:": 0x18, "dvz:": 0x1c,
        "hit_a:": 0x24, "hit_d:": 0x28, "hit_j:": 0x2c,
        "hit_Fa:": 0x30, "hit_Ua:": 0x34, "hit_Da:": 0x38,
        "hit_Fj:": 0x3c, "hit_Uj:": 0x40, "hit_Dj:": 0x44,
        "hit_ja:": 0x48, "mp:": 0x4c, "centerx:": 0x50, "centery:": 0x54
    ]
    private static let pointFields: [String: [String: Int]] = [
        "opoint:": ["kind:":0x58,"x:":0x5c,"y:":0x60,"action:":0x64,
                    "dvx:":0x68,"dvy:":0x6c,"oid:":0x70,"facing:":0x74],
        "bpoint:": ["x:":0x80,"y:":0x84],
        "cpoint:": ["kind:":0x88,"x:":0x8c,"y:":0x90,"injury:":0x94,
                    "cover:":0x98,"vaction:":0x9c,"aaction:":0xa0,"jaction:":0xa4,
                    "daction:":0xa8,"throwvx:":0xac,"throwvy:":0xb0,"hurtable:":0xb4,
                    "decrease:":0xb8,"dircontrol:":0xbc,"taction:":0xc0,
                    "throwinjury:":0xc4,"throwvz:":0xc8,
                    "fronthurtact:":0x94,"backhurtact:":0x98],
        "wpoint:": ["kind:":0xd8,"x:":0xdc,"y:":0xe0,"weaponact:":0xe4,
                    "attacking:":0xe8,"cover:":0xec,"dvx:":0xf0,"dvy:":0xf4,"dvz:":0xf8]
    ]
    private static let interactionFields: [String: [Int]] = [
        "kind:":[0],"x:":[1],"y:":[2],"w:":[3],"h:":[4],"dvx:":[5],"dvy:":[6],
        "fall:":[7],"arest:":[8],"vrest:":[9],"respond:":[10],"effect:":[11],
        "catchingact:":[12,13],"caughtact:":[14,15],"pickingact:":[12],"pickedact:":[13],
        "bdefend:":[16],"injury:":[17],"zwidth:":[18]
    ]
    private static let bodyFields: [String: [Int]] = ["kind:":[0],"x:":[1],"y:":[2],"w:":[3],"h:":[4]]

    /// Apply one source occurrence, retaining the previous record at this index.
    /// Failed/unsupported occurrences leave this loader unchanged.
    @discardableResult public mutating func apply(_ source: String) throws -> OriginalFrameRecord {
        var input = try OriginalFrameScanner(source)
        guard try input.token() == "<frame>" else {
            throw OriginalLoaderError.outsideVerifiedDomain("Expected a frame section")
        }
        var candidate = self
        let record = try candidate.consumeFrameBody(&input)
        guard input.isAtEnd else { throw OriginalLoaderError.outsideVerifiedDomain("Expected one complete frame section") }
        self = candidate
        return record
    }

    /// Shared parser used by both isolated sections and the continuous Object
    /// stream. The caller has consumed <frame>; no artificial section EOF here.
    mutating func consumeFrameBody(_ input: inout OriginalFrameScanner) throws -> OriginalFrameRecord {
        guard let index = try input.integer(), (0..<400).contains(index) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Expected a frame index in 0...399")
        }
        let name = try input.token()
        guard name.unicodeScalars.count <= 19 else {
            throw OriginalLoaderError.outsideVerifiedDomain("Original frame name exceeds 19 bytes")
        }
        var record = frames[Int(index)] ?? OriginalFrameRecord(number: Int(index))
        var updatedSounds = sounds
        record.name = name
        // 0x41043b–0x41046e: only these counters are reset at frame entry.
        record.words["0"] = 1
        record.words[String(0x128)] = 0; record.words[String(0x12c)] = 0
        record.interactions = []; record.bodies = []
        while true {
            let token = try input.token()
            if token == "<frame_end>" { break }
            if let offset = Self.frameFields[token] {
                if let value = try input.integer() { record.words[String(offset)] = value }
            } else if let fields = Self.pointFields[token] {
                let end = String(token.dropLast()) + "_end:"
                while true {
                    let tag = try input.token()
                    if tag == end { break }
                    if let offset = fields[tag], let value = try input.integer() {
                        record.words[String(offset)] = value
                    }
                }
            } else if token == "itr:" || token == "bdy:" {
                let isInteraction = token == "itr:"
                let count = isInteraction ? record.interactions.count : record.bodies.count
                guard count < 5 else { throw OriginalLoaderError.outsideVerifiedDomain("Original allocation holds five boxes") }
                let fields = isInteraction ? Self.interactionFields : Self.bodyFields
                var box = [Int32](repeating: 0, count: isInteraction ? 20 : 10)
                let end = isInteraction ? "itr_end:" : "bdy_end:"
                while true {
                    let tag = try input.token()
                    if tag == end { break }
                    if let indices = fields[tag] {
                        for offset in indices {
                            guard let value = try input.integer() else { break }
                            box[offset] = value
                        }
                    }
                }
                if isInteraction { record.interactions.append(box) } else { record.bodies.append(box) }
            } else if token == "sound:" {
                let sound = try input.token()
                record.sound = sound
                record.words[String(0x174)] = try updatedSounds.register(sound)
            }
            // Original %s loop ignores unknown tokens; it does not strip comments.
        }
        record.words[String(0x128)] = Int32(record.interactions.count)
        record.words[String(0x12c)] = Int32(record.bodies.count)
        // 0x411ef0–0x412274: signed comparisons and wrapping 32-bit ADD/SUB.
        // Empty arrays leave the old aggregate bounds in place.
        Self.updateBounds(record.interactions, offset: 0x138, record: &record)
        Self.updateBounds(record.bodies, offset: 0x148, record: &record)
        frames[Int(index)] = record; sounds = updatedSounds
        return record
    }

    private static func updateBounds(_ boxes: [[Int32]], offset: Int, record: inout OriginalFrameRecord) {
        guard let first = boxes.first else { return }
        var x = first[1], y = first[2], right = first[1] &+ first[3], bottom = first[2] &+ first[4]
        for box in boxes.dropFirst() {
            x = min(x, box[1]); y = min(y, box[2])
            right = max(right, box[1] &+ box[3]); bottom = max(bottom, box[2] &+ box[4])
        }
        for (i, value) in [x, y, right &- x, bottom &- y].enumerated() {
            record.words[String(offset+i*4)] = value
        }
    }
}

/// The original cache advances by 20 bytes but copies the complete path. A
/// 21-byte path overlaps the following entry; a later write can change lookup.
/// Preserve those bytes within a bounded Swift array, without unsafe writes.
/// 0x41098e–0x410a99, cache base 0x455638, count stored at 0x458438.
struct OriginalSoundRegistry {
    private(set) var bytes = [UInt8](repeating: 0, count: 0x2e00)
    private(set) var count = 0
    mutating func register(_ path: String, previous: Int32 = -1) throws -> Int32 {
        let incoming = path.unicodeScalars.map { UInt8($0.value) } + [0]
        guard incoming.count <= 256 else {
            throw OriginalLoaderError.outsideVerifiedDomain("Original sound scratch buffer")
        }
        for index in 0..<count {
            let start = index*20
            if start+incoming.count <= bytes.count && bytes[start..<start+incoming.count].elementsEqual(incoming) {
                return Int32(index)
            }
        }
        // Weapon helper 40bd90 only allocates a new index when its destination
        // still contains -1. Frame registration uses the default -1 argument.
        if previous != -1 { return previous }
        let start = count*20
        guard start+incoming.count <= bytes.count else {
            throw OriginalLoaderError.outsideVerifiedDomain("Sound cache would overwrite the original count/global storage")
        }
        bytes.replaceSubrange(start..<start+incoming.count, with: incoming)
        defer { count += 1 }
        return Int32(count)
    }
}

/// The tested subset of fscanf: ASCII whitespace, %s, decimal %d prefixes.
/// Conversion failure retains the destination; out-of-range conversion throws.
struct OriginalFrameScanner {
    let bytes: [UInt8]
    var position = 0
    private(set) var eof = false
    init(_ text: String) throws {
        guard text.unicodeScalars.allSatisfy({ $0.value <= 255 }) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Decoded DAT must contain Latin-1 bytes")
        }
        bytes = text.unicodeScalars.map { UInt8($0.value) }
    }
    private func whitespace(_ byte: UInt8) -> Bool { byte == 32 || (9...13).contains(byte) }
    mutating func skipSpace() { while position < bytes.count && whitespace(bytes[position]) { position += 1 } }
    var isAtEnd: Bool { bytes[position...].allSatisfy(whitespace) }
    mutating func token() throws -> String {
        guard let result = optionalToken() else { throw OriginalLoaderError.outsideVerifiedDomain("Unexpected end of frame") }
        return result
    }
    mutating func optionalToken() -> String? {
        skipSpace()
        let start = position
        while position < bytes.count && !whitespace(bytes[position]) { position += 1 }
        if position == bytes.count { eof = true }
        guard position > start else { return nil }
        return String(String.UnicodeScalarView(bytes[start..<position].map { UnicodeScalar($0) }))
    }
    mutating func integer() throws -> Int32? {
        skipSpace()
        // fscanf sets EOF even when no assignment can be made after whitespace.
        guard position < bytes.count else { eof = true; return nil }
        var cursor = position
        var negative = false
        if cursor < bytes.count && (bytes[cursor] == 43 || bytes[cursor] == 45) {
            negative = bytes[cursor] == 45; cursor += 1
        }
        let start = cursor
        var value: Int64 = 0
        while cursor < bytes.count && (48...57).contains(bytes[cursor]) {
            value = value * 10 + Int64(bytes[cursor]-48)
            guard value <= (negative ? 2_147_483_648 : 2_147_483_647) else {
                throw OriginalLoaderError.outsideVerifiedDomain("MSVCR80 decimal overflow is not yet verified")
            }
            cursor += 1
        }
        guard cursor > start else { return nil }
        position = cursor
        if position == bytes.count { eof = true }
        return Int32(negative ? -value : value)
    }

    /// Declared finite-decimal CRT boundary. This does not establish MSVCR80
    /// rounding; the reference harness supplies Python binary64 at the same boundary.
    mutating func binary64() throws -> Double? {
        skipSpace()
        let suffix = String(String.UnicodeScalarView(bytes[position...].map { UnicodeScalar($0) }))
        guard let range = suffix.range(of: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"#, options: .regularExpression) else { return nil }
        let literal = String(suffix[range])
        guard let value = Double(literal), value.isFinite else {
            throw OriginalLoaderError.outsideVerifiedDomain("Non-finite decimal is outside the object-loader domain")
        }
        position += literal.utf8.count
        if position == bytes.count { eof = true }
        return value
    }
}
