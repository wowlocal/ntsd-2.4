import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveContactsTests: XCTestCase {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveContactsProjection
    typealias S = Q.S
    typealias P = Q.P
    typealias M = OriginalApplicationLoadedMenuSession
    func sequence(_ reverse: Bool,onBody: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,M.Observation) throws -> Void)? = nil,onReturn: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,OriginalApplicationLoadedMenuSession.PendingReturn) throws -> Void)? = nil) throws {
        let source = try OriginalApplicationActiveContactsSource(reverse)
        let sourceEndpoints = try source.compare()
        var previous: M.Snapshot?,next = 0,count = 0,pairs = 0,itrs = 0
        var draws: [OriginalHitEvent] = []
        try OriginalApplicationActivePhysicsTests().sequence(reverse,onBody:{ call,ready,event in
            switch event {
            case .gameplay(.links),.gameplay(.contacts):
                throw OriginalApplicationLoadedCycleTests.Stop.unexpected("Contact/link primitive effect needs extended comparison")
            case .gameplay(.hits(let value)):draws.append(value)
            case .gameplayCheckpoint(.physics,let snapshot):
                try P.require(previous == nil && next == 0 && draws.isEmpty,"Contact single physics predecessor")
                previous = snapshot
            case .gameplayCheckpoint(let stage,let snapshot) where Q.stages.contains(stage):
                try P.require(next < Q.stages.count && Q.stages[next] == stage,"Own seven contact stages ordered")
                let before = try XCTUnwrap(previous)
                var expected = try Q(before.match)
                if count == 0 && stage == .contacts {
                    var alias = expected
                    try alias.state.pool.write(UInt32(0),at:0x198)
                    XCTAssertThrowsError(try alias.advance(.contacts),"Contact finite alias needs its comparison")
                    var unknown = expected,mask = expected.state.pool.defined
                    mask[0x7d8+0xf1] = false
                    unknown.state.pool = try .init(bytes:expected.state.pool.bytes,defined:mask)
                    XCTAssertThrowsError(try unknown.advance(.contacts),"Contact causal vrest stays unknown")
                    // A known DAT kind0 ITR separates effect+2c from the old
                    // erroneous+1c read, even when invulnerability hides it.
                    var effect = expected
                    try effect.put(0,0x7c,63);try effect.put(1,0x7c,0)
                    let pointer = UInt32(bitPattern:try effect.f(0,0x130,0x7c))
                    try P.require(effect.f(0,0x128,0x7c) == 1 && effect.f(1,0x12c,0x7c) > 0 && effect.heapWord(pointer) == 0,"Discriminating known kind0 DAT input")
                    let heapIndex = try XCTUnwrap(effect.heap.firstIndex { pointer >= $0.address && UInt64(pointer)-UInt64($0.address)+0x30 <= $0.storage.bytes.count })
                    let offset = Int(pointer-effect.heap[heapIndex].address)
                    var unknownEffect = effect,effectMask = effect.heap[heapIndex].storage.defined
                    effectMask[offset+0x2c] = false
                    unknownEffect.heap[heapIndex].storage = try .init(bytes:effect.heap[heapIndex].storage.bytes,defined:effectMask)
                    XCTAssertThrowsError(try unknownEffect.rejectedPair(0,1),"Unknown effect must be read before invulnerability")
                    try effect.put(1,8,0)
                    try effect.heap[heapIndex].storage.write(Int32(4),at:offset+0x2c)
                    try effect.rejectedPair(0,1)
                    try effect.heap[heapIndex].storage.write(Int32(0),at:offset+0x2c)
                    XCTAssertThrowsError(try effect.rejectedPair(0,1),"Without effect4 or invulnerability, later filters require comparison")
                }
                if count == 0 && stage == .hits {
                    var hit = expected
                    try hit.state.pool.write(Int32(1),at:0x7d8+0x2e4)
                    XCTAssertThrowsError(try hit.advance(.hits),"Actual hit cannot become a no-op")
                    var spawn = expected
                    try spawn.state.globals.write(Int32(0),at:0x450bcc-0x44d000)
                    try spawn.state.globals.write(Int32(0),at:0x450c34-0x44d000)
                    try spawn.state.globals.write(UInt8(199),at:0x44ff90-0x44d000+1)
                    XCTAssertThrowsError(try spawn.advance(.hits),"Item spawn cannot be silently skipped")
                }
                try expected.advance(stage)
                let events: [OriginalHitEvent] = expected.random.map { [.random(stream:146,range:200,result:$0)] } ?? []
                try P.require(draws == events,"Own contact complete primitive effects")
                draws = [];pairs += expected.broadPairs;itrs += expected.filteredITRs
                let actual = try P(snapshot.match)
                try P.same(actual.pool,expected.state.pool,"Own full \(stage) pool \(call.index)")
                try P.same(actual.globals,expected.state.globals,"Own full \(stage) globals \(call.index)")
                var model = before.match
                model.world = try S.slice(expected.state.pool,0,0x7d8)
                model.actors = try (0..<400).map { try S.slice(expected.state.pool,0x7d8+$0*0x420,0x420) }
                model.globals = expected.state.globals
                try I.sameMatch(snapshot.match,model)
                var state = before.state
                try state.replace(0,expected.state.globals)
                // Fusion examines all20 cooldowns, including inactive actors.
                // Keep every corresponding current allocation in this comparison.
                for slot in 0..<400 {
                    var record = model.actors[slot]
                    let token = ready.entry.actorTokens[slot]
                    var allocation = try XCTUnwrap(state.memory.allocations[token])
                    let ordinal = try record.integer(at:0x368,as:UInt32.self),objects = ready.entry.entry.snapshot.objectTokens
                    try P.require(ordinal < objects.count,"Contact current Object ordinal")
                    try record.write(objects[Int(ordinal)],at:0x368)
                    allocation.storage = record;state.memory.allocations[token] = allocation
                }
                try I.sameState(snapshot.state,state)
                try P.require(snapshot.music.allocations == before.music.allocations && snapshot.resources.bitmaps == before.resources.bitmaps && snapshot.backgrounds == before.backgrounds,"Contact complete retained resource owners")
                try P.require(snapshot.operations == before.operations,"Contact complete caller journal")
                try P.same(snapshot.local,before.local,"Contact complete caller local record")
                next += 1
                if next == Q.stages.count { count += 1;next = 0;previous = nil }
                else { previous = snapshot }
            default:break // The ten following body stages retain their open gate.
            }
            try onBody?(call,ready,event)
        },onReturn:onReturn)
        try P.require(count == 48 && previous == nil && next == 0 && draws.isEmpty,"Complete own contact sequence")
        print("Owned active contacts comparison: control=\(reverse), \(sourceEndpoints) source endpoints, \(count*7) own endpoints, \(pairs) own broad pairs/\(itrs) rejected ITRs, 48 item RNG effects; remaining10 body stages OPEN")
    }
    func testPrimaryOwnedContactProjection() throws { try sequence(false) }
    func testControlOwnedContactProjection() throws { try sequence(true) }
}
