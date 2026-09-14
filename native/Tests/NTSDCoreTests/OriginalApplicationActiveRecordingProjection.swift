import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Current-input finite result gate; no production recorder supplies expectations.
enum OriginalApplicationActiveRecordingProjection {
    typealias P = OriginalApplicationGameplayStateProjection
    static let continuation: UInt32 = 0x422944
    static func advance(_ input: OriginalStateRecord) throws -> OriginalStateRecord {
        try P.require(input.bytes.count == 0xb440,"Recording complete globals extent")
        let timer = try input.integer(at:0x450bdc-0x44d000,as:Int32.self)
        try P.require(UInt32(bitPattern:timer &- 101) > 248,"Active result-table branch needs its own comparison")
        var output = input
        if timer < 100 {
            let elapsed = try input.integer(at:0x450bbc-0x44d000,as:Int32.self)
            try output.write(elapsed &+ 1,at:0x450bbc-0x44d000)
        }
        // No result flags, mode, Actor, replay buffer or round word is read.
        return output
    }
}
