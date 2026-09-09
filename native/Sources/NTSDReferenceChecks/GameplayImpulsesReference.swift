import NTSDCore

enum GameplayImpulsesReference {
    struct Input: Decodable {
        let target: UInt32,mode: Int32,dcResult: Int32,dc: UInt32,methodResult: Int32
        let fpcw: UInt32,fpswBefore: UInt32,fpswAfter: UInt32,events: [OriginalMenuPresentationEvent]
    }
    struct Result { let helpers: Int,events: Int }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Gameplay impulses reference: "+text) }
    static func compare(_ section: MatchLaunchReference.Control.Section,state: inout OriginalMatchPreparation,
                        snapshot: (OriginalMatchPreparation,MatchLaunchReference.State,String) throws -> Void) throws -> Result {
        guard let input = section.impulses,section.end.pc == 0x41f550,section.end.sp == 0x1000e9bc,
              section.before.frameHeap != nil,section.after.frameHeap != nil,section.before.menuBitmaps != nil,section.after.menuBitmaps != nil,
              section.checkpoints.isEmpty,section.readsBeforeWrites.isEmpty,input.mode == 0,
              (input.fpcw == 0 || (input.fpcw == 0x23f && state.arithmeticPrecision == .bits53)),
              input.fpswAfter >> 11 & 7 == 0,input.mode == (try state.globals.integer(at: 0x451160-0x44d000,as: Int32.self)),
              input.target == (try state.globals.integer(at: 0x455608-0x44d000,as: UInt32.self)),
              section.helpers.map(\.entry) == [0x7817775d,0x401290,0x4196f0] else { throw error("Own source boundary") }
        // Historical source inherits CW0; the initialized chain executes445a31
        // and retains CW023f. Both own passes only clear pending vectors.
        for slot in 0..<400 where try state.world.integer(at: 4+slot,as: UInt8.self) != 0 {
            let actor = Int(try state.world.integer(at: 0x194+4*slot,as: UInt32.self))
            guard state.actors.indices.contains(actor) else { throw error("Own Actor binding") }
            if try state.actors[actor].integer(at: 0xb4,as: Int32.self) == 0 {
                guard try state.actors[actor].integer(at: 0x20,as: Int32.self) == 0 else { throw error("Own impulse arithmetic needs FPU initialization provenance") }
            }
        }
        for h in section.helpers {
            guard h.pop == 0,h.returnSP == h.entrySP+4,h.saved.count == 4 else { throw error("Helper ABI") }
            switch h.entry {
            case 0x7817775d:
                guard h.returnPC == 0x41f51c,h.arguments.count == 8,h.arguments[0] == section.end.sp+0x48c,h.arguments[1] == 0x449288 else { throw error("CRT caller") }
                let a = Int(try state.world.integer(at: 0x1bc,as: UInt32.self))
                let args = try [0xc4,0xc5,0xc3,0xc2,0xbe,0xc0].map { UInt32(bitPattern: Int32(try state.actors[a].integer(at: $0,as: Int8.self))) }
                guard Array(h.arguments.dropFirst(2)) == args,h.result == input.events.first?.arguments.first else { throw error("Signed diagnostic bytes") }
            case 0x401290:
                guard h.returnPC == 0x41f53b,h.arguments == [input.target,section.end.sp+0x48c,0,0xffffff,0,30],
                      h.result == UInt32(bitPattern: input.dcResult) else { throw error("Text caller") }
            default:
                guard h.returnPC == 0x41f545,h.this == 0x22000020,h.arguments.isEmpty else { throw error("Impulse caller") }
            }
        }
        try snapshot(state,section.before,"own impulses before")
        // A late invalid binding must not publish any earlier velocity changes.
        // GDI events are collected by the caller and discarded on failed ticks.
        var trial = state
        try trial.actors[0].write(Int32(2),at: 0x20);try trial.actors[0].writeBinary64(12.5,at: 0x28)
        try trial.world.write(UInt8(1),at: 403);try trial.world.write(UInt32.max,at: 0x194+399*4)
        let beforeTrial = trial;var seenTrial: [OriginalMenuPresentationEvent] = [],failed = false
        do { try OriginalPostDrawImpulses.apply(state: &trial,dcResult: input.dcResult,dc: input.dc,observe: { seenTrial.append($0) }) }
        catch let caught as OriginalStateError {
            guard case .invalidStorage("World impulses: Actor binding") = caught else { throw caught };failed = true
        }
        guard failed,seenTrial == input.events,trial.actors == beforeTrial.actors,trial.world == beforeTrial.world,trial.globals == beforeTrial.globals else { throw error("Public rollback") }
        trial.actors = state.actors;trial.world = state.world;try snapshot(trial,section.before,"own impulses rollback")
        var events: [OriginalMenuPresentationEvent] = []
        try OriginalPostDrawImpulses.apply(state: &state,dcResult: input.dcResult,dc: input.dc,observe: { events.append($0) })
        guard events == input.events else { throw error("Ordered CRT/GDI events") }
        try snapshot(state,section.after,"own impulses after")
        return .init(helpers: section.helpers.count,events: events.count)
    }
}
