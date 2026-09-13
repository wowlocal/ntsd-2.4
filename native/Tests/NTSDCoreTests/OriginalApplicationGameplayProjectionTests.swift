import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Full scalar records at every retained stage. Graphics/audio effects and the
/// complete differential acceptance remain a separate, explicitly open gate.
final class OriginalApplicationGameplayProjectionTests: XCTestCase {
    typealias P = OriginalApplicationGameplayStateProjection
    typealias L = OriginalApplicationLoadedLaunchTests
    typealias C = OriginalApplicationLoadedCycleTests
    typealias G = OriginalApplicationGameplaySession
    typealias M = OriginalApplicationLoadedMenuTests
    struct Environment {
        var expected: P
        let sections: [OriginalApplicationGameplaySource.Section]
        var count = 0
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
    func sequence(_ reverse: Bool) throws {
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
                    try saved.advance(section,sourceValues:true)
                    try Self.sourceEqual(saved,section.after,source,label+" after")
                    sourceStores += saved.stores.count
                }
                sourceExpected = saved
                let retained = try XCTUnwrap(expected)
                try Self.ownEqual(retained,ready.match,"Own input \(tick)")
                var session = try G(pending:ready),env = Environment(expected:retained,sections:call.sections)
                let output = OriginalMenuPresentationInput(targetSurface:ready.loading.target,methodResult:0,
                    queryResult:0,audioGetResult:0,audioSetResult:0,queriedAudio:0,audioVolume:0,
                    dcResult:0,dc:0x12345678,postResult:0)
                let result = try session.advance(environment:&env,outputInput:output,observe:{ observation,e in
                    if case .gameplayCheckpoint(let stage,let snapshot) = observation {
                        try P.require(e.sections.indices.contains(e.count),"Extra gameplay stage")
                        let section = e.sections[e.count]
                        try P.require(stage == section.stage,"Gameplay stage order")
                        try e.expected.advance(section,sourceValues:false)
                        try Self.ownEqual(e.expected,snapshot.match,"Own call \(tick) \(stage)")
                        try M.I.coherent(OriginalApplicationMatchBindings(pending:ready.entry),snapshot.match,snapshot.state)
                        try P.require(snapshot.match.bitmaps == ready.match.bitmaps,"Bitmap retention")
                        try P.require(snapshot.match.bitmapOwners == ready.match.bitmapOwners && snapshot.match.bitmapSurfaceOwners == ready.match.bitmapSurfaceOwners,"Bitmap owner retention")
                        try P.require(snapshot.state.random == ready.state.random,"CRT retention")
                        try P.require(snapshot.state.memory.replayPointers == ready.state.memory.replayPointers,"Replay aliases")
                        try P.require(snapshot.state.memory.allocations[L.R.replay] == ready.state.memory.allocations[L.R.replay],"Replay allocation retention")
                        ownStores += e.expected.stores.count;e.count += 1
                    }
                })
                try P.require(env.count == 19,"Complete scalar checkpoints")
                checkpoints += env.count;expected = env.expected
                try Self.ownEqual(env.expected,result.snapshot.match,"Whole return \(tick)")
                try C.finish(&app,result)
            }
            XCTAssertEqual(checkpoints,323)
            XCTAssertGreaterThan(heapEndpoints,0)
            print("Gameplay scalar projection: control=\(reverse), 17 owned Bootstrap returns, \(checkpoints) source-first stages, \(sourceStores) source typed stores, \(ownStores) own typed stores, \(heapEndpoints) available source Frame endpoints; graphics/audio differential acceptance remains open")
        })
    }
    func testPrimaryOwnedScalarSequence() throws { try sequence(false) }
    func testControlOwnedScalarSequence() throws { try sequence(true) }
}
