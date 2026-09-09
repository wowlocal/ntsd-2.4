import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalModeLabelTests: XCTestCase {
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Spec: Decodable { let label: String, mode: Int32?, alternate: UInt32?, results: [Int32]? }
    private struct Case: Decodable {
        let spec: Spec, globals: String, globalsAfter: String, written: String
        let bitmaps: [Storage], events: [OriginalFrontScreenEvent], blits: Int
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, fpcw: Int, bitmapBase: UInt32, target: UInt32, cases: [Case], blobs: [String:Blob]
    }

    func testWholeOriginalModeLabel() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_MODE_LABEL_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-mode-label", withExtension: "json", subdirectory: "Fixtures")) }
        let corpus = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 192_000_000))
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.fpcw, 0x23f); XCTAssertFalse(corpus.cases.isEmpty)
        var cache: [String:[UInt8]] = [:], totalEvents = 0, totalBlits = 0, rollbackTrials = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let value = cache[key] { return value }
            let item = try XCTUnwrap(corpus.blobs[key]), packed = try XCTUnwrap(Data(base64Encoded: item.deflate))
            guard packed.count >= 6, packed[0] == 0x78, packed[1] == 0xda else { throw OriginalStateError.invalidStorage("Mode label fixture zlib framing") }
            let value = try MatchPreparationReference.inflate(Data(packed.dropFirst(2).dropLast(4)).base64EncodedString(), count: item.count)
            guard MatchPreparationReference.digest(Data(value)) == key else { throw OriginalStateError.invalidStorage("Mode label fixture SHA") }
            cache[key] = value; return value
        }
        func record(_ key: String) throws -> OriginalStateRecord {
            let bytes = try blob(key); return try .init(bytes: bytes, defined: .init(repeating: true, count: bytes.count))
        }
        for c in corpus.cases {
            let s = c.spec
            var globals = try record(c.globals)
            let initial = globals
            var bitmaps: [OriginalStateRecord] = [], surfaces: [UInt32] = []
            for b in c.bitmaps {
                let raw = try blob(b.bytes), flags = try blob(b.defined)
                XCTAssertEqual(raw.count, 0x1f50); XCTAssertEqual(flags.count, raw.count)
                let surface = (0..<4).reduce(UInt32(0)) { $0 | UInt32(raw[$1]) << ($1*8) }
                var normalized = raw
                for i in 0..<4 { normalized[i] = i == 0 && surface != 0 ? 1 : 0 }
                bitmaps.append(try .init(bytes: normalized, defined: flags.map { $0 != 0 })); surfaces.append(surface)
            }
            func resource(_ pointer: UInt32) throws -> (OriginalStateRecord, UInt32) {
                guard pointer >= corpus.bitmapBase, (pointer-corpus.bitmapBase)%0x2000 == 0 else {
                    throw OriginalStateError.invalidStorage("Mode label fixture bitmap binding")
                }
                let index = Int((pointer-corpus.bitmapBase)/0x2000)
                guard bitmaps.indices.contains(index) else { throw OriginalStateError.invalidStorage("Mode label fixture bitmap extent") }
                return (bitmaps[index], surfaces[index])
            }
            let results = s.results ?? [-2147467259, 0, -1, 1]
            var events: [OriginalFrontScreenEvent] = [], blits = 0, written = [UInt8](repeating: 0, count: globals.bytes.count)
            try OriginalModeLabel.draw(mode: s.mode ?? 0, alternateLine: s.alternate ?? 0, globals: &globals,
                resourceBitmap: resource, performBlit: { _ in
                    defer { blits += 1 }; return results[blits%results.count]
                }, observe: { event in
                    events.append(event)
                    var offset: Int?, size = 1
                    if event.kind == "stringWrite" { offset = 0x450c38-0x44d000+Int(event.arguments[0]) }
                    if event.kind == "labelWrite" { offset = Int(event.arguments[0])-0x44d000; size = Int(event.arguments[1]) }
                    if let offset {
                        guard offset >= 0, size > 0, offset+size <= written.count else { throw OriginalStateError.invalidStorage("Mode label native write extent") }
                        for i in offset..<offset+size { written[i] = 1 }
                    }
                })
            XCTAssertEqual(globals, try record(c.globalsAfter), s.label)
            XCTAssertEqual(written, try blob(c.written), s.label)
            XCTAssertEqual(blits, c.blits, s.label)
            guard events == c.events else {
                let index = zip(events,c.events).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset
                throw OriginalStateError.invalidStorage("Mode label events differ in \(s.label), index \(index.map(String.init) ?? "count"), native \(events.count), source \(c.events.count)")
            }
            totalEvents += events.count; totalBlits += blits
            if s.label == "mode-0-0-0" {
                var trial = initial, passes = 0, writes = 0, labelWrites = 0
                XCTAssertThrowsError(try OriginalModeLabel.draw(mode: 0, alternateLine: 0, globals: &trial,
                    resourceBitmap: resource, performBlit: { _ in 0 }, observe: { event in
                        if event.kind == "labelWrite" { labelWrites += 1 }
                        if event.kind == "stringWrite" { writes += 1 }
                        if event.kind == "fontPass" {
                            passes += 1
                            if passes == 3 { throw OriginalStateError.invalidStorage("Mode label late pass observer") }
                        }
                    })) { error in
                        guard case OriginalStateError.invalidStorage("Mode label late pass observer") = error else { return XCTFail("Unexpected mode label error: \(error)") }
                    }
                XCTAssertEqual(passes, 3); XCTAssertEqual(writes, 2); XCTAssertEqual(labelWrites, 6)
                XCTAssertEqual(trial, initial); rollbackTrials += 1
            }
        }
        if corpus.cases.count > 25 { XCTAssertEqual(rollbackTrials, 1) }
        print("MODE LABEL \(corpus.cases.count) calls, \(totalEvents) events, \(totalBlits) Blts, \(rollbackTrials) late rollback trials")
    }
}
