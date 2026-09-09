import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalQueuedSoundTests: XCTestCase {
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Spec: Decodable { let label: String, entry: UInt32?, loop: UInt32?, results: [Int32]? }
    private struct Case: Decodable {
        let spec: Spec, before: String, after: String, written: String
        let events: [OriginalQueuedSound.Event], methods: Int
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, fpcw: Int, playWord: UInt32, cases: [Case], blobs: [String:Blob]
    }
    func testWholeOriginalQueuedSoundAndBufferPlayback() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_QUEUED_SOUND_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-queued-sound", withExtension: "json", subdirectory: "Fixtures")) }
        let corpus = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 192_000_000))
        XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.fpcw,0x23f);XCTAssertFalse(corpus.cases.isEmpty)
        var cache: [String:[UInt8]] = [:], methods = 0, events = 0, rollbacks = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = cache[key] { return bytes }
            let item = try XCTUnwrap(corpus.blobs[key]), packed = try XCTUnwrap(Data(base64Encoded: item.deflate))
            guard packed.count >= 6, packed[0] == 0x78, packed[1] == 0xda else { throw OriginalStateError.invalidStorage("Queued sound fixture framing") }
            let bytes = try MatchPreparationReference.inflate(Data(packed.dropFirst(2).dropLast(4)).base64EncodedString(),count: item.count)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw OriginalStateError.invalidStorage("Queued sound fixture SHA") }
            cache[key] = bytes;return bytes
        }
        func record(_ key: String) throws -> OriginalStateRecord {
            let bytes = try blob(key);return try .init(bytes: bytes,defined: .init(repeating: true,count: bytes.count))
        }
        for c in corpus.cases {
            var globals = try record(c.before)
            let before = globals, results = c.spec.results ?? [-2147467259,0,-1,1]
            var actual: [OriginalQueuedSound.Event] = [], calls = 0, written = [UInt8](repeating: 0,count: globals.bytes.count)
            func request(_ event: OriginalQueuedSound.Event) throws -> Int32 {
                actual.append(event)
                if event.kind == .queueWrite {
                    XCTAssertEqual(event.arguments.count,2);XCTAssertEqual(event.arguments[1],0)
                    let offset = Int(event.arguments[0])-0x44d000
                    guard offset >= 0, offset+4 <= written.count else { throw OriginalStateError.invalidStorage("Queued sound fixture write extent") }
                    for i in offset..<offset+4 { written[i] = 1 }
                }
                if event.kind == .method { defer { calls += 1 };return results[calls%results.count] }
                return 0
            }
            if c.spec.entry == 0x401a30 {
                try OriginalQueuedSound.play(bufferWordAddress: corpus.playWord,loop: c.spec.loop ?? 0,globals: globals,request: request)
            } else { try OriginalQueuedSound.drain(globals: &globals,request: request) }
            XCTAssertEqual(globals,try record(c.after),c.spec.label)
            XCTAssertEqual(written,try blob(c.written),c.spec.label)
            XCTAssertEqual(calls,c.methods,c.spec.label)
            guard actual == c.events else {
                let index = zip(actual,c.events).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset
                throw OriginalStateError.invalidStorage("Queued sound events differ in \(c.spec.label), index \(index.map(String.init) ?? "count")")
            }
            methods += calls;events += actual.count
            if c.spec.label == "all-queues" {
                var trial = before, requests = 0, clears = 0, plays = 0
                XCTAssertThrowsError(try OriginalQueuedSound.drain(globals: &trial) { event in
                    if event.kind == .queueWrite { clears += 1 }
                    if event.kind == .play { plays += 1 }
                    if event.kind == .method {
                        requests += 1
                        if requests == 7 { throw OriginalStateError.invalidStorage("Queued sound late method observer") }
                    }
                    return 0
                }) { error in
                    guard case OriginalStateError.invalidStorage("Queued sound late method observer") = error else { return XCTFail("Unexpected queued sound error: \(error)") }
                }
                XCTAssertEqual(requests,7);XCTAssertEqual(clears,2);XCTAssertEqual(plays,1);XCTAssertEqual(trial,before);rollbacks += 1
            }
        }
        if corpus.cases.count > 950 { XCTAssertEqual(rollbacks,1) }
        print("QUEUED SOUND \(corpus.cases.count) calls, \(events) events, \(methods) COM requests, \(rollbacks) late rollback trials")
    }
}
