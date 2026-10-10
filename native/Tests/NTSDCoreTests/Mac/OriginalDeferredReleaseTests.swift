import Foundation
import XCTest
@testable import NTSDRuntime

/// CORE_REALTIME R3: a retired value's last reference is dropped on the
/// release thread, every retired value is freed, and live copies that share
/// its buffers keep their contents.
final class OriginalDeferredReleaseTests: XCTestCase {
    final class Probe {
        let freed: (String?,Bool) -> Void
        init(_ freed: @escaping (String?,Bool) -> Void) { self.freed = freed }
        deinit { freed(Thread.current.name,Thread.isMainThread) }
    }
    struct Held { var probes: [Probe]; var bytes: [UInt8] }

    func testRetiredValuesAreFreedOnTheReleaseThread() throws {
        let started = expectation(description:"thread start"),freed = expectation(description:"freed")
        freed.expectedFulfillmentCount = 1000
        let lock = NSLock()
        var names = Set<String?>(),onMain = 0
        let release = OriginalDeferredRelease(threadStart:{ started.fulfill() })
        var live: [UInt8] = []
        for round in 0..<100 {
            var held = Held(probes:(0..<10).map { _ in Probe { name,main in
                lock.lock(); names.insert(name); if main { onMain += 1 }; lock.unlock(); freed.fulfill()
            } },bytes:[UInt8](repeating:UInt8(round),count:64))
            live = held.bytes   // shares the retired value's buffer
            release.retire(consume held)
            held = Held(probes:[],bytes:[])
            XCTAssertEqual(live,[UInt8](repeating:UInt8(round),count:64))
            live[0] = 0xee      // written while the release thread may still hold it
            XCTAssertEqual(live,[0xee]+[UInt8](repeating:UInt8(round),count:63))
        }
        wait(for:[started,freed],timeout:30)
        lock.lock(); defer { lock.unlock() }
        XCTAssertEqual(names,["NTSD.release"]);XCTAssertEqual(onMain,0)
        XCTAssertEqual(release.retired,100)
    }

    /// A starved release thread holds at most `backlogLimit` values; the
    /// caller frees the rest itself.
    func testBacklogBeyondTheLimitIsFreedByTheCaller() throws {
        let gate = DispatchSemaphore(value:0),freed = expectation(description:"freed")
        let limit = OriginalDeferredRelease.backlogLimit
        freed.expectedFulfillmentCount = limit+10
        let lock = NSLock()
        var byCaller = 0
        let caller = Thread.current
        let release = OriginalDeferredRelease(threadStart:{ gate.wait() })
        for _ in 0..<limit+10 {
            var probe: Probe? = Probe { _,_ in
                lock.lock(); if Thread.current == caller { byCaller += 1 }; lock.unlock(); freed.fulfill()
            }
            release.retire(consume probe)
            probe = nil
        }
        lock.lock(); XCTAssertEqual(byCaller,10); lock.unlock()
        XCTAssertEqual(release.retired,limit)
        gate.signal()
        wait(for:[freed],timeout:30)
        lock.lock(); XCTAssertEqual(byCaller,10); lock.unlock()
    }
}
