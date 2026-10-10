import XCTest
@testable import NTSDCore

/// MEMORY_LOADING L1: the stream steps change their stream in place. A throwing
/// observer must still leave the files exactly as before, at every event of a
/// whole DAT decode (with and without VC80's scanf lookahead) and inside a
/// single character or scanner step whose refills it rejects.
final class OriginalLoadingFilesInPlaceTests: XCTestCase {
    enum Stop: Error { case at(Int) }
    /// A synthetic encrypted file: the 123-byte header and enough payload for
    /// several 4096-byte refills and one full 65536-byte output buffer.
    let raw: [UInt8] = (0..<(123 + 70_001)).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }
    var tokens: UInt32 = 0x40000000
    func allocate(_ path: String, _ mode: String) throws -> OriginalLoadingFileAllocation {
        tokens += 0x20000
        return .init(token: tokens, buffer: tokens + 0x1000, descriptor: tokens >> 16, capacity: 65536, readLimit: 4096)
    }

    func testThrowingObserverAtEveryDecodeEventLeavesTheFilesUnchanged() throws {
        for lookahead in [false, true] {
            var files = OriginalLoadingFiles(translation: .raw, scanfLookahead: lookahead)
            _ = try files.decodeDAT("a.dat", source: { _ in self.raw }, allocate: allocate)
            let prior = files, base = tokens
            var events: [OriginalLoadingFileEvent] = []
            var done = prior
            _ = try done.decodeDAT("b.dat", source: { _ in self.raw }, allocate: allocate, observe: { events.append($0) })
            XCTAssertEqual(events.filter { $0.kind == .writeFile }.count, 2)
            XCTAssertGreaterThan(events.filter { $0.kind == .readFile }.count, 17)
            XCTAssertEqual(done.files[OriginalLoadingFiles.temporaryPath]?.count, lookahead ? 70_000 : 70_001)
            for stop in events.indices {
                var trial = prior, seen = 0
                tokens = base
                XCTAssertThrowsError(try trial.decodeDAT("b.dat", source: { _ in self.raw }, allocate: allocate, observe: { e in
                    XCTAssertEqual(e, events[seen]); defer { seen += 1 }
                    if seen == stop { throw Stop.at(stop) }
                }))
                XCTAssertEqual(trial, prior, "lookahead \(lookahead), observer throws at event \(stop)")
            }
        }
    }

    func testRejectedRefillLeavesTheStreamUnchanged() throws {
        var files = OriginalLoadingFiles(translation: .raw)
        let token = try files.open("plain.txt", mode: "r", source: { _ in self.raw }, allocate: allocate)
        for _ in 0..<4096 { _ = try files.character(token) }
        var prior = files
        // A character at the buffer's end refills first.
        XCTAssertThrowsError(try files.character(token, observe: { _ in throw Stop.at(0) }))
        XCTAssertEqual(files, prior)
        // A scanner look three buffers ahead refills three times; the third is rejected.
        var refills = 0
        XCTAssertThrowsError(try files.scannerAccess(token, position: 4096 * 3 + 5, observe: { _ in
            refills += 1; if refills == 3 { throw Stop.at(3) }
        }))
        XCTAssertEqual(refills, 3); XCTAssertEqual(files, prior)
        // Accepted, the same steps continue from where the stream was.
        XCTAssertEqual(try files.character(token), raw[4096])
        try files.scannerAccess(token, position: 4096 * 3 + 5)
        XCTAssertEqual(files.streams[token]?.loaded, 4096 * 4); XCTAssertEqual(files.streams[token]?.position, 4096 * 3 + 5)
        XCTAssertEqual(try files.character(token), raw[4096 * 3 + 5])
        // A write that fills the buffer flushes before its byte; a rejected flush keeps the earlier bytes of that write.
        let output = try files.open("out.txt", mode: "w", source: { _ in [] }, allocate: allocate)
        try files.write([UInt8](repeating: 1, count: 65536), to: output)
        prior = files
        XCTAssertThrowsError(try files.write([2, 3], to: output, observe: { _ in throw Stop.at(0) }))
        XCTAssertEqual(files, prior)
        try files.write([2, 3], to: output)
        XCTAssertEqual(files.files["out.txt"]?.count, 65536)
        XCTAssertEqual(files.streams[output]?.pending, [2, 3]); XCTAssertEqual(files.streams[output]?.output.count, 65538)
    }
}
