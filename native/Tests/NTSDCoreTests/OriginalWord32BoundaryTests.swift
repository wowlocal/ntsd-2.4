import XCTest
@testable import NTSDCore

/// TVOS_WEB W1b: a header word or declared size of 2^31 and more, from a file
/// or DAT, reaches the same boundary on every host. A 32-bit Int (wasm32)
/// cannot hold such a value, so these checks compare in 64 bits; the tests
/// pin the outcome a 64-bit host always had.
final class OriginalWord32BoundaryTests: XCTestCase {
    private func put(_ value: UInt32, _ at: Int, _ bytes: inout [UInt8]) {
        for i in 0..<4 { bytes[at+i] = UInt8(truncatingIfNeeded: value >> (8*UInt32(i))) }
    }
    private func storageText(_ error: Error) -> String? {
        if case OriginalStateError.invalidStorage(let text) = error { return text }
        return nil
    }

    /// A valid 2×1 8-bit DIB with two palette entries and one 4-byte row.
    private func dib() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 40)
        put(40, 0, &bytes); put(2, 4, &bytes); put(1, 8, &bytes); bytes[12] = 1; bytes[14] = 8; put(2, 32, &bytes)
        return bytes + [0, 0, 0, 0, 255, 255, 255, 0] + [0, 1, 0, 0]
    }
    private func bitmapFile() -> [UInt8] {
        let body = dib()
        var file = [UInt8](repeating: 0, count: 14); file[0] = 0x42; file[1] = 0x4d
        put(UInt32(14+body.count), 2, &file); put(14+48, 10, &file)
        return file + body
    }

    func testBitmapFileHeaderWords() throws {
        XCTAssertEqual(try OriginalApplicationStartupInputs.Bitmap(bitmapFile: bitmapFile()).width, 2)
        for (at, value) in [(2, UInt32.max), (2, 0x8000_0000), (10, UInt32.max), (10, 0x8000_0000)] {
            var file = bitmapFile(); put(value, at, &file)
            XCTAssertThrowsError(try OriginalApplicationStartupInputs.Bitmap(bitmapFile: file), "word \(at) = \(value)") {
                XCTAssertEqual($0 as? OriginalApplicationStartupInputs.Boundary, .invalid("BMP file extent or reserved fields"))
            }
        }
        for value in [UInt32.max, 0x8000_0000] {
            var file = bitmapFile(); put(value, 14+32, &file)
            XCTAssertThrowsError(try OriginalApplicationStartupInputs.Bitmap(bitmapFile: file), "colors \(value)") {
                XCTAssertEqual($0 as? OriginalApplicationStartupInputs.Boundary, .invalid("BMP pixel offset or palette"))
            }
        }
    }

    func testDIBHeaderWords() throws {
        XCTAssertEqual(try OriginalDIBPixels.validate(dib: dib()), 48)
        for (at, value, boundary) in [(32, UInt32.max, OriginalDIBPixels.Boundary.palette), (32, 0x8000_0000, .palette),
                                      (20, UInt32.max, .extent), (20, 0x8000_0000, .extent)] {
            var bytes = dib(); put(value, at, &bytes)
            XCTAssertThrowsError(try OriginalDIBPixels(dib: bytes), "decode word \(at) = \(value)") {
                XCTAssertEqual($0 as? OriginalDIBPixels.Boundary, boundary)
            }
            XCTAssertThrowsError(try OriginalDIBPixels.validate(dib: bytes), "validate word \(at) = \(value)") {
                XCTAssertEqual($0 as? OriginalDIBPixels.Boundary, boundary)
            }
        }
    }

    func testRLEImageSize() throws {
        for value in [UInt32.max, 0x8000_0000] {
            var bytes = dib(); put(1, 16, &bytes); put(value, 20, &bytes)
            XCTAssertThrowsError(try OriginalDIBPixels(dib: bytes), "decode RLE size \(value)") {
                XCTAssertEqual($0 as? OriginalDIBPixels.Boundary, .extent)
            }
            XCTAssertThrowsError(try OriginalDIBPixels.validate(dib: bytes), "validate RLE size \(value)") {
                XCTAssertEqual($0 as? OriginalDIBPixels.Boundary, .extent)
            }
        }
    }

    /// A name byte of 0x80–0xFB is a negative glyph frame whose first word
    /// (frame×4+0x10, as `draw` reads it) wraps past 2^31, outside the record.
    func testNegativeGlyphFrameWord() throws {
        let bitmap = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: 0x1f50), defined: [Bool](repeating: true, count: 0x1f50))
        for frame: Int32 in [-128, -100, -5] {
            let offset = UInt32(bitPattern: frame) &* 4 &+ 0x10
            XCTAssertThrowsError(try OriginalBitmapDrawing.word(offset, bitmap: bitmap, surface: 0, detail: false, observe: { _ in }),
                                 "frame \(frame)") {
                guard case OriginalStateError.outOfBounds(let reported, let count) = $0 else { return XCTFail("\($0)") }
                XCTAssertEqual(reported, Int(truncatingIfNeeded: offset)); XCTAssertEqual(count, 4)
            }
        }
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

    func testWaveChunkSize() throws {
        let platform = OriginalWavePlatform(destination: 4, device: 1, stream: 1, buffer: 0, firstPointer: 0, secondPointer: 0,
            descendResults: [0, 0, 0], formatReadResult: 0, ascendResult: 0, dataReadResult: 0, createResult: 0,
            lockResults: [0, 0], restoreResult: 0, unlockResult: 0, closeResult: 0, firstCount: 0, secondCount: 0, ramp: false)
        for value in [UInt32.max, 0x8000_0000] {
            var file = Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WAVE".utf8) + [UInt8](repeating: 0, count: 20)
            put(value, 4, &file)
            XCTAssertThrowsError(try OriginalWaveLoader.load(path: Array("data\\a.wav".utf8), file: file, output: 0, platform: platform),
                                 "size \(value)") {
                XCTAssertEqual(self.storageText($0), "Wave loading: RIFF chunk extends beyond the supplied file/parent")
            }
        }
    }
}
