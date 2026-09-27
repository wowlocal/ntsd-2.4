import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform

@MainActor final class OriginalMacLoadingAudioTests: XCTestCase {
    typealias A = OriginalMacAudioBackendTests
    typealias B = OriginalMacAudioBackend
    typealias E = OriginalLoadingAudioExchange
    typealias C = OriginalApplicationCatalogSession
    typealias F = OriginalApplicationCatalogFullTests
    typealias M = OriginalApplicationLoadedMenuTests
    typealias P = OriginalApplicationPreparedStartupPlatform
    typealias Host = OriginalApplicationHostSession<P>
    typealias Driver = OriginalApplicationObservedLoadingAudio<P>
    typealias O = OriginalApplicationObservedBitmapTests
    typealias Q = OriginalApplicationMenuInputTests
    enum Stop: Error, Equatable { case bound, late, afterCommon }
    struct Ready {
        let startup: A.Startup, sounds: C.StartupSounds
        let files: [String:A.File], common: OriginalApplicationLoadingInputs
        var host: Host { startup.host }
    }
    func ready() throws -> Ready {
        let run = try A().startup(false)
        do {
            try A().verify(run)
            let host = run.host,package = try OriginalApplicationStartupInputsTests.shared.get()
            _ = try host.takeCommitted()
            let packets = try O().packets(run.window,package)
            for p in packets where !p.dispatch { try O().previous(host,p);_ = try host.takeCommitted() }
            let packet = try XCTUnwrap(packets.first { $0.dispatch })
            let service = OriginalMacBitmapService(backend:run.display,inputs:.init(resources:package.bitmaps,
                files:Dictionary(uniqueKeysWithValues:package.bitmaps.keys.map { ($0,BitsFile.missing) })))
            let bitmap = OriginalApplicationObservedBitmapIteration<P>(host:host)
            var finished = false
            for _ in 0..<1200 {
                switch try bitmap.resume(prepare:{ _,_ in packet.host }) {
                case .request(let permit):try service.serve(permit,on:bitmap)
                case .advanced(let outcome):
                    guard case .committed = outcome else { throw Stop.bound }
                    _ = try host.takeCommitted();finished = true
                }
                if finished { break }
            }
            guard finished else { throw Stop.bound }
            // Replay only saved input/API stimuli, bound to the actual window.
            // No captured global/record after-state enters this Native Host.
            let fr = try Q.F.Resources(),body = try Q.Body.Resources(fr),mr = try Q.M.Resources(body,fr),qr = try Q.Resources(mr)
            XCTAssertEqual(qr.indices[47],0)
            let input = qr.c.cases[47],spec = input.spec
            let responses = OriginalApplicationMenuSession.Responses(draw:spec.drawResult,presentation:spec.presentResult,
                sound:spec.soundResult,release:spec.releaseResult,dcResult:spec.dcResult,dc:0x12345678)
            let kinds: Set<String> = ["peek","get","translate","dispatchMessage","time","sleep"]
            var offset = 0
            for step in input.iterations {
                let events = input.events[offset..<step.eventEnd];offset = step.eventEnd
                let queue = try events.filter { $0.kind == "queue" && kinds.contains($0.request?.kind ?? "") }.map { event -> Q.Loop.Response in
                    if let response = event.response {
                        let writes = response.writes.map { write -> Q.Loop.Write in
                            var bytes = write.bytes
                            if event.request?.kind == "get" || event.request?.kind == "peek" {
                                for i in bytes.indices where (0..<4).contains(write.offset+i) {
                                    bytes[i] = UInt8(truncatingIfNeeded:run.window >> ((write.offset+i)*8))
                                }
                            }
                            return .init(offset:write.offset,bytes:bytes)
                        }
                        return .init(result:response.result,writes:writes)
                    }
                    let kind = try XCTUnwrap(event.request).kind
                    guard kind == "translate" || kind == "dispatchMessage" else { throw Stop.bound }
                    return .init()
                }
                let window = try events.filter { $0.kind == "queue" && $0.request?.kind == "windowDefault" }.map { try XCTUnwrap($0.response).result }
                let surface = events.filter { $0.kind == "front" && $0.event?.kind == "clear" }.map { _ in OriginalWindowInitialization.Response(result:spec.drawResult) }
                let outcome = try host.step(prepare:{ _,_ in .init(responses:responses,queue:queue,windowDefault:window,surface:surface) })
                if step.end == "loading" { guard case .loading = outcome else { throw Stop.bound } }
                else { guard case .committed = outcome else { throw Stop.bound };_ = try host.takeCommitted() }
            }
            let pending = try XCTUnwrap(host.pendingLoading),startup = try XCTUnwrap(host.snapshot.startup)
            let sounds = try XCTUnwrap(startup.input?.sounds)
            let device = try pending.state.full.integer(at:0x44eecc-0x44d000,as:UInt32.self)
            let owners = try sounds.loads.enumerated().map { i,result in
                try run.audio.ownership(.init(i,OriginalMenuSoundStartup.paths[i],UInt32(0x45560c+i*4),device),result:result)
            }
            let files = Dictionary(uniqueKeysWithValues:try A().files().map { ($0.path,$0) })
            return try .init(startup:run,sounds:.init(owner:sounds,waveOwners:owners,music:startup.output.music),
                files:files,common:OriginalApplicationLoadingPrefixTests.commonInputs.get())
        } catch { try A().close(run);throw error }
    }
    typealias BitsFile = OriginalMacDisplayBackend.BitmapInputs.File
    func common(_ ready: Ready,_ pending: OriginalApplicationMenuSession.PendingLoading,
        _ audio: OriginalLoadingAudioContext) throws -> OriginalApplicationLoadingSession.PendingCatalog {
        var loading = try pending.makeLoadingSession()
        return try loading.prepareCommon(inputs:ready.common,prepareWave:{ i,path,destination,device in
            let file = try XCTUnwrap(ready.files[path])
            return audio.prepare(.init(i,path,destination,device),file:.init(file.input(destination,device)))
        },drawResult:0,presentationResult:0)
    }
    func registration(_ index: Int,_ path: String) -> OriginalSoundRegistration {
        .init(kind:.frame,index:index,path:path,cacheBefore:Array(repeating:0,count:0x2e00))
    }
    func registered(_ loader: inout OriginalRegisteredSoundLoading,_ q: OriginalSoundRegistration,
        _ file: A.File,_ device: UInt32,_ audio: OriginalLoadingAudioContext) throws {
        let binding = OriginalWaveBinding(q.index,q.path,0x452948+UInt32(q.index)*4,device)
        try loader.load(q,device:device,outputBefore:0,
            preparation:audio.prepare(binding,file:.init(file.input(binding.destination,device))),fileSource:{ _ in file.bytes },
            onVolume:{ args in
                XCTAssertEqual(args.count,2);XCTAssertEqual(args[1],UInt32(bitPattern:-10000))
                _ = try audio.volume(binding,buffer:args[0],value:Int32(bitPattern:args[1]))
            })
    }
    func check(_ owners: [OriginalWaveOwnership],_ ready: Ready) throws {
        for owner in owners {
            XCTAssertEqual(owner.domain,.opaque(ready.startup.audio.loadingDomain))
            XCTAssertNil(owner.legacy);XCTAssertNotNil(owner.lease)
            XCTAssertTrue(try owner.addressedRegions().isEmpty)
            try A().check(ready.startup.audio,owner.result.output,XCTUnwrap(ready.files[owner.binding.path]))
        }
    }
    func testOwnedStartupCommonAndRegisteredBuffers() throws {
        let r = try ready();defer { try? A().close(r.startup) }
        let exchange = E(),service = OriginalMacAudioService(backend:r.startup.audio)
        let pending = try XCTUnwrap(r.host.pendingLoading)
        var completed = false
        for _ in 0..<100 {
            let audio = try OriginalLoadingAudioContext(domain:.opaque(r.startup.audio.loadingDomain),cursor:exchange.snapshot.cursor())
            do {
                let common = try common(r,pending,audio)
                var loader = OriginalRegisteredSoundLoading()
                let device = try common.state.full.integer(at:0x44eecc-0x44d000,as:UInt32.self)
                for index in 0..<3 {
                    let path = OriginalInitialSoundLoading.paths[index == 2 ? 0 : index]
                    try registered(&loader,registration(index,path),XCTUnwrap(r.files[path]),device,audio)
                }
                _ = try exchange.finish(audio.cursor)
                XCTAssertTrue(common.waveInputs.isEmpty);XCTAssertEqual(common.waveOwners.count,18)
                XCTAssertEqual(try common.state.full.integer(at:0x45843c-0x44d000,as:UInt32.self),18)
                let owners = r.sounds.waveOwners+common.waveOwners+(0..<3).map { loader.owners[$0]! }
                try check(owners,r);XCTAssertEqual(Set(owners.map { $0.result.output }).count,26)
                XCTAssertEqual(r.startup.audio.bufferTokens.count,26);XCTAssertEqual(exchange.snapshot.receipts.count,87)
                for i in 0..<3 { XCTAssertEqual(try r.startup.audio.volumeObservation(loader.buffers[i]!.output),-10000) }
                let first = common.waveOwners[0],second = common.waveOwners[1]
                let a = try XCTUnwrap(first.result.regions.keys.first),b = try XCTUnwrap(second.result.regions.keys.first)
                XCTAssertLessThan(b-a,UInt32(first.result.first.bytes.count)) // Old address arithmetic would falsely overlap.
                var catalog = try C(pending:common,startup:r.sounds)
                let ref = try F.reference.get(),resources = try F().resources(ref,common.target)
                var reached = false
                XCTAssertThrowsError(try catalog.load(resources:resources,makeControls:{
                    .init(allocate:{ _,_ in reached = true;throw Stop.afterCommon },
                        bitmap:{ _ in throw Stop.bound },file:{ _,_ in throw Stop.bound },
                        wavePreparation:{ _,_ in throw Stop.bound },volume:{ _,_ in throw Stop.bound },
                        time:{ throw Stop.bound },message:{ _,_ in throw Stop.bound })
                })) { XCTAssertEqual($0 as? Stop,.afterCommon) }
                XCTAssertTrue(reached);XCTAssertNil(catalog.pendingPool)
                completed = true;break
            } catch let needed as E.RequestNeeded { try service.serve(exchange.claim(needed),on:exchange) }
        }
        XCTAssertTrue(completed);XCTAssertNil(r.host.preparedLoadedMenu)
    }

    func full(_ r: Ready,_ context: Host.LoadingContext,_ audio: OriginalLoadingAudioContext,
        reference: F.R) throws -> (C.PendingPool,M.S.PendingReturn) {
        let common = try common(r,context.entry,audio)
        let checksum = try common.state.full.integer(at:0x44f620-0x44d000,as:UInt32.self)
        let cache = Array(common.state.full.bytes[(0x455638-0x44d000)..<(0x458438-0x44d000)])
        let provider = F.Provider(reference,checksum,cache),old = provider.controls()
        let controls = C.Controls(allocate:old.allocate,bitmap:old.bitmap,file:old.file,wavePreparation:{ q,device in
            // This source provider checks registration/cache order. Its future
            // audio outputs are not used by Native file preparation or service.
            _ = try provider.wave(q,device)
            let f = try XCTUnwrap(r.files[q.path]),destination = UInt32(0x452948+q.index*4)
            return audio.prepare(.init(q.index,q.path,destination,device),file:.init(f.input(destination,device)))
        },volume:{ binding,args in
            let value = try audio.volume(binding,buffer:args[0],value:Int32(bitPattern:args[1]))
            provider.volumes += 1;return value
        },time:old.time,message:old.message,finish:old.finish)
        var catalog = try C(pending:common,startup:r.sounds)
        var pendingRegistration: Int?,pathWritten = false
        let loaded = try catalog.load(resources:F().resources(reference,common.target),makeControls:{ controls },
            observe:{ event,state in
                switch event {
                case .wave:break // Actual audio is checked from its own payload, not predicted replies.
                case .volume(let args,let result):
                    XCTAssertNil(pendingRegistration);let i = provider.volumes-1
                    XCTAssertEqual(result,0);XCTAssertEqual(args[1],UInt32(bitPattern:-10000))
                    XCTAssertEqual(try state.full.integer(at:0x458438-0x44d000,as:UInt32.self),UInt32(i))
                    XCTAssertEqual(try state.full.integer(at:0x452948+i*4-0x44d000,as:UInt32.self),args[0])
                    XCTAssertEqual(Array(state.full.bytes[(0x455638-0x44d000)..<(0x458438-0x44d000)]),try reference.cache(i,entry:cache))
                    pendingRegistration = i;pathWritten = false
                case .globalStore(let store):
                    if let i = pendingRegistration {
                        if store.address == 0x455638+i*20 {
                            XCTAssertEqual(store.bytes,reference.audio.calls[i].path+[0]);pathWritten = true
                        } else if store.address == 0x458438 {
                            XCTAssertTrue(pathWritten)
                            XCTAssertEqual(store.bytes,(0..<4).map { UInt8(truncatingIfNeeded:UInt32(i+1) >> ($0*8)) })
                            pendingRegistration = nil
                        }
                    }
                    try provider.observe(event,state)
                default:try provider.observe(event,state)
                }
            },afterChild:provider.afterChild)
        try reference.completeRecords(loaded)
        XCTAssertTrue(provider.finished);XCTAssertEqual(loaded.snapshot.waveOwners.count,400)
        XCTAssertTrue(loaded.snapshot.waveInputs.isEmpty)
        XCTAssertNil(pendingRegistration)
        for owner in loaded.snapshot.waveOwners {
            let file = try XCTUnwrap(r.files[owner.binding.path])
            XCTAssertEqual(owner.result.first.bytes,file.payload);XCTAssertTrue(owner.result.first.defined.allSatisfy { $0 })
            XCTAssertNil(owner.result.second);XCTAssertTrue(try owner.addressedRegions().isEmpty)
            XCTAssertEqual(try loaded.snapshot.state.full.integer(at:Int(owner.binding.destination)-0x44d000,as:UInt32.self),owner.result.output)
        }
        // Every actual volume precedes this registration's full path+NUL copy.
        var volumes = 0
        for operation in loaded.snapshot.operations {
            if case .volume(let args,let value) = operation {
                XCTAssertEqual(args[1],UInt32(bitPattern:-10000));XCTAssertEqual(value,0)
                volumes += 1
            }
            // Stores are compared in the retained globalStores journal below.
        }
        XCTAssertEqual(volumes,400)
        for i in 0..<400 {
            let path = Array(loaded.snapshot.waveOwners[i].binding.path.utf8)+[0]
            let pathStore = try XCTUnwrap(loaded.snapshot.globalStores.firstIndex { $0.address == 0x455638+i*20 && $0.bytes == path })
            let countStore = try XCTUnwrap(loaded.snapshot.globalStores.dropFirst(pathStore+1).first { $0.address == 0x458438 })
            XCTAssertEqual(countStore.bytes,(0..<4).map { UInt8(truncatingIfNeeded:UInt32(i+1) >> ($0*8)) })
        }
        let poolProvider = try M.P.Provider(loaded);var pool = try M.S.Input.Pool(pending:loaded)
        let pooled = try pool.prepare(inputs:OriginalApplicationInterfaceInputsTests.inputs.get(),
            makeControls:poolProvider.controls,observe:poolProvider.observe,beforeCommit:poolProvider.complete)
        var input = try M.S.Input(pending:pooled,arithmeticPrecision:.bits53),environment: Void = ()
        let ready = try input.advance(environment:&environment,controlBoundary:{ _,_ in throw Stop.bound })
        var menu = try M.S(pending:ready),env = M.Environment()
        let returned = try M.advance(&menu,&env)
        try M().compareGraphics(returned,env)
        XCTAssertEqual(returned.exit,.returned);XCTAssertEqual(returned.dispatcherResult,1)
        return (loaded,returned)
    }
    func testWholeCatalogPoolLoadedMenuHostWithOwnedAudio() throws {
        let r = try ready();defer { try? A().close(r.startup) }
        let driver = try Driver(host:r.host,domain:.opaque(r.startup.audio.loadingDomain))
        let service = OriginalMacAudioService(backend:r.startup.audio),reference = try F.reference.get()
        let before = r.host.snapshot,sequence = r.host.committedSequence
        var result: (C.PendingPool,M.S.PendingReturn)?,late = false,physical = -1,requests = 0
        for _ in 0..<3002 {
            do {
                var current: (C.PendingPool,M.S.PendingReturn)?
                let outcome = try driver.resume(prepare:{ context,_,audio in
                    current = try self.full(r,context,audio,reference:reference)
                    return .returned(try XCTUnwrap(current).1)
                },beforePrepared:{ _,_ in
                    if !late { throw Stop.late }
                    XCTAssertEqual(r.startup.audio.loadingOperations.count,physical)
                })
                switch outcome {
                case .request(let permit):
                    requests += 1;guard requests <= 3000 else { throw Stop.bound }
                    XCTAssertEqual(r.host.committedSequence,sequence);XCTAssertNil(r.host.preparedLoadedMenu)
                    try service.serve(permit,on:driver)
                case .prepared:
                    result = try XCTUnwrap(current)
                }
                if result != nil { break }
            } catch Stop.late {
                XCTAssertFalse(late);late = true;physical = r.startup.audio.loadingOperations.count
                XCTAssertNil(r.host.preparedLoadedMenu);XCTAssertEqual(driver.exchangeSnapshot.status,.open)
            }
        }
        let loaded = try XCTUnwrap(result)
        XCTAssertTrue(late);XCTAssertEqual(driver.exchangeSnapshot.status,.finished)
        try check(r.sounds.waveOwners+loaded.0.entry.waveOwners+loaded.0.snapshot.waveOwners,r)
        for owner in loaded.0.snapshot.waveOwners {
            XCTAssertEqual(try r.startup.audio.volumeObservation(owner.result.output),-10000)
        }
        XCTAssertEqual(requests,18*4+400*5);XCTAssertEqual(r.startup.audio.bufferTokens.count,423)
        XCTAssertEqual(Set(loaded.0.snapshot.waveOwners.map { $0.result.output }).count,400)
        XCTAssertEqual(Set(loaded.0.snapshot.waveOwners.map { $0.binding.path }).count,365)
        XCTAssertTrue(try XCTUnwrap(r.host.preparedLoadedMenu).loading.isSameAttempt(as:loaded.1.loading))
        try OriginalApplicationLoadedCycleTests.unchanged(r.host.snapshot,before)
        let time = try XCTUnwrap(r.host.snapshot.session).loop.timer.baseline &+ 1000
        let finished = try r.host.finishLoadedMenu(perform:{ request,_ in
            XCTAssertEqual(request.kind,.time);return .init(result:Int32(bitPattern:time))
        })
        guard case .committed(let next,_) = finished else { throw Stop.bound }
        XCTAssertGreaterThan(next,sequence);XCTAssertNil(r.host.pendingLoading)
        let batch = try XCTUnwrap(r.host.takeCommitted())
        guard case .loaded(let commit) = batch.contents else { throw Stop.bound }
        try OriginalApplicationLoadedCycleTests.checkFinished(r.host.snapshot,loaded.1,commit,time:time)
        XCTAssertNil(try r.host.takeCommitted())
        print("Owned Native loading",requests,"requests,423 buffers,137 Objects/400 registrations; pool/menu/Host retained; no Windows endpoint claim")
    }

    func permit(_ request: OriginalLoadingAudioRequest,_ e: E) throws -> E.Permit {
        var cursor = try e.snapshot.cursor()
        do { _ = try cursor.response(for:request);throw Stop.bound }
        catch let needed as E.RequestNeeded { return try e.claim(needed) }
    }
    func isolated(_ service: OriginalMacAudioService,_ file: A.File,late: Bool = false,
        exchange: E = E()) throws -> OriginalWaveOwnership {
        let device = try A().device(service),binding = OriginalWaveBinding(0,file.path,0x452948,device)
        var failed = false,count = -1
        for _ in 0..<10 {
            let context = try OriginalLoadingAudioContext(domain:.opaque(service.backend.loadingDomain),cursor:exchange.snapshot.cursor())
            do {
                var loader = OriginalRegisteredSoundLoading()
                try registered(&loader,registration(0,file.path),file,device,context)
                if late && !failed { failed = true;count = service.backend.loadingOperations.count;throw Stop.late }
                if late { XCTAssertEqual(service.backend.loadingOperations.count,count) }
                _ = try exchange.finish(context.cursor)
                let owner = try XCTUnwrap(loader.owners[0]);XCTAssertEqual(owner.binding,binding)
                XCTAssertEqual(failed,late);return owner
            } catch let needed as E.RequestNeeded { try service.serve(exchange.claim(needed),on:exchange) }
            catch Stop.late { XCTAssertEqual(exchange.snapshot.status,.open) }
        }
        throw Stop.bound
    }
    func testLateRetryProtocolAndRetainedOwners() throws {
        let file = try XCTUnwrap(A().files().first)
        var retained: OriginalWaveOwnership?
        weak var resource: AnyObject?
        weak var backend: B?
        do {
            let b = A().backend(),service = OriginalMacAudioService(backend:b);backend = b
            retained = try isolated(service,file,late:true)
            resource = try XCTUnwrap(retained?.lease?.resources.first) as AnyObject
            XCTAssertEqual(b.loadingOperations.count,5);XCTAssertEqual(b.bufferTokens.count,1)
            let owner = try XCTUnwrap(retained),request = OriginalLoadingAudioRequest.volume(owner.domain,owner.binding,owner.result.output,-10000)
            let e = E(),foreign = E(),ticket = try permit(request,e)
            XCTAssertThrowsError(try service.serve(ticket,on:foreign));XCTAssertEqual(b.loadingOperations.count,5)
            XCTAssertThrowsError(try e.answer(ticket,response:.volume(.opaque(OriginalAudioIdentityDomain()),0)))
            try service.serve(ticket,on:e);XCTAssertEqual(b.loadingOperations.count,6)
            XCTAssertThrowsError(try service.serve(ticket,on:e));XCTAssertEqual(b.loadingOperations.count,6)
            let prepared = try b.prepareLoading(request),stale = try b.prepareLoading(request)
            _ = try b.performLoading(prepared)
            XCTAssertThrowsError(try b.performLoading(prepared)) { XCTAssertEqual($0 as? B.Boundary,.repeatedPreparation) }
            XCTAssertThrowsError(try b.performLoading(stale)) { XCTAssertEqual($0 as? B.Boundary,.stalePreparation) }
            let other = A().backend()
            XCTAssertThrowsError(try other.prepareLoading(request))
            XCTAssertThrowsError(try other.performLoading(b.prepareLoading(request))) { XCTAssertEqual($0 as? B.Boundary,.foreignPreparation) }
            let cancelled = E(),pending = try permit(request,cancelled),count = b.loadingOperations.count
            cancelled.cancel();XCTAssertThrowsError(try service.serve(pending,on:cancelled))
            XCTAssertEqual(b.loadingOperations.count,count)
        }
        XCTAssertNil(backend);XCTAssertNotNil(resource)
        XCTAssertTrue(try XCTUnwrap(retained).addressedRegions().isEmpty)
        retained = nil;XCTAssertNil(resource)
        let empty = A().backend(0),service = OriginalMacAudioService(backend:empty),e = E()
        XCTAssertThrowsError(try isolated(service,file,exchange:e)) { XCTAssertEqual($0 as? B.Boundary,.allocationBudget) }
        XCTAssertEqual(e.snapshot.status,.indeterminate);XCTAssertNotNil(e.snapshot.failure)
        XCTAssertEqual(empty.bufferTokens.count,0)
        let r = try ready();defer { try? A().close(r.startup) }
        let driver = try Driver(host:r.host,domain:.opaque(r.startup.audio.loadingDomain))
        let live = OriginalMacAudioService(backend:r.startup.audio)
        var late = 0,physical = -1
        for _ in 0..<80 {
            do {
                let result = try driver.resume(prepare:{ context,_,audio in
                    _ = try self.common(r,context.entry,audio);throw Stop.afterCommon
                })
                guard case .request(let ticket) = result else { throw Stop.bound }
                try live.serve(ticket,on:driver)
            } catch Stop.afterCommon {
                late += 1
                if late == 1 { physical = r.startup.audio.loadingOperations.count }
                else { XCTAssertEqual(r.startup.audio.loadingOperations.count,physical);break }
            }
        }
        XCTAssertEqual(late,2);XCTAssertEqual(physical,72)
        XCTAssertNil(r.host.preparedLoadedMenu);XCTAssertEqual(driver.exchangeSnapshot.status,.open)
        try driver.cancel();XCTAssertEqual(driver.exchangeSnapshot.status,.cancelled)
        XCTAssertThrowsError(try driver.resume(prepare:{ _,_,_ in throw Stop.bound }))
        XCTAssertEqual(driver.exchangeSnapshot.receipts.count,72)
    }
}
