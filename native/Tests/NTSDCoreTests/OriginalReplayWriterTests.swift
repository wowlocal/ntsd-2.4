import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalReplayWriterTests: XCTestCase {
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Event: Decodable {
        let kind: String, name: String?, bytes: String?, path: String?, mode: String?
        let ordinal: UInt32?, address: UInt32?, size: UInt32?, count: UInt32?, value: UInt32?, state: UInt32?
        let status: Int32?, length: Int?, share: Int32?, result: Int32?
    }
    private struct Allocation: Decodable { let address: UInt32, count: UInt32, size: UInt32, live: Bool }
    private struct Stream: Decodable { let name: String, state: UInt32 }
    private struct Fault: Decodable { let kind: String }
    private struct Case: Decodable {
        let label: String, source: String, globals: String, globalsAfter: String
        let compressed: String?, adjusted: String, codecWritten: String
        let nullSource: Bool, sourceFreed: Bool, bufferFailure: Bool
        let allocationFailure: UInt32, recordingPointer: UInt32, longestMatchCalls: UInt32
        let codecStatus: Int32?, length: Int?, processorSignatures: [UInt32]
        let writerEvents: [Event], allocations: [Allocation], streams: [Stream], fault: Fault?
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, crtSHA256: String, cppSHA256: String
        let cases: [Case], blobs: [String:Blob]
    }
    private func hexBytes(_ text: String) throws -> [UInt8] {
        let chars = Array(text.utf8)
        guard chars.count%2 == 0 else { throw OriginalStateError.invalidStorage("Writer fixture hex extent") }
        return try stride(from: 0, to: chars.count, by: 2).map {
            try XCTUnwrap(UInt8(String(decoding: chars[$0..<$0+2], as: UTF8.self), radix: 16))
        }
    }

    func testWholeOriginalWriterIncludingCleanupAndFailureBoundaries() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_REPLAY_WRITER_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-replay-writer", withExtension: "json", subdirectory: "Fixtures")) }
        let corpus = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 192_000_000))
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.crtSHA256, "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        XCTAssertEqual(corpus.cppSHA256, "372af797353f9335915cd06d4076bab8410775dcaf2dac0593197d7c41bbffb2")
        XCTAssertFalse(corpus.cases.isEmpty)
        var cache: [String:[UInt8]] = [:], complete = 0, faults = 0, writes = 0, writtenBytes = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let value = cache[key] { return value }
            let item = try XCTUnwrap(corpus.blobs[key])
            // This corpus uses zlib-framed transport, whereas the shared
            // Compression framework helper consumes the raw deflate body.
            let packed = try XCTUnwrap(Data(base64Encoded: item.deflate))
            guard packed.count >= 6, packed[0] == 0x78, packed[1] == 0xda else {
                throw OriginalStateError.invalidStorage("Writer fixture zlib framing")
            }
            let value = try MatchPreparationReference.inflate(Data(packed.dropFirst(2).dropLast(4)).base64EncodedString(), count: item.count)
            guard MatchPreparationReference.digest(Data(value)) == key else {
                throw OriginalStateError.invalidStorage("Writer fixture blob hash")
            }
            cache[key] = value; return value
        }
        func same(_ value: [UInt8], _ key: String, _ label: String) throws {
            guard value == (try blob(key)) else {
                throw OriginalStateError.invalidStorage("Writer bytes differ: \(label), native SHA \(MatchPreparationReference.digest(Data(value))), source SHA \(key)")
            }
        }
        for c in corpus.cases {
            let source = try blob(c.source), beforeGlobals = try blob(c.globals)
            var globals = try OriginalStateRecord(bytes: beforeGlobals, defined: .init(repeating: true, count: beforeGlobals.count))
            var pointers = try OriginalStateRecord(bytes: .init(repeating: 0, count: 8), defined: .init(repeating: true, count: 8))
            try pointers.write(UInt32(c.nullSource ? 0 : 0x24000000), at: 0)
            var memory = OriginalMenuPresentationMemory(replayPointers: pointers)
            if !c.nullSource {
                memory.allocations[0x24000000] = .init(storage: try .init(bytes: source, defined: .init(repeating: true, count: source.count)))
            }
            let oldMemory = memory, oldGlobals = globals
            let compressedIndex = c.writerEvents.firstIndex { $0.kind == "compressed" } ?? c.writerEvents.count
            let firstAllocation = try XCTUnwrap(c.writerEvents.firstIndex { $0.kind == "calloc" })
            let privateEvents = Array(c.writerEvents[(firstAllocation+1)..<compressedIndex])
            let sequence = Array(c.writerEvents[...firstAllocation]) + Array(c.writerEvents[compressedIndex...])
            var cursor = 0, processor = 0
            func next(_ kind: String, _ name: String? = nil) throws -> Event {
                guard cursor < sequence.count, sequence[cursor].kind == kind,
                      name == nil || sequence[cursor].name == name else {
                    throw OriginalStateError.invalidStorage("Writer event \(cursor): \(kind)/\(name ?? "") in \(c.label)")
                }
                defer { cursor += 1 }; return sequence[cursor]
            }
            let observe: (OriginalReplayWriter.Event) throws -> Void = { event in
                switch event {
                case .format(let value): try same(value, XCTUnwrap(next("format").bytes), c.label+" format")
                case .calloc(let address):
                    let e = try next("calloc")
                    XCTAssertEqual(address, e.address, c.label)
                    XCTAssertEqual(e.count, 1); XCTAssertEqual(e.size, UInt32(OriginalReplayWriter.capacity))
                case .compressed(let status, let length):
                    let e = try next("compressed")
                    XCTAssertEqual(status, e.status, c.label); XCTAssertEqual(length, e.length, c.label)
                case .adjusted: _ = try next("adjusted")
                case .streamReturn(let name, let state): XCTAssertEqual(try next("streamReturn", name).state, state, c.label)
                case .free(let address): XCTAssertEqual(try next("free").address, address, c.label)
                case .clearRecordingPointer:
                    let e = try next("pointer")
                    XCTAssertEqual(e.address, 0x4588a8); XCTAssertEqual(e.size, 4); XCTAssertEqual(e.value, 0)
                }
            }
            let signature: () throws -> UInt32 = {
                guard processor < c.processorSignatures.count else {
                    throw OriginalStateError.invalidStorage("Unexpected native processor detector: \(c.label)")
                }
                defer { processor += 1 }; return c.processorSignatures[processor]
            }
            let open: (OriginalReplayFileOutput.OpenRequest) throws -> Bool = { request in
                let e = try next("file", "_wfsopen")
                XCTAssertEqual(request.path.flatMap { [UInt8(truncatingIfNeeded: $0), UInt8(truncatingIfNeeded: $0 >> 8)] }, try self.hexBytes(XCTUnwrap(e.path)), c.label)
                XCTAssertEqual(request.mode.flatMap { [$0, UInt8(0)] }, try self.hexBytes(XCTUnwrap(e.mode)), c.label)
                XCTAssertEqual(request.share, e.share, c.label)
                return try XCTUnwrap(e.result) != 0
            }
            let write: ([UInt8]) throws -> Int32 = { value in
                let e = try next("file", "_write")
                try same(value, XCTUnwrap(e.bytes), c.label+" descriptor write")
                XCTAssertEqual(value.count, e.count.map(Int.init), c.label)
                writes += 1; writtenBytes += value.count
                return try XCTUnwrap(e.result)
            }
            let close: () throws -> Int32 = { try XCTUnwrap(next("file", "_close").result) }
            do {
                let result: OriginalReplayWriter.Result
                if c.allocationFailure <= 1 && !c.bufferFailure {
                    result = try OriginalReplayWriter.write(globals: &globals, memory: &memory,
                        allocate: { c.allocationFailure == 1 ? 0 : 0x25000000 }, processorSignature: signature,
                        open: open, write: write, close: close, observe: observe)
                } else {
                    result = try OriginalReplayWriter.run(globals: &globals, memory: &memory,
                        codecFailureOrdinal: c.allocationFailure == 0 ? 0 : c.allocationFailure-1, bufferAvailable: !c.bufferFailure,
                        allocate: { c.allocationFailure == 1 ? 0 : 0x25000000 }, processorSignature: signature,
                        open: open, write: write, close: close, observe: observe)
                }
                guard c.fault == nil else { return XCTFail("Native returned across source fault: \(c.label)") }
                XCTAssertEqual(cursor, sequence.count, c.label); XCTAssertEqual(processor, c.processorSignatures.count, c.label)
                XCTAssertEqual(result.compression.status, c.codecStatus, c.label)
                XCTAssertEqual(result.compression.length, c.length, c.label)
                XCTAssertEqual(result.compression.longestMatchCalls, c.longestMatchCalls, c.label)
                try same(globals.bytes, c.globalsAfter, c.label+" globals")
                XCTAssertEqual(globals.defined, oldGlobals.defined, c.label)
                XCTAssertEqual(try memory.replayPointers.integer(at: 0, as: UInt32.self), c.recordingPointer, c.label)
                XCTAssertEqual(memory.replayPointers.bytes.suffix(4), oldMemory.replayPointers.bytes.suffix(4))
                XCTAssertEqual(memory.replayPointers.defined, oldMemory.replayPointers.defined)
                if !c.nullSource {
                    let recording = try XCTUnwrap(memory.allocations[0x24000000])
                    XCTAssertEqual(recording.storage, oldMemory.allocations[0x24000000]?.storage, c.label)
                    XCTAssertEqual(recording.live, !c.sourceFreed, c.label)
                }
                if result.temporary != 0 {
                    try same(XCTUnwrap(result.compressed).bytes, XCTUnwrap(c.compressed), c.label+" compressed")
                    let output = try XCTUnwrap(memory.allocations[result.temporary])
                    try same(output.storage.bytes, c.adjusted, c.label+" adjusted")
                    XCTAssertFalse(output.live, c.label)
                    XCTAssertTrue(output.storage.defined.allSatisfy({ $0 }), c.label)
                    XCTAssertTrue(try XCTUnwrap(result.compressed).defined.allSatisfy({ $0 }), c.label)
                } else { XCTAssertNil(result.compressed); XCTAssertNil(memory.allocations[0]) }
                let written = try blob(c.codecWritten)
                XCTAssertTrue(written == .init(repeating: 1, count: result.compression.written) + .init(repeating: 0, count: OriginalReplayWriter.capacity-result.compression.written), c.label)
                XCTAssertEqual(result.stream.streamStates, c.streams.map(\.state), c.label)
                let allocations = Array(c.allocations.dropFirst())
                let ordinals = Dictionary(uniqueKeysWithValues: allocations.enumerated().filter { $0.element.address != 0 }.map { ($0.element.address, UInt32($0.offset+1)) })
                XCTAssertEqual(result.compression.unreleasedAllocations, allocations.filter(\.live).count, c.label)
                XCTAssertEqual(result.compression.allocationEvents.count, privateEvents.count, c.label)
                for (native, original) in zip(result.compression.allocationEvents, privateEvents) {
                    XCTAssertEqual(native.kind, original.kind == "calloc" ? 1 : 2, c.label)
                    XCTAssertEqual(native.ordinal, original.address.flatMap { ordinals[$0] } ?? 0, c.label)
                    if original.kind == "calloc" {
                        XCTAssertEqual(native.count, original.count, c.label)
                        let size = try XCTUnwrap(original.size)
                        XCTAssertEqual(native.nativeSize, size == 5816 ? 5920 : size, c.label)
                    }
                }
                complete += 1
                if c.label == "original" {
                    var trialGlobals = oldGlobals, trialMemory = oldMemory
                    var released: [UInt32] = [], cleared = false, closed = false
                    XCTAssertThrowsError(try OriginalReplayWriter.write(globals: &trialGlobals, memory: &trialMemory,
                        allocate: { 0x25000000 }, processorSignature: { try XCTUnwrap(c.processorSignatures.first) },
                        open: { _ in true }, write: { Int32($0.count) }, close: { closed = true; return 0 },
                        observe: { event in
                            if case .free(let address) = event { released.append(address) }
                            if case .clearRecordingPointer = event { cleared = true }
                            if case .streamReturn("destroy", _) = event {
                                throw OriginalStateError.invalidStorage("Writer late observer")
                            }
                        })) { error in
                        guard case OriginalStateError.invalidStorage("Writer late observer") = error else {
                            return XCTFail("Unexpected writer transaction error: \(error)")
                        }
                    }
                    XCTAssertTrue(closed); XCTAssertTrue(cleared)
                    XCTAssertEqual(released, [0x25000000, 0x24000000])
                    XCTAssertEqual(trialGlobals, oldGlobals)
                    XCTAssertEqual(trialMemory.allocations, oldMemory.allocations)
                    XCTAssertEqual(trialMemory.replayPointers, oldMemory.replayPointers)
                }
            } catch {
                guard let fault = c.fault, let stateError = error as? OriginalStateError else { throw error }
                let expected: String
                if fault.kind == "unmappedBacking" { expected = "Replay writer modified codec version pointer" }
                else if fault.kind == "cookie" { expected = "Replay writer path overwrites original stack cookie" }
                else if fault.kind == "crtInvalidParameter" { expected = "Replay stream: NULL payload invalid parameter" }
                else if c.streams.isEmpty { expected = "Replay writer NULL key-adjustment destination" }
                else { return XCTFail("Unclassified writer fault \(fault.kind) in \(c.label)") }
                guard case .invalidStorage(let detail) = stateError, detail == expected else { throw error }
                XCTAssertEqual(globals, oldGlobals, c.label)
                XCTAssertEqual(memory.allocations, oldMemory.allocations, c.label)
                XCTAssertEqual(memory.replayPointers, oldMemory.replayPointers, c.label)
                faults += 1
            }
        }
        print("REPLAY WRITER", complete, "whole returns,", faults, "explicit unsupported source faults,", writes, "descriptor writes,", writtenBytes, "requested bytes")
    }
}
