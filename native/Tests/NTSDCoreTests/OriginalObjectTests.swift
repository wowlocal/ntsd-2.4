import Foundation
import XCTest
import NTSDReferenceChecks
@testable import NTSDCore

final class OriginalObjectTests: XCTestCase {
    func testCompleteObjectStreamsAgainstOriginalInstructions() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-objects", withExtension: "json", subdirectory: "Fixtures"))
        let result = try ObjectReference.compareSuite(Data(contentsOf: url))
        XCTAssertEqual(result.objects, 6)
        XCTAssertEqual(result.occurrences, 1233)
        XCTAssertEqual(result.finalFrames, 2400)
        XCTAssertEqual(result.bitmaps, 37)
        XCTAssertEqual(result.bytes, 308688)
    }

    func testFailedObjectDoesNotCommitSharedLoadingState() throws {
        var loader = OriginalObjectLoader()
        let beforeSounds = loader.soundBytes
        // A failure after bitmap construction and a successful frame/sound load
        // must not leak the candidate's cache, checksum or wrapper allocations.
        let source = """
        <bmp_begin>
        file(anything): sheet.bmp w: 7 h: 7 row: 1 col: 1
        <bmp_end>
        <frame> 0 sound sound: data\\001.wav <frame_end>
        <frame> 400 unsupported <frame_end>
        """
        XCTAssertThrowsError(try loader.load(decoded: source, id: 7, type: 3,
                                            headerBacking: Array(repeating: 0xa5, count: 0x7a4), tailBacking: Array(repeating: 0xa5, count: 0x3c),
                                            bitmapSource: { .init(path: $0, present: true, width: 8, height: 8) }))
        XCTAssertTrue(loader.bitmaps.isEmpty)
        XCTAssertEqual(loader.soundCount, 0)
        XCTAssertEqual(loader.soundBytes, beforeSounds)
        XCTAssertEqual(loader.checksum, 0)
    }
}
