import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform

/// Live front menu on runtime providers: no corpus reply reaches Native.
@MainActor final class OriginalMacRuntimeMenuTests: XCTestCase {
    typealias Messages = OriginalMacRuntimeMessages
    typealias Key = OriginalMacRuntimeKey
    enum Stop: Error { case limit }

    /// APPLICATION_JOYSTICKS_PLAN.md: declared joysticks answer 43bf10's WinMM
    /// probes; samples become joySetCapture's MM_JOY messages.
    func testJoystickStartupAnswersAndCaptureMessages() throws {
        let service = OriginalMacRuntimeStartupService(windows:OriginalMacWindowBackend(instance:0x400000),heap:OriginalMacRuntimeHeap(),
                                                       environment:.init(joysticks:1))
        func joystick(_ kind: String,_ arguments: [UInt32]) throws -> OriginalInputStartup.Response {
            guard case .joystick(let r) = try service.answer(.joystick(.init(kind,arguments))) else { throw Stop.limit }
            return r
        }
        XCTAssertEqual(try joystick("numberDevices",[]).result,16)
        XCTAssertEqual(try joystick("position",[0]).result,0); XCTAssertEqual(try joystick("position",[1]).result,167)
        XCTAssertEqual(try joystick("threshold",[0,100]).result,0); XCTAssertEqual(try joystick("capture",[7,0,25,1]).result,0)
        XCTAssertThrowsError(try joystick("capture",[7,1,25,1]))
        let caps = try joystick("capabilities",[0,404]); XCTAssertEqual(caps.result,0)
        let bytes = try XCTUnwrap(caps.writes.first).bytes; XCTAssertEqual(bytes.count,404)
        let record = try OriginalStateRecord(bytes:bytes,defined:Array(repeating:true,count:404))
        XCTAssertEqual(try [36,40,44,48,60].map { try record.integer(at:$0,as:UInt32.self) },[0,65535,0,65535,4])

        let m = Messages(window:7,clock:{ 1000 },point:{ (0,0) })
        m.joystick(0,x:32767,y:32767,buttons:0); XCTAssertTrue(m.queue.isEmpty)          // centred, as probed
        m.joystick(0,x:32867,y:32767,buttons:0); XCTAssertTrue(m.queue.isEmpty)          // within the threshold 100
        m.joystick(0,x:65535,y:32767,buttons:0)
        m.joystick(0,x:65535,y:32767,buttons:1)
        m.joystick(0,x:65535,y:32767,buttons:0)
        m.joystick(1,x:0,y:0,buttons:0b1010)
        m.joystick(2,x:0,y:0,buttons:1)                                                   // no third joystick
        XCTAssertEqual(m.queue.map(\.message),[0x3a0,0x3b5,0x3b7,0x3a1,0x3b6])
        XCTAssertEqual(m.queue.map(\.wParam),[0,0x101,0x100,0b1010,0b1010 | 0b1010 << 8])
        XCTAssertEqual(m.queue.map(\.lParam),[0x7fff_ffff,0x7fff_ffff,0x7fff_ffff,0,0])
        for message: UInt32 in [0x3a0,0x3a1,0x3b5,0x3b6,0x3b7,0x3b8] { XCTAssertEqual(try m.answer(.init(.windowDefault,[7,message,0,0])),0) }
    }

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
        XCTAssertThrowsError(try m.answer(.init(.windowDefault,[7,0x1c,0,0])))
        XCTAssertThrowsError(try m.answer(.init(.message,[7,4],[[],[]]))) // no MessageBoxA answerer
        XCTAssertEqual(try m.answer(.init(.time)).result,1025)
        XCTAssertEqual(try m.answer(.init(.sleep,[16])),.init()); XCTAssertEqual(m.sleeps,[16])
        // Arrow keys have no character; moves coalesce while pending.
        let up = try XCTUnwrap(Key.table[0x7e]); m.key(up,down:true,characters:"\u{f700}")
        m.mouse(0x200,x:1,y:2,buttons:0); m.mouse(0x200,x:3,y:4,buttons:1)
        XCTAssertEqual(m.queue.suffix(2).map(\.lParam),[0x01480001,0x00040003])
    }

    /// APPLICATION_WINDOW_CLOSE_PLAN.md: MessageBoxA, Release and free answers;
    /// the close button's SC_CLOSE delivers WM_CLOSE; DefWindowProcA(WM_CLOSE)
    /// destroys the window (queued input dropped, WM_DESTROY and WM_NCDESTROY
    /// next, later input ignored); PostQuitMessage queues WM_QUIT, which
    /// GetMessage returns as 0.
    func testQuitPathAnswersFollowTheDeclaredWindowsBehaviour() throws {
        let m = Messages(window:7,clock:{ 1 })
        var boxes: [[UInt8]] = [],types: [UInt32] = [],released: [UInt32] = [],destroyed = 0
        m.messageBox = { text,caption,type in boxes += [text,caption]; types.append(type); return 7 }
        m.release = { released.append($0) }
        m.destroyedWindow = { destroyed += 1 }
        XCTAssertEqual(try m.answer(.init(.message,[7,4],[Array("Are you sure to quit?".utf8),Array("LF2".utf8)])),7)
        XCTAssertEqual(boxes,[Array("Are you sure to quit?".utf8),Array("LF2".utf8)]); XCTAssertEqual(types,[4])
        // The main menu's ownerless boxes ("WSAStartup()", "InitWinSock()").
        XCTAssertEqual(try m.answer(.init(.message,[0,0],[Array("WSAStartup()".utf8),Array("Error".utf8)])),7)
        XCTAssertEqual(types,[4,0]); XCTAssertThrowsError(try m.answer(.init(.message,[9,0],[[],[]])))
        // OFFICIAL WEBSITE: ShellExecuteA(NULL, "open", url, NULL, NULL, SW_SHOWNORMAL) → 42.
        XCTAssertThrowsError(try m.answer(.init(.shell,[0,0,0,1],[Array("open".utf8),Array("http://littlefighter.com".utf8)])))
        var opened: [[UInt8]] = []; m.shell = { opened += [$0,$1] }
        XCTAssertEqual(try m.answer(.init(.shell,[0,0,0,1],[Array("open".utf8),Array("http://littlefighter.com".utf8)])),42)
        // RECORDING INFO's folder button: ShellExecuteA(NULL, "explore", "recording", …).
        XCTAssertEqual(try m.answer(.init(.shell,[0,0,0,1],[Array("explore".utf8),Array("recording".utf8)])),42)
        XCTAssertEqual(opened,[Array("open".utf8),Array("http://littlefighter.com".utf8),Array("explore".utf8),Array("recording".utf8)])
        XCTAssertThrowsError(try m.answer(.init(.shell,[0,0,0,1],[Array("print".utf8),[]])))
        XCTAssertEqual(try m.answer(.init(.method,[0x55,8])),0); XCTAssertEqual(released,[0x55])
        XCTAssertThrowsError(try m.answer(.init(.method,[0x55,0x30])))
        XCTAssertEqual(try m.answer(.init(.free,[0x1000])),0)
        let a = try XCTUnwrap(Key.table[0x00])
        m.key(a,down:true); m.close()
        XCTAssertEqual(m.queue.map(\.message),[0x100,0x112]); XCTAssertEqual(m.queue.last?.wParam,0xf060)
        XCTAssertEqual(try m.answer(.init(.windowDefault,[7,0x112,0xf060,0])),0)
        XCTAssertEqual(m.queue.map(\.message),[0x10,0x100,0x112])
        XCTAssertThrowsError(try m.answer(.init(.windowDefault,[7,0x112,0xf020,0])))
        XCTAssertEqual(try m.answer(.init(.postMessage,[7,0x10,0,0])),1); XCTAssertEqual(m.queue.last?.message,0x10)
        XCTAssertEqual(try m.answer(.init(.windowDefault,[7,0x10,0,0])),0)
        XCTAssertTrue(m.destroyed); XCTAssertEqual(m.queue.map(\.message),[2,0x82])
        XCTAssertThrowsError(try m.answer(.init(.windowDefault,[7,0x10,0,0])))
        m.key(a,down:false); m.mouse(0x200,x:1,y:1,buttons:0); m.close()
        XCTAssertEqual(m.queue.map(\.message),[2,0x82])
        XCTAssertEqual(try m.answer(.init(.postQuit,[0])),0); XCTAssertEqual(m.queue.map(\.message),[2,0x82,0x12])
        XCTAssertEqual(try m.answer(.init(.windowDefault,[7,0x82,0,0])),0); XCTAssertEqual(destroyed,1)
        XCTAssertEqual(try (0..<3).map { _ in try m.answer(.init(.get,[0,0,0])).result },[1,1,0])
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

    /// The end of the menu track: EC_COMPLETE and the registered 0x400 go through
    /// PeekMessage/DispatchMessage into the recovered WndProc graph callback.
    func testGraphNotificationRestartsTheMenuTrack() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-graph-\(UUID().uuidString)",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let (started,package) = try startup(root)
        while try started.host.takeCommitted() != nil {}
        var now: UInt32 = 5_000_000
        let menu = try OriginalMacRuntimeMenu(started,inputs:package,clock:{ now &+= 7; return now })
        let music = started.runtime.music
        for _ in 0..<400 where music.presented()?.running != true {
            guard case .committed = try menu.step() else { throw Stop.limit }
        }
        let playing = try XCTUnwrap(music.presented())
        XCTAssertEqual(playing.file,Array("bgm\\main.wma".utf8)); XCTAssertEqual(playing.seeks,0)
        XCTAssertNil(music.complete(playing.graph+999))
        let target = try XCTUnwrap(music.complete(playing.graph))
        XCTAssertEqual(target.window,menu.messages.window); XCTAssertEqual(target.message,0x400)
        menu.messages.post(target.message,0,target.lParam)
        for _ in 0..<5 where !menu.messages.queue.isEmpty { guard case .committed = try menu.step() else { throw Stop.limit } }
        XCTAssertTrue(menu.messages.queue.isEmpty); XCTAssertEqual(menu.messages.delivered.last?.message,0x400)
        let event = try XCTUnwrap(music.graphOperations.first?.request.arguments.first)
        XCTAssertEqual(music.interface(event),.event)
        let position = try XCTUnwrap(music.graphOperations.dropFirst().first?.request.arguments.first)
        XCTAssertEqual(music.interface(position),.position)
        XCTAssertEqual(music.graphOperations,[
            .init(request:.init(.getEvent,[event,0x20,0]),response:.init(result:0,code:1,first:0,second:0)),
            .init(request:.init(.method,[position,0x20,0,0]),response:.init(result:0)),
            .init(request:.init(.method,[event,0x30,1,0,0]),response:.init(result:0)),
            .init(request:.init(.getEvent,[event,0x20,0]),response:.init(result:OriginalMacRuntimeMusic.abort))])
        let restarted = try XCTUnwrap(music.presented())
        XCTAssertEqual(restarted.graph,playing.graph); XCTAssertTrue(restarted.running)
        XCTAssertEqual(restarted.seeks,1); XCTAssertEqual(restarted.position,0)
    }
}
