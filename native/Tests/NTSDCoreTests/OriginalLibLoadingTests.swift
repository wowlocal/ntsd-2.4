import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalLibLoadingTests: XCTestCase {
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Spec: Decodable {
        let label: String, results: [Int32]?, times: [UInt32]?, chain: Bool?, retainedDC: UInt32?, peek: Int32?, get: Int32?, message: String?
    }
    private struct Case: Decodable {
        let spec: Spec, input: OriginalMenuPresentationInput, globals: String, globalsAfter: String
        let bitmaps: [Storage], events: [OriginalFrontScreenEvent], blits: Int, fillBacking: [String], libraryBefore: String, libraryAfter: String
    }
    private struct Corpus: Decodable { let exeSHA256: String, libSHA256: String, crtSHA256: String, cases: [Case], blobs: [String:Blob] }
    private func hex(_ text: String) -> [UInt8] {
        stride(from: 0,to: text.count,by: 2).map { n in
            let start = text.index(text.startIndex,offsetBy: n);return UInt8(text[start..<text.index(start,offsetBy: 2)],radix: 16)!
        }
    }
    func testWholeLoadingCallerAndHelpers() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_LIB_LOADING_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-lib-loading",withExtension: "json",subdirectory: "Fixtures")) }
        let corpus = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 64_000_000))
        XCTAssertEqual(corpus.cases.count,318)
        XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(corpus.libSHA256,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
        XCTAssertEqual(corpus.crtSHA256,"c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        var cache: [String:[UInt8]] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let v = cache[key] { return v }
            let item = try XCTUnwrap(corpus.blobs[key]),packed = try XCTUnwrap(Data(base64Encoded: item.deflate))
            XCTAssertEqual(Array(packed.prefix(2)),[0x78,0xda])
            let v = try MatchPreparationReference.inflate(Data(packed.dropFirst(2).dropLast(4)).base64EncodedString(),count: item.count)
            XCTAssertEqual(MatchPreparationReference.digest(Data(v)),key);cache[key] = v;return v
        }
        func record(_ key: String) throws -> OriginalStateRecord {
            let b = try blob(key);return try .init(bytes: b,defined: .init(repeating: true,count: b.count))
        }
        var retained: [Int:UInt32] = [:],retainedText = OriginalLibSurfaceText(),totals = 0,rollbacks = 0
        for c in corpus.cases {
            let declared = try record(c.globals)
            var globals = declared,text = OriginalLibSurfaceText(retainedDC: c.spec.retainedDC ?? 0)
            if c.spec.chain == true {
                for (p,value) in retained { try globals.write(value,at: p-0x44d000) }
                text = retainedText;XCTAssertEqual(globals,declared)
            }
            XCTAssertEqual(text.retainedDC,try record(c.libraryBefore).integer(at: 0x306e,as: UInt32.self))
            let initial = globals,initialText = text
            var bitmaps: [OriginalStateRecord] = [],surfaces: [UInt32] = []
            for b in c.bitmaps {
                let raw = try blob(b.bytes),mask = try blob(b.defined)
                let value = try OriginalStateRecord(bytes: raw,defined: mask.map { $0 != 0 }).integer(at: 0,as: UInt32.self)
                var normalized = raw
                for n in 0..<4 { normalized[n] = n == 0 && value != 0 ? 1 : 0 }
                bitmaps.append(try .init(bytes: normalized,defined: mask.map { $0 != 0 }));surfaces.append(value)
            }
            func index(_ p: UInt32) throws -> Int {
                guard p >= 0x23000020,(p-0x23000020)%0x2000 == 0 else { throw OriginalStateError.invalidStorage("Loading bitmap binding") }
                let n = Int((p-0x23000020)/0x2000)
                guard bitmaps.indices.contains(n) else { throw OriginalStateError.invalidStorage("Loading bitmap extent") };return n
            }
            var events: [OriginalFrontScreenEvent] = [],clockIndex = 0,blits = 0,fillIndex = 0
            let times = c.spec.times ?? [134,134],results = c.spec.results ?? [-2147467259,0,-1,1]
            func draw(_ args: [UInt32]) throws {
                let n = try index(args[0])
                let input = try OriginalBitmapDrawInput(x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),frame: Int32(bitPattern: args[3]),
                    colorKey: args[4],mirrored: args[5],sourceSurface: surfaces[n],targetSurface: args[6],
                    viewportWidth: initial.integer(at: 0x44d78c-0x44d000,as: Int32.self),viewportHeight: initial.integer(at: 0x44d790-0x44d000,as: Int32.self))
                try OriginalBitmapDrawing.draw(input,bitmap: bitmaps[n],observeRead: {
                    var event = OriginalFrontScreenEvent("read");event.read = $0;events.append(event)
                },observeClip: {
                    var event = OriginalFrontScreenEvent("clip");event.clip = $0;events.append(event)
                },perform: {
                    var event = OriginalFrontScreenEvent("blit");event.blit = $0;events.append(event)
                    defer { blits += 1 };return results[blits%results.count]
                })
            }
            let messageBytes = hex(c.spec.message ?? "00112233445566778899aabbccddeeff102132435465768798a9bacb")
            try OriginalLibLoadingProgress.update(globals: &globals,libraryText: &text,input: c.input,time: {
                guard times.indices.contains(clockIndex) else { throw OriginalStateError.invalidStorage("Unexpected clock read") }
                defer { clockIndex += 1 };return times[clockIndex]
            },panelFirstWord: { surfaces[try index($0)] },draw: draw,fillBacking: {
                guard c.fillBacking.indices.contains(fillIndex) else { throw OriginalStateError.invalidStorage("Unexpected fill") }
                defer { fillIndex += 1 };return self.hex(c.fillBacking[fillIndex])
            },performFill: { _ in c.input.methodResult },message: { name,_ in
                .init(result: name == "PeekMessageA" ? c.spec.peek ?? 0 : c.spec.get ?? 0,bytes: messageBytes)
            },observe: { events.append($0) })
            XCTAssertEqual(globals,try record(c.globalsAfter),c.spec.label)
            XCTAssertEqual(text.retainedDC,try record(c.libraryAfter).integer(at: 0x306e,as: UInt32.self),c.spec.label)
            XCTAssertEqual(clockIndex,times.count);XCTAssertEqual(blits,c.blits,c.spec.label);XCTAssertEqual(fillIndex,c.fillBacking.count)
            if events != c.events {
                let at = zip(events,c.events).enumerated().first { $0.element.0 != $0.element.1 }?.offset
                let detail = at.map { String(describing: events[$0])+" / "+String(describing: c.events[$0]) } ?? "count"
                throw OriginalStateError.invalidStorage("Loading event mismatch \(c.spec.label) at \(String(describing: at)), counts \(events.count)/\(c.events.count): \(detail)")
            }
            totals += events.count
            if c.spec.chain == true {
                for p in [0x4511c0,0x4511bc,0x4511b8,0x457580] { retained[p] = try globals.integer(at: p-0x44d000,as: UInt32.self) }
                retainedText = text
            }
            if c.spec.label == "message-1-1" {
                enum Stop: Error { case late, missingBitmap }
                for missing in [false,true] {
                    var trial = initial,trialText = initialText,clock = 0,seen: [String] = []
                    XCTAssertThrowsError(try OriginalLibLoadingProgress.update(globals: &trial,libraryText: &trialText,input: c.input,
                        time: { defer { clock += 1 };return times[clock] },panelFirstWord: { surfaces[try index($0)] },
                        draw: { args in if missing && args[0] == 0x23002020 { throw Stop.missingBitmap } },
                        fillBacking: { [UInt8](repeating: 0xa5,count: 100) },performFill: { _ in 0 },
                        message: { name,_ in if name == "DispatchMessageA" { throw Stop.late };return .init(result: 1,bytes: messageBytes) },
                        observe: { seen.append($0.kind) }))
                    XCTAssertEqual(trial,initial);XCTAssertEqual(trialText,initialText)
                    XCTAssertTrue(seen.contains("textOut"));if !missing { XCTAssertTrue(seen.contains("TranslateMessage")) }
                    rollbacks += 1
                }
            }
        }
        XCTAssertEqual(rollbacks,2)
        print("LIB LOADING",corpus.cases.count,"whole calls",totals,"events",rollbacks,"rollback trials")
    }
}
