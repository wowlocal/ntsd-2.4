import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDRuntime
@testable import NTSDMacPlatform

@MainActor final class OriginalRuntimeContentInputsTests: XCTestCase {
    typealias Content = OriginalRuntimeContentInputs
    let fm = FileManager.default
    var package: URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("TargetInputs/NTSD2833Partial")
    }
    func temporary(_ label: String) -> URL { fm.temporaryDirectory.appendingPathComponent("ntsd-m0-\(label)-\(UUID().uuidString)",isDirectory:true) }
    func copiedTarget() throws -> URL {
        let root = temporary("target");try fm.copyItem(at:package,to:root);return root
    }
    func entries() throws -> [(String,[UInt8])] {
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:package.appendingPathComponent("manifest.json"))) as? [String:Any])
        return try XCTUnwrap(manifest["entries"] as? [[String:Any]]).map {
            let path = try XCTUnwrap($0["path"] as? String)
            return (path,Array(try Data(contentsOf:package.appendingPathComponent(path))))
        }
    }
    func testAllNineRawInputsOwnBytesAfterSourceRemovalAndSeparateOverlay() throws {
        let root = try copiedTarget(),writable = temporary("writable"),expected = try entries()
        defer {
            if fm.fileExists(atPath:root.path) { try? fm.removeItem(at:root) }
            if fm.fileExists(atPath:writable.path) { try? fm.removeItem(at:writable) }
        }
        let content = try Content.targetPartial(directory:root,writableParent:writable)
        XCTAssertEqual(content.identity,"NTSD-2.8.3.3-partial")
        XCTAssertEqual(expected.count,9);XCTAssertEqual(expected.reduce(0) { $0+$1.1.count },161_202)
        try fm.removeItem(at:root)
        for (path,bytes) in expected {
            XCTAssertEqual(try content.rawTargetFile(path),bytes,path)
            var changed = try content.rawTargetFile(path);changed[0] ^= 1
            XCTAssertEqual(try content.rawTargetFile(path),bytes,"Caller mutation cannot change owned input")
        }
        for name in ["missing","NTSD.exe","data\\data.txt","DATA/data.txt"] {
            XCTAssertThrowsError(try content.rawTargetFile(name)) { XCTAssertEqual($0 as? Content.Boundary,.unsupportedName(name)) }
        }
        let overlay = content.overlay { XCTFail("Target must not ask for the baseline root");return .init(root:writable) }
        XCTAssertEqual(overlay.root,writable.appendingPathComponent("NTSD-2.8.3.3",isDirectory:true))
        XCTAssertNotEqual(overlay.root,writable);XCTAssertFalse(fm.fileExists(atPath:writable.path))
        XCTAssertThrowsError(try content.acquireStartup()) { XCTAssertEqual($0 as? Content.Boundary,.unsupportedTargetStartup) }
    }
    func testMissingEmptyAndCorruptAreDistinctForEveryMember() throws {
        for (path,original) in try entries() {
            for kind in ["missing","empty","corrupt"] {
                let root = try copiedTarget();defer { try? fm.removeItem(at:root) }
                let file = root.appendingPathComponent(path)
                switch kind {
                case "missing":try fm.removeItem(at:file)
                case "empty":try Data().write(to:file)
                default:var bytes = original;bytes[0] ^= 1;try Data(bytes).write(to:file)
                }
                XCTAssertThrowsError(try Content.targetPartial(directory:root,writableParent:temporary("unused"))) {
                    let expected: Content.Boundary = kind == "missing" ? .missing(path) : kind == "empty" ? .empty(path) : .corrupt(path)
                    XCTAssertEqual($0 as? Content.Boundary,expected)
                }
            }
        }
    }
    func testTargetRejectsManifestExtrasAndSymlinks() throws {
        for kind in ["manifest","extra","directory","link","root-link"] {
            let root = try copiedTarget(),link = temporary("link")
            defer { try? fm.removeItem(at:root);try? fm.removeItem(at:link) }
            var input = root
            switch kind {
            case "manifest":try Data([1]).write(to:root.appendingPathComponent("manifest.json"))
            case "extra":try Data([1]).write(to:root.appendingPathComponent("extra"))
            case "directory":try fm.createDirectory(at:root.appendingPathComponent("extra"),withIntermediateDirectories:false)
            case "link":
                let path = root.appendingPathComponent("data/control.txt");try fm.removeItem(at:path)
                try fm.createSymbolicLink(at:path,withDestinationURL:root.appendingPathComponent("data/data.txt"))
            default:try fm.createSymbolicLink(at:link,withDestinationURL:root);input = link
            }
            XCTAssertThrowsError(try Content.targetPartial(directory:input,writableParent:temporary("unused")))
        }
    }
    enum ReadFailure: Error, Equatable { case at(Int) }
    func testReadAheadInvokesAllFiveReadersAndThrowsInBundledOrder() throws {
        // Failed IO answers are controlled here; no original execution/device claim.
        for first in 0..<5 {
            var calls: [Int] = []
            func fail<T>(_ index: Int) throws -> T { calls.append(index);throw ReadFailure.at(index) }
            let all = OriginalRuntimeLoadingPackages(readCatalog:{ try fail(0) },readLoading:{ try fail(1) },
                readInterface:{ try fail(2) },readMenu:{ try fail(3) },readArena:{ try fail(4) })
            XCTAssertEqual(calls,[0,1,2,3,4])
            // Earlier successful Results come from the exact unchanged readers.
            let p = OriginalRuntimeLoadingPackages(
                catalog:first > 0 ? Result { try .bundled() } : all.catalog,
                loading:first > 1 ? Result { try .bundled() } : all.loading,
                interface:first > 2 ? Result { try .bundled() } : all.interface,
                menu:first > 3 ? Result { try .bundledWithWar() } : all.menu,arena:all.arena)
            XCTAssertThrowsError(try p.values()) { XCTAssertEqual($0 as? ReadFailure,.at(first)) }
        }
    }
    func testStartupAndReadAheadTicketsRejectOtherOwnersBeforeCore() throws {
        let a = Content.baseline(),b = Content.baseline(),startup = try a.acquireStartup()
        let loading = try a.acquireLoading(for:startup)
        try a.validateOrigin(startup:startup,packages:loading)
        XCTAssertThrowsError(try b.acquireLoading(for:startup)) { XCTAssertEqual($0 as? Content.Boundary,.mixedOrigin) }
        let other = try b.acquireStartup(),otherLoading = try b.acquireLoading(for:other)
        XCTAssertThrowsError(try a.validateOrigin(startup:other,packages:loading)) { XCTAssertEqual($0 as? Content.Boundary,.mixedOrigin) }
        XCTAssertThrowsError(try a.validateOrigin(startup:startup,packages:otherLoading)) { XCTAssertEqual($0 as? Content.Boundary,.mixedOrigin) }
        let target = try Content.targetPartial(directory:package,writableParent:temporary("unused"))
        XCTAssertThrowsError(try target.acquireLoading(for:startup)) { XCTAssertEqual($0 as? Content.Boundary,.mixedOrigin) }
    }
    /// Real Session.start(), with observable host calls. The scheduler is held;
    /// no synthetic Core after-state is provided. Target must not touch any host
    /// service except the diagnostic stop. Baseline performs actual startup.
    final class Host: OriginalRuntimeSessionHost {
        let root: URL
        var calls: [String] = [],stops: [String] = []
        init(_ root: URL) { self.root = root }
        var startupHost: OriginalRuntimeStartupHost { calls.append("startup");return .mac }
        func capsLock() -> Int32 { 0 }
        func makeSockets() -> any OriginalRuntimeSockets { calls.append("sockets");return OriginalMacWinsock() }
        var loadingDialogs: OriginalRuntimeLoadingDialogs { calls.append("dialogs");return .init(chooseRecording:{ _ in nil },alert:{ _ in },open:{ _ in }) }
        func standardOverlay() throws -> OriginalMacRuntimeOverlay { calls.append("overlay");return .init(root:root) }
        func beginTimingActivity() { calls.append("timing") }
        func connectedJoysticks() -> Int { calls.append("joysticks");return 0 }
        func startJoystickSampling(_ session: OriginalRuntimeSession) { calls.append("sampling") }
        func makeMusicOutput() throws -> OriginalMacMusicOutput { calls.append("music");return .init(tracks:[:]) { _,_ in throw ReadFailure.at(10) } }
        var musicDirectory: String { "" }
        func startSoundOutput(_ effects: OriginalMacSoundEffects,muted: Bool) throws -> String { calls.append("sounds");return "test" }
        func backingScale(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) -> Double { 1 }
        func cursorPoint() -> (Int32,Int32) { (0,0) }
        func attach(_ window: UInt32,in windows: OriginalRuntimeWindowBackend,session: OriginalRuntimeSession) throws { calls.append("attach") }
        func snapshotPNG(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws -> Data { try windows.presentedPNG(window) }
        func viewPNG(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws -> Data { try snapshotPNG(window,in:windows) }
        func toggleFullScreen(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws {}
        func hide(_ window: UInt32,in windows: OriginalRuntimeWindowBackend) throws {}
        func askMessageBox(text: String,caption: String,buttons: [String]) -> Int { calls.append("message");return 0 }
        func open(_ url: URL) { calls.append("open") }
        func showStop(title: String,text: String) { stops.append(text) }
        func didStart() { calls.append("started") }
        func terminate() { calls.append("terminate") }
        func exit(_ code: Int32) -> Never { fatalError("Unexpected process exit in M0 session test: \(code)") }
        func scheduleIteration(after milliseconds: UInt32,_ body: @escaping @MainActor () -> Void) { calls.append("schedule") }
    }
    func testTargetBoundaryThroughRealSessionHasNoStateFilesOrHostEffects() throws {
        let root = temporary("session"),host = Host(root)
        defer { try? fm.removeItem(at:root) }
        let content = try Content.targetPartial(directory:package,writableParent:root)
        let session = OriginalRuntimeSession(arguments:["NTSD"],host:host,contentInputs:content)
        session.start()
        XCTAssertTrue(session.stopped);XCTAssertEqual(session.gameWindow,0);XCTAssertNil(session.messages);XCTAssertFalse(session.loadingStarted)
        XCTAssertEqual(host.calls,[]);XCTAssertEqual(host.stops,[Content.Boundary.unsupportedTargetStartup.description])
        XCTAssertFalse(fm.fileExists(atPath:root.path))
        let conflict = OriginalRuntimeSession(arguments:["NTSD","--resources",root.path],host:host,contentInputs:content)
        conflict.start();XCTAssertEqual(host.calls,[])
        XCTAssertEqual(host.stops.last,Content.Boundary.conflictingResources.description)
    }
    func testDefaultAndExplicitBaselineThroughRealSession() throws {
        _ = NSApplication.shared
        for content in [nil,Content.baseline()] as [Content?] {
            let root = temporary("baseline"),host = Host(root)
            defer { try? fm.removeItem(at:root) }
            let session = OriginalRuntimeSession(arguments:["NTSD","--no-network","--virtual-clock","123456789","8"],host:host,contentInputs:content)
            session.start()
            XCTAssertFalse(session.stopped);XCTAssertTrue(host.stops.isEmpty,"\(host.stops)")
            XCTAssertGreaterThan(session.gameWindow,0);XCTAssertNotNil(session.messages)
            XCTAssertTrue(host.calls.contains("started"));XCTAssertTrue(host.calls.contains("schedule"))
        }
    }
    func testRelocatedCompleteBaselineDoesNotFallBack() throws {
        let root = temporary("relocated").appendingPathExtension("app")
        defer { try? fm.removeItem(at:root) }
        let resources = root.appendingPathComponent("Contents/Resources",isDirectory:true)
        try fm.createDirectory(at:resources,withIntermediateDirectories:true)
        let plist: [String:Any] = ["CFBundleIdentifier":"local.ntsd.m0","CFBundlePackageType":"APPL","CFBundleExecutable":"unused"]
        try PropertyListSerialization.data(fromPropertyList:plist,format:.xml,options:0).write(to:root.appendingPathComponent("Contents/Info.plist"))
        let locations = try [OriginalApplicationStartupInputs.bundledDirectory(),OriginalApplicationCatalogInputs.bundledDirectory(),
            OriginalApplicationLoadingInputs.bundledDirectory(),OriginalApplicationInterfaceInputs.bundledDirectory(),
            OriginalApplicationMenuInputs.bundledDirectory(),
            OriginalApplicationStartupInputs.bundledDirectory().deletingLastPathComponent().appendingPathComponent("OriginalMatchArenas")]
        for location in locations { try fm.copyItem(at:location,to:resources.appendingPathComponent(location.lastPathComponent)) }
        // Menu's separate War package participates in bundledWithWar.
        let war = try OriginalApplicationMenuInputs.bundledDirectory("OriginalWarMenu")
        try fm.copyItem(at:war,to:resources.appendingPathComponent(war.lastPathComponent))
        let content = Content.baseline(in:try XCTUnwrap(Bundle(url:root))),startup = try content.acquireStartup()
        let loading = try content.acquireLoading(for:startup)
        try content.validateOrigin(startup:startup,packages:loading)
        try fm.removeItem(at:resources.appendingPathComponent("OriginalStartup"))
        XCTAssertThrowsError(try content.acquireStartup(),"A complete .app must not fall back to developer resources")
        XCTAssertEqual(startup.inputs,try OriginalApplicationStartupInputs.bundled())
    }
}
