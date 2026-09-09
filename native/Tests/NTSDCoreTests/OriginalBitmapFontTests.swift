import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalBitmapFontTests: XCTestCase {
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Spec: Decodable {
        let label: String, entry: UInt32
        let offset: Int?, x: Int32?, y: Int32?, columns: Int32?, lines: Int32?, style: Int32?, cursor: UInt32?
        let results: [Int32]?
    }
    private struct Case: Decodable {
        let spec: Spec, textBefore: String, maskBefore: String, textAfter: String, maskAfter: String, written: String, globals: String
        let bitmaps: [Storage], events: [OriginalFrontScreenEvent], blits: Int
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, fpcw: Int, bitmapBase: UInt32, target: UInt32, cases: [Case], blobs: [String:Blob]
    }

    func testWholeOriginalBitmapFontAndFourPassCaller() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_BITMAP_FONT_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-bitmap-font", withExtension: "json", subdirectory: "Fixtures")) }
        let corpus = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 192_000_000))
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.fpcw, 0x23f); XCTAssertFalse(corpus.cases.isEmpty)
        var cache: [String:[UInt8]] = [:], totalEvents = 0, totalBlits = 0, totalWrites = 0, rollbackTrials = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let value = cache[key] { return value }
            let item = try XCTUnwrap(corpus.blobs[key]), packed = try XCTUnwrap(Data(base64Encoded: item.deflate))
            guard packed.count >= 6, packed[0] == 0x78, packed[1] == 0xda else { throw OriginalStateError.invalidStorage("Font fixture zlib framing") }
            let value = try MatchPreparationReference.inflate(Data(packed.dropFirst(2).dropLast(4)).base64EncodedString(), count: item.count)
            guard MatchPreparationReference.digest(Data(value)) == key else { throw OriginalStateError.invalidStorage("Font fixture SHA") }
            cache[key] = value; return value
        }
        func record(_ bytes: String, _ mask: String? = nil) throws -> OriginalStateRecord {
            let raw = try blob(bytes), flags = try mask.map { try blob($0) } ?? .init(repeating: 1, count: raw.count)
            guard raw.count == flags.count, flags.allSatisfy({ $0 < 2 }) else { throw OriginalStateError.invalidStorage("Font fixture mask extent") }
            return try .init(bytes: raw, defined: flags.map { $0 != 0 })
        }
        for c in corpus.cases {
            let s = c.spec, entry = try XCTUnwrap(OriginalBitmapFont.Entry(rawValue: s.entry)), offset = s.offset ?? 16
            var text = try record(c.textBefore, c.maskBefore)
            let initial = text, globals = try record(c.globals)
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
                    throw OriginalStateError.invalidStorage("Font fixture bitmap binding")
                }
                let index = Int((pointer-corpus.bitmapBase)/0x2000)
                guard bitmaps.indices.contains(index) else { throw OriginalStateError.invalidStorage("Font fixture bitmap extent") }
                return (bitmaps[index], surfaces[index])
            }
            let results = s.results ?? [-2147467259, 0, -1, 1]
            var events: [OriginalFrontScreenEvent] = [], blits = 0, written = [UInt8](repeating: 0, count: text.bytes.count)
            try OriginalBitmapFont.draw(entry, text: &text, offset: offset, x: s.x ?? 80, y: s.y ?? 50,
                columns: s.columns ?? 8, lines: s.lines ?? 3, style: s.style ?? 0, cursor: s.cursor ?? 0,
                globals: globals, resourceBitmap: resource, performBlit: { _ in
                    defer { blits += 1 }; return results[blits%results.count]
                }, observe: { event in
                    events.append(event)
                    if event.kind == "stringWrite" {
                        guard event.arguments.count == 2, event.arguments[1] == 0 else { throw OriginalStateError.invalidStorage("Font native string write") }
                        let index = offset+Int(event.arguments[0])
                        guard written.indices.contains(index) else { throw OriginalStateError.invalidStorage("Font native string write extent") }
                        written[index] = 1; totalWrites += 1
                    }
                })
            XCTAssertEqual(text, try record(c.textAfter, c.maskAfter), s.label)
            XCTAssertEqual(written, try blob(c.written), s.label)
            XCTAssertEqual(blits, c.blits, s.label)
            guard events == c.events else {
                let index = zip(events,c.events).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset
                throw OriginalStateError.invalidStorage("Font events differ in \(s.label), index \(index.map(String.init) ?? "count"), native \(events.count), source \(c.events.count)")
            }
            totalEvents += events.count; totalBlits += blits
            if s.label == "grid-423a70-414243-1-1-0-1" {
                // Two passes have already truncated ABC to A before this
                // observer fails at the third pass. Preserve the original
                // caller's complete byte/mask record on native failure.
                var trial = initial, passes = 0, writes = 0
                XCTAssertThrowsError(try OriginalBitmapFont.draw(entry, text: &trial, offset: offset,
                    x: 80, y: 50, columns: 1, lines: 1, style: 0, cursor: 1, globals: globals,
                    resourceBitmap: resource, performBlit: { _ in 0 }, observe: { event in
                        if event.kind == "stringWrite" { writes += 1 }
                        if event.kind == "fontPass" {
                            passes += 1
                            if passes == 3 { throw OriginalStateError.invalidStorage("Font late pass observer") }
                        }
                    })) { error in
                        guard case OriginalStateError.invalidStorage("Font late pass observer") = error else { return XCTFail("Unexpected font error: \(error)") }
                    }
                XCTAssertEqual(passes, 3); XCTAssertEqual(writes, 2); XCTAssertEqual(trial, initial); rollbackTrials += 1
            }
        }
        if corpus.cases.count > 1200 { XCTAssertEqual(rollbackTrials, 1) }
        print("BITMAP FONT \(corpus.cases.count) calls, \(totalEvents) events, \(totalBlits) Blts, \(totalWrites) string writes, \(rollbackTrials) late rollback trials")
    }
}
