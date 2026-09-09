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
        // Actual MSVCP80 _Fiopen truncates the C-locale conversion to259 units.
        let widePath = path.prefix(while: { $0 != 0 }).prefix(259).map(UInt16.init)
        let opened = try open(.init(path: widePath, mode: [0x77, 0x62], share: 0x40))
        var state: UInt32 = opened ? 0 : 2
        var states = [state], buffer: [UInt8] = [], bufferRequested = false

        func consume(_ bytes: [UInt8]) throws {
            guard state == 0 else { state |= 4; return }
            if bytes.isEmpty { return }
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

        let length = UInt32(payload.count)
        try consume((0..<4).map { UInt8(truncatingIfNeeded: length >> (8*$0)) })
        states.append(state)
        try consume(payload)
        states.append(state)
        if opened {
            var failed = false
            if !buffer.isEmpty { failed = try write(buffer) != Int32(buffer.count) }
            let closeResult = try close()
            if failed || closeResult != 0 { state |= 2 }
        } else { state |= 2 }
        states.append(state)
        // The explicit close detached FILE; destruction performs no further IO.
        states.append(state)
        return .init(streamStates: states, bufferRequested: bufferRequested,
                     unbuffered: bufferRequested && !bufferAvailable)
    }
}
