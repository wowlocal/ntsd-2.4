import Foundation
import XCTest
import NTSDCore

final class OriginalSurfaceSourceColorsTests: XCTestCase {
    typealias Inputs = OriginalApplicationBitmapInputs
    typealias Colors = OriginalSurfaceSourceColors
    typealias API = OriginalBitmapSurfaceLoading
    struct Reference: Decodable {
        struct Copy: Decodable {
            let words: [UInt32],result: Int32,sourceImage: UInt32,memoryGeneration: Int,surfaceGeneration: Int
        }
        struct Surface: Decodable {
            let token: UInt32,width: Int,height: Int,rawSHA256: String?,releaseResults: [Int32],copies: [Copy]
        }
        struct Selection: Decodable { let image: UInt32,result: Int32 }
        struct MemoryDC: Decodable { let token: UInt32,selections: [Selection],deleteResults: [Int32] }
        struct SurfaceDC: Decodable { let token: UInt32,surface: UInt32,acquireResult: Int32,releaseResults: [Int32] }
        struct Operation: Decodable { let request: API.Request,response: API.Response }
        struct Lifetime: Decodable {
            let frontIndex: Int,operations: [Operation],surfaces: [Surface],memoryDCs: [MemoryDC],surfaceDCs: [SurfaceDC]
        }
        struct Release: Decodable { let eventIndex: Int,surface: UInt32,result: Int32 }
        struct Pixels: Decodable { let dib: [UInt8],rgb: [UInt8],defined: [UInt8] }
        struct Expected: Decodable { let rgb: [UInt8],defined: [UInt8] }
        struct Controls: Decodable { let rgb: Pixels,rle: Pixels,partial: Expected,failedCopy: Expected,controlNames: [String] }
        let version: Int,lifetimes: [Lifetime],inputReleaseEvents: [String:[Release]],controls: Controls
    }
    static let reference: Result<Reference,Error> = Result {
        let path = try XCTUnwrap(Bundle.module.url(forResource:"startup-surface-colors",withExtension:"json",subdirectory:"Fixtures"))
        return try JSONDecoder().decode(Reference.self,from:Data(contentsOf:path))
    }

    static func compareOwned(_ actual: Inputs,frontIndex: Int,file: StaticString = #filePath,line: UInt = #line) throws {
        let expected = try XCTUnwrap(reference.get().lifetimes.first { $0.frontIndex == frontIndex },file:file,line:line)
        let golden = try OriginalDIBPixelsTests.golden.get()
        XCTAssertEqual(Set(actual.surfaces.keys),Set(expected.surfaces.map(\.token)),file:file,line:line)
        for source in expected.surfaces {
            let surface = try XCTUnwrap(actual.surfaces[source.token],file:file,line:line),colors = surface.sourceColors
            XCTAssertEqual(colors.width,source.width,file:file,line:line);XCTAssertEqual(colors.height,source.height,file:file,line:line)
            XCTAssertEqual(try surface.descriptor.integer(at:12,as:Int32.self),Int32(source.width),file:file,line:line)
            XCTAssertEqual(try surface.descriptor.integer(at:8,as:Int32.self),Int32(source.height),file:file,line:line)
            XCTAssertEqual(colors.rgb.count,source.width*source.height*3,file:file,line:line)
            XCTAssertEqual(colors.defined.count,source.width*source.height,file:file,line:line)
            if let sha = source.rawSHA256 {
                let item = try XCTUnwrap(golden.bySHA[sha],file:file,line:line)
                XCTAssertTrue(Data(colors.rgb) == golden.payload.subdata(in:item.rgbOffset..<item.rgbOffset+item.rgbCount),"surface full RGB",file:file,line:line)
                XCTAssertTrue(Data(colors.defined.map { $0 ? UInt8(1) : 0 }) == golden.payload.subdata(in:item.maskOffset..<item.maskOffset+item.maskCount),"surface full mask",file:file,line:line)
            } else {
                XCTAssertTrue(colors.rgb.allSatisfy { $0 == 0 },file:file,line:line)
                XCTAssertTrue(colors.defined.allSatisfy { !$0 },file:file,line:line)
            }
            XCTAssertEqual(surface.releaseResults,source.releaseResults,file:file,line:line)
            XCTAssertEqual(surface.copies.count,source.copies.count,file:file,line:line)
            for (a,e) in zip(surface.copies,source.copies) {
                XCTAssertEqual(a.words,e.words,file:file,line:line);XCTAssertEqual(a.result,e.result,file:file,line:line)
                XCTAssertEqual(a.sourceImage,e.sourceImage,file:file,line:line)
                XCTAssertEqual(a.memoryGeneration,e.memoryGeneration,file:file,line:line);XCTAssertEqual(a.surfaceGeneration,e.surfaceGeneration,file:file,line:line)
            }
            XCTAssertTrue(try actual.sourceColors(forSurface:source.token) == colors,file:file,line:line)
        }
        XCTAssertEqual(actual.memoryDCs.count,expected.memoryDCs.count,file:file,line:line)
        for (a,e) in zip(actual.memoryDCs,expected.memoryDCs) {
            XCTAssertEqual(a.token,e.token,file:file,line:line);XCTAssertEqual(a.deleteResults,e.deleteResults,file:file,line:line)
            XCTAssertEqual(a.selectedImage,e.selections.last { $0.result != 0 }?.image,file:file,line:line)
            XCTAssertEqual(a.selections.map(\.image),e.selections.map(\.image),file:file,line:line)
            XCTAssertEqual(a.selections.map(\.result),e.selections.map(\.result),file:file,line:line)
        }
        XCTAssertEqual(actual.surfaceDCs.count,expected.surfaceDCs.count,file:file,line:line)
        for (a,e) in zip(actual.surfaceDCs,expected.surfaceDCs) {
            XCTAssertEqual(a.token,e.token,file:file,line:line);XCTAssertEqual(a.surface,e.surface,file:file,line:line)
            XCTAssertEqual(a.acquireResult,e.acquireResult,file:file,line:line);XCTAssertEqual(a.releaseResults,e.releaseResults,file:file,line:line)
        }
        XCTAssertTrue(actual.activeMemoryDCs.isEmpty,file:file,line:line);XCTAssertTrue(actual.activeSurfaceDCs.isEmpty,file:file,line:line)
    }

    /// Only independent saved Release events before this exact cursor extend
    /// the original parent. Never mutate a Native owner to build an expectation.
    static func compareInput(_ actual: Inputs?,parent: Inputs,inputIndex: Int,eventEnd: Int,
                             file: StaticString = #filePath,line: UInt = #line) throws {
        let actual = try XCTUnwrap(actual,file:file,line:line)
        let releases = try XCTUnwrap(reference.get().inputReleaseEvents[String(inputIndex)],file:file,line:line).filter { $0.eventIndex < eventEnd }
        XCTAssertTrue(actual.images == parent.images,file:file,line:line)
        XCTAssertEqual(actual.memoryDCs,parent.memoryDCs,file:file,line:line);XCTAssertEqual(actual.surfaceDCs,parent.surfaceDCs,file:file,line:line)
        XCTAssertEqual(actual.activeMemoryDCs,parent.activeMemoryDCs,file:file,line:line);XCTAssertEqual(actual.activeSurfaceDCs,parent.activeSurfaceDCs,file:file,line:line)
        XCTAssertEqual(Set(actual.surfaces.keys),Set(parent.surfaces.keys),file:file,line:line)
        for (token,old) in parent.surfaces {
            let current = try XCTUnwrap(actual.surfaces[token],file:file,line:line)
            XCTAssertEqual(current.descriptor,old.descriptor,file:file,line:line)
            XCTAssertTrue(current.sourceColors == old.sourceColors,file:file,line:line)
            XCTAssertEqual(current.copies,old.copies,file:file,line:line)
            XCTAssertEqual(current.releaseResults,old.releaseResults+releases.filter { $0.surface == token }.map(\.result),file:file,line:line)
        }
        XCTAssertTrue(releases.allSatisfy { parent.surfaces[$0.surface] != nil },file:file,line:line)
    }

    func testAllSavedLifetimesOwnExactColorsMasksAndDCGenerations() throws {
        let r = try Self.reference.get(),package = try OriginalApplicationStartupInputsTests.shared.get()
        XCTAssertEqual(r.version,1);XCTAssertEqual(r.lifetimes.map(\.frontIndex),Array(0...34)+Array(36...40))
        var operations = 0,surfaces = 0,copies = 0,memory = 0,target = 0
        for lifetime in r.lifetimes {
            var inputs = Inputs(resources:package.bitmaps)
            for operation in lifetime.operations {
                let saved = operation.request
                // Only the fully known CreateSurface descriptor is an input.
                // Other private request backing is deliberately not imported.
                let descriptor: OriginalStateRecord?
                if saved.kind == "createSurface" {
                    let mask = try XCTUnwrap(saved.defined);XCTAssertTrue(mask.allSatisfy { $0 })
                    descriptor = try .init(bytes:XCTUnwrap(saved.bytes),defined:mask)
                } else { descriptor = nil }
                let request = API.Request(saved.kind,saved.words,strings:saved.strings,structure:descriptor)
                let reply = try inputs.response(request,control:.init(result:operation.response.result,output:operation.response.output))
                XCTAssertEqual(reply,operation.response,"full independently saved API response")
                operations += 1
            }
            try Self.compareOwned(inputs,frontIndex:lifetime.frontIndex)
            surfaces += inputs.surfaces.count;copies += inputs.surfaces.values.reduce(0) { $0+$1.copies.count }
            memory += inputs.memoryDCs.count;target += inputs.surfaceDCs.count
        }
        XCTAssertEqual(operations,16_929);XCTAssertEqual(surfaces,995);XCTAssertEqual(copies,992)
        XCTAssertEqual(memory,993);XCTAssertEqual(target,992)
    }

    func testKnownBlackUnknownPartialCopiesAndAtomicBounds() throws {
        let c = try Self.reference.get().controls
        XCTAssertEqual(c.controlNames.count,16) // SelectObject -1 is the separate frozen amendment.
        let rgb = try OriginalDIBPixels(dib:c.rgb.dib),rle = try OriginalDIBPixels(dib:c.rle.dib)
        var colors = try Colors(width:2,height:2)
        XCTAssertThrowsError(try colors.color(x:0,y:0)) { XCTAssertEqual($0 as? Colors.Boundary,.undefinedPixel) }
        try colors.copy(rgb,width:2,height:2)
        XCTAssertEqual(colors.rgb,c.rgb.rgb);XCTAssertEqual(colors.defined.map { $0 ? UInt8(1) : 0 },c.rgb.defined)
        XCTAssertEqual(try colors.color(x:0,y:0),[0,0,0])
        let retained = colors
        try colors.copy(rle,width:2,height:2)
        XCTAssertEqual(colors.rgb,c.rle.rgb);XCTAssertEqual(colors.defined.map { $0 ? UInt8(1) : 0 },c.rle.defined)
        XCTAssertThrowsError(try colors.color(x:1,y:0));XCTAssertEqual(retained.rgb,c.rgb.rgb)
        colors = retained;try colors.invalidate(x:1,y:0,width:1,height:1)
        XCTAssertEqual(colors.rgb,c.failedCopy.rgb);XCTAssertEqual(colors.defined.map { $0 ? UInt8(1) : 0 },c.failedCopy.defined)
        var partial = try Colors(width:3,height:3);try partial.copy(rgb,width:2,height:2,x:1,y:1)
        XCTAssertEqual(partial.rgb,c.partial.rgb);XCTAssertEqual(partial.defined.map { $0 ? UInt8(1) : 0 },c.partial.defined)
        let before = partial
        XCTAssertThrowsError(try partial.copy(rgb,sourceX:1,width:2,height:2));XCTAssertEqual(partial,before)
        XCTAssertThrowsError(try partial.copy(rgb,width:2,height:2,x:2));XCTAssertEqual(partial,before)
        XCTAssertThrowsError(try partial.copy(rgb,width:Int.max,height:2));XCTAssertEqual(partial,before)
        XCTAssertThrowsError(try partial.invalidate(x:Int.max,y:0,width:1,height:1));XCTAssertEqual(partial,before)
        XCTAssertThrowsError(try Colors(width:0,height:2)) { XCTAssertEqual($0 as? Colors.Boundary,.extent) }
        for (w,h,budget) in [(2,2,3),(Int.max,2,Int.max),(Int.max/2,1,Int.max),(2,2,0)] {
            XCTAssertThrowsError(try Colors(width:w,height:h,maximumPixels:budget)) { XCTAssertEqual($0 as? Colors.Boundary,.pixelLimit) }
        }
    }

    func testSelectionCleanupReuseAndReleaseControls() throws {
        let package = try OriginalApplicationStartupInputsTests.shared.get()
        var inputs = Inputs(resources:package.bitmaps)
        let first = try XCTUnwrap(package.bitmaps["LF2_CURSOR"]).pixels,second = try XCTUnwrap(package.bitmaps["CS2"]).pixels
        let distinct = try XCTUnwrap((0..<min(first.height,second.height)).lazy.flatMap { y in
            (0..<min(first.width,second.width)).map { (x:$0,y:y) }
        }.first { p in
            let a = p.y*first.width+p.x,b = p.y*second.width+p.x
            return first.defined[a] && second.defined[b] && Array(first.rgb[a*3..<a*3+3]) != Array(second.rgb[b*3..<b*3+3])
        })
        func call(_ kind: String,_ words: [UInt32] = [],_ result: Int32 = 0,output: UInt32? = nil,
                  structure: OriginalStateRecord? = nil,strings: [[UInt8]] = []) throws {
            _ = try inputs.response(.init(kind,words,strings:strings,structure:structure),control:.init(result:result,output:output))
        }
        func reject(_ kind: String,_ words: [UInt32],_ result: Int32 = 0,output: UInt32? = nil) {
            let before = inputs
            XCTAssertThrowsError(try call(kind,words,result,output:output));XCTAssertTrue(inputs == before,"Rejected API is atomic")
        }
        for (name,token) in [("LF2_CURSOR",Int32(17)),("CS2",Int32(18))] {
            try call("image",[0x400000,0,0,0,0x2000],token,strings:[Array(name.utf8)])
        }
        var descriptor = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:108),defined:[Bool](repeating:true,count:108))
        for (at,value) in [(0,UInt32(108)),(4,7),(8,2),(12,2)] { try descriptor.write(value,at:at) }
        try call("createSurface",[1,0],output:90,structure:descriptor)
        try call("createSurface",[1,0],1,output:91,structure:descriptor)
        XCTAssertTrue(try inputs.sourceColors(forSurface:91).defined.allSatisfy { !$0 })
        let memory: UInt32 = 0x80000010,target: UInt32 = 0x80000020
        try call("createDC",[0],0);XCTAssertTrue(inputs.memoryDCs.isEmpty)
        try call("createDC",[0],Int32(bitPattern:memory))
        reject("createDC",[0],Int32(bitPattern:memory));reject("getDC",[90],output:memory)
        try call("getDC",[90],-1);XCTAssertTrue(inputs.surfaceDCs.isEmpty)
        try call("getDC",[90],output:target)
        reject("getDC",[90],output:target);reject("createDC",[0],Int32(bitPattern:target))
        let words: [UInt32] = [target,0,0,1,1,memory,UInt32(distinct.x),UInt32(distinct.y),1,1,0x00cc0020]
        try call("selectObject",[memory,17],0);reject("stretch",words,1)
        try call("selectObject",[memory,17],Int32(bitPattern:0x80000030))
        let selected = inputs
        XCTAssertThrowsError(try call("selectObject",[memory,18],-1)) { XCTAssertEqual($0 as? Inputs.Boundary,.unsupportedSelection) }
        XCTAssertTrue(inputs == selected)
        try call("selectObject",[memory,18],0);try call("stretch",words,-1)
        XCTAssertEqual(try inputs.sourceColors(forSurface:90).color(x:0,y:0),try first.color(x:distinct.x,y:distinct.y))
        XCTAssertEqual(inputs.surfaces[90]?.copies.last?.sourceImage,17)
        let retained = try inputs.sourceColors(forSurface:90)
        try call("stretch",words,0)
        XCTAssertTrue(try inputs.sourceColors(forSurface:90).defined.allSatisfy { !$0 })
        XCTAssertEqual(try retained.color(x:0,y:0),try first.color(x:distinct.x,y:distinct.y))
        try call("selectObject",[memory,18],17);try call("stretch",words,1)
        XCTAssertEqual(try inputs.sourceColors(forSurface:90).color(x:0,y:0),try second.color(x:distinct.x,y:distinct.y))
        let copied = try inputs.sourceColors(forSurface:90)
        try call("releaseDC",[90,target],-1);try call("deleteDC",[memory],0)
        reject("getDC",[90],output:target);reject("createDC",[0],Int32(bitPattern:memory))
        XCTAssertEqual(inputs.activeMemoryDCs[memory],0);XCTAssertEqual(inputs.activeSurfaceDCs[target],0)
        try call("releaseDC",[90,target]);try call("deleteDC",[memory],-1)
        try call("getDC",[90],output:target);try call("createDC",[0],Int32(bitPattern:memory))
        XCTAssertEqual(inputs.activeMemoryDCs[memory],1);XCTAssertEqual(inputs.activeSurfaceDCs[target],1)
        reject("stretch",words,1) // New generation has no selected image.
        try call("selectObject",[memory,17],1);try call("stretch",words,1)
        XCTAssertEqual(inputs.surfaces[90]?.copies.last?.memoryGeneration,1);XCTAssertEqual(inputs.surfaces[90]?.copies.last?.surfaceGeneration,1)
        try call("releaseDC",[90,target]);try call("deleteDC",[memory],1)
        XCTAssertEqual(inputs.memoryDCs[0].deleteResults,[0,-1]);XCTAssertEqual(inputs.surfaceDCs[0].releaseResults,[-1,0])
        let colors = try inputs.sourceColors(forSurface:90)
        try call("deleteObject",[17],1);try call("deleteObject",[18],1)
        XCTAssertTrue(try inputs.sourceColors(forSurface:90) == colors);XCTAssertThrowsError(try inputs.pixels(forImage:17))
        XCTAssertEqual(try copied.color(x:0,y:0),try second.color(x:distinct.x,y:distinct.y))
        for result in [Int32(0),17,-1] { try call("release",[90],result) }
        XCTAssertEqual(inputs.surfaces[90]?.releaseResults,[0,17,-1]);XCTAssertTrue(try inputs.sourceColors(forSurface:90) == colors)
        reject("release",[999]);XCTAssertThrowsError(try inputs.sourceColors(forSurface:999))
        var limited = Inputs(resources:package.bitmaps,maximumSurfacePixels:3)
        XCTAssertThrowsError(try limited.response(.init("createSurface",[1,0],structure:descriptor),control:.init(output:99))) {
            XCTAssertEqual($0 as? Colors.Boundary,.pixelLimit)
        }
        XCTAssertTrue(limited.surfaces.isEmpty)
    }
}
