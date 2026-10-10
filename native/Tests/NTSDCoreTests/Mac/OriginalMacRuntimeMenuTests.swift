import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform
@testable import NTSDRuntime

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
        m.joystick(0,x:65535,y:0,buttons:1); XCTAssertTrue(m.queue.isEmpty)              // nothing captured yet
        m.capturedJoysticks = 2
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
        XCTAssertEqual(Set(Key.table.values.map(\.vk)).count,Key.table.count-4) // shift/control/option pairs and both Returns share VKs
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

    /// APPLICATION_FULL_SCREEN_PLAN.md (declared): Option is Alt; keys while it is
    /// held are WM_SYSKEY* with bit 29; WM_SYSCHAR from TranslateMessage; SC_KEYMENU
    /// after Alt alone, SC_CLOSE on Alt+F4; DefWindowProc on a former window is 0.
    func testSystemKeysFollowWindows() throws {
        var now: UInt32 = 1000
        let m = Messages(window:7,clock:{ now += 5; return now })
        let alt = try XCTUnwrap(Key.table[0x3a]),enter = try XCTUnwrap(Key.table[0x24])
        XCTAssertEqual(alt,Key(0x12,0x38));XCTAssertEqual(Key.table[0x3d],Key(0x12,0x38,true))
        func drain() throws -> [(UInt32,UInt32,UInt32)] {
            var out: [(UInt32,UInt32,UInt32)] = []
            while !m.queue.isEmpty {
                let get = try m.answer(.init(.get,[0,0,0]))
                let r = try OriginalStateRecord(bytes:get.writes[0].bytes,defined:Array(repeating:true,count:28))
                _ = try m.answer(.init(.translate,message:r))
                let message = try r.integer(at:4,as:UInt32.self),w = try r.integer(at:8,as:UInt32.self),l = try r.integer(at:12,as:UInt32.self)
                out.append((message,w,l))
                if (0x104...0x106).contains(message) { _ = try m.answer(.init(.windowDefault,[7,message,w,l])) }
            }
            return out
        }
        // Alt+Enter: SYSKEYDOWN Alt, SYSKEYDOWN Enter (+ WM_SYSCHAR \r), SYSKEYUP Enter, SYSKEYUP Alt (bit 29 clear).
        m.key(alt,down:true);m.key(enter,down:true,characters:"\r");m.key(enter,down:false);m.key(alt,down:false)
        let a = try drain()
        XCTAssertEqual(a.map(\.0),[0x104,0x104,0x106,0x105,0x105])
        XCTAssertEqual(a.map(\.1),[0x12,0x0d,0x0d,0x0d,0x12])
        XCTAssertEqual(a.map(\.2),[0x20380001,0x201c0001,0x201c0001,0xe01c0001,0xc0380001])
        // Alt alone: SC_KEYMENU follows its SYSKEYUP (the game swallows it, 43b519).
        m.key(alt,down:true);m.key(alt,down:false)
        let b = try drain()
        XCTAssertEqual(b.map(\.0),[0x104,0x105,0x112]);XCTAssertEqual(b.last?.1,0xf100)
        // Alt+F4: SC_CLOSE right after its SYSKEYDOWN.
        let f4 = try XCTUnwrap(Key.table[0x76])
        m.key(alt,down:true);m.key(f4,down:true)
        let c = try drain()
        XCTAssertEqual(c.map(\.0),[0x104,0x104,0x112]);XCTAssertEqual(c.last?.1,0xf060)
        m.key(f4,down:false);m.key(alt,down:false);_ = try drain()
        // Without Alt, keys stay WM_KEYDOWN/UP.
        m.key(enter,down:true,characters:"\r");m.key(enter,down:false)
        XCTAssertEqual(try drain().map(\.0),[0x100,0x102,0x101])
        // After a recreation the old HWND answers DefWindowProc with 0.
        m.window = 9
        XCTAssertEqual(try m.answer(.init(.windowDefault,[7,0x105,0x0d,0])),0)
        XCTAssertEqual(m.formerWindows,[7])
        XCTAssertThrowsError(try m.answer(.init(.windowDefault,[8,0x100,0,0])))
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
        var opened: [[UInt8]] = [],delays: [UInt32] = []; m.shell = { opened += [$0,$1]; delays.append($2) }
        XCTAssertEqual(try m.answer(.init(.shell,[0,0,0,1],[Array("open".utf8),Array("http://littlefighter.com".utf8)])),42)
        // RECORDING INFO's folder button: ShellExecuteA(NULL, "explore", "recording", …).
        XCTAssertEqual(try m.answer(.init(.shell,[0,0,0,1],[Array("explore".utf8),Array("recording".utf8)])),42)
        XCTAssertEqual(opened,[Array("open".utf8),Array("http://littlefighter.com".utf8),Array("explore".utf8),Array("recording".utf8)])
        // Committed deferred calls: ShellExecuteA after its screen's Sleep.
        try m.deferred(.init(.shell,[0,0,0,1],[Array("open".utf8),Array("http://littlefighter.com".utf8)]),afterMilliseconds:300)
        XCTAssertEqual(delays,[0,0,300]); XCTAssertThrowsError(try m.deferred(.init(.postQuit,[0]),afterMilliseconds:0))
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
        XCTAssertGreaterThan(started.display.frontOperationCount,0)
        // The live app counts served operations but keeps no logs of them.
        XCTAssertTrue(started.display.frontOperations.isEmpty && started.display.operations.isEmpty && started.display.bitmapOperations.isEmpty)
        XCTAssertGreaterThan(started.display.operationCount+started.display.bitmapOperationCount,0)
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
            "front operations",started.display.frontOperationCount,"capture",capture.path)
    }

    /// Message-queue requests served inside the attempt (CORE_REALTIME M2) give
    /// the same counters, delivered messages, clock calls, committed globals,
    /// commits and frames as serving every request as a permit, the same request
    /// bounds and the same failure, while preparing fewer attempts.
    func testInlineQueueServingMatchesPermitService() throws {
        func run(inline: Bool,failAt: Int? = nil) throws -> (steps: [String],frame: Data?,prepares: Int,clockCalls: Int) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-inline-\(UUID().uuidString)",isDirectory:true)
            defer { try? FileManager.default.removeItem(at:root) }
            let (started,package) = try startup(root)
            while try started.host.takeCommitted() != nil {}
            var now: UInt32 = 5_000_000,clockCalls = 0,prepares = 0
            let menu = try OriginalMacRuntimeMenu(started,inputs:package,clock:{
                clockCalls += 1
                if let failAt,clockCalls == failAt { throw Stop.limit }
                now &+= 7; return now
            })
            // Called once per prepared attempt; a fixed value instead of the Mac's key state.
            menu.capsLock = { prepares += 1; return 0 }
            menu.servesQueueInline = inline
            var steps: [String] = []
            func record(_ kind: String) {
                var globals = Hasher()
                globals.combine(started.host.snapshot.session?.state.full.bytes ?? [])
                steps.append("\(kind) \(menu.requests) \(menu.textRequests) \(menu.emptyBlits) \(menu.iterations) \(clockCalls) "
                    + "\(String(describing:menu.lastRequest)) \(menu.messages.delivered.map(\.message)) \(menu.messages.sleeps) "
                    + "\(started.host.committedSequence) \(started.display.frontOperationCount) \(started.display.operationCount) "
                    + "\(globals.finalize())")
            }
            func step() throws -> Bool {
                switch try menu.step() {
                case .committed: record("committed"); return true
                case .loading: record("loading"); return false
                }
            }
            do {
                for _ in 0..<400 where try XCTUnwrap(started.host.snapshot.session).state.settings == nil { guard try step() else { throw Stop.limit } }
                for _ in 0..<5 { guard try step() else { throw Stop.limit } }
                let key = try XCTUnwrap(OriginalMacRuntimeKey.table[0x00])
                menu.messages.key(key,down:true,characters:"a"); menu.messages.key(key,down:false)
                for _ in 0..<20 where !menu.messages.queue.isEmpty { if !(try step()) { break } }
            } catch { record("failed \(error)"); return (steps,nil,prepares,clockCalls) }
            for bound in [0,1,2] {
                do { _ = try menu.step(maximumRequests:bound); record("unbounded \(bound)") } catch { record("bound \(bound) \(error)") }
            }
            return (steps,try started.windows.snapshotPNG(started.window),prepares,clockCalls)
        }
        let inline = try run(inline:true),permits = try run(inline:false)
        XCTAssertEqual(inline.steps.count,permits.steps.count)
        for (a,b) in zip(inline.steps,permits.steps) { XCTAssertEqual(a,b) }
        XCTAssertEqual(inline.frame,permits.frame)
        XCTAssertTrue(inline.steps.suffix(3).allSatisfy { $0.hasPrefix("bound") })
        XCTAssertLessThan(inline.prepares,permits.prepares,"requests were served inside the attempt")
        // A clock failing at the same call (half way through the run) fails the
        // same way in both modes.
        let failAt = max(2,inline.clockCalls/2)
        let a = try run(inline:true,failAt:failAt),b = try run(inline:false,failAt:failAt)
        XCTAssertEqual(a.steps,b.steps)
        XCTAssertTrue(a.steps.last?.hasPrefix("failed") == true)
    }

    /// CORE_REALTIME B1: the runtime's menu iterations (the idle kernel, whole
    /// steps and a key press, no observers) never read the parted `full` whole.
    func testMenuIterationsNeverReadTheWholeState() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-parts-\(UUID().uuidString)",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let (started,package) = try startup(root)
        while try started.host.takeCommitted() != nil {}
        var now: UInt32 = 5_000_000
        let menu = try OriginalMacRuntimeMenu(started,inputs:package,clock:{ now &+= 7; return now })
        menu.capsLock = { 0 }
        XCTAssertTrue(try XCTUnwrap(started.host.snapshot.session).state.full.isPartitioned)
        let before = OriginalStateRecord.partAssemblies
        func step() throws -> Bool { if case .committed = try menu.step() { return true }; return false }
        for _ in 0..<400 where try XCTUnwrap(started.host.snapshot.session).state.settings == nil { guard try step() else { throw Stop.limit } }
        for _ in 0..<40 { guard try step() else { throw Stop.limit } }
        let key = try XCTUnwrap(OriginalMacRuntimeKey.table[0x00])
        menu.messages.key(key,down:true,characters:"a"); menu.messages.key(key,down:false)
        for _ in 0..<40 { if !(try step()) { break } }
        XCTAssertGreaterThan(started.host.idleCommitCount,0)
        XCTAssertEqual(OriginalStateRecord.partAssemblies,before,"no whole read of full")
    }

    /// Idle iterations through the Host's kernel (CORE_REALTIME A1) give the
    /// same counters, delivered messages, sleeps, clock calls, committed globals,
    /// commits, frames, request bounds and failures as the whole step for every
    /// iteration, with the same number of prepared inputs.
    /// CORE_REALTIME A3 L5a (its review): a delivery context holds the
    /// shipping platform's committed candidate itself, so contexts kept across
    /// later Host attempts — idle commits, whole steps, a failing step — keep
    /// reading the platform exactly as it was committed.
    func testKeptContextsKeepTheirCommittedPlatform() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-kept-\(UUID().uuidString)",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let (started,package) = try startup(root)
        var kept: [OriginalApplicationHostSession<OriginalApplicationPreparedStartupPlatform>.DeliveryContext] = []
        while let batch = try started.host.takeCommitted() { kept.append(batch.context) }
        XCTAssertFalse(kept.isEmpty)
        func fingerprint(_ p: OriginalApplicationPreparedStartupPlatform) -> String {
            "\(p.snapshot) \(String(describing:p.windowExchange?.position)) \(String(describing:p.startupExchange?.position)) "
            + "\(String(describing:p.bitmapDelivery.cursor?.position)) \(p.bitmapDelivery.retainedIterationCount) "
            + "\(String(describing:p.lifecycleDelivery.cursor?.position)) \(p.lifecycleDelivery.retainedIterationCount) "
            + "\(String(describing:p.graphicsDelivery.cursor?.position)) \(p.graphicsDelivery.retainedIterationCount) "
            + "\(String(describing:p.iterationDelivery.cursor?.position)) \(p.iterationDelivery.retainedIterationCount)"
        }
        let committed = try kept.map { try fingerprint($0.platformSnapshot()) }
        var now: UInt32 = 5_000_000,calls = 0,failAt = Int.max
        let menu = try OriginalMacRuntimeMenu(started,inputs:package,clock:{
            calls += 1
            if calls == failAt { throw Stop.limit }
            now &+= 7; return now
        })
        menu.servesIdleDirectly = true
        for _ in 0..<400 where try XCTUnwrap(started.host.snapshot.session).state.settings == nil { guard case .committed = try menu.step() else { break } }
        for _ in 0..<40 { guard case .committed = try menu.step() else { break } }
        XCTAssertGreaterThan(started.host.idleCommitCount,0,"idle commits shared their platforms")
        let hostBefore = try fingerprint(started.host.platformSnapshot())
        failAt = calls + 2
        XCTAssertThrowsError(try { for _ in 0..<20 { _ = try menu.step() } }())
        XCTAssertEqual(try fingerprint(started.host.platformSnapshot()),hostBefore,"a failed attempt leaves the committed platform")
        XCTAssertEqual(try kept.map { try fingerprint($0.platformSnapshot()) },committed)
        XCTAssertNotEqual(hostBefore,committed.last,"later commits moved on from the kept platforms")
    }

    func testIdleKernelMatchesTheWholeStep() throws {
        func run(idle: Bool,failAt: Int? = nil,jumps: Bool = false) throws -> (steps: [String],frame: Data?,prepares: Int,clockCalls: Int,idleCommits: UInt64) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-idle-\(UUID().uuidString)",isDirectory:true)
            defer { try? FileManager.default.removeItem(at:root) }
            let (started,package) = try startup(root)
            while try started.host.takeCommitted() != nil {}
            var now: UInt32 = 5_000_000,clockCalls = 0,prepares = 0
            let menu = try OriginalMacRuntimeMenu(started,inputs:package,clock:{
                clockCalls += 1
                if let failAt,clockCalls == failAt { throw Stop.limit }
                // `jumps`: every 50th call the clock leaps 150 ms (the timer's
                // catch-up past 100 ms behind).
                now &+= jumps && clockCalls % 50 == 0 ? 150 : 7; return now
            })
            menu.capsLock = { prepares += 1; return 0 }
            menu.servesIdleDirectly = idle
            var steps: [String] = []
            func record(_ kind: String) {
                var globals = Hasher()
                globals.combine(started.host.snapshot.session?.state.full.bytes ?? [])
                globals.combine(started.host.snapshot.session?.state.full.defined ?? [])
                let loop = started.host.snapshot.session?.loop
                globals.combine(loop?.timer.baseline);globals.combine(loop?.counter);globals.combine(loop?.message.bytes)
                globals.combine(loop?.message.defined)
                // The committed platform's delivery (A3 invariant 11, L4b).
                let delivery = try? started.host.platformSnapshot().iterationDelivery
                globals.combine(delivery?.cursor?.position);globals.combine(delivery?.cursor?.isSuspended)
                globals.combine(delivery?.retainedIterationCount)
                steps.append("\(kind) \(menu.requests) \(menu.textRequests) \(menu.emptyBlits) \(menu.iterations) \(clockCalls) "
                    + "\(String(describing:menu.lastRequest)) \(menu.messages.delivered.map(\.message)) \(menu.messages.sleeps) "
                    + "\(started.host.committedSequence) \(started.display.frontOperationCount) \(started.display.operationCount) "
                    + "\(prepares) \(globals.finalize())")
            }
            func step() throws -> Bool {
                switch try menu.step() {
                case .committed: record("committed"); return true
                case .loading: record("loading"); return false
                }
            }
            do {
                for _ in 0..<400 where try XCTUnwrap(started.host.snapshot.session).state.settings == nil { guard try step() else { throw Stop.limit } }
                for _ in 0..<40 { guard try step() else { throw Stop.limit } }
                let key = try XCTUnwrap(OriginalMacRuntimeKey.table[0x00])
                menu.messages.key(key,down:true,characters:"a"); menu.messages.key(key,down:false)
                for _ in 0..<20 where !menu.messages.queue.isEmpty { if !(try step()) { break } }
                for _ in 0..<20 { if !(try step()) { break } }
            } catch { record("failed \(error)"); return (steps,nil,prepares,clockCalls,started.host.idleCommitCount) }
            for bound in [0,1,2,3] {
                do { _ = try menu.step(maximumRequests:bound); record("unbounded \(bound)") } catch { record("bound \(bound) \(error)") }
            }
            return (steps,try started.windows.snapshotPNG(started.window),prepares,clockCalls,started.host.idleCommitCount)
        }
        let kernel = try run(idle:true),whole = try run(idle:false)
        XCTAssertEqual(kernel.steps.count,whole.steps.count)
        for (a,b) in zip(kernel.steps,whole.steps) { XCTAssertEqual(a,b) }
        XCTAssertEqual(kernel.frame,whole.frame);XCTAssertEqual(kernel.prepares,whole.prepares)
        XCTAssertGreaterThan(kernel.idleCommits,0,"idle iterations went through the kernel");XCTAssertEqual(whole.idleCommits,0)
        // A clock leaping past the timer's 100 ms catch-up.
        let kernelJumps = try run(idle:true,jumps:true),wholeJumps = try run(idle:false,jumps:true)
        XCTAssertEqual(kernelJumps.steps,wholeJumps.steps);XCTAssertEqual(kernelJumps.frame,wholeJumps.frame)
        XCTAssertGreaterThan(kernelJumps.idleCommits,0)
        // A clock failing at the same call fails the same way on both paths, at
        // several distinct points of the run (a failing call that only stamps a
        // message's time is answered 0 by the message queue, on both paths).
        var failures = 0
        for failAt in Set([2,kernel.clockCalls/3,kernel.clockCalls/2,kernel.clockCalls-3].map { max(2,$0) }).sorted() {
            let a = try run(idle:true,failAt:failAt),b = try run(idle:false,failAt:failAt)
            XCTAssertEqual(a.steps,b.steps,"clock failing at call \(failAt)")
            if a.steps.last?.hasPrefix("failed") == true { failures += 1 }
        }
        XCTAssertGreaterThan(failures,0,"some clock failures reached a step")
    }

    /// CORE_REALTIME A3 L4a: the idle attempt's direct queue server leaves the
    /// iteration driver's exchange as the permit-served path does (receipts,
    /// status, outstanding request, service flag, failure) with the same
    /// outcome, committed sequence and idle commits, for a committed idle
    /// iteration, one with a queued message (the whole step after the idle
    /// attempt's replies), a bound decline, a failing answer and a refused reply.
    /// Each runs right after the timer's whole step, so the attempt starts idle.
    func testDirectIdleAttemptKeepsTheExchangeState() throws {
        typealias Driver = OriginalApplicationObservedIteration<OriginalApplicationPreparedStartupPlatform>
        typealias Loop = OriginalApplicationMessageLoop
        struct Fail: Error {}
        enum Case: String, CaseIterable { case idle,message,bound,failure,mismatch }
        /// `lane`: the runtime's driverless first attempt (A3 L4b) — the lane,
        /// then a driver's `resumeAfterIdle` when it falls back.
        func run(direct: Bool,lane: Bool = false,_ kind: Case) throws -> (log: [String],common: [String],directCalls: Int) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-direct-\(UUID().uuidString)",isDirectory:true)
            defer { try? FileManager.default.removeItem(at:root) }
            let (started,package) = try startup(root)
            while try started.host.takeCommitted() != nil {}
            var now: UInt32 = 5_000_000
            let menu = try OriginalMacRuntimeMenu(started,inputs:package,clock:{ now &+= 7; return now })
            for _ in 0..<400 where try XCTUnwrap(started.host.snapshot.session).state.settings == nil {
                guard case .committed = try menu.step() else { throw Stop.limit }
            }
            for _ in 0..<40 { guard case .committed = try menu.step() else { throw Stop.limit } }
            // Up to the timer's whole step (no idle commit): the next
            // iteration's timer is not due yet.
            for _ in 0..<20 {
                let before = started.host.idleCommitCount
                guard case .committed = try menu.step() else { throw Stop.limit }
                if started.host.idleCommitCount == before { break }
            }
            let idleCommits = started.host.idleCommitCount
            if kind == .message {
                let key = try XCTUnwrap(Key.table[0x00]); menu.messages.key(key,down:true,characters:"a")
            }
            var served = 0,directCalls = 0
            let bound = kind == .bound ? 1 : 100
            func answer(_ q: Loop.Request) throws -> Loop.Response {
                if kind == .failure && served == 2 { throw Fail() }
                let r = try menu.messages.answer(q)
                // Output writes on a time reply: `accepts` refuses it.
                return kind == .mismatch && q.kind == .time ? .init(result:r.result,writes:[.init(offset:0,bytes:[1])]) : r
            }
            // The runtime's inline service: queue requests within the bound and
            // the window Blt (CORE_REALTIME M2b) through the front service.
            let inline = Driver.Inline(accepts:{ q in
                switch q {
                case .queue: return served < bound
                case .graphics(.window(let w)) where w.kind == "blt": return served < bound
                default: return false
                }
            },serve:{ permit,exchange in
                if case .graphics = permit.request { served += 1; try menu.front.serve(permit,on:exchange); return }
                guard case .queue(let q) = permit.request else { throw Fail() }
                served += 1
                try exchange.beginService(permit)
                do { try exchange.answer(permit,response:.queue(try answer(q))) }
                catch { try exchange.fail(permit,diagnostic:String(reflecting:error)); throw error }
            },direct:direct ? { q in
                guard served < bound else { return nil }
                served += 1; directCalls += 1
                return try answer(q)
            } : nil)
            var driver: Driver?
            let outcome: String
            func describe(_ resumed: Driver.Outcome) -> String {
                switch resumed {
                case .request(let permit): return "request \(permit.ordinal) \(permit.request)"
                case .advanced(let o): return "advanced \(o)"
                }
            }
            do {
                if lane {
                    switch try Driver.resumeIdleDirect(host:started.host,prepare:{ _,state in try menu.inputs(state) },direct:try XCTUnwrap(inline.direct)) {
                    case .committed(let o): outcome = "advanced \(o)"
                    case .fallback(let fallback):
                        let d = Driver(host:started.host);driver = d
                        outcome = describe(try d.resumeAfterIdle(fallback,prepare:{ _,state in try menu.inputs(state) },network:false,inline:inline))
                    }
                } else {
                    let d = Driver(host:started.host);driver = d
                    outcome = describe(try d.resumeIdleFirst(prepare:{ _,state in try menu.inputs(state) },network:false,inline:inline))
                }
            } catch { outcome = "error \(error)" }
            // The committed platform's delivery (A3 invariant 11).
            let delivery = try started.host.platformSnapshot().iterationDelivery
            let common = ["\(kind.rawValue) \(outcome)","served \(served)",
                          "sequence \(started.host.committedSequence)","pending \(started.host.pendingBatchCount)",
                          "delivery \(String(describing:delivery.cursor?.position)) \(String(describing:delivery.cursor?.isSuspended)) \(delivery.retainedIterationCount)",
                          "idle commits \(started.host.idleCommitCount - idleCommits)"]
            guard let s = driver?.exchangeSnapshot else { return (common,common,directCalls) }
            return (common + ["status \(s.status)","outstanding \(String(describing:s.outstandingRequest))",
                     "service \(s.serviceStarted)","failure \(String(describing:s.failure?.request)) \(s.failure?.diagnostic ?? "-") \(String(describing:s.failure?.afterCancellation))",
                     "receipts \(s.receipts.map { "\($0.request) \($0.response) \($0.resources.count)" })"],common,directCalls)
        }
        for kind in Case.allCases {
            let lane = try run(direct:true,kind),permits = try run(direct:false,kind)
            XCTAssertEqual(lane.log,permits.log,kind.rawValue)
            // A3 L4b: the driverless lane gives the same outcome, counters and
            // delivery, and the same exchange whenever it hands over to a driver.
            let driverless = try run(direct:true,lane:true,kind)
            XCTAssertEqual(driverless.common,permits.common,"lane \(kind.rawValue)")
            if driverless.log.count > driverless.common.count { XCTAssertEqual(driverless.log,permits.log,"lane \(kind.rawValue)") }
            XCTAssertEqual(kind == .message || kind == .bound,driverless.log.count > driverless.common.count,"lane \(kind.rawValue) fell back to a driver")
            XCTAssertGreaterThan(lane.directCalls,0,"\(kind.rawValue) went through the direct server")
            XCTAssertEqual(permits.directCalls,0)
            let outcome = lane.log[0],idle = lane.common.last!
            switch kind {
            case .idle: XCTAssertTrue(outcome.contains("advanced") && idle == "idle commits 1",outcome+" "+idle)
            case .message: XCTAssertTrue(idle == "idle commits 0" && !outcome.contains("error"),outcome+" "+idle)
            case .bound: XCTAssertTrue(outcome.contains("request 1"),outcome)
            case .failure,.mismatch: XCTAssertTrue(outcome.contains("error"),outcome)
            }
        }
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
