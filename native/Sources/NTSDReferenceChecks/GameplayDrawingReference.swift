import Foundation
import NTSDCore

/// Own World draw, after the independently reconstructed camera/background.
enum GameplayDrawingReference {
    struct Result { let helpers: Int,events: Int }
    static func error(_ detail: String) -> OriginalStateError { .invalidStorage("Gameplay drawing reference: "+detail) }
    static func compare(_ section: MatchLaunchReference.Control.Section,state: inout OriginalMatchPreparation,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord,UInt32),
        snapshot: (OriginalMatchPreparation,MatchLaunchReference.State,String) throws -> Void) throws -> Result {
        guard let d = section.drawing,let phase = d.phase,let resourceSurfaces = d.resourceSurfaces,
              section.end.pc == 0x41f4ac,section.end.sp == 0x1000e9bc,
              section.before.frameHeap != nil,section.after.frameHeap != nil,section.before.menuBitmaps != nil,section.after.menuBitmaps != nil,section.checkpoints.isEmpty,
              d.target == 0x28002020,d.surfaces.count == section.before.bitmaps.count,d.drawResults == [0,1],d.fillInputs.isEmpty,
              phase == (try state.globals.integer(at: 0x450bd8-0x44d000,as: Int32.self)),
              d.mode == (try state.globals.integer(at: 0x451160-0x44d000,as: Int32.self)) else { throw error("Boundary/inputs") }
        let pop: [UInt32:UInt32] = [0x41a5a0:12,0x40de30:12,0x40be70:28,0x40bf30:4,0x43f010:24,0x43ef70:0,0x43f310:28,0x4450b2:0]
        for h in section.helpers {
            guard pop[h.entry] == h.pop,h.returnSP == h.entrySP+4+h.pop,h.saved.count == 4 else { throw error("Helper ABI") }
            if h.entry == 0x41a5a0 {
                guard h.this == 0x22000020,h.arguments == [d.target,UInt32(bitPattern: phase),UInt32(bitPattern: d.mode)],h.returnPC == 0x41f4ac else { throw error("Whole World caller") }
            }
        }
        guard section.helpers.filter({ $0.entry == 0x41a5a0 }).count == 1 else { throw error("Missing whole helper") }
        let catalogIndices = section.before.bitmaps.indices.filter { state.interface.bitmaps[section.before.bitmaps[$0].address] == nil }
        guard catalogIndices.count == state.bitmaps.count else { throw error("Catalog bitmap inventory") }
        for (n,index) in catalogIndices.enumerated() {
            guard d.surfaces[index] == (state.bitmaps[n].input.present ? 0x24000000 : 0) else { throw error("Retained surface binding") }
        }
        let ownedCatalog = state.bitmaps,ownedInterface = state.interface.bitmaps
        let sourceIndices = Dictionary(uniqueKeysWithValues: section.before.bitmaps.enumerated().map { ($0.element.address,$0.offset) })
        let nativeIndices = Dictionary(uniqueKeysWithValues: catalogIndices.enumerated().map { (section.before.bitmaps[$0.element].address,$0.offset) })
        func resource(_ token: UInt32) throws -> (OriginalStateRecord,UInt32) {
            let bitmap: OriginalLoadedBitmap
            if let value = ownedInterface[token] { bitmap = value }
            else if let index = nativeIndices[token] { bitmap = ownedCatalog[index] }
            else { return try resourceBitmap(token) }
            guard let index = sourceIndices[token],d.surfaces[index] == (bitmap.input.present ? 0x24000000 : 0) else { throw error("Global catalog/interface resource") }
            return (bitmap.storage,d.surfaces[index])
        }
        let expectedResources = try [0x44faf4,0x44f888,0x44fcbc,0x44fb68,0x44faf8,0x44fd80,0x44f8fc,0x44fd7c].map {
            try state.globals.integer(at: $0-0x44d000,as: UInt32.self)
        }
        guard Set(resourceSurfaces.keys) == Set(expectedResources.map(String.init)) else { throw error("Resource inventory") }
        for token in expectedResources {
            let (_,surface) = try resource(token)
            guard surface == resourceSurfaces[String(token)] else { throw error("Resource surface binding") }
        }
        for read in section.readsBeforeWrites {
            guard read.kind == "bitmap",read.size == 4,(0..<0x1f50).contains(read.offset),
                  (read.pc == 0x40bf9d || (0x43f010...0x43f37a).contains(read.pc)),
                  d.events.contains(where: { $0.read?.offset == read.offset && $0.read?.defined == false }) else { throw error("Unexpected undefined read") }
        }
        func surface(_ n: Int) throws -> UInt32 {
            guard catalogIndices.indices.contains(n) else { throw error("Surface ordinal") };return d.surfaces[catalogIndices[n]]
        }
        try snapshot(state,section.before,"own drawing before")
        // Separate failure-injection trial, never fed into the source or actual
        // continuation: first spark advances before the second device failure.
        var trial = state
        for (at,value) in [(0x36c,2),(0x3c0,4),(0x3c4,4),(0x370,400),(0x374,410),(0x398,300),(0x39c,310)] {
            try trial.actors[0].write(Int32(value),at: at)
        }
        let trialBefore = trial,sparkToken = try trial.globals.integer(at: 0x44f8fc-0x44d000,as: UInt32.self)
        var spark = false,sparkBlits = 0,stopped = false
        do {
            try OriginalWorldDrawing.apply(state: &trial,target: d.target,phase: phase,surface: surface,resourceBitmap: resource,performBlit: { _ in
                if spark { sparkBlits += 1;if sparkBlits == 2 { stopped = true;throw error("Injected spark device failure") } };return 0
            },observe: { e in if e.kind == "draw" { spark = e.arguments.first == sparkToken } else if e.kind == "rectangle" { spark = false } })
        } catch { if !stopped { throw error } }
        guard stopped,trial.actors == trialBefore.actors,trial.world == trialBefore.world,trial.globals == trialBefore.globals,
              trial.backgrounds == trialBefore.backgrounds,trial.frameAllocations == trialBefore.frameAllocations else { throw error("World draw public rollback") }
        // Restore only the deliberately changed trial records, then reuse the
        // full owned-state comparison for all untouched resource collections.
        trial.actors = state.actors;try snapshot(trial,section.before,"own drawing rollback")
        var seen = 0,blits = 0
        try OriginalWorldDrawing.apply(state: &state,target: d.target,phase: phase,surface: surface,resourceBitmap: resource,performBlit: { _ in
            defer { blits += 1 };return d.drawResults[blits%d.drawResults.count]
        },observe: { original in
            var event = original
            if event.kind == "draw" || event.kind == "width" || event.kind == "rectangle" {
                guard let token = event.arguments.first,token > 0 else { throw error("Draw token") }
                if catalogIndices.indices.contains(Int(token)-1) { event.arguments[0] = UInt32(catalogIndices[Int(token)-1]+1) }
                else if resourceSurfaces[String(token)] == nil { throw error("Resource token") }
                else if let index = sourceIndices[token] { event.arguments[0] = UInt32(index+1) }
            }
            guard seen < d.events.count,event == d.events[seen] else { throw error("Event \(seen): \(event)") };seen += 1
        })
        guard seen == d.events.count,blits == d.events.filter({ $0.kind == "blit" }).count else { throw error("Missing renderer events") }
        try snapshot(state,section.after,"own drawing after")
        return .init(helpers: section.helpers.count,events: seen)
    }
}
