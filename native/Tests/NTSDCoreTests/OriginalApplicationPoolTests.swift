import Foundation
import XCTest
import NTSDCore

final class OriginalApplicationPoolTests: XCTestCase {
    typealias P = OriginalApplicationPoolSession
    typealias R = OriginalApplicationPoolReference
    typealias F = OriginalApplicationCatalogFullTests
    typealias G = OriginalApplicationGraphics
    enum Stop: Error, Equatable { case injected(String) }
    /// Own the complete parent once, retaining the same catalog/graphics/PCM
    /// across independent pool attempts. The accepted full comparator runs here.
    static let parent: Result<P.Catalog.PendingPool,Error> = Result {
        let r = try F.reference.get(),prefix = try OriginalApplicationCatalogSessionReference(parentIndex:0)
        var result: P.Catalog.PendingPool?
        try F.Prior().withEntry(prefix) { entry,startup in
            let checksum = try entry.state.full.integer(at:0x44f620-0x44d000,as:UInt32.self)
            let cache = Array(entry.state.full.bytes[(0x455638-0x44d000)..<(0x458438-0x44d000)])
            let provider = F.Provider(r,checksum,cache);var owner = try P.Catalog(pending:entry,startup:startup)
            result = try owner.load(resources:F().resources(r,entry.target),makeControls:provider.controls,
                observe:provider.observe,afterChild:provider.afterChild,beforeCommit:{
                    try r.complete($0);try F().checkPublication($0,r,provider)
                })
        }
        guard let result else { throw P.Boundary.missingOwners };return result
    }
    final class Provider {
        let reference: R,stop: String?
        let events: [R.U.Event]
        var event = 0,ui = -1,actor = 0,api = 0,stores = 0,finished = false
        var expectedReply: P.API.Response?
        var expected: [P.Operation] = [],apis: [(P.API.Request,P.API.Response)] = []
        init(_ entry: P.Catalog.PendingPool,_ stop: String? = nil) throws {
            reference = try R(entry);self.stop = stop;events = Array(reference.c.events.dropFirst(401))
        }
        var image: UInt32 { 0x7a100000+UInt32(ui)*16 }
        var surface: UInt32 { 0x7b100000+UInt32(ui)*16 }
        var memory: UInt32 { 0x7c100000+UInt32(ui)*16 }
        var dc: UInt32 { 0x7d100000+UInt32(ui)*16 }
        func next(_ kind: String) throws -> R.U.Event {
            guard event < events.count else { throw P.Boundary.input("Extra UI event") }
            let e = events[event];event += 1
            XCTAssertEqual(e.kind ?? e.request?.kind,kind);return e
        }
        func fail(_ point: String) throws { if stop == point { throw Stop.injected(point) } }
        func allocate(_ kind: P.Allocation.Kind,_ count: Int) throws -> OriginalInterfaceAllocation {
            let token: UInt32
            switch kind {
            case .actor(let slot):
                XCTAssertEqual(slot,actor);XCTAssertEqual(count,0x420);actor += 1
                let e = reference.c.events[slot+1]
                XCTAssertEqual(e.kind,"allocateActor");XCTAssertEqual(e.count,count);XCTAssertEqual(e.address,R.actorTokens[slot])
                token = R.actorTokens[slot];if slot == 399 { try fail("allocate399") }
            case .interface(let index):
                let e = try next("allocate");XCTAssertEqual(e.index,index);XCTAssertEqual(e.count,count);XCTAssertEqual(count,0x1f50)
                ui = index;token = R.uiTokens[index]
            }
            return .init(address:token,backing:[UInt8](repeating:0xa5,count:count))
        }
        func bitmap(_ q: P.API.Request) throws -> P.API.Response {
            let e = try next(q.kind),source = try XCTUnwrap(e.request),reply = try XCTUnwrap(e.response)
            var words = source.words,result = reply.result,output = reply.output
            // Bind only the pointer-bearing operands of this API call. Opaque
            // selection results and all scalar/structure data remain unchanged.
            switch q.kind {
            case "module":break
            case "image":if result != 0 { result = Int32(bitPattern:image) }
            case "getObject","deleteObject":words[0] = image
            case "createSurface":
                words[0] = try reference.entry.snapshot.state.full.integer(at:0x457578-0x44d000,as:UInt32.self);output = surface
            case "restore","description","colorKey":words[0] = surface
            case "createDC":result = Int32(bitPattern:memory)
            case "selectObject":words[0] = memory;words[1] = image
            case "getDC":words[0] = surface;output = dc
            case "stretch":words[0] = dc;words[5] = memory
            case "releaseDC":words[0] = surface;words[1] = dc
            case "deleteDC":words[0] = memory
            default:throw P.Boundary.input("Undeclared UI API")
            }
            XCTAssertEqual(q.words,words);XCTAssertEqual(q.strings,source.strings);XCTAssertEqual(q.defined,source.defined)
            if let mask = q.defined {
                let a = try XCTUnwrap(q.bytes),b = try XCTUnwrap(source.bytes);XCTAssertEqual(a.count,b.count)
                for i in mask.indices { XCTAssertEqual(a[i],mask[i] ? b[i] : 0,"UI known request bytes / no private backing") }
            } else { XCTAssertEqual(q.bytes,source.bytes) }
            expectedReply = .init(result:result,writes:reply.writes,output:output);api += 1
            return .init(result:result,output:output)
        }
        func controls() -> P.Controls {
            .init(allocate:allocate,bitmap:bitmap,finish:{
                XCTAssertEqual(self.actor,400);XCTAssertEqual(self.ui,9);XCTAssertEqual(self.event,self.events.count)
                XCTAssertEqual(self.stores,10);self.finished = true;try self.fail("finish")
            })
        }
        func observe(_ o: P.Observation) throws {
            switch o {
            case .allocation(let a):expected.append(.allocation(a))
            case .constructor(let slot,let staging,let r):
                try reference.constructor(slot,staging,r)
                if staging && slot == 7 { try fail("constructor407") }
            case .pool(let p,let staging):try reference.pool(p,staging);if staging { try fail("pool") }
            case .interface(let e):
                if e.kind == .allocate { XCTAssertEqual(e.arguments,[0x1f50]) }
                else {
                    XCTAssertEqual(e.kind,.construct);let source = try next("construct")
                    XCTAssertEqual(source.index,ui);XCTAssertEqual(e.arguments,[R.uiTokens[ui],0x40,0])
                    XCTAssertEqual(e.strings,[Array(try XCTUnwrap(source.path).utf8)])
                }
            case .api(let q,let r):
                XCTAssertEqual(r,expectedReply);expected.append(.menu(.bitmap(q,r)));apis.append((q,r))
                if ui == 9 { try fail(q.kind+"10") }
            case .bitmapStored(let i,let g):
                XCTAssertEqual(g,try reference.globals(i));XCTAssertEqual(i,stores);stores += 1
                if i == 9 { try fail("lastGlobal") }
            }
        }
        func complete(_ p: P.PendingInput) throws {
            try reference.complete(p)
            XCTAssertEqual(p.allocations.count,410)
            XCTAssertEqual(p.allocations.map(\.kind),(0..<400).map(P.Allocation.Kind.actor)+(0..<10).map(P.Allocation.Kind.interface))
            XCTAssertEqual(p.allocations.map(\.token),R.actorTokens+R.uiTokens)
            XCTAssertEqual(p.allocations.map(\.count),[Int](repeating:0x420,count:400)+[Int](repeating:0x1f50,count:10))
            XCTAssertTrue(p.operations == p.entry.snapshot.operations.map(P.Operation.preceding)+expected,"Whole operation journal")
            try graphics(p)
            print("Owned pool/UI:400 allocations/408 constructor returns/two400-record phases/10UI;\(api) source API requests+responses; full entry bytes/masks and independent colors retained")
        }
        func graphics(_ p: P.PendingInput) throws {
            let old = p.entry.snapshot,prior = try XCTUnwrap(old.state.bitmapInputs),a = try XCTUnwrap(p.state.bitmapInputs)
            let oldG = try XCTUnwrap(old.state.graphics),g = try XCTUnwrap(p.state.graphics)
            XCTAssertEqual(Array(p.graphics.prefix(old.graphics.count)),old.graphics)
            let commands = Array(p.graphics.dropFirst(old.graphics.count));XCTAssertEqual(commands.count,apis.count)
            var refs = oldG.currentResources,next: [String:Int] = [:]
            for ref in oldG.resources.keys { next[ref.kind] = max(next[ref.kind,default:0],ref.generation+1) }
            var memoryIndex = prior.memoryDCs.count,dcIndex = prior.surfaceDCs.count
            var memoryRefs: [UInt32:G.Reference] = [:],dcRefs: [UInt32:G.Reference] = [:]
            func ref(_ p: UInt32) throws -> G.Reference { try XCTUnwrap(refs[p]) }
            func create(_ kind: String,_ token: UInt32) -> G.Reference {
                let r = G.Reference(kind:kind,token:token,generation:next[kind,default:0]);next[kind,default:0] += 1;refs[token] = r;return r
            }
            for (command,pair) in zip(commands,apis) {
                let (q,r) = pair,w = q.words;var bindings: [(String,G.Reference?)] = []
                switch q.kind {
                case "module":break
                case "image":if r.result != 0 { bindings = [("created",create("image",UInt32(bitPattern:r.result)))] }
                case "getObject","deleteObject":bindings = [("owner",try ref(w[0]))]
                case "createSurface":bindings = [("owner",try ref(w[0])),("created",create("bitmapSurface",try XCTUnwrap(r.output)))]
                case "createDC":
                    let token = UInt32(bitPattern:r.result),ref = G.Reference(kind:"memoryDC",token:token,generation:memoryIndex)
                    memoryIndex += 1;memoryRefs[token] = ref;bindings = [("created",ref)]
                case "selectObject":bindings = [("source",try ref(w[1])),("selectedDC",try XCTUnwrap(memoryRefs[w[0]]))]
                case "getDC":
                    let token = try XCTUnwrap(r.output),d = G.Reference(kind:"bitmapDC",token:token,generation:dcIndex)
                    dcIndex += 1;dcRefs[token] = d;bindings = [("owner",try ref(w[0])),("created",d)]
                case "stretch":bindings = [("target",try XCTUnwrap(dcRefs[w[0]])),("source",try XCTUnwrap(memoryRefs[w[5]]))]
                case "releaseDC":bindings = [("owner",try ref(w[0])),("dc",try XCTUnwrap(dcRefs[w[1]]))]
                case "deleteDC":bindings = [("dc",try XCTUnwrap(memoryRefs[w[0]]))]
                default:bindings = [("owner",try ref(w[0]))]
                }
                XCTAssertEqual(command.family,"bitmap");OriginalApplicationGraphicsTests.request(try XCTUnwrap(command.request),q)
                XCTAssertEqual(command.bitmapResponse,r);XCTAssertEqual(command.result,r.result);XCTAssertEqual(command.output,r.output)
                XCTAssertEqual(command.bindings.map(\.role),bindings.map(\.0));XCTAssertEqual(command.bindings.map(\.ref),bindings.map(\.1))
                XCTAssertTrue(command.dependencies.isEmpty);XCTAssertTrue(command.opaqueReferences.isEmpty)
                XCTAssertNil(command.windowResponse);XCTAssertNil(command.event);XCTAssertNil(command.sourceColors)
                XCTAssertNil(command.sourceRectangle);XCTAssertNil(command.destinationRectangle)
            }
            for (key,v) in prior.images { XCTAssertEqual(a.images[key],v) }
            for (key,v) in prior.surfaces { XCTAssertEqual(a.surfaces[key],v) }
            for (key,v) in oldG.resources { XCTAssertEqual(g.resources[key],v) }
            XCTAssertEqual(g.currentResources,refs);XCTAssertEqual(g.resources.count,oldG.resources.count+20)
            XCTAssertEqual(g.displayModes,oldG.displayModes);XCTAssertEqual(g.textLeases,oldG.textLeases);XCTAssertEqual(g.nextTextGeneration,oldG.nextTextGeneration)
            XCTAssertEqual(a.images.count,prior.images.count+10);XCTAssertEqual(a.surfaces.count,prior.surfaces.count+10)
            XCTAssertEqual(Array(a.memoryDCs.prefix(prior.memoryDCs.count)),prior.memoryDCs)
            XCTAssertEqual(Array(a.surfaceDCs.prefix(prior.surfaceDCs.count)),prior.surfaceDCs)
            XCTAssertEqual(a.memoryDCs.count,prior.memoryDCs.count+10);XCTAssertEqual(a.surfaceDCs.count,prior.surfaceDCs.count+10)
            XCTAssertEqual(a.activeMemoryDCs,prior.activeMemoryDCs);XCTAssertEqual(a.activeSurfaceDCs,prior.activeSurfaceDCs)
            let golden = try OriginalApplicationInterfaceInputsTests.golden.get()
            for i in 0..<10 {
                let image = UInt32(0x7a100000)+UInt32(i)*16,surface = UInt32(0x7b100000)+UInt32(i)*16
                let im = try XCTUnwrap(a.images[image]),s = try XCTUnwrap(a.surfaces[surface]),name = OriginalInitialInterfaceLoading.paths[i]
                XCTAssertEqual(im.bitmap,try OriginalApplicationInterfaceInputsTests.inputs.get().bitmaps[name])
                XCTAssertTrue(im.deleted);try golden.compare(im.bitmap.pixels,name)
                let item = try XCTUnwrap(golden.reference.resources.first { $0.name == name })
                XCTAssertTrue(Data(s.sourceColors.rgb) == golden.payload.subdata(in:item.rgbOffset..<item.rgbOffset+item.rgbCount))
                XCTAssertTrue(Data(s.sourceColors.defined.map { $0 ? 1 : 0 }) == golden.payload.subdata(in:item.maskOffset..<item.maskOffset+item.maskCount))
                XCTAssertEqual(s.sourceColors.width,item.width);XCTAssertEqual(s.sourceColors.height,item.height)
                XCTAssertTrue(s.releaseResults.isEmpty);XCTAssertEqual(s.copies.count,1)
                let copy = try XCTUnwrap(s.copies.first),stretch = try XCTUnwrap(apis.first { $0.0.kind == "stretch" && $0.0.words[0] == 0x7d100000+UInt32(i)*16 })
                XCTAssertEqual(copy.words,stretch.0.words);XCTAssertEqual(copy.result,stretch.1.result);XCTAssertEqual(copy.sourceImage,image)
                XCTAssertEqual(copy.memoryGeneration,prior.memoryDCs.count+i);XCTAssertEqual(copy.surfaceGeneration,prior.surfaceDCs.count+i)
                let md = a.memoryDCs[prior.memoryDCs.count+i],dc = a.surfaceDCs[prior.surfaceDCs.count+i]
                XCTAssertEqual(md.token,0x7c100000+UInt32(i)*16);XCTAssertEqual(md.selectedImage,image);XCTAssertEqual(md.deleteResults,[1])
                XCTAssertEqual(md.selections.map(\.image),[image])
                let selection = try XCTUnwrap(apis.first { $0.0.kind == "selectObject" && $0.0.words[1] == image })
                XCTAssertEqual(md.selections.map(\.result),[selection.1.result])
                XCTAssertEqual(dc.token,0x7d100000+UInt32(i)*16);XCTAssertEqual(dc.surface,surface);XCTAssertEqual(dc.acquireResult,0);XCTAssertEqual(dc.releaseResults,[0])
                let create = try XCTUnwrap(apis.first { $0.0.kind == "createSurface" && $0.1.output == surface }),key = try XCTUnwrap(apis.first { $0.0.kind == "colorKey" && $0.0.words[0] == surface })
                XCTAssertEqual(s.descriptor,try .init(bytes:XCTUnwrap(create.0.bytes),defined:XCTUnwrap(create.0.defined)))
                for (token,kind,event) in [(image,"image",try XCTUnwrap(apis.first { $0.0.kind == "image" && UInt32(bitPattern:$0.1.result) == image })),(surface,"bitmapSurface",create)] {
                    let resource = try XCTUnwrap(g.resources[ref(token)]);XCTAssertEqual(resource.ref.kind,kind)
                    XCTAssertEqual(resource.ref,try ref(token))
                    OriginalApplicationGraphicsTests.request(resource.creation,event.0);XCTAssertEqual(resource.createResult,event.1.result);XCTAssertTrue(resource.releaseResults.isEmpty)
                    if token == surface { OriginalApplicationGraphicsTests.request(try XCTUnwrap(resource.colorKey),key.0);XCTAssertEqual(resource.colorKeyResult,key.1.result) }
                    else { XCTAssertNil(resource.colorKey);XCTAssertNil(resource.colorKeyResult) }
                    XCTAssertNil(resource.clipper);XCTAssertNil(resource.clipperResult);XCTAssertNil(resource.palette)
                    XCTAssertNil(resource.paletteResult);XCTAssertNil(resource.pixelFormat)
                }
            }
        }
    }
    func testCompleteOwnedCatalogPoolAndInterface() throws {
        let entry = try Self.parent.get(),provider = try Provider(entry);var session = try P(pending:entry)
        let p = try session.prepare(inputs:OriginalApplicationInterfaceInputsTests.inputs.get(),makeControls:provider.controls,observe:provider.observe,beforeCommit:provider.complete)
        XCTAssertTrue(provider.finished);XCTAssertTrue(session.pendingInput != nil)
        XCTAssertEqual(p.loaded.bootstrap.world,provider.reference.world)
        XCTAssertThrowsError(try session.prepare(inputs:OriginalApplicationInterfaceInputsTests.inputs.get(),makeControls:provider.controls)) {
            XCTAssertEqual($0 as? P.Boundary,.alreadyPrepared)
        }
    }
    func testLateFailuresKeepWholeEntryAndFreshRetry() throws {
        let entry = try Self.parent.get(),inputs = try OriginalApplicationInterfaceInputsTests.inputs.get()
        for point in ["allocate399","constructor407","pool","createSurface10","deleteObject10","lastGlobal","finish","publication"] {
            var session = try P(pending:entry);let provider = try Provider(entry,point)
            XCTAssertThrowsError(try session.prepare(inputs:inputs,makeControls:provider.controls,observe:provider.observe,beforeCommit:{
                try provider.complete($0);throw Stop.injected("publication")
            })) { XCTAssertEqual($0 as? Stop,.injected(point)) }
            XCTAssertTrue(session.pendingInput == nil);F.Prior.retained(session.entry.snapshot.state,entry.snapshot.state)
            XCTAssertEqual(session.entry.snapshot.allocations,entry.snapshot.allocations)
            XCTAssertTrue(session.entry.snapshot.operations == entry.snapshot.operations)
            if point == "publication" {
                let fresh = try Provider(entry)
                _ = try session.prepare(inputs:inputs,makeControls:fresh.controls,observe:fresh.observe,beforeCommit:fresh.complete)
                XCTAssertFalse(provider === fresh);XCTAssertTrue(fresh.finished);XCTAssertTrue(session.pendingInput != nil)
            }
        }
    }
    func testOwnedRangeAndCapturedWriteBoundaries() throws {
        let entry = try Self.parent.get(),inputs = try OriginalApplicationInterfaceInputsTests.inputs.get()
        let live = try XCTUnwrap(entry.snapshot.state.memory.allocations.filter { $0.value.live }.keys.min())
        let tokens: [UInt32] = [0x458b00,0x70000020,entry.snapshot.objectTokens[0],live,
            try XCTUnwrap(entry.startup.music.allocations.keys.first),
            entry.startup.platforms[0].firstPointer,entry.entry.waveInputs[0].firstPointer,entry.snapshot.waveInputs[0].firstPointer,
            try XCTUnwrap(entry.files.streams.values.first).allocation.buffer]
        for kind in [P.Allocation.Kind.actor(0),.interface(0)] {
            for token in tokens {
                let provider = try Provider(entry);var session = try P(pending:entry)
                XCTAssertThrowsError(try session.prepare(inputs:inputs,makeControls:{ .init(allocate:{ k,n in
                    if k == kind { return .init(address:token,backing:[UInt8](repeating:0xa5,count:n)) }
                    return try provider.allocate(k,n)
                },bitmap:provider.bitmap) })) { XCTAssertEqual($0 as? P.Boundary,.overlap(token)) }
                XCTAssertTrue(session.pendingInput == nil);XCTAssertEqual(session.entry.snapshot.state.full,entry.snapshot.state.full)
            }
        }
        for malformed in ["nullActor","extent","capturedWrites"] {
            let provider = try Provider(entry);var session = try P(pending:entry)
            XCTAssertThrowsError(try session.prepare(inputs:inputs,makeControls:{ .init(allocate:{ kind,count in
                if malformed == "nullActor" { return .init(address:0,backing:[]) }
                if malformed == "extent" { return .init(address:0xfffffff0,backing:[UInt8](repeating:0xa5,count:count)) }
                return try provider.allocate(kind,count)
            },bitmap:{ _ in .init(writes:[.init(bytes:[0])]) }) })) {
                let expected: P.Boundary = malformed == "nullActor" ? .nullActor : .input(malformed == "extent" ? "Logical allocation extent" : "Captured bitmap writes")
                XCTAssertEqual($0 as? P.Boundary,expected)
            }
            XCTAssertTrue(session.pendingInput == nil)
        }
    }
}
