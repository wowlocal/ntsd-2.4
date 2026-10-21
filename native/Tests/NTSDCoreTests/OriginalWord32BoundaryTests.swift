import XCTest
@testable import NTSDCore

/// TVOS_WEB W1b: a header word or declared size of 2^31 and more, from a file
/// or DAT, reaches the same boundary on every host. A 32-bit Int (wasm32)
/// cannot hold such a value, so these checks compare in 64 bits; the tests
/// pin the outcome a 64-bit host always had.
/// ENGINE_SPLIT E4c-2: its synthetic tests moved to the engine's NTSDEngineTests (same class name).
final class OriginalWord32BoundaryTests: XCTestCase {
    private func put(_ value: UInt32, _ at: Int, _ bytes: inout [UInt8]) {
        for i in 0..<4 { bytes[at+i] = UInt8(truncatingIfNeeded: value >> (8*UInt32(i))) }
    }
    private func storageText(_ error: Error) -> String? {
        if case OriginalStateError.invalidStorage(let text) = error { return text }
        return nil
    }

    func testPlaybackPayloadLength() throws {
        let initial = try OriginalApplicationStartupInputs.bundled().initial
        for value in [UInt32.max, 0x8000_0000, UInt32(OriginalReplayFileInput.payloadBound)+1] {
            var file = [UInt8](repeating: 0, count: 1000); put(value, 0, &file)
            var globals = initial
            XCTAssertThrowsError(try OriginalReplayFileInput.load(file: file, globals: &globals), "length \(value)") {
                XCTAssertEqual(self.storageText($0), "Playback payload length beyond the declared bound")
            }
        }
    }
}
