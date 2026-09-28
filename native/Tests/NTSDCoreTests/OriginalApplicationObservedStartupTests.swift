import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

extension OriginalApplicationPreparedStartupPlatformTests.Audit: OriginalApplicationObservedStartupPlatform {
    var startupExchange: OriginalStartupRequestExchange.Cursor? {
        get { native.startupExchange }
        set { native.startupExchange = newValue }
    }
}

final class OriginalApplicationObservedStartupTests: XCTestCase {
    typealias N = OriginalApplicationPreparedStartupPlatform
    typealias Old = OriginalApplicationPreparedStartupPlatformTests
    typealias Audit = Old.Audit
    typealias P = OriginalWinMainStartupTests
    typealias B = OriginalApplicationBootstrapTests
    typealias D = OriginalApplicationHostDeliveryContextTests
    typealias E = OriginalStartupRequestExchange
    typealias Driver = OriginalApplicationObservedStartup<Audit>
    typealias Host = Driver.Host
    enum Stop: Error { case missingOutcome }
    final class Resource: OriginalApplicationStartupResource {}

    static func constants(_ full: N.Prepared) -> N.Prepared {
        var inputs = N.Prepared(panelIO:full.panelIO,environmentTZ:full.environmentTZ,sound:full.sound)
        inputs.files = full.files; inputs.resources = full.resources; return inputs
    }
    func audited(_ p: P.Adapter,_ package: OriginalApplicationStartupInputs) throws -> Audit {
        // Retain the old package/input hash check; Native only receives constants.
        let checked = try Old().audited(p,package)
        return Audit(N(inputs:checked.native.inputs,prepared:Self.constants(try Old().preparation(p))),p)
    }
    /// Explicit controlled API response service, outside Core. It never supplies
    /// expected state, and all keyed responses are checked by the production provider.
    final class Service {
        let values: N
        let windows: [OriginalWindowInitialization.Response]
        var windowIndex = 0, calls = 0
        init(_ p: P.Adapter,_ package: OriginalApplicationStartupInputs) throws {
            values = N(inputs:package,prepared:try Old().preparation(p))
            windows = try p.c.events.filter { $0.kind == "window" }.map { try XCTUnwrap($0.event?.response) }
        }
        func answer(_ q: OriginalStartupRequest) throws -> OriginalStartupResponse {
            calls += 1
            switch q {
            case .milliseconds:return .milliseconds(try values.milliseconds())
            case .initializeCriticalSection(let a):return .initializeCriticalSection(try values.initializeCriticalSection(a))
            case .initializeCOM:return .initializeCOM(try values.initializeCOM())
            case .window:
                guard windows.indices.contains(windowIndex) else { throw Stop.missingOutcome }
                defer { windowIndex += 1 }; return .window(windows[windowIndex])
            case .panelWrite(let b):return .panelWrite(try values.writePanel(b))
            case .panelClose:return .panelClose(try values.closePanel())
            case .allocatePanel:return .allocatePanel(try values.allocatePanel())
            case .panelBitmap(let path):return .panelBitmap(try values.panelBitmap(path))
            case .panelDevice:
                let v = try values.panelDevice(); return .panelDevice(.init(v.surface,v.colorKeyResult))
            case .filetime:return .filetime(try values.filetime())
            case .timezone:
                let v = try values.timezone(); return .timezone(.init(v.result,v.zone))
            case .allocateCalendar(let n):return .allocateCalendar(try values.allocateCalendar(n))
            case .zoneName(let s,let n):return .zoneName(try values.convertZoneName(s,n))
            case .music(let e):return .music(try values.music(e))
            case .cursor(let load,let args):return .cursor(try values.cursor(load,args))
            case .joystick(let q):return .joystick(try values.joystick(q,values.inputs.initial))
            case .wave(let w):return .wave(try values.wave(w.index,w.path,w.destination,w.device))
            case .sound,.waveAudio:throw Stop.missingOutcome // This legacy helper never serves the new audio path.
            }
        }
    }
    func globals(_ session: Host.Session) throws -> OriginalStateRecord { try Old().globals(session) }
    func unchanged(_ driver: Driver,_ p: P.Adapter) throws {
        XCTAssertNil(driver.snapshot.startup); XCTAssertNil(driver.snapshot.session); XCTAssertEqual(driver.pendingBatchCount,0)
        let saved = try driver.platformSnapshot()
        XCTAssertEqual(saved.audit.index,0); XCTAssertEqual(saved.audit.shadow,p.shadow)
        XCTAssertEqual(saved.native.snapshot,N.Snapshot()); XCTAssertNil(saved.startupExchange)
    }
    @discardableResult
    func drive(_ driver: Driver,_ p: P.Adapter,_ service: Service,
        prepare: (Audit) throws -> Void = { _ in },
        before: (OriginalWinMainStartup,Host.Session,Audit) throws -> Void = { _,_,_ in },
        failed: (Audit,Error) -> Void = { _,_ in },
        resources: () -> [any OriginalApplicationStartupResource] = { [] }) throws -> Host {
        for _ in 0..<1000 {
            switch try driver.resume(prepare:prepare,store:{ $0.audit.store($1,$2) },beforeCommit:before,failedAttempt:failed) {
            case .request(let permit):
                try unchanged(driver,p)
                XCTAssertEqual(permit.ordinal,service.calls)
                let response = try service.answer(permit.request)
                try driver.answer(permit,response:response,retaining:resources())
            case .started(let sequence,let host):
                XCTAssertEqual(sequence,1); XCTAssertEqual(driver.exchangeSnapshot.status,.finished)
                XCTAssertEqual(service.calls,driver.exchangeSnapshot.receipts.count)
                try service.values.validatePreparedConsumption(); return host
            }
        }
        throw Stop.missingOutcome
    }
    func testWholeWinMainWithObservedRequests() throws {
        let (corpus,raw) = try P().read(), package = try OriginalApplicationStartupInputsTests.shared.get()
        var cache: [String:[UInt8]] = [:]
        func blob(_ h: String) throws -> [UInt8] {
            if let value = cache[h] { return value }
            let b = try XCTUnwrap(corpus.blobs[h])
            let value = try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:10_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(value)),h); cache[h] = value; return value
        }
        XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.dllSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        let sources = Dictionary(uniqueKeysWithValues:corpus.sources.map { ($0.path,$0.sha256) })
        var whole = 0,stops = 0,unknown = 0,events = 0,waves = 0,served = 0
        for (c,r) in zip(corpus.cases,raw) {
            var before = try OriginalStateRecord(bytes:blob(c.initialGlobals),defined:[Bool](repeating:true,count:0xb440))
            for w in c.stimulus { for (i,b) in P.hex(w.bytes).enumerated() { try before.write(b,at:w.address-OriginalMatchPreparation.globalBase+i) } }
            XCTAssertEqual(before.bytes,try blob(c.beforeGlobals))
            var bytes = package.initial.bytes,mask = package.initial.defined
            bytes.replaceSubrange(0..<0xb440,with:before.bytes); mask.replaceSubrange(0..<0xb440,with:before.defined)
            let initial = try OriginalStateRecord(bytes:bytes,defined:mask)
            let p = try P.Adapter(c,r,sources:sources,blob:blob,initial:before.bytes)
            let driver = try Driver(platform:audited(p,package),instance:c.spec.instance ?? 0x400000,show:c.spec.show ?? 10,initial:initial)
            try p.calendar(OriginalWinMainStartup().output.calendar,c.before)
            let service = try Service(p,package)
            var attempted: P.Adapter?
            do {
                let host = try drive(driver,p,service,before:{ owner,session,candidate in
                    try candidate.audit.complete(owner,self.globals(session)); try candidate.native.validatePreparedConsumption()
                },failed:{ candidate,_ in attempted = candidate.audit })
                let committed = try host.platformSnapshot(); attempted = committed.audit
                XCTAssertEqual(c.end,"startupBoundary"); XCTAssertEqual(c.endPC,0x43d100); XCTAssertEqual(c.endSP,0x1000effc)
                let batch = try XCTUnwrap(host.takeCommitted()); XCTAssertEqual(batch.sequence,1)
                XCTAssertNil(try host.takeCommitted())
                guard case .startup(let value) = batch.contents else { throw Stop.missingOutcome }
                var reference = OriginalApplicationBootstrap(), referencePlatform = try p.stagedCopy()
                let expected = try reference.start(instance:c.spec.instance ?? 0x400000,show:c.spec.show ?? 10,
                    initial:initial,platform:&referencePlatform,store:{ $0.store($1,$2) },beforeCommit:{ owner,session,candidate in
                        try candidate.complete(owner,self.globals(session))
                    })
                try B.sameStartup(XCTUnwrap(host.snapshot.startup),XCTUnwrap(reference.startup))
                B.same(try XCTUnwrap(host.snapshot.session),try XCTUnwrap(reference.session))
                B.same(try XCTUnwrap(batch.context.application.session),try XCTUnwrap(reference.session))
                XCTAssertEqual(try D().encoded(value.operations),try D().encoded(expected.operations))
                XCTAssertEqual(value.graphics,expected.graphics)
                let cursor = try XCTUnwrap(committed.startupExchange)
                XCTAssertEqual(cursor.position,driver.exchangeSnapshot.receipts.count); XCTAssertFalse(cursor.isSuspended)
                XCTAssertThrowsError(try driver.resume()) { XCTAssertEqual($0 as? E.Boundary,.closed(.finished)) }
                XCTAssertEqual(host.pendingBatchCount,0); whole += 1
            } catch let error as OriginalWinMainStartup.Boundary {
                let a = try XCTUnwrap(attempted)
                XCTAssertEqual(error,.unknownFullscreenCursor)
                let next = try XCTUnwrap(c.events[a.index].event),q = try XCTUnwrap(next.request)
                XCTAssertEqual(q.kind,"registerClass"); XCTAssertEqual(q.defined.map { Array($0[24..<28]) },[false,false,false,false])
                XCTAssertTrue(c.stackStores.prefix(try XCTUnwrap(next.stackStoreCount)).allSatisfy {
                    $0.address >= 0x1000efd8+4 || $0.address+P.hex($0.bytes).count <= 0x1000efd8
                })
                a.compareStores(count:try XCTUnwrap(next.globalStoreCount)); unknown += 1
                try unchanged(driver,p); try driver.cancel()
            } catch OriginalStateError.undefinedBytes(let offset,let length) {
                let a = try XCTUnwrap(attempted),b = try XCTUnwrap(c.panel.ownBoundary ?? c.input?.ownBoundary)
                XCTAssertEqual(offset,b.offset); XCTAssertEqual(length,b.count); XCTAssertEqual(a.index,b.rootEventCount)
                a.compareStores(count:b.globalStoreCount); XCTAssertEqual(a.shadow,try blob(b.rootGlobals)); unknown += 1
                try unchanged(driver,p); try driver.cancel()
            } catch let error as OriginalStartupOutput.Boundary {
                let a = try XCTUnwrap(attempted)
                XCTAssertEqual(c.end,"nullCalendarRead"); XCTAssertEqual(error,.nullCalendarRead(address:try XCTUnwrap(c.boundaryPC)))
                a.compareStores(count:c.globalStores.count); XCTAssertEqual(a.index,c.events.count); stops += 1
                try unchanged(driver,p); try driver.cancel()
            } catch let error as OriginalCalendarTime.Boundary {
                let a = try XCTUnwrap(attempted)
                XCTAssertEqual(c.end,"invalidParameter"); XCTAssertEqual(error,.invalidParameter)
                a.compareStores(count:c.globalStores.count); XCTAssertEqual(a.index,c.events.count); stops += 1
                try unchanged(driver,p); try driver.cancel()
            } catch OriginalStateError.invalidStorage(let message) {
                let a = try XCTUnwrap(attempted)
                XCTAssertEqual(message,"Original menu wave reaches invalid CreateSoundBuffer continuation")
                XCTAssertEqual(c.end,"invalidCreateContinuation"); XCTAssertEqual(c.boundaryPC,0x40187a)
                a.compareStores(count:c.globalStores.count); XCTAssertEqual(a.index,c.events.count); stops += 1
                try unchanged(driver,p); try driver.cancel()
            }
            let a = try XCTUnwrap(attempted)
            XCTAssertEqual(c.controlWord,0x37f); events += a.index; waves += a.waves; served += service.windowIndex
            XCTAssertEqual(service.calls,driver.exchangeSnapshot.receipts.count)
            print("Observed startup case",whole+stops+unknown,"requests",service.calls,"windows",service.windowIndex)
            XCTAssertEqual(p.index,0); XCTAssertEqual(p.waves,0); XCTAssertNil(p.windowExchange)
        }
        XCTAssertEqual(corpus.cases.count,35); XCTAssertEqual(whole,23); XCTAssertEqual(stops,5); XCTAssertEqual(unknown,7)
        XCTAssertEqual(events,6325); XCTAssertEqual(waves,119); XCTAssertEqual(served,650)
        print("Observed startup:",whole,"whole",stops,"source stops",unknown,"provenance rejections",served,"once-served replies")
    }

    func testLateFailuresRetriesAndOwners() throws {
        let package = try OriginalApplicationStartupInputsTests.shared.get()
        for phase in ["window-return","panel-return","secondDate","output-return","fifthWave","after","publication-copy"] {
            let (p,initial) = try D().inputs(), service = try Service(p,package)
            let original = try audited(p,package)
            let driver = try Driver(platform:original,instance:0x400000,show:10,initial:initial)
            var reached = 0
            XCTAssertThrowsError(try drive(driver,p,service,prepare:{ $0.audit.fail = phase },before:{ owner,session,candidate in
                try candidate.audit.complete(owner,self.globals(session))
                if phase == "after" { throw P.Trial.late }
                if phase == "publication-copy" { candidate.failCopies = true }
            },failed:{ candidate,error in
                if error is P.Trial { reached += 1; XCTAssertGreaterThan(candidate.startupExchange?.position ?? 0,0) }
            })) { XCTAssertTrue($0 is P.Trial) }
            XCTAssertEqual(reached,1); try unchanged(driver,p)
            XCTAssertEqual(original.native.snapshot,N.Snapshot()); XCTAssertEqual(p.index,0)
            let prefix = driver.exchangeSnapshot.receipts.map(\.request)
            let calls = service.calls
            XCTAssertEqual(calls,prefix.count)
            let host = try drive(driver,p,service,before:{ owner,session,candidate in
                try candidate.audit.complete(owner,self.globals(session)); try candidate.native.validatePreparedConsumption()
            })
            XCTAssertEqual(Array(driver.exchangeSnapshot.receipts.prefix(calls).map(\.request)),prefix)
            XCTAssertEqual(driver.exchangeSnapshot.receipts.filter { $0.request == .milliseconds }.count,1)
            XCTAssertEqual(driver.exchangeSnapshot.receipts.filter { $0.request == .filetime }.count,1)
            let committed = try host.platformSnapshot(),copy = try committed.stagedCopy()
            XCTAssertFalse(copy.native === committed.native); XCTAssertEqual(copy.native.snapshot,committed.native.snapshot)
            XCTAssertEqual(copy.startupExchange?.position,committed.startupExchange?.position)
            var independent = try XCTUnwrap(copy.startupExchange)
            XCTAssertThrowsError(try independent.response(for:.milliseconds)) { XCTAssertTrue($0 is E.RequestNeeded) }
            XCTAssertTrue(independent.isSuspended); XCTAssertFalse(try XCTUnwrap(committed.startupExchange).isSuspended)
            XCTAssertEqual(try host.takeCommitted()?.sequence,1); XCTAssertNil(try host.takeCommitted())
        }
        let (p,initial) = try D().inputs()
        let driver = try Driver(platform:audited(p,package),instance:0x400000,show:10,initial:initial)
        XCTAssertThrowsError(try driver.resume(prepare:{ _ in throw P.Trial.late })) { XCTAssertTrue($0 is P.Trial) }
        try unchanged(driver,p); XCTAssertTrue(driver.exchangeSnapshot.receipts.isEmpty)
        weak var weakOwner: Resource?
        func retainedContext() throws -> Host.DeliveryContext {
            let (p,initial) = try D().inputs(),service = try Service(p,package)
            let owner = Resource(); weakOwner = owner
            let driver = try Driver(platform:audited(p,package),instance:0x400000,show:10,initial:initial)
            let host = try drive(driver,p,service,resources:{ [owner] })
            return try XCTUnwrap(host.takeCommitted()).context
        }
        var context: Host.DeliveryContext? = try retainedContext()
        XCTAssertNotNil(weakOwner)
        XCTAssertGreaterThan(try XCTUnwrap(context).platformSnapshot().startupExchange?.position ?? 0,0)
        context = nil; XCTAssertNil(weakOwner)
    }

    func testTypedRequestsAndProtocolBoundaries() throws {
        let package = try OriginalApplicationStartupInputsTests.shared.get()
        let base = N.Prepared(panelIO:.init(outputBacking:[0xa5]),environmentTZ:nil,
                              sound:.init(createResult:-1,createdDevice:nil))
        var values = base
        values.files["absent"] = .absent; values.files["empty"] = .bytes([])
        values.milliseconds = [7]; values.criticalSections = [.init(0x4554a4,[UInt8](repeating:0xa5,count:24))]
        values.com = [0x80004005]; values.panelWrites = [.init([8,9],-1)]; values.panelCloses = [-5]
        let allocation = OriginalInterfaceAllocation(address:0x28000000,backing:[1,2,3])
        values.panelAllocations = [allocation]
        values.panelBitmaps = [.init("image",.init(path:"image",present:false))]
        values.panelDevices = [.init(0,-6)]; values.filetimes = [9]; values.zones = [.init(UInt32.max,nil)]
        values.calendarAllocations = [.init(3,allocation)]
        values.zoneNames = [.init(.init("name",2),[1,0])]
        let music = OriginalMusicEvent(.method,[1,4],[[]])
        values.music = [.init(music,.init(result:-7,pointer:nil,bytes:nil))]
        values.cursors = [.init(.init(true,[0,0x7f00]),0)]
        let joy = OriginalInputStartup.Request("position",[1],information:[5])
        values.joysticks = [.init(joy,.init(result:167,writes:[.init(offset:1,bytes:[3])]))]
        let wave = OriginalWavePlatform(destination:4,device:0,stream:0,buffer:0,firstPointer:0,secondPointer:0,
            descendResults:[0,0,0],formatReadResult:0,ascendResult:0,dataReadResult:0,createResult:0,
            lockResults:[0,0],restoreResult:0,unlockResult:0,closeResult:0,firstCount:0,secondCount:0,ramp:false)
        values.waves = [.init(.init(0,"wave",4,0),wave)]
        let globals = package.initial
        let calls: [(N.Kind,(N) throws -> Void)] = [
            (.milliseconds,{ let r = try $0.milliseconds(); XCTAssertEqual(r,7) }),
            (.criticalSection,{ let r = try $0.initializeCriticalSection(0x4554a4); XCTAssertEqual(r,[UInt8](repeating:0xa5,count:24)) }),
            (.com,{ let r = try $0.initializeCOM(); XCTAssertEqual(r,0x80004005) }),
            (.panelWrite,{ let r = try $0.writePanel([8,9]); XCTAssertEqual(r,-1) }),
            (.panelClose,{ let r = try $0.closePanel(); XCTAssertEqual(r,-5) }),
            (.panelAllocation,{ let a = try $0.allocatePanel(); XCTAssertEqual(a.address,allocation.address); XCTAssertEqual(a.backing,allocation.backing) }),
            (.panelBitmap,{ let r = try $0.panelBitmap("image"); XCTAssertEqual(r,.init(path:"image",present:false)) }),
            (.panelDevice,{ let d = try $0.panelDevice(); XCTAssertEqual(d.surface,0); XCTAssertEqual(d.colorKeyResult,-6) }),
            (.filetime,{ let r = try $0.filetime(); XCTAssertEqual(r,9) }),
            (.timezone,{ let z = try $0.timezone(); XCTAssertEqual(z.result,UInt32.max); XCTAssertNil(z.zone) }),
            (.calendarAllocation,{ let r = try $0.allocateCalendar(3); XCTAssertEqual(r.backing,allocation.backing) }),
            (.zoneName,{ let r = try $0.convertZoneName("name",2); XCTAssertEqual(r,[1,0]) }),
            (.music,{ let r = try $0.music(music); XCTAssertEqual(r,.init(result:-7)) }),
            (.cursor,{ let r = try $0.cursor(true,[0,0x7f00]); XCTAssertEqual(r,0) }),
            (.joystick,{ try Old.same($0.joystick(joy,globals),OriginalInputStartup.Response(result:167,writes:[.init(offset:1,bytes:[3])])) }),
            (.wave,{ try Old.same($0.wave(0,"wave",4,0),wave) })]
        let requests: [OriginalStartupRequest] = [.milliseconds,.initializeCriticalSection(0x4554a4),.initializeCOM,
            .panelWrite([8,9]),.panelClose,.allocatePanel,.panelBitmap("image"),.panelDevice,.filetime,.timezone,
            .allocateCalendar(3),.zoneName("name",2),.music(music),.cursor(true,[0,0x7f00]),.joystick(joy),.wave(.init(0,"wave",4,0))]
        let replies: [OriginalStartupResponse] = [.milliseconds(7),.initializeCriticalSection([UInt8](repeating:0xa5,count:24)),
            .initializeCOM(0x80004005),.panelWrite(-1),.panelClose(-5),.allocatePanel(allocation),
            .panelBitmap(.init(path:"image",present:false)),.panelDevice(.init(0,-6)),.filetime(9),.timezone(.init(UInt32.max,nil)),
            .allocateCalendar(allocation),.zoneName([1,0]),.music(.init(result:-7)),.cursor(0),
            .joystick(.init(result:167,writes:[.init(offset:1,bytes:[3])])),.wave(wave)]
        let window = OriginalWindowInitialization.Request("metric",[7]),windowReply = OriginalWindowInitialization.Response(result:-1)
        let allRequests = requests+[.window(window)],allReplies = replies+[.window(windowReply)]
        let allCalls = calls.map { $0.1 } + [{ (p: N) throws -> Void in let r = try p.window(window); XCTAssertEqual(r,windowReply) }]
        XCTAssertEqual(allRequests.count,17); XCTAssertEqual(allReplies.count,allCalls.count)
        for i in allRequests.indices {
            let exchange = E(),native = N(inputs:package,prepared:base)
            native.startupExchange = try exchange.snapshot.cursor()
            var ticket: E.RequestNeeded?
            do { try allCalls[i](native); XCTFail("missing suspension") }
            catch let needed as E.RequestNeeded { ticket = needed }
            XCTAssertEqual(try XCTUnwrap(ticket).request,allRequests[i]); XCTAssertEqual(native.snapshot,N.Snapshot())
            let permit = try exchange.claim(XCTUnwrap(ticket))
            for j in allReplies.indices where i != j {
                XCTAssertFalse(allRequests[i].accepts(allReplies[j]))
                XCTAssertThrowsError(try exchange.answer(permit,response:allReplies[j])) {
                    XCTAssertEqual($0 as? E.Boundary,.responseMismatch)
                }
                XCTAssertEqual(exchange.snapshot.outstandingRequest,allRequests[i]); XCTAssertTrue(exchange.snapshot.receipts.isEmpty)
            }
            try exchange.answer(permit,response:allReplies[i])
            XCTAssertThrowsError(try exchange.answer(permit,response:allReplies[i])) { XCTAssertEqual($0 as? E.Boundary,.invalidPermit) }
            native.startupExchange = try exchange.snapshot.cursor()
            let copy = try native.stagedCopy()
            try allCalls[i](copy)
            XCTAssertEqual(native.startupExchange?.position,0); XCTAssertEqual(copy.startupExchange?.position,1)
            try copy.validatePreparedConsumption()
            XCTAssertThrowsError(try exchange.finish(XCTUnwrap(native.startupExchange))) { XCTAssertEqual($0 as? E.Boundary,.unconsumedReplies) }
            _ = try exchange.finish(XCTUnwrap(copy.startupExchange)); XCTAssertEqual(exchange.snapshot.status,.finished)
            XCTAssertThrowsError(try exchange.snapshot.cursor()) { XCTAssertEqual($0 as? E.Boundary,.closed(.finished)) }
        }
        func permit(_ e: E,_ q: OriginalStartupRequest) throws -> E.Permit {
            var cursor = try e.snapshot.cursor()
            do { _ = try cursor.response(for:q); throw Stop.missingOutcome }
            catch let ticket as E.RequestNeeded { return try e.claim(ticket) }
        }
        let e = E(),foreign = E(),q = try permit(e,.milliseconds),other = try permit(foreign,.filetime)
        XCTAssertThrowsError(try e.answer(other,response:.milliseconds(0))) { XCTAssertEqual($0 as? E.Boundary,.foreignOwner) }
        XCTAssertThrowsError(try e.snapshot.cursor()) { XCTAssertEqual($0 as? E.Boundary,.requestInFlight) }
        e.cancel(); try e.answer(q,response:.milliseconds(9))
        XCTAssertEqual(e.snapshot.status,.cancelled); XCTAssertEqual(e.snapshot.receipts.count,1)
        XCTAssertThrowsError(try e.snapshot.cursor()) { XCTAssertEqual($0 as? E.Boundary,.closed(.cancelled)) }
        foreign.cancel(); try foreign.fail(other,diagnostic:"physical result unavailable")
        XCTAssertEqual(foreign.snapshot.status,.indeterminate); XCTAssertEqual(foreign.snapshot.failure?.afterCancellation,true)
        XCTAssertTrue(foreign.snapshot.receipts.isEmpty)
        let ordered = E(),first = try permit(ordered,.panelWrite([1,2]))
        try ordered.answer(first,response:.panelWrite(-1))
        var wrong = try ordered.snapshot.cursor()
        XCTAssertThrowsError(try wrong.response(for:.panelWrite([2,1]))) { XCTAssertEqual($0 as? E.Boundary,.requestMismatch(0)) }
        XCTAssertEqual(wrong.position,0)
    }
    func testActualMacClocksAtWholeCallerBoundaries() throws {
        typealias Clock = OriginalMacStartupClock
        func sample(_ seconds: Int64,_ nanos: Int64 = 0) -> Clock.Sample { .init(seconds:seconds,nanoseconds:nanos) }
        // Fixed integer controls computed independently from Gregorian day counts
        // and the 100ns/32bit definitions; no host Date or floating-point calendar.
        XCTAssertEqual(try Clock.filetime(sample(-11_644_473_600)),0)
        XCTAssertEqual(try Clock.filetime(sample(0)),116_444_736_000_000_000)
        XCTAssertEqual(try Clock.filetime(sample(0,99)),116_444_736_000_000_000)
        XCTAssertEqual(try Clock.filetime(sample(0,100)),116_444_736_000_000_001)
        XCTAssertEqual(try Clock.filetime(sample(-1,999_999_999)),116_444_735_999_999_999)
        XCTAssertEqual(try Clock.filetime(sample(1_833_029_933_770,955_161_599)),UInt64.max)
        XCTAssertThrowsError(try Clock.filetime(sample(1_833_029_933_770,955_161_600))) { XCTAssertEqual($0 as? Clock.Boundary,.filetimeRange) }
        for value in [sample(-11_644_473_601),sample(Int64.max),sample(Int64.min)] {
            XCTAssertThrowsError(try Clock.filetime(value)) { XCTAssertEqual($0 as? Clock.Boundary,.filetimeRange) }
        }
        XCTAssertEqual(try Clock.milliseconds(sample(0,999_999)),0)
        XCTAssertEqual(try Clock.milliseconds(sample(4_294_967,295_999_999)),UInt32.max)
        XCTAssertEqual(try Clock.milliseconds(sample(4_294_967,296_000_000)),0)
        XCTAssertEqual(try Clock.milliseconds(sample(Int64.max,999_999_999)),UInt32.max)
        XCTAssertThrowsError(try Clock.milliseconds(sample(-1))) { XCTAssertEqual($0 as? Clock.Boundary,.negativeMonotonic) }
        for bad in [-1,1_000_000_000] {
            XCTAssertThrowsError(try Clock.filetime(sample(0,Int64(bad)))) { XCTAssertEqual($0 as? Clock.Boundary,.invalidNanoseconds) }
            XCTAssertThrowsError(try Clock.milliseconds(sample(0,Int64(bad)))) { XCTAssertEqual($0 as? Clock.Boundary,.invalidNanoseconds) }
        }
        XCTAssertThrowsError(try Clock.answer(.panelClose)) { XCTAssertEqual($0 as? Clock.Boundary,.unsupportedRequest) }
        let package = try OriginalApplicationStartupInputsTests.shared.get(),(p,initial) = try D().inputs()
        let native = N(inputs:package,prepared:Self.constants(try Old().preparation(p)))
        let driver = try OriginalApplicationObservedStartup(platform:native,instance:0x400000,show:10,initial:initial)
        let service = try Service(p,package)
        var milliseconds: UInt32?,filetime: UInt64?,windowCount = 0,clockReads = 0
        var attemptedClock: (UInt32,UInt64)?,reachedFailure = false
        var returned: OriginalApplicationHostSession<N>?
        for _ in 0..<1000 {
            do {
                let outcome = try driver.resume(beforeCommit:{ _,_,candidate in
                    let receipts = driver.exchangeSnapshot.receipts
                    XCTAssertEqual(receipts.filter { $0.request == .milliseconds }.count,1)
                    XCTAssertEqual(receipts.filter { $0.request == .filetime }.count,1)
                    let seed = try XCTUnwrap(milliseconds),time = try XCTUnwrap(filetime)
                    attemptedClock = (seed,time)
                    XCTAssertEqual(candidate.startupExchange?.position,receipts.count)
                    if !reachedFailure { throw P.Trial.late }
                })
                switch outcome {
                case .request(let permit):
                    XCTAssertNil(driver.snapshot.startup); XCTAssertNil(driver.snapshot.session)
                    XCTAssertEqual(driver.pendingBatchCount,0)
                    let reply: OriginalStartupResponse
                    switch permit.request {
                    case .milliseconds:
                        XCTAssertNil(milliseconds); XCTAssertEqual(windowCount,0); XCTAssertNil(filetime)
                        let before = try Clock.milliseconds(Clock.monotonicSample())
                        reply = try Clock.answer(permit.request)
                        let after = try Clock.milliseconds(Clock.monotonicSample())
                        guard case .milliseconds(let value) = reply else { throw Stop.missingOutcome }
                        XCTAssertLessThanOrEqual(value &- before,after &- before)
                        milliseconds = value; clockReads += 1
                    case .filetime:
                        XCTAssertNotNil(milliseconds); XCTAssertNil(filetime)
                        XCTAssertEqual(windowCount,service.windows.count)
                        let before = try Clock.filetime(Clock.realtimeSample())
                        reply = try Clock.answer(permit.request)
                        let after = try Clock.filetime(Clock.realtimeSample())
                        guard case .filetime(let value) = reply else { throw Stop.missingOutcome }
                        XCTAssertGreaterThanOrEqual(value,before); XCTAssertLessThanOrEqual(value,after)
                        filetime = value; clockReads += 1
                    default:
                        if case .window = permit.request { windowCount += 1; XCTAssertNil(filetime) }
                        reply = try service.answer(permit.request)
                    }
                    try driver.answer(permit,response:reply)
                case .started(_,let host):returned = host
                }
                if returned != nil { break }
            } catch P.Trial.late {
                XCTAssertFalse(reachedFailure); reachedFailure = true
                XCTAssertNil(driver.snapshot.startup); XCTAssertEqual(driver.pendingBatchCount,0)
                XCTAssertEqual(clockReads,2); XCTAssertNotNil(attemptedClock)
            }
        }
        let host = try XCTUnwrap(returned),batch = try XCTUnwrap(host.takeCommitted())
        XCTAssertTrue(reachedFailure); XCTAssertEqual(clockReads,2); XCTAssertEqual(windowCount,service.windows.count)
        guard case .startup(let startup) = batch.contents else { throw Stop.missingOutcome }
        let seeds = startup.operations.compactMap { if case .milliseconds(let v) = $0 { return v }; return nil }
        let times = startup.operations.compactMap { if case .filetime(let v) = $0 { return v }; return nil }
        XCTAssertEqual(seeds,[try XCTUnwrap(milliseconds)]); XCTAssertEqual(times,[try XCTUnwrap(filetime)])
        XCTAssertEqual(attemptedClock?.0,milliseconds); XCTAssertEqual(attemptedClock?.1,filetime)
        XCTAssertEqual(driver.exchangeSnapshot.status,.finished)
        print("Actual macOS clock observations",try XCTUnwrap(milliseconds),try XCTUnwrap(filetime),"windows before FILETIME",windowCount,"late retry retained both")
    }
}
