import XCTest
@testable import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E5c-1h: the slot prefix (A29, A31, N1), the scheduler's
/// invulnerability on rising (A47), the round restore (A32) and the input's held-back
/// transformation (A28) follow the profile.
/// Synthetic records.
final class NTSDProfileLifecycleTests: XCTestCase {
    func zero(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0, count: size), defined: [Bool](repeating: true, count: size))
    }
    func lifecycle(regen: OriginalIDSet? = nil, form: Int32? = nil, pieces: Int32? = nil, last: Int32? = nil, lying: OriginalIDSet? = nil,
                   from: Int32? = nil, to: Int32? = nil, guarded: Int32? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(lifecycle: .init(halfHPRegen: regen ?? n.halfHPRegen, state9995Object: form ?? n.state9995Object, pieces: pieces ?? n.pieces,
            lastPiece: last ?? n.lastPiece, noRiseInvulnerability: lying ?? n.noRiseInvulnerability, roundRevertFrom: from ?? n.roundRevertFrom,
            roundRevertTo: to ?? n.roundRevertTo, guardedTransformer: guarded ?? n.guardedTransformer))
    }
    /// The slot prefix for slot 0 (a character) over Objects with these IDs: the
    /// pool afterwards, or the error.
    func prefix(ids: [Int32], actor fields: [(Int, Int32)], frame: @escaping (Int32) throws -> OriginalStateRecord, retained: Int32? = nil,
                rules: OriginalGameRules) throws -> (actors: [OriginalStateRecord], error: String?) {
        let b = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5, count: 0x7d8),
            actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5, count: 0x420), count: 400), selector: 2)
        var world = b.world, actors = b.actors, globals = try zero(0xb440)
        for i in 0..<400 { try world.write(UInt8(i == 0 ? 1 : 0), at: 4+i) }
        for (o, v) in fields { try actors[0].write(v, at: o) }
        for i in 0..<3000 { try globals.write(UInt8(1), at: 0x44ff90-0x44d000+i) }
        let headers = try ids.map { id -> OriginalStateRecord in var h = try zero(0x7a4); try h.write(id, at: 0x6f4); return h }
        var r = retained
        do {
            _ = try OriginalPostDrawSlotPrefix.apply(world: &world, actors: &actors, globals: &globals, slot: 0, retainedObjectIndex: &r,
                objectCount: Int32(ids.count), header: { headers[$0] }, frame: { _, n in try frame(n) }, rules: rules)
        } catch { return (actors, "\(error)") }
        return (actors, nil)
    }
    func testHalfHPRegenA29() throws {
        func mp(_ id: Int32, _ rules: OriginalGameRules) throws -> Int32 {
            let f = try zero(0x178)
            // HP 400 at its recoverable maximum (+0x300) and +0x320 not negative (no HP drain): no HP step before the regeneration.
            let r = try prefix(ids: [id], actor: [(0x2fc, 400), (0x300, 400), (0x320, 0), (0x308, 0), (0x2f4, -1), (8, 0), (0x70, 0), (0x74, 0),
                                                  (0x368, 0)], frame: { _ in f },
                               rules: rules)
            XCTAssertNil(r.error); return try r.actors[0].integer(at: 0x308, as: Int32.self)
        }
        XCTAssertEqual(try mp(5, NTSDProfile.rules), 2, "(500 − 400)/100 + 1")
        XCTAssertEqual(try mp(51, NTSDProfile.rules), 4, "(500 − 200)/100 + 1"); XCTAssertEqual(try mp(52, NTSDProfile.rules), 4)
        XCTAssertEqual(try mp(51, lifecycle(regen: OriginalIDSet([5]))), 2); XCTAssertEqual(try mp(5, lifecycle(regen: OriginalIDSet([5]))), 4)
    }
    func testState9995ObjectA31() throws {
        func object(_ ids: [Int32], _ rules: OriginalGameRules) throws -> UInt32 { try formed(ids, rules).object }
        func formed(_ ids: [Int32], _ rules: OriginalGameRules) throws -> (object: UInt32, frame: Int32) {
            var form = try zero(0x178); try form.write(Int32(9995), at: 8)
            let f = form, plain = try zero(0x178)
            let r = try prefix(ids: ids, actor: [(0x2fc, 400), (0x308, 500), (8, 0), (0x70, 5), (0x74, 5), (0x368, 0)],
                               frame: { $0 == 5 ? f : plain }, rules: rules)
            XCTAssertNil(r.error); return (try r.actors[0].integer(at: 0x368, as: UInt32.self), try r.actors[0].integer(at: 0x70, as: Int32.self))
        }
        XCTAssertEqual(try object([5, 50], NTSDProfile.rules), 1, "becomes Object 50")
        XCTAssertEqual(try formed([5, 50], lifecycle(form: 77)).frame, 0, "frame 0 even without a match")
        XCTAssertEqual(try object([5, 50], lifecycle(form: 77)), 0, "no Object 77: unchanged")
        XCTAssertEqual(try object([5, 77], lifecycle(form: 77)), 1)
    }
    func testPiecesN1() throws {
        // State 9996 with +0x88 = 1: five pieces into slots 50…54, the fifth of `lastPiece`.
        func pieces(_ ids: [Int32], _ rules: OriginalGameRules) throws -> (objects: [UInt32], error: String?) {
            var shed = try zero(0x178); try shed.write(Int32(9996), at: 8)
            let f = shed
            let r = try prefix(ids: ids, actor: [(0x2fc, 400), (0x308, 500), (8, 0), (0x70, 0), (0x74, 0), (0x368, 0), (0x88, 1)],
                               frame: { _ in f }, rules: rules)
            return (try (50..<55).map { try r.actors[$0].integer(at: 0x368, as: UInt32.self) }, r.error)
        }
        var r = try pieces([217, 218], NTSDProfile.rules)
        XCTAssertNil(r.error); XCTAssertEqual(r.objects, [0, 0, 0, 0, 1])
        r = try pieces([217], NTSDProfile.rules); XCTAssertEqual(r.objects, [0, 0, 0, 0, 0], "no 218: the retained index")
        r = try pieces([217, 218], lifecycle(last: 217)); XCTAssertEqual(r.objects, [0, 0, 0, 0, 0])
        r = try pieces([217, 218], lifecycle(pieces: 218, last: 217)); XCTAssertEqual(r.objects, [1, 1, 1, 1, 0])
        r = try pieces([217, 218], lifecycle(pieces: 77, last: 78))
        XCTAssertEqual(r.error, "\(OriginalStateError.invalidStorage("Post-draw slot prefix: Retained catalog index provenance"))")
    }
    /// The scheduler for a special-team character (team 5) in this mode whose frame
    /// 1 (state 14) has run out and goes on to frame 2 (state 0): its +8 afterwards
    /// (15 is the invulnerability countdown).
    func lying(id: Int32, mode: Int32, rules: OriginalGameRules) throws -> Int32 {
        var actor = try OriginalStateRecord.actor(over: [UInt8](repeating: 0, count: OriginalStateRecord.actorSize))
        for (o, v): (Int, Int32) in [(0x70, 1), (0x74, 1), (0x364, 5), (0x2fc, 100), (0x88, 0)] { try actor.write(v, at: o) }
        var globals = try zero(OriginalMatchPreparation.globalSize)
        var header = try zero(0x7a4); try header.write(id, at: 0x6f4)
        var down = try zero(0x178); try down.write(Int32(14), at: 8); try down.write(Int32(2), at: 0x10)
        let d = down, next = try zero(0x178)
        try OriginalActorScheduler.apply(actor: &actor, header: header, globals: &globals, mode: mode, slot: 30,
            frame: { $0 == 1 ? d : next }, rules: rules)
        return try actor.integer(at: 8, as: Int32.self)
    }
    func testNoLyingDelayA47() throws {
        XCTAssertEqual(try lying(id: 5, mode: 1, rules: NTSDProfile.rules), 15)
        XCTAssertNotEqual(try lying(id: 35, mode: 1, rules: NTSDProfile.rules), 15)
        XCTAssertEqual(try lying(id: 38, mode: 1, rules: NTSDProfile.rules), 15)
        XCTAssertEqual(try lying(id: 35, mode: 0, rules: NTSDProfile.rules), 15, "only modes 1 and 4")
        XCTAssertEqual(try lying(id: 35, mode: 1, rules: lifecycle(lying: OriginalIDSet([38]))), 15)
        XCTAssertNotEqual(try lying(id: 38, mode: 1, rules: lifecycle(lying: OriginalIDSet([38]))), 15)
    }
    /// A VS round past its timer (0x450bdc ≥ 350) restores seat 0's character
    /// (Object 0): its Object afterwards.
    func revert(ids: [Int], rules: OriginalGameRules) throws -> UInt32 {
        var s = try NTSDProfileCatalog.state(ids: ids, rules: rules, zeroGlobals: true)
        for seat in 0..<400 { try s.world.write(UInt8(seat == 0 ? 1 : 0), at: 4+seat) }
        let a = Int(try s.world.integer(at: 0x194, as: UInt32.self))
        for (o, v): (Int, Int32) in [(0x368, 0), (0x324, -1), (0x328, -1), (0x2fc, 100), (0x364, 1)] { try s.actors[a].write(v, at: o) }
        try s.setGlobal(0x450bdc, 400)
        var context = OriginalInputControlContext(savedPlayback: try zero(0x320), memory: .init(replayPointers: try zero(8)))
        _ = try s.beginMatchRound(paused: false, context: &context)
        return try s.actors[a].integer(at: 0x368, as: UInt32.self)
    }
    func testRoundRevertA32() throws {
        XCTAssertEqual(try revert(ids: [50, 6, 1], rules: NTSDProfile.rules), 1, "50 reverts to the first 6")
        XCTAssertEqual(try revert(ids: [50, 6, 1], rules: lifecycle(from: 77)), 0)
        XCTAssertEqual(try revert(ids: [50, 6, 1], rules: lifecycle(to: 1)), 2)
        XCTAssertEqual(try revert(ids: [77, 6, 1], rules: lifecycle(from: 77)), 1)
    }
    /// Combo 8 (the hit_ja route) complete (progress 3 at +0xdc) for a character with
    /// this source ID and HP, its frame's hit_ja (+0x48) 300: whether the combo
    /// transferred (progress back to 0) or was held back (progress 3 kept).
    func comboTransferred(source: Int32, hp: Int32, rules: OriginalGameRules) throws -> Bool {
        var actor = try OriginalStateRecord.actor(over: [UInt8](repeating: 0, count: OriginalStateRecord.actorSize))
        try actor.write(UInt8(3), at: 0xd4+8); try actor.write(hp, at: 0x2fc); try actor.write(Int32(-1), at: 0x324)
        let globals = try zero(OriginalMatchPreparation.globalSize)
        var current = try zero(0x178); try current.write(Int32(300), at: 0x48)
        let c = current, target = try zero(0x178)
        try OriginalActorInput.recognizeCombos(actor: &actor, sourceID: source, globals: globals, rules: rules, frame: { $0 == 0 ? c : target })
        return try actor.integer(at: 0xd4+8, as: UInt8.self) == 0
    }
    func testGuardedTransformerA28() throws {
        let n = NTSDProfile.rules
        XCTAssertFalse(try comboTransferred(source: 6, hp: 200, rules: n), "6 above 177 HP: held back")
        XCTAssertTrue(try comboTransferred(source: 6, hp: 177, rules: n))
        XCTAssertTrue(try comboTransferred(source: 7, hp: 200, rules: n))
        XCTAssertTrue(try comboTransferred(source: 6, hp: 200, rules: lifecycle(guarded: 7)))
        XCTAssertFalse(try comboTransferred(source: 7, hp: 200, rules: lifecycle(guarded: 7)))
    }
}
