import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationLoadedMenuTests: XCTestCase {
    typealias S = OriginalApplicationLoadedMenuSession
    typealias I = OriginalApplicationInputTests
    typealias P = OriginalApplicationPoolTests
    typealias F = OriginalApplicationCatalogFullTests
    typealias State = OriginalApplicationMenuSession.State
    enum Stop: Error, Equatable { case injected(String), unexpected(String) }
    struct Parent { let session: OriginalApplicationMenuSession,input: S.Input.PendingContinuation }
    static let parent: Result<Parent,Error> = Result {
        let r = try F.reference.get(),prefix = try OriginalApplicationCatalogSessionReference(parentIndex:0)
        var parent: Parent?,origin: OriginalApplicationMenuSession?
        try F.Prior().withEntry(prefix,ownerAtLoading:{ origin = $0 }) { entry,startup in
            let checksum = try entry.state.full.integer(at:0x44f620-0x44d000,as:UInt32.self)
            let cache = Array(entry.state.full.bytes[(0x455638-0x44d000)..<(0x458438-0x44d000)])
            let controls = F.Provider(r,checksum,cache);var catalog = try S.Input.Pool.Catalog(pending:entry,startup:startup)
            let loaded = try catalog.load(resources:F().resources(r,entry.target),makeControls:controls.controls,
                observe:controls.observe,afterChild:controls.afterChild,beforeCommit:{ try r.complete($0);try F().checkPublication($0,r,controls) })
            let provider = try P.Provider(loaded);var pool = try S.Input.Pool(pending:loaded)
            let p = try pool.prepare(inputs:OriginalApplicationInterfaceInputsTests.inputs.get(),makeControls:provider.controls,observe:provider.observe,beforeCommit:provider.complete)
            var input = try S.Input(pending:p,arithmeticPrecision:.bits53),env: Void = ()
            let ready = try input.advance(environment:&env,controlBoundary:{ _,_ in throw Stop.unexpected("input platform") })
            parent = .init(session:try XCTUnwrap(origin),input:ready)
        }
        return try XCTUnwrap(parent)
    }
    struct ResourcePoint: Equatable { let phase: OriginalMenuResourceCheckpoint,records: [UInt32:OriginalLoadedBitmap] }
    struct Environment: Equatable {
        var index = -1,api = 0,clock = 0
        var points: [String] = [],music: [OriginalMusicEvent] = [],front: [OriginalFrontScreenEvent] = []
        var bitmapOperations: [S.Operation] = [],expectedOperations: [S.Operation] = []
        var resourcePoints: [ResourcePoint] = []
        var reverse = false,nullSpark = false,overlap: UInt32?,stop: String?
        var committed = false
        var token: UInt32 { index == 11 ? 0x7e230020 : 0x7e200020+UInt32(reverse ? 10-index : index)*0x2000 }
        var image: UInt32 { 0x7f100000+UInt32(index)*16 }
        var surface: UInt32 { 0x7f200000+UInt32(index)*16 }
        var memoryDC: UInt32 { 0x7f300000+UInt32(index)*16 }
        var dc: UInt32 { 0x7f400000+UInt32(index)*16 }
        func pattern(_ count: Int) -> [UInt8] { (0..<count).map { reverse ? UInt8(truncatingIfNeeded:$0) : 0xa5 } }
        mutating func allocate(_ kind: S.AllocationKind,_ count: Int) throws -> OriginalInterfaceAllocation {
            let i: Int
            switch kind { case .menu(let value):i = value;case .background:i = 11 }
            XCTAssertEqual(i,index+1);XCTAssertEqual(count,0x1f50);index = i
            if stop == "allocate10" && i == 10 { throw Stop.injected("allocate10") }
            if i == 0,let overlap { return .init(address:overlap,backing:pattern(count)) }
            let a = OriginalInterfaceAllocation(address:i == 10 && nullSpark ? 0 : token,backing:i == 10 && nullSpark ? [] : pattern(count))
            expectedOperations.append(.menu(.allocate(a.address,a.backing)));return a
        }
        mutating func bitmap(_ q: S.API.Request) throws -> S.API.Response {
            api += 1
            if stop == "colorKey10",index == 10,q.kind == "colorKey" { throw Stop.injected("colorKey10") }
            switch q.kind {
            case "module":return .init(result:0x400000)
            case "image":
                XCTAssertEqual(q.strings,[Array((index == 11 ? "MENU_BACK9" : OriginalMenuResourceLoading.paths[index]).utf8)])
                // Embedded DIB: the original loader first tries LR_LOADFROMFILE,
                // then retries the same name as an application resource.
                if q.words[4] == 0x2010 { return .init() }
                guard q.words[4] == 0x2000 else { throw Stop.unexpected("image flags") }
                return .init(result:Int32(bitPattern:image))
            case "getObject":return .init(result:24)
            case "createSurface":return .init(output:surface)
            case "createDC":return .init(result:Int32(bitPattern:memoryDC))
            case "getDC":return .init(output:dc)
            case "selectObject","stretch","deleteDC","deleteObject":return .init(result:1)
            case "restore","description","releaseDC","colorKey":return .init()
            default:throw Stop.unexpected(q.kind)
            }
        }
        mutating func sound(_ e: OriginalMusicEvent) throws -> OriginalMusicResponse {
            music.append(e)
            guard e.kind == .helper || e.kind == .method && e.arguments[1] == 0x1c else { throw Stop.unexpected("uncached music") }
            let r = OriginalMusicResponse()
            if e.kind != .helper { expectedOperations.append(.music(e,r)) };return r
        }
        mutating func time() throws -> UInt32 {
            clock += 1;let value = UInt32(12344+clock);expectedOperations.append(.clock(value));return value
        }
    }
    static func output(_ target: UInt32) throws -> OriginalMenuPresentationInput {
        try JSONDecoder().decode(OriginalMenuPresentationInput.self,from:JSONSerialization.data(withJSONObject:[
            "targetSurface":target,"methodResult":0,"queryResult":0,"audioGetResult":0,"audioSetResult":0,
            "queriedAudio":0,"audioVolume":0,"dcResult":0,"dc":0x12345678,"postResult":0]))
    }
    static func advance(_ session: inout S,_ env: inout Environment) throws -> S.PendingReturn {
        let target = session.entry.entry.entry.entry.target
        return try session.advance(inputs:OriginalApplicationMenuInputsTests.inputs.get(),environment:&env,
            screenInput:.init(dcResult:0,dc:0x12345678,methodResult:0,drawResults:[0],shellResult:33),outputInput:output(target),
            allocate:{ try $2.allocate($0,$1) },bitmap:{ try $1.bitmap($0) },music:{ try $1.sound($0) },milliseconds:{ try $0.time() },
            observe:{ o,e in
                switch o {
                case .bitmap(let q,let r):e.bitmapOperations.append(.menu(.bitmap(q,r)));e.expectedOperations.append(.menu(.bitmap(q,r)))
                case .front(let f):
                    e.front.append(f)
                    switch f.kind {
                    case "blit":e.expectedOperations.append(.menu(.blit(try XCTUnwrap(f.blit),result:0)))
                    case "fill":e.expectedOperations.append(.menu(.fill(try XCTUnwrap(f.fill),result:0)))
                    case "getDC":e.expectedOperations.append(.menu(.getDC(f,result:0,output:0x12345678)))
                    case "setBackgroundMode","setTextColor","textOut","releaseDC":e.expectedOperations.append(.menu(.graphics(f,result:0)))
                    case "method":e.expectedOperations.append(.menu(.present(f,result:0)))
                    case "soundMethod":e.expectedOperations.append(.menu(.soundMethod(f,ignoredResult:0)))
                    case "enter","leave","sleep":e.expectedOperations.append(.front(f,0,nil))
                    case "shell":e.expectedOperations.append(.front(f,33,nil))
                    case "free":e.expectedOperations.append(.menu(.free(f.arguments[0])))
                    case "write","read","clip","draw","text","stringLength","soundRequest","format","panel","keyName","timer","call","return","allocate","construct":break
                    default:throw Stop.unexpected("uncompared front journal "+f.kind)
                    }
                case .resourceCheckpoint(let p,let g,let records):
                    e.resourcePoints.append(.init(phase:p,records:records))
                    if p.kind == .flag {
                        XCTAssertEqual(try g.integer(at:0x7c,as:UInt32.self),0)
                        let token = try g.integer(at:0x44f8fc-0x44d000,as:UInt32.self)
                        let spark = try XCTUnwrap(records[token])
                        XCTAssertFalse(spark.storage.defined[0x1780+13*4])
                    }
                default:break
                }
            },checkpoint:{ name,g,e in
                e.points.append(name)
                if name == "heldCleared" { XCTAssertEqual(try g.integer(at:0x457580-0x44d000,as:UInt32.self),0) }
                if name == e.stop { throw Stop.injected(name) }
            },beforeCommit:{ _,e in
                if e.stop == "commit" { throw Stop.injected("commit") };e.committed = true
            })
    }
    /// Compare every current wrapper byte/mask at each original resource
    /// checkpoint, using unchanged saved A5 and ramp source outputs only as
    /// expected data. Successful API dimensions come from our own packaged DIB.
    func compareSavedBitmaps(_ pending: S.PendingReturn,_ env: Environment) throws {
        let reverse = env.reverse
        let url = try XCTUnwrap(Bundle.module.url(forResource:"original-menu-startup"+(reverse ? "-control" : ""),withExtension:"json",subdirectory:"Fixtures"))
        let c = try JSONDecoder().decode(MenuStartupReference.Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:128_000_000))
        func blob(_ key: String) throws -> [UInt8] {
            let b = try XCTUnwrap(c.blobs[key]),bytes = try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:8_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(bytes)),key);return bytes
        }
        let view = pending.snapshot
        for i in 0..<11 {
            let record = try XCTUnwrap(c.resources.records.first { $0.address == c.resources.allocations[i].address })
            let token = UInt32(0x7e200020)+UInt32(reverse ? 10-i : i)*0x2000
            var expected = try OriginalStateRecord(bytes:blob(record.storage.bytes),defined:blob(record.storage.defined).map { $0 != 0 })
            try expected.write(UInt32(1),at:0)
            let actual = try XCTUnwrap(view.resources.bitmaps[token])
            XCTAssertEqual(actual.storage,expected,"whole source wrapper \(i)")
            var stored = expected;try stored.write(UInt32(0x7f200000+i*16),at:0)
            XCTAssertEqual(view.state.memory.allocations[token]?.storage,stored)
            XCTAssertEqual(view.state.memory.allocations[token]?.live,true)
            XCTAssertEqual(try view.match.globals.integer(at:OriginalMenuResourceLoading.slots[i]-0x44d000,as:UInt32.self),token)
            let inputs = try XCTUnwrap(view.state.bitmapInputs),colors = try inputs.sourceColors(forSurface:UInt32(0x7f200000+i*16))
            let pixels = try XCTUnwrap(OriginalApplicationMenuInputsTests.inputs.get().bitmaps[OriginalMenuResourceLoading.paths[i]]).pixels
            XCTAssertEqual(colors.width,pixels.width);XCTAssertEqual(colors.height,pixels.height)
            XCTAssertEqual(colors.rgb,pixels.rgb);XCTAssertEqual(colors.defined,pixels.defined)
        }
        XCTAssertEqual(c.resources.records.count,11)
        XCTAssertEqual(env.resourcePoints.count,c.resources.checkpoints.count)
        for (actual,expected) in zip(env.resourcePoints,c.resources.checkpoints) {
            XCTAssertEqual(actual.phase.kind,expected.kind);XCTAssertEqual(actual.phase.index,expected.index)
            XCTAssertEqual(actual.records.count,expected.records.count)
            for record in expected.records {
                let i = try XCTUnwrap(c.resources.allocations.firstIndex { $0.address == record.address })
                let token = UInt32(0x7e200020)+UInt32(reverse ? 10-i : i)*0x2000
                var source = try OriginalStateRecord(bytes:blob(record.storage.bytes),defined:blob(record.storage.defined).map { $0 != 0 })
                try source.write(UInt32(1),at:0)
                XCTAssertEqual(actual.records[token]?.storage,source,"complete resource checkpoint bytes/masks")
            }
        }
    }
    func compareGraphics(_ pending: S.PendingReturn,_ env: Environment) throws {
        typealias G = OriginalApplicationCatalogGraphicsComparison
        let startup = try OriginalApplicationStartupInputsTests.shared.get(),menu = try OriginalApplicationMenuInputsTests.inputs.get()
        var resources = startup.bitmaps;resources.merge(menu.bitmaps) { _,new in new }
        let a = try OriginalDIBPixelsTests.golden.get(),b = try OriginalApplicationMenuInputsTests.golden.get()
        var colors: [String:([UInt8],[Bool],Int,Int)] = [:]
        for (records,bytes) in [(a.reference.resources,a.payload),(b.reference.resources,b.payload)] {
            for r in records {
                colors[r.name] = (Array(bytes[r.rgbOffset..<r.rgbOffset+r.rgbCount]),Array(bytes[r.maskOffset..<r.maskOffset+r.maskCount]).map { $0 != 0 },r.width,r.height)
            }
        }
        XCTAssertEqual(Array(pending.snapshot.operations.dropFirst(pending.entry.operations.count)),env.expectedOperations)
        let projection = try G(resources:resources,state:pending.entry.state,graphics:pending.entry.graphics,colors:colors)
        var events: [G.Event] = []
        for operation in pending.snapshot.operations.dropFirst(pending.entry.operations.count) {
            guard case .menu(let e) = operation else { continue }
            switch e {
            case .bitmap(let q,let r):events.append(.init(request:q,response:r,kind:nil,event:nil))
            case .blit(let b,let r):XCTAssertEqual(r,0);var e = OriginalFrontScreenEvent("blit");e.blit = b;events.append(.init(request:nil,response:nil,kind:"front",event:e))
            case .fill(let f,let r):XCTAssertEqual(r,0);var e = OriginalFrontScreenEvent("fill");e.fill = f;events.append(.init(request:nil,response:nil,kind:"front",event:e))
            case .getDC(let e,let r,let output):XCTAssertEqual(r,0);XCTAssertEqual(output,0x12345678);events.append(.init(request:nil,response:nil,kind:"front",event:e))
            case .graphics(let e,let r),.present(let e,let r):XCTAssertEqual(r,0);events.append(.init(request:nil,response:nil,kind:"front",event:e))
            case .allocate,.soundMethod:break
            default:throw Stop.unexpected("uncompared terminal menu effect")
            }
        }
        // Independent projection consumes declared terminal operations and saved
        // RGB/masks, never Core.consume or final owner fields to form expected.
        try projection.compare(state:pending.snapshot.state,graphics:pending.graphics,events:events)
        XCTAssertEqual(projection.images.count,env.index+1)
    }
    func testOwnMenuAndExactOuterIterationWithBothBitmapBackings() throws {
        let parent = try Self.parent.get()
        XCTAssertEqual(try parent.input.match.globals.integer(at:0x4511ac-0x44d000,as:UInt32.self),0)
        for reverse in [false,true] {
            var session = try S(pending:parent.input),env = Environment(reverse:reverse)
            let pending = try Self.advance(&session,&env),view = pending.snapshot
            XCTAssertEqual(pending.exit,.returned);XCTAssertEqual(pending.dispatcherResult,1)
            // Eleven menu resources are followed by the background required
            // by this parent's already-zero current background slot.
            XCTAssertEqual(env.index,11);XCTAssertTrue(env.committed)
            XCTAssertEqual(Set(view.backgrounds.keys),[UInt32(0x7e230020)])
            XCTAssertEqual(view.backgrounds[0x7e230020]?.input.path,"MENU_BACK9")
            XCTAssertEqual(try view.match.globals.integer(at:0x4511ac-0x44d000,as:UInt32.self),0x7e230020)
            XCTAssertEqual(env.music.map(\.kind),[.helper,.method])
            XCTAssertEqual(env.music.first?.arguments,[0x402020]);XCTAssertEqual(env.music.last?.arguments[1],0x1c)
            XCTAssertEqual(view.music.allocations,parent.input.music.allocations)
            try compareSavedBitmaps(pending,env)
            try compareGraphics(pending,env)
            try I.coherent(S.Input(pending:parent.input.entry,arithmeticPrecision:.bits53).bindings,view.match,view.state)
            XCTAssertEqual(view.match.actors,parent.input.match.actors);XCTAssertEqual(view.match.world,parent.input.match.world)
            XCTAssertEqual(view.match.frameAllocations,parent.input.match.frameAllocations)
            XCTAssertEqual(view.state.random,parent.input.state.random)
            for (token,allocation) in parent.input.state.memory.allocations { XCTAssertEqual(view.state.memory.allocations[token],allocation) }
            XCTAssertEqual(try I.slice(view.state.full,0xb440,0x6c0),try I.slice(parent.input.state.full,0xb440,0x6c0))
            XCTAssertEqual(try I.slice(view.state.full,0xc2d8,0xd0),try I.slice(parent.input.state.full,0xc2d8,0xd0))
            XCTAssertEqual(view.local.defined.filter { $0 }.count,108)
            XCTAssertEqual(Array(view.operations.prefix(parent.input.operations.count)),parent.input.operations.map(S.Operation.preceding))
            XCTAssertEqual(view.operations.filter { if case .menu(.bitmap) = $0 { return true };return false },env.bitmapOperations)
            XCTAssertEqual(Array(pending.graphics.prefix(parent.input.graphics.count)),parent.input.graphics)
            XCTAssertEqual(pending.graphics.count-parent.input.graphics.count,env.api+env.front.filter { ["blit","fill","getDC","setBackgroundMode","setTextColor","textOut","releaseDC","method"].contains($0.kind) }.count)
            XCTAssertEqual(env.points.suffix(6),["screen","menuReturned","matchBeforeReturn","loadingReturned","heldCleared","earlyReturned"])
            var owner = parent.session,tail: [String] = []
            let complete = try owner.finishLoadedMenu(pending,environment:&tail,perform:{ q,e in
                e.append(q.kind.rawValue)
                guard q.kind == .time else { throw Stop.unexpected(q.kind.rawValue) }
                return .init(result:123_457_923)
            },beforeCommit:{ loop,state,e in
                XCTAssertEqual(try state.full.integer(at:0xb580,as:UInt32.self),loop.counter);e.append("commit")
            })
            XCTAssertEqual(tail,["time","commit"]);XCTAssertEqual(complete.result,.continued)
            XCTAssertEqual(complete.operations,pending.snapshot.operations+[.loop(.init(.time),.init(result:123_457_923))])
            XCTAssertEqual(complete.graphics,pending.graphics)
            XCTAssertEqual(owner.loop.counter,parent.session.loop.counter &+ 1)
            // Original case47 dispatch checkpoint: baseline123456923,
            // counter7, target argument1. The tail clock is declared Native IO.
            XCTAssertEqual(owner.loop.timer.baseline,123_456_923)
            XCTAssertEqual(owner.loop.counter,8)
            XCTAssertEqual(owner.loop.message,parent.session.loop.message)
            var expectedState = view.state,expectedFull = view.state.full
            try expectedFull.write(UInt32(8),at:0xb580);try expectedState.replace(0,expectedFull)
            OriginalApplicationCatalogSessionTests.retained(owner.state,expectedState)
            XCTAssertEqual(owner.state.earlyScreen.bitmaps,expectedState.earlyScreen.bitmaps)
            XCTAssertEqual(owner.state.earlyScreen.surfaces,expectedState.earlyScreen.surfaces)
            XCTAssertEqual(owner.state.earlyScreen.retainedOperation,expectedState.earlyScreen.retainedOperation)
            XCTAssertEqual(owner.state.memory.allocations,view.state.memory.allocations)
            XCTAssertEqual(owner.state.libraryText,view.state.libraryText)
            XCTAssertEqual(owner.state.graphics,view.state.graphics)
            XCTAssertThrowsError(try owner.finishLoadedMenu(pending,environment:&tail,perform:{ _,_ in throw Stop.unexpected("repeated IO") }))
            XCTAssertThrowsError(try Self.advance(&session,&env))
            print("Owned menu complete: \(env.api)bitmap API/11 wrappers/full source masks; \(env.front.count)front events/\(env.clock)menu clocks; real dispatcher1/retained outer tail; reverse=\(reverse)")
        }
    }
    func testLateMenuAndOuterFailuresRetainAllOwnersAndRetry() throws {
        let parent = try Self.parent.get()
        for name in ["music","allocate10","colorKey10","resource.flag.-1","startup","screen","matchBeforeReturn","heldCleared","commit"] {
            var s = try S(pending:parent.input),env = Environment(stop:name);let initial = env
            XCTAssertThrowsError(try Self.advance(&s,&env)) { XCTAssertEqual($0 as? Stop,.injected(name)) }
            XCTAssertEqual(env,initial);XCTAssertNil(s.pendingReturn)
            OriginalApplicationCatalogSessionTests.retained(s.entry.state,parent.input.state)
        }
        var s = try S(pending:parent.input),env = Environment();let pending = try Self.advance(&s,&env)
        for at in ["time","sleep","commit"] {
            var owner = parent.session,e: [String] = []
            XCTAssertThrowsError(try owner.finishLoadedMenu(pending,environment:&e,perform:{ q,buffer in
                buffer.append(q.kind.rawValue)
                if q.kind == .sleep { XCTAssertEqual(q.arguments,[5]);throw Stop.injected("sleep") }
                if at == "time" { throw Stop.injected(at) }
                return .init(result:at == "sleep" ? 1_000_000 : 123_457_923)
            },beforeCommit:{ _,_,buffer in buffer.append("commit");throw Stop.injected(at) })) { XCTAssertEqual($0 as? Stop,.injected(at)) }
            XCTAssertEqual(e,[]);OriginalApplicationCatalogSessionTests.retained(owner.state,parent.session.state)
            XCTAssertEqual(owner.loop.counter,parent.session.loop.counter);XCTAssertEqual(owner.loop.message,parent.session.loop.message)
            _ = try owner.finishLoadedMenu(pending,environment:&e,perform:{ q,buffer in buffer.append(q.kind.rawValue);return .init(result:123_457_923) })
            XCTAssertEqual(e,["time"])
        }
    }
    func testDeclaredMissingBackgroundLoadsWithoutReplacingOldOwners() throws {
        let p = try Self.parent.get().input
        // Explicit idempotent zero control: the actual parent already has no
        // current background. This adds no distinct original branch coverage.
        XCTAssertEqual(try p.match.globals.integer(at:0x4511ac-0x44d000,as:UInt32.self),0)
        var model = p.match,state = p.state
        try model.globals.write(UInt32(0),at:0x4511ac-0x44d000)
        try state.replace(0,model.globals)
        let input = S.Input.PendingContinuation(entry:p.entry,state:state,match:model,inputContext:p.inputContext,music:p.music,
            commands:p.commands,playbackCommands:p.playbackCommands,paused:p.paused,round:p.round,operations:p.operations,graphics:p.graphics)
        var session = try S(pending:input),e = Environment()
        let result = try Self.advance(&session,&e),view = result.snapshot
        XCTAssertEqual(e.index,11);XCTAssertGreaterThanOrEqual(e.clock,1)
        XCTAssertEqual(try view.match.globals.integer(at:0x4511ac-0x44d000,as:UInt32.self),0x7e230020)
        let background = try XCTUnwrap(view.backgrounds[0x7e230020])
        XCTAssertEqual(background.input.path,"MENU_BACK9")
        var expected = background.storage;try expected.write(UInt32(0x7f200000+11*16),at:0)
        XCTAssertEqual(view.state.memory.allocations[0x7e230020]?.storage,expected)
        for (token,allocation) in p.state.memory.allocations { XCTAssertEqual(view.state.memory.allocations[token],allocation) }
        XCTAssertEqual(view.state.earlyScreen.bitmaps,p.state.earlyScreen.bitmaps)
        XCTAssertTrue(e.front.contains { $0.kind == "blit" && $0.blit?.sourceSurface == 0x7f200000+11*16 })
        try compareGraphics(result,e)
    }
    func testMenuReturnRequestsItsClockOnlyAtTheActualTimerBranch() throws {
        let p = try Self.parent.get(),target = p.input.entry.entry.entry.target
        for menu: Int32 in [0,10] {
            var world = p.input.match.world,globals = p.input.match.globals,memory = p.input.state.memory,text = p.input.state.libraryText
            try globals.write(menu,at:0x20)
            var calls = 0,events: [OriginalFrontScreenEvent] = []
            try OriginalMenuReturn.advanceWithLibrary(world:&world,globals:&globals,memory:&memory,libraryText:&text,
                input:Self.output(target),milliseconds:99,fillBacking:[UInt8](repeating:0,count:100),wholeEarlyReturn:true,
                readMilliseconds:{ calls += 1;return 0xfedcba98 },draw:{ _,_,_ in throw Stop.unexpected("timer control draw") },observe:{ events.append($0) })
            XCTAssertEqual(calls,menu == 0 ? 1 : 0)
            XCTAssertEqual(events.filter { $0.kind == "timer" }.map(\.arguments),menu == 0 ? [[0xfedcba98]] : [])
            if menu == 0 { XCTAssertEqual(try globals.integer(at:0x451154-0x44d000,as:UInt32.self),0xfedcba98) }
            XCTAssertEqual(try globals.integer(at:0x457580-0x44d000,as:UInt32.self),0)
        }
    }
    func testForeignStaleAndOverlappingOwnersAreRejected() throws {
        let p = try Self.parent.get()
        let catalog = p.input.entry.entry
        let tokens = [UInt32(0x44d000),p.input.entry.actorTokens[0],p.input.entry.interfaceTokens[0],
            try XCTUnwrap(p.input.music.allocations.keys.first),try XCTUnwrap(catalog.snapshot.allocations.first?.token)]
        for token in tokens {
            var s = try S(pending:p.input),e = Environment(overlap:token);let before = e
            XCTAssertThrowsError(try Self.advance(&s,&e)) { XCTAssertEqual($0 as? S.Boundary,.overlap(token)) }
            XCTAssertNil(s.pendingReturn);XCTAssertEqual(e,before)
        }
        var s = try S(pending:p.input),e = Environment(nullSpark:true);let before = e
        XCTAssertThrowsError(try Self.advance(&s,&e)) { XCTAssertEqual($0 as? OriginalCharacterMenuStartupError,.nullSpark) }
        XCTAssertEqual(e,before);XCTAssertNil(s.pendingReturn)
        e = Environment();let pending = try Self.advance(&s,&e)
        var foreign = try OriginalApplicationMenuSession(state:p.session.state,loop:p.session.loop),tail: [String] = []
        XCTAssertThrowsError(try foreign.finishLoadedMenu(pending,environment:&tail,perform:{ _,_ in throw Stop.unexpected("foreign IO") }))
        XCTAssertTrue(tail.isEmpty)
        var stale = p.session
        _ = try stale.step(responses:.init(draw:0,presentation:0,sound:0,release:0,dcResult:0,dc:0),queue:{ q in
            switch q.kind {
            case .peek:return .init(result:1)
            case .get:return .init(result:0,writes:[.init(offset:8,bytes:[0,0,0,0])])
            default:throw Stop.unexpected("stale prefix")
            }
        },windowDefault:{ _ in throw Stop.unexpected("WndProc") },surface:{ _ in throw Stop.unexpected("surface") })
        XCTAssertThrowsError(try stale.finishLoadedMenu(pending,environment:&tail,perform:{ _,_ in throw Stop.unexpected("stale IO") }))
        XCTAssertTrue(tail.isEmpty)
    }
}
