import XCTest
@testable import RandoriCore

/// MEMORY_LOADING L4: bitmaps are validated at load without being decoded.
/// `OriginalDIBPixels.validate` must succeed with the decoder's pixel offset
/// exactly when the decoder succeeds, and otherwise throw the decoder's error,
/// on every packaged image and on seeded mutations of small images of every
/// supported format.
/// ENGINE_SPLIT E4c-2: the synthetic half of native's OriginalDIBValidationTests; the content-reading tests stay there.
final class OriginalDIBValidationTests: XCTestCase {
    struct Generator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    }
    func outcome(_ body: () throws -> Int) -> String {
        do { return "offset \(try body())" } catch let error as OriginalDIBPixels.Boundary { return "error \(error.rawValue)" }
        catch { return "other \(error)" }
    }
    func check(_ dib: [UInt8], maximumPixels: Int = 16_777_216, pixelOffset: Int? = nil, _ label: @autoclosure () -> String) {
        XCTAssertEqual(outcome { try OriginalDIBPixels.validate(dib: dib, maximumPixels: maximumPixels, pixelOffset: pixelOffset) },
                       outcome { try OriginalDIBPixels(dib: dib, maximumPixels: maximumPixels, pixelOffset: pixelOffset).pixelOffset }, label())
    }
    func dib(width: Int, height: Int, bits: Int, compression: UInt32 = 0, colors: Int, pixels: [UInt8]) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 40)
        func put(_ value: UInt32, _ at: Int) { for i in 0..<4 { bytes[at+i] = UInt8(truncatingIfNeeded: value >> (8*UInt32(i))) } }
        put(40, 0); put(UInt32(width), 4); put(UInt32(height), 8); bytes[12] = 1; bytes[14] = UInt8(bits)
        put(compression, 16); put(compression == 1 ? UInt32(pixels.count) : 0, 20); put(UInt32(colors), 32)
        for i in 0..<colors { bytes += [UInt8(i), UInt8(255-i), UInt8(i*7 & 255), 0] }
        return bytes + pixels
    }

    func testSeededMutationsFailAsTheDecoderFails() {
        var random = Generator(state: 0x5eed)
        let samples: [(String, [UInt8])] = [
            ("24-bit", dib(width: 5, height: 3, bits: 24, colors: 0, pixels: (0..<48).map { UInt8($0) })),
            ("8-bit", dib(width: 5, height: 3, bits: 8, colors: 6, pixels: (0..<24).map { UInt8($0 % 6) })),
            ("4-bit", dib(width: 5, height: 3, bits: 4, colors: 5, pixels: (0..<12).map { _ in 0x34 })),
            ("RLE8", dib(width: 4, height: 2, bits: 8, compression: 1, colors: 4, pixels: [2, 1, 0, 2, 2, 3, 0, 0, 4, 2, 0, 1])),
        ]
        for (name, base) in samples {
            check(base, name)
            for trial in 0..<4000 {
                var bytes = base
                switch trial % 4 {
                case 0: bytes[Int.random(in: 0..<min(bytes.count, 64), using: &random)] = UInt8.random(in: 0...255, using: &random)
                case 1: bytes.removeLast(Int.random(in: 0...min(bytes.count, 30), using: &random))
                case 2: bytes[Int.random(in: 40..<bytes.count, using: &random)] = UInt8.random(in: 0...255, using: &random)
                default:
                    for _ in 0..<3 { bytes[Int.random(in: 0..<bytes.count, using: &random)] = UInt8.random(in: 0...20, using: &random) }
                }
                let offset: Int? = trial % 7 == 0 ? Int.random(in: 0...bytes.count + 4, using: &random) : nil
                let limit = trial % 11 == 0 ? Int.random(in: 0...20, using: &random) : 16_777_216
                check(bytes, maximumPixels: limit, pixelOffset: offset, "\(name) trial \(trial)")
            }
        }
    }
}
