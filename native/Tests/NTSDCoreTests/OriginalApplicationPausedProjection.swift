import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Finite pause rules derived from retained current input. These values are
/// assertions only, never inputs to the application candidate.
enum OriginalApplicationPausedProjection {
    typealias I = OriginalApplicationActiveGameplayInput
    typealias P = I.P
    typealias D = OriginalApplicationGameplayDrawingProjection
    typealias Q = OriginalApplicationActiveOutputProjection
    static let counters: [Int32] = [18,19,19,19,19,19,20,21,21,21,21,21,22,23]
    static let unpaused = [1,2,7,8,13,14]
    static func paused(_ globals: OriginalStateRecord) throws -> Bool {
        let value = try globals.integer(at:0x450bfc-0x44d000,as:Int32.self)
        try P.require([0,1].contains(value),"Finite cached pause")
        return value == 1
    }
    static func local(_ pool: OriginalStateRecord,_ globals: OriginalStateRecord,_ actors: [UInt32]) throws -> I.Local {
        if try paused(globals) {
            var value = globals
            // The caller initializes these sentinels even when it skips the
            // local-input helper. Prior equal bytes do not remove the writes.
            for n in 0..<21 { try value.write(UInt8(n == 20 ? 0 : 1),at:0x40+n) }
            return .init(pool:pool,globals:value,commands:[UInt8](repeating:0,count:10))
        }
        return try I.local(pool:pool,globals:globals,actorTokens:actors)
    }
    static func control(_ globals: OriginalStateRecord) throws -> [OriginalInputControlRequest] {
        func word(_ address: Int) throws -> UInt32 { try globals.integer(at:address-0x44d000,as:UInt32.self) }
        try P.require(word(0x44d020) == 0 && word(0x450b88) == 0 && globals.integer(at:0x44f1af-0x44d000,as:UInt8.self) == 0,"Offline non-menu pause controls")
        if try word(0x450b90) != 0 { return [] }
        var events: [OriginalInputControlRequest] = try [
            .init(.asyncSelect,[word(0x44f1b4),word(0x4546f4),0,0]),.init(.asyncSelect,[word(0x44f46c),word(0x4546f4),0,0]),
            .init(.ioctl,[word(0x44f1b4),0x8004667e,0]),.init(.ioctl,[word(0x44f46c),0x8004667e,1],[[0,0,0,0]])]
        for at in [0x455470,0x455471,0x4553ea,0x4553eb,0x4553ec,0x4553ed,0x4553ee,0x4553ef,0x4553f0] {
            try P.require(globals.integer(at:at-0x44d000,as:UInt8.self) != 100,"No undeclared input action")
        }
        for (address,helper): (Int,UInt32) in [(0x4553e8,0x416dd0),(0x4553e9,0x416df0)] {
            if try globals.integer(at:address-0x44d000,as:UInt8.self) == 100 {
                events.append(.init(.action,[helper],[[UInt8](repeating:0,count:10)]))
            }
        }
        return events
    }
    static func inputStage(_ stage: OriginalLoadedMatchEntry.Checkpoint,_ value: inout I.Local) throws {
        let isPaused = try paused(value.globals)
        if stage == .control {
            for action in try control(value.globals) where action.kind == .action {
                let first = action.arguments == [0x416dd0]
                try P.require(first || action.arguments == [0x416df0],"Declared pause helper")
                try value.globals.write(UInt8(117),at:(first ? 0x4553e8 : 0x4553e9)-0x44d000)
                try value.globals.write(Int32(first ? (isPaused ? 0 : 1) : 0),at:0x44fb60-0x44d000)
                try value.globals.write(Int32(first ? (isPaused ? 0 : 1) : 1),at:0x44fcb0-0x44d000)
            }
        }
        if !isPaused { try I.inputStage(stage,&value) }
        else if stage == .round {
            //41d71f precedes the paused return; cached pause is exactly1 here.
            try value.globals.write(Int32(0),at:0x450c00-0x44d000)
        }
    }
    static func body(_ stage: OriginalPausedGameplay.Stage,_ value: inout P,
                     _ drawing: inout D,_ target: UInt32,_ installed: Bool,
                     _ sounds: Set<UInt32>) throws -> [Q.Write] {
        try P.require(paused(value.globals) && value.g(0x450b84) == 0,"Own non-playback paused body")
        try value.livePair();let before = value
        value.stores = [];value.sounds = [];value.draw = nil;drawing.events = []
        switch stage {
        case .background:
            try value.global(0x44d02c,1,0x41d742)
            try P.require(value.backgrounds.count == 101 && value.g(0x44d024) == 0,"Paused District")
            let bg = value.backgrounds[0]
            try P.require(bg.integer(at:0x1c,as:Int32.self) == 15,"Paused District layer count")
            for layer in 0..<15 {
                try P.require(bg.integer(at:0x89c+4*layer,as:Int32.self) == 0 && bg.integer(at:0x644+4*layer,as:Int32.self) == 0,"Finite paused non-fill/non-loop layer")
                let period = try bg.integer(at:0x7ac+4*layer,as:Int32.self)
                if period > 0 {
                    let at = 0x824+4*layer,next = try (bg.integer(at:at,as:Int32.self) &+ 1)%period
                    try value.backgrounds[0].write(next,at:at)
                    value.stores.append(.init(pc:0x41a35a,region:"background0",offset:at,bytes:Array(value.backgrounds[0].bytes[at..<at+4])))
                }
            }
            // This method expands background draws only. No P.camera(), actor
            // bounds or camera scalar update is performed in the paused branch.
            try drawing.camera(before,value,target)
        case .drawing:try drawing.world(value,target)
        case .hud:try drawing.hud(value)
        case .pauseBitmap:
            try drawing.picture(drawing.resourceToken(UInt32(bitPattern:value.g(0x44ff8c))),false,
                360,288,-1,1,UInt32(bitPattern:value.g(0x455608)))
        case .indicators:
            try P.require(value.g(0x450b84) == 0,"No playback indicator")
        case .output:
            var q = Q(globals:value.globals,drawing:drawing,liveSounds:sounds)
            try q.advancePausedNoticeOne(installed)
            value.globals = q.globals;drawing = q.drawing;return q.writes
        }
        return []
    }
    /// Six explicit OS message iterations, including key-up after a key already
    /// consumed by input control. Source table writes have a different provenance.
    static func acquire(_ app: inout I.C.A,_ call: Int) throws -> Int {
        let messages: [Int:(UInt32,UInt32)] = [1:(0x100,112),2:(0x101,112),5:(0x100,113),6:(0x101,113),11:(0x100,112),12:(0x101,112)]
        guard let (message,key) = messages[call] else { return 0 }
        let old = try XCTUnwrap(app.session),before = app
        var expected = old.state,full = old.state.full
        try full.write(UInt8(message == 0x100 ? 100 : 117),at:0x455378-0x44d000+Int(key))
        if message == 0x100 {
            // F1/F2 neither enter text nor match any character of either
            // WINDOW_INPUT recognizer, so both progress words reset.
            for at in [0x45857c,0x458578] { try full.write(UInt32(0),at:at-0x44d000) }
        }
        let incremented = old.loop.counter &+ 1,counter = Int32(bitPattern:incremented) > 60 ? UInt32(0) : incremented
        try full.write(counter,at:0x458580-0x44d000);try expected.replace(0,full)
        var msg = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:28),defined:[Bool](repeating:true,count:28))
        try msg.write(old.state.full.integer(at:0x4546f4-0x44d000,as:UInt32.self),at:0)
        try msg.write(message,at:4);try msg.write(key,at:8)
        try I.C.key(&app,message,key)
        let current = try XCTUnwrap(app.session)
        try I.sameState(current.state,expected)
        try P.require(current.loop.message == msg && current.loop.counter == counter && current.loop.timer.baseline == old.loop.timer.baseline,"Paused acquisition entire MSG/counter/timer")
        let owners = try XCTUnwrap(current.loadedOwners),retained = try XCTUnwrap(before.session?.loadedOwners)
        try I.sameMatch(owners.match,retained.match)
        return 1
    }
}
