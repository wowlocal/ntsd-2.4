import Foundation

/// Original43dd60's fixed ofstream sequence, at the declared open/descriptor
/// boundary. C-locale path conversion and original CRT buffering are retained.
/// This does not implement compression, the whole writer, or Windows file IO.
public enum OriginalReplayFileOutput {
    public struct OpenRequest: Equatable, Sendable {
        public let path: [UInt16]
        public let mode: [UInt8]
        public let share: Int32
    }
    public struct Result: Equatable, Sendable {
        /// ios state after construct, header write, payload write, close, destroy.
        public let streamStates: [UInt32]
        public let bufferRequested: Bool
        public let unbuffered: Bool
    }

    /// open receives the original C-locale UTF-16 path, binary write mode and
    /// share0x40. Descriptor writes return their actual byte count or -1; close
    /// returns zero or -1. These results are data, not thrown observer failures.
    public static func write(_ payload: [UInt8], path: [UInt8],
                             open: (OpenRequest) throws -> Bool,
                             write: ([UInt8]) throws -> Int32,
                             close: () throws -> Int32) throws -> Result {
        try run(payload, path: path, bufferAvailable: true, open: open, write: write, close: close)
    }

    /// The original FILE buffer's failed4096-byte malloc is a research input.
    /// Swift storage is private; this does not reproduce Windows heap pressure.
    static func run(_ payload: [UInt8], path: [UInt8], bufferAvailable: Bool,
                    open: (OpenRequest) throws -> Bool,
                    write: ([UInt8]) throws -> Int32,
                    close: () throws -> Int32) throws -> Result {
        guard payload.count <= Int(Int32.max) else {
            throw OriginalStateError.invalidStorage("Replay stream: original signed write count")
        }
        return try run(payload, length: UInt32(payload.count), path: path, bufferAvailable: bufferAvailable,
                       open: open, write: write, close: close)
    }

    /// A failed outer calloc can supply NULL with a nonzero length. An already
    /// failed stream never reads it. Keep the writer's frees between close and
    /// destruction, including when an IO return value reports failure.
    static func run(_ payload: [UInt8]?, length: UInt32, path: [UInt8], bufferAvailable: Bool,
                    open: (OpenRequest) throws -> Bool,
                    write: ([UInt8]) throws -> Int32,
                    close: () throws -> Int32,
                    returned: (String, UInt32) throws -> Void = { _, _ in },
                    afterClose: () throws -> Void = {}) throws -> Result {
        guard length <= Int32.max, payload == nil || payload!.count == Int(length) else {
            throw OriginalStateError.invalidStorage("Replay stream: backing/declared extent")
        }
        // Actual MSVCP80 _Fiopen truncates the C-locale conversion to259 units.
        let widePath = path.prefix(while: { $0 != 0 }).prefix(259).map(UInt16.init)
        let opened = try open(.init(path: widePath, mode: [0x77, 0x62], share: 0x40))
        var state: UInt32 = opened ? 0 : 2
        var states = [state], buffer: [UInt8] = [], bufferRequested = false
        try returned("construct", state)

        func consume(_ supplied: [UInt8]?, count: Int) throws {
            guard state == 0 else { state |= 4; return }
            if count == 0 { return }
            guard let bytes = supplied else {
                throw OriginalStateError.invalidStorage("Replay stream: NULL payload invalid parameter")
            }
            bufferRequested = true
            if !bufferAvailable {
                // _getbuf uses FILE+14's two-byte backing with _IONBF set;
                // _flsbuf sends each byte immediately, without a final flush.
                for byte in bytes {
                    if try write([byte]) != 1 { state |= 4; return }
                }
                return
            }
            var cursor = 0
            while cursor < bytes.count {
                if buffer.count == 4096 {
                    let written = try write(buffer)
                    buffer.removeAll(keepingCapacity: true)
                    // Real _flsbuf retains the triggering byte even if flushing
                    // the preceding buffer failed. close later writes it.
                    buffer.append(bytes[cursor]); cursor += 1
                    if written != 4096 { state |= 4; return }
                }
                let count = min(4096-buffer.count, bytes.count-cursor)
                buffer.append(contentsOf: bytes[cursor..<cursor+count]); cursor += count
            }
        }

        try consume((0..<4).map { UInt8(truncatingIfNeeded: length >> (8*$0)) }, count: 4)
        states.append(state)
        try returned("write", state)
        try consume(payload, count: Int(length))
        states.append(state)
        try returned("write", state)
        if opened {
            var failed = false
            if !buffer.isEmpty { failed = try write(buffer) != Int32(buffer.count) }
            let closeResult = try close()
            if failed || closeResult != 0 { state |= 2 }
        } else { state |= 2 }
        states.append(state)
        try returned("close", state)
        try afterClose()
        // The explicit close detached FILE; destruction performs no further IO.
        states.append(state)
        try returned("destroy", state)
        return .init(streamStates: states, bufferRequested: bufferRequested,
                     unbuffered: bufferRequested && !bufferAvailable)
    }
}
