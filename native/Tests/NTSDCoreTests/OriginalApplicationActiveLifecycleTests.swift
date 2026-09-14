import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveLifecycleTests: XCTestCase {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveLifecycleProjection
    typealias P = Q.P
    typealias M = OriginalApplicationLoadedMenuSession
    typealias G = OriginalApplicationGameplaySession
    typealias Stop = OriginalApplicationLoadedCycleTests.Stop
    func sequence(_ reverse: Bool) throws {
        let source = try OriginalApplicationActiveLifecycleSource(reverse),sourceCount = try source.compare()
        var predecessor: M.Snapshot?,endpoint: M.Snapshot?,computed: Q?
        var events: [Q.Event] = [],fronts = 0,count = 0,constructors = 0,sounds = 0,rollback = 0
        try OriginalApplicationActiveGraphicsTests().sequence(reverse,onBody:{ call,ready,event in
            switch event {
            case .gameplayCheckpoint(.impulses,let snapshot):
                try P.require(predecessor == nil && endpoint == nil && events.isEmpty,"Single current impulse predecessor")
                predecessor = snapshot
            case .front where predecessor != nil:fronts += 1
            case .gameplay(.lifecycle(let e)):
                try P.require(predecessor != nil,"Lifecycle event belongs to its checkpoint interval")
                switch e {
                case let .reconstruct(slot,created):events.append(.init(kind:"reconstruct",slot:slot,arguments:[UInt32(created)]))
                case let .catalogSound(slot,x,index):events.append(.init(kind:"catalogSound",slot:slot,arguments:[x,index].map(UInt32.init(bitPattern:))))
                default:throw Stop.unexpected("Lifecycle random/builtin effect needs independent comparison")
                }
            case .gameplay where predecessor != nil:
                throw Stop.unexpected("Additional gameplay family inside lifecycle requires comparison")
            case .gameplayCheckpoint(.lifecycle,let snapshot):
                let before = try XCTUnwrap(predecessor)
                var model = try Q(before.match)
                let initial = model
                try model.advance()
                if count == 0 { try Self.inputControls(initial) }
                if !model.created.isEmpty { try Self.transientControls(initial,model) }
                try P.require(events == model.events && fronts == 0,"Own full lifecycle primitive effects, no front route")
                var expected = before.match
                expected.world = try Q.S.slice(model.state.pool,0,0x7d8)
                expected.actors = try (0..<400).map { try Q.S.slice(model.state.pool,0x7d8+$0*0x420,0x420) }
                expected.globals = model.state.globals
                try I.sameMatch(snapshot.match,expected)
                var state = before.state
                try state.replace(0,expected.globals)
                let objects = ready.entry.entry.snapshot.objectTokens
                for slot in 0..<400 {
                    let token = ready.entry.actorTokens[slot]
                    var allocation = try XCTUnwrap(state.memory.allocations[token]),record = expected.actors[slot]
                    let ordinal = try record.integer(at:0x368,as:UInt32.self)
                    try P.require(allocation.live && ordinal < objects.count,"Lifecycle retained current Actor allocation/Object owner")
                    try record.write(objects[Int(ordinal)],at:0x368)
                    allocation.storage = record;state.memory.allocations[token] = allocation
                }
                try I.sameState(snapshot.state,state)
                try P.require(snapshot.operations == before.operations,"Lifecycle chronological journal has no external IO yet")
                try P.require(snapshot.music.allocations == before.music.allocations && snapshot.resources.bitmaps == before.resources.bitmaps && snapshot.backgrounds == before.backgrounds,"Lifecycle retains all resource owners")
                try P.same(snapshot.local,before.local,"Lifecycle caller local provenance")
                endpoint = snapshot;computed = model;predecessor = nil;events = []
                count += 1;constructors += model.created.count;sounds += model.events.filter { $0.kind == "catalogSound" }.count
            default:break
            }
        },onReturn:{ call,ready,result in
            let snapshot = try XCTUnwrap(endpoint),model = try XCTUnwrap(computed)
            if !model.created.isEmpty {
                rollback += try Self.rollback(ready,result,snapshot,model.created)
                // Deactivation does not release or erase the owned allocation.
                for slot in model.created {
                    try P.same(result.snapshot.match.actors[slot],snapshot.match.actors[slot],"Whole return retains inactive lifecycle Actor")
                    let token = ready.entry.actorTokens[slot]
                    try P.require(result.snapshot.state.memory.allocations[token] == snapshot.state.memory.allocations[token],"Whole return retains inactive Actor owner")
                }
            }
            print("Owned active lifecycle: control=\(reverse), call=\(call.index), scheduled=\(model.scheduled), created=\(model.created), removed=\(model.removed), events=\(model.events); complete stage records/owners/journal, later6 semantics OPEN")
            endpoint = nil;computed = nil
        })
        try P.require(count == 48 && constructors == 1 && sounds == 7 && rollback == 4 && predecessor == nil && endpoint == nil && computed == nil && events.isEmpty,"Own complete lifecycle sequence")
        print("Owned active lifecycle comparison: control=\(reverse), \(sourceCount) source endpoints, \(count) own endpoints, \(constructors) transient, \(sounds) sounds, \(rollback) late rollbacks and 1 same-session retry; full tick/match/game OPEN")
    }
    static func inputControls(_ initial: Q) throws {
        var alias = initial;try alias.state.pool.write(UInt32(0),at:0x198)
        XCTAssertThrowsError(try alias.advance(),"Lifecycle unknown Actor alias contract")
        var unknown = initial,mask = initial.state.pool.defined
        mask[initial.at(0,0x70)] = false
        unknown.state.pool = try .init(bytes:initial.state.pool.bytes,defined:mask)
        XCTAssertThrowsError(try unknown.advance(),"Lifecycle current Frame is a causal input")
        var commands = initial
        for (at,value): (Int,Int32) in [(0x40c,9),(0x410,0),(0x414,9),(0x418,0)] { try commands.put(0,at,value) }
        XCTAssertThrowsError(try commands.advance(),"Real team command cannot become an empty event")
    }
    static func transientControls(_ initial: Q,_ baseline: Q) throws {
        let slot = try XCTUnwrap(baseline.created.first)
        try P.require(baseline.scheduled.contains(slot) && baseline.removed == baseline.created && baseline.state.pool.integer(at:4+slot,as:UInt8.self) == 0,"New later slot schedules and deactivates inside the same pass")
        let token = UInt32(bitPattern:try baseline.i(slot,0x368)),header = try XCTUnwrap(initial.state.objects[token])
        var objects = initial.state.objects,unknownHeader = header.defined
        unknownHeader[0x90] = false
        objects[token] = try .init(bytes:header.bytes,defined:unknownHeader)
        let original = initial.state
        var unknown = Q(.init(pool:original.pool,globals:original.globals,objects:objects,actorTokens:original.actorTokens),objects:initial.objectOrder)
        XCTAssertThrowsError(try unknown.advance(),"Opoint header90 must define retained Actor31c")
        var fraction = initial;try fraction.number(0,0x68,Double(initial.i(0,0x18)));try fraction.advance()
        XCTAssertThrowsError(try P.same(fraction.state.pool,baseline.state.pool,"Fractional child depth survives conversion"))
        var facing = initial;try facing.byte(0,0x80,1-initial.b(0,0x80));try facing.advance()
        XCTAssertThrowsError(try P.same(facing.state.pool,baseline.state.pool,"Opoint center/facing and signed-zero velocity"))
        var wait = initial;try wait.put(0,0x74,initial.i(0,0x70));try wait.put(0,0x88,-1);try wait.advance()
        try P.require(wait.created.isEmpty,"Scheduled current Frame, not stale Frame, supplies opoint")
        var backing = initial
        let offset = initial.at(slot,0x370),old = backing.state.pool.bytes[offset]
        var bytes = backing.state.pool.bytes;bytes[offset] = old ^ 0xff
        backing.state.pool = try .init(bytes:bytes,defined:backing.state.pool.defined)
        try backing.advance()
        try P.require(backing.state.pool.bytes[offset] == old ^ 0xff && backing.state.pool.defined[offset] == initial.state.pool.defined[offset],"Untouched inactive backing/mask survives construction and removal")
        XCTAssertThrowsError(try P.same(backing.state.pool,baseline.state.pool,"Do not discard inactive retained backing"))
        var zero = baseline
        try zero.number(slot,0x40,0.0)
        try P.require(baseline.state.pool.integer(at:baseline.at(slot,0x40),as:UInt64.self) == 0x8000000000000000,"Inherited facing keeps negative zero")
        XCTAssertThrowsError(try P.same(zero.state.pool,baseline.state.pool,"Signed zero belongs to complete stored record"))
    }
    struct RollbackEnvironment: Equatable { var constructions = 0,sounds = 0,observations = 0 }
    static func rollback(_ ready: OriginalApplicationInputSession.PendingContinuation,_ returned: M.PendingReturn,_ life: M.Snapshot,_ created: [Int]) throws -> Int {
        let input = OriginalMenuPresentationInput(targetSurface:ready.loading.target,methodResult:0,queryResult:0,audioGetResult:0,audioSetResult:0,queriedAudio:0,audioVolume:0,dcResult:0,dc:0x12345678,postResult:0)
        var session = try G(pending:ready)
        for stop in ["after-create","after-sound","lifecycle","commit"] {
            var env = RollbackEnvironment()
            XCTAssertThrowsError(try session.advance(environment:&env,outputInput:input,observe:{ event,e in
                e.observations += 1
                switch event {
                case .gameplay(.lifecycle(.reconstruct)):e.constructions += 1
                case .gameplay(.lifecycle(.catalogSound)) where e.constructions > 0:
                    e.sounds += 1
                    if (stop == "after-create" && e.sounds == 1) || (stop == "after-sound" && e.sounds == 2) { throw Stop.injected(stop) }
                case .gameplayCheckpoint(.lifecycle,let snapshot) where stop == "lifecycle":
                    try I.sameMatch(snapshot.match,life.match);try I.sameState(snapshot.state,life.state)
                    for slot in created { try P.require(snapshot.match.world.integer(at:4+slot,as:UInt8.self) == 0,"Rollback after actual same-pass deactivation") }
                    throw Stop.injected(stop)
                default:break
                }
            },beforeCommit:{ _,_ in if stop == "commit" { throw Stop.injected(stop) } })) { XCTAssertEqual($0 as? Stop,.injected(stop)) }
            try P.require(env == RollbackEnvironment() && session.pendingReturn == nil,"Whole lifecycle failure retains no buffered effects or pending return")
            try I.sameState(session.entry.state,ready.state);try I.sameMatch(session.entry.match,ready.match)
        }
        var retry = RollbackEnvironment()
        let result = try session.advance(environment:&retry,outputInput:input)
        try I.sameState(result.snapshot.state,returned.snapshot.state);try I.sameMatch(result.snapshot.match,returned.snapshot.match)
        try P.require(result.graphics == returned.graphics && result.snapshot.operations == returned.snapshot.operations && result.snapshot.music.allocations == returned.snapshot.music.allocations && result.snapshot.resources.bitmaps == returned.snapshot.resources.bitmaps && result.snapshot.backgrounds == returned.snapshot.backgrounds,"Same-session retry preserves full journal/commands/resources")
        try P.same(result.snapshot.local,returned.snapshot.local,"Same-session retry caller record")
        return 4
    }
    func testPrimaryOwnedLifecycleProjection() throws { try sequence(false) }
    func testControlOwnedLifecycleProjection() throws { try sequence(true) }
}
