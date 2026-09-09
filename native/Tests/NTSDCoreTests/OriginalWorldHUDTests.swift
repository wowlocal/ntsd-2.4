import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalWorldHUDTests: XCTestCase {
    private struct Patch: Decodable {
        let offset: Int,bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();offset = try c.decode(Int.self);bytes = try c.decode(String.self) }
    }
    private struct Actor: Decodable {
        let index: Int,patches: [Patch]
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();index = try c.decode(Int.self);patches = try c.decode([Patch].self) }
    }
    private struct Header: Decodable {
        let object: Int,offset: Int,bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer();object = try c.decode(Int.self);offset = try c.decode(Int.self);bytes = try c.decode(String.self) }
    }
    private struct Access: Decodable, Equatable { let pc: UInt32, offset: Int, size: Int, write: Bool }
    private struct Case: Decodable {
        let label: String, fill: String, poolSHA256: String, maskSHA256: String, globalsSHA256: String
        let actors: [Actor]?, active: [[Int]]?, aliases: [[Int]]?, headers: [Header]?, globals: [Patch]?
        let bitmaps: [Header]?, undefinedBitmap: [[Int]]?, events: [OriginalFrontScreenEvent], methodResults: [Int32]?
        let endPC: UInt32, argumentAccesses: [Access], blits: Int
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, header: [Patch], headerPatches: [Header], ids: [Int32], cases: [Case], fpcw: Int, instructions: [UInt32]
        let bitmapBase: UInt32, drawTarget: UInt32, fillTarget: UInt32, methodResults: [Int32]
    }
    private func bytes(_ hex: String) throws -> [UInt8] {
        let chars = Array(hex.utf8);XCTAssertEqual(chars.count%2,0)
        return try stride(from: 0,to: chars.count,by: 2).map { try XCTUnwrap(UInt8(String(decoding: chars[$0..<$0+2],as: UTF8.self),radix: 16)) }
    }
    private func patch(_ record: inout OriginalStateRecord,_ offset: Int,_ hex: String) throws {
        for (i,b) in try bytes(hex).enumerated() { try record.write(b,at: offset+i) }
    }
    private func defined(_ size: Int) throws -> OriginalStateRecord { try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size)) }
    func testEntireHUDCallerWithOriginalBitmapChildren() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_WORLD_HUD_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-world-hud", withExtension: "json", subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 128_000_000))
        XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.fpcw, 0x27f); XCTAssertEqual(c.cases.count, 1753); XCTAssertEqual(c.instructions.count, 483)
        var headers: [OriginalStateRecord] = []
        for (n, id) in c.ids.enumerated() {
            var h = try defined(0x7a4)
            for p in c.header { try patch(&h, p.offset, p.bytes) }
            try h.write(id, at: 0x6f4); try h.write(Int32(n == 3 ? 3 : 0), at: 0x6f8)
            for p in c.headerPatches where p.object == n { try patch(&h, p.offset, p.bytes) }
            headers.append(h)
        }
        var globalsBase = try defined(OriginalMatchPreparation.globalSize)
        try globalsBase.write(Int32(1), at: 0x44d034-0x44d000)
        for i in 0..<3000 { try globalsBase.write(UInt8(1+i%255), at: 0x44ff90-0x44d000+i) }
        var totalEvents = 0, totalBlits = 0
        for item in c.cases {
            let template = try OriginalStateRecord.actor(over: (0..<0x420).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            var actors = [OriginalStateRecord](repeating: template, count: 400)
            var world = try OriginalStateRecord.worldPrefix(over: (0..<0x7d8).map { item.fill == "a5" ? 0xa5 : UInt8(truncatingIfNeeded: $0) })
            let aliases = Dictionary(uniqueKeysWithValues: (item.aliases ?? []).map { ($0[0], $0[1]) })
            let active = Dictionary(uniqueKeysWithValues: (item.active ?? []).map { ($0[0], $0[1]) })
            for i in 0..<400 {
                try world.write(UInt32(aliases[i] ?? i), at: 0x194+i*4); try world.write(UInt8(active[i] ?? 0), at: 4+i)
                try actors[i].write(UInt32(0), at: 0x368)
            }
            try world.write(UInt32(0), at: 0x7d4)
            for a in item.actors ?? [] { for p in a.patches { try patch(&actors[a.index], p.offset, p.bytes) } }
            var ownHeaders = headers, globals = globalsBase, events: [OriginalFrontScreenEvent] = []
            for p in item.headers ?? [] { try patch(&ownHeaders[p.object], p.offset, p.bytes) }
            for n in ownHeaders.indices {
                let pointer = try ownHeaders[n].integer(at: 0x728, as: UInt32.self)
                if pointer != 0 {
                    guard pointer >= c.bitmapBase, (pointer-c.bitmapBase)%0x2000 == 0, (pointer-c.bitmapBase)/0x2000 < 5 else { return XCTFail("Portrait provenance") }
                    try ownHeaders[n].write((pointer-c.bitmapBase)/0x2000+1, at: 0x728)
                }
            }
            for p in item.globals ?? [] { try patch(&globals, p.offset-0x44d000, p.bytes) }
            var bitmaps: [OriginalStateRecord] = [], surfaces: [UInt32] = []
            for n in 0..<13 {
                var bitmap = try defined(0x1f50)
                try bitmap.write(c.drawTarget+0x100+UInt32(n)*16, at: 0)
                try bitmap.write(Int32(120+10*n), at: 4); try bitmap.write(Int32(90+10*n), at: 8)
                try bitmap.write(Int32(n == 4 ? -1 : 500), at: 0xc)
                for k in 0..<500 { for (offset, value) in [(0x10,k*7), (0x7e0,k*11), (0xfb0,30+n+k%5), (0x1780,40+n+k%7)] {
                    try bitmap.write(Int32(value), at: offset+4*k)
                } }
                for p in item.bitmaps ?? [] where p.object == n { try patch(&bitmap, p.offset, p.bytes) }
                let surface = try bitmap.integer(at: 0, as: UInt32.self); surfaces.append(surface)
                try bitmap.write(UInt32(surface == 0 ? 0 : 1), at: 0)
                var mask = bitmap.defined
                for u in item.undefinedBitmap ?? [] where u[0] == n { for o in u[1]..<u[1]+u[2] { mask[o] = false } }
                bitmaps.append(try .init(bytes: bitmap.bytes, defined: mask))
            }
            func binding(_ n: Int) throws -> (OriginalStateRecord, UInt32) {
                guard bitmaps.indices.contains(n) else { throw OriginalStateError.invalidStorage("Test bitmap binding") }
                return (bitmaps[n], surfaces[n])
            }
            let results = item.methodResults ?? c.methodResults
            var blits = 0
            do {
                try OriginalWorldHUD.draw(world: world, actors: actors, globals: &globals, header: { ownHeaders[$0] },
                    catalogBitmap: { try binding(Int($0)-1) }, resourceBitmap: { token in
                        guard token >= c.bitmapBase, (token-c.bitmapBase)%0x2000 == 0 else { throw OriginalStateError.invalidStorage("Test resource token") }
                        return try binding(Int((token-c.bitmapBase)/0x2000))
                    }, performBlit: { _ in defer { blits += 1 }; return results[blits%results.count] }, observe: { events.append($0) })
            } catch { XCTFail(item.label+": \(error)"); return }
            let records = [world]+actors
            let pool = MatchPreparationReference.digest(Data(records.flatMap(\.bytes)))
            let mask = MatchPreparationReference.digest(Data(records.flatMap { $0.defined.map { $0 ? UInt8(1) : UInt8(0) } }))
            let global = MatchPreparationReference.digest(Data(globals.bytes))
            guard pool == item.poolSHA256, mask == item.maskSHA256, global == item.globalsSHA256, events == item.events else {
                XCTFail("\(item.label): pool=\(pool == item.poolSHA256) mask=\(mask == item.maskSHA256) globals=\(global == item.globalsSHA256) events=\(events == item.events)")
                if let mismatch = zip(events, item.events).enumerated().first(where: { $0.element.0 != $0.element.1 }) {
                    print("HUD first event mismatch", mismatch.offset, mismatch.element)
                }
                return
            }
            XCTAssertTrue(globals.defined.allSatisfy { $0 }); XCTAssertEqual(blits, item.blits, item.label)
            XCTAssertEqual(item.endPC, 0x421a2d)
            XCTAssertEqual(item.argumentAccesses, [.init(pc: 0x421a15, offset: 0x68, size: 4, write: false),
                                                  .init(pc: 0x421a19, offset: -4, size: 4, write: true)])
            totalEvents += events.count; totalBlits += blits
        }
        XCTAssertEqual(totalEvents, 276106); XCTAssertEqual(totalBlits, 39462)
        print("WORLD HUD", c.cases.count, "complete pools,", totalEvents, "events and", totalBlits, "blits compared")
    }

    private func prepared() throws -> (OriginalStateRecord, [OriginalStateRecord], OriginalStateRecord, OriginalStateRecord, OriginalStateRecord) {
        let bootstrap = try OriginalWorldBootstrap(worldBacking: [UInt8](repeating: 0xa5, count: 0x7d8),
            actorBacking: [[UInt8]](repeating: [UInt8](repeating: 0xa5, count: 0x420), count: 400), selector: 2)
        var world = bootstrap.world, globals = try defined(0xb440), header = try defined(0x7a4), bitmap = try defined(0x1f50)
        try world.write(UInt8(1), at: 4); try header.write(UInt32(1), at: 0x728)
        try globals.write(Int32(2), at: 0x450bb8-0x44d000); try globals.write(Int32(1), at: 0x450bc0-0x44d000)
        for (address, value) in [(0x44d78c,794), (0x44d790,550), (0x455608,42), (0x4511a8,100), (0x44fd7c,101), (0x44faf4,102)] {
            try globals.write(Int32(value), at: address-0x44d000)
        }
        for (offset, value) in [(0,1), (4,198), (8,54), (0xc,-1)] { try bitmap.write(Int32(value), at: offset) }
        return (world, bootstrap.actors, globals, header, bitmap)
    }
    func testLaterResourceFailureRestoresCommandFlags() throws {
        let (world, actors, before, header, bitmap) = try prepared()
        var globals = before, interfaces = 0, blits = 0
        XCTAssertThrowsError(try OriginalWorldHUD.draw(world: world, actors: actors, globals: &globals, header: { _ in header },
            catalogBitmap: { _ in (bitmap, 7) }, resourceBitmap: { token in
                if token == 100 { interfaces += 1 }
                if interfaces == 2 { throw OriginalStateError.invalidStorage("Second cell resource") }
                return (bitmap, 7)
            }, performBlit: { _ in blits += 1; return -1 }))
        XCTAssertEqual(interfaces, 2); XCTAssertEqual(blits, 6); XCTAssertEqual(globals, before)
    }
    func testLaterObserverFailureRestoresCommandFlags() throws {
        let (world, actors, before, header, bitmap) = try prepared()
        var globals = before, observed = 0, performed = 0
        XCTAssertThrowsError(try OriginalWorldHUD.draw(world: world, actors: actors, globals: &globals, header: { _ in header },
            catalogBitmap: { _ in (bitmap, 7) }, resourceBitmap: { _ in (bitmap, 7) },
            performBlit: { _ in performed += 1; return 0 }, observe: { event in
                if event.kind == "blit" { observed += 1 }
                if observed == 7 { throw OriginalStateError.invalidStorage("Second cell observer") }
            }))
        XCTAssertEqual(observed, 7); XCTAssertEqual(performed, 6); XCTAssertEqual(globals, before)
    }
}
