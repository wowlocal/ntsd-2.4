import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Comparison-only acquisition and finite local-input specification. Full body
/// equivalence is a separate pending gate; no snapshot is fed to application code.
final class OriginalApplicationActiveGameplayInput {
    typealias P = OriginalApplicationGameplayStateProjection
    typealias C = OriginalApplicationLoadedCycleTests
    typealias A = ActiveGameplayReference
    let document: ContinuousGameplayReference.Document
    private var cache: [String:[UInt8]] = [:]
    init(_ reverse: Bool) throws {
        let name = "original-active-gameplay"+(reverse ? "-control" : "")
        let data = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures")))
        let sha = reverse ? "d3abb578f36ac74716fa6e71eb12091c6f0eed5adb02f1b59a550275c73fc0b3" : "3b074ff960538fde6e13b1b65bda4f833b22bbc9cafcef990de12f71aaed511c"
        try P.require(MatchPreparationReference.digest(data) == sha,"Active fixture SHA")
        document = try .init(data)
        let c = document.corpus
        try P.require(c.control == reverse && c.cases.count == 48 && c.schedule == A.schedule,"Active schedule identity")
        let parent = "original-continuous-gameplay"+(reverse ? "-control" : "")
        try P.require(c.parent.sha256 == OriginalApplicationGameplaySource.fixtureSHA256[parent],"Active neutral-parent identity")
        try P.require(c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c" && c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d","Active source identity")
        try P.require(c.actorAddresses.count == 400 && Set(c.actorAddresses).count == 400,"Active source Actor identities")
    }
    func bytes(_ key: String) throws -> [UInt8] {
        if let value = cache[key] { return value }
        let b = try XCTUnwrap(document.corpus.blobs[key])
        let value = try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:8_000_000)
        try P.require(MatchPreparationReference.digest(Data(value)) == key,"Active blob SHA")
        cache[key] = value;return value
    }
    func record(_ data: String,_ mask: String? = nil) throws -> OriginalStateRecord {
        let b = try bytes(data),m = try mask.map(bytes) ?? [UInt8](repeating:1,count:b.count)
        try P.require(m.count == b.count && m.allSatisfy { $0 < 2 },"Active byte/mask extent")
        return try .init(bytes:b,defined:m.map { $0 != 0 })
    }
    static func keyboard(_ globals: OriginalStateRecord) -> [UInt8] {
        Array(globals.bytes[(0x455378-0x44d000)..<(0x455378-0x44d000+300)])
    }
    static func sameState(_ a: C.Session.State,_ b: C.Session.State) throws {
        try P.same(a.full,b.full,"Active full caller state")
        try P.require(a.memory.allocations == b.memory.allocations && a.memory.replayPointers == b.memory.replayPointers,"Active complete memory owners")
        try P.require(a.bitmapInputs == b.bitmapInputs && a.graphics == b.graphics,"Active graphics/image owners")
        try P.require(a.front.bitmaps == b.front.bitmaps && a.earlyScreen.bitmaps == b.earlyScreen.bitmaps && a.earlyScreen.surfaces == b.earlyScreen.surfaces && a.earlyScreen.retainedOperation == b.earlyScreen.retainedOperation,"Active all front owners")
        try P.require(a.libraryText == b.libraryText && a.libraryHits == b.libraryHits && a.libraryTransforms == b.libraryTransforms,"Active installed-library state")
        try P.require(a.random == b.random && a.screenBody == b.screenBody && a.settings == b.settings,"Active CRT/startup/settings")
    }
    static func sameMatch(_ a: OriginalMatchPreparation,_ b: OriginalMatchPreparation) throws {
        try OriginalApplicationGameplayProjectionTests.ownEqual(P(b),a,"Active retained match")
        try P.require(a.arithmeticPrecision == b.arithmeticPrecision && a.libraryCommands == b.libraryCommands,"Active match context")
        try P.require(a.bitmapOwners == b.bitmapOwners && a.bitmapSurfaceOwners == b.bitmapSurfaceOwners && a.bitmaps == b.bitmaps && a.interface.bitmaps == b.interface.bitmaps,"Active all match bitmap owners")
        try P.require(a.releasedBitmapOrder == b.releasedBitmapOrder && a.releasedBitmaps == b.releasedBitmaps && a.backgroundLoader.outerTokens == b.backgroundLoader.outerTokens,"Active bitmap lifetime history")
        try P.require(a.catalog.registry == b.catalog.registry && a.catalog.backgrounds == b.catalog.backgrounds && a.catalog.stages == b.catalog.stages && a.catalog.bitmaps == b.catalog.bitmaps,"Active retained catalog")
        try P.require(a.catalog.frameAllocations == b.catalog.frameAllocations && a.catalog.checksum == b.catalog.checksum && a.catalog.soundCount == b.catalog.soundCount && a.catalog.soundBytes == b.catalog.soundBytes,"Active catalog backing")
        // catalog is an immutable let value. The mutable arena loader's complete
        // accessible resource state is retained too; no active operation allocates
        // Frame heap storage or advances its private allocation cursor.
        let x = a.backgroundLoader.resources,y = b.backgroundLoader.resources
        try P.require(x.checksum == y.checksum && x.bitmaps == y.bitmaps && x.sounds.bytes == y.sounds.bytes && x.sounds.count == y.sounds.count && x.frameHeap.allocations == y.frameHeap.allocations && x.frameHeap.fill == y.frameHeap.fill,"Active arena loader resources")
    }
    static func unchanged(_ a: C.A,_ b: C.A) throws {
        let x = try XCTUnwrap(a.session),y = try XCTUnwrap(b.session)
        try sameState(x.state,y.state)
        try P.require(x.loop.counter == y.loop.counter && x.loop.message == y.loop.message && x.loop.timer.baseline == y.loop.timer.baseline,"Active entire message-loop state")
        let owned = try XCTUnwrap(x.loadedOwners),old = try XCTUnwrap(y.loadedOwners)
        try sameMatch(owned.match,old.match)
        try P.require(owned.music.allocations == old.music.allocations && owned.resources.bitmaps == old.resources.bitmaps && owned.backgrounds == old.backgrounds,"Active loaded music/menu/background owners")
        // Bootstrap.startup is assigned only by start(); step/finish never replace
        // it. LoadedOwners.entry is the retained immutable historical input parent.
        try sameState(owned.entry.state,old.entry.state)
    }
    static func binding(_ globals: OriginalStateRecord,_ seat: Int) throws -> A.Acquisition.Binding {
        let status = try globals.integer(at:0x450b4c-0x44d000+seat*4,as:UInt32.self)
        try P.require((1...4).contains(status),"Active local keyboard seat")
        let config = 0x44fb20+status*80
        let device = try globals.integer(at:Int(config)-0x44d000,as:UInt32.self)
        let keys = try (0..<7).map { try globals.integer(at:Int(config)-0x44d000+4+$0*4,as:UInt32.self) }
        try P.require(device == 0 && keys.allSatisfy { $0 < 300 },"Active keyboard mapping")
        return .init(seat:seat,status:status,config:config,device:device,keys:keys)
    }
    static func desired(_ globals: OriginalStateRecord,_ plan: A.Plan) throws -> Set<UInt32> {
        try P.require(plan.buttons.count == 2,"Two declared local players")
        var keys = Set<UInt32>()
        for seat in 0..<2 {
            let b = try binding(globals,seat)
            for name in plan.buttons[seat] { keys.insert(b.keys[try XCTUnwrap(A.buttons.firstIndex(of:name))]) }
        }
        return keys
    }
    func sourceAcquisition(_ index: Int,_ held: inout Set<UInt32>) throws {
        let c = document.corpus.cases[index],a = try XCTUnwrap(c.acquisition)
        try P.require(c.index == index+1 && a.plan == A.schedule[index],"Source acquisition schedule")
        try P.require(c.before == (index == 0 ? document.corpus.initial : document.corpus.cases[index-1].after),"Source retained acquisition parent")
        let before = try document.snapshot(c.before),after = try document.snapshot(XCTUnwrap(c.acquired))
        let globals = try record(before.state.globals),next = try Self.desired(globals,a.plan)
        try P.require(a.bindings == (0..<2).map { try Self.binding(globals,$0) },"Source live bindings")
        var expected = Self.keyboard(globals),changes: [A.Acquisition.Change] = []
        try P.require(expected == a.before,"Source acquisition before")
        for key in held.union(next).sorted() {
            let value: UInt8 = next.contains(key) ? 100 : 117
            if expected[Int(key)] != value {
                changes.append(.init(key:key,address:0x455378+key,before:expected[Int(key)],after:value))
                expected[Int(key)] = value
            }
        }
        try P.require(changes == a.changes && expected == a.after && expected == Self.keyboard(record(after.state.globals)),"Source acquired byte effects")
        try P.require(c.keyboardBefore == expected && c.keyboardAfter == expected,"Source body retains acquired keys")
        var complete = globals
        for change in changes { try complete.write(change.after,at:Int(change.address)-0x44d000) }
        try P.same(complete,record(after.state.globals),"Source acquisition full globals")
        try P.require(before.state.poolBytes == after.state.poolBytes && before.state.poolMask == after.state.poolMask,"Acquisition retains source pool")
        try P.require(c.cycle.before == after.state,"Source acquired input boundary")
        let begun = try Self.prologue(complete)
        try P.same(begun,record(c.cycle.prefix.after.globals),"Source full input prologue globals")
        try P.require(c.cycle.prefix.after.poolBytes == after.state.poolBytes && c.cycle.prefix.after.poolMask == after.state.poolMask,"Source prologue pool retention")
        held = next
    }
    static func acquire(_ app: inout C.A,_ plan: A.Plan,_ held: inout Set<UInt32>) throws -> Int {
        let globals = try XCTUnwrap(app.session).state.full,next = try desired(globals,plan)
        var expected = keyboard(globals),count = 0
        for key in held.union(next).sorted() {
            let down = next.contains(key),value: UInt8 = down ? 100 : 117
            if expected[Int(key)] != value {
                let beforeSession = try XCTUnwrap(app.session),before = beforeSession.state
                var projected = before,full = before.full
                try P.require(key < 256 && key != 27 && key != 0x90,"Ordinary WndProc key domain")
                try full.write(value,at:0x455378-0x44d000+Int(key))
                if down {
                    // Dispatcher startup activates this retained text buffer. Its
                    // WndProc writes accompany ordinary gameplay keys too.
                    if try full.integer(at:0x458440-0x44d000,as:UInt32.self) == 1 {
                        if key == 0x20 || key == 0xbe || (0x42...0x59).contains(key) || (0x30...0x39).contains(key) {
                            let index = try full.integer(at:0x458570-0x44d000,as:UInt32.self)
                            try P.require(index < 299,"Finite active text index before alias boundary")
                            let total = try full.integer(at:0x458574-0x44d000,as:UInt32.self)
                            try full.write(UInt8(key == 0xbe ? 0x2e : key),at:0x458444-0x44d000+Int(index))
                            try full.write(total &+ 1,at:0x458574-0x44d000)
                            try full.write(index &+ 1,at:0x458570-0x44d000)
                            try full.write(UInt8(0),at:0x458444-0x44d000+Int(index)+1)
                        } else if key == 8 {
                            let index = try full.integer(at:0x458570-0x44d000,as:Int32.self)
                            if index > 0 {
                                try P.require(index <= 299,"Finite active backspace index")
                                try full.write(index-1,at:0x458570-0x44d000)
                                try full.write(UInt8(0),at:0x458444-0x44d000+Int(index)-1)
                            }
                        } else if key == 13 { try full.write(UInt32(0),at:0x458440-0x44d000) }
                    }
                    // WINDOW_INPUT's two retained recognizers are additional
                    // WndProc effects; semantic source acquisition has no such writes.
                    for (address,sentinel,text) in [(0x45857c,0x455471,"LF2.NET"),(0x458578,0x455470,"HEROFIGHTER.COM")] {
                        let sequence = text.utf8.map { $0 == 46 ? UInt32(0xbe) : UInt32($0) }
                        let current = try full.integer(at:address-0x44d000,as:UInt32.self)
                        if current < sequence.count && key == sequence[Int(current)] {
                            if current == sequence.count-1 { try full.write(UInt8(100),at:sentinel-0x44d000) }
                            else { try full.write(current+1,at:address-0x44d000) }
                        } else if !(current > 0 && current < sequence.count && key == sequence[Int(current)-1]) {
                            try full.write(UInt32(0),at:address-0x44d000)
                        }
                    }
                }
                // The enclosing message iteration also owns458580 and MSG.
                // Its wrapped increment is followed by a signed >60 reset.
                let incremented = beforeSession.loop.counter &+ 1
                let counter = Int32(bitPattern:incremented) > 60 ? UInt32(0) : incremented
                try P.require(full.integer(at:0x458580-0x44d000,as:UInt32.self) == beforeSession.loop.counter,"Acquisition coherent loop counter")
                try full.write(counter,at:0x458580-0x44d000)
                var message = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:28),defined:[Bool](repeating:true,count:28))
                try message.write(before.full.integer(at:0x4546f4-0x44d000,as:UInt32.self),at:0)
                try message.write(UInt32(down ? 0x100 : 0x101),at:4)
                try message.write(key,at:8)
                try projected.replace(0,full)
                try C.key(&app,down ? 0x100 : 0x101,key)
                let afterSession = try XCTUnwrap(app.session)
                try sameState(afterSession.state,projected)
                try P.require(afterSession.loop.counter == counter && afterSession.loop.message == message && afterSession.loop.timer.baseline == beforeSession.loop.timer.baseline,"Whole keyboard iteration loop state")
                expected[Int(key)] = value;count += 1
            }
        }
        try P.require(keyboard(XCTUnwrap(app.session).state.full) == expected,"Own WndProc acquired keyboard")
        held = next;return count
    }
    struct Local {
        var pool: OriginalStateRecord,globals: OriginalStateRecord,commands: [UInt8]
    }
    static func prologue(_ globals: OriginalStateRecord) throws -> OriginalStateRecord {
        var expected = globals
        let phase = try globals.integer(at:0x450b90-0x44d000,as:Int32.self)
        try P.require([0,1].contains(phase) && globals.integer(at:0x450b84-0x44d000,as:Int32.self) == 0,"Active prologue context")
        try expected.write(1-phase,at:0x450b90-0x44d000)
        if phase == 1 {
            let pause = try globals.integer(at:0x44fb60-0x44d000,as:UInt32.self)
            let next = try globals.integer(at:0x44fcb0-0x44d000,as:UInt32.self)
            try expected.write(pause,at:0x450bfc-0x44d000)
            try expected.write(next,at:0x44fb60-0x44d000)
        }
        return expected
    }
    static func inputStage(_ stage: OriginalLoadedMatchEntry.Checkpoint,_ value: inout Local) throws {
        func g(_ address: Int) throws -> Int32 { try value.globals.integer(at:address-0x44d000,as:Int32.self) }
        // The recorded offline active profile has neither hotkey actions nor
        // remote seats. REPLAY_TICK and MATCH_ROUND supply these numeric rules.
        try P.require(g(0x451160) == 0 && g(0x44d020) == 0 && g(0x450bfc) == 0 && g(0x450bdc) == 0,"Active ordinary round gates")
        if stage == .replay {
            let tick = try g(0x450b8c)
            try P.require((17..<65).contains(tick),"Finite recording counter")
            try value.globals.write(tick &+ 1,at:0x450b8c-0x44d000)
        }
        if stage == .round {
            for slot in 0..<400 { try P.require(value.pool.integer(at:4+slot,as:UInt8.self) == (slot < 2 ? 1 : 0),"Round finite activity") }
            for slot in 0..<2 {
                let at = 0x7d8+0x420*slot
                try P.require(value.pool.integer(at:at+0x2fc,as:Int32.self) > 0 && value.pool.integer(at:at+0x364,as:Int32.self) == 10+Int32(slot),"Two surviving fighter teams")
            }
            for (address,divisor) in [(0x450bd0,Int32(12)),(0x450bd4,Int32(3))] {
                try value.globals.write((g(address) &+ 1)%divisor,at:address-0x44d000)
            }
            try value.globals.write(1 &- g(0x450bd8),at:0x450bd8-0x44d000)
            try value.globals.write(Int32(0),at:0x450c00-0x44d000)
            try value.globals.write(Int32(-1),at:0x450bf8-0x44d000)
        }
    }
    /// LOCAL_INPUT table: raw previous bytes in either phase; phase0 samples
    /// exactly100 on keyboard and nonzero on the retained joystick profiles,
    /// packing80/40/20/10/08/04/02. Configured inactive seats still participate.
    /// Remote/playback/active AI children remain explicit boundaries.
    static func local(pool: OriginalStateRecord,globals: OriginalStateRecord,
                      actorTokens: [UInt32]) throws -> Local {
        var e = Local(pool:pool,globals:globals,commands:[UInt8](repeating:0,count:10))
        func g(_ address: Int) throws -> Int32 { try globals.integer(at:address-0x44d000,as:Int32.self) }
        try P.require(actorTokens.count == 400 && Set(actorTokens).count == 400,"Local Actor map")
        for slot in 0..<400 { try P.require(pool.integer(at:0x194+slot*4,as:UInt32.self) == actorTokens[slot],"Finite distinct local slot mapping") }
        try P.require(g(0x450b84) == 0 && g(0x450b80) == 1 && [0,1].contains(g(0x450b90)),"Active recording profile")
        try P.require(globals.integer(at:0x44f1af-0x44d000,as:Int8.self) <= 0,"Offline input profile")
        for n in 0..<21 { try e.globals.write(UInt8(n == 20 ? 0 : 1),at:0x40+n) }
        for seat in 0..<8 {
            let status = try g(0x450b4c+seat*4)
            try P.require((1...4).contains(status) || (seat >= 2 && status == 0),"Finite seat status")
            if status == 0 { continue }
            let token = try pool.integer(at:0x194+seat*4,as:UInt32.self)
            let offset = 0x7d8+0x420*(try XCTUnwrap(actorTokens.firstIndex(of:token)))
            for n in 0..<7 { try e.pool.write(pool.integer(at:offset+0xcd+n,as:UInt8.self),at:offset+0xc6+n) }
            if try g(0x450b90) == 0 {
                let config = 0x44fb20+Int(status)*80,device = try g(config)
                try P.require((0...2).contains(device),"Finite input device profile")
                for n in 0..<7 {
                    let down: Bool
                    if device == 0 {
                        let key = try globals.integer(at:config-0x44d000+4+n*4,as:UInt32.self)
                        try P.require(key < 300,"Local keyboard index")
                        down = try globals.integer(at:0x455378-0x44d000+Int(key),as:UInt8.self) == 100
                    } else {
                        let buttonOffset: UInt32
                        if n < 4 { buttonOffset = [0,1,3,2][n] }
                        else { buttonOffset = 4 &+ UInt32(bitPattern:try g(config+0x20+(n-4)*4)) }
                        try P.require(buttonOffset < 48,"Owned joystick state offset")
                        let address = 0x453ff0+48*Int(device-1)+Int(buttonOffset)
                        down = try globals.integer(at:address-0x44d000,as:UInt8.self) != 0
                    }
                    try e.pool.write(UInt8(down ? 1 : 0),at:offset+0xcd+n)
                    if down { e.commands[seat] |= UInt8(0x80 >> n) }
                }
            }
        }
        for slot in 10..<400 { try P.require(pool.integer(at:4+slot,as:UInt8.self) == 0,"No active AI child") }
        return e
    }
    func sourceLocal(_ index: Int) throws {
        let c = document.corpus.cases[index].cycle,p = c.prefix.after
        var e = try Self.local(pool:record(p.poolBytes,p.poolMask),globals:record(p.globals),actorTokens:document.corpus.actorAddresses)
        try P.require(c.prefix.commands == [UInt8](repeating:0,count:10) && c.prefix.playback == c.prefix.commands,"Source cleared packet buffers")
        try P.require(c.local.commandsBefore == c.prefix.commands && c.local.commandsAfter == e.commands && c.local.dispatch.isEmpty,"Source complete local commands/dispatch")
        for endpoint in [c.local.beforeDispatch,c.local.after] {
            let world = try record(endpoint.world.bytes,endpoint.world.defined)
            let actors = try endpoint.actors.map { try record($0.bytes,$0.defined) }
            let pool = try OriginalStateRecord(bytes:world.bytes+actors.flatMap(\.bytes),defined:world.defined+actors.flatMap(\.defined))
            try P.same(e.pool,pool,"Source complete local pool")
            try P.same(e.globals,record(endpoint.globals),"Source complete local globals")
        }
        for (stage,endpoint): (OriginalLoadedMatchEntry.Checkpoint,InputControlReference.Snapshot) in [
            (.control,c.inputControl.control),(.received,c.inputControl.after),(.replay,c.replay.after),(.round,c.round.after)] {
            try Self.inputStage(stage,&e)
            try P.same(e.pool,record(endpoint.poolBytes,endpoint.poolMask),"Source full input pool \(stage)")
            try P.same(e.globals,record(endpoint.globals),"Source full input globals \(stage)")
        }
    }
    func sourceReplay(_ index: Int) throws {
        let c = document.corpus.cases[index].cycle,before = c.inputControl.after,after = c.replay.after
        let pointers = try record(before.pointers),tick = try record(before.globals).integer(at:0x450b8c-0x44d000,as:Int32.self)
        try P.require(before.memory.count == 1 && after.memory.count == 1 && before.memory[0].live && after.memory[0].live,"Source recording owner")
        try P.require(pointers.bytes.count == 8 && pointers.integer(at:0,as:UInt32.self) == 0x72000020 && pointers.integer(at:4,as:UInt32.self) == 0,"Source recording/playback mapping")
        try P.require(tick == 17+Int32(index) && before.pointers == after.pointers && before.saved == after.saved,"Source retained recording metadata")
        var expected = try record(before.memory[0].bytes,before.memory[0].defined)
        try P.require(expected.bytes.count == 0x630e18,"Source full recording extent")
        for n in 0..<10 { try expected.write(c.local.commandsAfter[n],at:0x2b38+10*Int(tick)+n) }
        try P.same(expected,record(after.memory[0].bytes,after.memory[0].defined),"Source whole recorded packet allocation")
        try P.require(c.replay.events == [.init(.writePacket,[UInt32(tick),0x72000020],[c.local.commandsAfter])],"Source ordered write including unchanged packet")
        var teams = [UInt32](repeating:0,count:40);teams[10] = 1;teams[11] = 1
        try P.require(c.round.events == [.init(.teams,teams)],"Source complete team observation")
    }
}
