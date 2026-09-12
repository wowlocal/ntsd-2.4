import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalLibWarPreparationTests: XCTestCase {
    enum Study: String, Equatable {
        case preparation,matrix
        var count: Int { self == .preparation ? 22 : 256 }
        var rawBytes: Int { self == .preparation ? 192_093_188 : 2_866_445_440 }
        var rawSHA256: String { self == .preparation ? "e3abb5dec759c28103c5a746972d7fb1469e7fa7b8ca151a09fc952e6d5621f6" : "79b14f3aaa971e5ef1d60eac6d72955c1f9c924fcc2c2948caa74de67d24495a" }
        var environment: String { self == .preparation ? "NTSD_LIB_WAR_PREPARATION_INDEX" : "NTSD_LIB_WAR_PREPARATION_MATRIX_INDEX" }
        var fixture: String { self == .preparation ? "original-lib-war-preparation-bound" : "original-lib-war-preparation-matrix" }
    }
    typealias Base = OriginalCharacterMenuSurfaceTests
    typealias Music = OriginalCharacterMenuMusicSurfaceTests
    struct Environment: Equatable {
        var front: [OriginalFrontScreenEvent] = []
        var graphics = Base.Context()
        var music: [OriginalMusicEvent] = []
        var warGraphics = Base.Context()
        var preparationGraphics = Base.Context()
    }
    struct Startup: Decodable {
        let musicBoundary: Music.Boundary, musicAllocations: [Base.Record], events: [Music.Event]
    }
    struct MusicSpec: Decodable { let nullAllocation: Bool? }
    struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    struct Transport: Decodable { let count: Int,sha256: String,deflateSHA256: String,deflateParts: [String] }
    struct Storage: Decodable { let bytes: String, defined: String }
    struct Record: Decodable { let address: UInt32, storage: Storage, live: Bool? }
    struct CellEdit: Decodable { let row: Int,side: Int,unit: Int,address: Int }
    struct Actions: Decodable { let row: Int,mask: Int,address: Int }
    struct PreparationInputs: Decodable { let words: [String:Int32],strings: [String:String] }
    struct MatrixSeat: Decodable { let seat: Int,status: Int32,team: Int32 }
    struct MatrixInputs: Decodable { let words: [String:Int32],seats: [MatrixSeat]? }
    struct Spec: Decodable { let matrixInputs: MatrixInputs?,generation: Int?,matrixOrdinal: Int?; let preparationInputs: PreparationInputs?,localTime: [UInt16]?,expectedPreparation: Bool?; let bridgeGlobals: [String:Int32]?, bridgeReady: [Ready]?; let buttons: [[Int]]?; let expectedEdit: CellEdit?,expectedActions: Actions?; let label: String, control: Bool, music: MusicSpec?, chain: Bool?, dcResult: Int32?, dc: UInt32?, methodResult: Int32?, milliseconds: UInt32? }
    struct Ready: Decodable { let seat: Int,object: Int,team: Int32,status: Int32 }
    struct Point: Decodable { let name: String?; let kind: String,records: [Record],eventCount: Int,storeCount: Int,seat: UInt32?,locals: [String:UInt32]? }
    struct Helper: Decodable { let entry: UInt32,firstStore: Int,lastStore: Int? }
    struct Write: Decodable { let address: UInt32,bytes: String }
    struct Read: Decodable { let address: UInt32,count: Int,storeCount: Int }
    struct ResourceFailureInput: Decodable {
        struct Declared: Decodable { let replayNull: Bool? }
        struct Graphics: Decodable {
            let nullAllocationOrdinal: Int?,missingLoaderIndices: [Int]?,results: [String:Int32]?
        }
        let graphics: Graphics
        let declared: Declared?
        let music: OriginalWarPreparationMusicAdapter.Input?
    }
    struct Case: Decodable {
        let resourceFailureInput: ResourceFailureInput?
        let helpers: [Helper],pending: [Helper],writes: [Write],reads: [Read],apiReads: [Read]
        let preparationGraphics: WarGraphics?,replayAddress: UInt32?
        let warGraphics: WarGraphics?
        let warSP: UInt32?
        let spec: Spec, before: [Record], after: [Record], actorAddresses: [UInt32]
        let stimulus: [Write]?
        let bodyMusic: [Music.MusicEvent],musicAfter: [Base.Record]
        let events: [OriginalFrontScreenEvent], end: String, endSP: UInt32, cw: UInt32
        let startup: Startup?, characterSP: UInt32?, screenSP: UInt32?,output: OriginalMenuPresentationInput?,points: [Point]
    }
    struct Portrait: Decodable { let address: UInt32, surface: UInt32, width: Int32, height: Int32, path: String }
    struct Entry: Decodable { let ordinal: Int,id: Int32,type: Int32,address: UInt32,nameTail: String,nameMask: String,portrait: Portrait?,small: Portrait? }
    struct Roster: Decodable { let entries: [Entry] }
    struct CatalogDependency: Decodable { let bitmapAddresses: [UInt32],checksum: UInt32 }
    struct ConstructorCall: Decodable { let kind: String,address: UInt32,before: Storage,after: Storage }
    struct ConstructorParent: Decodable { let calls: [ConstructorCall] }
    struct Parent: Decodable { let firstCase: Int,constructors: ConstructorParent }
    struct WarGraphics: Decodable {
        let events: [Base.Event],allocations: [Base.Allocation],records: [Base.Record]
        let allocationStart: Int?,constructionHistory: [Base.Helper]?,wrapperLive: [String:Bool]?
        let helpers: [Base.Helper],images: [String:Base.Image],surfaces: [String:Base.Surface],dcs: [String:Bool]
    }
    struct Corpus: Decodable {
        let catalogDependency: CatalogDependency, assets: [String:Base.Asset], parents: [Parent]
        let roster: Roster
        let exeSHA256: String, libSHA256: String, cases: [Case], blobs: [String:Blob]
        let worldAddress: UInt32, bitmapAddress: UInt32, target: UInt32, libraryAddress: UInt32, stackAddress: UInt32, entrySP: UInt32, tailSP: UInt32
    }
    enum Stop: Error, Equatable { case injected, unexpected }
    struct NativeRejection {
        let message: String,frontEvents: Int,releaseFreePairs: Int
        let replayNull: Bool
    }
    struct IndexedCase: Decodable { let index: Int,label: String,path: String,bytes: Int,sha256: String; let position: Int? }
    struct IndexDocument: Decodable {
        struct Source: Decodable { let bytes: Int,sha256: String }
        struct Audit: Decodable { let path: String?,sha256: String }
        struct FilePin: Decodable { let bytes: Int,sha256: String }
        let schema: Int,source: Source,audit: Audit,cases: [IndexedCase]
        let auditBlob: Blob?,metadataBlob: Blob?,files: [String:FilePin]?
    }
    final class Index {
        struct Group: Decodable { let firstCase: Int,cases: [Blob] }
        let url: URL,c: IndexDocument,metadata: [String:Any]
        private var groupPath: String?,group: Group?
        private static func unpack(_ blob: Blob,maximumCount: Int) throws -> Data {
            let data=Data(try MatchPreparationReference.inflate(blob.deflate,count:blob.count,maximumCount:maximumCount))
            guard MatchPreparationReference.digest(data)==blob.sha256 else { throw Stop.unexpected }
            return data
        }
        init(_ study: Study = .preparation) throws {
            if let path=ProcessInfo.processInfo.environment[study.environment] {
                url=URL(fileURLWithPath:path)
            } else {
                url=try XCTUnwrap(Bundle.module.url(forResource:study.fixture,withExtension:"json",subdirectory:"Fixtures"))
            }
            let data=try Data(contentsOf:url)
            c=try JSONDecoder().decode(IndexDocument.self,from:data)
            let audit: Data
            if c.schema==1 {
                let document=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
                metadata=try XCTUnwrap(document["metadata"] as? [String:Any])
                audit=try Data(contentsOf:URL(fileURLWithPath:XCTUnwrap(c.audit.path)))
            } else {
                guard c.schema==2 else { throw Stop.unexpected }
                metadata=try XCTUnwrap(JSONSerialization.jsonObject(with:Self.unpack(XCTUnwrap(c.metadataBlob),maximumCount:256_000_000)) as? [String:Any])
                audit=try Self.unpack(XCTUnwrap(c.auditBlob),maximumCount:16_000_000)
            }
            guard c.source.bytes==study.rawBytes,c.source.sha256==study.rawSHA256,
                c.cases.count==study.count,c.cases.map(\.index)==Array(0..<study.count) else { throw Stop.unexpected }
            guard MatchPreparationReference.digest(audit)==c.audit.sha256 else { throw Stop.unexpected }
            let report=try XCTUnwrap(JSONSerialization.jsonObject(with:audit) as? [String:Any])
            guard report["sourceAudited"] as? Bool == true,report["cases"] as? Int == study.count,
                let raw=report["raw"] as? [String:Any],raw["bytes"] as? Int==c.source.bytes,
                raw["sha256"] as? String==c.source.sha256 else { throw Stop.unexpected }
        }
        func part(_ number: Int) throws -> [String:Any] {
            let entry=c.cases[number],path=url.deletingLastPathComponent().appendingPathComponent(entry.path)
            if c.schema==1 {
                let data=try Data(contentsOf:path)
                guard data.count==entry.bytes,MatchPreparationReference.digest(data)==entry.sha256 else { throw Stop.unexpected }
                return try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
            }
            if groupPath != entry.path {
                let pin=try XCTUnwrap(c.files?[entry.path]),data=try Data(contentsOf:path)
                guard data.count==pin.bytes,MatchPreparationReference.digest(data)==pin.sha256 else { throw Stop.unexpected }
                group=try JSONDecoder().decode(Group.self,from:data);groupPath=entry.path
            }
            let group=try XCTUnwrap(group),position=try XCTUnwrap(entry.position)
            guard group.cases.indices.contains(position),group.firstCase+position==number else { throw Stop.unexpected }
            let blob=group.cases[position]
            guard blob.count==entry.bytes,blob.sha256==entry.sha256 else { throw Stop.unexpected }
            let item=try XCTUnwrap(JSONSerialization.jsonObject(with:Self.unpack(blob,maximumCount:32_000_000)) as? [String:Any])
            let parents=try XCTUnwrap(metadata["parents"] as? [[String:Any]])
            let parent=try XCTUnwrap(parents.last { ($0["firstCase"] as? Int ?? Int.max)<=number })
            return ["case":item,"parents":[parent],"assets":try XCTUnwrap(metadata["assets"]),"blobs":try XCTUnwrap(metadata["blobs"])]
        }
    }
    final class Resources {
        let corpus: Corpus
        let startup: Base.Resources
        var decoded: [String:[UInt8]] = [:]
        let catalog: OriginalLoadedCatalog
        var bitmapAddresses: [Int:UInt32] = [:]
        convenience init(_ index: Index,_ number: Int,catalog: OriginalLoadedCatalog) throws {
            let entry=index.c.cases[number],part=try index.part(number)
            var document=index.metadata
            document["cases"]=[try XCTUnwrap(part["case"])];document["parents"]=part["parents"]
            document["assets"]=part["assets"];document["blobs"]=part["blobs"]
            try self.init(document:document,expectedLabel:entry.label,catalog:catalog)
        }
        init(document: [String:Any],expectedLabel: String,catalog: OriginalLoadedCatalog) throws {
            corpus=try JSONDecoder().decode(Corpus.self,from:JSONSerialization.data(withJSONObject:document))
            XCTAssertEqual(corpus.cases.count,1);XCTAssertEqual(corpus.cases[0].spec.label,expectedLabel)
            var projected=document
            projected["assets"]=(try XCTUnwrap(document["assets"] as? [String:Any])).filter { OriginalMenuResourceLoading.paths.contains($0.key) }
            let startup=(try XCTUnwrap(document["cases"] as? [[String:Any]])).first?["startup"]
            if let startup { projected["cases"]=[startup] }
            else {
                // Fault publication omitted this nested report. Keep its
                // absence; the test compares the saved outer checkpoints at
                // real Native startup callbacks instead of inventing a report.
                XCTAssertEqual(corpus.cases[0].end,"sourceFault")
                projected["cases"]=[]
            }
            let temporary=FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-war-startup-"+UUID().uuidString+".json")
            try JSONSerialization.data(withJSONObject:projected).write(to:temporary)
            defer { try? FileManager.default.removeItem(at:temporary) }
            self.startup=try Base.Resources(url:temporary,expectedCases:startup == nil ? 0 : 1)
            XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
            XCTAssertEqual(corpus.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
            XCTAssertEqual(corpus.worldAddress,0x22000020);XCTAssertEqual(corpus.bitmapAddress,0x27000020)
            XCTAssertEqual(corpus.target,0x26006000);XCTAssertEqual(corpus.libraryAddress,0x36000000)
            XCTAssertEqual(corpus.stackAddress,0x10000000);XCTAssertEqual(corpus.entrySP,0x1000f000);XCTAssertEqual(corpus.tailSP,0x1000e9bc)
            // Rebuild the whole accepted catalog through its normal loader.
            // New source snapshots supply comparisons, never Object inputs.
            self.catalog=catalog
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
        /// Only the11 recovered Object-pointer slots are canonicalized. The
        /// expected source record is a copy; actual native state stays owned.
        func nativeGlobals(_ source: OriginalStateRecord) throws -> OriginalStateRecord {
            var value=source
            for unit in 0..<11 {
                let offset=0x451b38+unit*4-OriginalMatchPreparation.globalBase
                guard value.defined[offset..<offset+4].allSatisfy({ $0 }) else { continue }
                let pointer=try value.integer(at:offset,as:UInt32.self)
                if pointer != 0 {
                    let entry=try XCTUnwrap(corpus.roster.entries.first { $0.address==pointer })
                    try value.write(UInt32(entry.ordinal+1),at:offset)
                }
            }
            return value
        }
        func sourceGlobals(_ native: OriginalStateRecord) throws -> OriginalStateRecord {
            var value=native
            for unit in 0..<11 {
                let offset=0x451b38+unit*4-OriginalMatchPreparation.globalBase
                guard value.defined[offset..<offset+4].allSatisfy({ $0 }) else { continue }
                let token=try value.integer(at:offset,as:UInt32.self)
                if token != 0 {
                    let entry=try XCTUnwrap(corpus.roster.entries.first { $0.ordinal==Int(token-1) })
                    try value.write(entry.address,at:offset)
                }
            }
            return value
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
        var war=OriginalWarMenuMemory()
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
        try OriginalTournamentLayout.initialize(globals:&produced)
        try OriginalWarTroops.initializeFileData(&produced)
        try produced.write(Int32(item.spec.control ? 3 : 0),at:0x451b80-base)
        for (address,count) in [(0x44d350,0x428),(0x451b38,0x7c)] {
            let span=address-base..<address-base+count
            XCTAssertEqual(Array(produced.bytes[span]),Array(globals.bytes[span]))
            XCTAssertEqual(Array(produced.defined[span]),Array(globals.defined[span]))
        }
        let layoutStart=0x44d120-base
        XCTAssertEqual(Array(produced.bytes[layoutStart..<layoutStart+504]),Array(globals.bytes[layoutStart..<layoutStart+504]))
        XCTAssertTrue(globals.defined[layoutStart..<layoutStart+504].allSatisfy { $0 })
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
        var prepared = try OriginalMatchPreparation(catalog:r.catalog,bootstrap:bootstrap,globals:produced)
        prepared.world=world;prepared.actors=actors
        return Retained(prepared:prepared,memory:memory,library:library)
    }
    @discardableResult
    func run(_ item: Case,_ r: Resources,_ retained: inout Retained?,failure: String? = nil,
             compareRetainedScratch: Bool = false,rejection: NativeRejection? = nil) throws -> Int {
        if rejection != nil {
            XCTAssertNil(failure);XCTAssertEqual(item.end,"sourceFault")
            guard retained != nil,item.spec.chain == true else { throw Stop.unexpected }
        }
        var initial=try retained ?? initialize(item,r)
        if item.spec.chain == true {
            if let inputs=item.spec.matrixInputs {
                XCTAssertNil(item.spec.preparationInputs)
                let allowed=Set([0x44d020,0x451b84,0x44d024,0x44d028,0x44d758,0x44d75c,0x450bcc,0x450c34])
                for (p,v) in inputs.words {
                    let address=try XCTUnwrap(Int(p));XCTAssertTrue(allowed.contains(address))
                    try initial.prepared.globals.write(v,at:address-OriginalMatchPreparation.globalBase)
                }
                for row in inputs.seats ?? [] {
                    XCTAssertTrue((0..<8).contains(row.seat));XCTAssertTrue([0,3,13].contains(row.status));XCTAssertTrue((1...2).contains(row.team))
                    let ordinal=try initial.prepared.globals.integer(at:0x451248+row.seat*4-OriginalMatchPreparation.globalBase,as:Int32.self)
                    XCTAssertEqual(try initial.prepared.actors[row.seat].integer(at:0x368,as:UInt32.self),UInt32(bitPattern:ordinal))
                    try initial.prepared.globals.write(row.status,at:0x451288+row.seat*4-OriginalMatchPreparation.globalBase)
                    try initial.prepared.actors[row.seat].write(row.team,at:0x364)
                }
            }
            if let inputs=item.spec.preparationInputs {
                XCTAssertEqual(inputs.words,[String(0x450b90):1,String(0x450b94):0,String(0x45842c):0,String(0x450be4):item.spec.control ? 1 : 0])
                XCTAssertEqual(inputs.strings,[String(0x44fd18):"War preservation",String(0x44f900):"Controlled reference",String(0x44f890):"NTSD 2.4"])
                for (p,v) in inputs.words { try initial.prepared.globals.write(v,at:Int(p)!-OriginalMatchPreparation.globalBase) }
                for (p,v) in inputs.strings {
                    for (i,b) in (Array(v.utf8)+[0]).enumerated() { try initial.prepared.globals.write(b,at:Int(p)!-OriginalMatchPreparation.globalBase+i) }
                }
            }
            for (address,value) in item.spec.bridgeGlobals ?? [:] {
                let a=try XCTUnwrap(Int(address))
                var allowed=Set([0x44d020,0x451ba8,0x44d760,0x451b98,0x451b9c])
                if item.spec.bridgeReady != nil { allowed.formUnion([0x4512c8]);for b in [0x451228,0x451248,0x451288] { allowed.formUnion(stride(from:b,to:b+32,by:4)) } }
                XCTAssertTrue(allowed.contains(a))
                try initial.prepared.globals.write(value,at:a-OriginalMatchPreparation.globalBase)
            }
            for row in item.spec.bridgeReady ?? [] {
                XCTAssertTrue((0..<8).contains(row.seat));XCTAssertTrue((1...2).contains(row.team));XCTAssertTrue([3,13].contains(row.status))
                XCTAssertTrue(r.catalog.objects.indices.contains(row.object))
                try initial.prepared.actors[row.seat].write(row.team,at:0x364)
                try initial.prepared.actors[row.seat].write(UInt32(row.object),at:0x368)
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
        var music=initial.music,resources=initial.resources,committed=initial.environment,war=initial.war
        let globals=prepared.globals,world=prepared.world,actors=prepared.actors
        let initialGlobals=globals,initialMemory=memory,initialLibrary=library,initialWorld=world
        let initialActors=actors
        // Match both the label and complete declared entry globals.
        let entryGlobals=try XCTUnwrap(item.before.first { $0.address==UInt32(base) }).storage.bytes
        let a: Base.Adapter?
        if item.startup != nil {
            let matches=r.startup.c.cases.indices.filter { r.startup.c.cases[$0].spec.label==item.spec.label && r.startup.c.cases[$0].before.globals==entryGlobals }
            XCTAssertEqual(matches.count,1)
            a=try Base.Adapter(r.startup.c.cases[XCTUnwrap(matches.first)],r.startup)
        } else {
            XCTAssertNotNil(rejection);XCTAssertTrue(r.startup.c.cases.isEmpty)
            XCTAssertEqual(try [0x44d020,0x4512cc,0x44d07c,0x4512c8].map {
                try initial.prepared.globals.integer(at:$0-base,as:UInt32.self)
            },[202,202,0,3])
            a=nil
        }
        let outputInput: OriginalMenuPresentationInput
        if let output=item.output { outputInput=output }
        else {
            XCTAssertNotNil(rejection)
            // Explicit unused Native response slots, not recovered source
            // values. The exact guard and event prefix must precede output.
            let unused:[String:Int]=["targetSurface":0,"methodResult":0,"queryResult":0,"audioGetResult":0,
                "audioSetResult":0,"queriedAudio":0,"audioVolume":0,"dcResult":0,"dc":0,"postResult":0]
            outputInput=try JSONDecoder().decode(OriginalMenuPresentationInput.self,from:JSONSerialization.data(withJSONObject:unused))
        }
        var eventIndex=0,characterPoint=0,musicIndex=0,warPoint=0,preparationPoint=0,numericPoint=0
        var reachedPoints: [String]=[],diagnosticFront: [OriginalFrontScreenEvent]=[]
        var diagnosticGraphics: Base.Context?,diagnosticGlobals: OriginalStateRecord?
        var diagnosticPreparationState: OriginalMatchPreparation?
        var allocatorResults: [(bytes:Int,address:UInt32)]=[]
        var preparationAdapter: OriginalWarPreparationSurfaceAdapter?
        let warAdapter=item.warGraphics.map { OriginalWarPreparationMenuSurfaceAdapter($0,r,control:item.spec.control) }
        let firstFrontCount=committed.front.count
        var scratchConstructors=0
        var scratchMusicFormat=false
        func compareScratch(_ scratch: OriginalWarBitmapScratch,_ records: [Record],throughStores: Int? = nil) throws {
            guard compareRetainedScratch else { return }
            var stack=try r.record(XCTUnwrap(records.first { $0.address==c.stackAddress }))
            if let throughStores {
                guard throughStores<=item.writes.count else { throw Stop.unexpected }
                for write in item.writes.prefix(throughStores) {
                    let count=write.bytes.utf8.count/2
                    guard [UInt32(0x1000d358),0x1000d258].contains(where:{
                        write.address<$0+8 && UInt64(write.address)+UInt64(count)>UInt64($0)
                    }) else { continue }
                    let text=Array(write.bytes.utf8)
                    for i in 0..<count {
                        let address=write.address+UInt32(i)
                        if (0x1000d358..<0x1000d360).contains(address) || (0x1000d258..<0x1000d260).contains(address) {
                            let byte=try XCTUnwrap(UInt8(String(decoding:text[i*2..<i*2+2],as:UTF8.self),radix:16))
                            try stack.write(byte,at:Int(address-c.stackAddress))
                        }
                    }
                }
            }
            // Source locations identify comparison evidence only. Native owns
            // the two semantic records and receives none of these source bytes.
            for (address,owned) in [(UInt32(0x1000d358),scratch.loaderDimensions),
                                    (UInt32(0x1000d258),scratch.copyDimensions)] {
                let offset=Int(address-c.stackAddress),mask=Array(stack.defined[offset..<offset+8])
                if address==0x1000d358,scratchMusicFormat {
                    XCTAssertTrue(scratch.loaderInvalidatedByPreparationMusicFormat)
                    XCTAssertNil(owned,"Music call ABI cannot remain a bitmap dimension producer")
                    XCTAssertTrue(mask.allSatisfy { $0 },"Source ABI bytes are known, not Native bitmap fields")
                    continue
                }
                if address==0x1000d358 { XCTAssertFalse(scratch.loaderInvalidatedByPreparationMusicFormat) }
                let actualMask=owned?.defined ?? [Bool](repeating:false,count:8)
                XCTAssertEqual(actualMask,mask,"Retained field lifetime mask")
                let expected=Array(stack.bytes[offset..<offset+8])
                let actual=owned?.bytes ?? [UInt8](repeating:0,count:8)
                for i in 0..<8 where mask[i] { XCTAssertEqual(actual[i],expected[i],"Retained field producer byte") }
            }
        }
        func compareMusic(_ records: [Base.Record],_ memory: OriginalMusicMemory) throws {
            XCTAssertEqual(records.count,memory.allocations.count)
            for record in records {
                XCTAssertEqual(record.kind,"music-wide");XCTAssertTrue(record.count>0 && record.count<0x1000 && record.count%2==0)
                let pattern: [UInt8]
                if record.address>=0x2c020020 { pattern=(0..<record.count).map { item.spec.control ? UInt8($0%256) : 0xa5 } }
                else { pattern=try XCTUnwrap(a).pattern(record.count) }
                XCTAssertEqual(try r.startup.blob(record.initial),pattern)
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
            if rejection != nil { diagnosticFront.append(e) }
            if failure=="replayFree",e.kind=="free",[UInt32(0x75000020),0x77000020,0x77640020].contains(e.arguments[0]) { throw Stop.injected }
            let currentEvents=environment.front.suffix(environment.front.count-firstFrontCount)
            if failure=="secondRandom",e.kind=="random",e.arguments[0]==0x122,
                currentEvents.filter({ $0.kind=="random" && $0.arguments[0]==0x122 }).count==2 { throw Stop.injected }
            if failure=="lateFrame",e.kind=="fill",currentEvents.contains(where:{ $0.kind=="warFrame" }) { throw Stop.injected }
            if failure=="lateText",e.kind=="textOut",currentEvents.filter({ $0.kind=="textOut" }).count==20 { throw Stop.injected }
            if failure=="present",e.kind=="method",e.arguments[1]==0x14 { throw Stop.injected }
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
            try compare(value.globals,r.nativeGlobals(r.record(XCTUnwrap(records[UInt32(base)]))),item.spec.label+" globals")
            try compareWorld(value.world,Array(records.values))
            for (i,p) in item.actorAddresses.enumerated() {
                var expected=try r.record(XCTUnwrap(records[p]))
                let pointer=try expected.integer(at:0x368,as:UInt32.self)
                guard pointer>=0x68000020,(pointer-0x68000020)%0x40000==0 else { throw Stop.unexpected }
                let ordinal=(pointer-0x68000020)/0x40000;XCTAssertLessThan(ordinal,137)
                try expected.write(ordinal,at:0x368);try compare(value.actors[i],expected,item.spec.label+" Actor"+String(i))
            }
            let bitmapPointers=c.catalogDependency.bitmapAddresses+(item.preparationGraphics?.allocations.compactMap(\.address).filter { $0 != 0 } ?? [])
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
        func compareFaultStartup(_ name: String,_ state: OriginalStateRecord) throws {
            guard rejection != nil else { return }
            let point=try XCTUnwrap(item.points.first { $0.kind==name })
            XCTAssertEqual(eventIndex,point.eventCount);reachedPoints.append(name)
            var stage=initial.prepared;stage.globals=state
            try compareState(stage,point.records)
        }
        func draw(_ request: OriginalCharacterScreenDraw,_ state: OriginalStateRecord,
                  _ images: [UInt32:OriginalLoadedBitmap],_ isWar: Bool,_ buffer: inout Environment) throws {
            let address: UInt32,surface: UInt32
            var bitmap: OriginalStateRecord
            switch request.bitmap {
            case .menu(let token):
                address=token
                if let owned=images[token] {
                    bitmap=owned.storage
                    surface=try XCTUnwrap((isWar ? buffer.warGraphics : buffer.graphics).surfaceForWrapper[token])
                } else {
                    bitmap=try XCTUnwrap(initial.memory.allocations[token]).storage
                    surface=try bitmap.integer(at:0,as:UInt32.self)
                    try bitmap.write(UInt32(1),at:0)
                }
            case .catalog(let i):
                address=try XCTUnwrap(r.bitmapAddresses[i]);bitmap=r.catalog.bitmaps[i].storage;surface=0x24000000
            }
            let args:[UInt32]=[address,UInt32(bitPattern:request.x),UInt32(bitPattern:request.y),UInt32(bitPattern:request.frame),request.colorKey,0,request.target]
            try event(.init("draw",args),&buffer)
            let input=try OriginalBitmapDrawInput(x:request.x,y:request.y,frame:request.frame,colorKey:request.colorKey,mirrored:0,sourceSurface:surface,targetSurface:request.target,
                viewportWidth:state.integer(at:0x44d78c-base,as:Int32.self),viewportHeight:state.integer(at:0x44d790-base,as:Int32.self))
            _ = try OriginalBitmapDrawing.draw(input,bitmap:bitmap,observeRead:{ read in
                var e=OriginalFrontScreenEvent("read");e.read=read;try event(e,&buffer)
            },observeClip:{ clip in var e=OriginalFrontScreenEvent("clip");e.clip=clip;try event(e,&buffer)
            },perform:{ blit in var e=OriginalFrontScreenEvent("blit");e.blit=blit;try event(e,&buffer);return -1 })
        }
        try compareState(prepared,item.before)
        try compareScratch(war.bitmapScratch,item.before)
        XCTAssertEqual(library.retainedDC,try XCTUnwrap(before[c.libraryAddress]).integer(at:0x306e,as:UInt32.self))
        try compareFaultStartup("declaredTail",prepared.globals)
        do {
            let end=try OriginalCharacterMenuContinuation.advanceWithWar(state:&prepared,memory:&memory,music:&music,resources:&resources,war:&war,libraryText:&library,environment:&committed,
                target:c.target,input:.init(dcResult:item.spec.dcResult ?? 0,dc:item.spec.dc ?? 0x76543210,methodResult:item.spec.methodResult ?? -1,drawResults:[-1],shellResult:33),
                warPreparation:{ scene,owned,audio,scratch,env in
                    let pg=try XCTUnwrap(item.preparationGraphics)
                    let adapter=OriginalWarPreparationSurfaceAdapter(pg,r,inputs:item.resourceFailureInput?.graphics);preparationAdapter=adapter
                    if (pg.allocationStart ?? 0)==0 { env.preparationGraphics=env.warGraphics }
                    try OriginalWarPreparation.prepare(state:&scene,memory:&owned,localTime:{
                        let t=try XCTUnwrap(item.spec.localTime)
                        return .init(year:t[0],month:t[1],dayOfWeek:t[2],day:t[3],hour:t[4],minute:t[5],second:t[6],milliseconds:t[7])
                    },constructBitmap:{ path,optional,backing in
                        var graphics=env.preparationGraphics
                        defer { if rejection != nil { diagnosticGraphics=graphics } }
                        let result=try adapter.construct(path,optional,backing,&graphics,scratch:&scratch,afterRequest:{ key in
                            if failure=="graphicsAPI:"+key { throw Stop.injected }
                        }) { try event(.init("preparationBitmap"),&env) }
                        env.preparationGraphics=graphics
                        if compareRetainedScratch,result != nil {
                            let constructors=item.helpers.filter { $0.entry==0x43ee50 }
                            guard scratchConstructors<constructors.count else { throw Stop.unexpected }
                            let count=try XCTUnwrap(constructors[scratchConstructors].lastStore)
                            try compareScratch(scratch,item.before,throughStores:count)
                            scratchConstructors += 1
                        }
                        if failure=="bitmap" || failure=="nullBitmap" && result==nil ||
                            failure=="partialBitmap" && adapter.failedConstructionOrdinals.contains(adapter.allocation-1) {
                            throw Stop.injected
                        };return result
                    },releaseBitmap:{ index,bitmap in
                        var graphics=env.preparationGraphics
                        defer { if rejection != nil { diagnosticGraphics=graphics } }
                        try adapter.release(index,bitmap,&graphics) { kind,_ in
                            try event(.init("preparationBitmap"),&env)
                            if failure==kind { throw Stop.injected }
                        }
                        env.preparationGraphics=graphics
                    },resumeMusic:{ globals in
                        let musicAdapter=try OriginalWarPreparationMusicAdapter(item.resourceFailureInput?.music,control:item.spec.control,memory:audio)
                        var musicGlobals=globals
                        try scratch.resumePreparationMusic(globals:&globals,memory:&audio,store:{ address,bytes in
                            for (i,byte) in bytes.enumerated() { try musicGlobals.write(byte,at:address-base+i) }
                        }) { request in
                            if request.kind == .format,request.strings.first == Array("%s\\graph.log".utf8) {
                                scratchMusicFormat=true
                            }
                            let response=try musicAdapter.response(request)
                            if request.kind == .message {
                                // The source graphics observer owns MessageBox; music
                                // stores have already changed globals at this request.
                                let captured=try adapter.next("message"),expected=try XCTUnwrap(captured.request)
                                XCTAssertEqual(request.arguments,expected.words);XCTAssertEqual(request.strings,expected.strings)
                                XCTAssertNil(expected.bytes);XCTAssertNil(expected.defined)
                                XCTAssertEqual(captured.response,.init(result:response.result))
                                let key=try XCTUnwrap(captured.key);XCTAssertEqual(key,"message#1")
                                env.preparationGraphics.requested.append(key)
                                let own=try r.sourceGlobals(musicGlobals)
                                XCTAssertEqual(own.bytes,Array(try r.blob(XCTUnwrap(captured.globals)).prefix(own.bytes.count)))
                                try event(.init("preparationBitmap"),&env)
                            } else {
                                guard musicIndex<item.bodyMusic.count else { throw Stop.unexpected }
                                let expected=item.bodyMusic[musicIndex];musicIndex += 1
                                XCTAssertEqual(request,.init(expected.kind,expected.arguments,expected.strings))
                                XCTAssertEqual(response,expected.response,"Declared music response")
                                try event(.init(request.kind.rawValue,request.arguments,request.strings),&env)
                            }
                            env.music.append(request)
                            if failure=="scratchMusicFormat",request.kind == .format,request.strings.first == Array("%s\\graph.log".utf8) { throw Stop.injected }
                            if let key=OriginalWarPreparationMusicAdapter.rollbackKey(request),failure=="musicAPI:"+key { throw Stop.injected }
                            if failure=="music",request.kind == .method,request.arguments.count==4,request.arguments[1]==0x34,request.arguments[2]==0x2c020020 { throw Stop.injected }
                            return response
                        }
                        XCTAssertEqual(musicGlobals,globals,"Music stores reconstruct own globals, including message boundaries")
                    },allocateReplay:{ bytes in
                        XCTAssertEqual(bytes,0x630e18)
                        if failure=="allocateReplay" { throw Stop.injected }
                        let generation=item.spec.generation ?? 0
                        let address: UInt32=item.resourceFailureInput?.declared?.replayNull == true ? 0 :
                            (generation==0 ? 0x75000020 : 0x77000020+UInt32(generation-1)*0x640000)
                        allocatorResults.append((bytes,address))
                        return address
                    },observe:{ try event($0,&env) },numericCheckpoint:{ pc,seat,value in
                        let points=item.points.filter { $0.kind.hasPrefix("war-preparation-numeric-") }
                        if item.spec.matrixOrdinal == nil && item.resourceFailureInput == nil { XCTAssertTrue(points.isEmpty);return }
                        guard numericPoint<points.count else { throw Stop.unexpected }
                        let expected=points[numericPoint];numericPoint += 1
                        reachedPoints.append(expected.kind)
                        XCTAssertEqual(expected.kind,"war-preparation-numeric-0x"+String(pc,radix:16));XCTAssertEqual(expected.seat,UInt32(seat))
                        XCTAssertEqual(eventIndex,expected.eventCount);try compareState(value,expected.records)
                    },checkpoint:{ pc,value,allocation,name in
                        let points=item.points.filter { $0.kind.hasPrefix("war-preparation-0x") }
                        let expected=points[preparationPoint];preparationPoint += 1
                        reachedPoints.append(expected.kind)
                        XCTAssertEqual(expected.kind,"war-preparation-0x"+String(pc,radix:16));XCTAssertEqual(eventIndex,expected.eventCount)
                        try compareState(value,expected.records)
                        if rejection != nil {
                            diagnosticGlobals=try r.sourceGlobals(value.globals)
                            diagnosticPreparationState=value
                        }
                        try compareScratch(scratch,expected.records)
                        if pc != 0x43a21f {
                            let text=try XCTUnwrap(expected.name),pairs=Array(text.utf8)
                            let bytes=try stride(from:0,to:pairs.count,by:2).map { try XCTUnwrap(UInt8(String(decoding:pairs[$0..<$0+2],as:UTF8.self),radix:16)) }
                            XCTAssertEqual(name,bytes)
                        }
                        if pc==0x43a42d { try adapter.compareGlobals(r.sourceGlobals(value.globals)) }
                        if pc==0x43a70c,failure=="participants" { throw Stop.injected }
                        if pc==0x43a766 || pc==0x43a769 {
                            let pointer=try r.record(XCTUnwrap(expected.records.first { $0.address==0x4588a8 }))
                            try self.compare(allocation.replayPointers,pointer,"recording pointers")
                            let recorded=try r.record(XCTUnwrap(expected.records.first { $0.address==item.replayAddress }))
                            try self.compare(XCTUnwrap(allocation.allocations[try XCTUnwrap(item.replayAddress)]).storage,recorded,"whole recording")
                            if failure=="recording" { throw Stop.injected }
                        }
                    })
                },
                outputInput:outputInput,milliseconds:item.spec.milliseconds ?? 17,
                musicRequest:{ request,env in
                    let a=try XCTUnwrap(a,"Missing source startup report permits no startup music requests")
                    let expected=item.bodyMusic[musicIndex];musicIndex += 1
                    XCTAssertEqual(request,.init(expected.kind,expected.arguments,expected.strings))
                    try event(.init(request.kind.rawValue,request.arguments,request.strings),&env)
                    var response=expected.response
                    if request.kind == .allocate {
                        let pointer: UInt32=item.spec.music?.nullAllocation == true ? 0 : (item.spec.expectedPreparation == true ? 0x2c020020 : 0x2c010020)
                        response = .init(pointer:pointer,bytes:pointer==0 ? nil : a.pattern(Int(request.arguments[0])))
                    } else if request.kind == .convert {
                        XCTAssertTrue(request.strings[0].allSatisfy { $0<128 })
                        let bytes=(request.strings[0]+[0]).flatMap { [$0,UInt8(0)] }
                        response = .init(result:request.arguments[3]==0 ? 0 : Int32(request.strings[0].count+1),bytes:request.arguments[3]==0 ? [] : bytes)
                    }
                    XCTAssertEqual(response,expected.response)
                    env.music.append(request)
                    if failure=="music",request.kind == .method,request.arguments.count==4,request.arguments[1]==0x34,request.arguments[2]==0x2c020020 { throw Stop.injected }
                    return response
                },allocate:{ i,env in
                    let value=try XCTUnwrap(a).allocate(i,&env.graphics);try event(.init("startup"),&env);return value
                },warAllocate:{ i,env in
                    let value=try XCTUnwrap(warAdapter).allocate(i,&env.warGraphics)
                    try event(.init("warBitmap"),&env);return value
                },perform:{ q,env in
                    let response=try XCTUnwrap(a).perform(q,&env.graphics);try event(.init("startup"),&env);return response
                },warPerform:{ q,env in
                    let response=try XCTUnwrap(warAdapter).perform(q,&env.warGraphics)
                    try event(.init("warBitmap"),&env);return response
                },bitmapStorage:{ token,_ in
                    try XCTUnwrap(initial.memory.allocations[token]).storage
                },resourceEvent:{ e,env in
                    try XCTUnwrap(a).observe(e,&env.graphics)
                    if e.kind != .allocate { try event(.init("startup"),&env) }
                },warResourceEvent:{ e,env in
                    try XCTUnwrap(warAdapter).observe(e,&env.warGraphics)
                    if e.kind != .allocate { try event(.init("warBitmap"),&env) }
                },warBeforeResource:{ _,state,_,_ in
                    try XCTUnwrap(warAdapter).shadow=r.sourceGlobals(state).bytes+XCTUnwrap(a).suffix
                },afterMusic:{ entered,state,memory,env in
                    try compareFaultStartup("musicReturned",state)
                    XCTAssertFalse(entered)
                    if let a,let startup=item.startup {
                        XCTAssertEqual(a.index,startup.musicBoundary.eventCount)
                        a.shadow=try r.sourceGlobals(state).bytes+a.suffix;XCTAssertEqual(a.shadow,try r.startup.blob(startup.musicBoundary.snapshot.globals))
                        try compareMusic(startup.musicBoundary.allocations,memory)
                    } else {
                        XCTAssertEqual(memory.allocations,initial.music.allocations)
                        XCTAssertEqual(env,initial.environment)
                    }
                    if failure == "afterMusic" { throw Stop.injected }
                },resourceCheckpoint:{ point,state,images,buffer in
                    try compareFaultStartup("resources-"+point.kind.rawValue,state)
                    guard let a else {
                        XCTAssertTrue(["prefix","complete"].contains(point.kind.rawValue))
                        XCTAssertEqual(images,initial.resources.bitmaps)
                        XCTAssertEqual(buffer,initial.environment)
                        return
                    }
                    if item.spec.chain != true { try a.stored(point,r.sourceGlobals(state),images,&buffer.graphics) }
                    else {
                        let expected=a.c.checkpoints[a.stores];a.stores += 1
                        XCTAssertEqual(point.kind.rawValue,expected.kind);XCTAssertEqual(point.index,expected.index);XCTAssertEqual(a.index,expected.eventCount)
                        a.shadow=try r.sourceGlobals(state).bytes+a.suffix;XCTAssertEqual(a.shadow,try r.startup.blob(expected.snapshot.globals))
                        try compareImages(expected.records,images,buffer)
                    }
                },afterStartup:{ result,state,memory,images,env in
                    try compareFaultStartup("startupReturned",state)
                    guard let a,let startup=item.startup else {
                        XCTAssertFalse(result.musicEntered)
                        XCTAssertEqual(result.resources.continuation,.ready)
                        XCTAssertEqual(result.resources.selectionAtEntry,3)
                        XCTAssertEqual(memory.allocations,initial.music.allocations)
                        XCTAssertEqual(images.bitmaps,initial.resources.bitmaps)
                        XCTAssertEqual(env,initial.environment)
                        return
                    }
                    XCTAssertEqual(try r.sourceGlobals(state).bytes+a.suffix,try r.startup.blob(a.c.after.globals))
                    XCTAssertEqual(a.index,a.events.count);XCTAssertEqual(a.stores,a.c.checkpoints.count)
                    try compareMusic(startup.musicAllocations,memory);try compareImages(a.c.records,images.bitmaps,env)
                    if failure == "afterStartup" { throw Stop.injected }
                },draw:{ request,state,images,buffer in
                    try draw(request,state,images.bitmaps,false,&buffer)
                },warDraw:{ request,state,images,buffer in
                    try draw(request,state,images.bitmaps,true,&buffer)
                },outputDraw:{ _,_,_,_ in throw Stop.unexpected },observe:event,
                characterCheckpoint:{ point,state,buffer in
                    let points=item.points.filter { $0.kind.hasPrefix("character-") }
                    let expected=points[characterPoint];characterPoint += 1
                    reachedPoints.append(expected.kind)
                    XCTAssertEqual(expected.kind,"character-0x"+String(point.pc,radix:16));XCTAssertEqual(eventIndex,expected.eventCount)
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

                },warCheckpoint:{ point,state,owned,buffer in
                    let points=item.points.filter { $0.kind.hasPrefix("war-0x") }
                    guard warPoint<points.count else { throw Stop.unexpected }
                    let expected=points[warPoint];warPoint += 1
                    reachedPoints.append(expected.kind)
                    XCTAssertEqual(expected.kind,"war-0x"+String(point.pc,radix:16));XCTAssertEqual(eventIndex,expected.eventCount)
                    // Source retains the full private stack in its read/store
                    // audit. These checkpoints expose owned game state only.
                    XCTAssertNil(expected.locals)
                    if point.pc==0x438bbb,initial.war.bitmaps.isEmpty { buffer.warGraphics=buffer.graphics }
                    if point.pc==0x438bbb,let actions=item.spec.expectedActions {
                        var mask=0
                        for (i,address) in [0x4513b4,0x4513b8,0x4513bc].enumerated() {
                            if try state.globals.integer(at:address-base,as:Int32.self) != 0 { mask |= 1<<i }
                        }
                        XCTAssertEqual(mask,actions.mask,item.spec.label+" actual Native menu input flags")
                    }
                    try compareState(state,expected.records)
                    try XCTUnwrap(warAdapter).compareOwned(owned,expected.records,buffer.warGraphics)
                    try compareScratch(owned.bitmapScratch,expected.records)
                    if failure=="secondResource",point.pc==0x438d2a { throw Stop.injected }
                    if failure=="latePreset",point.pc==0x439e76 { throw Stop.injected }
                    if failure=="lateFinalize",point.pc==0x43a21f { throw Stop.injected }
                },checkpoint:{ name,scene,state,buffer in
                    reachedPoints.append(name)
                    let point=try XCTUnwrap(item.points.first { $0.kind == name });XCTAssertEqual(eventIndex,point.eventCount)
                    let expected=try XCTUnwrap(point.records.first { $0.address == UInt32(base) });try compare(state,try r.nativeGlobals(r.record(expected)),name+" globals");try compareWorld(scene,point.records)
                    XCTAssertNil(rejection,"A faulted caller must not reach menu output")
                    if failure == "beforeReturn" && name == "matchBeforeReturn" { throw Stop.injected }
                })
            XCTAssertNil(rejection,"Expected the declared Native guard, but the whole caller returned")
            let a=try XCTUnwrap(a)
            XCTAssertNil(failure);XCTAssertEqual(warPoint,item.points.filter { $0.kind.hasPrefix("war-0x") }.count);XCTAssertEqual(end.rawValue,item.end);XCTAssertEqual(eventIndex,item.events.count)
            XCTAssertEqual(item.cw,0x23f)
            XCTAssertEqual(item.endSP,item.end == "warMatchPreparation" ? try XCTUnwrap(item.warSP) : c.entrySP+8)
            XCTAssertEqual(characterPoint,item.points.filter { $0.kind.hasPrefix("character-") }.count)
            try compareState(prepared,item.after)
            try compareScratch(war.bitmapScratch,item.after)
            try compare(memory.replayPointers,try XCTUnwrap(after[0x4588a8]),item.spec.label+" replay pointers")
            for record in item.after where record.live != nil && record.address < 0x2c000000 {
                let allocation=try XCTUnwrap(memory.allocations[record.address]);XCTAssertEqual(allocation.live,record.live)
                try compare(allocation.storage,try r.record(record),item.spec.label+" retained allocation")
            }
            if let adapter=warAdapter { try adapter.compare(war,committed.warGraphics) }
            XCTAssertEqual(preparationPoint,item.points.filter { $0.kind.hasPrefix("war-preparation-0x") }.count)
            XCTAssertEqual(numericPoint,item.points.filter { $0.kind.hasPrefix("war-preparation-numeric-") }.count)
            if let adapter=preparationAdapter { try adapter.compare(prepared,committed.preparationGraphics) }
            if compareRetainedScratch,preparationAdapter != nil { XCTAssertEqual(scratchConstructors,5) }
            for record in item.after where [UInt32(0x75000020),0x77000020,0x77640020].contains(record.address) {
                let allocation=try XCTUnwrap(memory.allocations[record.address]);XCTAssertEqual(allocation.live,record.live)
                try compare(allocation.storage,r.record(record),"retained recording bytes/mask")
            }
            if let replay=item.replayAddress {
                let allocation=try XCTUnwrap(memory.allocations[replay]);XCTAssertTrue(allocation.live)
                try compare(allocation.storage,try XCTUnwrap(after[replay]),"whole recording after outer return")
            }
            XCTAssertEqual(musicIndex,item.bodyMusic.count)
            try compareMusic(item.musicAfter,music);try compareImages(a.c.records,resources.bitmaps,committed)
            XCTAssertEqual(committed.graphics.imagesDeleted,Dictionary(uniqueKeysWithValues:a.c.images.map { (UInt32($0.key)!,$0.value.deleted) }))
            XCTAssertEqual(committed.graphics.surfacesReleased,Dictionary(uniqueKeysWithValues:a.c.surfaces.map { (UInt32($0.key)!,$0.value.released) }))
            XCTAssertEqual(committed.graphics.surfaceDescriptions,Dictionary(uniqueKeysWithValues:a.c.surfaces.map { (UInt32($0.key)!,$0.value.description) }))
            XCTAssertEqual(committed.graphics.dcs,Dictionary(uniqueKeysWithValues:a.c.dcs.map { (UInt32($0.key)!,$0.value) }))
            XCTAssertEqual(library.retainedDC,try XCTUnwrap(after[c.libraryAddress]).integer(at:0x306e,as:UInt32.self))
            XCTAssertEqual(committed.front.count-firstFrontCount,item.events.count)
            retained=Retained(war:war,prepared:prepared,memory:memory,library:library,music:music,resources:resources,environment:committed)
        } catch {
            if let rejection {
                guard let native=error as? OriginalStateError,
                      case .invalidStorage(let message)=native else { throw error }
                XCTAssertEqual(message,rejection.message,"Exact Native boundary, not a harness failure")
                XCTAssertEqual(eventIndex,rejection.frontEvents)
                XCTAssertEqual(diagnosticFront.count,rejection.frontEvents)
                XCTAssertEqual(reachedPoints,item.points.map(\.kind),"Consume every saved pre-guard checkpoint in order")
                XCTAssertEqual(characterPoint,item.points.filter { $0.kind.hasPrefix("character-") }.count)
                XCTAssertEqual(warPoint,item.points.filter { $0.kind.hasPrefix("war-0x") }.count)
                XCTAssertEqual(preparationPoint,item.points.filter { $0.kind.hasPrefix("war-preparation-0x") }.count)
                XCTAssertEqual(numericPoint,item.points.filter { $0.kind.hasPrefix("war-preparation-numeric-") }.count)
                XCTAssertEqual(musicIndex,item.bodyMusic.count)
                let adapter=try XCTUnwrap(preparationAdapter)
                XCTAssertEqual(adapter.index,adapter.c.events.count,"Complete graphics request prefix")
                XCTAssertEqual(adapter.allocation,adapter.c.allocations.count)
                let graphics=diagnosticGraphics ?? initial.environment.preparationGraphics
                adapter.compareContext(graphics)
                // In music/replay cases bitmap construction has returned in
                // full. Compare its owned bytes/masks and retained wrappers.
                if item.bodyMusic.count>0 { try adapter.compare(XCTUnwrap(diagnosticPreparationState),graphics) }
                // Release callbacks do not change globals. No post-release
                // checkpoint exists in these faulted source calls.
                if rejection.releaseFreePairs>0 { try adapter.compareGlobals(XCTUnwrap(diagnosticGlobals)) }
                let releaseEvents=adapter.c.events.filter { $0.request?.kind=="release" }
                let freeEvents=adapter.c.events.filter { $0.request?.kind=="free" }
                XCTAssertEqual(releaseEvents.count,rejection.releaseFreePairs)
                XCTAssertEqual(freeEvents.count,rejection.releaseFreePairs)
                if rejection.releaseFreePairs>0 {
                    for e in releaseEvents {
                        let surface=try XCTUnwrap(e.request?.words.first)
                        XCTAssertEqual(initial.environment.preparationGraphics.surfacesReleased[surface],false)
                        XCTAssertEqual(graphics.surfacesReleased[surface],true,"Staged request only; rollback below preserves the owner")
                    }
                }
                if rejection.replayNull {
                    XCTAssertEqual(item.resourceFailureInput?.declared?.replayNull,true)
                    XCTAssertEqual(allocatorResults.count,1)
                    let allocation=try XCTUnwrap(allocatorResults.first)
                    XCTAssertEqual(allocation.bytes,0x630e18);XCTAssertEqual(allocation.address,0)
                    XCTAssertEqual(item.events.count,rejection.frontEvents+1)
                    XCTAssertEqual(item.events.last,.init("calloc",[0,1,0x630e18]))
                    XCTAssertEqual(diagnosticFront.last,.init("free",[0x26003000]))
                    XCTAssertFalse(diagnosticFront.contains { $0.kind=="calloc" })
                    for address in [UInt32(0x26003000),0x26003100] {
                        XCTAssertEqual(initialMemory.allocations[address]?.live,true)
                    }
                } else {
                    XCTAssertTrue(allocatorResults.isEmpty)
                    XCTAssertEqual(item.events.count,rejection.frontEvents)
                }
            } else {
                guard let stop=error as? Stop,stop == .injected else { throw error }
                XCTAssertNotNil(failure)
            }
            XCTAssertEqual(prepared.globals,initialGlobals);XCTAssertEqual(prepared.world,initialWorld);XCTAssertEqual(prepared.actors,initialActors);XCTAssertEqual(memory.allocations,initialMemory.allocations);XCTAssertEqual(memory.replayPointers,initialMemory.replayPointers)
            XCTAssertEqual(war,initial.war)
            XCTAssertEqual(library,initialLibrary);XCTAssertEqual(committed,initial.environment)
            XCTAssertEqual(world,initialWorld);XCTAssertEqual(music.allocations,initial.music.allocations);XCTAssertEqual(resources.bitmaps,initial.resources.bitmaps)
            XCTAssertEqual(prepared.backgrounds,initial.prepared.backgrounds);XCTAssertEqual(prepared.bitmaps,initial.prepared.bitmaps)
            XCTAssertEqual(prepared.releasedBitmaps,initial.prepared.releasedBitmaps);XCTAssertEqual(prepared.releasedBitmapOrder,initial.prepared.releasedBitmapOrder)

        }
        return eventIndex
    }
    func compareParent(_ item: Case,_ r: Resources,firstCase: Int) throws {
        for parent in r.corpus.parents {
            XCTAssertEqual(parent.firstCase,firstCase)
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
    }
    func testWholeBoundPreparationAndLateRollback() throws {
        let index=try Index()
        let url=try XCTUnwrap(Bundle.module.url(forResource:"original-loaded-catalog",withExtension:"json",subdirectory:"Fixtures"))
        var loaded: OriginalLoadedCatalog?
        _ = try LoadedCatalogReference.compare(Data(contentsOf:url),onLoaded:{ loaded=$0 })
        let catalog=try XCTUnwrap(loaded)
        var retained: Retained?,events=0,expectedEvents=0,parents=0,preparations=0,rollbacks=0
        for number in index.c.cases.indices {
            try autoreleasepool {
                let r=try Resources(index,number,catalog:catalog),item=r.corpus.cases[0]
                if item.spec.chain != true { retained=nil;try compareParent(item,r,firstCase:number);parents += 1 }
                if item.spec.expectedPreparation == true {
                    for failure in ["bitmap","participants","music","allocateReplay","recording","beforeReturn"] {
                        var trial=retained;_ = try run(item,r,&trial,failure:failure);rollbacks += 1
                    }
                    preparations += 1
                }
                events += try run(item,r,&retained);expectedEvents += item.events.count
                XCTAssertEqual(item.end,"returned")
                FileHandle.standardError.write(Data("War preparation compared \(number): \(item.spec.label)\n".utf8))
            }
        }
        XCTAssertEqual(parents,2);XCTAssertEqual(preparations,2);XCTAssertEqual(rollbacks,12)
        XCTAssertEqual(events,expectedEvents)
    }
}
