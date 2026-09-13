import Foundation
import XCTest
import NTSDCore

final class OriginalApplicationInterfaceInputsTests: XCTestCase {
    struct Reference: Decodable {
        let resources: [OriginalDIBPixelsTests.Reference.Resource],payloadBytes: Int,payloadSHA256: String
    }
    struct Golden {
        let reference: Reference,payload: Data
        init() throws {
            reference = try JSONDecoder().decode(Reference.self,from:Data(contentsOf:XCTUnwrap(Bundle.module.url(
                forResource:"initial-interface-dib-pixels",withExtension:"json",subdirectory:"Fixtures"))))
            payload = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:"initial-interface-dib-pixels",withExtension:"bin",subdirectory:"Fixtures")))
            XCTAssertEqual(payload.count,reference.payloadBytes);XCTAssertEqual(OriginalDIBPixelsTests.digest(payload),reference.payloadSHA256)
        }
        func compare(_ pixels: OriginalDIBPixels,_ name: String) throws {
            let r = try XCTUnwrap(reference.resources.first { $0.name == name })
            XCTAssertEqual(pixels.width,r.width);XCTAssertEqual(pixels.height,r.height)
            XCTAssertTrue(Data(pixels.rgb) == payload.subdata(in:r.rgbOffset..<r.rgbOffset+r.rgbCount),name+" full RGB")
            XCTAssertTrue(Data(pixels.defined.map { $0 ? 1 : 0 }) == payload.subdata(in:r.maskOffset..<r.maskOffset+r.maskCount),name+" full mask")
        }
    }
    static let inputs: Result<OriginalApplicationInterfaceInputs,Error> = Result { try .bundled() }
    static let golden: Result<Golden,Error> = Result { try Golden() }
    func testTenOriginalDIBsFullPixelsMasksAndRows() throws {
        let package = try Self.inputs.get(),g = try Self.golden.get()
        XCTAssertEqual(Set(package.bitmaps.keys),Set(g.reference.resources.map(\.name)))
        var written = 0,unknown = 0,rows = 0
        for r in g.reference.resources {
            let bitmap = try XCTUnwrap(package.bitmaps[r.name]),p = bitmap.pixels
            XCTAssertEqual(OriginalDIBPixelsTests.digest(Data(bitmap.dib)),r.rawSHA256);try g.compare(p,r.name)
            for row in r.rows {
                let at = row.y*p.width,mask = Array(p.defined[at..<at+p.width])
                XCTAssertEqual(OriginalDIBPixelsTests.digest(Data(p.rgb[at*3..<(at+p.width)*3])),row.rgbSHA256)
                XCTAssertEqual(OriginalDIBPixelsTests.digest(Data(mask.map { $0 ? 1 : 0 })),row.maskSHA256)
                XCTAssertEqual(mask.filter { $0 }.count,row.writtenPixels);rows += 1
            }
            written += r.writtenPixels;unknown += r.unknownPixels
            XCTAssertEqual(p.defined.filter { $0 }.count,r.writtenPixels)
            if let at = p.defined.firstIndex(of:false) { XCTAssertThrowsError(try p.color(x:at%p.width,y:at/p.width)) }
        }
        XCTAssertEqual(written,96058);XCTAssertEqual(unknown,6875);XCTAssertEqual(rows,313)
    }
    func testOrdinaryAppPackageAndOwnedSnapshot() throws {
        let fm = FileManager.default,root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at:root) }
        let resources = root.appendingPathComponent("Interface.app/Contents/Resources"),package = resources.appendingPathComponent("OriginalLoadingInterface")
        try fm.createDirectory(at:resources,withIntermediateDirectories:true)
        try fm.copyItem(at:OriginalApplicationInterfaceInputs.bundledDirectory(),to:package)
        let app = resources.deletingLastPathComponent().deletingLastPathComponent()
        try Data("<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>test.interface</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>".utf8)
            .write(to:app.appendingPathComponent("Contents/Info.plist"))
        let bundle = try XCTUnwrap(Bundle(url:app)),owned = try OriginalApplicationInterfaceInputs.bundled(in:bundle)
        XCTAssertEqual(owned,try Self.inputs.get())
        try fm.removeItem(at:package)
        XCTAssertThrowsError(try OriginalApplicationInterfaceInputs.bundled(in:bundle))
        XCTAssertEqual(owned,try Self.inputs.get())
    }
    func testMissingCorruptExtraAndSymlinkPackagesAreRejected() throws {
        let fm = FileManager.default,root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at:root) };try fm.createDirectory(at:root,withIntermediateDirectories:true)
        for kind in ["missing","corrupt","manifest","extra","symlink"] {
            let p = root.appendingPathComponent(kind)
            try fm.copyItem(at:OriginalApplicationInterfaceInputs.bundledDirectory(),to:p)
            let dib = p.appendingPathComponent("PAUSE.dib")
            switch kind {
            case "missing":try fm.removeItem(at:dib)
            case "corrupt":var data = try Data(contentsOf:dib);data[data.count-1] ^= 1;try data.write(to:dib)
            case "manifest":try Data().write(to:p.appendingPathComponent("manifest.json"))
            case "extra":try Data().write(to:p.appendingPathComponent("extra"))
            default:try fm.removeItem(at:dib);try fm.createSymbolicLink(at:dib,withDestinationURL:OriginalApplicationInterfaceInputs.bundledDirectory().appendingPathComponent("PAUSE.dib"))
            }
            XCTAssertThrowsError(try OriginalApplicationInterfaceInputs.load(directory:p),kind)
        }
    }
}
