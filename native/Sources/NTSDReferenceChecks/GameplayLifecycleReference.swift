import NTSDCore

/// Runs the public full-loop API on the independently rebuilt initialized match.
/// Expected snapshots and inherited source stack bytes never seed native state.
enum GameplayLifecycleReference {
    struct Input: Decodable {
        struct Access: Decodable { let pc: UInt32,offset: Int,size: Int,write: Bool }
        struct Event: Decodable, Equatable { let kind: String,slot: Int,arguments: [UInt32] }
        let scratchOffsets: [Int],scratchBefore: [UInt32],scratchAfter: [UInt32],scratchAccesses: [Access]
        let fpcw: UInt16,fpswBefore: UInt16,fpswAfter: UInt16,fptagBefore: UInt16,fptagAfter: UInt16,sse2: UInt32
        let events: [Event]
    }
    struct Result { let helpers: Int,events: Int }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Gameplay lifecycle reference: "+text) }
    static func compare(_ section: MatchLaunchReference.Control.Section,state: inout OriginalMatchPreparation,
                        actorAddresses: [UInt32],
                        snapshot: (OriginalMatchPreparation,MatchLaunchReference.State,String) throws -> Void) throws -> Result {
        guard let input = section.lifecycle,section.end.pc == 0x4214d5,section.end.sp == 0x1000e9bc,
              section.before.frameHeap != nil,section.after.frameHeap != nil,
              section.before.menuBitmaps != nil,section.after.menuBitmaps != nil,
              section.readsBeforeWrites.isEmpty,section.checkpoints.isEmpty,
              state.arithmeticPrecision == .bits53,input.fpcw == 0x23f,
              input.fptagBefore == 0xffff,input.fptagAfter == 0xffff,
              input.fpswBefore >> 11 & 7 == 0,input.fpswAfter >> 11 & 7 == 0 else { throw error("Own source boundary") }
        // This particular initialized first pass must establish that none of
        // these retained words is read or written. Unknown native values then
        // remain unknown; arbitrary original stack bytes are not substituted.
        guard input.scratchOffsets == [0x44,0x50,0x5c,0x60,0x6c,0x70],input.scratchBefore.count == 6,
              input.scratchBefore == input.scratchAfter,input.scratchAccesses.isEmpty else { throw error("Retained caller scratch needs provenance") }
        for h in section.helpers {
            let abi: [UInt32:(Int,UInt32)] = [0x4061d0:(0,0),0x40d960:(2,8),0x417170:(2,0),
                                            0x416fb0:(2,0),0x417090:(2,0),0x4450d0:(0,0)]
            guard let (count,pop) = abi[h.entry],h.arguments.count == count,h.pop == pop,
                  h.returnSP == h.entrySP+4+pop,h.saved.count == 4 else { throw error("Helper ABI") }
            if h.entry == 0x40d960 {
                let slot = Int(h.arguments[1])
                guard (0..<400).contains(slot),h.returnPC == 0x41fb0b,
                      h.arguments[0] == (try state.globals.integer(at: 0x451160-0x44d000,as: UInt32.self)) else { throw error("Scheduler caller") }
                let actor = Int(try state.world.integer(at: 0x194+slot*4,as: UInt32.self))
                guard actorAddresses.indices.contains(actor),h.this == actorAddresses[actor] else { throw error("Scheduler receiver") }
            }
        }
        try snapshot(state,section.before,"own lifecycle before")
        var scratch = OriginalPostDrawScratch(),events: [Input.Event] = []
        try OriginalPostDrawLifecycle.apply(state: &state,scratch: &scratch,sse2: input.sse2 != 0,observe: { event in
            switch event {
            case let .reconstruct(slot,created): events.append(.init(kind: "reconstruct",slot: slot,arguments: [UInt32(created)]))
            case let .random(slot,stream,range,result): events.append(.init(kind: "random",slot: slot,arguments: [stream,range,result].map(UInt32.init(bitPattern:))))
            case let .catalogSound(slot,x,index): events.append(.init(kind: "catalogSound",slot: slot,arguments: [x,index].map(UInt32.init(bitPattern:))))
            case let .builtinSound(slot,x,index): events.append(.init(kind: "builtinSound",slot: slot,arguments: [x,index].map(UInt32.init(bitPattern:))))
            }
        })
        guard scratch == OriginalPostDrawScratch(),events == input.events else { throw error("Retained scratch/ordered events") }
        try snapshot(state,section.after,"own lifecycle after")
        return .init(helpers: section.helpers.count,events: events.count)
    }
}
