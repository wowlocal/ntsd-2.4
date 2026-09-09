import NTSDCore

/// Join the own round output to the result caller. The source audit is checked
/// as evidence; it never supplies native stack or recording initialization.
enum GameplayResultRecordingReference {
    struct Input: Decodable {
        struct Access: Decodable {
            let pc: UInt32, sp: UInt32, address: UInt32, size: Int, write: Bool, beforeWord: UInt32
            let reportedValue: UInt32?
        }
        let stageDefeatedBefore: UInt32, stageDefeatedAfter: UInt32
        let allStackAccesses: [Access], fromLastRoundInitialization: [Access]
        let fpcw: UInt16, fpswBefore: UInt16, fpswAfter: UInt16, fptagBefore: UInt16, fptagAfter: UInt16
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Gameplay result recording: "+text) }
    @discardableResult
    static func compare(_ section: MatchLaunchReference.Control.Section, state: inout OriginalMatchPreparation,
                        context: inout OriginalInputControlContext, round: OriginalMatchRoundResult) throws -> OriginalResultRecording.Continuation {
        guard let input = section.resultRecording, section.label == "result-recording",
              section.end.pc == 0x422944, section.end.sp == 0x1000e9bc,
              section.helpers.isEmpty, section.checkpoints.isEmpty, section.readsBeforeWrites.isEmpty,
              section.before.frameHeap != nil, section.after.frameHeap != nil,
              section.before.menuBitmaps != nil, section.after.menuBitmaps != nil,
              state.arithmeticPrecision == .bits53, round.continuation == .gameplay,
              round.stageDefeated == input.stageDefeatedBefore, input.stageDefeatedAfter == input.stageDefeatedBefore,
              input.fpcw == 0x23f, input.fpswBefore == 0x4000, input.fpswAfter == input.fpswBefore,
              input.fptagBefore == 0xffff, input.fptagAfter == input.fptagBefore,
              input.fromLastRoundInitialization.count == 1,
              let producer = input.fromLastRoundInitialization.first,
              producer.pc == 0x41d7d7, producer.sp == 0x1000e9bc, producer.address == 0x1000ea20,
              producer.size == 4, producer.write, producer.reportedValue == round.stageDefeated else {
            throw error("Own result/stack/FPU provenance")
        }
        let result = try OriginalResultRecording.apply(state: &state, context: &context,
            stageDefeated: round.stageDefeated, allocate: { throw error("Unexpected own writer allocation") },
            processorSignature: { throw error("Unexpected own processor request") },
            open: { _ in throw error("Unexpected own recording open") }, write: { _ in throw error("Unexpected own recording write") },
            close: { throw error("Unexpected own recording close") }, observe: { _ in throw error("Unexpected own recording event") })
        guard result.continuation.rawValue == section.end.pc, result.writer == nil else { throw error("Own continuation") }
        return result.continuation
    }
}
