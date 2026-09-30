import XCTest
@testable import NTSDCore

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
}
