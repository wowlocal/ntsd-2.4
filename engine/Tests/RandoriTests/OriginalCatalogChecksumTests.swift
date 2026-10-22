import XCTest
@testable import RandoriCore

/// APPLICATION_CATALOG_CHECKSUM.md: the catalog checksum 44f620 over the app's
/// own catalog package, through the owned file session the app uses. With
/// VC80's fscanf("%c") lookahead the value is the one the original computes
/// (0x1ec3356: its own recordings, and 44f620 read from the running original
/// under CrossOver). Without it, the earlier corpora's declared value remains.
/// ENGINE_SPLIT E4c-2: the synthetic half of native's OriginalCatalogChecksumTests; the content-reading tests stay there.
final class OriginalCatalogChecksumTests: XCTestCase {
    /// The decoder and the owned file session drop exactly the final source
    /// character with the lookahead, and nothing without it.
    func testScanfLookaheadDropsOnlyTheFinalCharacter() throws {
        let key = Array("SiuHungIsAGoodBearBecauseHeIsVeryGood".utf8), text = Array("<frame_end>\nZ".utf8)
        let source = [UInt8](repeating: 0x41, count: 123) + text.enumerated().map { $0.element &+ key[($0.offset + 123) % key.count] }
        XCTAssertEqual(try OriginalDATDecoder.decode(source, fileName: "a.dat", translation: .raw), "<frame_end>\nZ")
        XCTAssertEqual(try OriginalDATDecoder.decode(source, fileName: "a.dat", translation: .raw, scanfLookahead: true), "<frame_end>\n")
        for lookahead in [false, true] {
            var files = OriginalLoadingFiles(translation: .raw, scanfLookahead: lookahead), next: UInt32 = 0x100
            try files.decodeDAT("a.dat", source: { _ in source }, allocate: { _, _ in
                next += 0x10; return .init(token: next, buffer: next << 12, descriptor: 3, capacity: 0x1000, readLimit: 0x1000)
            })
            XCTAssertEqual(files.files[OriginalLoadingFiles.temporaryPath], Array((lookahead ? "<frame_end>\n" : "<frame_end>\nZ").utf8))
        }
    }
}
