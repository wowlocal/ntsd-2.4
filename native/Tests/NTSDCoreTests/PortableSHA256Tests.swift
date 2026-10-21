import Foundation
import XCTest
#if canImport(CryptoKit)
import CryptoKit
#endif
@testable import NTSDCore

/// Hosts without CryptoKit check packaged inputs with PortableSHA256, so it
/// must give the same digest as CryptoKit on every packaged input.
/// ENGINE_SPLIT E4c-2: its synthetic tests moved to the engine's NTSDEngineTests (same class name).
final class PortableSHA256Tests: XCTestCase {
    #if canImport(CryptoKit)
    func testEveryPackagedInputMatchesCryptoKit() throws {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let roots = ["Sources/NTSDContent/Resources"].map { native.appendingPathComponent($0) }
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
