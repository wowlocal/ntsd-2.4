import XCTest
@testable import NTSDCore

/// ENGINE_SPLIT E5c-0: an ID set answers as its literal list does for every
/// Int32 a catalog header can hold. Synthetic sets.
final class OriginalIDSetTests: XCTestCase {
    func check(_ ids: [Int32],file: StaticString = #filePath,line: UInt = #line) {
        let set = OriginalIDSet(ids)
        var probes: [Int32] = [Int32.min,Int32.min+1,-65536,-129,-128,-65,-64,-63,-2,-1,63,64,65,127,128,129,
                               65535,65536,65537,0x7fff_ffff-1,Int32.max]
        probes += Array(0...4096)
        for id in ids { for bit in 0..<32 { probes.append(id ^ Int32(bitPattern: UInt32(1) << UInt32(bit))) } }
        for probe in probes { XCTAssertEqual(set.contains(probe),ids.contains(probe),"\(ids) \(probe)",file: file,line: line) }
        XCTAssertEqual(set.ids,ids,file: file,line: line)
    }
    func testMembershipEqualsTheLiteralList() {
        check([])
        check([0])
        check([65535])
        check([0,65535])
        check([63,64,127,128])
        check([200,203,205,206,207,215,216])
        check([1,1,2,3,5,8,13,21,34,55,89,144,233,377,610,987,1597,2584,4181,6765,10946,17711,28657,46368])
    }
    func testEqualityFollowsTheList() {
        XCTAssertEqual(OriginalIDSet([200,203]),OriginalIDSet([200,203]))
        XCTAssertNotEqual(OriginalIDSet([200,203]),OriginalIDSet([200,204]))
    }
}
