import Foundation

public struct OriginalBitmapInput: Codable, Equatable, Sendable {
    public let path: String, present: Bool
    public let width: Int32?, height: Int32?
    public init(path: String, present: Bool, width: Int32? = nil, height: Int32? = nil) {
        self.path = path; self.present = present; self.width = width; self.height = height
    }
}

public struct OriginalLoadedBitmap: Equatable, Sendable {
    public typealias Constructor = (_ path: String, _ optional: Bool, _ backing: [UInt8]) throws -> OriginalLoadedBitmap
    public let input: OriginalBitmapInput
    public let optional: Bool
    /// Original +0 is canonicalized to 1 for an opaque present surface, 0 for
    /// absence. Pixel/device state is not implemented by this storage component.
    public internal(set) var storage: OriginalStateRecord
    /// Device operation requested by the original missing-mirror fallback.
    public internal(set) var mirroredFrom: Int? = nil

    /// Storage writes of 43ee50 with image dimensions supplied by a device adapter.
    /// Used by both Object sheets and background resources.
    static func construct(_ resource: OriginalBitmapInput, optional: Bool, fill: UInt8) throws -> Self {
        if !resource.present && !optional { throw OriginalLoaderError.outsideVerifiedDomain("Required bitmap is unavailable") }
        return Self(input: resource, optional: optional, storage: try constructionStorage(resource, backing: Array(repeating: fill, count: 0x1f50)))
    }

    static func checkedConstruction(_ bitmap: Self, path: String, optional: Bool) throws -> Self {
        guard bitmap.input.path == path, bitmap.optional == optional, bitmap.storage.bytes.count == 0x1f50,
              try bitmap.storage.integer(at: 0, as: UInt32.self) <= 1 else {
            throw OriginalStateError.invalidStorage("Loader bitmap constructor binding")
        }
        return bitmap
    }

    /// Shared wrapper writes; the caller decides how to handle a missing required
    /// resource. Device lifecycle and error reporting live in OriginalBitmapConstructor.
    static func constructionStorage(_ resource: OriginalBitmapInput, backing: [UInt8]) throws -> OriginalStateRecord {
        guard backing.count == 0x1f50 else { throw OriginalLoaderError.outsideVerifiedDomain("Bitmap allocation extent") }
        var record = try OriginalStateRecord(bytes: backing, defined: Array(repeating: false, count: 0x1f50))
        try record.write(UInt32(resource.present ? 1 : 0), at: 0)
        if resource.present {
            guard let width = resource.width, let height = resource.height, width > 0, height > 0 else { throw OriginalLoaderError.outsideVerifiedDomain("Invalid supplied bitmap dimensions") }
            try record.write(width, at: 4); try record.write(height, at: 8)
        }
        return record
    }
}

/// Caller-owned Blt fields for the absent-mirror fallback. Bitmap indices bind
/// to the loader's shared resource order; an adapter supplies actual surfaces.
public struct OriginalBitmapMirrorRequest: Equatable, Sendable {
    public let normalBitmap: Int, mirrorBitmap: Int
    public let destination: [Int32], source: [Int32], flags: UInt32
    public let effects: OriginalStateRecord
}

/// One complete strlen+1 weapon-path allocation. Bytes include the copied NUL.
/// The optional token binds a supplied allocator response; nil leaves native
/// storage unbound to a reference address. Earlier allocations remain owned
/// when a later field replaces the path, until this Object is released.
public struct OriginalWeaponSoundPathAllocation: Equatable, Sendable {
    public typealias Allocate = (_ slot: Int, _ byteCount: Int) throws -> UInt32?
    public let slot: Int, token: UInt32?, storage: OriginalStateRecord
}

public struct OriginalLoadedObject: Equatable, Sendable {
    public let header: OriginalStateRecord
    public let nameTail: OriginalStateRecord
    public let frames: [OriginalFrameRecord]
    public let frameStorage: [OriginalStateRecord]
    public let weaponSoundPaths: [Int: String]
    public internal(set) var weaponSoundAllocations: [OriginalWeaponSoundPathAllocation] = []
}

/// Continuous decoded Object stream, EXE 40ef70, with shared sound registration.
/// DAT decoding, filesystem/image decoding, pixels and audio devices are separate
/// boundaries. Nothing here selects a character or changes the source data.
public struct OriginalObjectLoader {
    var resources = OriginalLoaderResources()
    public private(set) var bitmaps: [OriginalLoadedBitmap] {
        get { resources.bitmaps } set { resources.bitmaps = newValue }
    }
    public private(set) var checksum: UInt32 {
        get { resources.checksum } set { resources.checksum = newValue }
    }
    private var sounds: OriginalSoundRegistry {
        get { resources.sounds } set { resources.sounds = newValue }
    }
    private var frameHeap: OriginalFrameHeap {
        get { resources.frameHeap } set { resources.frameHeap = newValue }
    }
    public var frameAllocations: [OriginalFrameAllocation] { frameHeap.allocations }
    public var soundCount: Int { sounds.count }
    public var soundBytes: [UInt8] { sounds.bytes }
    public init() {}

    /// Header bitmap pointers use global bitmap index + 1; zero is reserved for
    /// null in this model. Weapon string pointers use their field ordinal + 1.
    /// These explicit encodings differ from the bootstrap's non-null slot ordinals.
    /// The snapshot adapter binds only established pointers, never arbitrary words.
    public mutating func load(decoded: String, id: Int32, type: Int32,
                              headerBacking: [UInt8], tailBacking: [UInt8], bitmapFill: UInt8 = 0xa5,
                              frameBacking: [UInt8]? = nil,
                              frameAllocation: (OriginalFrameAllocationKind, Int) throws -> UInt32? = { _, _ in nil },
                              weaponSoundAllocation: OriginalWeaponSoundPathAllocation.Allocate = { _, _ in nil },
                              bitmapSource: (String) throws -> OriginalBitmapInput,
                              constructBitmap: OriginalLoadedBitmap.Constructor? = nil,
                              onMirror: (OriginalBitmapMirrorRequest) throws -> Void = { _ in },
                              onProgress: () throws -> Void = {},
                              onRead: ((Int) throws -> Void)? = nil,
                              onChecksum: (UInt32) throws -> Void = { _ in },
                              onSoundCache: ([UInt8], Int) throws -> Void = { _, _ in },
                              onMessage: (_ checksum: UInt32) throws -> Void = { _ in },
                              onNewSound: (OriginalSoundRegistration) throws -> Void = { _ in },
                              onFrame: (OriginalFrameRecord) -> Void = { _ in },
                              onFrameStorage: (Int, OriginalStateRecord) -> Void = { _, _ in }) throws -> OriginalLoadedObject {
        var candidate = self
        let result = try candidate.consume(decoded: decoded, id: id, type: type, headerBacking: headerBacking,
                                           tailBacking: tailBacking, bitmapFill: bitmapFill, frameBacking: frameBacking, frameAllocation: frameAllocation, weaponSoundAllocation: weaponSoundAllocation,
                                           bitmapSource: bitmapSource, constructBitmap: constructBitmap, onMirror: onMirror, onProgress: onProgress, onRead: onRead, onChecksum: onChecksum, onSoundCache: onSoundCache, onMessage: onMessage, onNewSound: onNewSound, onFrame: onFrame, onFrameStorage: onFrameStorage)
        self = candidate
        return result
    }

    private mutating func consume(decoded: String, id: Int32, type: Int32, headerBacking: [UInt8], tailBacking: [UInt8],
                                  bitmapFill: UInt8, frameBacking: [UInt8]?, frameAllocation: (OriginalFrameAllocationKind, Int) throws -> UInt32?,
                                  weaponSoundAllocation: OriginalWeaponSoundPathAllocation.Allocate,
                                  bitmapSource: (String) throws -> OriginalBitmapInput,
                                  constructBitmap: OriginalLoadedBitmap.Constructor?,
                                  onMirror: (OriginalBitmapMirrorRequest) throws -> Void,
                                  onProgress: () throws -> Void,
                                  onRead: ((Int) throws -> Void)?,
                                  onChecksum: (UInt32) throws -> Void,
                                  onSoundCache: ([UInt8], Int) throws -> Void,
                                  onMessage: (UInt32) throws -> Void,
                                  onNewSound: (OriginalSoundRegistration) throws -> Void,
                                  onFrame: (OriginalFrameRecord) -> Void, onFrameStorage: (Int, OriginalStateRecord) -> Void) throws -> OriginalLoadedObject {
        guard headerBacking.count == 0x7a4, tailBacking.count == 0x3c else { throw Self.error("Object storage size") }
        guard frameBacking == nil || frameBacking?.count == 400*0x178 else { throw Self.error("Frame backing size") }
        guard !decoded.unicodeScalars.contains(where: { $0.value == 0 || $0.value == 0x1a }) else { throw Self.error("NUL/DOS EOF in decoded stream") }
        var input = try OriginalFrameScanner(decoded, observeRead: onRead)
        var header = try OriginalStateRecord(bytes: headerBacking, defined: Array(repeating: false, count: 0x7a4))
        var tail = try OriginalStateRecord(bytes: tailBacking, defined: Array(repeating: false, count: 0x3c))
        var frames = OriginalFrameLoader(); frames.sounds = sounds
        frames.backing = frameBacking; frames.heap = frameHeap; frames.heap.fill = bitmapFill
        var weaponPaths: [Int: String] = [:], weaponAllocations: [OriginalWeaponSoundPathAllocation] = []
        for offset in stride(from: 0x90, through: 0xa0, by: 4) { try header.write(Int32(0), at: offset) }
        for offset in [0xa4, 0xa8, 0xac] { try header.write(Int32(-1), at: offset) }
        try Self.string("none", at: 0x700, limit: 40, in: &header)
        try Self.string("none", at: 0, limit: 60, in: &tail)
        try header.write(Int32(0), at: 0x498)
        try header.write(id, at: 0x6f4); try header.write(type, at: 0x6f8)
        for offset in stride(from: 0x62c, through: 0x650, by: 4) { try header.write(Int32(3000), at: offset) }
        for offset in stride(from: 0xb0, to: 0x3d0, by: 4) { try header.write(Int32(0), at: offset) }
        var token: String?, messageCountdown = 10
        while !input.eof {
            if let next = try input.observedToken() { token = next }
            guard let current = token else { throw Self.error("No initialized outer token") }
            for (index, scalar) in current.unicodeScalars.enumerated() {
                checksum &+= UInt32(bitPattern: Int32(Int8(bitPattern: UInt8(scalar.value)))) &* UInt32(index)
            }
            try onChecksum(checksum)
            //40f129 initializes ten;40f1ac decrements after the outer-token
            //checksum, before interpreting that token. Inner field scans do
            //not advance it.43d230 handles at most one queued message.
            messageCountdown -= 1
            if messageCountdown == 0 {
                messageCountdown = 10
                try onMessage(checksum)
            }
            if token == "<bmp_begin>" {
                try onProgress() //40f1d8, before each BMP field read
                token = try input.token()
                while token != "<bmp_end>" {
                    let tag = token!
                    if tag.hasPrefix("file") {
                        var count = try header.integer(at: 0x498, as: Int32.self)
                        if count > 0 { try finishSheet(Int(count), header: &header, bitmapFill: bitmapFill, source: bitmapSource, constructBitmap: constructBitmap, onMirror: onMirror, onProgress: onProgress) }
                        count += 1
                        guard (1...10).contains(count) else { throw Self.error("Sprite sheet arrays outside verified storage") }
                        try header.write(count, at: 0x498)
                        try Self.string(try input.token(), at: 0x474 + Int(count)*40, limit: 40, in: &header)
                    }
                    if tag == "head:" || tag == "small:" {
                        let path = try input.token(), offset = tag == "head:" ? 0x700 : 0x72c
                        try Self.string(path, at: offset, limit: tag == "head:" ? 40 : 36, in: &header)
                        let bitmap = try appendBitmap(path, optional: false, fill: bitmapFill, source: bitmapSource, constructBitmap: constructBitmap)
                        try header.write(UInt32(bitmap + 1), at: tag == "head:" ? 0x6fc : 0x728)
                    }
                    if let offset = Self.integerFields[tag], let value = try input.integer() { try header.write(value, at: offset) }
                    if let offset = Self.doubleFields[tag], let value = try input.binary64() { try header.writeBinary64(value, at: offset) }
                    if tag == "name:" { try Self.string(try input.token(), at: 0, limit: 60, in: &tail) }
                    if let offset = ["w:": 0x650, "h:": 0x678, "row:": 0x6a0, "col:": 0x6c8][tag] {
                        let index = Int(try header.integer(at: 0x498, as: Int32.self))
                        if let value = try input.integer() { try header.write(value, at: offset + index*4) }
                    }
                    if let ordinal = ["weapon_hit_sound:": 0, "weapon_drop_sound:": 1, "weapon_broken_sound:": 2][tag] {
                        let path = try input.token(), indexOffset = 0xa4 + ordinal*4
                        guard path.unicodeScalars.count < 256 else { throw Self.error("Weapon sound scratch buffer") }
                        let bytes = path.unicodeScalars.map { UInt8($0.value) } + [0]
                        let token = try weaponSoundAllocation(ordinal, bytes.count)
                        if let token {
                            guard token != 0, !weaponAllocations.contains(where: { $0.token == token }) else {
                                throw Self.error("NULL or reused weapon path allocation is outside the verified domain")
                            }
                        }
                        //40fbe6/40fc65/40fce8: store the new pointer, copy every
                        //byte through NUL, then enter40bd90. No preceding path
                        //allocation is freed here, even on a repeated field.
                        try header.write(UInt32(ordinal + 1), at: 0x98 + ordinal*4)
                        weaponAllocations.append(.init(slot: ordinal, token: token,
                            storage: try .init(bytes: bytes, defined: Array(repeating: true, count: bytes.count))))
                        weaponPaths[ordinal] = path
                        let previous = try header.integer(at: indexOffset, as: Int32.self)
                        _ = try frames.sounds.register(path, previous: previous, kind: .weapon,
                            assignIndex: { try header.write($0, at: indexOffset) }, onNewSound: onNewSound, onCommit: onSoundCache)
                    }
                    try onProgress() //40fd23 returns to40f1d8
                    token = try input.token()
                }
                let index = Int(try header.integer(at: 0x498, as: Int32.self))
                guard index > 0 else { throw Self.error("Header without initialized sprite sheet") }
                try finishSheet(index, header: &header, bitmapFill: bitmapFill, source: bitmapSource, constructBitmap: constructBitmap, onMirror: onMirror, onProgress: onProgress)
            }
            if token == "<weapon_strength_list>" {
                var index: Int32 = 0
                token = try input.token()
                while token != "<weapon_strength_list_end>" {
                    if token == "entry:" {
                        let previous = index // original computes the name pointer before %d updates the index
                        if let next = try input.integer() { index = next }
                        guard (0..<10).contains(index), (0..<10).contains(previous) else { throw Self.error("Weapon strength table index") }
                        try Self.string(try input.token(), at: 0x3d0 + Int(previous)*30, limit: 30, in: &header)
                    } else if let offset = Self.weaponFields[token!], let value = try input.integer() {
                        try header.write(value, at: offset + Int(index)*80)
                    }
                    token = try input.token()
                }
            }
            if token == "<frame>" {
                let record = try frames.consumeFrameBody(&input, allocate: frameAllocation, onNewSound: onNewSound, onSoundCache: onSoundCache)
                onFrame(record)
                onFrameStorage(record.number, try frames.storage(at: record.number))
                token = "<frame_end>"
            }
        }
        sounds = frames.sounds
        frameHeap = frames.heap
        let rawFrames = try (0..<400).map { try frames.storage(at: $0) }
        var object = OriginalLoadedObject(header: header, nameTail: tail,
                                    frames: try (0..<400).map { try frames.projected(at: $0, record: rawFrames[$0]) },
                                    frameStorage: rawFrames, weaponSoundPaths: weaponPaths)
        object.weaponSoundAllocations = weaponAllocations
        return object
    }

    private mutating func appendBitmap(_ path: String, optional: Bool, fill: UInt8,
                                       source: (String) throws -> OriginalBitmapInput,
                                       constructBitmap: OriginalLoadedBitmap.Constructor?) throws -> Int {
        let bitmap: OriginalLoadedBitmap
        if let constructBitmap {
            bitmap = try .checkedConstruction(constructBitmap(path, optional, Array(repeating: fill, count: 0x1f50)), path: path, optional: optional)
        } else {
            let resource = try source(path)
            guard resource.path == path else { throw Self.error("Bitmap provider returned a different path") }
            bitmap = try .construct(resource, optional: optional, fill: fill)
        }
        let index = bitmaps.count
        bitmaps.append(bitmap)
        return index
    }

    private mutating func finishSheet(_ slot: Int, header: inout OriginalStateRecord, bitmapFill: UInt8,
                                      source: (String) throws -> OriginalBitmapInput,
                                      constructBitmap: OriginalLoadedBitmap.Constructor?,
                                      onMirror: (OriginalBitmapMirrorRequest) throws -> Void, onProgress: () throws -> Void) throws {
        var first: Int32 = 0
        for previous in 1..<slot {
            first &+= (try header.integer(at: 0x6a0 + previous*4, as: Int32.self)) &* (try header.integer(at: 0x6c8 + previous*4, as: Int32.self))
        }
        try header.write(first, at: 0x628 + slot*4)
        let path = try Self.readString(header, at: 0x474 + slot*40)
        let normal = try appendBitmap(path, optional: false, fill: bitmapFill, source: source, constructBitmap: constructBitmap)
        try header.write(UInt32(normal + 1), at: 0x750 + slot*4)
        try onProgress() //40f314/40fdde
        guard path.unicodeScalars.count >= 4 else { throw Self.error("Bitmap filename shorter than mirror suffix replacement") }
        let mirrorPath = String(path.dropLast(4)) + "_mirror.bmp"
        var mirror = try appendBitmap(mirrorPath, optional: true, fill: bitmapFill, source: source, constructBitmap: constructBitmap)
        try header.write(UInt32(mirror + 1), at: 0x778 + slot*4)
        try onProgress() //40f3d5/40fe9b, before testing the surface
        if try bitmaps[mirror].storage.integer(at: 0, as: UInt32.self) == 0 {
            // Original leaks the failed wrapper, allocates a fresh normal image,
            // then asks DirectDraw to mirror it. Pixels remain a device boundary.
            mirror = try appendBitmap(path, optional: false, fill: bitmapFill, source: source, constructBitmap: constructBitmap)
            bitmaps[mirror].mirroredFrom = normal
            guard try bitmaps[normal].storage.integer(at: 0, as: UInt32.self) != 0,
                  try bitmaps[mirror].storage.integer(at: 0, as: UInt32.self) != 0 else {
                throw Self.error("Mirror Blt reaches an unavailable surface")
            }
            //40f454/40ff1b memset100, then size100/DDFX2. Every effects byte
            //and both rectangles have caller provenance; no retained stack input.
            var effects = try OriginalStateRecord(bytes: Array(repeating: 0, count: 100), defined: Array(repeating: true, count: 100))
            try effects.write(UInt32(100), at: 0); try effects.write(UInt32(2), at: 4)
            let rectangle: [Int32] = try [0, 0, bitmaps[normal].storage.integer(at: 4, as: Int32.self), bitmaps[normal].storage.integer(at: 8, as: Int32.self)]
            try onMirror(.init(normalBitmap: normal, mirrorBitmap: mirror, destination: rectangle, source: rectangle, flags: 0x1000800, effects: effects))
        }
        try header.write(UInt32(mirror + 1), at: 0x778 + slot*4)
        try onProgress() //40f500/40ffc3, also with an existing mirror
        let w = try header.integer(at: 0x650 + slot*4, as: Int32.self)
        let h = try header.integer(at: 0x678 + slot*4, as: Int32.self)
        let row = try header.integer(at: 0x6a0 + slot*4, as: Int32.self)
        let col = try header.integer(at: 0x6c8 + slot*4, as: Int32.self)
        let count = row &* col
        guard row > 0, (0...500).contains(count) else { throw Self.error("Bitmap slice table outside verified domain") }
        try bitmaps[normal].storage.write(count, at: 0xc)
        try bitmaps[mirror].storage.write(count, at: 0xc)
        let sheetWidth = try bitmaps[normal].storage.integer(at: 4, as: Int32.self)
        for index in 0..<Int(count) {
            let x = (Int32(index) % row) &* (w &+ 1), y = (Int32(index) / row) &* (h &+ 1)
            for (bitmap, horizontal) in [(normal, x), (mirror, sheetWidth &- x &- w)] {
                for (offset, value) in [(0x10, horizontal), (0x7e0, y), (0xfb0, w), (0x1780, h)] {
                    try bitmaps[bitmap].storage.write(value, at: offset + index*4)
                }
            }
        }
    }

    private static let integerFields = ["walking_frame_rate": 0, "running_frame_rate": 0x18, "weapon_hp:": 0x90, "weapon_drop_hurt:": 0x94]
    private static let doubleFields = ["walking_speed": 8, "walking_speedz": 0x10, "running_speed": 0x20, "running_speedz": 0x28,
                                      "heavy_walking_speed": 0x30, "heavy_walking_speedz": 0x38, "heavy_running_speed": 0x40,
                                      "heavy_running_speedz": 0x48, "jump_height": 0x50, "jump_distance": 0x58, "jump_distancez": 0x60,
                                      "dash_height": 0x68, "dash_distance": 0x70, "dash_distancez": 0x78, "rowing_height": 0x80, "rowing_distance": 0x88]
    private static let weaponFields = ["dvx:": 0xc4, "dvy:": 0xc8, "fall:": 0xcc, "arest:": 0xd0, "vrest:": 0xd4,
                                      "respond:": 0xd8, "effect:": 0xdc, "bdefend:": 0xf0, "injury:": 0xf4, "zwidth:": 0xf8]
    private static func error(_ detail: String) -> OriginalLoaderError { .outsideVerifiedDomain("Object loader: \(detail)") }
    private static func string(_ value: String, at offset: Int, limit: Int, in record: inout OriginalStateRecord) throws {
        let bytes = value.unicodeScalars.map { UInt8($0.value) }
        guard bytes.count < limit else { throw error("String exceeds verified storage") }
        for (index, byte) in (bytes + [0]).enumerated() { try record.write(byte, at: offset + index) }
    }
    private static func readString(_ record: OriginalStateRecord, at offset: Int) throws -> String {
        var bytes: [UInt8] = [], index = offset
        while true {
            let byte = try record.integer(at: index, as: UInt8.self)
            if byte == 0 { return String(String.UnicodeScalarView(bytes.map { UnicodeScalar($0) })) }
            bytes.append(byte); index += 1
        }
    }
}
