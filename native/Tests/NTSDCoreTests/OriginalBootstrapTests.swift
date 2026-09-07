import Foundation
import XCTest
import NTSDReferenceChecks
@testable import NTSDCore

final class OriginalBootstrapTests: XCTestCase {
    func testCompleteAllocatedAndStagedPoolsAgainstOriginalInstructions() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-bootstrap", withExtension: "json", subdirectory: "Fixtures"))
        let result = try BootstrapReference.compare(Data(contentsOf: url))
        XCTAssertEqual(result.cases, 8)
        XCTAssertEqual(result.checkpoints, 16)
        XCTAssertEqual(result.records, 6416)
        XCTAssertEqual(result.bytes, 6790528)
    }

    func testReconstructionPreservesPreviouslyInitializedOpaqueFields() throws {
        var record = try OriginalStateRecord.actor(over: Array(repeating: 0, count: OriginalStateRecord.actorSize))
        try record.write(Int32(-1234567), at: 0x31c)
        try record.write(UInt32(0x81234567), at: 0x368)
        try record.write(UInt32(0x89abcdef), at: 0x370)
        try record.write(Int32(80), at: 0x308)
        try record.reconstructActor()
        XCTAssertEqual(try record.integer(at: 0x31c, as: Int32.self), -1234567)
        XCTAssertEqual(try record.integer(at: 0x368, as: UInt32.self), 0x81234567)
        XCTAssertEqual(try record.integer(at: 0x370, as: UInt32.self), 0x89abcdef)
        XCTAssertEqual(try record.integer(at: 0x308, as: Int32.self), 500)
        XCTAssertThrowsError(try record.integer(at: 0x374, as: UInt32.self))
        XCTAssertThrowsError(try record.integer(at: 0x41c, as: UInt32.self))
        var world = try OriginalStateRecord.worldPrefix(over: Array(repeating: 0, count: OriginalStateRecord.worldPrefixSize))
        let before = world
        XCTAssertThrowsError(try world.reconstructActor())
        XCTAssertEqual(world, before)
    }
}
