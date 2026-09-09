import Foundation
import NTSDReplayCodec

/// Original whole43f4b0/43f400 memory-compression contract. This is the codec
/// dependency of43dd60, not file saving or an initialized result-caller join.
public enum OriginalReplayCompression {
    public struct AllocationEvent: Equatable, Sendable {
        public let kind: UInt32, ordinal: UInt32, count: UInt32, nativeSize: UInt32
    }
    public struct Result: Sendable {
        public let status: Int32
        /// Original mutable length word: unchanged when compression fails.
        public let length: Int
        public let written: Int
        /// Algorithm's private allocation/free requests; native ABI sizes.
        public let allocationEvents: [AllocationEvent]
        /// Recorded before reclaiming private host storage after a failed call.
        /// This does not reconstruct the original Windows heap's leaked bytes.
        public let unreleasedAllocations: Int
        /// Actual native longest_match invocations, used by the original
        /// writer's lazy processor-selector lifetime. No host CPUID is run.
        public let longestMatchCalls: UInt32
    }
    private static let lock = NSLock()

    public static func compress(_ source: [UInt8], destination: inout OriginalStateRecord,
                                level: Int32 = -1) throws -> Result {
        try compress(source, destination: &destination, level: level, failureOrdinal: 0)
    }

    /// Explicit allocator failure stimulus for the original-instruction corpus.
    static func compress(_ source: [UInt8], destination: inout OriginalStateRecord,
                         level: Int32, failureOrdinal: UInt32) throws -> Result {
        guard source.count <= Int(UInt32.max), destination.bytes.count <= Int(UInt32.max) else {
            throw OriginalStateError.invalidStorage("Replay compression: original 32-bit length extent")
        }
        var output: OriginalStateRecord? = destination
        let result = try compress(source, sourceCount: UInt32(source.count), destination: &output,
                                  capacity: UInt32(destination.bytes.count), level: level, failureOrdinal: failureOrdinal)
        destination = output!
        return result
    }

    /// Preserve NULL pointer with a nonzero declared length.43dd60 can still
    /// continue after the resulting stream error; NULL is not an empty buffer.
    static func compress(_ source: [UInt8]?, sourceCount: UInt32,
                         destination: inout OriginalStateRecord?, capacity: UInt32,
                         level: Int32 = -1, failureOrdinal: UInt32 = 0) throws -> Result {
        guard source == nil || source!.count == Int(sourceCount),
              destination == nil || destination!.bytes.count == Int(capacity) else {
            throw OriginalStateError.invalidStorage("Replay compression: backing/declared extent")
        }
        var input = (source ?? [])+[0], output = (destination?.bytes ?? [])+[UInt8](repeating: 0x69, count: 16)
        var result = NTSDReplayCodecResult()
        // zlib1.1.4 lazily initializes shared tables. Serialize native calls.
        lock.lock()
        input.withUnsafeMutableBufferPointer { inputBuffer in
            output.withUnsafeMutableBufferPointer { outputBuffer in
                ntsd_replay_codec_compress(destination == nil ? nil : outputBuffer.baseAddress!, capacity,
                    source == nil ? nil : inputBuffer.baseAddress!, sourceCount, level, failureOrdinal, &result)
            }
        }
        lock.unlock()
        guard result.contractViolation == 0, result.written <= capacity, result.eventCount <= 16,
              destination != nil || result.written == 0,
              output.suffix(16).allSatisfy({ $0 == 0x69 }) else {
            throw OriginalStateError.invalidStorage("Replay compression: native codec storage contract")
        }
        let events: [AllocationEvent] = withUnsafePointer(to: &result.events) { pointer in
            pointer.withMemoryRebound(to: NTSDReplayCodecEvent.self, capacity: 16) { values in
                (0..<Int(result.eventCount)).map { i in
                    let e = values[i]
                    return .init(kind: e.kind, ordinal: e.ordinal, count: e.count, nativeSize: e.size)
                }
            }
        }
        if let before = destination {
            var defined = before.defined
            for i in 0..<Int(result.written) { defined[i] = true }
            destination = try .init(bytes: Array(output.prefix(Int(capacity))), defined: defined)
        }
        return .init(status: result.status, length: Int(result.length), written: Int(result.written),
                     allocationEvents: events, unreleasedAllocations: Int(result.unreleasedCount),
                     longestMatchCalls: result.longestMatchCalls)
    }
}
