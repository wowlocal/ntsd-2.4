import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

/// Comparison adapter for the two War resources. The reference is the pinned
/// NTSD EXE/lib/VC80 controlled Unicorn capture, not a Windows graphics device.
/// Allocation backing and numeric API responses are declared inputs; DIB
/// metadata, descriptors and ownership are produced independently by Native.
final class OriginalWarPreparationMenuSurfaceAdapter {
    typealias Test = OriginalLibWarPreparationTests
    typealias Base = OriginalCharacterMenuSurfaceTests
    typealias API = OriginalBitmapSurfaceLoading
    let c: Test.WarGraphics,r: Test.Resources,control: Bool
    let paths=["BATTLEMODE","BATTLETROOPS"]
    var index=0,allocations=0,shadow: [UInt8]=[]
    init(_ c: Test.WarGraphics,_ r: Test.Resources,control: Bool) { self.c=c;self.r=r;self.control=control }
    func token(_ i: Int) -> UInt32 { 0x76000020+UInt32(control ? 1-i : i)*0x2000 }
    func pattern() -> [UInt8] { (0..<0x1f50).map { control ? UInt8(($0*37+11)&255) : 0xa5 } }
    func next(_ kind: String) throws -> Base.Event {
        guard index<c.events.count else { throw Test.Stop.unexpected }
        let e=c.events[index];index += 1
        guard (e.kind ?? e.request?.kind) == kind else { XCTFail("War resource event\(index-1): \(kind)");throw Test.Stop.unexpected }
        return e
    }
    func allocate(_ i: Int,_ context: inout Base.Context) throws -> OriginalInterfaceAllocation {
        guard (0..<2).contains(i) else { throw Test.Stop.unexpected }
        let e=try next("allocate"),address=token(i),backing=pattern()
        XCTAssertEqual(i,allocations);allocations += 1
        XCTAssertEqual(e.index,i);XCTAssertEqual(e.address,address);XCTAssertEqual(e.count,backing.count)
        XCTAssertEqual(c.allocations[i].address,address)
        XCTAssertEqual(backing,try r.blob(XCTUnwrap(c.allocations[i].backing)))
        context.currentWrapper=address;context.allocations.append(address)
        return .init(address:address,backing:backing)
    }
    func observe(_ e: OriginalInterfaceEvent,_ context: inout Base.Context) throws {
        if e.kind == .allocate { XCTAssertEqual(e.arguments,[0x1f50]);return }
        let expected=try next("construct"),i=try XCTUnwrap(expected.index)
        guard paths.indices.contains(i) else { throw Test.Stop.unexpected }
        XCTAssertEqual(e.kind,.construct);XCTAssertEqual(e.arguments,[token(i),0x40,0])
        XCTAssertEqual(e.strings,[Array(paths[i].utf8)])
        XCTAssertEqual(expected.path,paths[i]);XCTAssertEqual(expected.address,context.currentWrapper)
    }
    func bitmapBytes(_ path: String) throws -> [UInt8] {
        let asset=try XCTUnwrap(r.corpus.assets[path]),dib=try r.blob(asset.raw)
        XCTAssertEqual(asset.kind,"embedded")
        guard dib.count>=40 else { throw Test.Stop.unexpected }
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
    func perform(_ q: API.Request,_ context: inout Base.Context) throws -> API.Response {
        let e=try next(q.kind),expected=try XCTUnwrap(e.request),captured=try XCTUnwrap(e.response)
        XCTAssertEqual(q.words,expected.words);XCTAssertEqual(q.strings,expected.strings);XCTAssertEqual(q.defined,expected.defined)
        if let mask=q.defined {
            let actual=try XCTUnwrap(q.bytes),bytes=try XCTUnwrap(expected.bytes)
            XCTAssertEqual(actual.count,bytes.count);XCTAssertEqual(actual.count,mask.count)
            for i in mask.indices { XCTAssertEqual(actual[i],mask[i] ? bytes[i] : 0,"Native private API backing") }
        } else { XCTAssertEqual(q.bytes,expected.bytes) }
        XCTAssertFalse(shadow.isEmpty)
        XCTAssertEqual(shadow,try r.blob(XCTUnwrap(e.globals)),"War resource complete globals")
        var response=captured;context.requested.append(try XCTUnwrap(e.key))
        switch q.kind {
        case "image":if captured.result != 0 {
            let path=String(decoding:q.strings[0],as:UTF8.self),image=UInt32(bitPattern:captured.result)
            _=try bitmapBytes(path);context.imagePaths[image]=path;context.imagesDeleted[image]=false
        }
        case "getObject":if captured.result != 0 {
            response = .init(result:captured.result,writes:[.init(bytes:try bitmapBytes(XCTUnwrap(context.imagePaths[q.words[0]])))])
        }
        case "createSurface":if let surface=captured.output {
            context.surfaceDescriptions[surface]=try XCTUnwrap(q.bytes);context.surfacesReleased[surface]=false
            context.surfaceForWrapper[context.currentWrapper]=surface
        }
        case "description":if captured.result>=0 {
            response = .init(result:captured.result,writes:[.init(bytes:try XCTUnwrap(context.surfaceDescriptions[q.words[0]]))])
        }
        case "release":context.surfacesReleased[q.words[0]]=true
        case "createDC":context.dcs[UInt32(bitPattern:captured.result)]=false
        case "deleteDC":context.dcs[q.words[0]]=true
        case "deleteObject":context.imagesDeleted[q.words[0]]=captured.result != 0
        default:break
        }
        XCTAssertEqual(response,captured,"Owned War platform output");return response
    }
    func compareStorage(_ bitmap: OriginalLoadedBitmap,_ record: OriginalStateRecord,_ wrapper: UInt32,_ context: Base.Context) throws {
        var expected=record
        let surface=try XCTUnwrap(context.surfaceForWrapper[wrapper])
        XCTAssertEqual(try expected.integer(at:0,as:UInt32.self),surface)
        try expected.write(UInt32(1),at:0)
        XCTAssertEqual(bitmap.storage.bytes,expected.bytes,"War bitmap full backing")
        XCTAssertEqual(bitmap.storage.defined,expected.defined,"War bitmap full mask")
        let i=try XCTUnwrap((0..<2).first { token($0)==wrapper })
        XCTAssertEqual(bitmap.input.path,paths[i]);XCTAssertTrue(bitmap.input.present);XCTAssertFalse(bitmap.optional)
    }
    func compareOwned(_ owned: OriginalWarMenuMemory,_ records: [Test.Record],_ context: Base.Context) throws {
        let mapped=Dictionary(uniqueKeysWithValues:records.map { ($0.address,$0) })
        let wrappers=records.filter { record in (0..<2).contains(where:{ token($0)==record.address }) }
        XCTAssertEqual(wrappers.count,owned.bitmaps.count)
        for record in wrappers {
            XCTAssertEqual(record.live,true)
            try compareStorage(XCTUnwrap(owned.bitmaps[record.address]),r.record(record),record.address,context)
        }
        let source=try r.record(XCTUnwrap(mapped[UInt32(OriginalMatchPreparation.globalBase)]))
        var bindings: [Int:Int]=[:]
        for unit in 0..<11 {
            let pointer=try source.integer(at:0x451b38+unit*4-OriginalMatchPreparation.globalBase,as:UInt32.self)
            if pointer != 0 { bindings[unit]=try XCTUnwrap(r.corpus.roster.entries.first { $0.address==pointer }).ordinal }
        }
        XCTAssertEqual(owned.unitObjects,bindings)
    }
    func compare(_ owned: OriginalWarMenuMemory,_ context: Base.Context) throws {
        XCTAssertEqual(index,c.events.count)
        XCTAssertEqual(allocations,c.events.filter { $0.kind=="allocate" }.count)
        XCTAssertEqual(c.allocations.count,owned.bitmaps.count);XCTAssertEqual(c.records.count,owned.bitmaps.count)
        for record in c.records {
            XCTAssertEqual(record.count,0x1f50);XCTAssertEqual(try r.blob(record.initial),pattern())
            let expected=try OriginalStateRecord(bytes:r.blob(record.bytes),defined:r.blob(record.mask).map { $0 != 0 })
            try compareStorage(XCTUnwrap(owned.bitmaps[record.address]),expected,record.address,context)
        }
        XCTAssertEqual(context.imagesDeleted,Dictionary(uniqueKeysWithValues:c.images.map { (UInt32($0.key)!,$0.value.deleted) }))
        XCTAssertEqual(context.surfacesReleased,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.released) }))
        XCTAssertEqual(context.surfaceDescriptions,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.description) }))
        XCTAssertEqual(context.dcs,Dictionary(uniqueKeysWithValues:c.dcs.map { (UInt32($0.key)!,$0.value) }))
    }
}
