import Foundation
import NTSDCore

/// Own first camera call, continuing the independently reconstructed launch.
/// Raw bitmap addresses are reference identities only, never engine pointers.

enum GameplayCameraReference {
    struct Result { let helpers: Int,events: Int }
    static func error(_ detail: String) -> OriginalStateError { .invalidStorage("Gameplay camera reference: "+detail) }
    static func compare(_ section: MatchLaunchReference.Control.Section,state: inout OriginalMatchPreparation,
        snapshot: (OriginalMatchPreparation,MatchLaunchReference.State,String) throws -> Void) throws -> Result {
        guard let d = section.drawing,section.end.pc == 0x41f496,section.end.sp == 0x1000e9bc,
              section.before.frameHeap != nil,section.after.frameHeap != nil,section.checkpoints.isEmpty,
              d.target == 0x28002020,d.surfaces.count == section.before.bitmaps.count,d.drawResults == [0,1],d.fillResult == 0,
              d.mode == (try state.globals.integer(at: 0x451160-0x44d000,as: Int32.self)) else { throw error("Boundary/inputs") }
        let pop: [UInt32:UInt32] = [0x41b5d0:8,0x41a250:4,0x41a050:4,0x43f010:24,0x43ef70:0,0x415160:0,0x4450d0:0]
        for h in section.helpers {
            guard pop[h.entry] == h.pop,h.returnSP == h.entrySP+4+h.pop,h.saved.count == 4 else { throw error("Helper ABI") }
            if h.entry == 0x41b5d0 {
                guard h.this == 0x22000020,h.arguments == [d.target,UInt32(bitPattern: d.mode)],h.returnPC == 0x41f496 else { throw error("Whole camera caller") }
            } else if h.entry == 0x41a250 {
                guard h.this == 0x22000020,h.arguments == [d.target],h.returnPC == 0x41bc80 else { throw error("Background caller") }
            }
        }
        guard section.helpers.filter({ $0.entry == 0x41b5d0 }).count == 1,
              section.helpers.filter({ $0.entry == 0x41a250 }).count == 1 else { throw error("Missing whole helpers") }
        // The catalog owns indices without the separate initial HUD wrappers.
        let catalogIndices = section.before.bitmaps.indices.filter { state.interface.bitmaps[section.before.bitmaps[$0].address] == nil }
        guard catalogIndices.count == state.bitmaps.count else { throw error("Catalog bitmap inventory") }
        for (n,index) in catalogIndices.enumerated() {
            guard d.surfaces[index] == (state.bitmaps[n].input.present ? 0x24000000 : 0) else { throw error("Retained surface binding") }
        }
        for read in section.readsBeforeWrites {
            guard read.kind == "bitmap",read.size == 4,(0..<0x1f50).contains(read.offset),
                  (0x43f010...0x43f2fe).contains(read.pc),d.events.contains(where: { $0.read?.offset == read.offset && $0.read?.defined == false }) else { throw error("Unexpected undefined read") }
        }
        func backing(_ hex: String) throws -> [UInt8] {
            let chars = Array(hex.utf8)
            guard chars.count == 200 else { throw error("Fill backing extent") }
            return try stride(from: 0,to: chars.count,by: 2).map {
                guard let b = UInt8(String(decoding: chars[$0..<$0+2],as: UTF8.self),radix: 16) else { throw error("Fill backing hex") };return b
            }
        }
        try snapshot(state,section.before,"own camera before")
        var seen = 0,fills = 0,blits = 0
        func fillBacking() throws -> [UInt8] {
            guard fills < d.fillInputs.count else { throw error("Extra fill") }
            defer { fills += 1 };return try backing(d.fillInputs[fills])
        }
        func surface(_ n: Int) throws -> UInt32 {
            guard catalogIndices.indices.contains(n) else { throw error("Surface ordinal") };return d.surfaces[catalogIndices[n]]
        }
        // Fail at the last bitmap Blt, after animation counters advanced. The public caller must
        // retain the entire pre-camera state, including BG animation counters.
        var trial = state,stopped = false,trialBlits = 0
        let expectedBlits = d.events.filter { $0.kind == "blit" }.count
        do {
            try OriginalWorldCamera.apply(state: &trial,mode: d.mode,target: d.target,surface: surface,fillBacking: fillBacking,
                performFill: { _ in d.fillResult },performBlit: { _ in
                    trialBlits += 1
                    if trialBlits == expectedBlits { stopped = true;throw error("Injected stop after bitmap child") }
                    return d.drawResults[(trialBlits-1)%d.drawResults.count]
                })
        } catch { if !stopped { throw error } }
        guard stopped else { throw error("Rollback did not reach bitmap child") }
        try snapshot(trial,section.before,"own camera rollback");fills = 0
        try OriginalWorldCamera.apply(state: &state,mode: d.mode,target: d.target,surface: surface,fillBacking: fillBacking,
            performFill: { _ in d.fillResult },performBlit: { _ in defer { blits += 1 };return d.drawResults[blits%d.drawResults.count] },observe: { original in
                var event = original
                if event.kind == "draw" {
                    guard let token = event.arguments.first,token > 0,catalogIndices.indices.contains(Int(token)-1) else { throw error("Draw token") }
                    event.arguments[0] = UInt32(catalogIndices[Int(token)-1]+1)
                }
                guard seen < d.events.count,event == d.events[seen] else { throw error("Event \(seen): \(event)") };seen += 1
            })
        guard seen == d.events.count,fills == d.fillInputs.count else { throw error("Missing output") }
        try snapshot(state,section.after,"own camera after")
        print("OWN CAMERA",seen,"events",fills,"fills",blits,"blits")
        return .init(helpers: section.helpers.count,events: seen)
    }
}
