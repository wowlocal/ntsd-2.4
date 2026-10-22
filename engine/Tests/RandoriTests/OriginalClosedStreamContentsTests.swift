import Foundation
import XCTest
@testable import RandoriCore

/// MEMORY_LOADING M7a: after the catalog load, closed streams keep everything
/// but their contents; open streams, the order, staged files and decoder
/// results are unchanged.
final class OriginalClosedStreamContentsTests: XCTestCase {
    func testClosedStreamsLoseOnlyTheirContents() throws {
        var files = OriginalLoadingFiles(translation: .text)
        var next: UInt32 = 0x1000
        let allocate: OriginalLoadingFiles.Allocate = { _, _ in next += 0x100; return .init(token: next, buffer: next + 8, descriptor: next + 4, capacity: 64, readLimit: 16) }
        let a = try files.open("a.txt", mode: "r", source: { _ in Array("hello\nworld\n".utf8) }, allocate: allocate)
        for _ in 0..<5 { _ = try files.character(a) }
        let b = try files.open("b.txt", mode: "w", source: { _ in [] }, allocate: allocate)
        try files.write(Array("line\none\n".utf8), to: b)
        let c = try files.open("c.txt", mode: "r", source: { _ in Array("open".utf8) }, allocate: allocate)
        _ = try files.close(a); _ = try files.close(b)
        let released = files.releasingClosedContents()
        XCTAssertEqual(Array(released.streams.keys), Array(files.streams.keys))
        XCTAssertEqual(released.order, files.order); XCTAssertEqual(released.files, files.files); XCTAssertEqual(released.decoderReturns, files.decoderReturns)
        for token in [a, b] {
            let before = try XCTUnwrap(files.streams[token]), after = try XCTUnwrap(released.streams[token])
            XCTAssertEqual(after.allocation, before.allocation); XCTAssertEqual(after.path, before.path); XCTAssertEqual(after.mode, before.mode)
            XCTAssertEqual(after.position, before.position); XCTAssertEqual(after.loaded, before.loaded)
            XCTAssertEqual(after.eof, before.eof); XCTAssertTrue(after.closed)
            XCTAssertTrue(after.raw.isEmpty && after.input.isEmpty && after.output.isEmpty && after.pending.isEmpty)
        }
        XCTAssertFalse(files.streams[a]!.input.isEmpty); XCTAssertFalse(files.files["b.txt"]!.isEmpty)
        XCTAssertEqual(released.streams[c], files.streams[c])
        // The open stream still reads on.
        var reading = released
        XCTAssertEqual(try reading.character(c), UInt8(ascii: "o"))
    }
}
