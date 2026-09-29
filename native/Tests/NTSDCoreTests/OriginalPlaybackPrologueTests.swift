import Foundation
import XCTest
@testable import NTSDCore

/// Real41bd24..41bdce (tools/oracle_playback_prologue.py) against the playback
/// controls in OriginalInitialLoading.begin: every playback word and key byte,
/// and which of them the original stored.
final class OriginalPlaybackPrologueTests: XCTestCase {
    struct State: Decodable { let globals: [String:Int32], keys: [String:UInt8] }
    struct Write: Decodable { let address: Int, bytes: String }
    struct Case: Decodable { let before: State, after: State, writes: [Write] }
    struct Corpus: Decodable { let exeSHA256: String, cases: [Case], blocks: [Int] }
    func testPlaybackControlsMatchOriginal() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-playback-prologue",withExtension: "json",subdirectory: "Fixtures"))
        let c = try JSONDecoder().decode(Corpus.self,from: Data(contentsOf: url))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        let base = OriginalMatchPreparation.globalBase
        let tracked = Set(["0x44d030","0x450b74","0x450b78","0x450b7c","0x450bc4","0x450bc8","0x450b84"].map { Int($0.dropFirst(2),radix: 16)! })
        var seeking = 0
        for (n,item) in c.cases.enumerated() {
            var g = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: OriginalMatchPreparation.globalSize),
                                            defined: [Bool](repeating: true,count: OriginalMatchPreparation.globalSize))
            for (key,value) in item.before.globals { try g.write(value,at: Int(key.dropFirst(2),radix: 16)!-base) }
            for (key,value) in item.before.keys { try g.write(value,at: 0x455378+Int(key.dropFirst(2),radix: 16)!-base) }
            var stored = Set<Int>()
            _ = try OriginalInitialLoading.begin(globals: &g) { address,bytes in
                for i in 0..<bytes.count { stored.insert(address+i) }
            }
            for (key,value) in item.after.globals {
                XCTAssertEqual(try g.integer(at: Int(key.dropFirst(2),radix: 16)!-base,as: Int32.self),value,"case \(n) \(key)")
            }
            for (key,value) in item.after.keys {
                XCTAssertEqual(try g.integer(at: 0x455378+Int(key.dropFirst(2),radix: 16)!-base,as: UInt8.self),value,"case \(n) key \(key)")
            }
            var original = Set<Int>()
            for w in item.writes { for i in 0..<(w.bytes.count/2) { original.insert(w.address+i) } }
            let words = Set(tracked.flatMap { a in (a..<a+4) }+[0x4553ed])
            XCTAssertEqual(stored.intersection(words),original.intersection(words),"case \(n) stores")
            if item.before.globals["0x450b84"] != 0 && original.contains(0x450b7c) { seeking += 1 }
        }
        XCTAssertEqual(c.cases.count,600);XCTAssertGreaterThan(seeking,0)
    }
}
