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

    /// A TCP reset must remain an error when the service's readiness probe
    /// observes it before recv, and must still notify if recv observes it first.
    func testAbortivePeerClosePreservesReceiveErrorAndNotification() throws {
        for notificationFirst in [true, false] {
            let w = W(); _ = w.startup(0x101)
            defer { _ = w.cleanup() }
            let listener = w.socket(family: AF_INET, type: SOCK_STREAM, protocol: IPPROTO_TCP)
            XCTAssertEqual(w.bind(listener, address: 0x0100007f, port: 0), 0)
            XCTAssertEqual(w.listen(listener, backlog: 1), 0)
            let port = try XCTUnwrap(w.boundPort(listener))

            // A task-owned loopback peer uses SO_LINGER to request an abortive
            // close. This is a real macOS socket check, not Windows observation.
            let peer = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
            XCTAssertGreaterThanOrEqual(peer, 0)
            guard peer >= 0 else { return }
            var peerClosed = false
            defer { if !peerClosed { Darwin.close(peer) } }
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = port.bigEndian; address.sin_addr.s_addr = 0x0100007f
            let connected = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(peer, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            XCTAssertEqual(connected, 0)
            guard connected == 0 else { return }
            let server = w.accept(listener)
            XCTAssertNotEqual(server, W.invalidSocket)
            XCTAssertEqual(w.close(listener), 0)
            var notes: [W.Notification] = []
            w.post = { notes.append($0) }
            XCTAssertEqual(w.asyncSelect(server, window: 7, message: 0x401, events: 0x20), 0)
            var abortive = linger(l_onoff: 1, l_linger: 0)
            XCTAssertEqual(setsockopt(peer, SOL_SOCKET, SO_LINGER, &abortive,
                                      socklen_t(MemoryLayout<linger>.size)), 0)
            XCTAssertEqual(Darwin.close(peer), 0); peerClosed = true

            if notificationFirst {
                spin { !notes.isEmpty }
                XCTAssertFalse(notes.isEmpty, "Reset notification must not require a preceding game recv")
            }
            // Do not pump the main queue here: this also exercises recv before
            // the dispatch source has had a chance to consume the kernel error.
            let deadline = Date().addingTimeInterval(5)
            var received: (result: Int32, bytes: [UInt8]) = (W.socketError, [])
            repeat {
                received = w.receive(server, capacity: 22)
                if received.result != W.socketError || w.lastError != W.wouldBlock { break }
                Thread.sleep(forTimeInterval: 0.001)
            } while Date() < deadline
            XCTAssertEqual(received.result, W.socketError)
            XCTAssertEqual(received.bytes, [])
            XCTAssertEqual(w.lastError, 10054) // WSAECONNRESET
            spin { !notes.isEmpty }
            XCTAssertEqual(notes, [.init(window: 7, message: 0x401, socket: server,
                                         lParam: (10054 << 16) | 32)])
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
            XCTAssertEqual(notes.count, 1)
        }
    }

    func testCloseInsideAcceptNotificationAllowsImmediatePortReuse() throws {
        let w = W(); _ = w.startup(0x101)
        defer { w.post = nil; _ = w.cleanup() }
        let listener = w.socket(family: AF_INET, type: SOCK_STREAM, protocol: IPPROTO_TCP)
        XCTAssertEqual(w.bind(listener, address: 0x0100007f, port: 0), 0)
        XCTAssertEqual(w.listen(listener, backlog: 1), 0)
        let port = try XCTUnwrap(w.boundPort(listener))
        var accepted: UInt32?, replacement: UInt32?
        w.post = { note in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(note.socket, listener); XCTAssertEqual(note.lParam, 8)
            accepted = w.accept(listener)
            XCTAssertNotEqual(accepted, W.invalidSocket)
            XCTAssertEqual(w.close(listener), 0)
            // No main-queue turn occurs between close and this bind/listen.
            let next = w.socket(family: AF_INET, type: SOCK_STREAM, protocol: IPPROTO_TCP)
            XCTAssertEqual(w.bind(next, address: 0x0100007f, port: port), 0)
            XCTAssertEqual(w.listen(next, backlog: 1), 0)
            replacement = next
        }
        XCTAssertEqual(w.asyncSelect(listener, window: 7, message: 0x401, events: 8), 0)
        let client = w.socket(family: AF_INET, type: SOCK_STREAM, protocol: IPPROTO_TCP)
        XCTAssertEqual(w.connect(client, address: 0x0100007f, port: port), 0)
        spin { replacement != nil }
        XCTAssertNotNil(replacement)
        let server = try XCTUnwrap(accepted)
        XCTAssertEqual(w.send(client, [17, 21]), 2)
        var packet: [UInt8] = []
        spin { let r = w.receive(server, capacity: 2-packet.count); packet += r.bytes; return packet.count == 2 }
        XCTAssertEqual(packet, [17, 21])
        w.post = nil // Break the test callback's ownership of the service.
    }

    func testReplacingSelectionAndRearmingAfterAlreadyReadData() throws {
        let w = W(); _ = w.startup(0x101)
        defer { _ = w.cleanup() }
        let listener = w.socket(family: AF_INET, type: SOCK_STREAM, protocol: IPPROTO_TCP)
        XCTAssertEqual(w.bind(listener, address: 0x0100007f, port: 0), 0)
        XCTAssertEqual(w.listen(listener, backlog: 1), 0)
        let port = try XCTUnwrap(w.boundPort(listener))
        let client = w.socket(family: AF_INET, type: SOCK_STREAM, protocol: IPPROTO_TCP)
        XCTAssertEqual(w.connect(client, address: 0x0100007f, port: port), 0)
        let server = w.accept(listener)
        XCTAssertNotEqual(server, W.invalidSocket)
        XCTAssertEqual(w.close(listener), 0)
        var notes: [W.Notification] = []
        w.post = { XCTAssertTrue(Thread.isMainThread); notes.append($0) }
        XCTAssertEqual(w.asyncSelect(server, window: 7, message: 0x401, events: 1), 0)
        XCTAssertEqual(w.send(client, [1, 2]), 2)
        // Let readiness run without delivering a game notification yet.
        Thread.sleep(forTimeInterval: 0.03)
        XCTAssertTrue(notes.isEmpty)
        XCTAssertEqual(w.asyncSelect(server, window: 9, message: 0x402, events: 1), 0)
        let expected = W.Notification(window: 9, message: 0x402, socket: server, lParam: 1)
        spin { !notes.isEmpty }; XCTAssertEqual(notes, [expected])
        XCTAssertEqual(w.receive(server, capacity: 1).bytes, [1])
        spin { notes.count >= 2 }; XCTAssertEqual(notes, [expected, expected])
        XCTAssertEqual(w.receive(server, capacity: 1).bytes, [2])

        // Consume data before the main queue handles its readiness. The stale
        // observation must rearm rather than leave subsequent data unwatched.
        XCTAssertEqual(w.send(client, [3]), 1)
        Thread.sleep(forTimeInterval: 0.03)
        XCTAssertEqual(w.receive(server, capacity: 1).bytes, [3])
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        XCTAssertEqual(notes, [expected, expected])
        XCTAssertEqual(w.send(client, [4]), 1)
        spin { notes.count >= 3 }; XCTAssertEqual(notes, [expected, expected, expected])
        XCTAssertEqual(w.receive(server, capacity: 1).bytes, [4])
    }

    func testCancelCloseAndCleanupReusePortWithoutPumpingMainQueue() throws {
        let w = W(); _ = w.startup(0x101)
        defer { _ = w.cleanup() }
        var notes: [W.Notification] = []
        w.post = { notes.append($0) }
        var port: UInt16 = 0
        for i in 0..<32 {
            let listener = w.socket(family: AF_INET, type: SOCK_STREAM, protocol: IPPROTO_TCP)
            XCTAssertEqual(w.bind(listener, address: 0x0100007f, port: port), 0)
            XCTAssertEqual(w.listen(listener, backlog: 1), 0)
            port = try XCTUnwrap(w.boundPort(listener))
            XCTAssertEqual(w.asyncSelect(listener, window: 7, message: 0x401, events: 8), 0)
            if i % 3 == 0 {
                XCTAssertEqual(w.asyncSelect(listener, window: 7, message: 0, events: 0), 0)
                XCTAssertEqual(w.setNonBlocking(listener, false), 0)
                XCTAssertEqual(w.close(listener), 0)
            } else if i % 3 == 1 {
                XCTAssertEqual(w.close(listener), 0)
            } else {
                XCTAssertEqual(w.cleanup(), 0); XCTAssertEqual(w.startup(0x101).result, 0)
            }
            XCTAssertTrue(w.openHandles.isEmpty)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        XCTAssertTrue(notes.isEmpty)
    }
}
