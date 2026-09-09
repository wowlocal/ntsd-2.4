import Foundation

/// Whole421cdc..422218, with the original alternate continuation at422944.
/// The retained word is the caller's own round result (rootSP64). A paused
/// path can leave it unknown; it is required only at the original read.
/// Game records commit together. The enclosing tick must buffer external IO.
public enum OriginalResultRecording {
    public enum Continuation: UInt32, Codable, Sendable {
        case resultLayout = 0x422218, indicators = 0x422944
    }
    public enum Event: Equatable, Sendable {
        case restorePlayback
        case writer(OriginalReplayWriter.Event)
    }
    public struct Result: Sendable {
        public let continuation: Continuation
        public let writer: OriginalReplayWriter.Result?
    }

    public static func apply(state: inout OriginalMatchPreparation,
                             context: inout OriginalInputControlContext, stageDefeated: UInt32?,
                             allocate: () throws -> UInt32, processorSignature: () throws -> UInt32,
                             open: (OriginalReplayFileOutput.OpenRequest) throws -> Bool,
                             write: ([UInt8]) throws -> Int32, close: () throws -> Int32,
                             observe: (Event) throws -> Void = { _ in }) throws -> Result {
        let catalog = state.catalog
        return try apply(world: state.world, actors: state.actors, globals: &state.globals,
            context: &context, stageDefeated: stageDefeated, header: { index in
                guard catalog.objects.indices.contains(index) else { throw error("Object binding") }
                return catalog.objects[index].header
            }, allocate: allocate, processorSignature: processorSignature,
            open: open, write: write, close: close, observe: observe)
    }

    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Result recording: "+text) }

    static func apply(world: OriginalStateRecord, actors: [OriginalStateRecord], globals: inout OriginalStateRecord,
                      context: inout OriginalInputControlContext, stageDefeated: UInt32?,
                      header: (Int) throws -> OriginalStateRecord,
                      codecFailureOrdinal: UInt32 = 0, bufferAvailable: Bool = true,
                      allocate: () throws -> UInt32, processorSignature: () throws -> UInt32,
                      open: (OriginalReplayFileOutput.OpenRequest) throws -> Bool,
                      write: ([UInt8]) throws -> Int32, close: () throws -> Int32,
                      observe: (Event) throws -> Void = { _ in }) throws -> Result {
        var state = globals, owned = context
        func global(_ address: Int) throws -> Int32 { try state.integer(at: address-0x44d000, as: Int32.self) }
        func set(_ address: Int, _ value: Int32) throws { try state.write(value, at: address-0x44d000) }
        func active(_ slot: Int) throws -> Bool { try world.integer(at: 4+slot, as: UInt8.self) != 0 }
        func actor(_ slot: Int) throws -> OriginalStateRecord {
            let index = Int(try world.integer(at: 0x194+4*slot, as: UInt32.self))
            guard actors.indices.contains(index) else { throw error("Actor binding") }
            return actors[index]
        }
        func object(_ actor: OriginalStateRecord) throws -> OriginalStateRecord {
            try header(Int(actor.integer(at: 0x368, as: UInt32.self)))
        }
        func record(_ offset: Int, _ value: Int32) throws {
            // Each source store reloads4588a8. Preserve that allocation's
            // identity, including when playback and recording share backing.
            let pointer = try owned.memory.replayPointers.integer(at: 0, as: UInt32.self)
            guard var allocation = owned.memory.allocations[pointer], allocation.live else { throw error("Recording ownership") }
            try allocation.storage.write(value, at: offset)
            owned.memory.allocations[pointer] = allocation
        }

        let timer = try global(0x450bdc)
        if timer < 100 { try set(0x450bbc, global(0x450bbc) &+ 1) }
        let continuation: Continuation
        var writer: OriginalReplayWriter.Result?
        if UInt32(bitPattern: timer &- 101) > 248 { continuation = .indicators }
        else {
            continuation = .resultLayout
            if timer == 101 {
                if try global(0x450be4) != 0 && global(0x450b80) != 0 && global(0x450b84) == 0 {
                    var count: Int32 = 0
                    for seat in 0..<8 {
                        let offset = 0x14+4*seat
                        let slot: Int
                        if try active(seat) { slot = seat }
                        else if try active(seat+10) { slot = seat+10 }
                        else { try record(offset, -1); continue }
                        let participant = try actor(slot)
                        try record(offset+0x20, object(participant).integer(at: 0x6f4, as: Int32.self))
                        try record(offset, slot < 10 ? 1 : 0)
                        for (source, destination) in [(0x364,0x40),(0x358,0x60),(0x348,0x80),
                                                     (0x34c,0xa0),(0x350,0xc0),(0x35c,0xe0)] {
                            try record(offset+destination, participant.integer(at: source, as: Int32.self))
                        }
                        if try global(0x451160) == 1 {
                            guard let stageDefeated else { throw error("Retained stage result unavailable") }
                            try record(offset+0x100, stageDefeated == 1 ? -1 :
                                (participant.integer(at: 0x2fc, as: Int32.self) > 0 ? 2 : 1))
                        } else {
                            let winner = try global(0x450bf8)
                            if winner >= 0 {
                                try record(offset+0x100, winner == participant.integer(at: 0x364, as: Int32.self) ?
                                    (participant.integer(at: 0x2fc, as: Int32.self) > 0 ? 2 : 1) : -1)
                            }
                        }
                        count += 1
                    }
                    try record(0x10, count)
                    if try global(0x451160) == 4 {
                        for i in 0..<4 { try record(0x134+4*i, global(0x451b64+4*i)) }
                    }
                    try record(0x144, global(0x450bbc))
                    try set(0x450b6c, 0); try set(0x450b70, 2)
                    if try owned.memory.replayPointers.integer(at: 4, as: UInt32.self) != 0 && global(0x450b88) != 0 {
                        try observe(.restorePlayback)
                        try owned.restorePlayback(globals: &state)
                    }
                    for (offset, address) in [(0x8ac,0x44fb6c),(0x8b0,0x450c18),(0x8b4,0x450c1c),
                                               (0x8b8,0x450c20),(0x8bc,0x450c24)] {
                        try record(offset, global(address))
                    }
                    var living: Int32 = 0
                    for slot in 0..<400 where try active(slot) {
                        let a = try actor(slot)
                        if try object(a).integer(at: 0x6f8, as: Int32.self) == 0 &&
                            a.integer(at: 0x364, as: Int32.self) == 5 && a.integer(at: 0x2fc, as: Int32.self) > 0 { living += 1 }
                    }
                    let mode = try global(0x451160)
                    if mode == 1 { try record(0x8c0, living <= 0 ? 1 : 0) }
                    else if mode == 4 {
                        // Signed division truncates toward zero. Each LEA/IMUL
                        // below wraps to32 bits, including the decimal offset.
                        let first = try global(0x44d758), second = try global(0x44d75c)
                        var packed = try global(0x44d380) &* 10 &+ global(0x451b74)
                        packed = packed &* 10 &+ first/100
                        packed = packed &* 10 &+ (first%100)/10
                        packed = try packed &* 10 &+ global(0x44d384)
                        packed = try packed &* 10 &+ global(0x451b78) &+ 0x1adbb
                        packed = packed &* 10 &+ second/100
                        packed = packed &* 10 &+ (second%100)/10
                        try record(0x8c0, packed)
                    }
                    writer = try OriginalReplayWriter.run(globals: &state, memory: &owned.memory,
                        codecFailureOrdinal: codecFailureOrdinal, bufferAvailable: bufferAvailable,
                        allocate: allocate, processorSignature: processorSignature,
                        open: open, write: write, close: close, observe: { try observe(.writer($0)) })
                    try set(0x450b80, 0)
                }
                if try global(0x450bdc) == 101 { try set(0x450b84, 0) }
            }
        }
        globals = state; context = owned
        return .init(continuation: continuation, writer: writer)
    }
}
