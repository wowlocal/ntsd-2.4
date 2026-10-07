import Foundation
import XCTest
@testable import NTSDCore

/// The allocation table with an actor tier (CORE_REALTIME R3 stage 1) behaves
/// as the dictionary it replaced, and the match bindings' read and store give
/// the results and first errors of the per-entry algorithm they replaced.
final class OriginalAllocationTableTests: XCTestCase {
    typealias B = OriginalApplicationMatchBindings
    typealias State = OriginalApplicationMenuSession.State
    typealias Allocation = OriginalMenuPresentationMemory.Allocation

    private func error(_ body: () throws -> Void) -> String? {
        do { try body(); return nil } catch { return String(describing: error) }
    }

    // MARK: the bindings against the per-entry algorithm

    /// The store before R3 stage 1: every actor entry checked and written in
    /// index order into the context's memory.
    static func oracleStore(_ b: B,_ match: OriginalMatchPreparation,context: OriginalInputControlContext,
                            in state: inout State) throws {
        try state.validateAliases()
        guard context.savedPlayback.bytes.count == 0x320 else { throw B.Boundary.savedPlayback }
        guard match.loadedObjects.count == b.objectTokens.count,
              match.world.bytes.count == 0x7d8,match.actors.count == 400,
              match.actors.allSatisfy({ $0.bytes.count == OriginalStateRecord.actorSize }),
              match.globals.bytes.count == OriginalMatchPreparation.globalSize,
              try match.world.integer(at:0x7d4,as:UInt32.self) == 0 else { throw B.Boundary.catalog }
        var next = state,world = match.world,memory = context.memory
        try world.write(b.catalogToken,at:0x7d4)
        for seat in 0..<400 {
            let ordinal = try world.integer(at:0x194+seat*4,as:UInt32.self)
            guard ordinal < b.actorTokens.count else { throw B.Boundary.ordinal(ordinal) }
            try world.write(b.actorTokens[Int(ordinal)],at:0x194+seat*4)
        }
        for (i,token) in b.actorTokens.enumerated() {
            guard let a = state.memory.allocations[token],a.live,a.storage.bytes.count == OriginalStateRecord.actorSize else {
                throw B.Boundary.actor(token)
            }
            _ = a
            guard memory.allocations[token] == state.memory.allocations[token] else { throw B.Boundary.conflictingActor(token) }
            var converted = match.actors[i]
            let ordinal = try converted.integer(at:0x368,as:UInt32.self)
            guard ordinal < b.objectTokens.count else { throw B.Boundary.ordinal(ordinal) }
            try converted.write(b.objectTokens[Int(ordinal)],at:0x368)
            memory.allocations[token] = Allocation(storage:converted)
        }
        next.memory = memory
        try next.replace(0,match.globals);try next.replace(0xbb00,world)
        try next.replace(0xb588,context.savedPlayback);try next.replace(0xb8a8,memory.replayPointers)
        try next.validateAliases();state = next
    }

    /// Both stores on the same inputs: equal states, or the same error with
    /// the state unchanged.
    private func compareStores(_ b: B,_ model: OriginalMatchPreparation,_ context: OriginalInputControlContext,
                               _ state: State,_ label: String,file: StaticString = #filePath,line: UInt = #line) {
        // The oracle runs on the flat twin of `full` (B1: the session holds it
        // in parts); the input's bytes are taken first, so a shared parts
        // object written in place would show.
        let before = state.full.readOnce()
        var a = state,o = state.flatFullForTesting()
        let errorA = error { try b.store(model,context:context,in:&a) }
        let errorO = error { try Self.oracleStore(b,model,context:context,in:&o) }
        XCTAssertEqual(errorA,errorO,label,file:file,line:line)
        XCTAssertEqual(a.full,o.full,label,file:file,line:line)
        XCTAssertEqual(a.memory.allocations,o.memory.allocations,label,file:file,line:line)
        XCTAssertEqual(a.memory.allocations.dictionary,o.memory.allocations.dictionary,label,file:file,line:line)
        XCTAssertEqual(a.memory.replayPointers,o.memory.replayPointers,label,file:file,line:line)
        XCTAssertEqual(a.full.bytes,o.full.bytes,label,file:file,line:line);XCTAssertEqual(a.full.defined,o.full.defined,label,file:file,line:line)
        XCTAssertTrue(a.full.isPartitioned,label,file:file,line:line)
        let input = state.full.readOnce()
        XCTAssertEqual(input.bytes,before.bytes,label,file:file,line:line);XCTAssertEqual(input.defined,before.defined,label,file:file,line:line)
        if errorA != nil {
            OriginalApplicationCatalogSessionTests.retained(a,state)
            let kept = a.full.readOnce()
            XCTAssertEqual(kept.bytes,before.bytes,label,file:file,line:line);XCTAssertEqual(kept.defined,before.defined,label,file:file,line:line)
        } else {
            // The stored globals are the match model's own buffers (part 0).
            XCTAssertTrue(try OriginalApplicationMenuSession.State.slice(a.full,0,OriginalMatchPreparation.globalSize).sharesStorage(with:model.globals),label,file:file,line:line)
        }
    }

    func testStoreMatchesThePerEntryAlgorithmUnderFaults() throws {
        let p = try OriginalApplicationInputTests.parent.get(),b = try B(pending:p)
        func read(_ state: State) throws -> OriginalMatchPreparation {
            try b.read(state,catalog:p.loaded.catalog,interface:p.loaded.interface,arithmeticPrecision:.bits53)
        }
        // A state holding the actor tier (after one store) and one without it.
        var tiered = p.state
        try b.store(try read(p.state),context:try b.inputContext(p.state),in:&tiered)
        XCTAssertNotNil(tiered.memory.allocations.actors,"the store installs the actor tier")
        XCTAssertEqual(tiered.memory.allocations.count,p.state.memory.allocations.count)
        for (name,base) in [("plain",p.state),("tiered",tiered)] {
            let model = try read(base),context = try b.inputContext(base)
            compareStores(b,model,context,base,"\(name) clean")
            var changed = model
            try changed.actors[7].write(UInt8(0x5a),at:0x10)
            compareStores(b,changed,context,base,"\(name) changed actor")
            // Changed globals: part 0 becomes the model's new buffer (an install,
            // not the no-op of an already shared part).
            var globals = model
            try globals.globals.write(UInt8(0x5b),at:0x20)
            compareStores(b,globals,context,base,"\(name) changed globals")
            // Faults at one index and at several: the first failing index and
            // check must be the same.
            let t = b.actorTokens
            let faults: [(String,(inout State,inout OriginalInputControlContext,inout OriginalMatchPreparation) throws -> Void)] = [
                ("missing 3",{ s,_,_ in s.memory.allocations[t[3]] = nil }),
                ("dead 5",{ s,_,_ in s.memory.allocations[t[5]]?.live = false }),
                ("short 9",{ s,_,_ in s.memory.allocations[t[9]] = Allocation(storage:try .init(bytes:[0],defined:[true])) }),
                ("conflict 11",{ _,c,_ in try c.memory.allocations[t[11]]?.storage.write(UInt8(99),at:0) }),
                ("ordinal 13",{ _,_,m in try m.actors[13].write(UInt32(b.objectTokens.count),at:0x368) }),
                ("undefined ordinal 17",{ _,_,m in
                    let r = m.actors[17];var mask = r.defined;mask[0x368] = false
                    m.actors[17] = try .init(bytes:r.bytes,defined:mask) }),
                ("conflict 2 then dead 4",{ s,c,_ in
                    try c.memory.allocations[t[2]]?.storage.write(UInt8(98),at:0); s.memory.allocations[t[4]]?.live = false }),
                ("ordinal 1 then missing 6",{ s,_,m in
                    try m.actors[1].write(UInt32(b.objectTokens.count+5),at:0x368); s.memory.allocations[t[6]] = nil }),
                ("dead 8 then conflict 8",{ s,c,_ in
                    s.memory.allocations[t[8]]?.live = false; try c.memory.allocations[t[8]]?.storage.write(UInt8(97),at:0) }),
                ("conflict 10 then ordinal 10",{ _,c,m in
                    try c.memory.allocations[t[10]]?.storage.write(UInt8(96),at:0)
                    try m.actors[10].write(UInt32(b.objectTokens.count),at:0x368) }),
                ("last index ordinal",{ _,_,m in try m.actors[399].write(UInt32(b.objectTokens.count),at:0x368) }),
            ]
            for (label,fault) in faults {
                var state = base,context = try b.inputContext(base),m = model
                try fault(&state,&context,&m)
                compareStores(b,m,context,state,"\(name) \(label)")
            }
        }
    }

    func testReadMatchesThePerEntryAlgorithm() throws {
        let p = try OriginalApplicationInputTests.parent.get(),b = try B(pending:p)
        func read(_ state: State) throws -> OriginalMatchPreparation {
            try b.read(state,catalog:p.loaded.catalog,interface:p.loaded.interface,arithmeticPrecision:.bits53)
        }
        var tiered = p.state
        var model = try read(p.state)
        try model.actors[21].write(UInt8(0x33),at:0x20)
        try b.store(model,context:try b.inputContext(p.state),in:&tiered)
        // Reading the tier gives the stored records; reading the same entries
        // as a plain dictionary (no tier) gives the same records.
        let fromTier = try read(tiered)
        var plain = tiered
        plain.memory.allocations = OriginalAllocationTable(tiered.memory.allocations.dictionary)
        XCTAssertNil(plain.memory.allocations.actors)
        let fromPlain = try read(plain)
        // Reading the flat twin of `full` gives the same model (B1).
        let fromFlat = try read(tiered.flatFullForTesting())
        XCTAssertEqual(fromTier.actors,fromFlat.actors);XCTAssertEqual(fromTier.world,fromFlat.world);XCTAssertEqual(fromTier.globals,fromFlat.globals)
        XCTAssertEqual(fromTier.actors,fromPlain.actors)
        XCTAssertEqual(fromTier.actors,model.actors)
        XCTAssertEqual(fromTier.world,fromPlain.world); XCTAssertEqual(fromTier.globals,fromPlain.globals)
        // Faults dissolve the tier and fail as before.
        for kind in ["missing","dead","object"] {
            var a = tiered,o = plain
            for s in [0,1] {
                let token = b.actorTokens[50]
                switch kind {
                case "missing": if s == 0 { a.memory.allocations[token] = nil } else { o.memory.allocations[token] = nil }
                case "dead": if s == 0 { a.memory.allocations[token]?.live = false } else { o.memory.allocations[token]?.live = false }
                default:
                    if s == 0 { try a.memory.allocations[token]?.storage.write(UInt32(0),at:0x368) }
                    else { try o.memory.allocations[token]?.storage.write(UInt32(0),at:0x368) }
                }
            }
            XCTAssertNil(a.memory.allocations.actors,"changing an actor entry dissolves the tier")
            XCTAssertEqual(error { _ = try read(a) },error { _ = try read(o) },kind)
            XCTAssertNotNil(error { _ = try read(a) })
        }
    }

    // MARK: the table against a dictionary

    func testTableWithActorTierBehavesAsADictionary() throws {
        let p = try OriginalApplicationInputTests.parent.get(),b = try B(pending:p)
        var tiered = p.state
        try b.store(try b.read(p.state,catalog:p.loaded.catalog,interface:p.loaded.interface,arithmeticPrecision:.bits53),
                    context:try b.inputContext(p.state),in:&tiered)
        var table = tiered.memory.allocations
        var reference = table.dictionary
        XCTAssertNotNil(table.actors)
        XCTAssertEqual(reference.count,table.count)
        XCTAssertEqual(OriginalAllocationTable(reference),table,"a plain table with the same entries is equal")
        let actors = b.actorTokens,others = Array(reference.keys.filter { !actors.contains($0) }.sorted().prefix(20))
        var x: UInt64 = 0x9e3779b97f4a7c15
        func random(_ n: Int) -> Int { x = x &* 6364136223846793005 &+ 1442695040888963407; return Int((x >> 33) % UInt64(n)) }
        func check(_ step: Int) {
            XCTAssertEqual(table.count,reference.count,"step \(step)")
            XCTAssertEqual(table.isEmpty,reference.isEmpty)
            XCTAssertEqual(table.dictionary,reference,"step \(step)")
            XCTAssertEqual(Set(table.keys),Set(reference.keys))
            var seen: [UInt32: Allocation] = [:]
            for (k,v) in table { XCTAssertNil(seen[k],"each key once"); seen[k] = v }
            XCTAssertEqual(seen,reference)
            XCTAssertEqual(table.filter { $0.value.live },reference.filter { $0.value.live })
        }
        check(0)
        for step in 1...120 {
            let useActor = random(2) == 0
            let key = useActor ? actors[random(actors.count)] : (random(5) == 0 ? UInt32(0x7f000000+random(1000)) : others[random(others.count)])
            switch random(5) {
            case 0: XCTAssertEqual(table[key],reference[key],"get \(key)")
            case 1:
                let value = Allocation(storage:try .init(bytes:[UInt8(step & 0xff)],defined:[true]),live:random(2) == 0)
                table[key] = value; reference[key] = value
            case 2: XCTAssertEqual(table.removeValue(forKey:key),reference.removeValue(forKey:key))
            case 3: table[key]?.live.toggle(); reference[key]?.live.toggle()
            default:
                // A copy compares equal and stays independent.
                let copy = table
                XCTAssertEqual(copy,table)
                table[key] = nil; reference[key] = nil
                XCTAssertEqual(copy.dictionary.count,copy.count)
            }
            check(step)
            if step == 60 {
                // Reinstalling the tier on the changed table: same logical entries
                // for the actors, the others unchanged.
                var restored = tiered.memory.allocations
                restored[others[0]] = table[others[0]]
                XCTAssertEqual(restored[actors[0]],tiered.memory.allocations[actors[0]])
            }
        }
        XCTAssertNil(table.actors,"actor changes dissolved the tier")
    }
}
