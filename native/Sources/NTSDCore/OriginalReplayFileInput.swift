import NTSDReplayCodec

/// Whole43e620, the playback loader, over supplied file bytes (nil: the
/// stream does not open). Allocation and free order is reported for the
/// caller's memory registry; the loaded recording becomes 4588ac.
/// APPLICATION_PLAYBACK_PLAN.md P1.
public enum OriginalReplayFileInput {
    public static let recordingSize = 0x630e18, capacity = 0x631200
    /// Payload lengths beyond this are refused: the original callocs them and
    /// reads into the result, and its behaviour on allocation failure (a NULL
    /// destination for istream::read) is outside this port.
    public static let payloadBound = 0x1000_0000

    public enum Event: Equatable, Sendable {
        /// calloc(1, count) with the call's ordinal (1: recording, 2: payload).
        case allocate(ordinal: Int, count: Int)
        case free(ordinal: Int)
        case close, destroy
    }
    public struct Result: Equatable, Sendable {
        /// 1 loaded, 0 rejected, -1 not opened.
        public let status: Int32
        /// The decompressed recording (0x630e18 bytes) on success.
        public let recording: [UInt8]?
        public let events: [Event]
        public let payloadLength: Int?, inflateStatus: Int32?, inflatedLength: Int?
        /// Bytes the original's uncompress writes past its 0x630e18-byte
        /// allocation (capacity 0x631200) before failing. On Windows they land
        /// in heap memory this port does not model; the status is the
        /// original's 0 and the overflow is reported, never silently dropped.
        public let overflowBytes: Int
    }

    public static func load(file: [UInt8]?, globals: inout OriginalStateRecord) throws -> Result {
        let base = OriginalMatchPreparation.globalBase
        var state = globals,events: [Event] = [.allocate(ordinal: 1,count: recordingSize)]
        try state.write(Int32(1),at: 0x44d030-base);try state.write(Int32(0),at: 0x450b74-base)
        func finish(_ status: Int32,_ recording: [UInt8]? = nil,payload: Int? = nil,inflate: Int32? = nil,length: Int? = nil,overflow: Int = 0) -> Result {
            globals = state
            return .init(status: status,recording: recording,events: events,payloadLength: payload,inflateStatus: inflate,inflatedLength: length,overflowBytes: overflow)
        }
        guard let file else {
            events += [.close,.free(ordinal: 1),.destroy];return finish(-1)
        }
        // seekg(0,end)/tellg: the whole file size, then back to the start.
        guard file.count >= 1000 else {
            events += [.close,.free(ordinal: 1),.destroy];return finish(0)
        }
        let n = Int(UInt32(file[0])|UInt32(file[1])<<8|UInt32(file[2])<<16|UInt32(file[3])<<24)
        guard n <= payloadBound else { throw OriginalStateError.invalidStorage("Playback payload length beyond the declared bound") }
        events.append(.allocate(ordinal: 2,count: n))
        // istream::read stops at the end of the file; the rest stays zero.
        var payload = [UInt8](repeating: 0,count: n)
        let available = min(n,file.count-4)
        if available > 0 { payload.replaceSubrange(0..<available,with: file[4..<4+available]) }
        events.append(.close)
        // Undo the writer's key on the leading min(n, strlen(44d7a0)) bytes.
        var key: [UInt8] = [],p = 0x44d7a0-base
        while try state.integer(at: p,as: UInt8.self) != 0 { key.append(try state.integer(at: p,as: UInt8.self));p += 1 }
        for i in 0..<min(n,key.count) { payload[i] = payload[i] &- key[i] &+ 0x30 }
        var output = [UInt8](repeating: 0,count: capacity)
        var length = UInt32(capacity),produced: UInt32 = 0
        let status = output.withUnsafeMutableBufferPointer { destination in
            payload.withUnsafeBufferPointer { source in
                ntsd_replay_codec_uncompress(destination.baseAddress,&length,&produced,source.baseAddress,UInt32(n))
            }
        }
        let overflow = max(0,Int(produced)-recordingSize)
        guard status == 0 && Int(length) == recordingSize else {
            events += [.free(ordinal: 1),.free(ordinal: 2),.destroy]
            return finish(0,payload: n,inflate: status,length: Int(length),overflow: overflow)
        }
        events += [.free(ordinal: 2),.destroy]
        return finish(1,Array(output[0..<recordingSize]),payload: n,inflate: status,length: Int(length))
    }
}
