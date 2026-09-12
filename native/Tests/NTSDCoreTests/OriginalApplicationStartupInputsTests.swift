import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationStartupInputsTests: XCTestCase {
    typealias Inputs = OriginalApplicationStartupInputs
    static let shared: Result<Inputs,Error> = Result { try Inputs.bundled() }

    /// These are the explicit saved producer input formulas. No returned state,
    /// sc.input blob or Native output is used to select or author an overlay.
    static func control(_ label: String,_ package: Inputs) throws -> [UInt8] {
        let raw = try XCTUnwrap(package.file("data\\control.txt")),logical = try package.controlBytes()
        let text = String(decoding:logical,as:UTF8.self)
        let prefix = String(text[..<(try XCTUnwrap(text.range(of:"<No name>")).lowerBound)])
        switch label {
        case "raw":return raw
        case "trailing-lf":return logical+[10]
        case "empty":return []
        case "profile-tail-absent":return Array((prefix+"name\nemail").utf8)
        case "info99":return Array((prefix+"name\nemail\n"+String(repeating:"i",count:99)).utf8)
        case "info198":return Array((prefix+"name\nemail\n"+String(repeating:"i",count:198)).utf8)
        case "backtick":return Array(text.replacingOccurrences(of:"1 2 3 4\n",with:"one`a two``b ```four `\n").utf8)
        case "own-setting-1","own-setting--1":
            let setting = label == "own-setting-1" ? "1" : "-1"
            return Array(text.replacingOccurrences(of:"1 2 3 4\n0\n1\n",with:"1 2 3 4\n"+setting+"\n1\n").utf8)
        case "chunk1","chunk7","missing-file","close-negative":return logical
        default:
            guard (0...6).map({ "own-resource-\($0)" }).contains(label) else { throw Inputs.Boundary.unsupportedName(label) }
            return logical
        }
    }
    func testBundledInputsHavePinnedInitialFileAndBitmapProvenance() throws {
        let p = try Self.shared.get()
        func digest(_ bytes: [UInt8]) -> String { MatchPreparationReference.digest(Data(bytes)) }
        XCTAssertEqual(p.initial.bytes.count,0xc3a8);XCTAssertTrue(p.initial.defined.allSatisfy { $0 })
        XCTAssertEqual(digest(p.initial.bytes),"be350b20d7a33c12b8d6e8f29577709c7c1de76a82e233f581eeabb114ffc22f")
        XCTAssertEqual(digest(try XCTUnwrap(p.file("data\\adinfo.txt"))),"bbbc625958095740ae6f64a671c1673b5b1be1dad8a02de5e1c19b99528b759e")
        XCTAssertEqual(digest(try XCTUnwrap(p.file("data\\control.txt"))),"cc7f84872d9b95fe64c1c95cc7895b3e2c0a52a3ae0f7f7970f0b3c56b7037c0")
        XCTAssertEqual(digest(try p.controlBytes()),"6728804465456b893de32cb8bf9390b88843dbef58de25670e49834caaa177d9")
        XCTAssertEqual(p.bitmaps.count,36);XCTAssertEqual(p.bitmaps.values.reduce(0) { $0+$1.dib.count },28_986_014)
        for name in OriginalMenuSoundStartup.paths { XCTAssertGreaterThan(try XCTUnwrap(p.file(name)).count,44) }
        XCTAssertEqual(p.bitmaps.values.filter { $0.bitsPerPixel == 8 }.count,13)
        XCTAssertEqual(p.bitmaps.values.filter { $0.bitsPerPixel == 24 }.count,23)
        XCTAssertNil(try p.file("data\\ad0.txt"))
    }
    func copiedPackage() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-startup-inputs-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.copyItem(at:Inputs.bundledDirectory(),to:folder)
        return folder
    }
    func testSnapshotOwnsBytesAfterFilesDisappearAndOptionalOverlaysStaySeparate() throws {
        let directory = try copiedPackage()
        let p = try Inputs.load(directory:directory)
        let app = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-input-bundle-"+UUID().uuidString+".app",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:app) }
        let resources = app.appendingPathComponent("Contents/Resources",isDirectory:true)
        try FileManager.default.createDirectory(at:resources,withIntermediateDirectories:true)
        let plist: [String:Any] = ["CFBundleIdentifier":"local.ntsd.input-validation","CFBundlePackageType":"APPL","CFBundleExecutable":"unused"]
        try PropertyListSerialization.data(fromPropertyList:plist,format:.xml,options:0).write(to:app.appendingPathComponent("Contents/Info.plist"))
        let installed = resources.appendingPathComponent("OriginalStartup",isDirectory:true)
        try FileManager.default.moveItem(at:directory,to:installed)
        let bundle = try XCTUnwrap(Bundle(url:app))
        XCTAssertEqual(try Inputs.bundled(in:bundle),p)
        try FileManager.default.removeItem(at:installed)
        XCTAssertThrowsError(try Inputs.bundled(in:bundle),"An app must not fall back to developer SwiftPM resources")
        XCTAssertEqual(p,try Self.shared.get())
        let empty = try p.replacingFile("data\\ad0.txt",with:[])
        XCTAssertNil(try p.file("data\\ad0.txt"));XCTAssertEqual(try empty.file("data\\ad0.txt"),[])
        let changed = try p.replacingFile("data\\control.txt",with:[1,2,3])
        XCTAssertEqual(try changed.file("data\\control.txt"),[1,2,3]);XCTAssertEqual(try p.controlBytes().count,170)
        XCTAssertThrowsError(try p.file("data/control.txt"))
        XCTAssertThrowsError(try p.file("..\\data\\control.txt"))
        XCTAssertThrowsError(try p.replacingFile("unknown",with:[]))
    }
    func testPackageRejectsMissingCorruptAndUnexpectedFiles() throws {
        for kind in ["missing","corrupt","manifest","unexpected"] {
            let directory = try copiedPackage();defer { try? FileManager.default.removeItem(at:directory) }
            let file = directory.appendingPathComponent("data/m_ok.wav")
            switch kind {
            case "missing":try FileManager.default.removeItem(at:file)
            case "corrupt":var bytes = try Data(contentsOf:file);bytes[44] ^= 1;try bytes.write(to:file)
            case "manifest":try Data("{}".utf8).write(to:directory.appendingPathComponent("manifest.json"))
            default:try Data([0]).write(to:directory.appendingPathComponent("extra.bin"))
            }
            let expected: Inputs.Boundary
            switch kind {
            case "missing":expected = .missing("data/m_ok.wav")
            case "corrupt":expected = .invalid("data/m_ok.wav")
            case "manifest":expected = .invalid("Manifest digest")
            default:expected = .invalid("Package composition or PE masks")
            }
            XCTAssertThrowsError(try Inputs.load(directory:directory),kind) { error in
                XCTAssertEqual(error as? Inputs.Boundary,expected)
            }
        }
    }
    func testBitmapRepliesUseOwnedMetadataAndPreserveFailedAttempts() throws {
        typealias API = OriginalBitmapSurfaceLoading
        let p = try Self.shared.get(),bitmap = try XCTUnwrap(p.bitmaps["MENU_CLIP"])
        var bindings = OriginalApplicationBitmapInputs(resources:p.bitmaps)
        _ = try bindings.response(.init("image",[0x400000,0,0,0,0x2000],strings:[Array("MENU_CLIP".utf8)]),control:.init(result:17))
        let get = API.Request("getObject",[17,24])
        XCTAssertEqual(try bindings.response(get,control:.init(result:24)).writes,[.init(bytes:try bitmap.objectBytes())])
        XCTAssertEqual(try bindings.response(get,control:.init(result:0)).writes,[])
        var descriptor = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:108),defined:[Bool](repeating:true,count:108))
        try descriptor.write(UInt32(108),at:0);try descriptor.write(UInt32(7),at:4)
        try descriptor.write(bitmap.height,at:8);try descriptor.write(bitmap.width,at:12)
        _ = try bindings.response(.init("createSurface",[9,0],structure:descriptor),control:.init(result:1,output:31))
        XCTAssertEqual(bindings.surfaces[31]?.descriptor,descriptor,"Positive result has output but is not exact-zero loader continuation")
        XCTAssertEqual(try bindings.response(.init("description",[31]),control:.init(result:1)).writes,[.init(bytes:descriptor.bytes)])
        XCTAssertEqual(try bindings.response(.init("description",[31]),control:.init(result:-1)).writes,[])
        _ = try bindings.response(.init("release",[31]),control:.init(result:17))
        XCTAssertEqual(bindings.surfaces[31]?.releaseResults,[17])
        _ = try bindings.response(.init("deleteObject",[17]),control:.init(result:0))
        XCTAssertEqual(bindings.images[17]?.deleted,false)
        let prior = bindings
        XCTAssertThrowsError(try bindings.response(.init("createSurface",[9,0],structure:descriptor),control:.init(result:-1,output:32)))
        XCTAssertEqual(bindings,prior)
        XCTAssertThrowsError(try bindings.response(get,control:.init(result:24,writes:[.init(bytes:[9])])))
        XCTAssertEqual(bindings,prior)
        XCTAssertThrowsError(try bindings.response(.init("getObject",[999,24]),control:.init(result:24)))
        XCTAssertEqual(bindings,prior)
        _ = try bindings.response(.init("deleteObject",[17]),control:.init(result:1))
        XCTAssertThrowsError(try bindings.response(get,control:.init(result:24)))
        XCTAssertEqual(bindings.images[17]?.deleted,true)
    }
}
