import Foundation
import CryptoKit
import XCTest
import NTSDCore
import Compression

/// Original image files are inputs; independently fixed RGB/masks are outputs.
/// This does not compare Windows pixels or a returned application catalog.
final class OriginalCatalogDIBPixelsTests: XCTestCase {
    struct Golden: Decodable {
        struct Blob: Decodable { let count: Int,deflate: String }
        struct Resource: Decodable {
            let name: String,kind: String,input: String,dibSHA256: String,rgb: String,mask: String
            let width: Int,height: Int,bits: Int,compression: Int,pixelOffset: Int
            let writtenPixels: Int,unknownPixels: Int
        }
        struct Control: Decodable {
            let name: String,kind: String,input: [UInt8],error: String?
            let rgb: [UInt8]?,defined: [UInt8]?,width: Int?,height: Int?,maximumPixels: Int?,pixelOffset: Int?
        }
        let resources: [Resource],controls: [Control],blobs: [String:Blob]
        func bytes(_ key: String) throws -> [UInt8] {
            let blob = try XCTUnwrap(blobs[key])
            let bytes = try OriginalCatalogDIBPixelsTests.inflate(blob.deflate,count:blob.count,maximumCount:100_000_000)
            XCTAssertEqual(OriginalCatalogDIBPixelsTests.digest(bytes),key)
            return bytes
        }
        func bitmap(_ r: Resource) throws -> OriginalApplicationStartupInputs.Bitmap {
            let raw = try bytes(r.input)
            return try r.kind == "bmp" ? .init(bitmapFile:raw) : .init(dib:raw)
        }
    }
    // Test transport only: the existing reference helper is internal to its
    // module. Decode the same raw-deflate representation without changing Core.
    static func inflate(_ text: String,count: Int,maximumCount: Int) throws -> [UInt8] {
        guard (0...maximumCount).contains(count),let source = Data(base64Encoded:text),!source.isEmpty else {
            throw OriginalStateError.invalidStorage("Catalog fixture compressed block")
        }
        var bytes = [UInt8](repeating:0,count:count+1)
        let actual = bytes.withUnsafeMutableBufferPointer { output in
            source.withUnsafeBytes { input in
                compression_decode_buffer(output.baseAddress!,output.count,input.bindMemory(to:UInt8.self).baseAddress!,input.count,nil,COMPRESSION_ZLIB)
            }
        }
        guard actual == count else { throw OriginalStateError.invalidStorage("Catalog fixture compressed length") }
        bytes.removeLast();return bytes
    }
    static func digest(_ bytes: [UInt8]) -> String { SHA256.hash(data:Data(bytes)).map { String(format:"%02x",$0) }.joined() }
    static let golden: Result<Golden,Error> = Result {
        let url = try XCTUnwrap(Bundle.module.url(forResource:"original-catalog-dib-pixels.json",withExtension:"zlib",subdirectory:"Fixtures"))
        let packed = try Data(contentsOf:url)
        XCTAssertEqual(packed.count,48_082_802)
        XCTAssertEqual(digest(Array(packed)),"05c80127a13d8991ae9ca62a785bc416527ff8de52fc3e3630ab0f46ba174eb1")
        let raw = try OriginalCatalogDIBPixelsTests.inflate(packed.base64EncodedString(),count:66_335_316,maximumCount:100_000_000)
        XCTAssertEqual(digest(raw),"35c483a8fdf469670ac2ecfd758d088b8e526fcc4b95fc912f8bf099f718ae0d")
        return try JSONDecoder().decode(Golden.self,from:Data(raw))
    }
    func testEveryOriginalCatalogImageMatchesAllColorsAndMasks() throws {
        let g = try Self.golden.get();XCTAssertEqual(g.resources.count,669)
        var files = 0,embedded = 0,written = 0,unknown = 0
        for r in g.resources {
            let b = try g.bitmap(r),p = b.pixels
            XCTAssertEqual(Self.digest(b.dib),r.dibSHA256,r.name)
            XCTAssertEqual(p.width,r.width,r.name);XCTAssertEqual(p.height,r.height,r.name)
            XCTAssertTrue(p.rgb == (try g.bytes(r.rgb)),r.name+" full RGB")
            XCTAssertTrue(p.defined.map { $0 ? UInt8(1) : 0 } == (try g.bytes(r.mask)),r.name+" full mask")
            XCTAssertEqual(b.width,Int32(r.width));XCTAssertEqual(b.height,Int32(r.height))
            XCTAssertEqual(b.bitsPerPixel,UInt16(r.bits));XCTAssertEqual(b.planes,1)
            XCTAssertEqual(b.rowBytes,Int32(((r.width*r.bits+31)/32)*4))
            let metadata = try OriginalStateRecord(bytes:b.objectBytes(),defined:[Bool](repeating:true,count:24))
            XCTAssertEqual(try metadata.integer(at:4,as:Int32.self),Int32(r.width))
            XCTAssertEqual(try metadata.integer(at:8,as:Int32.self),Int32(r.height))
            XCTAssertEqual(try metadata.integer(at:12,as:Int32.self),b.rowBytes)
            XCTAssertEqual(try metadata.integer(at:18,as:UInt16.self),UInt16(r.bits))
            if r.kind == "bmp" {
                files += 1;XCTAssertEqual(b.bitmapFileHeader,Array(try g.bytes(r.input).prefix(14)))
                XCTAssertEqual(b.pixelOffset,r.pixelOffset)
            } else { embedded += 1;XCTAssertNil(b.bitmapFileHeader) }
            XCTAssertEqual(p.defined.filter { $0 }.count,r.writtenPixels)
            if let at = p.defined.firstIndex(of:false) {
                XCTAssertThrowsError(try p.color(x:at%p.width,y:at/p.width)) {
                    XCTAssertEqual($0 as? OriginalDIBPixels.Boundary,.undefinedPixel)
                }
            }
            written += r.writtenPixels;unknown += r.unknownPixels
        }
        XCTAssertEqual(files,665);XCTAssertEqual(embedded,4)
        XCTAssertEqual(written,227_759_411);XCTAssertEqual(unknown,2_765)
    }
    func testFixedIndexedPaletteAndFileOffsetControls() throws {
        let g = try Self.golden.get();XCTAssertEqual(g.controls.count,22)
        for c in g.controls {
            func decode() throws -> OriginalDIBPixels {
                if c.kind == "bmp" { return try OriginalApplicationStartupInputs.Bitmap(bitmapFile:c.input).pixels }
                return try .init(dib:c.input,maximumPixels:c.maximumPixels ?? 16_777_216,pixelOffset:c.pixelOffset)
            }
            if let expected = c.error {
                XCTAssertThrowsError(try decode(),c.name) { error in
                    if let error = error as? OriginalDIBPixels.Boundary { XCTAssertEqual(error.rawValue,expected,c.name) }
                    else if let error = error as? OriginalApplicationStartupInputs.Boundary {
                        if case .invalid = error { XCTAssertEqual(expected,"invalid",c.name) }
                        else { XCTFail("Unexpected BMP boundary: \(error)") }
                    } else { XCTFail("Unexpected error: \(error)") }
                }
            } else {
                let p = try decode()
                XCTAssertEqual(p.rgb,c.rgb,c.name);XCTAssertEqual(p.defined.map { $0 ? UInt8(1) : 0 },c.defined,c.name)
                XCTAssertEqual(p.width,c.width,c.name);XCTAssertEqual(p.height,c.height,c.name)
                if c.kind == "bmp" {
                    let b = try OriginalApplicationStartupInputs.Bitmap(bitmapFile:c.input)
                    XCTAssertEqual(b.bitmapFileHeader,Array(c.input.prefix(14)))
                    XCTAssertEqual(b.dib,Array(c.input.dropFirst(14)),"Original gap/header remain in the input")
                }
            }
        }
    }
    func testAddingFileInputsRetainsOwnersAndRejectsOriginConflictsAtomically() throws {
        let startup = try OriginalApplicationStartupInputsTests.shared.get(),g = try Self.golden.get()
        var owner = OriginalApplicationBitmapInputs(resources:startup.bitmaps)
        let q = OriginalBitmapSurfaceLoading.Request("image",[0x400000,0,0,0,0x2000],strings:[Array("LF2_CURSOR".utf8)])
        _ = try owner.response(q,control:.init(result:17))
        var descriptor = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:108),defined:[Bool](repeating:true,count:108))
        try descriptor.write(UInt32(108),at:0);try descriptor.write(UInt32(6),at:4)
        try descriptor.write(UInt32(19),at:8);try descriptor.write(UInt32(11),at:12)
        _ = try owner.response(.init("createSurface",[0x24000020],structure:descriptor),control:.init(result:0,output:18))
        _ = try owner.response(.init("createDC",[0]),control:.init(result:19))
        _ = try owner.response(.init("selectObject",[19,17]),control:.init(result:20))
        _ = try owner.response(.init("getDC",[18]),control:.init(result:0,output:21))
        _ = try owner.response(.init("releaseDC",[18,21]),control:.init(result:0))
        _ = try owner.response(.init("deleteDC",[19]),control:.init(result:1))
        let old = owner
        let r = try XCTUnwrap(g.resources.first { $0.kind == "bmp" && $0.bits == 4 }),file = try g.bitmap(r)
        try owner.addResources([r.name:file])
        XCTAssertEqual(owner.images,old.images);XCTAssertEqual(owner.surfaces,old.surfaces)
        XCTAssertEqual(owner.memoryDCs,old.memoryDCs);XCTAssertEqual(owner.surfaceDCs,old.surfaceDCs)
        XCTAssertEqual(owner.activeMemoryDCs,old.activeMemoryDCs);XCTAssertEqual(owner.activeSurfaceDCs,old.activeSurfaceDCs)
        XCTAssertEqual(try owner.pixels(forImage:17),try old.pixels(forImage:17))
        let extended = owner
        try owner.addResources([r.name:file]);XCTAssertEqual(owner,extended)
        let packed = try OriginalApplicationStartupInputs.Bitmap(dib:file.dib)
        XCTAssertEqual(packed.pixels,file.pixels);XCTAssertNotEqual(packed,file,"Origin is owned provenance")
        XCTAssertThrowsError(try owner.addResources(["new-unpublished":file,r.name:packed]));XCTAssertEqual(owner,extended)
        let fileRequest = OriginalBitmapSurfaceLoading.Request("image",[0x400000,0,0,0,0x2010],strings:[Array(r.name.utf8)])
        _ = try owner.response(fileRequest,control:.init(result:22))
        XCTAssertEqual(try owner.pixels(forImage:22),file.pixels)
        let now = owner
        XCTAssertThrowsError(try owner.response(.init("image",q.words,strings:[Array(r.name.utf8)]),control:.init(result:23)))
        XCTAssertEqual(owner,now)
        XCTAssertThrowsError(try owner.response(.init("image",fileRequest.words,strings:q.strings),control:.init(result:23)))
        XCTAssertEqual(owner,now)
        // Missing file and unsuccessful lookup do not require an input binding.
        _ = try owner.response(.init("image",fileRequest.words,strings:[Array("missing.bmp".utf8)]),control:.init(result:0))
        XCTAssertEqual(owner,now)
        _ = try owner.response(.init("image",fileRequest.words,strings:q.strings),control:.init(result:0))
        XCTAssertEqual(owner,now)
        _ = try owner.response(q,control:.init(result:24))
        XCTAssertEqual(try owner.pixels(forImage:24),try owner.pixels(forImage:17))
        // Exercise the file-origin image through generated API metadata and
        // the next surface consumer. Expected colors come from the fixed corpus.
        let metadata = try owner.response(.init("getObject",[22,24]),control:.init(result:24))
        var expectedObject = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:24),defined:[Bool](repeating:true,count:24))
        try expectedObject.write(Int32(r.width),at:4);try expectedObject.write(Int32(r.height),at:8)
        try expectedObject.write(Int32(((r.width*r.bits+31)/32)*4),at:12)
        try expectedObject.write(UInt16(1),at:16);try expectedObject.write(UInt16(r.bits),at:18)
        XCTAssertEqual(metadata,.init(result:24,writes:[.init(bytes:expectedObject.bytes)]))
        try descriptor.write(UInt32(2),at:8);try descriptor.write(UInt32(3),at:12)
        _ = try owner.response(.init("createSurface",[0x24000020,0],structure:descriptor),control:.init(result:0,output:26))
        _ = try owner.response(.init("createDC",[0]),control:.init(result:25))
        _ = try owner.response(.init("selectObject",[25,22]),control:.init(result:1))
        _ = try owner.response(.init("getDC",[26]),control:.init(result:0,output:27))
        let copy: [UInt32] = [27,0,0,3,2,25,0,0,3,2,0x00cc0020]
        _ = try owner.response(.init("stretch",copy),control:.init(result:1))
        let colors = try owner.sourceColors(forSurface:26),expectedRGB = try g.bytes(r.rgb),expectedMask = try g.bytes(r.mask)
        var rectangleRGB: [UInt8] = [],rectangleMask: [Bool] = []
        for y in 0..<2 {
            rectangleRGB += expectedRGB[(y*r.width)*3..<(y*r.width+3)*3]
            rectangleMask += expectedMask[y*r.width..<y*r.width+3].map { $0 == 1 }
        }
        XCTAssertEqual(colors.rgb,rectangleRGB);XCTAssertEqual(colors.defined,rectangleMask)
        let copied = owner
        var invalid = copy;invalid[6] = UInt32(r.width)
        XCTAssertThrowsError(try owner.response(.init("stretch",invalid),control:.init(result:1)))
        XCTAssertEqual(owner,copied)
        _ = try owner.response(.init("releaseDC",[26,27]),control:.init(result:0))
        _ = try owner.response(.init("deleteDC",[25]),control:.init(result:1))
        _ = try owner.response(.init("deleteObject",[22]),control:.init(result:1))
        XCTAssertThrowsError(try owner.pixels(forImage:22))
        XCTAssertEqual(try owner.sourceColors(forSurface:26),colors)
        XCTAssertEqual(owner.images[17],old.images[17]);XCTAssertEqual(owner.surfaces[18],old.surfaces[18])
    }
}
