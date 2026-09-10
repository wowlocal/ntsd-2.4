import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalLibActorHitsTests: XCTestCase {
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
        let label: String,fill: String,poolSHA256: String,maskSHA256: String,globalsSHA256: String,heapSHA256: String
        let fpcw: Int,libraryBefore: String,libraryAfter: String,libraryPatches: [Patch]?,retainLibrary: Bool?
        let crtAfter: UInt32,crtSeed: UInt32?,attacker: Int?,sse2: Int?
        let caller: Bool?,retainedSpawnSlot: Int32?,background: [Patch]?
        let actors: [Actor]?,active: [[Int]]?,aliases: [[Int]]?,frames: [Frame]?,headers: [Header]?,globals: [Patch]?,events: [Event],boxes: [Boxes]?,entry: Int?,mode: Int32?,pair: [Int]?,count: Int32?,result: UInt32?
    }
    private struct Corpus: Decodable { let exeSHA256: String,libSHA256: String,header: [Patch],baseActor: [Patch],states: [String:Int32],ids: [Int32],cases: [Case] }
    private func patch(_ record: inout OriginalStateRecord,_ offset: Int,_ hex: String) throws {
        let bytes = Array(hex.utf8);XCTAssertEqual(bytes.count%2,0)
        for i in stride(from: 0,to: bytes.count,by: 2) { try record.write(XCTUnwrap(UInt8(String(decoding: bytes[i..<i+2],as: UTF8.self),radix: 16)),at: offset+i/2) }
    }
    func testWholeResolutionAndRealHelpers() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_LIB_WORLD_HITS_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-lib-world-hits",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 400_000_000))
        try compare(c)
    }
    private func compare(_ c: Corpus) throws {
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba");XCTAssertEqual(c.ids,[2,7,8,51]);XCTAssertEqual(c.cases.count,18137)
        XCTAssertEqual(c.cases.filter { $0.caller == true }.count,300)
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
        var libraryState = OriginalLibHitState()
        for item in c.cases {
            if item.retainLibrary != true { libraryState = OriginalLibHitState() }
            for p in item.libraryPatches ?? [] { try patch(&libraryState.targets,p.offset,p.bytes) }
            XCTAssertEqual(MatchPreparationReference.digest(Data(libraryState.targets.bytes)),item.libraryBefore,item.label+" library input")
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
            var pass = OriginalHitPass(world: world,actors: actors,globals: globals,memory: OriginalContactFrameMemory(allocations),
                crt: OriginalCRTRandom(state: item.crtSeed ?? 1),objectCount: item.count ?? 4,
                header: { ownHeaders[$0] },frame: { ownFrames[$0][Int($1)] },sse2: (item.sse2 ?? 0) != 0,precision: try OriginalArithmeticPrecision(controlWord: UInt16(item.fpcw)),library: libraryState)
            func observe(_ event: OriginalHitEvent) throws {
                switch event {
                case let .random(stream,range,result): events.append(.init(kind: "random",arguments: [stream,range,result].map(UInt32.init(bitPattern:))))
                case let .builtinSound(x,index): events.append(.init(kind: "builtinSound",arguments: [x,index].map(UInt32.init(bitPattern:))))
                case let .catalogSound(x,index): events.append(.init(kind: "catalogSound",arguments: [x,index].map(UInt32.init(bitPattern:))))
                case let .crtRandom(before,after,result): events.append(.init(kind: "crtRandom",arguments: [before,after,result]))
                case let .reconstruct(slot): events.append(.init(kind: "reconstruct",arguments: [UInt32(slot)]))
                }
            }
            do {
                if item.caller == true {
                    var bg = try defined(0x990)
                    for p in item.background ?? [] { try patch(&bg,p.offset,p.bytes) }
                    try pass.advance(retainedSpawnSlot: item.retainedSpawnSlot,background: { n in XCTAssertEqual(n,0);return bg },observe: observe)
                } else {
                    var allocations = pass.memory.allocations,crt = pass.crt,library = libraryState
                    try OriginalLibActorHits.apply(slot: item.attacker ?? 0,world: &pass.world,actors: &pass.actors,globals: &pass.globals,
                        allocations: &allocations,crt: &crt,library: &library,objectCount: item.count ?? 4,
                        header: { ownHeaders[$0] },frame: { ownFrames[$0][Int($1)] },sse2: (item.sse2 ?? 0) != 0,
                        precision: try OriginalArithmeticPrecision(controlWord: UInt16(item.fpcw)),observe: observe)
                    pass.memory = OriginalContactFrameMemory(allocations);pass.crt = crt;pass.library = library
                }
            }
            catch { XCTFail(item.label+": \(error)");throw error }
            libraryState = try XCTUnwrap(pass.library)
            XCTAssertEqual(MatchPreparationReference.digest(Data(libraryState.targets.bytes)),item.libraryAfter,item.label+" library output")
            XCTAssertTrue(libraryState.targets.defined.allSatisfy { $0 })
            world = pass.world;actors = pass.actors;globals = pass.globals
            var heap = [UInt8](repeating: 0,count: 0x40000)
            for allocation in pass.memory.allocations {
                let offset = Int(allocation.address-0x51000000)
                heap.replaceSubrange(offset..<(offset+allocation.storage.bytes.count),with: allocation.storage.bytes)
            }
            XCTAssertEqual(MatchPreparationReference.digest(Data(heap)),item.heapSHA256,item.label+" heap")
            XCTAssertEqual(pass.crt.state,item.crtAfter,item.label+" CRT state")
            let records = [world]+actors
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap(\.bytes))),item.poolSHA256,item.label+" pool")
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap { $0.defined.map { $0 ? UInt8(1) : UInt8(0) } })),item.maskSHA256,item.label+" masks")
            XCTAssertEqual(MatchPreparationReference.digest(Data(globals.bytes)),item.globalsSHA256,item.label+" globals")
            XCTAssertTrue(globals.defined.allSatisfy { $0 });XCTAssertEqual(events,item.events,item.label+" events")
        }
        print("LIB WORLD HITS",c.cases.count,"whole pools compared")
    }

    private struct Trial {
        var world: OriginalStateRecord,actors: [OriginalStateRecord],globals: OriginalStateRecord
        var allocations: [OriginalFrameAllocation],crt: OriginalCRTRandom,library: OriginalLibHitState
        var header: OriginalStateRecord,frame: OriginalStateRecord
    }
    private func trial(twoContacts: Bool) throws -> Trial {
        func zero(_ size: Int) throws -> OriginalStateRecord {
            try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
        }
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5,count: 0x7d8),
            actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5,count: 0x420),count: 400),selector: 2)
        var world = bootstrap.world,actors = bootstrap.actors,globals = try zero(0xb440)
        var header = try zero(0x7a4),frame = try zero(0x178),heap = try zero(200)
        try header.write(Int32(2),at: 0x6f4);try frame.write(Int32(3),at: 8)
        try frame.write(Int32(2),at: 0x128);try frame.write(Int32(1),at: 0x12c)
        try frame.write(UInt32(0x51000000),at: 0x130);try frame.write(UInt32(0x510000a0),at: 0x134)
        for n in 0..<400 {
            try world.write(UInt32(n),at: 0x194+n*4);try world.write(UInt8(n<3 ? 1 : 0),at: 4+n)
            try actors[n].write(UInt32(0),at: 0x368);try actors[n].write(Int32(20),at: 0x31c)
        }
        try world.write(UInt32(0),at: 0x7d4)
        for n in 0..<3 { try actors[n].write(Int32(0),at: 8);try actors[n].write(Int32(n+1),at: 0x364) }
        try actors[0].write(Int32(twoContacts ? 2 : 1),at: 0x2e4)
        try actors[0].write(Int32(1),at: 0x280);try actors[0].write(Int32(2),at: 0x284)
        try actors[0].write(UInt8(0),at: 0x2d0);try actors[0].write(UInt8(1),at: 0x2d1)
        if !twoContacts { try actors[1].write(Int32(188),at: 0x78) }
        for start in [0,80] {
            try heap.write(Int32(3),at: start+0x14);try heap.write(Int32(-2),at: start+0x18)
            try heap.write(Int32(60),at: start+0x1c);try heap.write(Int32(1),at: start+0x24)
            try heap.write(Int32(40),at: start+0x40);try heap.write(Int32(40),at: start+0x44)
        }
        if twoContacts { try heap.write(Int32(824),at: 0);try heap.write(Int32(41),at: 0x14) }
        else { try heap.write(Int32(6067),at: 0x2c) }
        for n in 0..<3000 { try globals.write(UInt8(1),at: 0x44ff90-0x44d000+n) }
        var library = OriginalLibHitState();try library.targets.write(UInt32(777),at: 0)
        return .init(world: world,actors: actors,globals: globals,
            allocations: [.init(address: 0x51000000,kind: .interactions,storage: heap)],
            crt: OriginalCRTRandom(state: 1),library: library,header: header,frame: frame)
    }
    func testLateSoundRollsBackEarlierTargetBindingAndFrameChange() throws {
        enum Stop: Error { case afterBinding }
        var t = try trial(twoContacts: true);let before = t,header = t.header,frame = t.frame
        var events: [OriginalHitEvent] = []
        XCTAssertThrowsError(try OriginalLibActorHits.apply(slot: 0,world: &t.world,actors: &t.actors,globals: &t.globals,
            allocations: &t.allocations,crt: &t.crt,library: &t.library,objectCount: 1,
            header: { _ in header },frame: { _,_ in frame },observe: { event in
                events.append(event);throw Stop.afterBinding
            })) { error in XCTAssertTrue(error is Stop) }
        XCTAssertEqual(events,[.builtinSound(x: 0,index: 0)])
        XCTAssertEqual(t.world,before.world);XCTAssertEqual(t.actors,before.actors);XCTAssertEqual(t.globals,before.globals)
        XCTAssertEqual(t.allocations,before.allocations);XCTAssertEqual(t.crt.state,before.crt.state);XCTAssertEqual(t.library,before.library)
    }
    func testUnknownStrideByteRejectsAfterDamageAndRollsBack() throws {
        var t = try trial(twoContacts: false);let before = t,header = t.header,frame = t.frame
        var mask = frame.defined;mask[8] = false
        let unknown = try OriginalStateRecord(bytes: frame.bytes,defined: mask)
        var sawStrideFrame = false
        XCTAssertThrowsError(try OriginalLibActorHits.apply(slot: 0,world: &t.world,actors: &t.actors,globals: &t.globals,
            allocations: &t.allocations,crt: &t.crt,library: &t.library,objectCount: 1,
            header: { _ in header },frame: { _,n in
                if n == 89 { sawStrideFrame = true;return unknown };return frame
            })) { error in
                guard case OriginalStateError.undefinedBytes(offset: 8,count: 1) = error else { return XCTFail("Unexpected error: \(error)") }
            }
        XCTAssertTrue(sawStrideFrame)
        XCTAssertEqual(t.world,before.world);XCTAssertEqual(t.actors,before.actors);XCTAssertEqual(t.globals,before.globals)
        XCTAssertEqual(t.allocations,before.allocations);XCTAssertEqual(t.crt.state,before.crt.state);XCTAssertEqual(t.library,before.library)
    }
}
