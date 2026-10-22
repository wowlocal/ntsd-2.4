import Foundation
import XCTest
@testable import RandoriCore

/// MEMORY_LOADING M1: bitmap bytes kept compressed must read back exactly.
/// ENGINE_SPLIT E4c-2: its synthetic tests moved to the engine's RandoriTests (same class name).
final class OriginalLZ4Tests: XCTestCase {
    /// The startup package now loads on all cores too (M1): the first failing
    /// entry in manifest order still decides the error.
    func testStartupPackageFailsAtItsFirstBadEntryInManifestOrder() throws {
        struct Entry: Decodable { let path: String, count: Int }
        struct Manifest: Decodable { let entries: [Entry] }
        let fm = FileManager.default, source = try OriginalApplicationStartupInputs.bundledDirectory()
        let entries = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: source.appendingPathComponent("manifest.json"))).entries
        let bitmaps = entries.filter { $0.path.hasPrefix("bitmaps/") }.sorted { $0.count > $1.count }
        let large = try XCTUnwrap(bitmaps.first), firstIndex = try XCTUnwrap(entries.firstIndex { $0.path == large.path })
        let later = try XCTUnwrap(entries[(firstIndex + 1)...].last)
        for truncateLater in [false, true] {
            let folder = fm.temporaryDirectory.appendingPathComponent("ntsd-startup-\(UUID().uuidString)")
            try fm.copyItem(at: source, to: folder); defer { try? fm.removeItem(at: folder) }
            var bytes = try Data(contentsOf: folder.appendingPathComponent(large.path)); bytes[bytes.count / 2] ^= 1
            try bytes.write(to: folder.appendingPathComponent(large.path))
            let tail = folder.appendingPathComponent(later.path), tailBytes = try Data(contentsOf: tail)
            try (truncateLater ? Data(tailBytes.dropLast()) : Data(tailBytes.map { $0 ^ 0xff })).write(to: tail)
            XCTAssertThrowsError(try OriginalApplicationStartupInputs.load(directory: folder)) { error in
                XCTAssertEqual(error as? OriginalApplicationStartupInputs.Boundary, .invalid(large.path))
            }
        }
    }

    func testPackagedBitmapsKeepTheirBytes() throws {
        let directory = try OriginalApplicationCatalogInputs.bundledDirectory()
        let inputs = try OriginalApplicationCatalogInputs.load(directory: directory)
        struct Entry: Decodable { let name: String, kind: String, path: String }
        struct Manifest: Decodable { let entries: [Entry] }
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
        var checked = 0, compressed = 0
        for entry in manifest.entries where entry.kind == "bitmapFile" || entry.kind == "dib" {
            let file = [UInt8](try Data(contentsOf: directory.appendingPathComponent(entry.path)))
            let bitmap = try XCTUnwrap(inputs.bitmaps[entry.name])
            XCTAssertEqual(bitmap.dib, entry.kind == "bitmapFile" ? Array(file.dropFirst(14)) : file, entry.name)
            XCTAssertEqual(bitmap, entry.kind == "bitmapFile" ? try .init(bitmapFile: file) : try .init(dib: file), entry.name)
            checked += 1; if OriginalBitmapBytes(bitmap.dib).isCompressed { compressed += 1 }
        }
        XCTAssertEqual(checked, 669); XCTAssertGreaterThan(compressed, 500)
    }
}
