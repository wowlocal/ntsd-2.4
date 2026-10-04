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

    func testDroppingTheNewerCopyKeepsTheSharedTailLinked() {
        weak var oldest: Owner?
        var older = OriginalRetainedHistory<Owner>()
        do { let owner = Owner(0); oldest = owner; older.append(owner) }
        for i in 1..<5 { older.append(Owner(i)) }
        var newer: OriginalRetainedHistory<Owner>? = older
        newer!.append(Owner(99))
        newer = nil
        XCTAssertEqual(older.elements.map(\.id),[4,3,2,1,0])
        XCTAssertNotNil(oldest)
        var copy: OriginalRetainedHistory<Owner>? = older
        copy!.append(Owner(7))
        older = .init()
        XCTAssertEqual(copy?.elements.map(\.id),[7,4,3,2,1,0])
        copy = nil
        XCTAssertNil(oldest)
    }

    func testDroppingANewerCopyReleasesOnlyItsOwnNodes() {
        weak var own: Owner?
        var older = OriginalRetainedHistory<Owner>()
        for i in 0..<3 { older.append(Owner(i)) }
        var newer: OriginalRetainedHistory<Owner>? = older
        do { let owner = Owner(98); own = owner; newer!.append(owner) }
        newer!.append(Owner(99))
        newer = nil
        XCTAssertNil(own)
        XCTAssertEqual(older.elements.map(\.id),[2,1,0])
    }
}
