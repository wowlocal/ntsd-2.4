import Foundation
import XCTest
@testable import NTSDCore

/// MEMORY_LOADING L3: package entries are read, verified and decoded
/// concurrently and taken in manifest order, so the first failing entry in that
/// order still decides the error, whichever entry fails first in time.
final class OriginalConcurrentInputsTests: XCTestCase {
    let fm = FileManager.default
    struct Entry: Decodable { let name: String, path: String }
    struct Manifest: Decodable { let entries: [Entry] }

    func copied(_ directory: URL) throws -> URL {
        let folder = fm.temporaryDirectory.appendingPathComponent("ntsd-concurrent-\(UUID().uuidString)")
        try fm.copyItem(at: directory, to: folder)
        return folder
    }
    func corrupt(_ url: URL) throws { var bytes = try Data(contentsOf: url); bytes[bytes.count / 2] ^= 1; try bytes.write(to: url) }
    func truncate(_ url: URL) throws { let bytes = try Data(contentsOf: url); try bytes.dropLast().write(to: url) }

    func testMapKeepsTheOrderAndEachEntrysError() {
        struct Odd: Error, Equatable { let value: Int }
        let results = OriginalConcurrentInputs.map(Array(0..<5000)) { value -> Int in
            if value % 7 == 3 { throw Odd(value: value) }
            return value * 2
        }
        XCTAssertEqual(results.count, 5000)
        for (value, result) in results.enumerated() {
            switch result {
            case .success(let doubled): XCTAssertEqual(doubled, value * 2)
            case .failure(let error): XCTAssertEqual(error as? Odd, Odd(value: value)); XCTAssertEqual(value % 7, 3)
            }
        }
    }

    func testHexMatchesTheFormattedDigits() {
        let all = (0...255).map { UInt8($0) }
        XCTAssertEqual(OriginalConcurrentInputs.hex(all), all.map { String(format: "%02x", $0) }.joined())
        XCTAssertEqual(OriginalConcurrentInputs.hex([]), "")
    }

    func testTheFirstFailingCatalogEntryInManifestOrderDecides() throws {
        let source = try OriginalApplicationCatalogInputs.bundledDirectory()
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: source.appendingPathComponent("manifest.json")))
        let early = manifest.entries[10], late = manifest.entries[1100]
        XCTAssertNotEqual(early.path, late.path)
        // A size mismatch fails in the read (the entry's path); a digest mismatch
        // after it (the entry's name).
        for (early: earlyDamage, late: lateDamage) in [(early: "truncate", late: "corrupt"), (early: "corrupt", late: "truncate")] {
            let folder = try copied(source); defer { try? fm.removeItem(at: folder) }
            for (entry, damage) in [(early, earlyDamage), (late, lateDamage)] {
                let url = folder.appendingPathComponent(entry.path)
                try damage == "truncate" ? truncate(url) : corrupt(url)
            }
            XCTAssertThrowsError(try OriginalApplicationCatalogInputs.load(directory: folder)) { error in
                let expected: OriginalApplicationCatalogInputs.Boundary = earlyDamage == "truncate" ? .invalid(early.path) : .invalid(early.name)
                XCTAssertEqual(error as? OriginalApplicationCatalogInputs.Boundary, expected, "early \(earlyDamage), late \(lateDamage)")
            }
        }
    }

    func testTheFirstFailingArenaEntryInManifestOrderDecides() throws {
        let source = try OriginalApplicationCatalogInputs.bundledDirectory().deletingLastPathComponent().appendingPathComponent("OriginalMatchArenas")
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: source.appendingPathComponent("manifest.json")))
        XCTAssertGreaterThan(manifest.entries.count, 3)
        let early = manifest.entries[1], late = manifest.entries[manifest.entries.count - 1]
        let folder = try copied(source); defer { try? fm.removeItem(at: folder) }
        try corrupt(folder.appendingPathComponent(late.path)); try corrupt(folder.appendingPathComponent(early.path))
        XCTAssertThrowsError(try OriginalApplicationArenaInputs.load(directory: folder)) { error in
            XCTAssertEqual("\(error)", "\(OriginalStateError.invalidStorage("Arena inputs: " + early.path))")
        }
    }
}
