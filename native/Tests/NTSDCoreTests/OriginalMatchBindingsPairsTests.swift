import XCTest
@testable import NTSDCore

final class OriginalMatchBindingsPairsTests: XCTestCase {
    func record(_ fill: UInt8) throws -> OriginalStateRecord {
        try OriginalStateRecord(bytes: [UInt8](repeating: fill, count: OriginalStateRecord.actorSize),
                                defined: [Bool](repeating: true, count: OriginalStateRecord.actorSize))
    }

    /// CORE_REALTIME 4j: the actor pairs' batched check says "unchanged" only
    /// for a record sharing both buffers with the pair's model side, so the
    /// store's lookup would return the stored side; anything else asks it.
    func testActorPairsUnchangedOnlyForSharedModelBuffers() throws {
        let pairs = OriginalApplicationMatchBindings.ActorPairs()
        let model = try record(3), stored = try record(4), other = try record(3)
        XCTAssertEqual(pairs.unchanged([model]), [false], "no pair yet")
        pairs.set(0,stored:stored,model:model)
        let copy = model
        var written = model
        try written.write(UInt8(1),at:7)
        XCTAssertEqual(pairs.unchanged([copy,model]), [true,false], "pair 1 is unset")
        XCTAssertEqual(pairs.unchanged([other]), [false], "equal contents in other buffers ask the lookup")
        XCTAssertNotNil(pairs.stored(0,for:other))
        XCTAssertEqual(pairs.unchanged([written]), [false]); XCTAssertNil(pairs.stored(0,for:written))
        XCTAssertEqual(pairs.unchanged([try OriginalStateRecord(bytes:[],defined:[])]), [false])
        // Every "unchanged" answer agrees with the lookup.
        var records = [model,copy,other,written]
        for i in 0..<4 { pairs.set(i,stored:stored,model:records[i]) }
        records.swapAt(0,2)
        for (i,flag) in pairs.unchanged(records).enumerated() where flag { XCTAssertNotNil(pairs.stored(i,for:records[i])) }
        XCTAssertEqual(pairs.unchanged(records), [false,true,false,true])
    }

    /// Tier 3 M1: the whole-table lookup gives the dictionary's answer for
    /// every token: below the lowest, between and off the step, above the
    /// highest, near both ends of UInt32; with evenly spaced addresses (the
    /// actors' case), aligned irregular ones, and sets that need the
    /// dictionary.
    func testTokenOrdinalsMatchTheDictionary() {
        var state: UInt64 = 0x51
        func next() -> UInt32 { state = state &* 6364136223846793005 &+ 1442695040888963407; return UInt32(truncatingIfNeeded: state >> 29) }
        var aligned: UInt32 = 0x2000_0000
        let irregular: [UInt32] = (0..<400).map { _ in aligned += 0x420 + 16 * (next() % 4); return aligned }
        let sets: [(tokens: [UInt32], table: Bool)] = [
            ((0..<400).map { 1000 + UInt32($0) }, true),
            ((0..<400).map { 0x1000_0000 + 0x420 * UInt32($0) }, true),
            ((0..<400).map { 0x1000_0000 + 0x500 * UInt32($0) }.reversed(), true),
            ((0..<400).map { UInt32.max - 0x500 * 399 + 0x500 * UInt32($0) }, true),
            ((0..<400).map { UInt32.max - 2 * UInt32($0) }, true),
            (irregular, true), ([1, 4097], true), ([7], true),
            ([0, 1, 70_000], false), ((0..<400).map { _ in next() }, false)]
        for (tokens, table) in sets {
            let truth = Dictionary(uniqueKeysWithValues: tokens.enumerated().map { ($0.element, UInt32($0.offset)) })
            XCTAssertEqual(truth.count, tokens.count, "unique tokens")
            let lookup = OriginalApplicationMatchBindings.TokenOrdinals(tokens)
            XCTAssertEqual(lookup.usesTable, table, "set starting \(tokens[0])")
            var probes: [UInt32] = [0, 1, UInt32.max, UInt32.max - 1, tokens.min()! &- 1, tokens.max()! &+ 1, tokens.min()! &- 0x420, tokens.max()! &+ 0x420]
            for token in tokens { probes += [token, token &- 1, token &+ 1, token &+ 8, token &+ 0x210, token &- 0x420] }
            for _ in 0..<2000 { probes.append(next()) }
            for token in probes { XCTAssertEqual(lookup(token), truth[token], "token \(token) of a set starting \(tokens[0])") }
        }
    }
}
