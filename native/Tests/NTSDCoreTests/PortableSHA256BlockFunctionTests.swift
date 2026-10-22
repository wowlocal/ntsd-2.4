import Foundation
import XCTest
#if canImport(CryptoKit)
import CryptoKit
#endif
@testable import RandoriCore

/// MEMORY_LOADING L11: a host block function is installed only when it gives
/// the Swift digests, and the hasher drives it over whole blocks exactly as
/// its own compression.
/// ENGINE_SPLIT E4c-2: its synthetic tests moved to the engine's RandoriTests (same class name).
final class PortableSHA256BlockFunctionTests: XCTestCase {
    /// The Swift compression, block by block, as a C function (no capture).
    static let swiftBlocks: PortableSHA256.BlockFunction = { state, data, count in
        PortableSHA256.referenceBlocks(state, data, count)
    }
    override func tearDown() { PortableSHA256.install(nil) }

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
