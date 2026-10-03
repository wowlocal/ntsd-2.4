import Foundation
import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform

@MainActor final class OriginalMacWindowBackendTests: XCTestCase {
    typealias N = OriginalApplicationPreparedStartupPlatform
    typealias Old = OriginalApplicationPreparedStartupPlatformTests
    typealias Observed = OriginalApplicationObservedStartupTests
    typealias P = OriginalWinMainStartupTests
    typealias D = OriginalApplicationHostDeliveryContextTests
    typealias Driver = OriginalApplicationObservedStartup<N>
    typealias Service = OriginalMacWindowStartupService<N>
    typealias Backend = OriginalMacWindowBackend
    typealias E = OriginalStartupRequestExchange
    enum Stop: Error { case missingOutcome }

    /// All non-window-system APIs are explicit controlled responses. Only HWND
    /// request bindings change to the Native-owned actual window token; no source
    /// after-state, private pointer or expected pixel buffer is used as input.
    @MainActor final class Controls {
        let source: P.Adapter, values: Observed.Service
        let originalWindow: UInt32
        var window: UInt32 = 0
        init(_ source: P.Adapter,_ package: OriginalApplicationStartupInputs) throws {
            self.source = source; values = try Observed.Service(source,package)
            originalWindow = UInt32(bitPattern:try XCTUnwrap(source.c.events.first { $0.kind == "window" && $0.event?.request?.kind == "createWindow" }?.event?.response?.result))
        }
        func answer(_ q: OriginalStartupRequest) throws -> OriginalStartupResponse {
            switch q {
            case .music(let event) where event.kind == .method && event.arguments.count == 5 && event.arguments[1] == 0x34:
                var words = event.arguments; XCTAssertEqual(words[2],window); words[2] = originalWindow
                return try values.answer(.music(.init(event.kind,words,event.strings)))
            case .joystick(let request) where request.kind == "capture":
                var words = request.arguments; XCTAssertEqual(words[0],window); words[0] = originalWindow
                return try values.answer(.joystick(.init(request.kind,words,information:request.information)))
            case .window(let request):
                let events = source.c.events.filter { $0.kind == "window" }
                let expected = try XCTUnwrap(events[values.windowIndex].event?.request)
                XCTAssertEqual(request.kind,expected.kind)
                var words = request.words
                if request.kind == "cooperativeLevel" { XCTAssertEqual(words[1],window); words[1] = originalWindow }
                if request.kind == "clipperWindow" { XCTAssertEqual(words[2],window); words[2] = originalWindow }
                XCTAssertEqual(words,expected.words)
                return try values.answer(q)
            default:return try values.answer(q)
            }
        }
    }

    struct Run {
        let host: Driver.Host, driver: Driver, service: Service, controls: Controls
    }
    func setup() throws -> (Driver,Service,Controls) {
        _ = NSApplication.shared
        let package = try OriginalApplicationStartupInputsTests.shared.get(),(p,initial) = try D().inputs()
        let native = N(inputs:package,prepared:Observed.constants(try Old().preparation(p)))
        let driver = try Driver(platform:native,instance:0x400000,show:10,initial:initial)
        let backend = Backend(instance:0x400000)
        return (driver,Service(driver:driver,backend:backend),try Controls(p,package))
    }
    func service(_ permit: E.Permit,_ driver: Driver,_ service: Service,_ controls: Controls) throws {
        XCTAssertEqual(permit.ordinal,controls.values.calls)
        if case .window(let q) = permit.request,Backend.handles(q) {
            let events = controls.source.c.events.filter { $0.kind == "window" }
            XCTAssertEqual(q.kind,try XCTUnwrap(events[controls.values.windowIndex].event?.request).kind)
            try service.serve(permit)
            controls.values.windowIndex += 1; controls.values.calls += 1
            if q.kind == "createWindow" {
                guard case .window(let response) = try XCTUnwrap(driver.exchangeSnapshot.receipts.last).response else { throw Stop.missingOutcome }
                controls.window = UInt32(bitPattern:response.result)
                XCTAssertNotEqual(controls.window,0)
            }
        } else { try driver.answer(permit,response:controls.answer(permit.request)) }
    }
    func run(late: Bool) throws -> Run {
        let (driver,service,controls) = try setup()
        var didFail = false
        for _ in 0..<1000 {
            do {
                switch try driver.resume(beforeCommit:{ _,_,_ in if late && !didFail { throw P.Trial.late } }) {
                case .request(let permit):
                    XCTAssertNil(driver.snapshot.startup); XCTAssertNil(driver.snapshot.session)
                    XCTAssertEqual(driver.pendingBatchCount,0)
                    try self.service(permit,driver,service,controls)
                case .started(let sequence,let host):
                    XCTAssertEqual(sequence,1); XCTAssertEqual(didFail,late)
                    try controls.values.values.validatePreparedConsumption()
                    XCTAssertEqual(controls.values.calls,driver.exchangeSnapshot.receipts.count)
                    XCTAssertEqual(service.backend.createdWindowCount,1)
                    return .init(host:host,driver:driver,service:service,controls:controls)
                }
            } catch P.Trial.late {
                XCTAssertTrue(late); XCTAssertFalse(didFail); didFail = true
                XCTAssertNil(driver.snapshot.startup); XCTAssertEqual(driver.pendingBatchCount,0)
                XCTAssertEqual(service.backend.createdWindowCount,1)
                XCTAssertTrue(try service.backend.observation(controls.window).visible)
            }
        }
        throw Stop.missingOutcome
    }
    func close(_ run: Run) throws {
        let b = run.service.backend
        let reply = try b.perform(b.prepare(.init("destroyWindow",[run.controls.window])))
        XCTAssertEqual(reply.response.result,1)
        XCTAssertFalse(try b.observation(run.controls.window).visible)
    }
    func testWholeStartupUsesPhysicalWindowAndRetainsReplies() throws {
        let run = try run(late:false); defer { try? close(run) }
        let b = run.service.backend,id = run.controls.window,observation = try b.observation(id)
        XCTAssertEqual(observation.title,"Little Fighter 2"); XCTAssertTrue(observation.visible)
        XCTAssertFalse(observation.closed); XCTAssertGreaterThan(observation.windowNumber,0)
        XCTAssertGreaterThan(observation.backingScale,0)
        let state = try XCTUnwrap(run.host.snapshot.session).state.full
        XCTAssertEqual(try state.integer(at:0x4546f4-0x44d000,as:UInt32.self),id)
        XCTAssertEqual(observation.client.width,CGFloat(try state.integer(at:0x44d78c-0x44d000,as:UInt32.self)))
        XCTAssertEqual(observation.client.height,CGFloat(try state.integer(at:0x44d790-0x44d000,as:UInt32.self)))
        XCTAssertEqual(b.operations.filter { $0.request.kind == "createWindow" }.count,1)
        XCTAssertEqual(b.operations.filter { $0.request.kind == "showWindow" }.count,2)
        XCTAssertEqual(b.operations.filter { $0.request.kind == "metric" }.map(\.request.words),[[7],[8],[8],[4]])
        XCTAssertEqual(b.operations.first { $0.request.kind == "icon" }?.response.result,0)
        let batch = try XCTUnwrap(run.host.takeCommitted()); XCTAssertEqual(batch.sequence,1)
        XCTAssertEqual(try batch.context.platformSnapshot().startupExchange?.position,run.driver.exchangeSnapshot.receipts.count)
        guard case .startup(let output) = batch.contents else { throw Stop.missingOutcome }
        let requests = output.operations.compactMap { if case .window(let q,_) = $0 { return q }; return nil }
        XCTAssertEqual(requests.filter(Backend.handles),b.operations.map(\.request))
        print("Physical AppKit whole startup",observation,"physical window requests",b.operations.count)
    }
    func testWindowGeometryAndResourceLifetimes() throws {
        let run = try run(late:false); defer { try? close(run) }
        let b = run.service.backend,first = try b.observation(run.controls.window)
        let create = try XCTUnwrap(b.operations.first { $0.request.kind == "createWindow" }).request
        var words = create.words; words[6] += 160; words[7] += 120
        let prepared = try b.prepare(.init("createWindow",words,strings:create.strings))
        let served = try b.perform(prepared),id = UInt32(bitPattern:served.response.result)
        XCTAssertNotEqual(id,first.token)
        let second = try b.observation(id)
        XCTAssertEqual(second.client.width,first.client.width+160); XCTAssertEqual(second.client.height,first.client.height+120)
        XCTAssertEqual(second.frame.width,first.frame.width+160); XCTAssertEqual(second.frame.height,first.frame.height+120)
        XCTAssertThrowsError(try b.perform(prepared)) { XCTAssertEqual($0 as? Backend.Boundary,.repeatedPreparation) }
        let count = b.operations.count
        XCTAssertThrowsError(try b.prepare(.init("directDrawCreate",[0,0x457578,0]))) { XCTAssertEqual($0 as? Backend.Boundary,.unsupported("directDrawCreate")) }
        XCTAssertThrowsError(try b.prepare(.init("showWindow",[UInt32.max,5]))) { XCTAssertEqual($0 as? Backend.Boundary,.unknownOwner(UInt32.max)) }
        var full = words; full[0] = 8; full[3] = 0x80000000; full[4] = 0
        XCTAssertThrowsError(try b.prepare(.init("createWindow",full,strings:create.strings)))
        XCTAssertEqual(b.operations.count,count)
        let other = Backend(instance:0x400000)
        XCTAssertThrowsError(try other.perform(b.prepare(.init("metric",[7])))) { XCTAssertEqual($0 as? Backend.Boundary,.foreignPreparation) }
        let closed = try b.perform(b.prepare(.init("destroyWindow",[id])))
        XCTAssertEqual(closed.response.result,1); XCTAssertTrue(try b.observation(id).closed)
        XCTAssertEqual(try b.perform(b.prepare(.init("destroyWindow",[id]))).response.result,0)
        XCTAssertEqual(try b.perform(b.prepare(.init("showWindow",[0,5]))).response.result,0)
        withExtendedLifetime(served) {}
    }
    func firstWindow(_ driver: Driver,_ controls: Controls) throws -> E.Permit {
        for _ in 0..<10 {
            switch try driver.resume() {
            case .request(let p):
                if case .window = p.request { return p }
                try driver.answer(p,response:controls.answer(p.request))
            case .started:throw Stop.missingOutcome
            }
        }
        throw Stop.missingOutcome
    }
    func testPhysicalServiceRejectsForeignDuplicateAndCancelledPermits() throws {
        let (driver,service,controls) = try setup(),(foreign,_,other) = try setup()
        let permit = try firstWindow(driver,controls),alien = try firstWindow(foreign,other)
        XCTAssertThrowsError(try service.serve(alien)) { XCTAssertEqual($0 as? E.Boundary,.foreignOwner) }
        XCTAssertTrue(service.backend.operations.isEmpty)
        try driver.beginService(permit); XCTAssertTrue(driver.exchangeSnapshot.serviceStarted)
        XCTAssertThrowsError(try service.serve(permit)) { XCTAssertEqual($0 as? E.Boundary,.serviceAlreadyStarted) }
        XCTAssertTrue(service.backend.operations.isEmpty)
        try driver.cancel()
        XCTAssertThrowsError(try service.serve(permit)) { XCTAssertEqual($0 as? E.Boundary,.closed(.cancelled)) }
        XCTAssertTrue(service.backend.operations.isEmpty)
        try driver.answer(permit,response:.window(.init(result:0)))
        XCTAssertEqual(driver.exchangeSnapshot.status,.cancelled); XCTAssertFalse(driver.exchangeSnapshot.serviceStarted)
        try foreign.cancel()
        XCTAssertThrowsError(try foreign.beginService(alien)) { XCTAssertEqual($0 as? E.Boundary,.closed(.cancelled)) }
        try foreign.fail(alien,diagnostic:"declared unavailable outcome")
        XCTAssertEqual(foreign.exchangeSnapshot.status,.indeterminate)
        XCTAssertEqual(foreign.exchangeSnapshot.failure?.afterCancellation,true)
    }
    func testStartupLateFailureAndWindowDestruction() throws {
        weak var retained: Backend.WindowLease?
        func context() throws -> Driver.Host.DeliveryContext {
            let run = try run(late:true)
            retained = try run.service.backend.lease(run.controls.window)
            let context = try XCTUnwrap(run.host.takeCommitted()).context
            XCTAssertEqual(run.service.backend.createdWindowCount,1)
            try close(run)
            XCTAssertNotNil(retained)
            return context
        }
        var saved: Driver.Host.DeliveryContext? = try context()
        XCTAssertNotNil(retained)
        XCTAssertNotNil(try XCTUnwrap(saved).platformSnapshot().startupExchange)
        saved = nil; XCTAssertNil(retained)
    }
}
