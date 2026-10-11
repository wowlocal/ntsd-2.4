import Foundation
import XCTest
@testable import NTSDCore

/// MEMORY_LOADING L16: the loaded catalog loads objects without a rollback
/// copy; a loader that keeps the rollback still leaves earlier state unchanged
/// on a failure, and both load the same object into the same state.
final class OriginalInPlaceObjectLoadTests: XCTestCase {
    let good = """
    <bmp_begin>
    file(anything): sheet.bmp w: 7 h: 7 row: 1 col: 1
    <bmp_end>
    <frame> 0 sound sound: data\\001.wav <frame_end>
    """
    let bad = """
    <bmp_begin>
    file(anything): other.bmp w: 7 h: 7 row: 1 col: 1
    <bmp_end>
    <frame> 0 sound sound: data\\002.wav <frame_end>
    <frame> 400 unsupported <frame_end>
    """
    func load(_ loader: inout OriginalObjectLoader, _ text: String, id: Int32, rollback: Bool = true) throws -> OriginalLoadedObject {
        try loader.load(decoded: text, id: id, type: 0, headerBacking: Array(repeating: 0xa5, count: 0x7a4), tailBacking: Array(repeating: 0xa5, count: 0x3c),
                        frameAllocation: { _, _ in nil }, bitmapSource: { .init(path: $0, present: true, width: 8, height: 8) }, rollback: rollback)
    }
    struct State: Equatable { let bitmaps: [OriginalLoadedBitmap], allocations: [OriginalFrameAllocation], sounds: Int, soundBytes: [UInt8], checksum: UInt32 }
    func state(_ l: OriginalObjectLoader) -> State { .init(bitmaps: l.bitmaps, allocations: l.frameAllocations, sounds: l.soundCount, soundBytes: l.soundBytes, checksum: l.checksum) }

    func testAFailedLoadWithItsRollbackKeepsEarlierState() throws {
        var loader = OriginalObjectLoader()
        _ = try load(&loader, good, id: 1)
        let before = state(loader)
        XCTAssertFalse(before.bitmaps.isEmpty); XCTAssertFalse(before.allocations.isEmpty); XCTAssertEqual(before.sounds, 1)
        XCTAssertThrowsError(try load(&loader, bad, id: 2))
        XCTAssertEqual(state(loader), before)
    }

    func testLoadingInPlaceGivesTheSameObjectsAndState() throws {
        var copying = OriginalObjectLoader(), inPlace = OriginalObjectLoader()
        for (id, text) in [(Int32(1), good), (2, good.replacingOccurrences(of: "001.wav", with: "003.wav"))] {
            let a = try load(&copying, text, id: id), b = try load(&inPlace, text, id: id, rollback: false)
            XCTAssertEqual(a, b); XCTAssertEqual(state(copying), state(inPlace))
        }
        // A failure in place leaves the loader empty; its caller drops it.
        XCTAssertThrowsError(try load(&inPlace, bad, id: 3, rollback: false))
        XCTAssertEqual(state(inPlace), state(OriginalObjectLoader()))
    }

    func testStreamChecksThrowTheSameErrorAndChangeNothing() throws {
        var files = OriginalLoadingFiles(translation: .text)
        var next: UInt32 = 0x1000
        let allocate: OriginalLoadingFiles.Allocate = { _, _ in next += 0x100; return .init(token: next, buffer: next + 8, descriptor: next + 4, capacity: 64, readLimit: 16) }
        let input = try files.open("a.txt", mode: "r", source: { _ in Array("hello world".utf8) }, allocate: allocate)
        let output = try files.open("b.txt", mode: "w", source: { _ in [] }, allocate: allocate)
        XCTAssertEqual(try files.character(input), UInt8(ascii: "h"))
        let unknown: UInt32 = 0xdead
        for (token, expectRead, expectWrite) in [(unknown, false, false), (output, false, true), (input, true, false)] {
            let before = files
            if !expectRead {
                XCTAssertThrowsError(try files.character(token)) { XCTAssertEqual("\($0)", "\(OriginalStateError.invalidStorage("Loading files: Unknown, closed or wrong-mode stream"))") }
                XCTAssertThrowsError(try files.scannerAccess(token, position: 1))
                XCTAssertEqual(files, before)
            }
            if !expectWrite {
                XCTAssertThrowsError(try files.write([1], to: token)); XCTAssertEqual(files, before)
            }
        }
        _ = try files.close(input)
        let closed = files
        XCTAssertThrowsError(try files.character(input)); XCTAssertThrowsError(try files.scannerAccess(input, position: 2)); XCTAssertEqual(files, closed)
    }
}
