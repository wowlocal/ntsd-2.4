import Foundation
import XCTest
@testable import RandoriCore

/// MEMORY_LOADING L3: package entries are read, verified and decoded
/// concurrently and taken in manifest order, so the first failing entry in that
/// order still decides the error, whichever entry fails first in time.
/// ENGINE_SPLIT E4c-2: its synthetic tests moved to the engine's RandoriTests (same class name).
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

    /// The early entry is the largest file and fails only after its digest; the
    /// last entry fails at once on its size: the late failure comes first in
    /// time, the early one still decides.
    func testAnEarlierEntryThatFailsLaterInTimeStillDecides() throws {
        struct Sized: Decodable { let name: String, path: String, count: Int }
        struct SizedManifest: Decodable { let entries: [Sized] }
        let source = try OriginalApplicationCatalogInputs.bundledDirectory()
        let entries = try JSONDecoder().decode(SizedManifest.self, from: Data(contentsOf: source.appendingPathComponent("manifest.json"))).entries
        let early = try XCTUnwrap(entries.dropLast().max { $0.count < $1.count }), late = try XCTUnwrap(entries.last)
        XCTAssertGreaterThan(early.count, 1_000_000)
        let folder = try copied(source); defer { try? fm.removeItem(at: folder) }
        try corrupt(folder.appendingPathComponent(early.path)); try truncate(folder.appendingPathComponent(late.path))
        XCTAssertThrowsError(try OriginalApplicationCatalogInputs.load(directory: folder)) { error in
            XCTAssertEqual(error as? OriginalApplicationCatalogInputs.Boundary, .invalid(early.name))
        }
    }

    func testArenaReadErrorsAndMismatchesKeepTheManifestOrder() throws {
        let source = try OriginalApplicationCatalogInputs.bundledDirectory().deletingLastPathComponent().appendingPathComponent("OriginalMatchArenas")
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: source.appendingPathComponent("manifest.json")))
        let early = manifest.entries[1], late = manifest.entries[manifest.entries.count - 1]
        let mismatch = "\(OriginalStateError.invalidStorage("Arena inputs: " + early.path))"
        for removeEarly in [false, true] {
            let folder = try copied(source); defer { try? fm.removeItem(at: folder) }
            if removeEarly {
                try fm.removeItem(at: folder.appendingPathComponent(early.path)); try corrupt(folder.appendingPathComponent(late.path))
            } else {
                try corrupt(folder.appendingPathComponent(early.path)); try fm.removeItem(at: folder.appendingPathComponent(late.path))
            }
            XCTAssertThrowsError(try OriginalApplicationArenaInputs.load(directory: folder)) { error in
                // A missing early file fails in its read (a file-system error), before any later mismatch.
                if removeEarly { XCTAssertNotEqual("\(error)", mismatch); XCTAssertFalse("\(error)".contains("Arena inputs")) }
                else { XCTAssertEqual("\(error)", mismatch) }
            }
        }
    }

    /// A wrong-sized or unreadable arena file is read in manifest order as
    /// before: its own read error (or the guard's) decides, never a later one.
    func testArenaFilesOfAnotherSizeOrUnreadableFailAsBefore() throws {
        let source = try OriginalApplicationCatalogInputs.bundledDirectory().deletingLastPathComponent().appendingPathComponent("OriginalMatchArenas")
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: source.appendingPathComponent("manifest.json")))
        let early = manifest.entries[2], late = manifest.entries[manifest.entries.count - 1]
        for damage in ["truncate", "unreadable", "directory"] {
            let folder = try copied(source); defer { try? fm.removeItem(at: folder) }
            let url = folder.appendingPathComponent(early.path)
            switch damage {
            case "truncate": try truncate(url)
            case "unreadable": try truncate(url); try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: url.path)
            default: try fm.removeItem(at: url); try fm.createDirectory(at: url, withIntermediateDirectories: false)
            }
            defer { try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path) }
            try corrupt(folder.appendingPathComponent(late.path))
            XCTAssertThrowsError(try OriginalApplicationArenaInputs.load(directory: folder)) { error in
                let description = "\(error)"
                switch damage {
                case "truncate": XCTAssertEqual(description, "\(OriginalStateError.invalidStorage("Arena inputs: " + early.path))")
                case "directory": XCTAssertEqual(description, "\(OriginalStateError.invalidStorage("Arena inputs: Ordinary packaged file"))")
                default: XCTAssertFalse(description.contains("Arena inputs"), description)   // the read's own permission error
                }
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
