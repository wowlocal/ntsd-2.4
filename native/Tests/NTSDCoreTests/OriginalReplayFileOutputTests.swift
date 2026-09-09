import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalReplayFileOutputTests: XCTestCase {
    private struct Call: Decodable { let name: String, state: UInt32 }
    private struct Event: Decodable {
        let name: String
        let path: String?, mode: String?, share: Int32?, count: Int?, bytes: String?, result: Int32?, address: UInt32?
    }
    private struct Case: Decodable {
        let label: String, payload: String, path: String
        let bufferFailure: Bool, calls: [Call], events: [Event]
    }
    private struct Corpus: Decodable { let cppSHA256: String, crtSHA256: String, cases: [Case] }
    private func bytes(_ hex: String) throws -> [UInt8] {
        let chars = Array(hex.utf8)
        guard chars.count%2 == 0 else { throw OriginalStateError.invalidStorage("Replay stream hex extent") }
        return try stride(from: 0, to: chars.count, by: 2).map { i in
            try XCTUnwrap(UInt8(String(decoding: chars[i..<i+2], as: UTF8.self), radix: 16))
        }
    }
    func testOriginalStreamSequenceIncludingBufferedAndUnbufferedFailures() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_REPLAY_STREAM_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-replay-stream", withExtension: "json", subdirectory: "Fixtures")) }
        let corpus = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 32_000_000))
        XCTAssertEqual(corpus.cppSHA256, "372af797353f9335915cd06d4076bab8410775dcaf2dac0593197d7c41bbffb2")
        XCTAssertEqual(corpus.crtSHA256, "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        XCTAssertFalse(corpus.cases.isEmpty)
        var writes = 0, outputBytes = 0
        for c in corpus.cases {
            let io = c.events.filter { ["_wfsopen", "_write", "_close"].contains($0.name) }
            var cursor = 0
            func next(_ name: String) throws -> Event {
                guard cursor < io.count, io[cursor].name == name else {
                    throw OriginalStateError.invalidStorage("Replay stream unexpected \(name) in \(c.label)")
                }
                defer { cursor += 1 }; return io[cursor]
            }
            let open: (OriginalReplayFileOutput.OpenRequest) throws -> Bool = { request in
                let e = try next("_wfsopen")
                XCTAssertEqual(request.path.flatMap { [UInt8(truncatingIfNeeded: $0), UInt8(truncatingIfNeeded: $0 >> 8)] }, try self.bytes(XCTUnwrap(e.path)), c.label)
                XCTAssertEqual(request.mode.flatMap { [$0, UInt8(0)] }, try self.bytes(XCTUnwrap(e.mode)), c.label)
                XCTAssertEqual(request.share, e.share, c.label)
                return try XCTUnwrap(e.result) != 0
            }
            let write: ([UInt8]) throws -> Int32 = { value in
                let e = try next("_write")
                XCTAssertEqual(value, try self.bytes(XCTUnwrap(e.bytes)), c.label)
                XCTAssertEqual(value.count, e.count, c.label)
                writes += 1; outputBytes += value.count
                return try XCTUnwrap(e.result)
            }
            let close: () throws -> Int32 = { try XCTUnwrap(next("_close").result) }
            let result: OriginalReplayFileOutput.Result
            if c.bufferFailure {
                result = try OriginalReplayFileOutput.run(bytes(c.payload), path: bytes(c.path), bufferAvailable: false,
                                                          open: open, write: write, close: close)
            } else {
                result = try OriginalReplayFileOutput.write(bytes(c.payload), path: bytes(c.path), open: open, write: write, close: close)
            }
            XCTAssertEqual(cursor, io.count, c.label)
            XCTAssertEqual(c.calls.map(\.name), ["construct", "write", "write", "close", "destroy"], c.label)
            XCTAssertEqual(result.streamStates, c.calls.map(\.state), c.label)
            let allocations = c.events.filter { $0.name == "_malloc_crt" && $0.count == 4096 }
            XCTAssertEqual(allocations.count, result.bufferRequested ? 1 : 0, c.label)
            XCTAssertEqual(result.unbuffered, allocations.first?.address == 0, c.label)
        }
        print("REPLAY STREAM", corpus.cases.count, "sequences,", writes, "descriptor writes,", outputBytes, "requested bytes")
    }
}
