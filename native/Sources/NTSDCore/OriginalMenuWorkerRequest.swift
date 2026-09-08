import Foundation

///4237e0/43c450 through CreateThread/GetLastError. The worker body and
///concurrent changes remain platform inputs, shared by both original callers.
public enum OriginalMenuWorkerRequest {
    public static func run(globals: OriginalStateRecord,threadHandle: UInt32,threadID: UInt32,lastError: UInt32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        let base = OriginalMatchPreparation.globalBase
        func word(_ address: Int) throws -> UInt32 { try globals.integer(at: address-base,as: UInt32.self) }
        func string(_ address: Int) throws -> [UInt8] {
            let start = address-base
            guard start >= 0,start < globals.bytes.count,let end = globals.bytes[start...].firstIndex(of: 0) else { throw OriginalStateError.invalidStorage("Front gate string extent") }
            return Array(globals.bytes[start..<end])
        }
        var call = try word(0x44d788) == UInt32(bitPattern: -99)
        if !call {
            let index = 0x4527b0-base
            call = Array(globals.bytes[index..<index+4]) == Array("now\0".utf8)
            if !call {
                let left = try string(0x4527b0),right = try string(0x451d48)
                call = left == right || left.lexicographicallyPrecedes(right)
            }
        }
        if call {
            try observe(.init("enter",[0x4554a4]));let status = try word(0x458424);try observe(.init("leave",[0x4554a4]))
            if status == 0 {
                try observe(.init("createThread",[0,0,0x43c240,0,0,threadHandle,threadID]))
                if threadHandle == 0 { try observe(.init("lastError",[lastError])) }
            }
        }
    }
}
