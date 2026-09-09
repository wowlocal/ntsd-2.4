import Foundation

/// Whole43dd60 at declared allocator, processor-detection and file boundaries.
/// Own replay storage is shared with loading/input/menu cleanup. Host IO should
/// be buffered by the enclosing transaction: thrown observer/unsupported errors
/// roll back game records, but cannot undo external effects already performed.
public enum OriginalReplayWriter {
    public static let sourceCount = 0x630e18, capacity = 0x631200

    public enum Event: Equatable, Sendable {
        case format([UInt8])
        case calloc(UInt32)
        case compressed(Int32, Int)
        case adjusted
        case streamReturn(String, UInt32)
        case free(UInt32)
        case clearRecordingPointer
    }

    public struct Result: Sendable {
        public let compression: OriginalReplayCompression.Result
        public let stream: OriginalReplayFileOutput.Result
        public let temporary: UInt32
        /// Before the key prefix is added; the owned dead allocation retains
        /// the final adjusted bytes and their initialization provenance.
        public let compressed: OriginalStateRecord?
    }

    public static func write(globals: inout OriginalStateRecord,
                             memory: inout OriginalMenuPresentationMemory,
                             allocate: () throws -> UInt32,
                             processorSignature: () throws -> UInt32,
                             open: (OriginalReplayFileOutput.OpenRequest) throws -> Bool,
                             write: ([UInt8]) throws -> Int32,
                             close: () throws -> Int32,
                             observe: (Event) throws -> Void = { _ in }) throws -> Result {
        try run(globals: &globals, memory: &memory, codecFailureOrdinal: 0, bufferAvailable: true,
                allocate: allocate, processorSignature: processorSignature,
                open: open, write: write, close: close, observe: observe)
    }

    /// Private codec/CRT allocation failures are explicit research stimuli,
    /// distinct from a failure of the writer's own temporary-buffer allocation.
    static func run(globals: inout OriginalStateRecord, memory: inout OriginalMenuPresentationMemory,
                    codecFailureOrdinal: UInt32, bufferAvailable: Bool,
                    allocate: () throws -> UInt32, processorSignature: () throws -> UInt32,
                    open: (OriginalReplayFileOutput.OpenRequest) throws -> Bool,
                    write: ([UInt8]) throws -> Int32, close: () throws -> Int32,
                    observe: (Event) throws -> Void = { _ in }) throws -> Result {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize,
              memory.replayPointers.bytes.count == 8 else {
            throw OriginalStateError.invalidStorage("Replay writer globals/pointers extent")
        }
        var state = globals, owned = memory
        let base = OriginalMatchPreparation.globalBase
        func cstring(_ address: Int) throws -> [UInt8] {
            var result: [UInt8] = [], cursor = address-base
            while true {
                let byte = try state.integer(at: cursor, as: UInt8.self)
                if byte == 0 { return result }
                result.append(byte); cursor += 1
            }
        }
        let path = Array("recording\\".utf8) + (try cstring(0x44fd98))
        // Source sprintf is unbounded. At500 bytes from its destination is
        // the security cookie. Reject that unsupported stack overwrite rather
        // than truncate the game name or pretend its failure helper returned.
        guard path.count < 500 else {
            throw OriginalStateError.invalidStorage("Replay writer path overwrites original stack cookie")
        }
        try observe(.format(path))
        let recording = try owned.replayPointers.integer(at: 0, as: UInt32.self)
        let temporary = try allocate()
        if temporary != 0 {
            guard owned.allocations[temporary]?.live != true else {
                throw OriginalStateError.invalidStorage("Replay writer allocator returned live storage")
            }
        }
        try observe(.calloc(temporary))
        var destination: OriginalStateRecord? = temporary == 0 ? nil : try .init(
            bytes: .init(repeating: 0, count: capacity), defined: .init(repeating: true, count: capacity))
        //440434/44043c dereference the live compiled-version pointer before
        //codec allocation. A key overflowing into that global can destroy it.
        //Alternate pointer backing is not resolved by this native codec model.
        guard try state.integer(at: 0x44dce8-base, as: UInt32.self) == 0x44a2b4 else {
            throw OriginalStateError.invalidStorage("Replay writer modified codec version pointer")
        }
        let input: [UInt8]?
        if recording == 0 { input = nil }
        else {
            guard let allocation = owned.allocations[recording], allocation.live,
                  allocation.storage.bytes.count == sourceCount,
                  allocation.storage.defined.allSatisfy({ $0 }) else {
                throw OriginalStateError.invalidStorage("Replay writer source allocation/provenance")
            }
            input = allocation.storage.bytes
        }
        let compression = try OriginalReplayCompression.compress(input, sourceCount: UInt32(sourceCount),
            destination: &destination, capacity: UInt32(capacity), failureOrdinal: codecFailureOrdinal)
        if compression.longestMatchCalls != 0 {
            let selector = try state.integer(at: 0x44dd50-base, as: UInt32.self)
            if selector == 2 {
                //4428b0 lazily detects the processor at its first match search.
                //The initial call still uses generic matching. Native matching
                //is portable C; this word preserves the original game state.
                let signature = try processorSignature()
                try state.write(UInt32((signature & 0xf00) < 0x600 ? 0 : 1), at: 0x44dd50-base)
            }
        }
        let compressed = destination
        try observe(.compressed(compression.status, compression.length))
        // Read live globals AFTER compression: an unusually long key can alias
        // the selector. There is no callback or overlapping output during the
        // source repeated strlen loop, so this snapshot preserves those reads.
        let key = try cstring(0x44d7a0), prefixCount = min(key.count, compression.length)
        if prefixCount > 0 {
            guard var output = destination else {
                throw OriginalStateError.invalidStorage("Replay writer NULL key-adjustment destination")
            }
            for index in 0..<prefixCount {
                let byte = try output.integer(at: index, as: UInt8.self)
                try output.write(byte &+ key[index] &- 0x30, at: index)
            }
            destination = output
        }
        if let destination { owned.allocations[temporary] = .init(storage: destination) }
        try observe(.adjusted)
        func release(_ pointer: UInt32) throws {
            if pointer != 0 {
                guard var allocation = owned.allocations[pointer], allocation.live else {
                    throw OriginalStateError.invalidStorage("Replay writer free of unknown/dead allocation")
                }
                try observe(.free(pointer))
                allocation.live = false; owned.allocations[pointer] = allocation
            } else { try observe(.free(0)) }
        }
        let stream = try OriginalReplayFileOutput.run(destination.map { Array($0.bytes.prefix(compression.length)) },
            length: UInt32(compression.length), path: path, bufferAvailable: bufferAvailable,
            open: open, write: write, close: close,
            returned: { try observe(.streamReturn($0, $1)) }, afterClose: {
                try release(temporary)
                //43dea6 re-reads the pointer; do not substitute the earlier
                //compression argument or keep a buffer alive on IO failure.
                try release(owned.replayPointers.integer(at: 0, as: UInt32.self))
                try owned.replayPointers.write(UInt32(0), at: 0)
                try observe(.clearRecordingPointer)
            })
        globals = state; memory = owned
        return .init(compression: compression, stream: stream, temporary: temporary, compressed: compressed)
    }
}
