import NTSDCore

/// The initialized recorder selects the indicator entry. Retain unknown caller
/// backing as nil; the source access audit is evidence, never initialization.
enum GameplayResultLayoutReference {
    struct Input: Decodable {
        struct Access: Decodable { let pc: UInt32, offset: Int, size: Int, write: Bool }
        let continuation: UInt32, stageDefeatedBefore: UInt32, stageDefeatedAfter: UInt32
        let localAccesses: [Access]
        let fpcw: UInt16, fpswBefore: UInt16, fpswAfter: UInt16, fptagBefore: UInt16, fptagAfter: UInt16
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Gameplay result layout: "+text) }
    static func compare(_ section: MatchLaunchReference.Control.Section, state: inout OriginalMatchPreparation,
        context: OriginalInputControlContext, round: OriginalMatchRoundResult,
        continuation: OriginalResultRecording.Continuation) throws {
        guard let input = section.resultLayout, section.label == "result-layout",
              section.end.pc == 0x422994, section.end.sp == 0x1000e9bc,
              section.helpers.isEmpty, section.checkpoints.isEmpty, section.readsBeforeWrites.isEmpty,
              section.before.frameHeap != nil, section.after.frameHeap != nil,
              section.before.menuBitmaps != nil, section.after.menuBitmaps != nil,
              state.arithmeticPrecision == .bits53, round.continuation == .gameplay,
              round.stageDefeated == input.stageDefeatedBefore, input.stageDefeatedAfter == input.stageDefeatedBefore,
              continuation.rawValue == input.continuation, continuation == .indicators, input.localAccesses.isEmpty,
              input.fpcw == 0x23f, input.fpswBefore == 0x4000, input.fpswAfter == input.fpswBefore,
              input.fptagBefore == 0xffff, input.fptagAfter == input.fptagBefore else { throw error("Own continuation/storage/FPU provenance") }
        var local: OriginalStateRecord?
        try OriginalResultLayout.apply(state: &state, context: context, continuation: continuation,
            stageDefeated: round.stageDefeated, indicatorTarget: nil, local: &local, dcResult: 0, dc: 0,
            surface: { _ in throw error("Unexpected own portrait resolution") },
            resourceBitmap: { _ in throw error("Unexpected own layout resource") },
            performBlit: { _ in throw error("Unexpected own layout Blt") },
            observe: { _ in throw error("Unexpected own layout event") })
        guard local == nil else { throw error("Invented own formatter backing") }
    }
}
