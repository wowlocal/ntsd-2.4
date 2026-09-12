import Foundation
import CryptoKit
import XCTest
import NTSDCore

final class OriginalDIBPixelsTests: XCTestCase {
    struct Reference: Decodable {
        struct Row: Decodable { let y: Int,rgbSHA256: String,maskSHA256: String,writtenPixels: Int }
        struct Resource: Decodable {
            let name: String,rawSHA256: String,width: Int,height: Int
            let rgbOffset: Int,rgbCount: Int,maskOffset: Int,maskCount: Int
            let rgbSHA256: String,maskSHA256: String,writtenPixels: Int,unknownPixels: Int
            let rows: [Row]
        }
        struct Control: Decodable {
            let name: String,dib: [UInt8],error: String?,maximumPixels: Int?
            let rgb: [UInt8]?,defined: [UInt8]?,width: Int?,height: Int?
        }
        let resources: [Resource],controls: [Control],payloadBytes: Int,payloadSHA256: String
    }
    struct Golden {
        let reference: Reference,payload: Data,bySHA: [String:Reference.Resource]
        init() throws {
            let manifest = try XCTUnwrap(Bundle.module.url(forResource:"startup-dib-pixels",withExtension:"json",subdirectory:"Fixtures"))
            reference = try JSONDecoder().decode(Reference.self,from:Data(contentsOf:manifest))
            payload = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:"startup-dib-pixels",withExtension:"bin",subdirectory:"Fixtures")))
            XCTAssertEqual(payload.count,reference.payloadBytes)
            XCTAssertEqual(OriginalDIBPixelsTests.digest(payload),reference.payloadSHA256)
            bySHA = Dictionary(reference.resources.map { ($0.rawSHA256,$0) },uniquingKeysWith:{ first,_ in first })
        }
    }
    static let golden: Result<Golden,Error> = Result { try Golden() }
    static func digest(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
    static func compare(_ pixels: OriginalDIBPixels,to item: Reference.Resource,in golden: Golden,
                        file: StaticString = #filePath,line: UInt = #line) {
        XCTAssertEqual(pixels.width,item.width,file:file,line:line);XCTAssertEqual(pixels.height,item.height,file:file,line:line)
        XCTAssertEqual(pixels.rgb.count,item.rgbCount,file:file,line:line);XCTAssertEqual(pixels.defined.count,item.maskCount,file:file,line:line)
        let rgb = golden.payload.subdata(in:item.rgbOffset..<item.rgbOffset+item.rgbCount)
        let mask = golden.payload.subdata(in:item.maskOffset..<item.maskOffset+item.maskCount)
        XCTAssertTrue(Data(pixels.rgb) == rgb,item.name+" full RGB bytes",file:file,line:line)
        XCTAssertTrue(Data(pixels.defined.map { $0 ? 1 : 0 }) == mask,item.name+" full mask bytes",file:file,line:line)
    }
    /// Expected files compare outputs only; Core receives original packaged DIBs.
    static func compareOwned(_ pixels: OriginalDIBPixels,rawDIB: [UInt8],
                             file: StaticString = #filePath,line: UInt = #line) throws {
        let g = try golden.get(),item = try XCTUnwrap(g.bySHA[digest(Data(rawDIB))],file:file,line:line)
        compare(pixels,to:item,in:g,file:file,line:line)
    }
    func testAllPackagedPixelsMatchIndependentBytesMasksAndRows() throws {
        let package = try OriginalApplicationStartupInputsTests.shared.get(),g = try Self.golden.get()
        XCTAssertEqual(Set(package.bitmaps.keys),Set(g.reference.resources.map(\.name)))
        var written = 0,unknown = 0,rows = 0
        for item in g.reference.resources {
            let bitmap = try XCTUnwrap(package.bitmaps[item.name]),pixels = bitmap.pixels
            XCTAssertEqual(Self.digest(Data(bitmap.dib)),item.rawSHA256)
            Self.compare(pixels,to:item,in:g)
            for row in item.rows {
                let at = row.y*pixels.width,mask = Array(pixels.defined[at..<at+pixels.width])
                XCTAssertEqual(Self.digest(Data(pixels.rgb[at*3..<(at+pixels.width)*3])),row.rgbSHA256)
                XCTAssertEqual(Self.digest(Data(mask.map { $0 ? 1 : 0 })),row.maskSHA256)
                XCTAssertEqual(mask.filter { $0 }.count,row.writtenPixels);rows += 1
            }
            XCTAssertEqual(pixels.defined.filter { $0 }.count,item.writtenPixels)
            written += item.writtenPixels;unknown += item.unknownPixels
            if let at = pixels.defined.firstIndex(of:false) {
                XCTAssertThrowsError(try pixels.color(x:at%pixels.width,y:at/pixels.width)) {
                    XCTAssertEqual($0 as? OriginalDIBPixels.Boundary,.undefinedPixel)
                }
            }
        }
        XCTAssertEqual(written,10_037_872);XCTAssertEqual(unknown,146_289);XCTAssertEqual(rows,14_632)
    }
    func testDeclaredDecoderControlsAndTypedRejections() throws {
        let g = try Self.golden.get();XCTAssertEqual(g.reference.controls.count,18)
        for c in g.reference.controls {
            if let error = c.error {
                XCTAssertThrowsError(try OriginalDIBPixels(dib:c.dib,maximumPixels:c.maximumPixels ?? 16_777_216),c.name) {
                    XCTAssertEqual(($0 as? OriginalDIBPixels.Boundary)?.rawValue,error,c.name)
                }
            } else {
                let p = try OriginalDIBPixels(dib:c.dib)
                XCTAssertEqual(p.rgb,c.rgb,c.name);XCTAssertEqual(p.defined.map { $0 ? UInt8(1) : 0 },c.defined,c.name)
                XCTAssertEqual(p.width,c.width,c.name);XCTAssertEqual(p.height,c.height,c.name)
                for (at,known) in p.defined.enumerated() {
                    if known { XCTAssertEqual(try p.color(x:at%p.width,y:at/p.width),Array(p.rgb[at*3..<at*3+3])) }
                    else { XCTAssertThrowsError(try p.color(x:at%p.width,y:at/p.width)) }
                }
            }
        }
    }
    func testImagePixelsStayImmutableAndDeletedHandlesDoNotRevive() throws {
        let package = try OriginalApplicationStartupInputsTests.shared.get()
        var bindings = OriginalApplicationBitmapInputs(resources:package.bitmaps)
        _ = try bindings.response(.init("image",[0x400000,0,0,0,0x2000],strings:[Array("LF2_CURSOR".utf8)]),control:.init(result:17))
        let pixels = try bindings.pixels(forImage:17),prior = bindings
        try Self.compareOwned(pixels,rawDIB:XCTUnwrap(package.bitmaps["LF2_CURSOR"]).dib)
        var changed = pixels.rgb;changed[0] ^= 1
        XCTAssertNotEqual(changed,pixels.rgb);XCTAssertEqual(try bindings.pixels(forImage:17),pixels)
        XCTAssertThrowsError(try OriginalDIBPixels(dib:[0,1,2]))
        XCTAssertEqual(bindings,prior,"Failed pre-transaction decoding cannot publish a partial image")
        XCTAssertThrowsError(try pixels.color(x:-1,y:0))
        XCTAssertThrowsError(try bindings.pixels(forImage:999));XCTAssertEqual(bindings,prior)
        _ = try bindings.response(.init("deleteObject",[17]),control:.init(result:0))
        XCTAssertEqual(try bindings.pixels(forImage:17),pixels)
        _ = try bindings.response(.init("deleteObject",[17]),control:.init(result:1))
        XCTAssertThrowsError(try bindings.pixels(forImage:17))
        XCTAssertEqual(bindings.images[17]?.bitmap.pixels,pixels,"Retained dead binding owns immutable data")
        let deleted = bindings
        XCTAssertThrowsError(try bindings.response(.init("image",[0x400000,0,0,0,0x2000],strings:[Array("LF2_CURSOR".utf8)]),control:.init(result:17)))
        XCTAssertEqual(bindings,deleted)
        _ = try bindings.response(.init("image",[0x400000,0,0,0,0x2000],strings:[Array("LF2_CURSOR".utf8)]),control:.init(result:18))
        XCTAssertEqual(try bindings.pixels(forImage:18),pixels)
        XCTAssertThrowsError(try bindings.pixels(forImage:17))
    }
}
