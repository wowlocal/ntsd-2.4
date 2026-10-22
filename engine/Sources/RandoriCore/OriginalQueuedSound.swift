/// Original419e60 queue drain and401a30 buffer playback. COM responses remain
/// numeric requests; buffer external effects until the whole tick commits.
public enum OriginalQueuedSound {
    public struct Event: Codable, Equatable, Sendable {
        public enum Kind: String, Codable, Sendable { case queueWrite, play, method }
        public let kind: Kind, arguments: [UInt32]
        public init(_ kind: Kind, _ arguments: [UInt32]) { self.kind = kind; self.arguments = arguments }
    }
    public typealias Request = (Event) throws -> Int32
    private static func word(_ globals: OriginalStateRecord, _ address: Int) throws -> UInt32 {
        try globals.integer(at: address-0x44d000, as: UInt32.self)
    }
    private static func method(_ buffer: UInt32, _ offset: UInt32, _ values: [UInt32] = [], request: Request) throws {
        guard buffer != 0 else { throw OriginalStateError.invalidStorage("Queued sound: Null COM buffer") }
        _ = try request(.init(.method, [buffer,offset]+values))
    }

    /// A logical game-global word owns the supplied COM buffer token. This
    /// declared request boundary does not model arbitrary COM reentrancy.
    public static func play(bufferWordAddress: UInt32, loop: UInt32, globals: OriginalStateRecord,
                            request: Request) throws {
        _ = try request(.init(.play, [bufferWordAddress,loop]))
        guard try word(globals,0x44eecc) != 0 else { return }
        let address = Int(bufferWordAddress)
        guard try word(globals,address) != 0 else { return }
        try method(word(globals,address),0x48,request: request)
        try method(word(globals,address),0x34,[0],request: request)
        try method(word(globals,address),0x30,[0,0,loop == 0 ? 0 : 1],request: request)
    }

    public static func drain(globals: inout OriginalStateRecord, request: Request) throws {
        var staged = globals
        func signed(_ address: Int) throws -> Int32 { Int32(bitPattern: try word(staged,address)) }
        guard try word(staged,0x44eecc) != 0 else { return }
        for (count,pending,first,second,buffers) in [(400,0x457588,0x452170,0x457bc8,0x452948),
                                                    (80,0x453e10,0x4554c8,0x4527e8,0x451db0)] {
            for index in 0..<count {
                let offset = index*4, flag = pending+offset
                guard try signed(flag) > 0 else { continue }
                // The source reads the right-channel weight first, then left.
                let right = try signed(first+offset), left = try signed(second+offset), sum = right &+ left
                try staged.write(Int32(0),at: flag-0x44d000)
                _ = try request(.init(.queueWrite,[UInt32(flag),0]))
                let level = min(sum,100)
                guard level > 0 else { continue }
                let bufferWord = buffers+offset, pan = ((right &- left) &* 1500)/100
                try method(word(staged,bufferWord),0x40,[UInt32(bitPattern: pan)],request: request)
                let base = try ((signed(0x44d000) &- 100) &* 3800)/100
                let attenuation = ((level &- 100) &* 2000)/100
                try method(word(staged,bufferWord),0x3c,[UInt32(bitPattern: base &+ attenuation)],request: request)
                if try signed(0x44d000) > 0 {
                    try play(bufferWordAddress: UInt32(bufferWord),loop: 0,globals: staged,request: request)
                }
            }
        }
        globals = staged
    }
}
