import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Native integration preflight. The complete differential projection is a
/// separate acceptance gate; these assertions do not claim a source whole match.
final class OriginalApplicationGameplayTests: XCTestCase {
    typealias L = OriginalApplicationLoadedLaunchTests
    typealias C = OriginalApplicationLoadedCycleTests
    typealias M = OriginalApplicationLoadedMenuTests
    typealias G = OriginalApplicationGameplaySession
    struct Environment {
        var stages: [OriginalGameplayBody.Stage] = []
        var text: [OriginalFrontScreenEvent] = []
        var draws: [Int32] = []
        var stop: String?
    }
    ///41a250 advances each non-fill animated layer even when its current frame
    /// is outside the visible interval. Recover the full record, not just a
    /// count of successful draws. Validate this formula on saved source first.
    static func backgroundAfterDraw(_ before: OriginalStateRecord) throws -> OriginalStateRecord {
        var expected = before
        let count = try before.integer(at:0x1c,as:Int32.self)
        for layer in 0..<Int(count) {
            guard try before.integer(at:0x89c+4*layer,as:UInt32.self) == 0 else { continue }
            let period = try before.integer(at:0x7ac+4*layer,as:Int32.self)
            if period > 0 {
                let counter = try before.integer(at:0x824+4*layer,as:Int32.self)
                try expected.write((counter &+ 1)%period,at:0x824+4*layer)
            }
        }
        return expected
    }
    static func verifySavedBackground(_ reverse: Bool) throws {
        let name = "original-gameplay-camera"+(reverse ? "-control" : "")
        let data = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures")))
        XCTAssertEqual(MatchPreparationReference.digest(data),reverse
            ? "53648008dddc6aa95d4c7c731491b33b97bb83f0d501f6ccd903b7f8a7bc4d00"
            : "37644de333eca58bb194173ac06de4cf7a4cd987c01777a97f60b3b5502e60a2")
        let corpus = try JSONDecoder().decode(MatchLaunchReference.Control.self,
            from:MatchPreparationReference.unpack(data,maximumCount:128_000_000))
        let section = try XCTUnwrap(corpus.cases.first)
        func bytes(_ key: String) throws -> [UInt8] {
            let blob = try XCTUnwrap(corpus.blobs[key])
            let value = try MatchPreparationReference.inflate(blob.deflate,count:blob.count,maximumCount:8_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(value)),key);return value
        }
        func record(_ value: MatchLaunchReference.Storage) throws -> OriginalStateRecord {
            try .init(bytes:bytes(value.bytes),defined:bytes(value.defined).map { $0 != 0 })
        }
        XCTAssertEqual(section.before.backgrounds.count,section.after.backgrounds.count)
        for index in section.before.backgrounds.indices {
            let before = try record(section.before.backgrounds[index]),after = try record(section.after.backgrounds[index])
            try OriginalApplicationCatalogSessionTests.same(after,index == 0 ? backgroundAfterDraw(before) : before,"Saved camera BG\(index)")
        }
    }
    func body(_ session: inout G,_ env: inout Environment,dcResult: Int32 = 0,dc: UInt32 = 0x12345678) throws -> M.S.PendingReturn {
        let entry = session.entry
        let output = OriginalMenuPresentationInput(targetSurface:entry.loading.target,methodResult:0,
            queryResult:0,audioGetResult:0,audioSetResult:0,queriedAudio:0,audioVolume:0,dcResult:dcResult,dc:dc,postResult:0)
        return try session.advance(environment:&env,outputInput:output,observe:{ observation,e in
            switch observation {
            case .front(let event):
                if ["getDC","setBackgroundMode","setBackgroundColor","releaseDC"].contains(event.kind) { e.text.append(event) }
                if event.kind == e.stop { throw M.Stop.injected(event.kind) }
            case .gameplay(.hits(.random(let stream,let range,let result))):
                XCTAssertEqual(stream,146);XCTAssertEqual(range,200);e.draws.append(result)
            case .gameplayCheckpoint(let stage,let snapshot):
                e.stages.append(stage)
                try M.I.coherent(OriginalApplicationMatchBindings(pending:entry.entry),snapshot.match,snapshot.state)
                XCTAssertEqual(snapshot.state.libraryHits.targets,entry.state.libraryHits.targets)
                let textStages: Set<OriginalGameplayBody.Stage> = [.impulses,.lifecycle,.commands,.hud,.notices,.recording,.layout,.output]
                XCTAssertEqual(snapshot.state.libraryText.retainedDC,
                    dcResult >= 0 && textStages.contains(stage) ? dc : entry.state.libraryText.retainedDC)
                if stage.rawValue == e.stop { throw M.Stop.injected(stage.rawValue) }
            default:break
            }
        },beforeCommit:{ _,e in if e.stop == "commit" { throw M.Stop.injected("commit") } })
    }
    func sequence(_ reverse: Bool) throws {
        try Self.verifySavedBackground(reverse)
        _ = try OriginalApplicationLoadedSelectionTests().sequence(reverse,onStart:{ origin,pending in
            let reference = try L.R(reverse,pending)
            var app = origin,launch = try L.L(pending:pending),launchEnv = L.Environment()
            let started = try L().launch(&launch,&launchEnv,reference)
            try C.finish(&app,started)
            let itemDraws: [Int32] = [41,87,65,127,100,34,74,186,57,100,147,129,78,131,19,136,146]
            for tick in 0..<17 {
                let parent = app,loading = try C.next(&app)
                var cycle = try app.makeLoadedCycle(pending:loading),input = C.InputEnvironment()
                let ready = try C.input(&cycle,&input)
                XCTAssertEqual(ready.round.continuation,.gameplay)
                XCTAssertEqual(ready.match.libraryCommands?.requestedObjectID,0)
                if tick == 0 {
                    for stop in ["physics","commands","releaseDC","dispatcherWrite","commit"] {
                        var failed = try G(pending:ready),attempt = Environment(stop:stop)
                        XCTAssertThrowsError(try self.body(&failed,&attempt,dc:0x1234abcd)) { XCTAssertEqual($0 as? M.Stop,.injected(stop)) }
                        XCTAssertNil(failed.pendingReturn);XCTAssertTrue(attempt.stages.isEmpty)
                        XCTAssertTrue(attempt.text.isEmpty);XCTAssertTrue(attempt.draws.isEmpty)
                        try C.unchanged(app,parent)
                    }
                }
                var session = try G(pending:ready),env = Environment()
                let result = try self.body(&session,&env)
                XCTAssertEqual(env.stages,OriginalGameplayBody.Stage.allCases)
                XCTAssertEqual(env.draws,[itemDraws[tick]])
                XCTAssertFalse(env.text.contains { $0.kind == "setBackgroundColor" })
                XCTAssertEqual(env.text.filter { $0.kind == "getDC" }.count,2)
                XCTAssertEqual(env.text.filter { $0.kind == "setBackgroundMode" }.map(\.arguments),[[0x12345678,1],[0x12345678,1]])
                if tick == 0 {
                    for response: Int32 in [-17,0] {
                        var controlled = try G(pending:ready),effects = Environment()
                        let returned = try self.body(&controlled,&effects,dcResult:response,dc:0x1234abcd)
                        XCTAssertEqual(returned.snapshot.state.libraryText.retainedDC,response < 0 ? ready.state.libraryText.retainedDC : 0x1234abcd)
                        XCTAssertEqual(returned.snapshot.match.world,result.snapshot.match.world)
                        XCTAssertTrue(returned.snapshot.match.actors == result.snapshot.match.actors)
                        XCTAssertEqual(returned.snapshot.match.globals,result.snapshot.match.globals)
                        XCTAssertEqual(effects.text.filter { $0.kind == "setBackgroundMode" }.count,response < 0 ? 0 : 2)
                        XCTAssertEqual(effects.text.filter { $0.kind == "releaseDC" }.count,response < 0 ? 0 : 2)
                    }
                }
                let state = result.snapshot.state,match = result.snapshot.match
                XCTAssertEqual(state.libraryText.retainedDC,0x12345678)
                XCTAssertEqual(state.libraryHits,ready.state.libraryHits)
                XCTAssertEqual(state.libraryTransforms,ready.state.libraryTransforms)
                XCTAssertEqual(state.random,ready.state.random)
                XCTAssertEqual(match.bitmapOwners,ready.match.bitmapOwners)
                XCTAssertEqual(match.bitmapSurfaceOwners,ready.match.bitmapSurfaceOwners)
                XCTAssertTrue(match.bitmaps == ready.match.bitmaps)
                for index in ready.match.backgrounds.indices {
                    let expected = try index == 0 ? Self.backgroundAfterDraw(ready.match.backgrounds[index]) : ready.match.backgrounds[index]
                    try OriginalApplicationCatalogSessionTests.same(match.backgrounds[index],expected,"Own gameplay BG\(index),tick\(tick)")
                }
                XCTAssertEqual(match.libraryCommands,ready.match.libraryCommands)
                XCTAssertEqual(state.memory.replayPointers,ready.state.memory.replayPointers)
                XCTAssertTrue(state.memory.allocations[L.R.replay] == ready.state.memory.allocations[L.R.replay])
                XCTAssertEqual(try match.globals.integer(at:0x450bcc-0x44d000,as:Int32.self),Int32(40+tick))
                XCTAssertEqual(try match.globals.integer(at:0x450c34-0x44d000,as:Int32.self),Int32(tick+1))
                XCTAssertEqual(try match.globals.integer(at:0x450bbc-0x44d000,as:Int32.self),Int32(tick+1))
                XCTAssertEqual(try match.world.integer(at:4,as:UInt8.self),1)
                XCTAssertEqual(try match.world.integer(at:5,as:UInt8.self),1)
                XCTAssertEqual(Array(match.world.bytes[6..<404]),[UInt8](repeating:0,count:398))
                XCTAssertThrowsError(try self.body(&session,&env))
                try C.finish(&app,result)
                XCTAssertThrowsError(try C.finish(&app,result))
                XCTAssertEqual(app.session?.state.libraryHits,state.libraryHits)
                XCTAssertEqual(app.session?.state.libraryTransforms,state.libraryTransforms)
            }
            print("Owned installed gameplay preflight:17 complete Bootstrap calls,323 body checkpoints; reverse=\(reverse). Differential acceptance remains separate.")
        })
    }
    func testOwnedInstalledGameplayThroughSeventeenReturns() throws { try sequence(false) }
    func testOwnedInstalledGameplayThroughSeventeenReturnsWithControlBacking() throws { try sequence(true) }
}
