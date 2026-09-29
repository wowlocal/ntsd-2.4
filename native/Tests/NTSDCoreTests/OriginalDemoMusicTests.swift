import Foundation
import XCTest
@testable import NTSDCore

/// Real4025d0 cases (tools/oracle_demo_music.py) against selectDemoTrack and the
/// following4025b0 play decision: RNG draw, 44eed0 bytes, RNG words, play path.
final class OriginalDemoMusicTests: XCTestCase {
    struct Call: Decodable { let kind: String, path: String }
    struct Write: Decodable { let address: Int, bytes: String }
    struct Before: Decodable { let enabled: Int32, track: Int64, prior: String, index: Int32, counter: Int32 }
    struct After: Decodable { let path: String, index: Int32, counter: Int32 }
    struct Case: Decodable { let before: Before, calls: [Call], writes: [Write], after: After }
    struct Corpus: Decodable { let exeSHA256: String, table: String, cases: [Case] }
    static func hex(_ s: String) -> [UInt8] {
        let u = Array(s.utf8)
        return stride(from: 0,to: u.count,by: 2).map { UInt8(String(decoding: u[$0..<$0+2],as: UTF8.self),radix: 16)! }
    }
    func testDemoTrackSelectionMatchesOriginal() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-demo-music",withExtension: "json",subdirectory: "Fixtures"))
        let c = try JSONDecoder().decode(Corpus.self,from: Data(contentsOf: url))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        let base = OriginalMatchPreparation.globalBase,table = Self.hex(c.table)
        var draws = 0,plays = 0
        for item in c.cases {
            var g = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: OriginalMatchPreparation.globalSize),
                                            defined: [Bool](repeating: true,count: OriginalMatchPreparation.globalSize))
            for (i,b) in table.enumerated() { try g.write(b,at: 0x44ff90-base+i) }
            try g.write(item.before.enabled,at: 0x44d010-base)
            let prior = Self.hex(item.before.prior)+[0]
            for i in 0..<0x20 { try g.write(i < prior.count ? prior[i] : 0xa5,at: 0x44eed0-base+i) }
            try g.write(item.before.index,at: 0x450bcc-base);try g.write(item.before.counter,at: 0x450c34-base)
            var random = OriginalRandom(table: table,index: Int(item.before.index),counter: Int(item.before.counter),source: "test",sourceSHA256: "")
            let enabled = try OriginalMusicPlayback.selectDemoTrack(Int32(truncatingIfNeeded: item.before.track),globals: &g) { tag,range in
                XCTAssertEqual(tag,2);XCTAssertEqual(range,8);draws += 1
                return Int32(random.next(Int(range)))
            }
            try g.write(Int32(random.index),at: 0x450bcc-base);try g.write(Int32(random.counter),at: 0x450c34-base)
            XCTAssertEqual(Array(g.bytes[(0x44eed0-base)..<(0x44eed0-base+0x20)]),Self.hex(item.after.path))
            XCTAssertEqual(try g.integer(at: 0x450bcc-base,as: Int32.self),item.after.index)
            XCTAssertEqual(try g.integer(at: 0x450c34-base,as: Int32.self),item.after.counter)
            // 4025b0 plays 44eed0 only when its first byte is set.
            let path = Array(g.bytes[(0x44eed0-base)...].prefix { $0 != 0 })
            let played = enabled && !path.isEmpty ? [path] : []
            XCTAssertEqual(played,item.calls.map { Self.hex($0.path) });plays += played.count
        }
        XCTAssertEqual(c.cases.count,102);XCTAssertGreaterThan(draws,0);XCTAssertGreaterThan(plays,0)
    }
}
