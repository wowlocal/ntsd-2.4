import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalCalendarTimeTests: XCTestCase {
    private struct Blob: Decodable { let count: Int,deflate: String }
    private struct Allocation: Decodable { let address: UInt32,count: Int,backing: String,bytes: String,mask: String }
    private struct Snapshot: Decodable {
        let allocations: [Allocation],timezone: [UInt32],cache: [UInt32],names: String
        let initialized: UInt32,osZone: UInt32,errno: Int32,tmPointer: UInt32
    }
    private struct Spec: Decodable {
        let label: String,zone: OriginalCalendarTime.Zone,tz: String?,zoneResult: UInt32?,filetime: UInt64?,output: Bool?,allocationFail: Bool?
    }
    private struct Step: Decodable {
        let kind: String,value: Int64?,before: Snapshot,after: Snapshot,events: [OriginalCalendarEvent],end: String
        let eax: UInt32,edx: UInt32,endPC: UInt32,endSP: UInt32,controlWord: UInt32,output: String?,outputMask: [UInt8]?
    }
    private struct Case: Decodable { let spec: Spec,steps: [Step] }
    private struct Corpus: Decodable { let exeSHA256: String,dllSHA256: String,cases: [Case],blobs: [String:Blob] }
    private enum Trial: Error { case late }
    private func read(transitions: Bool = false) throws -> Corpus {
        let variable = transitions ? "NTSD_CALENDAR_TRANSITIONS" : "NTSD_CALENDAR_TIME"
        let resource = transitions ? "original-calendar-transitions" : "original-calendar-time"
        let url = try ProcessInfo.processInfo.environment[variable].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:resource,withExtension:"json",subdirectory:"Fixtures"))
        return try JSONDecoder().decode(Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:500_000_000))
    }
    private func execute(_ item: Case,_ step: Step,_ state: inout OriginalCalendarTime,blob: (String) throws -> [UInt8],observe: (OriginalCalendarEvent) throws -> Void,after: (OriginalCalendarTime) throws -> Void = { _ in }) throws -> [Int32]? {
        let inputs = step.events.filter { $0.kind == "allocate" };var allocationIndex = 0
        return try state.local(try XCTUnwrap(step.value),environmentTZ:item.spec.tz.map { Array($0.utf8) },timezoneSource:{ (item.spec.zoneResult ?? 0,item.spec.zone) },allocate:{ count in
            guard allocationIndex < inputs.count else { XCTFail("Excess allocation");throw Trial.late }
            let e = inputs[allocationIndex];allocationIndex += 1;XCTAssertEqual(count,e.count)
            let address = try XCTUnwrap(e.address)
            let backing = try address == 0 ? [] : blob(XCTUnwrap(step.after.allocations.first { $0.address == address }).backing)
            return .init(address:address,backing:backing)
        },convertName:{ name,capacity in XCTAssertEqual(capacity,63);return Array(name.utf8)+[0] },observe:observe,after:after)
    }
    func testWholeClockCalendarAndOwnTimezoneCaches() throws {
        try compareCorpus(read(),cases:40,whole:9755,rejected:3)
    }
    func testEveryDeclaredDSTBoundaryNeighbor() throws {
        try compareCorpus(read(transitions:true),cases:11,whole:1089,rejected:0)
    }
    private func compareCorpus(_ corpus: Corpus,cases expectedCases: Int,whole expectedWhole: Int,rejected expectedRejected: Int) throws {
        var cache: [String:[UInt8]] = [:]
        XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.dllSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        func blob(_ h: String) throws -> [UInt8] {
            if let bytes = cache[h] { return bytes };let b = try XCTUnwrap(corpus.blobs[h]);let raw = try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:100_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(raw)),h);cache[h] = raw;return raw
        }
        func compare(_ state: OriginalCalendarTime,_ expected: Snapshot,_ label: String) throws {
            XCTAssertEqual(state.timezone.map { UInt32(bitPattern:$0) },expected.timezone,label)
            XCTAssertEqual(state.cache.map { UInt32(bitPattern:$0) },expected.cache,label)
            XCTAssertEqual(state.names,try blob(expected.names),label)
            XCTAssertEqual(state.initialized,expected.initialized != 0,label);XCTAssertEqual(state.osZone,expected.osZone != 0,label)
            XCTAssertEqual(state.errno,expected.errno,label);XCTAssertEqual(state.tmPointer,expected.tmPointer,label)
            XCTAssertEqual(state.allocations.count,expected.allocations.count,label)
            for a in expected.allocations {
                let record = try XCTUnwrap(state.allocations[a.address]);XCTAssertEqual(record.bytes,try blob(a.bytes),label)
                XCTAssertEqual(record.defined,try blob(a.mask).map { $0 == 1 },label)
            }
        }
        var whole = 0,rejected = 0,events = 0
        for item in corpus.cases {
            var state = OriginalCalendarTime()
            for step in item.steps {
                try compare(state,step.before,item.spec.label)
                let prior = state;var observed: [OriginalCalendarEvent] = []
                if step.kind == "time" {
                    var output: OriginalStateRecord? = item.spec.output == true ? try .init(bytes:[UInt8](repeating:0xa5,count:8),defined:[Bool](repeating:false,count:8)) : nil
                    let time = try OriginalCalendarTime.readClock(filetime:{ try XCTUnwrap(item.spec.filetime) },output:&output,observe:{ observed.append($0) })
                    XCTAssertEqual(time,UInt64(step.eax) | UInt64(step.edx)<<32,item.spec.label)
                    if let output { XCTAssertEqual(output.bytes.map { String(format:"%02x",$0) }.joined(),step.output);XCTAssertEqual(output.defined,step.outputMask?.map { $0 == 1 }) }
                    else { XCTAssertEqual(step.output,"a5a5a5a5a5a5a5a5");XCTAssertEqual(step.outputMask,[UInt8](repeating:0,count:8)) }
                    whole += 1
                } else {
                    do {
                        let result = try execute(item,step,&state,blob:blob,observe:{ observed.append($0) })
                        XCTAssertEqual(step.end,"returned",item.spec.label);XCTAssertEqual(result == nil,step.eax == 0,item.spec.label)
                        if let result,let allocation = step.after.allocations.first(where:{ $0.address == step.eax }) {
                            let tm = try OriginalStateRecord(bytes:blob(allocation.bytes),defined:[Bool](repeating:true,count:36))
                            XCTAssertEqual(result,try (0..<9).map { try tm.integer(at:$0*4,as:Int32.self) })
                        }
                        try compare(state,step.after,item.spec.label);whole += 1
                    } catch let boundary as OriginalCalendarTime.Boundary {
                        XCTAssertEqual(boundary == .invalidParameter ? "invalidParameter" : "unknownAllocatorReturn",step.end,item.spec.label)
                        XCTAssertEqual(state,prior);rejected += 1
                    }
                }
                XCTAssertEqual(observed,step.events,item.spec.label);events += observed.count
                if step.end == "returned" { XCTAssertEqual(step.endPC,0x30000000);XCTAssertEqual(step.endSP,0x1000f004) }
                XCTAssertEqual(step.controlWord,0x37f)
            }
        }
        XCTAssertEqual(corpus.cases.count,expectedCases);XCTAssertEqual(whole,expectedWhole);XCTAssertEqual(rejected,expectedRejected)
        print("CalendarTime:",whole,"whole returns",rejected,"source-stop/native rejections",events,"ordered requests")
    }
    func testLateCalendarRollbackAndOwnReusableBuffer() throws {
        let corpus = try read(),item = try XCTUnwrap(corpus.cases.first { $0.spec.label == "us" })
        func blob(_ h: String) throws -> [UInt8] { let b = try XCTUnwrap(corpus.blobs[h]);return try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:100_000) }
        var state = OriginalCalendarTime();let initial = state;var reached = false
        XCTAssertThrowsError(try execute(item,item.steps[0],&state,blob:blob,observe:{ e in if e.kind == "nameConversion" { reached = true;throw Trial.late } })) { XCTAssertTrue($0 is Trial) }
        XCTAssertTrue(reached);XCTAssertEqual(state,initial)
        _ = try execute(item,item.steps[0],&state,blob:blob,observe:{ _ in })
        let prior = state;reached = false
        XCTAssertThrowsError(try execute(item,item.steps[1],&state,blob:blob,observe:{ _ in },after:{ _ in reached = true;throw Trial.late })) { XCTAssertTrue($0 is Trial) }
        XCTAssertTrue(reached);XCTAssertEqual(state,prior)
    }
}
