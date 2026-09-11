import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalLibTournamentArenaReleaseTests: XCTestCase {
    typealias Base = OriginalCharacterMenuSurfaceTests
    typealias Music = OriginalCharacterMenuMusicSurfaceTests
    struct Environment: Equatable {
        var front: [OriginalFrontScreenEvent] = []
        var graphics = Base.Context()
        var music: [OriginalMusicEvent] = []
        var preparationGraphics = Base.Context()
        var freedWrappers: Set<UInt32> = []
    }
    struct Startup: Decodable {
        let musicBoundary: Music.Boundary, musicAllocations: [Base.Record], events: [Music.Event]
    }
    struct MusicSpec: Decodable { let nullAllocation: Bool? }
    struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    struct Transport: Decodable { let count: Int,sha256: String,deflateSHA256: String,deflateParts: [String] }
    struct Storage: Decodable { let bytes: String, defined: String }
    struct Record: Decodable { let address: UInt32, storage: Storage, live: Bool? }
    struct Spec: Decodable { let bridgeGlobals: [String:Int32]?, generation: Int; let assigned: [[Int]]?, localTime: [UInt16]?; let buttons: [[Int]]?; let label: String, control: Bool, music: MusicSpec?, chain: Bool?, dcResult: Int32?, dc: UInt32?, methodResult: Int32?, milliseconds: UInt32? }
    struct Point: Decodable { let name: String?; let kind: String,records: [Record],eventCount: Int,storeCount: Int,seat: UInt32?,locals: [String:UInt32]? }
    struct Helper: Decodable { let entry: UInt32,firstStore: Int,lastStore: Int? }
    struct Write: Decodable { let address: UInt32,bytes: String }
    struct Read: Decodable { let address: UInt32,count: Int,storeCount: Int }
    struct Case: Decodable {
        let helpers: [Helper],pending: [Helper],writes: [Write],reads: [Read],apiReads: [Read]
        let preparationGraphics: PreparationGraphics?
        let replayAddress: UInt32
        let spec: Spec, before: [Record], after: [Record], actorAddresses: [UInt32]
        let stimulus: [Write]?
        let bodyMusic: [Music.MusicEvent],musicAfter: [Base.Record]
        let events: [OriginalFrontScreenEvent], end: String, endSP: UInt32, cw: UInt32
        let startup: Startup, characterSP: UInt32?, screenSP: UInt32?,output: OriginalMenuPresentationInput,points: [Point]
    }
    struct Portrait: Decodable { let address: UInt32, surface: UInt32, width: Int32, height: Int32, path: String }
    struct Entry: Decodable { let ordinal: Int,id: Int32,type: Int32,address: UInt32,nameTail: String,nameMask: String,portrait: Portrait?,small: Portrait? }
    struct Roster: Decodable { let entries: [Entry] }
    struct CatalogDependency: Decodable { let bitmapAddresses: [UInt32],checksum: UInt32 }
    struct ConstructorCall: Decodable { let kind: String,address: UInt32,before: Storage,after: Storage }
    struct ConstructorParent: Decodable { let calls: [ConstructorCall] }
    struct Parent: Decodable { let firstCase: Int,constructors: ConstructorParent }
    struct PreparationGraphics: Decodable {
        let allocationStart: Int, constructionHistory: [Base.Helper], wrapperLive: [String:Bool]
        let events: [Base.Event],allocations: [Base.Allocation],records: [Base.Record]
        let helpers: [Base.Helper],images: [String:Base.Image],surfaces: [String:Base.Surface],dcs: [String:Bool]
    }
    struct Corpus: Decodable {
        let catalogDependency: CatalogDependency, assets: [String:Base.Asset], parents: [Parent]
        let roster: Roster
        let exeSHA256: String, libSHA256: String, cases: [Case], blobs: [String:Blob]
        let worldAddress: UInt32, bitmapAddress: UInt32, target: UInt32, libraryAddress: UInt32, stackAddress: UInt32, entrySP: UInt32, tailSP: UInt32
    }
    enum Stop: Error, Equatable { case injected, unexpected }
    final class Resources {
        let corpus: Corpus
        let startup: Base.Resources
        var decoded: [String:[UInt8]] = [:]
        let catalog: OriginalLoadedCatalog
        var bitmapAddresses: [Int:UInt32] = [:]
        init() throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_LIB_TOURNAMENT_ARENA_RELEASE"].map { URL(fileURLWithPath:$0) }
                ?? XCTUnwrap(Bundle.module.url(forResource:"original-lib-tournament-arena-release",withExtension:"json",subdirectory:"Fixtures"))
            let envelope=try Data(contentsOf:url)
            let data: Data
            if let parts=try? JSONDecoder().decode(Transport.self,from:envelope) {
                var deflate=Data()
                for name in parts.deflateParts {
                    guard !name.contains("/"),name.hasPrefix("original-lib-tournament-arena-release-part") else { throw Stop.unexpected }
                    let bytes=try Data(contentsOf:url.deletingLastPathComponent().appendingPathComponent(name))
                    deflate.append(try MatchPreparationReference.unpack(bytes,maximumCount:60_000_000))
                }
                XCTAssertEqual(MatchPreparationReference.digest(deflate),parts.deflateSHA256)
                let joined=try JSONSerialization.data(withJSONObject:["count":parts.count,"sha256":parts.sha256,"deflate":deflate.base64EncodedString()])
                data=try MatchPreparationReference.unpack(joined,maximumCount:2_000_000_000)
            } else { data=try MatchPreparationReference.unpack(envelope,maximumCount:2_000_000_000) }
            corpus = try JSONDecoder().decode(Corpus.self,from:data)
            // A lossless projection into the retained startup comparator schema.
            // Full source bytes remain in the new fixture; no expected fields change.
            let document = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
            var projected = document
            projected["assets"] = (document["assets"] as! [String:Any]).filter { OriginalMenuResourceLoading.paths.contains($0.key) }
            projected["cases"] = try XCTUnwrap(document["cases"] as? [[String:Any]]).map { $0["startup"]! }
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-lib-tournament-arena-release-"+UUID().uuidString+".json")
            try JSONSerialization.data(withJSONObject:projected).write(to:temporary)
            defer { try? FileManager.default.removeItem(at:temporary) }
            startup = try Base.Resources(url:temporary,expectedCases:51)
            XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
            XCTAssertEqual(corpus.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
            XCTAssertEqual(corpus.cases.count,51)
            XCTAssertEqual(corpus.worldAddress,0x22000020);XCTAssertEqual(corpus.bitmapAddress,0x27000020)
            XCTAssertEqual(corpus.target,0x26006000);XCTAssertEqual(corpus.libraryAddress,0x36000000)
            XCTAssertEqual(corpus.stackAddress,0x10000000);XCTAssertEqual(corpus.entrySP,0x1000f000);XCTAssertEqual(corpus.tailSP,0x1000e9bc)
            // Rebuild the whole accepted catalog through its normal loader.
            // New source snapshots supply comparisons, never Object inputs.
            let urlCatalog = try XCTUnwrap(Bundle.module.url(forResource:"original-loaded-catalog",withExtension:"json",subdirectory:"Fixtures"))
            var loaded: OriginalLoadedCatalog?
            _ = try LoadedCatalogReference.compare(Data(contentsOf:urlCatalog),onLoaded:{ loaded=$0 })
            catalog = try XCTUnwrap(loaded)
            XCTAssertEqual(catalog.objects.count,137)
            for entry in corpus.roster.entries {
                let object=catalog.objects[entry.ordinal]
                XCTAssertEqual(try object.header.integer(at:0x6f4,as:Int32.self),entry.id)
                XCTAssertEqual(try object.header.integer(at:0x6f8,as:Int32.self),entry.type)
                XCTAssertEqual(object.nameTail.bytes.map { String(format:"%02x",$0) }.joined(),entry.nameTail)
                XCTAssertEqual(object.nameTail.defined.map { $0 ? "01" : "00" }.joined(),entry.nameMask)
                if let portrait=entry.portrait {
                    let ref=try object.header.integer(at:0x6fc,as:UInt32.self);XCTAssertGreaterThan(ref,0)
                    let index=Int(ref-1);XCTAssertNil(bitmapAddresses[index]);bitmapAddresses[index]=0x72000020+UInt32(entry.ordinal)*0x2000
                    XCTAssertEqual(portrait.address,bitmapAddresses[index]);XCTAssertEqual(portrait.surface,0x24000000)
                    let bitmap=catalog.bitmaps[index];XCTAssertEqual(bitmap.input.path,portrait.path)
                    var expected=try OriginalStateRecord(bytes:[UInt8](repeating:0xa5,count:0x1f50),defined:[Bool](repeating:false,count:0x1f50))
                    try expected.write(UInt32(1),at:0);try expected.write(portrait.width,at:4);try expected.write(portrait.height,at:8)
                    XCTAssertEqual(bitmap.storage,expected)
                }
            }
            for entry in corpus.roster.entries {
                if let small=entry.small {
                    let ref=try catalog.objects[entry.ordinal].header.integer(at:0x728,as:UInt32.self);XCTAssertGreaterThan(ref,0)
                    let index=Int(ref-1);XCTAssertNil(bitmapAddresses[index]);bitmapAddresses[index]=0x74000020+UInt32(entry.ordinal)*0x2000
                    XCTAssertEqual(small.address,bitmapAddresses[index]);XCTAssertEqual(small.surface,0x24000000)
                    let bitmap=catalog.bitmaps[index];XCTAssertEqual(bitmap.input.path,small.path)
                    var expected=try OriginalStateRecord(bytes:[UInt8](repeating:0xa5,count:0x1f50),defined:[Bool](repeating:false,count:0x1f50))
                    try expected.write(UInt32(1),at:0);try expected.write(small.width,at:4);try expected.write(small.height,at:8)
                    XCTAssertEqual(bitmap.storage,expected)
                }
            }
            XCTAssertEqual(bitmapAddresses.count,84)
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes=decoded[key] { return bytes }
            let b=try XCTUnwrap(corpus.blobs[key]);XCTAssertEqual(b.sha256,key)
            let bytes=try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:12_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(bytes)),key);decoded[key]=bytes;return bytes
        }
        func record(_ record: Record) throws -> OriginalStateRecord {
            let raw=try blob(record.storage.bytes),mask=try blob(record.storage.defined)
            XCTAssertEqual(raw.count,mask.count);XCTAssertTrue(mask.allSatisfy { $0<2 })
            return try .init(bytes:raw,defined:mask.map { $0 != 0 })
        }
    }
    func compare(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String, privateZero: Bool = false) throws {
        XCTAssertEqual(actual.bytes.count,expected.bytes.count,label)
        for i in actual.bytes.indices {
            if actual.defined[i] != expected.defined[i] || (expected.defined[i] || !privateZero) && actual.bytes[i] != expected.bytes[i] || privateZero && !actual.defined[i] && actual.bytes[i] != 0 {
                XCTFail("\(label)+\(String(i,radix:16)): \(actual.bytes[i])/\(actual.defined[i]) expected \(expected.bytes[i])/\(expected.defined[i])");throw Stop.unexpected
            }
        }
    }
    struct Retained {
        var prepared: OriginalMatchPreparation
        var memory: OriginalMenuPresentationMemory
        var library: OriginalLibSurfaceText
        var music=OriginalMusicMemory(),resources=OriginalMenuResourceLoading()
        var environment=Environment()
    }
    func initialize(_ item: Case,_ r: Resources) throws -> Retained {
        XCTAssertNotEqual(item.spec.chain,true)
        let c=r.corpus,base=OriginalMatchPreparation.globalBase
        let before=try Dictionary(uniqueKeysWithValues:item.before.map { ($0.address,try r.record($0)) })
        let globals=try XCTUnwrap(before[UInt32(base)])
        // Independently rebuild the declared table with the already verified
        // native VC80/422ac0 producer. Source snapshots never choose its bytes.
        var random=OriginalCRTRandom(state:item.spec.control ? 0xffffffff : 17),produced=globals
        try random.rebuildGameTable(globals:&produced)
        let rngStart=0x44ff90-base
        XCTAssertEqual(Array(produced.bytes[rngStart...rngStart+3000]),Array(globals.bytes[rngStart...rngStart+3000]))
        XCTAssertTrue(globals.defined[rngStart...rngStart+3000].allSatisfy { $0 })
        // These are explicitly declared controlled entry bytes, never after-state.
        // World/Actor backing is a declared input; bind all400 Actor slots and the known catalog/Object owners.
        let pattern=(0..<OriginalStateRecord.actorSize).map { item.spec.control ? UInt8(($0*37+11)&255) : 0xa5 }
        var world=try OriginalStateRecord.worldPrefix(over:(0..<OriginalStateRecord.worldPrefixSize).map { item.spec.control ? UInt8(($0*37+11)&255) : 0xa5 })
        var actors=try (0..<400).map { _ in try OriginalStateRecord.actor(over:pattern) }
        for i in 0..<400 {
            try world.write(UInt32(i),at:0x194+i*4);try actors[i].write(UInt32(0),at:0x368)
        }
        try world.write(UInt32(0),at:0x7d4)
        for assignment in item.spec.assigned ?? [] {
            try world.write(UInt8(1),at:4+assignment[0]);try actors[assignment[0]].write(UInt32(assignment[2]),at:0x368)
        }
        for input in item.spec.buttons ?? [] { try actors[input[0]].write(UInt8(input[2]),at:input[1]) }
        XCTAssertEqual(try globals.integer(at:0x44f620-base,as:UInt32.self),r.catalog.checksum)
        var memory=OriginalMenuPresentationMemory(replayPointers:try XCTUnwrap(before[0x4588a8]))
        for record in item.before where record.live == true { memory.allocations[record.address] = .init(storage:try r.record(record),live:record.live!) }
        XCTAssertEqual(memory.allocations.count,8)
        // Build all five declared bitmap records ourselves; source bytes are checks.
        for i in 0..<5 {
            var bitmap=try OriginalStateRecord(bytes:[UInt8](repeating:0,count:0x1f50),defined:[Bool](repeating:true,count:0x1f50))
            for (offset,value): (Int,UInt32) in [(0,0x26004000+UInt32(i*16)),(4,64),(8,64),(12,500)] { try bitmap.write(value,at:offset) }
            for j in 0..<500 {
                for (offset,value): (Int,UInt32) in [(0x10,UInt32(j%8*8)),(0x7e0,UInt32(j%8*8)),(0xfb0,8),(0x1780,8)] { try bitmap.write(value,at:offset+j*4) }
            }
            let address=c.bitmapAddress+UInt32(i*0x2000)
            try compare(bitmap,try XCTUnwrap(before[address]),item.spec.label+" bitmap input")
            memory.allocations[address] = .init(storage:bitmap)
        }
        let panelAddress=c.bitmapAddress+(item.spec.control ? 0xc000 : 0xa000)
        var panel=try OriginalStateRecord(bytes:(0..<0x1f50).map { item.spec.control ? UInt8(($0*37+11)&255) : 0xa5 },defined:[Bool](repeating:false,count:0x1f50))
        for (offset,value): (Int,UInt32) in [(0,0x26004050),(4,794),(8,550),(12,11)] { try panel.write(value,at:offset) }
        let rects:[[UInt32]]=[[0,0,397,34],[397,0,397,34],[0,34,198,194],[198,34,198,194],[396,34,198,194],[594,34,198,194],[0,228,198,194],[198,228,198,194],[396,228,198,194],[594,228,198,194],[0,422,794,128]]
        for i in 0..<13 {
            let rect=i<11 ? rects[i] : [UInt32(i%8*8),UInt32(i%8*8),8,8]
            for (offset,value) in zip([0x10,0x7e0,0xfb0,0x1780],rect) { try panel.write(value,at:offset+i*4) }
        }
        try compare(panel,try XCTUnwrap(before[panelAddress]),item.spec.label+" own panel input")
        memory.allocations[panelAddress] = .init(storage:panel)
        let beforeLibrary=try XCTUnwrap(before[c.libraryAddress])
        let library=OriginalLibSurfaceText()
        XCTAssertEqual(library.retainedDC,try beforeLibrary.integer(at:0x306e,as:UInt32.self),item.spec.label+" own retained DC entry")
        let bootstrap = try OriginalWorldBootstrap(world:world,actorBacking:actors.map(\.bytes))
        var prepared = try OriginalMatchPreparation(catalog:r.catalog,bootstrap:bootstrap,globals:globals)
        prepared.world=world;prepared.actors=actors
        return Retained(prepared:prepared,memory:memory,library:library)
    }
    @discardableResult
    func run(_ item: Case,_ r: Resources,_ retained: inout Retained?,failure: String? = nil) throws -> Int {
        var initial=try retained ?? initialize(item,r)
        if item.spec.chain == true {
            for (address,value) in item.spec.bridgeGlobals ?? [:] {
                let a=try XCTUnwrap(Int(address));XCTAssertTrue([0x44d020,0x44d024,0x44d028].contains(a))
                try initial.prepared.globals.write(value,at:a-OriginalMatchPreparation.globalBase)
            }
            for change in item.spec.buttons ?? [] {
                XCTAssertEqual(change.count,3)
                try initial.prepared.actors[change[0]].write(UInt8(change[2]),at:change[1])
            }
        } else { XCTAssertNil(retained) }
        retained=initial
        let c=r.corpus,base=OriginalMatchPreparation.globalBase
        let before=try Dictionary(uniqueKeysWithValues:item.before.map { ($0.address,try r.record($0)) })
        let after=try Dictionary(uniqueKeysWithValues:item.after.map { ($0.address,try r.record($0)) })
        var prepared=initial.prepared,memory=initial.memory,library=initial.library
        var music=initial.music,resources=initial.resources,committed=initial.environment
        let globals=prepared.globals,world=prepared.world,actors=prepared.actors
        let initialGlobals=globals,initialMemory=memory,initialLibrary=library,initialWorld=world
        let initialActors=actors
        // The immutable manifest contains two different release calls with
        // the same label. Match both label and complete declared entry globals.
        let entryGlobals=try XCTUnwrap(item.before.first { $0.address==UInt32(base) }).storage.bytes
        let matches=r.startup.c.cases.indices.filter { r.startup.c.cases[$0].spec.label==item.spec.label && r.startup.c.cases[$0].before.globals==entryGlobals }
        XCTAssertEqual(matches.count,1)
        let startupIndex = try XCTUnwrap(matches.first)
        let a = try Base.Adapter(r.startup.c.cases[startupIndex],r.startup)
        var eventIndex=0,characterPoint=0,musicIndex=0,preparationPoint=0
        var preparationAdapter: OriginalTournamentArenaReleaseSurfaceAdapter?
        let firstFrontCount=committed.front.count
        func compareMusic(_ records: [Base.Record],_ memory: OriginalMusicMemory) throws {
            XCTAssertEqual(records.count,memory.allocations.count)
            for record in records {
                XCTAssertEqual(record.kind,"music-wide");XCTAssertEqual(record.count,26)
                XCTAssertEqual(try r.startup.blob(record.initial),a.pattern(record.count))
                let value=try XCTUnwrap(memory.allocations[record.address])
                XCTAssertEqual(value.bytes,try r.startup.blob(record.bytes))
                XCTAssertEqual(value.defined,try r.startup.blob(record.mask).map { $0 != 0 })
            }
        }
        func event(_ e: OriginalFrontScreenEvent,_ environment: inout Environment) throws {
            guard eventIndex<item.events.count else { XCTFail("Unexpected event \(e)");throw Stop.unexpected }
            let expected=item.events[eventIndex]
            if e.kind == "fill" {
                let a=try XCTUnwrap(e.fill),b=try XCTUnwrap(expected.fill)
                XCTAssertEqual(a.target,b.target);XCTAssertEqual(a.rectangle,b.rectangle);XCTAssertEqual(a.flags,b.flags);XCTAssertEqual(a.defined,b.defined)
                for i in a.effects.indices { XCTAssertEqual(a.effects[i],a.defined[i] ? b.effects[i] : 0) }
            } else if e != expected { XCTFail("\(item.spec.label) event\(eventIndex): \(e), expected \(expected)");throw Stop.unexpected }
            eventIndex += 1;environment.front.append(e)
            let currentEvents=environment.front.suffix(environment.front.count-firstFrontCount)
            if failure == "shuffle",e.kind == "random",[UInt32(0xf7),0xf8].contains(e.arguments[0]),
               currentEvents.filter({ $0.kind == "random" && [UInt32(0xf7),0xf8].contains($0.arguments[0]) }).count == 3 { throw Stop.injected }
            if failure == "controllerLabel",e.kind == "textOut",e.strings.first?.count == 1,
               currentEvents.filter({ $0.kind == "textOut" && $0.strings.first?.count == 1 }).count == 3 { throw Stop.injected }
            if failure == "text" && e.kind == "textOut" && environment.front.filter({ $0.kind == "textOut" }).count == 3 { throw Stop.injected }
            if failure == "draw" && e.kind == "blit" && environment.front.filter({ $0.kind == "blit" }).count == 4 { throw Stop.injected }
            if failure == "network" && e.kind == "textOut" && e.strings == [Array("Waiting for opponent...".utf8)] || failure == "volume" && e.kind == "method" && environment.front.filter({ $0.kind == "method" && $0.arguments[1] == 0x3c }).count == 5 || failure == "present" && e.kind == "method" && e.arguments[1] == 0x14 { throw Stop.injected }
        }
        func compareWorld(_ value: OriginalStateRecord,_ records: [Record]) throws {
            var expected=try r.record(XCTUnwrap(records.first { $0.address == c.worldAddress }))
            XCTAssertEqual(try expected.integer(at:0x7d4,as:UInt32.self),0x60000020);try expected.write(UInt32(0),at:0x7d4)
            for i in 0..<400 {
                let pointer=try expected.integer(at:0x194+i*4,as:UInt32.self)
                let index=try XCTUnwrap(item.actorAddresses.firstIndex(of:pointer));try expected.write(UInt32(index),at:0x194+i*4)
            }
            try compare(value,expected,item.spec.label+" World")
        }
        func compareState(_ value: OriginalMatchPreparation,_ records: [Record]) throws {
            let records=Dictionary(uniqueKeysWithValues:records.map { ($0.address,$0) })
            try compare(value.globals,r.record(XCTUnwrap(records[UInt32(base)])),item.spec.label+" globals")
            try compareWorld(value.world,Array(records.values))
            for (i,p) in item.actorAddresses.enumerated() {
                var expected=try r.record(XCTUnwrap(records[p]))
                let pointer=try expected.integer(at:0x368,as:UInt32.self)
                guard pointer>=0x68000020,(pointer-0x68000020)%0x40000==0 else { throw Stop.unexpected }
                let ordinal=(pointer-0x68000020)/0x40000;XCTAssertLessThan(ordinal,137)
                try expected.write(ordinal,at:0x368);try compare(value.actors[i],expected,item.spec.label+" Actor"+String(i))
            }
            let bitmapPointers=c.catalogDependency.bitmapAddresses+(item.preparationGraphics?.allocations.compactMap { $0.address } ?? [])
            for i in 0..<101 {
                let address: UInt32=0x60000020+0x4d45db0+UInt32(i*0x990)
                var expected=try r.record(XCTUnwrap(records[address]))
                for offset in Array(stride(from:0x914,through:0x988,by:4))+[0x98c] where expected.defined[offset..<offset+4].allSatisfy({ $0 }) {
                    let pointer=try expected.integer(at:offset,as:UInt32.self)
                    if pointer != 0 { try expected.write(UInt32(try XCTUnwrap(bitmapPointers.firstIndex(of:pointer))+1),at:offset) }
                }
                try compare(value.backgrounds[i],expected,item.spec.label+" BG"+String(i))
            }
        }
        func compareImages(_ records: [Base.Record],_ images: [UInt32:OriginalLoadedBitmap],_ buffer: Environment) throws {
            XCTAssertEqual(records.count,images.count)
            for record in records {
                let actual=try XCTUnwrap(images[record.address]);var expected=try r.startup.blob(record.bytes)
                let surface=try XCTUnwrap(buffer.graphics.surfaceForWrapper[record.address])
                XCTAssertEqual(Array(expected.prefix(4)),(0..<4).map { UInt8(truncatingIfNeeded:surface >> ($0*8)) })
                expected.replaceSubrange(0..<4,with:[1,0,0,0]);XCTAssertEqual(actual.storage.bytes,expected)
                XCTAssertEqual(actual.storage.defined,try r.startup.blob(record.mask).map { $0 != 0 })
                let i=Int((record.address-0x50000020)/0x2000);XCTAssertEqual(actual.input.path,OriginalMenuResourceLoading.paths[item.spec.control ? 10-i : i]);XCTAssertTrue(actual.input.present)
            }
        }
        try compareState(prepared,item.before)
        XCTAssertEqual(library.retainedDC,try XCTUnwrap(before[c.libraryAddress]).integer(at:0x306e,as:UInt32.self))
        do {
            let end=try OriginalCharacterMenuContinuation.advance(state:&prepared,memory:&memory,music:&music,resources:&resources,libraryText:&library,environment:&committed,includeTournamentBracket:true,
                target:c.target,input:.init(dcResult:item.spec.dcResult ?? 0,dc:item.spec.dc ?? 0x76543210,methodResult:item.spec.methodResult ?? -1,drawResults:[-1],shellResult:33),
                tournamentPreparation:{ scene,owned,env in
                    let pg=try XCTUnwrap(item.preparationGraphics)
                    let adapter=OriginalTournamentArenaReleaseSurfaceAdapter(pg,r);preparationAdapter=adapter
                    if item.spec.generation==0 { env.preparationGraphics=env.graphics }
                    try OriginalTournamentPreparation.prepare(state:&scene,memory:&owned,localTime:{
                        let t=item.spec.localTime ?? [2026,9,5,11,12,34,56,789]
                        return .init(year:t[0],month:t[1],dayOfWeek:t[2],day:t[3],hour:t[4],minute:t[5],second:t[6],milliseconds:t[7])
                    },constructBitmap:{ path,optional,backing in
                        var graphics=env.preparationGraphics
                        let result=try adapter.construct(path,optional,backing,&graphics) { try event(.init("preparationBitmap"),&env) }
                        env.preparationGraphics=graphics
                        if failure=="bitmap" { throw Stop.injected };return result
                    },releaseBitmap:{ index,bitmap in
                        var graphics=env.preparationGraphics
                        try adapter.release(index,bitmap,&graphics) { kind,token in
                            try event(.init("preparationBitmap"),&env)
                            if kind=="free" { XCTAssertTrue(env.freedWrappers.insert(token).inserted) }
                            if failure==kind { throw Stop.injected }
                        }
                        env.preparationGraphics=graphics
                    },allocateReplay:{ bytes in
                        XCTAssertEqual(bytes,0x630e18)
                        if failure=="allocateReplay" { throw Stop.injected };return item.replayAddress
                    },observe:{ try event($0,&env) },checkpoint:{ pc,value,allocation,name in
                        let points=item.points.filter { $0.kind.hasPrefix("preparation-") }
                        let expected=points[preparationPoint];preparationPoint += 1
                        XCTAssertEqual(expected.kind,"preparation-0x"+String(pc,radix:16));XCTAssertEqual(eventIndex,expected.eventCount)
                        try compareState(value,expected.records)
                        if pc != 0x4343c3 {
                            let text=try XCTUnwrap(expected.name),pairs=Array(text.utf8)
                            let bytes=try stride(from:0,to:pairs.count,by:2).map { try XCTUnwrap(UInt8(String(decoding:pairs[$0..<$0+2],as:UTF8.self),radix:16)) }
                            XCTAssertEqual(name,bytes)
                        }
                        if pc==0x434765 { try adapter.compareGlobals(value.globals) }
                        if pc==0x4347ba {
                            let pointer=try r.record(XCTUnwrap(expected.records.first { $0.address==0x4588a8 }))
                            try self.compare(allocation.replayPointers,pointer,"recording pointers")
                            let recorded=try r.record(XCTUnwrap(expected.records.first { $0.address==item.replayAddress }))
                            try self.compare(XCTUnwrap(allocation.allocations[item.replayAddress]).storage,recorded,"whole recording")
                            if failure=="recording" { throw Stop.injected }
                        }
                    })
                },outputInput:item.output,milliseconds:item.spec.milliseconds ?? 17,
                musicRequest:{ request,env in
                    let expected=item.bodyMusic[musicIndex];musicIndex += 1
                    XCTAssertEqual(request,.init(expected.kind,expected.arguments,expected.strings))
                    try event(.init(request.kind.rawValue,request.arguments,request.strings),&env)
                    var response=expected.response
                    if request.kind == .allocate {
                        let pointer: UInt32=item.spec.music?.nullAllocation == true ? 0 : 0x2c010020
                        response = .init(pointer:pointer,bytes:pointer==0 ? nil : a.pattern(Int(request.arguments[0])))
                    } else if request.kind == .convert {
                        XCTAssertTrue(request.strings[0].allSatisfy { $0<128 })
                        let bytes=(request.strings[0]+[0]).flatMap { [$0,UInt8(0)] }
                        response = .init(result:request.arguments[3]==0 ? 0 : Int32(request.strings[0].count+1),bytes:request.arguments[3]==0 ? [] : bytes)
                    }
                    XCTAssertEqual(response,expected.response)
                    env.music.append(request)
                    if failure=="startMusic",request.kind == .method,request.arguments[1]==0x34,request.arguments[0]==0x2c002000 { throw Stop.injected }
                    return response
                },allocate:{ i,env in
                    let value=try a.allocate(i,&env.graphics);try event(.init("startup"),&env);return value
                },perform:{ q,env in
                    let response=try a.perform(q,&env.graphics);try event(.init("startup"),&env);return response
                },resourceEvent:{ e,env in
                    try a.observe(e,&env.graphics)
                    if e.kind != .allocate { try event(.init("startup"),&env) }
                },afterMusic:{ entered,state,memory,env in
                    XCTAssertFalse(entered);XCTAssertEqual(a.index,item.startup.musicBoundary.eventCount)
                    a.shadow=state.bytes+a.suffix;XCTAssertEqual(a.shadow,try r.startup.blob(item.startup.musicBoundary.snapshot.globals))
                    try compareMusic(item.startup.musicBoundary.allocations,memory)
                    if failure == "afterMusic" { throw Stop.injected }
                },resourceCheckpoint:{ point,state,images,buffer in
                    if item.spec.chain != true { try a.stored(point,state,images,&buffer.graphics) }
                    else {
                        let expected=a.c.checkpoints[a.stores];a.stores += 1
                        XCTAssertEqual(point.kind.rawValue,expected.kind);XCTAssertEqual(point.index,expected.index);XCTAssertEqual(a.index,expected.eventCount)
                        a.shadow=state.bytes+a.suffix;XCTAssertEqual(a.shadow,try r.startup.blob(expected.snapshot.globals))
                        try compareImages(expected.records,images,buffer)
                    }
                },afterStartup:{ _,state,memory,images,env in
                    XCTAssertEqual(state.bytes+a.suffix,try r.startup.blob(a.c.after.globals))
                    XCTAssertEqual(a.index,a.events.count);XCTAssertEqual(a.stores,a.c.checkpoints.count)
                    try compareMusic(item.startup.musicAllocations,memory);try compareImages(a.c.records,images.bitmaps,env)
                    if failure == "afterStartup" { throw Stop.injected }
                },draw:{ request,state,images,buffer in
                    let address: UInt32,surface: UInt32
                    var bitmap: OriginalStateRecord
                    switch request.bitmap {
                    case .menu(let token):
                        address=token
                        if let owned=images.bitmaps[token] { bitmap=owned.storage;surface=try XCTUnwrap(buffer.graphics.surfaceForWrapper[token]) }
                        else {
                            bitmap=try XCTUnwrap(initial.memory.allocations[token]).storage;surface=try bitmap.integer(at:0,as:UInt32.self)
                            // The declared atlas has a known source surface token.
                            // Drawing uses the same semantic1 binding as loaded bitmaps.
                            try bitmap.write(UInt32(1),at:0)
                        }
                    case .catalog(let index):address=try XCTUnwrap(r.bitmapAddresses[index]);bitmap=r.catalog.bitmaps[index].storage;surface=0x24000000
                    }
                    let args:[UInt32]=[address,UInt32(bitPattern:request.x),UInt32(bitPattern:request.y),UInt32(bitPattern:request.frame),request.colorKey,0,request.target]
                    try event(.init("draw",args),&buffer)
                    let input=try OriginalBitmapDrawInput(x:request.x,y:request.y,frame:request.frame,colorKey:request.colorKey,mirrored:0,sourceSurface:surface,targetSurface:request.target,
                        viewportWidth:state.integer(at:0x44d78c-base,as:Int32.self),viewportHeight:state.integer(at:0x44d790-base,as:Int32.self))
                    _ = try OriginalBitmapDrawing.draw(input,bitmap:bitmap,observeRead:{ read in
                        var e=OriginalFrontScreenEvent("read");e.read=read;try event(e,&buffer)
                    },observeClip:{ clip in var e=OriginalFrontScreenEvent("clip");e.clip=clip;try event(e,&buffer) },perform:{ blit in var e=OriginalFrontScreenEvent("blit");e.blit=blit;try event(e,&buffer);return -1 })
                    if failure == "computerPortrait",case .catalog = request.bitmap,request.x==453,request.y==94 { throw Stop.injected }
                },outputDraw:{ _,_,_,_ in throw Stop.unexpected },observe:event,
                characterCheckpoint:{ point,state,buffer in
                    let points=item.points.filter { $0.kind.hasPrefix("character-") || $0.kind.hasPrefix("tournament-") }
                    // The extended source observer also records the four
                    // bracket guards for menu20..25. The accepted setup API
                    // emits only their entry/exit. Verify every intermediate
                    // state and prove that no original store/event intervened.
                    if point.pc==0x434a92,try state.globals.integer(at:0x44d020-base,as:Int32.self)<26,
                       points[characterPoint].kind=="tournament-0x433bc9" {
                        let prior=points[characterPoint-1]
                        XCTAssertEqual(prior.kind,"tournament-0x433ae7")
                        for kind in ["tournament-0x433bc9","tournament-0x433c22","tournament-0x4347c5","tournament-0x434992"] {
                            let guardPoint=points[characterPoint];characterPoint += 1
                            XCTAssertEqual(guardPoint.kind,kind);XCTAssertEqual(guardPoint.storeCount,prior.storeCount)
                            XCTAssertEqual(guardPoint.eventCount,eventIndex)
                            XCTAssertEqual(guardPoint.locals,prior.locals)
                            try compareState(state,guardPoint.records)
                        }
                        XCTAssertEqual(points[characterPoint].storeCount,prior.storeCount)
                    }
                    let expected=points[characterPoint];characterPoint += 1
                    XCTAssertEqual(expected.kind,(point.pc>=0x432ab0 ? "tournament-0x" : "character-0x")+String(point.pc,radix:16));XCTAssertEqual(eventIndex,expected.eventCount)
                    if point.pc == 0x42a25a { XCTAssertEqual(expected.seat,UInt32(point.seat)) }
                    var expectedLocals=(expected.locals ?? [:]).reduce(into:[Int:Int32]()) { $0[Int($1.key)!]=Int32(bitPattern:$1.value) }
                    if point.pc == 0x42cb86,let cursor=expectedLocals[0x38],UInt32(bitPattern:cursor)==c.worldAddress+0x1b4 {
                        expectedLocals[0x38]=0x1b4 // semantic World cursor, never imported backing
                    }
                    if [UInt32(0x42cb86),0x42e0b6,0x42e0d2].contains(point.pc),let cursor=expectedLocals[0x20],UInt32(bitPattern:cursor)==c.worldAddress+0x1b4 {
                        expectedLocals[0x20]=0x1b4 // caller's own World cursor after reroll
                    }
                    XCTAssertEqual(point.locals,expectedLocals,item.spec.label+" caller locals at "+String(point.pc,radix:16))
                    try compareState(state,expected.records)
                    if failure == "assignment" && point.pc == 0x4347c5 { throw Stop.injected }
                },checkpoint:{ name,scene,state,buffer in
                    let point=try XCTUnwrap(item.points.first { $0.kind == name });XCTAssertEqual(eventIndex,point.eventCount)
                    let expected=try XCTUnwrap(point.records.first { $0.address == UInt32(base) });try compare(state,try r.record(expected),name+" globals");try compareWorld(scene,point.records)
                    if failure == "beforeReturn" && name == "matchBeforeReturn" { throw Stop.injected }
                })
            XCTAssertNil(failure);XCTAssertEqual(preparationPoint,item.points.filter { $0.kind.hasPrefix("preparation-") }.count);XCTAssertEqual(end.rawValue,item.end);XCTAssertEqual(eventIndex,item.events.count)
            XCTAssertEqual(item.cw,0x23f)
            XCTAssertEqual(item.endSP,item.end == "tournamentMatchPreparation" ? try XCTUnwrap(item.characterSP)-0xa14 : c.entrySP+8)
            XCTAssertEqual(characterPoint,item.points.filter { $0.kind.hasPrefix("character-") || $0.kind.hasPrefix("tournament-") }.count)
            try compareState(prepared,item.after)
            try compare(memory.replayPointers,try XCTUnwrap(after[0x4588a8]),item.spec.label+" replay pointers")
            for record in item.after where record.live != nil && record.address < 0x2c000000 {
                let allocation=try XCTUnwrap(memory.allocations[record.address]);XCTAssertEqual(allocation.live,record.live)
                try compare(allocation.storage,try r.record(record),item.spec.label+" retained allocation")
            }
            if let adapter=preparationAdapter {
                try adapter.compare(prepared,committed.preparationGraphics)
                let pg=try XCTUnwrap(item.preparationGraphics)
                for (address,live) in pg.wrapperLive { XCTAssertEqual(!committed.freedWrappers.contains(try XCTUnwrap(UInt32(address))),live) }
                let released=pg.events.filter { $0.request?.kind=="free" }.map { Int(($0.request!.words[0]-0x76000020)/0x2000)+r.catalog.bitmaps.count }
                XCTAssertEqual(prepared.releasedBitmapOrder,released)
                XCTAssertEqual(prepared.releasedBitmaps,Set(committed.freedWrappers.map { Int(($0-0x76000020)/0x2000)+r.catalog.bitmaps.count }))
                for record in item.after where record.live != nil && (record.address==0x75000020 || (0x77000000..<0x77c80000).contains(record.address)) {
                    let allocation=try XCTUnwrap(memory.allocations[record.address]);XCTAssertEqual(allocation.live,record.live)
                    try compare(allocation.storage,try r.record(record),"retained replay allocation")
                }
                let actual=try XCTUnwrap(memory.allocations[item.replayAddress]);let expected=try XCTUnwrap(after[item.replayAddress])
                try compare(actual.storage,expected,"final recording");XCTAssertTrue(actual.live)
            }
            XCTAssertEqual(musicIndex,item.bodyMusic.count)
            try compareMusic(item.musicAfter,music);try compareImages(a.c.records,resources.bitmaps,committed)
            XCTAssertEqual(committed.graphics.imagesDeleted,Dictionary(uniqueKeysWithValues:a.c.images.map { (UInt32($0.key)!,$0.value.deleted) }))
            XCTAssertEqual(committed.graphics.surfacesReleased,Dictionary(uniqueKeysWithValues:a.c.surfaces.map { (UInt32($0.key)!,$0.value.released) }))
            XCTAssertEqual(committed.graphics.surfaceDescriptions,Dictionary(uniqueKeysWithValues:a.c.surfaces.map { (UInt32($0.key)!,$0.value.description) }))
            XCTAssertEqual(committed.graphics.dcs,Dictionary(uniqueKeysWithValues:a.c.dcs.map { (UInt32($0.key)!,$0.value) }))
            XCTAssertEqual(library.retainedDC,try XCTUnwrap(after[c.libraryAddress]).integer(at:0x306e,as:UInt32.self))
            XCTAssertEqual(committed.front.count-firstFrontCount,item.events.count)
            retained=Retained(prepared:prepared,memory:memory,library:library,music:music,resources:resources,environment:committed)
        } catch let error as Stop {
            guard error == .injected else { throw error };XCTAssertNotNil(failure)
            XCTAssertEqual(prepared.globals,initialGlobals);XCTAssertEqual(prepared.world,initialWorld);XCTAssertEqual(prepared.actors,initialActors);XCTAssertEqual(memory.allocations,initialMemory.allocations);XCTAssertEqual(memory.replayPointers,initialMemory.replayPointers)
            XCTAssertEqual(library,initialLibrary);XCTAssertEqual(committed,initial.environment)
            XCTAssertEqual(world,initialWorld);XCTAssertEqual(music.allocations,initial.music.allocations);XCTAssertEqual(resources.bitmaps,initial.resources.bitmaps)
            XCTAssertEqual(prepared.backgrounds,initial.prepared.backgrounds);XCTAssertEqual(prepared.bitmaps,initial.prepared.bitmaps)
            XCTAssertEqual(prepared.releasedBitmaps,initial.prepared.releasedBitmaps);XCTAssertEqual(prepared.releasedBitmapOrder,initial.prepared.releasedBitmapOrder)

        }
        return eventIndex
    }
    func testWholeTournamentPreparationRetainsLibraryMenu() throws {
        let r=try Resources();var retained: Retained?,events=0
        for parent in r.corpus.parents {
            let item=r.corpus.cases[parent.firstCase]
            XCTAssertEqual(parent.constructors.calls.count,401)
            for (index,call) in parent.constructors.calls.enumerated() {
                let size=index==0 ? OriginalStateRecord.worldPrefixSize : OriginalStateRecord.actorSize
                let pattern=(0..<size).map { item.spec.control ? UInt8(($0*37+11)&255) : 0xa5 }
                var input=try OriginalStateRecord(bytes:pattern,defined:[Bool](repeating:false,count:size))
                var expectedBefore=try r.record(.init(address:call.address,storage:call.before,live:nil))
                var expectedAfter=try r.record(.init(address:call.address,storage:call.after,live:nil))
                if index==0 {
                    XCTAssertEqual(call.kind,"world")
                    for slot in 0..<400 {
                        XCTAssertEqual(try expectedBefore.integer(at:0x194+slot*4,as:UInt32.self),item.actorAddresses[slot])
                        try input.write(UInt32(slot),at:0x194+slot*4);try expectedBefore.write(UInt32(slot),at:0x194+slot*4);try expectedAfter.write(UInt32(slot),at:0x194+slot*4)
                    }
                    try input.write(UInt32(0),at:0x7d4);try expectedBefore.write(UInt32(0),at:0x7d4);try expectedAfter.write(UInt32(0),at:0x7d4)
                    try compare(input,expectedBefore,"World constructor declared input")
                    var output=try OriginalStateRecord.worldPrefix(over:pattern)
                    for slot in 0..<400 { try output.write(UInt32(slot),at:0x194+slot*4) };try output.write(UInt32(0),at:0x7d4)
                    try compare(output,expectedAfter,"World constructor with retained bindings")
                } else {
                    let slot=index-1;XCTAssertEqual(call.kind,"actor");XCTAssertEqual(call.address,item.actorAddresses[slot])
                    try input.write(Int32([-1,0,1,2,3,4,5][slot%7]),at:0x364);try input.write(UInt32(0),at:0x368)
                    if slot<8 { try input.write(UInt8(0),at:0xca) }
                    XCTAssertEqual(try expectedBefore.integer(at:0x368,as:UInt32.self),0x68000020)
                    try expectedBefore.write(UInt32(0),at:0x368);try expectedAfter.write(UInt32(0),at:0x368)
                    try compare(input,expectedBefore,"Actor constructor declared input")
                    try input.reconstructActor();try compare(input,expectedAfter,"Actual retained Actor constructor")
                }
            }
        }
        for item in r.corpus.cases {
            if item.spec.chain != true { retained=nil }
            events += try run(item,r,&retained)

        }
        XCTAssertGreaterThan(events,10_000)
    }
    func testLateTournamentArenaReleaseRollsBackWholeCall() throws {
        let r=try Resources()
        var first: Retained?;_ = try run(r.corpus.cases[0],r,&first)
        for failure in ["release","free","allocateReplay","recording","beforeReturn"] {
            var retained=first;_ = try run(r.corpus.cases[1],r,&retained,failure:failure)
        }
        var released=first;_ = try run(r.corpus.cases[1],r,&released)
        _ = try run(r.corpus.cases[2],r,&released,failure:"bitmap")
    }
    func testUnconnectedExistingArenaReleaseRejectsAndRollsBack() throws {
        let r=try Resources(),item=try XCTUnwrap(r.corpus.cases.first { $0.spec.label=="arena-release-0-load" })
        var retained: Retained?;_ = try run(item,r,&retained)
        let initial=try XCTUnwrap(retained);var scene=initial.prepared,memory=initial.memory
        XCTAssertGreaterThan(try scene.backgrounds[0].integer(at:0x914,as:UInt32.self),0)
        do {
            // Direct native preparation boundary after a successful load. This
            // is a rejection/rollback test, not an additional source match.
            try OriginalTournamentPreparation.prepare(state:&scene,memory:&memory,
                localTime:{ .init(year:2026,month:9,dayOfWeek:5,day:11,hour:12,minute:34,second:56,milliseconds:789) },
                constructBitmap:{ _,_,_ in throw Stop.unexpected },allocateReplay:{ _ in throw Stop.unexpected })
            XCTFail("Missing release continuation was accepted")
        } catch OriginalStateError.invalidStorage(let message) {
            XCTAssertEqual(message,"Existing BG release continuation was not supplied")
        }
        XCTAssertEqual(scene.globals,initial.prepared.globals);XCTAssertEqual(scene.world,initial.prepared.world);XCTAssertEqual(scene.actors,initial.prepared.actors)
        XCTAssertEqual(scene.backgrounds,initial.prepared.backgrounds);XCTAssertEqual(scene.bitmaps,initial.prepared.bitmaps);XCTAssertEqual(scene.releasedBitmaps,initial.prepared.releasedBitmaps)
        XCTAssertEqual(memory.replayPointers,initial.memory.replayPointers);XCTAssertEqual(memory.allocations,initial.memory.allocations)
    }
}
