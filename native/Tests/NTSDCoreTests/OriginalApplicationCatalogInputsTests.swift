import Foundation
import XCTest
import NTSDCore

final class OriginalApplicationCatalogInputsTests: XCTestCase {
    typealias Inputs = OriginalApplicationCatalogInputs
    static let shared: Result<Inputs,Error> = Result { try Inputs.bundled() }
    let fm = FileManager.default

    func testCompleteOriginalInputMapsAndImageOrigins() throws {
        let inputs = try Self.shared.get(),r = try OriginalApplicationCatalogFullReference()
        XCTAssertTrue(inputs.files == (try r.fixtureFiles()),"All521 original input names and bytes")
        XCTAssertEqual(Set(inputs.bitmaps.keys),Set(r.golden.resources.map(\.name)))
        var files = 0,embedded = 0
        for resource in r.golden.resources {
            let expected = try r.golden.bitmap(resource),actual = try XCTUnwrap(inputs.bitmaps[resource.name])
            XCTAssertTrue(actual == expected,resource.name+" complete bytes, origin, metadata, RGB and masks")
            if resource.kind == "bmp" { files += 1;XCTAssertNotNil(actual.bitmapFileHeader) }
            else { embedded += 1;XCTAssertNil(actual.bitmapFileHeader) }
        }
        XCTAssertEqual(files,665);XCTAssertEqual(embedded,4)
        // Separately pinned baseline WMA bytes; this is no decoding/playback claim.
        let music = [
            "boss1":"851b9337cf258e59f8c2ba34c884507644b81cbceebb3d8e4ab6fa763e5a6d8e",
            "boss2":"5806bb56d2dcb6d05af3362c080d6be5c92418a432d2f5bedeb743380fbb82c9",
            "main":"e3448b9b8445e3483b18e2eab4eaf60592695e73771728d6857f1cc02a583e2d",
            "stage1":"82ae94243bbd6ab4513713f67f23773196cacc0bf4560ccb18c87e752641e8f3",
            "stage2":"568be15688c780495521fc7aa3c1c3df9712bd6031257b4c873b754a61911f4f",
            "stage3":"3557950e4a5d83dc10d711862f27649b6758471c34b5c23ab4003b276cf3ce39",
            "stage4":"323ec7712db42b348c50964b919d3859b206f3da9f6f5b8d61f433741db92a36",
            "stage5":"1af041e596fe69f67c214a6d9c6ccc410dd969212fa0ac688aade0fe43ffe435"]
        XCTAssertEqual(Set(inputs.music.keys),Set(music.keys.map { "bgm\\"+$0+".wma" }))
        for (name,sha) in music { XCTAssertEqual(OriginalCatalogDIBPixelsTests.digest(try inputs.musicFile("bgm\\"+name+".wma")),sha) }
        XCTAssertEqual(inputs.music.values.reduce(0) { $0+$1.count },14_455_318)
        XCTAssertThrowsError(try inputs.musicFile("bgm\\missing.wma"))
    }
    func copiedPackage() throws -> URL {
        let folder = fm.temporaryDirectory.appendingPathComponent("ntsd-catalog-inputs-"+UUID().uuidString,isDirectory:true)
        try fm.copyItem(at:Inputs.bundledDirectory(),to:folder)
        return folder
    }
    func testOwnedSnapshotSurvivesFilesAndOverlaysStaySeparate() throws {
        let folder = try copiedPackage();defer { try? fm.removeItem(at:folder) }
        let inputs = try Inputs.load(directory:folder),name = "data\\data.txt"
        let original = try XCTUnwrap(inputs.file(name))
        try Data([9]).write(to:folder.appendingPathComponent("files/data/data.txt"))
        XCTAssertEqual(try inputs.file(name),original)
        try fm.removeItem(at:folder)
        XCTAssertTrue(inputs == (try Self.shared.get()),"All bytes and decoded images remain owned")
        let missing = try inputs.replacingFile(name,with:nil),empty = try inputs.replacingFile(name,with:[])
        XCTAssertNil(try missing.file(name));XCTAssertEqual(try empty.file(name),[])
        XCTAssertEqual(try inputs.file(name),original)
        XCTAssertEqual(try missing.replacingFile(name,with:original).file(name),original)
        for unknown in ["data/data.txt","DATA\\DATA.TXT","..\\data\\data.txt","missing"] {
            XCTAssertThrowsError(try inputs.file(unknown))
            XCTAssertThrowsError(try inputs.replacingFile(unknown,with:[]))
        }
    }
    func testRejectsIncompleteCorruptConflictingAndNonregularPackages() throws {
        for kind in ["missing","empty","corrupt","duplicate","conflict","extra","extra-directory","file-link","directory-link","file-directory","root-link"] {
            let folder = try copiedPackage();defer { try? fm.removeItem(at:folder) }
            let file = folder.appendingPathComponent("files/data/data.txt"),manifest = folder.appendingPathComponent("manifest.json")
            var readFolder = folder
            let link = folder.appendingPathExtension("link");defer { try? fm.removeItem(at:link) }
            switch kind {
            case "missing":try fm.removeItem(at:file)
            case "empty":try Data().write(to:file)
            case "corrupt":var bytes = try Data(contentsOf:file);bytes[0] ^= 1;try bytes.write(to:file)
            case "duplicate","conflict":
                var object = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:manifest)) as? [String:Any])
                var entries = try XCTUnwrap(object["entries"] as? [[String:Any]])
                var duplicate = entries[0]
                if kind == "conflict" { duplicate["kind"] = "dib" }
                entries.append(duplicate);object["entries"] = entries
                try JSONSerialization.data(withJSONObject:object,options:[.sortedKeys]).write(to:manifest)
            case "extra":try Data([0]).write(to:folder.appendingPathComponent("extra.bin"))
            case "extra-directory":try fm.createDirectory(at:folder.appendingPathComponent("extra"),withIntermediateDirectories:false)
            case "file-link":
                try fm.removeItem(at:file);try fm.createSymbolicLink(at:file,withDestinationURL:manifest)
            case "directory-link":
                let sub = folder.appendingPathComponent("files/data")
                try fm.moveItem(at:sub,to:link);try fm.createSymbolicLink(at:sub,withDestinationURL:link)
            case "file-directory":try fm.removeItem(at:file);try fm.createDirectory(at:file,withIntermediateDirectories:false)
            case "root-link":try fm.createSymbolicLink(at:link,withDestinationURL:folder);readFolder = link
            default:XCTFail("Unknown control")
            }
            var published: Inputs?
            XCTAssertThrowsError(try { published = try Inputs.load(directory:readFolder) }(),kind)
            XCTAssertNil(published,"Failed load publishes no snapshot: "+kind)
        }
    }
    func testRelocatedAppUsesOrdinaryPackageWithoutFallback() throws {
        let app = fm.temporaryDirectory.appendingPathComponent("ntsd-catalog-bundle-"+UUID().uuidString+".app",isDirectory:true)
        defer { try? fm.removeItem(at:app) }
        let resources = app.appendingPathComponent("Contents/Resources",isDirectory:true)
        try fm.createDirectory(at:resources,withIntermediateDirectories:true)
        let plist = ["CFBundleIdentifier":"local.ntsd.catalog-input-validation","CFBundlePackageType":"APPL","CFBundleExecutable":"unused"]
        try PropertyListSerialization.data(fromPropertyList:plist,format:.xml,options:0).write(to:app.appendingPathComponent("Contents/Info.plist"))
        let installed = resources.appendingPathComponent("OriginalCatalog",isDirectory:true)
        try fm.copyItem(at:Inputs.bundledDirectory(),to:installed)
        let bundle = try XCTUnwrap(Bundle(url:app)),inputs = try Inputs.bundled(in:bundle)
        XCTAssertTrue(inputs == (try Self.shared.get()))
        try fm.removeItem(at:installed)
        XCTAssertThrowsError(try Inputs.bundled(in:bundle),"App data must not fall back to developer module resources")
        XCTAssertEqual(inputs.files.count,521);XCTAssertEqual(inputs.bitmaps.count,669)
    }
}
