import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationTimerTests: XCTestCase {
    struct Event: Decodable,Equatable { let kind: String,arguments: [UInt32] }
    struct Case: Decodable {
        let index: Int,speed: Int32,baselineBefore: UInt32,clockResponses: [UInt32],dispatchResult: Int32,target: UInt32
        let baselineAfter: UInt32,events: [Event]
    }
    struct Corpus: Decodable { let exeSHA256: String,cases: [Case] }
    private func corpus() throws -> Corpus {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_APPLICATION_TIMER_CORPUS"] { url = URL(fileURLWithPath:path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource:"original-application-timer.json",withExtension:nil,subdirectory:"Fixtures")) }
        return try JSONDecoder().decode(Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:2_000_000))
    }
    func testWholeDecisionAndRequestOrder() throws {
        let corpus = try corpus();XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.cases.count,2025)
        for c in corpus.cases {
            var timer = OriginalApplicationTimer(baseline:c.baselineBefore),events: [Event] = [],reads = 0,targets = 0
            try timer.iterate(speedFlag:c.speed,time:{
                XCTAssertLessThan(reads,c.clockResponses.count);let value = c.clockResponses[reads];reads += 1
                events.append(.init(kind:"time",arguments:[value]));return value
            },target:{ targets += 1;return c.target },dispatch:{ target in
                events.append(.init(kind:"dispatch",arguments:[target,UInt32(bitPattern:c.dispatchResult)]));return c.dispatchResult
            },recoverSurface:{ events.append(.init(kind:"recoverSurface",arguments:[])) },sleep:{ value in
                events.append(.init(kind:"sleep",arguments:[value]))
            })
            XCTAssertEqual(timer.baseline,c.baselineAfter,"case\(c.index)");XCTAssertEqual(events,c.events,"case\(c.index)")
            XCTAssertEqual(targets,c.events.filter { $0.kind == "dispatch" }.count)
        }
    }
    func testLateSleepFailureRetainsBaseline() throws {
        enum Failure: Error { case sleep }
        var timer = OriginalApplicationTimer(baseline:0),clock = [UInt32(34),34,34].makeIterator(),requests: [String] = []
        XCTAssertThrowsError(try timer.iterate(speedFlag:1,time:{ clock.next()! },target:{ requests.append("target");return 7 },
            dispatch:{ _ in requests.append("dispatch");return -1 },recoverSurface:{ requests.append("recover") },sleep:{ _ in requests.append("sleep");throw Failure.sleep }))
        XCTAssertEqual(timer.baseline,0);XCTAssertEqual(requests,["target","dispatch","recover","sleep"])
    }
}
