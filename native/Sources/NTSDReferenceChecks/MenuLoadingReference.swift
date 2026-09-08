import Foundation
import NTSDCore

/// Own early-menu state continues into the shared full loading composition.
/// Expected snapshots check the handoff and final records; they never seed it.
public enum MenuLoadingReference {
    public struct Result {
        public let menu: FrontMenuLoopReference.Result, loading: InitialLoadingReference.Result
        public let draws: Int, reads: Int, clips: Int, blits: Int, helpers: Int, records: Int, bytes: Int
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Record: Decodable { let address: UInt32, live: Bool, storage: Storage }
    private struct Snapshot: Decodable { let globals: String, world: Storage, crtState: UInt32, pointers: [UInt8], records: [Record] }
    private struct Entry: Decodable { let pc: UInt32, sp: UInt32, returnPC: UInt32, target: UInt32 }
    private struct Helper: Decodable { let entry: UInt32, entrySP: UInt32, returnPC: UInt32, pop: UInt32, saved: [UInt32], returnSP: UInt32, result: UInt32 }
    private struct Draw: Decodable { let entrySP: UInt32, returnPC: UInt32, input: [UInt32], drawResults: [Int32], events: [OriginalFrontScreenEvent], helpers: [Helper], returnSP: UInt32, result: UInt32 }
    private struct Corpus: Decodable { let loadingEntry: Entry, loadingDraws: [Draw], afterLoading: Snapshot, blobs: [String:Blob] }
    private struct LoadingIdentity: Decodable { let worldAddress: UInt32, actorAddresses: [UInt32], entrySP: UInt32, bodySP: UInt32 }
    private struct CatalogIdentity: Decodable { let catalogAddress: UInt32 }
    private struct SoundIdentity: Decodable {
        struct Call: Decodable { let index: Int, input: OriginalWavePlatform, outputBefore: UInt32 }
        let calls: [Call]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Menu loading reference: "+text) }
    public static func compare(menu: Data,loading: Data,catalog: Data,sounds: Data,
                               onLoaded: (OriginalInitialLoading,OriginalCRTRandom,OriginalMenuPresentationMemory) throws -> Void = { _,_,_ in }) throws -> Result {
        let raw = try MatchPreparationReference.unpack(menu,maximumCount: 128_000_000),c = try JSONDecoder().decode(Corpus.self,from: raw)
        let identity = try JSONDecoder().decode(LoadingIdentity.self,from: MatchPreparationReference.unpack(loading))
        let catalogIdentity = try JSONDecoder().decode(CatalogIdentity.self,from: MatchPreparationReference.unpack(catalog))
        guard c.loadingEntry.pc == 0x41bc90,c.loadingEntry.sp == 0x1000eff8,c.loadingEntry.returnPC == 0x424746,c.loadingEntry.target == 0x28002020,
              identity.entrySP == c.loadingEntry.sp,identity.worldAddress == 0x22000020,identity.actorAddresses.count == 400 else { throw error("Actual menu/loading caller") }
        var blobs: [String:[UInt8]] = [:],recordCount = 0,byteCount = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let value = blobs[key] { return value };guard let b = c.blobs[key],b.sha256 == key else { throw error("Blob binding") }
            let bytes = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob SHA") };blobs[key] = bytes;return bytes
        }
        func storage(_ ref: Storage) throws -> OriginalStateRecord {
            let bytes = try blob(ref.bytes),mask = try blob(ref.defined)
            guard bytes.count == mask.count,mask.allSatisfy({ $0 < 2 }) else { throw error("Storage mask") }
            return try .init(bytes: bytes,defined: mask.map { $0 != 0 })
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual == expected else {
                let i = actual.bytes.indices.first { $0 >= expected.bytes.count || actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                throw error(label+" storage+"+(i.map { String($0,radix:16) } ?? "extent"))
            };recordCount += 1;byteCount += actual.bytes.count
        }
        var owned: (world:OriginalStateRecord,globals:OriginalStateRecord,crt:OriginalCRTRandom,memory:OriginalMenuPresentationMemory)?
        let menuResult = try FrontMenuLoopReference.compare(menu) { world,globals,crt,memory in
            guard owned == nil,try world.integer(at: 0,as: Int32.self) == 2 else { throw error("Own World2 handoff") };owned = (world,globals,crt,memory)
        }
        guard let own = owned else { throw error("Missing native early-menu continuation") }
        let base = OriginalMatchPreparation.globalBase
        // Loading's two common clears and its18 sound slots do not touch the
        // catalog's400 output words. Each new registry slot inherits our own
        // before value; its device is the retained original audio binding.
        let soundIdentity = try JSONDecoder().decode(SoundIdentity.self,from: MatchPreparationReference.unpack(sounds))
        let device = try own.globals.integer(at: 0x44eecc-base,as: UInt32.self)
        guard soundIdentity.calls.count == 400 else { throw error("Source registered audio inventory") }
        for (index,call) in soundIdentity.calls.enumerated() {
            guard call.index == index,call.input.device == device,
                  try own.globals.integer(at: 0x452948-base+index*4,as: UInt32.self) == call.outputBefore else { throw error("Own initial catalog audio bindings") }
        }
        let width = try own.globals.integer(at: 0x44d78c-base,as: Int32.self),height = try own.globals.integer(at: 0x44d790-base,as: Int32.self)
        var drawIndex = 0,reads = 0,clips = 0,blits = 0,helpers = 0
        let loaded = try InitialLoadingReference.compare(loading: loading,catalog: catalog,sounds: sounds,initialState: (own.world,own.globals),onCommonEvent: { event in
            guard let p = event.presentation,p.kind == .bitmap else { return }
            guard drawIndex < c.loadingDraws.count else { throw error("Excess common draw") };let d = c.loadingDraws[drawIndex];drawIndex += 1
            let args = p.arguments
            guard args == d.input,args.count == 7,args[6] == c.loadingEntry.target,!d.drawResults.isEmpty,
                  d.entrySP == identity.bodySP-28,d.returnSP == identity.bodySP,d.returnPC == 0x41beae,
                  let bitmap = own.memory.allocations[args[0]],bitmap.live else { throw error("Live MENU_WAIT/caller binding") }
            var index = 0,blitIndex = 0
            func emit(_ e: OriginalFrontScreenEvent) throws {
                guard index < d.events.count,e == d.events[index] else { throw error("Common bitmap event\(index): \(e)") };index += 1
            }
            try emit(.init("draw",args))
            let input = OriginalBitmapDrawInput(x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),frame: Int32(bitPattern: args[3]),colorKey: args[4],mirrored: args[5],
                sourceSurface: try bitmap.storage.integer(at: 0,as: UInt32.self),targetSurface: args[6],viewportWidth: width,viewportHeight: height)
            var canonical = bitmap.storage;try canonical.write(UInt32(input.sourceSurface == 0 ? 0 : 1),at: 0)
            let result = try OriginalBitmapDrawing.draw(input,bitmap: canonical,observeRead: { r in
                var e = OriginalFrontScreenEvent("read");e.read = r;try emit(e);reads += 1
            },observeClip: { clip in
                var e = OriginalFrontScreenEvent("clip");e.clip = clip;try emit(e);clips += 1
            },perform: { blit in
                var e = OriginalFrontScreenEvent("blit");e.blit = blit;try emit(e);blits += 1
                defer { blitIndex += 1 };return d.drawResults[blitIndex%d.drawResults.count]
            })
            guard index == d.events.count,UInt32(bitPattern: result) == d.result else { throw error("Common bitmap result/events") }
            for h in d.helpers {
                guard h.saved.count == 4,h.returnSP == h.entrySP+4+h.pop,
                      h.entry == 0x43f010 && h.pop == 24 && h.returnPC == 0x41beae || h.entry == 0x43ef70 && h.pop == 0 && [0x43f0d5,0x43f212].contains(h.returnPC) else { throw error("Common graphics helper ABI") };helpers += 1
            }
        },onLoaded: { native in
            let bytes = try blob(c.afterLoading.globals)
            guard bytes.count == OriginalMatchPreparation.globalSize else { throw error("Final globals extent") }
            try check(native.globals,OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count)),"Final globals")
            var expected = try storage(c.afterLoading.world)
            guard try expected.integer(at: 0x7d4,as: UInt32.self) == catalogIdentity.catalogAddress else { throw error("World/catalog binding") };try expected.write(UInt32(0),at: 0x7d4)
            for (i,address) in identity.actorAddresses.enumerated() {
                guard try expected.integer(at: 0x194+i*4,as: UInt32.self) == address else { throw error("World/Actor binding") };try expected.write(UInt32(i),at: 0x194+i*4)
            }
            try check(native.bootstrap.world,expected,"Same World after loading")
            guard c.afterLoading.records.count == own.memory.allocations.count,Set(c.afterLoading.records.map(\.address)).count == c.afterLoading.records.count,
                  own.crt.state == c.afterLoading.crtState,own.memory.replayPointers.bytes == c.afterLoading.pointers else { throw error("Retained ownership/CRT/pointers") }
            for r in c.afterLoading.records {
                guard let bitmap = own.memory.allocations[r.address],bitmap.live == r.live else { throw error("Retained early allocation") }
                try check(bitmap.storage,storage(r.storage),"Retained early bitmap")
            }
            try onLoaded(native,own.crt,own.memory)
        })
        guard drawIndex == c.loadingDraws.count,drawIndex == 1 else { throw error("Initial MENU_WAIT inventory") }
        return .init(menu: menuResult,loading: loaded,draws: drawIndex,reads: reads,clips: clips,blits: blits,helpers: helpers,records: recordCount,bytes: byteCount)
    }
}
