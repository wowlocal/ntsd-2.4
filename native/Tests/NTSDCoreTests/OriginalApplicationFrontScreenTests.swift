import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationFrontScreenTests: XCTestCase {
    typealias B = OriginalBitmapSurfaceLoadingTests
    typealias S = OriginalApplicationSettingsTests
    typealias API = OriginalBitmapSurfaceLoading
    typealias Entry = OriginalApplicationDispatchEntryTests
    struct Spec: Decodable { let label: String,milliseconds: UInt32?,thread: UInt32?,fillResult: Int32?,drawResult: Int32?,null: Bool? }
    struct State: Decodable { let globals: String,pc: UInt32,sp: UInt32,cw: UInt32,registers: [UInt32] }
    struct Event: Decodable { let kind: String?,event: OriginalFrontScreenEvent?,key: String?,request: API.Request?,response: API.Response?,globals: String }
    struct Case: Decodable {
        let spec: Spec,parent: String,before: State,after: State,events: [Event],allocation: B.Allocation,records: [B.Record],images: [String:B.Image],surfaces: [String:B.Surface],dcs: [String:Bool],end: String
    }
    struct Corpus: Decodable { let cases: [Case],blobs: [String:OriginalApplicationMessageLoopTests.Blob] }
    final class Resources {
        let c: Corpus,settings: S.Resources,settingKeys: [String]
        let rawCases: [[String:Any]]
        var cache: [String:[UInt8]] = [:]
        init() throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_APPLICATION_FRONT_SCREEN"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-application-front-screen",withExtension:"json",subdirectory:"Fixtures"))
            let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:100_000_000)
            c = try JSONDecoder().decode(Corpus.self,from:data);XCTAssertEqual(c.cases.count,41)
            let raw = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any]),parents = try XCTUnwrap(raw["settingsParents"] as? [String:[String:Any]])
            rawCases = try XCTUnwrap(raw["cases"] as? [[String:Any]])
            settingKeys = parents.keys.sorted();XCTAssertEqual(settingKeys.count,19)
            let supplied: [String:Any] = ["cases":settingKeys.map { parents[$0]! },"parents":try XCTUnwrap(raw["bitmapParents"]),"blobs":try XCTUnwrap(raw["blobs"]),"scratchAddress":0x1000e878,"scratchCount":500]
            settings = try S.Resources(supplied:JSONSerialization.data(withJSONObject:supplied))
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let b = cache[key] { return b }
            let z = try XCTUnwrap(c.blobs[key]),b = try MatchPreparationReference.inflate(z.deflate,count:z.count,maximumCount:10_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),key);cache[key] = b;return b
        }
    }
    final class Adapter {
        let c: Case,r: Resources,fail: String?
        var index = 0,shadow: [UInt8],created: UInt32?,fillOpaque = 0
        init(_ c: Case,_ r: Resources,initial: [UInt8],fail: String?) { self.c = c;self.r = r;shadow = initial;self.fail = fail }
        func next() throws -> Event {
            guard index < c.events.count else { XCTFail("Extra front event");throw B.Stop.late }
            let e = c.events[index];index += 1
            XCTAssertEqual(shadow,try r.blob(e.globals),c.spec.label+" full globals at event \(index)")
            return e
        }
        func observe(_ q: OriginalFrontScreenEvent) throws {
            let e = try next(),expected = try XCTUnwrap(e.event)
            XCTAssertEqual(e.kind,"front");XCTAssertEqual(q.kind,expected.kind);XCTAssertEqual(q.arguments,expected.arguments);XCTAssertEqual(q.strings,expected.strings)
            XCTAssertEqual(q.read,expected.read);XCTAssertEqual(q.clip,expected.clip);XCTAssertEqual(q.blit,expected.blit)
            if let actual = q.fill {
                let source = try XCTUnwrap(expected.fill)
                XCTAssertEqual(actual.target,source.target);XCTAssertEqual(actual.rectangle,source.rectangle);XCTAssertEqual(actual.flags,source.flags);XCTAssertEqual(actual.defined,source.defined)
                for i in source.defined.indices {
                    if source.defined[i] { XCTAssertEqual(actual.effects[i],source.effects[i]) }
                    else { fillOpaque += 1;XCTAssertEqual(actual.effects[i],0,"Private fill backing was imported") }
                }
            } else { XCTAssertNil(expected.fill) }
            if q.kind == "write" {
                let at = Int(q.arguments[0])-0x44d000,n = Int(q.arguments[1]),v = q.arguments[2]
                shadow.replaceSubrange(at..<at+n,with:(0..<n).map { UInt8(truncatingIfNeeded:v >> ($0*8)) })
            }
            if fail == q.kind || (fail == "backgroundStore" && q.kind == "write" && q.arguments[0] == 0x4511ac) { throw B.Stop.late }
        }
        func perform(_ q: API.Request,_ g: inout B.Graphics) throws -> API.Response {
            let e = try next(),expected = try XCTUnwrap(e.request),response = try XCTUnwrap(e.response),key = try XCTUnwrap(e.key)
            XCTAssertEqual(q.kind,expected.kind,key);XCTAssertEqual(q.words,expected.words,key);XCTAssertEqual(q.strings,expected.strings,key);XCTAssertEqual(q.defined,expected.defined,key)
            if let mask = q.defined {
                let a = try XCTUnwrap(q.bytes),b = try XCTUnwrap(expected.bytes)
                for i in mask.indices { XCTAssertEqual(a[i],mask[i] ? b[i] : 0,key+" field \(i)") }
            }
            g.log.append(key)
            switch q.kind {
            case "image":if response.result != 0 { g.images[UInt32(bitPattern:response.result)] = false }
            case "createSurface":if let output = response.output {
                g.surfaces[output] = false;g.descriptions[output] = q.bytes
                if response.result == 0 { created = output }
            }
            case "release":g.surfaces[q.words[0]] = true
            case "createDC":g.dcs[UInt32(bitPattern:response.result)] = false
            case "deleteDC":g.dcs[q.words[0]] = true
            case "deleteObject":g.images[q.words[0]] = response.result != 0
            default:break
            }
            if fail == key { throw B.Stop.late }
            return response
        }
        func complete(_ g: B.Graphics,_ bitmaps: [UInt32:OriginalLoadedBitmap]) throws {
            XCTAssertEqual(index,c.events.count);XCTAssertEqual(shadow,try r.blob(c.after.globals));XCTAssertEqual(fillOpaque,92)
            XCTAssertEqual(g.images,Dictionary(uniqueKeysWithValues:c.images.map { (UInt32($0.key)!,$0.value.deleted) }))
            XCTAssertEqual(g.surfaces,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.released) }))
            XCTAssertEqual(g.dcs,Dictionary(uniqueKeysWithValues:c.dcs.map { (UInt32($0.key)!,$0.value) }))
            XCTAssertEqual(g.descriptions,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.description) }))
            XCTAssertEqual(bitmaps.count,c.records.count)
            for record in c.records {
                let bitmap = try XCTUnwrap(bitmaps[record.address]);var b = try r.blob(record.bytes)
                let surface = b.prefix(4).enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
                if surface != 0 { XCTAssertNotNil(g.surfaces[surface]) }
                b.replaceSubrange(0..<4,with:[surface == 0 ? 0 : 1,0,0,0]);XCTAssertEqual(bitmap.storage.bytes,b);XCTAssertEqual(bitmap.storage.defined,try r.blob(record.mask).map { $0 != 0 })
            }
        }
    }
    func run(_ index: Int,_ r: Resources,_ br: B.Resources,_ er: Entry.Resources,fail: String? = nil,
             continuation: ((inout B.OwnContext) throws -> Void)? = nil) throws {
        let c = r.c.cases[index],si = try XCTUnwrap(r.settingKeys.firstIndex(of:c.parent));var reached = false
        try S().compare(si,r.settings,br,er,fail:fail == nil ? nil : "front",continuation:{ owned in
            reached = true
            let before = try r.blob(c.before.globals)
            XCTAssertEqual(owned.base.globals.bytes,Array(before.prefix(0xb440)))
            let output = try XCTUnwrap(owned.settings);XCTAssertEqual(output.continuation,.ready);XCTAssertEqual(output.retainedESI,UInt32.max)
            var screen = owned.earlyScreen,g = owned.graphics,globals = owned.base.globals
            let full = owned.base.globals.bytes+owned.outerAndWorldBytes
            XCTAssertEqual(full,before)
            let adapter = Adapter(c,r,initial:full,fail:fail)
            let input = OriginalFrontScreenInput(drawTarget:try XCTUnwrap(output.target),milliseconds:c.spec.milliseconds ?? 123456900,threadHandle:c.spec.thread ?? 0x50010000,threadID:0xabcd,lastError:5,fillResult:c.spec.fillResult ?? 0,drawResults:[c.spec.drawResult ?? 0])
            let end = try screen.advance(globals:&globals,input:input,fillBacking:[UInt8](repeating:0,count:100),allocate:{
                let token: UInt32 = c.spec.null == true ? 0 : (owned.front.bitmaps.keys.max() ?? 0x2800e020)+0x2000
                XCTAssertEqual(token,c.allocation.address)
                let backing = token == 0 ? [] : [UInt8](repeating:0xa5,count:0x1f50)
                if let h = c.allocation.backing { XCTAssertEqual(backing,try r.blob(h)) }
                return .init(address:token,backing:backing)
            },source:{ _ in throw B.Stop.late },constructBitmap:{ allocation,device,path in
                let bitmap = try OriginalBitmapConstructor.constructWithSurfaceLoading(path:path,optional:false,backing:allocation.backing,device:device,flags:0x40,context:&g,perform:adapter.perform)
                let present = try bitmap.storage.integer(at:0,as:UInt32.self) != 0
                return (bitmap,present ? try XCTUnwrap(adapter.created) : 0)
            },observe:adapter.observe)
            XCTAssertEqual(end.rawValue,c.end);XCTAssertEqual(c.after.cw,0x37f)
            var all = owned.front.bitmaps
            for (token,bitmap) in screen.bitmaps { XCTAssertNil(all.updateValue(bitmap,forKey:token)) }
            try adapter.complete(g,all);XCTAssertEqual(globals.bytes,Array(adapter.shadow.prefix(0xb440)))
            if end == .critical { XCTAssertEqual(c.after.pc,0x427127);XCTAssertEqual(c.after.sp,0x1000ea74) }
            else if end == .alternate { XCTAssertEqual(c.after.pc,0x4275cb);XCTAssertEqual(c.after.sp,0x1000ea74) }
            else { XCTAssertEqual(end,.nullBitmap);XCTAssertEqual(c.after.pc,0x43f04b) }
            if end == .critical || end == .alternate {
                XCTAssertEqual(screen.retainedOperation,.sleep)
                // Source's already declared message-loop Sleep binding.
                XCTAssertEqual(c.after.registers[2],0x30009040)
                XCTAssertEqual(c.after.registers[3],output.target)
            } else { XCTAssertNil(screen.retainedOperation) }
            owned.base.globals = globals;owned.graphics = g;owned.earlyScreen = screen
            if fail == "screenBoundary" { throw B.Stop.late }
            try continuation?(&owned)
        })
        XCTAssertTrue(reached)
    }
    func testOwnScreenUsesWholeBackgroundLoaderAndPrivateFillMasks() throws {
        let r = try Resources(),br = try B.Resources(),er = try Entry.Resources()
        for i in r.c.cases.indices { try run(i,r,br,er) }
        print("APPLICATION FRONT SCREEN 40 own prefixes to body/alternate and1 pre-NULL stop; full parents/resources/requests and outer rollback")
    }
    func testLateScreenFailuresRollBackCommittedStartupAndCallback() throws {
        let r = try Resources(),br = try B.Resources(),er = try Entry.Resources()
        for fail in ["fill","format","createSurface#1","deleteObject#1","backgroundStore","blit","screenBoundary"] { try run(0,r,br,er,fail:fail) }
        try run(38,r,br,er,fail:"createThread");try run(40,r,br,er,fail:"lastError")
    }
}
