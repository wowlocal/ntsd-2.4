import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalStartupOutputTests: XCTestCase {
    private struct Blob: Decodable { let count: Int,deflate: String }
    private struct Allocation: Decodable { let address: UInt32,backing: String,bytes: String,mask: String }
    private struct Snapshot: Decodable {
        let allocations: [Allocation],timezone: [UInt32],cache: [UInt32],names: String
        let initialized: UInt32,osZone: UInt32,errno: Int32,tmPointer: UInt32
    }
    private struct Music: Decodable {
        let kind: OriginalMusicEvent.Kind,arguments: [UInt32],strings: [[UInt8]],response: OriginalMusicResponse
    }
    private struct Event: Decodable {
        let kind: String,value: UInt64?,result: UInt32?,address: UInt32?,bytes: [UInt8]?,values: [Int32]?,arguments: [UInt32]?
        let count: Int?,capacity: Int?,music: Music?
    }
    private struct Spec: Decodable { let label: String,zone: OriginalCalendarTime.Zone,tz: String?,zoneResult: UInt32?,ramp: Bool?,allocationFail: Bool? }
    private struct Input: Decodable { let filetime: UInt64 }
    private struct Write: Decodable { let address: Int,bytes: String }
    private struct Store: Decodable { let address: Int,bytes: String,eventIndex: Int }
    private struct CalendarResult: Decodable { let pointer: UInt32,bytes: [UInt8]? }
    private struct Step: Decodable {
        let input: Input,stimulus: [Write],before: Snapshot,after: Snapshot,beforeGlobals: String,globals: String,globalMask: String
        let events: [Event],localInputs: [Int64],calendarResults: [CalendarResult],musicAllocations: [Allocation]
        let globalStores: [Store]
        let end: String,boundaryPC: UInt32?,endPC: UInt32,endSP: UInt32,controlWord: UInt32
    }
    private struct Case: Decodable { let spec: Spec,initialGlobals: String,steps: [Step] }
    private struct Corpus: Decodable { let exeSHA256: String,dllSHA256: String,cases: [Case],blobs: [String:Blob] }
    private enum Trial: Error { case late }
    private func read() throws -> Corpus {
        let url = try ProcessInfo.processInfo.environment["NTSD_STARTUP_OUTPUT"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-startup-output",withExtension:"json",subdirectory:"Fixtures"))
        return try JSONDecoder().decode(Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:100_000_000))
    }
    private func stimulate(_ step: Step,_ globals: inout OriginalStateRecord) throws {
        for w in step.stimulus {
            let bytes = stride(from:0,to:w.bytes.count,by:2).map { i in UInt8(w.bytes.dropFirst(i).prefix(2),radix:16)! }
            for (i,b) in bytes.enumerated() { try globals.write(b,at:w.address-OriginalMatchPreparation.globalBase+i) }
        }
    }
    @discardableResult
    private func execute(_ c: Case,_ s: Step,_ engine: inout OriginalStartupOutput,_ globals: inout OriginalStateRecord,
        blob: (String) throws -> [UInt8],mask: inout [UInt8],fail: String? = nil) throws -> OriginalStartupOutput.Result {
        var index = 0,localIndex = 0,storeIndex = 0,shadow = globals.bytes,expected = globals.bytes
        func compareStores() {
            while storeIndex < s.globalStores.count && s.globalStores[storeIndex].eventIndex <= index {
                let w = s.globalStores[storeIndex];storeIndex += 1
                let bytes = stride(from:0,to:w.bytes.count,by:2).map { i in UInt8(w.bytes.dropFirst(i).prefix(2),radix:16)! }
                let offset = w.address-OriginalMatchPreparation.globalBase
                expected.replaceSubrange(offset..<offset+bytes.count,with:bytes)
            }
            XCTAssertTrue(shadow == expected,"Global write order at event \(index) in \(c.spec.label)")
        }
        defer {
            if fail == nil {
                compareStores();XCTAssertEqual(storeIndex,s.globalStores.count)
                XCTAssertEqual(index,s.events.count);XCTAssertEqual(localIndex,s.calendarResults.count)
            }
        }
        func next(_ kind: String) throws -> Event {
            guard index < s.events.count else { XCTFail("Excess event "+kind);throw Trial.late }
            compareStores()
            let e = s.events[index];index += 1;XCTAssertEqual(e.kind,kind,c.spec.label)
            if fail == kind { throw Trial.late };return e
        }
        return try engine.run(globals:&globals,filetime:{ s.input.filetime },environmentTZ:c.spec.tz.map { Array($0.utf8) },timezoneSource:{ (c.spec.zoneResult ?? 0,c.spec.zone) },allocateCalendar:{ count in
            let e = try XCTUnwrap(s.events[index].address);XCTAssertEqual(count,s.events[index].count)
            let b = try e == 0 ? [] : blob(XCTUnwrap(s.after.allocations.first { $0.address == e }).backing)
            return .init(address:e,backing:b)
        },convertName:{ name,capacity in XCTAssertEqual(capacity,63);return Array(name.utf8)+[0] },observeCalendar:{ actual in
            let e = try next(actual.kind)
            XCTAssertEqual(actual.value,e.value);XCTAssertEqual(actual.result,e.result);XCTAssertEqual(actual.address,e.address)
            XCTAssertEqual(actual.bytes,e.bytes);XCTAssertEqual(actual.count,e.count);XCTAssertEqual(actual.capacity,e.capacity)
        },returnedCalendar:{ seconds,values in
            XCTAssertEqual(seconds,s.localInputs[localIndex],c.spec.label)
            let e = s.calendarResults[localIndex];localIndex += 1
            if let values {
                let raw = values.flatMap { v in (0..<4).map { UInt8(truncatingIfNeeded:UInt32(bitPattern:v) >> ($0*8)) } }
                XCTAssertEqual(raw,e.bytes,c.spec.label);XCTAssertNotEqual(e.pointer,0)
            } else { XCTAssertNil(e.bytes);XCTAssertEqual(e.pointer,0) }
        },formatted:{ address,values,bytes in
            let e = try next("dateFormat");XCTAssertEqual(UInt32(address),e.address);XCTAssertEqual(values,e.values);XCTAssertEqual(bytes,e.bytes)
            XCTAssertEqual(bytes.count-1,Int(try XCTUnwrap(e.result)))
            if fail == "firstDate" && address == 0x451d48 || fail == "secondDate" && address == 0x458350 { throw Trial.late }
        },requestMusic:{ actual in
            let m = try XCTUnwrap(next("music").music)
            XCTAssertEqual(actual.kind,m.kind,c.spec.label);XCTAssertEqual(actual.arguments,m.arguments,c.spec.label);XCTAssertEqual(actual.strings,m.strings,c.spec.label)
            return m.response
        },requestCursor:{ load,args in
            let e = try next(load ? "loadCursor" : "setCursor");XCTAssertEqual(args,e.arguments,c.spec.label)
            return try XCTUnwrap(e.result)
        },store:{ address,bytes in
            let offset = address-OriginalMatchPreparation.globalBase
            shadow.replaceSubrange(offset..<offset+bytes.count,with:bytes)
            for i in bytes.indices { mask[address-OriginalMatchPreparation.globalBase+i] = 1 }
        },after:{ _,_ in
            XCTAssertEqual(index,s.events.count);XCTAssertEqual(localIndex,s.localInputs.count)
            if fail == "after" { throw Trial.late }
        })
    }
    func testWholeCallerDatesMusicCursorAndSourceBoundaries() throws {
        let c = try read();var cache: [String:[UInt8]] = [:]
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.dllSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        func blob(_ h: String) throws -> [UInt8] {
            if let b = cache[h] { return b };let p = try XCTUnwrap(c.blobs[h]),b = try MatchPreparationReference.inflate(p.deflate,count:p.count,maximumCount:200_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),h);cache[h] = b;return b
        }
        func allocations(_ state: [UInt32:OriginalStateRecord],_ expected: [Allocation]) throws {
            XCTAssertEqual(state.count,expected.count)
            for a in expected { let r = try XCTUnwrap(state[a.address]);XCTAssertEqual(r.bytes,try blob(a.bytes));XCTAssertEqual(r.defined,try blob(a.mask).map { $0 == 1 }) }
        }
        func calendar(_ a: OriginalCalendarTime,_ b: Snapshot) throws {
            XCTAssertEqual(a.timezone.map { UInt32(bitPattern:$0) },b.timezone);XCTAssertEqual(a.cache.map { UInt32(bitPattern:$0) },b.cache)
            XCTAssertEqual(a.names,try blob(b.names));XCTAssertEqual(a.initialized,b.initialized != 0);XCTAssertEqual(a.osZone,b.osZone != 0)
            XCTAssertEqual(a.errno,b.errno);XCTAssertEqual(a.tmPointer,b.tmPointer);try allocations(a.allocations,b.allocations)
        }
        var whole = 0,rejected = 0,events = 0
        for item in c.cases {
            // Independent verifier binds these initial bytes to PE sections.
            // All later calls retain this native engine's own output.
            var globals = try OriginalStateRecord(bytes:blob(item.initialGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize)),engine = OriginalStartupOutput()
            for step in item.steps {
                try stimulate(step,&globals);XCTAssertTrue(globals.bytes == (try blob(step.beforeGlobals)),item.spec.label)
                try calendar(engine.calendar,step.before)
                let prior = engine,before = globals;var mask = [UInt8](repeating:0,count:globals.bytes.count)
                do {
                    let result = try execute(item,step,&engine,&globals,blob:blob,mask:&mask)
                    XCTAssertEqual(step.end,"returned",item.spec.label);XCTAssertEqual(step.endPC,0x43d078);XCTAssertEqual(step.endSP,0x1000effc)
                    XCTAssertEqual(Int64(bitPattern:result.time),step.localInputs[0]);XCTAssertEqual(result.expiry,step.localInputs[1])
                    XCTAssertTrue(globals.bytes == (try blob(step.globals)),item.spec.label);XCTAssertEqual(mask,try blob(step.globalMask),item.spec.label)
                    try calendar(engine.calendar,step.after);try allocations(engine.music.allocations,step.musicAllocations);whole += 1
                } catch let b as OriginalStartupOutput.Boundary {
                    XCTAssertEqual(step.end,"nullCalendarRead");XCTAssertEqual(b,.nullCalendarRead(address:try XCTUnwrap(step.boundaryPC)));rejected += 1
                    XCTAssertEqual(globals,before);XCTAssertEqual(engine.calendar,prior.calendar);XCTAssertEqual(engine.music.allocations,prior.music.allocations)
                } catch let b as OriginalCalendarTime.Boundary {
                    XCTAssertEqual(b,.invalidParameter);XCTAssertEqual(step.end,"invalidParameter");rejected += 1
                    XCTAssertEqual(globals,before);XCTAssertEqual(engine.calendar,prior.calendar);XCTAssertEqual(engine.music.allocations,prior.music.allocations)
                }
                XCTAssertEqual(step.controlWord,0x37f);events += step.events.count
            }
        }
        XCTAssertEqual(c.cases.count,51);XCTAssertEqual(whole,49);XCTAssertEqual(rejected,9)
        print("StartupOutput:",whole,"whole callers",rejected,"source-stop/native rejections",events,"ordered events")
    }
    func testLateRollbackIncludesOwnCalendarAndMusicGenerations() throws {
        let c = try read(),item = try XCTUnwrap(c.cases.first { $0.spec.label == "own-repeat" })
        func blob(_ h: String) throws -> [UInt8] { let p = try XCTUnwrap(c.blobs[h]);return try MatchPreparationReference.inflate(p.deflate,count:p.count,maximumCount:200_000) }
        for phase in ["firstDate","secondDate","loadCursor","setCursor","after"] {
            var engine = OriginalStartupOutput(),globals = try OriginalStateRecord(bytes:blob(item.initialGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
            for step in item.steps.prefix(2) { try stimulate(step,&globals);var mask = [UInt8](repeating:0,count:globals.bytes.count);try execute(item,step,&engine,&globals,blob:blob,mask:&mask) }
            let step = item.steps[2];try stimulate(step,&globals);let prior = engine,before = globals;var mask = [UInt8](repeating:0,count:globals.bytes.count),reached = false
            do { try execute(item,step,&engine,&globals,blob:blob,mask:&mask,fail:phase);XCTFail("Missing late rejection") }
            catch Trial.late { reached = true }
            XCTAssertTrue(reached);XCTAssertEqual(globals,before);XCTAssertEqual(engine.calendar,prior.calendar);XCTAssertEqual(engine.music.allocations,prior.music.allocations)
        }
    }
}
