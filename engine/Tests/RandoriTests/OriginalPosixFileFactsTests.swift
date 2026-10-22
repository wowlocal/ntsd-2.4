import Foundation
import XCTest
@testable import RandoriCore

/// MEMORY_LOADING L17: Linux and Android read the loaders' file facts with
/// lstat/stat; on this host they must give what resourceValues and
/// fileExists give for every kind of entry the loaders meet.
final class OriginalPosixFileFactsTests: XCTestCase {
    func testPosixFactsMatchResourceValues() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ntsd-facts-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true); defer { try? fm.removeItem(at: root) }
        let file = root.appendingPathComponent("file.bin"), empty = root.appendingPathComponent("empty.bin")
        let directory = root.appendingPathComponent("dir"), missing = root.appendingPathComponent("missing")
        try Data((0..<12345).map { UInt8(truncatingIfNeeded: $0) }).write(to: file); try Data().write(to: empty)
        try fm.createDirectory(at: directory, withIntermediateDirectories: false)
        let fileLink = root.appendingPathComponent("file-link"), dirLink = root.appendingPathComponent("dir-link"), dangling = root.appendingPathComponent("dangling")
        try fm.createSymbolicLink(at: fileLink, withDestinationURL: file)
        try fm.createSymbolicLink(at: dirLink, withDestinationURL: directory)
        try fm.createSymbolicLink(atPath: dangling.path, withDestinationPath: missing.path)
        let fifo = root.appendingPathComponent("fifo"); XCTAssertEqual(mkfifo(fifo.path, 0o644), 0)
        // A directory link spelled with a trailing slash, as appendingPathComponent
        // makes for a directory.
        let slashed = URL(fileURLWithPath: dirLink.path, isDirectory: true)
        let keys: [Set<URLResourceKey>] = [[.isDirectoryKey, .isSymbolicLinkKey], [.isRegularFileKey, .isSymbolicLinkKey],
                                           [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]]
        for url in [root, file, empty, directory, fileLink, dirLink, dangling, fifo, slashed] {
            XCTAssertEqual(OriginalFileFacts.posixExists(url), fm.fileExists(atPath: url.path), url.lastPathComponent)
            for set in keys {
                let v = try url.resourceValues(forKeys: set), p = try OriginalFileFacts.posix(url, set)
                XCTAssertEqual(p.isDirectory, v.isDirectory, "\(url.lastPathComponent) \(set)")
                XCTAssertEqual(p.isRegularFile, v.isRegularFile, "\(url.lastPathComponent) \(set)")
                XCTAssertEqual(p.isSymbolicLink, v.isSymbolicLink, "\(url.lastPathComponent) \(set)")
                // The loaders read the size only of a regular file.
                if v.isRegularFile == true { XCTAssertEqual(p.fileSize, v.fileSize, url.lastPathComponent) }
            }
        }
        // Failures (missing, through a file, below an unsearchable directory)
        // are resourceValues' own: the same error.
        let locked = root.appendingPathComponent("locked"), inside = locked.appendingPathComponent("x")
        try fm.createDirectory(at: locked, withIntermediateDirectories: false); try Data([1]).write(to: inside)
        try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }
        for url in [missing, file.appendingPathComponent("x"), inside] {
            XCTAssertEqual(OriginalFileFacts.posixExists(url), fm.fileExists(atPath: url.path), url.path)
            let posix = Result { try OriginalFileFacts.posix(url, [.isRegularFileKey]) }, values = Result { try url.resourceValues(forKeys: [.isRegularFileKey]) }
            guard case .failure(let p) = posix, case .failure(let v) = values else { XCTFail("both must fail: \(url.path)"); continue }
            // The descriptions differ only in the underlying error's address.
            XCTAssertEqual((p as NSError).domain, (v as NSError).domain, url.path); XCTAssertEqual((p as NSError).code, (v as NSError).code, url.path)
        }
    }
}
