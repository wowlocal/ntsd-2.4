import Foundation
import XCTest
import NTSDReferenceChecks
@testable import NTSDCore

final class OriginalStageTests: XCTestCase {
    func testWholeStageTableAgainstOriginalInstructions() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-stages", withExtension: "json", subdirectory: "Fixtures"))
        let result = try StageReference.compareSuite(Data(contentsOf: url))
        XCTAssertEqual(result.loads, 6)
        XCTAssertEqual(result.initializations, 55)
        XCTAssertEqual(result.phases, 381)
        XCTAssertEqual(result.checkpoints, 436)
        XCTAssertEqual(result.records, 796)
        XCTAssertEqual(result.bytes, 1_074_924_768)
    }

    func testUnsupportedStageDoesNotCommitEarlierParsedStages() throws {
        var backing = try OriginalStateRecord(bytes: Array(repeating: 0xa5, count: OriginalStageLoader.stageSize),
                                              defined: Array(repeating: false, count: OriginalStageLoader.stageSize))
        try backing.write(Int32(7), at: 0)
        try backing.write(UInt32(0x87654321), at: 4) // previously initialized opaque bytes
        var loader = try OriginalStageLoader(backing: Array(repeating: backing, count: 60))
        let previous = loader.records
        var observed = false
        XCTAssertThrowsError(try loader.load(decoded: "<stage> id: 0 <phase> id: 3 hp: 10 <phase_end> <stage_end> <stage> id: 60 <stage_end>") { kind, _, _, _ in
            if kind == "phase" { observed = true }
        })
        XCTAssertTrue(observed)
        XCTAssertEqual(loader.records, previous)
        // A subsequent empty stage stream resets only phase-count sentinels.
        try loader.load(decoded: "<end>")
        XCTAssertEqual(try loader.records[0].integer(at: 0, as: Int32.self), -1)
        XCTAssertEqual(try loader.records[0].integer(at: 4, as: UInt32.self), 0x87654321)
        XCTAssertFalse(loader.records[0].defined[8])
    }
}
