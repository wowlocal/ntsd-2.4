import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalLibSelectionCommandsTests: XCTestCase {
    typealias Base = OriginalCharacterMenuSurfaceTests
    typealias Music = OriginalCharacterMenuMusicSurfaceTests
    struct Environment: Equatable {
        var front: [OriginalFrontScreenEvent] = []
        var graphics = Base.Context()
        var music: [OriginalMusicEvent] = []
    }
    struct Startup: Decodable {
        let musicBoundary: Music.Boundary, musicAllocations: [Base.Record], events: [Music.Event]
    }
    struct MusicSpec: Decodable { let nullAllocation: Bool? }
    struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    struct Transport: Decodable { let count: Int,sha256: String,deflateSHA256: String,deflateParts: [String] }
    struct Storage: Decodable { let bytes: String, defined: String }
    struct Record: Decodable { let address: UInt32, storage: Storage, live: Bool? }
    struct Spec: Decodable { let buttons: [[Int]]?; let label: String, control: Bool, music: MusicSpec?, chain: Bool?, dcResult: Int32?, dc: UInt32?, methodResult: Int32?, milliseconds: UInt32? }
    struct Point: Decodable { let kind: String,records: [Record],eventCount: Int,seat: UInt32?,locals: [String:UInt32]? }
    struct Helper: Decodable { let entry: UInt32,firstStore: Int,lastStore: Int? }
    struct Write: Decodable { let address: UInt32,bytes: String }
    struct Read: Decodable { let address: UInt32,count: Int,storeCount: Int }
    struct Case: Decodable {
        let helpers: [Helper],pending: [Helper],writes: [Write],reads: [Read],apiReads: [Read]
        let spec: Spec, before: [Record], after: [Record], actorAddresses: [UInt32]
        let stimulus: [Write]?
        let events: [OriginalFrontScreenEvent], end: String, endSP: UInt32, cw: UInt32
        let startup: Startup, characterSP: UInt32?, screenSP: UInt32?,output: OriginalMenuPresentationInput,points: [Point]
    }
    struct Portrait: Decodable { let address: UInt32, surface: UInt32, width: Int32, height: Int32, path: String }
    struct Entry: Decodable { let ordinal: Int,id: Int32,type: Int32,address: UInt32,nameTail: String,nameMask: String,portrait: Portrait? }
    struct Roster: Decodable { let entries: [Entry] }
    struct Corpus: Decodable {
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
        var portraitAddresses: [Int:UInt32] = [:]
        init() throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_LIB_SELECTION_COMMANDS"].map { URL(fileURLWithPath:$0) }
                ?? XCTUnwrap(Bundle.module.url(forResource:"original-lib-selection-commands",withExtension:"json",subdirectory:"Fixtures"))
            let envelope=try Data(contentsOf:url)
            let data: Data
            if let parts=try? JSONDecoder().decode(Transport.self,from:envelope) {
                var deflate=Data()
                for name in parts.deflateParts {
                    guard !name.contains("/"),name.hasPrefix("original-lib-selection-commands-part") else { throw Stop.unexpected }
                    let bytes=try Data(contentsOf:url.deletingLastPathComponent().appendingPathComponent(name))
                    deflate.append(try MatchPreparationReference.unpack(bytes,maximumCount:60_000_000))
                }
                XCTAssertEqual(MatchPreparationReference.digest(deflate),parts.deflateSHA256)
                let joined=try JSONSerialization.data(withJSONObject:["count":parts.count,"sha256":parts.sha256,"deflate":deflate.base64EncodedString()])
                data=try MatchPreparationReference.unpack(joined,maximumCount:1_500_000_000)
            } else { data=try MatchPreparationReference.unpack(envelope,maximumCount:1_500_000_000) }
            corpus = try JSONDecoder().decode(Corpus.self,from:data)
            // A lossless projection into the retained startup comparator schema.
            // Full source bytes remain in the new fixture; no expected fields change.
            let document = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
            var projected = document
            projected["cases"] = try XCTUnwrap(document["cases"] as? [[String:Any]]).map { $0["startup"]! }
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-lib-commands-"+UUID().uuidString+".json")
            try JSONSerialization.data(withJSONObject:projected).write(to:temporary)
            defer { try? FileManager.default.removeItem(at:temporary) }
            startup = try Base.Resources(url:temporary,expectedCases:338)
            XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
            XCTAssertEqual(corpus.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
            XCTAssertEqual(corpus.cases.count,338)
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
                    let index=Int(ref-1);XCTAssertNil(portraitAddresses[index]);portraitAddresses[index]=0x72000020+UInt32(entry.ordinal)*0x2000
                    XCTAssertEqual(portrait.address,portraitAddresses[index]);XCTAssertEqual(portrait.surface,0x24000000)
                    let bitmap=catalog.bitmaps[index];XCTAssertEqual(bitmap.input.path,portrait.path)
                    var expected=try OriginalStateRecord(bytes:[UInt8](repeating:0xa5,count:0x1f50),defined:[Bool](repeating:false,count:0x1f50))
                    try expected.write(UInt32(1),at:0);try expected.write(portrait.width,at:4);try expected.write(portrait.height,at:8)
                    XCTAssertEqual(bitmap.storage,expected)
                }
            }
            XCTAssertEqual(portraitAddresses.count,42)
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes=decoded[key] { return bytes }
            let b=try XCTUnwrap(corpus.blobs[key]);XCTAssertEqual(b.sha256,key)
            let bytes=try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:2_000_000)
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
        var world=try XCTUnwrap(before[c.worldAddress])
        var actors=try item.actorAddresses.map { try XCTUnwrap(before[$0]) }
        XCTAssertEqual(actors.count,400)
        for i in 0..<400 {
            let pointer=try world.integer(at:0x194+i*4,as:UInt32.self)
            let index=try XCTUnwrap(item.actorAddresses.firstIndex(of:pointer));try world.write(UInt32(index),at:0x194+i*4)
        }
        try world.write(UInt32(0),at:0x7d4)
        for i in 0..<400 {
            XCTAssertEqual(try actors[i].integer(at:0x368,as:UInt32.self),0x68000020)
            try actors[i].write(UInt32(0),at:0x368)
        }
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
        let startupIndex = try XCTUnwrap(r.startup.c.cases.firstIndex { $0.spec.label == item.spec.label })
        let a = try Base.Adapter(r.startup.c.cases[startupIndex],r.startup)
        var eventIndex=0,characterPoint=0
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
            if failure == "reroll",e.kind == "random",e.arguments[0] == 0xea,
               environment.front.suffix(environment.front.count-firstFrontCount).filter({ $0.kind == "random" && $0.arguments[0] == 0xea }).count == 3 { throw Stop.injected }
            if failure == "arenaText",e.kind == "textOut",e.strings == [Array("Lee On Road".utf8)] { throw Stop.injected }
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
            let end=try OriginalCharacterMenuContinuation.advance(state:&prepared,memory:&memory,music:&music,resources:&resources,libraryText:&library,environment:&committed,
                target:c.target,input:.init(dcResult:item.spec.dcResult ?? 0,dc:item.spec.dc ?? 0x76543210,methodResult:item.spec.methodResult ?? -1,drawResults:[-1],shellResult:33),
                outputInput:item.output,milliseconds:item.spec.milliseconds ?? 17,
                musicRequest:{ _,_ in XCTFail("Music child must be skipped for menu1/3");throw Stop.unexpected
                },allocate:{ i,env in
                    let value=try a.allocate(i,&env.graphics);try event(.init("startup"),&env);return value
                },perform:{ q,env in
                    let response=try a.perform(q,&env.graphics);try event(.init("startup"),&env);return response
                },resourceEvent:{ e,env in
                    try a.observe(e,&env.graphics)
                    if e.kind != .allocate { try event(.init("startup"),&env) }
                },afterMusic:{ entered,state,memory,env in
                    XCTAssertEqual(entered,!env.music.isEmpty);XCTAssertEqual(a.index,item.startup.musicBoundary.eventCount)
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
                    case .catalog(let index):address=try XCTUnwrap(r.portraitAddresses[index]);bitmap=r.catalog.bitmaps[index].storage;surface=0x24000000
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
                    let points=item.points.filter { $0.kind.hasPrefix("character-") }
                    let expected=points[characterPoint];characterPoint += 1
                    XCTAssertEqual(expected.kind,"character-0x"+String(point.pc,radix:16));XCTAssertEqual(eventIndex,expected.eventCount)
                    if point.pc == 0x42a25a { XCTAssertEqual(expected.seat,UInt32(point.seat)) }
                    var expectedLocals=try XCTUnwrap(expected.locals).reduce(into:[Int:Int32]()) { $0[Int($1.key)!]=Int32(bitPattern:$1.value) }
                    if point.pc == 0x42cb86,let cursor=expectedLocals[0x38],UInt32(bitPattern:cursor)==c.worldAddress+0x1b4 {
                        expectedLocals[0x38]=0x1b4 // semantic World cursor, never imported backing
                    }
                    if [UInt32(0x42e0b6),0x42e0d2].contains(point.pc),let cursor=expectedLocals[0x20],UInt32(bitPattern:cursor)==c.worldAddress+0x1b4 {
                        expectedLocals[0x20]=0x1b4 // caller's own World cursor after reroll
                    }
                    XCTAssertEqual(point.locals,expectedLocals,item.spec.label+" caller locals at "+String(point.pc,radix:16))
                    try compareState(state,expected.records)
                    if failure == "screen" && point.pc == 0x42e0d2 { throw Stop.injected }
                },checkpoint:{ name,scene,state,buffer in
                    let point=try XCTUnwrap(item.points.first { $0.kind == name });XCTAssertEqual(eventIndex,point.eventCount)
                    let expected=try XCTUnwrap(point.records.first { $0.address == UInt32(base) });try compare(state,try r.record(expected),name+" globals");try compareWorld(scene,point.records)
                    if failure == "beforeReturn" && name == "matchBeforeReturn" { throw Stop.injected }
                })
            XCTAssertNil(failure);XCTAssertEqual(end.rawValue,item.end);XCTAssertEqual(eventIndex,item.events.count)
            XCTAssertEqual(item.cw,0x23f)
            XCTAssertEqual(item.endSP,item.end == "matchPrelude" ? item.characterSP : c.entrySP+8)
            XCTAssertEqual(characterPoint,item.points.filter { $0.kind.hasPrefix("character-") }.count)
            try compareState(prepared,item.after)
            try compare(memory.replayPointers,try XCTUnwrap(after[0x4588a8]),item.spec.label+" replay pointers")
            for record in item.after where record.live != nil && record.address < 0x2c000000 {
                let allocation=try XCTUnwrap(memory.allocations[record.address]);XCTAssertEqual(allocation.live,record.live)
                try compare(allocation.storage,try r.record(record),item.spec.label+" retained allocation")
            }
            try compareMusic(item.startup.musicAllocations,music);try compareImages(a.c.records,resources.bitmaps,committed)
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

        }
        return eventIndex
    }
    func testRerollAndReselectRetainWholeLibraryMenu() throws {
        let r=try Resources();var retained: Retained?,events=0
        for item in r.corpus.cases {
            if item.spec.chain != true { retained=nil }
            events += try run(item,r,&retained)
            if item.spec.label.hasPrefix("countdown-jump-release") {
                let s=try XCTUnwrap(retained).prepared,g=s.globals,base=OriginalMatchPreparation.globalBase
                XCTAssertEqual(try (0..<2).map { try g.integer(at:0x451248+$0*4-base,as:Int32.self) },[17,21])
                XCTAssertEqual(try (0..<2).map { try g.integer(at:0x451288+$0*4-base,as:Int32.self) },[3,3])
                XCTAssertEqual(try g.integer(at:0x44d078-base,as:Int32.self),115)
            }
        }
        XCTAssertGreaterThan(events,10_000)
    }
    func testLateRerollAndReselectRollBackCurrentCall() throws {
        let r=try Resources()
        for (label,failure) in [("reroll-first-press","reroll"),("reselect-press","screen")] {
            var retained: Retained?
            let end=try XCTUnwrap(r.corpus.cases.firstIndex { $0.spec.label==label })
            for item in r.corpus.cases[..<end] { _ = try run(item,r,&retained) }
            _ = try run(r.corpus.cases[end],r,&retained,failure:failure)
        }
    }
}
