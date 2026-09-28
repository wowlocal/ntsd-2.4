import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform

@MainActor final class OriginalMacBitmapBackendTests: XCTestCase {
    typealias D = OriginalMacDisplayBackendTests
    typealias B = OriginalMacDisplayBackend
    typealias S = OriginalMacBitmapService
    typealias E = S.Exchange
    typealias API = OriginalBitmapSurfaceLoading
    typealias Q = API.Request
    enum Stop: Error { case limit, late }
    func service(_ run: D.Run,_ inputs: OriginalApplicationStartupInputs) -> S {
        S(backend:run.setup.display,inputs:.init(resources:inputs.bitmaps,
            files:Dictionary(uniqueKeysWithValues:inputs.bitmaps.keys.map { ($0,B.BitmapInputs.File.missing) })))
    }
    func call(_ service: S,_ q: Q) throws -> API.Response {
        let e = E();var c = try e.snapshot.cursor()
        do { _ = try c.response(for:.init(q));throw Stop.limit }
        catch let ticket as E.RequestNeeded { try service.serve(e.claim(ticket),on:e) }
        c = try e.snapshot.cursor();let result = try c.response(for:.init(q));_ = try e.finish(c);return result
    }
    func construct(_ service: S,_ name: String,_ device: UInt32,optional: Bool = false,late: Bool = false) throws -> (OriginalLoadedBitmap,E) {
        let e = E();var failed = false
        for _ in 0..<80 {
            var cursor = try e.snapshot.cursor()
            do {
                let result = try OriginalBitmapConstructor.constructWithSurfaceLoading(path:name,optional:optional,
                    backing:Array(repeating:0xa7,count:0x1f50),device:device,flags:0x40,context:&cursor,
                    perform:{ q,c in try c.response(for:.init(q)) })
                if late && !failed {
                    failed = true;let count = service.backend.bitmapOperations.count
                    XCTAssertEqual(e.snapshot.status,.open)
                    // A complete retry must consume saved replies without physical work.
                    var replay = try e.snapshot.cursor()
                    _ = try OriginalBitmapConstructor.constructWithSurfaceLoading(path:name,optional:optional,
                        backing:Array(repeating:0xa7,count:0x1f50),device:device,flags:0x40,context:&replay,
                        perform:{ q,c in try c.response(for:.init(q)) })
                    XCTAssertEqual(service.backend.bitmapOperations.count,count)
                    throw Stop.late
                }
                _ = try e.finish(cursor);XCTAssertEqual(failed,late);return (result,e)
            } catch let needed as E.RequestNeeded { try service.serve(e.claim(needed),on:e) }
            catch Stop.late { XCTAssertEqual(e.snapshot.status,.open) }
        }
        throw Stop.limit
    }
    func surface(_ e: E) throws -> UInt32 {
        try XCTUnwrap(e.snapshot.receipts.first { $0.request.value.kind == "createSurface" }?.response.output)
    }
    func check(_ result: B.Pixels,_ input: OriginalDIBPixels) {
        XCTAssertEqual(result.width,input.width);XCTAssertEqual(result.height,input.height)
        XCTAssertEqual(result.defined,input.defined)
        // Independent XRGB packing from the accepted RGB bytes, not backend pixels.
        let words = stride(from:0,to:input.rgb.count,by:3).map { i in
            UInt32(input.rgb[i])*65536+UInt32(input.rgb[i+1])*256+UInt32(input.rgb[i+2])
        }
        XCTAssertEqual(result.values,words)
    }
    func testAllOriginalDIBsThroughWholeConstructorOnStartupDisplay() throws {
        let d = D(),r = try d.run(late:false);defer { try? d.close(r) }
        let inputs = try OriginalApplicationStartupInputs.bundled(),s = service(r,inputs),device = try d.ids(r).0
        let baseline = s.backend.allocatedBytes
        var count = 0,unknown = 0
        for name in inputs.bitmaps.keys.sorted() {
            let bitmap = try XCTUnwrap(inputs.bitmaps[name]),(loaded,e) = try construct(s,name,device)
            let token = try surface(e),pixels = try s.backend.pixels(token)
            XCTAssertEqual(loaded.input.width,bitmap.width);XCTAssertEqual(loaded.input.height,bitmap.height)
            XCTAssertTrue(loaded.input.present);XCTAssertEqual(try loaded.storage.integer(at:0,as:UInt32.self),1)
            XCTAssertTrue(loaded.storage.defined.prefix(12).allSatisfy { $0 })
            XCTAssertTrue(loaded.storage.defined.dropFirst(12).allSatisfy { !$0 })
            check(pixels,bitmap.pixels);unknown += pixels.defined.filter { !$0 }.count;count += 1
            XCTAssertEqual(try s.backend.bitmapObservation(token).colorKey,[0,0])
            XCTAssertNil(try s.backend.bitmapObservation(token).activeDC)
            XCTAssertEqual(e.snapshot.receipts.map { $0.request.value.kind },["module","image","module","image","getObject","createSurface","restore","createDC","selectObject","getObject","description","getDC","stretch","releaseDC","deleteDC","deleteObject","colorKey"])
            let object = try XCTUnwrap(e.snapshot.receipts.first { $0.request.value.kind == "getObject" })
            XCTAssertEqual(object.response.writes.map(\.offset),[4]);XCTAssertEqual(object.response.writes.first?.bytes.count,16)
            let image = try XCTUnwrap(e.snapshot.receipts.first { $0.request.value.kind == "image" && $0.response.result != 0 })
            XCTAssertEqual(try s.backend.observation(UInt32(bitPattern:image.response.result)).references,0)
            if pixels.defined.allSatisfy({ $0 }) { XCTAssertEqual(try s.backend.image(token).width,pixels.width) }
            else { XCTAssertThrowsError(try s.backend.image(token)) { XCTAssertEqual($0 as? B.Boundary,.unknownPixel) } }
            XCTAssertEqual(try call(s,.init("release",[token])).result,0)
            XCTAssertEqual(s.backend.allocatedBytes,baseline)
            check(pixels,bitmap.pixels) // owned snapshot survives native surface release
            withExtendedLifetime(e) {}
        }
        XCTAssertEqual(count,inputs.bitmaps.count);XCTAssertGreaterThan(count,20);XCTAssertGreaterThan(unknown,0)
        print("Native whole bitmap constructors",count,"unknown original pixels",unknown)
    }
    func testLateRetryMissingFileAndExplicitFormat() throws {
        let d = D(),r = try d.run(late:false);defer { try? d.close(r) }
        let inputs = try OriginalApplicationStartupInputs.bundled(),device = try d.ids(r).0
        let name = try XCTUnwrap(inputs.bitmaps.keys.sorted().first),bitmap = try XCTUnwrap(inputs.bitmaps[name])
        let s = service(r,inputs),(_,retained) = try construct(s,name,device,late:true)
        XCTAssertEqual(s.backend.bitmapOperations.count,17)
        let token = try surface(retained);check(try s.backend.pixels(token),bitmap.pixels)
        let missing = S(backend:s.backend,inputs:.init(resources:[:],files:["missing.bmp":.missing]))
        let (absent,e) = try construct(missing,"missing.bmp",device,optional:true)
        XCTAssertFalse(absent.input.present);XCTAssertNil(absent.input.width);XCTAssertNil(absent.input.height)
        XCTAssertEqual(e.snapshot.receipts.count,4);XCTAssertTrue(absent.storage.defined.dropFirst(4).allSatisfy { !$0 })
        // Prepare an actual BMP container from immutable original DIB bytes.
        var header = try OriginalStateRecord(bytes:Array(repeating:0,count:14),defined:Array(repeating:true,count:14))
        try header.write(UInt16(0x4d42),at:0);try header.write(UInt32(14+bitmap.dib.count),at:2)
        try header.write(UInt32(14+bitmap.pixelOffset),at:10)
        let file = try OriginalApplicationStartupInputs.Bitmap(bitmapFile:header.bytes+bitmap.dib)
        let fileService = S(backend:s.backend,inputs:.init(resources:[:],files:["original-colors.bmp":.bitmap(file)]))
        let exchange = E();var loaded: UInt32?
        for _ in 0..<80 {
            var cursor = try exchange.snapshot.cursor()
            do {
                loaded = try API.load(path:Array("original-colors.bmp".utf8),device:device,flags:0x40,
                    pixelFormat:[32,0x40,0,32,0xff0000,0xff00,0xff,0],context:&cursor,
                    perform:{ q,c in try c.response(for:.init(q)) })
                _ = try exchange.finish(cursor);break
            } catch let needed as E.RequestNeeded { try fileService.serve(exchange.claim(needed),on:exchange) }
        }
        check(try s.backend.pixels(XCTUnwrap(loaded)),bitmap.pixels)
        XCTAssertEqual(exchange.snapshot.receipts.filter { $0.request.value.kind == "image" }.count,1)
        let desc = try XCTUnwrap(exchange.snapshot.receipts.first { $0.request.value.kind == "createSurface" }?.request.value)
        XCTAssertEqual(Array(try XCTUnwrap(desc.bytes)[72..<76]),[0,0,0,0])
        XCTAssertThrowsError(try s.backend.prepareBitmap(.init("image",[UInt32(bitPattern:retained.snapshot.receipts[0].response.result),0,0,0,0x2010],strings:[Array("undeclared".utf8)]),inputs:s.inputs))
        XCTAssertThrowsError(try s.backend.prepareBitmap(.init("message",[0,0],strings:[[],[]]),inputs:s.inputs))
        XCTAssertEqual(try call(s,.init("release",[token])).result,0)
        XCTAssertEqual(try call(s,.init("release",[XCTUnwrap(loaded)])).result,0)
    }
    func testSelectionAcquisitionMasksAndAtomicRectangles() throws {
        let d = D(),r = try d.run(late:false);defer { try? d.close(r) }
        // Two source pixels: one explicitly red; an RLE EOB leaves the other unknown.
        var dib = try OriginalStateRecord(bytes:Array(repeating:0,count:52),defined:Array(repeating:true,count:52))
        try dib.write(UInt32(40),at:0);try dib.write(Int32(2),at:4);try dib.write(Int32(1),at:8)
        try dib.write(UInt16(1),at:12);try dib.write(UInt16(8),at:14);try dib.write(UInt32(1),at:16)
        try dib.write(UInt32(4),at:20);try dib.write(UInt32(2),at:32);try dib.write(UInt8(255),at:46)
        for (i,v) in [1,1,0,1].enumerated().map({ ($0.offset,UInt8($0.element)) }) { try dib.write(v,at:48+i) }
        let input = try OriginalApplicationStartupInputs.Bitmap(dib:dib.bytes)
        let s = S(backend:r.setup.display,inputs:.init(resources:["control":input],files:["control":.missing]))
        let (_,e) = try construct(s,"control",d.ids(r).0),token = try surface(e)
        XCTAssertEqual(try s.backend.pixels(token).values,[0xff0000,0]);XCTAssertEqual(try s.backend.pixels(token).defined,[true,false])
        let module = UInt32(bitPattern:try call(s,.init("module",[0])).result)
        let bitmap = UInt32(bitPattern:try call(s,.init("image",[module,0,0,0,0x2000],strings:[Array("control".utf8)])).result)
        let dc = UInt32(bitPattern:try call(s,.init("createDC",[0])).result)
        let other = UInt32(bitPattern:try call(s,.init("createDC",[0])).result)
        let stock = try call(s,.init("selectObject",[dc,bitmap])).result;XCTAssertNotEqual(stock,0)
        XCTAssertEqual(try call(s,.init("selectObject",[other,bitmap])).result,0)
        XCTAssertEqual(try call(s,.init("deleteObject",[bitmap])).result,0)
        let target = try XCTUnwrap(call(s,.init("getDC",[token])).output)
        XCTAssertThrowsError(try s.backend.prepareBitmap(.init("getDC",[token]),inputs:s.inputs))
        XCTAssertThrowsError(try s.backend.prepareBitmap(.init("release",[token]),inputs:s.inputs))
        let before = try s.backend.pixels(token),operations = s.backend.bitmapOperations.count
        for words: [UInt32] in [[target,1,0,2,1,dc,0,0,2,1,0xcc0020], [target,0,0,2,1,dc,0,0,1,1,0xcc0020], [target,0,0,2,1,dc,UInt32.max,0,2,1,0xcc0020]] {
            XCTAssertThrowsError(try s.backend.prepareBitmap(.init("stretch",words),inputs:s.inputs))
        }
        XCTAssertEqual(try s.backend.pixels(token),before);XCTAssertEqual(s.backend.bitmapOperations.count,operations)
        XCTAssertEqual(try call(s,.init("stretch",[target,0,0,1,1,dc,1,0,1,1,0xcc0020])).result,1)
        XCTAssertEqual(try s.backend.pixels(token).defined,[false,false]);XCTAssertEqual(before.defined,[true,false])
        XCTAssertEqual(try call(s,.init("releaseDC",[token,target])).result,0)
        XCTAssertThrowsError(try s.backend.prepareBitmap(.init("releaseDC",[token,target]),inputs:s.inputs))
        XCTAssertEqual(try call(s,.init("selectObject",[dc,UInt32(bitPattern:stock)])).result,Int32(bitPattern:bitmap))
        XCTAssertEqual(try call(s,.init("deleteObject",[bitmap])).result,1)
        for handle in [dc,other] { XCTAssertEqual(try call(s,.init("deleteDC",[handle])).result,1) }
        XCTAssertEqual(try call(s,.init("release",[token])).result,0)
        withExtendedLifetime(e) {}
    }
    func ticket(_ e: E,_ q: Q) throws -> E.Permit {
        var c = try e.snapshot.cursor()
        do { _ = try c.response(for:.init(q));throw Stop.limit }
        catch let needed as E.RequestNeeded { return try e.claim(needed) }
    }
    func testServiceProtocolAndAllocationFailure() throws {
        let d = D(),r = try d.run(late:false);defer { try? d.close(r) }
        let inputs = try OriginalApplicationStartupInputs.bundled(),s = service(r,inputs),e = E(),other = E()
        let p = try ticket(e,.init("module",[0])),foreign = try ticket(other,.init("module",[0]))
        let allocations = s.backend.allocationCount
        XCTAssertThrowsError(try s.serve(foreign,on:e)) { XCTAssertEqual($0 as? E.Boundary,.foreignOwner) }
        XCTAssertEqual(s.backend.allocationCount,allocations)
        try s.serve(p,on:e);XCTAssertEqual(s.backend.allocationCount,allocations+1)
        XCTAssertThrowsError(try s.serve(p,on:e));XCTAssertEqual(s.backend.allocationCount,allocations+1)
        other.cancel();XCTAssertThrowsError(try s.serve(foreign,on:other)) { XCTAssertEqual($0 as? E.Boundary,.closed(.cancelled)) }
        let a = try s.backend.prepareBitmap(.init("module",[0]),inputs:s.inputs)
        let bounded = B(windows:r.setup.window.backend,maximumBytes:0)
        XCTAssertThrowsError(try bounded.performBitmap(a)) { XCTAssertEqual($0 as? B.Boundary,.foreignPreparation) }
        _ = try s.backend.performBitmap(a)
        XCTAssertThrowsError(try s.backend.performBitmap(a)) { XCTAssertEqual($0 as? B.Boundary,.repeatedPreparation) }
        let draw = try XCTUnwrap(bounded.perform(bounded.prepare(.init("directDrawCreate",[0,0x457578,0]))).response.output)
        _ = try bounded.perform(bounded.prepare(.init("cooperativeLevel",[draw,r.setup.controls.window,8])))
        let b = S(backend:bounded,inputs:s.inputs),name = try XCTUnwrap(inputs.bitmaps.keys.sorted().first),exchange = E()
        var rejected = false
        for _ in 0..<20 {
            var cursor = try exchange.snapshot.cursor()
            do {
                _ = try OriginalBitmapConstructor.constructWithSurfaceLoading(path:name,optional:false,
                    backing:Array(repeating:0xa7,count:0x1f50),device:draw,flags:0x40,context:&cursor,
                    perform:{ q,c in try c.response(for:.init(q)) })
                XCTFail("Zero-budget surface unexpectedly returned");break
            } catch let needed as E.RequestNeeded {
                do { try b.serve(exchange.claim(needed),on:exchange) }
                catch B.Boundary.allocationBudget { rejected = true;break }
            }
        }
        XCTAssertTrue(rejected);XCTAssertEqual(exchange.snapshot.status,.indeterminate)
        XCTAssertEqual(bounded.allocatedBytes,0);XCTAssertEqual(exchange.snapshot.failure?.request.value.kind,"createSurface")
        XCTAssertFalse(try XCTUnwrap(exchange.snapshot.failure).resources.isEmpty)
        XCTAssertThrowsError(try exchange.snapshot.cursor())
    }
}
