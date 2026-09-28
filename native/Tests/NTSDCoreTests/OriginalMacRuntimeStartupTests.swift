import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform

/// Runtime WinMain providers: no corpus reply reaches Native. Saved source
/// records are read only as independent evidence for the defaults write.
@MainActor final class OriginalMacRuntimeStartupTests: XCTestCase {
    typealias Z = OriginalMacRuntimeZone
    typealias Service = OriginalMacRuntimeStartupService
    func instant(_ text: String) throws -> Date { try XCTUnwrap(ISO8601DateFormatter().date(from:text)) }
    func zone(_ id: String) throws -> TimeZone { try XCTUnwrap(TimeZone(identifier:id)) }

    // Public Windows registry TZI rules for the same zones (2026 rules).
    func testZoneRulesMatchWindowsDayInMonthForm() throws {
        let berlin = try Z.information(zone("Europe/Berlin"),now:instant("2026-09-28T12:00:00Z"))
        XCTAssertEqual(berlin.result,Z.daylight); let b = try XCTUnwrap(berlin.value)
        XCTAssertEqual(b.bias,-60); XCTAssertEqual(b.standardBias,0); XCTAssertEqual(b.daylightBias,-60)
        XCTAssertEqual(b.standard,[0,10,0,5,3,0,0,0]); XCTAssertEqual(b.daylight,[0,3,0,5,2,0,0,0])
        let york = try Z.information(zone("America/New_York"),now:instant("2026-01-15T12:00:00Z"))
        XCTAssertEqual(york.result,Z.standard); let y = try XCTUnwrap(york.value)
        XCTAssertEqual(y.bias,300); XCTAssertEqual(y.daylightBias,-60)
        XCTAssertEqual(y.standard,[0,11,0,1,2,0,0,0]); XCTAssertEqual(y.daylight,[0,3,0,2,2,0,0,0])
        let sydney = try XCTUnwrap(Z.information(zone("Australia/Sydney"),now:instant("2026-06-01T00:00:00Z")).value)
        XCTAssertEqual(sydney.bias,-600); XCTAssertEqual(sydney.daylightBias,-60)
        XCTAssertEqual(sydney.standard,[0,4,0,1,3,0,0,0]); XCTAssertEqual(sydney.daylight,[0,10,0,1,2,0,0,0])
        for id in ["Europe/Moscow","UTC"] {
            let value = try Z.information(zone(id),now:instant("2026-09-28T12:00:00Z"))
            XCTAssertEqual(value.result,Z.unknown,id); let v = try XCTUnwrap(value.value)
            XCTAssertEqual(v.bias,id == "UTC" ? 0 : -180,id)
            XCTAssertEqual(v.standard,[Int32](repeating:0,count:8)); XCTAssertEqual(v.daylight,[Int32](repeating:0,count:8))
            XCTAssertEqual(v.daylightBias,0)
        }
        for v in [b,y,sydney] {
            XCTAssertLessThanOrEqual(v.standardName.utf16.count,31); XCTAssertLessThanOrEqual(v.daylightName.utf16.count,31)
        }
        XCTAssertEqual(try Z.convert("STD",capacity:63),Array("STD".utf8)+[0])
        XCTAssertThrowsError(try Z.convert(String(repeating:"x",count:63),capacity:63))
        XCTAssertThrowsError(try Z.convert("Zeit\u{00e4}",capacity:63))
    }

    func testHeapIsDisjointAlignedZeroAndBounded() throws {
        let heap = OriginalMacRuntimeHeap()
        let a = try heap.allocate(36),b = try heap.allocate(0),c = try heap.allocate(26)
        XCTAssertEqual(a.address,0x30000000); XCTAssertEqual(a.backing,[UInt8](repeating:0,count:36))
        XCTAssertEqual(b.address,0x30000030); XCTAssertTrue(b.backing.isEmpty)
        XCTAssertEqual(c.address,0x30000040)
        for x in [a,b,c] { XCTAssertEqual(x.address%16,0) }
        XCTAssertThrowsError(try heap.allocate(-1)); XCTAssertThrowsError(try heap.allocate(0x10000001))
        for _ in 0..<3 { _ = try heap.allocate(0x10000000) }
        XCTAssertThrowsError(try heap.allocate(0x10000000)) { XCTAssertEqual($0 as? OriginalMacRuntimeHeap.Boundary,.exhausted(0x10000000)) }
    }

    func testDirectShowSuccessPathOwnsIdentitiesAndCounts() throws {
        let music = OriginalMacRuntimeMusic(identities:.init(),heap:.init())
        func iid(_ first: UInt8) -> [UInt8] { [first]+OriginalMacRuntimeMusic.iidTail }
        let graph = try XCTUnwrap(music.answer(.init(.createInstance,[0x44a2a4,0,1,0x44a254,0x44f040])).pointer)
        let control = try XCTUnwrap(music.answer(.init(.queryInterface,[graph],[iid(0xb1)])).pointer)
        let event = try XCTUnwrap(music.answer(.init(.queryInterface,[graph],[iid(0xb6)])).pointer)
        let position = try XCTUnwrap(music.answer(.init(.queryInterface,[graph],[iid(0xb2)])).pointer)
        XCTAssertEqual(Set([graph,control,event,position]).count,4)
        XCTAssertEqual(try music.answer(.init(.queryInterface,[graph],[iid(0xb1)])).pointer,control)
        XCTAssertEqual(try music.answer(.init(.method,[control,8])).result,4)
        XCTAssertEqual(try music.answer(.init(.method,[event,0x34,1,0x400,0])).result,0)
        XCTAssertEqual(try music.answer(.init(.method,[event,0x38,0])).result,0)
        XCTAssertEqual(try music.answer(.init(.createFile,[0x40000000,0,0,2,0x80,0],[Array("\\graph.log".utf8)])).result,-1)
        XCTAssertEqual(try music.answer(.init(.method,[graph,0x3c,UInt32.max])).result,0)
        let path = Array("bgm\\main.wma".utf8)
        let memory = try music.answer(.init(.allocate,[26]))
        let pointer = try XCTUnwrap(memory.pointer); XCTAssertEqual(memory.bytes,[UInt8](repeating:0,count:26))
        let wide = try music.answer(.init(.convert,[0,0,UInt32.max,pointer,13],[path]))
        XCTAssertEqual(wide.result,13); XCTAssertEqual(wide.bytes,path.flatMap { [$0,0] }+[0,0])
        XCTAssertEqual(try music.answer(.init(.method,[graph,0x34,pointer,0],[XCTUnwrap(wide.bytes)])).result,0)
        XCTAssertEqual(music.renderedFile(graph),path)
        XCTAssertEqual(try music.answer(.init(.closeHandle,[UInt32.max])).result,1)
        let audio = try XCTUnwrap(music.answer(.init(.queryInterface,[graph],[iid(0xb3)])).pointer)
        XCTAssertEqual(try music.answer(.init(.audioVolumeRead,[audio])).result,0)
        XCTAssertEqual(try music.answer(.init(.method,[audio,0x1c,UInt32(bitPattern:-500)])).result,0)
        XCTAssertEqual(music.volume(graph),-500)
        XCTAssertEqual(try music.answer(.init(.method,[audio,8])).result,4)
        XCTAssertFalse(music.isRunning(graph))
        XCTAssertEqual(try music.answer(.init(.method,[control,0x1c])).result,0); XCTAssertTrue(music.isRunning(graph))
        XCTAssertThrowsError(try music.answer(.init(.method,[control,0x28])))
        XCTAssertThrowsError(try music.answer(.init(.method,[0x1234,8])))
        XCTAssertThrowsError(try music.answer(.init(.convert,[0,0,UInt32.max,pointer,13],[[0xe4]])))
    }

    func environment(_ text: String,_ zone: TimeZone) throws -> Service.Environment {
        let seconds = Int64(try instant(text).timeIntervalSince1970)
        return .init(monotonic:{ .init(seconds:5000,nanoseconds:123_000_000) },
            realtime:{ .init(seconds:seconds,nanoseconds:0) },zone:{ zone })
    }
    func formatted(_ date: Date,_ zone: TimeZone) -> [UInt8] {
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = zone
        let c = calendar.dateComponents([.year,.month,.day,.hour,.minute,.second],from:date)
        return Array(String(format:"%04d/%02d/%02d/%02d/%02d/%02d",c.year!,c.month!,c.day!,c.hour!,c.minute!,c.second!).utf8)+[0]
    }
    /// Source defaults write for the shipped info bytes, concatenated from the
    /// saved startup corpus's writeFile records. Evidence only.
    func sourceDefaultsWrite() throws -> [UInt8] {
        let (p,_) = try OriginalApplicationHostDeliveryContextTests().inputs()
        var bytes: [UInt8] = []
        for (event,raw) in zip(p.c.events,p.rawEvents) where event.kind == "panel-defaults" {
            let e = try JSONDecoder().decode(OriginalWinMainStartupTests.PanelEvent.self,from:JSONSerialization.data(withJSONObject:XCTUnwrap(raw["event"])))
            if e.kind == "writeFile" { bytes += try XCTUnwrap(e.strings?.first) }
        }
        XCTAssertEqual(try XCTUnwrap(p.c.spec.panel.info),Array("now 0 4 <end>\r\n".utf8))
        return bytes
    }
    func run(_ text: String,_ zoneID: String,overlay root: URL) throws -> OriginalMacRuntimeStartup.Started {
        let package = try OriginalApplicationStartupInputsTests.shared.get()
        XCTAssertEqual(try package.file("data\\adinfo.txt"),Array("now 0 4 <end>\r\n".utf8))
        return try OriginalMacRuntimeStartup.run(inputs:package,overlay:.init(root:root),environment:environment(text,zone(zoneID)))
    }
    func check(_ s: OriginalMacRuntimeStartup.Started,_ text: String,_ zoneID: String,expiry: String) throws {
        XCTAssertEqual(s.sequence,1); XCTAssertEqual(s.driver.exchangeSnapshot.status,.finished)
        XCTAssertEqual(s.driver.exchangeSnapshot.receipts.count,s.requests.count)
        XCTAssertEqual(s.attempts,s.requests.count+1)
        let owners = Dictionary(grouping:s.requests,by:\.owner).mapValues(\.count)
        XCTAssertEqual(Set(owners.keys),["window","display","audio","runtime"])
        XCTAssertFalse(s.requests.contains { $0.kind == "wave" })
        XCTAssertEqual(s.runtime.debugOutput,["DDStartup: Setting windowed mode...\n","DDCreateFakeFlipper: Using fake flipper.\n"].map { Array($0.utf8) })
        let runtime = s.requests.filter { $0.owner == "runtime" }.map(\.kind)
        XCTAssertEqual(Array(runtime.prefix(3)),["milliseconds","criticalSection","com"])
        XCTAssertEqual(runtime.filter { $0 == "joystick:numberDevices" }.count,1)
        XCTAssertEqual(runtime.filter { $0 == "joystick:position" }.count,2)
        XCTAssertFalse(runtime.contains { $0.hasPrefix("joystick:") && !["joystick:numberDevices","joystick:position"].contains($0) })
        XCTAssertEqual(runtime.filter { $0 == "panelWrite" }.count,1); XCTAssertEqual(runtime.filter { $0 == "panelClose" }.count,1)
        XCTAssertFalse(runtime.contains { ["allocatePanel","panelBitmap","panelDevice"].contains($0) })
        let startup = try XCTUnwrap(s.host.snapshot.startup),dates = try XCTUnwrap(startup.dates)
        let zone = try zone(zoneID)
        XCTAssertEqual(dates.dates,[formatted(try instant(text),zone),formatted(try instant(expiry),zone)])
        XCTAssertEqual(dates.time,UInt64(try instant(text).timeIntervalSince1970))
        XCTAssertEqual(dates.cursor,s.windows.arrowCursorToken); XCTAssertEqual(dates.previousCursor,s.windows.arrowCursorToken)
        XCTAssertEqual(s.audio.bufferTokens.count,5)
        let music = s.runtime.music.operations
        XCTAssertEqual(music.first?.event.kind,.createInstance)
        let graph = try XCTUnwrap(music.first?.response.pointer)
        XCTAssertEqual(s.runtime.music.renderedFile(graph),Array("bgm\\main.wma".utf8))
        XCTAssertTrue(s.runtime.music.isRunning(graph)); XCTAssertEqual(s.runtime.music.volume(graph),-500)
        XCTAssertTrue(s.runtime.music.messages.isEmpty)
        let batch = try XCTUnwrap(s.host.takeCommitted()); XCTAssertEqual(batch.sequence,1)
        guard case .startup = batch.contents else { return XCTFail("startup batch") }
        XCTAssertNil(try s.host.takeCommitted())
        let observation = try s.windows.observation(s.window)
        XCTAssertTrue(observation.visible); XCTAssertEqual(observation.title,"Little Fighter 2")
    }
    func testWholeWinMainWithRuntimeProvidersAndOverlay() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-runtime-\(UUID().uuidString)",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let source = try sourceDefaultsWrite(),expected = Array("now 0 4 <end>\r\n".utf8)
        XCTAssertEqual(source,Array("now 0 4 <end>\n".utf8))
        let first = try run("2026-09-28T12:34:56Z","Europe/Berlin",overlay:root)
        try check(first,"2026-09-28T12:34:56Z","Europe/Berlin",expiry:"2026-10-02T12:34:56Z")
        XCTAssertEqual(first.runtime.panelWrites.flatMap { $0 },source)
        // Text-mode translation reproduces the shipped original file exactly.
        XCTAssertEqual(first.runtime.staged,[.init(path:"data\\adinfo.txt",bytes:expected)])
        XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent("data/adinfo.txt")),Data(expected))
        // The second launch reads the overlay; its expiry crosses the October DST change.
        let second = try run("2026-10-23T12:00:00Z","Europe/Berlin",overlay:root)
        try check(second,"2026-10-23T12:00:00Z","Europe/Berlin",expiry:"2026-10-27T12:00:00Z")
        XCTAssertEqual(try XCTUnwrap(second.host.snapshot.startup?.dates).dates[1],Array("2026/10/27/13/00/00".utf8)+[0])
        print("Runtime WinMain:",first.requests.count,"requests;",Dictionary(grouping:first.requests,by:\.owner).mapValues(\.count),"dates",
            String(decoding:try XCTUnwrap(first.host.snapshot.startup?.dates).dates[0].dropLast(),as:UTF8.self))
    }
}
