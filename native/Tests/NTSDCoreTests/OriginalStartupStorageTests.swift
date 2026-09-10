import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalStartupStorageTests: XCTestCase {
    struct Sample: Decodable {
        let index: Int, before: [UInt8], after: [UInt8], beforeDefined: [Bool], afterDefined: [Bool]
        let entries: [Int], writeMask: [UInt8]
    }
    struct Corpus: Decodable {
        let exeSHA256: String, libSHA256: String, crtSHA256: String
        let base: Int, count: Int, cases: [Sample], retainedChain: [Int]
    }
    private func corpus() throws -> Corpus {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_STARTUP_STORAGE_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-startup-storage.json", withExtension: nil, subdirectory: "Fixtures")) }
        let value = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 2_000_000))
        XCTAssertEqual(value.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(value.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
        XCTAssertEqual(value.crtSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        return value
    }
    func testActualTableCallbacksAndRetainedBacking() throws {
        let corpus = try corpus()
        XCTAssertEqual(corpus.cases.count,12);XCTAssertEqual(corpus.base,OriginalStartupStorage.observedBase)
        XCTAssertEqual(corpus.count,OriginalStartupStorage.observedCount)
        var retained: OriginalStateRecord?
        for sample in corpus.cases {
            let before = try OriginalStateRecord(bytes: sample.before,defined: sample.beforeDefined)
            var storage: OriginalStateRecord
            if corpus.retainedChain.contains(sample.index), let previous = retained {
                XCTAssertEqual(previous,before);storage = previous
            } else { storage = before }
            var completed: [Int] = []
            try OriginalStartupStorage.initialize(&storage) { completed.append($0.rawValue) }
            XCTAssertEqual(completed,sample.entries)
            XCTAssertEqual(storage.bytes,sample.after,"All storage bytes \(sample.index)")
            XCTAssertEqual(storage.defined,sample.afterDefined,"All provenance \(sample.index)")
            XCTAssertEqual(sample.writeMask.filter { $0 != 0 }.count,416)
            if corpus.retainedChain.contains(sample.index) { retained = storage }
        }
        print("STARTUP STORAGE 12 controlled table calls 36 constructors 4992 written bytes")
    }
    func testLateCompletionFailureRollsBackAllStorage() throws {
        enum Stop: Error { case late }
        let sample = try XCTUnwrap(corpus().cases.first { $0.index == 1 })
        let before = try OriginalStateRecord(bytes: sample.before,defined: sample.beforeDefined)
        var storage = before, seen: [OriginalStartupStorage.Constructor] = []
        XCTAssertThrowsError(try OriginalStartupStorage.initialize(&storage) {
            seen.append($0)
            if $0 == .soundQueue { throw Stop.late }
        })
        XCTAssertEqual(seen,OriginalStartupStorage.Constructor.allCases)
        XCTAssertEqual(storage,before)
    }
}
