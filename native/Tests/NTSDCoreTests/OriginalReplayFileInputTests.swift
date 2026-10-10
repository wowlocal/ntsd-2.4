import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
import XCTest
@testable import NTSDCore

/// Real43e620 results (tools/oracle_replay_loader.py) against the Native
/// loader: status, 44d030/450b74, 4588ac, recording bytes, allocation order,
/// frees and whether the file was closed. Variants are rebuilt from the base
/// recordings exactly as the oracle declared them.
final class OriginalReplayFileInputTests: XCTestCase {
    struct Case: Decodable {
        let label: String, fileSHA256: String?, keySHA256: String, result: Int32, flag: UInt32, cleared: UInt32, pointer: UInt32
        let recordingSHA256: String?, allocations: [[Int]], frees: [Int], closed: Bool, live: [Int], overflowBytes: Int
    }
    struct Corpus: Decodable { let exeSHA256: String, recordings: [String:String], cases: [Case] }
    static func sha(_ bytes: [UInt8]) -> String { SHA256.hash(data: Data(bytes)).map { String(format: "%02x",$0) }.joined() }

    func testLoaderMatchesOriginal() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-replay-loader",withExtension: "json",subdirectory: "Fixtures"))
        let c = try JSONDecoder().decode(Corpus.self,from: Data(contentsOf: url))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        let startup = try OriginalApplicationStartupInputs.bundled()
        let base = OriginalMatchPreparation.globalBase
        let globals = startup.initial
        let o = 0x44d7a0-base
        let key = Array(globals.bytes[o..<globals.bytes[o...].firstIndex(of: 0)!])
        XCTAssertEqual(key.count,1345)
        func variant(_ label: String) throws -> ([UInt8]?,[UInt8]) {
            switch label {
            case "missing": return (nil,key)
            case "tiny": return ([0x10,0,0,0]+[UInt8](repeating: 0,count: 995),key)
            case "zero-length": return ([0,0,0,0]+[UInt8](repeating: 0x33,count: 1200),key)
            default: break
            }
            let parts = label.split(separator: "-",maxSplits: 1).map(String.init)
            let data = [UInt8](try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(c.recordings[parts[0]]))))
            let n = Int(UInt32(data[0])|UInt32(data[1])<<8|UInt32(data[2])<<16|UInt32(data[3])<<24)
            func length(_ v: Int) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: v >> ($0*8)) } }
            switch parts.count == 1 ? "" : parts[1] {
            case "": return (data,key)
            case "other-key": return (data,[0x32]+key.dropFirst())
            case "empty-key": return (data,[])
            case "truncated": return (Array(data[0..<data.count/2]),key)
            case "corrupt": var d = data;d[4+n/2] ^= 0x5a;return (d,key)
            case "short-length": return (length(n-100)+data[4...],key)
            case "long-length": return (length(n+5000)+data[4...],key)
            case "trailing": return (data+[UInt8](repeating: 1,count: 300),key)
            default: throw XCTSkip("unknown variant")
            }
        }
        var loaded = 0
        for item in c.cases {
            let (file,caseKey) = try variant(item.label)
            XCTAssertEqual(file.map(Self.sha),item.fileSHA256,item.label);XCTAssertEqual(Self.sha(caseKey),item.keySHA256,item.label)
            var g = globals
            for (i,b) in (caseKey+[0]).enumerated() { try g.write(b,at: o+i) }
            try g.write(Int32(7),at: 0x44d030-base);try g.write(Int32(7),at: 0x450b74-base)
            let r = try OriginalReplayFileInput.load(file: file,globals: &g)
            XCTAssertEqual(r.status,item.result,item.label)
            XCTAssertEqual(r.overflowBytes,item.overflowBytes,item.label)
            XCTAssertEqual(try g.integer(at: 0x44d030-base,as: UInt32.self),item.flag,item.label)
            XCTAssertEqual(try g.integer(at: 0x450b74-base,as: UInt32.self),item.cleared,item.label)
            XCTAssertEqual(r.recording.map(Self.sha),item.recordingSHA256,item.label)
            var allocations: [[Int]] = [],frees: [Int] = [],closed = false
            for e in r.events {
                switch e {
                case .allocate(let ordinal,let count):allocations.append([ordinal,count])
                case .free(let ordinal):frees.append(ordinal)
                case .close:closed = true
                case .destroy:break
                }
            }
            XCTAssertEqual(allocations,item.allocations,item.label);XCTAssertEqual(frees,item.frees,item.label)
            // The descriptor close happens only for a file that opened.
            XCTAssertEqual(closed && file != nil,item.closed,item.label)
            XCTAssertEqual(item.live,item.result == 1 ? [1] : [],item.label)
            // 4588ac is written only on success (the recording's address there).
            XCTAssertEqual(item.pointer == 0x30100000,item.result == 1,item.label)
            if r.status == 1 { loaded += 1 }
        }
        XCTAssertEqual(c.cases.count,27);XCTAssertEqual(loaded,9)
    }
}
