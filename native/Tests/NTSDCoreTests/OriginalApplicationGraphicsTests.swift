import Foundation
import XCTest
import NTSDCore

final class OriginalApplicationGraphicsTests: XCTestCase {
    typealias G = OriginalApplicationGraphics
    struct Reply: Decodable {
        let result: Int32,output: UInt32?,bytes: [UInt8]?,writes: [OriginalBitmapSurfaceLoading.Write]?
    }
    struct Command: Decodable {
        let eventIndex: Int,family: String,request: OriginalWindowInitialization.Request?,response: Reply?
        let event: OriginalFrontScreenEvent?,result: Int32?,output: UInt32?
    }
    struct Stage: Decodable { let commands: [Command] }
    struct Relation: Decodable {
        struct Colors: Decodable { let surfaceGeneration: Int,rawSHA256: String? }
        let stage: String,eventIndex: Int,bindings: [G.Binding],dependencies: [String]
        let opaqueReferences: [G.OpaqueReference]?,sourceRectangle: [Int32]?,destinationRectangle: [Int32]?,sourceColors: Colors?
    }
    struct Acquisition: Decodable {
        struct Release: Decodable { let result: Int32 }
        let ref: G.Reference,owner: G.Reference,acquireResult: Int32,releaseRequests: [Release]
    }
    struct Chain: Decodable {
        let rootKind: String,caseIndex: Int,stages: [String],bitmapLifetime: String,commandRelations: [Relation]
        let commandCount: Int,textAcquisitions: [Acquisition],nextTextGeneration: Int,finalActiveTextGenerations: [G.Reference]
    }
    struct Lifetime: Decodable { let frontIndex: Int,operations: [Relation] }
    struct Reference: Decodable {
        let stages: [String:Stage],chains: [Chain],bitmapLifetimes: [String:Lifetime],rasterDependencies: [String]
    }
    static let reference: Result<Reference,Error> = Result {
        let url = try XCTUnwrap(Bundle.module.url(forResource:"startup-graphics-owners",withExtension:"json",subdirectory:"Fixtures"))
        return try JSONDecoder().decode(Reference.self,from:Data(contentsOf:url))
    }
    static func chain(_ kind: String,_ index: Int) throws -> Chain {
        try XCTUnwrap(reference.get().chains.first { $0.rootKind == kind && $0.caseIndex == index })
    }
    static func request(_ actual: OriginalWindowInitialization.Request,_ expected: OriginalWindowInitialization.Request) {
        XCTAssertEqual(actual.kind,expected.kind);XCTAssertEqual(actual.words,expected.words);XCTAssertEqual(actual.strings,expected.strings)
        XCTAssertEqual(actual.defined,expected.defined);XCTAssertEqual(actual.bytes?.count,expected.bytes?.count)
        if let a = actual.bytes,let b = expected.bytes,let mask = expected.defined,a.count == b.count,b.count == mask.count {
            XCTAssertTrue(zip(zip(a,b),mask).allSatisfy { !$0.1 || $0.0.0 == $0.0.1 },"Known request bytes")
        } else { XCTAssertEqual(actual.bytes,expected.bytes) }
    }
    static func front(_ actual: OriginalFrontScreenEvent,_ expected: OriginalFrontScreenEvent) {
        // Original opaque DDBLTFX backing is audited, not imported by Native.
        if let a = actual.fill,let b = expected.fill {
            XCTAssertEqual(a.target,b.target);XCTAssertEqual(a.rectangle,b.rectangle);XCTAssertEqual(a.flags,b.flags)
            XCTAssertEqual(a.defined,b.defined);XCTAssertEqual(a.effects.count,b.effects.count)
            XCTAssertTrue(zip(zip(a.effects,b.effects),b.defined).allSatisfy { !$0.1 || $0.0.0 == $0.0.1 })
            var x = actual,y = expected;x.fill = nil;y.fill = nil;XCTAssertEqual(x,y)
        } else { XCTAssertEqual(actual,expected) }
    }
    /// All expected payloads and bindings were frozen independently before Core.
    /// A failed attempt compares its exact prefix; full routes require full count.
    static func compare(_ actual: [G.Command],kind: String,index: Int,stageKind: String? = nil,
        prefix: Bool = false,inputs: OriginalApplicationBitmapInputs? = nil) throws {
        let r = try reference.get(),c = try chain(kind,index)
        let allRelations = c.commandRelations + (try XCTUnwrap(r.bitmapLifetimes[c.bitmapLifetime])).operations
        var relations: [String:Relation] = [:]
        for relation in allRelations { relations[relation.stage+"#\(relation.eventIndex)"] = relation }
        let expected: [(Command,Relation)] = try c.stages.filter { stageKind == nil || $0.hasPrefix(stageKind!+":") }.flatMap { id in
            try XCTUnwrap(r.stages[id]).commands.map { ($0,try XCTUnwrap(relations[id+"#\($0.eventIndex)"])) }
        }
        if stageKind == nil { XCTAssertEqual(expected.count,c.commandCount) }
        if prefix { XCTAssertLessThanOrEqual(actual.count,expected.count) } else { XCTAssertEqual(actual.count,expected.count,"\(kind) \(index) graphics count") }
        for (i,pair) in zip(actual,expected).enumerated() {
            let a = pair.0,e = pair.1.0,binding = pair.1.1
            XCTAssertEqual(a.family,e.family,"\(kind) \(index) command \(i)")
            if let q = e.request {
                request(try XCTUnwrap(a.request),q)
                let reply = try XCTUnwrap(e.response)
                if e.family == "window" { XCTAssertEqual(a.windowResponse,.init(result:reply.result,output:reply.output,bytes:reply.bytes)) }
                else { XCTAssertEqual(a.bitmapResponse,.init(result:reply.result,writes:reply.writes ?? [],output:reply.output)) }
            } else { front(try XCTUnwrap(a.event),try XCTUnwrap(e.event)) }
            XCTAssertEqual(a.result,e.response?.result ?? e.result)
            XCTAssertEqual(a.output,e.response?.output ?? e.output)
            XCTAssertEqual(a.bindings,binding.bindings,"\(kind) \(index) bindings \(i)")
            XCTAssertEqual(a.dependencies,binding.dependencies);XCTAssertEqual(a.opaqueReferences,binding.opaqueReferences ?? [])
            if e.event?.kind == "method",e.event?.arguments[1] == 20 {
                XCTAssertEqual(a.destinationRectangle,binding.destinationRectangle);XCTAssertEqual(a.sourceRectangle,binding.sourceRectangle)
            }
            if e.event?.kind == "blit" {
                XCTAssertEqual(a.sourceRectangle,e.event?.blit?.source);XCTAssertEqual(a.destinationRectangle,e.event?.blit?.destination)
            }
            if e.event?.kind == "fill" { XCTAssertEqual(a.destinationRectangle,e.event?.fill?.rectangle) }
            if binding.sourceColors != nil {
                let token = try XCTUnwrap(binding.bindings.first { $0.role == "source" }?.ref?.token)
                let colors = try XCTUnwrap(a.sourceColors),lifetime = try XCTUnwrap(r.bitmapLifetimes[c.bitmapLifetime])
                let saved = try XCTUnwrap(OriginalSurfaceSourceColorsTests.reference.get().lifetimes.first { $0.frontIndex == lifetime.frontIndex }).surfaces[try XCTUnwrap(binding.sourceColors).surfaceGeneration]
                XCTAssertEqual(saved.token,token);XCTAssertEqual(colors.width,saved.width);XCTAssertEqual(colors.height,saved.height)
                if let sha = saved.rawSHA256 {
                    let golden = try OriginalDIBPixelsTests.golden.get(),item = try XCTUnwrap(golden.bySHA[sha])
                    XCTAssertTrue(Data(colors.rgb) == golden.payload.subdata(in:item.rgbOffset..<item.rgbOffset+item.rgbCount))
                    XCTAssertTrue(Data(colors.defined.map { $0 ? UInt8(1) : 0 }) == golden.payload.subdata(in:item.maskOffset..<item.maskOffset+item.maskCount))
                } else { XCTAssertTrue(colors.rgb.allSatisfy { $0 == 0 });XCTAssertTrue(colors.defined.allSatisfy { !$0 }) }
                if let inputs { XCTAssertTrue(try inputs.sourceColors(forSurface:token) == colors) }
            } else { XCTAssertNil(a.sourceColors) }
        }
    }
    static func compareOwner(_ owner: G?,kind: String,index: Int) throws {
        let owner = try XCTUnwrap(owner),c = try chain(kind,index),r = try reference.get()
        XCTAssertEqual(owner.nextTextGeneration,c.nextTextGeneration)
        XCTAssertEqual(Set(owner.textLeases.values.map(\.ref)),Set(c.finalActiveTextGenerations))
        for ref in c.finalActiveTextGenerations {
            let i = ref.generation
            let a = try XCTUnwrap(owner.textLeases[i]),e = c.textAcquisitions[i]
            XCTAssertEqual(a.ref,ref);XCTAssertEqual(a.ref,e.ref);XCTAssertEqual(a.owner,e.owner);XCTAssertEqual(a.acquireResult,e.acquireResult)
            XCTAssertEqual(a.releaseResults,e.releaseRequests.map(\.result))
        }
        let relations = c.commandRelations + (try XCTUnwrap(r.bitmapLifetimes[c.bitmapLifetime])).operations
        let byLocation = Dictionary(uniqueKeysWithValues:relations.map { ($0.stage+"#\($0.eventIndex)",$0) })
        var created = Set<G.Reference>(),releases: [G.Reference:[Int32]] = [:]
        var keys: [G.Reference:(OriginalWindowInitialization.Request,Int32)] = [:]
        var formats: [G.Reference:OriginalWindowInitialization.Response] = [:]
        var clippers: [G.Reference:(G.Reference,Int32)] = [:]
        for stage in c.stages {
            for command in try XCTUnwrap(r.stages[stage]).commands {
                let binding = try XCTUnwrap(byLocation[stage+"#\(command.eventIndex)"])
                if let ref = binding.bindings.first(where:{ $0.role == "created" })?.ref,
                   !["memoryDC","bitmapDC","textDC"].contains(ref.kind) {
                    created.insert(ref)
                    let actual = try XCTUnwrap(owner.resources[ref])
                    request(actual.creation,try XCTUnwrap(command.request));XCTAssertEqual(actual.createResult,command.response?.result)
                    XCTAssertEqual(actual.ref,ref);XCTAssertEqual(owner.currentResources[ref.token],ref)
                }
                guard let ref = binding.bindings.first(where:{ $0.role == "owner" })?.ref else { continue }
                if command.request?.kind == "release" || (command.event?.kind == "method" && command.event?.arguments[1] == 8) {
                    releases[ref,default:[]].append(try XCTUnwrap(command.response?.result ?? command.result))
                }
                if let q = command.request,let response = command.response {
                    if q.kind == "colorKey" { keys[ref] = (q,response.result) }
                    if q.kind == "pixelFormat" { formats[ref] = .init(result:response.result,output:response.output,bytes:response.bytes) }
                    if q.kind == "setClipper" { clippers[ref] = (try XCTUnwrap(binding.bindings.first { $0.role == "source" }?.ref),response.result) }
                }
            }
        }
        XCTAssertEqual(Set(owner.resources.keys),created)
        for ref in created {
            let actual = try XCTUnwrap(owner.resources[ref])
            XCTAssertEqual(actual.releaseResults,releases[ref] ?? [])
            XCTAssertEqual(actual.pixelFormat,formats[ref]);XCTAssertNil(actual.palette);XCTAssertNil(actual.paletteResult)
            XCTAssertEqual(actual.clipper,clippers[ref]?.0);XCTAssertEqual(actual.clipperResult,clippers[ref]?.1)
            if let key = keys[ref] { request(try XCTUnwrap(actual.colorKey),key.0);XCTAssertEqual(actual.colorKeyResult,key.1) }
            else { XCTAssertNil(actual.colorKey);XCTAssertNil(actual.colorKeyResult) }
        }
        XCTAssertTrue(owner.displayModes.isEmpty)
        XCTAssertEqual(G.rasterDependencies,try reference.get().rasterDependencies)
    }

    static func display() throws -> G {
        var g = G()
        _ = try g.window(.init("directDrawCreate",[0,0,0]),.init(output:1))
        for (token,caps): (UInt32,UInt32) in [(2,0x200),(3,0x40)] {
            var descriptor = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:108),defined:[Bool](repeating:false,count:108))
            for (offset,value): (Int,UInt32) in [(0,108),(4,7),(8,550),(12,794),(104,caps)] { try descriptor.write(value,at:offset) }
            _ = try g.window(.init("createSurface",[1,0,0],structure:descriptor),.init(output:token))
        }
        return g
    }
    func testDeclaredTextAcquisitionsAndUnresolvedCleanup() throws {
        var g = try Self.display()
        func text(_ kind: String,_ args: [UInt32],_ result: Int32 = 0,_ output: UInt32? = nil) throws -> G.Command {
            try g.front(.init(kind,args),result:result,output:output)
        }
        _ = try text("getDC",[3],0,0)
        XCTAssertEqual(g.nextTextGeneration,1);XCTAssertEqual(g.textLeases[0]?.ref.token,0)
        _ = try text("setBackgroundMode",[0,1]);_ = try text("textOut",[0,1,2,0])
        XCTAssertEqual(try text("releaseDC",[3,0],-1).dependencies,["unresolvedTextLease"])
        XCTAssertEqual(try text("getDC",[3],1,0).dependencies,["unresolvedTextLease"])
        XCTAssertEqual(g.nextTextGeneration,2)
        XCTAssertEqual(try text("releaseDC",[3,0],0).dependencies,["unresolvedTextLease"])
        XCTAssertEqual(Set(g.textLeases.keys),[0]);XCTAssertEqual(g.textLeases[0]?.releaseResults,[-1])
        let before = g
        XCTAssertThrowsError(try text("textOut",[0,1,2,0]));XCTAssertEqual(g,before)
        _ = try text("getDC",[3],-1)
        XCTAssertEqual(g,before)
        XCTAssertThrowsError(try text("getDC",[999],0,10));XCTAssertEqual(g,before)
        _ = try text("getDC",[3],0,45)
        _ = try text("releaseDC",[3,45],-1)
        let unresolved = g.textLeases,oldGeneration = g.nextTextGeneration
        _ = try text("getDC",[3],-1)
        XCTAssertEqual(g.textLeases,unresolved);XCTAssertEqual(g.nextTextGeneration,oldGeneration)
        let rejectedSequence = g
        XCTAssertThrowsError(try text("textOut",[45,1,2,0]));XCTAssertEqual(g,rejectedSequence)
    }
    func testDisplayGenerationsLiveTargetsPaletteAndRectangles() throws {
        var g = try Self.display()
        _ = try g.window(.init("createClipper",[1,0,0,0]),.init(output:4))
        _ = try g.window(.init("setClipper",[2,4]),.init(result:-1))
        _ = try g.window(.init("release",[4]),.init(result:17))
        _ = try g.window(.init("setPalette",[2,55]),.init())
        let primary = try XCTUnwrap(g.currentResources[2]),clipper = try XCTUnwrap(g.currentResources[4])
        XCTAssertEqual(g.resources[primary]?.palette,55);XCTAssertNil(g.currentResources[55])
        XCTAssertEqual(g.resources[primary]?.clipper,clipper);XCTAssertEqual(g.resources[clipper]?.releaseResults,[17])
        var q = try XCTUnwrap(g.resources[XCTUnwrap(g.currentResources[3])]).creation
        _ = try g.window(q,.init(output:5))
        _ = try g.window(.init("pixelFormat",[2]),.init(result:-1,bytes:[UInt8](repeating:8,count:32)))
        let clear = try g.window(.init("blt",[5,0,0,0,0x1000400]),.init(result:-1))
        XCTAssertEqual(clear.bindings[0].ref?.token,5);XCTAssertEqual(clear.dependencies,[])
        let zero = try g.front(.init("method",[2,20,99,3,0,0x1000000,0],[[UInt8](repeating:0,count:16)]),result:0)
        let null = try g.front(.init("method",[2,20,0,3,0,0x1000000,0]),result:0)
        XCTAssertEqual(zero.destinationRectangle,[0,0,0,0]);XCTAssertNil(null.destinationRectangle);XCTAssertNotEqual(zero,null)
        let oldBack = try XCTUnwrap(g.currentResources[3])
        _ = try g.window(.init("release",[3]),.init(result:0))
        q = try XCTUnwrap(g.resources[oldBack]).creation
        _ = try g.window(q,.init(output:3))
        XCTAssertNotEqual(g.currentResources[3],oldBack);XCTAssertEqual(g.resources[oldBack]?.releaseResults,[0])
        XCTAssertEqual(g.resources[primary]?.palette,55);XCTAssertEqual(g.currentResources[4],clipper)
        _ = try g.window(.init("setPalette",[2,0]),.init());XCTAssertEqual(g.resources[primary]?.palette,0)
        _ = try g.window(.init("displayMode",[1,794,550,8]),.init())
        XCTAssertEqual(g.displayModes[try XCTUnwrap(g.currentResources[1])]?.words,[1,794,550,8])
        let before = g
        XCTAssertThrowsError(try g.window(.init("blt",[999,0,0,0,0x1000400]),.init()));XCTAssertEqual(g,before)
        XCTAssertThrowsError(try g.window(q,.init(output:3)));XCTAssertEqual(g,before)
    }
    func testResolvedSourceSnapshotAndNullSourceBoundary() throws {
        let package = try OriginalApplicationStartupInputsTests.shared.get()
        var inputs = OriginalApplicationBitmapInputs(resources:package.bitmaps),g = try Self.display()
        func call(_ kind: String,_ words: [UInt32],_ result: Int32 = 0,output: UInt32? = nil,
                  strings: [[UInt8]] = [],structure: OriginalStateRecord? = nil) throws {
            let q = OriginalBitmapSurfaceLoading.Request(kind,words,strings:strings,structure:structure)
            var nextInputs = inputs,nextGraphics = g
            let response = try nextInputs.response(q,control:.init(result:result,output:output))
            _ = try nextGraphics.bitmap(q,response,inputs:nextInputs)
            inputs = nextInputs;g = nextGraphics
        }
        try call("image",[1,0,0,0,0x2000],20,strings:[Array("CS2".utf8)])
        var descriptor = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:108),defined:[Bool](repeating:true,count:108))
        for (at,value): (Int,UInt32) in [(0,108),(4,7),(8,2),(12,2),(104,0x40)] { try descriptor.write(value,at:at) }
        try call("createSurface",[1,0],output:10,structure:descriptor)
        try call("createDC",[0],30);try call("selectObject",[30,20],1);try call("getDC",[10],output:31)
        let copy: [UInt32] = [31,0,0,2,2,30,0,0,2,2,0xcc0020]
        try call("stretch",copy,1)
        func event(_ source: UInt32) throws -> OriginalFrontScreenEvent {
            var e = OriginalFrontScreenEvent("blit")
            let object: [String:Any] = ["sourceSurface":source,"targetSurface":3,"source":[0,0,2,2],"destination":[0,0,2,2],"flags":0x1008000]
            e.blit = try JSONDecoder().decode(OriginalBitmapBlit.self,from:JSONSerialization.data(withJSONObject:object));return e
        }
        let saved = try g.front(event(10),result:0,inputs:inputs),colors = try XCTUnwrap(saved.sourceColors)
        XCTAssertTrue(colors.defined.allSatisfy { $0 })
        try call("stretch",copy,0)
        XCTAssertTrue(try inputs.sourceColors(forSurface:10).defined.allSatisfy { !$0 })
        try call("releaseDC",[10,31]);try call("deleteDC",[30],1);try call("deleteObject",[20],1);try call("release",[10],17)
        XCTAssertTrue(saved.sourceColors == colors);XCTAssertTrue(colors.defined.allSatisfy { $0 })
        let null = try g.front(event(0),result:-1,inputs:inputs)
        XCTAssertEqual(null.dependencies,["nullSource"]);XCTAssertNil(null.sourceColors);XCTAssertNil(null.bindings[1].ref)
        let before = g
        XCTAssertThrowsError(try g.front(event(999),result:0,inputs:inputs));XCTAssertEqual(g,before)
    }
}
