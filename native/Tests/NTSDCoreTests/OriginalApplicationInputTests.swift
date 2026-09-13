import Foundation
import XCTest
import NTSDCore

final class OriginalApplicationInputTests: XCTestCase {
    typealias S = OriginalApplicationInputSession
    typealias B = OriginalApplicationMatchBindings
    typealias State = OriginalApplicationMenuSession.State
    typealias P = OriginalApplicationPoolTests
    enum Stop: Error, Equatable { case injected(String), platform }
    struct Environment: Equatable { var phases: [String] = [];var published = 0 }
    static let order: [OriginalLoadedMatchEntry.Checkpoint] = [.localBeforeDispatch,.local,.control,.received,.replay,.round]
    static let parent: Result<S.Pool.PendingInput,Error> = Result {
        let entry = try P.parent.get(),provider = try P.Provider(entry)
        var session = try S.Pool(pending:entry)
        return try session.prepare(inputs:OriginalApplicationInterfaceInputsTests.inputs.get(),
            makeControls:provider.controls,observe:provider.observe,beforeCommit:provider.complete)
    }
    static func put(_ record: OriginalStateRecord,at offset: Int,in full: inout OriginalStateRecord) throws {
        var bytes = full.bytes,mask = full.defined
        bytes.replaceSubrange(offset..<offset+record.bytes.count,with:record.bytes)
        mask.replaceSubrange(offset..<offset+record.defined.count,with:record.defined)
        full = try .init(bytes:bytes,defined:mask)
    }
    static func slice(_ r: OriginalStateRecord,_ at: Int,_ n: Int) throws -> OriginalStateRecord {
        try .init(bytes:Array(r.bytes[at..<at+n]),defined:Array(r.defined[at..<at+n]))
    }
    /// Controlled owner adapter tests need only full/memory. Empty front values
    /// do not claim a second application bootstrap or reconstructed draw owners.
    static func state(_ full: OriginalStateRecord,_ memory: OriginalMenuPresentationMemory) throws -> State {
        try .init(full:full,memory:memory,front:.init(),frontSurfaces:[:],earlyScreen:.init(),
                  libraryText:.init(),random:.init(state:1),screenBody:nil)
    }
    static func coherent(_ b: B,_ model: OriginalMatchPreparation,_ state: State) throws {
        XCTAssertEqual(try slice(state.full,0,OriginalMatchPreparation.globalSize),model.globals)
        XCTAssertEqual(try state.full.integer(at:0xbb00+0x7d4,as:UInt32.self),b.catalogToken)
        var world = try slice(state.full,0xbb00,0x7d8)
        try world.write(UInt32(0),at:0x7d4)
        for seat in 0..<400 {
            let ordinal = try model.world.integer(at:0x194+4*seat,as:UInt32.self)
            XCTAssertEqual(try state.full.integer(at:0xbb00+0x194+4*seat,as:UInt32.self),b.actorTokens[Int(ordinal)])
            try world.write(ordinal,at:0x194+4*seat)
        }
        XCTAssertEqual(world,model.world)
        for i in 0..<400 {
            var r = try XCTUnwrap(state.memory.allocations[b.actorTokens[i]])
            XCTAssertTrue(r.live)
            let object = try model.actors[i].integer(at:0x368,as:UInt32.self)
            XCTAssertEqual(try r.storage.integer(at:0x368,as:UInt32.self),b.objectTokens[Int(object)])
            try r.storage.write(object,at:0x368);XCTAssertEqual(r.storage,model.actors[i])
        }
        XCTAssertEqual(try slice(state.full,0xb8a8,8),state.memory.replayPointers)
    }
    func testOwnLoadedInputRetainsCurrentOwnersAtAllSixCheckpoints() throws {
        let p = try Self.parent.get();var session = try S(pending:p,arithmeticPrecision:.bits53)
        let bindings = session.bindings
        var env = Environment()
        let result = try session.advance(environment:&env,controlBoundary:{ _,_ in throw Stop.platform },
            checkpoint:{ phase,model,state,commands,e in
                e.phases.append(phase.rawValue);try Self.coherent(bindings,model,state)
                XCTAssertEqual(model.arithmeticPrecision,.bits53);XCTAssertEqual(commands.count,10)
                XCTAssertEqual(try Self.slice(state.full,0xb440,0x6c0),try Self.slice(p.state.full,0xb440,0x6c0))
                XCTAssertEqual(try Self.slice(state.full,0xc2d8,0xd0),try Self.slice(p.state.full,0xc2d8,0xd0))
                XCTAssertEqual(state.graphics,p.state.graphics);XCTAssertEqual(state.bitmapInputs,p.state.bitmapInputs)
            },beforeCommit:{ result,e in
                XCTAssertEqual(result.round.continuation,.menu);XCTAssertEqual(result.round.stageDefeated,0)
                XCTAssertEqual(result.inputContext.savedPlayback,try Self.slice(p.state.full,0xb588,0x320))
                XCTAssertEqual(result.inputContext.memory.allocations,result.state.memory.allocations)
                XCTAssertEqual(result.inputContext.memory.replayPointers,result.state.memory.replayPointers)
                XCTAssertEqual(result.music.allocations,p.entry.startup.music.allocations)
                XCTAssertFalse(result.music.allocations.isEmpty)
                XCTAssertTrue(result.operations == p.operations.map(S.Operation.preceding))
                XCTAssertEqual(result.graphics,p.graphics);e.published += 1
            })
        XCTAssertEqual(env.phases,Self.order.map(\.rawValue));XCTAssertEqual(env.published,1)
        XCTAssertEqual(result.playbackCommands,Array(p.loaded.commands.suffix(10)))
        XCTAssertEqual(result.match.interface.bitmaps,p.loaded.interface.bitmaps)
        XCTAssertEqual(result.match.loadedObjects,p.loaded.catalog.objects)
        XCTAssertEqual(result.match.frameAllocations,p.loaded.catalog.frameAllocations)
        XCTAssertEqual(result.state.random,p.state.random);XCTAssertEqual(result.state.libraryText,p.state.libraryText)
        XCTAssertThrowsError(try session.advance(environment:&env,controlBoundary:{ _,_ in throw Stop.platform })) {
            XCTAssertEqual($0 as? S.Boundary,.alreadyPrepared)
        }
    }
    func testEveryLateInputFailureKeepsParentAndEnvironment() throws {
        let p = try Self.parent.get()
        for point in Self.order.map(\.rawValue)+["publication"] {
            var session = try S(pending:p,arithmeticPrecision:.bits53),env = Environment()
            XCTAssertThrowsError(try session.advance(environment:&env,controlBoundary:{ _,_ in throw Stop.platform },
                checkpoint:{ phase,_,_,_,e in
                    e.phases.append(phase.rawValue);if phase.rawValue == point { throw Stop.injected(point) }
                },beforeCommit:{ _,e in e.published += 1;throw Stop.injected("publication") })) {
                    XCTAssertEqual($0 as? Stop,.injected(point))
                }
            XCTAssertEqual(env,Environment());XCTAssertNil(session.pendingContinuation)
            OriginalApplicationCatalogSessionTests.retained(session.entry.state,p.state)
            XCTAssertEqual(session.entry.entry.startup.music.allocations,p.entry.startup.music.allocations)
            if point == "publication" {
                _ = try session.advance(environment:&env,controlBoundary:{ _,_ in throw Stop.platform },
                    checkpoint:{ phase,_,_,_,e in e.phases.append(phase.rawValue) },beforeCommit:{ _,e in e.published += 1 })
                XCTAssertEqual(env.phases,Self.order.map(\.rawValue));XCTAssertEqual(env.published,1)
            }
        }
    }
    func testCurrentAliasesUnknownBytesAndReturnedResourceChanges() throws {
        let p = try Self.parent.get(),b = try B(pending:p)
        var full = p.state.full,memory = p.state.memory
        // Deliberate Native-only caller inputs, including two seats sharing the
        // same current Actor and a changed live Object. No source branch claim.
        try full.write(b.actorTokens[7],at:0xbb00+0x194)
        try full.write(b.actorTokens[7],at:0xbb00+0x198)
        try full.write(b.actorTokens[0],at:0xbb00+0x194+7*4)
        var worldBytes = full.bytes,worldMask = full.defined
        worldBytes[0xbb00+0x190] = 0x95;worldMask[0xbb00+0x190] = false
        full = try .init(bytes:worldBytes,defined:worldMask)
        var a = try XCTUnwrap(memory.allocations[b.actorTokens[7]])
        try a.storage.write(b.objectTokens[21],at:0x368);try a.storage.write(Int32(-97),at:0x2fc)
        var bytes = a.storage.bytes,mask = a.storage.defined
        bytes[0x41f] = 0xe3;mask[0x41f] = false
        a.storage = try .init(bytes:bytes,defined:mask);memory.allocations[b.actorTokens[7]] = a
        try full.write(UInt8(0xfe),at:0xb588+0x1f4)
        var state = try Self.state(full,memory)
        var model = try b.read(state,catalog:p.loaded.catalog,interface:p.loaded.interface,arithmeticPrecision:.bits24)
        XCTAssertEqual(try model.world.integer(at:0x194,as:UInt32.self),7)
        XCTAssertEqual(try model.world.integer(at:0x198,as:UInt32.self),7)
        XCTAssertEqual(try model.world.integer(at:0x194+7*4,as:UInt32.self),0)
        XCTAssertEqual(model.world.bytes[0x190],0x95);XCTAssertFalse(model.world.defined[0x190])
        XCTAssertEqual(try model.actors[7].integer(at:0x368,as:UInt32.self),21)
        XCTAssertEqual(try model.actors[7].integer(at:0x2fc,as:Int32.self),-97)
        XCTAssertEqual(model.actors[7].bytes[0x41f],0xe3);XCTAssertFalse(model.actors[7].defined[0x41f])
        var context = try b.inputContext(state)
        XCTAssertEqual(try context.savedPlayback.integer(at:0x1f4,as:Int8.self),-2)
        try b.store(model,context:context,in:&state)
        XCTAssertEqual(state.full,full);XCTAssertEqual(state.memory.allocations,memory.allocations)
        try model.actors[7].write(Int32(123),at:0x2fc)
        try model.actors[0].write(UInt32(0),at:0x368)
        let extra: UInt32 = 0x7e000020
        context.memory.allocations[extra] = .init(storage:try .init(bytes:[1,2,3,4],defined:[true,false,true,false]),live:false)
        try context.memory.replayPointers.write(extra,at:0)
        try context.savedPlayback.write(UInt8(0x81),at:0x319)
        try b.store(model,context:context,in:&state)
        try Self.coherent(b,model,state)
        XCTAssertEqual(state.memory.allocations[extra],context.memory.allocations[extra])
        XCTAssertEqual(try Self.slice(state.full,0xb588,0x320),context.savedPlayback)
        XCTAssertEqual(try state.full.integer(at:0xb8a8,as:UInt32.self),extra)
        XCTAssertEqual(try state.memory.allocations[b.actorTokens[0]]?.storage.integer(at:0x368,as:UInt32.self),b.objectTokens[0])
        XCTAssertEqual(try state.memory.allocations[b.actorTokens[7]]?.storage.integer(at:0x2fc,as:Int32.self),123)
    }
    func testInvalidBindingAndConflictingWritersRejectAtomically() throws {
        let p = try Self.parent.get(),b = try B(pending:p)
        for kind in ["missing","dead","object","unknownObject","unknownActor","catalog"] {
            var memory = p.state.memory,full = p.state.full
            let token = b.actorTokens[0]
            switch kind {
            case "missing":memory.allocations[token] = nil
            case "dead":memory.allocations[token]?.live = false
            case "object":try memory.allocations[token]?.storage.write(UInt32(0),at:0x368)
            case "unknownObject":
                let old = try XCTUnwrap(memory.allocations[token]?.storage);var mask = old.defined;mask[0x368] = false
                memory.allocations[token]?.storage = try .init(bytes:old.bytes,defined:mask)
            case "unknownActor":try full.write(UInt32(0),at:0xbb00+0x194)
            default:try full.write(UInt32(0),at:0xbb00+0x7d4)
            }
            let state = try Self.state(full,memory)
            XCTAssertThrowsError(try b.read(state,catalog:p.loaded.catalog,interface:p.loaded.interface,arithmeticPrecision:.bits53))
        }
        for kind in ["actorOrdinal","objectOrdinal","conflict","savedExtent","replayExtent"] {
            var state = p.state,context = try b.inputContext(state)
            var model = try b.read(state,catalog:p.loaded.catalog,interface:p.loaded.interface,arithmeticPrecision:.bits53)
            switch kind {
            case "actorOrdinal":try model.world.write(UInt32(400),at:0x194)
            case "objectOrdinal":try model.actors[399].write(UInt32(b.objectTokens.count),at:0x368)
            case "conflict":try context.memory.allocations[b.actorTokens[399]]?.storage.write(UInt8(99),at:0)
            case "savedExtent":context.savedPlayback = try .init(bytes:[0],defined:[true])
            default:context.memory.replayPointers = try .init(bytes:[0],defined:[true])
            }
            XCTAssertThrowsError(try b.store(model,context:context,in:&state))
            OriginalApplicationCatalogSessionTests.retained(state,p.state)
        }
        XCTAssertThrowsError(try B(catalogToken:0,actorTokens:b.actorTokens,objectTokens:b.objectTokens))
        XCTAssertThrowsError(try B(catalogToken:b.catalogToken,actorTokens:[UInt32](repeating:1,count:400),objectTokens:b.objectTokens))
    }

    /// Both retained MENU_STARTUP source comparators invoke this after their
    /// original six checkpoint checks. Inputs here come from their Native load,
    /// not the source after-state. The independently source-checked result is
    /// used only for comparison. Reversed logical identities add a Native control.
    static func compareSavedEntry(_ loaded: OriginalInitialLoading,_ input: OriginalInputControlContext,
                                 _ expected: OriginalInitialMatchEntry,reversed: Bool) throws {
        let actors = (0..<400).map { UInt32(0x60000020)+UInt32(reversed ? 399-$0 : $0)*0x500 }
        let objects = (0..<loaded.catalog.objects.count).map { UInt32(0x61000020)+UInt32($0)*0x10000 }
        let b = try B(catalogToken:0x70000020,actorTokens:actors,objectTokens:objects)
        var full = try OriginalStateRecord(bytes:[UInt8](repeating:0xa7,count:0xc3a8),defined:[Bool](repeating:false,count:0xc3a8))
        var world = loaded.bootstrap.world,memory = input.memory
        try world.write(b.catalogToken,at:0x7d4)
        for seat in 0..<400 {
            let ordinal = try world.integer(at:0x194+4*seat,as:UInt32.self)
            try world.write(actors[Int(ordinal)],at:0x194+4*seat)
            var record = loaded.bootstrap.actors[seat]
            let object = try record.integer(at:0x368,as:UInt32.self)
            try record.write(objects[Int(object)],at:0x368)
            XCTAssertNil(memory.allocations[actors[seat]]);memory.allocations[actors[seat]] = .init(storage:record)
        }
        try put(loaded.globals,at:0,in:&full);try put(world,at:0xbb00,in:&full)
        try put(input.savedPlayback,at:0xb588,in:&full);try put(memory.replayPointers,at:0xb8a8,in:&full)
        var own = try state(full,memory),model = try b.read(own,catalog:loaded.catalog,interface:loaded.interface,arithmeticPrecision:.bits64)
        XCTAssertEqual(model.world,loaded.bootstrap.world);XCTAssertEqual(model.actors,loaded.bootstrap.actors)
        var context = try b.inputContext(own),commands = Array(loaded.commands.prefix(10))
        var phases: [OriginalLoadedMatchEntry.Checkpoint] = []
        let round = try OriginalLoadedMatchEntry.run(state:&model,paused:loaded.paused,commands:&commands,
            playbackCommands:Array(loaded.commands.suffix(10)),context:&context,
            controlBoundary:{ _ in throw Stop.platform },checkpoint:{ phase,match,resources,buffer in
                phases.append(phase);var snapshot = own
                try b.store(match,context:resources,in:&snapshot);try coherent(b,match,snapshot)
                XCTAssertEqual(buffer,expected.commands)
            })
        try b.store(model,context:context,in:&own)
        XCTAssertEqual(phases,order);XCTAssertEqual(round.continuation,expected.round.continuation)
        XCTAssertEqual(round.stageDefeated,expected.round.stageDefeated);XCTAssertEqual(commands,expected.commands)
        XCTAssertEqual(model.world,expected.state.world);XCTAssertEqual(model.actors,expected.state.actors)
        XCTAssertEqual(model.globals,expected.state.globals);XCTAssertEqual(model.interface.bitmaps,expected.state.interface.bitmaps)
        XCTAssertEqual(context.savedPlayback,expected.inputContext.savedPlayback)
        XCTAssertEqual(context.memory.replayPointers,expected.inputContext.memory.replayPointers)
        for (token,allocation) in expected.inputContext.memory.allocations { XCTAssertEqual(own.memory.allocations[token],allocation) }
        XCTAssertEqual(own.memory.allocations.count,expected.inputContext.memory.allocations.count+400)
        XCTAssertEqual(try slice(own.full,0xb440,0x6c0),try slice(full,0xb440,0x6c0))
        XCTAssertEqual(try slice(own.full,0xc2d8,0xd0),try slice(full,0xc2d8,0xd0))
        try coherent(b,model,own)
    }
}
