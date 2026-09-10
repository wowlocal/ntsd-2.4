/// Original428420 deferred connection action at declared platform boundaries.
/// Returns the original next presentation/epilogue entry, not a whole menu ret.
/// Local offsets refer to callerSP+14, excluding saved control/cookie fields.
public enum OriginalNetworkClient {
    public enum Exit: String, Codable, Sendable { case present, returnWithoutPresentation }
    public enum Region: String, Codable, Sendable { case globals, local }
    public struct Request: Codable, Equatable, Sendable {
        public enum Kind: String, Codable, Sendable { case closeSocket, socket, hostLookup, hostByAddress, addressWord, htons, connect, send, receive, sleep, message }
        public let kind: Kind, arguments: [UInt32], bytes: [UInt8]
        public init(_ kind: Kind,_ arguments: [UInt32] = [],_ bytes: [UInt8] = []) { self.kind = kind;self.arguments = arguments;self.bytes = bytes }
    }
    public struct Response: Codable, Equatable, Sendable {
        public let result: Int32, bytes: [UInt8], hostAddress: UInt32?
        public init(result: Int32 = 0,bytes: [UInt8] = [],hostAddress: UInt32? = nil) { self.result = result;self.bytes = bytes;self.hostAddress = hostAddress }
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Network client: "+text) }
    /// Host lookup outputs bind the returned hostent's first address explicitly.
    /// Numeric send/recv errors are ignored; output bytes are independent inputs.
    /// Providers/observers that throw roll back the complete action. Buffer
    /// external effects until commit; actual peer delivery/reentrancy is separate.
    public static func attempt(globals: inout OriginalStateRecord,local: inout OriginalStateRecord,
        world: OriginalStateRecord,request: (Request) throws -> Response,
        store: (Region,Int,[UInt8]) throws -> Void = { _,_,_ in }) throws -> Exit {
        let base = OriginalMatchPreparation.globalBase
        guard globals.bytes.count == OriginalMatchPreparation.globalSize,local.bytes.count == 0x400 else { throw error("Global/local extent") }
        var state = globals,temporary = local
        func word(_ a: Int) throws -> UInt32 { try state.integer(at: a-base,as: UInt32.self) }
        func put(_ region: Region,_ offset: Int,_ bytes: [UInt8]) throws {
            let count = region == .globals ? state.bytes.count : temporary.bytes.count
            guard offset >= 0,offset <= count,bytes.count <= count-offset else { throw error("Required bytes exceed recovered backing") }
            for (i,b) in bytes.enumerated() {
                if region == .globals { try state.write(b,at: offset+i) } else { try temporary.write(b,at: offset+i) }
            }
            try store(region,offset,bytes)
        }
        func wordBytes(_ v: UInt32) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: v >> ($0*8)) } }
        func putWord(_ a: Int,_ v: UInt32) throws { try put(.globals,a-base,wordBytes(v)) }
        func bytes(_ r: OriginalStateRecord,_ o: Int,_ n: Int) throws -> [UInt8] { try (o..<o+n).map { try r.integer(at: $0,as: UInt8.self) } }
        func string(_ r: OriginalStateRecord,_ o: Int) throws -> [UInt8] {
            var value: [UInt8] = []
            while true { let b = try r.integer(at: o+value.count,as: UInt8.self);if b == 0 { return value };value.append(b) }
        }
        func message(_ text: String,_ caption: String) throws { _ = try request(.init(.message,[0,0],Array(text.utf8)+[0]+Array(caption.utf8)+[0])) }
        func commit(_ exit: Exit) -> Exit { globals = state;local = temporary;return exit }
        func receive(_ count: UInt32,_ region: Region,_ offset: Int) throws {
            let r = try request(.init(.receive,[word(0x44f46c),count,0]))
            guard r.bytes.count <= Int(count) else { throw error("Receive output exceeds original request") }
            if !r.bytes.isEmpty { try put(region,offset,r.bytes) }
        }
        guard try word(0x4511b0) == 1 else { return commit(.present) }
        let previous = try word(0x44f46c)
        try putWord(0x4511b0,0);_ = try request(.init(.closeSocket,[previous]))
        let socket = UInt32(bitPattern: try request(.init(.socket,[2,1,6])).result)
        try putWord(0x44f46c,socket)
        if socket == UInt32.max { try message("socket()","Client Error");return commit(.returnWithoutPresentation) }
        let hostname = try string(world,0x7d8)
        var host = try request(.init(.hostLookup,[],hostname))
        try putWord(0x44f2d4,UInt32(bitPattern: host.result))
        if host.result == 0 {
            let address = UInt32(bitPattern: try request(.init(.addressWord,[],hostname)).result)
            try put(.local,0,wordBytes(address))
            host = try request(.init(.hostByAddress,[4,2],bytes(temporary,0,4)))
            try putWord(0x44f2d4,UInt32(bitPattern: host.result))
            if host.result == 0 {
                try message("Can't get the Server","Error");try putWord(0x44d064,1);return commit(.present)
            }
        }
        if try word(0x44d064) == 1 { return commit(.present) }
        try put(.globals,0x44f58c-base,[2,0])
        guard let address = host.hostAddress else { throw error("Successful host result lacks first-address provenance") }
        try putWord(0x44f590,address)
        let port = UInt16(truncatingIfNeeded: try request(.init(.htons,[12345])).result)
        try put(.globals,0x44f58e-base,[UInt8(truncatingIfNeeded: port),UInt8(truncatingIfNeeded: port >> 8)])
        let connected = try request(.init(.connect,[word(0x44f46c),16],bytes(state,0x44f58c-base,16))).result
        if connected == -1 {
            try message("Can't connect to server","Error")
            _ = try request(.init(.closeSocket,[word(0x44f1b4)]))
            try putWord(0x44d064,1);return commit(.returnWithoutPresentation)
        }
        try receive(100,.local,0x270)
        for (i,b) in (Array("u can connect".utf8)+[0]).enumerated() {
            if try temporary.integer(at: 0x270+i,as: UInt8.self) != b { return commit(.present) }
        }
        // Actual caller's EBP19 originates at424771. Intervening UI is outside
        // this action's declared ABI; no expected stack/control word is imported.
        let template = [UInt8](repeating: 48,count: 4)+[UInt8](repeating: 49,count: 4)+[UInt8](repeating: 48,count: 68)+[0]
        for i in stride(from: 0,to: 76,by: 4) { try put(.local,0x90+i,Array(template[i..<i+4])) }
        for i in 0..<4 { try putWord(0x450b5c+i*4,UInt32(i+1)) }
        try put(.local,0xdc,[0]);try put(.local,0xb0,[UInt8](repeating: 95,count: 45))
        for player in 0..<4 {
            var i = 0
            while true {
                let b = try state.integer(at: 0x44fcc0-base+player*11+i,as: UInt8.self)
                try put(.globals,0x44fcec-base+player*11+i,[b]);i += 1;if b == 0 { break }
            }
            i = 0
            while true {
                let b = try state.integer(at: 0x44fcc0-base+player*11+i,as: UInt8.self)
                try put(.local,0xb0+player*11+i,[b]);i += 1;if b == 0 { break }
            }
        }
        for i in 0..<44 where try temporary.integer(at: 0xb0+i,as: UInt8.self) == 0 { try put(.local,0xb0+i,[95]) }
        try put(.local,0xdc,[0]);try put(.globals,0x44f1af-base,[1])
        _ = try request(.init(.send,[word(0x44f46c),77,0],bytes(temporary,0x90,77)))
        _ = try request(.init(.sleep,[500]));try receive(77,.local,0xf4)
        _ = try request(.init(.sleep,[500]));try receive(3001,.globals,0x44ff90-base)
        for i in 0..<8 where try temporary.integer(at: 0xf4+i,as: UInt8.self) == 49 { try putWord(0x450b4c+i*4,UInt32.max) }
        for i in 0..<44 {
            let b = try temporary.integer(at: 0x114+i,as: UInt8.self)
            try put(.globals,0x44fcc0-base+i,[b]);if b == 95 { try put(.globals,0x44fcc0-base+i,[0]) }
        }
        try putWord(0x44d064,4);return commit(.present)
    }
}
