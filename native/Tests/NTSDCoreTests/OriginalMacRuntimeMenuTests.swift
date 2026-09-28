import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform

/// Live front menu on runtime providers: no corpus reply reaches Native.
@MainActor final class OriginalMacRuntimeMenuTests: XCTestCase {
    typealias Messages = OriginalMacRuntimeMessages
    typealias Key = OriginalMacRuntimeKey
    enum Stop: Error { case limit }

    func testMessageQueueKeyMapAndTranslation() throws {
        var now: UInt32 = 1000
        let m = Messages(window:7,clock:{ now += 5; return now },point:{ (-3,40) })
        XCTAssertEqual(Key.table[0x00],Key(0x41,0x1e)); XCTAssertEqual(Key.table[0x7e],Key(0x26,0x48,true))
        XCTAssertEqual(Key.table[0x7a],Key(0x70,0x3b)); XCTAssertEqual(Key.table[0x6f],Key(0x7b,0x58))
        XCTAssertEqual(Key.table[0x24],Key(0x0d,0x1c)); XCTAssertEqual(Key.table[0x1d],Key(0x30,0x0b))
        XCTAssertEqual(Set(Key.table.values.map(\.vk)).count,Key.table.count-3) // shift/control pairs and both Returns share VKs
        XCTAssertEqual(try m.answer(.init(.peek,[0,0,0,0])),.init(result:0))
        XCTAssertThrowsError(try m.answer(.init(.get,[0,0,0])))
        m.key(try XCTUnwrap(Key.table[0x00]),down:true,characters:"a")
        m.key(try XCTUnwrap(Key.table[0x00]),down:true,repeated:true,characters:"a")
        m.key(try XCTUnwrap(Key.table[0x00]),down:false)
        let peek = try m.answer(.init(.peek,[0,0,0,0]))
        XCTAssertEqual(peek.result,1)
        let msg = try OriginalStateRecord(bytes:try XCTUnwrap(peek.writes.first).bytes,defined:Array(repeating:true,count:28))
        XCTAssertEqual(try (0..<7).map { try msg.integer(at:$0*4,as:UInt32.self) },[7,0x100,0x41,0x001e0001,1005,UInt32(bitPattern:-3),40])
        let get = try m.answer(.init(.get,[0,0,0])); XCTAssertEqual(get,peek)
        let record = try OriginalStateRecord(bytes:get.writes[0].bytes,defined:Array(repeating:true,count:28))
        XCTAssertEqual(try m.answer(.init(.translate,message:record)).result,1)
        // WM_CHAR precedes the pending repeat keydown and keyup.
        XCTAssertEqual(m.queue.map(\.message),[0x102,0x100,0x101])
        XCTAssertEqual(m.queue.map(\.wParam),[0x61,0x41,0x41])
        XCTAssertEqual(m.queue.map(\.lParam),[0x001e0001,0x401e0001,0xc01e0001])
        XCTAssertEqual(try m.answer(.init(.windowDefault,[7,0x102,0x61,0x1e0001])),0)
        XCTAssertThrowsError(try m.answer(.init(.windowDefault,[7,0x10,0,0])))
        XCTAssertThrowsError(try m.answer(.init(.message,[7,4],[[],[]])))
        XCTAssertEqual(try m.answer(.init(.time)).result,1025)
        XCTAssertEqual(try m.answer(.init(.sleep,[16])),.init()); XCTAssertEqual(m.sleeps,[16])
        // Arrow keys have no character; moves coalesce while pending.
        let up = try XCTUnwrap(Key.table[0x7e]); m.key(up,down:true,characters:"\u{f700}")
        m.mouse(0x200,x:1,y:2,buttons:0); m.mouse(0x200,x:3,y:4,buttons:1)
        XCTAssertEqual(m.queue.suffix(2).map(\.lParam),[0x01480001,0x00040003])
    }

    func startup(_ root: URL) throws -> (OriginalMacRuntimeStartup.Started,OriginalApplicationStartupInputs) {
        let package = try OriginalApplicationStartupInputsTests.shared.get()
        let seconds = Int64(try XCTUnwrap(ISO8601DateFormatter().date(from:"2026-09-28T12:00:00Z")).timeIntervalSince1970)
        let environment = OriginalMacRuntimeStartupService.Environment(monotonic:{ .init(seconds:5000,nanoseconds:0) },
            realtime:{ .init(seconds:seconds,nanoseconds:0) },zone:{ TimeZone(identifier:"Europe/Berlin")! })
        return (try OriginalMacRuntimeStartup.run(inputs:package,overlay:.init(root:root),environment:environment),package)
    }
    func testRuntimeFrontMenuIteratesAndAcceptsKeys() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-menu-\(UUID().uuidString)",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let (started,package) = try startup(root)
        while try started.host.takeCommitted() != nil {}
        var now: UInt32 = 5_000_000
        let menu = try OriginalMacRuntimeMenu(started,inputs:package,clock:{ now &+= 7; return now })
        XCTAssertEqual(menu.initialization.frontAllocations.count,24)
        var committed = 0
        func step() throws -> Bool {
            let outcome: OriginalMacRuntimeMenu.Host.Outcome
            do { outcome = try menu.step() }
            catch { print("Runtime menu stopped:",error,"at",String(describing:menu.lastRequest).prefix(600));throw error }
            switch outcome {
            case .committed: committed += 1; return true
            case .loading: return false
            }
        }
        // Empty queue: iterate until the first menu has loaded its settings/art.
        for _ in 0..<400 where try XCTUnwrap(started.host.snapshot.session).state.settings == nil { guard try step() else { throw Stop.limit } }
        XCTAssertNotNil(try XCTUnwrap(started.host.snapshot.session).state.settings)
        for _ in 0..<5 { guard try step() else { throw Stop.limit } }
        XCTAssertEqual(menu.diagnostics.debug.map { String(decoding:$0,as:UTF8.self) },["LoadGameArt: Art loaded.\n"])
        XCTAssertTrue(menu.diagnostics.messages.isEmpty)
        XCTAssertGreaterThan(started.display.frontOperations.count,0)
        XCTAssertFalse(menu.messages.sleeps.isEmpty)
        let png = try started.windows.snapshotPNG(started.window)
        let capture = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-runtime-menu.png")
        try png.write(to:capture)
        // A key press/release goes through PeekMessage, GetMessage, TranslateMessage (WM_CHAR) and the WndProc.
        let key = try XCTUnwrap(OriginalMacRuntimeKey.table[0x00])
        menu.messages.key(key,down:true,characters:"a"); menu.messages.key(key,down:false)
        var loading = false
        for _ in 0..<20 where !menu.messages.queue.isEmpty { if !(try step()) { loading = true; break } }
        XCTAssertEqual(menu.messages.delivered.map(\.message),[5,3,0x100,0x102,0x101])
        XCTAssertTrue(menu.messages.queue.isEmpty)
        print("Runtime menu:",committed,"committed iterations,",menu.requests,"permits,",menu.textRequests,"GetDC failures, loading",loading,
            "front operations",started.display.frontOperations.count,"capture",capture.path)
    }
}
