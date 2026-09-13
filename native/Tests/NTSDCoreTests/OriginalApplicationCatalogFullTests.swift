import Foundation
import XCTest
import NTSDCore

/// Complete owned Native composition in an explicitly declared platform
/// environment. Full game records come from the retained controlled catalogs;
/// missing original application clock/graphics events are not claimed matched.
final class OriginalApplicationCatalogFullTests: XCTestCase {
    typealias C = OriginalApplicationCatalogSession
    typealias R = OriginalApplicationCatalogFullReference
    typealias Prior = OriginalApplicationCatalogSessionTests
    enum Stop: Error, Equatable { case stage,publication }
    static let reference: Result<R,Error> = Result { try R() }
    final class Provider {
        let r: R
        var allocations = 0,objects = 0,files = 0,waves = 0,volumes = 0,times = 0,messages = 0
        var bitmaps = 0,api = 0,event = 0,child = 0,finished = false
        var pcm: UInt32 = 0x78000020
        var queue: [String] = [],image: UInt32 = 0,surface: UInt32 = 0,memoryDC: UInt32 = 0,surfaceDC: UInt32 = 0
        var currentBitmap = "",currentGolden: OriginalCatalogDIBPixelsTests.Golden.Resource?
        var waveInputs: [OriginalWavePlatform] = [],waveEvents: [[OriginalWaveEvent]] = []
        var expectedAllocations: [(C.Allocation.Kind,UInt32,Int)] = []
        var expectedOperations: [C.Operation] = []
        let entryChecksum: UInt32,entryCache: [UInt8]
        init(_ r: R,_ checksum: UInt32,_ cache: [UInt8]) { self.r = r;entryChecksum = checksum;entryCache = cache }
        func next(_ kind: String) throws -> R.Event {
            let e = try XCTUnwrap(r.catalog.events.indices.contains(event) ? r.catalog.events[event] : nil)
            guard e.kind == kind else { throw OriginalStateError.invalidStorage("Full observed event \(event): \(kind)/\(e.kind)") }
            event += 1;return e
        }
        func allocate(_ kind: C.Allocation.Kind,_ count: Int) throws -> UInt32 {
            if kind == .catalog { XCTAssertEqual(count,81273768);expectedAllocations.append((kind,0x70000020,count));return 0x70000020 }
            if kind == .object {
                XCTAssertEqual(count,0x25360);let p = r.catalog.objectAddresses[objects];objects += 1;expectedAllocations.append((kind,p,count));return p
            }
            let a = r.catalog.allocations[allocations];allocations += 1
            guard count == a.size else { throw OriginalStateError.invalidStorage("Native computed allocation size \(allocations)") }
            switch kind {
            case .bitmap:
                XCTAssertEqual(a.kind,"bitmap");XCTAssertEqual(a.address,r.catalog.bitmaps[bitmaps].address)
                guard queue.isEmpty else { throw OriginalStateError.invalidStorage("Incomplete preceding bitmap") }
                currentBitmap = r.catalog.bitmaps[bitmaps].path
                let g = try XCTUnwrap(r.golden.resources.first { $0.name == currentBitmap });currentGolden = g
                image = 0x7a000000+UInt32(bitmaps)*16;surface = 0x7b000000+UInt32(bitmaps)*16
                memoryDC = 0x7c000000+UInt32(bitmaps)*16;surfaceDC = 0x7d000000+UInt32(bitmaps)*16
                queue = ["module","image"] + (g.kind == "dib" ? ["module","image"] : [])
                    + ["getObject","createSurface","restore","createDC","selectObject","getObject","description","getDC","stretch","releaseDC","deleteDC","deleteObject","colorKey"]
                bitmaps += 1
            case .frame(let k):XCTAssertEqual(r.frameKinds[a.caller],k)
            case .weapon(let slot):XCTAssertEqual(r.weaponSlots[a.caller],slot)
            default:throw OriginalStateError.invalidStorage("Unclassified full allocation")
            }
            expectedAllocations.append((kind,a.address,count));return a.address
        }
        func bitmap(_ q: C.API.Request) throws -> C.API.Response {
            guard queue.first == q.kind else { throw OriginalStateError.invalidStorage("Full bitmap API order: \(q.kind)/\(queue.first ?? "end")") }
            queue.removeFirst();api += 1
            let g = try XCTUnwrap(currentGolden),w = UInt32(g.width),h = UInt32(g.height)
            switch q.kind {
            case "module":XCTAssertEqual(q.words,[0]);return .init(result:0x400000)
            case "image":
                XCTAssertEqual(q.strings,[Array(currentBitmap.utf8)])
                let matches = q.words[4] == (g.kind == "bmp" ? 0x2010 : 0x2000)
                if matches { let e = try next("bitmap-load");XCTAssertEqual(e.path,currentBitmap) }
                return .init(result:matches ? Int32(bitPattern:image) : 0)
            case "getObject":XCTAssertEqual(q.words,[image,24]);return .init(result:24)
            case "createSurface":
                let b = try OriginalStateRecord(bytes:XCTUnwrap(q.bytes),defined:XCTUnwrap(q.defined))
                XCTAssertEqual(try b.integer(at:12,as:UInt32.self),w);XCTAssertEqual(try b.integer(at:8,as:UInt32.self),h)
                XCTAssertEqual(try b.integer(at:104,as:UInt32.self),0x40)
                return .init(output:surface)
            case "restore","description":XCTAssertEqual(q.words,[surface]);return .init()
            case "createDC":XCTAssertEqual(q.words,[0]);return .init(result:Int32(bitPattern:memoryDC))
            case "selectObject":XCTAssertEqual(q.words,[memoryDC,image]);return .init(result:1)
            case "getDC":XCTAssertEqual(q.words,[surface]);return .init(output:surfaceDC)
            case "stretch":XCTAssertEqual(q.words,[surfaceDC,0,0,w,h,memoryDC,0,0,w,h,0xcc0020]);return .init(result:1)
            case "releaseDC":XCTAssertEqual(q.words,[surface,surfaceDC]);return .init()
            case "deleteDC":XCTAssertEqual(q.words,[memoryDC]);return .init(result:1)
            case "deleteObject":XCTAssertEqual(q.words,[image]);return .init(result:1)
            case "colorKey":
                let e = try next("color-key");XCTAssertEqual(e.bitmap,bitmaps-1)
                XCTAssertEqual(q.words,[surface,8]);XCTAssertEqual(q.strings,[[UInt8](repeating:0,count:8)]);return .init()
            default:throw OriginalStateError.invalidStorage("Undeclared full bitmap API")
            }
        }
        func file(_ path: String,_ mode: String) throws -> OriginalLoadingFileAllocation {
            let opens = r.catalog.events.filter { $0.kind == "open" },e = opens[files]
            XCTAssertEqual(e.path,path);XCTAssertEqual(e.mode,mode);files += 1
            let token = try XCTUnwrap(e.handle)
            return .init(token:token,buffer:0x54001000+UInt32(files)*0x20000,descriptor:token,capacity:65536,readLimit:4096)
        }
        func region(_ count: Int) throws -> UInt32 {
            guard count >= 0,UInt64(pcm)+UInt64(count)+15 < 0x79000000 else { throw OriginalStateError.invalidStorage("Declared PCM arena exhausted") }
            let p = pcm;pcm = (pcm+UInt32(count)+15) & ~UInt32(15);return p
        }
        func wave(_ request: OriginalSoundRegistration,_ device: UInt32) throws -> OriginalWavePlatform {
            let w = r.audio.calls[waves],p = w.input
            XCTAssertEqual(request.index,w.index);XCTAssertEqual(request.kind,w.kind)
            XCTAssertEqual(Array(request.path.utf8),w.path);XCTAssertTrue(request.cacheBefore == (try r.cache(waves,entry:entryCache)),"Whole pre-registration cache")
            let first = try region(p.firstCount),second = try p.secondPointer == 0 ? 0 : region(p.secondCount)
            let q = OriginalWavePlatform(destination:p.destination,device:device,stream:0x79010000+UInt32(waves)*16,
                buffer:0x79000000+UInt32(waves)*16,firstPointer:first,secondPointer:second,
                descendResults:p.descendResults,formatReadResult:p.formatReadResult,ascendResult:p.ascendResult,dataReadResult:p.dataReadResult,
                createResult:p.createResult,lockResults:p.lockResults,restoreResult:p.restoreResult,unlockResult:p.unlockResult,closeResult:p.closeResult,
                firstCount:p.firstCount,secondCount:p.secondCount,ramp:p.ramp)
            waveInputs.append(q);waveEvents.append([]);waves += 1;return q
        }
        func controls() -> C.Controls {
            .init(allocate:allocate,bitmap:bitmap,file:file,wave:wave,volume:{ args in
                XCTAssertEqual(args,[self.waveInputs[self.volumes].buffer,UInt32(bitPattern:-10000)])
                self.volumes += 1;return -1
            },time:{ defer { self.times += 1 };return 123457000+UInt32(self.times)*20 },message:{ name,bytes in
                XCTAssertEqual(name,"PeekMessageA");self.messages += 1
                self.expectedOperations.append(.message(name,0,bytes));return .init(name:name,response:.init(result:0))
            },finish:{
                XCTAssertEqual(self.allocations,15545);XCTAssertEqual(self.objects,137);XCTAssertEqual(self.bitmaps,829)
                XCTAssertEqual(self.api,12443);XCTAssertEqual(self.files,621);XCTAssertEqual(self.waves,400);XCTAssertEqual(self.volumes,400)
                XCTAssertEqual(self.event,self.r.catalog.events.count);XCTAssertEqual(self.child,155);XCTAssertTrue(self.queue.isEmpty)
                XCTAssertEqual(self.pcm,0x78df6360)
                self.finished = true
            })
        }
        func observe(_ e: C.Observation,_ state: OriginalApplicationMenuSession.State) throws {
            // Independent journal from typed callbacks/control requests, never
            // from published operations or graphics commands.
            switch e {
            case .allocation(let a):expectedOperations.append(.allocation(a))
            case .api(let q,let reply):expectedOperations.append(.menu(.bitmap(q,reply)))
            case .file(let f):expectedOperations.append(.file(f))
            case .wave(let i,let w):if w.kind != .load { expectedOperations.append(.wave(i,w)) }
            case .volume(let args,let result):expectedOperations.append(.volume(args,ignoredResult:result))
            case .front(let f):
                switch f.kind {
                case "timeGetTime":expectedOperations.append(.clock(try XCTUnwrap(f.arguments.first)))
                case "sleep":expectedOperations.append(.menu(.sleep(try XCTUnwrap(f.arguments.first))))
                case "blit":expectedOperations.append(.menu(.blit(try XCTUnwrap(f.blit),result:0)))
                case "method":expectedOperations.append(.menu(.present(f,result:0)))
                case "soundMethod":expectedOperations.append(.menu(.soundMethod(f,ignoredResult:0)))
                case "getDC":expectedOperations.append(.menu(.getDC(f,result:0,output:0x12345678)))
                case "setBackgroundMode","setTextColor","textOut","releaseDC":expectedOperations.append(.menu(.graphics(f,result:0)))
                case "read","clip","draw","panelRead","text","stringLength","soundRequest","PeekMessageA":break
                default:throw OriginalStateError.invalidStorage("Unclassified observed full front operation")
                }
            case .catalogEntry,.request,.parentStore,.globalStore:break
            }
            switch e {
            case .file(let f):
                if f.kind == .openFile { let e = try next("open");XCTAssertEqual(f.path,e.path);XCTAssertEqual(f.mode,e.mode);XCTAssertEqual(f.arguments,[e.handle!]) }
                if f.kind == .closeReadFile || f.kind == .closeOutputDescriptor { let e = try next("close");XCTAssertEqual(f.arguments.last,e.handle);XCTAssertEqual(f.result,0) }
            case .wave(let i,let w):
                if w.kind == .load { XCTAssertEqual(w.arguments,[waveInputs[i].destination]);XCTAssertEqual(w.strings,[r.audio.calls[i].path]) }
                else { waveEvents[i].append(w) }
            case .volume:
                let actual = waveEvents[volumes-1],source = r.audio.calls[volumes-1],p = waveInputs[volumes-1]
                let expected = source.events.map { e -> OriginalWaveEvent in
                    var a = e.arguments
                    // Only the typed pointer operands of this particular call
                    // change. Never replace matching values inside PCM/Frames.
                    switch e.kind {
                    case .descend,.read,.ascend,.close:a[0] = p.stream
                    case .create:a[0] = p.device
                    case .lock,.restore:a[0] = p.buffer
                    case .unlock:a[0] = p.buffer;a[1] = p.firstPointer;a[3] = p.secondPointer
                    default:break
                    }
                    return .init(e.kind,a,e.strings)
                }
                XCTAssertEqual(actual,expected)
            default:break
            }
        }
        func afterChild(_ c: OriginalCatalogChildObservation,_ s: C.Snapshot) throws {
            try r.child(c,child,entryChecksum:entryChecksum,entryCache:entryCache);child += 1
            XCTAssertEqual(s.sounds.buffers.count,c.soundCount)
        }
    }
    func resources(_ r: R,_ target: UInt32) throws -> C.Resources {
        let p = try JSONDecoder().decode(OriginalMenuPresentationInput.self,from:JSONSerialization.data(withJSONObject:[
            "targetSurface":target,"methodResult":0,"queryResult":0,"audioGetResult":0,"audioSetResult":0,
            "queriedAudio":0,"audioVolume":0,"dcResult":0,"dc":0x12345678,"postResult":0]))
        return try .init(files:r.files,bitmaps:r.images,presentation:p,drawResult:0,graphicsResult:0,allocationFill:0xa5)
    }
    func checkPublication(_ p: C.PendingPool,_ r: R,_ provider: Provider) throws {
        let expectedWaves = provider.waveInputs
        XCTAssertEqual(provider.expectedAllocations.count,15683)
        XCTAssertEqual(p.snapshot.allocations.map(\.kind),provider.expectedAllocations.map(\.0))
        XCTAssertEqual(p.snapshot.allocations.map(\.token),provider.expectedAllocations.map(\.1))
        XCTAssertEqual(p.snapshot.allocations.map(\.count),provider.expectedAllocations.map(\.2))
        let expectedOperations = p.entry.stagedOperations.map(C.Operation.preceding)+provider.expectedOperations
        XCTAssertEqual(p.snapshot.operations.count,expectedOperations.count)
        XCTAssertTrue(p.snapshot.operations == expectedOperations,"Complete callback-to-publication operation stream")
        XCTAssertEqual(p.snapshot.objectTokens,r.catalog.objectAddresses)
        XCTAssertEqual(p.snapshot.bitmapTokens,r.catalog.bitmaps.map(\.address))
        XCTAssertEqual(p.snapshot.bitmapSurfaces,(0..<829).map { UInt32(0x7b000000)+UInt32($0)*16 })
        let encoder = JSONEncoder();encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try encoder.encode(p.snapshot.waveInputs),try encoder.encode(expectedWaves))
        for i in 0..<400 {
            let expected = UInt32(0x79000000)+UInt32(i)*16
            XCTAssertEqual(expectedWaves[i].buffer,expected)
            XCTAssertEqual(p.snapshot.sounds.buffers[i]?.output,expected)
            XCTAssertEqual(try p.snapshot.state.full.integer(at:0x452948-0x44d000+i*4,as:UInt32.self),expected)
        }
        XCTAssertEqual(try p.snapshot.state.full.integer(at:0x458438-0x44d000,as:UInt32.self),400)
        XCTAssertTrue(Array(p.snapshot.state.full.bytes[(0x455638-0x44d000)..<(0x458438-0x44d000)]) == (try r.cache(400,entry:provider.entryCache)),"Whole published cache")
        XCTAssertEqual(try p.snapshot.state.full.integer(at:0x44f620-0x44d000,as:UInt32.self),p.catalog.checksum)
        let projection = try OriginalApplicationCatalogGraphicsComparison(resources:r.images,golden:r.golden,entry:p.entry)
        var events: [OriginalApplicationCatalogGraphicsComparison.Event] = []
        XCTAssertEqual(Array(p.snapshot.operations.prefix(p.entry.stagedOperations.count)),p.entry.stagedOperations.map(C.Operation.preceding))
        for operation in p.snapshot.operations.dropFirst(p.entry.stagedOperations.count) {
            guard case .menu(let effect) = operation else { continue }
            switch effect {
            case .bitmap(let q,let reply):events.append(.init(request:q,response:reply,kind:nil,event:nil))
            case .blit(let b,let result):
                XCTAssertEqual(result,0);var e = OriginalFrontScreenEvent("blit");e.blit = b
                events.append(.init(request:nil,response:nil,kind:"front",event:e))
            case .present(let e,let result),.graphics(let e,let result):
                XCTAssertEqual(result,0);events.append(.init(request:nil,response:nil,kind:"front",event:e))
            case .getDC(let e,let result,let output):
                XCTAssertEqual(result,0);XCTAssertEqual(output,0x12345678)
                events.append(.init(request:nil,response:nil,kind:"front",event:e))
            case .sleep,.soundMethod:break // These staged effects have no graphics Command.
            default:throw OriginalStateError.invalidStorage("Unclassified full catalog platform effect")
            }
        }
        try projection.compare(snapshot:p.snapshot,events:events)
        XCTAssertEqual(projection.images.count,829);XCTAssertEqual(projection.surfaces.count,829)
        XCTAssertEqual(p.snapshot.state.memory.allocations,p.entry.state.memory.allocations)
        XCTAssertEqual(p.snapshot.state.random,p.entry.state.random)
        XCTAssertEqual(p.startup.owner.loads.count,5);XCTAssertEqual(p.entry.common.sounds.count,18)
    }
    func run(_ stop: Stop?) throws {
        let r = try Self.reference.get(),prefix = try OriginalApplicationCatalogSessionReference(parentIndex:0)
        try Prior().withEntry(prefix) { entry,startup in
            let inputs = try self.resources(r,entry.target),checksum = try entry.state.full.integer(at:0x44f620-0x44d000,as:UInt32.self)
            let cache = Array(entry.state.full.bytes[(0x455638-0x44d000)..<(0x458438-0x44d000)])
            var owner = try C(pending:entry,startup:startup),providers: [Provider] = []
            let factory: () throws -> C.Controls = {
                let provider = Provider(r,checksum,cache);providers.append(provider);return provider.controls()
            }
            func attempt(_ stop: Stop?) throws -> C.PendingPool {
                return try owner.load(resources:inputs,makeControls:factory,
                    observe:{ try XCTUnwrap(providers.last).observe($0,$1) },afterChild:{ child,snapshot in
                        try XCTUnwrap(providers.last).afterChild(child,snapshot)
                        if stop == .stage && child.request.kind == .stages { throw Stop.stage }
                    },beforeCommit:{ pending in
                        try r.complete(pending);try self.checkPublication(pending,r,XCTUnwrap(providers.last))
                        if stop == .publication { throw Stop.publication }
                    })
            }
            if let stop {
                do { _ = try attempt(stop);XCTFail("Expected late cancellation") } catch let actual as Stop { XCTAssertEqual(actual,stop) }
                XCTAssertNil(owner.pendingPool);Prior.retained(owner.entry.state,entry.state)
                XCTAssertEqual(providers.count,1);XCTAssertEqual(providers[0].finished,stop == .publication)
                if stop == .publication {
                    let p = try attempt(nil);XCTAssertEqual(providers.count,2);XCTAssertFalse(providers[0] === providers[1])
                    XCTAssertEqual(p.catalog.objects.count,137);XCTAssertTrue(owner.pendingPool != nil)
                }
            } else {
                let p = try attempt(nil);XCTAssertTrue(owner.pendingPool != nil);XCTAssertTrue(providers[0].finished)
                XCTAssertEqual(p.snapshot.allocations.count,15683);XCTAssertEqual(p.catalog.objects.count,137)
                print("Owned full Native catalog:137 Objects/17 BG/Stage;829 bitmap colors/400 WAV; full records and PendingPool. Declared Native environment, no whole original application match")
            }
        }
    }
    func testCompleteCatalogFromOwnedApplication() throws { try run(nil) }
    func testLateStageCancellationRollsBackEntireCatalog() throws { try run(.stage) }
    func testBeforePublicationCancellationAndFreshFactory() throws { try run(.publication) }
}
