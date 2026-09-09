import NTSDCore

/// The own first tick reaches this pass with both command flags clear. The
/// controlled corpus separately checks item/resource branches and aliased pools.
enum GameplayCommandsReference {
    struct Input: Decodable {
        struct Access: Decodable { let pc: UInt32,offset: Int,size: Int,write: Bool }
        struct Event: Decodable, Equatable { let kind: String,arguments: [UInt32] }
        let retainedOffset: Int,retainedBefore: UInt32,retainedAfter: UInt32,scratchAccesses: [Access]
        let fpcw: UInt16,fpswBefore: UInt16,fpswAfter: UInt16,fptagBefore: UInt16,fptagAfter: UInt16,sse2: UInt32
        let events: [Event]
    }
    struct Result { let helpers: Int,events: Int }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Gameplay commands reference: "+text) }
    static func compare(_ section: MatchLaunchReference.Control.Section,state: inout OriginalMatchPreparation,
                        snapshot: (OriginalMatchPreparation,MatchLaunchReference.State,String) throws -> Void) throws -> Result {
        guard let input = section.commands,section.end.pc == 0x421a15,section.end.sp == 0x1000e9bc,
              section.before.frameHeap != nil,section.after.frameHeap != nil,
              section.before.menuBitmaps != nil,section.after.menuBitmaps != nil,
              section.readsBeforeWrites.isEmpty,section.checkpoints.isEmpty,section.helpers.isEmpty,input.events.isEmpty,
              state.arithmeticPrecision == .bits53,input.fpcw == 0x23f,
              input.fptagBefore == 0xffff,input.fptagAfter == 0xffff,
              input.fpswBefore >> 11 & 7 == 0,input.fpswAfter >> 11 & 7 == 0 else { throw error("Own source boundary") }
        guard input.retainedOffset == 0x34,input.retainedBefore == input.retainedAfter,input.scratchAccesses.isEmpty else {
            throw error("Retained caller slot needs provenance")
        }
        try snapshot(state,section.before,"own commands before")
        // Do not import arbitrary original caller-stack backing as a native
        // fallback. This source path proves the word is never consumed.
        var retained: Int32?,events: [Input.Event] = []
        try OriginalPostDrawCommands.apply(state: &state,retainedSpawnSlot: &retained,sse2: input.sse2 != 0,observe: { event in
            switch event {
            case let .reconstruct(slot): events.append(.init(kind: "reconstruct",arguments: [UInt32(slot)]))
            case let .random(stream,range,result): events.append(.init(kind: "random",arguments: [stream,range,result].map(UInt32.init(bitPattern:))))
            case let .resumeMusic(slot,control): events.append(.init(kind: "resumeMusic",arguments: [UInt32(slot),control]))
            }
        })
        guard retained == nil,events == input.events else { throw error("Retained slot/ordered events") }
        try snapshot(state,section.after,"own commands after")
        return .init(helpers: section.helpers.count,events: events.count)
    }
}
