import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalPostHUDNoticesTests: XCTestCase {
    private struct Patch: Decodable {
        let offset: Int, bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer(); offset = try c.decode(Int.self); bytes = try c.decode(String.self) }
    }
    private struct Actor: Decodable {
        let index: Int, patches: [Patch]
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer(); index = try c.decode(Int.self); patches = try c.decode([Patch].self) }
    }
    private struct BitmapPatch: Decodable {
        let object: Int, offset: Int, bytes: String
        init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer(); object = try c.decode(Int.self); offset = try c.decode(Int.self); bytes = try c.decode(String.self) }
    }
    private struct Format: Decodable { let format: String, arguments: [UInt32], result: Int, bytes: String, localBytes: String, localMask: [UInt8] }
    private struct Case: Decodable {
        let label: String, group: String, fill: String, poolSHA256: String, maskSHA256: String, globalsSHA256: String
        let actors: [Actor]?, active: [[Int]]?, aliases: [[Int]]?, globals: [Patch]?, bitmaps: [BitmapPatch]?, undefinedBitmap: [[Int]]?
        let stackPattern: Int?, dcResult: Int32?, dc: UInt32?, methodResult: Int32?
        let localBytes: String, localMask: [UInt8], fillBacking: [String], formats: [Format], events: [OriginalFrontScreenEvent]
        let endPC: UInt32, esi: UInt32, edi: UInt32, blits: Int
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, dllSHA256: String, cases: [Case], overflows: [Case], fpcw: Int, instructions: [UInt32], formats: [String]
        let bitmapBase: UInt32, drawTarget: UInt32, fillTarget: UInt32, localOffset: Int, localSize: Int, cookieOffset: Int
    }
    private func bytes(_ hex: String) throws -> [UInt8] {
        let chars = Array(hex.utf8)
        return try stride(from: 0, to: chars.count, by: 2).map { try XCTUnwrap(UInt8(String(decoding: chars[$0..<$0+2], as: UTF8.self), radix: 16)) }
    }
    private func patch(_ record: inout OriginalStateRecord, _ offset: Int, _ hex: String) throws {
        for (i, b) in try bytes(hex).enumerated() { try record.write(b, at: offset+i) }
    }
    private func defined(_ size: Int) throws -> OriginalStateRecord { try .init(bytes: [UInt8](repeating: 0, count: size), defined: [Bool](repeating: true, count: size)) }
    private func corpus() throws -> Corpus {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_POSTHUD_NOTICES_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-posthud-notices", withExtension: "json", subdirectory: "Fixtures")) }
        return try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 128_000_000))
    }
    func testWholeCallerWithExplicitSignalingNaNOracleDifferences() throws {
        let c = try corpus()
        XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.dllSHA256, "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        XCTAssertEqual(c.cases.count, 827); XCTAssertEqual(c.overflows.count, 4); XCTAssertEqual(c.instructions.count, 2190)
        XCTAssertEqual(c.fpcw, 0x23f); XCTAssertEqual(c.localOffset, 0x46c); XCTAssertEqual(c.localSize, 0x154); XCTAssertEqual(c.cookieOffset, 0x5c0)
        XCTAssertEqual(c.formats, OriginalPostHUDNotices.formats)
        let labels = Dictionary(uniqueKeysWithValues: c.cases.map { ($0.label, $0) })
        var matched = 0, signaling = 0, totalEvents = 0, oversized = 0
        for item in c.cases+c.overflows {
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
            var globals = try defined(0xb440)
            try globals.write(Int32(1), at: 0x44d034-0x44d000)
            for i in 0..<3000 { try globals.write(UInt8(1+i%255), at: 0x44ff90-0x44d000+i) }
            for p in item.globals ?? [] { try patch(&globals, p.offset-0x44d000, p.bytes) }
            let localBefore = try OriginalStateRecord(bytes: (0..<c.localSize).map {
                (item.stackPattern ?? 0) == 0 ? 0xa5 : UInt8(truncatingIfNeeded: (0x546c+$0)*13+17)
            }, defined: [Bool](repeating: false, count: c.localSize))
            var local = localBefore, events: [OriginalFrontScreenEvent] = [], formatted: [OriginalStateRecord] = []
            var fillIndex = 0, blits = 0
            do {
                try OriginalPostHUDNotices.draw(world: world, actors: actors, globals: globals, local: &local,
                    dcResult: item.dcResult ?? 0, dc: item.dc ?? 0x76543210, fillBacking: {
                        defer { fillIndex += 1 }; return try self.bytes(item.fillBacking[fillIndex])
                    }, resourceBitmap: { token in
                        guard token >= c.bitmapBase, (token-c.bitmapBase)%0x2000 == 0 else { throw OriginalStateError.invalidStorage("Test bitmap token") }
                        let n = Int((token-c.bitmapBase)/0x2000); var bitmap = try self.defined(0x1f50)
                        try bitmap.write(c.drawTarget+0x100+UInt32(n)*16, at: 0)
                        try bitmap.write(Int32(120+10*n), at: 4); try bitmap.write(Int32(90+10*n), at: 8); try bitmap.write(Int32(n == 4 ? -1 : 500), at: 0xc)
                        for k in 0..<500 { for (offset, value) in [(0x10,k*7), (0x7e0,k*11), (0xfb0,30+n+k%5), (0x1780,40+n+k%7)] {
                            try bitmap.write(Int32(value), at: offset+4*k)
                        } }
                        for p in item.bitmaps ?? [] where p.object == n { try self.patch(&bitmap, p.offset, p.bytes) }
                        let surface = try bitmap.integer(at: 0, as: UInt32.self); try bitmap.write(UInt32(surface == 0 ? 0 : 1), at: 0)
                        var mask = bitmap.defined
                        for u in item.undefinedBitmap ?? [] where u[0] == n { for offset in u[1]..<u[1]+u[2] { mask[offset] = false } }
                        return (try .init(bytes: bitmap.bytes, defined: mask), surface)
                    }, performFill: { _ in item.methodResult ?? -2147467259 }, performBlit: { _ in blits += 1; return item.methodResult ?? -2147467259 },
                    observe: { events.append($0) }, observeFormatStorage: { formatted.append($0) })
                guard item.group != "cookie-overwrite" else { XCTFail("Accepted cookie corruption"); return }
            } catch OriginalStateError.invalidStorage(let detail) where detail == "Post-HUD notices: String overwrites caller security cookie" && item.group == "cookie-overwrite" {
                XCTAssertEqual(local, localBefore); XCTAssertTrue(events.isEmpty); oversized += 1; continue
            } catch { XCTFail(item.label+": \(error)"); return }
            let records = [world]+actors
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap(\.bytes))), item.poolSHA256, item.label)
            XCTAssertEqual(MatchPreparationReference.digest(Data(records.flatMap { $0.defined.map { $0 ? UInt8(1) : UInt8(0) } })), item.maskSHA256, item.label)
            XCTAssertEqual(MatchPreparationReference.digest(Data(globals.bytes)), item.globalsSHA256, item.label)
            var expected = item
            if item.group == "coordinates" {
                let parts = item.label.split(separator: "-"); let input = try XCTUnwrap(UInt64(parts[1], radix: 16))
                let quiet = OriginalPostHUDNotices.quietLoad(input)
                if quiet != input {
                    // Keep the actual mismatching source record unchanged.
                    // Compare the remainder to an independently executed QNaN
                    // companion, justified separately by Intel and the x87 probe.
                    let h = String(quiet, radix: 16)
                    let label = "coordinates-"+String(repeating: "0", count: 16-h.count)+h+"-"+parts.dropFirst(2).joined(separator: "-")
                    expected = try XCTUnwrap(labels[label]); signaling += 1
                    XCTAssertNotEqual(events, item.events, item.label)
                    let words = item.formats[0].arguments, offset = parts[2] == "72" ? 0 : 2
                    XCTAssertEqual(UInt64(words[offset]) | UInt64(words[offset+1]) << 32, input)
                } else { matched += 1 }
            } else { matched += 1 }
            guard events == expected.events else {
                XCTFail(item.label+": events differ from "+expected.label)
                if let difference = zip(events, expected.events).enumerated().first(where: { $0.element.0 != $0.element.1 }) { print("NOTICE", difference) }
                return
            }
            XCTAssertEqual(local.bytes, try bytes(expected.localBytes), item.label); XCTAssertEqual(local.defined, expected.localMask.map { $0 != 0 }, item.label)
            XCTAssertEqual(formatted.count, expected.formats.count)
            for (state, source) in zip(formatted, expected.formats) {
                XCTAssertEqual(state.bytes, try bytes(source.localBytes), item.label); XCTAssertEqual(state.defined, source.localMask.map { $0 != 0 }, item.label)
            }
            XCTAssertEqual(item.endPC, 0x421cdc); XCTAssertEqual(blits, item.blits); XCTAssertEqual(fillIndex, item.fillBacking.count)
            let exiting = try globals.integer(at: 0x450c2c-0x44d000, as: Int32.self) == 1
            XCTAssertEqual(item.esi, exiting ? 28 : 0x7817775d); XCTAssertEqual(item.edi, exiting ? 0x1000e489 : 0)
            totalEvents += events.count
        }
        XCTAssertEqual(matched, 819); XCTAssertEqual(signaling, 8); XCTAssertEqual(totalEvents, 19802); XCTAssertEqual(oversized, 4)
        print("POSTHUD NOTICES:", matched, "direct full caller matches;", signaling, "documented sNaN oracle differences with independently executed QNaN companions;", oversized, "cookie-corruption rejections;", totalEvents, "events")
    }

    func testLateBitmapFailureRollsBackCallerStrings() throws {
        let world = try OriginalStateRecord.worldPrefix(over: [UInt8](repeating: 0xa5, count: 0x7d8))
        var globals = try defined(0xb440)
        try globals.write(Int32(1), at: 0x450c2c-0x44d000); try globals.write(UInt32(12), at: 0x455608-0x44d000); try globals.write(UInt32(13), at: 0x44f8f8-0x44d000)
        let before = try OriginalStateRecord(bytes: [UInt8](repeating: 0x69, count: 0x154), defined: [Bool](repeating: false, count: 0x154))
        var local = before, textCount = 0
        XCTAssertThrowsError(try OriginalPostHUDNotices.draw(world: world, actors: [], globals: globals, local: &local,
            dcResult: 0, dc: 14, fillBacking: { XCTFail("Unexpected fill"); return [] },
            resourceBitmap: { _ in throw OriginalStateError.invalidStorage("Late missing bitmap") }, performFill: { _ in 0 }, performBlit: { _ in 0 },
            observe: { if $0.kind == "textOut" { textCount += 1 } }))
        XCTAssertEqual(textCount, 2); XCTAssertEqual(local, before)
    }
}
