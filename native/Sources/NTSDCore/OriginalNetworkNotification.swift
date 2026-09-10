/// Whole WndProc message401 and402ec0 at declared socket/Win32 boundaries.
/// The160 local bytes end before the original cookie; their initial provenance
/// is a caller input. No Windows socket, DLL, sleep or process is run here.
public enum OriginalNetworkNotification {
    public enum Region: String, Codable, Sendable { case globals, local }
    public struct Request: Codable, Equatable, Sendable {
        public enum Kind: String, Codable, Sendable { case accept, closeSocket, send, receive, sleep, message, windowDefault }
        public let kind: Kind, arguments: [UInt32], bytes: [UInt8]
        public init(_ kind: Kind,_ arguments: [UInt32] = [],_ bytes: [UInt8] = []) {
            self.kind = kind;self.arguments = arguments;self.bytes = bytes
        }
    }
    public struct Response: Codable, Equatable, Sendable {
        public let result: Int32, bytes: [UInt8]
        public init(result: Int32 = 0,bytes: [UInt8] = []) { self.result = result;self.bytes = bytes }
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Network notification: "+text) }
    /// Numeric errors retain original continuation. Thrown providers/observers
    /// roll back globals and locals; buffer external effects until whole commit.
    public static func receive(_ input: OriginalWindowInput.Message,globals: inout OriginalStateRecord,
        local: inout OriginalStateRecord,request: (Request) throws -> Response,
        store: (Region,Int,[UInt8]) throws -> Void = { _,_,_ in }) throws -> Int32 {
        let base = OriginalMatchPreparation.globalBase
        guard input.message == 0x401,globals.bytes.count == OriginalMatchPreparation.globalSize,
              local.bytes.count == 160 else { throw error("Message/global/local extent") }
        var state = globals,temporary = local
        func word(_ address: Int) throws -> UInt32 { try state.integer(at: address-base,as: UInt32.self) }
        func put(_ region: Region,_ offset: Int,_ bytes: [UInt8]) throws {
            let count = region == .globals ? state.bytes.count : temporary.bytes.count
            guard offset >= 0,offset <= count,bytes.count <= count-offset else { throw error("Required storage extends beyond recovered backing") }
            for (i,b) in bytes.enumerated() {
                if region == .globals { try state.write(b,at: offset+i) } else { try temporary.write(b,at: offset+i) }
            }
            try store(region,offset,bytes)
        }
        func putWord(_ address: Int,_ value: UInt32) throws {
            try put(.globals,address-base,(0..<4).map { UInt8(truncatingIfNeeded: value >> ($0*8)) })
        }
        func bytes(_ record: OriginalStateRecord,_ offset: Int,_ count: Int) throws -> [UInt8] {
            try (offset..<offset+count).map { try record.integer(at: $0,as: UInt8.self) }
        }
        func message(_ text: String,_ caption: String) throws {
            _ = try request(.init(.message,[0,0],Array(text.utf8)+[0]+Array(caption.utf8)+[0]))
        }
        switch UInt16(truncatingIfNeeded: input.lParam) {
        case 1: try message("FD_READ","Handle Message")
        case 16: try message("FD_CONNECT","Handle Message")
        case 32: try message("FD_CLOSE","Handle Message")
        case 8:
            let listener = try word(0x44f1b4)
            try put(.globals,0x44f1af-base,[2])
            let accepted = UInt32(bitPattern: try request(.init(.accept,[listener,0,0])).result)
            try putWord(0x44f46c,accepted)
            if accepted == UInt32.max {
                try message("Accpet() Error","Error")
                _ = try request(.init(.closeSocket,[word(0x44f46c)]))
                _ = try request(.init(.closeSocket,[word(0x44f1b4)]))
            } else {
                _ = try request(.init(.closeSocket,[word(0x44f1b4)]))
                _ = try request(.init(.send,[word(0x44f46c),14,0],Array("u can connect".utf8)+[0]))
                try put(.local,0,[UInt8](repeating: 0,count: 77))
                _ = try request(.init(.sleep,[3000]))
                let response = try request(.init(.receive,[word(0x44f46c),77,0]))
                guard response.bytes.count <= 77 else { throw error("Receive output exceeds original request") }
                if !response.bytes.isEmpty { try put(.local,0,response.bytes) }
                _ = try request(.init(.sleep,[500]))
                let template = [UInt8](repeating: 49,count: 4)+[UInt8](repeating: 48,count: 72)+[0]
                for i in stride(from: 0,to: 76,by: 4) { try put(.local,0x50+i,Array(template[i..<i+4])) }
                try put(.local,0x9c,[template[76]])
                try put(.local,0x70,[UInt8](repeating: 0x5f,count: 45))
                for player in 0..<4 {
                    var i = 0
                    while true {
                        let b = try state.integer(at: 0x44fcc0-base+player*11+i,as: UInt8.self)
                        try put(.local,0x70+player*11+i,[b]);i += 1
                        if b == 0 { break }
                    }
                }
                for i in 0..<44 where try temporary.integer(at: 0x70+i,as: UInt8.self) == 0 {
                    try put(.local,0x70+i,[0x5f])
                }
                try put(.local,0x9c,[0])
                _ = try request(.init(.send,[word(0x44f46c),77,0],bytes(temporary,0x50,77)))
                _ = try request(.init(.sleep,[500]))
                _ = try request(.init(.send,[word(0x44f46c),3001,0],bytes(state,0x44ff90-base,3001)))
                let first = try temporary.integer(at: 0,as: UInt8.self)
                for i in 0..<4 { try putWord(0x450b4c+4*i,UInt32(i+1)) }
                if first == 49 { try putWord(0x450b4c,UInt32.max) }
                for i in 1..<8 where try temporary.integer(at: i,as: UInt8.self) == 49 {
                    try putWord(0x450b4c+4*i,UInt32.max)
                }
                for i in 0..<44 {
                    let b = try temporary.integer(at: 0x20+i,as: UInt8.self)
                    try put(.globals,0x44fcec-base+i,[b])
                    if b == 0x5f { try put(.globals,0x44fcec-base+i,[0]) }
                }
                try put(.globals,0x44f1ae-base,[1])
            }
        default: break
        }
        let result = try request(.init(.windowDefault,[input.window,input.message,input.wParam,input.lParam])).result
        globals = state;local = temporary;return result
    }
}
