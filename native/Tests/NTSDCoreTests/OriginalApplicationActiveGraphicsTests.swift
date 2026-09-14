import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveGraphicsTests: XCTestCase {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveGraphicsProjection
    typealias P = Q.P
    typealias D = Q.D
    typealias M = OriginalApplicationLoadedMenuSession
    typealias G = OriginalApplicationCatalogGraphicsComparison
    struct Endpoint {
        let state: OriginalApplicationMenuSession.State
        let events: [G.Event]
    }
    func sequence(_ reverse: Bool,onBody: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,M.Observation) throws -> Void)? = nil,onReturn: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,OriginalApplicationLoadedMenuSession.PendingReturn) throws -> Void)? = nil) throws {
        let source = try OriginalApplicationActiveGraphicsSource(reverse),sourceCount = try source.compare()
        var previous: M.Snapshot?,front: [OriginalFrontScreenEvent] = [],endpoints: [Endpoint] = []
        var computedGraphics: [G.Event] = [],wholeRelations: [G.Event] = []
        var stageIndex = 0,count = 0,events = 0,unknown = 0
        try OriginalApplicationActiveContactsTests().sequence(reverse,onBody:{ call,ready,observation in
            switch observation {
            case .front(let e):front.append(e)
            case .gameplay(.drawing),.gameplay(.impulses):break // One .front route only.
            case .gameplayCheckpoint(.attachments,let snapshot):
                try P.require(previous == nil && stageIndex == 0 && endpoints.isEmpty && front.isEmpty && computedGraphics.isEmpty && wholeRelations.isEmpty,"Single graphics predecessor with no earlier graphics effects")
                previous = snapshot
            case .gameplayCheckpoint(let stage,let snapshot) where Q.stages.contains(stage):
                try P.require(stageIndex < 3 && Q.stages[stageIndex] == stage,"Own consecutive graphics stages")
                let before = try XCTUnwrap(previous)
                var model = try Q(before.match,before.state)
                if count == 0 { try Self.controls(model,stage,ready.loading.target) }
                try model.advance(stage,ready.loading.target,true)
                try D.compare(front,model.drawing.events,"Own full active graphics \(call.index) \(stage)")
                let journal = try D.journal(model.drawing.events,ready)
                try P.require(snapshot.operations == before.operations+journal.operations,"Own complete chronological graphics journal")
                computedGraphics += journal.graphics;wholeRelations += journal.graphics
                endpoints.append(.init(state:snapshot.state,events:computedGraphics))
                events += front.count;unknown += front.filter { $0.read?.defined == false }.count;front = []
                var expected = before.match
                expected.world = try Q.S.slice(model.state.pool,0,0x7d8)
                expected.actors = try (0..<400).map { try Q.S.slice(model.state.pool,0x7d8+$0*0x420,0x420) }
                expected.globals = model.state.globals;expected.backgrounds = model.backgrounds
                try I.sameMatch(snapshot.match,expected)
                var state = before.state
                try state.replace(0,expected.globals)
                for slot in 0..<400 {
                    let token = ready.entry.actorTokens[slot]
                    var allocation = try XCTUnwrap(state.memory.allocations[token]),record = expected.actors[slot]
                    let ordinal = try record.integer(at:0x368,as:UInt32.self),objects = ready.entry.entry.snapshot.objectTokens
                    try P.require(ordinal < objects.count,"Graphics current Object ordinal")
                    try record.write(objects[Int(ordinal)],at:0x368)
                    allocation.storage = record;state.memory.allocations[token] = allocation
                }
                if stage == .impulses { state.libraryText = .init(retainedDC:0x12345678) }
                // The full graphics owner is checked independently with actual
                // PendingReturn command prefixes below. Compare every other
                // state field here without importing a graphics after-state.
                var nonGraphics = snapshot.state;nonGraphics.graphics = state.graphics
                try I.sameState(nonGraphics,state)
                try P.require(snapshot.music.allocations == before.music.allocations && snapshot.resources.bitmaps == before.resources.bitmaps && snapshot.backgrounds == before.backgrounds,"Graphics complete retained music/menu/BG owners")
                try P.same(snapshot.local,before.local,"Graphics complete unknown caller local record")
                previous = snapshot;stageIndex += 1
            case .gameplayCheckpoint:
                // Outside the selected stages, these observations only check
                // command/owner relations. They are not expected game behavior.
                let relations = try D.journal(front,ready)
                wholeRelations += relations.graphics;front = []
            default:break
            }
            try onBody?(call,ready,observation)
        },onReturn:{ call,ready,result in
            try P.require(stageIndex == 3 && endpoints.count == 3 && front.isEmpty,"Whole graphics observation boundaries")
            for endpoint in endpoints {
                let graphics = try G(resources:[:],state:ready.state,graphics:ready.graphics)
                let end = ready.graphics.count+endpoint.events.count
                try P.require(result.graphics.count >= end,"Actual graphics prefix exists")
                try graphics.compare(state:endpoint.state,graphics:Array(result.graphics.prefix(end)),events:endpoint.events)
            }
            // Covers the full command extent, so a spurious command at a stage
            // boundary cannot disappear beyond a sliced prefix. Late event
            // positions remain unaccepted, but their binding is checked.
            let relations = try G(resources:[:],state:ready.state,graphics:ready.graphics)
            try relations.compare(state:result.snapshot.state,graphics:result.graphics,events:wholeRelations)
            count += 1;previous = nil;stageIndex = 0;endpoints = [];computedGraphics = [];wholeRelations = []
            print("Owned active graphics: control=\(reverse), call=\(call.index), 3 independent endpoints, complete command extent and retained owners; later7 semantics OPEN")
            try onReturn?(call,ready,result)
        })
        try P.require(count == 48 && stageIndex == 0 && previous == nil && endpoints.isEmpty && front.isEmpty,"Complete own active graphics schedule")
        print("Owned active graphics comparison: control=\(reverse), \(sourceCount) source endpoints, \(count*3) own endpoints, \(events) own events, \(unknown) undefined bitmap observations; full tick/match/game OPEN")
    }
    static func controls(_ initial: Q,_ stage: OriginalGameplayBody.Stage,_ target: UInt32) throws {
        var expected = initial;try expected.advance(stage,target,true)
        switch stage {
        case .camera:
            var alias = initial;try alias.state.pool.write(UInt32(0),at:0x198)
            XCTAssertThrowsError(try alias.advance(stage,target,true),"Camera unknown alias contract")
            var unknown = initial,mask = initial.state.globals.defined
            mask[0x450bc8-0x44d000] = false
            unknown.state.globals = try .init(bytes:initial.state.globals.bytes,defined:mask)
            XCTAssertThrowsError(try unknown.advance(stage,target,true),"Camera causal velocity remains unknown")
            // The real first own positions both clamp the target to zero.
            // Move only this comparison trial across the camera's two target
            // directions, including smoothing, so facing is discriminating.
            var camera = initial
            for slot in 0..<2 {
                try camera.state.pool.writeBinary64(500,at:camera.at(slot,0x58))
                try camera.put(slot,0x10,500)
            }
            try camera.state.globals.write(Int32(130),at:0x450bc4-0x44d000)
            try camera.state.globals.write(Int32(0),at:0x450bc8-0x44d000)
            var baseline = camera;try baseline.advance(stage,target,true)
            var facing = camera;try facing.state.pool.write(Int8(0),at:facing.at(0,0x80));try facing.advance(stage,target,true)
            XCTAssertThrowsError(try P.same(facing.state.globals,baseline.state.globals,"Camera facing look-ahead control"))
        case .drawing:
            // Supply a comparison-only visible airborne trial from current own
            // records. It is never passed to the Native game or source reader.
            var trial = initial
            for slot in 0..<2 { try trial.put(slot,8,0) }
            try trial.put(0,0x14,-13)
            var baseline = trial;try baseline.advance(stage,target,true)
            var grounded = trial;try grounded.put(0,0x14,0);try grounded.advance(stage,target,true)
            XCTAssertThrowsError(try D.compare(grounded.drawing.events,baseline.drawing.events,"Airborne sprite destination"))
            var facing = trial;try facing.state.pool.write(Int8(0),at:facing.at(0,0x80));try facing.advance(stage,target,true)
            XCTAssertThrowsError(try D.compare(facing.drawing.events,baseline.drawing.events,"Normal width and mirrored sheet"))
            var depth = trial;try depth.put(0,0x18,530);try depth.advance(stage,target,true)
            XCTAssertThrowsError(try D.compare(depth.drawing.events,baseline.drawing.events,"Current integer depth ordering"))
            var effect = trial;try effect.put(0,0x36c,1)
            XCTAssertThrowsError(try effect.advance(stage,target,true),"Sparks cannot be silently skipped")
            var read = baseline.drawing.events
            let index = try XCTUnwrap(read.firstIndex { $0.read?.defined == false })
            let old = try XCTUnwrap(read[index].read)
            read[index].read = .init(offset:old.offset,value:old.value,defined:true)
            XCTAssertThrowsError(try D.compare(read,baseline.drawing.events,"Unknown bitmap provenance"))
        case .impulses:
            var pending = initial
            try pending.state.pool.writeBinary64(-0.0,at:pending.at(0,0x28))
            try pending.advance(stage,target,true)
            try P.require(pending.state.pool.bytes[pending.at(0,0x28)..<pending.at(0,0x28)+8].allSatisfy { $0 == 0 },"Impulse count0 clears positive zero")
            var stopped = initial;try stopped.put(0,0xb4,1)
            try stopped.state.pool.writeBinary64(3,at:stopped.at(0,0x28));try stopped.advance(stage,target,true)
            try P.require(stopped.d(0,0x28) == 3,"Hitstop preserves pending impulses")
            var count = initial;try count.put(0,0x20,1)
            XCTAssertThrowsError(try count.advance(stage,target,true),"Nonzero impulse requires comparison extension")
            var diagnostic = initial;try diagnostic.state.pool.write(Int8(-2),at:diagnostic.at(10,0xc4));try diagnostic.advance(stage,target,true)
            XCTAssertThrowsError(try D.compare(diagnostic.drawing.events,expected.drawing.events,"Inactive diagnostic signed byte"))
        default:throw OriginalApplicationGameplaySource.error("Unknown graphics control stage")
        }
    }
    func testPrimaryOwnedGraphicsProjection() throws { try sequence(false) }
    func testControlOwnedGraphicsProjection() throws { try sequence(true) }
}
