import XCTest
@testable import NTSDCore

/// APPLICATION_CATALOG_CHECKSUM.md: the catalog checksum 44f620 over the app's
/// own catalog package, through the owned file session the app uses. With
/// VC80's fscanf("%c") lookahead the value is the one the original computes
/// (0x1ec3356: its own recordings, and 44f620 read from the running original
/// under CrossOver). Without it, the earlier corpora's declared value remains.
final class OriginalCatalogChecksumTests: XCTestCase {
    private func checksum(scanfLookahead: Bool) throws -> UInt32 {
        let inputs = try OriginalApplicationCatalogInputs.load(directory: OriginalApplicationCatalogInputs.bundledDirectory())
        func unknown(_ count: Int) throws -> OriginalStateRecord {
            try .init(bytes: [UInt8](repeating: 0xa5, count: count), defined: [Bool](repeating: false, count: count))
        }
        var parent = try OriginalCatalogRegistry.regionSizes.mapValues { try unknown($0) }
        let background = try unknown(OriginalBackgroundLoader.recordSize), stage = try unknown(OriginalStageLoader.stageSize)
        let backgrounds = [OriginalStateRecord](repeating: background, count: 101)
        parent[0x4d81060] = backgrounds[99]; parent[0x4d819f0] = backgrounds[100]
        var next: UInt32 = 0x100
        let result = try OriginalLoadedCatalog.loadWithFiles(files: .init(translation: .text, scanfLookahead: scanfLookahead),
            fileName: "data\\data.txt", parentBacking: parent, backgroundBacking: backgrounds,
            stageBacking: [OriginalStateRecord](repeating: stage, count: 60),
            fileSource: { path in
                guard let bytes = try inputs.file(path) else { throw OriginalStateError.invalidStorage("Missing catalog file \(path)") }
                return bytes
            },
            fileAllocation: { _, _ in
                next += 0x10
                return .init(token: next, buffer: next << 12, descriptor: 3, capacity: 0x1000, readLimit: 0x1000)
            },
            bitmapSource: { path in
                guard let bitmap = inputs.bitmaps[path] else { return .init(path: path, present: true, width: 1, height: 1) }
                return .init(path: path, present: true, width: Int32(bitmap.width), height: Int32(bitmap.height))
            })
        return result.catalog.checksum
    }

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

    func testCatalogChecksumMatchesTheOriginalWithTheScanfLookahead() throws {
        XCTAssertEqual(try checksum(scanfLookahead: true), 0x1ec3356)
    }

    func testDeclaredCorpusDecoderKeepsItsEarlierChecksum() throws {
        XCTAssertEqual(try checksum(scanfLookahead: false), 31475378)
    }
}
