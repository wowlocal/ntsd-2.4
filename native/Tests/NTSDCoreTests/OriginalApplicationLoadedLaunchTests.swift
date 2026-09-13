import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationLoadedLaunchTests: XCTestCase {
    typealias M = OriginalApplicationLoadedMenuTests
    typealias C = OriginalApplicationLoadedCycleTests
    typealias H = OriginalApplicationLoadedCharacterTests
    typealias L = OriginalApplicationMatchLaunchSession
    typealias R = OriginalApplicationLoadedLaunchComparison
    typealias Stop = M.Stop
    struct Environment {
        var layers = 0,api = 0,music = 0,times = 0,recordings = 0,clocks = 0
        var requests: [L.API.Request] = [],front: [OriginalFrontScreenEvent] = []
        var preparation: [[Int32]] = [],points: [String] = []
        var snapshots: [String:M.S.Snapshot] = [:]
        var stop: String?,replayAddress: UInt32 = R.replay
        var generation: UInt32 = 0
        mutating func check(_ name: String) throws { if name == stop { throw Stop.injected(name) } }
        static func wrapper(_ i: Int) -> UInt32 { 0x77010020+UInt32(i)*0x2000 }
        static func surface(_ i: Int) -> UInt32 { 0x74100000+UInt32(i)*16 }
        mutating func allocate(_ index: Int,_ count: Int) throws -> OriginalInterfaceAllocation {
            XCTAssertEqual(index,layers);XCTAssertEqual(count,0x1f50);layers += 1
            try check("allocate\(index)")
            return .init(address:Self.wrapper(index)+generation*0x100000,backing:[UInt8](repeating:0xa5,count:count))
        }
        mutating func bitmap(_ q: L.API.Request) throws -> L.API.Response {
            requests.append(q);api += 1;let i = layers-1
            try check(q.kind+"\(i)")
            switch q.kind {
            case "module":return .init(result:0x400000)
            case "image":XCTAssertEqual(q.words[4],0x2010);return .init(result:Int32(bitPattern:0x74000000+UInt32(i)*16+generation*0x10000))
            case "getObject":return .init(result:24)
            case "createSurface":return .init(output:Self.surface(i)+generation*0x10000)
            case "createDC":return .init(result:Int32(bitPattern:0x74200000+UInt32(i)*16+generation*0x10000))
            case "getDC":return .init(output:0x74300000+UInt32(i)*16+generation*0x10000)
            case "selectObject","stretch","deleteDC","deleteObject":return .init(result:1)
            case "restore","description","releaseDC","colorKey","release":return .init()
            default:throw Stop.unexpected("Launch bitmap "+q.kind)
            }
        }
        mutating func observe(_ o: M.S.Observation) throws {
            switch o {
            case .front(let e):front.append(e);try check(e.kind)
            case .preparation(let e):
                switch e {
                case .reconstruct(let i):preparation.append([0,Int32(i)])
                case .random(let s,let r,let v,let bi,let bc,let i,let c):preparation.append([1,s,r,v,Int32(bi),Int32(bc),Int32(i),Int32(c)])
                case .releaseLayers(let i):preparation.append([2,Int32(i)])
                case .loadLayers(let i):preparation.append([3,Int32(i)])
                case .resetInput:preparation.append([4]);try check("resetInput")
                case .resumeMusic:preparation.append([5])
                case .musicPath:preparation.append([6])
                }
            case .launchCheckpoint(let name,let s):points.append(name);snapshots[name] = s;try check(name)
            default:break
            }
        }
    }
    static let inputs = Result { try OriginalApplicationArenaInputs.bundled() }
    func launch(_ session: inout L,_ env: inout Environment,_ r: R) throws -> M.S.PendingReturn {
        try session.advance(environment:&env,bitmaps:Self.inputs.get().bitmaps,outputInput:M.output(session.entry.loading.target),
            allocateBitmap:{ try $2.allocate($0,$1) },bitmap:{ try $1.bitmap($0) },localTime:{ e in
                e.times += 1;try e.check("localTime");return R.time
            },music:{ q,e in
                let index = e.music;e.music += 1;try e.check("music\(index)");return try r.music(q,index)
            },allocateReplay:{ count,e in
                XCTAssertEqual(count,0x630e18);e.recordings += 1;try e.check("calloc");return e.replayAddress
            },milliseconds:{ e in e.clocks += 1;try e.check("clock");return R.timer },
            observe:{ try $1.observe($0) },beforeCommit:{ _,e in try e.check("commit") })
    }
    func compare(_ result: M.S.PendingReturn,_ e: Environment,_ r: R) throws {
        XCTAssertEqual(e.layers,15);XCTAssertEqual(e.times,1);XCTAssertEqual(e.music,27);XCTAssertEqual(e.recordings,1);XCTAssertEqual(e.clocks,1)
        XCTAssertEqual(e.points,["entry","prelude","preparation","music","tail","recording","menu","menuReturned","matchBeforeReturn","loadingReturned","heldCleared","earlyReturned"])
        for (i,name) in ["prelude","preparation","music","tail","recording","menu"].enumerated() { try r.state(i,XCTUnwrap(e.snapshots[name])) }
        try r.state(6,result.snapshot)
        var expected: [[Int32]] = [],draw = 0
        for event in (r.corpus.cases[1].events ?? [])+(r.corpus.cases[3].events ?? []) {
            switch event.kind {
            case "reconstruct":expected.append([0,Int32(try XCTUnwrap(event.slot))])
            case "releaseLayers":expected.append([2,Int32(try XCTUnwrap(event.index))])
            case "loadLayers":expected.append([3,Int32(try XCTUnwrap(event.index))]);expected += [[5],[6]]
            case "resetInput":expected.append([4])
            case "random":
                expected.append([1,try XCTUnwrap(event.stream),try XCTUnwrap(event.range),[177,53,189,18][draw],Int32(35+draw),Int32(35+draw),Int32(36+draw),Int32(36+draw)]);draw += 1
            default:throw Stop.unexpected("Source preparation event "+event.kind)
            }
        }
        XCTAssertEqual(e.preparation,expected);XCTAssertEqual(draw,4)
        XCTAssertEqual(e.front.filter { $0.kind == "soundMethod" }.map(\.arguments),[[0x24001010,0x48],[0x24001010,0x34,0],[0x24001010,0x30,0,0,0]])
        XCTAssertEqual(e.requests.filter { $0.kind == "image" }.map { String(decoding:$0.strings[0],as:UTF8.self) },r.corpus.cases[1].newBitmaps?.map(\.path))
        XCTAssertFalse(e.requests.contains { $0.kind == "release" });XCTAssertFalse(e.front.contains { $0.kind == "free" })
        let own = result.snapshot,old = r.initial.snapshot,new = Array(own.match.bitmaps.dropFirst(old.match.bitmaps.count))
        XCTAssertEqual(new.count,15);XCTAssertEqual(own.match.bitmapOwners.count,old.match.bitmapOwners.count+15)
        XCTAssertEqual(Array(own.match.bitmaps.prefix(old.match.bitmaps.count)),old.match.bitmaps)
        var expectedOperations: [M.S.Operation] = [.localTime(R.time)]
        for arguments: [UInt32] in [[0x24001010,0x48],[0x24001010,0x34,0],[0x24001010,0x30,0,0,0]] {
            expectedOperations.append(.menu(.soundMethod(.init("soundMethod",arguments),ignoredResult:0)))
        }
        typealias G = OriginalApplicationCatalogGraphicsComparison
        var graphicsEvents: [G.Event] = [],colors: [String:([UInt8],[Bool],Int,Int)] = [:]
        let inputs = try Self.inputs.get().bitmaps
        for (path,input) in inputs { colors[path] = try R.pixels(input) }
        for (i,b) in new.enumerated() {
            let wrapper = Environment.wrapper(i),surface = Environment.surface(i)
            XCTAssertEqual(own.match.bitmapOwners[old.match.bitmaps.count+i],wrapper)
            XCTAssertEqual(own.state.memory.allocations[wrapper]?.live,true)
            var normalized = try XCTUnwrap(own.state.memory.allocations[wrapper]).storage
            XCTAssertEqual(try normalized.integer(at:0,as:UInt32.self),surface);try normalized.write(UInt32(1),at:0)
            try r.equal(normalized,b.storage,"arena current wrapper\(i)")
            XCTAssertEqual(try own.match.backgrounds[0].integer(at:0x914+i*4,as:UInt32.self),UInt32(old.match.bitmaps.count+i+1))
            let colors = try XCTUnwrap(own.state.bitmapInputs).sourceColors(forSurface:surface)
            let input = try XCTUnwrap(Self.inputs.get().bitmaps[b.input.path])
            let rgb = try R.pixels(input)
            XCTAssertEqual(colors.rgb,rgb.0);XCTAssertEqual(colors.defined,rgb.1)
            XCTAssertEqual(colors.width,input.pixels.width);XCTAssertEqual(colors.height,input.pixels.height)
            XCTAssertEqual(b.input.present,true);XCTAssertEqual(b.input.width,Int32(rgb.2));XCTAssertEqual(b.input.height,Int32(rgb.3));XCTAssertFalse(b.optional)
            let source = r.corpus.cases[1].after.bitmaps[old.match.bitmaps.count+10+i]
            var expected = try OriginalStateRecord(bytes:r.bytes(source.storage.bytes),defined:r.bytes(source.storage.defined).map { $0 != 0 })
            try expected.write(UInt32(1),at:0);try r.equal(b.storage,expected,"saved complete arena bitmap\(i)")
            let calls = try r.bitmapEvents(i,b.input.path,input);graphicsEvents += calls
            expectedOperations.append(.menu(.allocate(wrapper,[UInt8](repeating:0xa5,count:0x1f50))))
            for call in calls { expectedOperations.append(.menu(.bitmap(try XCTUnwrap(call.request),try XCTUnwrap(call.response)))) }
        }
        XCTAssertEqual(e.requests,graphicsEvents.compactMap(\.request))
        let music = try XCTUnwrap(r.corpus.cases[2].music).events
        // Request projection is independently checked by the provider. Recover
        // the projected request sequence from that same immutable event schema.
        let recordedMusic = Array(own.operations.dropFirst(old.operations.count)).compactMap { operation -> (OriginalMusicEvent,OriginalMusicResponse)? in
            if case .music(let q,let response) = operation { return (q,response) };return nil
        }
        XCTAssertEqual(recordedMusic.count,music.filter { $0.kind != .helper && $0.kind != .format }.count)
        var eventIndex = 0
        for (i,source) in music.enumerated() where source.kind != .helper && source.kind != .format {
            guard eventIndex < recordedMusic.count else { throw Stop.unexpected("Missing terminal music") }
            let (q,response) = recordedMusic[eventIndex];eventIndex += 1
            XCTAssertEqual(response,try r.music(q,i));expectedOperations.append(.music(q,response))
        }
        expectedOperations.append(.recordingAllocation(R.replay,0x630e18))
        let returning = try r.returnEvents()
        var expectedFront: [OriginalFrontScreenEvent] = [.init("soundRequest",[0])]
        expectedFront += [[UInt32(0x24001010),0x48],[0x24001010,0x34,0],[0x24001010,0x30,0,0,0]].map { .init("soundMethod",$0) }
        XCTAssertEqual(e.front,expectedFront+returning)
        for event in returning {
            switch event.kind {
            case "getDC":expectedOperations.append(.menu(.getDC(event,result:0,output:0x12345678)))
            case "setBackgroundMode","setTextColor","textOut","releaseDC":expectedOperations.append(.menu(.graphics(event,result:0)))
            case "method":expectedOperations.append(.menu(.present(event,result:0)))
            case "timer":expectedOperations.append(.clock(R.timer));continue
            case "format","stringLength":continue
            default:throw Stop.unexpected("Return projection "+event.kind)
            }
            graphicsEvents.append(.init(request:nil,response:nil,kind:"front",event:event))
        }
        let appended = Array(own.operations.dropFirst(old.operations.count))
        XCTAssertEqual(Array(own.operations.prefix(old.operations.count)),old.operations)
        XCTAssertEqual(appended,expectedOperations)
        let projection = try G(resources:inputs,state:old.state,graphics:r.initial.graphics,colors:colors)
        try projection.compare(state:own.state,graphics:result.graphics,events:graphicsEvents)
        var expectedBG = old.match.backgrounds[0]
        for i in 0..<15 { try expectedBG.write(UInt32(old.match.bitmaps.count+i+1),at:0x914+i*4) }
        try r.equal(own.match.backgrounds[0],expectedBG,"whole owned District")
        for i in 1..<old.match.backgrounds.count { XCTAssertEqual(own.match.backgrounds[i],old.match.backgrounds[i]) }
        XCTAssertEqual(own.match.releasedBitmapOrder,[])
        XCTAssertEqual(Set(own.state.memory.allocations.keys),Set(old.state.memory.allocations.keys).union((0..<15).map(Environment.wrapper)).union([R.replay]))
        let actorTokens = Set(r.initial.entry.entry.actorTokens)
        for (token,a) in old.state.memory.allocations where !actorTokens.contains(token) { XCTAssertEqual(own.state.memory.allocations[token],a) }
        XCTAssertEqual(own.music.allocations.count,old.music.allocations.count+1)
        for (token,a) in old.music.allocations { XCTAssertEqual(own.music.allocations[token],a) }
        let wide = try XCTUnwrap(own.music.allocations[R.musicBuffer])
        XCTAssertEqual(wide.bytes,(R.path+[0]).flatMap { [$0,UInt8(0)] });XCTAssertTrue(wide.defined.allSatisfy { $0 })
        XCTAssertEqual(try own.state.memory.replayPointers.integer(at:0,as:UInt32.self),R.replay)
        XCTAssertEqual(Array(own.state.memory.replayPointers.bytes[4..<8]),Array(old.state.memory.replayPointers.bytes[4..<8]))
        try r.replay(XCTUnwrap(own.state.memory.allocations[R.replay]).storage,own.match)
        XCTAssertEqual(Array(own.state.full.bytes[0xb588..<0xb8a8]),Array(old.state.full.bytes[0xb588..<0xb8a8]))
        XCTAssertEqual(Array(own.state.full.defined[0xb588..<0xb8a8]),Array(old.state.full.defined[0xb588..<0xb8a8]))
        for range in [0xb440..<0xb8a8,0xb8b0..<0xbb00,0xc2d8..<0xc3a8] {
            XCTAssertEqual(Array(own.state.full.bytes[range]),Array(old.state.full.bytes[range]))
            XCTAssertEqual(Array(own.state.full.defined[range]),Array(old.state.full.defined[range]))
        }
        XCTAssertEqual(Array(own.state.memory.replayPointers.defined[4..<8]),Array(old.state.memory.replayPointers.defined[4..<8]))
        XCTAssertEqual(own.state.front.bitmaps,old.state.front.bitmaps);XCTAssertEqual(own.state.screenBody,old.state.screenBody)
        XCTAssertEqual(own.state.settings,old.state.settings);XCTAssertEqual(own.state.earlyScreen.bitmaps,old.state.earlyScreen.bitmaps)
        XCTAssertEqual(own.state.earlyScreen.surfaces,old.state.earlyScreen.surfaces);XCTAssertEqual(own.state.earlyScreen.retainedOperation,old.state.earlyScreen.retainedOperation)
        XCTAssertEqual(own.state.libraryText.retainedDC,old.state.libraryText.retainedDC)
        XCTAssertEqual(own.match.libraryCommands?.requestedObjectID,0)
        XCTAssertEqual(Array(result.graphics.prefix(r.initial.graphics.count)),r.initial.graphics)
        XCTAssertEqual(try own.match.globals.integer(at:0x457580-0x44d000,as:UInt32.self),0)
        let present = try H.present(own.match.globals)
        XCTAssertEqual(e.front.filter { $0.kind == "method" || $0.kind == "blit" },[present])
    }
    func testOwnStartPreparesDistrictRecordsAndReachesGameplay() throws {
        for reverse in [false,true] {
            _ = try OriginalApplicationLoadedSelectionTests().sequence(reverse,onStart:{ origin,pending in
                let r = try R(reverse,pending);var app = origin,session = try L(pending:pending),env = Environment()
                let returned = try self.launch(&session,&env,r);try self.compare(returned,env,r)
                try C.unchanged(app,origin);try C.finish(&app,returned)
                XCTAssertEqual(app.session?.loadedOwners?.match.libraryCommands?.requestedObjectID,0)
                XCTAssertEqual(app.session?.loadedOwners?.match.bitmapOwners,returned.snapshot.match.bitmapOwners)
                XCTAssertThrowsError(try C.finish(&app,returned))
                let entry = try C.next(&app);var cycle = try app.makeLoadedCycle(pending:entry),input = C.InputEnvironment()
                let next = try C.input(&cycle,&input)
                let snapshot = M.S.Snapshot(state:next.state,match:next.match,music:next.music,resources:next.menuResources,
                    backgrounds:next.menuBackgrounds,local:returned.snapshot.local,operations:[])
                try r.state(7,snapshot)
                XCTAssertEqual(next.round.continuation,.gameplay);XCTAssertFalse(next.paused)
                XCTAssertEqual(input.phases,[Int32](repeating:1,count:6));XCTAssertTrue(input.requests.isEmpty)
                XCTAssertEqual(next.commands,[UInt8](repeating:0,count:10));XCTAssertEqual(next.match.libraryCommands?.requestedObjectID,0)
                XCTAssertEqual(next.match.bitmapOwners,returned.snapshot.match.bitmapOwners)
                XCTAssertEqual(next.match.backgrounds,returned.snapshot.match.backgrounds);XCTAssertEqual(next.match.bitmaps,returned.snapshot.match.bitmaps)
                XCTAssertEqual(next.music.allocations,returned.snapshot.music.allocations)
                let recording = try XCTUnwrap(next.state.memory.allocations[R.replay]).storage
                var expected = try XCTUnwrap(returned.snapshot.state.memory.allocations[R.replay]).storage
                try expected.write(Int32(1000),at:0x14b8);try r.equal(recording,expected,"first gameplay recording")
                XCTAssertEqual(try next.match.globals.integer(at:0x450bd0-0x44d000,as:Int32.self),1)
                for point in ["replay","round","commit"] {
                    var failed = try app.makeLoadedCycle(pending:entry),attempt = C.InputEnvironment(stop:point)
                    XCTAssertThrowsError(try C.input(&failed,&attempt))
                    XCTAssertTrue(attempt.points.isEmpty);XCTAssertTrue(failed.pendingContinuation == nil)
                }
                print("Owned installed launch: prelude/preparation/music/tail/replay/menu/Bootstrap return/next gameplay boundary;15 surfaces,382 constructors,4 own draws,234 replay array words; reverse=\(reverse)")
            })
        }
    }
    func testLaunchFailuresPreserveTheRetainedStartAndAllEarlierCommits() throws {
        _ = try OriginalApplicationLoadedSelectionTests().sequence(false,onStart:{ app,pending in
            let r = try R(false,pending)
            for stop in ["localTime","soundMethod","allocate14","createSurface14","colorKey14","music2","music7","music18","music19","resetInput","calloc","recording","method","clock","heldCleared","commit"] {
                var session = try L(pending:pending),env = Environment(stop:stop)
                XCTAssertThrowsError(try self.launch(&session,&env,r)) { XCTAssertEqual($0 as? Stop,.injected(stop)) }
                XCTAssertTrue(session.pendingReturn == nil);XCTAssertEqual(env.layers,0);XCTAssertEqual(env.music,0)
                XCTAssertTrue(env.points.isEmpty);XCTAssertTrue(env.front.isEmpty);XCTAssertTrue(env.requests.isEmpty)
            }
            var session = try L(pending:pending),env = Environment(replayAddress:pending.entry.entry.actorTokens[0])
            XCTAssertThrowsError(try self.launch(&session,&env,r)) { XCTAssertEqual($0 as? M.S.Boundary,.overlap(pending.entry.entry.actorTokens[0])) }
            XCTAssertTrue(session.pendingReturn == nil);XCTAssertEqual(env.layers,0)
            env = .init();let complete = try self.launch(&session,&env,r);try self.compare(complete,env,r)
            XCTAssertThrowsError(try self.launch(&session,&env,r)) { XCTAssertEqual($0 as? M.S.Boundary,.alreadyPrepared) }
            try self.retainedControl(complete)
        })
    }

    /// Controlled continuation from our returned owners, not a second saved
    /// source launch or a played fight. Exercises new live resource wiring.
    func retainedControl(_ parent: M.S.PendingReturn) throws {
        let pending = M.S.PendingMatchPrelude(entry:parent.entry,snapshot:parent.snapshot,confirmation:1,locals:[:],graphics:parent.graphics)
        func run(_ session: inout L,_ env: inout Environment) throws -> M.S.PendingReturn {
            try session.advance(environment:&env,bitmaps:Self.inputs.get().bitmaps,outputInput:M.output(pending.loading.target,dc:0x1234abcd),
                allocateBitmap:{ try $2.allocate($0,$1) },bitmap:{ try $1.bitmap($0) },localTime:{ _ in R.time },
                music:{ q,e in
                    let expected: [OriginalMusicEvent] = [.init(.helper,[0x402020],[R.path]),.init(.method,[R.musicBase+0x100,0x1c])]
                    guard e.music < expected.count else { throw Stop.unexpected("Retained music") }
                    XCTAssertEqual(q,expected[e.music]);e.music += 1;return .init()
                },allocateReplay:{ count,e in
                    XCTAssertEqual(count,0x630e18);e.recordings += 1;try e.check("calloc");return e.replayAddress
                },milliseconds:{ _ in R.timer },observe:{ try $1.observe($0) })
        }
        for stop in ["free","calloc","recording"] {
            var session = try L(pending:pending),env = Environment(stop:stop,replayAddress:0x80800020,generation:1)
            XCTAssertThrowsError(try run(&session,&env)) { XCTAssertEqual($0 as? Stop,.injected(stop)) }
            XCTAssertEqual(env.layers,0);XCTAssertEqual(env.recordings,0);XCTAssertTrue(env.requests.isEmpty)
            XCTAssertTrue(session.pendingReturn == nil)
        }
        // The old pointer was freed in the staged attempt, but the monotonic
        // logical identity domain does not silently revive a retired generation.
        var reuse = try L(pending:pending),reuseEnv = Environment(generation:1)
        XCTAssertThrowsError(try run(&reuse,&reuseEnv)) { XCTAssertEqual($0 as? M.S.Boundary,.overlap(R.replay)) }
        XCTAssertTrue(reuse.pendingReturn == nil);XCTAssertEqual(reuseEnv.layers,0)
        var session = try L(pending:pending),env = Environment(replayAddress:0x80800020,generation:1)
        let result = try run(&session,&env)
        XCTAssertEqual(env.requests.filter { $0.kind == "release" }.map(\.words),(0..<15).map { [Environment.surface($0)] })
        // Bitmap frees are API effects; the front free here is the old replay.
        XCTAssertEqual(env.front.filter { $0.kind == "free" }.map(\.arguments),[[R.replay]])
        XCTAssertEqual(result.snapshot.state.memory.allocations[R.replay]?.live,false)
        XCTAssertEqual(result.snapshot.state.memory.allocations[0x80800020]?.live,true)
        for i in 0..<15 {
            XCTAssertEqual(result.snapshot.state.memory.allocations[Environment.wrapper(i)]?.live,false)
            XCTAssertEqual(result.snapshot.state.bitmapInputs?.surfaces[Environment.surface(i)]?.releaseResults,[0])
        }
        XCTAssertEqual(result.snapshot.music.allocations,parent.snapshot.music.allocations)
        XCTAssertEqual(result.snapshot.match.libraryCommands?.requestedObjectID,0)
        try result.snapshot.state.validateAliases()
        // A declared waiting-notice control forces a changed text DC. Each
        // intermediate snapshot must own that new value, not just the final one.
        var noticeModel = parent.snapshot.match,noticeState = parent.snapshot.state
        try noticeModel.globals.write(Int32(1),at:0x44d058-0x44d000)
        try noticeModel.globals.write(Int8(1),at:0x44f1af-0x44d000)
        try noticeState.replace(0,noticeModel.globals)
        let snapshot = M.S.Snapshot(state:noticeState,match:noticeModel,music:parent.snapshot.music,
            resources:parent.snapshot.resources,backgrounds:parent.snapshot.backgrounds,local:parent.snapshot.local,operations:parent.snapshot.operations)
        var notice = try L(pending:.init(entry:parent.entry,snapshot:snapshot,confirmation:1,locals:[:],graphics:parent.graphics))
        var noticeEnv = Environment(replayAddress:0x80800020,generation:1)
        let returned = try run(&notice,&noticeEnv)
        XCTAssertEqual(noticeEnv.snapshots["menuReturned"]?.state.libraryText.retainedDC,parent.snapshot.state.libraryText.retainedDC)
        for name in ["matchBeforeReturn","loadingReturned","heldCleared","earlyReturned"] {
            XCTAssertEqual(noticeEnv.snapshots[name]?.state.libraryText.retainedDC,0x1234abcd)
        }
        XCTAssertEqual(returned.snapshot.state.libraryText.retainedDC,0x1234abcd)
    }
}
