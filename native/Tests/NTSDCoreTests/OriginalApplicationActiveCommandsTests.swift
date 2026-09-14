import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveCommandsTests: XCTestCase {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveCommandsProjection
    typealias P = Q.P
    typealias M = OriginalApplicationLoadedMenuSession
    typealias Stop = OriginalApplicationLoadedCycleTests.Stop
    func sequence(_ reverse: Bool) throws {
        let sourceCount = try OriginalApplicationActiveCommandsSource(reverse).compare()
        var predecessor: M.Snapshot?,endpoint: M.Snapshot?,count = 0
        try OriginalApplicationActiveLifecycleTests().sequence(reverse,onBody:{ call,ready,event in
            switch event {
            case .gameplayCheckpoint(.lifecycle,let snapshot):
                try P.require(predecessor == nil && endpoint == nil,"Single current lifecycle predecessor for commands")
                predecessor = snapshot
            case .gameplay where predecessor != nil:
                throw Stop.unexpected("A command gameplay effect needs independent comparison")
            case .front where predecessor != nil:
                throw Stop.unexpected("A command front effect needs independent comparison")
            case .gameplayCheckpoint(.commands,let snapshot):
                let before = try XCTUnwrap(predecessor)
                var model = try Q(before.match)
                if count == 0 { try Self.controls(model) }
                try model.advance()
                try P.require(model.cleaned == [0,1],"Own finite current command slots")
                var match = before.match
                match.world = try Q.S.slice(model.state.pool,0,0x7d8)
                match.actors = try (0..<400).map { try Q.S.slice(model.state.pool,0x7d8+$0*0x420,0x420) }
                match.globals = model.state.globals
                try I.sameMatch(snapshot.match,match)
                var state = before.state
                try state.replace(0,match.globals)
                let objects = ready.entry.entry.snapshot.objectTokens
                for slot in 0..<400 {
                    let token = ready.entry.actorTokens[slot]
                    var owner = try XCTUnwrap(state.memory.allocations[token]),record = match.actors[slot]
                    let ordinal = try record.integer(at:0x368,as:UInt32.self)
                    try P.require(owner.live && ordinal < objects.count,"Commands retain every Actor allocation/Object owner")
                    try record.write(objects[Int(ordinal)],at:0x368)
                    owner.storage = record;state.memory.allocations[token] = owner
                }
                try I.sameState(snapshot.state,state)
                try P.require(snapshot.operations == before.operations && snapshot.music.allocations == before.music.allocations && snapshot.resources.bitmaps == before.resources.bitmaps && snapshot.backgrounds == before.backgrounds,"Commands complete journal and resource owners")
                try P.same(snapshot.local,before.local,"Commands preserve caller-local provenance")
                predecessor = nil;endpoint = snapshot;count += 1
            default:break
            }
        },onReturn:{ call,ready,result in
            let snapshot = try XCTUnwrap(endpoint)
            for slot in 0..<400 where try snapshot.match.world.integer(at:4+slot,as:UInt8.self) == 0 {
                try P.same(result.snapshot.match.actors[slot],snapshot.match.actors[slot],"Whole return retains inactive command records")
                let token = ready.entry.actorTokens[slot]
                try P.require(result.snapshot.state.memory.allocations[token] == snapshot.state.memory.allocations[token],"Whole return retains inactive command allocation identity/storage")
            }
            print("Owned active commands: control=\(reverse), call=\(call.index), complete stage records/owners/journal; later5 semantics OPEN")
            endpoint = nil
        })
        try P.require(count == 48 && predecessor == nil && endpoint == nil,"Own complete commands sequence")
        print("Owned active commands comparison: control=\(reverse), \(sourceCount) source endpoints, \(count) own endpoints, no primitive effects; full tick/match/game OPEN")
    }
    static func controls(_ initial: Q) throws {
        var alias = initial;try alias.state.pool.write(UInt32(0),at:0x198)
        XCTAssertThrowsError(try alias.advance(),"Command Actor aliases require their own comparison")
        for offset in [0xe0,0xe4,0x70] {
            var unknown = initial,mask = initial.state.pool.defined;mask[initial.at(0,offset)] = false
            unknown.state.pool = try .init(bytes:initial.state.pool.bytes,defined:mask)
            XCTAssertThrowsError(try unknown.advance(),"Commands need known causal timer/Frame input")
        }
        var activity = initial,mask = initial.state.pool.defined;mask[4] = false
        activity.state.pool = try .init(bytes:initial.state.pool.bytes,defined:mask)
        XCTAssertThrowsError(try activity.advance(),"Commands need known activity")
        for address in [0x450bb8,0x450bc0,0x451160] {
            var command = initial;try command.state.globals.write(Int32(1),at:address-0x44d000)
            XCTAssertThrowsError(try command.advance(),"An active command/refill/mode cannot become a no-op")
        }
        var healing = initial;try healing.put(0,0xe0,1100)
        XCTAssertThrowsError(try healing.advance(),"Healing needs its real comparison")
        let token = UInt32(bitPattern:try initial.i(0,0x368)),at = 0x7ac+Int(try initial.i(0,0x70))*0x178
        var objects = initial.state.objects,object = try XCTUnwrap(objects[token])
        var frameMask = object.defined;frameMask[at] = false
        objects[token] = try .init(bytes:object.bytes,defined:frameMask)
        var unknownFrame = Q(.init(pool:initial.state.pool,globals:initial.state.globals,objects:objects,actorTokens:initial.state.actorTokens))
        XCTAssertThrowsError(try unknownFrame.advance(),"Commands need known current Frame state")
        try object.write(Int32(1700),at:at);objects[token] = object
        var special = Q(.init(pool:initial.state.pool,globals:initial.state.globals,objects:objects,actorTokens:initial.state.actorTokens))
        XCTAssertThrowsError(try special.advance(),"Current state1700 cannot be inferred from a source frame number")

        // Poison write-only outputs and make their masks unknown. Preserve E8's
        // other bytes and neighboring EC; cleanup must define only its outputs.
        var dirty = initial
        for offset in [0x2e4,0x2e8,0x2ec,0x2f0] { try dirty.put(0,offset,-123) }
        try dirty.state.pool.write(UInt32(0xa1b2c3d4),at:dirty.at(0,0xe8));try dirty.put(0,0xec,0x13572468)
        var defined = dirty.state.pool.defined
        for offset in [0x2e4,0x2e8,0x2ec,0x2f0] { for b in 0..<4 { defined[dirty.at(0,offset+b)] = false } }
        defined[dirty.at(0,0xeb)] = false
        dirty.state.pool = try .init(bytes:dirty.state.pool.bytes,defined:defined)
        let before = dirty.state.pool
        try dirty.advance()
        XCTAssertThrowsError(try P.same(before,dirty.state.pool,"Omitted cleanup is distinguishable"))
        try P.require([dirty.i(0,0x2e4),dirty.i(0,0x2e8),dirty.i(0,0x2ec),dirty.i(0,0x2f0)] == [0,1000,1000,1000],"Cleanup defines all four output words")
        try P.require(dirty.state.pool.integer(at:dirty.at(0,0xe8),as:UInt32.self) == 0x00b2c3d4 && dirty.i(0,0xec) == 0x13572468,"Cleanup writes byteEB, preserving adjacent bytes")
        try P.require(dirty.state.pool.defined[dirty.at(0,0xeb)],"Cleanup defines previously unknown byteEB")
        var inactive = initial,bytes = initial.state.pool.bytes,inactiveMask = initial.state.pool.defined
        let opaque = initial.at(50,0x370);bytes[opaque] ^= 0xff;inactiveMask[opaque] = false
        inactive.state.pool = try .init(bytes:bytes,defined:inactiveMask)
        try inactive.advance()
        try P.require(inactive.state.pool.bytes[opaque] == bytes[opaque] && !inactive.state.pool.defined[opaque],"Inactive allocation backing and masks survive cleanup")
    }
    func testPrimaryOwnedCommandsProjection() throws { try sequence(false) }
    func testControlOwnedCommandsProjection() throws { try sequence(true) }
}
