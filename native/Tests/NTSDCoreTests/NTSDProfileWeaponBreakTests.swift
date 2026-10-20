import XCTest
@testable import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E5e-5: a weapon's break (A52–A54) takes its pieces, their Object
/// and each weapon's draws from the profile. Synthetic records; the post-draw
/// lifecycle runs one slot whose weapon creation breaks the weapon.
final class NTSDProfileWeaponBreakTests: XCTestCase {
    func zero(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0, count: size), defined: [Bool](repeating: true, count: size))
    }
    func rules(fragments: [Int32: Int32]? = nil, object: Int32? = nil, high: OriginalIDSet? = nil, low: OriginalIDSet? = nil,
               frames10: Int32? = nil, frame174: OriginalIDSet? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules, w = n.weaponBreak
        return n.with(weaponBreak: .init(fragments: fragments ?? w.fragments, fragmentObject: object ?? w.fragmentObject,
            highToss: high ?? w.highToss, lowToss: low ?? w.lowToss, frames0: w.frames0, frames10: frames10 ?? w.frames10,
            frames150: w.frames150, frames20: w.frames20, frames40: w.frames40, frames54: w.frames54, frame170: w.frame170,
            frame60: w.frame60, frames70: w.frames70, frames160: w.frames160, frame174: frame174 ?? w.frame174))
    }
    /// Slot 1 holds the weapon (catalog entry 0: this ID, type 1, +0x31c −1) and breaks
    /// it, over a catalog of the weapon and `others`: the pieces made, the random
    /// streams drawn, the error if any.
    func breakWeapon(_ id: Int32, others: [Int32] = [999], rules: OriginalGameRules) throws
        -> (pieces: Int, streams: [Int32], draws: [[Int32]], error: String?) {
        let b = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5, count: 0x7d8),
            actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5, count: 0x420), count: 400), selector: 2)
        var world = b.world, actors = b.actors, globals = try zero(0xb440)
        for slot in 0..<400 { try world.write(UInt8(slot < 2 ? 1 : 0), at: 4+slot) }
        for i in 0..<3000 { try globals.write(UInt8(1), at: 0x44ff90-0x44d000+i) }
        let headers = try ([id] + others).map { n -> OriginalStateRecord in
            var h = try zero(0x7a4); try h.write(n, at: 0x6f4); try h.write(Int32(1), at: 0x6f8)
            try h.write(Int32(20), at: 0x90); try h.write(Int32(-1), at: 0xac); return h
        }
        var first = try zero(0x178), second = try zero(0x178)
        try first.write(Int32(3), at: 8); try first.write(Int32(-1), at: 0x174)
        try second.write(Int32(13), at: 8); try second.write(Int32(-1), at: 0x174)
        let frames = [first, second]
        func frame(_ number: Int32) throws -> OriginalStateRecord {
            guard frames.indices.contains(Int(number)) else { throw OriginalStateError.invalidStorage("Test frame \(number)") }
            return frames[Int(number)]
        }
        for slot in 0..<2 {
            let a = Int(try world.integer(at: 0x194+4*slot, as: UInt32.self))
            for offset in [0x70, 0x78, 0x88, 0xb4] { try actors[a].write(Int32(0), at: offset) }
            try actors[a].write(Int32(100), at: 0x2fc); try actors[a].write(UInt32(0), at: 0x368)
        }
        try actors[Int(try world.integer(at: 0x194+4, as: UInt32.self))].write(Int32(-1), at: 0x31c)
        var scratch = OriginalPostDrawScratch(requestSlot: .initial()), pieces = 0, streams: [Int32] = [], draws: [[Int32]] = []
        do {
            try OriginalPostDrawLifecycle.apply(world: &world, actors: &actors, globals: &globals, scratch: &scratch, wholeLoop: false, slot: 1,
                precision: .bits53, sse2: false, objectCount: Int32(headers.count), header: { headers[$0] },
                frame: { _, number in try frame(number) }, rules: rules, observe: { event in
                    switch event {
                    case .reconstruct: pieces += 1
                    case let .random(_, stream, range, _): streams.append(stream); draws.append([stream, range])
                    default: break
                    }
                })
        } catch { return (pieces, streams, draws, "\(error)") }
        return (pieces, streams, draws, nil)
    }
    func testFragmentsAndTheirObjectA52A53() throws {
        let n = NTSDProfile.rules
        for (id, count): (Int32, Int) in [(101, 7), (218, 7), (100, 5), (213, 5), (217, 5), (201, 3), (150, 13), (151, 15), (120, 3),
                                          (124, 3), (121, 4), (122, 9), (123, 9), (7, 0)] {
            let r = try breakWeapon(id, rules: n)
            XCTAssertNil(r.error, "\(id)"); XCTAssertEqual(r.pieces, count, "\(id)")
        }
        XCTAssertEqual(try breakWeapon(100, rules: rules(fragments: [100: 2])).pieces, 2)
        XCTAssertEqual(try breakWeapon(7, rules: rules(fragments: [7: 4])).pieces, 4)
        // The piece Object: none in the catalog and none kept from earlier: the error.
        XCTAssertEqual(try breakWeapon(100, others: [998], rules: n).error,
                       "\(OriginalStateError.invalidStorage("Post-draw lifecycle: Weapon Object index provenance"))")
        XCTAssertEqual(try breakWeapon(100, others: [998], rules: rules(object: 998)).pieces, 5)
    }
    func testEachWeaponsDrawsA54() throws {
        let n = NTSDProfile.rules
        // Each weapon's own streams besides the position draws (166, 167) and the x speed (170).
        let own: [(Int32, Set<Int32>)] = [(150, [168, 171, 172]), (151, [168, 180, 181, 182, 183]), (213, [168, 175, 176]),
            (100, [169, 173, 174]), (201, [169]), (101, [169, 177, 178, 179]), (120, [169, 184, 185]), (121, [169, 187]),
            (122, [169, 188, 189, 190, 191]), (123, [169, 192, 193, 194, 195]), (124, [169, 186]), (217, [169, 196]), (218, [169, 196])]
        for (id, streams) in own {
            let r = try breakWeapon(id, rules: n)
            XCTAssertEqual(Set(r.streams).subtracting([166, 167, 170]), streams, "\(id)")
            XCTAssertEqual(Array(r.streams.prefix(4)), [166, 167, streams.contains(168) ? 168 : 169, 170], "\(id): the first piece's order")
        }
        // Moved roles: the toss sets, a frame branch and the 174 set.
        XCTAssertEqual(Set(try breakWeapon(100, rules: rules(high: OriginalIDSet([100]), low: OriginalIDSet([]))).streams), [166, 167, 168, 170, 173, 174])
        XCTAssertEqual(Set(try breakWeapon(100, rules: rules(frames10: 77)).streams), [166, 167, 169, 170])
        XCTAssertEqual(Set(try breakWeapon(201, rules: rules(frames10: 201)).streams), [166, 167, 169, 170, 173, 174])
        XCTAssertFalse(try breakWeapon(217, rules: rules(frame174: OriginalIDSet([201]))).streams.contains(196))
        XCTAssertTrue(try breakWeapon(201, rules: rules(frame174: OriginalIDSet([201]))).streams.contains(196))
    }
    /// The streams and ranges HEAD's `weapon` draws for `count` pieces of a weapon whose
    /// frame branch is `branch` (an NTSD weapon ID, or nil) and whose toss is `toss`
    /// (168, 169 or nil): the specification the profile's roles must keep.
    static func expected(branch: Int32?, toss: Int32?, count: Int) -> [[Int32]] {
        var out: [[Int32]] = []
        for k in 0..<count {
            out += [[166, 7], [167, 7]]
            if let toss { out.append([toss, toss == 168 ? 20 : 8]) }
            out.append([170, 11])
            switch branch {
            case 150: out.append([k < 5 ? 171 : 172, 4])
            case 100: out.append([k < 2 ? 173 : 174, 4])
            case 213: out.append([k < 2 ? 175 : 176, 4])
            case 101: out += k < 5 ? [[177, 2], [178, 4]] : [[179, 4]]
            case 151: out.append([k < 2 ? 180 : k < 5 ? 181 : k < 8 ? 182 : 183, 4])
            case 120: if k < 5 { out.append([k < 2 ? 184 : 185, 4]) }
            case 124: out.append([186, 4])
            case 121: out.append([187, 4])
            case 122: out += k < 1 ? [[188, 4]] : k < 3 ? [[189, 4]] : [[190, 4], [191, 18]]
            case 123: out += k < 1 ? [[192, 4]] : k < 3 ? [[193, 4]] : [[194, 4], [195, 18]]
            case 217, 218: out.append([196, 4])
            default: break
            }
        }
        return out
    }
    func testExactDrawsA54() throws {
        let n = NTSDProfile.rules
        for (id, count): (Int32, Int) in [(101, 7), (218, 7), (100, 5), (213, 5), (217, 5), (201, 3), (150, 13), (151, 15), (120, 3),
                                          (124, 3), (121, 4), (122, 9), (123, 9)] {
            let toss: Int32 = [150, 151, 213].contains(id) ? 168 : 169
            XCTAssertEqual(try breakWeapon(id, rules: n).draws, Self.expected(branch: id, toss: toss, count: count), "\(id)")
        }
        // Each frame role moved onto 7 (15 pieces, no toss): 7 takes that branch.
        let w = n.weaponBreak
        let roles: [(Int32, Int)] = [(150, 0), (100, 1), (213, 2), (101, 3), (151, 4), (120, 5), (124, 6), (121, 7), (122, 8), (123, 9)]
        for (branch, k) in roles {
            var f = [w.frames0, w.frames10, w.frames150, w.frames20, w.frames40, w.frames54, w.frame170, w.frame60, w.frames70, w.frames160]
            f[k] = 7
            let moved = n.with(weaponBreak: .init(fragments: w.fragments.merging([7: 15]) { $1 }, fragmentObject: w.fragmentObject,
                highToss: w.highToss, lowToss: w.lowToss, frames0: f[0], frames10: f[1], frames150: f[2], frames20: f[3], frames40: f[4],
                frames54: f[5], frame170: f[6], frame60: f[7], frames70: f[8], frames160: f[9], frame174: w.frame174))
            XCTAssertEqual(try breakWeapon(7, rules: moved).draws, Self.expected(branch: branch, toss: nil, count: 15), "\(branch)")
            XCTAssertEqual(try breakWeapon(branch, rules: moved).draws.contains { $0 == Self.expected(branch: branch, toss: nil, count: 1).last },
                           false, "\(branch) no longer takes its branch")
        }
        // The family takes part in the rules' equality.
        XCTAssertNotEqual(n, rules(fragments: [100: 5])); XCTAssertEqual(n, n.with(profile: n.profile, weaponBreak: w))
    }
}
