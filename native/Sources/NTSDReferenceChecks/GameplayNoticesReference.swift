import Foundation
import NTSDCore

/// Own whole post-HUD caller. Raw untouched source stack bytes are evidence
/// of non-access, never initialization data for the native caller.
enum GameplayNoticesReference {
    struct Input: Decodable {
        struct Access: Decodable { let pc: UInt32, offset: Int, size: Int, write: Bool }
        let target: UInt32, dcResult: Int32, dc: UInt32, methodResult: Int32, flags: [String:UInt32]
        let events: [OriginalFrontScreenEvent], fillInputs: [String], localAccesses: [Access]
        let localBefore: String, localAfter: String, localWritten: [UInt8], esi: UInt32, edi: UInt32
        let fpcw: UInt16, fpswBefore: UInt16, fpswAfter: UInt16, fptagBefore: UInt16, fptagAfter: UInt16
    }
    struct Result { let helpers: Int, events: Int }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Gameplay notices reference: "+text) }

    static func compare(_ section: MatchLaunchReference.Control.Section, state: inout OriginalMatchPreparation,
        snapshot: (OriginalMatchPreparation,MatchLaunchReference.State,String) throws -> Void) throws -> Result {
        guard let n = section.notices, section.label == "post-hud-notices", section.end.pc == 0x421cdc, section.end.sp == 0x1000e9bc,
              section.helpers.isEmpty, section.checkpoints.isEmpty, section.readsBeforeWrites.isEmpty,
              section.before.frameHeap != nil, section.after.frameHeap != nil, section.before.menuBitmaps != nil, section.after.menuBitmaps != nil,
              state.arithmeticPrecision == .bits53, n.fpcw == 0x23f, n.fpswBefore == 0x4000, n.fpswAfter == n.fpswBefore,
              n.fptagBefore == 0xffff, n.fptagAfter == n.fptagBefore, n.esi == 0x7817775d, n.edi == 0,
              n.target == (try state.globals.integer(at: 0x455608-0x44d000, as: UInt32.self)),
              n.dcResult == 0, n.dc == 0x12345678, n.methodResult == 0,
              n.events.isEmpty, n.fillInputs.isEmpty, n.localAccesses.isEmpty,
              n.localBefore.count == 0x158*2, n.localAfter == n.localBefore,
              n.localWritten == [UInt8](repeating: 0, count: 0x158) else { throw error("Own source boundary") }
        let addresses = [0x450bec,0x450c2c,0x450c28,0x451160]
        guard Set(n.flags.keys) == Set(addresses.map { "0x"+String($0,radix:16) }) else { throw error("Flag inventory") }
        for address in addresses {
            let flag = try state.globals.integer(at: address-0x44d000, as: UInt32.self)
            guard flag == n.flags["0x"+String(address,radix:16)] else { throw error("Own flag provenance") }
        }
        try snapshot(state, section.before, "own notices before")
        // A separate native failure trial verifies that activating a writer
        // with unavailable backing cannot invent storage from source bytes.
        var trial = state
        try trial.globals.write(Int32(2), at: 0x450c28-0x44d000)
        var trialLocal: OriginalStateRecord?, rejected = false
        do {
            try OriginalPostHUDNotices.apply(state: trial, local: &trialLocal, dcResult: n.dcResult, dc: n.dc,
                fillBacking: { throw error("Trial unexpectedly filled") }, resourceBitmap: { _ in throw error("Trial unexpectedly resolved bitmap") },
                performFill: { _ in throw error("Trial unexpectedly performed fill") }, performBlit: { _ in throw error("Trial unexpectedly performed bitmap") },
                observe: { _ in throw error("Trial unexpectedly published event") })
        } catch OriginalStateError.invalidStorage(let message) where message == "Post-HUD notices: Caller string backing unavailable" { rejected = true }
        guard rejected, trialLocal == nil else { throw error("Unknown backing was manufactured") }
        var local: OriginalStateRecord?
        try OriginalPostHUDNotices.apply(state: state, local: &local, dcResult: n.dcResult, dc: n.dc,
            fillBacking: { throw error("Unexpected own fill backing read") }, resourceBitmap: { _ in throw error("Unexpected own resource resolution") },
            performFill: { _ in throw error("Unexpected own fill") }, performBlit: { _ in throw error("Unexpected own bitmap") },
            observe: { _ in throw error("Unexpected own event") })
        guard local == nil else { throw error("Unaccessed caller backing changed") }
        try snapshot(state, section.after, "own notices after")
        return .init(helpers: section.helpers.count, events: n.events.count)
    }
}
