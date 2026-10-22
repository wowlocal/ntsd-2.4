import Foundation
import XCTest
@testable import RandoriCore
@testable import RandoriRuntime

/// ENGINE_SPLIT E7d, rung 2: the engine started on the synthetic pack, from
/// the recovered WinMain (`OriginalMacRuntimeStartup.run`) through the front
/// menu's first frames, with engine-computed results pinned: the startup's
/// served requests, the window, state words and drawn frames. Then
/// `OriginalRuntimeSession` itself (RandoriHeadlessHost's path) on the pack: its
/// `--exit-after-startup` and its front-menu frames, which equal the driver's.
final class SyntheticHeadlessStartTests: XCTestCase {
    typealias Pack = SyntheticContentPack

    func testStartupReachesTheFrontMenu() throws {
        try Pack.withWrittenPack { root, pack in
            try MainActor.assumeIsolated {
                let run = try SyntheticRun(root: root, pack: pack)
                let started = run.started
                let owners = Dictionary(grouping: started.requests, by: \.owner).mapValues(\.count)
                syntheticLog("E7D rung2 startup sequence \(started.sequence) window \(started.window) attempts \(started.attempts) requests \(started.requests.count) owners \(owners.sorted { $0.key < $1.key })")
                syntheticLog("E7D rung2 kinds \(started.requests.map(\.kind))")
                XCTAssertEqual(Self.pinnedStartup, [Int(started.sequence), Int(started.window), started.attempts, started.requests.count])
                XCTAssertEqual(owners, Self.pinnedOwners)
                // One titled window whose client is the record's 800 x 600 (WinMain adds the
                // frame metrics, OriginalWindowInitialization.swift:90-91; the host takes the caption off).
                XCTAssertEqual(run.windowHost.windows.count, 1)
                let window = try XCTUnwrap(run.windowHost.windows.first)
                XCTAssertEqual([window.client.width, window.client.height, window.popup ? 1 : 0], [800, 600, 0])
                XCTAssertEqual(window.title, "Little Fighter 2", "the window title the EXE passes (OriginalWindowInitialization.swift:110)")
                XCTAssertTrue(window.visible)
                XCTAssertNil(try run.presented(), "nothing presented before the menu runs")
                // The front menu: the first iterations present nothing; the one that loads
                // the 24 front bitmaps (0x44d068 set) presents.
                var digests: [Int: String] = [:]
                for n in 1...12 {
                    XCTAssertEqual(try run.step(), .committed)
                    if let frame = try run.presented(), n == 12 || digests.isEmpty {
                        digests[n] = SyntheticDigest.sha256(frame)
                        XCTAssertEqual([frame.width, frame.height], [800, 600])
                    }
                }
                syntheticLog("E7D rung2 front digests \(digests.sorted { $0.key < $1.key })")
                XCTAssertEqual(digests, Self.pinnedFrontFrames)
                // Selector 0 (the title screen), World+0 0; the front bitmaps' slots hold
                // allocations, and settings loading has cleared the record's load flag
                // (0xe7d in the pack; OriginalSettingsLoading.swift:139).
                XCTAssertEqual(try [run.global(0x44d064), run.global(0x458b00)], [0, 0])
                XCTAssertEqual(try OriginalFrontMenuResources.slots.filter { try run.global($0) == 0 }, [])
                XCTAssertEqual(try run.global(0x44d068), 0)
                syntheticLog("E7D rung2 menu iterations \(run.menu.iterations) requests \(run.menu.requests) debug \(run.menu.diagnostics.debug.map { String(decoding: $0, as: UTF8.self) }) messages \(run.menu.diagnostics.messages.count) presents \(window.presents)")
                XCTAssertEqual([run.menu.iterations, run.menu.requests, window.presents], Self.pinnedMenuCounts)
                XCTAssertEqual(run.menu.diagnostics.messages.count, 0)
                XCTAssertEqual(run.log.shown, [])
            }
        }
    }
    /// Startup: committed sequence, window token, attempts, served requests.
    static let pinnedStartup = [1, 3, 59, 58]
    static let pinnedOwners = ["runtime": 17, "audio": 22, "display": 8, "window": 11]
    /// The first presented front frame (iteration 3) and iteration 12's: the title screen holds still.
    static let pinnedFrontFrames = [3: "95e6c67eb114d63c197c887ab381b46caeeec06a600a72bb83cb0d2fb1175aaa",
                                    12: "95e6c67eb114d63c197c887ab381b46caeeec06a600a72bb83cb0d2fb1175aaa"]
    /// Menu iterations, served requests, presents.
    static let pinnedMenuCounts = [12, 733, 10]

    /// The session's arguments for the pack: content from `--resources`, the
    /// virtual clock, no network, original menu input, synchronous rendering.
    @MainActor static func sessionArguments(_ root: URL, _ extra: [String] = []) -> [String] {
        ["NTSDEngineTests", "--resources", root.path, "--virtual-clock", String(SyntheticRun.clockBase), String(SyntheticRun.clockStep),
         "--no-network", "--original-menu-input", "--synchronous-render", "--mute-music", "--mute-sounds",
         "--overlay", root.appendingPathComponent("session-overlay").path] + extra
    }

    /// RandoriHeadlessHost's `--exit-after-startup`: the session reads the pack
    /// from `--resources`, runs startup, music and sound output, and ends.
    func testSessionExitsAfterStartup() throws {
        try Pack.withWrittenPack { root, pack in
            MainActor.assumeIsolated {
                let host = SyntheticSessionHost(pack: pack, root: root)
                let session = OriginalRuntimeSession(arguments: Self.sessionArguments(root, ["--exit-after-startup"]), host: host)
                session.start()
                XCTAssertTrue(host.terminated)
                XCTAssertEqual(host.stops, [])
                XCTAssertFalse(session.stopped)
                XCTAssertEqual(host.didStartCalls, 0, "it ends before the menu")
                XCTAssertEqual(host.windowHost.windows.map { [$0.client.width, $0.client.height] }, [[800, 600]])
                XCTAssertEqual(host.runScheduled(1), 0, "no iteration scheduled")
            }
        }
    }

    /// The session's own front menu on the pack: its scheduled iterations,
    /// run by the test, present the same frame as the driver's (the same
    /// virtual clock; the session's startup takes the host's time zone).
    func testSessionFrontMenuPresentsTheDriversFrame() throws {
        try Pack.withWrittenPack { root, pack in
            try MainActor.assumeIsolated {
                let host = SyntheticSessionHost(pack: pack, root: root)
                let session = OriginalRuntimeSession(arguments: Self.sessionArguments(root), host: host)
                session.start()
                XCTAssertEqual(host.didStartCalls, 1)
                XCTAssertEqual(host.runScheduled(12), 12)
                XCTAssertEqual(host.stops, [])
                XCTAssertFalse(session.loadingStarted)
                let backend = try XCTUnwrap(host.backend)
                let frame = try XCTUnwrap(try backend.presentedFrame(session.gameWindow))
                XCTAssertEqual(SyntheticDigest.sha256(frame), Self.pinnedFrontFrames[12])
            }
        }
    }
}
