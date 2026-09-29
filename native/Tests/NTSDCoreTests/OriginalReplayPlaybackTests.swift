import Foundation
import XCTest
import NTSDCore
import NTSDReferenceChecks

/// Both accepted 43dfa0 corpora (startup precision and 64-bit control loading)
/// replayed against OriginalReplayPlayback with exact masks.
final class OriginalReplayPlaybackTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let r = try ReplayPlaybackReference.compare(input: fixture("original-replay-playback"),loading: fixture("original-initial-loading"),
            catalog: fixture("original-initial-loading-catalog"),sounds: fixture("original-initial-loading-sounds"))
        XCTAssertEqual(r.cases,84)
        XCTAssertEqual(r.initial.catalog.catalog.objects,137)
        XCTAssertGreaterThan(r.calls,0); XCTAssertGreaterThan(r.constructors,0)
        XCTAssertEqual(Set(r.families.keys),["vs","war","mission"])
    }
    func testPlaybackStartAtStartupPrecision() throws { try compare("") }
    func testPlaybackStartAt64BitPrecision() throws { try compare("-control") }
}

/// 4327aa..4328c0 against the writer's packing of +0x8c0 (OriginalResultRecording,
/// accepted with the whole writer): displays and strengths come back with
/// their −1 offsets and the defense multipliers as two decimal digits ×10.
final class OriginalReplayPlaybackStartTests: XCTestCase {
    func testWarSettingsRoundTripAndChecks() throws {
        let base = OriginalMatchPreparation.globalBase
        var globals = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: OriginalMatchPreparation.globalSize),
                                              defined: [Bool](repeating: true,count: OriginalMatchPreparation.globalSize))
        try globals.write(Int32(30),at: 0x44d03c-base);try globals.write(Int32(0x1e02ab),at: 0x44f620-base)
        var recording = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 0x630e18),defined: [Bool](repeating: true,count: 0x630e18))
        try recording.write(Int32(30),at: 0x748);try recording.write(Int32(0x1e02ab),at: 0x744)
        for (d0,s0,m0,d1,s1,m1): (Int32,Int32,Int32,Int32,Int32,Int32) in [(-1,-1,100,-1,-1,100),(1,0,150,6,2,300),(0,2,250,3,1,200),(5,1,100,-1,0,120)] {
            // The writer's packing (OriginalResultRecording), including its offset.
            var packed = (d0 &* 10 &+ s0) &* 10 &+ m0/100
            packed = packed &* 10 &+ (m0%100)/10
            packed = packed &* 10 &+ d1
            packed = packed &* 10 &+ s1 &+ 0x1adbb
            packed = packed &* 10 &+ m1/100
            packed = packed &* 10 &+ (m1%100)/10
            try recording.write(packed,at: 0x8c0)
            var g = globals
            XCTAssertEqual(try OriginalReplayPlayback.start(recording: recording,globals: &g),.started)
            let values = try [0x44d380,0x451b74,0x44d758,0x44d384,0x451b78,0x44d75c].map { try g.integer(at: $0-base,as: Int32.self) }
            XCTAssertEqual(values,[d0,s0,m0,d1,s1,m1],"\(packed)")
            XCTAssertEqual(try g.integer(at: 0x44d020-base,as: Int32.self),0)
        }
        var g = globals
        try recording.write(Int32(31),at: 0x748)
        guard case .rejected(let message) = try OriginalReplayPlayback.start(recording: recording,globals: &g) else { return XCTFail() }
        XCTAssertEqual(String(decoding: message,as: UTF8.self),"Version error.  Recording file are recorded in a newer version. (your LF2 is v2.0)!")
        XCTAssertEqual(try g.integer(at: 0x451160-base,as: Int32.self),6)
        try recording.write(Int32(30),at: 0x748);try recording.write(Int32(7),at: 0x744)
        g = globals
        guard case .rejected(let other) = try OriginalReplayPlayback.start(recording: recording,globals: &g) else { return XCTFail() }
        XCTAssertTrue(String(decoding: other,as: UTF8.self).hasPrefix("Error!  Recording file are recorded in a LF2 with some data files"))
    }
}
