import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform
@testable import NTSDRuntime

/// START → loading on runtime providers with inline audio delivery.
@MainActor final class OriginalMacRuntimeLoadingTests: XCTestCase {
    enum Stop: Error { case limit }
    /// Actual localhost IO is performed once even if the owned input attempt
    /// is recomputed. Short receives retain their original boundaries/replies.
    func testNetworkInputRetryKeepsReceiptsWithoutRepeatingSocketIO() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-control-\(UUID().uuidString)",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let (started,package) = try OriginalMacRuntimeMenuTests().startup(root)
        let loading = try OriginalMacRuntimeLoading.bundled(started,startupInputs:package,clock:{ 5000 })
        let network = OriginalMacRuntimeNetwork(),w = network.winsock
        var notes: [OriginalMacWinsock.Notification] = []
        w.post = { notes.append($0) }
        loading.network = network
        XCTAssertEqual(w.startup(0x101).result,0)
        defer { _ = w.cleanup() }
        let listener = w.socket(family:AF_INET,type:SOCK_STREAM,protocol:IPPROTO_TCP)
        XCTAssertEqual(w.bind(listener,address:0x0100007f,port:0),0)
        XCTAssertEqual(w.listen(listener,backlog:1),0)
        XCTAssertEqual(w.asyncSelect(listener,window:7,message:0x401,events:0x38),0)
        let peer = w.socket(family:AF_INET,type:SOCK_STREAM,protocol:IPPROTO_TCP)
        XCTAssertEqual(w.connect(peer,address:0x0100007f,port:try XCTUnwrap(w.boundPort(listener))),0)
        let deadline = Date().addingTimeInterval(3)
        while notes.isEmpty && Date() < deadline { RunLoop.main.run(until:Date().addingTimeInterval(0.01)) }
        XCTAssertEqual(notes,[.init(window:7,message:0x401,socket:listener,lParam:8)])
        let server = w.accept(listener)
        guard server != OriginalMacWinsock.invalidSocket else { return XCTFail("Own listener was not ready: \(w.lastError)") }
        XCTAssertEqual(w.close(listener),0)
        let outgoing = Array(UInt8(0)..<22),incoming = Array(UInt8(80)..<102)
        let requests: [OriginalInputControlRequest] = [
            .init(.asyncSelect,[listener,7,0,0]),.init(.asyncSelect,[server,7,0,0]),
            .init(.ioctl,[listener,0x8004667e,0]),.init(.ioctl,[server,0x8004667e,1],[[0,0,0,0]]),
            .init(.send,[server,22,0],[outgoing]),.init(.receive,[server,0,22,0]),
            .init(.receive,[server,10,12,0]),.init(.message,[0,0x4493b4,0x447850,0])]
        var messages = 0
        loading.messageBox = { text,caption,flags in
            XCTAssertEqual(text,Array("Connection Lost!".utf8));XCTAssertEqual(caption,Array("Error".utf8));XCTAssertEqual(flags,0)
            messages += 1;return 1
        }
        try loading.beginInputControl()
        var replies: [OriginalInputControlResponse] = []
        for (index,request) in requests.enumerated() {
            if index == 5 { XCTAssertEqual(w.send(peer,Array(incoming.prefix(10))),10) }
            if index == 6 { XCTAssertEqual(w.send(peer,Array(incoming.suffix(12))),12) }
            replies.append(try loading.control(request))
        }
        XCTAssertEqual(replies.map(\.result),[-1,0,-1,0,22,10,12,1])
        XCTAssertEqual(replies[5].bytes+replies[6].bytes,incoming)
        XCTAssertEqual(w.receive(peer,capacity:22).bytes,outgoing)
        XCTAssertEqual(network.controlRequestCount,7);XCTAssertEqual(messages,1)
        // A failed enclosing calculation retries the same call at the same Host
        // sequence. No peer sends again, so a repeated blocking recv would hang.
        try loading.beginInputControl()
        XCTAssertEqual(try requests.map { try loading.control($0) },replies)
        XCTAssertEqual(network.controlRequestCount,7);XCTAssertEqual(messages,1)
        XCTAssertEqual(network.sentControlPackets,1);XCTAssertEqual(network.receivedControlBytes,22)
        XCTAssertEqual(w.setNonBlocking(peer,true),0)
        XCTAssertEqual(w.receive(peer,capacity:22).result,OriginalMacWinsock.socketError)
        XCTAssertEqual(w.lastError,OriginalMacWinsock.wouldBlock)
        // A service failure marks this journal terminal rather than retrying IO.
        XCTAssertThrowsError(try loading.control(.init(.send,[server,23,0],[outgoing])))
        XCTAssertThrowsError(try loading.beginInputControl())
    }
    /// Network mismatch shutdown releases secondary buffers and then the
    /// device. A device must never be interpreted as PCM or a buffer method.
    func testCommittedShutdownReleasesPlayingAndUnusedAudio() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-control-release-\(UUID().uuidString)",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let (started,package) = try OriginalMacRuntimeMenuTests().startup(root)
        let loading = try OriginalMacRuntimeLoading.bundled(started,startupInputs:package,clock:{ 5000 })
        let sounds = OriginalMacSoundEffects.backed(by:started.audio)
        let buffers = started.audio.bufferTokens.sorted()
        XCTAssertGreaterThanOrEqual(buffers.count,2)
        let playing = buffers[0],unused = buffers[1],device = try XCTUnwrap(started.audio.deviceTokens.first)
        try loading.performSound(.init(buffer:playing,method:0x30,arguments:[0,0,1]),on:sounds)
        XCTAssertEqual(sounds.voice(playing)?.playing,true)
        for token in [playing,unused,device] {
            try loading.performSound(.init(buffer:token,method:8,arguments:[]),on:sounds)
        }
        XCTAssertEqual(sounds.voice(playing)?.playing,false)
        XCTAssertNil(sounds.voice(unused));XCTAssertNil(sounds.voice(device))
        XCTAssertEqual(sounds.performed,1)
        XCTAssertThrowsError(try loading.performSound(.init(buffer:device,method:8,arguments:[1]),on:sounds))
        XCTAssertThrowsError(try loading.performSound(.init(buffer:UInt32.max,method:8,arguments:[]),on:sounds))
    }
    /// INPUT_CONTROL's error path calls the shared shutdown before examining
    /// the next header. The source can then fault while writing its freed
    /// recording buffer; neither shutdown nor the close posts depend on finish.
    func testControlShutdownPrecedesNextDialogAndSurvivesRecordingFault() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-control-order-\(UUID().uuidString)",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let (started,package) = try OriginalMacRuntimeMenuTests().startup(root)
        let loading = try OriginalMacRuntimeLoading.bundled(started,startupInputs:package,clock:{ 5000 })
        let network = OriginalMacRuntimeNetwork();loading.network = network
        XCTAssertEqual(network.winsock.startup(0x101).result,0)
        defer { _ = network.winsock.cleanup() }
        let sounds = OriginalMacSoundEffects.backed(by:started.audio);loading.sounds = sounds
        let buffers = started.audio.bufferTokens.sorted()
        let playing = try XCTUnwrap(buffers.first),unused = try XCTUnwrap(buffers.dropFirst().first)
        let device = try XCTUnwrap(started.audio.deviceTokens.first)
        try sounds.perform(.init(buffer:playing,method:0x30,arguments:[0,0,1]))

        var globals = try OriginalApplicationMenuSession.State.slice(
            XCTUnwrap(started.host.snapshot.session).state.full,0,OriginalMatchPreparation.globalSize)
        let music = started.runtime.music
        // Dispose the startup graph through the recovered release helper, then
        // supply owned interfaces for the controlled shutdown case.
        try OriginalMusicPlayback.release(globals:&globals,request:{ try music.answer($0) })
        let graph = try OriginalMacMusicOutputTests().play(music,"bgm\\main.wma",volume:0)
        for (address,token) in [(0x44f04c,graph.position),(0x44f048,graph.event),(0x44f044,graph.control),(0x44f040,graph.graph),
            (0x44eecc,device),(0x458438,UInt32(1)),(0x45843c,UInt32(1)),(0x452948,playing),(0x451db0,unused)] {
            try globals.write(token,at:address-OriginalMatchPreparation.globalBase)
        }
        let player = OriginalMacMusicOutputTests.Recorder(URL(fileURLWithPath:"/main.caf"),duration:100)
        let output = OriginalMacMusicOutput(tracks:["bgm\\main.wma":player.url]) { _,_ in player }
        try output.present(music.presented());XCTAssertTrue(player.isPlaying)
        loading.presentControlMusic = { try output.present(music.presented()) }
        var events: [String] = []
        loading.messageBox = { _,_,_ in
            if events.isEmpty { XCTAssertEqual(sounds.voice(playing)?.playing,true);XCTAssertTrue(player.isPlaying) }
            else { XCTAssertEqual(events,["message","post"]);XCTAssertEqual(sounds.voice(playing)?.playing,false);XCTAssertFalse(player.isPlaying) }
            events.append("message");return 1
        }
        loading.postMessage = { message,wParam,lParam in
            XCTAssertEqual([message,wParam,lParam],[0x10,0,0])
            XCTAssertEqual(sounds.voice(playing)?.playing,false);XCTAssertFalse(player.isPlaying)
            XCTAssertNil(sounds.voice(unused));XCTAssertNil(sounds.voice(device))
            events.append("post")
        }
        let zero = try OriginalStateRecord(bytes:[0,0,0,0,0,0,0,0],defined:Array(repeating:true,count:8))
        var memory = OriginalMenuPresentationMemory(replayPointers:zero)
        for (offset,token) in [(0,UInt32(0x30000000)),(4,UInt32(0x30000100))] {
            try memory.replayPointers.write(token,at:offset)
            memory.allocations[token] = .init(storage:zero)
        }
        let originalGlobals = globals,originalMemory = memory
        func attempt() throws {
            try loading.beginInputControl()
            for text: UInt32 in [0x4493b4,0x449384] {
                _ = try loading.control(.init(.message,[0,text,0x447850,0]))
                try OriginalMenuPresentation.shutdown(globals:&globals,memory:&memory) { e in
                    let kind: OriginalInputControlRequest.Kind
                    switch e.kind { case .method:kind = .method;case .free:kind = .free;case .postMessage:kind = .postMessage;default:throw Stop.limit }
                    _ = try loading.control(.init(kind,e.arguments,e.strings))
                }
            }
            var context = OriginalInputControlContext(savedPlayback:zero,memory:memory)
            XCTAssertThrowsError(try context.recordReplayPacket(tick:1,commands:Array(repeating:0,count:10),observe:{ _ in })) {
                XCTAssertTrue(String(describing:$0).contains("4588a8 recording"))
            }
        }
        try attempt()
        XCTAssertEqual(events,["message","post","message","post"])
        XCTAssertTrue(memory.allocations.values.allSatisfy { !$0.live })
        XCTAssertNil(music.presented());XCTAssertFalse(player.isPlaying)
        let musicCalls = music.operations.count,playerCalls = player.log
        // Recompute the same failed owned attempt: requests use receipts even
        // though the music interfaces were released on the first attempt.
        globals = originalGlobals;memory = originalMemory
        try attempt()
        XCTAssertEqual(events,["message","post","message","post"])
        XCTAssertEqual(music.operations.count,musicCalls);XCTAssertEqual(player.log,playerCalls)
        // No Host finish/commit was called; the original recording fault remains.
    }
    func testControlMusicOutputFailureIsTerminalAndNotRetried() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-control-music-failure-\(UUID().uuidString)",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let (started,package) = try OriginalMacRuntimeMenuTests().startup(root)
        let loading = try OriginalMacRuntimeLoading.bundled(started,startupInputs:package,clock:{ 5000 })
        let network = OriginalMacRuntimeNetwork();loading.network = network
        XCTAssertEqual(network.winsock.startup(0x101).result,0);defer { _ = network.winsock.cleanup() }
        let graph = try OriginalMacMusicOutputTests().play(started.runtime.music,"bgm\\main.wma",volume:0)
        var calls = 0
        loading.presentControlMusic = { calls += 1;throw Stop.limit }
        try loading.beginInputControl()
        XCTAssertThrowsError(try loading.control(.init(.method,[graph.position,8])))
        let performed = started.runtime.music.operations.count
        XCTAssertThrowsError(try loading.beginInputControl())
        XCTAssertEqual(calls,1);XCTAssertEqual(started.runtime.music.operations.count,performed)
    }
    func testInlineCursorRecordsReceiptsAndRetriesReuseThem() throws {
        typealias E = OriginalStartupRequestExchange
        let e = E(); var served = 0
        let serve: (E.Permit) throws -> Void = { permit in
            served += 1; try e.beginService(permit); try e.answer(permit,response:.milliseconds(UInt32(100+served)))
        }
        var first = try e.inlineCursor(serve)
        func value(_ r: OriginalStartupResponse) -> UInt32? { if case .milliseconds(let v) = r { return v }; return nil }
        XCTAssertEqual(value(try first.response(for:.milliseconds)),101)
        XCTAssertEqual(value(try first.response(for:.milliseconds)),102)
        XCTAssertEqual(e.snapshot.receipts.count,2); XCTAssertEqual(served,2)
        // A retried attempt reuses both receipts and serves only the new request.
        var retry = try e.inlineCursor(serve)
        XCTAssertEqual(value(try retry.response(for:.milliseconds)),101)
        XCTAssertEqual(value(try retry.response(for:.milliseconds)),102)
        XCTAssertEqual(value(try retry.response(for:.milliseconds)),103)
        XCTAssertEqual(served,3); XCTAssertThrowsError(try e.finish(first))
        XCTAssertThrowsError(try retry.response(for:.filetime))  // the exchange rejects a reply of the wrong family
        _ = try? e.finish(retry)
        // A permit cursor still suspends; a failing inline service ends the exchange.
        let f = E(); var plain = try f.snapshot.cursor()
        XCTAssertThrowsError(try plain.response(for:.milliseconds)) { XCTAssertTrue($0 is E.RequestNeeded) }
        let g = E(); var failing = try g.inlineCursor { permit in
            try g.beginService(permit); try g.fail(permit,diagnostic:"device"); throw Stop.limit
        }
        XCTAssertThrowsError(try failing.response(for:.milliseconds)); XCTAssertEqual(g.snapshot.status,.indeterminate)
    }
    func testStartLoadsCatalogPoolAndLoadedMenuInOneAttempt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-loading-\(UUID().uuidString)",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let (started,package) = try OriginalMacRuntimeMenuTests().startup(root)
        while try started.host.takeCommitted() != nil {}
        var now: UInt32 = 5_000_000
        let clock: () throws -> UInt32 = { now &+= 7; return now }
        let menu = try OriginalMacRuntimeMenu(started,inputs:package,clock:clock)
        var loadingRequested = false
        func step() throws {
            do { if case .loading = try menu.step() { loadingRequested = true } }
            catch { print("Runtime menu stopped:",error,"at",String(describing:menu.lastRequest).prefix(600));throw error }
        }
        for _ in 0..<400 where try XCTUnwrap(started.host.snapshot.session).state.settings == nil { try step() }
        for _ in 0..<10 { try step() }
        // Click START, as the saved menu-input case 47 stimulus: move to (350,230), left button.
        menu.messages.mouse(0x200,x:350,y:230,buttons:0)
        for _ in 0..<10 where !loadingRequested { try step() }
        menu.messages.mouse(0x201,x:350,y:230,buttons:1)
        for _ in 0..<300 where !loadingRequested { try step() }
        XCTAssertTrue(loadingRequested); XCTAssertNotNil(started.host.pendingLoading)
        let loading = try OriginalMacRuntimeLoading.bundled(started,startupInputs:package,clock:clock)
        let begin = Date()
        let outcome: OriginalMacRuntimeLoading.Host.LoadedOutcome
        do { outcome = try loading.run() }
        catch { print("Runtime loading stopped:",error,loading.counts);throw error }
        let seconds = Date().timeIntervalSince(begin)
        let c = loading.counts
        XCTAssertEqual(c.audioRequests,18*4+400*5)
        XCTAssertEqual(started.audio.bufferTokens.count,5+18+400)
        XCTAssertGreaterThan(c.bitmapRequests,12000); XCTAssertEqual(c.files,621)
        guard case .returned = outcome else { return XCTFail("loaded menu did not return: \(outcome)") }
        let tail = Date()
        guard case .committed = try loading.finish() else { return XCTFail("Host tail") }
        print(String(format:"Runtime first tail+replay %.2fs, %d draws",Date().timeIntervalSince(tail),loading.counts.replayedDraws))
        XCTAssertNil(started.host.pendingLoading)
        while try started.host.takeCommitted() != nil {}
        // Later outer iterations return through cached loaded cycles.
        var after = 0,cycles = 0
        func advance() throws {
            switch try menu.step() {
            case .committed: after += 1
            case .loading:
                cycles += 1
                let t0 = Date()
                guard case .returned = try loading.runCycle() else { throw Stop.limit }
                let t1 = Date()
                guard case .committed = try loading.finish() else { throw Stop.limit }
                if cycles <= 3 { print(String(format:"Runtime cycle %d: prepare %.2fs, tail+replay %.2fs",cycles,t1.timeIntervalSince(t0),Date().timeIntervalSince(t1))) }
            }
        }
        for _ in 0..<12 {
            do { try advance() }
            catch { print("Runtime cycle stopped:",error,loading.counts,"at",String(describing:menu.lastRequest).prefix(400));throw error }
        }
        XCTAssertGreaterThan(cycles,0); XCTAssertGreaterThan(loading.counts.replayedDraws,0)
        let capture = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-runtime-loaded.png")
        try started.windows.snapshotPNG(started.window).write(to:capture)
        print("Runtime loading:",String(format:"%.1fs",seconds),c,"after",after,"iterations,",cycles,"cycles,",loading.counts.replayedDraws,"replayed draws; capture",capture.path)
    }
}
