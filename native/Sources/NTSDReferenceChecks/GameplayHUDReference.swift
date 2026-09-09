import Foundation
import NTSDCore

/// Complete own HUD on independently reconstructed match and bitmap state.
/// The source's discarded stack argument never supplies a native draw target.
enum GameplayHUDReference {
    struct Input: Decodable {
        struct Access: Decodable, Equatable { let pc: UInt32,offset: Int,size: Int,write: Bool }
        let argument: UInt32,retainedAfter: UInt32,argumentAccesses: [Access]
        let fpcw: UInt16,fpswBefore: UInt16,fpswAfter: UInt16,fptagBefore: UInt16,fptagAfter: UInt16
    }
    struct Result { let helpers: Int,events: Int }
    private static func error(_ detail: String) -> OriginalStateError { .invalidStorage("Gameplay HUD reference: "+detail) }
    static func compare(_ section: MatchLaunchReference.Control.Section,state: inout OriginalMatchPreparation,
        resourceBitmap: (UInt32) throws -> (OriginalStateRecord,UInt32),
        snapshot: (OriginalMatchPreparation,MatchLaunchReference.State,String) throws -> Void) throws -> Result {
        guard let h = section.hud,let d = section.drawing,let resourceSurfaces = d.resourceSurfaces,
              section.end.pc == 0x421a2d,section.end.sp == 0x1000e9bc,
              section.before.frameHeap != nil,section.after.frameHeap != nil,section.before.menuBitmaps != nil,section.after.menuBitmaps != nil,
              section.checkpoints.isEmpty,d.surfaces.count == section.before.bitmaps.count,d.drawResults == [0,1],d.fillInputs.isEmpty,
              d.target == (try state.globals.integer(at: 0x455608-0x44d000,as: UInt32.self)),
              state.arithmeticPrecision == .bits53,h.fpcw == 0x23f,h.fptagBefore == 0xffff,h.fptagAfter == 0xffff,
              h.fpswBefore >> 11 & 7 == 0,h.fpswAfter >> 11 & 7 == 0 else { throw error("Own source boundary") }
        guard h.argument == h.retainedAfter,h.argumentAccesses == [
            .init(pc: 0x421a15,offset: 0x68,size: 4,write: false),
            .init(pc: 0x421a19,offset: -4,size: 4,write: true)] else { throw error("Discarded argument provenance") }
        let abi: [UInt32:(Int,UInt32)] = [0x41ae60:(1,4),0x43f010:(6,24),0x43ef70:(6,0),0x43f310:(7,28)]
        for call in section.helpers {
            guard let (count,pop) = abi[call.entry],call.pop == pop,call.arguments.count == count,
                  call.returnSP == call.entrySP+4+pop,call.saved.count == 4 else { throw error("Helper ABI") }
            if call.entry == 0x41ae60 {
                guard call.this == 0x22000020,call.arguments == [h.argument],call.returnPC == 0x421a2d,
                      call.entrySP == 0x1000e9b4 else { throw error("Whole HUD caller") }
            }
        }
        guard section.helpers.filter({ $0.entry == 0x41ae60 }).count == 1 else { throw error("Missing whole HUD") }
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
        let expectedResources = try [0x4511a8,0x44faf4,0x44f888,0x44fcbc,0x44fb68,0x44faf8,0x44fd7c].map {
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
        try snapshot(state,section.before,"own HUD before")
        var seen = 0,blits = 0
        try OriginalWorldHUD.apply(state: &state,surface: surface,resourceBitmap: resource,performBlit: { _ in
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
        try snapshot(state,section.after,"own HUD after")
        return .init(helpers: section.helpers.count,events: seen)
    }
}
