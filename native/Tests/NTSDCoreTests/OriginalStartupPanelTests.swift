import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalStartupPanelTests: XCTestCase {
    private struct Blob: Decodable { let count: Int,deflate: String }
    private struct Storage: Decodable { let bytes: String,defined: String }
    private struct InfoState: Decodable { let globals: String,globalMask: String,local: String,localMask: String }
    private struct Event: Decodable {
        let kind: String,arguments: [UInt32]?,strings: [[UInt8]]?,format: String?,result: UInt32?
        let before: Int?,position: Int?,eof: Bool?,state: InfoState?,globals: String?,scratch: Storage?,file: String?,buffer: Storage?
    }
    private struct Allocation: Decodable { let address: UInt32,backing: String? }
    private struct Record: Decodable { let address: UInt32,live: Bool,storage: Storage }
    private struct Child: Decodable {
        let kind: String,entry: UInt32,entrySP: UInt32,returnPC: UInt32,beforeGlobals: String,globals: String,events: [Event],completed: Bool,result: UInt32?
        let localState: InfoState?,scratch: Storage?,initialLocalMask: String?,backing: String?
        let allocation: Allocation?,resource: OriginalBitmapInput?,surface: UInt32?,colorKeyResult: Int32?,records: [Record]?
        let file: String?,buffer: Storage?
    }
    private struct Spec: Decodable {
        let label: String,info: [UInt8]?,content: [UInt8]?,chunk: Int,infoReadFailAt: Int,infoClose: Int32,contentClose: Int32
        let capacity: Int,writeOpen: Bool,writeMode: String,writeFailAt: Int,writeClose: Int32
    }
    private struct Boundary: Decodable { let kind: String,child: Int,offset: Int,count: Int,eventCount: Int }
    private struct Step: Decodable {
        let spec: Spec,beforeGlobals: String,globals: String,globalMask: String,events: [OriginalMenuPanelUpdateEvent],children: [Child],ownBoundary: Boundary?
        let end: String,endPC: UInt32,endSP: UInt32,eax: UInt32,records: [Record]
    }
    private struct CaseSpec: Decodable { let label: String,ramp: Bool }
    private struct Case: Decodable { let spec: CaseSpec,initialGlobals: String,steps: [Step] }
    private struct Corpus: Decodable { let exeSHA256: String,dllSHA256: String,cases: [Case],blobs: [String:Blob] }
    private enum Trial: Error { case late }
    private func read() throws -> Corpus {
        let url = try ProcessInfo.processInfo.environment["NTSD_STARTUP_PANEL"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-startup-panel",withExtension:"json",subdirectory:"Fixtures"))
        return try JSONDecoder().decode(Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:200_000_000))
    }
    private func execute(_ item: Step,ramp: Bool,globals: inout OriginalStateRecord,panel: inout OriginalStartupPanel,
        blob: (String) throws -> [UInt8],observe: @escaping (OriginalStartupPanel.Observation) throws -> Void = { _ in },
        written: @escaping (Int,[UInt8]) throws -> Void = { _,_ in },after: @escaping (UInt32,UInt32,OriginalStateRecord,OriginalStartupPanel) throws -> Void = { _,_,_,_ in }) throws -> UInt32 {
        let s = item.spec,b = item.children.first { $0.kind == "bitmap" };var writes = 0
        let backing = (0..<s.capacity).map { ramp ? UInt8(truncatingIfNeeded:$0) : UInt8(0xa5) }
        return try panel.run(globals:&globals,infoBytes:s.info,contentSource:{ path in
            let infoChild = try XCTUnwrap(item.children.first { $0.kind == "content" })
            let bytes = try blob(infoChild.beforeGlobals),offset = 0x44d784-OriginalMatchPreparation.globalBase
            let expectedIndex = Int32(bitPattern:UInt32(bytes[offset]) | UInt32(bytes[offset+1])<<8 | UInt32(bytes[offset+2])<<16 | UInt32(bytes[offset+3])<<24)
            XCTAssertEqual(path,"data\\ad\(expectedIndex).txt");return s.content
        },chunk:s.chunk,infoReadFailAt:s.infoReadFailAt,infoClose:s.infoClose,contentClose:s.contentClose,outputBacking:backing,writeAvailable:s.writeOpen,write:{ bytes in
            defer { writes += 1 }
            if writes != s.writeFailAt { return Int32(bytes.count) }
            switch s.writeMode { case "error":return -1;case "zero":return 0;case "short":return Int32(bytes.count)-1;default:return Int32(bytes.count) }
        },close:{ s.writeClose },allocate:{
            let a = try XCTUnwrap(b?.allocation)
            return try .init(address:a.address,backing:a.backing.map(blob) ?? [])
        },bitmapSource:{ path in let input = try XCTUnwrap(b?.resource);XCTAssertEqual(path,input.path);return input },deviceResult:{ (try XCTUnwrap(b?.surface),try XCTUnwrap(b?.colorKeyResult)) },observe:observe,written:written,afterChild:after)
    }
    func testWholeCallerAndOwnBitmapReplacements() throws {
        let c = try read();var cache: [String:[UInt8]] = [:]
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.dllSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        func blob(_ h: String) throws -> [UInt8] {
            if let b = cache[h] { return b };let p = try XCTUnwrap(c.blobs[h]),b = try MatchPreparationReference.inflate(p.deflate,count:p.count,maximumCount:2_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),h);cache[h] = b;return b
        }
        func globals(_ h: String) throws -> OriginalStateRecord { try .init(bytes:blob(h),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize)) }
        func local(_ actual: OriginalStateRecord,bytes h: String,mask m: String) throws {
            let bytes = try blob(h),mask = try blob(m);XCTAssertEqual(actual.defined,mask.map { $0 == 1 })
            XCTAssertTrue(mask.indices.allSatisfy { mask[$0] == 0 || actual.bytes[$0] == bytes[$0] },"Defined local bytes")
        }
        func records(_ actual: OriginalMenuPanelBitmap,_ expected: [Record]) throws {
            XCTAssertEqual(actual.records.count,expected.count)
            for (a,e) in zip(actual.records,expected) {
                var raw = try blob(e.storage.bytes);let surface = UInt32(raw[0]) | UInt32(raw[1])<<8 | UInt32(raw[2])<<16 | UInt32(raw[3])<<24
                XCTAssertEqual(a.address,e.address);XCTAssertEqual(a.live,e.live);XCTAssertEqual(a.surface,surface)
                raw.replaceSubrange(0..<4,with:[surface == 0 ? 0 : 1,0,0,0]);XCTAssertTrue(a.bitmap.storage.bytes == raw)
                XCTAssertTrue(a.bitmap.storage.defined == (try blob(e.storage.defined).map { $0 == 1 }))
            }
        }
        func target(_ p: UInt32) -> [UInt32] { p >= 0x1000ef44 && p < 0x1000effc ? [1,p-0x1000ef44] : [0,p-0x44d000] }
        var whole = 0,rejected = 0,childCount = 0,eventCount = 0
        for item in c.cases {
            var state = try globals(item.initialGlobals),engine = OriginalStartupPanel()
            for step in item.steps {
                XCTAssertTrue(state.bytes == (try blob(step.beforeGlobals)))
                let before = state,prior = engine
                var parentIndex = 0,childIndex = -1,cursor = 0,mask = [UInt8](repeating:0,count:state.bytes.count)
                func event(_ kind: String,_ args: [UInt32],_ strings: [[UInt8]],_ format: String?,_ value: UInt32?,
                    state: OriginalStateRecord? = nil,scratch: OriginalStateRecord? = nil,stream: OriginalBufferedTextOutput? = nil,
                    before: Int? = nil,position: Int? = nil,eof: Bool? = nil) throws {
                    let child = step.children[childIndex]
                    guard cursor < child.events.count else { XCTFail("Excess child event");throw Trial.late }
                    let e = child.events[cursor];cursor += 1;eventCount += 1
                    let expectedArgs = kind == "scan" && child.kind == "info" ? (e.arguments ?? []).flatMap(target) : (e.arguments ?? [])
                    XCTAssertEqual(kind,e.kind,item.spec.label);XCTAssertEqual(args,expectedArgs,item.spec.label);XCTAssertEqual(strings,e.strings ?? [],item.spec.label)
                    XCTAssertEqual(format,e.format);XCTAssertEqual(value,e.result,item.spec.label);XCTAssertEqual(before,e.before);XCTAssertEqual(position,e.position);XCTAssertEqual(eof,e.eof)
                    if let s = e.state { XCTAssertTrue(try XCTUnwrap(state).bytes == blob(s.globals));try local(XCTUnwrap(scratch),bytes:s.local,mask:s.localMask) }
                    if let h = e.globals { XCTAssertTrue(try XCTUnwrap(state).bytes == blob(h)) }
                    if let s = e.scratch { try local(XCTUnwrap(scratch),bytes:s.bytes,mask:s.defined) }
                    if let h = e.file { XCTAssertTrue(try XCTUnwrap(stream).fileStorage().bytes == blob(h)) }
                    if let s = e.buffer { let output = try XCTUnwrap(stream);XCTAssertTrue(output.buffer.bytes == (try blob(s.bytes)));XCTAssertTrue(output.buffer.defined == (try blob(s.defined).map { $0 == 1 })) }
                }
                do {
                    let result = try execute(step,ramp:item.spec.ramp,globals:&state,panel:&engine,blob:blob,observe:{ observation in
                        switch observation {
                        case let .caller(e,s):
                            XCTAssertEqual(e,step.events[parentIndex]);parentIndex += 1
                            if e.kind == "call" { childIndex += 1;cursor = 0;XCTAssertTrue(s.bytes == (try blob(step.children[childIndex].beforeGlobals))) }
                            else { XCTAssertEqual(cursor,step.children[childIndex].events.count);XCTAssertTrue(s.bytes == (try blob(step.children[childIndex].globals))) }
                        case let .info(e,s,l):try event(e.kind,e.arguments,e.strings,e.format,e.result,state:s,scratch:l)
                        case let .content(e,s,l):try event(e.kind,e.arguments,e.strings,e.format,e.result,state:s,scratch:l,before:e.before,position:e.position,eof:e.eof)
                        case let .bitmap(e):try event(e.kind,e.arguments,e.strings,nil,nil)
                        case let .writer(e,s,o):try event(e.kind,e.arguments,e.strings,e.format,e.result,state:s,stream:o)
                        }
                    },written:{ address,bytes in for i in bytes.indices { mask[address-OriginalMatchPreparation.globalBase+i] = 1 } },after:{ entry,value,s,engine in
                        let child = step.children[childIndex];XCTAssertEqual(entry,child.entry);XCTAssertEqual(value,child.result);XCTAssertTrue(s.bytes == (try blob(child.globals)));childCount += 1
                        if let info = child.localState { try local(XCTUnwrap(engine.infoLocal),bytes:info.local,mask:info.localMask) }
                        if let content = child.scratch { try local(XCTUnwrap(engine.contentLocal),bytes:content.bytes,mask:content.defined) }
                        if let expected = child.records { try records(engine.panel,expected) }
                    })
                    XCTAssertNil(step.ownBoundary);XCTAssertEqual(result,step.eax);XCTAssertEqual(step.end,"returned");XCTAssertEqual(step.endPC,0x43cfb4);XCTAssertEqual(step.endSP,0x1000f004)
                    XCTAssertEqual(parentIndex,step.events.count);XCTAssertEqual(childIndex+1,step.children.count)
                    XCTAssertTrue(state.bytes == (try blob(step.globals)));XCTAssertTrue(mask == (try blob(step.globalMask)));try records(engine.panel,step.records);whole += 1
                } catch OriginalStateError.undefinedBytes(let offset,let count) {
                    let b = try XCTUnwrap(step.ownBoundary);XCTAssertEqual(childIndex,b.child);XCTAssertEqual(offset,b.offset);XCTAssertEqual(count,b.count);XCTAssertEqual(cursor,b.eventCount)
                    XCTAssertEqual(state,before);XCTAssertEqual(engine.infoLocal,prior.infoLocal);XCTAssertEqual(engine.contentLocal,prior.contentLocal)
                    XCTAssertEqual(engine.panel.records.count,prior.panel.records.count);rejected += 1
                }
            }
        }
        XCTAssertEqual(c.cases.count,188);XCTAssertEqual(whole,212);XCTAssertEqual(rejected,8)
        print("StartupPanel:",whole,"whole callers",rejected,"unknown-local rejections",childCount,"child returns",eventCount,"child events")
    }
    func testLateWholeCallerRollbackAfterReplacementAndDefaults() throws {
        let c = try read(),item = try XCTUnwrap(c.cases.first { $0.spec.label == "own-replace-live-missing-a5" })
        func blob(_ h: String) throws -> [UInt8] { let p = try XCTUnwrap(c.blobs[h]);return try MatchPreparationReference.inflate(p.deflate,count:p.count,maximumCount:2_000_000) }
        for entry: UInt32 in [0x43cc60,0x43c690] {
            var globals = try OriginalStateRecord(bytes:blob(item.initialGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize)),engine = OriginalStartupPanel()
            _ = try execute(item.steps[0],ramp:false,globals:&globals,panel:&engine,blob:blob)
            let before = globals,prior = engine;var reached = false
            XCTAssertThrowsError(try execute(item.steps[1],ramp:false,globals:&globals,panel:&engine,blob:blob,after:{ e,_,_,_ in if e == entry { reached = true;throw Trial.late } })) { XCTAssertTrue($0 is Trial) }
            XCTAssertTrue(reached);XCTAssertEqual(globals,before);XCTAssertEqual(engine.infoLocal,prior.infoLocal);XCTAssertEqual(engine.contentLocal,prior.contentLocal);XCTAssertNil(engine.output)
            XCTAssertEqual(engine.panel.records.count,prior.panel.records.count)
            for (a,b) in zip(engine.panel.records,prior.panel.records) { XCTAssertEqual(a.live,b.live);XCTAssertEqual(a.surface,b.surface);XCTAssertEqual(a.address,b.address);XCTAssertEqual(a.bitmap,b.bitmap) }
        }
    }
}
