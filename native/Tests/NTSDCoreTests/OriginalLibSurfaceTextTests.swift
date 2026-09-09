import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalLibSurfaceTextTests: XCTestCase {
    struct Case: Decodable {
        let index: Int, target: UInt32, text: [UInt8], background: UInt32, color: UInt32
        let x: Int32, y: Int32, dcResult: Int32, dc: UInt32, retainedDC: UInt32, retainedDCAfter: UInt32
        let before: [UInt8], after: [UInt8], events: [OriginalMenuPresentationEvent], result: Int32
    }
    struct Corpus: Decodable {
        let exeSHA256: String, libSHA256: String, cases: [Case], retainedChain: [Int]
    }
    private func corpus() throws -> Corpus {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_LIB_SURFACE_TEXT_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-lib-surface-text.json", withExtension: nil, subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 5_000_000))
        XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.libSHA256, "28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
        return c
    }
    func testActualInstalledReplacementAndRetainedDC() throws {
        let c = try corpus(); XCTAssertEqual(c.cases.count, 276); XCTAssertEqual(c.retainedChain.count, 6)
        var chain: OriginalLibSurfaceText?
        for item in c.cases {
            var state: OriginalLibSurfaceText
            if c.retainedChain.contains(item.index), let prior = chain {
                state = prior; XCTAssertEqual(state.retainedDC, item.retainedDC)
            } else { state = OriginalLibSurfaceText(retainedDC: item.retainedDC) }
            var events: [OriginalMenuPresentationEvent] = []
            let result = try state.draw(item.text, target: item.target, background: item.background,
                color: item.color, x: item.x, y: item.y, dcResult: item.dcResult, dc: item.dc) { events.append($0) }
            XCTAssertEqual(result, item.result); XCTAssertEqual(events, item.events, "Events \(item.index)")
            XCTAssertEqual(state.retainedDC, item.retainedDCAfter, "DC \(item.index)")
            var storage = try OriginalStateRecord(bytes: item.before, defined: Array(repeating: true, count: item.before.count))
            XCTAssertEqual(try storage.integer(at: 0x6e, as: UInt32.self), item.retainedDC)
            try storage.write(state.retainedDC, at: 0x6e)
            XCTAssertEqual(storage.bytes, item.after, "All library data \(item.index)")
            if c.retainedChain.contains(item.index) { chain = state }
        }
    }
    func testLateObserverFailurePreservesRetainedDC() throws {
        enum Stop: Error { case late }
        var state = OriginalLibSurfaceText(retainedDC: 0xaabbccdd), events: [OriginalMenuPresentationEvent] = []
        XCTAssertThrowsError(try state.draw([65], target: 1, background: 2, color: 3,
            x: 4, y: 5, dcResult: 0, dc: 6) { event in
                events.append(event)
                if event.kind == .releaseDC { throw Stop.late }
            })
        XCTAssertEqual(events.count, 6); XCTAssertEqual(state.retainedDC, 0xaabbccdd)
    }
}
