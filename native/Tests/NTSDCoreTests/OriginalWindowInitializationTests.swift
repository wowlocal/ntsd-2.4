import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalWindowInitializationTests: XCTestCase {
    struct Spec: Decodable { let mode: Int32?, show: Int32?, instance: UInt32? }
    struct Backing: Decodable { let kind: String, bytes: [UInt8] }
    struct Event: Decodable {
        let key: String, request: OriginalWindowInitialization.Request, response: OriginalWindowInitialization.Response
    }
    struct Release: Codable, Equatable { let key: String, result: UInt32 }
    struct Object: Codable, Equatable { let address: UInt32, family: String; var releases: [Release] }
    struct Sample: Decodable {
        let index: Int, spec: Spec, before: [UInt8], after: [UInt8], written: [UInt8]
        let backings: [Backing], events: [Event], objects: [Object], result: Int32
    }
    struct Corpus: Decodable { let exeSHA256: String, libSHA256: String, cases: [Sample] }
    private func corpus() throws -> Corpus {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_WINDOW_INITIALIZATION_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-window-initialization.json", withExtension: nil, subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 128_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
        return c
    }
    private func initial(_ c: Sample) throws -> OriginalStateRecord {
        try .init(bytes: c.before,defined: [Bool](repeating: true,count: c.before.count))
    }
    func testWholeOriginalWindowDisplayAndFailureOrder() throws {
        let corpus = try corpus();XCTAssertGreaterThan(corpus.cases.count,200)
        var events = 0
        for c in corpus.cases {
            var state = try initial(c), event = 0, frame = 0, objects: [Object] = []
            var counters: [String:Int] = [:]
            let result = try OriginalWindowInitialization.initialize(instance: c.spec.instance ?? 0x400000,show: c.spec.show ?? 10,globals: &state,backing: { kind,count in
                guard frame < c.backings.count else { throw OriginalStateError.invalidStorage("Unexpected frame \(c.index)/\(kind)") }
                let input = c.backings[frame];frame += 1;XCTAssertEqual(kind,input.kind);XCTAssertEqual(count,input.bytes.count)
                return input.bytes
            },perform: { request in
                guard event < c.events.count else { throw OriginalStateError.invalidStorage("Unexpected request \(c.index)/\(request.kind)") }
                let expected = c.events[event];event += 1
                XCTAssertEqual(request,expected.request,"Case \(c.index) event \(event) \(expected.key)")
                counters[request.kind,default: 0] += 1
                let key = request.kind+"#"+String(counters[request.kind]!)
                XCTAssertEqual(key,expected.key)
                if let output = expected.response.output {
                    let family = request.kind == "directDrawCreate" ? "draw" : request.kind == "createClipper" ? "clipper" : "surface"
                    XCTAssertFalse(objects.contains { $0.address == output })
                    objects.append(.init(address: output,family: family,releases: []))
                }
                if request.kind == "release" {
                    let index = try XCTUnwrap(objects.firstIndex { $0.address == request.words[0] })
                    objects[index].releases.append(.init(key: key,result: UInt32(bitPattern: expected.response.result)))
                }
                return expected.response
            })
            XCTAssertEqual(result.returnCode,c.result);XCTAssertEqual(result.written,c.written.map { $0 != 0 })
            XCTAssertNil(state.bytes.indices.first { state.bytes[$0] != c.after[$0] },"Global byte mismatch case \(c.index)")
            XCTAssertTrue(state.defined.allSatisfy { $0 })
            XCTAssertEqual(event,c.events.count);XCTAssertEqual(frame,c.backings.count);XCTAssertEqual(objects,c.objects)
            events += event
        }
        print("WINDOW INITIALIZATION \(corpus.cases.count) whole calls \(events) ordered events")
    }
    func testLatePlatformFailureRollsBackGlobals() throws {
        enum Stop: Error { case late }
        let c = try XCTUnwrap(corpus().cases.first);let before = try initial(c)
        var state = before, frame = 0, event = 0
        XCTAssertThrowsError(try OriginalWindowInitialization.initialize(instance: 0x400000,show: 10,globals: &state,backing: { _,_ in
            defer { frame += 1 };return c.backings[frame].bytes
        },perform: { request in
            let expected = c.events[event];event += 1;XCTAssertEqual(request,expected.request)
            if expected.key == "showWindow#2" { throw Stop.late }
            return expected.response
        }))
        XCTAssertEqual(event,c.events.count);XCTAssertEqual(state,before)
    }
    func testMissingDeclaredBackingAndOutputRollBack() throws {
        for missing in ["pixelFormat","successfulOutput"] {
            let c = try XCTUnwrap(corpus().cases.first { $0.spec.mode == (missing == "pixelFormat" ? 1 : 0) })
            let before = try initial(c);var state = before, frame = 0, event = 0
            XCTAssertThrowsError(try OriginalWindowInitialization.initialize(instance: 0x400000,show: 10,globals: &state,backing: { kind,_ in
                defer { frame += 1 }
                return kind == missing ? [] : c.backings[frame].bytes
            },perform: { request in
                let expected = c.events[event];event += 1;XCTAssertEqual(request,expected.request)
                if missing == "successfulOutput" && request.kind == "directDrawCreate" { return .init(result: 0) }
                return expected.response
            }))
            XCTAssertGreaterThan(event,5);XCTAssertEqual(state,before)
        }
    }
}
