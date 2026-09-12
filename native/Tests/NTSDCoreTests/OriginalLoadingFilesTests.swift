import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Complete first DAT file child and separate Object file lifecycle against
/// immutable same-CPU probe8 file projection. Its original file-event ordinals
/// and all required file bytes are retained. The lifecycle filters parser events;
/// it does not claim their interleaving or private CRT FILE/stack equivalence.
final class OriginalLoadingFilesTests: XCTestCase {
    struct Blob: Decodable { let count: Int, deflate: String }
    struct File: Decodable { let address: UInt32,buffer: UInt32,path: String,mode: String,raw: String,logical: String,read: Int,closed: Bool }
    struct Call: Decodable { let eventStart: Int,eventEnd: Int,path: String,result: UInt32 }
    struct Event: Decodable { let kind: String?,arguments: [UInt32]?,path: String?,mode: String?,bytes: String?,result: Int32? }
    struct IndexedEvent: Decodable { let ordinal: Int, event: Event }
    struct CloseResponse: Decodable {
        let kind: String, file: UInt32, path: String, result: Int32, errnoChangedByResponse: Bool
    }
    struct Case: Decodable {
        let files: [File], decoders: [Call], fileEvents: [IndexedEvent], virtualFiles: [String:String]
        let sourceEventCount: Int
        let closeResponses: [CloseResponse]?
    }
    struct Corpus: Decodable {
        let c: Case,blobs: [String:Blob]
        enum CodingKeys: String,CodingKey { case c = "case",blobs }
    }
    enum Stop: Error { case late }
    final class Reference {
        let c: Case,blobs: [String:Blob]
        var cache: [String:[UInt8]] = [:],files = 1,eventIndex = 0,expected: [Event] = []
        init(negativeClose: Bool = false) throws {
            let data: Data
            if negativeClose {
                data = try OriginalLoadingFilesFixture.data("original-loading-files-negative-close", expectedCount: 699375,
                    expectedSHA256: "c53022ae08b279d4bea58e5cae1fb1c1dd696795f6e195f31d8751315ead9858")
            } else {
                data = try OriginalLoadingFilesFixture.data("original-loading-files-first-object", expectedCount: 698562,
                    expectedSHA256: "7f7873e9ae3a797e445e8030d475b72cd9b278931bb9688b225efe2732f8fbd9")
            }
            let d = try JSONDecoder().decode(Corpus.self, from: data)
            c = d.c; blobs = d.blobs
            XCTAssertEqual(c.sourceEventCount, 2065)
            XCTAssertEqual(c.fileEvents.count, 51)
        }
        func blob(_ h: String) throws -> [UInt8] {
            if let b = cache[h] { return b }
            let z = try XCTUnwrap(blobs[h]),b = try MatchPreparationReference.inflate(z.deflate,count:z.count,maximumCount:100_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),h);cache[h] = b;return b
        }
        func source(_ path: String) throws -> [UInt8] {
            // Original source asset only: temporary content must come from the
            // native writer, never the captured expected temporary file.
            XCTAssertEqual(path,"chars\\pein.dat")
            return try blob(XCTUnwrap(c.files.first { $0.path == path && $0.mode == "r" }).raw)
        }
        func allocate(_ path: String,_ mode: String) throws -> OriginalLoadingFileAllocation {
            guard c.files.indices.contains(files) else { throw OriginalStateError.invalidStorage("Extra native file allocation") }
            let f = c.files[files];files += 1
            XCTAssertEqual(path,f.path);XCTAssertEqual(mode,f.mode)
            let closeResult: Int32
            if let responses = c.closeResponses {
                // Bind the independently captured declared API response, not
                // the Native event or the decoder's expected return value.
                let matches = responses.filter { $0.file == f.address }
                XCTAssertEqual(matches.count, 1)
                let response = try XCTUnwrap(matches.first)
                XCTAssertEqual(response.path, path)
                XCTAssertEqual(response.kind, mode == "r" ? "readFileClose" : "outputDescriptorClose")
                closeResult = response.result
            } else { closeResult = 0 }
            return .init(token:f.address,buffer:f.buffer,descriptor:UInt32.max,capacity:65536,readLimit:4096,
                         closeResult:closeResult)
        }
        func event(_ e: OriginalLoadingFileEvent) throws {
            guard eventIndex<expected.count else { throw OriginalStateError.invalidStorage("Extra native file request") }
            let q = expected[eventIndex];eventIndex += 1
            XCTAssertEqual(e.kind.rawValue,q.kind);XCTAssertEqual(e.arguments,q.arguments)
            XCTAssertEqual(e.path,q.path);XCTAssertEqual(e.mode,q.mode)
            if e.kind == .closeReadFile || e.kind == .closeOutputDescriptor { XCTAssertEqual(e.result,q.result ?? 0) } else { XCTAssertNil(e.result) }
            XCTAssertEqual(e.bytes == nil,q.bytes == nil)
            if let b = e.bytes,let hex = q.bytes { XCTAssertEqual(b.map { String(format:"%02x",$0) }.joined(),hex) }
        }
        func select(_ sourceOrdinals: Range<Int>) {
            // Keep the original event ordinals; this projection does not claim
            // comparison of intervening parser, progress, WAV or output events.
            expected = c.fileEvents.filter { sourceOrdinals.contains($0.ordinal) }.map(\.event)
            eventIndex = 0
        }
        func check(_ files: OriginalLoadingFiles,_ ordinals: Range<Int>) throws {
            XCTAssertEqual(eventIndex,expected.count)
            XCTAssertEqual(files.order,ordinals.map { c.files[$0].address })
            for ordinal in ordinals {
                let f = c.files[ordinal],s = try XCTUnwrap(files.streams[f.address])
                XCTAssertEqual(s.path,f.path);XCTAssertEqual(s.mode,f.mode);XCTAssertEqual(s.closed,f.closed)
                XCTAssertTrue(s.pending.isEmpty)
                if f.mode == "r" {
                    XCTAssertEqual(s.raw,try blob(f.raw));XCTAssertEqual(s.input,try blob(f.logical))
                    XCTAssertEqual(s.position,s.input.count);XCTAssertEqual(s.loaded,f.read);XCTAssertTrue(s.eof)
                } else { XCTAssertEqual(s.output,try blob(f.logical)) }
            }
        }
    }
    func testWholeFirstDATFileRequestsAndLateRollback() throws {
        let r = try Reference(),call = try XCTUnwrap(r.c.decoders.first)
        r.select(call.eventStart..<call.eventEnd)
        var files = OriginalLoadingFiles(translation:.text)
        let output = try files.decodeDAT(call.path,source:r.source,allocate:r.allocate,observe:r.event)
        try r.check(files,1..<3)
        XCTAssertEqual(files.decoderReturns,[Int32(bitPattern:call.result)])
        XCTAssertEqual(r.expected.count,25)
        let raw = try XCTUnwrap(files.files[OriginalLoadingFiles.temporaryPath])
        XCTAssertEqual(raw,try r.blob(r.c.files[2].raw));XCTAssertEqual(raw.count,74271)
        XCTAssertEqual(files.streams[output]?.output.count,72102)
        XCTAssertEqual(try OriginalDATDecoder.decode(r.source(call.path),fileName:call.path,translation:.text).unicodeScalars.map { UInt8($0.value) },files.streams[output]?.output)
        // A late close error must retain an already owned previous file session.
        let prior = files
        var allocations = 0,writes = 0,closedInput = false
        XCTAssertThrowsError(try files.decodeDAT(call.path,source:r.source,allocate:{ _,_ in
            defer { allocations += 1 }
            let token: UInt32 = 0x58000000+UInt32(allocations)*0x20000
            return .init(token:token,buffer:token+0x1000,descriptor:UInt32.max,capacity:65536,readLimit:4096)
        },observe:{ event in
            if event.kind == .writeFile { writes += 1 }
            if event.kind == .closeReadFile { closedInput = true }
            if event.kind == .closeOutputDescriptor { XCTAssertTrue(closedInput);XCTAssertEqual(writes,2);throw Stop.late }
        })) { error in guard case Stop.late = error else { return XCTFail("Unexpected rollback error: \(error)") } }
        XCTAssertEqual(files,prior)
        print("First complete DAT child:25 ordered file requests,19 translated reads including EOF,65536+6566 logical output bytes,74271 produced temporary bytes and late rollback. Private CRT ABI/Windows remain open.")
    }
    func testObjectFileLifecycleAndCleanupRollback() throws {
        let r = try Reference(),call = try XCTUnwrap(r.c.decoders.first)
        r.select(call.eventStart..<r.c.sourceEventCount)
        var files = OriginalLoadingFiles(translation:.text)
        let input = try files.openObject(call.path,source:r.source,allocate:r.allocate,observe:r.event)
        var parsed: [UInt8] = []
        while let b = try files.character(input,observe:r.event) { parsed.append(b) }
        XCTAssertEqual(parsed,try r.blob(r.c.files[3].logical))
        let beforeCleanup = files
        try files.finishObject(input,source:r.source,allocate:r.allocate,observe:r.event)
        try r.check(files,1..<5)
        XCTAssertEqual(r.expected.count,49)
        XCTAssertEqual(files.files[OriginalLoadingFiles.temporaryPath],Array("Do not erase this file.".utf8))
        XCTAssertEqual(files.files[OriginalLoadingFiles.temporaryPath],try r.blob(XCTUnwrap(r.c.virtualFiles[OriginalLoadingFiles.temporaryPath])))
        var trial = beforeCleanup,written = 0
        XCTAssertThrowsError(try trial.finishObject(input,source:r.source,allocate:{ _,_ in
            .init(token:0x58000000,buffer:0x58001000,descriptor:UInt32.max,capacity:65536,readLimit:4096)
        },observe:{ event in
            if event.kind == .writeFile { written += 1;XCTAssertEqual(event.bytes,Array("Do not erase this file.".utf8)) }
            if event.kind == .closeOutputDescriptor { throw Stop.late }
        })) { error in guard case Stop.late = error else { return XCTFail("Unexpected cleanup rollback error: \(error)") } }
        XCTAssertEqual(written,1);XCTAssertEqual(trial,beforeCleanup)
        print("Object file-only lifecycle:49 ordered requests,all raw/logical file bytes and23-byte cleanup write; late cleanup failure preserves prior files/stream ownership. Parser/output interleaving remains open.")
    }
    func testObjectFileTransactionDropsDecodeOnLateCleanup() throws {
        let r = try Reference(),call = try XCTUnwrap(r.c.decoders.first)
        r.select(call.eventStart..<r.c.sourceEventCount)
        var files = OriginalLoadingFiles(translation:.text)
        let prior = files
        var consumed = 0,writes = 0,closes = 0
        XCTAssertThrowsError(try files.withObject(call.path,source:r.source,allocate:r.allocate,observe:{ e in
            try r.event(e)
            if e.kind == .writeFile { writes += 1 }
            if e.kind == .closeOutputDescriptor { closes += 1;if closes == 2 { throw Stop.late } }
        }) { text,read in
            consumed = text.unicodeScalars.count
            try read(consumed)
            return consumed
        }) { error in guard case Stop.late = error else { return XCTFail("Unexpected full file rollback error: \(error)") } }
        XCTAssertEqual(consumed,72102);XCTAssertEqual(writes,3);XCTAssertEqual(closes,2)
        XCTAssertEqual(r.eventIndex,49);XCTAssertEqual(files,prior)
        print("Whole Object file transaction: late second descriptor-close observer rejects after all49 file events and rolls back the preceding DAT output as well as cleanup.")
    }
    func testDeclaredNegativeClosesRetainObjectFileBytesAndOrder() throws {
        let r = try Reference(negativeClose: true), nominal = try Reference()
        let call = try XCTUnwrap(r.c.decoders.first)
        let responses = try XCTUnwrap(r.c.closeResponses)
        XCTAssertEqual(responses.count, 4)
        XCTAssertEqual(responses.map(\.result), Array(repeating: -1, count: 4))
        XCTAssertTrue(responses.allSatisfy { !$0.errnoChangedByResponse })
        XCTAssertEqual(call.result, UInt32.max)

        // The control changes four declared close responses. Its file bytes
        // and the remaining ordered file requests still equal nominal probe8.
        XCTAssertEqual(r.c.files.count, nominal.c.files.count)
        for (actual, prior) in zip(r.c.files, nominal.c.files) {
            XCTAssertEqual(actual.address, prior.address); XCTAssertEqual(actual.buffer, prior.buffer)
            XCTAssertEqual(actual.path, prior.path); XCTAssertEqual(actual.mode, prior.mode)
            XCTAssertEqual(actual.raw, prior.raw); XCTAssertEqual(actual.logical, prior.logical)
            XCTAssertEqual(actual.read, prior.read); XCTAssertEqual(actual.closed, prior.closed)
        }
        XCTAssertEqual(r.c.fileEvents.count, nominal.c.fileEvents.count)
        for (actual, prior) in zip(r.c.fileEvents, nominal.c.fileEvents) {
            XCTAssertEqual(actual.ordinal, prior.ordinal)
            XCTAssertEqual(actual.event.kind, prior.event.kind)
            XCTAssertEqual(actual.event.arguments, prior.event.arguments)
            XCTAssertEqual(actual.event.path, prior.event.path); XCTAssertEqual(actual.event.mode, prior.event.mode)
            XCTAssertEqual(actual.event.bytes, prior.event.bytes)
        }

        r.select(call.eventStart..<r.c.sourceEventCount)
        var files = OriginalLoadingFiles(translation: .text), closeResults: [Int32] = []
        func observe(_ event: OriginalLoadingFileEvent) throws {
            try r.event(event)
            if event.kind == .closeReadFile || event.kind == .closeOutputDescriptor {
                closeResults.append(try XCTUnwrap(event.result))
            }
        }
        let input = try files.openObject(call.path, source: r.source, allocate: r.allocate, observe: observe)
        var parsed: [UInt8] = []
        while let byte = try files.character(input, observe: observe) { parsed.append(byte) }
        XCTAssertEqual(parsed, try r.blob(r.c.files[3].logical))
        try files.finishObject(input, source: r.source, allocate: r.allocate, observe: observe)
        try r.check(files, 1..<5)
        XCTAssertEqual(r.expected.count, 49)
        XCTAssertEqual(closeResults, responses.map(\.result))
        XCTAssertEqual(files.decoderReturns, [Int32(bitPattern: call.result)])
        XCTAssertEqual(files.files[OriginalLoadingFiles.temporaryPath],
                       try r.blob(XCTUnwrap(r.c.virtualFiles[OriginalLoadingFiles.temporaryPath])))
    }
}
