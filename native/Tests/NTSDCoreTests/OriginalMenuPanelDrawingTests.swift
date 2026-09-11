import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalMenuPanelDrawingTests: XCTestCase {
    struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    struct Storage: Decodable { let bytes: String, defined: String }
    struct Record: Decodable { let address: UInt32, storage: Storage, live: Bool? }
    struct Spec: Decodable {
        let label: String, control: Bool, retained: Bool?, nullSurface: Bool?, chain: Bool?
        let previousAddress: UInt32?, target: UInt32?, milliseconds: UInt32?, methodResult: Int32?
        let globals: [String:Int32], strings: [String:String]
    }
    struct Case: Decodable {
        let spec: Spec, before: [Record], after: [Record], events: [OriginalFrontScreenEvent]
        let end: String, endPC: UInt32, endSP: UInt32, cw: UInt32
    }
    struct Corpus: Decodable { let exeSHA256: String, libSHA256: String, cases: [Case], blobs: [String:Blob], entrySP: UInt32 }
    enum Stop: Error { case injected, mismatch }
    final class Resources {
        let corpus: Corpus
        var decoded: [String:[UInt8]] = [:]
        init() throws {
            let url=try ProcessInfo.processInfo.environment["NTSD_MENU_PANEL_DRAW"].map { URL(fileURLWithPath:$0) }
                ?? XCTUnwrap(Bundle.module.url(forResource:"original-menu-panel-draw",withExtension:"json",subdirectory:"Fixtures"))
            corpus=try JSONDecoder().decode(Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:300_000_000))
            XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
            XCTAssertEqual(corpus.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
            XCTAssertEqual(corpus.cases.count,1012);XCTAssertEqual(corpus.entrySP,0x1000f000)
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let value=decoded[key] { return value }
            let b=try XCTUnwrap(corpus.blobs[key]);XCTAssertEqual(b.sha256,key)
            let value=try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:100_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(value)),key);decoded[key]=value;return value
        }
        func record(_ r: Record) throws -> OriginalStateRecord {
            let value=try blob(r.storage.bytes),mask=try blob(r.storage.defined)
            XCTAssertEqual(value.count,mask.count);XCTAssertTrue(mask.allSatisfy { $0<2 })
            return try .init(bytes:value,defined:mask.map { $0 != 0 })
        }
    }
    func check(_ value: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
        if value != expected {
            let i=try XCTUnwrap(value.bytes.indices.first { value.bytes[$0] != expected.bytes[$0] || value.defined[$0] != expected.defined[$0] })
            XCTFail("\(label)+\(String(i,radix:16)): \(value.bytes[i])/\(value.defined[i]) expected \(expected.bytes[i])/\(expected.defined[i])")
            throw Stop.mismatch
        }
    }
    func run(_ item: Case,_ r: Resources,_ retained: inout OriginalStateRecord?,failure: String? = nil) throws {
        let base=OriginalMatchPreparation.globalBase
        let before=try Dictionary(uniqueKeysWithValues:item.before.map { ($0.address,try r.record($0)) })
        let after=try Dictionary(uniqueKeysWithValues:item.after.map { ($0.address,try r.record($0)) })
        var state:OriginalStateRecord
        if item.spec.retained == true {
            state=try XCTUnwrap(retained)
            for (p,v) in item.spec.globals { try state.write(v,at:try XCTUnwrap(Int(p))-base) }
            for (p,s) in item.spec.strings {
                for (i,b) in (Array(s.utf8)+[0]).enumerated() { try state.write(b,at:try XCTUnwrap(Int(p))-base+i) }
            }
            try check(state,try XCTUnwrap(before[UInt32(base)]),item.spec.label+" own retained input")
        } else { state=try XCTUnwrap(before[UInt32(base)]) }
        let original=state;var index=0,fills=0,blits=0,shells=0,buffer:[OriginalFrontScreenEvent]=[],committed:[OriginalFrontScreenEvent]=[]
        func event(_ e: OriginalFrontScreenEvent) throws {
            guard index<item.events.count else { XCTFail("Unexpected panel event \(e)");throw Stop.mismatch }
            let expected=item.events[index]
            if e.kind == "fill" {
                let a=try XCTUnwrap(e.fill),b=try XCTUnwrap(expected.fill)
                XCTAssertEqual(a.target,b.target);XCTAssertEqual(a.rectangle,b.rectangle);XCTAssertEqual(a.flags,b.flags);XCTAssertEqual(a.defined,b.defined)
                for i in a.effects.indices { XCTAssertEqual(a.effects[i],a.defined[i] ? b.effects[i] : 0) }
                fills += 1
            } else if e != expected { XCTFail("\(item.spec.label) event\(index): \(e), expected \(expected)");throw Stop.mismatch }
            index += 1;buffer.append(e)
            if e.kind == "blit" { blits += 1 };if e.kind == "shell" { shells += 1 }
            if failure == "timer" && e.kind == "timer" || failure == "fill" && fills == 4 || failure == "sound" && e.kind == "soundMethod" || failure == "shell" && shells == 1 || failure == "finalDraw" && e.kind == "blit" && index == item.events.count { throw Stop.injected }
        }
        do {
            let result=try OriginalMenuPanelDrawing.draw(globals:&state,target:item.spec.target ?? 0x26006000,
                previous:{ try $0.integer(at:Int(item.spec.previousAddress ?? 0x4513c4)-base,as:Int32.self) },
                bitmap:{ try XCTUnwrap(before[$0]) },milliseconds:{ item.spec.milliseconds ?? 17 },
                drawBitmap:{ args,globals in
                    var bitmap=try XCTUnwrap(before[args[0]])
                    let surface=try bitmap.integer(at:0,as:UInt32.self);try bitmap.write(UInt32(surface == 0 ? 0 : 1),at:0)
                    let input=try OriginalBitmapDrawInput(x:Int32(bitPattern:args[1]),y:Int32(bitPattern:args[2]),frame:Int32(bitPattern:args[3]),colorKey:args[4],mirrored:args[5],sourceSurface:surface,targetSurface:args[6],viewportWidth:globals.integer(at:0x44d78c-base,as:Int32.self),viewportHeight:globals.integer(at:0x44d790-base,as:Int32.self))
                    _ = try OriginalBitmapDrawing.draw(input,bitmap:bitmap,observeRead:{ read in var e=OriginalFrontScreenEvent("read");e.read=read;try event(e) },observeClip:{ clip in var e=OriginalFrontScreenEvent("clip");e.clip=clip;try event(e) },perform:{ blit in var e=OriginalFrontScreenEvent("blit");e.blit=blit;try event(e);return item.spec.methodResult ?? -1 })
                },observe:event)
            XCTAssertNil(failure);XCTAssertEqual(item.end,"returned");XCTAssertEqual(index,item.events.count)
            XCTAssertEqual(item.endPC,0x30000000);XCTAssertEqual(item.endSP,r.corpus.entrySP+4);XCTAssertEqual(item.cw,0x23f)
            try check(state,try XCTUnwrap(after[UInt32(base)]),item.spec.label+" globals")
            if let x=result.minimumX,let y=result.minimumY {
                let stack=try XCTUnwrap(after[0x10000000]);XCTAssertEqual(x,try stack.integer(at:0xeff8,as:Int32.self));XCTAssertEqual(y,try stack.integer(at:0xeffc,as:Int32.self))
            } else { XCTAssertTrue(item.spec.label.hasPrefix("null-wrapper") || item.spec.label.hasPrefix("null-surface")) }
            for (p,v) in before where p != UInt32(base) && p != 0x10000000 { try check(v,try XCTUnwrap(after[p]),item.spec.label+" read-only region") }
            committed=buffer;XCTAssertEqual(committed.count,item.events.count)
            if item.spec.chain == true { retained=state }
        } catch let error as OriginalMenuPanelDrawingError {
            XCTAssertNil(failure);XCTAssertEqual(index,item.events.count)
            XCTAssertEqual(item.end,error == .zeroTimerRange ? "zeroTimerRange" : "noSelectableRow")
            XCTAssertEqual(state,original);XCTAssertTrue(committed.isEmpty)
        } catch Stop.injected {
            XCTAssertNotNil(failure);XCTAssertGreaterThan(index,0);XCTAssertEqual(state,original);XCTAssertTrue(committed.isEmpty)
        }
    }
    func testWholeOriginalPanelTimerLinksBlinkAndRetainedCalls() throws {
        let r=try Resources();var retained:OriginalStateRecord?
        for item in r.corpus.cases { if item.spec.chain == true && item.spec.retained != true { retained=nil };try run(item,r,&retained) }
    }
    func testLateTimerFillSoundShellAndFinalDrawEventsRollBack() throws {
        let r=try Resources()
        for (label,failure) in [("initial-10-1","timer"),("ta-hover-591-200-1-0","fill"),("ta-hover-591-200-1-0","sound"),("banner-23-101-1000","shell"),("notice-29-397-0","finalDraw")] {
            let item=try XCTUnwrap(r.corpus.cases.first { $0.spec.label == label });var retained:OriginalStateRecord?
            try run(item,r,&retained,failure:failure)
        }
    }
}
