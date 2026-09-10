import Foundation
import NTSDCore

public enum FrontMenuCompletionReference {
    public struct Result {
        public var cases = 0, main = 0, tails = 0, worldOne = 0, errors = 0, helpers = 0, events = 0, draws = 0, clips = 0, reads = 0, blits = 0, random = 0, tables = 0, frees = 0, formats = 0, posts = 0, records = 0, bytes = 0
        public var parent = FrontScreenAlternateReference.Result()
        public var libraryText: OriginalLibSurfaceText?
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Record: Decodable { let address: UInt32, live: Bool, storage: Storage }
    private struct Snapshot: Decodable { let globals: String, world: Storage, crtState: UInt32, pointers: [UInt8], records: [Record] }
    private struct Helper: Decodable { let entry: UInt32, entrySP: UInt32, returnPC: UInt32, pop: UInt32, saved: [UInt32], returnSP: UInt32, result: UInt32 }
    private struct Random: Decodable { let before: UInt32, after: UInt32, result: UInt32 }
    private struct ABI: Decodable { let endPC: UInt32, endSP: UInt32, saved: [UInt32], seh: UInt32 }
    private struct Input: Decodable { let menu: OriginalMainMenuInput, presentation: OriginalMenuPresentationInput, drawResults: [Int32] }
    private struct Case: Decodable {
        let label: String, entry: String, stimulus: [InputControlReference.GlobalWrite], input: Input, mainExit: OriginalMainMenuExit?, mainAfter: Snapshot?, mainEvents: Int?
        let libraryDCBefore: UInt32?, libraryDCAfter: UInt32?
        let events: [OriginalFrontScreenEvent], helpers: [Helper], random: [Random], after: Snapshot, abi: ABI
    }
    private struct Corpus: Decodable { let exeSHA256: String, dllSHA256: String, initialGlobals: String, initialCRT: UInt32, initialPointers: [UInt8], cases: [Case], blobs: [String:Blob] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Front menu completion reference: "+text) }
    public static func compare(_ data: Data,libraryEnabled: Bool = false,onNatural: ((OriginalStateRecord,OriginalStateRecord,OriginalCRTRandom,[UInt32:OriginalLoadedBitmap],[UInt32:UInt32],OriginalMenuPresentationMemory) throws -> Void)? = nil) throws -> Result {
        let raw = try MatchPreparationReference.unpack(data,maximumCount: 128_000_000),c = try JSONDecoder().decode(Corpus.self,from: raw)
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",!c.cases.isEmpty,c.initialCRT == 1,c.initialPointers == [UInt8](repeating: 0,count: 8) else { throw error("Source identity/fresh PTD/BSS") }
        var result = Result(),blobs: [String:[UInt8]] = [:],cache: [String:OriginalStateRecord] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = blobs[key] { return bytes };guard let b = c.blobs[key],b.sha256 == key else { throw error("Blob binding") }
            let bytes = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob SHA") };blobs[key] = bytes;return bytes
        }
        func globals(_ key: String) throws -> OriginalStateRecord {
            if let value = cache[key] { return value };let bytes = try blob(key)
            guard bytes.count == OriginalMatchPreparation.globalSize else { throw error("Globals extent") }
            let value = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count));cache[key] = value;return value
        }
        func storage(_ ref: Storage) throws -> OriginalStateRecord {
            let key = ref.bytes+ref.defined;if let value = cache[key] { return value };let bytes = try blob(ref.bytes),mask = try blob(ref.defined)
            guard bytes.count == mask.count,mask.allSatisfy({ $0 < 2 }) else { throw error("Storage mask") }
            let value = try OriginalStateRecord(bytes: bytes,defined: mask.map { $0 != 0 });cache[key] = value;return value
        }
        func check(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
            guard actual == expected else {
                let i = actual.bytes.indices.first { $0 >= expected.bytes.count || actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                throw error(label+" storage+"+(i.map { String($0,radix:16) } ?? "extent"))
            };result.records += 1;result.bytes += actual.bytes.count
        }
        guard let document = try JSONSerialization.jsonObject(with: raw) as? [String:Any],var parent = document["parent"] as? [String:Any] else { throw error("Parent document") }
        parent["blobs"] = document["blobs"]
        var ownWorld: OriginalStateRecord?,ownGlobals: OriginalStateRecord?,ownLocal: OriginalStateRecord?
        var early: [UInt32:OriginalLoadedBitmap] = [:],tokens: [UInt32:UInt32] = [:]
        var memory = OriginalMenuPresentationMemory(replayPointers: try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 8),defined: [Bool](repeating: true,count: 8)))
        result.parent = try FrontScreenAlternateReference.compare(JSONSerialization.data(withJSONObject: parent),libraryEnabled: libraryEnabled) { world,state,local,bitmaps,surfaces in
            try check(state,globals(c.initialGlobals),"Own native alternate parent");ownWorld = world;ownGlobals = state;ownLocal = local
            early = bitmaps;tokens = surfaces
            for (address,bitmap) in bitmaps {
                guard let surface = surfaces[address] else { throw error("Declared parent surface") }
                var record = bitmap.storage;try record.write(surface,at: 0)
                memory.allocations[address] = .init(storage: record)
            }
        }
        guard var world = ownWorld,var state = ownGlobals,let local = ownLocal else { throw error("Missing native parent") }
        let target = local.bytes[0x20..<0x24].enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
        var crt = OriginalCRTRandom()
        var libraryText = result.parent.parent.libraryText
        guard (libraryText != nil) == libraryEnabled else { throw error("Library parent route") }
        let helperReturns: [UInt32:Set<UInt32>] = [
            0x43ef70:[0x43f0d5,0x43f212],0x43f010:[0x42471c,0x427937,0x4279f0,0x427a90,0x427b9c,0x427bf6,0x427c58,0x428778],
            0x423b00:[0x427a60,0x427bd4,0x427c2e,0x427c9f],0x4028a0:[0x424728,0x42877e],0x43e940:[0x424733,0x428789],
            0x422ac0:[0x427a31,0x427a76],0x401a30:[0x427a19,0x427ab9,0x427bbf,0x427c19,0x427c74],
            0x402a60:[0x402b28],0x402ad0:[0x402c4d],0x402b60:[0x427acb],0x401290:[0x40293d,0x4029cd,0x402a09,0x402a47],
            0x401f30:[0x40283e],0x402810:[0x4028ea],0x4019b0:[0x4287b7],0x401d30:[0x4287bc],0x43d280:[0x43d2aa,0x43d2b4],
            0x43d2a0:[0x4287c1],0x43ef50:[0x42391f],0x423910:[0x424708]
        ]
        func snapshot(_ s: Snapshot,_ label: String) throws {
            try check(state,globals(s.globals),label+" globals");try check(world,storage(s.world),label+" World")
            guard crt.state == s.crtState,memory.replayPointers.bytes == s.pointers,s.records.count == memory.allocations.count else { throw error(label+" CRT/pointers/ownership") }
            for r in s.records {
                guard let own = memory.allocations[r.address],own.live == r.live else { throw error(label+" live allocation") }
                try check(own.storage,storage(r.storage),label+" bitmap")
            }
        }
        for (caseIndex,item) in c.cases.enumerated() {
            guard caseIndex != 0 || item.stimulus.isEmpty && item.entry == "main",item.input.menu.targetSurface == target,item.input.presentation.targetSurface == target,!item.input.drawResults.isEmpty else { throw error("Caller/device inputs") }
            for write in item.stimulus {
                let bytes = Array(write.bytes);guard bytes.count%2 == 0 else { throw error("Stimulus extent") }
                for i in stride(from: 0,to: bytes.count,by: 2) {
                    guard let byte = UInt8(String(bytes[i...i+1]),radix: 16) else { throw error("Stimulus byte") }
                    try state.write(byte,at: Int(write.address)-OriginalMatchPreparation.globalBase+i/2)
                }
            }
            var index = 0,blits = 0,randomIndex = 0
            // Drawing reads these inputs; menu/overlay do not write viewport size.
            let width = try state.integer(at: 0x44d78c-OriginalMatchPreparation.globalBase,as: Int32.self),height = try state.integer(at: 0x44d790-OriginalMatchPreparation.globalBase,as: Int32.self)
            func event(_ e: OriginalFrontScreenEvent) throws {
                guard index < item.events.count,e == item.events[index] else { throw error("\(item.label) event\(index): \(e); expected \(index < item.events.count ? String(describing:item.events[index]) : "end")") }
                index += 1;result.events += 1
                switch e.kind {
                case "draw":result.draws += 1
                case "clip":result.clips += 1
                case "read":result.reads += 1
                case "blit":result.blits += 1
                case "free":result.frees += 1
                case "format","formatAddress":result.formats += 1
                case "postMessage":result.posts += 1
                default:break
                }
            }
            // Separate value copy avoids overlapping inout access during a
            // presentation release. The only released bitmap is the background;
            // subsequent World1 drawing uses the distinct retained MENU_WAIT.
            let drawMemory = memory.allocations
            func draw(_ args: [UInt32]) throws {
                try event(.init("draw",args))
                guard let bitmap = drawMemory[args[0]],bitmap.live else { throw error("Unbound/dead bitmap draw") }
                let input = OriginalBitmapDrawInput(x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),frame: Int32(bitPattern: args[3]),colorKey: args[4],mirrored: args[5],
                    sourceSurface: try bitmap.storage.integer(at: 0,as: UInt32.self),targetSurface: args[6],viewportWidth: width,viewportHeight: height)
                // Ownership/release stores raw COM tokens. Drawing takes the
                // established canonical record plus its explicit raw binding.
                var drawing = bitmap.storage;try drawing.write(UInt32(input.sourceSurface == 0 ? 0 : 1),at: 0)
                _ = try OriginalBitmapDrawing.draw(input,bitmap: drawing,observeRead: { r in
                    var e = OriginalFrontScreenEvent("read");e.read = r;try event(e)
                },observeClip: { c in
                    var e = OriginalFrontScreenEvent("clip");e.clip = c;try event(e)
                },perform: { b in
                    var e = OriginalFrontScreenEvent("blit");e.blit = b;try event(e)
                    defer { blits += 1 };return item.input.drawResults[blits%item.input.drawResults.count]
                })
            }
            var presentation: OriginalMenuPresentationEntry = .tail
            if item.entry == "main" {
                let exit = try OriginalMainMenu.run(world: &world,globals: &state,crt: &crt,input: item.input.menu) { e in
                    if e.kind == .bitmap { try draw(e.arguments);return }
                    if e.kind == .randomTable {
                        guard e.arguments.count == 2 else { throw error("RNG event") };var random = OriginalCRTRandom(state: e.arguments[0])
                        for _ in 0..<3000 {
                            guard randomIndex < item.random.count else { throw error("Excess RNG") };let r = item.random[randomIndex];randomIndex += 1
                            guard random.state == r.before,random.next() == r.result,random.state == r.after else { throw error("Actual DLL RNG") };result.random += 1
                        }
                        guard random.state == e.arguments[1] else { throw error("Table CRT state") };result.tables += 1
                    }
                    try event(.init(e.kind.rawValue,e.arguments,e.strings))
                }
                guard exit == item.mainExit,index == item.mainEvents,let after = item.mainAfter else { throw error("Main exit") };try snapshot(after,item.label+" main exit")
                presentation = exit == .present ? .tail : .epilogue;result.main += 1
                if exit == .returnWithoutPresentation { result.errors += 1 }
            } else if item.entry == "worldOne" { presentation = .worldOne;result.worldOne += 1 }
            else { guard item.entry == "tail" else { throw error("Entry") } }
            if presentation == .tail { result.tails += 1 }
            func presentEvent(_ e: OriginalMenuPresentationEvent) throws {
                if e.kind == .bitmap { try draw(e.arguments) }
                else { try event(.init(e.kind.rawValue,e.arguments,e.strings)) }
            }
            if libraryEnabled {
                guard item.libraryDCBefore == libraryText!.retainedDC else { throw error("Own library DC before completion") }
                try OriginalMenuPresentation.applyWithLibrary(presentation,input: item.input.presentation,world: &world,globals: &state,memory: &memory,libraryText: &libraryText!,observe: presentEvent)
                guard item.libraryDCAfter == libraryText!.retainedDC else { throw error("Own library DC after completion") }
                result.libraryText = libraryText
            } else { try OriginalMenuPresentation.apply(presentation,input: item.input.presentation,world: &world,globals: &state,memory: &memory,observe: presentEvent) }
            guard index == item.events.count,randomIndex == item.random.count,item.abi.endPC == 0x30000000,item.abi.endSP == 0x1000f42c,
                  item.abi.saved == [0x11223344,0x22334455,0x33445566,0x44556677],item.abi.seh == 0x12345678 else { throw error("Final events/ABI") }
            for h in item.helpers {
                let pop: UInt32 = h.entry == 0x43f010 ? 24 : h.entry == 0x401a30 ? 4 : 0
                guard h.pop == pop,h.saved.count == 4,h.returnSP == h.entrySP+4+pop,helperReturns[h.entry]?.contains(h.returnPC) == true else { throw error("Helper ABI") };result.helpers += 1
            }
            try snapshot(item.after,item.label+" return")
            if caseIndex == 0 { try onNatural?(world,state,crt,early,tokens,memory) }
            result.cases += 1
        }
        return result
    }
}
