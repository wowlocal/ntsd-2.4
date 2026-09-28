import XCTest
@testable import NTSDCore

final class OriginalRetainedHistoryTests: XCTestCase {
    final class Owner { let id: Int; init(_ id: Int) { self.id = id } }

    func testCopiesShareEarlierElementsAndAppendIndependently() {
        var a = OriginalRetainedHistory<Int>()
        XCTAssertEqual(a.count,0); XCTAssertEqual(a.elements,[])
        a.append(1); a.append(2)
        var b = a
        b.append(3); a.append(4)
        XCTAssertEqual(a.elements,[4,2,1]); XCTAssertEqual(b.elements,[3,2,1])
        XCTAssertEqual(a.count,3); XCTAssertEqual(b.count,3)
    }

    func testElementsLiveWhileAnyCopyHoldsThem() {
        weak var first: Owner?
        var copy: OriginalRetainedHistory<Owner>?
        do {
            var history = OriginalRetainedHistory<Owner>()
            let owner = Owner(1); first = owner
            history.append(owner); history.append(Owner(2))
            copy = history
        }
        XCTAssertNotNil(first)
        copy = nil
        XCTAssertNil(first)
    }

    func testLongHistoryReleasesWithoutRecursion() {
        var history: OriginalRetainedHistory<Int>? = .init()
        for i in 0..<1_000_000 { history!.append(i) }
        let shared = history
        history!.append(-1)
        XCTAssertEqual(history?.count,1_000_001); XCTAssertEqual(shared?.count,1_000_000)
        history = nil
        XCTAssertEqual(shared?.count,1_000_000)
    }
}
