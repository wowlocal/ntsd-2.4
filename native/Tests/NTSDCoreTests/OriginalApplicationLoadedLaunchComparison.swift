import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Immutable pristine launch observations projected onto the retained installed
/// application. All expected values stay here; no projected state enters Core.
final class OriginalApplicationLoadedLaunchComparison {
    typealias R = MatchLaunchReference
    typealias M = OriginalApplicationLoadedMenuTests
    let corpus: R.Corpus,initial: M.S.PendingMatchPrelude
    let sourcePool: OriginalStateRecord,sourceGlobals: OriginalStateRecord
    var cache: [String:[UInt8]] = [:]
    static let path = Array("bgm\\stage5.wma".utf8)
    static let musicBase: UInt32 = 0x32002000,musicBuffer: UInt32 = 0x32011020,replay: UInt32 = 0x80000020
    static let timer: UInt32 = 12345
    static let time = OriginalLocalTime(year:2026,month:9,dayOfWeek:3,day:9,hour:12,minute:34,second:56,milliseconds:789)
    init(_ reverse: Bool,_ pending: M.S.PendingMatchPrelude) throws {
        initial = pending
        let url = try XCTUnwrap(Bundle.module.url(forResource:"original-match-launch"+(reverse ? "-control" : ""),withExtension:"json",subdirectory:"Fixtures"))
        let data = try Data(contentsOf:url)
        XCTAssertEqual(MatchPreparationReference.digest(data),reverse ? "b7f7fd598116ad21bb5e6874d39409ec19f701aea2221d33580c1a0eb0b7efad" : "dc84f98a28b5e96aa691584ccd0389c62217f57dfd64f496a8e1f4d1341a4dda")
        corpus = try JSONDecoder().decode(R.Corpus.self,from:MatchPreparationReference.unpack(data,maximumCount:8_000_000))
        let before = try XCTUnwrap(corpus.cases[0].before)
        sourceGlobals = try Self.global(before.state,corpus)
        sourcePool = try Self.pool(before.state,corpus)
        XCTAssertEqual(corpus.cases.map(\.label),["prelude","preparation","music","preparation-tail","recording","menu-continuation","returned","gameplay-entry"])
        XCTAssertEqual(corpus.localTime,[2026,9,3,9,12,34,56,789])
        XCTAssertEqual(pending.confirmation,1);XCTAssertTrue(pending.snapshot.match.libraryCommands != nil)
        XCTAssertNil(pending.snapshot.match.libraryCommands?.requestedObjectID)
        let own = pending.snapshot.match
        for address in [0x451160,0x44d020,0x44d024,0x44d028,0x44d06c,0x450c2c,0x450b98,0x450be4,0x450bcc,0x450c34] {
            XCTAssertEqual(try own.globals.integer(at:address-0x44d000,as:UInt32.self),try sourceGlobals.integer(at:address-0x44d000,as:UInt32.self))
        }
        for seat in 0..<8 {
            XCTAssertEqual(try own.globals.integer(at:0x451288-0x44d000+seat*4,as:Int32.self),seat < 2 ? 3 : 0)
        }
        for seat in 0..<2 { for offset in [0x364,0x368] {
            XCTAssertEqual(try own.actors[seat].integer(at:offset,as:UInt32.self),try sourcePool.integer(at:0x7d8+seat*0x420+offset,as:UInt32.self))
        } }
        XCTAssertEqual(try (0..<4).map { try own.backgrounds[0].integer(at:$0*4,as:Int32.self) },[960,450,525,0])
        let table = Array(own.globals.bytes[(0x44ff90-0x44d000)..<(0x44ff90-0x44d000+3001)])
        XCTAssertEqual(MatchPreparationReference.digest(Data(table)),"5352f941c619060669587370c1974685877d4899a6ad0d1b165f54ecd4aa89c7")
        XCTAssertEqual((36...39).map { (Int(table[$0])+$0)%($0%2 == 0 ? 480 : 75) },[177,53,189,18])
    }
    static func bytes(_ key: String,_ corpus: R.Corpus) throws -> [UInt8] {
        let b = try XCTUnwrap(corpus.blobs[key]),value = try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:8_000_000)
        XCTAssertEqual(MatchPreparationReference.digest(Data(value)),key);return value
    }
    func bytes(_ key: String) throws -> [UInt8] {
        if let b = cache[key] { return b };let b = try Self.bytes(key,corpus);cache[key] = b;return b
    }
    static func global(_ snapshot: InputControlReference.Snapshot,_ c: R.Corpus) throws -> OriginalStateRecord {
        let b = try bytes(snapshot.globals,c);return try .init(bytes:b,defined:[Bool](repeating:true,count:b.count))
    }
    static func pool(_ snapshot: InputControlReference.Snapshot,_ c: R.Corpus) throws -> OriginalStateRecord {
        var r = try OriginalStateRecord(bytes:bytes(snapshot.poolBytes,c),defined:bytes(snapshot.poolMask,c).map { $0 != 0 })
        let actors = Dictionary(uniqueKeysWithValues:c.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let objects = Dictionary(uniqueKeysWithValues:c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        for i in 0..<400 {
            try r.write(XCTUnwrap(actors[r.integer(at:0x194+4*i,as:UInt32.self)]),at:0x194+4*i)
            let offset = 0x7d8+i*0x420+0x368
            try r.write(XCTUnwrap(objects[r.integer(at:offset,as:UInt32.self)]),at:offset)
        }
        try r.write(UInt32(0),at:0x7d4);return r
    }
    func pool(_ state: OriginalMatchPreparation) throws -> OriginalStateRecord {
        try .init(bytes:state.world.bytes+state.actors.flatMap(\.bytes),defined:state.world.defined+state.actors.flatMap(\.defined))
    }
    func equal(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
        guard actual.bytes.count == expected.bytes.count else { throw M.Stop.unexpected(label+" extent") }
        if let i = actual.bytes.indices.first(where:{ actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
            throw M.Stop.unexpected(label+" byte "+String(i,radix:16)+" actual \(actual.bytes[i])/\(actual.defined[i]) expected \(expected.bytes[i])/\(expected.defined[i])")
        }
    }
    func copy(_ from: OriginalStateRecord,_ range: Range<Int>,into to: inout OriginalStateRecord) throws {
        var b = to.bytes,m = to.defined
        b.replaceSubrange(range,with:from.bytes[range]);m.replaceSubrange(range,with:from.defined[range])
        to = try .init(bytes:b,defined:m)
    }
    func delta(_ own: OriginalStateRecord,_ before: OriginalStateRecord,_ after: OriginalStateRecord,
               overwrites: Set<Int> = []) throws -> OriginalStateRecord {
        var b = own.bytes,m = own.defined
        for i in b.indices where before.bytes[i] != after.bytes[i] || before.defined[i] != after.defined[i] {
            guard overwrites.contains(i) || (own.bytes[i] == before.bytes[i] && own.defined[i] == before.defined[i]) else {
                throw M.Stop.unexpected("Undeclared changed launch input "+String(i,radix:16))
            }
            b[i] = after.bytes[i];m[i] = after.defined[i]
        }
        return try .init(bytes:b,defined:m)
    }
    func expectedPool(_ index: Int) throws -> OriginalStateRecord {
        let after = try Self.pool(corpus.cases[index].after.state,corpus)
        let slots = index >= 1 ? [0,1]+(index >= 3 ? Array(20..<400) : []) : []
        let writes = [0..<0x24,0x28..<0x81,0x84..<0xbd,0xbe..<0xdd,0xe0..<0x31c,0x320..<0x368,0x36c..<0x370,0x3e8..<0x41c]
        var overwritten = Set<Int>()
        for slot in slots { for range in writes { for offset in range { overwritten.insert(0x7d8+slot*0x420+offset) } } }
        if index >= 1 { overwritten.formUnion(14..<0x194) }
        if index >= 3 { for slot in 0..<8 { overwritten.formUnion((0x7d8+slot*0x420+0xcd)..<(0x7d8+slot*0x420+0xd4)) } }
        var value = try delta(pool(initial.snapshot.match),sourcePool,after,overwrites:overwritten)
        if index >= 1 {
            try copy(after,4..<6,into:&value);try copy(after,14..<0x194,into:&value)
            // Actual4061d0 store footprint, including idempotent stores. Values
            // are taken from the immutable returned constructor/caller records.
            for slot in slots { for r in writes {
                let start = 0x7d8+slot*0x420;try copy(after,(start+r.lowerBound)..<(start+r.upperBound),into:&value)
            } }
            for slot in 0..<2 {
                let start = 0x7d8+slot*0x420
                for r in [0x31c..<0x320,0x368..<0x36c] { try copy(after,(start+r.lowerBound)..<(start+r.upperBound),into:&value) }
                try value.write(Int32(240),at:start+0x10);try value.writeBinary64(240,at:start+0x58)
                try value.write(Int32(slot == 0 ? 503 : 468),at:start+0x18)
                try value.writeBinary64(slot == 0 ? 503 : 468,at:start+0x68)
            }
        }
        if index >= 3 { for seat in 0..<8 {
            let start = 0x7d8+seat*0x420;try copy(after,(start+0xcd)..<(start+0xd4),into:&value)
        } }
        return value
    }
    func expectedGlobals(_ index: Int) throws -> OriginalStateRecord {
        let after = try Self.global(corpus.cases[index].after.state,corpus)
        var words = [0x450bb0,0x450bb4,0x44d020,0x450b6c,0x450b70]
        if index >= 1 { words += Array(stride(from:0x450c04,through:0x450c28,by:4))+[0x44d034,0x450bbc,0x450bdc,0x450bcc,0x450c34] }
        if index >= 3 { words += Array(stride(from:0x4513a4,through:0x4513bc,by:4))+Array(stride(from:0x451320,through:0x45133c,by:4)) }
        if index >= 4 { words += [0x450b8c,0x450b80,0x450c34,0x450bd0,0x450bd4,0x450bd8] }
        var overwritten = Set(words.flatMap { ($0-0x44d000)..<($0-0x44d000+4) })
        overwritten.formUnion((0x44fd98-0x44d000)..<(0x44fd98-0x44d000+23))
        if index >= 2 {
            overwritten.formUnion((0x44f040-0x44d000)..<(0x44f050-0x44d000))
            overwritten.formUnion((0x44ef04-0x44d000)..<(0x44ef38-0x44d000))
        }
        if index >= 3 { overwritten.formUnion((0x455378-0x44d000)..<(0x455378-0x44d000+300)) }
        if index >= 6 { overwritten.formUnion((0x451154-0x44d000)..<(0x45115c-0x44d000)) }
        var value = try delta(initial.snapshot.match.globals,sourceGlobals,after,overwrites:overwritten)
        for address in words { try copy(after,(address-0x44d000)..<(address-0x44d000+4),into:&value) }
        try copy(after,(0x44fd98-0x44d000)..<(0x44fd98-0x44d000+23),into:&value)
        if index >= 1 { try value.write(UInt8(3),at:0x450bb8-0x44d000) }
        if index >= 2 {
            for (i,address) in [0x44f040,0x44f044,0x44f048,0x44f04c].enumerated() { try value.write(Self.musicBase+UInt32(i)*0x100,at:address-0x44d000) }
            // The old selected/cache paths have different lengths; copy only
            // the owned path through NUL, retaining the original own suffix.
            try copy(initial.snapshot.match.globals,(0x44ef04-0x44d000)..<(0x44ef38-0x44d000),into:&value)
            for (i,b) in (Self.path+[0]).enumerated() { try value.write(b,at:0x44ef04-0x44d000+i) }
        }
        if index >= 3 { try copy(after,(0x455378-0x44d000)..<(0x455378-0x44d000+300),into:&value) }
        if index >= 6 { try value.write(Self.timer,at:0x451154-0x44d000) }
        return value
    }
    func state(_ index: Int,_ actual: M.S.Snapshot) throws {
        try equal(pool(actual.match),expectedPool(index),"launch \(index) pool")
        try equal(actual.match.globals,expectedGlobals(index),"launch \(index) globals")
        XCTAssertEqual(actual.match.arithmeticPrecision,.bits53)
        XCTAssertEqual(actual.match.frameAllocations,initial.snapshot.match.frameAllocations)
        XCTAssertTrue(actual.match.loadedObjects == initial.snapshot.match.loadedObjects,"All loaded Object owners retained")
        XCTAssertEqual(actual.match.interface.bitmaps,initial.snapshot.match.interface.bitmaps)
        XCTAssertEqual(actual.match.releasedBitmaps,initial.snapshot.match.releasedBitmaps)
        XCTAssertEqual(actual.resources.bitmaps,initial.snapshot.resources.bitmaps)
        XCTAssertEqual(actual.backgrounds,initial.snapshot.backgrounds)
        XCTAssertEqual(actual.state.random,initial.snapshot.state.random)
        XCTAssertEqual(actual.match.libraryCommands?.requestedObjectID,index >= 1 ? 0 : nil)
        try M.I.coherent(OriginalApplicationMatchBindings(pending:initial.entry.entry),actual.match,actual.state)
    }

    func returnEvents() throws -> [OriginalFrontScreenEvent] {
        let saved = try XCTUnwrap(corpus.cases[6].returned).events
        XCTAssertEqual(saved.map(\.kind),["format","getDC","setBackgroundColor","setTextColor","stringLength","textOut","releaseDC","method","timer"])
        let target: UInt32 = try initial.snapshot.match.globals.integer(at:0x455608-0x44d000,as:UInt32.self)
        return try saved.map { event in
            switch event.kind {
            case "getDC":return .init("getDC",[target])
            case "releaseDC":return .init("releaseDC",[target,0x12345678])
            case "setBackgroundColor":
                XCTAssertEqual(event.arguments,[0x12345678,0]);return .init("setBackgroundMode",[0x12345678,1])
            case "method":return try OriginalApplicationLoadedCharacterTests.present(expectedGlobals(6))
            case "timer":return .init("timer",[Self.timer])
            default:return event
            }
        }
    }

    /// Explicit numeric API controls plus independent ASCII-to-UTF16 output.
    /// Source request order is retained; current path/window/old owners differ.
    func music(_ request: OriginalMusicEvent,_ index: Int) throws -> OriginalMusicResponse {
        let events = try XCTUnwrap(corpus.cases[2].music).events
        guard events.indices.contains(index) else { throw M.Stop.unexpected("Extra launch music event") }
        let source = events[index]
        func translated(_ token: UInt32) throws -> UInt32 {
            if (0x31002000...0x31002400).contains(token),token%0x100 == 0 {
                let slot = Int((token-0x31002000)/0x100)
                if index < 6 {
                    return try initial.snapshot.match.globals.integer(at:0x44f040-0x44d000+slot*4,as:UInt32.self)
                }
                return Self.musicBase+UInt32(slot)*0x100
            }
            return token == 0x31011020 ? Self.musicBuffer : token
        }
        var arguments = try source.arguments.map(translated),strings = source.strings
        var response = OriginalMusicResponse(result:source.response.result,pointer:try source.response.pointer.map(translated),bytes:source.response.bytes)
        let wide = (Self.path+[0]).flatMap { [$0,UInt8(0)] }
        if index == 0 || index == 13 { strings = [Self.path] }
        if index == 11 { arguments[2] = try initial.snapshot.match.globals.integer(at:0x4546f4-0x44d000,as:UInt32.self) }
        let directory = Array(initial.snapshot.match.globals.bytes[(0x44ef38-0x44d000)...].prefix { $0 != 0 })
        let log = directory+Array("\\graph.log".utf8)
        if index == 14 { arguments = [UInt32(log.count)];strings[1] = log }
        if index == 15 { strings = [log] }
        if source.kind == .allocate {
            arguments = [30];response = .init(pointer:Self.musicBuffer,bytes:[UInt8](repeating:0xa5,count:30))
        }
        if source.kind == .convert {
            arguments[4] = 15;strings = [Self.path];response = .init(result:15,bytes:wide)
        }
        if index == 19 { strings = [wide] }
        XCTAssertEqual(request,.init(source.kind,arguments,strings),"whole launch music request \(index)")
        return response
    }

    func replay(_ actual: OriginalStateRecord,_ state: OriginalMatchPreparation) throws {
        let saved = corpus.cases[4].after.state
        let pointers = try bytes(saved.pointers)
        let address = pointers.prefix(4).enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element)<<($1.offset*8) }
        XCTAssertEqual(address,0x72000020)
        let source = try XCTUnwrap(saved.memory.first)
        let raw = try bytes(source.bytes),mask = try bytes(source.defined)
        XCTAssertEqual(raw.count,0x630e18);XCTAssertTrue(mask.allSatisfy { $0 == 1 })
        // Independently lay out the complete format, validating source first.
        func buffer(_ globals: OriginalStateRecord,_ pool: OriginalStateRecord,_ ids: [UInt32]) throws -> OriginalStateRecord {
            var b = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:0x630e18),defined:[Bool](repeating:true,count:0x630e18))
            func word(_ address: Int) throws -> UInt32 { try globals.integer(at:address-0x44d000,as:UInt32.self) }
            func string(_ address: Int,_ target: Int) throws {
                let start = address-0x44d000
                let text = Array(globals.bytes[start...].prefix { $0 != 0 })+[0]
                XCTAssertTrue(globals.defined[start..<start+text.count].allSatisfy { $0 })
                for (i,v) in text.enumerated() { try b.write(v,at:target+i) }
            }
            for (destination,source) in [(0,0x450c30),(4,0x450b94),(8,0x458428),(12,0x45842c),(0x148,0x451160),
                (0x1a4,0x44d024),(0x744,0x44f620),(0x748,0x44d03c),(0x8c4,0x450bcc),(0x14b4,0x450b90)] {
                try b.write(word(source),at:destination)
            }
            for i in 0..<8 { try string(0x44fcc0+i*11,0x14c+i*11) }
            for (source,target) in [(0x44fd18,0x630bc0),(0x44f900,0x630c24),(0x44f890,0x630db4),(0x44eed0,0x550)] { try string(source,target) }
            for seat in 0..<18 {
                let start = 0x7d8+seat*0x420
                let object = Int(try pool.integer(at:start+0x368,as:UInt32.self))
                var values = try [pool.integer(at:start+0x364,as:UInt32.self),ids[object],UInt32(bitPattern:Int32(pool.integer(at:4+seat,as:Int8.self)))]
                values += try [0x8,0x10,0x14,0x18,0x308,0x354,0x304,0x33c,0x344,0x340].map { try pool.integer(at:start+$0,as:UInt32.self) }
                for (array,v) in values.enumerated() { try b.write(v,at:0x1a8+array*0x48+seat*4) }
            }
            for i in 0..<88 { try b.write(word(0x44d5f8+i*4),at:0x74c+i*4) }
            for i in 0..<3001 { try b.write(globals.integer(at:0x44ff90-0x44d000+i,as:UInt8.self),at:0x8c8+i) }
            for i in 0..<11 { try b.write(word(0x44d324+i*4),at:0x1488+i*4) }
            return b
        }
        XCTAssertTrue(state.loadedObjects == initial.snapshot.match.loadedObjects,"All replay source Object owners retained")
        let ids = try initial.snapshot.match.loadedObjects.map { try $0.header.integer(at:0x6f4,as:UInt32.self) }
        let expectedSource = try buffer(Self.global(corpus.cases[3].after.state,corpus),Self.pool(corpus.cases[3].after.state,corpus),ids)
        try equal(expectedSource,.init(bytes:raw,defined:mask.map { $0 != 0 }),"independent saved replay layout")
        try equal(actual,buffer(expectedGlobals(3),expectedPool(3),ids),"whole owned replay layout")
    }

    /// Direct little-endian BMP projection from immutable file bytes. Does not
    /// call a Core pixel decoder or use its dimensions, palette or pixel offset.
    static func pixels(_ input: OriginalApplicationStartupInputs.Bitmap) throws -> ([UInt8],[Bool],Int,Int) {
        let header = try XCTUnwrap(input.bitmapFileHeader),b = header+input.dib
        func word(_ at: Int,_ count: Int = 4) -> Int { (0..<count).reduce(0) { $0 | Int(b[at+$1]) << ($1*8) } }
        XCTAssertEqual(word(14),40);XCTAssertEqual(word(30),0);XCTAssertEqual(word(26,2),1)
        let width = word(18),height = word(22),bits = word(28,2),offset = word(10),stride = ((width*bits+31)/32)*4
        guard width > 0,height > 0,[8,24].contains(bits),offset+stride*height <= b.count else { throw M.Stop.unexpected("District BMP format") }
        var rgb = [UInt8](repeating:0,count:width*height*3)
        for y in 0..<height { for x in 0..<width {
            let source = offset+(height-1-y)*stride+(bits == 24 ? x*3 : x)
            let color = bits == 24 ? source : 54+Int(b[source])*4,target = (y*width+x)*3
            rgb[target] = b[color+2];rgb[target+1] = b[color+1];rgb[target+2] = b[color]
        } }
        return (rgb,[Bool](repeating:true,count:width*height),width,height)
    }

    func bitmapEvents(_ index: Int,_ path: String,_ input: OriginalApplicationStartupInputs.Bitmap) throws -> [OriginalApplicationCatalogGraphicsComparison.Event] {
        typealias API = OriginalBitmapSurfaceLoading
        typealias Event = OriginalApplicationCatalogGraphicsComparison.Event
        let colors = try Self.pixels(input),width = UInt32(colors.2),height = UInt32(colors.3)
        let image = UInt32(0x74000000+index*16),surface = UInt32(0x74100000+index*16)
        let dc = UInt32(0x74200000+index*16),target = UInt32(0x74300000+index*16)
        var descriptor = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:108),defined:[Bool](repeating:true,count:108))
        for (at,value): (Int,UInt32) in [(0,108),(4,7),(8,height),(12,width),(104,0x40)] { try descriptor.write(value,at:at) }
        var description = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:108),defined:[Bool](repeating:false,count:108))
        try description.write(UInt32(108),at:0);try description.write(UInt32(6),at:4)
        let unknown = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:24),defined:[Bool](repeating:false,count:24))
        var object = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:24),defined:[Bool](repeating:true,count:24))
        let bits = UInt32(input.dib[14]) | UInt32(input.dib[15])<<8
        for (at,value): (Int,UInt32) in [(4,width),(8,height),(12,((width*bits+31)/32)*4),(16,1 | bits<<16)] { try object.write(value,at:at) }
        let device = try initial.snapshot.match.globals.integer(at:0x457578-0x44d000,as:UInt32.self)
        let pairs: [(API.Request,API.Response)] = [
            (.init("module",[0]),.init(result:0x400000)),
            (.init("image",[0x400000,0,0,0,0x2010],strings:[Array(path.utf8)]),.init(result:Int32(bitPattern:image))),
            (.init("getObject",[image,24],structure:unknown),.init(result:24,writes:[.init(bytes:object.bytes)])),
            (.init("createSurface",[device,0],structure:descriptor),.init(output:surface)),
            (.init("restore",[surface]),.init()),(.init("createDC",[0]),.init(result:Int32(bitPattern:dc))),
            (.init("selectObject",[dc,image]),.init(result:1)),
            (.init("getObject",[image,24],structure:unknown),.init(result:24,writes:[.init(bytes:object.bytes)])),
            (.init("description",[surface],structure:description),.init(writes:[.init(bytes:descriptor.bytes)])),
            (.init("getDC",[surface]),.init(output:target)),
            (.init("stretch",[target,0,0,width,height,dc,0,0,width,height,0xcc0020]),.init(result:1)),
            (.init("releaseDC",[surface,target]),.init()),(.init("deleteDC",[dc]),.init(result:1)),
            (.init("deleteObject",[image]),.init(result:1)),
            (.init("colorKey",[surface,8],strings:[[UInt8](repeating:0,count:8)]),.init())]
        return pairs.map { Event(request:$0.0,response:$0.1,kind:nil,event:nil) }
    }
}
