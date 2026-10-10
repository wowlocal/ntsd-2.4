import Foundation

/// The recovered numerical part of the original 0x178-byte frame record.
/// Keys are byte offsets from the record, not object offsets. Absent words were
/// not initialized by the original constructor and must not acquire defaults.
/// Pointers and name bytes are represented separately; no x86 code runs here.
public struct OriginalFrameRecord: Codable, Equatable, Sendable {
    public let number: Int
    public internal(set) var name: String
    /// The words by decimal byte offset. Kept compact (MEMORY_LOADING M2): the
    /// record's 94 four-byte offsets 0...0x174 as slots with a presence mask,
    /// any other key apart; 400 projected frames for each of 137 objects held
    /// 161 MB as dictionaries. Equality and the JSON form are the dictionary's.
    public internal(set) var words: [String: Int32] {
        get {
            var result = extra
            for slot in 0..<Self.slotCount where isPresent(slot) { result[String(slot*4)] = slots[slot] }
            return result
        }
        set {
            slots = []; low = 0; high = 0; extra = [:]
            for (key, value) in newValue {
                if let slot = Self.slot(key) { setWord(value, offset: slot*4) } else { extra[key] = value }
            }
        }
    }
    /// Absent slots hold 0, so equal words give equal storage.
    private var slots: [Int32] = [], low: UInt64 = 0, high: UInt64 = 0
    private var extra: [String: Int32] = [:]
    public internal(set) var sound: String?
    /// A name write can replace part/all of the original pointer. Keep its bits
    /// explicitly; it is neither a valid path nor a null pointer.
    public internal(set) var opaqueSoundPointer: String? = nil
    public internal(set) var interactions: [[Int32]] = []
    public internal(set) var bodies: [[Int32]] = []

    static let slotCount = 0x178/4
    private static func slot(_ key: String) -> Int? {
        guard let value = Int(key), String(value) == key, value >= 0, value < 0x178, value % 4 == 0 else { return nil }
        return value/4
    }
    private func isPresent(_ slot: Int) -> Bool { slot < 64 ? low >> UInt64(slot) & 1 != 0 : high >> UInt64(slot-64) & 1 != 0 }
    mutating func setWord(_ value: Int32, offset: Int) {
        precondition(offset >= 0 && offset < 0x178 && offset % 4 == 0, "frame word offset")
        let slot = offset/4
        if slots.isEmpty { slots = Array(repeating: 0, count: Self.slotCount) }
        slots[slot] = value
        if slot < 64 { low |= 1 << UInt64(slot) } else { high |= 1 << UInt64(slot-64) }
    }

    init(number: Int) {
        self.number = number; name = ""
        // Defaults live in OriginalStateRecord.frame; this is only a projection.
    }
    public subscript(offset: Int) -> Int32? {
        guard offset >= 0, offset < 0x178, offset % 4 == 0 else { return extra[String(offset)] }
        return isPresent(offset/4) ? slots[offset/4] : nil
    }
    public func field(_ name: String) -> Int32? {
        guard let offset = OriginalFrameLoader.frameFields[name + ":"] else { return nil }
        return self[offset]
    }

    enum CodingKeys: String, CodingKey { case number, name, words, sound, opaqueSoundPointer, interactions, bodies }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        number = try c.decode(Int.self, forKey: .number); name = try c.decode(String.self, forKey: .name)
        sound = try c.decodeIfPresent(String.self, forKey: .sound)
        opaqueSoundPointer = try c.decodeIfPresent(String.self, forKey: .opaqueSoundPointer)
        interactions = try c.decode([[Int32]].self, forKey: .interactions); bodies = try c.decode([[Int32]].self, forKey: .bodies)
        words = try c.decode([String: Int32].self, forKey: .words)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(number, forKey: .number); try c.encode(name, forKey: .name); try c.encode(words, forKey: .words)
        try c.encodeIfPresent(sound, forKey: .sound); try c.encodeIfPresent(opaqueSoundPointer, forKey: .opaqueSoundPointer)
        try c.encode(interactions, forKey: .interactions); try c.encode(bodies, forKey: .bodies)
    }
}

public enum OriginalLoaderError: Error, CustomStringConvertible {
    case outsideVerifiedDomain(String)
    public var description: String {
        switch self { case .outsideVerifiedDomain(let message): return message }
    }
}

/// Shared Frame mechanism for continuous Object streams and isolated sections.
/// Name writes within the whole record are preserved, including sound overlap;
/// writes beyond that record or the five-box allocations remain unsupported.
/// Reference: docs/FRAME_LOADER.md, original EXE constructor and frame branch.
public struct OriginalFrameLoader {
    public private(set) var frames: [Int: OriginalFrameRecord] = [:]
    public private(set) var storage: [Int: OriginalStateRecord] = [:]
    var heap = OriginalFrameHeap()
    var backing: [UInt8]? = nil
    var sounds = OriginalSoundRegistry()
    public init() {}

    public func storage(at index: Int) throws -> OriginalStateRecord {
        if let record = storage[index] { return record }
        guard (0..<400).contains(index) else { throw OriginalStateError.invalidStorage("Frame index") }
        let raw = backing.map { Array($0[index*0x178..<(index+1)*0x178]) } ?? Array(repeating: UInt8(0xa5), count: 0x178)
        return try .frame(over: raw)
    }

    func projected(at index: Int, record: OriginalStateRecord) throws -> OriginalFrameRecord {
        var result = OriginalFrameRecord(number: index)
        result.setWord(Int32(try record.integer(at: 0, as: UInt8.self)), offset: 0)
        for offset in stride(from: 4, to: 0x178, by: 4) where offset != 0x130 && offset != 0x134 && !(0x15c..<0x174).contains(offset) {
            if record.allDefined(in: offset..<(offset+4)) {
                result.setWord(try record.integer(at: offset, as: Int32.self), offset: offset)
            }
        }
        result.name = result[0] == 0 ? "" : try OriginalFrameHeap.string(in: record, at: 0x15c)
        for (countOffset, pointerOffset, stride) in [(0x128, 0x130, 20), (0x12c, 0x134, 10)] {
            let count = Int(try record.integer(at: countOffset, as: Int32.self))
            guard (0...5).contains(count) else { throw OriginalStateError.invalidStorage("Frame box count") }
            if count > 0 {
                let pointer = try record.integer(at: pointerOffset, as: UInt32.self)
                let words = try heap.words(at: pointer, count: count*stride)
                let boxes = (0..<count).map { Array(words[$0*stride..<($0+1)*stride]) }
                if countOffset == 0x128 { result.interactions = boxes } else { result.bodies = boxes }
            }
        }
        let pointer = try record.integer(at: 0x170, as: UInt32.self)
        if pointer != 0 {
            result.sound = try heap.string(at: pointer)
            if result.sound == nil { result.opaqueSoundPointer = "0x" + String(pointer, radix: 16) }
        }
        return result
    }

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
    mutating func consumeFrameBody(_ input: inout OriginalFrameScanner,
                                  allocate: (OriginalFrameAllocationKind, Int) throws -> UInt32? = { _, _ in nil },
                                  onNewSound: (OriginalSoundRegistration) throws -> Void = { _ in },
                                  onSoundCache: ([UInt8], Int) throws -> Void = { _, _ in }) throws -> OriginalFrameRecord {
        guard let index = try input.integer(), (0..<400).contains(index) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Expected a frame index in 0...399")
        }
        let name = try input.token()
        let nameBytes = name.unicodeScalars.map { UInt8($0.value) } + [0]
        guard nameBytes.count <= 0x1c else {
            throw OriginalLoaderError.outsideVerifiedDomain("Frame name crosses the end of its record")
        }
        var record = try storage(at: Int(index))
        var updatedSounds = sounds
        for (offset, byte) in nameBytes.enumerated() { try record.write(byte, at: 0x15c + offset) }
        // 0x41043b–0x41046e: only these counters are reset at frame entry.
        try record.write(UInt8(1), at: 0)
        try record.write(Int32(0), at: 0x128); try record.write(Int32(0), at: 0x12c)
        var interactions: [[Int32]] = [], bodies: [[Int32]] = []
        while true {
            let token = try input.token()
            if token == "<frame_end>" { break }
            if let offset = Self.frameFields[token] {
                if let value = try input.integer() { try record.write(value, at: offset) }
            } else if let fields = Self.pointFields[token] {
                let end = String(token.dropLast()) + "_end:"
                while true {
                    let tag = try input.token()
                    if tag == end { break }
                    if let offset = fields[tag], let value = try input.integer() {
                        try record.write(value, at: offset)
                    }
                }
            } else if token == "itr:" || token == "bdy:" {
                let isInteraction = token == "itr:"
                let count = isInteraction ? interactions.count : bodies.count
                guard count < 5 else { throw OriginalLoaderError.outsideVerifiedDomain("Original allocation holds five boxes") }
                let fields = isInteraction ? Self.interactionFields : Self.bodyFields
                var box = [Int32](repeating: 0, count: isInteraction ? 20 : 10)
                let kind: OriginalFrameAllocationKind = isInteraction ? .interactions : .bodies
                let size = isInteraction ? 400 : 200, pointerOffset = isInteraction ? 0x130 : 0x134
                if count == 0 {
                    let pointer = try heap.allocate(size, kind: kind, address: allocate(kind, size))
                    try record.write(pointer, at: pointerOffset)
                }
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
                let pointer = try record.integer(at: pointerOffset, as: UInt32.self)
                for (offset, value) in box.enumerated() { try heap.write(value, at: pointer, offset: (count*box.count + offset)*4) }
                if isInteraction { interactions.append(box) } else { bodies.append(box) }
            } else if token == "sound:" {
                let sound = try input.token()
                let bytes = sound.unicodeScalars.map { UInt8($0.value) } + [0]
                guard bytes.count <= 256 else { throw OriginalLoaderError.outsideVerifiedDomain("Sound scratch buffer") }
                let pointer = try heap.allocate(bytes.count, kind: .sound, address: allocate(.sound, bytes.count))
                try record.write(pointer, at: 0x170)
                for (offset, byte) in bytes.enumerated() { try heap.write(byte, at: pointer, offset: offset) }
                try record.write(Int32(-1), at: 0x174) // 41097b, before lookup/loading
                _ = try updatedSounds.register(sound, assignIndex: { try record.write($0, at: 0x174) }, onNewSound: onNewSound, onCommit: onSoundCache)
            }
            // Original %s loop ignores unknown tokens; it does not strip comments.
        }
        try record.write(Int32(interactions.count), at: 0x128)
        try record.write(Int32(bodies.count), at: 0x12c)
        // 0x411ef0–0x412274: signed comparisons and wrapping 32-bit ADD/SUB.
        // Empty arrays leave the old aggregate bounds in place.
        try Self.updateBounds(interactions, offset: 0x138, record: &record)
        try Self.updateBounds(bodies, offset: 0x148, record: &record)
        let result = try projected(at: Int(index), record: record)
        storage[Int(index)] = record; frames[Int(index)] = result; sounds = updatedSounds
        return result
    }

    private static func updateBounds(_ boxes: [[Int32]], offset: Int, record: inout OriginalStateRecord) throws {
        guard let first = boxes.first else { return }
        var x = first[1], y = first[2], right = first[1] &+ first[3], bottom = first[2] &+ first[4]
        for box in boxes.dropFirst() {
            x = min(x, box[1]); y = min(y, box[2])
            right = max(right, box[1] &+ box[3]); bottom = max(bottom, box[2] &+ box[4])
        }
        for (i, value) in [x, y, right &- x, bottom &- y].enumerated() {
            try record.write(value, at: offset+i*4)
        }
    }
}

/// A newly assigned index, before WAV loading and before the cache is committed.
public struct OriginalSoundRegistration: Sendable {
    public enum Kind: String, Codable, Sendable { case frame, weapon }
    public let kind: Kind, index: Int, path: String, cacheBefore: [UInt8]
}

/// The original cache advances by 20 bytes but copies the complete path. A
/// 21-byte path overlaps the following entry; a later write can change lookup.
/// Preserve those bytes within a bounded Swift array, without unsafe writes.
/// 0x41098e–0x410a99, cache base 0x455638, count stored at 0x458438.
struct OriginalSoundRegistry {
    private(set) var bytes = [UInt8](repeating: 0, count: 0x2e00)
    private(set) var count = 0
    init() {}
    init(bytes: [UInt8]) throws {
        guard bytes.count == 0x2e00 else { throw OriginalStateError.invalidStorage("Sound registry global backing") }
        self.bytes = bytes
    }
    mutating func register(_ path: String, previous: Int32 = -1, kind: OriginalSoundRegistration.Kind = .frame,
                           assignIndex: (Int32) throws -> Void = { _ in },
                           onNewSound: (OriginalSoundRegistration) throws -> Void = { _ in },
                           onCommit: ([UInt8], Int) throws -> Void = { _, _ in }) throws -> Int32 {
        let incoming = path.unicodeScalars.map { UInt8($0.value) } + [0]
        guard incoming.count <= 256 else {
            throw OriginalLoaderError.outsideVerifiedDomain("Original sound scratch buffer")
        }
        for index in 0..<count {
            let start = index*20
            if start+incoming.count <= bytes.count && bytes[start..<start+incoming.count].elementsEqual(incoming) {
                try assignIndex(Int32(index))
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
        // Both source callers load/SetVolume BEFORE copying the cache path and
        // incrementing458438. Cache hits and retained weapon indices skip this.
        try assignIndex(Int32(count))
        try onNewSound(.init(kind: kind, index: count, path: path, cacheBefore: bytes))
        bytes.replaceSubrange(start..<start+incoming.count, with: incoming)
        let assigned = count
        count += 1
        try onCommit(bytes, count)
        return Int32(assigned)
    }
}

/// The tested subset of fscanf: ASCII whitespace, %s, decimal %d prefixes.
/// VC80 decimal accumulation wraps at 32 bits. Failed conversion consumes its
/// optional sign but retains the destination. See docs/research/CRT_SCANNER.md.
struct OriginalFrameScanner {
    let bytes: [UInt8]
    var position = 0
    private(set) var eof = false
    private let observeRead: ((Int) throws -> Void)?
    init(_ text: String, observeRead: ((Int) throws -> Void)? = nil) throws {
        guard text.unicodeScalars.allSatisfy({ $0.value <= 255 }) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Decoded DAT must contain Latin-1 bytes")
        }
        bytes = text.unicodeScalars.map { UInt8($0.value) }
        self.observeRead = observeRead
    }
    private func whitespace(_ byte: UInt8) -> Bool { byte == 32 || (9...13).contains(byte) }
    mutating func skipSpace() { while position < bytes.count && whitespace(bytes[position]) { position += 1 } }
    var isAtEnd: Bool { bytes[position...].allSatisfy(whitespace) }
    mutating func token() throws -> String {
        guard let result = try observedToken() else { throw OriginalLoaderError.outsideVerifiedDomain("Unexpected end of frame") }
        return result
    }
    mutating func observedToken() throws -> String? {
        let result = optionalToken()
        try observeRead?(position)
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
        guard position < bytes.count else { eof = true; try observeRead?(position); return nil }
        var negative = false
        if bytes[position] == 43 || bytes[position] == 45 {
            negative = bytes[position] == 45; position += 1
        }
        let start = position
        var value: UInt32 = 0
        while position < bytes.count && (48...57).contains(bytes[position]) {
            value = value &* 10 &+ UInt32(bytes[position]-48)
            position += 1
        }
        if position == bytes.count { eof = true }
        try observeRead?(position)
        guard position > start else { return nil }
        return Int32(bitPattern: negative ? 0 &- value : value)
    }

    /// Finite-decimal subset checked against actual MSVCR80 instructions for
    /// the original catalog. General decimal lexing/rounding is still open;
    /// see docs/research/CRT_SCANNER.md and CATALOG_PRECISION.md.
    mutating func binary64() throws -> Double? {
        skipSpace()
        // The anchored regex below can consume only this ASCII alphabet and
        // has no lookaround. Text after its first other byte cannot affect the
        // match. Keep the regex/conversion and scanner state updates unchanged.
        var end = position
        while end < bytes.count {
            let byte = bytes[end]
            guard (48...57).contains(byte) || byte == 43 || byte == 45 ||
                byte == 46 || byte == 69 || byte == 101 else { break }
            end += 1
        }
        let suffix = String(String.UnicodeScalarView(bytes[position..<end].map { UnicodeScalar($0) }))
        guard let range = suffix.range(of: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"#, options: .regularExpression) else { try observeRead?(position); return nil }
        let literal = String(suffix[range])
        guard let value = Double(literal), value.isFinite else {
            throw OriginalLoaderError.outsideVerifiedDomain("Non-finite decimal is outside the object-loader domain")
        }
        position += literal.utf8.count
        if position == bytes.count { eof = true }
        try observeRead?(position)
        return value
    }
}
