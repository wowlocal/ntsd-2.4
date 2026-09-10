import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationMenuReturnTests: XCTestCase {
    typealias B = OriginalBitmapSurfaceLoadingTests
    typealias F = OriginalApplicationFrontScreenTests
    typealias Body = OriginalApplicationScreenBodyTests
    typealias Entry = OriginalApplicationDispatchEntryTests
    struct Spec: Decodable { let label: String,drawResult: Int32,presentResult: Int32,time: UInt32 }
    struct State: Decodable {
        let globals: String,mask: String,local: String,localMask: String,retainedDC: UInt32
        let pc: UInt32,sp: UInt32,eax: UInt32,cw: UInt32,seh: UInt32,registers: [UInt32],baseline: UInt32,counter: UInt32
    }
    struct Case: Decodable {
        let spec: Spec,parent: String,parentKind: String,before: State,mainEntry: State?,tailEntry: State?,worldReturn: State?,dispatchReturn: State?,after: State
        let events: [F.Event],records: [B.Record],end: String
    }
    struct Corpus: Decodable { let cases: [Case],blobs: [String:OriginalApplicationMessageLoopTests.Blob] }
    final class Resources {
        let c: Corpus,indices: [Int],rawCases: [[String:Any]]
        var cache: [String:[UInt8]] = [:]
        init(_ body: Body.Resources,_ front: F.Resources) throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_APPLICATION_MENU_RETURN"].map { URL(fileURLWithPath:$0) } ?? XCTUnwrap(Bundle.module.url(forResource:"original-application-menu-return",withExtension:"json",subdirectory:"Fixtures"))
            let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:100_000_000)
            c = try JSONDecoder().decode(Corpus.self,from:data);XCTAssertEqual(c.cases.count,48)
            let raw = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
            rawCases = try XCTUnwrap(raw["cases"] as? [[String:Any]])
            let bp = try XCTUnwrap(raw["bodyParents"] as? [String:[String:Any]]),fp = try XCTUnwrap(raw["frontParents"] as? [String:[String:Any]])
            XCTAssertEqual(bp.count,43);XCTAssertEqual(fp.count,40)
            indices = try c.cases.map { c in
                let parent = try XCTUnwrap((c.parentKind == "body" ? bp : fp)[c.parent])
                return try XCTUnwrap((c.parentKind == "body" ? body.rawCases : front.rawCases).firstIndex { NSDictionary(dictionary:$0).isEqual(to:parent) })
            }
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let b = cache[key] { return b }
            let z = try XCTUnwrap(c.blobs[key]),b = try MatchPreparationReference.inflate(z.deflate,count:z.count,maximumCount:10_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(b)),key);cache[key] = b;return b
        }
    }
    final class Adapter {
        let c: Case,r: Resources,fail: String?
        var index = 0,shadow: [UInt8],mask = [UInt8](repeating:0,count:0xc3a8),occurrences: [String:Int] = [:]
        init(_ c: Case,_ r: Resources,initial: [UInt8],fail: String?) { self.c = c;self.r = r;shadow = initial;self.fail = fail }
        func observe(_ q: OriginalFrontScreenEvent) throws {
            guard index < c.events.count else { XCTFail("Extra return event \(q.kind)");throw B.Stop.late }
            let e = c.events[index];index += 1
            XCTAssertTrue(shadow == (try r.blob(e.globals)),c.spec.label+" globals at \(index)")
            XCTAssertEqual(e.kind,"front");XCTAssertEqual(q,try XCTUnwrap(e.event),c.spec.label+" event \(index)")
            occurrences[q.kind,default:0] += 1
            if q.kind == "write" {
                let at = Int(q.arguments[0])-0x44d000,n = Int(q.arguments[1]),v = q.arguments[2]
                shadow.replaceSubrange(at..<at+n,with:(0..<n).map { UInt8(truncatingIfNeeded:v >> ($0*8)) });mask.replaceSubrange(at..<at+n,with:repeatElement(1,count:n))
            }
            if fail == q.kind+"#\(occurrences[q.kind]!)" { throw B.Stop.late }
        }
        func store(_ address: Int,_ bytes: [UInt8]) throws {
            let v = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
            try observe(.init("write",[UInt32(address),UInt32(bytes.count),v]))
        }
    }
    func run(_ index: Int,_ r: Resources,_ body: Body.Resources,_ front: F.Resources,_ br: B.Resources,_ er: Entry.Resources,fail: String? = nil,continuation: ((OriginalApplicationMessageLoop,B.OwnContext) throws -> Void)? = nil) throws {
        let c = r.c.cases[index];var adapter: Adapter?,reached = false,committed = false
        func full(_ owned: B.OwnContext,_ counter: UInt32? = nil) -> [UInt8] {
            if let counter { return owned.base.globals.bytes+owned.base.outerBytes(counter:counter)+owned.outerAndWorldBytes.dropFirst(0x854) }
            return owned.base.globals.bytes+owned.outerAndWorldBytes
        }
        func finished(_ loop: OriginalApplicationMessageLoop,_ owned: B.OwnContext) throws {
            let a = try XCTUnwrap(adapter)
            XCTAssertEqual(a.index,c.events.count);XCTAssertTrue(a.shadow == (try r.blob(c.after.globals)))
            XCTAssertEqual(a.mask,try r.blob(c.after.mask));XCTAssertTrue(full(owned,loop.counter) == a.shadow)
            XCTAssertEqual(loop.counter,c.after.counter);XCTAssertEqual(loop.timer.baseline,c.after.baseline)
            XCTAssertEqual(owned.dispatchResult,Int32(bitPattern:try XCTUnwrap(c.dispatchReturn).eax))
            XCTAssertEqual(owned.libraryText.retainedDC,c.after.retainedDC)
            XCTAssertEqual(c.after.pc,0x43d110);XCTAssertEqual(c.after.sp,0x1000effc);XCTAssertEqual(c.after.eax,2)
            XCTAssertEqual(c.after.cw,0x37f);XCTAssertEqual(c.after.seh,UInt32.max)
        }
        let completion = B.LoopCompletion(perform:{ q,owned in
            let a = try XCTUnwrap(adapter)
            switch q.kind {
            case .time:try a.observe(.init("time",[c.spec.time]));return .init(result:Int32(bitPattern:c.spec.time))
            case .sleep:try a.observe(.init("sleep",q.arguments));return .init()
            default:XCTFail("Unrecovered loop operation \(q.kind)");throw B.Stop.late
            }
        },counter:{ try XCTUnwrap(adapter).observe(.init("write",[0x458580,4,$0])) },beforeCommit:{ loop,owned in
            try finished(loop,owned)
            if fail == "commit" { throw B.Stop.late }
        },completed:{ loop,owned in try finished(loop,owned);committed = true;try continuation?(loop,owned) })
        let continueMenu: (inout B.OwnContext) throws -> Void = { owned in
            reached = true
            var globals = owned.base.globals,random = owned.random,library = owned.libraryText,memory = owned.base.memory
            let initial = full(owned);XCTAssertTrue(initial == (try r.blob(c.before.globals)))
            let a = Adapter(c,r,initial:initial,fail:fail);adapter = a
            let initialRandom = random,target = try XCTUnwrap(owned.gameEntry).target
            // Selector and RNG are own semantic outputs. No source register,
            // cookie, saved nonvolatile or CRT/PTD after-state is imported.
            let selector = try owned.screenBody?.retainedSelector ?? globals.integer(at:0x44d064-0x44d000,as:Int32.self)
            XCTAssertEqual(UInt32(bitPattern:selector),c.before.eax)
            var all = owned.front.bitmaps,surfaces = owned.frontSurfaces
            for (p,b) in owned.earlyScreen.bitmaps { XCTAssertNil(all.updateValue(b,forKey:p)) }
            for (p,s) in owned.earlyScreen.surfaces { XCTAssertNil(surfaces.updateValue(s,forKey:p)) }
            let width = try globals.integer(at:0x44d78c-0x44d000,as:Int32.self),height = try globals.integer(at:0x44d790-0x44d000,as:Int32.self)
            func draw(_ args: [UInt32]) throws {
                if args[0] == 0 {
                    XCTAssertEqual(c.end,"nullBitmap");XCTAssertEqual(a.index,c.events.count)
                    XCTAssertTrue(a.shadow == (try r.blob(c.after.globals)));XCTAssertEqual(a.mask,try r.blob(c.after.mask))
                    throw B.Stop.required
                }
                let bitmap = try XCTUnwrap(all[args[0]])
                func emit(_ kind: String,_ configure: (inout OriginalFrontScreenEvent) -> Void) throws {
                    var e = OriginalFrontScreenEvent(kind);configure(&e);try a.observe(e)
                }
                let input = OriginalBitmapDrawInput(x:Int32(bitPattern:args[1]),y:Int32(bitPattern:args[2]),frame:Int32(bitPattern:args[3]),colorKey:args[4],mirrored:args[5],sourceSurface:try XCTUnwrap(surfaces[args[0]]),targetSurface:args[6],viewportWidth:width,viewportHeight:height)
                _ = try OriginalBitmapDrawing.draw(input,bitmap:bitmap.storage,observeRead:{ read in try emit("read") { $0.read = read } },observeClip:{ clip in try emit("clip") { $0.clip = clip } },perform:{ b in try emit("blit") { $0.blit = b };return c.spec.drawResult })
            }
            let alt = OriginalFrontScreenAlternateInput(selector:selector,drawTarget:target,timers:[],methodResult:0,drawResults:[c.spec.drawResult],fillResult:0,threadHandle:0,threadID:0,lastError:0)
            let alternate = try OriginalFrontScreenAlternate.advance(globals:&globals,input:alt,draw:draw,fill:{ _ in throw B.Stop.late },writeSettings:{ _ in throw B.Stop.late },observe:a.observe)
            let worldOffset = 0x458b00-0x44d000
            var world = try OriginalStateRecord(bytes:Array(initial[worldOffset..<worldOffset+0x7d8]),defined:[Bool](repeating:true,count:0x7d8))
            if alternate == .mainMenu {
                XCTAssertTrue(globals.bytes+owned.outerAndWorldBytes == (try r.blob(XCTUnwrap(c.mainEntry).globals)))
                // No own row is hovered/clicked. Network fields are unused;
                // every unexpected network/sound/RNG operation rejects here.
                let raw: [String:Any] = ["targetSurface":target,"network":["startupResult":0,"version":0,"hostnameResult":0,"hostname":[],"hostEntryAddress":0,"addresses":[],"socketResult":0,"asyncResult":0,"bindResult":0,"listenResult":0]]
                let input = try JSONDecoder().decode(OriginalMainMenuInput.self,from:JSONSerialization.data(withJSONObject:raw))
                let end = try OriginalMainMenu.run(world:&world,globals:&globals,crt:&random,input:input,store:a.store,observe:{ e in
                    if e.kind == .bitmap { try a.observe(.init("draw",e.arguments));try draw(e.arguments) }
                    else if e.kind == .panel { try a.observe(.init("panel",e.arguments)) }
                    else { XCTFail("Unrecovered own menu event \(e.kind)");throw B.Stop.late }
                })
                XCTAssertEqual(end,.present)
            } else { XCTAssertEqual(alternate,.presentation);XCTAssertNil(c.mainEntry) }
            XCTAssertTrue(globals.bytes+owned.outerAndWorldBytes == (try r.blob(XCTUnwrap(c.tailEntry).globals)))
            let raw: [String:Any] = ["targetSurface":target,"methodResult":c.spec.presentResult,"queryResult":0,"audioGetResult":0,"audioSetResult":0,"queriedAudio":0,"audioVolume":0,"dcResult":0,"dc":0,"postResult":0]
            let input = try JSONDecoder().decode(OriginalMenuPresentationInput.self,from:JSONSerialization.data(withJSONObject:raw))
            try OriginalMenuPresentation.applyWithLibrary(.tail,input:input,world:&world,globals:&globals,memory:&memory,libraryText:&library,store:a.store,observe:{ e in
                if e.kind == .bitmap { try a.observe(.init("draw",e.arguments));try draw(e.arguments) }
                else if e.kind == .method { var q = OriginalFrontScreenEvent("method",e.arguments);q.strings = e.strings;try a.observe(q) }
                else { XCTFail("Unrecovered own presentation event \(e.kind)");throw B.Stop.late }
            })
            owned.base.globals = globals;owned.random = random;owned.libraryText = library;owned.base.memory = memory
            let relative = worldOffset-0xb440
            owned.outerAndWorldBytes.replaceSubrange(relative..<relative+0x7d8,with:world.bytes)
            let returned = try XCTUnwrap(c.worldReturn)
            XCTAssertTrue(full(owned) == (try r.blob(returned.globals)));XCTAssertEqual(returned.pc,0x43ecbf);XCTAssertEqual(returned.sp,0x1000eea0);XCTAssertEqual(returned.eax,UInt32(bitPattern:c.spec.presentResult))
            owned.dispatchResult = try OriginalApplicationDispatchEntry.finishWorldCall(globals:.init(bytes:full(owned),defined:[Bool](repeating:true,count:0xc3a8)))
            XCTAssertEqual(owned.dispatchResult,Int32(bitPattern:try XCTUnwrap(c.dispatchReturn).eax));XCTAssertEqual(owned.dispatchResult,1)
            XCTAssertEqual(random,initialRandom);XCTAssertEqual(library.retainedDC,c.before.retainedDC)
            XCTAssertEqual(all.count,c.records.count)
            for record in c.records {
                let bitmap = try XCTUnwrap(all[record.address]);var bytes = try r.blob(record.bytes)
                bytes.replaceSubrange(0..<4,with:[surfaces[record.address] == 0 ? 0 : 1,0,0,0])
                XCTAssertEqual(bitmap.storage.bytes,bytes);XCTAssertEqual(bitmap.storage.defined,try r.blob(record.mask).map { $0 != 0 })
            }
            // Reconcile the loop's own overlapping records after its dispatcher.
            // These bytes were produced by native children, never an oracle.
            owned.base.outer = try .init(bytes:Array(owned.outerAndWorldBytes.prefix(0x854)),defined:[Bool](repeating:true,count:0x854))
            owned.base.local = try .init(bytes:Array(owned.outerAndWorldBytes.prefix(0x140)),defined:[Bool](repeating:true,count:0x140))
            if fail == "dispatchReturn" { throw B.Stop.late }
        }
        if c.parentKind == "body" { try Body().run(r.indices[index],body,front,br,er,fail:fail == nil ? nil : "menu",completion:completion,continuation:continueMenu) }
        else { try F().run(r.indices[index],front,br,er,fail:fail == nil ? nil : "menu",completion:completion,continuation:continueMenu) }
        XCTAssertTrue(reached);XCTAssertEqual(committed,fail == nil && c.end == "iteration")
    }
    func testOwnMenusReturnDispatcherAndCommitFirstDueIteration() throws {
        let front = try F.Resources(),body = try Body.Resources(front),r = try Resources(body,front),br = try B.Resources(),er = try Entry.Resources()
        for i in r.c.cases.indices { try run(i,r,body,front,br,er) }
        print("APPLICATION MENU RETURN 47 own whole menu/World/dispatcher/loop returns;1 pre-NULL cursor rejection with whole iteration rollback;48 full parents and resource registries")
    }
    func testLateMenuReturnFailuresRollBackWholeIteration() throws {
        let front = try F.Resources(),body = try Body.Resources(front),r = try Resources(body,front),br = try B.Resources(),er = try Entry.Resources()
        for fail in ["blit#1","panel#1","blit#2","method#1","write#2","dispatchReturn","time#1","write#3","commit"] { try run(0,r,body,front,br,er,fail:fail) }
    }
}
