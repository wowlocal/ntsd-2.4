import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Controlled provider/owner trials starting from the actual retained launch.
/// These do not substitute for the source-first whole-body comparison.
final class OriginalApplicationGameplayProviderTests: XCTestCase {
    typealias T = OriginalApplicationGameplayTests
    typealias L = T.L
    typealias C = T.C
    typealias M = T.M
    typealias G = T.G
    typealias P = OriginalApplicationInputSession.PendingContinuation
    struct Environment {
        var calls: [String] = [], writes: [[UInt8]] = []
        var events: [OriginalResultRecording.Event] = []
        var journal: [M.S.Operation] = []
        var stages: [OriginalGameplayBody.Stage] = []
        var resumed: [UInt32] = [], opens: [OriginalReplayFileOutput.OpenRequest] = []
        var token: UInt32 = 0x81800020
        var opened = true, writeResult: Int32? = nil, closeResult: Int32 = 0
        var stop: String?
        mutating func call(_ name: String) throws {
            calls.append(name)
            if stop == name { throw M.Stop.injected(name) }
        }
    }
    func withReady(_ body: (inout OriginalApplicationBootstrap,P,M.S.PendingReturn) throws -> Void) throws {
        _ = try OriginalApplicationLoadedSelectionTests().sequence(false,onStart:{ origin,pending in
            var app = origin,launch = try L.L(pending:pending),env = L.Environment()
            let result = try L().launch(&launch,&env,L.R(false,pending))
            try C.finish(&app,result)
            let loading = try C.next(&app)
            var cycle = try app.makeLoadedCycle(pending:loading),input = C.InputEnvironment()
            try body(&app,C.input(&cycle,&input),result)
        })
    }
    func controlled(_ p: P,_ edit: (inout OriginalMatchPreparation,inout M.S.State) throws -> Void) throws -> P {
        var model = p.match,state = p.state
        try edit(&model,&state)
        var context = p.inputContext;context.memory = state.memory
        try OriginalApplicationMatchBindings(pending:p.entry).store(model,context:context,in:&state)
        context.memory = state.memory
        return .init(entry:p.entry,state:state,match:model,inputContext:context,music:p.music,
            commands:p.commands,playbackCommands:p.playbackCommands,paused:p.paused,round:p.round,
            operations:p.operations,graphics:p.graphics,loading:p.loading,
            menuResources:p.menuResources,menuBackgrounds:p.menuBackgrounds)
    }
    func run(_ s: inout G,_ e: inout Environment,missing: String? = nil) throws -> M.S.PendingReturn {
        let p = s.entry,output = try M.output(p.loading.target)
        // Declared call-local unknown backing; formatting must produce every
        // byte it reads. This is not an original stack snapshot or startup claim.
        let caller = try OriginalGameplayBody.Caller(formatter:.init(
            bytes:[UInt8](repeating:0xa5,count:OriginalResultLayout.localSize),
            defined:[Bool](repeating:false,count:OriginalResultLayout.localSize)))
        let allocate: (inout Environment) throws -> UInt32 = {
            try $0.call("allocate");$0.journal.append(.gameplayAllocate($0.token,OriginalReplayWriter.capacity));return $0.token
        }
        let processor: (inout Environment) throws -> UInt32 = {
            try $0.call("processor");$0.journal.append(.gameplayProcessor(0x306c4));return 0x306c4
        }
        let open: (OriginalReplayFileOutput.OpenRequest,inout Environment) throws -> Bool = {
            try $1.call("open");$1.opens.append($0);$1.journal.append(.gameplayOpen($0,$1.opened));return $1.opened
        }
        let write: ([UInt8],inout Environment) throws -> Int32 = {
            try $1.call("write");$1.writes.append($0)
            let result = $1.writeResult ?? Int32($0.count)
            $1.journal.append(.gameplayWrite($0,result));return result
        }
        let close: (inout Environment) throws -> Int32 = {
            try $0.call("close");$0.journal.append(.gameplayClose($0.closeResult));return $0.closeResult
        }
        let music: (UInt32,inout Environment) throws -> Int32 = {
            try $1.call("music");$1.resumed.append($0);$1.journal.append(.gameplayResume($0,-17));return -17
        }
        let observer: (M.S.Observation,inout Environment) throws -> Void = { observation,env in
            switch observation {
            case .gameplay(.recording(let event)):
                env.events.append(event);env.journal.append(.gameplayRecording(event))
            case .gameplayCheckpoint(let stage,let snapshot):
                env.stages.append(stage)
                try M.I.coherent(OriginalApplicationMatchBindings(pending:p.entry),snapshot.match,snapshot.state)
                if env.stop == stage.rawValue { throw M.Stop.injected(stage.rawValue) }
            default:break
            }
        }
        let commit: (M.S.PendingReturn,inout Environment) throws -> Void = { _,env in
            if env.stop == "commit" { throw M.Stop.injected("commit") }
        }
        switch missing {
        case "allocate","music":
            return try s.advance(environment:&e,outputInput:output,caller:caller,observe:observer,beforeCommit:commit)
        case "processor":
            return try s.advance(environment:&e,outputInput:output,caller:caller,allocate:allocate,observe:observer,beforeCommit:commit)
        case "open":
            return try s.advance(environment:&e,outputInput:output,caller:caller,allocate:allocate,
                processorSignature:processor,observe:observer,beforeCommit:commit)
        case "write":
            return try s.advance(environment:&e,outputInput:output,caller:caller,allocate:allocate,
                processorSignature:processor,open:open,observe:observer,beforeCommit:commit)
        case "close":
            return try s.advance(environment:&e,outputInput:output,caller:caller,allocate:allocate,
                processorSignature:processor,open:open,write:write,observe:observer,beforeCommit:commit)
        default:
            return try s.advance(environment:&e,outputInput:output,caller:caller,allocate:allocate,
                processorSignature:processor,open:open,write:write,close:close,resumeMusic:music,
                observe:observer,beforeCommit:commit)
        }
    }
    func empty(_ env: Environment) {
        XCTAssertTrue(env.calls.isEmpty && env.writes.isEmpty && env.events.isEmpty && env.stages.isEmpty && env.resumed.isEmpty && env.opens.isEmpty && env.journal.isEmpty)
    }
    func journal(_ result: M.S.PendingReturn,_ env: Environment) {
        let actual = result.snapshot.operations.filter { op in
            switch op {
            case .gameplayRecording,.gameplayAllocate,.gameplayProcessor,.gameplayOpen,
                 .gameplayWrite,.gameplayClose,.gameplayResume:return true
            default:return false
            }
        }
        // Full request bytes, responses and observation order; compact failure
        // output avoids dumping complete replay buffers into the test log.
        XCTAssertTrue(actual == env.journal,"Gameplay provider journal differs")
    }
    func testRetainedSurfaceMapsAndActualOwnerRejections() throws {
        try withReady { app,p,launch in
            let catalog = p.entry.entry.snapshot,n = catalog.bitmapTokens.count
            XCTAssertEqual(n,829);XCTAssertEqual(catalog.bitmapSurfaces.count,n)
            XCTAssertEqual(p.match.bitmaps.count,n+15);XCTAssertEqual(p.match.backgrounds.count,101)
            XCTAssertEqual(try p.match.globals.integer(at:0x44d024-0x44d000,as:Int32.self),0)
            var wrappers = Dictionary(uniqueKeysWithValues:catalog.bitmapTokens.enumerated().map { ($0.offset,$0.element) })
            var surfaces = Dictionary(uniqueKeysWithValues:catalog.bitmapSurfaces.enumerated().map { ($0.offset,$0.element) })
            let allocated = launch.snapshot.operations.compactMap { op -> UInt32? in
                if case .menu(.allocate(let token,_)) = op { return token };return nil
            }
            let created = try launch.snapshot.operations.compactMap { op -> UInt32? in
                if case .menu(.bitmap(let request,let response)) = op,request.kind == "createSurface" {
                    return try XCTUnwrap(response.output)
                };return nil
            }
            XCTAssertEqual(allocated.count,15);XCTAssertEqual(created.count,15)
            guard allocated.count == 15,created.count == 15 else { return }
            for i in 0..<15 {
                let wrapper = allocated[i],surface = created[i]
                XCTAssertEqual(wrapper,L.Environment.wrapper(i));XCTAssertEqual(surface,L.Environment.surface(i))
                wrappers[n+i] = wrapper;surfaces[n+i] = surface
                XCTAssertEqual(try p.state.memory.allocations[wrapper]?.storage.integer(at:0,as:UInt32.self),surface)
            }
            XCTAssertEqual(p.match.bitmapOwners,wrappers);XCTAssertEqual(p.match.bitmapSurfaceOwners,surfaces)
            let parent = app
            for fault in ["catalog-wrapper","catalog-surface","catalog-stale","catalog-released","arena-wrapper","arena-dead","arena-stale"] {
                let changed = try self.controlled(p) { match,state in
                    for i in 0..<n {
                        if fault == "catalog-wrapper" { match.bitmapOwners.removeValue(forKey:i) }
                        if fault == "catalog-surface" { match.bitmapSurfaceOwners.removeValue(forKey:i) }
                        if fault == "catalog-stale" { match.bitmapSurfaceOwners[i] = 0xdead0000 }
                        if fault == "catalog-released",match.bitmaps[i].input.present {
                            // Controlled one-layer release descriptor, used only
                            // to set the owner's release state through its API.
                            // It does not replace an actual game background.
                            var release = try OriginalStateRecord(
                                bytes:[UInt8](repeating:0xa5,count:OriginalBackgroundLoader.recordSize),
                                defined:[Bool](repeating:false,count:OriginalBackgroundLoader.recordSize))
                            try release.write(Int32(1),at:0x1c);try release.write(UInt32(i+1),at:0x914)
                            XCTAssertEqual(try match.backgroundLoader.releaseLayers(in:&release),[i])
                        }
                    }
                    for i in n..<n+15 {
                        if fault == "arena-wrapper" { match.bitmapOwners.removeValue(forKey:i) }
                        let token = wrappers[i]!
                        if fault == "arena-dead" { state.memory.allocations[token]!.live = false }
                        if fault == "arena-stale" { try state.memory.allocations[token]!.storage.write(UInt32(0xdead0000),at:0) }
                    }
                }
                var session = try G(pending:changed),env = Environment()
                XCTAssertThrowsError(try self.run(&session,&env)) { error in
                    if fault == "catalog-released" {
                        // The existing HUD resolves its catalog portrait before
                        // invoking the application's surface callback.
                        guard case OriginalStateError.invalidStorage("World HUD: Bitmap binding") = error else {
                            return XCTFail("Unexpected released-catalog rejection: \(error)")
                        }
                        return
                    }
                    guard let boundary = error as? M.S.Boundary else { return XCTFail("Unexpected \(fault) rejection: \(error)") }
                    switch fault {
                    case "catalog-wrapper","arena-wrapper":
                        XCTAssertEqual(boundary,.dependency("Gameplay bitmap ordinal"))
                    case "catalog-stale","arena-stale":XCTAssertEqual(boundary,.owner(0xdead0000))
                    case "catalog-surface":
                        guard case .owner(let token) = boundary else { return XCTFail("Expected missing catalog owner") }
                        XCTAssertTrue(catalog.bitmapTokens.contains(token))
                    case "arena-dead":
                        guard case .owner(let token) = boundary else { return XCTFail("Expected dead arena owner") }
                        XCTAssertTrue(allocated.contains(token))
                    default:XCTFail("Unexpected fault \(fault)")
                    }
                }
                XCTAssertTrue(session.pendingReturn == nil);self.empty(env);try C.unchanged(app,parent)
            }
        }
    }
    func testMusicRecoveryProviderAndLateRollback() throws {
        try withReady { app,p,_ in
            let changed = try self.controlled(p) { match,_ in
                try match.globals.write(Int32(1),at:0x450bc0-0x44d000)
                try match.actors[0].write(Int32(100),at:0x2fc)
                try match.actors[1].write(Int32(200),at:0x2fc)
            }
            let parent = app,control = try changed.match.globals.integer(at:0x44f044-0x44d000,as:UInt32.self)
            XCTAssertNotEqual(control,0)
            var missing = try G(pending:changed),missingEnv = Environment()
            XCTAssertThrowsError(try self.run(&missing,&missingEnv,missing:"music")) {
                XCTAssertEqual($0 as? M.S.Boundary,.dependency("Gameplay command music resume"))
            }
            self.empty(missingEnv);XCTAssertTrue(missing.pendingReturn == nil)
            for stop in ["music","hud","commit"] {
                var failed = try G(pending:changed),env = Environment(stop:stop)
                XCTAssertThrowsError(try self.run(&failed,&env)) { XCTAssertEqual($0 as? M.Stop,.injected(stop)) }
                self.empty(env);XCTAssertTrue(failed.pendingReturn == nil);try C.unchanged(app,parent)
                if stop == "commit" {
                    env.stop = nil
                    let recovered = try self.run(&failed,&env)
                    self.journal(recovered,env);XCTAssertTrue(failed.pendingReturn != nil)
                    var committed = app;try C.finish(&committed,recovered)
                }
            }
            var session = try G(pending:changed),env = Environment()
            let result = try self.run(&session,&env)
            self.journal(result,env)
            XCTAssertEqual(env.resumed,[control,control]);XCTAssertEqual(env.calls,["music","music"])
            let resume = result.snapshot.operations.compactMap { op -> UInt32? in
                if case .gameplayResume(let token,let response) = op { XCTAssertEqual(response,-17);return token };return nil
            }
            XCTAssertEqual(resume,[control,control])
            for i in 0..<2 { XCTAssertEqual(try result.snapshot.match.actors[i].integer(at:0x2fc,as:Int32.self),500) }
            try C.finish(&app,result)
            XCTAssertEqual(app.session?.state.libraryText,result.snapshot.state.libraryText)
        }
    }
    func testResultFileProvidersCleanupAndWholeCallRollback() throws {
        try withReady { app,p,_ in
            let changed = try self.controlled(p) { match,_ in
                try match.globals.write(Int32(101),at:0x450bdc-0x44d000)
                try match.globals.write(UInt32(2),at:0x44dd50-0x44d000)
            }
            let parent = app,replay = L.R.replay
            let dependencies = ["allocate":"Gameplay replay codec allocation","processor":"Gameplay replay processor input",
                "open":"Gameplay replay file open","write":"Gameplay replay file write","close":"Gameplay replay file close"]
            for missing in ["allocate","processor","open","write","close"] {
                var session = try G(pending:changed),env = Environment()
                XCTAssertThrowsError(try self.run(&session,&env,missing:missing)) {
                    XCTAssertEqual($0 as? M.S.Boundary,.dependency(dependencies[missing]!))
                }
                self.empty(env);XCTAssertTrue(session.pendingReturn == nil);try C.unchanged(app,parent)
            }
            var overlap = try G(pending:changed),overlapEnv = Environment(token:p.entry.entry.snapshot.bitmapTokens[0])
            XCTAssertThrowsError(try self.run(&overlap,&overlapEnv)) {
                XCTAssertEqual($0 as? M.S.Boundary,.overlap(overlapEnv.token))
            }
            self.empty(overlapEnv);XCTAssertTrue(overlap.pendingReturn == nil)
            for stop in ["write","close","recording","output","commit"] {
                var failed = try G(pending:changed),env = Environment(stop:stop)
                XCTAssertThrowsError(try self.run(&failed,&env)) { XCTAssertEqual($0 as? M.Stop,.injected(stop)) }
                self.empty(env);XCTAssertTrue(failed.pendingReturn == nil);try C.unchanged(app,parent)
                if stop == "commit" {
                    env.stop = nil
                    let recovered = try self.run(&failed,&env)
                    self.journal(recovered,env);XCTAssertTrue(failed.pendingReturn != nil)
                    var committed = app;try C.finish(&committed,recovered)
                }
            }
            var successfulFile: [UInt8] = []
            let trials: [(Bool,Int32?,Int32)] = [(true,nil,0),(false,nil,0),(true,nil,-1),(true,0,0),(true,-1,0),(true,1,0)]
            for (opened,writeResult,closeResult) in trials {
                var session = try G(pending:changed),env = Environment(opened:opened,writeResult:writeResult,closeResult:closeResult)
                let result = try self.run(&session,&env),state = result.snapshot.state
                self.journal(result,env)
                XCTAssertEqual(Array(env.calls.prefix(3)),["allocate","processor","open"])
                XCTAssertEqual(env.opens.count,1);XCTAssertEqual(env.opens[0].mode,[0x77,0x62]);XCTAssertEqual(env.opens[0].share,0x40)
                let name = Array(changed.match.globals.bytes[(0x44fd98-0x44d000)...].prefix(while:{ $0 != 0 }))
                XCTAssertEqual(env.opens[0].path,Array((Array("recording\\".utf8)+name).prefix(259)).map(UInt16.init))
                XCTAssertEqual(try state.memory.replayPointers.integer(at:0,as:UInt32.self),0)
                XCTAssertEqual(state.memory.allocations[replay]?.live,false);XCTAssertEqual(state.memory.allocations[env.token]?.live,false)
                XCTAssertEqual(try result.snapshot.match.globals.integer(at:0x450b80-0x44d000,as:Int32.self),0)
                let freed = env.events.compactMap { e -> UInt32? in if case .writer(.free(let p)) = e { return p };return nil }
                XCTAssertEqual(freed,[env.token,replay])
                let streams = env.events.compactMap { e -> UInt32? in
                    if case .writer(.streamReturn(_,let value)) = e { return value };return nil
                }
                let failedClose: UInt32 = writeResult == 1 ? 4 : 6
                XCTAssertEqual(streams,!opened ? [2,6,6,6,6] : writeResult != nil ? [0,0,4,failedClose,failedClose] : closeResult != 0 ? [0,0,0,2,2] : [0,0,0,0,0])
                if opened {
                    XCTAssertEqual(env.calls.last,"close")
                    if writeResult == nil {
                        let file = env.writes.flatMap { $0 };XCTAssertGreaterThan(file.count,4096)
                        let count = (0..<4).reduce(UInt32(0)) { $0 | UInt32(file[$1]) << ($1*8) }
                        XCTAssertEqual(Int(count),file.count-4)
                        XCTAssertTrue(Array(file.dropFirst(4)) == Array(state.memory.allocations[env.token]!.storage.bytes.prefix(Int(count))))
                        if closeResult == 0 { successfulFile = file }
                        else { XCTAssertTrue(file == successfulFile) }
                    } else {
                        // Retained CRT contract: failed first4096-byte flush
                        // still buffers its triggering byte for the close flush.
                        XCTAssertEqual(env.writes.map(\.count),[4096,1])
                        XCTAssertTrue(env.writes.first == Array(successfulFile.prefix(4096)))
                        XCTAssertEqual(env.writes.last,Array(successfulFile.dropFirst(4096).prefix(1)))
                    }
                    var committed = app;try C.finish(&committed,result)
                    let loading = try C.next(&committed)
                    var cycle = try committed.makeLoadedCycle(pending:loading),input = C.InputEnvironment()
                    let next = try C.input(&cycle,&input)
                    XCTAssertEqual(try next.state.memory.replayPointers.integer(at:0,as:UInt32.self),0)
                } else { XCTAssertEqual(env.calls,["allocate","processor","open"]);XCTAssertTrue(env.writes.isEmpty) }
            }
        }
    }
}
