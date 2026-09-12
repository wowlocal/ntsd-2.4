import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationLoadingPrefixTests: XCTestCase {
    typealias I = OriginalApplicationMenuInputTests
    typealias B = I.B
    typealias Loading = OriginalApplicationLoadingSession
    static let commonInputs = Result { try OriginalApplicationLoadingInputs.bundled() }
    struct Spec: Decodable { let label: String,parentIndex: Int }
    struct Record: Decodable { let bytes: String,defined: String }
    struct Wave: Decodable {
        let path: [UInt8],file: String,input: OriginalWavePlatform,outputBefore: UInt32,outputAfter: UInt32
        let beforeGlobals: String,afterGlobals: String,temporary: Record?,first: Record?,second: Record?,format: Record?,descriptor: Record?
        let temporaryLive: Bool,exit: OriginalWaveExit,returned: UInt32?,events: [OriginalWaveEvent]
    }
    struct Event: Decodable { let kind: String,event: OriginalFrontScreenEvent,globals: String }
    struct Case: Decodable {
        let spec: Spec,before: I.State,after: I.State,states: [I.Checkpoint],events: [Event],loads: [Wave]
        let commands: [String],paused: UInt32,bodySP: UInt32,end: String
    }
    struct Corpus: Decodable { let cases: [Case],blobs: [String:OriginalApplicationMessageLoopTests.Blob] }
    final class Resources {
        let c: Corpus
        var cache: [String:[UInt8]] = [:]
        init() throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_APPLICATION_LOADING_PREFIX"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-application-loading-prefix",withExtension:"json",subdirectory:"Fixtures"))
            c = try JSONDecoder().decode(Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:150_000_000))
            XCTAssertEqual(c.cases.count,12)
        }
        func blob(_ h: String) throws -> [UInt8] {
            if let b = cache[h] { return b }
            let z = try XCTUnwrap(c.blobs[h]),b = try MatchPreparationReference.inflate(z.deflate,count:z.count,maximumCount:10_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),h);cache[h] = b;return b
        }
        func check(_ actual: OriginalStateRecord?,_ expected: Record?) throws {
            XCTAssertEqual(actual == nil,expected == nil)
            guard let actual,let expected else { return }
            XCTAssertEqual(actual.bytes,try blob(expected.bytes));XCTAssertEqual(actual.defined,try blob(expected.defined).map { $0 != 0 })
        }
        func wave(_ actual: OriginalWaveLoadResult,_ expected: Wave) throws {
            XCTAssertEqual(actual.output,expected.outputAfter);XCTAssertEqual(actual.returned,expected.returned)
            XCTAssertEqual(actual.exit,expected.exit);XCTAssertEqual(actual.temporaryLive,expected.temporaryLive)
            try check(actual.temporary,expected.temporary);try check(actual.first,expected.first);try check(actual.second,expected.second)
            try check(actual.format,expected.format);try check(actual.descriptor,expected.descriptor)
        }
    }
    enum Stop: Error { case late }
    final class Adapter {
        let c: Case,r: Resources,fail: String?
        var shadow: [UInt8],mask = [UInt8](repeating:0,count:0xc3a8),index = 0,counts: [String:Int] = [:]
        init(_ c: Case,_ r: Resources,_ own: [UInt8],_ fail: String?) { self.c = c;self.r = r;shadow = own;self.fail = fail }
        func event(_ event: OriginalFrontScreenEvent,_ kind: String = "front") throws {
            guard index<c.events.count else { XCTFail("Extra event");throw Stop.late }
            let expected = c.events[index];index += 1
            XCTAssertEqual(expected.kind,kind);XCTAssertEqual(expected.event,event,c.spec.label+" event \(index)")
            XCTAssertTrue(shadow == (try r.blob(expected.globals)),c.spec.label+" event globals \(index)")
            counts[event.kind,default:0] += 1
            if event.kind == "write" {
                let offset = Int(event.arguments[0])-0x44d000,n = Int(event.arguments[1]),v = event.arguments[2]
                shadow.replaceSubrange(offset..<offset+n,with:(0..<n).map { UInt8(truncatingIfNeeded:v >> ($0*8)) })
                mask.replaceSubrange(offset..<offset+n,with:repeatElement(1,count:n))
            }
            if fail == event.kind+"#\(counts[event.kind]!)" { throw Stop.late }
        }
        func store(_ address: Int,_ bytes: [UInt8]) throws {
            let value = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
            try event(.init("write",[UInt32(address),UInt32(bytes.count),value]))
        }
    }
    @discardableResult
    func check(_ c: Case,_ r: Resources,_ own: B.OwnContext,_ pending: OriginalApplicationMenuSession.PendingLoading,responses: I.Spec,fail: String? = nil) throws -> OriginalInitialLoadingCommon? {
        let retainedBitmapInputs = try XCTUnwrap(own.bitmapInputs)
        let retainedGraphics = try XCTUnwrap(own.applicationGraphics)
        let target = pending.target
        var loading = try pending.makeLoadingSession()
        var commands: [OriginalApplicationGraphics.Command] = [],attempted = 0
        var prepared: Loading.PendingCatalog?
        var committedGraphics: OriginalApplicationGraphics?
        let caseIndex = try XCTUnwrap(r.c.cases.firstIndex { $0.spec.label == c.spec.label })
        let full = own.base.globals.bytes+own.outerAndWorldBytes
        XCTAssertTrue(full == (try r.blob(c.before.globals)));XCTAssertEqual(own.random.state,c.before.random)
        XCTAssertEqual(own.libraryText.retainedDC,c.before.retainedDC);XCTAssertEqual(target,0x31003000)
        for record in c.before.records {
            let b = try XCTUnwrap(own.base.memory.allocations[record.address]);XCTAssertEqual(b.live,record.live)
            XCTAssertEqual(b.storage.bytes,try r.blob(record.bytes));XCTAssertEqual(b.storage.defined,try r.blob(record.mask).map { $0 != 0 })
        }
        let a = Adapter(c,r,full,fail),prior = own.base.globals
        var result: OriginalInitialLoadingCommon?,reached = false
        let files = try Self.commonInputs.get()
        for wave in c.loads {
            XCTAssertEqual(try files.file(String(decoding:wave.path,as:UTF8.self)),try r.blob(wave.file))
        }
        do {
            prepared = try loading.prepareCommon(inputs:files,waves:c.loads.map(\.input),
                drawResult:responses.drawResult,presentationResult:responses.presentResult,store:a.store,
                observe:{ event in
                    switch event {
                    case .front(let event):try a.event(event)
                    case .wave(let event):try a.event(.init(event.kind.rawValue,event.arguments,event.strings),"wave")
                    }
                },graphicsObserve:{ commands.append($0) },beforeWave:{ i,path,destination,g in
                    let wave = c.loads[i]
                    XCTAssertEqual(wave.path,Array(path.utf8));XCTAssertEqual(wave.input.destination,destination)
                    XCTAssertEqual(try g.integer(at:Int(destination)-0x44d000,as:UInt32.self),wave.outputBefore)
                    XCTAssertEqual(wave.input.device,try g.integer(at:0x44eecc-0x44d000,as:UInt32.self))
            },afterPrologue:{ g,paused in
                let checkpoint = c.states[0];XCTAssertEqual(checkpoint.kind,"prologue");XCTAssertEqual(a.index,checkpoint.eventIndex)
                XCTAssertTrue(g.bytes+own.outerAndWorldBytes == (try r.blob(checkpoint.state.globals)));XCTAssertEqual(paused,c.paused == 1)
                XCTAssertEqual(c.bodySP,0x1000e43c)
            },attemptedWave:{ i,w,g in
                XCTAssertEqual(i,attempted);attempted += 1;try r.wave(w,c.loads[i])
                XCTAssertTrue(g.bytes == (try r.blob(c.loads[i].afterGlobals)))
            },afterWave:{ i,w,g in
                XCTAssertTrue(g.bytes == (try r.blob(c.loads[i].afterGlobals)))
                let checkpoint = c.states[i+1];XCTAssertEqual(checkpoint.kind,"wave");XCTAssertEqual(a.index,checkpoint.eventIndex)
                XCTAssertTrue(g.bytes+own.outerAndWorldBytes == (try r.blob(checkpoint.state.globals)))
            },beforeCatalog:{ pendingCatalog in
                let next = pendingCatalog.common
                reached = true;XCTAssertEqual(next.sounds.count,18)
                for i in 0..<2 { XCTAssertEqual(next.commands[i],try r.blob(c.commands[i])) }
                XCTAssertTrue(next.globals.bytes+own.outerAndWorldBytes == (try r.blob(c.after.globals)))
                if fail == "commit" { throw Stop.late }
            })
            result = try XCTUnwrap(prepared).common
            committedGraphics = prepared?.state.graphics
        } catch {
            if let fail { guard case Stop.late = error else { throw error };XCTAssertTrue(reached || fail != "commit") }
            else {
                XCTAssertEqual(c.end,"invalidCreateContinuation")
                guard case OriginalStateError.invalidStorage("Invalid original CreateSoundBuffer continuation") = error else { throw error }
                XCTAssertEqual(attempted,c.loads.count)
                XCTAssertEqual(c.loads.last?.exit,.invalidCreateContinuation)
            }
            XCTAssertNil(result)
        }
        XCTAssertEqual(own.bitmapInputs,retainedBitmapInputs)
        XCTAssertEqual(own.applicationGraphics,retainedGraphics)
        XCTAssertEqual(committedGraphics != nil,result != nil)
        try OriginalApplicationGraphicsTests.compare(commands,kind:"loading",index:caseIndex,stageKind:"loading",prefix:fail != nil,inputs:retainedBitmapInputs)
        if let prepared {
            XCTAssertEqual(prepared.common.sounds.count,c.loads.count)
            for (wave,expected) in zip(prepared.common.sounds,c.loads) { try r.wave(wave,expected) }
            XCTAssertEqual(prepared.common.paused,c.paused == 1)
            for i in 0..<2 { XCTAssertEqual(prepared.common.commands[i],try r.blob(c.commands[i])) }
            let encoder = JSONEncoder();encoder.outputFormatting = .sortedKeys
            XCTAssertEqual(try encoder.encode(prepared.waveInputs),try encoder.encode(c.loads.map(\.input)))
            try OriginalApplicationGraphicsTests.compareOwner(prepared.state.graphics,kind:"loading",index:caseIndex)
            XCTAssertEqual(prepared.stagedGraphics,pending.stagedGraphics+commands)
            XCTAssertEqual(prepared.state.full.bytes,try r.blob(c.after.globals))
            XCTAssertTrue(prepared.state.full.defined.allSatisfy { $0 })
            XCTAssertEqual(prepared.state.memory.allocations,pending.state.memory.allocations)
            XCTAssertEqual(prepared.state.memory.replayPointers,pending.state.memory.replayPointers)
            XCTAssertEqual(prepared.state.bitmapInputs,pending.state.bitmapInputs)
            XCTAssertEqual(prepared.state.libraryText,pending.state.libraryText)
            XCTAssertEqual(prepared.state.random,pending.state.random)
            XCTAssertEqual(prepared.state.front.bitmaps,pending.state.front.bitmaps)
            XCTAssertEqual(prepared.state.earlyScreen.bitmaps,pending.state.earlyScreen.bitmaps)
            XCTAssertEqual(prepared.state.earlyScreen.surfaces,pending.state.earlyScreen.surfaces)
            XCTAssertEqual(prepared.state.earlyScreen.retainedOperation,pending.state.earlyScreen.retainedOperation)
            XCTAssertEqual(prepared.state.screenBody,pending.state.screenBody)
            XCTAssertEqual(prepared.state.settings,pending.state.settings)
            XCTAssertEqual(prepared.target,pending.target);XCTAssertEqual(prepared.allocationBytes,81_273_768)
            var expectedOperations = pending.stagedEffects.map(Loading.Operation.menu),waveIndex = -1
            for saved in c.events {
                let event = saved.event
                if saved.kind == "wave" {
                    if event.kind == "load" { waveIndex += 1 }
                    else { expectedOperations.append(.wave(waveIndex,.init(try XCTUnwrap(OriginalWaveEvent.Kind(rawValue:event.kind)),event.arguments,event.strings))) }
                } else if event.kind == "blit" {
                    expectedOperations.append(.menu(.blit(try XCTUnwrap(event.blit),result:responses.drawResult)))
                } else if event.kind == "method" {
                    expectedOperations.append(.menu(.present(event,result:responses.presentResult)))
                }
            }
            XCTAssertEqual(prepared.stagedOperations,expectedOperations)
            var called = false
            XCTAssertThrowsError(try loading.prepareCommon(inputs:files,waves:c.loads.map(\.input),drawResult:responses.drawResult,
                presentationResult:responses.presentResult,observe:{ _ in called = true })) {
                    XCTAssertEqual($0 as? Loading.Boundary,.alreadyPrepared)
                }
            XCTAssertFalse(called)
            XCTAssertEqual(loading.pendingCatalog?.state.full,prepared.state.full)
            XCTAssertEqual(loading.pendingCatalog?.stagedOperations,prepared.stagedOperations)
            XCTAssertEqual(loading.pendingCatalog?.stagedGraphics,prepared.stagedGraphics)
        } else { XCTAssertNil(loading.pendingCatalog) }
        XCTAssertEqual(own.base.globals,prior)
        if fail == nil {
            XCTAssertEqual(attempted,c.loads.count)
            XCTAssertEqual(a.index,c.events.count);XCTAssertEqual(a.mask,try r.blob(c.after.mask))
            XCTAssertEqual(result != nil,c.end == "catalogAllocation")
        }
        return result
    }
    func run(_ indices: [Int],failures: [String?]) throws {
        let r = try Resources(),fr = try I.F.Resources(),body = try I.Body.Resources(fr),mr = try I.M.Resources(body,fr),ir = try I.Resources(mr),br = try B.Resources(),er = try B.Entry.Resources()
        for i in indices {
            for fail in failures {
                var called = false
                try I().run(r.c.cases[i].spec.parentIndex,ir,mr,body,fr,br,er,loading:{ own,pending in
                    called = true;try self.check(r.c.cases[i],r,own,pending,responses:ir.c.cases[r.c.cases[i].spec.parentIndex].spec,fail:fail)
                })
                XCTAssertTrue(called)
            }
        }
    }
    func testOwnLoadingCommonSoundsAndOrdinaryFailures() throws { try run(Array(0..<12),failures:[nil]) }
    func testLateLoadingFailuresPreserveOwnMenuAndPendingIteration() throws {
        try run([0],failures:["write#1","blit#1","copy#12","method#1","commit"])
    }
}
