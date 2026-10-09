import Foundation
import XCTest
@testable import NTSDCore

/// Blt and fill commands built directly (CORE_REALTIME tier 3 G3a) equal
/// `consume`'s: the same command or the same error, the owner unchanged.
final class OriginalApplicationGraphicsDirectTests: XCTestCase {
    private typealias G = OriginalApplicationGraphics

    private enum Outcome: Equatable {
        case command(G.Command?), error(String)
        var failed: Bool { if case .error = self { return true }; return false }
    }
    private func outcome(_ body: () throws -> G.Command?) -> Outcome {
        do { return .command(try body()) } catch { return .error(String(describing: error)) }
    }

    func testDirectBlitAndFillMatchConsume() throws {
        let package = try OriginalApplicationStartupInputsTests.shared.get()
        let fresh = OriginalApplicationBitmapInputs(resources: package.bitmaps)
        var inputs = fresh, g = try OriginalApplicationGraphicsTests.display()
        func call(_ kind: String, _ words: [UInt32], _ result: Int32 = 0, output: UInt32? = nil,
                  strings: [[UInt8]] = [], structure: OriginalStateRecord? = nil) throws {
            let q = OriginalBitmapSurfaceLoading.Request(kind, words, strings: strings, structure: structure)
            var nextInputs = inputs, nextGraphics = g
            let response = try nextInputs.response(q, control: .init(result: result, output: output))
            _ = try nextGraphics.bitmap(q, response, inputs: nextInputs)
            inputs = nextInputs; g = nextGraphics
        }
        try call("image", [1, 0, 0, 0, 0x2000], 20, strings: [Array("CS2".utf8)])
        var descriptor = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: 108), defined: [Bool](repeating: true, count: 108))
        for (at, value): (Int, UInt32) in [(0, 108), (4, 7), (8, 2), (12, 2), (104, 0x40)] { try descriptor.write(value, at: at) }
        try call("createSurface", [1, 0], output: 10, structure: descriptor)
        try call("createDC", [0], 30); try call("selectObject", [30, 20], 1); try call("getDC", [10], output: 31)
        try call("stretch", [31, 0, 0, 2, 2, 30, 0, 0, 2, 2, 0xcc0020], 1)

        var compared = 0, commands = 0, errors = 0, colored = 0
        let rectangles: [[Int32]] = [[0, 0, 2, 2], [-5, 3, 700, 9], [0, 0, 2], [0, 0, 2, 2, 7], []]
        for source: UInt32 in [0, 2, 3, 10, 999] {
            for target: UInt32 in [0, 2, 3, 10, 999] {
                for (r, rect) in rectangles.enumerated() {
                    for owner in [inputs, fresh] as [OriginalApplicationBitmapInputs?] + [nil] {
                        let blit = OriginalBitmapBlit(sourceSurface: source, targetSurface: target,
                            source: rect, destination: r == 1 ? [1, 2, 3, 4] : rect, flags: 0x1008000,
                            effects: source == 3 ? [UInt8](repeating: 1, count: 100) : nil)
                        var old = g
                        let before = g
                        let expected = outcome { try old.consume(.blit(blit, result: Int32(r) - 1), inputs: owner) }
                        let actual = outcome { try g.blitCommand(blit, result: Int32(r) - 1, inputs: owner) }
                        XCTAssertEqual(actual, expected, "blit \(source)->\(target) rect \(rect)")
                        XCTAssertEqual(g, before, "the mutating builder leaves the owner unchanged")
                        XCTAssertEqual(old, before, "consume left the owner unchanged")
                        compared += 1
                        if expected.failed { errors += 1 } else { commands += 1 }
                        if case .command(let c?) = expected, c.sourceColors != nil { colored += 1 }
                    }
                }
                let fill = OriginalSurfaceFillRequest(target: target, rectangle: rectangles[Int(source % 5)],
                    flags: 0x1000400, effects: [UInt8](repeating: 0, count: 100), defined: [Bool](repeating: source == 2, count: 100))
                var old = g
                let before = g
                let expected = outcome { try old.consume(.fill(fill, result: 3), inputs: inputs) }
                XCTAssertEqual(outcome { try g.fillCommand(fill, result: 3) }, expected, "fill \(target) \(fill.rectangle)")
                XCTAssertEqual(g, before)
                XCTAssertEqual(old, before)
                compared += 1
                if expected.failed { errors += 1 } else { commands += 1 }
            }
        }
        XCTAssertEqual(compared, 5 * 5 * 5 * 3 + 25)
        // Exact counts, so a path that starts failing cannot hide: 60 Blts
        // (6 of them from the bitmap surface, with its colours) and 6 fills.
        XCTAssertEqual(commands, 66)
        XCTAssertEqual(errors, 334)
        XCTAssertEqual(colored, 6)
    }

    /// Without a graphics owner, a loaded attempt's Blt, fill and other
    /// effects all throw the Graphics dependency (G3c's review).
    func testLoadedCommandWithoutOwnerThrows() throws {
        typealias Session = OriginalApplicationMenuSession
        var bytes = [UInt8](repeating: 0, count: 0xc3a8)
        bytes[0xb580] = 58
        let mask = [Bool](repeating: true, count: 0xc3a8), full = try OriginalStateRecord(bytes: bytes, defined: mask)
        let pointers = try OriginalStateRecord(bytes: Array(bytes[0xb8a8..<0xb8b0]), defined: Array(mask[0xb8a8..<0xb8b0]))
        var state = try Session.State(full: full, memory: .init(replayPointers: pointers), front: .init(), frontSurfaces: [:],
                                      earlyScreen: .init(), libraryText: .init(), random: .init(), screenBody: nil)
        XCTAssertNil(state.graphics)
        let blit = OriginalBitmapBlit(sourceSurface: 0, targetSurface: 3, source: [0, 0, 2, 2], destination: [0, 0, 2, 2],
                                      flags: 0x1008000, effects: nil)
        let fill = OriginalSurfaceFillRequest(target: 3, rectangle: [0, 0, 2, 2], flags: 0x1000400,
                                              effects: [UInt8](repeating: 0, count: 100), defined: [Bool](repeating: true, count: 100))
        for effect: Session.Effect in [.blit(blit, result: 0), .fill(fill, result: 0), .free(5)] {
            XCTAssertThrowsError(try state.loadedCommand(for: effect)) { error in
                XCTAssertEqual(error as? OriginalApplicationLoadedMenuSession.Boundary, .dependency("Graphics"))
            }
        }
    }
}
