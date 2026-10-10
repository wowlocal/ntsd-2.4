import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform
@testable import NTSDRuntime

@MainActor final class OriginalMacFrontRasterTests: XCTestCase {
    typealias D = OriginalMacDisplayBackendTests
    typealias M = OriginalMacBitmapBackendTests
    typealias G = OriginalApplicationObservedGraphicsTests
    typealias W = OriginalMacWindowGeometryTests
    typealias B = OriginalMacDisplayBackend
    typealias Service = OriginalMacFrontService
    typealias E = OriginalMenuGraphicsRequestExchange
    typealias Event = OriginalFrontScreenEvent
    enum Stop: Error { case limit, late }
    func fill(_ target: UInt32,_ color: UInt32,_ rect: [Int32]) throws -> Event {
        var q = Event("fill")
        q.fill = try OriginalSurfaceFilling.request(target:target,x:rect[0],y:rect[1],
            width:rect[2]-rect[0],height:rect[3]-rect[1],color:color,backing:Array(repeating:0xa7,count:100))
        return q
    }
    func blt(_ source: UInt32,_ target: UInt32,_ from: [Int32],_ to: [Int32],key: Bool = true,mirror: Bool = false) throws -> Event {
        var q = Event("blit"),effects: [UInt8]?
        if mirror {
            var r = try OriginalStateRecord(bytes:Array(repeating:0,count:100),defined:Array(repeating:true,count:100))
            try r.write(UInt32(100),at:0);try r.write(UInt32(2),at:4);effects = r.bytes
        }
        q.blit = .init(sourceSurface:source,targetSurface:target,source:from,destination:to,
            flags:0x1000000 | (key ? 0x8000 : 0) | (mirror ? 0x800 : 0),effects:effects)
        return q
    }
    func present(_ primary: UInt32,_ back: UInt32,_ rect: [Int32]?,source: [Int32]? = nil) -> Event {
        let rectangles = [rect,source].compactMap { $0 }.map { W().bytes($0) }
        return .init("method",[primary,0x14,rect == nil ? 0 : 0x453ccc,back,source == nil ? 0 : 0x1234,0x1000000,0],rectangles)
    }
    func perform(_ b: B,_ q: Event) throws -> B.FrontServed { try b.performFront(b.prepareFront(q)) }
    // Test-only destination calculation consumes Core-owned source colors, never
    // backend source pixels or an expected frame imported into the renderer.
    func expected(_ commands: [OriginalApplicationGraphics.Command],width: Int,height: Int) throws -> ([UInt32],[Bool]) {
        var words = Array(repeating:UInt32(0),count:width*height),known = Array(repeating:false,count:width*height)
        for command in commands {
            guard let event = command.event else { continue }
            if let f = event.fill {
                let r = try OriginalStateRecord(bytes:f.effects,defined:f.defined),color = try r.integer(at:80,as:UInt32.self)
                for i in words.indices {
                    let x = i%width,y = i/width
                    if x >= f.rectangle[0] && x < f.rectangle[2] && y >= f.rectangle[1] && y < f.rectangle[3] { words[i] = color;known[i] = true }
                }
            } else if let b = event.blit {
                let colors = try XCTUnwrap(command.sourceColors)
                XCTAssertEqual(b.source[2]-b.source[0],b.destination[2]-b.destination[0]);XCTAssertEqual(b.source[3]-b.source[1],b.destination[3]-b.destination[1])
                for i in words.indices {
                    let x = i%width,y = i/width
                    guard x >= b.destination[0] && x < b.destination[2] && y >= b.destination[1] && y < b.destination[3] else { continue }
                    let sx = Int(b.source[0])+x-Int(b.destination[0]),sy = Int(b.source[1])+y-Int(b.destination[1]),a = sy*colors.width+sx
                    guard colors.defined[a] else { known[i] = false;continue }
                    let j = a*3,value = UInt32(colors.rgb[j])*65536+UInt32(colors.rgb[j+1])*256+UInt32(colors.rgb[j+2])
                    if b.flags & 0x8000 == 0 || value != 0 { words[i] = value;known[i] = true }
                }
            }
        }
        return (words,known)
    }
    func whole(_ failure: String? = nil) throws -> G.Run {
        let ready = try W().ready(),r = ready.run,packet = ready.menu
        _ = try W().move(ready)
        let host = r.host,before = host.snapshot,old = try XCTUnwrap(before.session)
        var windowIndex = 0,diagnostics: [[UInt8]] = []
        let driver = G.Driver(host:host),bitmap = G.O().service(r,ready.package)
        let service = Service(backend:r.setup.display,diagnostic:{ q in
            guard packet.surface.indices.contains(windowIndex) else { throw Stop.limit }
            diagnostics.append(q.strings[0])
            // Saved declared API input response, not an expected after-state.
            return packet.surface[windowIndex]
        })
        var served: [OriginalMenuGraphicsRequest] = [],checkpoints: [(G.S.Checkpoint,Int32?)] = [],failed = false,negative = 0,presentation = 0
        for _ in 0..<1200 {
            var points: [(G.S.Checkpoint,Int32?)] = []
            do {
                switch try driver.resume(prepare:{ _,_ in G().observed(packet) },graphicsObserve:{ q in
                    if failure == "graphics" && !failed && q.event?.kind == "blit" { throw Stop.late }
                },checkpoint:{ c,_,v in points.append((c,v)) },beforePublication:{ _ in
                    if failure == "publication" && !failed { throw Stop.late }
                }) {
                case .request(let permit):
                    G.B.same(try XCTUnwrap(host.snapshot.session),old);XCTAssertEqual(host.pendingBatchCount,0)
                    switch permit.request {
                    case .bitmap:try bitmap.serve(permit,on:driver)
                    case .window:try service.serve(permit,on:driver);windowIndex += 1
                    case .front(_,let q):
                        if q.kind == "getDC" {
                            // Declared negative GetDC for this Core comparison profile; the
                            // backend is not asked, so no DC is held. The backend's own text
                            // path is testSurfaceTextDrawsBothRoutinesWithTheDeclaredFont.
                            try driver.beginService(permit);try driver.answer(permit,response:.front(.init(result:-7,output:0x12345678)));negative += 1
                        } else if q.kind == "method" && q.arguments[1] == 0x14 {
                            let primary = try D().ids(r).1,pixels = try r.setup.display.pixels(primary),count = r.setup.display.frontOperations.count
                            XCTAssertThrowsError(try service.serve(permit,on:driver)) { XCTAssertEqual($0 as? B.Boundary,.unknownPixel) }
                            XCTAssertFalse(driver.exchangeSnapshot.serviceStarted);XCTAssertEqual(try r.setup.display.pixels(primary),pixels)
                            XCTAssertEqual(r.setup.display.frontOperations.count,count)
                            // Explicit controlled reply for Core comparison only, not presentation.
                            try driver.beginService(permit);try driver.answer(permit,response:.front(.init(result:0)));presentation += 1
                        } else { try service.serve(permit,on:driver) }
                    }
                    served.append(permit.request)
                case .advanced(.committed):
                    checkpoints = points
                    XCTAssertEqual(windowIndex,packet.surface.count)
                    XCTAssertEqual(diagnostics,[Array("LoadGameArt: Art loaded.\n".utf8)])
                    XCTAssertEqual(failed,failure != nil);XCTAssertEqual(negative,3);XCTAssertEqual(presentation,1)
                    let batch = try XCTUnwrap(host.takeCommitted());XCTAssertNil(try host.takeCommitted())
                    let run = G.Run(startup:r,packet:packet,before:before,driver:driver,batch:batch,profile:.negative,served:served,checkpoints:checkpoints)
                    try G().checkJournal(run)
                    let (reference,referenceBatch) = try G().prepared(run,profile:.negative)
                    G.B.same(try XCTUnwrap(batch.context.application.session),try XCTUnwrap(reference.session))
                    guard case .iteration(let actual) = batch.contents else { throw Stop.limit }
                    XCTAssertEqual(try actual.effects.map(G().normalized),try referenceBatch.effects.map(G().normalized))
                    XCTAssertEqual(actual.graphics.map(G().normalized),referenceBatch.graphics.map(G().normalized))
                    return run
                case .advanced:throw Stop.limit
                }
            } catch Stop.late {
                XCTAssertFalse(failed);failed = true
                G.B.same(try XCTUnwrap(host.snapshot.session),old);XCTAssertEqual(host.pendingBatchCount,0)
                XCTAssertEqual(served,driver.exchangeSnapshot.receipts.map(\.request));XCTAssertEqual(driver.exchangeSnapshot.status,.open)
            }
        }
        try D().close(r);throw Stop.limit
    }
    func checkFrame(_ run: G.Run) throws {
        guard case .iteration(let iteration) = run.batch.contents else { throw Stop.limit }
        let back = try D().ids(run.startup).2,b = run.startup.setup.display,pixels = try b.pixels(back)
        let (words,mask) = try expected(iteration.graphics,width:pixels.width,height:pixels.height)
        XCTAssertEqual(pixels.defined,mask);XCTAssertEqual(mask.filter { !$0 }.count,101)
        for i in words.indices where mask[i] { XCTAssertEqual(pixels.values[i],words[i]) }
        XCTAssertThrowsError(try b.image(back)) { XCTAssertEqual($0 as? B.Boundary,.unknownPixel) }
        let actual = b.frontOperations
        XCTAssertEqual(actual.map(\.request.kind),["fill","blit","blit","blit","blit","blit"])
        let receipts = run.driver.exchangeSnapshot.receipts.compactMap { r -> B.FrontOperation? in
            guard case .front(_,let q) = r.request,q.kind == "fill" || q.kind == "blit",case .front(let a) = r.response else { return nil }
            return .init(request:q,response:a)
        }
        XCTAssertEqual(actual,receipts)
        print("Whole menu actual nontext raster",pixels.width,pixels.height,"known",mask.filter { $0 }.count,"unknown",mask.filter { !$0 }.count)
    }
    func testWholeMenuPhysicalRasterRetainsUnknownCursorWithDeclaredNegativeText() throws {
        let run = try whole();defer { try? D().close(run.startup) };try checkFrame(run)
    }
    func testLateWholeMenuFailuresDoNotRepeatPhysicalRaster() throws {
        for failure in ["graphics","publication"] {
            let run = try whole(failure);defer { try? D().close(run.startup) };try checkFrame(run)
            XCTAssertEqual(run.driver.exchangeSnapshot.status,.finished)
        }
    }
    func bitmap(_ words: [UInt32],width: Int,height: Int) throws -> OriginalApplicationStartupInputs.Bitmap {
        XCTAssertEqual(words.count,width*height)
        let pitch = (width*3+3)/4*4
        var data = try OriginalStateRecord(bytes:Array(repeating:0,count:40+pitch*height),defined:Array(repeating:true,count:40+pitch*height))
        try data.write(UInt32(40),at:0);try data.write(Int32(width),at:4);try data.write(Int32(height),at:8)
        try data.write(UInt16(1),at:12);try data.write(UInt16(24),at:14)
        for y in 0..<height { for x in 0..<width {
            let value = words[y*width+x],i = 40+(height-1-y)*pitch+x*3
            for c in 0..<3 { try data.write(UInt8(truncatingIfNeeded:value >> (c*8)),at:i+c) }
        } }
        return try .init(dib:data.bytes)
    }
    func unknownBitmap() throws -> OriginalApplicationStartupInputs.Bitmap {
        var data = try OriginalStateRecord(bytes:Array(repeating:0,count:52),defined:Array(repeating:true,count:52))
        try data.write(UInt32(40),at:0);try data.write(Int32(2),at:4);try data.write(Int32(1),at:8)
        try data.write(UInt16(1),at:12);try data.write(UInt16(8),at:14);try data.write(UInt32(1),at:16)
        try data.write(UInt32(4),at:20);try data.write(UInt32(2),at:32);try data.write(UInt8(255),at:46)
        for (i,v) in [1,1,0,1].enumerated() { try data.write(UInt8(v),at:48+i) }
        return try .init(dib:data.bytes)
    }
    /// GDI text (APPLICATION_GDI_TEXT_PLAN.md): the library routine's transparent
    /// TextOut, the EXE routine's opaque extent box, results and boundaries.
    func testSurfaceTextDrawsBothRoutinesWithTheDeclaredFont() throws {
        let r = try D().run(late:false);defer { try? D().close(r) };let b = r.setup.display,(_,_,back,_) = try D().ids(r)
        let base: UInt32 = 0xabcdef
        _ = try perform(b,fill(back,base,[0,0,794,550]))
        // Library route: GetDC, SetBkMode(TRANSPARENT), SetTextColor, TextOut, ReleaseDC.
        let dc = try XCTUnwrap(perform(b,.init("getDC",[back])).response.output)
        XCTAssertEqual(dc,B.textDCHandle)
        XCTAssertThrowsError(try b.prepareFront(.init("getDC",[back])))
        XCTAssertThrowsError(try b.prepareFront(try fill(back,0,[0,0,4,4])))
        XCTAssertEqual(try perform(b,.init("setBackgroundMode",[dc,1])).response.result,2)
        XCTAssertEqual(try perform(b,.init("setTextColor",[dc,0x0000ff])).response.result,0)
        XCTAssertThrowsError(try b.prepareFront(.init("setTextColor",[dc &+ 1,0])))
        XCTAssertThrowsError(try b.prepareFront(.init("textOut",[dc,0,0,1],[[0xa4]])))
        XCTAssertEqual(try perform(b,.init("textOut",[dc,10,20,2],[Array("Hi".utf8)])).response.result,1)
        XCTAssertEqual(try perform(b,.init("releaseDC",[back,dc])).response.result,0)
        let mask = B.textMask(Array("Hi".utf8)),p = try b.pixels(back)
        XCTAssertGreaterThan(mask.advance,0);XCTAssertGreaterThan(mask.bits.filter { $0 != 0 }.count,0)
        for y in 0..<p.height { for x in 0..<p.width {
            let mx = x-10+mask.originX,my = y-20+mask.originY
            let glyph = mx >= 0 && my >= 0 && mx < mask.width && my < mask.height && mask.bits[my*mask.width+mx] != 0
            XCTAssertEqual(p.values[y*p.width+x],glyph ? 0xff0000 : base)
        } }
        // Glyphs stay inside the 16 px cell (ascent 13): nothing above y 20.
        for x in 0..<p.width { for y in 0..<20 { XCTAssertEqual(p.values[y*p.width+x],base) } }
        // EXE route: GetDC, SetBkColor, SetTextColor, TextOut in the default OPAQUE mode.
        let dc2 = try XCTUnwrap(perform(b,.init("getDC",[back])).response.output)
        XCTAssertEqual(try perform(b,.init("setBackgroundColor",[dc2,0x602010])).response.result,Int32(0xffffff))
        _ = try perform(b,.init("setTextColor",[dc2,0xffffff]))
        _ = try perform(b,.init("textOut",[dc2,UInt32(bitPattern:-3),100,1],[Array("W".utf8)]))
        _ = try perform(b,.init("releaseDC",[back,dc2]))
        let w = B.textMask(Array("W".utf8)),q = try b.pixels(back)
        for y in 100..<116 { for x in 0..<(w.advance-3) {
            let mx = x+3+w.originX,my = y-100+w.originY,glyph = mask.width > 0 && w.bits[my*w.width+mx] != 0
            XCTAssertEqual(q.values[y*q.width+x],glyph ? 0xffffff : 0x102060)
        } }
        XCTAssertEqual(q.values[116*q.width],base)
        XCTAssertThrowsError(try b.prepareFront(.init("textOut",[dc2,0,0,1],[Array("x".utf8)])))
    }

    /// Alt+Enter's full-screen display (APPLICATION_FULL_SCREEN_PLAN.md, declared):
    /// exclusive level, DD_OK display mode, a flip chain, Flip swapping memory,
    /// and Blt from a surface of the released DirectDraw object.
    func testFullScreenFlipChainSwapsAndDrawsReleasedObjectSurfaces() throws {
        let r = try D().run(late:false);defer { try? D().close(r) };let b = r.setup.display,(oldDraw,_,back,_) = try D().ids(r)
        let window = r.setup.controls.window
        func call(_ q: OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response { try b.perform(b.prepare(q)).response }
        _ = try perform(b,fill(back,0x445566,[0,0,794,550]))
        let draw = try XCTUnwrap(call(.init("directDrawCreate",[0,0x457578,0])).output)
        XCTAssertThrowsError(try b.prepare(.init("displayMode",[draw,794,550,8]))) // only after the exclusive level
        _ = try call(.init("cooperativeLevel",[draw,window,0x11]))
        XCTAssertEqual(try call(.init("displayMode",[draw,794,550,8])).result,0)
        var description = try OriginalStateRecord(bytes:Array(repeating:0,count:108),defined:Array(repeating:true,count:108))
        for (offset,value): (Int,UInt32) in [(0,108),(4,0x21),(8,550),(12,794),(20,1),(104,0x4218)] { try description.write(value,at:offset) }
        let primary = try XCTUnwrap(call(.init("createSurface",[draw,0x455634,0],structure:description)).output)
        let flipping = try XCTUnwrap(call(.init("attachedSurface",[primary,4,0x455608])).output)
        XCTAssertEqual(try b.pixels(primary).width,794);XCTAssertEqual(try b.pixels(flipping).height,550)
        // The old object is released; its surface still draws into the new chain.
        _ = try call(.init("release",[oldDraw]))
        _ = try perform(b,fill(flipping,0x101010,[0,0,794,550]))
        _ = try perform(b,blt(back,flipping,[0,0,4,4],[2,2,6,6],key:false))
        let frame = try b.pixels(flipping).values
        XCTAssertEqual(frame[2*794+2],0x445566)
        XCTAssertEqual(try perform(b,.init("method",[primary,0x2c,0,1])).response.result,0)
        XCTAssertEqual(try b.pixels(primary).values,frame)
        XCTAssertFalse(try b.pixels(flipping).defined.contains(true)) // the old front's never-drawn memory
        _ = try perform(b,fill(flipping,0x202020,[0,0,794,550]))
        _ = try perform(b,.init("method",[primary,0x2c,0,1]))
        XCTAssertEqual(try b.pixels(primary).values,Array(repeating:0x202020,count:794*550))
        XCTAssertEqual(try b.pixels(flipping).values,frame)
        XCTAssertThrowsError(try b.prepareFront(.init("method",[flipping,0x2c,0,1]))) // Flip needs the chain's primary
    }

    func testMaskedFillKeyAndMirrorCopyUseOwnedConstructorSurfaces() throws {
        let r = try D().run(late:false);defer { try? D().close(r) };let b = r.setup.display,(device,_,back,_) = try D().ids(r)
        let colors: [UInt32] = [0,0xff0000,0xff00,0xff,0x110022,0,0x334455,0]
        let service = OriginalMacBitmapService(backend:b,inputs:.init(resources:["pattern":try bitmap(colors,width:4,height:2),"unknown":try unknownBitmap()],files:["pattern":.missing,"unknown":.missing]))
        let (_,exchange) = try M().construct(service,"pattern",device),source = try M().surface(exchange)
        let (_,unknownExchange) = try M().construct(service,"unknown",device),unknown = try M().surface(unknownExchange)
        let base: UInt32 = 0xabcdef
        _ = try perform(b,fill(back,base,[0,0,794,550]))
        let q = try fill(back,0x10206c,[7,9,9,11])
        XCTAssertEqual(q.fill?.defined.filter { $0 }.count,8);_ = try perform(b,q)
        _ = try perform(b,blt(source,back,[0,0,4,2],[1,1,5,3]))
        _ = try perform(b,blt(source,back,[0,0,4,2],[10,1,14,3],mirror:true))
        _ = try perform(b,blt(source,back,[1,0,3,2],[20,1,22,3],key:false))
        _ = try perform(b,blt(unknown,back,[0,0,2,1],[30,1,32,2]))
        let p = try b.pixels(back)
        func row(_ x: Int,_ y: Int,_ count: Int) -> [UInt32] { Array(p.values[(y*p.width+x)..<(y*p.width+x+count)]) }
        XCTAssertEqual(row(1,1,4),[base,0xff0000,0xff00,0xff]);XCTAssertEqual(row(1,2,4),[0x110022,base,0x334455,base])
        XCTAssertEqual(row(10,1,4),[0xff,0xff00,0xff0000,base]);XCTAssertEqual(row(10,2,4),[base,0x334455,base,0x110022])
        XCTAssertEqual(row(20,1,2),[0xff0000,0xff00]);XCTAssertEqual(row(20,2,2),[0,0x334455])
        XCTAssertEqual(row(30,1,2),[0xff0000,base]);XCTAssertFalse(p.defined[p.width+31])
        XCTAssertEqual(p.defined.filter { !$0 }.count,1)
        for y in 9..<11 { XCTAssertEqual(row(7,y,2),[0x10206c,0x10206c]) }
        XCTAssertEqual(try b.pixels(source).values,colors)
        XCTAssertEqual(try b.pixels(unknown).defined,[true,false])
    }
    /// CORE_REALTIME 1g: the known mask's "every pixel known" flag. With the
    /// live app's fresh-black surfaces every mask starts full; a stretched image
    /// with an unknown pixel, an unkeyed copy of it and a keyed copy of it must
    /// each leave that pixel unknown in later copies, and a whole fill or a
    /// whole unkeyed copy of known pixels makes every pixel known again.
    func testKnownFlagFollowsClearsFillsAndWholeCopies() throws {
        let r = try D().run(late:false,freshSurfacesKnownBlack:true);defer { try? D().close(r) }
        let b = r.setup.display,(device,_,back,_) = try D().ids(r)
        let p = try b.pixels(back),width = p.width,height = p.height
        XCTAssertTrue(p.defined.allSatisfy { $0 },"fresh surfaces start known black")
        let colors: [UInt32] = [0,0xff0000,0xff00,0xff,0x110022,0,0x334455,0],whole: UInt32 = 0x123456
        let service = OriginalMacBitmapService(backend:b,inputs:.init(resources:["pattern":try bitmap(colors,width:4,height:2),
            "unknown":try unknownBitmap(),"whole":try bitmap(Array(repeating:whole,count:width*height),width:width,height:height)],
            files:["pattern":.missing,"unknown":.missing,"whole":.missing]))
        let (_,e1) = try M().construct(service,"pattern",device),pattern = try M().surface(e1)
        let (_,e2) = try M().construct(service,"unknown",device),unknown = try M().surface(e2)
        let (_,e3) = try M().construct(service,"whole",device),source = try M().surface(e3)
        XCTAssertEqual(try b.pixels(unknown).defined,[true,false],"the image's unknown pixel clears a fresh-black bit")
        func probe() throws -> [Bool] {
            // Back pixels (30,1) and (31,1) copied into the pattern's first row.
            _ = try perform(b,blt(back,pattern,[30,1,32,2],[0,0,2,1],key:false))
            return Array(try b.pixels(pattern).defined[0..<2])
        }
        func unknownCount() throws -> Int { try b.pixels(back).defined.filter { !$0 }.count }
        _ = try perform(b,blt(unknown,back,[0,0,2,1],[30,1,32,2],key:false))
        XCTAssertEqual(try unknownCount(),1);XCTAssertEqual(try probe(),[true,false],"unkeyed copy cleared the flag")
        _ = try perform(b,fill(back,0xabcdef,[0,0,Int32(width),Int32(height)]))
        XCTAssertEqual(try unknownCount(),0);XCTAssertEqual(try probe(),[true,true],"a whole fill")
        XCTAssertEqual(Array(try b.pixels(pattern).values[0..<2]),[0xabcdef,0xabcdef])
        _ = try perform(b,blt(unknown,back,[0,0,2,1],[30,1,32,2]))
        XCTAssertEqual(try unknownCount(),1);XCTAssertEqual(try probe(),[true,false],"keyed copy cleared the flag")
        _ = try perform(b,blt(source,back,[0,0,Int32(width),Int32(height)],[0,0,Int32(width),Int32(height)],key:false))
        XCTAssertEqual(try unknownCount(),0);XCTAssertEqual(try probe(),[true,true],"a whole unkeyed copy of known pixels")
        XCTAssertEqual(Array(try b.pixels(pattern).values[0..<2]),[whole,whole])
        _ = try perform(b,blt(unknown,back,[0,0,2,1],[30,1,32,2],mirror:true))
        XCTAssertEqual(try unknownCount(),1);XCTAssertEqual(try probe(),[false,true],"mirrored keyed copy cleared the flag")
        XCTAssertEqual(try b.observation(back).knownPixels,width*height-1)
        withExtendedLifetime((e1,e2,e3)) {}
    }
    /// CORE_REALTIME 4g: validating once (`prepareAndPerformFront`, the
    /// committed-batch replay) equals `performFront(prepareFront(_))` for
    /// draws, rejected rectangles and validation errors.
    func testSingleValidationEqualsPrepareThenPerform() throws {
        func run(_ once: Bool) throws -> ([String],B.Pixels,Int) {
            let r = try D().run(late:false);defer { try? D().close(r) };let b = r.setup.display,(device,_,back,_) = try D().ids(r)
            let colors: [UInt32] = [0,0xff0000,0xff00,0xff,0x110022,0,0x334455,0]
            let service = OriginalMacBitmapService(backend:b,inputs:.init(resources:["pattern":try bitmap(colors,width:4,height:2),
                "unknown":try unknownBitmap()],files:["pattern":.missing,"unknown":.missing]))
            let (_,e1) = try M().construct(service,"pattern",device),source = try M().surface(e1)
            let (_,e2) = try M().construct(service,"unknown",device),unknown = try M().surface(e2)
            let events: [Event] = [
                try fill(back,0xabcdef,[0,0,794,550]),try fill(back,0x10206c,[7,9,9,11]),
                try blt(source,back,[0,0,4,2],[1,1,5,3]),try blt(source,back,[0,0,4,2],[10,1,14,3],mirror:true),
                try blt(source,back,[1,0,3,2],[20,1,22,3],key:false),try blt(unknown,back,[0,0,2,1],[30,1,32,2]),
                try blt(source,back,[0,0,4,2],[-5,-5,-1,-3]),   // outside: rejected
                try blt(source,back,[0,0,4,2],[790,548,794,550]),
                try blt(source,source,[0,0,1,1],[1,1,2,2]),     // the same surface: a validation error
                .init("textOut",[0x1234,0,0,1],[[0x41]]),       // no held DC: a validation error
                .init("unknownKind"),
            ]
            var log: [String] = []
            for q in events {
                do { let served = once ? try b.prepareAndPerformFront(q) : try perform(b,q);log.append("ok \(served.response.result)") }
                catch { log.append("error \(error)") }
            }
            withExtendedLifetime((e1,e2)) {}
            return (log,try b.pixels(back),b.frontOperationCount)
        }
        let (twice,pixelsTwice,countTwice) = try run(false),(once,pixelsOnce,countOnce) = try run(true)
        XCTAssertEqual(once,twice);XCTAssertEqual(pixelsOnce.values,pixelsTwice.values)
        XCTAssertEqual(pixelsOnce.defined,pixelsTwice.defined);XCTAssertEqual(countOnce,countTwice)
        XCTAssertTrue(twice.contains { $0.hasPrefix("error") } && twice.contains { $0.hasPrefix("ok") },"both outcomes covered")
    }
    /// CORE_REALTIME tier 3 e: replaying a Blt or fill record (`replayBlit`,
    /// `replayFill`, no event) equals replaying its event (`replayFront`) for
    /// draws, rejected rectangles and validation errors, with the same pixels
    /// and operation count.
    func testRecordReplayEqualsEventReplay() throws {
        func run(_ records: Bool) throws -> ([String],B.Pixels,[B.FrontOperation]) {
            let r = try D().run(late:false);defer { try? D().close(r) };let b = r.setup.display,(device,_,back,_) = try D().ids(r)
            let colors: [UInt32] = [0,0xff0000,0xff00,0xff,0x110022,0,0x334455,0]
            let service = OriginalMacBitmapService(backend:b,inputs:.init(resources:["pattern":try bitmap(colors,width:4,height:2),
                "unknown":try unknownBitmap()],files:["pattern":.missing,"unknown":.missing]))
            let (_,e1) = try M().construct(service,"pattern",device),source = try M().surface(e1)
            let (_,e2) = try M().construct(service,"unknown",device),unknown = try M().surface(e2)
            let logged = b.frontOperations.count
            func rawFill(_ effects: [UInt8],_ defined: [Bool]) -> Event {
                var e = Event("fill")
                e.fill = OriginalSurfaceFillRequest(target:back,rectangle:[2,2,4,4],flags:0x1000400,effects:effects,defined:defined)
                return e
            }
            var sized = [UInt8](repeating:0,count:100);sized[0] = 100
            var wrongSize = sized;wrongSize[0] = 99
            var undefinedColor = [Bool](repeating:true,count:100);undefinedColor[81] = false
            var shortFill = Event("fill")
            shortFill.fill = OriginalSurfaceFillRequest(target:back,rectangle:[0,0,1,1],flags:0x1000400,
                effects:[UInt8](repeating:0,count:99),defined:[Bool](repeating:true,count:99))
            var badFlags = try blt(source,back,[0,0,4,2],[1,1,5,3])
            if let x = badFlags.blit {
                badFlags.blit = OriginalBitmapBlit(sourceSurface:x.sourceSurface,targetSurface:x.targetSurface,source:x.source,
                    destination:x.destination,flags:x.flags | 0x10,effects:x.effects)
            }
            let events: [Event] = [
                try fill(back,0xabcdef,[0,0,794,550]),try fill(back,0x10206c,[7,9,9,11]),
                try blt(source,back,[0,0,4,2],[1,1,5,3]),try blt(source,back,[0,0,4,2],[10,1,14,3],mirror:true),
                try blt(source,back,[1,0,3,2],[20,1,22,3],key:false),try blt(unknown,back,[0,0,2,1],[30,1,32,2]),
                try blt(source,back,[0,0,4,2],[-5,-5,-1,-3]),   // outside: rejected
                try blt(source,back,[0,0,4,2],[790,548,794,550]),
                try blt(source,source,[0,0,1,1],[1,1,2,2]),     // the same surface: a validation error
                shortFill,badFlags,                             // fill effects extent, Blt flags: errors
                rawFill(wrongSize,[Bool](repeating:true,count:100)),rawFill(sized,undefinedColor),   // fill size, undefined colour
                try fill(back,0x123456,[3,3,5,5]),
            ]
            var log: [String] = []
            for q in events {
                do {
                    let response: OriginalLibSurfaceText.Response
                    if records, q.kind == "blit", let blit = q.blit { response = try b.replayBlit(blit) }
                    else if records, q.kind == "fill", let fill = q.fill { response = try b.replayFill(fill) }
                    else { response = try b.replayFront(q) }
                    log.append("ok \(response.result)")
                } catch { log.append("error \(error)") }
            }
            withExtendedLifetime((e1,e2)) {}
            return (log,try b.pixels(back),Array(b.frontOperations.dropFirst(logged)))
        }
        let (events,pixelsEvents,logEvents) = try run(false),(records,pixelsRecords,logRecords) = try run(true)
        XCTAssertEqual(records,events);XCTAssertEqual(pixelsRecords.values,pixelsEvents.values)
        XCTAssertEqual(pixelsRecords.defined,pixelsEvents.defined)
        XCTAssertEqual(logRecords,logEvents,"the operation log, its events built only for it")
        XCTAssertEqual(logEvents.count,events.filter { $0.hasPrefix("ok") }.count)
        XCTAssertEqual(events.filter { $0.hasPrefix("error") }.count,5,"\(events)")
        XCTAssertTrue(events[11].contains("front fill size") && events[12].hasPrefix("error State bytes"),"\(events)")
        XCTAssertTrue(events.contains("ok 0") && events.contains("ok \(OriginalMacDisplayBackend.invalidRect)"),"draws and a rejection: \(events)")
    }
    /// CORE_REALTIME 1h: the four-pixel copy path gives the pixels and known
    /// bits of a per-pixel model for keyed, unkeyed and mirrored copies of a
    /// wide sprite, each row starting at chosen bit positions of the target's
    /// mask words (both sides of a word boundary), over a patterned background
    /// laid by the row copy (values) and over unknown pixels (known bits).
    func testWideSpriteCopiesMatchAPerPixelModel() throws {
        try wideSpriteCopies(fullTarget:false)
        // CORE_REALTIME 1j: over a fully known target (the live app's) the
        // known source rows take the path without known-bit work; an unknown
        // source pixel then clears the flag and the bit-gathering path resumes.
        try wideSpriteCopies(fullTarget:true)
        // CORE_REALTIME R4: spans that leave one to three pixels after the
        // four-pixel groups of the fully known target's path.
        try wideSpriteCopies(fullTarget:true,trim:6)
        try wideSpriteCopies(fullTarget:true,trim:7)
        try wideSpriteCopies(fullTarget:true,trim:8)
    }
    /// CORE_REALTIME R4: a key range with low < high (pixels below, at,
    /// inside and above both bounds) and pixels whose top byte is set (laid by
    /// fills) give the per-pixel model's result through the four-pixel path,
    /// forward and mirrored, with a remainder after the groups.
    func testKeyRangeAndTopByteFollowThePerPixelModel() throws {
        let r = try D().run(late:false,freshSurfacesKnownBlack:true);defer { try? D().close(r) }
        let b = r.setup.display,(device,_,back,_) = try D().ids(r)
        let low: UInt32 = 0x101010,high: UInt32 = 0x202020,width = 38
        let cycle: [UInt32] = [0x10100f,0x101010,0x151515,0x202020,0x202021,0,0xabcdef,0x101011,0x20201f]
        let colors = (0..<width).map { cycle[$0 % cycle.count] }
        let service = OriginalMacBitmapService(backend:b,inputs:.init(resources:["keyed":try bitmap(colors,width:width,height:1),
            "plain":try bitmap([UInt32](repeating:0x404040,count:width),width:width,height:1)],files:["keyed":.missing,"plain":.missing]))
        let (_,e1) = try M().construct(service,"keyed",device),source = try M().surface(e1)
        let (_,e2) = try M().construct(service,"plain",device),filled = try M().surface(e2)
        // The top byte set: inside the range once masked, above it unmasked.
        _ = try perform(b,fill(filled,0xff151515,[0,0,13,1]))
        _ = try perform(b,fill(filled,0xff303030,[13,0,26,1]))
        let filledValues = try b.pixels(filled).values
        XCTAssertEqual(filledValues[0],0xff151515,"a fill keeps the top byte")
        var key = try OriginalStateRecord(bytes:Array(repeating:0,count:8),defined:Array(repeating:true,count:8))
        try key.write(low,at:0);try key.write(high,at:4)
        for surface in [source,filled] { _ = try M().call(service,.init("colorKey",[surface,8],strings:[key.bytes])) }
        let stride = try b.pixels(back).width
        var values = try b.pixels(back).values
        var dy = 4
        for (surface,pixels) in [(source,colors),(filled,filledValues)] { for mirror in [false,true] {
            let span = width-1   // groups of four and a remainder of one
            _ = try perform(b,blt(surface,back,[1,0,Int32(1+span),1],[3,Int32(dy),Int32(3+span),Int32(dy+1)],key:true,mirror:mirror))
            for xx in 0..<span {
                let v = pixels[mirror ? span-xx : 1+xx]
                if v & 0xffffff < low || v & 0xffffff > high { values[dy*stride+3+xx] = v }
            }
            dy += 2
        } }
        XCTAssertEqual(try b.pixels(back).values,values)
        withExtendedLifetime((e1,e2)) {}
    }
    func wideSpriteCopies(fullTarget: Bool,trim: Int = 5) throws {
        let r = try D().run(late:false,freshSurfacesKnownBlack:fullTarget);defer { try? D().close(r) }
        let b = r.setup.display,(device,_,back,_) = try D().ids(r)
        let width = 37,height = 1,noiseWidth = 64
        var x: UInt32 = 0x9e3779b9
        func next() -> UInt32 { x ^= x << 13;x ^= x >> 17;x ^= x << 5;return x }
        let colors = (0..<width*height).map { _ in next() % 3 == 0 ? 0 : next() & 0xffffff }
        let noise = (0..<noiseWidth).map { _ in next() & 0xffffff | 1 }
        let service = OriginalMacBitmapService(backend:b,inputs:.init(resources:["wide":try bitmap(colors,width:width,height:height),
            "noise":try bitmap(noise,width:noiseWidth,height:1)],files:["wide":.missing,"noise":.missing]))
        let (_,e1) = try M().construct(service,"wide",device),source = try M().surface(e1)
        let (_,e2) = try M().construct(service,"noise",device),background = try M().surface(e2)
        let stride = try b.pixels(back).width
        var values = try b.pixels(back).values,defined = try b.pixels(back).defined
        let sx0 = 2,span = width-trim   // a source span that does not start at column 0
        var dy = 10
        for patterned in [true,false] { for mirror in [false,true] { for key in [true,false] {
            for startBit in [0,1,2,3,4,56,57,58,59,60,61,62,63] {
                // The column whose mask bit is startBit in row dy.
                let offset = ((startBit-(dy*stride) % 64) % 64+64) % 64
                if patterned {
                    // The row copy (unkeyed, forward, known) lays a pattern under the sprite.
                    _ = try perform(b,blt(background,back,[0,0,Int32(span),1],[Int32(offset),Int32(dy),Int32(offset+span),Int32(dy+1)],key:false))
                    for xx in 0..<span { values[dy*stride+offset+xx] = noise[xx];defined[dy*stride+offset+xx] = true }
                }
                _ = try perform(b,blt(source,back,[Int32(sx0),0,Int32(sx0+span),1],[Int32(offset),Int32(dy),Int32(offset+span),Int32(dy+1)],
                                      key:key,mirror:mirror))
                for xx in 0..<span {
                    let v = colors[mirror ? sx0+span-1-xx : sx0+xx]
                    if !key || v != 0 { values[dy*stride+offset+xx] = v;defined[dy*stride+offset+xx] = true }
                }
                dy += 2
            }
        } } }
        var p = try b.pixels(back)
        XCTAssertEqual(p.values,values);XCTAssertEqual(p.defined,defined)
        if fullTarget {
            XCTAssertFalse(p.defined.contains(false),"every target pixel stays known")
            XCTAssertEqual(try b.observation(back).knownPixels,p.width*p.height)
            // An unknown source pixel over the full target clears its bit.
            let service2 = OriginalMacBitmapService(backend:b,inputs:.init(resources:["unknown":try unknownBitmap()],files:["unknown":.missing]))
            let (_,e3) = try M().construct(service2,"unknown",device),unknown = try M().surface(e3)
            _ = try perform(b,blt(unknown,back,[0,0,2,1],[3,Int32(dy),5,Int32(dy+1)]))
            _ = try perform(b,blt(source,back,[Int32(sx0),0,Int32(sx0+span),1],[0,Int32(dy+2),Int32(span),Int32(dy+3)],key:true,mirror:true))
            for xx in 0..<span { let v = colors[sx0+span-1-xx]; if v != 0 { values[(dy+2)*stride+xx] = v } }
            p = try b.pixels(back)
            XCTAssertEqual(p.defined.filter { !$0 }.count,1,"the unknown pixel's bit is cleared")
            XCTAssertEqual(p.values[(dy+2)*stride..<(dy+2)*stride+span],values[(dy+2)*stride..<(dy+2)*stride+span])
            withExtendedLifetime(e3) {}
        } else {
            XCTAssertTrue(p.defined.contains(false),"some target pixels stayed unknown")
        }
        withExtendedLifetime((e1,e2)) {}
    }
    func testKnownFramePresentationClipsToOwnedWindowAndUnknownPreflightIsAtomic() throws {
        let r = try D().run(late:false);defer { try? D().close(r) };let b = r.setup.display,(_,primary,back,_) = try D().ids(r)
        let rect = try W().rectangle(W().window(r)),base: UInt32 = 0x336699
        _ = try perform(b,fill(back,base,[0,0,794,550]));_ = try perform(b,fill(back,0xff0000,[0,0,40,30]))
        _ = try perform(b,present(primary,back,rect))
        let p = try b.pixels(primary)
        for i in p.values.indices {
            let x = i%p.width,y = i/p.width,inside = x >= rect[0] && x < rect[2] && y >= rect[1] && y < rect[3]
            XCTAssertEqual(p.defined[i],inside)
            if inside { XCTAssertEqual(p.values[i],x < rect[0]+40 && y < rect[1]+30 ? 0xff0000 : base) }
        }
        let view = try r.setup.window.backend.captureView(r.setup.controls.window)
        for (x,y,expected): (Int,Int,[CGFloat]) in [(4,4,[1,0,0]),(view.pixelsWide/2,view.pixelsHigh/2,[0.2,0.4,0.6])] {
            let c = try XCTUnwrap(view.colorAt(x:x,y:y)?.usingColorSpace(.sRGB))
            XCTAssertEqual(c.redComponent,expected[0],accuracy:2.0/255);XCTAssertEqual(c.greenComponent,expected[1],accuracy:2.0/255);XCTAssertEqual(c.blueComponent,expected[2],accuracy:2.0/255)
        }
        // Part of this destination lies outside our client clip, still on the primary.
        let clipped = [rect[0]-2,rect[1]-2,rect[0]+2,rect[1]+2]
        _ = try perform(b,present(primary,back,clipped,source:[50,50,54,54]))
        let after = try b.pixels(primary)
        for i in p.values.indices {
            let x = i%p.width,y = i/p.width,changed = x >= rect[0] && x < rect[0]+2 && y >= rect[1] && y < rect[1]+2
            XCTAssertEqual(after.defined[i],p.defined[i]);XCTAssertEqual(after.values[i],changed ? base : p.values[i])
        }
        let count = b.frontOperations.count
        XCTAssertThrowsError(try b.prepareFront(present(primary,back,[0,0,0,0])))
        XCTAssertThrowsError(try b.prepareFront(present(primary,back,nil)))
        XCTAssertEqual(try b.pixels(primary),after);XCTAssertEqual(b.frontOperations.count,count)
        // A fresh offscreen remains unknown; presenting it cannot erase known primary bytes.
        var desc = try OriginalStateRecord(bytes:Array(repeating:0,count:108),defined:Array(repeating:true,count:108))
        for (i,v): (Int,UInt32) in [(0,108),(4,7),(8,550),(12,794),(104,0x40)] { try desc.write(v,at:i) }
        let q = OriginalBitmapSurfaceLoading.Request("createSurface",[try D().ids(r).0,0],structure:desc)
        let s = try b.performBitmap(b.prepareBitmap(q,inputs:.init(resources:[:],files:[:])))
        XCTAssertThrowsError(try b.prepareFront(present(primary,XCTUnwrap(s.response.output),rect))) { XCTAssertEqual($0 as? B.Boundary,.unknownPixel) }
        XCTAssertEqual(try b.pixels(primary),after);XCTAssertEqual(b.frontOperations.count,count)
    }
    func testProtocolPreflightResourcesAndReleaseKeepDistinctOutcomes() throws {
        let r = try D().run(late:false),other = try D().run(late:false);defer { try? D().close(r);try? D().close(other) }
        let b = r.setup.display,(_,_,back,_) = try D().ids(r),service = Service(backend:b),q = try fill(back,0x123456,[0,0,794,550])
        let prepared = try b.prepareFront(q),before = try b.pixels(back)
        XCTAssertThrowsError(try other.setup.display.performFront(prepared)) { XCTAssertEqual($0 as? B.Boundary,.foreignPreparation) }
        XCTAssertEqual(try b.pixels(back),before);_ = try b.performFront(prepared)
        XCTAssertThrowsError(try b.performFront(prepared)) { XCTAssertEqual($0 as? B.Boundary,.repeatedPreparation) }
        let pixels = try b.pixels(back)
        // DirectDraw Blt/fill with an empty or out-of-surface rectangle:
        // DDERR_INVALIDRECT and no pixel change.
        for rejected in [try fill(back,1,[0,0,0,1]),try fill(back,1,[-1,0,1,1]),try fill(back,1,[0,0,795,550])] {
            XCTAssertEqual(try b.performFront(b.prepareFront(rejected)).response.result,B.invalidRect)
        }
        XCTAssertEqual(try b.pixels(back),pixels)
        let count = b.frontOperations.count
        // GetDC is served for GDI text (APPLICATION_GDI_TEXT_PLAN.md); a malformed one is not.
        for invalid in [try blt(back,back,[0,0,2,2],[0,0,2,2]),Event("getDC",[back,1]),Event("method",[back,0x2c,0,1])] {
            XCTAssertThrowsError(try b.prepareFront(invalid))
        }
        XCTAssertEqual(try b.pixels(back),pixels);XCTAssertEqual(b.frontOperations.count,count)
        let bitmap = OriginalMacBitmapService(backend:b,inputs:.init(resources:[:],files:[:]))
        let dc = try XCTUnwrap(M().call(bitmap,.init("getDC",[back])).output)
        XCTAssertThrowsError(try b.prepareFront(q));XCTAssertThrowsError(try b.prepareFront(.init("method",[back,8])))
        _ = try M().call(bitmap,.init("releaseDC",[back,dc]))
        let e = E(),foreign = E(),a = try G().ticket(e,.front(.prefix,q)),f = try G().ticket(foreign,.front(.prefix,q))
        XCTAssertThrowsError(try service.serve(f,on:e)) { XCTAssertEqual($0 as? E.Boundary,.foreignOwner) }
        XCTAssertEqual(b.frontOperations.count,count)
        e.cancel();XCTAssertThrowsError(try service.serve(a,on:e)) { XCTAssertEqual($0 as? E.Boundary,.closed(.cancelled)) }
        XCTAssertEqual(b.frontOperations.count,count)
        let completed = E(),p = try G().ticket(completed,.front(.prefix,q));try service.serve(p,on:completed)
        XCTAssertEqual(completed.snapshot.receipts.count,1);XCTAssertFalse(completed.snapshot.receipts[0].resources.isEmpty)
        XCTAssertThrowsError(try service.serve(p,on:completed));XCTAssertEqual(b.frontOperations.count,count+1)
        // Controlled diagnostic inputs exercise the same retained service boundary.
        let debug = OriginalWindowInitialization.Request("debug",strings:[[0xff,0,0x41]])
        let missing = E(),missingTicket = try G().ticket(missing,.window(debug))
        XCTAssertThrowsError(try service.serve(missingTicket,on:missing)) { XCTAssertEqual($0 as? B.Boundary,.unsupported("window debug consumer")) }
        XCTAssertFalse(missing.snapshot.serviceStarted);XCTAssertTrue(missing.snapshot.receipts.isEmpty)
        var diagnostics: [OriginalWindowInitialization.Request] = []
        let reply = OriginalWindowInitialization.Response(result:-23,output:0xa7,bytes:[0xff,0,0x12])
        let diagnosticService = Service(backend:b,diagnostic:{ q in diagnostics.append(q);return reply })
        let structure = try OriginalStateRecord(bytes:[0],defined:[true])
        for malformed in [OriginalWindowInitialization.Request("debug"),.init("debug",[1],strings:[[1]]),
            .init("debug",strings:[[1],[2]]),.init("debug",strings:[[1]],structure:structure)] {
            let exchange = E(),permit = try G().ticket(exchange,.window(malformed))
            XCTAssertThrowsError(try diagnosticService.serve(permit,on:exchange)) { XCTAssertEqual($0 as? B.Boundary,.arguments("window debug")) }
            XCTAssertFalse(exchange.snapshot.serviceStarted);XCTAssertTrue(exchange.snapshot.receipts.isEmpty)
        }
        let diagnosticExchange = E(),foreignExchange = E()
        let diagnosticPermit = try G().ticket(diagnosticExchange,.window(debug)),foreignPermit = try G().ticket(foreignExchange,.window(debug))
        XCTAssertThrowsError(try diagnosticService.serve(foreignPermit,on:diagnosticExchange)) { XCTAssertEqual($0 as? E.Boundary,.foreignOwner) }
        foreignExchange.cancel()
        XCTAssertThrowsError(try diagnosticService.serve(foreignPermit,on:foreignExchange)) { XCTAssertEqual($0 as? E.Boundary,.closed(.cancelled)) }
        XCTAssertTrue(diagnostics.isEmpty)
        try diagnosticService.serve(diagnosticPermit,on:diagnosticExchange)
        XCTAssertEqual(diagnostics,[debug]);XCTAssertEqual(diagnosticExchange.snapshot.receipts.count,1)
        XCTAssertEqual(diagnosticExchange.snapshot.receipts[0].request,.window(debug))
        XCTAssertEqual(diagnosticExchange.snapshot.receipts[0].response,.window(reply))
        XCTAssertFalse(diagnosticExchange.snapshot.receipts[0].resources.isEmpty)
        XCTAssertThrowsError(try diagnosticService.serve(diagnosticPermit,on:diagnosticExchange))
        XCTAssertEqual(diagnostics,[debug])
        let thrown = E(),thrownPermit = try G().ticket(thrown,.window(debug))
        let throwingService = Service(backend:b,diagnostic:{ q in diagnostics.append(q);throw Stop.late })
        XCTAssertThrowsError(try throwingService.serve(thrownPermit,on:thrown)) { XCTAssertTrue($0 is Stop) }
        XCTAssertEqual(diagnostics,[debug,debug]);XCTAssertEqual(thrown.snapshot.status,.indeterminate)
        XCTAssertTrue(thrown.snapshot.receipts.isEmpty)
        let failure = try XCTUnwrap(thrown.snapshot.failure)
        XCTAssertEqual(failure.request,.window(debug));XCTAssertFalse(failure.afterCancellation);XCTAssertFalse(failure.resources.isEmpty)
        XCTAssertThrowsError(try throwingService.serve(thrownPermit,on:thrown));XCTAssertEqual(diagnostics.count,2)
        let late = E(),latePermit = try G().ticket(late,.window(debug))
        let lateService = Service(backend:b,diagnostic:{ q in diagnostics.append(q);late.cancel();return reply })
        try lateService.serve(latePermit,on:late)
        XCTAssertEqual(late.snapshot.status,.cancelled);XCTAssertEqual(late.snapshot.receipts.count,1)
        XCTAssertEqual(late.snapshot.receipts[0].response,.window(reply));XCTAssertFalse(late.snapshot.receipts[0].resources.isEmpty)
        XCTAssertThrowsError(try lateService.serve(latePermit,on:late));XCTAssertEqual(diagnostics.count,3)
        XCTAssertEqual(try b.pixels(back),pixels);XCTAssertEqual(b.frontOperations.count,count+1)
        let release = E(),ticket = try G().ticket(release,.front(.menu,.init("method",[back,8])))
        try service.serve(ticket,on:release)
        guard case .front(let response) = try XCTUnwrap(release.snapshot.receipts.first).response else { throw Stop.limit }
        XCTAssertEqual(response.result,0);XCTAssertEqual(try b.observation(back).references,0)
        XCTAssertThrowsError(try b.pixels(back));XCTAssertThrowsError(try b.prepareFront(q))
        XCTAssertFalse(release.snapshot.receipts[0].resources.isEmpty)
        XCTAssertEqual(pixels.values.first,0x123456) // Saved value snapshot survives physical release.
    }
}
