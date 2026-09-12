import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

/// Declared platform responses around actual source bitmap helpers. Native
/// image metadata comes from pinned raw BMP bytes, never source API after-state.
final class OriginalWarPreparationSurfaceAdapter {
    typealias Test = OriginalLibWarPreparationTests
    typealias Base = OriginalCharacterMenuSurfaceTests
    typealias API = OriginalBitmapSurfaceLoading
    let c: Test.WarGraphics,r: Test.Resources
    let inputs: Test.ResourceFailureInput.Graphics?
    var missingImageAttempts: [Int:Int]=[:],appliedResultKeys=Set<String>()
    var failedConstructionOrdinals=Set<Int>()
    var index=0,allocation=0,globalKeys: [String]=[]
    init(_ c: Test.WarGraphics,_ r: Test.Resources,inputs: Test.ResourceFailureInput.Graphics? = nil) {
        self.c=c;self.r=r;self.allocation=c.allocationStart ?? 0
        self.inputs=inputs
    }
    func ownerAddresses() throws -> [UInt32] {
        try c.allocations.map { try XCTUnwrap($0.address) }.filter { $0 != 0 }
    }
    func next(_ kind: String) throws -> Base.Event {
        guard index<c.events.count else { throw Test.Stop.unexpected }
        let e=c.events[index];index += 1;XCTAssertEqual(e.kind ?? e.request?.kind,kind);return e
    }
    func bitmapBytes(_ path: String) throws -> [UInt8] {
        let asset=try XCTUnwrap(r.corpus.assets[path]),file=try r.blob(asset.raw)
        XCTAssertEqual(asset.kind,"file");XCTAssertEqual(Array(file.prefix(2)),[66,77])
        let dib=Array(file.dropFirst(14))
        func word(_ i: Int) -> UInt32 { (0..<4).reduce(0) { $0 | UInt32(dib[i+$1]) << ($1*8) } }
        let width=word(4),height=UInt32(abs(Int64(Int32(bitPattern:word(8)))))
        let planes=UInt32(dib[12])|UInt32(dib[13])<<8,bpp=UInt32(dib[14])|UInt32(dib[15])<<8
        XCTAssertEqual(width,UInt32(bitPattern:asset.width));XCTAssertEqual(height,UInt32(bitPattern:asset.height))
        XCTAssertEqual(planes,UInt32(asset.planes));XCTAssertEqual(bpp,UInt32(asset.bpp))
        var bytes=[UInt8](repeating:0,count:24)
        for (offset,value) in [(4,width),(8,height),(12,((width*bpp+31)/32)*4),(16,planes|bpp<<16)] {
            for i in 0..<4 { bytes[offset+i]=UInt8(truncatingIfNeeded:value >> (i*8)) }
        }
        return bytes
    }
    func construct(_ path: String,_ optional: Bool,_ backing: [UInt8],_ context: inout Base.Context,
                   scratch: inout OriginalWarBitmapScratch,
                   afterRequest: (String) throws -> Void = { _ in },
                   observe: () throws -> Void) throws -> OriginalLoadedBitmap? {
        let ordinal=allocation
        // The allocator stimulus is declared separately from captured outputs.
        // Request ordinals advance even when no wrapper owner is produced.
        let token: UInt32=ordinal==inputs?.nullAllocationOrdinal ? 0 : 0x76004020+UInt32(ordinal)*0x2000
        let e=try next("allocate");XCTAssertEqual(e.index,allocation);XCTAssertEqual(e.address,token);XCTAssertEqual(e.count,0x1f50)
        guard c.allocations.indices.contains(allocation) else { throw Test.Stop.unexpected }
        XCTAssertEqual(c.allocations[allocation].address,token)
        XCTAssertFalse(optional)
        if token==0 {
            XCTAssertNil(c.allocations[allocation].backing)
            allocation += 1;try observe();return nil
        }
        XCTAssertEqual(backing,[UInt8](repeating:0xa5,count:0x1f50));XCTAssertEqual(backing,try r.blob(XCTUnwrap(c.allocations[allocation].backing)))
        // Every prior non-NULL wrapper in these owned chains invoked one loader.
        // A loader can try two images; its ordinal is not the image request count.
        let loaderOrdinal=context.allocations.filter { $0 != 0 }.count
        let missingImage=inputs?.missingLoaderIndices?.contains(loaderOrdinal)==true
        allocation += 1;context.currentWrapper=token;context.allocations.append(token);try observe()
        let constructor=try next("construct");XCTAssertEqual(constructor.address,token);XCTAssertEqual(constructor.path,path);XCTAssertFalse(optional);try observe()
        return try scratch.constructPreparationBitmap(path:path,optional:optional,backing:backing,device:0x32001000,flags:0x40,context:&context) { q,g in
            let e=try self.next(q.kind),expected=try XCTUnwrap(e.request),captured=try XCTUnwrap(e.response)
            XCTAssertEqual(q.words,expected.words);XCTAssertEqual(q.strings,expected.strings);XCTAssertEqual(q.defined,expected.defined)
            if let mask=q.defined {
                let actual=try XCTUnwrap(q.bytes),bytes=try XCTUnwrap(expected.bytes)
                for i in mask.indices { XCTAssertEqual(actual[i],mask[i] ? bytes[i] : 0,"Native private API backing") }
            }
            self.globalKeys.append(try XCTUnwrap(e.globals))
            let key=try XCTUnwrap(e.key)
            var response=captured;g.requested.append(key)
            if q.kind=="image",missingImage {
                response = .init(result:0)
                self.missingImageAttempts[loaderOrdinal,default:0] += 1
                self.failedConstructionOrdinals.insert(ordinal)
            }
            if let result=self.inputs?.results?[key] {
                let supported: [String:Int32]=["createSurface":-1,"colorKey":-1,"getDC":-1,
                    "restore":-1,"releaseDC":-1,"createDC":0,"selectObject":0,
                    "stretch":0,"deleteDC":0,"deleteObject":0,"getObject":0,"description":-1]
                guard supported[q.kind]==result,self.appliedResultKeys.insert(key).inserted else { throw Test.Stop.unexpected }
                response = .init(result:result)
                if ["createSurface","colorKey"].contains(q.kind) { self.failedConstructionOrdinals.insert(ordinal) }
            }
            switch q.kind {
            case "image":if response.result != 0 {
                let path=String(decoding:q.strings[0],as:UTF8.self),image=UInt32(bitPattern:response.result)
                _=try self.bitmapBytes(path);g.imagePaths[image]=path;g.imagesDeleted[image]=false
            }
            case "getObject":if response.result != 0 {
                response = .init(result:response.result,writes:[.init(bytes:try self.bitmapBytes(XCTUnwrap(g.imagePaths[q.words[0]])))])
            }
            case "createSurface":if let surface=response.output {
                g.surfaceDescriptions[surface]=try XCTUnwrap(q.bytes);g.surfacesReleased[surface]=false;g.surfaceForWrapper[g.currentWrapper]=surface
            }
            case "description":if response.result>=0 { response = .init(result:response.result,writes:[.init(bytes:try XCTUnwrap(g.surfaceDescriptions[q.words[0]]))]) }
            case "release":g.surfacesReleased[q.words[0]]=true
            case "createDC":g.dcs[UInt32(bitPattern:response.result)]=false
            case "deleteDC":g.dcs[q.words[0]]=true
            case "deleteObject":g.imagesDeleted[q.words[0]]=response.result != 0
            default:break
            }
            XCTAssertEqual(response,captured,"Owned platform output")
            try observe();try afterRequest(key);return response
        }
    }
    func release(_ index: Int,_ bitmap: OriginalLoadedBitmap,_ context: inout Base.Context,
                 observe: (String,UInt32) throws -> Void) throws {
        let ordinal=index-r.catalog.bitmaps.count
        let owners=try ownerAddresses()
        guard owners.indices.contains(ordinal) else { throw Test.Stop.unexpected }
        let wrapper=owners[ordinal]
        let request=try XCTUnwrap(c.allocations.firstIndex { $0.address==wrapper })
        XCTAssertLessThan(request,c.allocationStart ?? 0)
        let surface: UInt32
        if let owned=context.surfaceForWrapper[wrapper] { surface=owned }
        else if try bitmap.storage.integer(at:0,as:UInt32.self)==0,!bitmap.input.present {
            // An owned wrapper whose loader produced no surface reaches the
            // Core ownership guard. A missing binding for marker1 is a harness
            // error, never a substitute NULL platform response.
            surface=0
        } else { surface=try XCTUnwrap(context.surfaceForWrapper[wrapper]) }
        try OriginalBitmapRelease.release(bitmap,wrapper:wrapper,surface:surface,context:&context) { q,g in
            let e=try self.next(q.kind),expected=try XCTUnwrap(e.request),response=try XCTUnwrap(e.response)
            XCTAssertEqual(q.words,expected.words);XCTAssertEqual(q.strings,expected.strings);XCTAssertNil(q.bytes);XCTAssertNil(q.defined)
            self.globalKeys.append(try XCTUnwrap(e.globals));g.requested.append(try XCTUnwrap(e.key))
            if q.kind=="release" { XCTAssertEqual(g.surfacesReleased[surface],false);g.surfacesReleased[surface]=true }
            else { XCTAssertEqual(q.kind,"free");XCTAssertEqual(g.surfacesReleased[surface],true) }
            try observe(q.kind,wrapper);return response
        }
    }
    func compareGlobals(_ globals: OriginalStateRecord) throws {
        // All BG API requests precede43a42d and change no game globals. Each
        // captured request independently checks this whole native stage value.
        for key in Set(globalKeys) { XCTAssertEqual(globals.bytes,Array(try r.blob(key).prefix(globals.bytes.count))) }
    }
    func compare(_ state: OriginalMatchPreparation,_ context: Base.Context) throws {
        XCTAssertEqual(index,c.events.count);XCTAssertEqual(allocation,c.allocations.count)
        XCTAssertEqual(Set(missingImageAttempts.keys),Set(inputs?.missingLoaderIndices ?? []))
        for count in missingImageAttempts.values { XCTAssertEqual(count,2) }
        XCTAssertEqual(appliedResultKeys,Set((inputs?.results ?? [:]).keys))
        let owners=try ownerAddresses()
        XCTAssertEqual(state.bitmaps.count,r.catalog.bitmaps.count+owners.count)
        XCTAssertEqual(c.records.map(\.address),owners)
        let history=c.constructionHistory ?? c.helpers
        for (i,record) in c.records.enumerated() {
            let bitmap=state.bitmaps[r.catalog.bitmaps.count+i]
            var expected=try r.blob(record.bytes)
            let pointer=(0..<4).reduce(UInt32(0)) { $0 | UInt32(expected[$1]) << ($1*8) }
            if pointer != 0 { XCTAssertEqual(context.surfaceForWrapper[record.address],pointer) }
            expected.replaceSubrange(0..<4,with:[pointer == 0 ? 0 : 1,0,0,0])
            XCTAssertEqual(bitmap.storage.bytes,expected);XCTAssertEqual(bitmap.storage.defined,try r.blob(record.mask).map { $0 != 0 })
            let constructorIndex=try XCTUnwrap(history.firstIndex { $0.kind=="constructor" && $0.wrapper==record.address })
            let h=history[constructorIndex]
            // Event indices restart at each call; the enclosing constructor's
            // immediately preceding loader return preserves call provenance.
            let loader=try XCTUnwrap(history[..<constructorIndex].last { $0.kind=="loader" && $0.eventStart>=h.eventStart && $0.eventEnd<=h.eventEnd })
            XCTAssertEqual(bitmap.input.path,loader.path);XCTAssertEqual(bitmap.input.present,loader.result != 0);XCTAssertFalse(bitmap.optional)
            if loader.result==0 { XCTAssertNil(context.surfaceForWrapper[record.address]) }
            else if pointer==0 {
                XCTAssertEqual(context.surfaceForWrapper[record.address],loader.result)
                XCTAssertEqual(context.surfacesReleased[loader.result],true)
            }
            if let live=c.wrapperLive?[String(record.address)] { XCTAssertEqual(state.releasedBitmaps.contains(r.catalog.bitmaps.count+i),!live) }
        }
        compareContext(context)
    }
    /// Controlled request bookkeeping at the reached prefix; this is separate
    /// from the outer caller's committed state and real device lifetimes.
    func compareContext(_ context: Base.Context) {
        XCTAssertEqual(context.imagesDeleted,Dictionary(uniqueKeysWithValues:c.images.map { (UInt32($0.key)!,$0.value.deleted) }))
        XCTAssertEqual(context.surfacesReleased,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.released) }))
        XCTAssertEqual(context.surfaceDescriptions,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.description) }))
        XCTAssertEqual(context.dcs,Dictionary(uniqueKeysWithValues:c.dcs.map { (UInt32($0.key)!,$0.value) }))
    }
}
