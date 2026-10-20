import XCTest
@testable import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E5d-1a: the character AI's target choice (A80–A86) follows the
/// profile. Synthetic records; the pass's steps are run directly.
final class NTSDProfileCharacterAITests: XCTestCase {
    func zero(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0, count: size), defined: [Bool](repeating: true, count: size))
    }
    func characterAI(bound: Int32? = nil, ball: Int32? = nil, healers: OriginalIDSet? = nil, stateDanger: Int32? = nil,
                     frameDanger: Int32? = nil, pickup: OriginalIDRange? = nil, extra: Int32? = nil, sought: Int32? = nil,
                     avoided: Int32? = nil, defenders: [OriginalIDFrames]? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(characterAI: .init(stageAllyBound: bound ?? n.stageAllyBound, healBall: ball ?? n.healBall, healers: healers ?? n.healers,
            stateDanger: stateDanger ?? n.stateDanger, frameDanger: frameDanger ?? n.frameDanger, pickupItems: pickup ?? n.pickupItems,
            pickupExtra: extra ?? n.pickupExtra, soughtDrink: sought ?? n.soughtDrink, avoidedDrink: avoided ?? n.avoidedDrink,
            idleDefenders: defenders ?? n.idleDefenders))
    }
    /// The character (a type-0 Object with this ID, team 1, HP 500 of 500, at this
    /// frame) in slot 10 and another Object (this ID, type 1, team, frame, z and
    /// the state of that frame) in slot 20; 0x450bb4 (the width) 1000 and the
    /// difficulty 0x450c30 2.
    func pass(own: Int32, ownFrame: Int32 = 0, other: Int32 = 1, team: Int32 = 1, frame: Int32 = 0, z: Int32 = 0,
              state: Int32 = 0) throws -> OriginalCharacterAIPass {
        var world = try zero(0x7d8), globals = try zero(0xb440)
        for (slot, actor) in [(10, 0), (20, 1)] { try world.write(UInt32(actor), at: 0x194+4*slot); try world.write(UInt8(1), at: 4+slot) }
        try globals.write(Int32(1000), at: 0x450bb4-0x44d000); try globals.write(Int32(2), at: 0x450c30-0x44d000)
        var actors = try (0..<2).map { _ in try zero(0x420) }
        for a in 0..<2 { try actors[a].write(UInt32(a), at: 0x368) }
        for o in [0x2fc, 0x300, 0x304] { try actors[0].write(Int32(500), at: o) }
        try actors[0].write(Int32(1), at: 0x364); try actors[0].write(ownFrame, at: 0x70)
        try actors[1].write(team, at: 0x364); try actors[1].write(frame, at: 0x70); try actors[1].write(z, at: 0x18)
        func object(_ id: Int32, type: Int32, frames: Int, state: Int32) throws -> OriginalLoadedObject {
            var header = try zero(0x7a4); try header.write(id, at: 0x6f4); try header.write(type, at: 0x6f8)
            var f = try zero(0x178); try f.write(state, at: 8)
            return OriginalLoadedObject(header: header, nameTail: try zero(0x3c), frames: [],
                                        frameStorage: [OriginalStateRecord](repeating: f, count: frames), weaponSoundPaths: [:])
        }
        let objects = [try object(own, type: 0, frames: 1, state: 0), try object(other, type: 1, frames: Int(frame)+1, state: state)]
        return OriginalCharacterAIPass(world: world, actors: actors, globals: globals, objects: objects, objectCount: 2, backgrounds: [],
                                       sse2: false)
    }
    /// A80: the AI level `setup` stores (0x44f60c) for the character in this slot, in mode 1.
    func level(own: Int32, slot: Int, rules: OriginalGameRules) throws -> Int32 {
        var p = try pass(own: own), l = OriginalCharacterAIPass.Locals()
        try p.setup(0, slot: slot, mode: 1, &l, rules: rules)
        return try p.g(0x44f60c)
    }
    func testStageAllyBoundA80() throws {
        let n = NTSDProfile.rules
        XCTAssertEqual(try level(own: 30, slot: 20, rules: n), 2)
        XCTAssertEqual(try level(own: 29, slot: 20, rules: n), 0)
        XCTAssertEqual(try level(own: 30, slot: 19, rules: n), 0, "slots below 20 never read the bound")
        XCTAssertEqual(try level(own: 30, slot: 20, rules: characterAI(bound: 31)), 0)
        XCTAssertEqual(try level(own: 31, slot: 20, rules: characterAI(bound: 31)), 2)
    }
    /// `items` for the character over the Object in slot 20, from these locals.
    func items(_ p: OriginalCharacterAIPass, rules: OriginalGameRules,
               _ set: (inout OriginalCharacterAIPass.Locals) -> Void = { _ in }) throws -> OriginalCharacterAIPass.Locals {
        var p = p, l = OriginalCharacterAIPass.Locals(); set(&l)
        try p.items(0, &l, rules: rules)
        return l
    }
    func testHealBallAndHealersA81A84() throws {
        let n = NTSDProfile.rules
        // A81: an enemy's ball in frames 60–69 keeps the enemy target (near48).
        XCTAssertEqual(try items(pass(own: 7, other: 200, team: 2, frame: 60), rules: n).near48, 1)
        XCTAssertEqual(try items(pass(own: 7, other: 200, team: 2, frame: 60), rules: characterAI(ball: 77)).near48, 0)
        XCTAssertEqual(try items(pass(own: 7, other: 77, team: 2, frame: 60), rules: characterAI(ball: 77)).near48, 1)
        // A81: its own team's in frames 50–59, for a healer.
        XCTAssertEqual(try items(pass(own: 2, other: 200, frame: 50), rules: n).near48, 1)
        XCTAssertEqual(try items(pass(own: 7, other: 200, frame: 50), rules: n).near48, 0)
        XCTAssertEqual(try items(pass(own: 7, other: 200, frame: 50), rules: characterAI(healers: OriginalIDSet([7]))).near48, 1)
        XCTAssertEqual(try items(pass(own: 2, other: 200, frame: 50), rules: characterAI(healers: OriginalIDSet([7]))).near48, 0)
        // A84: its own team's within 300×90 is seen (seen44) by a non-healer too.
        XCTAssertEqual(try items(pass(own: 7, other: 200, frame: 50), rules: n).seen44, 1)
        XCTAssertEqual(try items(pass(own: 7, other: 200, frame: 50), rules: characterAI(ball: 77)).seen44, 0)
        XCTAssertEqual(try items(pass(own: 7, other: 77, frame: 50), rules: characterAI(ball: 77)).seen44, 1)
    }
    func testDangersA82() throws {
        let n = NTSDProfile.rules
        XCTAssertEqual(try items(pass(own: 7, other: 211, z: 30, state: 18), rules: n).down3c, 1)
        XCTAssertEqual(try items(pass(own: 7, other: 211, z: 30, state: 17), rules: n).down3c, 0)
        XCTAssertEqual(try items(pass(own: 7, other: 211, z: 30, state: 18), rules: characterAI(stateDanger: 77)).down3c, 0)
        XCTAssertEqual(try items(pass(own: 7, other: 77, z: 30, state: 18), rules: characterAI(stateDanger: 77)).down3c, 1)
        XCTAssertEqual(try items(pass(own: 7, other: 212, frame: 160, z: 30), rules: n).down3c, 1)
        XCTAssertEqual(try items(pass(own: 7, other: 212, frame: 171, z: 30), rules: n).down3c, 0)
        XCTAssertEqual(try items(pass(own: 7, other: 212, frame: 160, z: 30), rules: characterAI(frameDanger: 77)).down3c, 0)
        XCTAssertEqual(try items(pass(own: 7, other: 77, frame: 160, z: 30), rules: characterAI(frameDanger: 77)).down3c, 1)
    }
    func testPickupsAndDrinksA83A85() throws {
        let n = NTSDProfile.rules
        func target(_ other: Int32, _ rules: OriginalGameRules, state: Int32 = 1004, flag404: Bool = false,
                    _ set: (inout OriginalCharacterAIPass.Locals) -> Void = { _ in }) throws -> Int32 {
            var p = try pass(own: 7, other: other, state: state)
            if flag404 { try p.actors[0].write(Int32(1), at: 0x404) }
            return try items(p, rules: rules, set).target
        }
        XCTAssertEqual(try target(150, n), 20); XCTAssertEqual(try target(213, n), 20); XCTAssertEqual(try target(150, n, state: 2004), 20)
        XCTAssertEqual(try target(99, n), -1); XCTAssertEqual(try target(200 + 13, n, state: 17), -1)
        XCTAssertEqual(try target(150, characterAI(pickup: OriginalIDRange(0..<0))), -1)
        XCTAssertEqual(try target(213, characterAI(extra: 77)), -1)
        XCTAssertEqual(try target(77, characterAI(extra: 77)), 20)
        XCTAssertEqual(try target(5, characterAI(pickup: OriginalIDRange(0..<10))), 20)
        // A83: the drinks a healthy or avoiding character skips; +0x404 = 1 picks only the sought one.
        XCTAssertEqual(try target(122, n) { $0.healthy18 = 1 }, -1)
        XCTAssertEqual(try target(123, n) { $0.healthy18 = 1 }, 20)
        XCTAssertEqual(try target(122, characterAI(sought: 123)) { $0.healthy18 = 1 }, 20)
        XCTAssertEqual(try target(123, n) { $0.avoid2c = 1 }, -1)
        XCTAssertEqual(try target(123, characterAI(avoided: 122)) { $0.avoid2c = 1 }, 20)
        XCTAssertEqual(try target(122, characterAI(avoided: 122)) { $0.avoid2c = 1 }, -1)
        XCTAssertEqual(try target(122, n, flag404: true), 20); XCTAssertEqual(try target(150, n, flag404: true), -1)
        XCTAssertEqual(try target(123, characterAI(sought: 123), flag404: true), 20)
        XCTAssertEqual(try target(122, characterAI(sought: 123), flag404: true), -1)
        // A85: a hurt character takes the sought drink in state 1004 (seen44), whatever it picks up.
        func seen(_ other: Int32, _ rules: OriginalGameRules) throws -> Int32 {
            try items(pass(own: 7, other: other, state: 1004), rules: rules) { $0.hurt1c = 1 }.seen44
        }
        XCTAssertEqual(try seen(122, n), 1); XCTAssertEqual(try seen(123, n), 0)
        XCTAssertEqual(try seen(122, characterAI(sought: 123)), 0); XCTAssertEqual(try seen(123, characterAI(sought: 123)), 1)
    }
    /// A86: whether `idle` presses defend (Actor+0xd3) for the character at this frame.
    func defends(own: Int32, frame: Int32, rules: OriginalGameRules) throws -> Bool {
        var p = try pass(own: own, ownFrame: frame), l = OriginalCharacterAIPass.Locals()
        try p.idle(0, &l, rules: rules)
        return try p.actors[0].integer(at: 0xd3, as: UInt8.self) == 1
    }
    func testIdleDefendersA86() throws {
        let n = NTSDProfile.rules
        for (id, first, last): (Int32, Int32, Int32) in [(7, 255, 261), (9, 280, 290), (32, 240, 245)] {
            XCTAssertFalse(try defends(own: id, frame: first-1, rules: n)); XCTAssertTrue(try defends(own: id, frame: first, rules: n))
            XCTAssertTrue(try defends(own: id, frame: last, rules: n)); XCTAssertFalse(try defends(own: id, frame: last+1, rules: n))
        }
        XCTAssertFalse(try defends(own: 8, frame: 258, rules: n))
        let moved = characterAI(defenders: [OriginalIDFrames(8, frames: 255...261)])
        XCTAssertTrue(try defends(own: 8, frame: 258, rules: moved)); XCTAssertFalse(try defends(own: 7, frame: 258, rules: moved))
        let shifted = characterAI(defenders: [OriginalIDFrames(7, frames: 300...302)])
        XCTAssertFalse(try defends(own: 7, frame: 258, rules: shifted)); XCTAssertTrue(try defends(own: 7, frame: 301, rules: shifted))
        for (id, frame): (Int32, Int32) in [(7, 258), (9, 285), (32, 242)] {
            XCTAssertFalse(try defends(own: id, frame: frame, rules: characterAI(defenders: [])))
        }
    }
}
