import Foundation
import XCTest
@testable import NTSDCore

/// `OriginalBitmapDrawing.draw` with `detail` false runs a stack-value path
/// (CORE_REALTIME tier 3 G1). It must perform the same Blts in the same order
/// and return or throw the same as the observed path, over random bitmaps and
/// inputs: negative and out-of-range frames, whole-bitmap fallthrough,
/// mirroring, clipping on every edge, null surfaces and broken bindings.
final class OriginalBitmapDrawingUnobservedTests: XCTestCase {
    private struct Generator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state >> 17
        }
        mutating func int(_ range: ClosedRange<Int>) -> Int { range.lowerBound + Int(next() % UInt64(range.count)) }
        mutating func chance(_ percent: Int) -> Bool { int(0...99) < percent }
    }

    private enum Outcome: Equatable {
        case returned(Int32, [OriginalBitmapBlit])
        case threw(String, [OriginalBitmapBlit])
    }

    private func run(_ input: OriginalBitmapDrawInput, _ bitmap: OriginalStateRecord, detail: Bool,
                     responses: [Int32]) -> Outcome {
        var blits: [OriginalBitmapBlit] = []
        do {
            let value = try OriginalBitmapDrawing.draw(input, bitmap: bitmap, detail: detail, perform: { blit in
                blits.append(blit); return responses[(blits.count - 1) % responses.count]
            })
            return .returned(value, blits)
        } catch {
            return .threw(String(describing: error), blits)
        }
    }

    func testUnobservedDrawMatchesTheObservedOne() throws {
        var g = Generator(state: 0x6731)
        var returned = 0, threw = 0, performed = 0, mirrored = 0, clipped = 0
        for _ in 0..<6000 {
            let surface: UInt32 = g.chance(8) ? 0 : 0x22003000
            // Definedness is not read on this path (raw words), so all bytes are defined.
            var bytes = [UInt8](repeating: 0, count: 0x1f50)
            for i in bytes.indices { bytes[i] = UInt8(truncatingIfNeeded: g.next()) }
            func put(_ value: Int32, at offset: Int) {
                for k in 0..<4 { bytes[offset + k] = UInt8(truncatingIfNeeded: UInt32(bitPattern: value) >> (8 * k)) }
            }
            let binding: Int32 = g.chance(4) ? 7 : (surface == 0 ? 0 : 1)
            put(binding, at: 0)
            put(Int32(g.int(-300...300)), at: 4)
            put(Int32(g.int(-300...300)), at: 8)
            // 5%: a frame count far past the tables, so large frames read
            // beyond the bitmap and fail on its bounds.
            let huge = g.chance(5)
            let frames = huge ? 5000 : g.chance(10) ? 0 : Int32(g.int(1...40))
            put(frames, at: 0x0c)
            for f in 0..<64 {
                put(Int32(g.int(-50...400)), at: 0x10 + 4 * f)
                put(Int32(g.int(-50...400)), at: 0x7e0 + 4 * f)
                put(Int32(g.int(-60...320)), at: 0xfb0 + 4 * f)
                put(Int32(g.int(-60...320)), at: 0x1780 + 4 * f)
            }
            let bitmap = try OriginalStateRecord(bytes: bytes, defined: [Bool](repeating: true, count: bytes.count))
            let frame: Int32 = huge ? Int32(g.int(1000...4000)) : g.chance(10) ? Int32(g.int(-6 ... -1)) : Int32(g.int(0...45))
            let input = OriginalBitmapDrawInput(
                x: Int32(g.int(-400...1000)), y: Int32(g.int(-400...800)), frame: frame,
                colorKey: g.chance(50) ? 1 : 0, mirrored: g.chance(30) ? 1 : 0,
                sourceSurface: surface, targetSurface: g.chance(6) ? 0 : 0x22003100,
                viewportWidth: g.chance(5) ? Int32(g.int(-20...20)) : 640,
                viewportHeight: g.chance(5) ? Int32(g.int(-20...20)) : 480)
            let responses = [Int32(g.int(-5...5)), Int32(g.int(-5...5))]
            let observed = run(input, bitmap, detail: true, responses: responses)
            let unobserved = run(input, bitmap, detail: false, responses: responses)
            XCTAssertEqual(unobserved, observed, "input \(input)")
            switch observed {
            case .returned(_, let blits):
                returned += 1; performed += blits.count
                if input.mirrored != 0 && !blits.isEmpty { mirrored += 1 }
                if blits.contains(where: { $0.destination[0] == 0 || $0.destination[1] == 0
                    || $0.destination[2] == input.viewportWidth || $0.destination[3] == input.viewportHeight }) { clipped += 1 }
            case .threw: threw += 1
            }
        }
        // The corpus reaches every branch it is meant to.
        XCTAssertGreaterThan(returned, 3000)
        XCTAssertGreaterThan(threw, 200)
        XCTAssertGreaterThan(performed, 700)
        XCTAssertGreaterThan(mirrored, 200)
        XCTAssertGreaterThan(clipped, 200)
    }

    /// A null target and a broken surface binding together: the whole-bitmap
    /// Blt checks the target before the binding word, the frame Blt reads the
    /// binding first. Both paths keep that order.
    func testNullTargetAndBindingOrder() throws {
        func bitmap(frames: Int32) throws -> OriginalStateRecord {
            var bytes = [UInt8](repeating: 0, count: 0x1f50)
            func put(_ value: Int32, at offset: Int) {
                for k in 0..<4 { bytes[offset + k] = UInt8(truncatingIfNeeded: UInt32(bitPattern: value) >> (8 * k)) }
            }
            put(7, at: 0); put(10, at: 4); put(10, at: 8); put(frames, at: 0x0c)
            put(2, at: 0x10 + 4); put(3, at: 0x7e0 + 4); put(12, at: 0xfb0 + 4); put(12, at: 0x1780 + 4)
            return try OriginalStateRecord(bytes: bytes, defined: [Bool](repeating: true, count: bytes.count))
        }
        let input = OriginalBitmapDrawInput(x: 10, y: 10, frame: 1, colorKey: 1, mirrored: 0,
            sourceSurface: 0x22003000, targetSurface: 0, viewportWidth: 640, viewportHeight: 480)
        let whole = try bitmap(frames: 0), framed = try bitmap(frames: 5)
        for detail in [true, false] {
            XCTAssertEqual(run(input, whole, detail: detail, responses: [0]),
                           .threw(String(describing: OriginalStateError.invalidStorage("Null bitmap target surface")), []))
            XCTAssertEqual(run(input, framed, detail: detail, responses: [0]),
                           .threw(String(describing: OriginalStateError.invalidStorage("Bitmap surface binding")), []))
        }
    }
}
