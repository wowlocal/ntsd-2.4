import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Independent source-first scalar and complete rendering/audio projections at
/// every retained stage, followed by own ownership/journal and Bootstrap checks.
final class OriginalApplicationGameplayProjectionTests: XCTestCase {
    typealias P = OriginalApplicationGameplayStateProjection
    typealias L = OriginalApplicationLoadedLaunchTests
    typealias C = OriginalApplicationLoadedCycleTests
    typealias G = OriginalApplicationGameplaySession
    typealias M = OriginalApplicationLoadedMenuTests
    typealias D = OriginalApplicationGameplayDrawingProjection
    struct Environment {
        var expected: P
        let sections: [OriginalApplicationGameplaySource.Section]
        var count = 0
        var front: [OriginalFrontScreenEvent] = []
        var other: [String] = []
        var allGraphics: [OriginalApplicationCatalogGraphicsComparison.Event] = []
        var operations: [M.S.Operation] = []
    }
    static func sourceEqual(_ model: P,_ state: MatchLaunchReference.State,_ source: OriginalApplicationGameplaySource,_ label: String) throws {
        try P.same(model.pool,source.pool(state),label+" pool")
        try P.same(model.globals,source.globals(state),label+" globals")
        try P.require(model.backgrounds.count == state.backgrounds.count,label+" BG count")
        for n in model.backgrounds.indices { try P.same(model.backgrounds[n],source.record(state.backgrounds[n]),label+" BG\(n)") }
    }
    static func ownEqual(_ expected: P,_ actual: OriginalMatchPreparation,_ label: String) throws {
        let value = try P(actual)
        try P.same(value.pool,expected.pool,label+" pool")
        try P.same(value.globals,expected.globals,label+" globals")
        try P.require(value.backgrounds.count == expected.backgrounds.count,label+" BG count")
        for n in value.backgrounds.indices { try P.same(value.backgrounds[n],expected.backgrounds[n],label+" BG\(n)") }
        // Includes every Frame byte/mask and catalog/header field. Neither the
        // comparison model nor Core is allowed to replace this immutable parent.
        try P.require(actual.loadedObjects == expected.objects,label+" Object/Frame retention")
        try P.require(actual.frameAllocations == expected.ownedFrames,label+" Mutable Frame allocation retention")
    }
    func sequence(_ reverse: Bool,onComplete: ((C.A) throws -> Void)? = nil) throws {
        let source = try OriginalApplicationGameplaySource(reverse)
        _ = try OriginalApplicationLoadedSelectionTests().sequence(reverse,onStart:{ origin,pending in
            let reference = try L.R(reverse,pending)
            var app = origin,launch = try L.L(pending:pending),launchEnv = L.Environment()
            let started = try L().launch(&launch,&launchEnv,reference)
            try C.finish(&app,started)
            var expected: P?
            var sourceExpected: P?
            var checkpoints = 0,sourceStores = 0,ownStores = 0
            var sourceHeap: [MatchLaunchReference.State.Heap]?
            var heapEndpoints = 0
            for tick in 0..<17 {
                let call = source.calls[tick]
                let loading = try C.next(&app)
                var cycle = try app.makeLoadedCycle(pending:loading),input = C.InputEnvironment()
                let ready = try C.input(&cycle,&input)
                try P.require(ready.round.continuation == .gameplay,"Own gameplay continuation")
                if tick == 0 {
                    let catalog = try OriginalApplicationCatalogFullTests.reference.get()
                    for child in catalog.catalog.children where child.kind == .object {
                        try catalog.checkObject(ready.match.loadedObjects[XCTUnwrap(child.index)],child)
                    }
                    expected = try P(ready.match)
                    var cooldown = try P(ready.match)
                    try cooldown.pool.write(Int32(1),at:cooldown.actor(10)+0x338)
                    XCTAssertThrowsError(try cooldown.contacts())
                    var hit = try P(ready.match)
                    try hit.pool.write(Int32(1),at:hit.actor(0)+0x2e4)
                    XCTAssertThrowsError(try hit.hits())
                    var unknown = try P(ready.match),mask = unknown.pool.defined
                    mask[try unknown.actor(10)+0x338] = false
                    unknown.pool = try .init(bytes:unknown.pool.bytes,defined:mask)
                    XCTAssertThrowsError(try unknown.contacts())
                    var alias = try P(ready.match)
                    try alias.pool.write(UInt32(0),at:0x194+4)
                    XCTAssertThrowsError(try alias.livePair())
                    sourceExpected = try P(call.sections[0].before,source:source,objects:ready.match.loadedObjects)
                } else {
                    var retained = try XCTUnwrap(expected),saved = try XCTUnwrap(sourceExpected)
                    try Self.sourceEqual(saved,XCTUnwrap(call.beforeInput),source,"Source prior return \(tick)")
                    try saved.input(call.writes,sourceValues:true)
                    try retained.input(call.writes,sourceValues:false)
                    sourceExpected = saved;expected = retained
                }
                var saved = try XCTUnwrap(sourceExpected)
                for section in call.sections {
                    let label = "Source call \(tick) \(section.stage)"
                    for state in [section.before,section.after] {
                        if let heap = state.frameHeap {
                            if let baseline = sourceHeap {
                                try P.require(heap.count == baseline.count,label+" source Frame count")
                                for n in heap.indices {
                                    let a = heap[n],b = baseline[n]
                                    try P.require(a.address == b.address && a.kind == b.kind,label+" source Frame identity")
                                    try P.same(source.record(a.storage),source.record(b.storage),label+" source Frame \(n)")
                                }
                            } else { sourceHeap = heap }
                            heapEndpoints += 1
                        }
                    }
                    try Self.sourceEqual(saved,section.before,source,label+" before")
                    let sourceBefore = saved
                    try saved.advance(section,sourceValues:true)
                    var drawing = try D(section.before,source)
                    try drawing.validateSourcePlatform(section,source,sourceBefore)
                    let front = try drawing.stage(section.stage,sourceBefore,saved,UInt32(bitPattern:sourceBefore.g(0x455608)),installed:false)
                    try D.compare(D.sourceEvents(section),front,label+" complete front")
                    try P.require(D.sourceOther(section) == D.other(saved),label+" complete non-front")
                    try Self.sourceEqual(saved,section.after,source,label+" after")
                    sourceStores += saved.stores.count
                }
                sourceExpected = saved
                let retained = try XCTUnwrap(expected)
                try Self.ownEqual(retained,ready.match,"Own input \(tick)")
                var session = try G(pending:ready),env = Environment(expected:retained,sections:call.sections)
                env.operations = ready.operations.map(M.S.Operation.preceding)
                let drawing = try D(ready.match,ready.state)
                let graphics = try OriginalApplicationCatalogGraphicsComparison(resources:[:],state:ready.state,graphics:ready.graphics)
                let output = OriginalMenuPresentationInput(targetSurface:ready.loading.target,methodResult:0,
                    queryResult:0,audioGetResult:0,audioSetResult:0,queriedAudio:0,audioVolume:0,
                    dcResult:0,dc:0x12345678,postResult:0)
                let result = try session.advance(environment:&env,outputInput:output,observe:{ observation,e in
                    switch observation {
                    case .front(let event):e.front.append(event)
                    case .gameplay(let event):
                        switch event {
                        case .drawing,.impulses:break // The .front route is collected exactly once.
                        case .hits(.random(let stream,let range,let value)):e.other.append("random:\(stream):\(range):\(value)")
                        case .lifecycle(.catalogSound(let slot,let x,let index)):e.other.append("sound:\(slot):\(x):\(index)")
                        default:throw OriginalApplicationGameplaySource.error("Unexpected finite gameplay event \(event)")
                        }
                    case .gameplayCheckpoint(let stage,let snapshot):
                        try P.require(e.sections.indices.contains(e.count),"Extra gameplay stage")
                        let section = e.sections[e.count]
                        try P.require(stage == section.stage,"Gameplay stage order")
                        let before = e.expected
                        try e.expected.advance(section,sourceValues:false)
                        var projection = drawing
                        let events = try projection.stage(stage,before,e.expected,ready.loading.target,installed:true)
                        try D.compare(e.front,events,"Own call \(tick) \(stage)")
                        let other = D.other(e.expected)
                        try P.require(e.other == other,"Complete non-front events \(stage): \(e.other)/\(other)")
                        let journal = try D.journal(events,ready)
                        e.operations += journal.operations;e.allGraphics += journal.graphics
                        try P.require(snapshot.operations == e.operations,"Complete chronological journal \(stage)")
                        e.front = [];e.other = []
                        try Self.retained(snapshot,ready,stage)
                        try Self.ownEqual(e.expected,snapshot.match,"Own call \(tick) \(stage)")
                        try M.I.coherent(OriginalApplicationMatchBindings(pending:ready.entry),snapshot.match,snapshot.state)
                        try P.require(snapshot.match.bitmaps == ready.match.bitmaps,"Bitmap retention")
                        try P.require(snapshot.match.bitmapOwners == ready.match.bitmapOwners && snapshot.match.bitmapSurfaceOwners == ready.match.bitmapSurfaceOwners,"Bitmap owner retention")
                        try P.require(snapshot.state.random == ready.state.random,"CRT retention")
                        try P.require(snapshot.state.memory.replayPointers == ready.state.memory.replayPointers,"Replay aliases")
                        try P.require(snapshot.state.memory.allocations[L.R.replay] == ready.state.memory.allocations[L.R.replay],"Replay allocation retention")
                        ownStores += e.expected.stores.count;e.count += 1
                    default:throw OriginalApplicationGameplaySource.error("Unexpected gameplay observation")
                    }
                })
                try P.require(env.count == 19,"Complete scalar checkpoints")
                try P.require(env.front.isEmpty && env.other.isEmpty,"No observations beyond final checkpoint")
                try P.require(result.snapshot.operations == env.operations,"Whole operation journal")
                try graphics.compare(state:result.snapshot.state,graphics:result.graphics,events:env.allGraphics)
                if tick == 0 || tick == 16 {
                    // Fail after effects have accumulated, including a queued sound on
                    // the first call and a retained later call. Nothing is published.
                    for stop in ["blit","textOut","sound","commit"] where stop != "sound" || tick == 0 {
                        var failed = try G(pending:ready),buffer: [OriginalFrontScreenEvent] = []
                        XCTAssertThrowsError(try failed.advance(environment:&buffer,outputInput:output,observe:{ observation,b in
                            if case .front(let event) = observation {
                                b.append(event)
                                if event.kind == stop || (stop == "sound" && event.kind == "method" && event.arguments.count > 1 && event.arguments[1] == 0x30) {
                                    throw M.Stop.injected(stop)
                                }
                            }
                        },beforeCommit:{ _,_ in if stop == "commit" { throw M.Stop.injected(stop) } })) { XCTAssertEqual($0 as? M.Stop,.injected(stop)) }
                        XCTAssertTrue(failed.pendingReturn == nil);XCTAssertTrue(buffer.isEmpty)
                        try Self.ownEqual(retained,failed.entry.match,"Rejected call retains entry")
                        OriginalApplicationCatalogSessionTests.retained(failed.entry.state,ready.state)
                    }
                    for stop in ["time","sleep","commit"] {
                        let parent = app
                        XCTAssertThrowsError(try C.finish(&app,result,stop:stop)) { XCTAssertEqual($0 as? C.Stop,.injected(stop)) }
                        try C.unchanged(app,parent)
                    }
                }
                checkpoints += env.count;expected = env.expected
                try Self.ownEqual(env.expected,result.snapshot.match,"Whole return \(tick)")
                try C.finish(&app,result)
            }
            XCTAssertEqual(checkpoints,323)
            XCTAssertGreaterThan(heapEndpoints,0)
            print("Gameplay state/effects projection: control=\(reverse), 17 owned Bootstrap returns, \(checkpoints) source-first stages, \(sourceStores) source typed stores, \(ownStores) own typed stores, \(heapEndpoints) available source Frame endpoints; full front/non-front streams, journal, graphics owners/colors and rollback verified")
            try onComplete?(app)
        })
    }
    func testPrimaryOwnedScalarSequence() throws { try sequence(false) }
    func testControlOwnedScalarSequence() throws { try sequence(true) }
}

extension OriginalApplicationGameplayProjectionTests {
    static func retained(_ snapshot: M.S.Snapshot,_ entry: OriginalApplicationInputSession.PendingContinuation,_ stage: OriginalGameplayBody.Stage) throws {
        let a = snapshot.state,b = entry.state,bindings = try OriginalApplicationMatchBindings(pending:entry.entry)
        let actors = Set(bindings.actorTokens)
        try P.require(snapshot.local.bytes == [UInt8](repeating:0,count:0x704) && snapshot.local.defined == [Bool](repeating:false,count:0x704),"Caller local backing remains unknown")
        try P.require(Set(a.memory.allocations.keys) == Set(b.memory.allocations.keys),"All allocation identities retained")
        for (token,record) in b.memory.allocations where !actors.contains(token) {
            try P.require(a.memory.allocations[token] == record,"Unmodified non-Actor allocation \(token)")
        }
        // Globals/World/Actor aliases are checked independently by coherent().
        // Every remaining byte and defined mask belongs to the unchanged caller.
        for range in [0xb440..<0xbb00,(0xbb00+0x7d8)..<b.full.bytes.count] {
            try P.require(a.full.bytes[range] == b.full.bytes[range] && a.full.defined[range] == b.full.defined[range],"Full caller backing retention")
        }
        try P.require(a.front.bitmaps == b.front.bitmaps && a.screenBody == b.screenBody && a.settings == b.settings,"Front/settings retention")
        try P.require(a.earlyScreen.bitmaps == b.earlyScreen.bitmaps && a.earlyScreen.surfaces == b.earlyScreen.surfaces && a.earlyScreen.retainedOperation == b.earlyScreen.retainedOperation,"Early screen retention")
        try P.require(a.libraryHits == b.libraryHits && a.libraryTransforms == b.libraryTransforms && a.random == b.random,"Library/CRT owners")
        let afterText = try XCTUnwrap(OriginalGameplayBody.Stage.allCases.firstIndex(of:stage)) >= XCTUnwrap(OriginalGameplayBody.Stage.allCases.firstIndex(of:.impulses))
        try P.require(a.libraryText.retainedDC == (afterText ? 0x12345678 : b.libraryText.retainedDC),"Retained text DC")
        try P.require(a.bitmapInputs == b.bitmapInputs,"All image/color backing retained")
        try P.require(snapshot.music.allocations == entry.music.allocations && snapshot.resources.bitmaps == entry.menuResources.bitmaps && snapshot.backgrounds == entry.menuBackgrounds,"Music/resource owners")
        try P.require(snapshot.match.interface.bitmaps == entry.match.interface.bitmaps && snapshot.match.libraryCommands == entry.match.libraryCommands,"Interface/command owners")
        try P.require(snapshot.match.releasedBitmapOrder == entry.match.releasedBitmapOrder && snapshot.match.releasedBitmaps == entry.match.releasedBitmaps,"Release history")
    }
}
