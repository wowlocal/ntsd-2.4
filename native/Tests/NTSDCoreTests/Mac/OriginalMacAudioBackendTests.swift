import AppKit
import AVFAudio
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform
@testable import NTSDRuntime
@testable import NTSDReferenceChecks

@MainActor final class OriginalMacAudioBackendTests: XCTestCase {
    typealias B = OriginalMacAudioBackend
    typealias S = OriginalMacAudioService
    typealias E = OriginalStartupRequestExchange
    typealias N = OriginalApplicationPreparedStartupPlatform
    typealias Driver = OriginalApplicationObservedStartup<N>
    typealias W = OriginalMacWindowBackendTests
    typealias A = OriginalStartupAudioTests
    enum Stop: Error { case bound, late }
    struct Blob: Decodable { let count: Int, deflate: String }
    struct Source: Decodable { let path: String, sha256: String, bytes: Int }
    // Expected cases/after-state are deliberately not part of this input type.
    struct Corpus: Decodable { let exeSHA256: String, sources: [Source], blobs: [String:Blob] }
    struct File {
        let path: String, bytes: [UInt8], payload: [UInt8], channels: Int, rate: Int, bits: Int
        var tuple: [Int] { [channels,rate,bits] }
        var frames: Int { payload.count/(channels*bits/8) }
        func input(_ destination: UInt32,_ device: UInt32) -> OriginalWaveInput {
            .init(destination:destination,device:device,stream:1,descendResults:[0,0,0],
                formatReadResult:18,ascendResult:0,dataReadResult:Int32(payload.count),closeResult:0,
                storage:.init(first:.init(bytes:[],defined:[]),second:nil,ramp:false))
        }
        func samples(_ channel: Int) -> [Float] {
            // Independent arithmetic sign extension, not the backend's Int16 conversion.
            (0..<frames).map { frame in
                let i = (frame*channels+channel)*(bits/8)
                if bits == 8 { return Float(Int(payload[i])-128)/Float(1<<7) }
                let value = Int(payload[i])+256*Int(payload[i+1])
                return Float(value >= 32768 ? value-65536 : value)/Float(1<<15)
            }
        }
    }
    func file(_ path: String,_ bytes: [UInt8]) throws -> File {
        func u16(_ i: Int) -> Int { Int(bytes[i])+256*Int(bytes[i+1]) }
        func u32(_ i: Int) -> Int { u16(i)+65536*u16(i+2) }
        guard bytes.count >= 36,Array(bytes[0..<4]) == Array("RIFF".utf8),
              Array(bytes[8..<12]) == Array("WAVE".utf8),Array(bytes[12..<16]) == Array("fmt ".utf8) else { throw Stop.bound }
        let limit = u32(4)+8;guard limit <= bytes.count,u16(20) == 1 else { throw Stop.bound }
        let channels = u16(22),rate = u32(24),bits = u16(34)
        var offset = 12
        for _ in 0..<256 {
            guard offset+8 <= limit else { throw Stop.bound }
            let count = u32(offset+4),start = offset+8;guard start+count <= limit else { throw Stop.bound }
            if Array(bytes[offset..<(offset+4)]) == Array("data".utf8) {
                return .init(path:path,bytes:bytes,payload:Array(bytes[start..<(start+count)]),channels:channels,rate:rate,bits:bits)
            }
            offset = start+count+(count%2)
        }
        throw Stop.bound
    }
    func files() throws -> [File] {
        let url = try XCTUnwrap(Bundle.module.url(forResource:"original-wave-loader",withExtension:"json",subdirectory:"Fixtures"))
        let corpus = try JSONDecoder().decode(Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:url)))
        XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.sources.count,409)
        return try corpus.sources.map { source in
            let blob = try XCTUnwrap(corpus.blobs[source.sha256])
            let raw = try MatchPreparationReference.inflate(blob.deflate,count:blob.count)
            XCTAssertEqual(raw.count,source.bytes);XCTAssertEqual(MatchPreparationReference.digest(Data(raw)),source.sha256)
            return try file(source.path,raw)
        }
    }
    func backend(_ budget: Int = 128*1024*1024) -> B {
        B(windows:OriginalMacWindowBackend(instance:0x400000),maximumBytes:budget)
    }
    func permit(_ request: OriginalStartupRequest,_ e: E) throws -> E.Permit {
        var cursor = try e.snapshot.cursor()
        do { _ = try cursor.response(for:request);throw Stop.bound }
        catch let needed as E.RequestNeeded { return try e.claim(needed) }
    }
    func call(_ service: S,_ request: OriginalStartupRequest) throws -> OriginalStartupResponse {
        let e = E();try service.serve(permit(request,e),on:e)
        var c = try e.snapshot.cursor();let r = try c.response(for:request);_ = try e.finish(c);return r
    }
    func device(_ service: S) throws -> UInt32 {
        guard case .sound(let r) = try call(service,.sound(.init("deviceCreate",[0,0x44eecc,0]))),
              r.result == 0,let token = r.output else { throw Stop.bound };return token
    }
    func load(_ service: S,_ file: File,_ device: UInt32,_ index: Int = 0,late: Bool = false,
        exchange: E = E()) throws -> (OriginalWaveLoadResult,E) {
        let destination = UInt32(0x452948+index*4),binding = OriginalWaveBinding(index,file.path,destination,device)
        var failed = false,servedBeforeRetry = -1
        for _ in 0..<20 {
            var c = try exchange.snapshot.cursor()
            do {
                let result = try OriginalWaveLoader.loadObserved(path:Array(file.path.utf8),file:file.bytes,output:0,
                    input:file.input(destination,device),request:{ q in
                        guard case .waveAudio(let r) = try c.response(for:.waveAudio(binding,q)) else { throw Stop.bound };return r
                    })
                if late && !failed { failed = true;servedBeforeRetry = service.backend.operations.count;throw Stop.late }
                if late { XCTAssertEqual(service.backend.operations.count,servedBeforeRetry) }
                _ = try exchange.finish(c);XCTAssertEqual(failed,late);return (result,exchange)
            } catch let needed as E.RequestNeeded { try service.serve(exchange.claim(needed),on:exchange) }
            catch Stop.late { XCTAssertEqual(exchange.snapshot.status,.open) }
        }
        throw Stop.bound
    }
    func check(_ b: B,_ token: UInt32,_ file: File) throws {
        let o = try b.observation(token),pcm = try b.pcmSnapshot(token)
        XCTAssertEqual(o.raw.bytes,file.payload);XCTAssertTrue(o.raw.defined.allSatisfy { $0 })
        XCTAssertTrue(o.ready);XCTAssertNil(o.activeLock)
        XCTAssertEqual(o.format.channels,file.channels);XCTAssertEqual(o.format.bits,file.bits);XCTAssertEqual(o.format.rate,UInt32(file.rate))
        XCTAssertEqual(pcm.format.sampleRate,Double(file.rate));XCTAssertEqual(Int(pcm.format.channelCount),file.channels)
        XCTAssertEqual(Int(pcm.frameLength),file.frames)
        try withExtendedLifetime(pcm) {
            let channels = try XCTUnwrap(pcm.floatChannelData)
            for channel in 0..<file.channels {
                XCTAssertEqual(Array(UnsafeBufferPointer(start:channels[channel],count:file.frames)),file.samples(channel))
            }
            channels[0][0] = 123 // exported snapshot must not alias the retained owner
            let independent = try b.pcmSnapshot(token)
            try withExtendedLifetime(independent) {
                XCTAssertEqual(try XCTUnwrap(independent.floatChannelData)[0][0],file.samples(0)[0])
            }
        }
    }
    func testOriginalWAVsThroughOwnedBuffers() throws {
        let files = try files(),b = backend(),s = S(backend:b),d = try device(s)
        var tuples = Set<[Int]>(),rates = Set<Int>(),bytes = 0
        for (i,f) in files.enumerated() {
            let (r,e) = try load(s,f,d,i)
            XCTAssertEqual(r.exit,.returned);XCTAssertEqual(r.returned,1);XCTAssertFalse(r.temporaryLive)
            XCTAssertEqual(r.first.bytes,f.payload);XCTAssertTrue(r.first.defined.allSatisfy { $0 });XCTAssertNil(r.second)
            XCTAssertEqual(try XCTUnwrap(r.initialStorage).first.bytes,[]);try check(b,r.output,f)
            XCTAssertEqual(e.snapshot.receipts.count,4)
            guard case .waveAudio(.locked(_,let lock?)) = e.snapshot.receipts[1].response else { throw Stop.bound }
            XCTAssertTrue(try XCTUnwrap(lock.first).storage.defined.allSatisfy { !$0 })
            XCTAssertTrue(try XCTUnwrap(lock.first).storage.bytes.allSatisfy { $0 == 0xa5 })
            tuples.insert(f.tuple);rates.insert(f.rate);bytes += f.payload.count
        }
        XCTAssertEqual(b.bufferTokens.count,409);XCTAssertEqual(Set(b.bufferTokens).count,409)
        XCTAssertEqual(tuples.count,23);XCTAssertEqual(rates.count,18);XCTAssertEqual(b.operations.count,1+409*4)
        let first = try XCTUnwrap(files.first),r = try load(s,first,d,0).0
        XCTAssertEqual(b.bufferTokens.count,410);XCTAssertNotEqual(r.output,b.bufferTokens.first);try check(b,r.output,first)
        print("Native owned PCM",409,"formats",tuples.count,"rates",rates.count,"payload bytes",bytes,"no endpoint opened")
    }
    struct Startup {
        let driver: Driver, host: Driver.Host, audio: B, windows: OriginalMacWindowBackend
        let display: OriginalMacDisplayBackend, window: UInt32, files: [File]
    }
    func startup(_ late: Bool) throws -> Startup {
        _ = NSApplication.shared
        let package = try OriginalApplicationStartupInputsTests.shared.get(),(p,initial) = try W.D().inputs()
        let full = try W.Old().preparation(p),values = try A.Service(p,package)
        var prepared = W.Observed.constants(full);prepared.observesAudio = true;prepared.waves = [];prepared.waveInputs = []
        let files = try full.waves.map { try file($0.request.path,XCTUnwrap(package.file($0.request.path))) }
        prepared.waveFiles = zip(full.waves,files).map { row,f in
            .init(.init(row.request.index,row.request.path,row.request.destination),OriginalWaveFileInput(f.input(row.request.destination,0)))
        }
        // This ignored legacy value must not create the device or choose buffers.
        prepared.sound = .init(createResult:123,createdDevice:0xdeadbeef)
        let driver = try Driver(platform:N(inputs:package,prepared:prepared),instance:0x400000,show:10,initial:initial)
        let windows = OriginalMacWindowBackend(instance:0x400000),windowService = OriginalMacWindowStartupService(driver:driver,backend:windows)
        let display = OriginalMacDisplayBackend(windows:windows),displayService = OriginalMacDisplayStartupService(driver:driver,backend:display)
        let audio = B(windows:windows),service = S(backend:audio)
        var window: UInt32 = 0,failed = false,physical = -1
        let oldWindow = UInt32(bitPattern:try XCTUnwrap(p.c.events.first { $0.kind == "window" && $0.event?.request?.kind == "createWindow" }?.event?.response?.result))
        for _ in 0..<1500 {
            do {
                switch try driver.resume(beforeCommit:{ _,_,_ in if late && !failed { throw Stop.late } }) {
                case .request(let permit):
                    XCTAssertNil(driver.snapshot.startup);XCTAssertEqual(driver.pendingBatchCount,0)
                    XCTAssertEqual(permit.ordinal,values.calls)
                    switch permit.request {
                    case .sound,.waveAudio:
                        try service.serve(permit,on:driver);values.calls += 1
                    case .window(let q) where OriginalMacWindowBackend.handles(q):
                        try windowService.serve(permit);values.calls += 1;values.windowIndex += 1
                        if q.kind == "createWindow" {
                            guard case .window(let r) = try XCTUnwrap(driver.exchangeSnapshot.receipts.last).response else { throw Stop.bound }
                            window = UInt32(bitPattern:r.result)
                        }
                    case .window(let q) where OriginalMacDisplayBackend.handles(q):
                        try displayService.serve(permit);values.calls += 1;values.windowIndex += 1
                    default:
                        var q = permit.request
                        if case .music(let event) = q,event.kind == .method,event.arguments.count == 5,event.arguments[1] == 0x34 {
                            var a = event.arguments;XCTAssertEqual(a[2],window);a[2] = oldWindow;q = .music(.init(event.kind,a,event.strings))
                        }
                        if case .joystick(let event) = q,event.kind == "capture" {
                            var a = event.arguments;XCTAssertEqual(a[0],window);a[0] = oldWindow;q = .joystick(.init(event.kind,a,information:event.information))
                        }
                        try driver.beginService(permit)
                        do { try driver.answer(permit,response:values.answer(q)) }
                        catch { try driver.fail(permit,diagnostic:String(reflecting:error));throw error }
                    }
                case .started(_,let host):
                    try values.values.validatePreparedConsumption();XCTAssertEqual(failed,late)
                    if late { XCTAssertEqual(audio.operations.count,physical) }
                    XCTAssertEqual(driver.exchangeSnapshot.status,.finished)
                    return .init(driver:driver,host:host,audio:audio,windows:windows,display:display,window:window,files:files)
                }
            } catch Stop.late {
                XCTAssertTrue(late);XCTAssertFalse(failed);failed = true;physical = audio.operations.count
                XCTAssertNil(driver.snapshot.startup);XCTAssertEqual(driver.pendingBatchCount,0)
                XCTAssertEqual(audio.bufferTokens.count,5)
            }
        }
        throw Stop.bound
    }
    func close(_ run: Startup) throws {
        _ = try run.windows.perform(run.windows.prepare(.init("destroyWindow",[run.window])))
    }
    func verify(_ run: Startup) throws {
        let g = try XCTUnwrap(run.host.snapshot.session).state.full
        let d = try g.integer(at:0x44eecc-0x44d000,as:UInt32.self)
        XCTAssertEqual(run.audio.deviceTokens,[d]);XCTAssertNotEqual(d,run.window)
        XCTAssertEqual(run.audio.bufferTokens.count,5);XCTAssertEqual(run.audio.operations.count,22)
        let startup = try XCTUnwrap(run.host.snapshot.startup),loads = try XCTUnwrap(startup.input?.sounds.loads)
        XCTAssertEqual(loads.count,5)
        for (load,f) in zip(loads,run.files) { try check(run.audio,load.output,f) }
        let audioReceipts = run.driver.exchangeSnapshot.receipts.filter {
            switch $0.request { case .sound,.waveAudio:return true;default:return false }
        }
        XCTAssertEqual(audioReceipts.count,22);XCTAssertTrue(audioReceipts.allSatisfy { !$0.resources.isEmpty })
        XCTAssertEqual(run.windows.createdWindowCount,1);XCTAssertEqual(run.display.allocationCount,4)
        let batch = try XCTUnwrap(run.host.takeCommitted());XCTAssertEqual(batch.sequence,1)
        XCTAssertEqual(try batch.context.platformSnapshot().startupExchange?.position,run.driver.exchangeSnapshot.receipts.count)
        print("Whole own WinMain PCM",loads.count,"buffers; Native window/display; other boundaries declared")
    }
    func testWholeStartupWithOwnedMenuBuffers() throws {
        let r = try startup(false);defer { try? close(r) };try verify(r)
    }
    func testLateRetryAndResourceLifetimes() throws {
        let r = try startup(true);defer { try? close(r) };try verify(r)
        let f = try XCTUnwrap(files().first),b = backend(),s = S(backend:b),d = try device(s)
        let (loaded,e) = try load(s,f,d,late:true);XCTAssertEqual(b.operations.count,5);try check(b,loaded.output,f)
        XCTAssertEqual(e.snapshot.receipts.count,4)
        weak var owner: AnyObject?
        func retained() throws -> E {
            let b = backend(),s = S(backend:b),d = try device(s),(_,e) = try load(s,f,d)
            owner = try XCTUnwrap(e.snapshot.receipts.last?.resources.first);return e
        }
        var journal: E? = try retained();XCTAssertNotNil(owner)
        withExtendedLifetime(journal) {};journal = nil;XCTAssertNil(owner)
    }
    func testUnsupportedInputsAndServiceProtocol() throws {
        let b = backend(),s = S(backend:b),create = OriginalStartupRequest.sound(.init("deviceCreate",[0,0x44eecc,0]))
        let e = E(),other = E(),p = try permit(create,e),foreign = try permit(create,other)
        XCTAssertThrowsError(try s.serve(foreign,on:e));XCTAssertTrue(b.operations.isEmpty)
        try s.serve(p,on:e);let count = b.operations.count
        XCTAssertThrowsError(try s.serve(p,on:e));XCTAssertEqual(b.operations.count,count)
        other.cancel();XCTAssertThrowsError(try s.serve(foreign,on:other));XCTAssertEqual(b.operations.count,count)
        let a = try b.prepare(create),stale = try b.prepare(create),alien = backend()
        XCTAssertThrowsError(try alien.perform(a)) { XCTAssertEqual($0 as? B.Boundary,.foreignPreparation) }
        _ = try b.perform(a)
        XCTAssertThrowsError(try b.perform(a)) { XCTAssertEqual($0 as? B.Boundary,.repeatedPreparation) }
        XCTAssertThrowsError(try b.perform(stale)) { XCTAssertEqual($0 as? B.Boundary,.stalePreparation) }
        let f = try XCTUnwrap(files().first),d = try device(s),(loaded,_) = try load(s,f,d)
        let o = try b.observation(loaded.output),binding = o.binding
        guard case .waveAudio(_,let original) = try XCTUnwrap(b.operations.first { if case .waveAudio(_,let q) = $0.request { return q.event.kind == .create };return false }).request else { throw Stop.bound }
        for (structure,offset,value) in [(0,0,0),(0,4,0),(0,8,0),(1,0,0),(1,2,3),(1,4,0),(1,14,24)] {
            var records = try original.structures.map { try $0.record() };try records[structure].write(UInt16(value),at:offset)
            let q = OriginalWaveRequest(.init(.create,[d,0],records.map(\.bytes)),structures:records.map(OriginalAudioBytes.init))
            let before = b.operations.count;XCTAssertThrowsError(try b.prepare(.waveAudio(binding,q)));XCTAssertEqual(b.operations.count,before)
        }
        XCTAssertThrowsError(try b.prepare(.milliseconds))
        _ = try call(s,.waveAudio(binding,.init(.init(.lock,[loaded.output,0,UInt32(f.payload.count),0]))))
        let region = try XCTUnwrap(b.observation(loaded.output).activeLock)
        var mask = Array(repeating:true,count:f.payload.count);mask[0] = false
        _ = try call(s,.waveAudio(binding,.init(.init(.copy,[0,0,UInt32(f.payload.count)]),target:region,bytes:f.payload,defined:mask)))
        XCTAssertEqual(try b.observation(loaded.output).raw.defined,mask)
        XCTAssertThrowsError(try b.pcmSnapshot(loaded.output)) { XCTAssertEqual($0 as? B.Boundary,.unknownSamples) }
        let unlock = OriginalStartupRequest.waveAudio(binding,.init(.init(.unlock,[loaded.output,region,UInt32(f.payload.count),0,0])))
        let before = b.operations.count;XCTAssertThrowsError(try b.prepare(unlock)) { XCTAssertEqual($0 as? B.Boundary,.unknownSamples) };XCTAssertEqual(b.operations.count,before)
        let limited = backend(0),limitedService = S(backend:limited),ld = try device(limitedService),failed = E()
        XCTAssertThrowsError(try load(limitedService,f,ld,exchange:failed)) { XCTAssertEqual($0 as? B.Boundary,.allocationBudget) }
        XCTAssertEqual(failed.snapshot.status,.indeterminate);XCTAssertFalse(try XCTUnwrap(failed.snapshot.failure).resources.isEmpty)
        XCTAssertTrue(limited.bufferTokens.isEmpty);XCTAssertEqual(limited.allocatedBytes,0)
        var diagnostics = 0
        let diag = B(windows:OriginalMacWindowBackend(instance:0x400000),diagnostic:{ q in
            diagnostics += 1;if case .sound = q { return .sound(.init(result:17)) };return .waveAudio(.result(19))
        }),ds = S(backend:diag),dd = try device(ds)
        guard case .waveAudio(.result(19)) = try call(ds,.waveAudio(.init(0,f.path,0x452948,dd),.init(.init(.message,[0,0],[Array("reason".utf8),Array("title".utf8)])))) else { throw Stop.bound }
        XCTAssertEqual(diagnostics,1)
        let input = OriginalWaveFileInput(f.input(0x452948,0)),package = try OriginalApplicationStartupInputsTests.shared.get()
        var prepared = N.Prepared(panelIO:.init(outputBacking:[]),environmentTZ:nil,sound:.init(createResult:0,createdDevice:nil))
        prepared.observesAudio = true;prepared.waveFiles = [.init(.init(0,f.path,0x452948),input)]
        let n = N(inputs:package,prepared:prepared),bound = try n.waveInput(0,f.path,0x452948,d)
        XCTAssertEqual(bound.device,d);XCTAssertEqual(bound.destination,0x452948);XCTAssertEqual(bound.storage,input.storage)
        try n.validatePreparedConsumption()
        prepared.waveInputs = [.init(binding,bound)]
        let mixed = N(inputs:package,prepared:prepared)
        XCTAssertThrowsError(try mixed.waveInput(0,f.path,0x452948,d));XCTAssertTrue(mixed.snapshot.positions.isEmpty)
        XCTAssertThrowsError(try mixed.validatePreparedConsumption())
    }
    func testOfflinePCMTransportForEveryOriginalFormat() throws {
        var seen = Set<[Int]>(),count = 0,frames = 0
        for f in try files().sorted(by:{ $0.path < $1.path }) where seen.insert(f.tuple).inserted {
            let b = backend(),s = S(backend:b),d = try device(s),loaded = try load(s,f,d).0,pcm = try b.pcmSnapshot(loaded.output)
            let engine = AVAudioEngine(),player = AVAudioPlayerNode()
            try engine.enableManualRenderingMode(.offline,format:pcm.format,maximumFrameCount:1024)
            engine.attach(player);engine.connect(player,to:engine.mainMixerNode,format:pcm.format)
            engine.connect(engine.mainMixerNode,to:engine.outputNode,format:pcm.format)
            defer { player.stop();engine.stop() }
            player.scheduleBuffer(pcm,at:nil,options:[]);try engine.start();player.play()
            let output = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:pcm.format,frameCapacity:1024))
            var position = 0,calls = 0
            let expected = (0..<f.channels).map { f.samples($0) }
            while position < f.frames {
                calls += 1;guard calls <= (f.frames+1023)/1024+2 else { throw Stop.bound }
                let request = min(1024,f.frames-position),status = try engine.renderOffline(AVAudioFrameCount(request),to:output)
                XCTAssertEqual(status,.success);XCTAssertEqual(Int(output.frameLength),request)
                guard status == .success,Int(output.frameLength) == request else { throw Stop.bound }
                try withExtendedLifetime(output) {
                    let channels = try XCTUnwrap(output.floatChannelData)
                    for channel in 0..<f.channels {
                        XCTAssertEqual(Array(UnsafeBufferPointer(start:channels[channel],count:request)),Array(expected[channel][position..<(position+request)]))
                    }
                }
                position += request
            }
            count += 1;frames += position
        }
        XCTAssertEqual(count,23);print("Offline PCM transport formats",count,"frames",frames,"same rate/channels; no hardware output")
    }
}
