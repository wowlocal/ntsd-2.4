import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalCatalogPrecisionTests: XCTestCase {
    private struct Historical: Decodable {
        let corpus: String, corpusSHA256: String, fixture: String, sha256: String
    }
    private struct Precision: Decodable {
        let gameControlWord: UInt16, scannerControlWord: UInt16, scannerSharesGameCPU: Bool
        let formats: [String: Int], numericCases: Int, historical: Historical
        let changedHistoricalFields: [String], fullCorpus: String, fullSHA256: String, fullBytes: Int
    }
    private struct Metadata: Decodable { let precision: Precision }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Scan: Decodable, Equatable {
        let result: Int, position: Int, eof: Bool, errno: Int, outputs: [String]
    }
    private struct Case: Decodable {
        let index: Int, kind: String, path: String, source: String, offset: Int
        let caller: UInt32, destination: UInt32, result: Scan, unwritten: Scan, precision64: Scan
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, dllSHA256: String, precision: Precision, cases: [Case], blobs: [String: Blob]
    }
    private func data(_ name: String) throws -> Data {
        let url: URL
        if let directory = ProcessInfo.processInfo.environment["NTSD_CATALOG_PRECISION_DIRECTORY"] {
            url = URL(fileURLWithPath: directory).appendingPathComponent(name + ".json")
        } else {
            url = try XCTUnwrap(Bundle.module.url(forResource: "original-" + name, withExtension: "json", subdirectory: "Fixtures"))
        }
        return try MatchPreparationReference.unpack(Data(contentsOf: url))
    }
    private func check(_ precision: Precision) {
        XCTAssertEqual(precision.gameControlWord, 0x27f)
        XCTAssertEqual(precision.scannerControlWord, 0x27f)
        XCTAssertFalse(precision.scannerSharesGameCPU)
        XCTAssertEqual(precision.numericCases, 863)
        XCTAssertEqual(precision.formats, ["%s": 510027, "%d": 408268, "%lf": 863, "%d %d": 523,
                                          "%d %s %d %s %s": 137, "%d %s": 60, "%d %s %s": 17, "%s %s %d %d": 17])
        XCTAssertEqual(precision.formats.values.reduce(0, +), 919912)
        XCTAssertEqual(precision.changedHistoricalFields, [])
        XCTAssertEqual(precision.historical.corpus, "loaded-catalog.json")
        XCTAssertEqual(precision.historical.fixture, "original-loaded-catalog.json")
        XCTAssertEqual(precision.historical.corpusSHA256, "8ff43ea70036d84dbbea5309387176595658b0246aa3ff5773e8e22d08f12dee")
        XCTAssertEqual(precision.historical.sha256, "5fcd6e364a7761fcad4dc5af9792acf18e20b7bd9ff6ea89a66955c48a2af05e")
        XCTAssertEqual(precision.fullCorpus, "loaded-catalog53-full.json")
        XCTAssertEqual(precision.fullSHA256, precision.historical.corpusSHA256)
        XCTAssertEqual(precision.fullBytes, 95289959)
    }

    func testCompleteOriginalCatalogAtExplicit53Bits() throws {
        let raw = try data("loaded-catalog53")
        check(try JSONDecoder().decode(Metadata.self, from: raw).precision)
        let result = try LoadedCatalogReference.compare(raw)
        XCTAssertEqual(result.objects, 137)
        XCTAssertEqual(result.backgrounds, 17)
        XCTAssertEqual(result.stages, 25)
        XCTAssertEqual(result.phases, 138)
        XCTAssertEqual(result.frames, 15388)
        XCTAssertEqual(result.bitmaps, 829)
        XCTAssertEqual(result.allocations, 14586)
        XCTAssertEqual(result.bytes, 112063739)
        XCTAssertEqual(result.checksum, 31475378)
        print("CATALOG53", result.objects, "objects", result.bytes, "bytes and masks compared")
    }

    func testEveryActualDATDoubleScanAtExplicit53Bits() throws {
        let corpus = try JSONDecoder().decode(Corpus.self, from: data("dat-numeric53"))
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.dllSHA256, "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        check(corpus.precision)
        XCTAssertEqual(corpus.cases.count, 863)
        XCTAssertEqual(corpus.blobs.count, 43)
        XCTAssertEqual(Set(corpus.cases.map(\.source)), Set(corpus.blobs.keys))
        XCTAssertEqual(Set(corpus.cases.map(\.caller)).count, 17)
        XCTAssertEqual(corpus.cases.filter { $0.kind == "object" }.count, 672)
        XCTAssertEqual(corpus.cases.filter { $0.kind == "stages" }.count, 191)
        var sources: [String: [UInt8]] = [:]
        for (key, blob) in corpus.blobs {
            let bytes = try MatchPreparationReference.inflate(blob.deflate, count: blob.count)
            XCTAssertEqual(MatchPreparationReference.digest(Data(bytes)), key)
            sources[key] = bytes
        }
        for (index, item) in corpus.cases.enumerated() {
            XCTAssertEqual(item.index, index)
            let source = try XCTUnwrap(sources[item.source])
            let label = "\(item.path) @\(item.offset), caller \(String(item.caller, radix: 16))"
            guard source.indices.contains(item.offset) else { XCTFail(label + " outside source"); return }
            // Keep the complete decoded suffix, including following fields and
            // EOF. A pre-extracted numeric token would hide consumption errors.
            let text = String(String.UnicodeScalarView(source[item.offset...].map { UnicodeScalar($0) }))
            var scanner = try OriginalFrameScanner(text)
            let value = try scanner.binary64()
            var outputs = Array(repeating: "", count: 8)
            if let value {
                outputs[0] = (0..<8).map { String(format: "%02x", (value.bitPattern >> (8*$0)) & 255) }.joined()
            }
            XCTAssertEqual(outputs, item.result.outputs, label)
            XCTAssertEqual(scanner.position, item.result.position, label)
            XCTAssertEqual(scanner.eof, item.result.eof, label)
            XCTAssertEqual(value == nil ? (scanner.eof ? -1 : 0) : 1, item.result.result, label)
            // Every original call in this catalog succeeds without errno/EOF;
            // this does not claim general decimal failure/overflow behavior.
            XCTAssertEqual(item.result.result, 1, label)
            XCTAssertEqual(item.result.errno, 0, label)
            XCTAssertFalse(item.result.eof, label)
            XCTAssertEqual(item.result, item.unwritten, label)
            XCTAssertEqual(item.result, item.precision64, label)
        }
        print("DAT NUMERIC53", corpus.cases.count, "original double scans compared including full suffix consumption")
    }
}
