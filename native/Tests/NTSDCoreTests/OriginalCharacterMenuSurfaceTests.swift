import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalCharacterMenuSurfaceTests: XCTestCase {
    typealias API = OriginalBitmapSurfaceLoading
    struct Spec: Decodable { let label: String, ramp: Bool?, reverse: Bool?, nulls: [Int]? }
    struct Snapshot: Decodable { let globals: String, cw: UInt32, sp: UInt32 }
    struct Allocation: Decodable { let address: UInt32, backing: String? }
    struct Record: Decodable { let address: UInt32, count: Int, kind: String, initial: String, bytes: String, mask: String }
    struct Checkpoint: Decodable { let kind: String, index: Int, snapshot: Snapshot, records: [Record], eventCount: Int }
    struct Event: Decodable { let kind: String?, index: Int?, address: UInt32?, count: Int?, path: String?, key: String?, request: API.Request?, response: API.Response?, globals: String? }
    struct Asset: Decodable { let raw: String, kind: String, width: Int32, height: Int32, planes: UInt16, bpp: UInt16 }
    struct Image: Decodable { let asset: Asset, deleted: Bool }
    struct Surface: Decodable { let description: [UInt8], released: Bool }
    struct Helper: Decodable { let kind: String, result: UInt32, wrapper: UInt32?, path: String?, sp: UInt32, returnSP: UInt32, pop: UInt32, eventStart: Int, eventEnd: Int }
    struct Case: Decodable {
        let spec: Spec, before: Snapshot, after: Snapshot
        let allocations: [Allocation], checkpoints: [Checkpoint], records: [Record], events: [Event], helpers: [Helper]
        let images: [String:Image], surfaces: [String:Surface], dcs: [String:Bool], end: String
    }
    struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    struct Corpus: Decodable { let exeSHA256: String, crtSHA256: String, cases: [Case], blobs: [String:Blob], assets: [String:Asset] }
    final class Resources {
        let c: Corpus
        var cache: [String:[UInt8]] = [:]
        init() throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_CHARACTER_MENU_SURFACE"].map { URL(fileURLWithPath:$0) }
                ?? XCTUnwrap(Bundle.module.url(forResource:"original-character-menu-surface",withExtension:"json",subdirectory:"Fixtures"))
            let raw = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:120_000_000)
            c = try JSONDecoder().decode(Corpus.self, from:raw)
            XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
            XCTAssertEqual(c.crtSHA256, "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
            XCTAssertEqual(c.cases.count, 27); XCTAssertEqual(c.assets.count, 11)
        }
        func blob(_ key: String) throws -> [UInt8] {
            if let raw = cache[key] { return raw }
            let item = try XCTUnwrap(c.blobs[key])
            let raw = try MatchPreparationReference.inflate(item.deflate,count:item.count,maximumCount:2_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(raw)), key); XCTAssertEqual(key,item.sha256)
            cache[key] = raw; return raw
        }
        func bitmapBytes(_ path: String) throws -> [UInt8] {
            let a = try XCTUnwrap(c.assets[path]), dib = try blob(a.raw)
            func word(_ at: Int) -> UInt32 { (0..<4).reduce(0) { $0 | UInt32(dib[at+$1]) << ($1*8) } }
            let width = word(4), height = UInt32(abs(Int64(Int32(bitPattern:word(8)))))
            let planes = UInt16(dib[12]) | UInt16(dib[13]) << 8, bpp = UInt16(dib[14]) | UInt16(dib[15]) << 8
            XCTAssertEqual(width,UInt32(bitPattern:a.width)); XCTAssertEqual(height,UInt32(bitPattern:a.height))
            XCTAssertEqual(planes,a.planes); XCTAssertEqual(bpp,a.bpp)
            var bytes = [UInt8](repeating:0,count:24)
            for (at,value) in [(4,width),(8,height),(12,((width*UInt32(bpp)+31)/32)*4),(16,UInt32(planes)|UInt32(bpp)<<16)] {
                for i in 0..<4 { bytes[at+i] = UInt8(truncatingIfNeeded:value >> (i*8)) }
            }
            return bytes
        }
    }
    struct Context: Equatable {
        var currentWrapper: UInt32 = 0
        var imagePaths: [UInt32:String] = [:], imagesDeleted: [UInt32:Bool] = [:]
        var surfaceDescriptions: [UInt32:[UInt8]] = [:], surfacesReleased: [UInt32:Bool] = [:]
        var dcs: [UInt32:Bool] = [:], surfaceForWrapper: [UInt32:UInt32] = [:]
        var requested: [String] = [], allocations: [UInt32] = []
    }
    enum Stop: Error { case injected }
    final class Adapter {
        let c: Case, r: Resources, failure: String?
        let events: [Event], suffix: [UInt8]
        var index = 0, stores = 0, unknown = 0
        var shadow: [UInt8]
        init(_ c: Case,_ r: Resources, failure: String? = nil) throws {
            self.c=c; self.r=r; self.failure=failure
            events=c.events
            shadow=try r.blob(c.before.globals); suffix=Array(shadow.dropFirst(OriginalMatchPreparation.globalSize))
        }
        func next(_ kind: String) throws -> Event {
            guard index<events.count else { XCTFail("Extra event \(kind)"); throw Stop.injected }
            let e=events[index]; index += 1
            XCTAssertEqual(e.kind ?? e.request?.kind,kind,"\(c.spec.label) event \(index-1)"); return e
        }
        func pattern(_ count: Int) -> [UInt8] { c.spec.ramp == true ? (0..<count).map { UInt8(truncatingIfNeeded:$0) } : [UInt8](repeating:0xa5,count:count) }
        func allocate(_ i: Int,_ g: inout Context) throws -> OriginalInterfaceAllocation {
            let e=try next("allocate")
            let token: UInt32 = c.spec.nulls?.contains(i) == true ? 0 : 0x50000020+UInt32(c.spec.reverse == true ? 10-i : i)*0x2000
            XCTAssertEqual(e.index,i); XCTAssertEqual(e.address,token); XCTAssertEqual(e.count,0x1f50)
            XCTAssertEqual(c.allocations[i].address,token)
            let backing = token == 0 ? [] : pattern(0x1f50)
            if let key=c.allocations[i].backing { XCTAssertEqual(backing,try r.blob(key)) }
            g.currentWrapper=token; g.allocations.append(token)
            return .init(address:token,backing:backing)
        }
        func observe(_ e: OriginalInterfaceEvent,_ g: inout Context) throws {
            if e.kind == .allocate { XCTAssertEqual(e.arguments,[0x1f50]); return }
            XCTAssertEqual(e.kind,.construct)
            let expected=try next("construct"), i=try XCTUnwrap(expected.index)
            XCTAssertEqual(e.arguments,[g.currentWrapper,0x40,0]); XCTAssertEqual(expected.address,g.currentWrapper)
            XCTAssertEqual(e.strings,[Array(OriginalMenuResourceLoading.paths[i].utf8)])
            XCTAssertEqual(expected.path,OriginalMenuResourceLoading.paths[i])
        }
        func perform(_ q: API.Request,_ g: inout Context) throws -> API.Response {
            let e=try next(q.kind), expected=try XCTUnwrap(e.request), captured=try XCTUnwrap(e.response), key=try XCTUnwrap(e.key)
            XCTAssertEqual(q.words,expected.words,key); XCTAssertEqual(q.strings,expected.strings,key); XCTAssertEqual(q.defined,expected.defined,key)
            if let mask=q.defined {
                let a=try XCTUnwrap(q.bytes),b=try XCTUnwrap(expected.bytes); XCTAssertEqual(a.count,b.count)
                for i in mask.indices {
                    if mask[i] { XCTAssertEqual(a[i],b[i],key+" owned byte\(i)") }
                    else { unknown += 1; XCTAssertEqual(a[i],0,"Private API backing imported") }
                }
            }
            XCTAssertEqual(shadow,try r.blob(XCTUnwrap(e.globals)),key+" complete globals")
            var response=captured; g.requested.append(key)
            switch q.kind {
            case "image": if captured.result != 0 {
                let token=UInt32(bitPattern:captured.result), path=String(decoding:q.strings[0],as:UTF8.self)
                _=try r.bitmapBytes(path); g.imagePaths[token]=path; g.imagesDeleted[token]=false
            }
            case "getObject": if captured.result != 0 {
                let bytes=try r.bitmapBytes(XCTUnwrap(g.imagePaths[q.words[0]]))
                response = .init(result:captured.result,writes:[.init(bytes:bytes)])
            }
            case "createSurface": if let token=captured.output {
                g.surfaceDescriptions[token]=try XCTUnwrap(q.bytes); g.surfacesReleased[token]=false
                g.surfaceForWrapper[g.currentWrapper]=token
            }
            case "description": if captured.result >= 0 {
                response = .init(result:captured.result,writes:[.init(bytes:try XCTUnwrap(g.surfaceDescriptions[q.words[0]]))])
            }
            case "release": g.surfacesReleased[q.words[0]]=true
            case "createDC": g.dcs[UInt32(bitPattern:captured.result)]=false
            case "deleteDC": g.dcs[q.words[0]]=true
            case "deleteObject": g.imagesDeleted[q.words[0]]=captured.result != 0
            default: break
            }
            XCTAssertEqual(response,captured,key+" owned platform output")
            if failure==key { throw Stop.injected }
            return response
        }
        func stored(_ cp: OriginalMenuResourceCheckpoint,_ state: OriginalStateRecord,
                    _ bitmaps: [UInt32:OriginalLoadedBitmap],_ g: inout Context) throws {
            let expected=c.checkpoints[stores]; stores += 1
            XCTAssertEqual(cp.kind.rawValue,expected.kind); XCTAssertEqual(cp.index,expected.index)
            XCTAssertEqual(index,expected.eventCount)
            shadow=state.bytes+suffix
            XCTAssertEqual(shadow,try r.blob(expected.snapshot.globals),"\(c.spec.label) checkpoint\(stores)")
            try compare(expected.records,bitmaps,g)
            if failure==cp.kind.rawValue || failure=="bitmap5" && cp.kind == .bitmap && cp.index==5 { throw Stop.injected }
        }
        func compare(_ records: [Record],_ bitmaps: [UInt32:OriginalLoadedBitmap],_ g: Context) throws {
            XCTAssertEqual(records.count,bitmaps.count)
            for record in records {
                XCTAssertEqual(record.kind,"bitmap"); XCTAssertEqual(record.count,0x1f50)
                XCTAssertEqual(try r.blob(record.initial),pattern(record.count))
                let bitmap=try XCTUnwrap(bitmaps[record.address]); var expected=try r.blob(record.bytes)
                let pointer=(0..<4).reduce(UInt32(0)) { $0 | UInt32(expected[$1]) << ($1*8) }
                if pointer != 0 { XCTAssertEqual(g.surfaceForWrapper[record.address],pointer) }
                expected.replaceSubrange(0..<4,with:[pointer == 0 ? 0 : 1,0,0,0])
                XCTAssertEqual(bitmap.storage.bytes,expected,"\(c.spec.label) bitmap \(record.address)")
                XCTAssertEqual(bitmap.storage.defined,try r.blob(record.mask).map { $0 != 0 })
                let constructor=try XCTUnwrap(c.helpers.first { $0.kind=="constructor" && $0.wrapper==record.address })
                let child=try XCTUnwrap(c.helpers.first { $0.kind=="loader" && $0.eventStart>=constructor.eventStart && $0.eventEnd<=constructor.eventEnd })
                XCTAssertEqual(bitmap.input.present,child.result != 0); XCTAssertEqual(bitmap.input.path,child.path); XCTAssertFalse(bitmap.optional)
            }
        }
    }
    func run(_ c: Case,_ r: Resources,failure: String? = nil) throws -> Int {
        let a=try Adapter(c,r,failure:failure), initial=try r.blob(c.before.globals)
        var globals=try OriginalStateRecord(bytes:Array(initial.prefix(OriginalMatchPreparation.globalSize)),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
        var loader=OriginalMenuResourceLoading(),context=Context()
        let before=globals,beforeContext=context
        let unavailable: String? = c.spec.label=="object-first-zero" ? "bitmap width" : c.spec.label=="first-description-unavailable" ? "surface width" : nil
        do {
            let result=try loader.loadWithSurfaceLoading(globals:&globals,context:&context,allocate:a.allocate,perform:a.perform,checkpoint:a.stored,observe:a.observe)
            XCTAssertNil(failure); XCTAssertNil(unavailable)
            XCTAssertEqual(result.continuation.rawValue,c.end)
            XCTAssertEqual(result.selectionAtEntry,try before.integer(at:0x4512c8-OriginalMatchPreparation.globalBase,as:UInt32.self))
        } catch {
            if let unavailable {
                XCTAssertEqual(error as? API.Boundary,.unknownField(unavailable))
                XCTAssertEqual(a.index,unavailable=="bitmap width" ? 7 : 14)
            } else {
                guard failure != nil, case Stop.injected = error else { throw error }
            }
            XCTAssertEqual(globals,before); XCTAssertEqual(context,beforeContext); XCTAssertTrue(loader.bitmaps.isEmpty)
            return a.unknown
        }
        XCTAssertEqual(a.index,a.events.count); XCTAssertEqual(a.stores,c.checkpoints.count)
        XCTAssertEqual(globals.bytes+a.suffix,try r.blob(c.after.globals))
        try a.compare(c.records,loader.bitmaps,context)
        XCTAssertEqual(context.imagesDeleted,Dictionary(uniqueKeysWithValues:c.images.map { (UInt32($0.key)!,$0.value.deleted) }))
        XCTAssertEqual(context.surfacesReleased,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.released) }))
        XCTAssertEqual(context.surfaceDescriptions,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.description) }))
        XCTAssertEqual(context.dcs,Dictionary(uniqueKeysWithValues:c.dcs.map { (UInt32($0.key)!,$0.value) }))
        for h in c.helpers {
            XCTAssertEqual(h.returnSP,h.sp+4+h.pop)
            if h.kind=="constructor" { XCTAssertEqual(h.result,h.wrapper) }
        }
        XCTAssertEqual(c.after.cw,c.before.cw); XCTAssertEqual(c.after.sp,c.before.sp)
        return a.unknown
    }
    func testWholeCharacterMenuSurfaceCallsAndUnavailableOperands() throws {
        let r=try Resources(); var unknown=0
        for c in r.c.cases { unknown += try run(c,r) }
        XCTAssertGreaterThan(unknown,0)
        print("CHARACTER MENU SURFACE23 ready matches,2 NULL-SPARK boundaries,2 unavailable-operand rollback rejections; current-call private API bytes remain unknown: \(unknown)")
    }
    func testLateMenuSurfaceErrorsRollBackAllOwnedState() throws {
        let r=try Resources(),c=r.c.cases[0]
        for failure in ["createSurface#11","deleteObject#11","colorKey#11","bitmap5","flag","complete"] { _=try run(c,r,failure:failure) }
    }
}
