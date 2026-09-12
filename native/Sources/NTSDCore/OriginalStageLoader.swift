import Foundation

/// Full original Stage storage. 40c910 owns sparse writes into 60 slots, each
/// 0x149b08 bytes; it does not initialize the entire allocation. No pointer or
/// guessed spawn-struct projection is used here. Stage gameplay remains separate.
public struct OriginalStageLoader {
    public static let stageSize = 0x149b08, phaseStride = 0x34c0, entryStride = 0xe0
    public private(set) var records: [OriginalStateRecord]

    public init(backing: [OriginalStateRecord]) throws {
        guard backing.count == 60, backing.allSatisfy({ $0.bytes.count == Self.stageSize }) else { throw Self.error("Stage table size") }
        records = backing
    }

    /// The original always decodes data/stage.dat through 414a30; use
    /// OriginalDATDecoder at that explicit file boundary before calling this.
    /// This loader does not contribute to the shared file checksum.
    /// Diagnostic callbacks may occur before a failure, but table changes commit
    /// only after the complete supported stream succeeds.
    public mutating func load(decoded: String,
                              onRead: ((Int) throws -> Void)? = nil,
                              onCheckpoint: (_ kind: String, _ stage: Int, _ phase: Int?, _ record: OriginalStateRecord) throws -> Void = { _, _, _, _ in }) throws {
        var candidate = self
        try candidate.consume(decoded: decoded, onRead: onRead, onCheckpoint: onCheckpoint)
        self = candidate
    }

    private mutating func consume(decoded: String,
                                  onRead: ((Int) throws -> Void)?,
                                  onCheckpoint: (String, Int, Int?, OriginalStateRecord) throws -> Void) throws {
        guard !decoded.unicodeScalars.contains(where: { $0.value == 0 || $0.value == 0x1a }) else { throw Self.error("NUL/DOS EOF in decoded stream") }
        var scanner = try OriginalFrameScanner(decoded, observeRead: onRead)
        for index in records.indices { try records[index].write(Int32(-1), at: 0) }
        var stageID: Int?, nextPhase: Int?, token: String?
        while !scanner.eof {
            if let next = try scanner.observedToken() { token = try Self.bounded(next, limit: 192) }
            guard token != nil else { throw Self.error("Uninitialized outer token") }
            if token != "<stage>" { continue }
            repeat {
                token = try Self.bounded(scanner.token(), limit: 192)
                if token == "id:" {
                    if let id = try scanner.integer() {
                        guard (0..<60).contains(id) else { throw Self.error("Stage ID outside verified allocation") }
                        stageID = Int(id)
                    }
                    guard let stage = stageID else { throw Self.error("Uninitialized stage ID after matching failure") }
                    try initialize(stage)
                    nextPhase = 0
                    try onCheckpoint("initialized", stage, nil, records[stage])
                }
                if token == "<phase>" {
                    guard let stage = stageID, let phase = nextPhase, (0..<100).contains(phase) else { throw Self.error("Uninitialized or overflowing phase index") }
                    let phaseOffset = phase*Self.phaseStride
                    try records[stage].write(UInt8(0), at: phaseOffset + 0xc)
                    try records[stage].write(Int32(phase + 1), at: 0)
                    var entry = -1
                    repeat {
                        token = try Self.bounded(scanner.token(), limit: 192)
                        if token == "bound:" {
                            if let value = try scanner.integer() { try records[stage].write(value, at: phaseOffset + 8) }
                            let bound = try records[stage].integer(at: phaseOffset + 8, as: Int32.self)
                            for index in 0..<60 {
                                try records[stage].write(bound &+ 80, at: phaseOffset + 0xf0 + index*Self.entryStride)
                            }
                        }
                        if token == "id:" {
                            entry += 1
                            guard entry < 60 else { throw Self.error("Entry table overflow is not recovered") }
                            if let value = try scanner.integer() { try records[stage].write(value, at: phaseOffset + 0xec + entry*Self.entryStride) }
                        }
                        if token == "music:" {
                            let path = try Self.bounded(scanner.token(), limit: 224)
                            for (index, byte) in (path.unicodeScalars.map { UInt8($0.value) } + [0]).enumerated() {
                                try records[stage].write(byte, at: phaseOffset + 0xc + index)
                            }
                        }
                        // Before the first id:, entry = -1. Original field writes
                        // then overlap the phase's music area; preserve that order.
                        let entryBase = phaseOffset + 0xec + entry*Self.entryStride
                        if let offset = Self.fields[token!], let value = try scanner.integer() {
                            try records[stage].write(value, at: entryBase + offset)
                        }
                        if token == "<boss>" { try records[stage].write(Int32(2), at: entryBase + 0x2c) }
                        if token == "<soldier>" {
                            try records[stage].write(Int32(1), at: entryBase + 0x2c)
                            try records[stage].write(Int32(50), at: entryBase + 0xc)
                        }
                        if token == "when_clear_goto_phase:", let value = try scanner.integer() {
                            try records[stage].write(value, at: phaseOffset + 0x34c0)
                        }
                        if token == "ratio:", let value = try scanner.binary64() {
                            try records[stage].writeBinary64(value, at: entryBase + 0x24)
                        }
                    } while token != "<phase_end>"
                    try onCheckpoint("phase", stage, phase, records[stage])
                    nextPhase = phase + 1
                }
            } while token != "<stage_end>"
        }
    }

    private mutating func initialize(_ stage: Int) throws {
        // 40c9f5..40cb79: phase-major, entry-major sparse writes. The entry
        // stride is not proof of a disjoint 0xe0-byte C struct at this offset.
        for phase in 0..<100 {
            let base = phase*Self.phaseStride
            try records[stage].write(Int32(-1), at: base + 8)
            try records[stage].write(Int32(-1), at: base + 0x34c0)
            try records[stage].write(UInt8(0), at: base + 0xc)
            for entry in 0..<60 {
                let start = base + 0xec + entry*Self.entryStride
                for (offset, value) in Self.defaults { try records[stage].write(value, at: start + offset) }
                try records[stage].write(UInt64(0), at: start + 0x24) // fldz/fst positive zero
                try records[stage].write(Int32(0), at: start + 0x20)
                try records[stage].write(Int32(9), at: start + 0x1c)
            }
        }
        try records[stage].write(Int32(-1), at: 0)
    }

    private static let fields = ["x:": 4, "hp:": 8, "times:": 0xc, "reserve:": 0x10,
                                 "join:": 0x14, "join_reserve:": 0x18, "act:": 0x1c, "y:": 0x20]
    private static let defaults: [(Int, Int32)] = [(0, -1), (4, 500), (8, 500), (0xc, 1), (0x10, 0), (0x2c, 0),
                                                  (0x14, 0), (0x18, 0)]
    private static func bounded(_ text: String, limit: Int) throws -> String {
        guard text.unicodeScalars.count < limit else { throw error("String exceeds verified buffer domain") }
        return text
    }
    private static func error(_ text: String) -> OriginalLoaderError { .outsideVerifiedDomain("Stage loader: \(text)") }
}
