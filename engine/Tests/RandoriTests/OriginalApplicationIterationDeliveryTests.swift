import XCTest
@testable import RandoriCore

final class OriginalApplicationIterationDeliveryTests: XCTestCase {
    private final class Held: OriginalApplicationStartupResource {}
    private typealias Exchange = OriginalApplicationIterationExchange

    /// A consumed one-request cursor whose single receipt retains `resources`.
    private func consumed(_ resources: [any OriginalApplicationStartupResource]) throws -> Exchange.Cursor {
        let exchange = Exchange(),request = OriginalApplicationIterationRequest.queue(.init(.time))
        var cursor = try exchange.snapshot.cursor()
        do { _ = try cursor.response(for:request); XCTFail("expected a ticket") } catch let ticket as Exchange.RequestNeeded {
            let permit = try exchange.claim(ticket); try exchange.beginService(permit)
            try exchange.answer(permit,response:.queue(.init(result:7)),retaining:resources)
        }
        var replay = try exchange.snapshot.cursor()
        XCTAssertEqual(try replay.response(for:request),.queue(.init(result:7)))
        return replay
    }

    func testOnlyIterationsHoldingResourcesAreRetained() throws {
        var delivery = OriginalApplicationIterationDelivery()
        weak var weakHeld: Held?
        try autoreleasepool {
            let held = Held(); weakHeld = held
            delivery.begin(try consumed([]))
            delivery.begin(try consumed([held]))
            // The resource-free iteration before it is not kept.
            XCTAssertEqual(delivery.retainedIterationCount,0)
            delivery.begin(try consumed([]))
        }
        // The iteration that retained a resource is kept, and so is the resource.
        XCTAssertEqual(delivery.retainedIterationCount,1)
        XCTAssertNotNil(weakHeld)
        for _ in 0..<100 { delivery.begin(try consumed([])) }
        XCTAssertEqual(delivery.retainedIterationCount,1)
        // An unconsumed cursor is not kept, with or without resources (unchanged).
        let exchange = Exchange()
        delivery.begin(try exchange.snapshot.cursor()); delivery.begin(try exchange.snapshot.cursor())
        XCTAssertEqual(delivery.retainedIterationCount,1)
    }

    /// Menu iterations hold the same surfaces every frame (MENU_MEMORY): each
    /// distinct resource is kept once and stays alive, however many
    /// iterations held it, and a copy keeps what it had when copied.
    func testRetainedResourcesAreKeptOnceEach() throws {
        var delivery = OriginalApplicationIterationDelivery()
        weak var weakFirst: Held?,weakSecond: Held?,weakThird: Held?
        var copy: OriginalApplicationIterationDelivery?
        try autoreleasepool {
            let first = Held(),second = Held(),third = Held(); weakFirst = first; weakSecond = second; weakThird = third
            for i in 0..<1000 { delivery.begin(try consumed(i == 500 ? [first,second] : [first])) }
            delivery.begin(try consumed([]))
            copy = delivery
            delivery.begin(try consumed([third]))
            delivery.begin(try consumed([]))
        }
        XCTAssertEqual(delivery.retainedIterationCount,1001)
        XCTAssertEqual(delivery.retainedResourceCount,3)
        XCTAssertNotNil(weakFirst); XCTAssertNotNil(weakSecond); XCTAssertNotNil(weakThird)
        XCTAssertEqual(copy?.retainedIterationCount,1000)
        XCTAssertEqual(copy?.retainedResourceCount,2)
        // Either holder alone keeps what it holds; the last one releases it.
        delivery = OriginalApplicationIterationDelivery()
        XCTAssertNotNil(weakFirst); XCTAssertNotNil(weakSecond); XCTAssertNil(weakThird)
        copy = nil
        XCTAssertNil(weakFirst); XCTAssertNil(weakSecond)
    }
}
