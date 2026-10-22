import XCTest
@testable import NTSDCore
@testable import NTSDProfile

/// ENGINE_SPLIT E5d-1a/1b/2: the character AI's target choice (A80–A86), fight
/// (A87–A91, A93–A98) and special-move hook follow the profile. Synthetic records; the pass's steps are run directly.
final class NTSDProfileCharacterAITests: XCTestCase {
    func zero(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0, count: size), defined: [Bool](repeating: true, count: size))
    }
    func characterAI(bound: Int32? = nil, ball: Int32? = nil, healers: OriginalIDSet? = nil, stateDanger: Int32? = nil,
                     frameDanger: Int32? = nil, pickup: OriginalIDRange? = nil, extra: Int32? = nil, sought: Int32? = nil,
                     avoided: Int32? = nil, defenders: [OriginalIDFrames]? = nil, drinks: OriginalIDSet? = nil,
                     band: OriginalIDSet? = nil, joiner: Int32? = nil, melee: OriginalIDSet? = nil, rolling: Int32? = nil,
                     thrown: OriginalIDSet? = nil, counters: OriginalIDSet? = nil, jumper: Int32? = nil,
                     short: Int32? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        // One value per statement: a single expression of these defaults outgrows the type checker.
        let bound: Int32 = bound ?? n.stageAllyBound, ball: Int32 = ball ?? n.healBall, healers: OriginalIDSet = healers ?? n.healers
        let stateDanger: Int32 = stateDanger ?? n.stateDanger, frameDanger: Int32 = frameDanger ?? n.frameDanger
        let pickup: OriginalIDRange = pickup ?? n.pickupItems, extra: Int32 = extra ?? n.pickupExtra
        let sought: Int32 = sought ?? n.soughtDrink, avoided: Int32 = avoided ?? n.avoidedDrink
        let defenders: [OriginalIDFrames] = defenders ?? n.idleDefenders, drinks: OriginalIDSet = drinks ?? n.drinks
        let band: OriginalIDSet = band ?? n.rangedBand, joiner: Int32 = joiner ?? n.rangedJoiner
        let melee: OriginalIDSet = melee ?? n.meleeWeapons, rolling: Int32 = rolling ?? n.rollingWeapon
        let thrown: OriginalIDSet = thrown ?? n.thrownWeapons, counters: OriginalIDSet = counters ?? n.dashCounters
        let jumper: Int32 = jumper ?? n.dashJumper, short: Int32 = short ?? n.shortDasher
        let ai = OriginalGameRules.CharacterAI(stageAllyBound: bound, healBall: ball, healers: healers, stateDanger: stateDanger,
            frameDanger: frameDanger, pickupItems: pickup, pickupExtra: extra, soughtDrink: sought, avoidedDrink: avoided,
            idleDefenders: defenders, drinks: drinks, rangedBand: band, rangedJoiner: joiner, meleeWeapons: melee, rollingWeapon: rolling,
            thrownWeapons: thrown, dashCounters: counters, dashJumper: jumper, shortDasher: short)
        return n.with(characterAI: ai)
    }
    /// The character (a type-0 Object with this ID, team 1, HP 500 of 500, at this
    /// frame) in slot 10 and another Object (this ID, type 1, team, frame, x, z and
    /// the state of that frame) in slot 20; with `held`, a third Object in slot 21
    /// that the character holds (+0x98 1, +0x9c 21). 0x450bb4 (the width) 1000,
    /// the difficulty 0x450c30 2, a random table of ones and one background.
    func pass(own: Int32, ownFrame: Int32 = 0, other: Int32 = 1, team: Int32 = 1, frame: Int32 = 0, x: Int32 = 0, z: Int32 = 0,
              state: Int32 = 0, held: Int32? = nil) throws -> OriginalCharacterAIPass {
        var world = try zero(0x7d8), globals = try zero(0xb440)
        for (slot, actor) in [(10, 0), (20, 1), (21, 2)] { try world.write(UInt32(actor), at: 0x194+4*slot) }
        for slot in held == nil ? [10, 20] : [10, 20, 21] { try world.write(UInt8(1), at: 4+slot) }
        try globals.write(Int32(1000), at: 0x450bb4-0x44d000); try globals.write(Int32(2), at: 0x450c30-0x44d000)
        for n in 0..<3000 { try globals.write(UInt8(1), at: 0x44ff90-0x44d000+n) }
        var actors = try (0..<3).map { _ in try zero(0x420) }
        for a in 0..<3 { try actors[a].write(UInt32(a), at: 0x368) }
        if held != nil { try actors[0].write(Int32(1), at: 0x98); try actors[0].write(Int32(21), at: 0x9c) }
        try actors[1].write(x, at: 0x10)
        for o in [0x2fc, 0x300, 0x304] { try actors[0].write(Int32(500), at: o) }
        try actors[0].write(Int32(1), at: 0x364); try actors[0].write(ownFrame, at: 0x70)
        try actors[1].write(team, at: 0x364); try actors[1].write(frame, at: 0x70); try actors[1].write(z, at: 0x18)
        func object(_ id: Int32, type: Int32, frames: Int, state: Int32) throws -> OriginalLoadedObject {
            var header = try zero(0x7a4); try header.write(id, at: 0x6f4); try header.write(type, at: 0x6f8)
            var f = try zero(0x178); try f.write(state, at: 8)
            return OriginalLoadedObject(header: header, nameTail: try zero(0x3c), frames: [],
                                        frameStorage: [OriginalStateRecord](repeating: f, count: frames), weaponSoundPaths: [:])
        }
        let objects = [try object(own, type: 0, frames: 1, state: 0), try object(other, type: 1, frames: Int(frame)+1, state: state),
                       try object(held ?? 0, type: 1, frames: 1, state: 0)]
        return OriginalCharacterAIPass(world: world, actors: actors, globals: globals, objects: objects, objectCount: 3,
                                       backgrounds: [try zero(0x100)], sse2: false)
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
    /// The random streams one step drew (a branch is told by its streams).
    func streams(_ p: OriginalCharacterAIPass) -> [Int32] { p.events.map { if case let .random(stream, _, _) = $0 { return stream }; return -1 } }
    /// `fight` for the character with the Object in slot 20 as its target.
    func fight(_ p: OriginalCharacterAIPass, rules: OriginalGameRules) throws -> [Int32] {
        var p = p, l = OriginalCharacterAIPass.Locals(); l.target = 20
        try p.fight(0, slot: 10, mode: 0, &l, rules: rules)
        return streams(p)
    }
    func testDrinksAndHealBallInFightA87A88() throws {
        let n = NTSDProfile.rules
        func drinker(_ held: Int32) throws -> OriginalCharacterAIPass {
            var p = try pass(own: 3, other: 3, held: held); try p.actors[0].write(Int32(1), at: 0x404); return p
        }
        // A87: with +0x404 1 a held drink is drunk at once: only the entry roll 0x14.
        XCTAssertEqual(try fight(drinker(122), rules: n), [0x14]); XCTAssertEqual(try fight(drinker(123), rules: n), [0x14])
        XCTAssertTrue(try fight(drinker(150), rules: n).contains(0x3c), "not a drink: on to the special roll")
        XCTAssertTrue(try fight(drinker(122), rules: characterAI(drinks: OriginalIDSet([150]))).contains(0x3c))
        XCTAssertEqual(try fight(drinker(150), rules: characterAI(drinks: OriginalIDSet([150]))), [0x14])
        // A88: a target ball is walked onto, before the special roll.
        XCTAssertEqual(try fight(pass(own: 3, other: 200, x: 50), rules: n), [0x14])
        XCTAssertTrue(try fight(pass(own: 3, other: 200, x: 50), rules: characterAI(ball: 77)).contains(0x3c))
        XCTAssertEqual(try fight(pass(own: 3, other: 77, x: 50), rules: characterAI(ball: 77)), [0x14])
    }
    func testRangedBandAndJoinerA89A90() throws {
        let n = NTSDProfile.rules
        // approach: the band closes in from beyond 170 (stream 0x1a), the others from beyond 60 (0x1c).
        func approach(_ own: Int32, _ rules: OriginalGameRules) throws -> [Int32] {
            var p = try pass(own: own, x: 200), l = OriginalCharacterAIPass.Locals()
            try p.approach(0, 1, slot: 10, mode: 0, &l, rules: rules); return streams(p)
        }
        for own: Int32 in [4, 5, 31] { XCTAssertEqual(try approach(own, n), [0x1a], "\(own)") }
        XCTAssertEqual(try approach(7, n), [0x1c])
        XCTAssertEqual(try approach(4, characterAI(band: OriginalIDSet([7]))), [0x1c])
        XCTAssertEqual(try approach(7, characterAI(band: OriginalIDSet([7]))), [0x1a])
        // tactics: the close attack (0x21) is for those outside the band; the band and the joiner step away (0x23).
        func tactics(_ own: Int32, _ rules: OriginalGameRules) throws -> (close: Bool, away: Bool) {
            var p = try pass(own: own, x: 50), l = OriginalCharacterAIPass.Locals()
            try p.tactics(0, 1, slot: 10, mode: 0, &l, rules: rules); let s = streams(p)
            return (s.contains(0x21), s.contains(0x23))
        }
        XCTAssertTrue(try tactics(4, n) == (false, true)); XCTAssertTrue(try tactics(36, n) == (true, true))
        XCTAssertTrue(try tactics(7, n) == (true, false))
        XCTAssertTrue(try tactics(7, characterAI(band: OriginalIDSet([7]))) == (false, true))
        XCTAssertTrue(try tactics(36, characterAI(joiner: 7)) == (true, false))
        XCTAssertTrue(try tactics(7, characterAI(joiner: 7)) == (true, true))
    }
    func testDrinkTargetsA91() throws {
        let n = NTSDProfile.rules
        // item: a far target (+0x404 1, 300 away) is walked to only when a drink.
        func walks(_ other: Int32, _ rules: OriginalGameRules) throws -> Bool {
            var p = try pass(own: 7, other: other, x: 300), l = OriginalCharacterAIPass.Locals()
            try p.actors[0].write(Int32(1), at: 0x404)
            try p.item(0, 1, &l, rules: rules); return try p.actors[0].integer(at: 0xd0, as: UInt8.self) == 1
        }
        XCTAssertTrue(try walks(122, n)); XCTAssertTrue(try walks(123, n)); XCTAssertFalse(try walks(150, n))
        XCTAssertFalse(try walks(122, characterAI(drinks: OriginalIDSet([150])))); XCTAssertTrue(try walks(150, characterAI(drinks: OriginalIDSet([150]))))
    }
    func testHeldWeaponsA93A94A95() throws {
        let n = NTSDProfile.rules
        func weapon(_ held: Int32, _ rules: OriginalGameRules, own: Int32 = 7, x: Int32 = 50, counter: Int32 = 0) throws -> (going: Bool, streams: [Int32]) {
            var p = try pass(own: own, x: x, held: held), l = OriginalCharacterAIPass.Locals()
            try p.setG(0x44f604, 1000); try p.setG(0x450c34, counter); try p.actors[0].write(Int32(200), at: 0x308)
            let going = try p.weapon(0, 1, slot: 10, l, rules: rules); return (going, streams(p))
        }
        // A93: melee swings (0x2a), the rolling one's extra roll (0x2b); A94: a throw (0x2d); A95: a drink stops (false).
        for held: Int32 in [100, 101, 120, 121, 124] { XCTAssertTrue(try weapon(held, n).streams.contains(0x2a), "\(held)") }
        XCTAssertFalse(try weapon(100, n).streams.contains(0x2b))
        XCTAssertTrue(try weapon(124, n).streams.contains(0x2b)); XCTAssertFalse(try weapon(150, n).streams.contains(0x2a))
        XCTAssertFalse(try weapon(100, characterAI(melee: OriginalIDSet([150]))).streams.contains(0x2a))
        XCTAssertTrue(try weapon(150, characterAI(melee: OriginalIDSet([150]))).streams.contains(0x2a))
        XCTAssertFalse(try weapon(124, characterAI(rolling: 100)).streams.contains(0x2b))
        XCTAssertTrue(try weapon(100, characterAI(rolling: 100)).streams.contains(0x2b))
        XCTAssertTrue(try weapon(150, n).streams.contains(0x2d)); XCTAssertTrue(try weapon(151, n).streams.contains(0x2d))
        XCTAssertFalse(try weapon(100, n).streams.contains(0x2d))
        XCTAssertFalse(try weapon(150, characterAI(thrown: OriginalIDSet([100]))).streams.contains(0x2d))
        XCTAssertTrue(try weapon(100, characterAI(thrown: OriginalIDSet([100]))).streams.contains(0x2d))
        XCTAssertFalse(try weapon(122, n).going); XCTAssertFalse(try weapon(123, n).going); XCTAssertTrue(try weapon(150, n).going)
        XCTAssertTrue(try weapon(122, characterAI(drinks: OriginalIDSet([150]))).going)
        XCTAssertFalse(try weapon(150, characterAI(drinks: OriginalIDSet([150]))).going)
        // A95: a healer holding a drink, away from the target, on a passed 1-in-5 roll (0x34), rolls 0x35.
        let counter = try XCTUnwrap((0..<20).first { c in
            ((try? weapon(122, n, own: 2, x: 500, counter: Int32(c)).streams) ?? []).contains(0x35)
        }.map(Int32.init))
        XCTAssertTrue(try weapon(122, n, own: 34, x: 500, counter: counter).streams.contains(0x35))
        XCTAssertFalse(try weapon(122, n, own: 7, x: 500, counter: counter).streams.contains(0x35))
        XCTAssertTrue(try weapon(122, characterAI(healers: OriginalIDSet([7])), own: 7, x: 500, counter: counter).streams.contains(0x35))
        XCTAssertFalse(try weapon(122, characterAI(healers: OriginalIDSet([7])), own: 2, x: 500, counter: counter).streams.contains(0x35))
    }
    func testDashCountersA96A97A98() throws {
        let n = NTSDProfile.rules
        // attackHelper at frame 110, facing a target this far: the counter's defence roll (0x39), the short
        // dasher's (0x3b), the dash jumper's coin (0x3a).
        func helper(_ own: Int32, _ rules: OriginalGameRules, x: Int32 = 500) throws -> [Int32] { try run(own, rules, x: x).streams }
        func run(_ own: Int32, _ rules: OriginalGameRules, x: Int32) throws -> (streams: [Int32], attack: Bool) {
            var p = try pass(own: own, ownFrame: 110, x: x), l = OriginalCharacterAIPass.Locals()
            try p.attackHelper(0, 1, l, rules: rules)
            return (streams(p), try p.actors[0].integer(at: 0xd1, as: UInt8.self) == 1)
        }
        for own: Int32 in [2, 4, 6, 9, 10, 11, 8, 7, 33, 34] { XCTAssertTrue(try helper(own, n).contains(0x39), "\(own)") }
        XCTAssertFalse(try helper(5, n).contains(0x39))
        XCTAssertFalse(try helper(2, characterAI(counters: OriginalIDSet([5]))).contains(0x39))
        XCTAssertTrue(try helper(5, characterAI(counters: OriginalIDSet([5]))).contains(0x39))
        XCTAssertTrue(try helper(34, n).contains(0x3a)); XCTAssertFalse(try helper(2, n).contains(0x3a))
        XCTAssertFalse(try helper(34, characterAI(jumper: 2)).contains(0x3a)); XCTAssertTrue(try helper(2, characterAI(jumper: 2)).contains(0x3a))
        XCTAssertFalse(try helper(5, characterAI(jumper: 5)).contains(0x3a), "the jumper dashes only among the counters")
        // The counters' dash (A96's second use) carries the jumper.
        XCTAssertTrue(try helper(5, characterAI(counters: OriginalIDSet([5]), jumper: 5)).contains(0x3a))
        XCTAssertFalse(try helper(34, characterAI(counters: OriginalIDSet([5]))).contains(0x3a))
        XCTAssertTrue(try helper(1, n, x: 200).contains(0x3b)); XCTAssertFalse(try helper(5, n, x: 200).contains(0x3b))
        XCTAssertFalse(try helper(1, characterAI(short: 5), x: 200).contains(0x3b))
        XCTAssertTrue(try helper(5, characterAI(short: 5), x: 200).contains(0x3b))
        // The short dasher's dash (A97's second use) attacks at 200 (beyond the close attack's 80); it draws no stream.
        XCTAssertTrue(try run(1, n, x: 200).attack); XCTAssertFalse(try run(5, n, x: 200).attack)
        XCTAssertTrue(try run(5, characterAI(short: 5), x: 200).attack); XCTAssertFalse(try run(1, characterAI(short: 5), x: 200).attack)
    }
    /// Stateless special moves for the tests: each stores the own id it was given
    /// in the command byte +0xd4, then ends or goes on with `fight`.
    struct EndsFight: OriginalCharacterAISpecial {
        func special(own: Int32,_ ai: inout OriginalCharacterAIPass,s: Int,t: Int,slot: Int,_ l: OriginalCharacterAIPass.Locals) throws -> Bool {
            try ai.byte(s,0xd4,UInt8(truncatingIfNeeded: own)); return true
        }
    }
    struct GoesOn: OriginalCharacterAISpecial {
        func special(own: Int32,_ ai: inout OriginalCharacterAIPass,s: Int,t: Int,slot: Int,_ l: OriginalCharacterAIPass.Locals) throws -> Bool {
            try ai.byte(s,0xd4,UInt8(truncatingIfNeeded: own)); return false
        }
    }
    func testSpecialMoveHookE5d2() throws {
        let n = NTSDProfile.rules, ends = n.with(characterAISpecial: EndsFight()), goes = n.with(characterAISpecial: GoesOn())
        // The entry roll comes first: with 0x44f618 = 5 its range is 6; from counter 0 it rolls 2
        // (no call), from counter 4 it rolls 0 (the hook gets the own id).
        func special(_ rules: OriginalGameRules, counter: Int32) throws -> (result: Bool, seen: UInt8, streams: [Int32]) {
            var p = try pass(own: 7), l = OriginalCharacterAIPass.Locals()
            try p.setG(0x44f618, 5); try p.setG(0x450c34, counter)
            let result = try p.special(0, 1, slot: 10, l, rules: rules)
            return (result, try p.actors[0].integer(at: 0xd4, as: UInt8.self), streams(p))
        }
        for (rules, counter, result, seen): (OriginalGameRules, Int32, Bool, UInt8) in [(ends, 0, false, 0), (ends, 4, true, 7), (goes, 4, false, 7)] {
            let r = try special(rules, counter: counter)
            XCTAssertEqual(r.result, result); XCTAssertEqual(r.seen, seen); XCTAssertEqual(r.streams, [0x3c])
        }
        // True ends `fight` right after the roll; false goes on to the approach and tactics.
        XCTAssertEqual(try fight(pass(own: 3, other: 3, x: 50), rules: ends), [0x14, 0x3c])
        let goesOn = try fight(pass(own: 3, other: 3, x: 50), rules: goes)
        XCTAssertGreaterThan(goesOn.count, 2)
        XCTAssertEqual(goesOn, try fight(pass(own: 3, other: 3, x: 50), rules: n), "false goes on as NTSD's own (no routine for 3)")
        // NTSD's routines are LF2 2.0a's, the engine's default (E6c; the game's in E5d-3); rules differ by the hook's type.
        XCTAssertTrue(n.characterAISpecial is OriginalLF2CharacterAISpecial)
        XCTAssertNotEqual(n, n.with(profile: n.profile, characterAISpecial: EndsFight()))
        XCTAssertNotEqual(ends, goes); XCTAssertEqual(ends, n.with(characterAISpecial: EndsFight()))
        XCTAssertEqual(n, n.with(profile: n.profile))
    }
    /// E5d-3, E6c: the routines (in the game, then back in the engine) resolve the pass's own `abs` (`0 &- v`,
    /// wrapping), not `Swift.abs`, which traps on `Int32.min`.
    func testMovedRoutinesUseThePassAbs() throws {
        let p = try pass(own: 7, x: Int32.min, z: Int32.min)
        XCTAssertEqual(try p.dx(0, 1), Int32.min); XCTAssertEqual(try p.dz(0, 1), Int32.min)
        XCTAssertEqual(p.abs(Int32.min), Int32.min); XCTAssertEqual(p.abs(-5), 5)
    }
}
