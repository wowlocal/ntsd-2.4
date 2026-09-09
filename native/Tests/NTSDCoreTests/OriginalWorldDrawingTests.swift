import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalWorldDrawingTests: XCTestCase {
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
    private struct Case: Decodable {
        let label: String,fill: String,poolSHA256: String,maskSHA256: String,globalsSHA256: String,backgroundsSHA256: String,backgroundMasksSHA256: String
        let mode: Int32?,phase: Int32?,width: Int32?,arena: Int?,target: UInt32?
        let actors: [Actor]?,active: [[Int]]?,aliases: [[Int]]?,frames: [Frame]?,headers: [Header]?,globals: [Patch]?,background: [Patch]?
        let bitmaps: [Header]?,undefinedBitmap: [[Int]]?,undefinedBackground: [[Int]]?,events: [OriginalFrontScreenEvent],bounds: [Int32]?,drawOrder: [Int]
    }
    private struct Corpus: Decodable {
        let exeSHA256: String,header: [Patch],drawHeader: [Patch],baseActor: [Patch],states: [String:Int32],ids: [Int32],cases: [Case],fpcw: Int
        let bitmapBase: UInt32,drawTarget: UInt32,fillTarget: UInt32,resources: [String:Int]
    }
    private func bytes(_ hex: String) throws -> [UInt8] {
        let chars = Array(hex.utf8);XCTAssertEqual(chars.count%2,0)
        return try stride(from: 0,to: chars.count,by: 2).map { try XCTUnwrap(UInt8(String(decoding: chars[$0..<$0+2],as: UTF8.self),radix: 16)) }
    }
    private func patch(_ record: inout OriginalStateRecord,_ offset: Int,_ hex: String) throws {
        for (i,b) in try bytes(hex).enumerated() { try record.write(b,at: offset+i) }
    }
    private func defined(_ size: Int) throws -> OriginalStateRecord { try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size)) }
    func testEntireWorldDrawingWithRealChildren() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_WORLD_DRAWING_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-world-drawing",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 128_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c");XCTAssertEqual(c.fpcw,0x37f)
        XCTAssertEqual(c.ids,[2,122,123,10]);XCTAssertEqual(c.cases.count,2679)
        var headers: [OriginalStateRecord] = [],frames: [[OriginalStateRecord]] = []
        for (i,id) in c.ids.enumerated() {
            var h = try defined(0x7a4)
            for p in c.header+c.drawHeader { try patch(&h,p.offset,p.bytes) }
            try h.write(id,at: 0x6f4);try h.write(Int32(i == 0 ? 0 : 1),at: 0x6f8);headers.append(h)
            frames.append(try (0..<400).map { n in
                var f = try defined(0x178);try f.write(UInt8(1),at: 0);try f.write(c.states[String(n)] ?? 3,at: 8)
                if [60,65,80,85,90].contains(n) { try f.write(Int32(100),at: 0x4c) };return f
            })
        }
        var globalsBase = try defined(OriginalMatchPreparation.globalSize)
        try globalsBase.write(Int32(1),at: 0x44d034-0x44d000)
        try globalsBase.write(Int32(794),at: 0x44d78c-0x44d000);try globalsBase.write(Int32(550),at: 0x44d790-0x44d000)
        try globalsBase.write(c.fillTarget,at: 0x455608-0x44d000)
        for i in 0..<3000 { try globalsBase.write(UInt8(1+i%255),at: 0x44ff90-0x44d000+i) }
        for slot in 0..<10 { for (n,b) in Array("P\(slot)".utf8).enumerated() { try globalsBase.write(b,at: 0x44fcc0-0x44d000+slot*11+n) } }
        for (address,n) in c.resources { try globalsBase.write(c.bitmapBase+UInt32(n)*0x2000,at: try XCTUnwrap(Int(address))-0x44d000) }
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
            var ownFrames = frames,ownHeaders = headers,globals = globalsBase,events: [OriginalFrontScreenEvent] = [],bg = try defined(0x990)
            let bounds = item.bounds ?? [0,600],arena = item.arena ?? 0
            try bg.write(item.width ?? 1600,at: 0);try bg.write(bounds[0],at: 4);try bg.write(bounds[1],at: 8)
            var backgrounds = [OriginalStateRecord](repeating: bg,count: 101)
            try backgrounds[arena].write(Int32(40),at: 0x14);try backgrounds[arena].write(Int32(20),at: 0x18);try backgrounds[arena].write(UInt32(5),at: 0x98c)
            for p in item.background ?? [] { try patch(&backgrounds[arena],p.offset,p.bytes) }
            var backgroundMask = backgrounds[arena].defined
            for u in item.undefinedBackground ?? [] { for o in u[0]..<u[0]+u[1] { backgroundMask[o] = false } }
            backgrounds[arena] = try .init(bytes: backgrounds[arena].bytes,defined: backgroundMask)
            for p in item.frames ?? [] { try patch(&ownFrames[p.object][p.index],p.offset,p.bytes) }
            for p in item.headers ?? [] { try patch(&ownHeaders[p.object],p.offset,p.bytes) }
            try globals.write(Int32(arena),at: 0x44d024-0x44d000)
            for p in item.globals ?? [] { try patch(&globals,p.offset-0x44d000,p.bytes) }
            var bitmaps: [OriginalStateRecord] = []
            for n in 0..<13 {
                var bitmap = try defined(0x1f50)
                try bitmap.write(UInt32(1),at: 0);try bitmap.write(Int32(120+10*n),at: 4);try bitmap.write(Int32(90+10*n),at: 8);try bitmap.write(Int32(n == 4 ? -1 : 500),at: 0xc)
                for k in 0..<500 { for (offset,value) in [(0x10,k*7),(0x7e0,k*11),(0xfb0,30+n+k%5),(0x1780,40+n+k%7)] { try bitmap.write(Int32(value),at: offset+4*k) } }
                for p in item.bitmaps ?? [] where p.object == n { try patch(&bitmap,p.offset,p.bytes) }
                var mask = bitmap.defined
                for u in item.undefinedBitmap ?? [] where u[0] == n { for o in u[1]..<u[1]+u[2] { mask[o] = false } }
                bitmaps.append(try .init(bytes: bitmap.bytes,defined: mask))
            }
            func binding(_ index: Int) throws -> (OriginalStateRecord,UInt32) {
                guard bitmaps.indices.contains(index) else { throw OriginalStateError.invalidStorage("Test bitmap binding") }
                return (bitmaps[index],c.drawTarget+0x100+UInt32(index)*16)
            }
            do {
                try OriginalWorldDrawing.draw(world: world,actors: &actors,globals: globals,backgrounds: backgrounds,
                    target: item.target ?? c.drawTarget,phase: item.phase ?? 0,header: { ownHeaders[$0] },frame: { ownFrames[$0][Int($1)] },
                    catalogBitmap: { try binding(Int($0)-1) },resourceBitmap: { token in
                        guard token >= c.bitmapBase,(token-c.bitmapBase)%0x2000 == 0 else { throw OriginalStateError.invalidStorage("Test resource token") }
                        return try binding(Int((token-c.bitmapBase)/0x2000))
                    },performBlit: { _ in events.count%2 == 1 ? Int32(bitPattern: 0x80004005) : 0 },observe: { events.append($0) })
            } catch { XCTFail(item.label+": \(error)");throw error }
            let records = [world]+actors
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap(\.bytes))),item.poolSHA256,item.label+" pool")
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap { $0.defined.map { $0 ? UInt8(1) : UInt8(0) } })),item.maskSHA256,item.label+" masks")
            XCTAssertEqual(MatchPreparationReference.digest(Data(globals.bytes)),item.globalsSHA256,item.label+" globals")
            XCTAssertEqual(MatchPreparationReference.digest(Data(backgrounds.flatMap(\.bytes))),item.backgroundsSHA256,item.label+" backgrounds")
            XCTAssertEqual(MatchPreparationReference.digest(Data(backgrounds.flatMap { $0.defined.map { $0 ? UInt8(1) : UInt8(0) } })),item.backgroundMasksSHA256,item.label+" background masks")
            XCTAssertTrue(globals.defined.allSatisfy { $0 })
            XCTAssertEqual(events,item.events,item.label+" events")
        }
        print("WORLD DRAWING",c.cases.count,"whole pools and ordered renderer requests compared")
    }
}
