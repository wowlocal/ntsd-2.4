import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationActiveHUDTests: XCTestCase {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias Q = OriginalApplicationActiveHUDProjection
    typealias P = Q.P
    typealias D = Q.D
    typealias M = OriginalApplicationLoadedMenuSession
    typealias G = OriginalApplicationCatalogGraphicsComparison
    typealias Stop = OriginalApplicationLoadedCycleTests.Stop
    func sequence(_ reverse: Bool,onBody: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,M.Observation) throws -> Void)? = nil,onReturn: ((ContinuousGameplayReference.Case,OriginalApplicationInputSession.PendingContinuation,M.PendingReturn) throws -> Void)? = nil) throws {
        let sourceCount = try OriginalApplicationActiveHUDSource(reverse).compare()
        var before: M.Snapshot?,endpoint: M.Snapshot?
        var earlier: [OriginalFrontScreenEvent] = [],front: [OriginalFrontScreenEvent] = [],prefix: [G.Event] = []
        var count = 0,events = 0,unknown = 0,rollbacks = 0
        try OriginalApplicationActiveCommandsTests().sequence(reverse,onBody:{ call,ready,event in
            switch event {
            case .front(let value):
                if before != nil { front.append(value) }
                else if endpoint == nil { earlier.append(value) }
            case .gameplayCheckpoint(.commands,let snapshot):
                try P.require(before == nil && endpoint == nil && front.isEmpty && prefix.isEmpty,"Single current HUD predecessor")
                before = snapshot
                // Earlier event semantics are compared by the parent graphics
                // chain; here they locate this stage in the actual whole journal.
                prefix = try D.journal(earlier,ready).graphics;earlier = []
            case .gameplay(.drawing(.hud,_)):
                try P.require(before != nil && endpoint == nil,"HUD family belongs only to the commands/HUD interval")
                break // Compare its one .front route.
            case .gameplay where before != nil:
                throw Stop.unexpected("Additional HUD gameplay family")
            case .gameplayCheckpoint(.hud,let snapshot):
                let previous = try XCTUnwrap(before)
                var model = try Q(previous.match,previous.state)
                if count == 0 { try Self.controls(model) }
                try model.advance()
                try P.require(model.selected == [0,1],"Own finite HUD participants")
                try D.compare(front,model.drawing.events,"Own full current HUD events")
                let journal = try D.journal(model.drawing.events,ready)
                try P.require(snapshot.operations == previous.operations+journal.operations,"HUD complete chronological journal")
                prefix += journal.graphics
                var expected = previous.match;expected.globals = model.state.globals
                try P.same(model.state.pool,Q.S(previous.match).pool,"HUD preserves all Actor/World backing and masks")
                try I.sameMatch(snapshot.match,expected)
                var state = previous.state;try state.replace(0,expected.globals)
                // Independently check the full graphics owner at PendingReturn
                // against the derived command prefix, not an imported after-state.
                var nonGraphics = snapshot.state;nonGraphics.graphics = state.graphics
                try I.sameState(nonGraphics,state)
                try P.require(snapshot.music.allocations == previous.music.allocations && snapshot.resources.bitmaps == previous.resources.bitmaps && snapshot.backgrounds == previous.backgrounds,"HUD complete retained resource owners")
                try P.same(snapshot.local,previous.local,"HUD caller-local provenance")
                count += 1;events += front.count;unknown += front.filter { $0.read?.defined == false }.count
                before = nil;endpoint = snapshot;front = []
            default:break
            }
            try onBody?(call,ready,event)
        },onReturn:{ call,ready,result in
            let snapshot = try XCTUnwrap(endpoint)
            let relation = try G(resources:[:],state:ready.state,graphics:ready.graphics)
            let end = ready.graphics.count+prefix.count
            try P.require(result.graphics.count >= end,"HUD complete returned graphics prefix")
            try relation.compare(state:snapshot.state,graphics:Array(result.graphics.prefix(end)),events:prefix)
            // Parent verifies the complete returned graphics extent, including
            // later observations, without claiming their unaccepted semantics.
            if count == 1 { rollbacks += try Self.rollback(ready,result,snapshot) }
            print("Owned active HUD: control=\(reverse), call=\(call.index), complete stage records/events/owners/journal; later4 semantics OPEN")
            endpoint = nil;prefix = []
            try onReturn?(call,ready,result)
        })
        try P.require(count == 48 && rollbacks == 3 && before == nil && endpoint == nil && front.isEmpty && earlier.isEmpty && prefix.isEmpty,"Own complete HUD sequence")
        print("Owned active HUD comparison: control=\(reverse), \(sourceCount) source endpoints, \(count) own endpoints, \(events) own events, \(unknown) undefined reads, \(rollbacks) late rollbacks and 1 same-session retry; full tick/match/game OPEN")
    }
    static func controls(_ initial: Q) throws {
        var baseline = initial;try baseline.advance()
        var dirty = initial,mask = dirty.state.globals.defined
        for address in [0x450bc0,0x450bb8] {
            try dirty.state.globals.write(Int32(-123),at:address-0x44d000)
            for b in 0..<4 { mask[address-0x44d000+b] = false }
        }
        dirty.state.globals = try .init(bytes:dirty.state.globals.bytes,defined:mask)
        try dirty.advance();try P.same(dirty.state.globals,baseline.state.globals,"HUD defines write-only command flags")
        for offset in [0x2fc,0x300,0x308,0x364,0x368] {
            var unknown = initial,m = unknown.state.pool.defined;m[unknown.at(0,offset)] = false
            unknown.state.pool = try .init(bytes:unknown.state.pool.bytes,defined:m)
            XCTAssertThrowsError(try unknown.advance(),"HUD needs known causal Actor input")
        }
        var mp = initial;try mp.put(0,0x308,-501);try mp.advance()
        XCTAssertThrowsError(try D.compare(mp.drawing.events,baseline.drawing.events,"HUD current signed MP width"))
        try P.require(mp.drawing.events.contains { $0.kind == "rectangle" && $0.arguments[2] == 0 && Int32(bitPattern:$0.arguments[3]) == (-501 &* 31)/125 },"Negative HUD width is not clamped")
        var maximum = initial;try maximum.put(0,0x304,123);try maximum.advance()
        try D.compare(maximum.drawing.events,baseline.drawing.events,"HUD widths do not depend on maxHP")
        var dead = initial;try dead.put(0,0x2fc,0)
        var deadMask = dead.state.pool.defined;deadMask[dead.at(0,0x308)] = false
        dead.state.pool = try .init(bytes:dead.state.pool.bytes,defined:deadMask);try dead.advance()
        try P.require(dead.drawing.events.filter { $0.kind == "rectangle" }.count == 4,"Dead Actor skips all bars and unread MP")
        var alias = initial;try alias.state.pool.write(UInt32(0),at:0x198);try alias.advance()
        try P.require(alias.selected == [0,0] && alias.drawing.events.filter { $0.kind == "draw" }.count == 12,"HUD aliases are not deduplicated")
        var fallback = initial
        try fallback.state.pool.write(UInt8(0),at:4);try fallback.state.pool.write(UInt8(2),at:14)
        try fallback.state.pool.write(UInt32(0),at:0x194+10*4);try fallback.advance()
        try D.compare(fallback.drawing.events,baseline.drawing.events,"HUD nonzero fallback activity uses current mapping")
        var opaque = baseline.drawing.events
        let n = try XCTUnwrap(opaque.firstIndex { $0.read?.defined == false }),old = try XCTUnwrap(opaque[n].read)
        opaque[n].read = .init(offset:old.offset,value:old.value,defined:true)
        XCTAssertThrowsError(try D.compare(opaque,baseline.drawing.events,"Unknown bitmap read remains unknown"))
    }
    struct Environment: Equatable { var inHUD = false,blits = 0,observations = 0 }
    static func rollback(_ ready: OriginalApplicationInputSession.PendingContinuation,_ returned: M.PendingReturn,_ hud: M.Snapshot) throws -> Int {
        let input = OriginalMenuPresentationInput(targetSurface:ready.loading.target,methodResult:0,queryResult:0,audioGetResult:0,audioSetResult:0,queriedAudio:0,audioVolume:0,dcResult:0,dc:0x12345678,postResult:0)
        var session = try OriginalApplicationGameplaySession(pending:ready)
        for stop in ["seventh-blit","hud","commit"] {
            var environment = Environment()
            XCTAssertThrowsError(try session.advance(environment:&environment,outputInput:input,observe:{ event,e in
                e.observations += 1
                switch event {
                case .gameplayCheckpoint(.commands,_):e.inHUD = true
                case .front(let event) where e.inHUD && event.kind == "blit":
                    e.blits += 1
                    if stop == "seventh-blit" && e.blits == 7 { throw Stop.injected(stop) }
                case .gameplayCheckpoint(.hud,let snapshot):
                    e.inHUD = false
                    if stop == "hud" {
                        try I.sameMatch(snapshot.match,hud.match);try I.sameState(snapshot.state,hud.state)
                        try P.require(snapshot.operations == hud.operations,"Rollback after actual HUD journal")
                        throw Stop.injected(stop)
                    }
                default:break
                }
            },beforeCommit:{ _,_ in if stop == "commit" { throw Stop.injected(stop) } })) { XCTAssertEqual($0 as? Stop,.injected(stop)) }
            try P.require(environment == Environment() && session.pendingReturn == nil,"HUD failure rolls back buffered environment and return")
            try I.sameState(session.entry.state,ready.state);try I.sameMatch(session.entry.match,ready.match)
        }
        var retry = Environment()
        let result = try session.advance(environment:&retry,outputInput:input)
        try I.sameState(result.snapshot.state,returned.snapshot.state);try I.sameMatch(result.snapshot.match,returned.snapshot.match)
        try P.require(result.graphics == returned.graphics && result.snapshot.operations == returned.snapshot.operations && result.snapshot.music.allocations == returned.snapshot.music.allocations && result.snapshot.resources.bitmaps == returned.snapshot.resources.bitmaps && result.snapshot.backgrounds == returned.snapshot.backgrounds,"HUD same-session retry full commands/journal/owners")
        try P.same(result.snapshot.local,returned.snapshot.local,"HUD retry local record")
        return 3
    }
    func testPrimaryOwnedHUDProjection() throws { try sequence(false) }
    func testControlOwnedHUDProjection() throws { try sequence(true) }
}
