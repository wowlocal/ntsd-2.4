import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalLibWorldContactsTests: XCTestCase {
    private struct Patch: Decodable {
        let offset: Int,bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();offset = try c.decode(Int.self);bytes = try c.decode(String.self) }
    }
    private struct Actor: Decodable {
        let index: Int,patches: [Patch]
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();index = try c.decode(Int.self);patches = try c.decode([Patch].self) }
    }
    private struct Frame: Decodable {
        let object: Int,index: Int,offset: Int,bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();object = try c.decode(Int.self);index = try c.decode(Int.self);offset = try c.decode(Int.self);bytes = try c.decode(String.self) }
    }
    private struct Header: Decodable {
        let object: Int,offset: Int,bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();object = try c.decode(Int.self);offset = try c.decode(Int.self);bytes = try c.decode(String.self) }
    }
    private struct Boxes: Decodable {
        let object: Int,frame: Int,interactions: [[Int32]],bodies: [[Int32]]
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();object = try c.decode(Int.self);frame = try c.decode(Int.self);interactions = try c.decode([[Int32]].self);bodies = try c.decode([[Int32]].self) }
    }
    private struct Event: Decodable,Equatable { let kind: String,arguments: [UInt32] }
    private struct Case: Decodable {
        let label: String,fill: String,poolSHA256: String,maskSHA256: String,globalsSHA256: String
        let actors: [Actor]?,active: [[Int]]?,aliases: [[Int]]?,frames: [Frame]?,headers: [Header]?,globals: [Patch]?,events: [Event],boxes: [Boxes]?,entry: Int?,mode: Int32?,pair: [Int]?,count: Int32?,result: UInt32?
    }
    private struct Corpus: Decodable { let exeSHA256: String,libSHA256: String,header: [Patch],baseActor: [Patch],states: [String:Int32],ids: [Int32],cases: [Case],fpcw: Int }
    private func patch(_ record: inout OriginalStateRecord,_ offset: Int,_ hex: String) throws {
        let bytes = Array(hex.utf8);XCTAssertEqual(bytes.count%2,0)
        for i in stride(from: 0,to: bytes.count,by: 2) { try record.write(XCTUnwrap(UInt8(String(decoding: bytes[i..<i+2],as: UTF8.self),radix: 16)),at: offset+i/2) }
    }
    func testWholeCollectionAndRealHelpers() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_LIB_WORLD_CONTACTS_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-lib-world-contacts",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 160_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c");XCTAssertEqual(c.fpcw,0x37f)
        XCTAssertEqual(c.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba");XCTAssertEqual(c.ids,[2,7,8,51]);XCTAssertEqual(c.cases.count,10661)
        func defined(_ size: Int) throws -> OriginalStateRecord { try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size)) }
        var headers: [OriginalStateRecord] = [],frames: [[OriginalStateRecord]] = []
        for id in c.ids {
            var h = try defined(0x7a4)
            for p in c.header { try patch(&h,p.offset,p.bytes) }
            try h.write(id,at: 0x6f4);try h.write(Int32(0),at: 0x6f8);headers.append(h)
            frames.append(try (0..<400).map { n in
                var f = try defined(0x178);try f.write(UInt8(1),at: 0);try f.write(c.states[String(n)] ?? 3,at: 8)
                if [60,65,80,85,90].contains(n) { try f.write(Int32(100),at: 0x4c) };return f
            })
        }
        var globalsBase = try defined(OriginalMatchPreparation.globalSize)
        try globalsBase.write(Int32(1),at: 0x44d034-0x44d000)
        for i in 0..<3000 { try globalsBase.write(UInt8(1+i%255),at: 0x44ff90-0x44d000+i) }
        for item in c.cases {
            var template = try OriginalStateRecord.actor(over: (0..<0x420).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            for p in c.baseActor { try patch(&template,p.offset,p.bytes) }
            var actors = [OriginalStateRecord](repeating: template,count: 400)
            var world = try OriginalStateRecord.worldPrefix(over: (0..<0x7d8).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            let aliases = Dictionary(uniqueKeysWithValues: (item.aliases ?? []).map { ($0[0],$0[1]) })
            let active = Dictionary(uniqueKeysWithValues: (item.active ?? []).map { ($0[0],$0[1]) })
            for i in 0..<400 {
                try world.write(UInt32(aliases[i] ?? i),at: 0x194+i*4);try world.write(UInt8(active[i] ?? 0),at: 4+i);try actors[i].write(UInt32(0),at: 0x368)
            };try world.write(UInt32(0),at: 0x7d4)
            for a in item.actors ?? [] { for p in a.patches { try patch(&actors[a.index],p.offset,p.bytes) } }
            var ownFrames = frames,ownHeaders = headers,globals = globalsBase,events: [Event] = []
            var allocations: [OriginalFrameAllocation] = [],cursor: UInt32 = 0x51000000
            for object in c.ids.indices {
                for boxes in item.boxes ?? [] where boxes.object == object {
                    for (values,countOffset,pointerOffset,boundsOffset,stride,kind): ([[Int32]],Int,Int,Int,Int,OriginalFrameAllocationKind) in
                        [(boxes.interactions,0x128,0x130,0x138,20,.interactions),(boxes.bodies,0x12c,0x134,0x148,10,.bodies)] {
                        try ownFrames[object][boxes.frame].write(Int32(values.count),at: countOffset)
                        guard let first = values.first else { continue }
                        var record = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 5*stride*4),defined: [Bool](repeating: false,count: 5*stride*4))
                        for (n,box) in values.enumerated() { for (word,value) in box.enumerated() { try record.write(value,at: (n*stride+word)*4) } }
                        allocations.append(.init(address: cursor,kind: kind,storage: record))
                        try ownFrames[object][boxes.frame].write(cursor,at: pointerOffset);cursor += UInt32(record.bytes.count)
                        var x = first[1],y = first[2],right = first[1] &+ first[3],bottom = first[2] &+ first[4]
                        for box in values.dropFirst() { x = min(x,box[1]);y = min(y,box[2]);right = max(right,box[1] &+ box[3]);bottom = max(bottom,box[2] &+ box[4]) }
                        for (n,v) in [x,y,right &- x,bottom &- y].enumerated() { try ownFrames[object][boxes.frame].write(v,at: boundsOffset+n*4) }
                    }
                }
            }
            for p in item.frames ?? [] { try patch(&ownFrames[p.object][p.index],p.offset,p.bytes) }
            for p in item.headers ?? [] { try patch(&ownHeaders[p.object],p.offset,p.bytes) }
            for p in item.globals ?? [] { try patch(&globals,p.offset-0x44d000,p.bytes) }
            let memory = OriginalContactFrameMemory(allocations)
            var pass = OriginalContactPass(world: world,actors: actors,globals: globals,objectCount: item.count ?? 4,
                header: { ownHeaders[$0] },frame: { ownFrames[$0][Int($1)] },heapWord: { try memory.word($0) },bundledLibrary: true)
            func observe(_ event: OriginalWorldContactsEvent) throws {
                switch event {
                case let .random(attacker,defender,stream,range,result): events.append(.init(kind: "random",arguments: [UInt32(attacker),UInt32(defender)]+[stream,range,result].map(UInt32.init(bitPattern:))))
                case let .reconstruct(slot,created): events.append(.init(kind: "reconstruct",arguments: [UInt32(slot),UInt32(created)]))
                }
            }
            do {
                switch item.entry ?? 0x419380 {
                case 0x41eed8: try OriginalLibWorldContacts.apply(world: &pass.world,actors: &pass.actors,globals: &pass.globals,objectCount: item.count ?? 4,header: { ownHeaders[$0] },frame: { ownFrames[$0][Int($1)] },heapWord: { try memory.word($0) },observe: observe)
                case 0x419380: try pass.collect(mode: item.mode ?? 0,observe: observe)
                case 0x4064d0: try pass.fusion(observe: observe)
                case 0x417400: let pair = item.pair ?? [0,1];try pass.pair(pair[0],pair[1],mode: item.mode ?? 0,observe: observe)
                case 0x417200: let pair = item.pair ?? [0,1];XCTAssertEqual(try pass.broadphase(pair[0],pair[1]) ? 1 : 0,item.result,item.label)
                default: XCTFail("Unknown source entry");return
                }
            } catch { XCTFail(item.label+": \(error)");throw error }
            world = pass.world;actors = pass.actors;globals = pass.globals
            let records = [world]+actors
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap(\.bytes))),item.poolSHA256,item.label+" pool")
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap { $0.defined.map { $0 ? UInt8(1) : UInt8(0) } })),item.maskSHA256,item.label+" masks")
            XCTAssertEqual(MatchPreparationReference.digest(Data(globals.bytes)),item.globalsSHA256,item.label+" globals")
            XCTAssertTrue(globals.defined.allSatisfy { $0 });XCTAssertEqual(events,item.events,item.label+" events")
        }
        print("LIB WORLD CONTACTS",c.cases.count,"whole pools compared")
    }
    func testWholeCallerRollsBackAfterLibraryKind80AndActualTieRandom() throws {
        try verifyRollback(kind: 80,undefinedCategory: false)
    }
    func testKind802RequiresItsOtherwiseUnfilteredCategoryAndRollsBack() throws {
        try verifyRollback(kind: 802,undefinedCategory: true)
    }
    private func verifyRollback(kind: Int32,undefinedCategory: Bool) throws {
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5,count: 0x7d8),actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5,count: 0x420),count: 400),selector: 2)
        var world = bootstrap.world,actors = bootstrap.actors
        func defined(_ size: Int) throws -> OriginalStateRecord { try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size)) }
        var globals = try defined(0xb440),header = try defined(0x7a4),frame = try defined(0x178),boxes = try defined(120)
        try header.write(Int32(2),at: 0x6f4)
        for slot in 0..<400 { try actors[slot].write(UInt32(0),at: 0x368);try world.write(UInt8(slot < 2 ? 1 : 0),at: 4+slot) }
        for slot in 0..<2 {
            try actors[slot].write(Int32(0),at: 8);try actors[slot].write(Int32(123),at: 0x7c)
            try actors[slot].write(Int32(0),at: 0x2e8);try actors[slot].write(Int32(slot+1),at: 0x364)
        }
        for n in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+n) }
        try frame.write(Int32(1),at: 0x128);try frame.write(Int32(1),at: 0x12c)
        try frame.write(UInt32(0x51000000),at: 0x130);try frame.write(UInt32(0x51000050),at: 0x134)
        for base in [0x138,0x148] { for (n,v): (Int,Int32) in [-20,-20,40,40].enumerated() { try frame.write(v,at: base+n*4) } }
        for base in [0,80] { for (n,v): (Int,Int32) in [-20,-20,40,40].enumerated() { try boxes.write(v,at: base+4+n*4) } }
        try boxes.write(kind,at: 0)
        if undefinedCategory {
            var mask = header.defined;for index in 0x6f8..<0x6fc { mask[index] = false }
            header = try .init(bytes: header.bytes,defined: mask)
        }
        let memory = OriginalContactFrameMemory([.init(address: 0x51000000,kind: .interactions,storage: boxes)])
        let beforeWorld = world,beforeActors = actors,beforeGlobals = globals
        var seen: [OriginalWorldContactsEvent] = []
        XCTAssertThrowsError(try OriginalLibWorldContacts.apply(world: &world,actors: &actors,globals: &globals,objectCount: 1,header: { _ in header },frame: { _,_ in frame },heapWord: { try memory.word($0) },observe: { event in
            seen.append(event);throw OriginalStateError.invalidStorage("Stop after tie RNG")
        }))
        XCTAssertEqual(seen,undefinedCategory ? [] : [.random(attacker: 0,defender: 1,stream: 133,range: 2,result: 0)])
        XCTAssertEqual(world,beforeWorld);XCTAssertEqual(actors,beforeActors);XCTAssertEqual(globals,beforeGlobals)
    }
}
