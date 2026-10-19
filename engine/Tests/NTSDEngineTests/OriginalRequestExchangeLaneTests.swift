import XCTest
@testable import NTSDCore

/// CORE_REALTIME A3 L4b: a cursor of no exchange answers as an exchange's
/// direct cursor does; its consumption checks are `finish`'s; and after its
/// replies are recorded, `claimNext` claims what a cursor over them would ask.
final class OriginalRequestExchangeLaneTests: XCTestCase {
    /// Hides a constant closure from the release optimizer: specialising the
    /// still-generic `standaloneCursor` closure on one crashed Xcode's Swift
    /// (PerfInliner, `isLoadableOrOpaque`; rtl4b- and rtl4bt-tests-build.log).
    @inline(never) private func opaque<T>(_ value: T) -> T { value }

    typealias Exchange = OriginalApplicationIterationExchange
    typealias Loop = OriginalApplicationMessageLoop

    func testStandaloneCursorMatchesADirectCursor() throws {
        let requests: [Exchange.Request] = [.queue(.init(.peek)),.queue(.init(.time)),.queue(.init(.time)),.queue(.init(.sleep,[5]))]
        func answer(_ q: Exchange.Request) throws -> Exchange.Response? {
            guard case .queue(let r) = q else { return nil }
            return r.kind == .sleep ? nil : .queue(.init(result:r.kind == .peek ? 0 : 1234))
        }
        let exchange = Exchange()
        var direct = try exchange.directCursor(opaque { try answer($0) }),lane = Exchange.standaloneCursor(opaque { try answer($0) })
        var directLog: [String] = [],laneLog: [String] = []
        for q in requests {
            do { directLog.append("\(try direct.response(for:q))") } catch { directLog.append("needed") }
            do { laneLog.append("\(try lane.response(for:q))") } catch { laneLog.append("needed") }
        }
        XCTAssertEqual(laneLog,directLog);XCTAssertEqual(laneLog.last,"needed")
        XCTAssertEqual(lane.position,direct.position);XCTAssertEqual(lane.isSuspended,direct.isSuspended)
        XCTAssertThrowsError(try lane.requireConsumed()) { XCTAssertEqual($0 as? Exchange.Boundary,.suspendedCursor) }

        // A committed attempt's cursor: every reply consumed.
        var done = Exchange.standaloneCursor(opaque { try answer($0) })
        for q in requests.prefix(3) { _ = try done.response(for:q) }
        XCTAssertNoThrow(try done.requireConsumed())

        // After recording the served replies, claimNext equals claiming the
        // ticket a cursor over them raises for the declined request.
        let served = try requests.prefix(3).map { Exchange.Receipt(request:$0,response:try XCTUnwrap(try answer($0)),resources:[]) }
        let a = Exchange(),b = Exchange()
        try a.record(served);try b.record(served)
        var replay = try a.snapshot.cursor()
        for q in requests.prefix(3) { _ = try replay.response(for:q) }
        var ticket: Exchange.RequestNeeded?
        do { _ = try replay.response(for:requests[3]) } catch let needed as Exchange.RequestNeeded { ticket = needed }
        let viaTicket = try a.claim(try XCTUnwrap(ticket)),viaNext = try b.claimNext(requests[3])
        XCTAssertEqual(viaNext.request,viaTicket.request);XCTAssertEqual(viaNext.ordinal,viaTicket.ordinal);XCTAssertEqual(viaNext.ordinal,3)
        XCTAssertThrowsError(try b.claimNext(requests[3])) { XCTAssertEqual($0 as? Exchange.Boundary,.requestInFlight) }
    }
}
