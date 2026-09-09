import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationServiceKeysTests: XCTestCase {
    struct Store: Decodable,Equatable { let address: UInt32,value: UInt32 }
    struct Case: Decodable { let index: Int,before: [UInt32],pressed: [Int],after: [UInt32],writes: [Store],chain: String?,step: Int? }
    struct Corpus: Decodable { let exeSHA256: String,cases: [Case] }
    func testOriginalPrefixAndRetainedSequences() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_APPLICATION_SERVICE_KEYS_CORPUS"] { url = URL(fileURLWithPath:path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource:"original-application-service-keys.json",withExtension:nil,subdirectory:"Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:12_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.cases.count,3964)
        var retained: [String:OriginalApplicationKeyScan] = [:],steps: [String:Int] = [:]
        for item in c.cases {
            var state = OriginalApplicationKeyScan(sequence:item.before[0],diagnostics:item.before[1],mode:item.before[2])
            if let chain = item.chain {
                if let own = retained[chain] { XCTAssertEqual(state,own);state = own }
                else { XCTAssertEqual(item.before,[0,0,0]) }
                XCTAssertEqual(item.step,steps[chain,default:0]);steps[chain,default:0] += 1
            }
            let pressed = Set(item.pressed),keyboard: [UInt8] = (0..<300).map { pressed.contains($0) ? 100 : 117 }
            var stores: [Store] = []
            try state.apply(keyboard:keyboard) { stores.append(.init(address:$0,value:$1)) }
            XCTAssertEqual([state.sequence,state.diagnostics,state.mode],item.after,"case\(item.index)")
            XCTAssertEqual(stores,item.writes,"case\(item.index)")
            if let chain = item.chain { retained[chain] = state }
        }
    }
    func testLateModeObserverRetainsState() throws {
        enum Failure: Error { case observer }
        var state = OriginalApplicationKeyScan(sequence:0,diagnostics:0,mode:0)
        let original = state,pressed: Set<Int> = [65,66,67,112,113,114]
        var stores: [Store] = []
        XCTAssertThrowsError(try state.apply(keyboard:(0..<300).map { pressed.contains($0) ? 100 : 117 }) { address,value in
            stores.append(.init(address:address,value:value))
            if address == 0x4593a0 && value == 2 { throw Failure.observer }
        })
        XCTAssertEqual(state,original)
        XCTAssertEqual(stores,[.init(address:0x450bec,value:1),.init(address:0x4593a4,value:0),
            .init(address:0x4593a0,value:0),.init(address:0x4593a0,value:1),.init(address:0x4593a0,value:2)])
    }
}
