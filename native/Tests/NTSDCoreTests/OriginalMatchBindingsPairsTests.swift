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
}
