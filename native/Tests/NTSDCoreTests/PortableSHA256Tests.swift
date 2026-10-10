import Foundation
import XCTest
#if canImport(CryptoKit)
import CryptoKit
#endif
@testable import NTSDCore

/// Hosts without CryptoKit check packaged inputs with PortableSHA256, so it
/// must give the same digest as CryptoKit on every packaged input.
final class PortableSHA256Tests: XCTestCase {
    private func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined() }

    func testStandardVectors() {
        let vectors: [(String, String)] = [
            ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
            ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
            ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
             "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"),
            ("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
             "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1")]
        for (message, expected) in vectors { XCTAssertEqual(hex(PortableSHA256.hash(data: Data(message.utf8))), expected, message) }
        XCTAssertEqual(hex(PortableSHA256.hash(data: Data(repeating: UInt8(ascii: "a"), count: 1_000_000))),
                       "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }

    /// Every length across two block boundaries, also delivered in split regions.
    func testLengthsAndSplitRegions() {
        var generator = SystemRandomNumberGenerator()
        for length in 0...200 {
            let bytes = (0..<length).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
            let whole = PortableSHA256.hash(data: bytes)
            var hasher = PortableSHA256.Hasher()
            var offset = 0, step = 1
            while offset < length {
                let end = min(length, offset + step)
                bytes[offset..<end].withUnsafeBytes { hasher.update($0) }
                offset = end; step = step % 67 + 3
            }
            XCTAssertEqual(hasher.finalize(), whole, "length \(length)")
            #if canImport(CryptoKit)
            XCTAssertEqual(whole, Array(SHA256.hash(data: Data(bytes))), "length \(length)")
            #endif
        }
    }

    #if canImport(CryptoKit)
    func testEveryPackagedInputMatchesCryptoKit() throws {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let roots = ["Sources/NTSDCore/Resources", "Sources/NTSDMacPlatform/Resources"].map { native.appendingPathComponent($0) }
        var files = 0, bytes = 0
        for root in roots {
            let iterator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]))
            for case let url as URL in iterator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                let data = try Data(contentsOf: url)
                XCTAssertEqual(PortableSHA256.hash(data: data), Array(SHA256.hash(data: data)), url.path)
                files += 1; bytes += data.count
            }
        }
        XCTAssertGreaterThan(files, 0)
        print("PortableSHA256 matched CryptoKit on \(files) packaged files, \(bytes) bytes")
    }
    #endif
}
