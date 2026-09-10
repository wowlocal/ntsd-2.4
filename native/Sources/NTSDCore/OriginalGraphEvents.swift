/// Whole message400 callback and401e90 event drain at declared COM boundaries.
/// The64-byte local record is helper-entry backing; actual Windows stack/queue
/// provenance and callback reentrancy remain separate from this request model.
public enum OriginalGraphEvents {
    public struct Request: Codable, Equatable, Sendable {
        public enum Kind: String, Codable, Sendable { case getEvent, method, windowDefault }
        public let kind: Kind, arguments: [UInt32]
        public init(_ kind: Kind,_ arguments: [UInt32]) { self.kind = kind;self.arguments = arguments }
    }
    public struct Response: Codable, Equatable, Sendable {
        public let result: Int32, code: UInt32?, first: UInt32?, second: UInt32?
        public init(result: Int32 = 0,code: UInt32? = nil,first: UInt32? = nil,second: UInt32? = nil) {
            self.result = result;self.code = code;self.first = first;self.second = second
        }
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Graph events: "+text) }
    /// Each missing output leaves the corresponding local word untouched. Only
    /// exactE_ABORT terminates; every other result processes the retained words.
    /// Providers may throw on exhaustion/cancellation. Buffer external effects;
    /// late failure rolls back the full local record, including terminal outputs.
    public static func receive(_ input: OriginalWindowInput.Message,globals: OriginalStateRecord,
        local: inout OriginalStateRecord,request: (Request) throws -> Response,
        store: (Int,[UInt8]) throws -> Void = { _,_ in }) throws -> Int32 {
        guard input.message == 0x400,globals.bytes.count == OriginalMatchPreparation.globalSize,
              local.bytes.count == 64 else { throw error("Message/global/local extent") }
        var next = local
        func interface(_ address: Int) throws -> UInt32 {
            let token = try globals.integer(at: address-OriginalMatchPreparation.globalBase,as: UInt32.self)
            guard token != 0 else { throw error("Missing required interface") };return token
        }
        func put(_ offset: Int,_ value: UInt32?) throws {
            if let value {
                try next.write(value,at: offset)
                try store(offset,(0..<4).map { UInt8(truncatingIfNeeded: value >> ($0*8)) })
            }
        }
        while true {
            let response = try request(.init(.getEvent,[interface(0x44f048),0x20,0]))
            try put(0x34,response.code);try put(0x3c,response.first);try put(0x38,response.second)
            if UInt32(bitPattern: response.result) == 0x80004004 { break }
            let code = try next.integer(at: 0x34,as: UInt32.self)
            if code == 1 {
                try OriginalMusicPlayback.seekToStart(position: interface(0x44f04c),request: { event in
                    guard event.kind == .method else { throw error("Unexpected seek event") }
                    return .init(result: try request(.init(.method,event.arguments)).result)
                })
            }
            // Original reads parameter2 first, then parameter1 and the live code.
            let second = try next.integer(at: 0x38,as: UInt32.self)
            let first = try next.integer(at: 0x3c,as: UInt32.self)
            let liveCode = try next.integer(at: 0x34,as: UInt32.self)
            _ = try request(.init(.method,[interface(0x44f048),0x30,liveCode,first,second]))
        }
        let result = try request(.init(.windowDefault,[input.window,input.message,input.wParam,input.lParam])).result
        local = next;return result
    }
}
