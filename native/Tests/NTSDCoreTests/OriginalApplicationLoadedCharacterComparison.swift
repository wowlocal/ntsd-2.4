import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Saved pristine human-screen state transitions projected onto the actual
/// application's entry. Expected records remain comparator-owned values.
/// Library text, live sound owners and declared fill backing are separate
/// explicit projections; this does not assert a new whole-original app trace.
final class OriginalApplicationLoadedCharacterComparison {
    typealias R = CharacterScreenReference
    typealias M = OriginalApplicationLoadedMenuTests
    struct SourceCatalog: Decodable {
        struct Child: Decodable { let kind: String,index: Int?,storage: ModeScreenReference.Storage? }
        struct Bitmap: Decodable { let address: UInt32,path: String,storage: ModeScreenReference.Storage }
        let children: [Child],bitmaps: [Bitmap],blobs: [String:InputControlReference.Blob]
    }
    let corpus: R.Corpus,menu: MenuStartupReference.Corpus,catalog: R.Catalog,sourceCatalog: SourceCatalog
    var blobs: [String:[UInt8]] = [:]
    var points = 0,draws = 0,reads = 0,blits = 0,sounds = 0
    init(_ reverse: Bool,selection: Bool = false) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource:"original-"+name+(reverse ? "-control" : ""),withExtension:"json",subdirectory:"Fixtures"))
            return try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:192_000_000)
        }
        corpus = try JSONDecoder().decode(R.Corpus.self,from:fixture(selection ? "match-selection" : "character-screen"))
        menu = try JSONDecoder().decode(MenuStartupReference.Corpus.self,from:fixture("menu-startup"))
        let data = try fixture("menu-loading-catalog")
        catalog = try JSONDecoder().decode(R.Catalog.self,from:data)
        sourceCatalog = try JSONDecoder().decode(SourceCatalog.self,from:data)
        XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.cases.count,selection ? 50 : 34)
    }
    func catalogInputs(_ own: OriginalMatchPreparation) throws {
        func blob(_ key: String) throws -> [UInt8] {
            let b = try XCTUnwrap(sourceCatalog.blobs[key])
            let value = try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:8_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(value)),key);return value
        }
        let objects = sourceCatalog.children.filter { $0.kind == "object" }
        XCTAssertEqual(objects.count,137);XCTAssertEqual(own.loadedObjects.count,objects.count)
        XCTAssertEqual(own.bitmaps.count,sourceCatalog.bitmaps.count)
        let indices = Dictionary(uniqueKeysWithValues:sourceCatalog.bitmaps.enumerated().map { ($0.element.address,UInt32($0.offset+1)) })
        var portraits = 0
        for child in objects {
            let index = try XCTUnwrap(child.index),storage = try XCTUnwrap(child.storage)
            let raw = try blob(storage.bytes),mask = try blob(storage.defined)
            let record = try OriginalStateRecord(bytes:raw,defined:mask.map { $0 != 0 }),actual = own.loadedObjects[index]
            for offset in [0x6f4,0x6f8] {
                XCTAssertEqual(try actual.header.integer(at:offset,as:UInt32.self),try record.integer(at:offset,as:UInt32.self))
                XCTAssertTrue(actual.header.defined[offset..<offset+4].allSatisfy { $0 })
            }
            if record.defined[0x6fc..<0x700].allSatisfy({ $0 }) {
                let sourcePortrait = try record.integer(at:0x6fc,as:UInt32.self)
                let portrait = try sourcePortrait == 0 ? UInt32(0) : XCTUnwrap(indices[sourcePortrait])
                XCTAssertEqual(try actual.header.integer(at:0x6fc,as:UInt32.self),portrait);portraits += 1
            } else {
                XCTAssertEqual(Array(actual.header.bytes[0x6fc..<0x700]),Array(record.bytes[0x6fc..<0x700]))
                XCTAssertEqual(Array(actual.header.defined[0x6fc..<0x700]),Array(record.defined[0x6fc..<0x700]))
            }
            try equal(actual.nameTail,.init(bytes:Array(raw[0x25324..<0x25360]),defined:Array(mask[0x25324..<0x25360]).map { $0 != 0 }),"catalog name\(index)")
        }
        XCTAssertEqual(portraits,42)
        for i in own.bitmaps.indices {
            let source = sourceCatalog.bitmaps[i]
            XCTAssertEqual(own.bitmaps[i].input.path,source.path)
            var expected = try OriginalStateRecord(bytes:blob(source.storage.bytes),defined:blob(source.storage.defined).map { $0 != 0 })
            let present = try expected.integer(at:0,as:UInt32.self) != 0
            try expected.write(present ? UInt32(1) : 0,at:0)
            try equal(own.bitmaps[i].storage,expected,"catalog bitmap\(i)")
        }
    }
    func bytes(_ key: String) throws -> [UInt8] {
        if let b = blobs[key] { return b }
        let b = try XCTUnwrap(corpus.blobs[key])
        let value = try MatchPreparationReference.inflate(b.deflate,count:b.count,maximumCount:8_000_000)
        XCTAssertEqual(MatchPreparationReference.digest(Data(value)),key);blobs[key] = value;return value
    }
    func pool(_ snapshot: InputControlReference.Snapshot) throws -> OriginalStateRecord {
        var r = try OriginalStateRecord(bytes:bytes(snapshot.poolBytes),defined:bytes(snapshot.poolMask).map { $0 != 0 })
        let actors = Dictionary(uniqueKeysWithValues:corpus.actorAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        let objects = Dictionary(uniqueKeysWithValues:corpus.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
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
    func globals(_ snapshot: InputControlReference.Snapshot) throws -> OriginalStateRecord {
        let b = try bytes(snapshot.globals)
        return try .init(bytes:b,defined:[Bool](repeating:true,count:b.count))
    }
    func equal(_ a: OriginalStateRecord,_ b: OriginalStateRecord,_ label: String) throws {
        guard a.bytes.count == b.bytes.count else { throw M.Stop.unexpected(label+" extent") }
        if let i = a.bytes.indices.first(where:{ a.bytes[$0] != b.bytes[$0] || a.defined[$0] != b.defined[$0] }) {
            throw M.Stop.unexpected(label+" byte"+String(i,radix:16)+" actual \(a.bytes[i])/\(a.defined[i]) expected \(b.bytes[i])/\(b.defined[i])")
        }
    }
    // Equality over the full possible write footprint prevents idempotent
    // source stores from being hidden by a byte-delta comparison.
    func entry(_ own: OriginalMatchPreparation,_ item: R.Case,
               projectedPool: OriginalStateRecord? = nil,projectedGlobals: OriginalStateRecord? = nil) throws {
        let sourcePool = try projectedPool ?? pool(item.screen.before),ownPool = try pool(own)
        let sourceGlobals = try projectedGlobals ?? globals(item.screen.before)
        var poolOffsets = Array(4..<12)+Array(0x194..<(0x194+8*4))
        for i in 0..<400 { poolOffsets += Array((0x7d8+i*0x420+0x364)..<(0x7d8+i*0x420+0x36c)) }
        for i in 0..<8 { poolOffsets += Array((0x7d8+i*0x420+0xcd)..<(0x7d8+i*0x420+0xd4)) }
        for i in poolOffsets {
            guard ownPool.bytes[i] == sourcePool.bytes[i],ownPool.defined[i] == sourcePool.defined[i] else { throw M.Stop.unexpected("Human entry pool footprint "+String(i,radix:16)) }
        }
        let ranges = [0x44d020..<0x44d024,0x44d074..<0x44d07c,0x451224..<0x451228,
                      0x451248..<0x4512a8,0x4512c8..<0x4512cc,0x451160..<0x451164,
                      0x450c2c..<0x450c30,0x458428..<0x45842c,0x450b4c..<0x450b6c]
        for range in ranges { for address in range {
            let i = address-0x44d000
            guard own.globals.bytes[i] == sourceGlobals.bytes[i],own.globals.defined[i] == sourceGlobals.defined[i] else { throw M.Stop.unexpected("Human entry global footprint "+String(address,radix:16)) }
        } }
    }
    func transition(_ actual: OriginalStateRecord,_ own: OriginalStateRecord,_ before: OriginalStateRecord,_ after: OriginalStateRecord,_ label: String) throws {
        guard own.bytes.count == before.bytes.count,after.bytes.count == before.bytes.count else { throw M.Stop.unexpected(label+" transition extent") }
        var bytes = own.bytes,mask = own.defined
        for i in before.bytes.indices where before.bytes[i] != after.bytes[i] || before.defined[i] != after.defined[i] {
            guard own.bytes[i] == before.bytes[i],own.defined[i] == before.defined[i] else { throw M.Stop.unexpected(label+" changed entry "+String(i,radix:16)) }
            bytes[i] = after.bytes[i];mask[i] = after.defined[i]
        }
        try equal(actual,.init(bytes:bytes,defined:mask),label)
    }
    func state(_ actual: OriginalMatchPreparation,_ own: OriginalMatchPreparation,_ before: InputControlReference.Snapshot,_ after: InputControlReference.Snapshot,_ label: String) throws {
        try transition(pool(actual),pool(own),pool(before),pool(after),label+" pool")
        try transition(actual.globals,own.globals,globals(before),globals(after),label+" globals")
        XCTAssertEqual(actual.arithmeticPrecision,own.arithmeticPrecision);XCTAssertEqual(actual.interface.bitmaps,own.interface.bitmaps)
        XCTAssertEqual(actual.releasedBitmaps,own.releasedBitmaps)
        XCTAssertEqual(actual.frameAllocations,own.frameAllocations);XCTAssertEqual(actual.backgrounds,own.backgrounds)
        XCTAssertEqual(actual.bitmaps,own.bitmaps);XCTAssertEqual(actual.releasedBitmapOrder,own.releasedBitmapOrder)
    }
    func checkpoint(_ point: OriginalCharacterScreenCheckpoint,_ state: OriginalMatchPreparation,_ own: OriginalMatchPreparation,_ item: R.Case,_ index: Int) throws {
        let expected = item.screen.checkpoints[index]
        XCTAssertEqual(point.pc,expected.pc)
        if point.pc == 0x42a25a { XCTAssertEqual(point.seat,Int(expected.seat)) }
        XCTAssertEqual(point.locals,expected.locals.reduce(into:[:]) { $0[Int($1.key)!] = $1.value })
        try self.state(state,own,item.screen.before,expected.state,item.label+" point\(index)");points += 1
    }
    func events(_ actual: [OriginalFrontScreenEvent],_ ready: M.S.Input.PendingContinuation,_ item: R.Case,
                sourceEvents: [OriginalFrontScreenEvent]? = nil,
                extraDraws: [UInt32:(UInt32,OriginalStateRecord,UInt32)] = [:],
                confirmationSlot: Int = 0x45560c) throws {
        let model = ready.match,source = sourceEvents ?? item.screen.events,bindings = ready.entry.entry.snapshot
        let target = ready.loading.target,textTarget = try model.globals.integer(at:0x455608-0x44d000,as:UInt32.self)
        var bitmap: OriginalStateRecord?,surface: UInt32 = 0,expected: [OriginalFrontScreenEvent] = []
        for event in source {
            var e = event
            switch e.kind {
            case "draw":
                let token: UInt32
                if let (ownedToken,record,ownedSurface) = extraDraws[e.arguments[0]] {
                    token = ownedToken;bitmap = record;surface = ownedSurface
                } else if let i = menu.resources.allocations.firstIndex(where:{ $0.address == e.arguments[0] }) {
                    token = try model.globals.integer(at:OriginalMenuResourceLoading.slots[i]-0x44d000,as:UInt32.self)
                    bitmap = try XCTUnwrap(ready.state.memory.allocations[token]).storage
                    surface = try bitmap!.integer(at:0,as:UInt32.self)
                } else {
                    let i = try XCTUnwrap(catalog.bitmaps.firstIndex(where:{ $0.address == e.arguments[0] }))
                    token = bindings.bitmapTokens[i];bitmap = model.bitmaps[i].storage
                    surface = try bitmap!.integer(at:0,as:UInt32.self) == 0 ? 0 : bindings.bitmapSurfaces[i]
                }
                e.arguments[0] = token;e.arguments[6] = target;draws += 1
            case "read":
                let read = try XCTUnwrap(e.read),record = try XCTUnwrap(bitmap)
                guard read.offset >= 0,read.offset+4 <= record.bytes.count else { throw M.Stop.unexpected("Source bitmap read extent") }
                let value = read.offset == 0 ? surface : (0..<4).reduce(UInt32(0)) { $0 | UInt32(record.bytes[read.offset+$1]) << (8*$1) }
                e.read = .init(offset:read.offset,value:value,defined:record.defined[read.offset..<read.offset+4].allSatisfy { $0 })
                reads += 1
            case "blit":
                let b = try XCTUnwrap(e.blit)
                e.blit = .init(sourceSurface:surface,targetSurface:target,source:b.source,destination:b.destination,flags:b.flags,effects:b.effects);blits += 1
            case "fill":
                let f = try XCTUnwrap(e.fill)
                var bytes = [UInt8](repeating:0,count:100)
                for i in bytes.indices where f.defined[i] { bytes[i] = f.effects[i] }
                e.fill = .init(target:textTarget,rectangle:f.rectangle,flags:f.flags,effects:bytes,defined:f.defined)
            case "getDC":e.arguments = [textTarget]
            case "setBackgroundColor":e = .init("setBackgroundMode",[0x12345678,1])
            case "setTextColor","textOut":e.arguments[0] = 0x12345678
            case "releaseDC":e.arguments = [textTarget,0x12345678]
            case "soundRequest":
                expected.append(e);sounds += 1
                // Human selection uses45560c; count/arena confirmations use
                //455610 at their independently identified401a30 callsites.
                let token = try model.globals.integer(at:confirmationSlot-0x44d000,as:UInt32.self)
                XCTAssertNotEqual(token,0);XCTAssertNotEqual(try model.globals.integer(at:0x44eecc-0x44d000,as:UInt32.self),0)
                expected += [.init("soundMethod",[token,0x48]),.init("soundMethod",[token,0x34,0]),.init("soundMethod",[token,0x30,0,0,0])]
                continue
            case "musicConfiguration":e.arguments[3] = target
            case "clip","stringLength","candidates","random","format":break
            default:throw M.Stop.unexpected("Unprojected source character event "+e.kind)
            }
            expected.append(e)
        }
        guard actual.count == expected.count else { throw M.Stop.unexpected(item.label+" event count \(actual.count) expected \(expected.count)") }
        for i in expected.indices where actual[i] != expected[i] { throw M.Stop.unexpected(item.label+" event\(i) actual \(actual[i]) expected \(expected[i])") }
    }
}
