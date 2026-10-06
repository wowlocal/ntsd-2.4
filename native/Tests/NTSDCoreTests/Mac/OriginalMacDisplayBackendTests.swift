import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform
@testable import NTSDRuntime

@MainActor final class OriginalMacDisplayBackendTests: XCTestCase {
    typealias W = OriginalMacWindowBackendTests
    typealias Driver = W.Driver
    typealias Backend = OriginalMacDisplayBackend
    typealias Service = OriginalMacDisplayStartupService<W.N>
    typealias Request = OriginalWindowInitialization.Request
    typealias E = OriginalStartupRequestExchange
    struct Setup {
        let driver: Driver,window: W.Service,controls: W.Controls,display: Backend,service: Service
    }
    struct Run { let setup: Setup,host: Driver.Host }
    func setup(maximumBytes: Int = 256*1024*1024,rleHolesReadPaletteZero: Bool = false,freshSurfacesKnownBlack: Bool = false) throws -> Setup {
        let (driver,window,controls) = try W().setup()
        let display = Backend(windows:window.backend,maximumBytes:maximumBytes,freshSurfacesKnownBlack:freshSurfacesKnownBlack,
                              rleHolesReadPaletteZero:rleHolesReadPaletteZero)
        return .init(driver:driver,window:window,controls:controls,display:display,service:Service(driver:driver,backend:display))
    }
    func answer(_ permit: E.Permit,_ s: Setup) throws {
        XCTAssertEqual(permit.ordinal,s.controls.values.calls)
        if case .window(let q) = permit.request,Backend.handles(q) {
            let events = s.controls.source.c.events.filter { $0.kind == "window" }
            XCTAssertEqual(q.kind,try XCTUnwrap(events[s.controls.values.windowIndex].event?.request).kind)
            try s.service.serve(permit)
            s.controls.values.windowIndex += 1;s.controls.values.calls += 1
        } else { try W().service(permit,s.driver,s.window,s.controls) }
    }
    func run(late: Bool,rleHolesReadPaletteZero: Bool = false,freshSurfacesKnownBlack: Bool = false) throws -> Run {
        let s = try setup(rleHolesReadPaletteZero:rleHolesReadPaletteZero,freshSurfacesKnownBlack:freshSurfacesKnownBlack);var failed = false
        for _ in 0..<1000 {
            do {
                switch try s.driver.resume(beforeCommit:{ _,_,_ in if late && !failed { throw W.P.Trial.late } }) {
                case .request(let p):
                    XCTAssertNil(s.driver.snapshot.startup);XCTAssertEqual(s.driver.pendingBatchCount,0)
                    try answer(p,s)
                case .started(let sequence,let host):
                    XCTAssertEqual(sequence,1);XCTAssertEqual(failed,late)
                    try s.controls.values.values.validatePreparedConsumption()
                    XCTAssertEqual(s.controls.values.calls,s.driver.exchangeSnapshot.receipts.count)
                    return .init(setup:s,host:host)
                }
            } catch W.P.Trial.late {
                XCTAssertTrue(late);XCTAssertFalse(failed);failed = true
                XCTAssertNil(s.driver.snapshot.startup);XCTAssertEqual(s.driver.pendingBatchCount,0)
                XCTAssertEqual(s.display.allocationCount,4)
                XCTAssertTrue(try s.window.backend.observation(s.controls.window).visible)
            }
        }
        throw W.Stop.missingOutcome
    }
    func ids(_ run: Run) throws -> (UInt32,UInt32,UInt32,UInt32) {
        let g = try XCTUnwrap(run.host.snapshot.session).state.full
        return try (g.integer(at:0x457578-0x44d000,as:UInt32.self),g.integer(at:0x455634-0x44d000,as:UInt32.self),
                    g.integer(at:0x455608-0x44d000,as:UInt32.self),g.integer(at:0x457584-0x44d000,as:UInt32.self))
    }
    func close(_ run: Run) throws { try close(run.setup) }
    func close(_ s: Setup) throws {
        let b = s.window.backend
        XCTAssertEqual(try b.perform(b.prepare(.init("destroyWindow",[s.controls.window]))).response.result,1)
    }
    func clear(_ backend: Backend,_ token: UInt32,_ color: UInt32) throws -> Int32 {
        try OriginalSurfaceClearing.clear(target:token,color:color,backing:Array(repeating:0xa7,count:100)) { q in
            try backend.perform(backend.prepare(.init("blt",[q.target,0,0,0,q.flags],
                structure:OriginalStateRecord(bytes:q.effects,defined:q.defined)))).response.result
        }
    }
    func testWholeStartupUsesOwnedDisplaySurfacesAndClipper() throws {
        let r = try run(late:false);defer { try? close(r) }
        let s = r.setup,(draw,primary,back,clip) = try ids(r)
        XCTAssertEqual(Set([draw,primary,back,clip,s.controls.window]).count,5)
        XCTAssertEqual(s.display.allocationCount,4);XCTAssertEqual(s.window.backend.createdWindowCount,1)
        let d = try s.display.observation(draw),p = try s.display.observation(primary),b = try s.display.observation(back),c = try s.display.observation(clip)
        XCTAssertEqual(d.kind,.display);XCTAssertEqual(d.window,s.controls.window)
        XCTAssertEqual(p.kind,.primary);XCTAssertEqual(p.clipper,clip);XCTAssertEqual(c.window,s.controls.window)
        XCTAssertEqual(c.references,1);XCTAssertEqual(b.kind,.backbuffer)
        let screen = try s.window.backend.displayGeometry(s.controls.window).screen
        XCTAssertEqual(p.width,Int(screen.width));XCTAssertEqual(p.height,Int(screen.height))
        let client = try s.window.backend.observation(s.controls.window).client
        XCTAssertEqual(b.width,Int(client.width));XCTAssertEqual(b.height,Int(client.height))
        XCTAssertEqual(p.knownPixels,0);XCTAssertEqual(b.knownPixels,0)
        XCTAssertEqual(s.display.allocatedBytes,(p.width*p.height+b.width*b.height)*5)
        XCTAssertEqual(s.display.operations.map(\.request.kind),["directDrawCreate","cooperativeLevel","createSurface","createSurface","createClipper","clipperWindow","setClipper","release"])
        XCTAssertFalse(s.display.operations.contains { $0.request.kind == "blt" || $0.request.kind == "pixelFormat" })
        let batch = try XCTUnwrap(r.host.takeCommitted())
        guard case .startup(let output) = batch.contents else { throw W.Stop.missingOutcome }
        let requests = output.operations.compactMap { if case .window(let q,_) = $0 { return q };return nil }
        XCTAssertEqual(requests.filter(Backend.handles),s.display.operations.map(\.request))
        XCTAssertEqual(try batch.context.platformSnapshot().startupExchange?.position,s.driver.exchangeSnapshot.receipts.count)
        print("Physical display whole startup",d,p,b,c,"allocated bytes",s.display.allocatedBytes)
    }
    func testWholeClearMasksPixelsAndAppKitViewReadback() throws {
        let r = try run(late:false);defer { try? close(r) }
        let s = r.setup,(_,primary,back,_) = try ids(r)
        XCTAssertThrowsError(try s.display.image(back)) { XCTAssertEqual($0 as? Backend.Boundary,.unknownPixel) }
        let before = try s.display.pixels(back);XCTAssertTrue(before.defined.allSatisfy { !$0 })
        for color: UInt32 in [0,1,0xff,0xff0000,0xff00,0x123456,0xffabcdef] {
            XCTAssertEqual(try clear(s.display,back,color),0)
            let pixels = try s.display.pixels(back)
            XCTAssertEqual(pixels.values.count,pixels.width*pixels.height)
            XCTAssertTrue(pixels.defined.allSatisfy { $0 });XCTAssertTrue(pixels.values.allSatisfy { $0 == color })
        }
        XCTAssertTrue(before.defined.allSatisfy { !$0 })
        let image = try s.display.image(back)
        XCTAssertEqual(image.bitsPerPixel,32);XCTAssertEqual(image.bitsPerComponent,8);XCTAssertEqual(image.alphaInfo,.noneSkipFirst)
        var format = try OriginalStateRecord(bytes:Array(repeating:0xa7,count:32),defined:Array(repeating:false,count:32));try format.write(UInt32(32),at:0)
        let f = try s.display.perform(s.display.prepare(.init("pixelFormat",[back],structure:format)))
        let formatRecord = try OriginalStateRecord(bytes:XCTUnwrap(f.response.bytes),defined:Array(repeating:true,count:32))
        XCTAssertEqual(try formatRecord.integer(at:12,as:UInt32.self),32)
        XCTAssertEqual(try formatRecord.integer(at:16,as:UInt32.self),0xff0000)
        XCTAssertEqual(try formatRecord.integer(at:20,as:UInt32.self),0xff00)
        XCTAssertEqual(try formatRecord.integer(at:24,as:UInt32.self),0xff)
        XCTAssertEqual(try clear(s.display,primary,0x00336699),0)
        let p = try s.display.pixels(primary),rect = try s.window.backend.displayGeometry(s.controls.window).clientInDesktop
        for y in 0..<p.height { for x in 0..<p.width {
            let inside = x >= Int(rect.minX) && x < Int(rect.maxX) && y >= Int(rect.minY) && y < Int(rect.maxY)
            XCTAssertEqual(p.defined[y*p.width+x],inside)
            if inside { XCTAssertEqual(p.values[y*p.width+x],0x00336699) }
        } }
        let view = try s.window.backend.captureView(s.controls.window)
        for point in [(1,1),(view.pixelsWide/2,view.pixelsHigh/2),(view.pixelsWide-2,view.pixelsHigh-2)] {
            let color = try XCTUnwrap(view.colorAt(x:point.0,y:point.1)?.usingColorSpace(.sRGB))
            XCTAssertEqual(color.redComponent,0.2,accuracy:2.0/255)
            XCTAssertEqual(color.greenComponent,0.4,accuracy:2.0/255)
            XCTAssertEqual(color.blueComponent,0.6,accuracy:2.0/255)
        }
        print("Physical primary clear and AppKit view",rect,"view pixels",view.pixelsWide,view.pixelsHigh,"XRGB",0x00336699)
    }
    func firstDisplay(_ s: Setup) throws -> E.Permit {
        for _ in 0..<100 {
            switch try s.driver.resume() {
            case .request(let p):
                if case .window(let q) = p.request,Backend.handles(q) { return p }
                try answer(p,s)
            case .started:throw W.Stop.missingOutcome
            }
        }
        throw W.Stop.missingOutcome
    }
    func testProtocolUnknownAndAllocationBoundaries() throws {
        let s = try setup(),other = try setup()
        let p = try firstDisplay(s),foreign = try firstDisplay(other)
        defer {
            do { try close(s);try close(other) }
            catch { XCTFail("Physical protocol-window cleanup: \(error)") }
        }
        XCTAssertThrowsError(try s.service.serve(foreign)) { XCTAssertEqual($0 as? E.Boundary,.foreignOwner) }
        XCTAssertEqual(s.display.allocationCount,0)
        try s.driver.beginService(p)
        XCTAssertThrowsError(try s.service.serve(p)) { XCTAssertEqual($0 as? E.Boundary,.serviceAlreadyStarted) }
        try s.driver.cancel()
        XCTAssertThrowsError(try s.service.serve(p)) { XCTAssertEqual($0 as? E.Boundary,.closed(.cancelled)) }
        try s.driver.fail(p,diagnostic:"declared cancellation control, no physical service performed")
        XCTAssertEqual(s.display.allocationCount,0);XCTAssertTrue(s.display.operations.isEmpty)
        try other.driver.cancel();try other.driver.fail(foreign,diagnostic:"foreign-owner control cleanup")
        let q = Request("directDrawCreate",[0,0x457578,0]),prepared = try s.display.prepare(q)
        XCTAssertThrowsError(try other.display.perform(prepared)) { XCTAssertEqual($0 as? Backend.Boundary,.foreignPreparation) }
        let served = try s.display.perform(prepared)
        XCTAssertThrowsError(try s.display.perform(prepared)) { XCTAssertEqual($0 as? Backend.Boundary,.repeatedPreparation) }
        XCTAssertThrowsError(try s.display.prepare(.init("release",[UInt32.max]))) { XCTAssertEqual($0 as? Backend.Boundary,.owner(UInt32.max)) }
        XCTAssertThrowsError(try s.display.prepare(.init("displayMode",[1,640,480,8])))
        withExtendedLifetime(served) {}
        let bounded = try setup(maximumBytes:0)
        let firstPermit = try firstDisplay(bounded)
        defer { do { try close(bounded) } catch { XCTFail("Bounded window cleanup: \(error)") } }
        try answer(firstPermit,bounded)
        var failed = false
        for _ in 0..<10 {
            guard case .request(let permit) = try bounded.driver.resume() else { throw W.Stop.missingOutcome }
            do { try answer(permit,bounded) }
            catch Backend.Boundary.allocationBudget { failed = true;break }
        }
        XCTAssertTrue(failed);XCTAssertEqual(bounded.driver.exchangeSnapshot.status,.indeterminate)
        XCTAssertEqual(bounded.display.allocationCount,1);XCTAssertEqual(bounded.display.allocatedBytes,0)
        XCTAssertNil(bounded.driver.snapshot.startup);XCTAssertEqual(bounded.driver.pendingBatchCount,0)
        XCTAssertFalse(try XCTUnwrap(bounded.driver.exchangeSnapshot.failure).resources.isEmpty)
        XCTAssertThrowsError(try bounded.driver.resume())
    }
    func testLateRetryReleaseAndContextOwnership() throws {
        weak var retained: Backend.Resource?
        func context() throws -> Driver.Host.DeliveryContext {
            let r = try run(late:true),s = r.setup,(draw,primary,back,clip) = try ids(r)
            XCTAssertEqual(s.display.allocationCount,4)
            retained = try s.display.lease(back)
            let context = try XCTUnwrap(r.host.takeCommitted()).context
            XCTAssertEqual(try s.display.observation(clip).references,1)
            XCTAssertEqual(try s.display.perform(s.display.prepare(.init("release",[back]))).response.result,0)
            XCTAssertEqual(try s.display.observation(back).references,0)
            XCTAssertThrowsError(try s.display.pixels(back)) { XCTAssertEqual($0 as? Backend.Boundary,.released(back)) }
            XCTAssertThrowsError(try s.display.prepare(.init("release",[back])))
            XCTAssertEqual(try s.display.perform(s.display.prepare(.init("release",[primary]))).response.result,0)
            XCTAssertEqual(try s.display.observation(clip).references,0)
            XCTAssertEqual(try s.display.perform(s.display.prepare(.init("release",[draw]))).response.result,0)
            XCTAssertEqual(s.display.allocatedBytes,0);XCTAssertNotNil(retained)
            try close(r);return context
        }
        var saved: Driver.Host.DeliveryContext? = try context()
        XCTAssertNotNil(retained);XCTAssertNotNil(try XCTUnwrap(saved).platformSnapshot().startupExchange)
        saved = nil;XCTAssertNil(retained)
    }
}
