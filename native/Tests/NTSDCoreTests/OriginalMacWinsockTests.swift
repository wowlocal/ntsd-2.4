import Foundation
import XCTest
@testable import NTSDMacPlatform

/// NETWORK_PLAY_PLAN.md N1: the Mac Winsock service on loopback, in the order
/// the original's host notification and client attempt use it.
final class OriginalMacWinsockTests: XCTestCase {
    typealias W = OriginalMacWinsock
    private func spin(until condition: () -> Bool, seconds: Double = 5) {
        let end = Date().addingTimeInterval(seconds)
        while !condition() && Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    }
    private func receive(_ w: W, _ s: UInt32, _ count: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        while bytes.count < count {
            let (result, chunk) = w.receive(s, capacity: count-bytes.count)
            if result <= 0 { break }
            bytes += chunk
        }
        return bytes
    }

    func testStartupNamesAndAddresses() {
        let w = W()
        XCTAssertEqual(w.socket(family: AF_INET, type: SOCK_STREAM, protocol: IPPROTO_TCP), W.invalidSocket) // before WSAStartup
        let (result, data) = w.startup(0x101)
        XCTAssertEqual(result, 0); XCTAssertEqual(data.count, 400)
        XCTAssertEqual(Array(data[0..<4]), [1, 1, 2, 2])
        XCTAssertEqual(String(decoding: data[4..<15], as: UTF8.self), "WinSock 2.0")
        let (named, name) = w.hostName(capacity: 256)
        XCTAssertEqual(named, 0); XCTAssertEqual(name.last, 0); XCTAssertGreaterThan(name.count, 1)
        XCTAssertEqual(w.hostAddresses(Array("localhost".utf8))?.contains(0x0100007f), true)
        XCTAssertEqual(W.address(Array("127.0.0.1".utf8)+[0]), 0x0100007f)
        XCTAssertEqual(W.address(Array("192.168.1.20".utf8)), 0x1401a8c0)
        XCTAssertEqual(W.address(Array("12345".utf8)), 0xffff_ffff)
        XCTAssertEqual(W.text(0x0100007f), Array("127.0.0.1".utf8))
        XCTAssertEqual(W.htons(12345), 0x3930)
        XCTAssertEqual(w.cleanup(), 0); XCTAssertEqual(w.cleanup(), W.socketError)
    }

    /// The host notification's order: FD_ACCEPT, accept (inherited selection
    /// and non-blocking mode), greeting, 77-byte reply after a wait, 77 + 3001
    /// back; partial receives; the peer closing gives FD_CLOSE and recv 0.
    func testHostAndClientExchangeOnLoopback() throws {
        let w = W(); _ = w.startup(0x101)
        var notes: [W.Notification] = []
        w.post = { notes.append($0) }
        let listener = w.socket(family: AF_INET, type: SOCK_STREAM, protocol: IPPROTO_TCP)
        XCTAssertNotEqual(listener, W.invalidSocket)
        XCTAssertEqual(w.bind(listener, address: 0, port: 0), 0); XCTAssertEqual(w.listen(listener, backlog: 1), 0)
        let port = try XCTUnwrap(w.boundPort(listener))
        XCTAssertEqual(w.asyncSelect(listener, window: 7, message: 0x401, events: 0x38), 0)
        let client = w.socket(family: AF_INET, type: SOCK_STREAM, protocol: IPPROTO_TCP)
        XCTAssertEqual(w.connect(client, address: 0x0100007f, port: port), 0)
        spin { !notes.isEmpty }
        XCTAssertEqual(notes, [.init(window: 7, message: 0x401, socket: listener, lParam: 8)])
        let server = w.accept(listener)
        XCTAssertNotEqual(server, W.invalidSocket)
        XCTAssertEqual(w.close(listener), 0)
        let greeting = Array("u can connect".utf8)+[0]
        XCTAssertEqual(w.send(server, greeting), 14)
        XCTAssertEqual(receive(w, client, 14), greeting)
        // The accepted socket is non-blocking: nothing has arrived yet.
        XCTAssertEqual(w.receive(server, capacity: 77).result, W.socketError); XCTAssertEqual(w.lastError, W.wouldBlock)
        let name = (0..<77).map { UInt8($0) }
        XCTAssertEqual(w.send(client, name), 77)
        var reply: [UInt8] = []
        spin { let (r, b) = w.receive(server, capacity: 77-reply.count); if r > 0 { reply += b }; return reply.count == 77 }
        XCTAssertEqual(reply, name)
        let table = (0..<3001).map { UInt8(truncatingIfNeeded: $0 &* 7) }
        XCTAssertEqual(w.send(server, table), 3001)
        XCTAssertEqual(receive(w, client, 3001), table)
        // A short packet: recv(22) returns what arrived.
        XCTAssertEqual(w.send(server, Array(repeating: 9, count: 10)), 10)
        spin(until: { false }, seconds: 0.1)
        XCTAssertEqual(w.receive(client, capacity: 22).bytes, Array(repeating: 9, count: 10))
        // The client closes: the accepted socket inherited 0x38, so FD_CLOSE.
        XCTAssertEqual(w.close(client), 0)
        spin { notes.count == 2 }
        XCTAssertEqual(notes.last, .init(window: 7, message: 0x401, socket: server, lParam: 32))
        XCTAssertEqual(w.receive(server, capacity: 22).result, 0)
        XCTAssertEqual(w.close(server), 0); XCTAssertTrue(w.openHandles.isEmpty)
    }

    /// The match's switch to blocking: FIONBIO 0 is refused while selected,
    /// accepted after WSAAsyncSelect(s, hwnd, 0, 0); a refused connect fails.
    func testCancelBlockingAndRefusedConnect() throws {
        let w = W(); _ = w.startup(0x101)
        let listener = w.socket(family: AF_INET, type: SOCK_STREAM, protocol: IPPROTO_TCP)
        XCTAssertEqual(w.bind(listener, address: 0x0100007f, port: 0), 0); XCTAssertEqual(w.listen(listener, backlog: 1), 0)
        let port = try XCTUnwrap(w.boundPort(listener))
        XCTAssertEqual(w.asyncSelect(listener, window: 7, message: 0x401, events: 0x38), 0)
        XCTAssertEqual(w.setNonBlocking(listener, false), W.socketError)
        XCTAssertEqual(w.asyncSelect(listener, window: 7, message: 0, events: 0), 0)
        XCTAssertEqual(w.setNonBlocking(listener, false), 0)
        XCTAssertEqual(w.close(listener), 0)
        let client = w.socket(family: AF_INET, type: SOCK_STREAM, protocol: IPPROTO_TCP)
        XCTAssertEqual(w.connect(client, address: 0x0100007f, port: port), W.socketError) // nothing listens now
        XCTAssertEqual(w.send(0x9999, [1]), W.socketError); XCTAssertEqual(w.lastError, 10038)
        XCTAssertEqual(w.cleanup(), 0); XCTAssertTrue(w.openHandles.isEmpty)
    }
}
