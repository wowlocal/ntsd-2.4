/// Whole402d70 network exit at declared platform boundaries. The returned word
/// preserves observed EAX; the original menu caller ignores it.
public enum OriginalNetworkExit {
    public enum Region: String, Codable, Sendable { case globals, local }
    public struct Request: Codable, Equatable, Sendable {
        public enum Kind: String, Codable, Sendable { case sendTo, closeSocket, cleanup, message }
        public let kind: Kind, arguments: [UInt32], bytes: [UInt8]
        /// sendTo carries payload then16 sockaddr bytes; arguments are socket,
        /// payload count, flags and sockaddr count. No host pointer is imported.
        public init(_ kind: Kind,_ arguments: [UInt32] = [],_ bytes: [UInt8] = []) { self.kind = kind;self.arguments = arguments;self.bytes = bytes }
    }
    /// Local256 bytes end before the original cookie. Required unknown inputs
    /// and throwing providers/observers roll back both records. Callers must
    /// buffer external effects until their encompassing operation commits.
    public static func run(globals: inout OriginalStateRecord,local: inout OriginalStateRecord,
        request: (Request) throws -> Int32,store: (Region,Int,[UInt8]) throws -> Void = { _,_,_ in }) throws -> Int32 {
        let base = OriginalMatchPreparation.globalBase
        guard globals.bytes.count == OriginalMatchPreparation.globalSize,local.bytes.count == 256 else { throw OriginalStateError.invalidStorage("Network exit storage extent") }
        var state = globals,temporary = local
        func word(_ a: Int) throws -> UInt32 { try state.integer(at: a-base,as: UInt32.self) }
        func put(_ r: Region,_ o: Int,_ bytes: [UInt8]) throws {
            for (i,b) in bytes.enumerated() { if r == .globals { try state.write(b,at: o+i) } else { try temporary.write(b,at: o+i) } }
            try store(r,o,bytes)
        }
        func commit(_ result: Int32) -> Int32 { globals = state;local = temporary;return result }
        var listener = try word(0x44f1b4)
        if listener != 0,try word(0x44f1b0) != 0 {
            try put(.local,0,[UInt8](repeating: 0,count: 256))
            let literal = Array("Client want to EXIT.".utf8)
            for i in [0,8,12] { try put(.local,i,Array(literal[i..<i+4])) }
            try put(.local,20,[0])
            for i in [4,16] { try put(.local,i,Array(literal[i..<i+4])) }
            // Source loads address bytes0,2,1,3 and writes in that same order.
            for i in [0,2,1,3] { try put(.local,20+i,[state.integer(at: 0x44f208-base+i,as: UInt8.self)]) }
            var payload: [UInt8] = []
            while true {
                let b = try temporary.integer(at: payload.count,as: UInt8.self)
                if b == 0 { break };payload.append(b)
            }
            let target = try (0..<16).map { try state.integer(at: 0x44f58c-base+$0,as: UInt8.self) }
            let sent = try request(.init(.sendTo,[listener,UInt32(payload.count),0,16],payload+target))
            if sent == -1 {
                _ = try request(.init(.message,[0,0],Array("sendto()".utf8)+[0]+Array("Error".utf8)+[0]))
                return commit(try request(.init(.closeSocket,[word(0x44f1b4)])))
            }
            listener = try word(0x44f1b4)
        }
        _ = try request(.init(.closeSocket,[listener]))
        try put(.globals,0x44f1b4-base,[0,0,0,0]);try put(.globals,0x44f1b0-base,[0,0,0,0])
        return commit(try request(.init(.cleanup)))
    }
}
