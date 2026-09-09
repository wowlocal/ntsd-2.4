import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalReplayCompressionTests: XCTestCase {
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Event: Decodable { let kind: String, address: UInt32, count: UInt32?, size: UInt32? }
    private struct Allocation: Decodable { let count: Int, size: Int, address: UInt32, live: Bool }
    private struct Case: Decodable {
        let label: String, input: String, output: String, written: String
        let capacity: Int, level: Int32?, failAt: UInt32, result: Int32, length: Int
        let events: [Event], allocations: [Allocation]
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, dllSHA256: String, cases: [Case], blobs: [String:Blob]
    }
    func testWholeOriginalCompressionWithCapacityAndAllocationFailures() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_REPLAY_COMPRESSION_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-replay-compression", withExtension: "json", subdirectory: "Fixtures")) }
        let corpus = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 128_000_000))
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.dllSHA256, "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        XCTAssertFalse(corpus.cases.isEmpty)
        var cache: [String:[UInt8]] = [:], bytes = 0, failures = 0, unfinished = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let value = cache[key] { return value }
            let item = try XCTUnwrap(corpus.blobs[key])
            let value = try MatchPreparationReference.inflate(item.deflate, count: item.count)
            guard MatchPreparationReference.digest(Data(value)) == key else {
                throw OriginalStateError.invalidStorage("Compression fixture blob hash")
            }
            cache[key] = value; return value
        }
        for c in corpus.cases {
            let source = try blob(c.input), expected = try blob(c.output), written = try blob(c.written)
            XCTAssertEqual(expected.count, c.capacity); XCTAssertEqual(written.count, c.capacity)
            // Previously defined bytes must survive partial/failed compression.
            let priorMask = (0..<c.capacity).map { $0%3 == 0 }
            var output = try OriginalStateRecord(bytes: [UInt8](repeating: 0xa5, count: c.capacity), defined: priorMask)
            let result: OriginalReplayCompression.Result
            if c.failAt == 0 {
                result = try OriginalReplayCompression.compress(source, destination: &output, level: c.level ?? -1)
            } else {
                result = try OriginalReplayCompression.compress(source, destination: &output, level: c.level ?? -1, failureOrdinal: c.failAt)
            }
            guard output.bytes == expected else {
                return XCTFail("Compressed bytes \(c.label), first mismatch \(zip(output.bytes,expected).enumerated().first { $0.element.0 != $0.element.1 }?.offset ?? -1)")
            }
            XCTAssertEqual(result.status, c.result, c.label); XCTAssertEqual(result.length, c.length, c.label)
            guard written == [UInt8](repeating: 1, count: result.written)+[UInt8](repeating: 0, count: c.capacity-result.written),
                  output.defined == zip(priorMask,written).map({ $0 || $1 != 0 }) else {
                return XCTFail("Compression write provenance \(c.label)")
            }
            XCTAssertEqual(result.unreleasedAllocations, c.allocations.filter(\.live).count, c.label)
            XCTAssertEqual(result.allocationEvents.count, c.events.count, c.label)
            let ordinals = Dictionary(uniqueKeysWithValues: c.allocations.enumerated().filter { $0.element.address != 0 }.map { ($0.element.address, UInt32($0.offset+1)) })
            for (old,new) in zip(c.events,result.allocationEvents) {
                XCTAssertEqual(new.kind, old.kind == "calloc" ? 1 : 2, c.label)
                XCTAssertEqual(new.ordinal, ordinals[old.address] ?? 0, c.label)
                if old.kind == "calloc" {
                    XCTAssertEqual(new.count, old.count, c.label)
                    if old.size == 5816 {
                        // Private deflate_state differs between x86 and LP64.
                        XCTAssertEqual(new.nativeSize, 5920, c.label)
                    } else { XCTAssertEqual(new.nativeSize, old.size, c.label) }
                }
            }
            bytes += c.capacity; failures += c.result != 0 ? 1 : 0; unfinished += result.unreleasedAllocations > 0 ? 1 : 0
        }
        print("REPLAY COMPRESSION", corpus.cases.count, "whole calls,", bytes, "output bytes/masks,", failures, "error statuses,", unfinished, "unfinished source allocation lifecycles")
    }
}
