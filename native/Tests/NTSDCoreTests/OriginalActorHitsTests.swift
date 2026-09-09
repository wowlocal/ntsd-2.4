import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalActorHitsTests: XCTestCase {
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
        let crtAfter: UInt32,crtSeed: UInt32?,attacker: Int?,sse2: Int?
        let caller: Bool?,retainedSpawnSlot: Int32?,background: [Patch]?
        let actors: [Actor]?,active: [[Int]]?,aliases: [[Int]]?,frames: [Frame]?,headers: [Header]?,globals: [Patch]?,events: [Event],boxes: [Boxes]?,entry: Int?,mode: Int32?,pair: [Int]?,count: Int32?,result: UInt32?
    }
    private struct Corpus: Decodable { let exeSHA256: String,header: [Patch],baseActor: [Patch],states: [String:Int32],ids: [Int32],cases: [Case],fpcw: Int }
    private func patch(_ record: inout OriginalStateRecord,_ offset: Int,_ hex: String) throws {
        let bytes = Array(hex.utf8);XCTAssertEqual(bytes.count%2,0)
        for i in stride(from: 0,to: bytes.count,by: 2) { try record.write(XCTUnwrap(UInt8(String(decoding: bytes[i..<i+2],as: UTF8.self),radix: 16)),at: offset+i/2) }
    }
    func testWholeResolutionAndRealHelpers() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_WORLD_HITS_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-world-hits",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 64_000_000))
        XCTAssertEqual(c.fpcw,0x37f)
        try compare(c)
    }
    func testWholePassAtStartupPrecision() throws {
        let url: URL
        if let directory = ProcessInfo.processInfo.environment["NTSD_PRECISION_DIRECTORY"] {
            url = URL(fileURLWithPath: directory).appendingPathComponent("world-hits53.json")
        } else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-world-hits53",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 64_000_000))
        XCTAssertEqual(c.fpcw,0x27f)
        try compare(c)
    }
    private func compare(_ c: Corpus) throws {
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.ids,[2,7,8,51]);XCTAssertEqual(c.cases.count,7845)
        XCTAssertEqual(c.cases.filter { $0.caller == true }.count,150)
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
            var pass = OriginalHitPass(world: world,actors: actors,globals: globals,memory: OriginalContactFrameMemory(allocations),
                crt: OriginalCRTRandom(state: item.crtSeed ?? 1),objectCount: item.count ?? 4,
                header: { ownHeaders[$0] },frame: { ownFrames[$0][Int($1)] },sse2: (item.sse2 ?? 0) != 0,precision: try OriginalArithmeticPrecision(controlWord: UInt16(c.fpcw)))
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
                } else { try pass.resolve(item.attacker ?? 0,observe: observe) }
            }
            catch { XCTFail(item.label+": \(error)");throw error }
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
        print("WORLD HITS",c.cases.count,"whole pools compared")
    }
}
