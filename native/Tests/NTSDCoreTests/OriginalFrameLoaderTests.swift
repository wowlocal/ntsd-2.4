import Foundation
import XCTest
@testable import NTSDCore

final class OriginalFrameLoaderTests: XCTestCase {
    private struct Corpus: Decodable { let exeSHA256: String; let cases: [Case] }
    private struct Case: Decodable {
        let label: String
        let definitions: [String]
        let snapshots: [OriginalFrameRecord]
    }

    func testOriginalX86SnapshotsAfterEveryOccurrence() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-frames", withExtension: "json", subdirectory: "Fixtures"))
        let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertFalse(corpus.cases.isEmpty)
        for item in corpus.cases {
            XCTAssertEqual(item.definitions.count, item.snapshots.count, item.label)
            var loader = OriginalFrameLoader()
            for (index, source) in item.definitions.enumerated() {
                XCTAssertEqual(try loader.apply(source), item.snapshots[index], "\(item.label), occurrence \(index)")
            }
        }
    }

    func testUnsupportedInputDoesNotCommitPartialState() throws {
        var loader = OriginalFrameLoader()
        let prior = try loader.apply("<frame> 1 prior\npic: 7 sound: data\\001.wav\n<frame_end>")
        let inputs = [
            "<frame> 1 change\npic: 8 sound: data\\002.wav\n<frame_end> trailing-input",
            "<frame> 400 outside\n<frame_end>",
            "<frame> 1 name_longer_than_the_original_buffer\n<frame_end>",
            "<frame> 1 excess\n" + String(repeating: "bdy: x: 2 bdy_end: ", count: 6) + "<frame_end>",
            "<frame> 1 incomplete\nitr: kind: 1 <frame_end>"
        ]
        for source in inputs {
            XCTAssertThrowsError(try loader.apply(source))
            XCTAssertEqual(loader.frames, [1: prior])
        }
        let next = try loader.apply("<frame> 2 next\nsound: data\\003.wav\n<frame_end>")
        XCTAssertEqual(next[0x174], 1, "An unsupported frame must not add a sound to the registry")
    }
}
