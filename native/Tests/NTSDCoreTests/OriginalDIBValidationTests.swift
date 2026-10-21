import Foundation
import XCTest
@testable import NTSDCore

/// MEMORY_LOADING L4: bitmaps are validated at load without being decoded.
/// `OriginalDIBPixels.validate` must succeed with the decoder's pixel offset
/// exactly when the decoder succeeds, and otherwise throw the decoder's error,
/// on every packaged image and on seeded mutations of small images of every
/// supported format.
/// ENGINE_SPLIT E4c-2: its synthetic tests moved to the engine's NTSDEngineTests (same class name).
final class OriginalDIBValidationTests: XCTestCase {
    func outcome(_ body: () throws -> Int) -> String {
        do { return "offset \(try body())" } catch let error as OriginalDIBPixels.Boundary { return "error \(error.rawValue)" }
        catch { return "other \(error)" }
    }
    func check(_ dib: [UInt8], maximumPixels: Int = 16_777_216, pixelOffset: Int? = nil, _ label: @autoclosure () -> String) {
        XCTAssertEqual(outcome { try OriginalDIBPixels.validate(dib: dib, maximumPixels: maximumPixels, pixelOffset: pixelOffset) },
                       outcome { try OriginalDIBPixels(dib: dib, maximumPixels: maximumPixels, pixelOffset: pixelOffset).pixelOffset }, label())
    }

    func testEveryPackagedImageValidatesAsItDecodes() throws {
        let catalog = try OriginalApplicationCatalogInputs.load(directory: OriginalApplicationCatalogInputs.bundledDirectory())
        let arenas = try OriginalApplicationArenaInputs.bundled()
        var count = 0
        for (name, bitmap) in Array(catalog.bitmaps) + Array(arenas.bitmaps) {
            let declared = bitmap.bitmapFileHeader == nil ? nil : bitmap.pixelOffset
            check(bitmap.dib, pixelOffset: declared, name); count += 1
        }
        XCTAssertGreaterThan(count, 680)
    }
}
