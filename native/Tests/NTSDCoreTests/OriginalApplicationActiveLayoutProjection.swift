import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Finite disabled-indicator contract, independent of the public layout handler.
enum OriginalApplicationActiveLayoutProjection {
    typealias P = OriginalApplicationGameplayStateProjection
    static func recordingEntry(_ globals: OriginalStateRecord) throws -> OriginalResultRecording.Continuation {
        let timer = try globals.integer(at:0x450bdc-0x44d000,as:Int32.self)
        return UInt32(bitPattern:timer &- 101) <= 248 ? .resultLayout : .indicators
    }
    static func advance(_ input: OriginalStateRecord,continuation: OriginalResultRecording.Continuation) throws -> OriginalStateRecord {
        try P.require(input.bytes.count == 0xb440,"Layout complete globals extent")
        try P.require(continuation == .indicators,"Active result-table layout needs its own comparison")
        try P.require(input.integer(at:0x450b84-0x44d000,as:UInt32.self) == 0,"Active enabled indicator needs its own comparison")
        // Playback is nested below this gate. Unknown unread bytes stay unknown.
        return input
    }
}
