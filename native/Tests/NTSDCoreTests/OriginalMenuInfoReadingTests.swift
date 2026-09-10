import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalMenuInfoReadingTests: XCTestCase {
    private struct Blob: Decodable { let count: Int,deflate: String }
    private struct State: Decodable { let globals: String,globalMask: String,local: String,localMask: String }
    private struct Event: Decodable { let kind: String,arguments: [UInt32],strings: [[UInt8]]?,format: String?,result: UInt32?,state: State }
    private struct Store: Decodable { let region: Int,offset: Int,bytes: String,pc: UInt32,eventIndex: Int }
    private struct Spec: Decodable { let label: String,input: [UInt8]?,chunk: Int,readFailAt: Int,close: Int32 }
    private struct Boundary: Decodable { let offset: Int,count: Int,eventCount: Int,storeCount: Int }
    private struct Case: Decodable { let spec: Spec,before: State,after: State,events: [Event],stores: [Store],unknown: Boundary?,result: UInt32 }
    private struct Corpus: Decodable { let exeSHA256: String,dllSHA256: String,cases: [Case],blobs: [String:Blob] }
    private enum Trial: Error { case late }
    private func read() throws -> Corpus {
        let url = try ProcessInfo.processInfo.environment["NTSD_MENU_INFO_READING"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-menu-info-reading",withExtension:"json",subdirectory:"Fixtures"))
        return try JSONDecoder().decode(Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:url)))
    }
    func testWholeStartupInfoReader() throws {
        let c = try read();var cache: [String:[UInt8]] = [:]
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.dllSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        func blob(_ h: String) throws -> [UInt8] {
            if let b = cache[h] { return b };let p = try XCTUnwrap(c.blobs[h]),b = try MatchPreparationReference.inflate(p.deflate,count:p.count)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),h);cache[h] = b;return b
        }
        func target(_ p: UInt32) -> [UInt32] {
            if p >= 0x1000ef44 && p < 0x1000effc { return [1,p-0x1000ef44] }
            return [0,p-0x44d000]
        }
        var whole = 0,rejected = 0,events = 0
        for item in c.cases {
            var globals = try OriginalStateRecord(bytes:blob(item.before.globals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
            // Native owns unknown backing; no original local byte is imported.
            var local = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:184),defined:[Bool](repeating:false,count:184))
            let before = globals,localBefore = local
            var cursor = 0,stores: [(Int,Int,String,Int)] = [],masks = [[UInt8](repeating:0,count:globals.bytes.count),[UInt8](repeating:0,count:184)]
            func check(_ state: OriginalStateRecord,_ scratch: OriginalStateRecord,_ expected: State) throws {
                XCTAssertTrue(state.bytes == (try blob(expected.globals)),item.spec.label+" globals \(cursor)")
                let bytes = try blob(expected.local),mask = try blob(expected.localMask)
                XCTAssertTrue(scratch.defined == mask.map { $0 == 1 },item.spec.label+" local mask \(cursor)")
                XCTAssertTrue(mask.indices.allSatisfy { mask[$0] == 0 || scratch.bytes[$0] == bytes[$0] },item.spec.label+" defined local \(cursor)")
                XCTAssertTrue(masks[0] == (try blob(expected.globalMask)),item.spec.label+" global write mask")
                XCTAssertEqual(masks[1],mask,item.spec.label+" local write mask")
            }
            do {
                let result = try OriginalMenuInfoReading.load(globals:&globals,local:&local,translatedBytes:item.spec.input,chunk:item.spec.chunk,readFailAt:item.spec.readFailAt,closeResult:item.spec.close,
                    store:{ r,o,b in stores.append((r,o,b.map { String(format:"%02x",$0) }.joined(),cursor)) },
                    written:{ r,o,b in for i in b.indices { masks[r][o+i] = 1 } },observe:{ actual,state,scratch in
                        guard cursor < item.events.count else { XCTFail("Extra reader event");throw Trial.late }
                        let expected = item.events[cursor];XCTAssertEqual(actual.kind,expected.kind);XCTAssertEqual(actual.format,expected.format);XCTAssertEqual(actual.result,expected.result,item.spec.label)
                        let args = expected.kind == "scan" ? expected.arguments.flatMap(target) : expected.arguments
                        XCTAssertEqual(actual.arguments,args,item.spec.label);XCTAssertEqual(actual.strings,expected.strings ?? [],item.spec.label)
                        try check(state,scratch,expected.state);cursor += 1
                    })
                XCTAssertNil(item.unknown);XCTAssertEqual(result,item.result,item.spec.label);try check(globals,local,item.after);whole += 1
            } catch OriginalStateError.undefinedBytes(let offset,let count) {
                let boundary = try XCTUnwrap(item.unknown);XCTAssertEqual(offset,boundary.offset);XCTAssertEqual(count,boundary.count)
                XCTAssertEqual(globals,before);XCTAssertEqual(local,localBefore);rejected += 1
            }
            let expected = item.stores.prefix(item.unknown?.storeCount ?? item.stores.count).filter { $0.pc >= 0x43c4a0 && $0.pc <= 0x43c685 }
            XCTAssertEqual(stores.count,expected.count,item.spec.label)
            for (a,e) in zip(stores,expected) { XCTAssertEqual(a.0,e.region);XCTAssertEqual(a.1,e.offset);XCTAssertEqual(a.2,e.bytes);XCTAssertEqual(a.3,e.eventIndex) }
            XCTAssertEqual(cursor,item.unknown?.eventCount ?? item.events.count);events += cursor
        }
        XCTAssertEqual(whole,194);XCTAssertEqual(rejected,2)
        print("MenuInfoReading:",whole,"whole calls",rejected,"unknown-local rejections",events,"ordered events")
    }
    func testLateReaderRollback() throws {
        let c = try read(),item = try XCTUnwrap(c.cases.first { $0.result == 1 })
        let p = try XCTUnwrap(c.blobs[item.before.globals])
        var globals = try OriginalStateRecord(bytes:MatchPreparationReference.inflate(p.deflate,count:p.count),defined:[Bool](repeating:true,count:p.count))
        var local = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:184),defined:[Bool](repeating:false,count:184))
        let before = globals,localBefore = local;var formats = 0
        XCTAssertThrowsError(try OriginalMenuInfoReading.load(globals:&globals,local:&local,translatedBytes:item.spec.input,observe:{ e,_,_ in
            if e.kind == "format" { formats += 1;if formats == 2 { throw Trial.late } }
        })) { XCTAssertTrue($0 is Trial) }
        XCTAssertEqual(formats,2);XCTAssertEqual(globals,before);XCTAssertEqual(local,localBefore)
    }
    private struct Buffer: Decodable { let bytes: String,defined: String }
    private struct WriterEvent: Decodable {
        let kind: String,arguments: [UInt32],strings: [[UInt8]],format: String?,result: UInt32?
        let globals: String?,file: String?,buffer: Buffer?
    }
    private struct Writer: Decodable {
        let capacity: Int,backing: String,writeMode: String,failAt: Int,closeResult: Int32
        let events: [WriterEvent],result: UInt32,globals: String,file: String,buffer: Buffer
    }
    private struct Chain: Decodable { let label: String,first: Case,writer: Writer,emitted: [UInt8],second: Case }
    private struct Chains: Decodable { let cases: [Chain],blobs: [String:Blob] }
    func testOwnReadWriteReadComposition() throws {
        let url = try ProcessInfo.processInfo.environment["NTSD_MENU_INFO_ROUNDTRIP"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-menu-info-roundtrip",withExtension:"json",subdirectory:"Fixtures"))
        let c = try JSONDecoder().decode(Chains.self,from:MatchPreparationReference.unpack(Data(contentsOf:url)))
        var cache: [String:[UInt8]] = [:]
        func blob(_ h: String) throws -> [UInt8] {
            if let b = cache[h] { return b };let p = try XCTUnwrap(c.blobs[h]),b = try MatchPreparationReference.inflate(p.deflate,count:p.count)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),h);cache[h] = b;return b
        }
        func checkLocal(_ actual: OriginalStateRecord,_ expected: State) throws {
            let bytes = try blob(expected.local),mask = try blob(expected.localMask)
            XCTAssertEqual(actual.defined,mask.map { $0 == 1 })
            XCTAssertTrue(mask.indices.allSatisfy { mask[$0] == 0 || actual.bytes[$0] == bytes[$0] })
        }
        func reader(_ item: Case,_ input: [UInt8]?,_ globals: inout OriginalStateRecord) throws {
            XCTAssertTrue(globals.bytes == (try blob(item.before.globals)))
            var local = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:184),defined:[Bool](repeating:false,count:184)),cursor = 0
            let result = try OriginalMenuInfoReading.load(globals:&globals,local:&local,translatedBytes:input,chunk:item.spec.chunk,readFailAt:item.spec.readFailAt,closeResult:item.spec.close,observe:{ event,state,scratch in
                let e = item.events[cursor];cursor += 1
                XCTAssertEqual(event.kind,e.kind);XCTAssertEqual(event.result,e.result);XCTAssertEqual(event.format,e.format)
                XCTAssertTrue(state.bytes == (try blob(e.state.globals)));try checkLocal(scratch,e.state)
            })
            XCTAssertEqual(result,item.result);XCTAssertEqual(cursor,item.events.count)
            XCTAssertTrue(globals.bytes == (try blob(item.after.globals)));try checkLocal(local,item.after)
        }
        var totalWrites = 0,totalBytes = 0
        for chain in c.cases {
            var globals = try OriginalStateRecord(bytes:blob(chain.first.before.globals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
            try reader(chain.first,chain.first.spec.input,&globals)
            let w = chain.writer;var output = try OriginalBufferedTextOutput(backing:blob(w.backing)),cursor = 0,writeIndex = 0,emitted: [UInt8] = []
            func buffer(_ actual: OriginalStateRecord,_ expected: Buffer) throws {
                XCTAssertTrue(actual.bytes == (try blob(expected.bytes)));XCTAssertTrue(actual.defined == (try blob(expected.defined).map { $0 == 1 }))
            }
            let returned = try OriginalMenuInfoWriting.run(.cache,globals:&globals,output:&output,available:true,write:{ bytes in
                let returned: Int32 = writeIndex == w.failAt ? (w.writeMode == "error" ? -1 : Int32(bytes.count)-1) : Int32(bytes.count)
                writeIndex += 1;if returned > 0 { emitted += bytes.prefix(Int(returned)) };return returned
            },close:{ w.closeResult },observe:{ event,state,stream in
                let e = w.events[cursor];cursor += 1
                XCTAssertEqual(event.kind,e.kind);XCTAssertEqual(event.arguments,e.arguments);XCTAssertEqual(event.strings,e.strings);XCTAssertEqual(event.format,e.format);XCTAssertEqual(event.result,e.result)
                if let h = e.globals { XCTAssertTrue(state.bytes == (try blob(h))) }
                if let h = e.file { XCTAssertTrue(try stream.fileStorage().bytes == blob(h)) }
                if let b = e.buffer { try buffer(stream.buffer,b) }
            })
            XCTAssertEqual(returned,w.result);XCTAssertEqual(cursor,w.events.count);XCTAssertEqual(emitted,chain.emitted)
            XCTAssertTrue(globals.bytes == (try blob(w.globals)));XCTAssertTrue(try output.fileStorage().bytes == blob(w.file));try buffer(output.buffer,w.buffer)
            // The next input consists only of bytes accepted from this native
            // writer's own requests, including its partial/error continuation.
            try reader(chain.second,emitted,&globals);totalWrites += writeIndex;totalBytes += emitted.count
        }
        XCTAssertEqual(c.cases.count,16)
        print("MenuInfoReading own chains:",c.cases.count,"read/write/read",totalWrites,"descriptor requests",totalBytes,"accepted bytes")
    }

}
