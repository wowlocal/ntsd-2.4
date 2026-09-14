import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Current-input finite specification; no production command routine supplies an expectation.
struct OriginalApplicationActiveCommandsProjection {
    typealias S = OriginalApplicationActiveBodyControl
    typealias P = S.P
    var state: S
    var cleaned: [Int] = []
    init(_ own: OriginalMatchPreparation) throws { state = try S(own) }
    init(_ source: S) { state = source }
    func at(_ slot: Int,_ offset: Int) -> Int { 0x7d8+slot*0x420+offset }
    func i(_ slot: Int,_ offset: Int) throws -> Int32 { try state.pool.integer(at:at(slot,offset),as:Int32.self) }
    func g(_ address: Int) throws -> Int32 { try state.globals.integer(at:address-0x44d000,as:Int32.self) }
    mutating func put(_ slot: Int,_ offset: Int,_ value: Int32) throws { try state.pool.write(value,at:at(slot,offset)) }
    mutating func advance() throws {
        try P.require(state.pool.bytes.count == 0x7d8+400*0x420 && state.globals.bytes.count == 0xb440 && state.actorTokens.count == 400 && Set(state.actorTokens).count == 400,"Commands complete distinct current records")
        try P.require(g(0x450bb8) == 0 && g(0x450bc0) == 0 && g(0x451160) == 0,"Active command/refill/mode needs its own comparison")
        for slot in 0..<400 {
            try P.require(state.pool.integer(at:0x194+4*slot,as:UInt32.self) == state.actorTokens[slot],"Commands current Actor mapping")
            if try state.pool.integer(at:4+slot,as:UInt8.self) == 0 { continue }
            try P.require(i(slot,0xe0) == 0 && i(slot,0xe4) == 0,"Active healing timers need their own comparison")
            let object = try XCTUnwrap(state.objects[UInt32(bitPattern:i(slot,0x368))]),frame = try i(slot,0x70)
            try P.require((0..<400).contains(frame),"Commands current Frame extent")
            try P.require(object.integer(at:0x7ac+Int(frame)*0x178,as:Int32.self) != 1700,"Active state1700 timer needs its own comparison")
            // Original4219dd/e3/e9/ef/f5 stores; the last is BYTE EB only.
            for offset in [0x2e8,0x2ec,0x2f0] { try put(slot,offset,1000) }
            try put(slot,0x2e4,0);try state.pool.write(UInt8(0),at:at(slot,0xeb))
            cleaned.append(slot)
        }
    }
}
