import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalInitialInterfaceSurfaceTests: XCTestCase {
    typealias API = OriginalBitmapSurfaceLoading
    struct Spec: Decodable { let label: String, ramp: Bool?, reverse: Bool?, nulls: [Int]? }
    struct Snapshot: Decodable { let globals: String, cw: UInt32, sp: UInt32 }
    struct Allocation: Decodable { let address: UInt32, backing: String? }
    struct Record: Decodable { let address: UInt32, count: Int, kind: String, initial: String, bytes: String, mask: String }
    struct Checkpoint: Decodable { let index: Int, slot: Int, value: UInt32, globals: String, eventCount: Int }
    struct Event: Decodable { let kind: String?, index: Int?, address: UInt32?, count: Int?, path: String?, key: String?, request: API.Request?, response: API.Response?, globals: String? }
    struct Asset: Decodable { let raw: String, kind: String, width: Int32, height: Int32, planes: UInt16, bpp: UInt16 }
    struct Image: Decodable { let asset: Asset, deleted: Bool }
    struct Surface: Decodable { let description: [UInt8], released: Bool }
    struct Helper: Decodable { let kind: String, result: UInt32, wrapper: UInt32?, path: String?, sp: UInt32, returnSP: UInt32, pop: UInt32, eventStart: Int, eventEnd: Int }
    struct Case: Decodable {
        let spec: Spec, initial: Snapshot, beforeInterface: Snapshot, after: Snapshot
        let worldAddress: UInt32, catalogAddress: UInt32, objectAddress: UInt32, firstObjectWord90: UInt32, selector: Int32
        let actorAddresses: [UInt32], constructorSlots: [Int], allocations: [Allocation], checkpoints: [Checkpoint], records: [Record], events: [Event], helpers: [Helper]
        let images: [String:Image], surfaces: [String:Surface], dcs: [String:Bool], end: String
    }
    struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    struct Corpus: Decodable { let exeSHA256: String, crtSHA256: String, cases: [Case], blobs: [String:Blob], assets: [String:Asset] }
    final class Resources {
        let c: Corpus
        var cache: [String:[UInt8]] = [:]
        init() throws {
            let url = try ProcessInfo.processInfo.environment["NTSD_INITIAL_INTERFACE_SURFACE"].map { URL(fileURLWithPath:$0) }
                ?? XCTUnwrap(Bundle.module.url(forResource:"original-initial-interface-surface",withExtension:"json",subdirectory:"Fixtures"))
            let raw = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:120_000_000)
            c = try JSONDecoder().decode(Corpus.self, from:raw)
            XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
            XCTAssertEqual(c.crtSHA256, "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
            XCTAssertEqual(c.cases.count, 10); XCTAssertEqual(c.assets.count, 10)
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
        let prefix: Int, events: [Event], suffix: [UInt8]
        var index = 0, stores = 0, unknown = 0
        var shadow: [UInt8]
        init(_ c: Case,_ r: Resources, failure: String? = nil) throws {
            self.c=c; self.r=r; self.failure=failure
            prefix = try XCTUnwrap(c.events.firstIndex { $0.kind == "allocate" })
            XCTAssertEqual(prefix,401); events=Array(c.events.dropFirst(prefix))
            shadow=try r.blob(c.initial.globals); suffix=Array(shadow.dropFirst(OriginalMatchPreparation.globalSize))
        }
        func next(_ kind: String) throws -> Event {
            guard index<events.count else { XCTFail("Extra event \(kind)"); throw Stop.injected }
            let e=events[index]; index += 1
            XCTAssertEqual(e.kind ?? e.request?.kind,kind,"\(c.spec.label) event \(index-1)"); return e
        }
        func pattern(_ count: Int) -> [UInt8] { c.spec.ramp == true ? (0..<count).map { UInt8(truncatingIfNeeded:$0) } : [UInt8](repeating:0xa5,count:count) }
        func allocate(_ i: Int,_ g: inout Context) throws -> OriginalInterfaceAllocation {
            let e=try next("allocate")
            let token: UInt32 = c.spec.nulls?.contains(i) == true ? 0 : 0x50000020+UInt32(c.spec.reverse == true ? 9-i : i)*0x2000
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
            XCTAssertEqual(e.strings,[Array(OriginalInitialInterfaceLoading.paths[i].utf8)])
            XCTAssertEqual(expected.path,OriginalInitialInterfaceLoading.paths[i])
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
        func stored(_ i: Int,_ state: OriginalStateRecord,_ g: inout Context) throws {
            let cp=c.checkpoints[i]
            XCTAssertEqual(i,stores); stores += 1
            XCTAssertEqual(cp.index,i); XCTAssertEqual(cp.slot,OriginalInitialInterfaceLoading.slots[i]); XCTAssertEqual(cp.value,g.currentWrapper)
            XCTAssertEqual(index+prefix,cp.eventCount)
            shadow=state.bytes+suffix
            XCTAssertEqual(shadow,try r.blob(cp.globals),"global store\(i)")
            if failure=="lastGlobal" && i==9 { throw Stop.injected }
        }
    }
    func run(_ c: Case,_ r: Resources, failure: String? = nil) throws -> Int {
        let a=try Adapter(c,r,failure:failure)
        var pool=try OriginalWorldBootstrap(worldBacking:a.pattern(0x7d8),actorBacking:[Array<UInt8>](repeating:a.pattern(0x420),count:400),selector:c.selector)
        try pool.activateStagingActors(firstObjectWord90:Int32(bitPattern:c.firstObjectWord90))
        XCTAssertEqual(c.constructorSlots,Array(0..<400)+Array(0..<8))
        let allocated=c.events.filter { $0.kind=="allocateActor" }; XCTAssertEqual(allocated.count,400)
        for i in 0..<400 {
            let token=0x75000020+UInt32(c.spec.reverse == true ? 399-i : i)*0x500
            XCTAssertEqual(c.actorAddresses[i],token); XCTAssertEqual(allocated[i].address,token); XCTAssertEqual(allocated[i].index,i); XCTAssertEqual(allocated[i].count,0x420)
        }
        let initial=try r.blob(c.initial.globals)
        var globals=try OriginalStateRecord(bytes:Array(initial.prefix(OriginalMatchPreparation.globalSize)),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
        var loader=OriginalInitialInterfaceLoading(), context=Context()
        let before=globals, beforeContext=context
        do {
            try loader.loadWithSurfaceLoading(globals:&globals,context:&context,allocate:a.allocate,perform:a.perform,afterBitmap:a.stored,observe:a.observe)
            XCTAssertNil(failure)
        } catch {
            guard failure != nil, case Stop.injected = error else { throw error }
            XCTAssertEqual(globals,before); XCTAssertEqual(context,beforeContext); XCTAssertTrue(loader.bitmaps.isEmpty)
            return 0
        }
        XCTAssertEqual(a.index,a.events.count); XCTAssertEqual(a.stores,10)
        XCTAssertEqual(globals.bytes+a.suffix,try r.blob(c.after.globals))
        XCTAssertEqual(context.imagesDeleted,Dictionary(uniqueKeysWithValues:c.images.map { (UInt32($0.key)!,$0.value.deleted) }))
        XCTAssertEqual(context.surfacesReleased,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.released) }))
        XCTAssertEqual(context.surfaceDescriptions,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.description) }))
        XCTAssertEqual(context.dcs,Dictionary(uniqueKeysWithValues:c.dcs.map { (UInt32($0.key)!,$0.value) }))
        func bind(_ bytes: inout [UInt8],_ offset: Int,_ address: UInt32,_ ordinal: UInt32) {
            XCTAssertEqual(Array(bytes[offset..<offset+4]),(0..<4).map { UInt8(truncatingIfNeeded:address >> ($0*8)) })
            bytes.replaceSubrange(offset..<offset+4,with:(0..<4).map { UInt8(truncatingIfNeeded:ordinal >> ($0*8)) })
        }
        for record in c.records {
            var expected=try r.blob(record.bytes); let mask=try r.blob(record.mask)
            XCTAssertEqual(try r.blob(record.initial),a.pattern(record.count))
            let actual: OriginalStateRecord
            if record.kind=="world" {
                XCTAssertEqual(record.address,c.worldAddress); actual=pool.world
                bind(&expected,0x7d4,c.catalogAddress,0)
                for i in 0..<400 { bind(&expected,0x194+i*4,c.actorAddresses[i],UInt32(i)) }
            } else if record.kind=="actor" {
                let i=try XCTUnwrap(c.actorAddresses.firstIndex(of:record.address)); actual=pool.actors[i]
                bind(&expected,0x368,c.objectAddress,0)
            } else {
                XCTAssertEqual(record.kind,"bitmap")
                let bitmap=try XCTUnwrap(loader.bitmaps[record.address]); actual=bitmap.storage
                let pointer=(0..<4).reduce(UInt32(0)) { $0 | UInt32(expected[$1]) << ($1*8) }
                if pointer != 0 { XCTAssertEqual(context.surfaceForWrapper[record.address],pointer) }
                bind(&expected,0,pointer,pointer == 0 ? 0 : 1)
                let constructor=try XCTUnwrap(c.helpers.first { $0.kind=="constructor" && $0.wrapper==record.address })
                let child=try XCTUnwrap(c.helpers.first { $0.kind=="loader" && $0.eventStart>=constructor.eventStart && $0.eventEnd<=constructor.eventEnd })
                XCTAssertEqual(bitmap.input.present,child.result != 0); XCTAssertEqual(bitmap.input.path,child.path); XCTAssertFalse(bitmap.optional)
            }
            XCTAssertEqual(actual.bytes,expected,"\(c.spec.label) \(record.kind) \(record.address)")
            XCTAssertEqual(actual.defined,mask.map { $0 != 0 })
        }
        for h in c.helpers {
            XCTAssertEqual(h.returnSP,h.sp+4+h.pop)
            if h.kind=="constructor" || h.kind=="world" { XCTAssertEqual(h.result,h.wrapper) }
            if h.kind=="actor" { XCTAssertEqual(h.result,0xfffffc18) }
        }
        return a.unknown
    }
    func testWholeControlledPoolAndInterfaceSurfaceCalls() throws {
        let r=try Resources(); var unknown=0
        for c in r.c.cases { unknown += try run(c,r) }
        XCTAssertGreaterThan(unknown,0)
        print("INITIAL INTERFACE SURFACE10 controlled whole callers; unknown private API bytes retained as unknown: \(unknown)")
    }
    func testLateSurfaceAndFinalStoreErrorsRollBackContext() throws {
        let r=try Resources(),c=r.c.cases[0]
        for failure in ["createSurface#10","deleteObject#10","colorKey#10","lastGlobal"] { _=try run(c,r,failure:failure) }
    }
}
