import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalResultLayoutTests: XCTestCase {
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Fault: Decodable { let pc: UInt32, address: UInt32, bitmap: UInt32 }
    private struct Spec: Decodable {
        let label: String, entry: UInt32?, stageDefeated: UInt32?, indicatorTarget: UInt32?
        let dcResult: Int32?, dc: UInt32?, results: [Int32]?
    }
    private struct Case: Decodable {
        let spec: Spec, globals: String, globalsAfter: String, written: String
        let world: String, actors: String, headers: String, playback: String
        let localBefore: String, localAfter: String, localWritten: String, lowBefore: String, lowAfter: String, lowWritten: String
        let bitmaps: [Storage], events: [OriginalFrontScreenEvent], blits: Int
        let fault: Fault?
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, fpcw: Int, bitmapBase: UInt32, target: UInt32, indicatorTarget: UInt32
        let worldBase: UInt32, actorBase: UInt32, headerBase: UInt32, cases: [Case], blobs: [String:Blob]
    }

    func testWholeOriginalResultLayoutAndIndicators() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_RESULT_LAYOUT_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-result-layout", withExtension: "json", subdirectory: "Fixtures")) }
        let corpus = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 256_000_000))
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.fpcw, 0x23f); XCTAssertFalse(corpus.cases.isEmpty)
        var cache: [String:[UInt8]] = [:], totalEvents = 0, totalBlits = 0, rollbackTrials = 0, faultRejections = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let value = cache[key] { return value }
            let item = try XCTUnwrap(corpus.blobs[key]), packed = try XCTUnwrap(Data(base64Encoded: item.deflate))
            guard packed.count >= 6, packed[0] == 0x78, packed[1] == 0xda else { throw OriginalStateError.invalidStorage("Result layout fixture zlib framing") }
            let value = try MatchPreparationReference.inflate(Data(packed.dropFirst(2).dropLast(4)).base64EncodedString(), count: item.count)
            guard MatchPreparationReference.digest(Data(value)) == key else { throw OriginalStateError.invalidStorage("Result layout fixture SHA") }
            cache[key] = value; return value
        }
        func record(_ key: String) throws -> OriginalStateRecord {
            let bytes = try blob(key); return try .init(bytes: bytes, defined: .init(repeating: true, count: bytes.count))
        }
        for c in corpus.cases {
            let s = c.spec
            var world = try record(c.world), actors: [OriginalStateRecord] = [], headers: [OriginalStateRecord] = []
            let actorBytes = try blob(c.actors), headerBytes = try blob(c.headers)
            for n in 0..<400 {
                let pointer = try world.integer(at: 0x194+4*n, as: UInt32.self)
                guard pointer >= corpus.actorBase, (pointer-corpus.actorBase)%0x420 == 0, (pointer-corpus.actorBase)/0x420 < 400 else { throw OriginalStateError.invalidStorage("Layout fixture Actor pointer") }
                try world.write((pointer-corpus.actorBase)/0x420, at: 0x194+4*n)
                var actor = try OriginalStateRecord(bytes: Array(actorBytes[n*0x420..<(n+1)*0x420]), defined: .init(repeating: true, count: 0x420))
                let object = try actor.integer(at: 0x368, as: UInt32.self)
                guard object >= corpus.headerBase, (object-corpus.headerBase)%0x76c == 0, (object-corpus.headerBase)/0x76c < 4 else { throw OriginalStateError.invalidStorage("Layout fixture Object pointer") }
                try actor.write((object-corpus.headerBase)/0x76c, at: 0x368); actors.append(actor)
            }
            for n in 0..<4 { headers.append(try .init(bytes: Array(headerBytes[n*0x76c..<(n+1)*0x76c]), defined: .init(repeating: true, count: 0x76c))) }
            let beforeWorld = world, beforeActors = actors, beforeHeaders = headers, playback = try record(c.playback)
            var globals = try record(c.globals)
            let initial = globals, localBefore = try OriginalStateRecord(bytes: blob(c.localBefore), defined: .init(repeating: false, count: OriginalResultLayout.localSize))
            var local: OriginalStateRecord? = localBefore
            var low = try record(c.lowBefore), lowWritten = [UInt8](repeating: 0, count: low.bytes.count)
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
                guard pointer >= corpus.bitmapBase, (pointer-corpus.bitmapBase)%0x2000 == 0 else { throw OriginalStateError.invalidStorage("Layout fixture bitmap binding") }
                let index = Int((pointer-corpus.bitmapBase)/0x2000)
                guard bitmaps.indices.contains(index) else { throw OriginalStateError.invalidStorage("Layout fixture bitmap extent") }
                return (bitmaps[index], surfaces[index])
            }
            let results = s.results ?? [-2147467259, 0, -1, 1]
            let continuation = try XCTUnwrap(OriginalResultRecording.Continuation(rawValue: s.entry ?? 0x422218))
            var textAddress = 0, events: [OriginalFrontScreenEvent] = [], blits = 0
            var written = [UInt8](repeating: 0, count: globals.bytes.count), formatWritten = [UInt8](repeating: 0, count: OriginalResultLayout.localSize)
            func invoke(_ candidate: inout OriginalStateRecord, _ storage: inout OriginalStateRecord?,
                        stage: UInt32?, target: UInt32?, observe: (OriginalFrontScreenEvent) throws -> Void) throws {
                try OriginalResultLayout.draw(world: world, actors: actors, globals: &candidate, continuation: continuation,
                    stageDefeated: stage, indicatorTarget: target, local: &storage, dcResult: s.dcResult ?? 0, dc: s.dc ?? 0x76543210,
                    header: { n in
                        guard headers.indices.contains(n) else { throw OriginalStateError.invalidStorage("Layout fixture Object extent") }; return headers[n]
                    }, catalogBitmap: resource, playbackTicks: { try playback.integer(at: 0x144, as: Int32.self) },
                    resourceBitmap: resource, performBlit: { _ in defer { blits += 1 }; return results[blits%results.count] }, observe: observe)
            }
            if let fault = c.fault {
                XCTAssertEqual(fault.bitmap, 0x41414141)
                XCTAssertThrowsError(try invoke(&globals, &local, stage: s.stageDefeated ?? 0, target: corpus.indicatorTarget) { events.append($0) }) { error in
                    guard case OriginalStateError.invalidStorage("Layout fixture bitmap binding") = error else { return XCTFail("Unexpected malformed author boundary: \(error)") }
                }
                XCTAssertEqual(globals, initial); XCTAssertEqual(local, localBefore)
                XCTAssertEqual(events, c.events, s.label); XCTAssertEqual(blits, c.blits, s.label)
                faultRejections += 1; continue
            }
            try invoke(&globals, &local, stage: s.stageDefeated ?? 0, target: s.indicatorTarget ?? corpus.indicatorTarget) { event in
                events.append(event)
                if event.kind == "localWrite" {
                    let offset = Int(event.arguments[0])-0x34, size = Int(event.arguments[1])
                    var value = event.arguments[2]
                    if event.arguments[0] == 0x50 { value = value &- corpus.worldBase &- 4 }
                    for n in 0..<size { try low.write(UInt8(truncatingIfNeeded: value >> (8*n)), at: offset+n); lowWritten[offset+n] = 1 }
                }
                if event.kind == "formatWrite" { formatWritten[Int(event.arguments[0])] = 1 }
                var offset: Int?, size = 1
                if event.kind == "infoText" { textAddress = Int(event.arguments[0]) }
                if event.kind == "stringWrite" { offset = textAddress-0x44d000+Int(event.arguments[0]) }
                if event.kind == "infoWrite" { offset = Int(event.arguments[0])-0x44d000; size = Int(event.arguments[1]) }
                if let offset {
                    guard offset >= 0, size > 0, offset+size <= written.count else { throw OriginalStateError.invalidStorage("Layout native write extent") }
                    for i in offset..<offset+size { written[i] = 1 }
                }
            }
            XCTAssertEqual(globals, try record(c.globalsAfter), s.label); XCTAssertEqual(written, try blob(c.written), s.label)
            XCTAssertEqual(local?.bytes, try blob(c.localAfter), s.label); XCTAssertEqual(local?.defined, try blob(c.localWritten).map { $0 != 0 }, s.label)
            XCTAssertEqual(formatWritten, try blob(c.localWritten), s.label)
            XCTAssertEqual(low, try record(c.lowAfter), s.label); XCTAssertEqual(lowWritten, try blob(c.lowWritten), s.label)
            XCTAssertEqual(world, beforeWorld); XCTAssertEqual(actors, beforeActors); XCTAssertEqual(headers, beforeHeaders)
            XCTAssertEqual(blits, c.blits, s.label)
            guard events == c.events else {
                let index = zip(events,c.events).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset
                throw OriginalStateError.invalidStorage("Result layout events differ in \(s.label), index \(index.map(String.init) ?? "count"), native \(events.count), source \(c.events.count): \(index.map { String(describing: events[$0])+" / "+String(describing: c.events[$0]) } ?? "")")
            }
            totalEvents += events.count; totalBlits += blits
            if s.label == "whole-playback" {
                var trial = initial, storage: OriginalStateRecord? = localBefore, passes = 0, formats = 0, activeText: UInt32 = 0
                XCTAssertThrowsError(try invoke(&trial, &storage, stage: 0, target: corpus.indicatorTarget) { event in
                    if event.kind == "infoText" { activeText = event.arguments[0] }
                    if event.kind == "format" { formats += 1 }
                    if event.kind == "fontPass" && activeText == 0x450e98 {
                        passes += 1
                        if passes == 3 { throw OriginalStateError.invalidStorage("Result layout late overlay observer") }
                    }
                }) { error in
                    guard case OriginalStateError.invalidStorage("Result layout late overlay observer") = error else { return XCTFail("Unexpected late layout error: \(error)") }
                }
                XCTAssertEqual(passes, 3); XCTAssertEqual(formats, 22); XCTAssertEqual(trial, initial); XCTAssertEqual(storage, localBefore); rollbackTrials += 1
                trial = initial; storage = localBefore
                XCTAssertThrowsError(try invoke(&trial, &storage, stage: 0, target: nil, observe: { _ in })) { error in
                    guard case OriginalStateError.invalidStorage("Result layout: Retained indicator target unavailable") = error else { return XCTFail("Unexpected target error: \(error)") }
                }
                XCTAssertEqual(trial, initial); XCTAssertEqual(storage, localBefore); rollbackTrials += 1
            }
            if s.label == "ordinary" {
                var trial = initial, storage: OriginalStateRecord?
                XCTAssertThrowsError(try invoke(&trial, &storage, stage: nil, target: nil, observe: { _ in })) { error in
                    guard case OriginalStateError.invalidStorage("Result layout: Caller string backing unavailable") = error else { return XCTFail("Unexpected storage error: \(error)") }
                }
                XCTAssertEqual(trial, initial); XCTAssertNil(storage); rollbackTrials += 1
                try trial.write(Int32(1), at: 0x451160-0x44d000); let initialStage = trial; storage = localBefore
                XCTAssertThrowsError(try invoke(&trial, &storage, stage: nil, target: nil, observe: { _ in })) { error in
                    guard case OriginalStateError.invalidStorage("Result layout: Retained stage result unavailable") = error else { return XCTFail("Unexpected stage error: \(error)") }
                }
                XCTAssertEqual(trial, initialStage); XCTAssertEqual(storage, localBefore); rollbackTrials += 1
            }
            if s.label == "skip-all" {
                var trial = initial, storage: OriginalStateRecord?
                try invoke(&trial, &storage, stage: nil, target: nil) { _ in XCTFail("Disabled layout produced an event") }
                XCTAssertEqual(trial, initial); XCTAssertNil(storage)
            }
        }
        if corpus.cases.count >= 6 { XCTAssertEqual(rollbackTrials, 4) }
        print("RESULT LAYOUT \(corpus.cases.count-faultRejections) whole matches, \(faultRejections) source fault rejections, \(totalEvents) events, \(totalBlits) Blts, \(rollbackTrials) rollback trials")
    }
}
