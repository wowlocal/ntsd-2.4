import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalWinMainStartupTests: XCTestCase {
    struct Blob: Decodable { let count: Int,deflate: String }
    struct Storage: Decodable { let bytes: String,defined: String }
    struct Allocation: Decodable { let address: UInt32,backing: String?,bytes: String?,mask: String? }
    struct Snapshot: Decodable {
        let ptd: String,allocations: [Allocation],timezone: [UInt32],cache: [UInt32],names: String
        let initialized: UInt32,osZone: UInt32,errno: Int32,tmPointer: UInt32
    }
    struct Store: Decodable { let address: Int,bytes: String,eventIndex: Int? }
    struct Stage: Decodable { let name: String,globals: String,eventCount: Int,crt: Snapshot }
    struct Local: Decodable { let globals: String,local: String,localMask: String }
    struct PanelEvent: Decodable {
        let kind: String,arguments: [UInt32]?,strings: [[UInt8]]?,format: String?,result: UInt32?
        let before: Int?,position: Int?,eof: Bool?,state: Local?,globals: String?,scratch: Storage?,file: String?,buffer: Storage?
    }
    struct Record: Decodable { let address: UInt32,live: Bool,storage: Storage }
    struct PanelChild: Decodable {
        let kind: String,beforeGlobals: String,globals: String,allocation: Allocation?,resource: OriginalBitmapInput?
        let surface: UInt32?,colorKeyResult: Int32?,localState: Local?,scratch: Storage?,file: String?,buffer: Storage?
    }
    struct OwnBoundary: Decodable { let offset: Int,count: Int,rootEventCount: Int,globalStoreCount: Int,rootGlobals: String }
    struct Panel: Decodable { let children: [PanelChild],records: [Record],ownBoundary: OwnBoundary? }
    struct PanelSpec: Decodable {
        let info: [UInt8]?,content: [UInt8]?,chunk: Int,infoReadFailAt: Int,infoClose: Int32,contentClose: Int32
        let capacity: Int,writeOpen: Bool,writeMode: String,writeFailAt: Int,writeClose: Int32
    }
    struct InputSpec: Decodable { let device: OriginalMenuSoundStartup.Platform }
    struct Spec: Decodable {
        let label: String,milliseconds: UInt32,filetime: UInt64,zone: OriginalCalendarTime.Zone,criticalSection: [UInt8]
        let panel: PanelSpec,input: InputSpec,instance: UInt32?,show: Int32?,tz: String?,zoneResult: UInt32?
    }
    struct MusicEvent: Decodable { let kind: OriginalMusicEvent.Kind,arguments: [UInt32],strings: [[UInt8]],response: OriginalMusicResponse }
    struct ChildEvent: Decodable {
        let request: OriginalWindowInitialization.Request?,response: OriginalWindowInitialization.Response?
        let kind: String?,arguments: [UInt32]?,event: OriginalMenuSoundStartup.Event?,globals: String?
        let stackStoreCount: Int?,globalStoreCount: Int?
    }
    struct Event: Decodable {
        let kind: String,event: ChildEvent?,music: MusicEvent?,arguments: [UInt32]?,result: UInt32?,value: UInt64?
        let address: UInt32?,count: Int?,capacity: Int?,bytes: [UInt8]?,values: [Int32]?
    }
    struct Joy: Decodable { let request: OriginalInputStartup.Request,response: OriginalInputStartup.Response,globals: String }
    struct Caps: Decodable { let id: Int,bytes: String,defined: String }
    struct Load: Decodable {
        let path: [UInt8],file: String,input: OriginalWavePlatform,afterGlobals: String,outputAfter: UInt32,returned: UInt32?,temporaryLive: Bool
        let first: Storage,second: Storage?,temporary: Storage?,format: Storage?,descriptor: Storage?
    }
    struct Input: Decodable { let loads: [Load],joyRequests: [Joy],capsStates: [Caps],ownBoundary: OwnBoundary?,joystickReturn: JoyReturn? }
    struct JoyReturn: Decodable { let eax: UInt32 }
    struct Music: Decodable { let allocations: [Allocation] }
    struct CalendarReturn: Decodable { let pointer: UInt32,bytes: [UInt8]? }
    struct Case: Decodable {
        let spec: Spec,initialGlobals: String,beforeGlobals: String,globals: String,globalMask: String,stimulus: [Store]
        let before: Snapshot,after: Snapshot,events: [Event],globalStores: [Store],stackStores: [Store],stages: [Stage]
        let panel: Panel,music: Music,input: Input?,end: String,boundaryPC: UInt32?,endPC: UInt32,endSP: UInt32,controlWord: UInt32
        let localInputs: [Int64],calendarResults: [CalendarReturn]
    }
    struct Source: Decodable { let path: String,sha256: String,count: Int }
    struct Corpus: Decodable { let exeSHA256: String,dllSHA256: String,cases: [Case],sources: [Source],blobs: [String:Blob] }
    enum Trial: Error { case late }
    static func hex(_ s: String) -> [UInt8] { stride(from:0,to:s.count,by:2).map { UInt8(s.dropFirst($0).prefix(2),radix:16)! } }
    private func read() throws -> (Corpus,[[String:Any]]) {
        let url = try ProcessInfo.processInfo.environment["NTSD_WINMAIN_STARTUP"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-winmain-startup",withExtension:"json",subdirectory:"Fixtures"))
        let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:100_000_000)
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        return (try JSONDecoder().decode(Corpus.self,from:data),try XCTUnwrap(raw["cases"] as? [[String:Any]]))
    }
    final class Adapter: OriginalApplicationStartupPlatform {
        let c: Case,rawEvents: [[String:Any]],blob: (String) throws -> [UInt8],sources: [String:String],fail: String?
        let startupInputs: OriginalApplicationStartupInputs?
        var index = 0,storeIndex = 0,stageIndex = 0,calendarIndex = 0,joyIndex = 0,capsIndex = 0,waves = 0,childIndex = -1,writes = 0
        var shadow: [UInt8],expected: [UInt8],mask: [UInt8]
        /// Every mutable member is a value. Blob's shared cache holds immutable
        /// input bytes and is not a reply position or an external effect queue.
        func stagedCopy() throws -> Adapter {
            let copy = try Adapter(c,["events":rawEvents],sources:sources,blob:blob,initial:shadow,fail:fail,startupInputs:startupInputs)
            copy.index = index;copy.storeIndex = storeIndex;copy.stageIndex = stageIndex
            copy.calendarIndex = calendarIndex;copy.joyIndex = joyIndex;copy.capsIndex = capsIndex
            copy.waves = waves;copy.childIndex = childIndex;copy.writes = writes
            copy.expected = expected;copy.mask = mask
            return copy
        }
        init(_ c: Case,_ raw: [String:Any],sources: [String:String],blob: @escaping (String) throws -> [UInt8],initial: [UInt8],fail: String? = nil,startupInputs: OriginalApplicationStartupInputs? = nil) throws {
            self.startupInputs = startupInputs;self.c = c;self.blob = blob;self.sources = sources;self.fail = fail;shadow = initial;expected = initial;mask = [UInt8](repeating:0,count:initial.count)
            rawEvents = try XCTUnwrap(raw["events"] as? [[String:Any]])
        }
        func store(_ address: Int,_ bytes: [UInt8]) {
            let offset = address-OriginalMatchPreparation.globalBase
            shadow.replaceSubrange(offset..<offset+bytes.count,with:bytes)
            mask.replaceSubrange(offset..<offset+bytes.count,with:repeatElement(UInt8(1),count:bytes.count))
        }
        func compareStores(count: Int? = nil) {
            while storeIndex < c.globalStores.count && (count.map { storeIndex < $0 } ?? ((c.globalStores[storeIndex].eventIndex ?? 0) <= index)) {
                let w = c.globalStores[storeIndex];storeIndex += 1;let b = OriginalWinMainStartupTests.hex(w.bytes),o = w.address-OriginalMatchPreparation.globalBase
                expected.replaceSubrange(o..<o+b.count,with:b)
            }
            XCTAssertTrue(shadow == expected,"\(c.spec.label) global write order at event \(index), store \(storeIndex)")
        }
        func next(_ kind: String) throws -> Event {
            guard index < c.events.count else { XCTFail("Excess \(kind) in \(c.spec.label)");throw Trial.late }
            compareStores();let e = c.events[index];index += 1;XCTAssertEqual(e.kind,kind,"\(c.spec.label) event \(index-1)")
            return e
        }
        func state(_ actual: OriginalStateRecord,_ hash: String) throws { XCTAssertTrue(actual.bytes == (try blob(hash)),"\(c.spec.label) globals at \(index)") }
        func local(_ actual: OriginalStateRecord,_ bytes: String,_ mask: String) throws {
            let b = try blob(bytes),m = try blob(mask);XCTAssertEqual(actual.defined,m.map { $0 == 1 })
            XCTAssertTrue(m.indices.allSatisfy { m[$0] == 0 || actual.bytes[$0] == b[$0] },c.spec.label+" defined local bytes")
        }
        func storage(_ actual: OriginalStateRecord?,_ expected: Storage?) throws {
            XCTAssertEqual(actual == nil,expected == nil,c.spec.label)
            if let actual,let expected { XCTAssertTrue(actual.bytes == (try blob(expected.bytes)),c.spec.label+" owned bytes");XCTAssertTrue(actual.defined == (try blob(expected.defined).map { $0 == 1 }),c.spec.label+" owned masks") }
        }
        func allocations(_ actual: [UInt32:OriginalStateRecord],_ expected: [Allocation]) throws {
            XCTAssertEqual(actual.count,expected.count)
            for e in expected { let a = try XCTUnwrap(actual[e.address]);XCTAssertTrue(a.bytes == (try blob(XCTUnwrap(e.bytes))));XCTAssertTrue(a.defined == (try blob(XCTUnwrap(e.mask)).map { $0 == 1 })) }
        }
        func calendar(_ actual: OriginalCalendarTime,_ expected: Snapshot) throws {
            XCTAssertEqual(actual.timezone.map { UInt32(bitPattern:$0) },expected.timezone);XCTAssertEqual(actual.cache.map { UInt32(bitPattern:$0) },expected.cache)
            XCTAssertEqual(actual.names,try blob(expected.names));XCTAssertEqual(actual.initialized,expected.initialized != 0);XCTAssertEqual(actual.osZone,expected.osZone != 0)
            XCTAssertEqual(actual.errno,expected.errno);XCTAssertEqual(actual.tmPointer,expected.tmPointer);try allocations(actual.allocations,expected.allocations)
        }
        var panelIO: OriginalWinMainStartup.PanelIO {
            let s = c.spec.panel
            return .init(chunk:s.chunk,readFailAt:s.infoReadFailAt,infoClose:s.infoClose,contentClose:s.contentClose,outputBacking:[UInt8](repeating:0xa5,count:s.capacity),writeAvailable:s.writeOpen)
        }
        var environmentTZ: [UInt8]? { c.spec.tz.map { Array($0.utf8) } }
        var sound: OriginalMenuSoundStartup.Platform { c.spec.input.device }
        func milliseconds() throws -> UInt32 { let e = try next("timeGetTime");XCTAssertEqual(e.arguments,[]);XCTAssertEqual(e.result,c.spec.milliseconds);return c.spec.milliseconds }
        func initializeCriticalSection(_ address: UInt32) throws -> [UInt8] { let e = try next("initializeCriticalSection");XCTAssertEqual(e.arguments,[address]);return c.spec.criticalSection }
        func initializeCOM() throws -> UInt32 { let e = try next("coInitialize");XCTAssertEqual(e.arguments,[0]);return try XCTUnwrap(e.result) }
        func window(_ request: OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response {
            let e = try XCTUnwrap(next("window").event),r = try XCTUnwrap(e.request)
            XCTAssertEqual(request.kind,r.kind);XCTAssertEqual(request.words,r.words,c.spec.label);XCTAssertEqual(request.strings,r.strings)
            XCTAssertEqual(request.defined,r.defined,c.spec.label);XCTAssertEqual(request.bytes?.count,r.bytes?.count)
            if let mask = r.defined { let a = try XCTUnwrap(request.bytes),b = try XCTUnwrap(r.bytes);XCTAssertTrue(mask.indices.allSatisfy { !mask[$0] || a[$0] == b[$0] },c.spec.label+" window owned fields") }
            return try XCTUnwrap(e.response)
        }
        func file(_ path: String) throws -> [UInt8]? {
            if let startupInputs {
                let actual = try startupInputs.file(path)
                let expected = try path == "data\\adinfo.txt" ? c.spec.panel.info : sources[path].map(blob) ?? c.spec.panel.content
                XCTAssertEqual(actual,expected);return actual
            }
            if path == "data\\adinfo.txt" { return c.spec.panel.info }
            if let h = sources[path] { return try blob(h) }
            let content = try XCTUnwrap(c.panel.children.first { $0.kind == "content" })
            let g = try OriginalStateRecord(bytes:blob(content.beforeGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
            XCTAssertEqual(path,"data\\ad\(try g.integer(at:0x44d784-OriginalMatchPreparation.globalBase,as:Int32.self)).txt")
            return c.spec.panel.content
        }
        func writePanel(_ bytes: [UInt8]) throws -> Int32 {
            defer { writes += 1 };let s = c.spec.panel
            guard writes == s.writeFailAt else { return Int32(bytes.count) }
            switch s.writeMode { case "error":return -1;case "zero":return 0;case "short":return Int32(bytes.count)-1;default:return Int32(bytes.count) }
        }
        func closePanel() throws -> Int32 { c.spec.panel.writeClose }
        var bitmap: PanelChild { get throws { try XCTUnwrap(c.panel.children.first { $0.kind == "bitmap" }) } }
        func allocatePanel() throws -> OriginalInterfaceAllocation { let a = try XCTUnwrap(bitmap.allocation);return try .init(address:a.address,backing:a.backing.map(blob) ?? []) }
        func panelBitmap(_ path: String) throws -> OriginalBitmapInput { let r = try XCTUnwrap(bitmap.resource);XCTAssertEqual(path,r.path);return r }
        func panelDevice() throws -> (surface: UInt32,colorKeyResult: Int32) { (try XCTUnwrap(bitmap.surface),try XCTUnwrap(bitmap.colorKeyResult)) }
        func filetime() throws -> UInt64 { c.spec.filetime }
        func timezone() throws -> (result: UInt32,zone: OriginalCalendarTime.Zone?) { (c.spec.zoneResult ?? 0,c.spec.zone) }
        func allocateCalendar(_ count: Int) throws -> OriginalInterfaceAllocation {
            let e = c.events[index];XCTAssertEqual(e.kind,"allocate");XCTAssertEqual(e.count,count);let p = try XCTUnwrap(e.address)
            let b = try p == 0 ? [] : blob(XCTUnwrap(c.after.allocations.first { $0.address == p }?.backing))
            return .init(address:p,backing:b)
        }
        func convertZoneName(_ name: String,_ capacity: Int) throws -> [UInt8] { XCTAssertEqual(capacity,63);return Array(name.utf8)+[0] }
        func music(_ event: OriginalMusicEvent) throws -> OriginalMusicResponse {
            let e = try XCTUnwrap(next("music").music);XCTAssertEqual(event.kind,e.kind);XCTAssertEqual(event.arguments,e.arguments,c.spec.label);XCTAssertEqual(event.strings,e.strings,c.spec.label);return e.response
        }
        func cursor(_ load: Bool,_ arguments: [UInt32]) throws -> UInt32 { let e = try next(load ? "loadCursor" : "setCursor");XCTAssertEqual(arguments,e.arguments);return try XCTUnwrap(e.result) }
        func joystick(_ request: OriginalInputStartup.Request,_ globals: OriginalStateRecord) throws -> OriginalInputStartup.Response {
            let j = try XCTUnwrap(c.input).joyRequests[joyIndex];joyIndex += 1;XCTAssertEqual(request,j.request,c.spec.label);try state(globals,j.globals)
            try soundEvent(.init(request.kind,request.arguments,request.information.map { [$0] } ?? []),globals);return j.response
        }
        func wave(_ index: Int,_ path: String,_ destination: UInt32,_ device: UInt32) throws -> OriginalWavePlatform {
            let l = try XCTUnwrap(c.input).loads[index];XCTAssertEqual(Array(path.utf8),l.path);XCTAssertEqual(l.file,sources[path]);XCTAssertEqual(destination,l.input.destination);XCTAssertEqual(device,l.input.device);return l.input
        }
        func soundEvent(_ event: OriginalMenuSoundStartup.Event,_ globals: OriginalStateRecord) throws {
            let e = try XCTUnwrap(next("input").event);XCTAssertEqual(event,e.event,c.spec.label+" input event");try state(globals,XCTUnwrap(e.globals))
        }
        func panelEvent(_ kind: String,_ args: [UInt32],_ strings: [[UInt8]],_ format: String?,_ result: UInt32?,
            globals: OriginalStateRecord? = nil,scratch: OriginalStateRecord? = nil,stream: OriginalBufferedTextOutput? = nil,
            before: Int? = nil,position: Int? = nil,eof: Bool? = nil) throws {
            let child = c.panel.children[childIndex],raw = try XCTUnwrap(rawEvents[index]["event"] as? [String:Any])
            _ = try next("panel-"+child.kind);let e = try JSONDecoder().decode(PanelEvent.self,from:JSONSerialization.data(withJSONObject:raw))
            func target(_ p: UInt32) -> [UInt32] { p >= 0x1000ef44 && p < 0x1000effc ? [1,p-0x1000ef44] : [0,p-0x44d000] }
            let arguments = kind == "scan" && child.kind == "info" ? (e.arguments ?? []).flatMap(target) : (e.arguments ?? [])
            XCTAssertEqual(kind,e.kind);XCTAssertEqual(args,arguments,c.spec.label);XCTAssertEqual(strings,e.strings ?? [],c.spec.label);XCTAssertEqual(format,e.format);XCTAssertEqual(result,e.result)
            XCTAssertEqual(before,e.before);XCTAssertEqual(position,e.position);XCTAssertEqual(eof,e.eof)
            if let s = e.state { try state(XCTUnwrap(globals),s.globals);try local(XCTUnwrap(scratch),s.local,s.localMask) }
            if let h = e.globals { try state(XCTUnwrap(globals),h) };if let s = e.scratch { try local(XCTUnwrap(scratch),s.bytes,s.defined) }
            if let h = e.file { XCTAssertTrue(try XCTUnwrap(stream).fileStorage().bytes == blob(h)) }
            if let s = e.buffer { try storage(XCTUnwrap(stream).buffer,s) }
        }
        func observe(_ event: OriginalWinMainStartup.Observation) throws {
            switch event {
            case let .stage(name,s):
                let e = c.stages[stageIndex];stageIndex += 1;XCTAssertEqual(name,e.name);XCTAssertEqual(index,e.eventCount);try state(s,e.globals)
                if fail == name { throw Trial.late }
            case let .panel(observation):
                switch observation {
                case let .caller(e,s):
                    let a = try XCTUnwrap(next("panelCaller").event);XCTAssertEqual(e.kind,a.kind);XCTAssertEqual(e.arguments,a.arguments)
                    if e.kind == "call" { childIndex += 1;try state(s,c.panel.children[childIndex].beforeGlobals) }
                    else { try state(s,c.panel.children[childIndex].globals) }
                case let .info(e,s,l):try panelEvent(e.kind,e.arguments,e.strings,e.format,e.result,globals:s,scratch:l)
                case let .content(e,s,l):try panelEvent(e.kind,e.arguments,e.strings,e.format,e.result,globals:s,scratch:l,before:e.before,position:e.position,eof:e.eof)
                case let .bitmap(e):try panelEvent(e.kind,e.arguments,e.strings,nil,nil)
                case let .writer(e,s,o):try panelEvent(e.kind,e.arguments,e.strings,e.format,e.result,globals:s,stream:o)
                }
            case let .calendar(a):
                let e = try next(a.kind);XCTAssertEqual(a.value,e.value);XCTAssertEqual(a.result,e.result);XCTAssertEqual(a.address,e.address);XCTAssertEqual(a.bytes,e.bytes);XCTAssertEqual(a.count,e.count);XCTAssertEqual(a.capacity,e.capacity)
            case let .calendarReturn(seconds,values):
                XCTAssertEqual(seconds,c.localInputs[calendarIndex]);let e = c.calendarResults[calendarIndex];calendarIndex += 1
                if let values { let raw: [UInt8] = values.flatMap { v in (0..<4).map { UInt8(truncatingIfNeeded:UInt32(bitPattern:v) >> ($0*8)) } };XCTAssertEqual(raw,e.bytes);XCTAssertNotEqual(e.pointer,0) }
                else { XCTAssertNil(e.bytes);XCTAssertEqual(e.pointer,0) }
            case let .date(address,values,bytes):
                let e = try next("dateFormat");XCTAssertEqual(UInt32(address),e.address);XCTAssertEqual(values,e.values);XCTAssertEqual(bytes,e.bytes);XCTAssertEqual(bytes.count-1,Int(try XCTUnwrap(e.result)))
                if fail == "secondDate" && address == 0x458350 { throw Trial.late }
            case let .capabilities(id,s):
                let e = try XCTUnwrap(c.input).capsStates[capsIndex];capsIndex += 1;XCTAssertEqual(id,e.id);try local(s,e.bytes,e.defined)
            case let .wave(i,r,s):
                let e = try XCTUnwrap(c.input).loads[i];XCTAssertEqual(r.output,e.outputAfter);XCTAssertEqual(r.returned,e.returned);XCTAssertEqual(r.temporaryLive,e.temporaryLive);try state(s,e.afterGlobals)
                try storage(r.first,e.first);try storage(r.second,e.second);try storage(r.temporary,e.temporary);try storage(r.format,e.format);try storage(r.descriptor,e.descriptor);waves += 1
                if fail == "fifthWave" && i == 4 { throw Trial.late }
            case let .sound(e,s):try soundEvent(e,s)
            }
        }
        func complete(_ engine: OriginalWinMainStartup,_ globals: OriginalStateRecord) throws {
            compareStores(count:c.globalStores.count);XCTAssertEqual(index,c.events.count);XCTAssertEqual(stageIndex,c.stages.count);XCTAssertEqual(calendarIndex,c.calendarResults.count)
            try state(globals,c.globals);XCTAssertTrue(mask == (try blob(c.globalMask)),c.spec.label+" global mask")
            XCTAssertEqual(engine.random.state,c.spec.milliseconds);try calendar(engine.output.calendar,c.after);try allocations(engine.output.music.allocations,c.music.allocations)
            XCTAssertEqual(engine.dates?.expiry,c.localInputs[1]);XCTAssertEqual(engine.input?.joystickReturn,c.input?.joystickReturn?.eax);XCTAssertEqual(engine.input?.sounds.loads.count,5)
            XCTAssertEqual(engine.panel.panel.records.count,c.panel.records.count)
            for (a,e) in zip(engine.panel.panel.records,c.panel.records) {
                var bytes = try blob(e.storage.bytes);let surface = UInt32(bytes[0]) | UInt32(bytes[1])<<8 | UInt32(bytes[2])<<16 | UInt32(bytes[3])<<24
                XCTAssertEqual(a.address,e.address);XCTAssertEqual(a.live,e.live);XCTAssertEqual(a.surface,surface);bytes.replaceSubrange(0..<4,with:[surface == 0 ? 0 : 1,0,0,0])
                XCTAssertTrue(a.bitmap.storage.bytes == bytes);XCTAssertTrue(a.bitmap.storage.defined == (try blob(e.storage.defined).map { $0 == 1 }))
            }
            for child in c.panel.children {
                if let e = child.localState { try local(XCTUnwrap(engine.panel.infoLocal),e.local,e.localMask) }
                if let e = child.scratch { try local(XCTUnwrap(engine.panel.contentLocal),e.bytes,e.defined) }
                if let e = child.buffer { try storage(XCTUnwrap(engine.panel.output).buffer,e) }
                if let h = child.file { XCTAssertTrue(try XCTUnwrap(engine.panel.output).fileStorage().bytes == blob(h)) }
            }
        }
    }
    private func rollback(_ a: OriginalWinMainStartup,_ b: OriginalWinMainStartup) {
        XCTAssertEqual(a.random,b.random);XCTAssertEqual(a.output.calendar,b.output.calendar);XCTAssertEqual(a.output.music.allocations,b.output.music.allocations)
        XCTAssertEqual(a.panel.infoLocal,b.panel.infoLocal);XCTAssertEqual(a.panel.contentLocal,b.panel.contentLocal);XCTAssertEqual(a.panel.panel.records.count,b.panel.panel.records.count)
        XCTAssertNil(a.panel.output);XCTAssertNil(a.input);XCTAssertNil(a.dates)
    }
    func testContinuousStartupOwnedStateAndExplicitBoundaries() throws {
        let (corpus,raw) = try read();var cache: [String:[UInt8]] = [:]
        XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c");XCTAssertEqual(corpus.dllSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        func blob(_ h: String) throws -> [UInt8] { if let b = cache[h] { return b };let p = try XCTUnwrap(corpus.blobs[h]),b = try MatchPreparationReference.inflate(p.deflate,count:p.count,maximumCount:10_000_000);XCTAssertEqual(MatchPreparationReference.digest(Data(b)),h);cache[h] = b;return b }
        let sources = Dictionary(uniqueKeysWithValues:corpus.sources.map { ($0.path,$0.sha256) });var whole = 0,sourceStops = 0,unknown = 0,events = 0,waves = 0
        for (c,r) in zip(corpus.cases,raw) {
            var globals = try OriginalStateRecord(bytes:blob(c.initialGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize)),engine = OriginalWinMainStartup()
            for w in c.stimulus { for (i,b) in Self.hex(w.bytes).enumerated() { try globals.write(b,at:w.address-OriginalMatchPreparation.globalBase+i) } }
            XCTAssertTrue(globals.bytes == (try blob(c.beforeGlobals)));let before = globals,prior = engine
            let p = try Adapter(c,r,sources:sources,blob:blob,initial:globals.bytes)
            try p.calendar(engine.output.calendar,c.before)
            do {
                try engine.run(instance:c.spec.instance ?? 0x400000,show:c.spec.show ?? 10,globals:&globals,platform:p,store:p.store)
                XCTAssertEqual(c.end,"startupBoundary");XCTAssertEqual(c.endPC,0x43d100);XCTAssertEqual(c.endSP,0x1000effc)
                try p.complete(engine,globals);whole += 1
            } catch let e as OriginalWinMainStartup.Boundary {
                XCTAssertEqual(e,.unknownFullscreenCursor);let next = try XCTUnwrap(c.events[p.index].event),request = try XCTUnwrap(next.request)
                XCTAssertEqual(request.kind,"registerClass");XCTAssertEqual(request.defined.map { Array($0[24..<28]) },[false,false,false,false])
                let cursor = 0x1000efd8
                XCTAssertTrue(c.stackStores.prefix(try XCTUnwrap(next.stackStoreCount)).allSatisfy { $0.address >= cursor+4 || $0.address+Self.hex($0.bytes).count <= cursor })
                p.compareStores(count:try XCTUnwrap(next.globalStoreCount));unknown += 1
                XCTAssertEqual(globals,before);rollback(engine,prior)
            } catch OriginalStateError.undefinedBytes(let offset,let count) {
                let b = try XCTUnwrap(c.panel.ownBoundary ?? c.input?.ownBoundary);XCTAssertEqual(offset,b.offset);XCTAssertEqual(count,b.count);XCTAssertEqual(p.index,b.rootEventCount)
                p.compareStores(count:b.globalStoreCount);XCTAssertTrue(p.shadow == (try blob(b.rootGlobals)));unknown += 1
                XCTAssertEqual(globals,before);rollback(engine,prior)
            } catch let e as OriginalStartupOutput.Boundary {
                XCTAssertEqual(c.end,"nullCalendarRead");XCTAssertEqual(e,.nullCalendarRead(address:try XCTUnwrap(c.boundaryPC)));p.compareStores(count:c.globalStores.count);XCTAssertEqual(p.index,c.events.count);sourceStops += 1
                XCTAssertEqual(globals,before);rollback(engine,prior)
            } catch let e as OriginalCalendarTime.Boundary {
                XCTAssertEqual(c.end,"invalidParameter");XCTAssertEqual(e,.invalidParameter);p.compareStores(count:c.globalStores.count);XCTAssertEqual(p.index,c.events.count);sourceStops += 1
                XCTAssertEqual(globals,before);rollback(engine,prior)
            } catch OriginalStateError.invalidStorage(let message) {
                XCTAssertEqual(message,"Original menu wave reaches invalid CreateSoundBuffer continuation");XCTAssertEqual(c.end,"invalidCreateContinuation");XCTAssertEqual(c.boundaryPC,0x40187a)
                p.compareStores(count:c.globalStores.count);XCTAssertEqual(p.index,c.events.count);sourceStops += 1;XCTAssertEqual(globals,before);rollback(engine,prior)
            }
            XCTAssertEqual(c.controlWord,0x37f);events += p.index;waves += p.waves
        }
        XCTAssertEqual(corpus.cases.count,35);XCTAssertEqual(whole,23);XCTAssertEqual(sourceStops,5);XCTAssertEqual(unknown,7)
        print("WinMainStartup:",whole,"whole chains",sourceStops,"source stops",unknown,"unknown-provenance rejections",events,"compared events",waves,"whole WAV results")
    }
    func testLateRollbackOfWholeStartup() throws {
        let (corpus,raw) = try read(),c = try XCTUnwrap(corpus.cases.first),r = try XCTUnwrap(raw.first)
        func blob(_ h: String) throws -> [UInt8] { let p = try XCTUnwrap(corpus.blobs[h]);return try MatchPreparationReference.inflate(p.deflate,count:p.count,maximumCount:10_000_000) }
        let sources = Dictionary(uniqueKeysWithValues:corpus.sources.map { ($0.path,$0.sha256) })
        for phase in ["window-return","panel-return","secondDate","output-return","fifthWave","after"] {
            var globals = try OriginalStateRecord(bytes:blob(c.initialGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize)),engine = OriginalWinMainStartup()
            let before = globals,prior = engine,p = try Adapter(c,r,sources:sources,blob:blob,initial:globals.bytes,fail:phase);var reached = false
            do { try engine.run(instance:0x400000,show:10,globals:&globals,platform:p,store:p.store,after:{ _,_ in if phase == "after" { throw Trial.late } });XCTFail("Missing late error") }
            catch Trial.late { reached = true }
            XCTAssertTrue(reached);XCTAssertEqual(globals,before);rollback(engine,prior)
        }
    }
}
