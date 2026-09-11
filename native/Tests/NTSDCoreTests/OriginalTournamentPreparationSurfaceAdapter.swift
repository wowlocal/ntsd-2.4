import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

/// Declared platform responses around actual source bitmap helpers. Native
/// image metadata comes from pinned raw BMP bytes, never source API after-state.
final class OriginalTournamentPreparationSurfaceAdapter {
    typealias Test = OriginalLibTournamentPreparationTests
    typealias Base = OriginalCharacterMenuSurfaceTests
    typealias API = OriginalBitmapSurfaceLoading
    let c: Test.PreparationGraphics,r: Test.Resources
    var index=0,allocation=0,globalKeys: [String]=[]
    init(_ c: Test.PreparationGraphics,_ r: Test.Resources) { self.c=c;self.r=r }
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
                   observe: () throws -> Void) throws -> OriginalLoadedBitmap {
        let token: UInt32=0x76000020+UInt32(allocation)*0x2000
        let e=try next("allocate");XCTAssertEqual(e.index,allocation);XCTAssertEqual(e.address,token);XCTAssertEqual(e.count,0x1f50)
        XCTAssertEqual(c.allocations[allocation].address,token)
        XCTAssertEqual(backing,[UInt8](repeating:0xa5,count:0x1f50));XCTAssertEqual(backing,try r.blob(XCTUnwrap(c.allocations[allocation].backing)))
        allocation += 1;context.currentWrapper=token;context.allocations.append(token);try observe()
        let constructor=try next("construct");XCTAssertEqual(constructor.address,token);XCTAssertEqual(constructor.path,path);XCTAssertFalse(optional);try observe()
        return try OriginalBitmapConstructor.constructWithSurfaceLoading(path:path,optional:optional,backing:backing,device:0x32001000,flags:0x40,context:&context) { q,g in
            let e=try self.next(q.kind),expected=try XCTUnwrap(e.request),captured=try XCTUnwrap(e.response)
            XCTAssertEqual(q.words,expected.words);XCTAssertEqual(q.strings,expected.strings);XCTAssertEqual(q.defined,expected.defined)
            if let mask=q.defined {
                let actual=try XCTUnwrap(q.bytes),bytes=try XCTUnwrap(expected.bytes)
                for i in mask.indices { XCTAssertEqual(actual[i],mask[i] ? bytes[i] : 0,"Native private API backing") }
            }
            self.globalKeys.append(try XCTUnwrap(e.globals))
            var response=captured;g.requested.append(try XCTUnwrap(e.key))
            switch q.kind {
            case "image":if captured.result != 0 {
                let path=String(decoding:q.strings[0],as:UTF8.self),image=UInt32(bitPattern:captured.result)
                _=try self.bitmapBytes(path);g.imagePaths[image]=path;g.imagesDeleted[image]=false
            }
            case "getObject":if captured.result != 0 {
                response = .init(result:captured.result,writes:[.init(bytes:try self.bitmapBytes(XCTUnwrap(g.imagePaths[q.words[0]])))])
            }
            case "createSurface":if let surface=captured.output {
                g.surfaceDescriptions[surface]=try XCTUnwrap(q.bytes);g.surfacesReleased[surface]=false;g.surfaceForWrapper[g.currentWrapper]=surface
            }
            case "description":if captured.result>=0 { response = .init(result:captured.result,writes:[.init(bytes:try XCTUnwrap(g.surfaceDescriptions[q.words[0]]))]) }
            case "release":g.surfacesReleased[q.words[0]]=true
            case "createDC":g.dcs[UInt32(bitPattern:captured.result)]=false
            case "deleteDC":g.dcs[q.words[0]]=true
            case "deleteObject":g.imagesDeleted[q.words[0]]=captured.result != 0
            default:break
            }
            XCTAssertEqual(response,captured,"Owned platform output");try observe();return response
        }
    }
    func compareGlobals(_ globals: OriginalStateRecord) throws {
        // All BG API requests precede434765 and change no game globals. Each
        // captured request independently checks this whole native stage value.
        for key in Set(globalKeys) { XCTAssertEqual(globals.bytes,Array(try r.blob(key).prefix(globals.bytes.count))) }
    }
    func compare(_ state: OriginalMatchPreparation,_ context: Base.Context) throws {
        XCTAssertEqual(index,c.events.count);XCTAssertEqual(allocation,c.allocations.count)
        XCTAssertEqual(state.bitmaps.count,r.catalog.bitmaps.count+allocation)
        for (i,record) in c.records.enumerated() {
            let bitmap=state.bitmaps[r.catalog.bitmaps.count+i],surface=try XCTUnwrap(context.surfaceForWrapper[record.address])
            var expected=try r.blob(record.bytes)
            XCTAssertEqual(Array(expected.prefix(4)),(0..<4).map { UInt8(truncatingIfNeeded:surface >> ($0*8)) });expected.replaceSubrange(0..<4,with:[1,0,0,0])
            XCTAssertEqual(bitmap.storage.bytes,expected);XCTAssertEqual(bitmap.storage.defined,try r.blob(record.mask).map { $0 != 0 })
            let h=try XCTUnwrap(c.helpers.first { $0.kind=="constructor" && $0.wrapper==record.address })
            let loader=try XCTUnwrap(c.helpers.first { $0.kind=="loader" && $0.eventStart>=h.eventStart && $0.eventEnd<=h.eventEnd })
            XCTAssertEqual(bitmap.input.path,loader.path);XCTAssertTrue(bitmap.input.present);XCTAssertFalse(bitmap.optional)
        }
        XCTAssertEqual(context.imagesDeleted,Dictionary(uniqueKeysWithValues:c.images.map { (UInt32($0.key)!,$0.value.deleted) }))
        XCTAssertEqual(context.surfacesReleased,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.released) }))
        XCTAssertEqual(context.surfaceDescriptions,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.description) }))
        XCTAssertEqual(context.dcs,Dictionary(uniqueKeysWithValues:c.dcs.map { (UInt32($0.key)!,$0.value) }))
    }
}
