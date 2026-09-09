import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalResultRecordingTests: XCTestCase {
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Options: Decodable { let allocation_failure: UInt32?, buffer_failure: Bool? }
    private struct Spec: Decodable { let stageDefeated: UInt32?, options: Options? }
    private struct Event: Decodable {
        let kind: String, name: String?, bytes: String?, path: String?, mode: String?
        let ordinal: UInt32?, address: UInt32?, size: UInt32?, count: UInt32?, value: UInt32?, state: UInt32?
        let status: Int32?, length: Int?, share: Int32?, result: Int32?
    }
    private struct Helper: Decodable { let entry: UInt32, entrySP: UInt32, returnPC: UInt32, returnSP: UInt32 }
    private struct Access: Decodable { let pc: UInt32, write: Bool }
    private struct Allocation: Decodable { let address: UInt32, count: UInt32, size: UInt32, live: Bool }
    private struct Stream: Decodable { let name: String, state: UInt32 }
    private struct End: Decodable { let pc: UInt32, sp: UInt32 }
    private struct Case: Decodable {
        let label: String, spec: Spec, globals: String, globalsAfter: String, world: String, actors: String, headers: String
        let source: String, sourceAfter: String, playback: String, saved: String, pointers: String, pointersAfter: String
        let writerInput: String?, compressed: String?, adjusted: String?, codecWritten: String
        let sourceFreed: Bool, longestMatchCalls: UInt32, codecStatus: Int32?, length: Int?, processorSignatures: [UInt32]
        let writerEvents: [Event], allocations: [Allocation], streams: [Stream], callerHelpers: [Helper], stackAccesses: [Access]
        let end: End
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, crtSHA256: String, cppSHA256: String, cases: [Case], blobs: [String:Blob]
    }
    private func hexBytes(_ text: String) throws -> [UInt8] {
        let chars = Array(text.utf8)
        guard chars.count%2 == 0 else { throw OriginalStateError.invalidStorage("Result fixture hex extent") }
        return try stride(from: 0, to: chars.count, by: 2).map {
            try XCTUnwrap(UInt8(String(decoding: chars[$0..<$0+2], as: UTF8.self), radix: 16))
        }
    }

    func testWholeOriginalResultRecordingAndWriter() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_RESULT_RECORDING_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-result-recording", withExtension: "json", subdirectory: "Fixtures")) }
        let corpus = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 192_000_000))
        XCTAssertEqual(corpus.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.crtSHA256, "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        XCTAssertEqual(corpus.cppSHA256, "372af797353f9335915cd06d4076bab8410775dcaf2dac0593197d7c41bbffb2")
        XCTAssertFalse(corpus.cases.isEmpty)
        var cache: [String:[UInt8]] = [:], writes = 0, writtenBytes = 0, writerCalls = 0, restores = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let value = cache[key] { return value }
            let item = try XCTUnwrap(corpus.blobs[key]), packed = try XCTUnwrap(Data(base64Encoded: item.deflate))
            guard packed.count >= 6, packed[0] == 0x78, packed[1] == 0xda else { throw OriginalStateError.invalidStorage("Result zlib framing") }
            let value = try MatchPreparationReference.inflate(Data(packed.dropFirst(2).dropLast(4)).base64EncodedString(), count: item.count)
            guard MatchPreparationReference.digest(Data(value)) == key else { throw OriginalStateError.invalidStorage("Result blob hash") }
            cache[key] = value; return value
        }
        func record(_ bytes: [UInt8]) throws -> OriginalStateRecord {
            try .init(bytes: bytes, defined: .init(repeating: true, count: bytes.count))
        }
        func same(_ value: [UInt8], _ key: String, _ label: String) throws {
            let expected = try blob(key)
            guard value == expected else {
                let offset = zip(value, expected).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset
                throw OriginalStateError.invalidStorage("Result bytes differ: \(label), offset \(offset.map { String($0, radix: 16) } ?? "length")")
            }
        }
        for c in corpus.cases {
            var world = try record(blob(c.world)), actors: [OriginalStateRecord] = [], headers: [OriginalStateRecord] = []
            let actorBytes = try blob(c.actors), headerBytes = try blob(c.headers)
            for n in 0..<400 {
                let pointer = try world.integer(at: 0x194+4*n, as: UInt32.self)
                XCTAssertTrue(pointer >= 0x22100000 && (pointer-0x22100000)%0x420 == 0)
                try world.write((pointer-0x22100000)/0x420, at: 0x194+4*n)
                var a = try record(Array(actorBytes[n*0x420..<(n+1)*0x420]))
                let object = try a.integer(at: 0x368, as: UInt32.self)
                XCTAssertTrue(object >= 0x22200000 && (object-0x22200000)%0x76c == 0)
                try a.write((object-0x22200000)/0x76c, at: 0x368); actors.append(a)
            }
            for n in 0..<4 { headers.append(try record(Array(headerBytes[n*0x76c..<(n+1)*0x76c]))) }
            var globals = try record(blob(c.globals))
            var memory = OriginalMenuPresentationMemory(replayPointers: try record(blob(c.pointers)))
            memory.allocations[0x24000000] = .init(storage: try record(blob(c.source)))
            memory.allocations[0x23000000] = .init(storage: try record(blob(c.playback)))
            var context = OriginalInputControlContext(savedPlayback: try record(blob(c.saved)), memory: memory)
            let oldGlobals = globals, oldContext = context
            let failure = c.spec.options?.allocation_failure ?? 0
            let allocationIndex = c.writerEvents.firstIndex { $0.kind == "calloc" }
            let compressedIndex = c.writerEvents.firstIndex { $0.kind == "compressed" }
            let privateEvents: [Event], sequence: [Event]
            if let allocationIndex, let compressedIndex {
                privateEvents = Array(c.writerEvents[(allocationIndex+1)..<compressedIndex])
                sequence = Array(c.writerEvents[...allocationIndex])+Array(c.writerEvents[compressedIndex...])
            } else { privateEvents = []; sequence = c.writerEvents }
            var cursor = 0, processor = 0, restoreCount = 0
            func next(_ kind: String, _ name: String? = nil) throws -> Event {
                guard cursor < sequence.count, sequence[cursor].kind == kind,
                      name == nil || sequence[cursor].name == name else {
                    throw OriginalStateError.invalidStorage("Result event \(cursor): \(kind)/\(name ?? "") in \(c.label)")
                }
                defer { cursor += 1 }; return sequence[cursor]
            }
            let observe: (OriginalResultRecording.Event) throws -> Void = { event in
                switch event {
                case .restorePlayback:
                    XCTAssertEqual(cursor, 0); restoreCount += 1
                case .writer(let event):
                    switch event {
                    case .format(let value): try same(value, XCTUnwrap(next("format").bytes), c.label+" path")
                    case .calloc(let address):
                        let e = try next("calloc"); XCTAssertEqual(address, e.address)
                        XCTAssertEqual(e.count, 1); XCTAssertEqual(e.size, UInt32(OriginalReplayWriter.capacity))
                    case .compressed(let status, let length):
                        let e = try next("compressed"); XCTAssertEqual(status, e.status); XCTAssertEqual(length, e.length)
                    case .adjusted: _ = try next("adjusted")
                    case .streamReturn(let name, let state): XCTAssertEqual(try next("streamReturn", name).state, state)
                    case .free(let address): XCTAssertEqual(try next("free").address, address)
                    case .clearRecordingPointer:
                        let e = try next("pointer"); XCTAssertEqual(e.address, 0x4588a8); XCTAssertEqual(e.size, 4); XCTAssertEqual(e.value, 0)
                    }
                }
            }
            let result = try OriginalResultRecording.apply(world: world, actors: actors, globals: &globals,
                context: &context, stageDefeated: c.stackAccesses.isEmpty ? nil : c.spec.stageDefeated ?? 0,
                header: { try XCTUnwrap(headers.indices.contains($0) ? headers[$0] : nil) },
                codecFailureOrdinal: failure > 1 ? failure-1 : 0, bufferAvailable: !(c.spec.options?.buffer_failure ?? false),
                allocate: { failure == 1 ? 0 : 0x25000000 }, processorSignature: {
                    guard processor < c.processorSignatures.count else { throw OriginalStateError.invalidStorage("Unexpected result processor detector") }
                    defer { processor += 1 }; return c.processorSignatures[processor]
                }, open: { request in
                    let e = try next("file", "_wfsopen")
                    XCTAssertEqual(request.path.flatMap { [UInt8(truncatingIfNeeded: $0), UInt8(truncatingIfNeeded: $0 >> 8)] }, try self.hexBytes(XCTUnwrap(e.path)))
                    XCTAssertEqual(request.mode.flatMap { [$0, UInt8(0)] }, try self.hexBytes(XCTUnwrap(e.mode)))
                    XCTAssertEqual(request.share, e.share); return try XCTUnwrap(e.result) != 0
                }, write: { value in
                    let e = try next("file", "_write"); try same(value, XCTUnwrap(e.bytes), c.label+" write")
                    XCTAssertEqual(value.count, e.count.map(Int.init)); writes += 1; writtenBytes += value.count
                    return try XCTUnwrap(e.result)
                }, close: { try XCTUnwrap(next("file", "_close").result) }, observe: observe)
            XCTAssertEqual(result.continuation.rawValue, c.end.pc, c.label); XCTAssertEqual(c.end.sp, 0x1000f004)
            XCTAssertEqual(cursor, sequence.count, c.label); XCTAssertEqual(processor, c.processorSignatures.count)
            XCTAssertEqual(restoreCount, c.callerHelpers.filter { $0.entry == 0x43df00 }.count); restores += restoreCount
            XCTAssertTrue(c.stackAccesses.allSatisfy { $0.pc == 0x421eb1 && !$0.write })
            try same(globals.bytes, c.globalsAfter, c.label+" globals"); XCTAssertEqual(globals.defined, oldGlobals.defined)
            try same(context.memory.replayPointers.bytes, c.pointersAfter, c.label+" pointers")
            XCTAssertEqual(context.memory.replayPointers.defined, oldContext.memory.replayPointers.defined)
            let recording = try XCTUnwrap(context.memory.allocations[0x24000000])
            try same(recording.storage.bytes, c.sourceAfter, c.label+" serialized recording")
            XCTAssertEqual(recording.storage.defined, oldContext.memory.allocations[0x24000000]?.storage.defined)
            XCTAssertEqual(recording.live, !c.sourceFreed)
            XCTAssertEqual(context.memory.allocations[0x23000000], oldContext.memory.allocations[0x23000000])
            XCTAssertEqual(context.savedPlayback, oldContext.savedPlayback)
            if let writer = result.writer {
                writerCalls += 1
                try same(recording.storage.bytes, XCTUnwrap(c.writerInput), c.label+" writer input")
                XCTAssertEqual(writer.compression.status, c.codecStatus); XCTAssertEqual(writer.compression.length, c.length)
                XCTAssertEqual(writer.compression.longestMatchCalls, c.longestMatchCalls)
                XCTAssertEqual(writer.stream.streamStates, c.streams.map(\.state))
                XCTAssertEqual(c.callerHelpers.last?.entry, 0x43dd60)
                if writer.temporary != 0 {
                    try same(XCTUnwrap(writer.compressed).bytes, XCTUnwrap(c.compressed), c.label+" compressed")
                    let output = try XCTUnwrap(context.memory.allocations[writer.temporary])
                    try same(output.storage.bytes, XCTUnwrap(c.adjusted), c.label+" adjusted")
                    XCTAssertFalse(output.live); XCTAssertTrue(output.storage.defined.allSatisfy { $0 })
                } else { XCTAssertNil(writer.compressed) }
                XCTAssertEqual(try blob(c.codecWritten), [UInt8](repeating: 1, count: writer.compression.written) +
                    [UInt8](repeating: 0, count: OriginalReplayWriter.capacity-writer.compression.written))
                let allocations = Array(c.allocations.dropFirst())
                let ordinals = Dictionary(uniqueKeysWithValues: allocations.enumerated().filter { $0.element.address != 0 }.map { ($0.element.address, UInt32($0.offset+1)) })
                XCTAssertEqual(writer.compression.unreleasedAllocations, allocations.filter(\.live).count)
                XCTAssertEqual(writer.compression.allocationEvents.count, privateEvents.count)
                for (native, original) in zip(writer.compression.allocationEvents, privateEvents) {
                    XCTAssertEqual(native.kind, original.kind == "calloc" ? 1 : 2)
                    XCTAssertEqual(native.ordinal, original.address.flatMap { ordinals[$0] } ?? 0)
                    if original.kind == "calloc" {
                        XCTAssertEqual(native.count, original.count)
                        let size = try XCTUnwrap(original.size); XCTAssertEqual(native.nativeSize, size == 5816 ? 5920 : size)
                    }
                }
            } else { XCTAssertNil(c.writerInput); XCTAssertFalse(c.sourceFreed); XCTAssertTrue(c.callerHelpers.isEmpty) }

            if c.label == "restore-True-1" || c.label == "stage-0" {
                var trialGlobals = oldGlobals, trialContext = oldContext, reachedDestroy = false
                let missingStage = c.label == "stage-0"
                XCTAssertThrowsError(try OriginalResultRecording.apply(world: world, actors: actors, globals: &trialGlobals,
                    context: &trialContext, stageDefeated: missingStage ? nil : 0, header: { headers[$0] },
                    allocate: { 0x25000000 }, processorSignature: { 0x306c4 }, open: { _ in true },
                    write: { Int32($0.count) }, close: { 0 }, observe: {
                        if case .writer(.streamReturn("destroy", _)) = $0 {
                            reachedDestroy = true; throw OriginalStateError.invalidStorage("Result late observer")
                        }
                    })) { error in
                        guard case OriginalStateError.invalidStorage(let detail) = error else { return XCTFail("Unexpected result failure: \(error)") }
                        XCTAssertEqual(detail, missingStage ? "Result recording: Retained stage result unavailable" : "Result late observer")
                    }
                XCTAssertEqual(reachedDestroy, !missingStage)
                XCTAssertEqual(trialGlobals, oldGlobals); XCTAssertEqual(trialContext.memory.allocations, oldContext.memory.allocations)
                XCTAssertEqual(trialContext.memory.replayPointers, oldContext.memory.replayPointers)
                XCTAssertEqual(trialContext.savedPlayback, oldContext.savedPlayback)
            }
        }
        print("Whole result recording: \(corpus.cases.count) callers, \(writerCalls) writers, \(restores) playback restores, \(writes) writes/\(writtenBytes) bytes")
    }
}
