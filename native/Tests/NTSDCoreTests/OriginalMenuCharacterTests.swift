import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalMenuCharacterTests: XCTestCase {
    typealias Blob = OriginalNetworkClientTests.Blob
    typealias Resources = OriginalNetworkClientTests.Resources
    struct Spec: Decodable { let key: UInt32, shift: UInt8, caps: [UInt32] }
    struct Event: Decodable { let kind: String, value: UInt8?, argument: UInt32?, result: UInt32? }
    struct Sample: Decodable { let index: Int, spec: Spec, before: String, after: String, events: [Event], result: UInt8 }
    struct Corpus: Decodable { let exeSHA256: String, limited: Bool, cases: [Sample], blobs: [String:Blob], globalWritten: String }
    func corpus() throws -> Corpus {
        let url: URL
        if let p = ProcessInfo.processInfo.environment["NTSD_MENU_CHARACTER_CORPUS"] { url = URL(fileURLWithPath: p) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-menu-character.json",withExtension: nil,subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 40_000_000))
        XCTAssertEqual(c.cases.count,10492);XCTAssertFalse(c.limited);XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c");return c
    }
    func testWholeCharacterCallsAndExactReadRequestOrder() throws {
        let c = try corpus(),r = Resources(c.blobs);var requests = 0,reads = 0
        XCTAssertTrue(try r.blob(c.globalWritten).allSatisfy { $0 == 0 })
        for s in c.cases {
            let globals = try r.record(s.before);var cursor = 0,cap = 0
            func next(_ kind: String) throws -> Event {
                guard cursor < s.events.count else { throw OriginalStateError.invalidStorage("Extra character event case\(s.index)") }
                let e = s.events[cursor];cursor += 1;XCTAssertEqual(e.kind,kind);return e
            }
            let result = try OriginalMenuCharacter.decode(s.spec.key,readShift: {
                let e = try next("shift"),value = try globals.integer(at: 0x455388-OriginalMatchPreparation.globalBase,as: UInt8.self)
                XCTAssertEqual(value,s.spec.shift);XCTAssertEqual(e.value,value);reads += 1;return value
            },keyState: { key in
                let e = try next("keyState");XCTAssertEqual(e.argument,key);XCTAssertLessThan(cap,s.spec.caps.count)
                let result = s.spec.caps[cap];cap += 1;requests += 1;XCTAssertEqual(e.result,result);return Int32(bitPattern: result)
            })
            XCTAssertEqual(result,s.result,"Case\(s.index)");XCTAssertEqual(cursor,s.events.count);XCTAssertEqual(globals,try r.record(s.after))
        }
        print("MENU CHARACTER 10492 whole calls \(requests) keyboard requests \(reads) Shift reads")
    }
    func testUnknownShiftAndUnavailableFirstOrSecondResponseReject() throws {
        enum Stop: Error { case absent }
        for key: UInt32 in [65,49,0xbd,0x21,0xff,300,UInt32.max] {
            XCTAssertThrowsError(try OriginalMenuCharacter.decode(key,readShift: { throw Stop.absent },keyState: { _ in XCTFail("Unexpected keyboard request");return 0 }))
        }
        for fail in [1,2] {
            var calls = 0,reads = 0
            XCTAssertThrowsError(try OriginalMenuCharacter.decode(65,readShift: { reads += 1;return 100 },keyState: { key in
                XCTAssertEqual(key,20);calls += 1;if calls == fail { throw Stop.absent };return 1
            }))
            XCTAssertEqual(calls,fail);XCTAssertEqual(reads,1)
        }
    }
    func testSpaceAndKeypadDoNotRequireShiftOrCaps() throws {
        for (key,expected): (UInt32,UInt8) in [(0x20,0x20),(0x60,0x30),(0x69,0x39),(0x6b,0x2b),(0x6d,0x2d),(0x6a,0x2a),(0x6f,0x2f),(0x6e,0x2e)] {
            XCTAssertEqual(try OriginalMenuCharacter.decode(key,readShift: { XCTFail("Unread Shift");return 0 },keyState: { _ in XCTFail("Unread Caps");return 0 }),expected)
        }
    }
}
