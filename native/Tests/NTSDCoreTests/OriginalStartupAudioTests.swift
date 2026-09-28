import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

// These witnesses forward the new path. Old Audit instances keep observesAudio=false.
extension OriginalApplicationPreparedStartupPlatformTests.Audit {
    var observesAudio: Bool { native.observesAudio }
    func soundRequest(_ event: OriginalMenuSoundStartup.Event) throws -> OriginalSoundResponse {
        try native.soundRequest(event)
    }
    func waveInput(_ i: Int,_ path: String,_ destination: UInt32,_ device: UInt32) throws -> OriginalWaveInput {
        let r = try native.waveInput(i,path,destination,device)
        XCTAssertEqual(r,try OriginalWaveInput(legacy:audit.wave(i,path,destination,device)));return r
    }
    func waveRequest(_ binding: OriginalWaveBinding,_ q: OriginalWaveRequest) throws -> OriginalWaveResponse {
        try native.waveRequest(binding,q)
    }
}

final class OriginalStartupAudioTests: XCTestCase {
    typealias N = OriginalApplicationPreparedStartupPlatform
    typealias Old = OriginalApplicationPreparedStartupPlatformTests
    typealias Observed = OriginalApplicationObservedStartupTests
    typealias Audit = Old.Audit
    typealias P = OriginalWinMainStartupTests
    typealias B = OriginalApplicationBootstrapTests
    typealias D = OriginalApplicationHostDeliveryContextTests
    typealias E = OriginalStartupRequestExchange
    typealias Driver = OriginalApplicationObservedStartup<Audit>
    typealias Host = Driver.Host
    typealias Op = OriginalApplicationStartupOperation
    enum Stop: Error { case missingOutcome }
    final class Resource: OriginalApplicationStartupResource {}
    final class AudioOwner: OriginalApplicationStartupResource {
        var regions: [Int:[UInt32:OriginalStateRecord]] = [:]
        var copyWrites = 0
    }
    func audited(_ p: P.Adapter,_ package: OriginalApplicationStartupInputs) throws -> Audit {
        let checked = try Old().audited(p,package),full = try Old().preparation(p)
        var inputs = Observed.constants(full)
        inputs.observesAudio = true
        // Deliberately contradictory unused aggregate: actual sound replies win.
        inputs.sound = .init(createResult:123,createdDevice:0xdeadbeef,cooperativeResult:-123,messageResult:123)
        inputs.waveInputs = try full.waves.map {
            try .init(.init($0.request.index,$0.request.path,$0.request.destination,$0.request.device),OriginalWaveInput(legacy:$0.value))
        }
        return Audit(N(inputs:checked.native.inputs,prepared:inputs),p)
    }
    final class Service {
        let values: N, full: N.Prepared
        let windows: [OriginalWindowInitialization.Response]
        let owner = AudioOwner()
        var waves: [Int:OriginalWaveLegacyReplies] = [:]
        var audio: [Op] = []
        var windowIndex = 0, calls = 0
        init(_ p: P.Adapter,_ package: OriginalApplicationStartupInputs) throws {
            full = try Old().preparation(p)
            var other = full;other.waves = []
            values = N(inputs:package,prepared:other)
            windows = try p.c.events.filter { $0.kind == "window" }.map { try XCTUnwrap($0.event?.response) }
            for w in full.waves { waves[w.request.index] = try OriginalWaveLegacyReplies(w.value) }
        }
        func wave(_ binding: OriginalWaveBinding) throws -> OriginalWavePlatform {
            let w = try XCTUnwrap(full.waves.first { $0.request.index == binding.index })
            XCTAssertEqual(binding,.init(w.request.index,w.request.path,w.request.destination,w.request.device));return w.value
        }
        func project(_ ops: [Op]) throws -> [Op] {
            try ops.map { operation in
                switch operation {
                case .soundReply(let q,_):return .sound(q,full.sound)
                case .waveReply(let binding,let q,_):return .wave(q.event,try wave(binding))
                case .wavePrepared(let binding,let q,let input):
                    let p = try wave(binding);XCTAssertEqual(input,try OriginalWaveInput(legacy:p));return .wave(q,p)
                default:return operation
                }
            }
        }
        func verifyReceipts(_ snapshot: E.Snapshot) throws {
            let operations: [Op] = snapshot.receipts.compactMap { r in
                switch (r.request,r.response) {
                case (.sound(let q),.sound(let a)):return .soundReply(q,a)
                case (.waveAudio(let b,let q),.waveAudio(let a)):return .waveReply(b,q,a)
                default:return nil
                }
            }
            XCTAssertEqual(try D().encoded(operations),try D().encoded(audio))
            XCTAssertEqual(owner.copyWrites,operations.filter { if case .waveReply(_,let q,_) = $0 { return q.event.kind == .copy };return false }.count)
            for receipt in snapshot.receipts { XCTAssertTrue(receipt.resources.contains { $0 === owner }) }
        }
        func verify(_ snapshot: E.Snapshot,_ ops: [Op],_ startup: OriginalWinMainStartup) throws {
            try verifyReceipts(snapshot)
            let replies = ops.filter { switch $0 { case .soundReply,.waveReply:return true;default:return false } }
            XCTAssertEqual(try D().encoded(replies),try D().encoded(audio))
            for (i,load) in (startup.input?.sounds.loads ?? []).enumerated() {
                let expectedInput = try XCTUnwrap(waves[i]).input
                XCTAssertEqual(load.initialStorage,expectedInput.storage)
                let requests: [(OriginalWaveRequest,OriginalWaveResponse)] = audio.compactMap {
                    if case .waveReply(let b,let q,let r) = $0,b.index == i { return (q,r) };return nil
                }
                let locks = requests.filter { $0.0.event.kind == .lock }.map { $0.1 }
                XCTAssertEqual(load.lockReplies,locks)
                if !load.regions.isEmpty {
                    XCTAssertEqual(load.regions,owner.regions[i])
                    let temporary = try XCTUnwrap(load.temporary)
                    for (q,_) in requests where q.event.kind == .copy {
                        let offset = Int(q.event.arguments[1]),count = Int(q.event.arguments[2])
                        XCTAssertEqual(q.bytes,Array(temporary.bytes[offset..<(offset+count)]))
                        XCTAssertEqual(q.defined,Array(temporary.defined[offset..<(offset+count)]))
                    }
                }
            }
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
            case .wave:throw Stop.missingOutcome
            case .sound(let q):
                let r = try OriginalSoundLegacyReplies.reply(full.sound,q)
                audio.append(.soundReply(q,r));return .sound(r)
            case .waveAudio(let binding,let q):
                try q.validate()
                let input = try wave(binding),reply = try XCTUnwrap(waves[binding.index]).reply(q)
                XCTAssertEqual(input.destination,binding.destination);XCTAssertEqual(input.device,binding.device)
                if case .locked(_,let lock?) = reply {
                    for region in [lock.first,lock.second].compactMap({ $0 }) {
                        owner.regions[binding.index,default:[:]][region.token] = try region.storage.record()
                    }
                }
                if q.event.kind == .copy {
                    let token = try XCTUnwrap(q.target),bytes = try XCTUnwrap(q.bytes),mask = try XCTUnwrap(q.defined)
                    let prior = try XCTUnwrap(owner.regions[binding.index]?[token])
                    guard bytes.count <= prior.bytes.count else { throw Stop.missingOutcome }
                    var raw = prior.bytes,known = prior.defined
                    raw.replaceSubrange(0..<bytes.count,with:bytes);known.replaceSubrange(0..<mask.count,with:mask)
                    owner.regions[binding.index,default:[:]][token] = try .init(bytes:raw,defined:known)
                    owner.copyWrites += 1
                }
                audio.append(.waveReply(binding,q,reply));return .waveAudio(reply)
            }
        }
    }

    func globals(_ session: Host.Session) throws -> OriginalStateRecord { try Old().globals(session) }
    func unchanged(_ driver: Driver,_ p: P.Adapter) throws { try Observed().unchanged(driver,p) }
    @discardableResult
    func drive(_ driver: Driver,_ p: P.Adapter,_ service: Service,
        prepare: (Audit) throws -> Void = { _ in },
        before: (OriginalWinMainStartup,Host.Session,Audit) throws -> Void = { _,_,_ in },
        failed: (Audit,Error) -> Void = { _,_ in },
        resources: () -> [any OriginalApplicationStartupResource] = { [] }) throws -> Host {
        for _ in 0..<1500 {
            switch try driver.resume(prepare:prepare,store:{ $0.audit.store($1,$2) },beforeCommit:before,failedAttempt:failed) {
            case .request(let permit):
                try unchanged(driver,p);XCTAssertEqual(permit.ordinal,service.calls)
                if case .waveAudio(_,let q) = permit.request { try q.validate() }
                try driver.beginService(permit)
                do {
                    let response = try service.answer(permit.request)
                    try driver.answer(permit,response:response,retaining:[service.owner]+resources())
                } catch {
                    try driver.fail(permit,diagnostic:String(describing:error),retaining:[service.owner]);throw error
                }
            case .started(let sequence,let host):
                XCTAssertEqual(sequence,1);XCTAssertEqual(driver.exchangeSnapshot.status,.finished)
                XCTAssertEqual(service.calls,driver.exchangeSnapshot.receipts.count)
                try service.values.validatePreparedConsumption();return host
            }
        }
        throw Stop.missingOutcome
    }
    func testPerCallWaveCorpusAndInitialCallerKeepAllBytesAndMasks() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource:"original-wave-loader",withExtension:"json",subdirectory:"Fixtures"))
        var copies = 0,bytes = 0
        let result = try WaveLoaderReference.compare(Data(contentsOf:url),audio:{ p in
            let replies = try OriginalWaveLegacyReplies(p)
            return { q in
                try q.validate()
                if q.event.kind == .copy {
                    copies += 1;bytes += try XCTUnwrap(q.bytes).count
                    XCTAssertTrue(try XCTUnwrap(q.defined).allSatisfy { $0 })
                }
                return try replies.reply(q)
            }
        })
        XCTAssertEqual(result.sources,409);XCTAssertEqual(result.cases,431)
        XCTAssertEqual(result.startupPasses,3);XCTAssertEqual(result.startupLoads,54)
        XCTAssertEqual(result.bytes,75_829_038);XCTAssertEqual(result.events,6982)
        XCTAssertEqual(result.restores,93);XCTAssertEqual(result.messages,13)
        XCTAssertEqual(result.leaks,2);XCTAssertEqual(result.invalidContinuations,2)
        XCTAssertGreaterThan(copies,400);XCTAssertGreaterThan(bytes,1_000_000)
    }
    func testPerCallMenuSoundCorpusKeepsWholeAndStoppedOutcomes() throws {
        try OriginalStartupAudioMenuCorpus().compareWholeMenuSoundStartupAgainstOriginal()
    }
    func testWholeWinMainAudioRequestsMatchSourceAndPreparedState() throws {
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
                XCTAssertEqual(try D().encoded(service.project(value.operations)),try D().encoded(expected.operations))
                XCTAssertEqual(value.graphics,expected.graphics)
                try service.verify(driver.exchangeSnapshot,value.operations,try XCTUnwrap(host.snapshot.startup))
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
            try service.verifyReceipts(driver.exchangeSnapshot)
            print("Observed startup case",whole+stops+unknown,"requests",service.calls,"windows",service.windowIndex)
            XCTAssertEqual(p.index,0); XCTAssertEqual(p.waves,0); XCTAssertNil(p.windowExchange)
        }
        XCTAssertEqual(corpus.cases.count,35); XCTAssertEqual(whole,23); XCTAssertEqual(stops,5); XCTAssertEqual(unknown,7)
        XCTAssertEqual(events,6325); XCTAssertEqual(waves,119); XCTAssertEqual(served,650)
        print("Observed startup:",whole,"whole",stops,"source stops",unknown,"provenance rejections",served,"once-served replies")
    }

    func testLateStartupAudioFailuresDoNotRepeatServedCopies() throws {
        let package = try OriginalApplicationStartupInputsTests.shared.get()
        for phase in ["fifthWave","publication-copy"] {
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
            let calls = service.calls,copyWrites = service.owner.copyWrites
            XCTAssertGreaterThan(copyWrites,0)
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
            let batch = try XCTUnwrap(host.takeCommitted())
            XCTAssertEqual(batch.sequence,1); XCTAssertNil(try host.takeCommitted())
            guard case .startup(let value) = batch.contents else { throw Stop.missingOutcome }
            try service.verify(driver.exchangeSnapshot,value.operations,try XCTUnwrap(host.snapshot.startup))
            XCTAssertEqual(service.owner.copyWrites,copyWrites)
            var reference = OriginalApplicationBootstrap(),referencePlatform = try p.stagedCopy()
            let expected = try reference.start(instance:0x400000,show:10,initial:initial,platform:&referencePlatform,
                store:{ $0.store($1,$2) },beforeCommit:{ owner,session,candidate in
                    try candidate.complete(owner,self.globals(session))
                })
            try B.sameStartup(XCTUnwrap(host.snapshot.startup),XCTUnwrap(reference.startup))
            B.same(try XCTUnwrap(host.snapshot.session),try XCTUnwrap(reference.session))
            XCTAssertEqual(try D().encoded(service.project(value.operations)),try D().encoded(expected.operations))
            XCTAssertEqual(value.graphics,expected.graphics)
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

    // Small declared Native controls. No claim of Windows reachability or audio.
    func testAudioProtocolAndLockRegionsKeepDistinctOutcomes() throws {
        let file = P.hex("524946462c00000057415645666d74201000000001000100401f0000401f00000100080064617461080000000a141e28323c4650")
        let prior = OriginalWaveStorage(first:.init(bytes:[201,202],defined:[false,true]),second:nil,ramp:false)
        func input(_ read: Int32 = 8,_ device: UInt32 = 7) -> OriginalWaveInput {
            .init(destination:0x1234,device:device,stream:8,descendResults:[0,0,0],formatReadResult:18,
                ascendResult:0,dataReadResult:read,closeResult:-99,storage:prior)
        }
        func region(_ token: UInt32,_ count: Int) -> OriginalWaveRegion {
            .init(token:token,storage:.init(bytes:Array(repeating:0xa5,count:count),defined:Array(repeating:false,count:count)))
        }
        let finalLock = OriginalWaveLock(firstPointer:20,firstCount:3,secondPointer:21,secondCount:5,
            first:region(20,3),second:region(21,5))
        let ignored = OriginalWaveLock(firstPointer:0,firstCount:-1,secondPointer:99,secondCount:99,first:nil,second:nil)
        var requests: [OriginalWaveRequest] = [],locks = 0
        let result = try OriginalWaveLoader.loadObserved(path:Array("control.wav".utf8),file:file,output:55,input:input(),request:{ q in
            requests.append(q)
            switch q.event.kind {
            case .create:return .created(0,9)
            case .lock:
                locks += 1
                return locks == 1 ? .locked(0x88780096,ignored) : .locked(0x80004005,finalLock)
            case .copy:return .copied
            case .restore,.unlock,.message:return .result(-17)
            default:throw Stop.missingOutcome
            }
        })
        XCTAssertEqual(result.initialStorage,prior);XCTAssertEqual(result.output,9);XCTAssertEqual(result.returned,1)
        XCTAssertEqual(result.lockReplies,[.locked(0x88780096,ignored),.locked(0x80004005,finalLock)])
        XCTAssertEqual(requests.map { $0.event.kind },[.create,.lock,.restore,.lock,.copy,.copy,.unlock])
        XCTAssertEqual(result.first.bytes,[10,20,30]);XCTAssertEqual(result.second?.bytes,[40,50,60,70,80])
        XCTAssertEqual(result.first.defined,[true,true,true]);XCTAssertEqual(result.second?.defined,Array(repeating:true,count:5))
        XCTAssertEqual(requests[4].target,20);XCTAssertEqual(requests[4].bytes,[10,20,30])
        XCTAssertEqual(requests[5].target,21);XCTAssertEqual(requests[5].bytes,[40,50,60,70,80])
        XCTAssertEqual(requests.last?.event.arguments,[9,20,3,21,5])
        XCTAssertEqual(result.regions.count,2);XCTAssertFalse(result.temporaryLive)
        func run(_ lock: OriginalWaveLock?,create: OriginalWaveResponse = .created(0,9),read: Int32 = 8,
            sink: (OriginalWaveRequest) -> Void = { _ in }) throws -> OriginalWaveLoadResult {
            try OriginalWaveLoader.loadObserved(path:Array("control.wav".utf8),file:file,output:55,input:input(read),request:{ q in
                sink(q)
                switch q.event.kind {
                case .create:return create
                case .lock:return .locked(0,lock)
                case .copy:return .copied
                case .message,.restore,.unlock:return .result(-13)
                default:throw Stop.missingOutcome
                }
            })
        }
        let alias = OriginalWaveLock(firstPointer:20,firstCount:3,secondPointer:20,secondCount:5,first:region(20,8),second:region(20,8))
        let same = try run(alias)
        XCTAssertEqual(same.regions.count,1);XCTAssertEqual(same.first,same.second)
        XCTAssertEqual(same.first.bytes,[40,50,60,70,80,0xa5,0xa5,0xa5])
        XCTAssertEqual(same.first.defined,[true,true,true,true,true,false,false,false])
        let conflict = OriginalWaveLock(firstPointer:20,firstCount:3,secondPointer:20,secondCount:5,
            first:region(20,8),second:.init(token:20,storage:.init(bytes:Array(repeating:0x44,count:8),defined:Array(repeating:false,count:8))))
        XCTAssertThrowsError(try run(conflict)) {
            guard case OriginalStateError.invalidStorage(let text) = $0 else { return XCTFail("Wrong alias boundary: \($0)") }
            XCTAssertEqual(text,"Wave loading: Conflicting Lock alias backing")
        }
        var zeroCopies: [OriginalWaveRequest] = []
        let zero = try run(.init(firstPointer:20,firstCount:8,secondPointer:21,secondCount:0,first:region(20,8),second:region(21,0)),sink:{ zeroCopies.append($0) })
        XCTAssertEqual(zero.second?.bytes,[]);XCTAssertEqual(zeroCopies.filter { $0.event.kind == .copy }.count,2)
        XCTAssertEqual(zeroCopies.last?.event.arguments,[9,20,8,21,0])
        let absent = try run(.init(firstPointer:20,firstCount:3,secondPointer:0,secondCount:5,first:region(20,3),second:nil))
        XCTAssertNil(absent.second);XCTAssertEqual(absent.first.bytes,[10,20,30])
        for lock: OriginalWaveLock? in [nil,ignored,.init(firstPointer:20,firstCount:3,secondPointer:21,secondCount:5,first:region(99,3),second:region(21,5))] {
            XCTAssertThrowsError(try run(lock))
        }
        var missing: [OriginalWaveEvent.Kind] = []
        XCTAssertThrowsError(try run(finalLock,create:.created(0,nil),sink:{ missing.append($0.event.kind) }))
        XCTAssertEqual(missing,[.create])
        XCTAssertThrowsError(try run(finalLock,create:.result(0)))
        let invalid = try run(finalLock,create:.created(1,9))
        XCTAssertEqual(invalid.exit,.invalidCreateContinuation);XCTAssertNil(invalid.returned);XCTAssertFalse(invalid.temporaryLive)
        XCTAssertEqual(invalid.initialStorage,prior);XCTAssertTrue(invalid.lockReplies.isEmpty)
        let short = try run(nil,read:3)
        XCTAssertEqual(short.returned,0);XCTAssertTrue(short.temporaryLive)
        XCTAssertEqual(short.temporary?.bytes,[10,20,30,0xa5,0xa5,0xa5,0xa5,0xa5])
        XCTAssertEqual(short.temporary?.defined,[true,true,true,false,false,false,false,false])
        let noDevice = try OriginalWaveLoader.loadObserved(path:[],file:[],output:55,input:input(8,0),request:{ _ in XCTFail("device0 audio IO");throw Stop.missingOutcome })
        XCTAssertEqual(noDevice.output,55);XCTAssertEqual(noDevice.returned,1);XCTAssertEqual(noDevice.first,try prior.first.record())
        var globals = try OriginalStateRecord(bytes:Array(repeating:0xa5,count:OriginalMatchPreparation.globalSize),defined:Array(repeating:true,count:OriginalMatchPreparation.globalSize))
        let saved = globals
        var stores: [UInt32] = [],soundEvents: [String] = []
        let ready = try OriginalMenuSoundStartup.initializeDevice(globals:&globals,window:6,request:{ q in
            soundEvents.append(q.kind);return .init(result:1,output:77)
        },store:{ _,v in stores.append(v) })
        XCTAssertFalse(ready);XCTAssertEqual(stores,[77,0]);XCTAssertEqual(soundEvents,["deviceCreate"])
        XCTAssertEqual(try globals.integer(at:0x44eecc-OriginalMatchPreparation.globalBase,as:UInt32.self),0)
        globals = saved
        XCTAssertThrowsError(try OriginalMenuSoundStartup.initializeDevice(globals:&globals,window:6,request:{ _ in .init(result:0) }))
        XCTAssertEqual(globals,saved)
        let copy = OriginalWaveRequest(.init(.copy,[0,0,3]),target:20,bytes:[10,20,30],defined:[true,true,true])
        try copy.validate()
        for q in [OriginalWaveRequest(.init(.copy,[0,0,3]),target:20),
                  OriginalWaveRequest(.init(.copy,[0,0,3]),target:0,bytes:[10,20,30],defined:[true,true,true]),
                  OriginalWaveRequest(.init(.lock,[]))] { XCTAssertThrowsError(try q.validate()) }
        let request = OriginalStartupRequest.waveAudio(.init(0,"control.wav",0x1234,7),copy)
        func ticket(_ e: E) throws -> E.RequestNeeded {
            var cursor = try e.snapshot.cursor()
            do { _ = try cursor.response(for:request);throw Stop.missingOutcome }
            catch let needed as E.RequestNeeded { return needed }
        }
        let exchange = E(),other = E(),needed = try ticket(exchange),permit = try exchange.claim(needed)
        XCTAssertThrowsError(try other.beginService(permit)) { XCTAssertEqual($0 as? E.Boundary,.foreignOwner) }
        XCTAssertThrowsError(try exchange.answer(permit,response:.sound(.init(result:0)))) { XCTAssertEqual($0 as? E.Boundary,.responseMismatch) }
        XCTAssertThrowsError(try exchange.answer(permit,response:.waveAudio(.result(0)))) { XCTAssertEqual($0 as? E.Boundary,.responseMismatch) }
        try exchange.beginService(permit)
        XCTAssertThrowsError(try exchange.beginService(permit)) { XCTAssertEqual($0 as? E.Boundary,.serviceAlreadyStarted) }
        try exchange.answer(permit,response:.waveAudio(.copied))
        XCTAssertThrowsError(try exchange.answer(permit,response:.waveAudio(.copied))) { XCTAssertEqual($0 as? E.Boundary,.invalidPermit) }
        XCTAssertThrowsError(try exchange.claim(needed)) { XCTAssertEqual($0 as? E.Boundary,.staleRevision) }
        var cursor = try exchange.snapshot.cursor()
        guard case .waveAudio(.copied) = try cursor.response(for:request) else { throw Stop.missingOutcome }
        XCTAssertEqual(try exchange.finish(cursor).status,.finished)
        let cancelled = E(),cancelPermit = try cancelled.claim(ticket(cancelled));cancelled.cancel()
        XCTAssertThrowsError(try cancelled.beginService(cancelPermit)) { XCTAssertEqual($0 as? E.Boundary,.closed(.cancelled)) }
        XCTAssertTrue(cancelled.snapshot.receipts.isEmpty)
        weak var retained: Resource?
        func late(_ failure: Bool) throws -> E.Snapshot {
            let e = E(),p = try e.claim(ticket(e)),owner = Resource();retained = owner
            try e.beginService(p);e.cancel()
            if failure { try e.fail(p,diagnostic:"controlled outcome unavailable",retaining:[owner]) }
            else { try e.answer(p,response:.waveAudio(.copied),retaining:[owner]) }
            return e.snapshot
        }
        for failure in [false,true] {
            var snapshot: E.Snapshot? = try late(failure)
            XCTAssertNotNil(retained)
            XCTAssertEqual(snapshot?.status,failure ? .indeterminate : .cancelled)
            if failure {
                XCTAssertEqual(snapshot?.failure?.diagnostic,"controlled outcome unavailable")
                XCTAssertEqual(snapshot?.failure?.afterCancellation,true);XCTAssertEqual(snapshot?.receipts.count,0)
            } else { XCTAssertEqual(snapshot?.receipts.count,1);XCTAssertNil(snapshot?.failure) }
            snapshot = nil;XCTAssertNil(retained)
        }
    }
}
