import Foundation
import XCTest
import NTSDCore

/// Independent test projection of source events or declared Native effects.
/// Neither Core graphics/bitmap transitions nor pixel copying construct expected
/// values. The source overload remains an original comparison; a declared effect
/// overload checks rendering relations without claiming source animation events.
final class OriginalApplicationCatalogGraphicsComparison {
    typealias R = OriginalApplicationCatalogSessionReference
    typealias C = OriginalApplicationCatalogSession
    typealias G = OriginalApplicationGraphics
    struct Image { let name: String; var deleted = false }
    struct Memory { let token: UInt32; var selected: UInt32?; var selections: [(UInt32,Int32)] = []; var deletes: [Int32] = [] }
    struct DC { let token: UInt32,surface: UInt32,result: Int32; var releases: [Int32] = [] }
    struct Copy { let words: [UInt32],result: Int32,image: UInt32,memory: Int,dc: Int }
    struct Surface {
        let descriptor: OriginalStateRecord,width: Int,height: Int
        var rgb: [UInt8],mask: [Bool],copies: [Copy] = [],releases: [Int32] = []
    }
    struct Event {
        let request: C.API.Request?,response: C.API.Response?,kind: String?,event: OriginalFrontScreenEvent?
    }
    let reference: R?,bitmapResources: [String:OriginalApplicationStartupInputs.Bitmap]
    let entry: OriginalApplicationLoadingSession.PendingCatalog
    let prior: OriginalApplicationBitmapInputs, oldGraphics: G, golden: OriginalCatalogDIBPixelsTests.Golden
    var eventIndex = 0,commandIndex: Int,textGeneration: Int
    var refs: [UInt32:G.Reference],next: [String:Int] = [:],creations: [G.Reference:(C.API.Request,Int32)] = [:]
    var keys: [G.Reference:(C.API.Request,Int32)] = [:],images: [UInt32:Image] = [:],surfaces: [UInt32:Surface] = [:]
    var memory: [Memory] = [],dcs: [DC] = [],lastMemory: [UInt32:Int] = [:],lastDC: [UInt32:Int] = [:]
    var textRef: G.Reference?,textOwner: G.Reference?
    var colors: [String:([UInt8],[Bool],Int,Int)] = [:]
    convenience init(reference: R,entry: OriginalApplicationLoadingSession.PendingCatalog) throws {
        try self.init(reference:reference,resources:reference.bitmapResources,golden:OriginalCatalogDIBPixelsTests.golden.get(),entry:entry)
    }
    init(reference: R? = nil,resources: [String:OriginalApplicationStartupInputs.Bitmap],
         golden: OriginalCatalogDIBPixelsTests.Golden,entry: OriginalApplicationLoadingSession.PendingCatalog) throws {
        self.reference = reference;bitmapResources = resources;self.entry = entry;self.golden = golden
        prior = try XCTUnwrap(entry.state.bitmapInputs);oldGraphics = try XCTUnwrap(entry.state.graphics)
        refs = oldGraphics.currentResources; textGeneration = oldGraphics.nextTextGeneration; commandIndex = entry.stagedGraphics.count
        for ref in oldGraphics.resources.keys { next[ref.kind] = max(next[ref.kind,default:0],ref.generation+1) }
    }
    func imageColors(_ name: String) throws -> ([UInt8],[Bool],Int,Int) {
        if let value = colors[name] { return value }
        let resource = try XCTUnwrap(golden.resources.first { $0.name == name })
        if reference != nil {
            let binding = try XCTUnwrap(R.index.get().inputs.catalogImages.first { $0.gameName == name })
            XCTAssertEqual(resource.input,binding.acceptedResource.input)
            XCTAssertEqual(resource.name,binding.acceptedResource.name)
        }
        let value = (try golden.bytes(resource.rgb),try golden.bytes(resource.mask).map { $0 == 1 },resource.width,resource.height)
        colors[name] = value; return value
    }
    func ref(_ token: UInt32) throws -> G.Reference { try XCTUnwrap(refs[token]) }
    func create(_ kind: String,_ token: UInt32,_ q: C.API.Request,_ result: Int32) -> G.Reference {
        let value = G.Reference(kind:kind,token:token,generation:next[kind,default:0]); next[kind,default:0] += 1
        refs[token] = value; creations[value] = (q,result); return value
    }
    func surfaceColors(_ token: UInt32) throws -> ([UInt8],[Bool],Int,Int) {
        if let s = surfaces[token] { return (s.rgb,s.mask,s.width,s.height) }
        let old = try XCTUnwrap(prior.surfaces[token]).sourceColors
        return (old.rgb,old.defined,old.width,old.height)
    }
    func color(_ actual: OriginalSurfaceSourceColors?,_ token: UInt32?) throws {
        guard let token else { XCTAssertNil(actual); return }
        let actual = try XCTUnwrap(actual),e = try surfaceColors(token)
        XCTAssertEqual(actual.width,e.2); XCTAssertEqual(actual.height,e.3)
        XCTAssertTrue(actual.rgb == e.0,"All source RGB"); XCTAssertTrue(actual.defined == e.1,"All source color masks")
    }
    func compare(snapshot: C.Snapshot,sourceEventEnd: Int) throws {
        let source = try XCTUnwrap(reference)
        let events = source.c.events[eventIndex..<sourceEventEnd].map {
            Event(request:$0.request,response:$0.response,kind:$0.kind,event:$0.event)
        }
        try compare(snapshot:snapshot,events:events);eventIndex = sourceEventEnd
    }
    func compare(snapshot: C.Snapshot,events: [Event]) throws {
        XCTAssertEqual(Array(snapshot.graphics.prefix(entry.stagedGraphics.count)),entry.stagedGraphics)
        for event in events {
            var bindings: [(String,G.Reference?)] = [],sourceRect: [Int32]?,destinationRect: [Int32]?,colorToken: UInt32?
            var dependencies: [String] = [],result: Int32 = 0,output: UInt32?,family = "bitmap"
            if let q = event.request {
                let r = try XCTUnwrap(event.response),w = q.words; result = r.result; output = r.output
                switch q.kind {
                case "module":break
                case "image":
                    if r.result != 0 {
                        let token = UInt32(bitPattern:r.result),name = String(decoding:try XCTUnwrap(q.strings.first),as:UTF8.self)
                        XCTAssertNil(images[token]); images[token] = .init(name:name)
                        bindings.append(("created",create("image",token,q,r.result)))
                    }
                case "getObject","deleteObject":
                    bindings.append(("owner",try ref(w[0])))
                    if q.kind == "deleteObject" { XCTAssertEqual(r.result,1); images[w[0]]!.deleted = true }
                case "createSurface":
                    XCTAssertEqual(r.result,0)
                    let token = try XCTUnwrap(r.output),record = try OriginalStateRecord(bytes:XCTUnwrap(q.bytes),defined:XCTUnwrap(q.defined))
                    let width = Int(try record.integer(at:12,as:UInt32.self)),height = Int(try record.integer(at:8,as:UInt32.self))
                    surfaces[token] = .init(descriptor:record,width:width,height:height,rgb:[UInt8](repeating:0,count:width*height*3),mask:[Bool](repeating:false,count:width*height))
                    bindings = [("owner",try ref(w[0])),("created",create("bitmapSurface",token,q,r.result))]
                case "createDC":
                    let token = UInt32(bitPattern:r.result),i = prior.memoryDCs.count+memory.count
                    memory.append(.init(token:token)); lastMemory[token] = i
                    bindings = [("created",.init(kind:"memoryDC",token:token,generation:i))]
                case "selectObject":
                    let i = try XCTUnwrap(lastMemory[w[0]]),at = i-prior.memoryDCs.count
                    XCTAssertNotEqual(r.result,0); memory[at].selected = w[1]; memory[at].selections.append((w[1],r.result))
                    bindings = [("source",try ref(w[1])),("selectedDC",.init(kind:"memoryDC",token:w[0],generation:i))]
                case "getDC":
                    XCTAssertEqual(r.result,0)
                    let token = try XCTUnwrap(r.output),i = prior.surfaceDCs.count+dcs.count
                    dcs.append(.init(token:token,surface:w[0],result:r.result)); lastDC[token] = i
                    bindings = [("owner",try ref(w[0])),("created",.init(kind:"bitmapDC",token:token,generation:i))]
                case "stretch":
                    XCTAssertEqual(r.result,1); XCTAssertEqual(w.count,11); XCTAssertEqual(w[10],0x00cc0020)
                    XCTAssertEqual(w[3],w[8]); XCTAssertEqual(w[4],w[9])
                    let mi = try XCTUnwrap(lastMemory[w[5]]),di = try XCTUnwrap(lastDC[w[0]])
                    let image = try XCTUnwrap(memory[mi-prior.memoryDCs.count].selected),target = dcs[di-prior.surfaceDCs.count].surface
                    let pixels = try imageColors(XCTUnwrap(images[image]).name)
                    var s = try XCTUnwrap(surfaces[target])
                    let x = Int(w[1]),y = Int(w[2]),width = Int(w[3]),height = Int(w[4]),sx = Int(w[6]),sy = Int(w[7])
                    guard x+width <= s.width,y+height <= s.height,sx+width <= pixels.2,sy+height <= pixels.3 else {
                        throw R.Boundary.invalid("Saved copy rectangle outside declared color input")
                    }
                    for row in 0..<height {
                        let a = (sy+row)*pixels.2+sx,b = (y+row)*s.width+x
                        s.rgb.replaceSubrange(b*3..<(b+width)*3,with:pixels.0[a*3..<(a+width)*3])
                        s.mask.replaceSubrange(b..<b+width,with:pixels.1[a..<a+width])
                    }
                    s.copies.append(.init(words:w,result:r.result,image:image,memory:mi,dc:di)); surfaces[target] = s
                    bindings = [("target",.init(kind:"bitmapDC",token:w[0],generation:di)),("source",.init(kind:"memoryDC",token:w[5],generation:mi))]
                case "releaseDC":
                    let i = try XCTUnwrap(lastDC[w[1]]); dcs[i-prior.surfaceDCs.count].releases.append(r.result)
                    bindings = [("owner",try ref(w[0])),("dc",.init(kind:"bitmapDC",token:w[1],generation:i))]
                case "deleteDC":
                    let i = try XCTUnwrap(lastMemory[w[0]]); memory[i-prior.memoryDCs.count].deletes.append(r.result)
                    bindings = [("dc",.init(kind:"memoryDC",token:w[0],generation:i))]
                case "restore","description","colorKey":
                    let owner = try ref(w[0]); bindings = [("owner",owner)]
                    if q.kind == "colorKey" { keys[owner] = (q,r.result) }
                default:throw R.Boundary.invalid("Unclassified source bitmap graphics operation: "+q.kind)
                }
            } else if event.kind == "front",let e = event.event {
                family = "front"
                switch e.kind {
                case "blit":
                    let b = try XCTUnwrap(e.blit),source = try b.sourceSurface == 0 ? nil : ref(b.sourceSurface)
                    bindings = [("target",try ref(b.targetSurface)),("source",source)]
                    sourceRect = b.source; destinationRect = b.destination
                    if source?.kind == "bitmapSurface" { colorToken = b.sourceSurface }
                    if source == nil { dependencies = ["nullSource"] }
                case "getDC":
                    output = 0x12345678; textOwner = try ref(e.arguments[0])
                    textRef = .init(kind:"textDC",token:0x12345678,generation:textGeneration); textGeneration += 1
                    bindings = [("owner",textOwner),("created",textRef)]
                case "setBackgroundMode","setTextColor","textOut": bindings = [("dc",try XCTUnwrap(textRef))]
                case "releaseDC":
                    bindings = [("owner",try ref(e.arguments[0])),("dc",try XCTUnwrap(textRef))]
                    textRef = nil; textOwner = nil
                case "method":
                    let a = e.arguments,owner = try ref(a[0]); bindings = [("owner",owner)]
                    if a[1] == 0x14 {
                        bindings += [("target",owner),("source",try ref(a[3]))]
                        var bytes = e.strings.makeIterator()
                        func rectangle(_ pointer: UInt32) throws -> [Int32]? {
                            if pointer == 0 { return nil }
                            let b = try XCTUnwrap(bytes.next()); XCTAssertEqual(b.count,16)
                            return stride(from:0,to:16,by:4).map { i in Int32(bitPattern:(0..<4).reduce(UInt32(0)) { $0|UInt32(b[i+$1]) << ($1*8) }) }
                        }
                        destinationRect = try rectangle(a[2]); sourceRect = try rectangle(a[4]); XCTAssertNil(bytes.next())
                    } else if a[1] == 0x2c { bindings.append(("target",owner)) }
                    else { throw R.Boundary.invalid("Unclassified loading surface method") }
                case "draw","read","clip","text","stringLength","panelRead","soundRequest","soundMethod":continue
                default:throw R.Boundary.invalid("Unclassified loading graphics observation: "+e.kind)
                }
            } else { continue }
            guard commandIndex < snapshot.graphics.count else { throw R.Boundary.invalid("Missing appended graphics command") }
            let a = snapshot.graphics[commandIndex]; commandIndex += 1
            XCTAssertEqual(a.family,family); XCTAssertEqual(a.result,result); XCTAssertEqual(a.output,output)
            XCTAssertEqual(a.bindings.map(\.role),bindings.map(\.0)); XCTAssertEqual(a.bindings.map(\.ref),bindings.map(\.1))
            XCTAssertEqual(a.dependencies,dependencies); XCTAssertTrue(a.opaqueReferences.isEmpty)
            XCTAssertEqual(a.sourceRectangle,sourceRect); XCTAssertEqual(a.destinationRectangle,destinationRect)
            XCTAssertNil(a.windowResponse)
            if let q = event.request {
                OriginalApplicationGraphicsTests.request(try XCTUnwrap(a.request),q)
                XCTAssertEqual(a.bitmapResponse,event.response); XCTAssertNil(a.event)
            } else { XCTAssertEqual(a.event,event.event); XCTAssertNil(a.request); XCTAssertNil(a.bitmapResponse) }
            try color(a.sourceColors,colorToken)
        }
        XCTAssertEqual(commandIndex,snapshot.graphics.count)
        try owners(snapshot)
    }
    func owners(_ snapshot: C.Snapshot) throws {
        let a = try XCTUnwrap(snapshot.state.bitmapInputs),g = try XCTUnwrap(snapshot.state.graphics)
        XCTAssertEqual(Set(a.images.keys),Set(prior.images.keys).union(images.keys))
        XCTAssertEqual(Set(a.surfaces.keys),Set(prior.surfaces.keys).union(surfaces.keys))
        for (token,image) in prior.images { XCTAssertEqual(a.images[token],image) }
        for (token,surface) in prior.surfaces { XCTAssertEqual(a.surfaces[token],surface) }
        for (token,e) in images {
            let image = try XCTUnwrap(a.images[token]),input = try XCTUnwrap(bitmapResources[e.name]),p = try imageColors(e.name)
            XCTAssertEqual(image.deleted,e.deleted); XCTAssertEqual(image.bitmap.dib,input.dib)
            XCTAssertEqual(image.bitmap.bitmapFileHeader,input.bitmapFileHeader); XCTAssertEqual(image.bitmap.pixelOffset,input.pixelOffset)
            XCTAssertTrue(image.bitmap.pixels.rgb == p.0); XCTAssertTrue(image.bitmap.pixels.defined == p.1)
            XCTAssertEqual(image.bitmap.pixels.width,p.2); XCTAssertEqual(image.bitmap.pixels.height,p.3)
        }
        for (token,e) in surfaces {
            let surface = try XCTUnwrap(a.surfaces[token])
            XCTAssertEqual(surface.descriptor,e.descriptor); XCTAssertEqual(surface.releaseResults,e.releases)
            try color(surface.sourceColors,token); XCTAssertEqual(surface.copies.count,e.copies.count)
            for (actual,c) in zip(surface.copies,e.copies) {
                XCTAssertEqual(actual.words,c.words); XCTAssertEqual(actual.result,c.result); XCTAssertEqual(actual.sourceImage,c.image)
                XCTAssertEqual(actual.memoryGeneration,c.memory); XCTAssertEqual(actual.surfaceGeneration,c.dc)
            }
        }
        XCTAssertEqual(Array(a.memoryDCs.prefix(prior.memoryDCs.count)),prior.memoryDCs)
        XCTAssertEqual(Array(a.surfaceDCs.prefix(prior.surfaceDCs.count)),prior.surfaceDCs)
        XCTAssertEqual(a.memoryDCs.count,prior.memoryDCs.count+memory.count); XCTAssertEqual(a.surfaceDCs.count,prior.surfaceDCs.count+dcs.count)
        for (actual,e) in zip(a.memoryDCs.dropFirst(prior.memoryDCs.count),memory) {
            XCTAssertEqual(actual.token,e.token); XCTAssertEqual(actual.selectedImage,e.selected); XCTAssertEqual(actual.deleteResults,e.deletes)
            XCTAssertEqual(actual.selections.map(\.image),e.selections.map(\.0)); XCTAssertEqual(actual.selections.map(\.result),e.selections.map(\.1))
        }
        for (actual,e) in zip(a.surfaceDCs.dropFirst(prior.surfaceDCs.count),dcs) {
            XCTAssertEqual(actual.token,e.token); XCTAssertEqual(actual.surface,e.surface); XCTAssertEqual(actual.acquireResult,e.result)
            XCTAssertEqual(actual.releaseResults,e.releases)
        }
        // Every new copy DC is released and every new memory DC deleted at the
        // completed child boundary; prior unresolved generations remain intact.
        XCTAssertTrue(memory.allSatisfy { $0.deletes == [1] }); XCTAssertTrue(dcs.allSatisfy { $0.releases == [0] })
        XCTAssertEqual(a.activeMemoryDCs,prior.activeMemoryDCs); XCTAssertEqual(a.activeSurfaceDCs,prior.activeSurfaceDCs)
        XCTAssertEqual(g.currentResources,refs); XCTAssertEqual(g.nextTextGeneration,textGeneration)
        XCTAssertEqual(g.textLeases,oldGraphics.textLeases); XCTAssertEqual(g.displayModes,oldGraphics.displayModes)
        XCTAssertEqual(Set(g.resources.keys),Set(oldGraphics.resources.keys).union(creations.keys))
        for (ref,resource) in oldGraphics.resources { XCTAssertEqual(g.resources[ref],resource) }
        for (ref,e) in creations {
            let resource = try XCTUnwrap(g.resources[ref]); XCTAssertEqual(resource.ref,ref)
            OriginalApplicationGraphicsTests.request(resource.creation,e.0); XCTAssertEqual(resource.createResult,e.1)
            XCTAssertTrue(resource.releaseResults.isEmpty); XCTAssertNil(resource.clipper); XCTAssertNil(resource.clipperResult)
            XCTAssertNil(resource.palette); XCTAssertNil(resource.paletteResult); XCTAssertNil(resource.pixelFormat)
            if let key = keys[ref] { OriginalApplicationGraphicsTests.request(try XCTUnwrap(resource.colorKey),key.0); XCTAssertEqual(resource.colorKeyResult,key.1) }
            else { XCTAssertNil(resource.colorKey); XCTAssertNil(resource.colorKeyResult) }
        }
    }
}
