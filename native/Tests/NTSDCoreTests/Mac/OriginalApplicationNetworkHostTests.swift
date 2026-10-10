import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform
@testable import NTSDRuntime

/// Actual menu startup/listener and the whole 0x401 iteration. The peer is a
/// task-owned socket on this machine; it supplies input, never an after-state.
@MainActor final class OriginalApplicationNetworkHostTests: XCTestCase {
    typealias Menu = OriginalMacRuntimeMenu
    typealias Driver = Menu.Driver
    enum Stop: Error { case limit, late }

    func testHostGreetingThroughMenuPermitsDoesNotRepeatIOAfterLateValidation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-network-host-\(UUID().uuidString)",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let (started,package) = try OriginalMacRuntimeMenuTests().startup(root)
        while try started.host.takeCommitted() != nil {}
        var now: UInt32 = 5_000_000
        let menu = try Menu(started,inputs:package,clock:{ now &+= 7; return now })
        let network = OriginalMacRuntimeNetwork(),peer = OriginalMacWinsock()
        menu.network = network
        network.winsock.post = { [weak menu] n in menu?.messages.post(n.message,n.socket,n.lParam) }
        defer { _ = peer.cleanup(); _ = network.winsock.cleanup() }
        var boxes: [String] = []
        menu.messages.messageBox = { text,_,_ in boxes.append(String(decoding:text,as:UTF8.self)); return 1 }
        func step() throws { guard case .committed = try menu.step() else { throw Stop.limit } }
        func state() throws -> OriginalApplicationMenuSession.State { try XCTUnwrap(started.host.snapshot.session).state }
        func word(_ address: Int) throws -> UInt32 { try state().full.integer(at:address-OriginalMatchPreparation.globalBase,as:UInt32.self) }
        for _ in 0..<400 where try state().settings == nil { try step() }
        XCTAssertNotNil(try state().settings)
        func click(_ x: Int32,_ y: Int32,until condition: () throws -> Bool) throws {
            menu.messages.mouse(0x200,x:x,y:y,buttons:0)
            menu.messages.mouse(0x201,x:x,y:y,buttons:1)
            for _ in 0..<100 where try !condition() { try step() }
            XCTAssertTrue(try condition())
            menu.messages.mouse(0x202,x:x,y:y,buttons:0)
            for _ in 0..<10 where !menu.messages.queue.isEmpty { try step() }
            XCTAssertTrue(menu.messages.queue.isEmpty)
        }
        try click(410,262) { network.requests.contains { $0.kind == .listen } }
        XCTAssertTrue(boxes.isEmpty)
        let listener = try word(0x44f1b4)
        XCTAssertEqual(network.winsock.boundPort(listener),12345)
        try click(400,287) { try word(0x44d064) == 2 }
        let before = try state(),base = OriginalMatchPreparation.globalBase
        let table = Array(before.full.bytes[(0x44ff90-base)..<(0x44ff90-base+3001)])
        var names = [UInt8](repeating:49,count:4)+[UInt8](repeating:48,count:28)
        for i in 0..<4 {
            let raw = Array(before.full.bytes[(0x44fcc0-base+11*i)..<(0x44fcc0-base+11*(i+1))])
            let text = Array(raw.prefix { $0 != 0 })
            XCTAssertLessThan(text.count,11)
            names += text+[UInt8](repeating:95,count:11-text.count)
        }
        names.append(0)
        var packet = Array("01010101".utf8)+[UInt8](repeating:48,count:24)
        packet += Array("Peer".utf8)+[UInt8](repeating:95,count:40)+[0]
        XCTAssertEqual(packet.count,77)
        XCTAssertEqual(peer.startup(0x101).result,0)
        let socket = peer.socket(family:2,type:1,protocol:6)
        // The original binds the address chosen from its own hostname, so the
        // local peer connects to that exact interface address, not another host.
        XCTAssertEqual(peer.connect(socket,address:try word(0x44f590),port:12345),0)
        XCTAssertEqual(peer.send(socket,packet),77)
        XCTAssertEqual(peer.setNonBlocking(socket,true),0)
        let deadline = Date().addingTimeInterval(3)
        while menu.messages.queue.isEmpty && Date() < deadline { RunLoop.main.run(until:Date().addingTimeInterval(0.01)) }
        XCTAssertEqual(menu.messages.queue.first?.message,0x401)
        XCTAssertEqual(menu.messages.queue.first?.lParam,8)

        let driver = Driver(host:started.host)
        var late = false,done = false,socketKinds: [OriginalNetworkNotification.Request.Kind] = []
        var sends: [[UInt8]] = [],sleeps: [UInt32] = []
        let began = Date()
        for _ in 0..<50 where !done {
            do {
                switch try driver.resume(prepare:{ _,s in try menu.inputs(s) },beforePublication:{ _ in
                    if !late { throw Stop.late }
                },network:true) {
                case .request(let permit):
                    XCTAssertEqual(try state().full,before.full)
                    switch permit.request {
                    case .queue,.windowDefault: try menu.messages.serve(permit,on:driver)
                    case .socket(let q):
                        socketKinds.append(q.kind)
                        if q.kind == .send { sends.append(q.bytes) }
                        if q.kind == .sleep { sleeps.append(q.arguments[0]) }
                        try driver.beginService(permit)
                        do { try driver.answer(permit,response:.socket(try network.answer(q))) }
                        catch { try driver.fail(permit,diagnostic:String(reflecting:error)); throw error }
                    default: throw Stop.limit
                    }
                case .advanced(let result):
                    guard case .committed = result else { throw Stop.limit }
                    done = true
                }
            } catch Stop.late {
                XCTAssertFalse(late); late = true
                XCTAssertEqual(try state().full,before.full)
                XCTAssertEqual(started.host.pendingBatchCount,0)
            }
        }
        XCTAssertTrue(done && late)
        XCTAssertEqual(driver.exchangeSnapshot.status,.finished)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(began),4)
        XCTAssertEqual(socketKinds,[.accept,.closeSocket,.send,.sleep,.receive,.sleep,.send,.sleep,.send])
        XCTAssertEqual(sleeps,[3000,500,500]); XCTAssertEqual(network.notificationRequestCount,9)
        let greeting = Array("u can connect".utf8)+[0]
        XCTAssertEqual(sends,[greeting,names,table])
        var received: [UInt8] = []
        let end = Date().addingTimeInterval(3)
        while received.count < 3092 && Date() < end {
            let r = peer.receive(socket,capacity:3092-received.count)
            if r.result > 0 { received += r.bytes } else { RunLoop.main.run(until:Date().addingTimeInterval(0.01)) }
        }
        XCTAssertEqual(received,greeting+names+table)
        XCTAssertEqual(peer.receive(socket,capacity:1).result,-1) // no duplicate send on retry
        XCTAssertEqual(peer.lastError,OriginalMacWinsock.wouldBlock)
        XCTAssertNil(network.winsock.boundPort(listener))
        XCTAssertNotEqual(try word(0x44f46c),UInt32.max)
        let after = try state()
        XCTAssertEqual(try after.full.integer(at:0x44f1af-base,as:UInt8.self),2)
        XCTAssertEqual(try after.full.integer(at:0x44f1ae-base,as:UInt8.self),1)
        XCTAssertEqual(Array(after.full.bytes[(0x44fcec-base)..<(0x44fcec-base+44)]),Array(packet[32..<76]).map { $0 == 95 ? 0 : $0 })
        for i in 0..<8 {
            let expected: UInt32 = packet[i] == 49 ? .max : (i < 4 ? UInt32(i+1) : try before.full.integer(at:0x450b4c-base+4*i,as:UInt32.self))
            XCTAssertEqual(try word(0x450b4c+4*i),expected)
        }
        let changed = [(0x44f1ae,2),(0x44f46c,4),(0x450b4c,32),(0x44fcec,44),(0x458580,4)]
        let indices = before.full.bytes.indices.filter { i in !changed.contains { start,count in (start-base..<start-base+count).contains(i) } }
        XCTAssertEqual(indices.map { before.full.bytes[$0] },indices.map { after.full.bytes[$0] })
        XCTAssertEqual(indices.map { before.full.defined[$0] },indices.map { after.full.defined[$0] })
        _ = try started.host.takeCommitted()
        // Other notifications are message boxes and DefWindowProc only; they
        // retain the accepted socket and never run acceptance a second time.
        for (event,label): (UInt32,String) in [(1,"FD_READ"),(16,"FD_CONNECT"),(32,"FD_CLOSE")] {
            menu.messages.post(0x401,try word(0x44f46c),event | 10054 << 16)
            try step(); XCTAssertEqual(boxes.last,label)
        }
        XCTAssertEqual(network.notificationRequestCount,9)
    }
}
