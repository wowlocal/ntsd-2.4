import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform
@testable import NTSDRuntime

@MainActor final class OriginalApplicationNetworkExitTests: XCTestCase {
    enum Stop: Error { case limit }

    /// Cancelling the actual ONLINE GAME menu releases its listener; the next
    /// visit can bind the same port. No native globals are supplied by the test.
    func testMenuCancelCleansUpAndCanReenterOnlineGame() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-exit-\(UUID().uuidString)",isDirectory:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let (started,package) = try OriginalMacRuntimeMenuTests().startup(root)
        while try started.host.takeCommitted() != nil {}
        var now: UInt32 = 5_000_000
        let menu = try OriginalMacRuntimeMenu(started,inputs:package,clock:{ now &+= 7;return now })
        let network = OriginalMacRuntimeNetwork(localAddresses:[0x0100007f]);menu.network = network
        network.winsock.post = { [weak menu] n in menu?.messages.post(n.message,n.socket,n.lParam) }
        defer { if network.winsock.started { _ = network.winsock.cleanup() } }
        var boxes: [String] = [],exits: [OriginalNetworkExit.Request.Kind] = []
        menu.messages.messageBox = { text,_,_ in boxes.append(String(decoding:text,as:UTF8.self));return 1 }
        network.observeExit = { q,_ in exits.append(q.kind) }
        func state() throws -> OriginalApplicationMenuSession.State { try XCTUnwrap(started.host.snapshot.session).state }
        func word(_ a: Int) throws -> UInt32 { try state().full.integer(at:a-OriginalMatchPreparation.globalBase,as:UInt32.self) }
        func step() throws { guard case .committed = try menu.step() else { throw Stop.limit } }
        for _ in 0..<400 where try state().settings == nil { try step() }
        XCTAssertNotNil(try state().settings)
        func click(_ x: Int32,_ y: Int32,until condition: () throws -> Bool) throws {
            menu.messages.mouse(0x200,x:x,y:y,buttons:0);menu.messages.mouse(0x201,x:x,y:y,buttons:1)
            for _ in 0..<150 where try !condition() { try step() }
            XCTAssertTrue(try condition())
            menu.messages.mouse(0x202,x:x,y:y,buttons:0)
            for _ in 0..<12 where !menu.messages.queue.isEmpty { try step() }
            XCTAssertTrue(menu.messages.queue.isEmpty)
            // WM_LBUTTONUP updates the live button; presentation's next frame
            // copies it to44d060, the original previous-button edge detector.
            for _ in 0..<12 where try word(0x44d060) != 0 { try step() }
            XCTAssertEqual(try word(0x44d060),0)
        }
        for _ in 0..<2 {
            try click(410,262) { guard network.winsock.started else { return false };return try word(0x44d064) == 1 }
            let listener = try word(0x44f1b4)
            XCTAssertEqual(network.winsock.boundPort(listener),12345)
            try click(400,348) { guard !network.winsock.started else { return false };return try word(0x44d064) == 0 }
            XCTAssertTrue(network.winsock.openHandles.isEmpty)
            XCTAssertEqual(try word(0x44f1b4),0);XCTAssertEqual(try word(0x44f1b0),0)
        }
        XCTAssertEqual(exits,[.closeSocket,.cleanup,.closeSocket,.cleanup])
        XCTAssertEqual(network.exitRequestCount,4);XCTAssertTrue(boxes.isEmpty)
    }

    /// Controlled platform inputs to the already recovered whole402d70. A real
    /// connected socket sends the exact binary-address suffix; an unconnected
    /// socket takes the original early-error branch without cleanup/global clear.
    func testExitSendsAddressPrefixAndRetainsEarlyErrorState() throws {
        for connected in [true,false] {
            let network = OriginalMacRuntimeNetwork(),w = network.winsock,peer = OriginalMacWinsock()
            XCTAssertEqual(w.startup(0x101).result,0);XCTAssertEqual(peer.startup(0x101).result,0)
            defer { if w.started { _ = w.cleanup() };_ = peer.cleanup() }
            let listener = w.socket(family:2,type:1,protocol:6)
            XCTAssertEqual(w.bind(listener,address:0x0100007f,port:0),0);XCTAssertEqual(w.listen(listener,backlog:1),0)
            let port = try XCTUnwrap(w.boundPort(listener)),client = peer.socket(family:2,type:1,protocol:6)
            let socket: UInt32
            if connected {
                XCTAssertEqual(peer.connect(client,address:0x0100007f,port:port),0)
                socket = w.accept(listener);XCTAssertNotEqual(socket,UInt32.max)
            } else { socket = listener }
            let base = OriginalMatchPreparation.globalBase
            var globals = try OriginalStateRecord(bytes:Array(repeating:0,count:OriginalMatchPreparation.globalSize),defined:Array(repeating:false,count:OriginalMatchPreparation.globalSize))
            try globals.write(socket,at:0x44f1b4-base);try globals.write(UInt32(1),at:0x44f1b0-base)
            try globals.write(UInt32(0x0100007f),at:0x44f208-base)
            let address: [UInt8] = [2,0,UInt8(port>>8),UInt8(port&255),127,0,0,1]+Array(repeating:0,count:8)
            for (i,b) in address.enumerated() { try globals.write(b,at:0x44f58c-base+i) }
            var local = try OriginalStateRecord(bytes:Array(repeating:0,count:256),defined:Array(repeating:false,count:256))
            var kinds: [OriginalNetworkExit.Request.Kind] = [],boxes = 0
            let result = try OriginalNetworkExit.run(globals:&globals,local:&local,request:{ q in
                kinds.append(q.kind)
                if q.kind == .message { boxes += 1;XCTAssertEqual(q.bytes,Array("sendto()\0Error\0".utf8));return 1 }
                return try network.answer(q)
            })
            XCTAssertEqual(result,0)
            if connected {
                let expected = Array("Client want to EXIT.".utf8)+[127]
                XCTAssertEqual(peer.receive(client,capacity:24).bytes,expected)
                XCTAssertEqual(peer.receive(client,capacity:1).result,0)
                XCTAssertEqual(kinds,[.sendTo,.closeSocket,.cleanup]);XCTAssertEqual(boxes,0)
                XCTAssertFalse(w.started);XCTAssertTrue(w.openHandles.isEmpty)
                XCTAssertEqual(try globals.integer(at:0x44f1b4-base,as:UInt32.self),0)
                XCTAssertEqual(try globals.integer(at:0x44f1b0-base,as:UInt32.self),0)
            } else {
                XCTAssertEqual(kinds,[.sendTo,.message,.closeSocket]);XCTAssertEqual(boxes,1)
                XCTAssertTrue(w.started);XCTAssertTrue(w.openHandles.isEmpty)
                XCTAssertEqual(try globals.integer(at:0x44f1b4-base,as:UInt32.self),socket)
                XCTAssertEqual(try globals.integer(at:0x44f1b0-base,as:UInt32.self),1)
            }
        }
    }
}
