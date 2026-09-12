import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Saved normalized source pools and declared allocation bindings. The original
/// DLL is never executed here; source faults are separate rejection trials.
final class OriginalLibTransformTests: XCTestCase {
    private struct Patch: Decodable {
        let offset: Int, bytes: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            offset = try c.decode(Int.self); bytes = try c.decode(String.self)
        }
    }
    private struct Actor: Decodable {
        let index: Int, patches: [Patch]
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            index = try c.decode(Int.self); patches = try c.decode([Patch].self)
        }
    }
    private struct Header: Decodable {
        let object: Int, offset: Int, bytes: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            object = try c.decode(Int.self); offset = try c.decode(Int.self); bytes = try c.decode(String.self)
        }
    }
    private struct Frame: Decodable {
        let object: Int, index: Int, offset: Int, bytes: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            object = try c.decode(Int.self); index = try c.decode(Int.self)
            offset = try c.decode(Int.self); bytes = try c.decode(String.self)
        }
    }
    private struct Input: Decodable {
        let label: String, slot: Int
        let fill: String?, retainedBefore: UInt32?, count: Int32?
        let actors: [Actor]?, active: [[Int]]?, aliases: [[Int]]?
        let frames: [Frame]?, headers: [Header]?, globals: [Patch]?
    }
    private struct Event: Decodable, Equatable { let slot: Int, kind: String, arguments: [UInt32] }
    private struct Write: Decodable { let pc: UInt32, actor: Int, address: UInt32, before: String, value: UInt32 }
    private struct Case: Decodable {
        let input: Input
        let tailSHA256: String, poolSHA256: String, maskSHA256: String, globalsSHA256: String
        let events: [Event], endPC: UInt32, retainedAfter: UInt32, extendedWrites: [Write]
        enum CodingKeys: String, CodingKey {
            case tailSHA256, poolSHA256, maskSHA256, globalsSHA256, events, endPC, retainedAfter, extendedWrites
        }
        init(from decoder: Decoder) throws {
            input = try Input(from: decoder)
            let c = try decoder.container(keyedBy: CodingKeys.self)
            tailSHA256 = try c.decode(String.self, forKey: .tailSHA256)
            poolSHA256 = try c.decode(String.self, forKey: .poolSHA256)
            maskSHA256 = try c.decode(String.self, forKey: .maskSHA256)
            globalsSHA256 = try c.decode(String.self, forKey: .globalsSHA256)
            events = try c.decode([Event].self, forKey: .events)
            endPC = try c.decode(UInt32.self, forKey: .endPC)
            retainedAfter = try c.decode(UInt32.self, forKey: .retainedAfter)
            extendedWrites = try c.decode([Write].self, forKey: .extendedWrites)
        }
    }
    private struct Fault: Decodable {
        struct Access: Decodable { let pc: UInt32, address: UInt32, size: Int, value: UInt32 }
        let input: Input, error: String, errno: Int, event: Access
    }
    private struct Corpus: Decodable {
        let libSHA256: String, poolAddress: UInt32, actorStride: Int, actorSize: Int, tailCount: Int, tailInitial: String
        let exeSHA256: String, header: [Patch], headerPatches: [Header], states: [String: Int32], ids: [Int32]
        let cases: [Case], faults: [Fault]?, fpcw: UInt16, instructions: [UInt32]
    }
    private struct State: Equatable {
        var world: OriginalStateRecord, actors: [OriginalStateRecord], globals: OriginalStateRecord
        var retained: Int32?, backing: OriginalLibTransformBacking?
    }
    private struct Base {
        var headers: [OriginalStateRecord], frames: [[OriginalStateRecord]], globals: OriginalStateRecord
    }
    private enum Stop: Error { case late }

    private func zero(_ count: Int) throws -> OriginalStateRecord {
        try .init(bytes: Array(repeating: 0, count: count), defined: Array(repeating: true, count: count))
    }
    private func patch(_ record: inout OriginalStateRecord, _ offset: Int, _ hex: String) throws {
        let bytes = Array(hex.utf8)
        guard bytes.count % 2 == 0 else { throw OriginalStateError.invalidStorage("Odd patch hex") }
        for i in stride(from: 0, to: bytes.count, by: 2) {
            try record.write(XCTUnwrap(UInt8(String(decoding: bytes[i..<i+2], as: UTF8.self), radix: 16)), at: offset+i/2)
        }
    }
    private func corpus(_ name: String) throws -> Corpus {
        let url: URL
        if let directory = ProcessInfo.processInfo.environment["NTSD_LIB_TRANSFORM_DIRECTORY"] {
            url = URL(fileURLWithPath: directory).appendingPathComponent(name+".json")
        } else {
            url = try XCTUnwrap(Bundle.module.url(forResource: "original-"+name, withExtension: "json", subdirectory: "Fixtures"))
        }
        let raw = try MatchPreparationReference.unpack(Data(contentsOf: url))
        let pin = name == "lib-transforms"
            ? "afbba6e63fcc3b94ba8453e332ace5659d0b0c50e6311eca0308a1cc35f19dd6"
            : "cbfd623e3a64e0b6ac96ec7c71796e81b746bb6b316b984a7ea7282708d3427d"
        XCTAssertEqual(MatchPreparationReference.digest(raw), pin)
        let c = try JSONDecoder().decode(Corpus.self, from: raw)
        XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.libSHA256, "28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
        XCTAssertEqual(c.fpcw, 0x27f); XCTAssertEqual(c.ids, [2, 50, 217, 218])
        if name == "lib-transforms" {
            XCTAssertEqual(c.instructions.filter { (0x41f550...0x41fb06).contains($0) }.count, 326)
        }
        XCTAssertEqual(c.poolAddress, 0x70000020); XCTAssertEqual(c.actorStride, 0x500)
        XCTAssertEqual(c.actorSize, 0x420); XCTAssertEqual(c.tailCount, 0x1000); XCTAssertEqual(c.tailInitial, "a5")
        return c
    }
    private func base(_ c: Corpus) throws -> Base {
        var headers: [OriginalStateRecord] = [], frames: [[OriginalStateRecord]] = []
        for (i, id) in c.ids.enumerated() {
            var h = try zero(0x7a4)
            for p in c.header { try patch(&h, p.offset, p.bytes) }
            try h.write(id, at: 0x6f4); try h.write(Int32(i == 3 ? 3 : 0), at: 0x6f8)
            for p in c.headerPatches where p.object == i { try patch(&h, p.offset, p.bytes) }
            headers.append(h)
            frames.append(try (0..<400).map { n in
                var f = try zero(0x178); try f.write(UInt8(1), at: 0)
                try f.write(c.states[String(n)] ?? 3, at: 8)
                if [60, 65, 80, 85, 90].contains(n) { try f.write(Int32(100), at: 0x4c) }
                return f
            })
        }
        var globals = try zero(OriginalMatchPreparation.globalSize)
        try globals.write(Int32(1), at: 0x44d034-0x44d000)
        for i in 0..<3000 { try globals.write(UInt8(1+i%255), at: 0x44ff90-0x44d000+i) }
        return .init(headers: headers, frames: frames, globals: globals)
    }
    private func prepare(_ c: Corpus, _ item: Input, _ base: Base) throws -> (State, Base) {
        // Fault captures use probe ordinal0: declared a5 constructors and the
        // retained input word from the historical source setup.
        let fill = item.fill ?? "a5"
        let template = try OriginalStateRecord.actor(over: (0..<0x420).map { fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
        var actors = Array(repeating: template, count: 400)
        var world = try OriginalStateRecord.worldPrefix(over: (0..<0x7d8).map { fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
        let aliases = Dictionary(uniqueKeysWithValues: (item.aliases ?? []).map { ($0[0], $0[1]) })
        let active = Dictionary(uniqueKeysWithValues: (item.active ?? []).map { ($0[0], $0[1]) })
        for i in 0..<400 {
            try world.write(UInt32(aliases[i] ?? i), at: 0x194+i*4); try world.write(UInt8(active[i] ?? 0), at: 4+i)
            try actors[i].write(UInt32(0), at: 0x368)
        }
        try world.write(UInt32(0), at: 0x7d4)
        for a in item.actors ?? [] { for p in a.patches { try patch(&actors[a.index], p.offset, p.bytes) } }
        var own = base
        for p in item.headers ?? [] { try patch(&own.headers[p.object], p.offset, p.bytes) }
        for p in item.frames ?? [] { try patch(&own.frames[p.object][p.index], p.offset, p.bytes) }
        for p in item.globals ?? [] { try patch(&own.globals, p.offset-0x44d000, p.bytes) }
        // Bindings derive solely from declared allocation inputs, never output.
        let destinations = Dictionary(uniqueKeysWithValues: (0..<400).map { i in
            (i, i == 399 ? OriginalLibTransformBacking.Destination.external(index: 0, offset: 0x2b4) : .actor(index: i+1, offset: 0x2b4))
        })
        let tokens = Dictionary(uniqueKeysWithValues: (0..<400).map { ($0, c.poolAddress+UInt32($0*c.actorStride)) })
        let backing = OriginalLibTransformBacking(destinations: destinations, actorAddressTokens: tokens,
            externalRecords: [try .init(bytes: Array(repeating: 0xa5, count: c.tailCount), defined: Array(repeating: false, count: c.tailCount))])
        return (.init(world: world, actors: actors, globals: own.globals,
                      retained: Int32(bitPattern: item.retainedBefore ?? 0x12345678), backing: backing), own)
    }
    private func execute(_ state: inout State, input: Input, base: Base,
                         observe: (Event) throws -> Void = { _ in }) throws -> (UInt32, [Event]) {
        var events: [Event] = []
        let scheduled = try OriginalPostDrawSlotPrefix.apply(world: &state.world, actors: &state.actors, globals: &state.globals,
            slot: input.slot, retainedObjectIndex: &state.retained, objectCount: input.count ?? 4, library: &state.backing,
            header: { base.headers[$0] }, frame: { base.frames[$0][Int($1)] }, observe: { event in
                let value: Event
                switch event {
                case let .random(slot, stream, range, result):
                    value = .init(slot: slot, kind: "random", arguments: [stream, range, result].map(UInt32.init(bitPattern:)))
                case let .reconstruct(slot, created):
                    value = .init(slot: slot, kind: "reconstruct", arguments: [UInt32(created)])
                case let .catalogSound(slot, x, index):
                    value = .init(slot: slot, kind: "catalogSound", arguments: [x, index].map(UInt32.init(bitPattern:)))
                }
                try observe(value); events.append(value)
            })
        return (scheduled ? 0x41fb0b : 0x4214c6, events)
    }
    private func compare(_ state: State, result: (UInt32, [Event]), item: Case, corpus c: Corpus) throws {
        let label = item.input.label, records = [state.world]+state.actors
        XCTAssertEqual(result.0, item.endPC, label)
        XCTAssertEqual(result.1, item.events, label)
        XCTAssertEqual(state.retained.map(UInt32.init(bitPattern:)), item.retainedAfter, label)
        XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap(\.bytes))), item.poolSHA256, label)
        XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap { $0.defined.map { $0 ? UInt8(1) : 0 } })), item.maskSHA256, label)
        XCTAssertEqual(MatchPreparationReference.digest(Data(state.globals.bytes)), item.globalsSHA256, label)
        XCTAssertTrue(state.globals.defined.allSatisfy { $0 }, label)
        let tail = try XCTUnwrap(state.backing).externalRecords[0]
        XCTAssertEqual(MatchPreparationReference.digest(Data(tail.bytes)), item.tailSHA256, label)
        // Expected defined bits come from saved writes. Their values and output
        // bytes never initialize the Native state.
        var mask = Array(repeating: false, count: c.tailCount)
        let tailAddress = c.poolAddress+UInt32(400*c.actorStride)
        for write in item.extendedWrites {
            XCTAssertEqual(write.pc, 0x36001112, label)
            XCTAssertEqual(write.address, c.poolAddress+UInt32(write.actor*c.actorStride)+0x7b4, label)
            XCTAssertEqual(write.before.count, 8, label)
            if write.address >= tailAddress {
                let offset = Int(write.address-tailAddress)
                for i in offset..<offset+4 { mask[i] = true }
            }
        }
        XCTAssertEqual(tail.defined, mask, label)
    }
    private func compareCorpus(_ name: String, cases: Int, events: Int, writes: Int, instructions: Int) throws {
        let c = try corpus(name), b = try base(c)
        XCTAssertEqual(c.cases.count, cases); XCTAssertEqual(Set(c.instructions).count, instructions)
        var totalEvents = 0
        for item in c.cases {
            var (state, own) = try prepare(c, item.input, b)
            let result = try execute(&state, input: item.input, base: own)
            try compare(state, result: result, item: item, corpus: c)
            totalEvents += result.1.count
        }
        XCTAssertEqual(totalEvents, events); XCTAssertEqual(c.cases.reduce(0) { $0+$1.extendedWrites.count }, writes)
        print("LIB TRANSFORMS", name, cases, "returned pools/masks and", totalEvents, "ordered events compared")
    }
    func testWholeSlotPrefixAgainstOriginalInstructions() throws {
        try compareCorpus("lib-transforms", cases: 1688, events: 2827, writes: 371, instructions: 744)
    }
    func testRetainedAliasesAndActivityBoundaries() throws {
        try compareCorpus("lib-transform-boundaries", cases: 72, events: 653, writes: 68, instructions: 568)
    }
    func testRecordedSourceFaultsAreRejectedWithWholeRollback() throws {
        let c = try corpus("lib-transform-boundaries"), b = try base(c), faults = try XCTUnwrap(c.faults)
        XCTAssertEqual(faults.count, 4)
        for fault in faults {
            XCTAssertEqual(fault.error, "Invalid memory write (UC_ERR_WRITE_UNMAPPED)")
            XCTAssertEqual(fault.errno, 7); XCTAssertEqual(fault.event.pc, 0x36001112)
            XCTAssertEqual(fault.event.address, c.poolAddress+UInt32(399*c.actorStride)+0x7b4)
            XCTAssertEqual(fault.event.size, 4)
            var (state, own) = try prepare(c, fault.input, b)
            let backing = try XCTUnwrap(state.backing)
            var destinations = backing.destinations
            destinations.removeValue(forKey: 399)
            state.backing = .init(destinations: destinations, actorAddressTokens: backing.actorAddressTokens)
            let before = state
            XCTAssertThrowsError(try execute(&state, input: fault.input, base: own)) { error in
                guard case OriginalStateError.invalidStorage(let reason) = error else { return XCTFail("Unexpected rejection: \(error)") }
                XCTAssertEqual(reason, "Library transform +7b4: Unavailable destination backing")
            }
            XCTAssertEqual(state, before, fault.input.label)
        }
        print("LIB TRANSFORMS four source faults rejected with rollback; these are not source/native matches")
    }
    func testMissingProvenanceInvalidExtentAndLateObserverRollback() throws {
        let c = try corpus("lib-transform-boundaries"), b = try base(c)
        let item = try XCTUnwrap(c.cases.first { row in
            row.extendedWrites.contains { $0.actor == 399 && $0.value == c.poolAddress+UInt32(399*c.actorStride) }
                && !row.events.isEmpty
        })
        for trial in 0..<5 {
            var (state, own) = try prepare(c, item.input, b)
            let backing = try XCTUnwrap(state.backing)
            var destinations = backing.destinations, tokens = backing.actorAddressTokens
            if trial == 0 { destinations.removeValue(forKey: 399) }
            if trial == 1 { tokens.removeValue(forKey: 399) }
            if trial == 2 { destinations[399] = .external(index: 1, offset: 0) }
            if trial == 3 { destinations[399] = .external(index: 0, offset: c.tailCount-2) }
            state.backing = .init(destinations: destinations, actorAddressTokens: tokens, externalRecords: backing.externalRecords)
            let before = state
            var observed = 0
            XCTAssertThrowsError(try execute(&state, input: item.input, base: own, observe: { _ in
                observed += 1
                if trial == 4 && observed == item.events.count { throw Stop.late }
            })) { error in
                if trial == 4 { guard case Stop.late = error else { return XCTFail("Unexpected late error: \(error)") } }
                else { XCTAssertTrue(error is OriginalStateError) }
            }
            if trial == 4 { XCTAssertEqual(observed, item.events.count) }
            XCTAssertEqual(state, before, "provenance/late trial \(trial)")
        }
        // Miss/count<=0 needs no invented Actor pointer token.
        let main = try corpus("lib-transforms"), mainBase = try base(main)
        for count: Int32 in [4, 0, -1] {
            let item = try XCTUnwrap(main.cases.first { ($0.input.count ?? 4) == count
                && $0.extendedWrites.contains { $0.value == UInt32(bitPattern: max(count, 0)) } })
            var (state, own) = try prepare(main, item.input, mainBase)
            let backing = try XCTUnwrap(state.backing)
            state.backing = .init(destinations: backing.destinations, externalRecords: backing.externalRecords)
            let result = try execute(&state, input: item.input, base: own)
            try compare(state, result: result, item: item, corpus: main)
        }
    }
}
