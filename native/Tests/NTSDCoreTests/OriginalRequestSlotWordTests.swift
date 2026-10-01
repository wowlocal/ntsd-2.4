import Foundation
import XCTest
@testable import NTSDCore

/// APPLICATION_REQUESTED_ITEMS_SLOT_PLAN.md: the body's frame word SP+34 through
/// the lifecycle loop's writers, and what the requested-items pass does with it
/// on a full pool. Small synthetic pools; every value follows the static reading.
final class OriginalRequestSlotWordTests: XCTestCase {
    private func zero(_ count: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0, count: count), defined: [Bool](repeating: true, count: count))
    }
    private struct Pool {
        var world: OriginalStateRecord, actors: [OriginalStateRecord], globals: OriginalStateRecord
        var header: OriginalStateRecord, frames: [OriginalStateRecord]
        mutating func fill() throws { for slot in 50..<400 { try world.write(UInt8(1), at: 4+slot) } }
        mutating func put(_ slot: Int, _ offset: Int, _ value: Int32) throws {
            try actors[Int(try world.integer(at: 0x194+4*slot, as: UInt32.self))].write(value, at: offset)
        }
        /// The whole post-scheduler continuation of one slot (41fb0b..4214c6).
        mutating func slot(_ slot: Int, _ scratch: inout OriginalPostDrawScratch) throws {
            let header = self.header, frames = self.frames
            try OriginalPostDrawLifecycle.apply(world: &world, actors: &actors, globals: &globals, scratch: &scratch,
                wholeLoop: false, slot: slot, precision: .bits53, sse2: false, objectCount: 1,
                header: { _ in header }, frame: { _, number in try Pool.frame(frames, number) })
        }
        static func frame(_ frames: [OriginalStateRecord], _ number: Int32) throws -> OriginalStateRecord {
            guard frames.indices.contains(Int(number)) else { throw OriginalStateError.invalidStorage("Test frame \(number)") }
            return frames[Int(number)]
        }
    }
    /// Slots 0 and 1 live, one Object (ID `id`), frame 0 state 3 and frame 1 state 13.
    private func pool(id: Int32) throws -> Pool {
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5, count: 0x7d8),
            actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5, count: 0x420), count: 400), selector: 2)
        var world = bootstrap.world, globals = try zero(0xb440), header = try zero(0x7a4)
        var first = try zero(0x178), second = try zero(0x178)
        for slot in 0..<400 { try world.write(UInt8(slot < 2 ? 1 : 0), at: 4+slot) }
        try header.write(id, at: 0x6f4); try header.write(Int32(20), at: 0x90); try header.write(Int32(-1), at: 0xac)
        try first.write(Int32(3), at: 8); try first.write(Int32(-1), at: 0x174)
        try second.write(Int32(13), at: 8); try second.write(Int32(-1), at: 0x174)
        for i in 0..<3000 { try globals.write(UInt8(1), at: 0x44ff90-0x44d000+i) }
        var p = Pool(world: world, actors: bootstrap.actors, globals: globals, header: header, frames: [first, second])
        for slot in 0..<2 {
            for offset in [0x70, 0x78, 0x88, 0xb4] { try p.put(slot, offset, 0) }
            try p.put(slot, 0x2fc, 100)
        }
        return p
    }

    func testInitialWordIsMinusFourMinusWorld() {
        XCTAssertEqual(OriginalRequestSlotWord.initial(), .value(Int32(bitPattern: 0xffba74fc)))
        // The commands oracle's controlled World observes 0xddffffdc at 4214d5.
        XCTAssertEqual(OriginalRequestSlotWord.initial(world: 0x22000020), .value(Int32(bitPattern: 0xddffffdc)))
    }

    /// 420f89: each death particle stores its Actor; a full pool leaves the word.
    func testDeathParticlesLeaveTheLastActor() throws {
        var p = try pool(id: 999); try p.put(1, 0x78, 1)
        var scratch = OriginalPostDrawScratch(requestSlot: .initial())
        try p.slot(1, &scratch)
        XCTAssertEqual(scratch.requestSlot, .actor(64))
        p = try pool(id: 999); try p.put(1, 0x78, 1); try p.fill()
        scratch = OriginalPostDrawScratch(requestSlot: .initial())
        try p.slot(1, &scratch)
        XCTAssertEqual(scratch.requestSlot, .initial())
    }

    /// 4211f6/421212: each fire particle steps the catalog cursor to the match,
    /// or to the count when no Object 999 exists (the retained Object is used).
    func testFireParticlesLeaveTheCatalogCursor() throws {
        var p = try pool(id: 999); try p.frames[1].write(Int32(18), at: 8)
        try p.put(0, 0x78, 1)
        var scratch = OriginalPostDrawScratch(requestSlot: .initial())
        try p.slot(0, &scratch)
        XCTAssertEqual(scratch.requestSlot, .catalogCursor(0))
        try p.header.write(Int32(2), at: 0x6f4); try p.put(0, 0x78, 1)
        scratch = OriginalPostDrawScratch(fireObject: 0, requestSlot: .initial())
        try p.slot(0, &scratch)
        XCTAssertEqual(scratch.requestSlot, .catalogCursor(1))
    }

    /// 420c7b..420e89: a command child ends with the slot counter at 400; a full
    /// pool still steps the cursor.
    func testCommandLeavesFourHundredOrTheCursor() throws {
        for full in [false, true] {
            var p = try pool(id: 998)
            if full { try p.fill() }
            try p.put(0, 0x2fc, 100)
            for (offset, value) in [(0x40c, 9), (0x410, 0), (0x414, 9), (0x418, 0)] { try p.put(0, offset, Int32(value)) }
            var scratch = OriginalPostDrawScratch(requestSlot: .initial())
            try p.slot(0, &scratch)
            XCTAssertEqual(scratch.requestSlot, full ? .catalogCursor(0) : .value(400))
        }
    }

    /// 420537: a weapon child stores its Actor.
    func testWeaponLeavesTheLastActor() throws {
        var p = try pool(id: 100); try p.header.write(Int32(1), at: 0x6f8)
        try p.put(1, 0x31c, -1)
        var scratch = OriginalPostDrawScratch(weaponObject: 0, requestSlot: .initial())
        try p.slot(1, &scratch)
        XCTAssertEqual(scratch.requestSlot, .actor(54))
    }

    /// 4213b6..421497: the frame 11xx/12xx exit counts the word down to 0.
    func testEarlyExitCountsDownToZero() throws {
        var p = try pool(id: 999); try p.put(1, 0x70, 1100)
        var scratch = OriginalPostDrawScratch(requestSlot: .initial())
        try p.slot(1, &scratch)
        XCTAssertEqual(scratch.requestSlot, .value(0))
    }

    /// 41fd2f..41fedc: an opoint child leaves 0, or its y when the parent faces
    /// left; a full pool leaves the catalog cursor.
    func testOpointLeavesZeroTheChildYOrTheCursor() throws {
        for (facing, full) in [(UInt8(0), false), (1, false), (0, true)] {
            var p = try pool(id: 999)
            for (offset, value) in [(0x58, 1), (0x70, 999), (0x74, 1), (0x54, 7), (0x60, 30), (0x5c, 4)] {
                try p.frames[0].write(Int32(value), at: offset)
            }
            if full { try p.fill() }
            try p.put(1, 0x14, 100)
            try p.actors[Int(try p.world.integer(at: 0x194+4, as: UInt32.self))].write(facing, at: 0x80)
            var scratch = OriginalPostDrawScratch(requestSlot: .initial())
            try p.slot(1, &scratch)
            XCTAssertEqual(scratch.requestSlot, full ? .catalogCursor(0) : .value(facing == 0 ? 0 : 100-7+30), "facing \(facing) full \(full)")
        }
    }

    /// 41f8e9/41f914/41f933: the five 0x270c particles leave the last raw draw.
    func testPrefixParticlesLeaveTheirLastDraw() throws {
        var p = try pool(id: 217)
        try p.frames[1].write(Int32(9996), at: 8)
        try p.put(1, 0x70, 1); try p.put(1, 0x88, 1)
        var retained: Int32?, library: OriginalLibTransformBacking?, word: OriginalRequestSlotWord? = .initial()
        var draws: [Int32: Int32] = [:]
        let header = p.header, frames = p.frames
        try OriginalPostDrawSlotPrefix.apply(world: &p.world, actors: &p.actors, globals: &p.globals, slot: 1,
            retainedObjectIndex: &retained, requestSlot: &word, objectCount: 1, library: &library,
            header: { _ in header }, frame: { _, number in try Pool.frame(frames, number) }, observe: { event in
                if case let .random(_, stream, _, result) = event { draws[stream] = result }
            })
        XCTAssertEqual(word, .value(try XCTUnwrap(draws[162])))
    }

    /// 421651 on a full pool: a slot rebuilds; −4 − World is the original's
    /// access violation; 400, a cursor or an Actor address are declared stops.
    func testFullPoolOutcomes() throws {
        var p = try pool(id: 100); try p.fill()
        try p.globals.write(Int32(1), at: 0x450bb8-0x44d000)
        var bg = try zero(12)
        for (i, value) in [Int32(800), 200, 700].enumerated() { try bg.write(value, at: 4*i) }
        let header = p.header, frames = p.frames, background = bg
        func run(_ start: OriginalRequestSlotWord?) throws -> (OriginalRequestSlotWord?, [OriginalPostDrawCommandEvent], Pool) {
            var q = p, word = start, events: [OriginalPostDrawCommandEvent] = []
            try OriginalPostDrawCommands.apply(world: &q.world, actors: &q.actors, globals: &q.globals, requestSlot: &word,
                sse2: false, objectCount: 1, header: { _ in header }, frame: { _, number in try Pool.frame(frames, number) },
                background: { _ in background }, observe: { events.append($0) })
            return (word, events, q)
        }
        let (word, events, rebuilt) = try run(.value(0))
        XCTAssertEqual(word, .value(0)); XCTAssertTrue(events.contains(.reconstruct(slot: 0)))
        XCTAssertNotEqual(rebuilt.actors, p.actors)
        func message(_ start: OriginalRequestSlotWord?) -> String {
            do { _ = try run(start); return "" } catch OriginalStateError.invalidStorage(let text) { return text } catch { return "\(error)" }
        }
        XCTAssertTrue(message(.initial()).hasPrefix("Source fault:"))
        XCTAssertTrue(message(.initial()).contains("0xff2f6084"))
        XCTAssertTrue(message(.value(400)).contains("World+0x7d4, the catalog pointer"))
        XCTAssertTrue(message(.value(400)).hasSuffix("(declared stop)"))
        XCTAssertTrue(message(.catalogCursor(3)).contains("catalog table cursor at index 3"))
        XCTAssertTrue(message(.actor(77)).contains("Actor address of slot 77"))
        XCTAssertEqual(message(nil), "Post-draw commands: Retained caller slot provenance")
        // A free slot replaces any incoming word.
        var open = p; try open.world.write(UInt8(0), at: 4+120); let saved = p; p = open
        XCTAssertEqual(try run(.initial()).0, .value(120)); p = saved
    }
}
