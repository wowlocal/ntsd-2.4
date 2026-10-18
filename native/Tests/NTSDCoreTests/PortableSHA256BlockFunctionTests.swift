import Foundation
import XCTest
#if canImport(CryptoKit)
import CryptoKit
#endif
@testable import NTSDCore

/// MEMORY_LOADING L11: a host block function is installed only when it gives
/// the Swift digests, and the hasher drives it over whole blocks exactly as
/// its own compression.
final class PortableSHA256BlockFunctionTests: XCTestCase {
    /// The Swift compression, block by block, as a C function (no capture).
    static let swiftBlocks: PortableSHA256.BlockFunction = { state, data, count in
        PortableSHA256.referenceBlocks(state, data, count)
    }
    static let wrongBlocks: PortableSHA256.BlockFunction = { state, _, _ in state[0] ^= 1 }
    /// Right for one block, but only the first of several.
    static let firstBlockOnly: PortableSHA256.BlockFunction = { state, data, count in
        PortableSHA256.referenceBlocks(state, data, min(count, 1))
    }
    override func tearDown() { PortableSHA256.install(nil) }

    func testOnlyAFunctionGivingTheSameDigestsIsInstalled() throws {
        let message = Array("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)
        let expected = PortableSHA256.hash(data: message)
        XCTAssertFalse(PortableSHA256.install(Self.wrongBlocks))
        XCTAssertFalse(PortableSHA256.install(Self.firstBlockOnly)); XCTAssertFalse(PortableSHA256.usesHostBlocks)
        XCTAssertEqual(PortableSHA256.hash(data: message), expected)
        XCTAssertTrue(PortableSHA256.install(Self.swiftBlocks)); XCTAssertTrue(PortableSHA256.usesHostBlocks)
        XCTAssertEqual(PortableSHA256.hash(data: message), expected)
        // Split deliveries cross the pending-block path and the whole-block runs.
        for length in [0, 1, 63, 64, 65, 200, 4097] {
            let bytes = (0..<length).map { UInt8(truncatingIfNeeded: $0 &* 131 &+ 7) }
            var hasher = PortableSHA256.Hasher(); var offset = 0, step = 1
            while offset < length { let end = min(length, offset + step); bytes[offset..<end].withUnsafeBytes { hasher.update($0) }; offset = end; step = step * 3 + 1 }
            PortableSHA256.install(nil)
            let plain = PortableSHA256.hash(data: bytes)
            PortableSHA256.install(Self.swiftBlocks)
            XCTAssertEqual(hasher.finalize(), plain, "\(length)")
        }
    }

    #if canImport(CryptoKit)
    func testInstalledFunctionDigestsEveryPackagedInputAsCryptoKit() throws {
        XCTAssertTrue(PortableSHA256.install(Self.swiftBlocks))
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = native.appendingPathComponent("Sources/NTSDContent/Resources/OriginalStartup")
        let iterator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]))
        var files = 0
        for case let url as URL in iterator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            let data = try Data(contentsOf: url)
            XCTAssertEqual(PortableSHA256.hash(data: data), Array(SHA256.hash(data: data)), url.path); files += 1
        }
        XCTAssertGreaterThan(files, 40)
    }
    #endif
}
