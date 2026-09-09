import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalLibMatchPreparationTests: XCTestCase {
    func testWholePreparationFeedsItsOwnLibraryCommandConsumer() throws {
        func fixture(_ name: String) throws -> Data {
            try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")))
        }
        let corpora = try ["lib-match-preparation", "lib-match-preparation-ramp"].map { name in
            if let directory = ProcessInfo.processInfo.environment["NTSD_LIB_MATCH_PREPARATION_DIRECTORY"] {
                return try Data(contentsOf: URL(fileURLWithPath: directory).appendingPathComponent(name+".json"))
            }
            return try fixture("original-"+name)
        }
        struct Assets: Decodable { let assets: [OriginalBitmapInput] }
        let assets = try corpora.map { data in
            Dictionary(uniqueKeysWithValues: try JSONDecoder().decode(Assets.self, from: MatchPreparationReference.unpack(data)).assets.map { ($0.path, $0) })
        }
        var rollbackTrials = 0
        let result = try MatchPreparationReference.compare(loaded: fixture("original-loaded-catalog"), corpora: corpora,
            beforePreparation: { corpusIndex, caseIndex, state in
                guard caseIndex == 0 || caseIndex == 21 else { return }
                var trial = state, library = OriginalLibStageCommands(requestedObjectID: 122)
                let beforeLibrary = library
                var resetObserved = false
                XCTAssertThrowsError(try trial.prepareUsingBundledLibrary(mode: 0, library: &library, bitmapSource: { path in
                    try XCTUnwrap(assets[corpusIndex][path])
                }, observe: { event in
                    if case .resetInput = event {
                        resetObserved = true
                        throw OriginalStateError.invalidStorage("Late preparation observer")
                    }
                })) { error in
                    if caseIndex == 21 {
                        guard case OriginalStateError.undefinedBytes(offset: 0xc, count: 4) = error else { return XCTFail("Unexpected backing rejection: \(error)") }
                    }
                }
                XCTAssertEqual(resetObserved, caseIndex == 0)
                XCTAssertEqual(trial.world, state.world); XCTAssertEqual(trial.actors, state.actors)
                XCTAssertEqual(trial.globals, state.globals); XCTAssertEqual(trial.backgrounds, state.backgrounds)
                XCTAssertEqual(trial.bitmaps, state.bitmaps); XCTAssertEqual(trial.releasedBitmaps, state.releasedBitmaps)
                XCTAssertEqual(trial.releasedBitmapOrder, state.releasedBitmapOrder); XCTAssertEqual(trial.frameAllocations, state.frameAllocations)
                XCTAssertEqual(library, beforeLibrary)
                rollbackTrials += 1
            })
        XCTAssertEqual(rollbackTrials, 4)
        XCTAssertEqual(result.cases, 70)
        XCTAssertEqual(result.records, 107732); XCTAssertEqual(result.bytes, 160959136)
        XCTAssertEqual(result.constructors, 26942); XCTAssertEqual(result.randomCalls, 756)
        XCTAssertEqual(result.bitmaps, 1096); XCTAssertEqual(result.releases, 1066)
        XCTAssertEqual(result.commandEvents, 40); XCTAssertEqual(result.commandConstructors, 8)
        print("LIB MATCH PREPARATION", result.cases, "cases", result.records, "records", result.bytes, "bytes", result.constructors, "constructors", result.randomCalls, "RNG", result.bitmaps, "bitmaps", result.releases, "releases", result.commandEvents, "command events", result.commandConstructors, "command constructors")
    }
}
