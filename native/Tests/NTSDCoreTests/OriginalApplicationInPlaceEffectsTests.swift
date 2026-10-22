import Foundation
import XCTest
@testable import RandoriCore

/// MEMORY_LOADING L5: the bitmap inputs' `response` and the graphics' `bitmap`
/// run in place, without a rollback copy, because each throws only before its
/// first change. Every rejected call must leave the value exactly as it was.
final class OriginalApplicationInPlaceEffectsTests: XCTestCase {
    typealias Request = OriginalBitmapSurfaceLoading.Request

    func descriptor(width: UInt32 = 2, height: UInt32 = 2, flags: UInt32 = 7, size: UInt32 = 108) throws -> OriginalStateRecord {
        var d = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: 108), defined: [Bool](repeating: true, count: 108))
        for (at, value): (Int, UInt32) in [(0, size), (4, flags), (8, height), (12, width), (104, 0x40)] { try d.write(value, at: at) }
        return d
    }

    func testRejectedCallsLeaveInputsAndGraphicsUnchanged() throws {
        let package = try OriginalApplicationStartupInputsTests.shared.get()
        var inputs = OriginalApplicationBitmapInputs(resources: package.bitmaps), g = try OriginalApplicationGraphicsTests.display()
        func call(_ kind: String, _ words: [UInt32], _ result: Int32 = 0, output: UInt32? = nil,
                  strings: [[UInt8]] = [], structure: OriginalStateRecord? = nil) throws {
            let q = Request(kind, words, strings: strings, structure: structure)
            let response = try inputs.response(q, control: .init(result: result, output: output))
            _ = try g.bitmap(q, response, inputs: inputs)
        }
        try call("image", [1, 0, 0, 0, 0x2000], 20, strings: [Array("CS2".utf8)])
        try call("createSurface", [1, 0], output: 10, structure: descriptor())
        try call("createDC", [0], 30); try call("selectObject", [30, 20], 1); try call("getDC", [10], output: 31)
        try call("stretch", [31, 0, 0, 2, 2, 30, 0, 0, 2, 2, 0xcc0020], 1)
        try call("image", [1, 0, 0, 0, 0x2000], 21, strings: [Array("CS2".utf8)])
        try call("deleteObject", [21], 1)

        // Each request fails one of the inputs' checks.
        let cs2 = [Array("CS2".utf8)]
        let rejected: [(String, Request, OriginalBitmapSurfaceLoading.Response)] = [
            ("writes", Request("description", [10]), .init(result: 0, writes: [.init(bytes: [1])])),
            ("image words", Request("image", [1, 0, 0, 0x2000], strings: cs2), .init(result: 22)),
            ("image unknown", Request("image", [1, 0, 0, 0, 0x2000], strings: [Array("NOPE".utf8)]), .init(result: 22)),
            ("image live handle", Request("image", [1, 0, 0, 0, 0x2000], strings: cs2), .init(result: 20)),
            ("image flags", Request("image", [1, 0, 0, 0, 0x2010], strings: cs2), .init(result: 22)),
            ("getObject size", Request("getObject", [20, 23]), .init(result: 24)),
            ("getObject deleted", Request("getObject", [21, 24]), .init(result: 24)),
            ("createSurface negative", Request("createSurface", [1, 0], structure: try descriptor()), .init(result: -1, output: 11)),
            ("createSurface token 0", Request("createSurface", [1, 0], structure: try descriptor()), .init(result: 0, output: 0)),
            ("createSurface live", Request("createSurface", [1, 0], structure: try descriptor()), .init(result: 0, output: 10)),
            ("createSurface missing", Request("createSurface", [1, 0]), .init(result: 0, output: 11)),
            ("createSurface size", Request("createSurface", [1, 0], structure: try descriptor(size: 100)), .init(result: 0, output: 11)),
            ("createSurface flags", Request("createSurface", [1, 0], structure: try descriptor(flags: 1)), .init(result: 0, output: 11)),
            ("createSurface huge", Request("createSurface", [1, 0], structure: try descriptor(width: 100_000, height: 100_000)), .init(result: 0, output: 11)),
            ("description unknown", Request("description", [99]), .init(result: 0)),
            ("createDC words", Request("createDC", [1]), .init(result: 32)),
            ("createDC live", Request("createDC", [0]), .init(result: 30)),
            ("selectObject unknown DC", Request("selectObject", [99, 20]), .init(result: 1)),
            ("selectObject deleted", Request("selectObject", [30, 21]), .init(result: 1)),
            ("selectObject failure", Request("selectObject", [30, 20]), .init(result: -1)),
            ("getDC unknown", Request("getDC", [99]), .init(result: 0, output: 33)),
            ("getDC failed output", Request("getDC", [10]), .init(result: -1, output: 33)),
            ("getDC live token", Request("getDC", [10]), .init(result: 0, output: 30)),
            ("getDC no output", Request("getDC", [10]), .init(result: 0)),
            ("stretch rop", Request("stretch", [31, 0, 0, 2, 2, 30, 0, 0, 2, 2, 0x660046]), .init(result: 1)),
            ("stretch scale", Request("stretch", [31, 0, 0, 2, 2, 30, 0, 0, 1, 2, 0xcc0020]), .init(result: 1)),
            ("stretch outside", Request("stretch", [31, 1, 1, 2, 2, 30, 0, 0, 2, 2, 0xcc0020]), .init(result: 1)),
            ("releaseDC unknown", Request("releaseDC", [10, 99]), .init(result: 0)),
            ("deleteDC unknown", Request("deleteDC", [99]), .init(result: 1)),
            ("deleteObject deleted", Request("deleteObject", [21]), .init(result: 1)),
            ("release unknown", Request("release", [99]), .init(result: 0)),
        ]
        for (label, q, control) in rejected {
            let before = inputs
            XCTAssertThrowsError(try inputs.response(q, control: control), label)
            XCTAssertEqual(inputs, before, label)
        }
        // Each request fails one of the graphics' checks (the inputs answer it).
        let graphicsRejected: [(String, Request, OriginalBitmapSurfaceLoading.Response)] = [
            ("surface not an input", Request("createSurface", [1, 0]), .init(result: 0, output: 77)),
            ("surface created twice", Request("createSurface", [1, 0]), .init(result: 0, output: 10)),
            ("image not an input", Request("image", [1, 0, 0, 0, 0x2000]), .init(result: 77)),
            ("image created twice", Request("image", [1, 0, 0, 0, 0x2000]), .init(result: 20)),
            ("owner unknown", Request("getObject", [77, 24]), .init(result: 24)),
            ("selected DC unknown", Request("selectObject", [77, 20]), .init(result: 1)),
            ("stretch DC unknown", Request("stretch", [77, 0, 0, 2, 2, 30, 0, 0, 2, 2, 0xcc0020]), .init(result: 1)),
            ("getDC output unknown", Request("getDC", [10]), .init(result: 0, output: 77)),
            ("releaseDC unknown", Request("releaseDC", [10, 77]), .init(result: 0)),
            ("colorKey owner unknown", Request("colorKey", [77]), .init(result: 0)),
            ("unknown kind", Request("unknown", [1]), .init(result: 0)),
        ]
        for (label, q, response) in graphicsRejected {
            let before = g
            XCTAssertThrowsError(try g.bitmap(q, response, inputs: inputs), label)
            XCTAssertEqual(g, before, label)
        }
        // Accepted calls still change both.
        let beforeInputs = inputs, beforeGraphics = g
        try call("release", [10], 0)
        XCTAssertNotEqual(inputs, beforeInputs); XCTAssertNotEqual(g, beforeGraphics)
    }

    /// MEMORY_LOADING L20: `observed` runs in place too (its own checks come
    /// first, then `perform`). A rejected call leaves the inputs as they were;
    /// an accepted one returns the observed response and leaves the inputs as
    /// `response` with the same result and output does.
    func testObservedRunsInPlace() throws {
        let package = try OriginalApplicationStartupInputsTests.shared.get()
        var inputs = OriginalApplicationBitmapInputs(resources: package.bitmaps)
        let cs2 = [Array("CS2".utf8)]
        func both(_ q: Request, _ actual: OriginalBitmapSurfaceLoading.Response, _ label: String) throws {
            var viaResponse = inputs
            _ = try viaResponse.response(q, control: .init(result: actual.result, output: actual.output))
            XCTAssertEqual(try inputs.observed(q, response: actual), actual, label)
            XCTAssertEqual(inputs, viaResponse, label)
        }
        try both(Request("image", [1, 0, 0, 0, 0x2000], strings: cs2), .init(result: 20), "image")
        try both(Request("createSurface", [1, 0], structure: try descriptor()), .init(result: 0, output: 10), "createSurface")
        let object = try inputs.bitmap(forImage: 20).objectBytes()
        try both(Request("getObject", [20, 24]), .init(result: 24, writes: [.init(offset: 4, bytes: Array(object[4..<20]))]), "getObject")
        try both(Request("description", [10]), .init(result: 0, writes: [.init(offset: 8, bytes: Array(try descriptor().bytes[8..<16]))]), "description")
        try both(Request("createDC", [0]), .init(result: 30), "createDC")
        try both(Request("selectObject", [30, 20]), .init(result: 1), "selectObject")
        try both(Request("getDC", [10]), .init(result: 0, output: 31), "getDC")
        try both(Request("stretch", [31, 0, 0, 2, 2, 30, 0, 0, 2, 2, 0xcc0020]), .init(result: 1), "stretch")
        try both(Request("image", [1, 0, 0, 0, 0x2000], strings: cs2), .init(result: 21), "second image")
        try both(Request("deleteObject", [21]), .init(result: 1), "deleteObject")

        let rejected: [(String, Request, OriginalBitmapSurfaceLoading.Response)] = [
            // The observed checks.
            ("getObject extent", Request("getObject", [20, 24]), .init(result: 24, writes: [.init(offset: 2, bytes: [0, 0])])),
            ("getObject conflict", Request("getObject", [20, 24]), .init(result: 24, writes: [.init(offset: 4, bytes: [object[4] ^ 1])])),
            ("getObject owner", Request("getObject", [99, 24]), .init(result: 24)),
            ("getObject deleted owner", Request("getObject", [21, 24]), .init(result: 24)),
            ("description extent", Request("description", [10]), .init(result: 0, writes: [.init(offset: 12, bytes: [0, 0, 0, 0, 0, 0])])),
            ("description owner", Request("description", [99]), .init(result: 0)),
            ("other kinds take no writes", Request("createDC", [0]), .init(result: 32, writes: [.init(offset: 0, bytes: [1])])),
            // perform's checks, reached through observed.
            ("image live handle", Request("image", [1, 0, 0, 0, 0x2000], strings: cs2), .init(result: 20)),
            ("getObject size", Request("getObject", [20, 23]), .init(result: 24)),
            ("createSurface live", Request("createSurface", [1, 0], structure: try descriptor()), .init(result: 0, output: 10)),
            ("createDC live", Request("createDC", [0]), .init(result: 30)),
            ("selectObject failure", Request("selectObject", [30, 20]), .init(result: -1)),
            ("getDC live token", Request("getDC", [10]), .init(result: 0, output: 30)),
            ("stretch outside", Request("stretch", [31, 1, 1, 2, 2, 30, 0, 0, 2, 2, 0xcc0020]), .init(result: 1)),
            ("releaseDC unknown", Request("releaseDC", [10, 99]), .init(result: 0)),
            ("deleteObject deleted", Request("deleteObject", [21]), .init(result: 1)),
        ]
        for (label, q, actual) in rejected {
            let before = inputs
            XCTAssertThrowsError(try inputs.observed(q, response: actual), label)
            XCTAssertEqual(inputs, before, label)
        }
    }
}
