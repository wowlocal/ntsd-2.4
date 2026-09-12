import Foundation
import XCTest
import NTSDCore

final class OriginalApplicationLoadingSessionTests: XCTestCase {
    typealias Inputs = OriginalApplicationLoadingInputs
    func temporaryCopy() throws -> URL {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:parent,withIntermediateDirectories:true)
        addTeardownBlock { try FileManager.default.removeItem(at:parent) }
        let copy = parent.appendingPathComponent("OriginalCommonSounds",isDirectory:true)
        try FileManager.default.copyItem(at:Inputs.bundledDirectory(),to:copy)
        return copy
    }
    func testBundledCommonSoundsAreOwnedAndRetainDistinctNames() throws {
        let copy = try temporaryCopy(),owned = try Inputs.load(directory:copy)
        let files = try OriginalInitialSoundLoading.paths.map { try owned.file($0) }
        XCTAssertEqual(files.count,18);XCTAssertEqual(files.reduce(0) { $0+$1.count },351_078)
        XCTAssertEqual(files[0],files[14]);XCTAssertEqual(files[1],files[17])
        XCTAssertEqual(Set(files.map { Data($0) }).count,16)
        try Data([0]).write(to:copy.appendingPathComponent("001.wav"))
        XCTAssertEqual(try owned.file("data\\001.wav"),files[0])
        XCTAssertThrowsError(try Inputs.load(directory:copy))
        XCTAssertThrowsError(try owned.file("data\\003.wav")) {
            XCTAssertEqual($0 as? Inputs.Boundary,.unsupportedName("data\\003.wav"))
        }
    }
    func testMissingCorruptExtraAndSymlinkPackagesAreDistinctNativeBoundaries() throws {
        let missing = try temporaryCopy()
        try FileManager.default.removeItem(at:missing.appendingPathComponent("085.wav"))
        XCTAssertThrowsError(try Inputs.load(directory:missing)) {
            XCTAssertEqual($0 as? Inputs.Boundary,.missing("085.wav"))
        }
        let corrupt = try temporaryCopy()
        try Data("{}\n".utf8).write(to:corrupt.appendingPathComponent("manifest.json"))
        XCTAssertThrowsError(try Inputs.load(directory:corrupt)) {
            XCTAssertEqual($0 as? Inputs.Boundary,.invalid("Manifest digest"))
        }
        let extra = try temporaryCopy()
        try Data().write(to:extra.appendingPathComponent("unexpected"))
        XCTAssertThrowsError(try Inputs.load(directory:extra)) {
            XCTAssertEqual($0 as? Inputs.Boundary,.invalid("Package composition"))
        }
        let linked = try temporaryCopy(),file = linked.appendingPathComponent("001.wav")
        try FileManager.default.removeItem(at:file)
        try FileManager.default.createSymbolicLink(at:file,withDestinationURL:Inputs.bundledDirectory().appendingPathComponent("001.wav"))
        XCTAssertThrowsError(try Inputs.load(directory:linked)) {
            XCTAssertEqual($0 as? Inputs.Boundary,.invalid("001.wav"))
        }
    }
    func testApplicationBundleRequiresItsOwnCommonSoundPackage() throws {
        let parent = try temporaryCopy().deletingLastPathComponent(),app = parent.appendingPathComponent("CommonSounds.app",isDirectory:true)
        let resources = app.appendingPathComponent("Contents/Resources",isDirectory:true)
        try FileManager.default.createDirectory(at:resources,withIntermediateDirectories:true)
        let info: [String:Any] = ["CFBundleIdentifier":"local.ntsd.common-sounds-test","CFBundleName":"CommonSounds",
            "CFBundlePackageType":"APPL","CFBundleExecutable":"CommonSounds"]
        try PropertyListSerialization.data(fromPropertyList:info,format:.xml,options:0).write(to:app.appendingPathComponent("Contents/Info.plist"))
        let bundle = try XCTUnwrap(Bundle(url:app))
        XCTAssertThrowsError(try Inputs.bundled(in:bundle)) {
            XCTAssertEqual($0 as? Inputs.Boundary,.missing("OriginalCommonSounds"))
        }
        try FileManager.default.copyItem(at:Inputs.bundledDirectory(),to:resources.appendingPathComponent("OriginalCommonSounds"))
        XCTAssertEqual(try Inputs.bundled(in:bundle),try Inputs.bundled())
    }
}
