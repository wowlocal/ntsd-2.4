#if os(Windows)
import Dispatch
import Foundation
import WinSDK

/// Winsock 1.1 for the original's network code on Windows hosts, over the
/// real Winsock 2 stack, with the declared contract of the BSD adapter
/// (`OriginalMacWinsock`, NETWORK_PLAY_PLAN.md N1) so game state does not
/// depend on the host: handles from 0x100 step 4, the same WSADATA bytes,
/// sockets blocking until WSAAsyncSelect, FD_ACCEPT/FD_READ re-armed by
/// accept/recv, FD_CLOSE once. The runtime has no real window for
/// WSAAsyncSelect, so a watcher thread polls armed sockets (WSAPoll) and the
/// main queue receives the notifications through `post`. Error codes are the
/// stack's own WSAGetLastError values.
public final class OriginalWindowsWinsock: OriginalRuntimeSockets {
    public static let socketError: Int32 = -1
    public static let invalidSocket: UInt32 = 0xffff_ffff
    public static let wouldBlock: Int32 = 10035 // WSAEWOULDBLOCK
    private static let connectionReset: Int32 = 10054 // WSAECONNRESET
    private static let fionbio = Int32(bitPattern: 0x8004_667E) // _IOW('f', 126, u_long)
    public enum Event: UInt32 { case read = 1, write = 2, accept = 8, connect = 16, close = 32 }
    public typealias Notification = OriginalRuntimeSocketNotification
    private struct Selection { let window: UInt32, message: UInt32, events: UInt32 }
    private final class Socket {
        let fd: SOCKET
        var nonBlocking = false, listening = false, closeReported = false, reset = false
        var selection: Selection?
        /// Watched by the poller; a delivery disarms until accept/recv re-arms.
        var watched = false, armed = false
        init(_ fd: SOCKET) { self.fd = fd }
    }
    private var sockets: [UInt32: Socket] = [:]
    private var nextHandle: UInt32 = 0x100
    public private(set) var started = false
    public private(set) var lastError: Int32 = 0
    public var post: ((Notification) -> Void)?
    private let lock = NSLock()
    private var poller: Thread?, polling = false
    private var stackStarted = false

    public init() {}
    deinit {
        lock.lock(); polling = false; lock.unlock()
        for socket in sockets.values { closesocket(socket.fd) }
        if stackStarted { WSACleanup() }
    }

    // MARK: - Startup

    /// WSAStartup: the same declared 400-byte WSADATA as the BSD adapter; the
    /// real stack is started underneath.
    public func startup(_ requested: UInt16) -> (result: Int32, data: [UInt8]) {
        if !stackStarted {
            var data = WSADATA()
            guard WSAStartup(0x0202, &data) == 0 else { lastError = WSAGetLastError(); return (lastError, []) }
            stackStarted = true
        }
        var data = [UInt8](repeating: 0, count: 400)
        let version: UInt16 = requested >= 0x0202 ? 0x0202 : requested
        data[0] = UInt8(version & 0xff); data[1] = UInt8(version >> 8); data[2] = 0x02; data[3] = 0x02
        for (i, byte) in Array("WinSock 2.0".utf8).enumerated() { data[4+i] = byte }
        for (i, byte) in Array("Running".utf8).enumerated() { data[4+257+i] = byte }
        started = true
        return (0, data)
    }
    public func cleanup() -> Int32 {
        guard started else { lastError = 10093; return Self.socketError }
        lock.lock(); let all = sockets; sockets = [:]; lock.unlock()
        for socket in all.values { closesocket(socket.fd) }
        started = false; return 0
    }

    // MARK: - Names and addresses

    public func hostName(capacity: Int) -> (result: Int32, name: [UInt8]) {
        var buffer = [CChar](repeating: 0, count: 256)
        guard gethostname(&buffer, Int32(buffer.count)) == 0 else { lastError = WSAGetLastError(); return (Self.socketError, []) }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        guard bytes.count < capacity else { lastError = 10014; return (Self.socketError, []) }
        return (0, bytes + [0])
    }
    /// gethostbyname's IPv4 list; for this machine's own name, the up,
    /// non-loopback IPv4 adapter addresses (as the BSD adapter declares).
    public func hostAddresses(_ name: [UInt8]) -> [UInt32]? {
        let own = hostName(capacity: 256)
        if own.result == 0, Array(own.name.dropLast()) == Array(name.prefix { $0 != 0 }), let local = Self.interfaceAddresses(), !local.isEmpty {
            return local
        }
        var hints = ADDRINFOA(); hints.ai_family = AF_INET; hints.ai_socktype = SOCK_STREAM
        var list: UnsafeMutablePointer<ADDRINFOA>?
        let text = String(decoding: name.prefix { $0 != 0 }, as: UTF8.self)
        guard getaddrinfo(text, nil, &hints, &list) == 0, let first = list else { lastError = 11001; return nil }
        defer { freeaddrinfo(first) }
        var words: [UInt32] = [], cursor: UnsafeMutablePointer<ADDRINFOA>? = first
        while let node = cursor {
            if let address = node.pointee.ai_addr, node.pointee.ai_family == AF_INET {
                let word = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.S_un.S_addr }
                if !words.contains(word) { words.append(word) }
            }
            cursor = node.pointee.ai_next
        }
        return words.isEmpty ? nil : words
    }
    public func hostAddresses(address: UInt32) -> [UInt32]? {
        guard started else { lastError = 10093; return nil }
        var raw = address
        let entry = withUnsafePointer(to: &raw) { $0.withMemoryRebound(to: CChar.self, capacity: 4) { gethostbyaddr($0, 4, AF_INET) } }
        guard let entry else { lastError = WSAGetLastError(); return nil }
        guard entry.pointee.h_addrtype == AF_INET, entry.pointee.h_length == 4, let addresses = entry.pointee.h_addr_list else {
            lastError = 11004; return nil
        }
        var words: [UInt32] = [], index = 0
        while let bytes = addresses[index] {
            words.append(UnsafeRawPointer(bytes).loadUnaligned(as: UInt32.self)); index += 1
        }
        guard !words.isEmpty else { lastError = 11004; return nil }
        return words
    }
    /// The up, non-loopback IPv4 adapter addresses (GetAdaptersAddresses order).
    public static func interfaceAddresses() -> [UInt32]? {
        var size: ULONG = 16 * 1024
        var buffer = [UInt8](repeating: 0, count: Int(size))
        let flags = ULONG(GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER)
        var result = buffer.withUnsafeMutableBytes { GetAdaptersAddresses(ULONG(AF_INET), flags, nil, $0.baseAddress?.assumingMemoryBound(to: IP_ADAPTER_ADDRESSES.self), &size) }
        if result == ULONG(ERROR_BUFFER_OVERFLOW) {
            buffer = [UInt8](repeating: 0, count: Int(size))
            result = buffer.withUnsafeMutableBytes { GetAdaptersAddresses(ULONG(AF_INET), flags, nil, $0.baseAddress?.assumingMemoryBound(to: IP_ADAPTER_ADDRESSES.self), &size) }
        }
        guard result == ULONG(ERROR_SUCCESS) else { return nil }
        var words: [UInt32] = []
        buffer.withUnsafeMutableBytes { raw in
            var adapter = raw.baseAddress?.assumingMemoryBound(to: IP_ADAPTER_ADDRESSES.self)
            while let a = adapter {
                if a.pointee.OperStatus == IfOperStatusUp, a.pointee.IfType != IF_TYPE_SOFTWARE_LOOPBACK {
                    var unicast = a.pointee.FirstUnicastAddress
                    while let u = unicast {
                        if let sa = u.pointee.Address.lpSockaddr, sa.pointee.sa_family == ADDRESS_FAMILY(AF_INET) {
                            let word = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.S_un.S_addr }
                            if !words.contains(word) { words.append(word) }
                        }
                        unicast = u.pointee.Next
                    }
                }
                adapter = a.pointee.Next
            }
        }
        return words
    }

    // MARK: - Sockets

    public func socket(family: Int32, type: Int32, protocol proto: Int32) -> UInt32 {
        guard started else { lastError = 10093; return Self.invalidSocket }
        guard family == 2, type == 1, proto == 0 || proto == 6 else { lastError = 10047; return Self.invalidSocket }
        let fd = WinSDK.socket(AF_INET, SOCK_STREAM, Int32(IPPROTO_TCP.rawValue))
        guard fd != INVALID_SOCKET else { lastError = WSAGetLastError(); return Self.invalidSocket }
        return adopt(fd)
    }
    public func bind(_ handle: UInt32, address: UInt32, port: UInt16) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        // Windows' bind reuses a port in TIME_WAIT by default; no SO_REUSEADDR
        // (on Windows it would allow stealing an active listener's port).
        var a = Self.socketAddress(address, port)
        let r = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            WinSDK.bind(s.fd, $0, Int32(MemoryLayout<sockaddr_in>.size)) } }
        return r == 0 ? 0 : fail(Self.socketError)
    }
    public func listen(_ handle: UInt32, backlog: Int32) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        guard WinSDK.listen(s.fd, backlog) == 0 else { return fail(Self.socketError) }
        s.listening = true; return 0
    }
    public func accept(_ handle: UInt32) -> UInt32 {
        guard let s = lookup(handle) else { return Self.invalidSocket }
        let fd = WinSDK.accept(s.fd, nil, nil)
        let error = WSAGetLastError()
        rearm(s)
        guard fd != INVALID_SOCKET else { lastError = error == WSAEWOULDBLOCK ? Self.wouldBlock : error; return Self.invalidSocket }
        let accepted = adopt(fd), child = sockets[accepted]!
        if s.nonBlocking { _ = setNonBlocking(child, true) }
        if let selection = s.selection { select(accepted, child, selection) }
        return accepted
    }
    public func connect(_ handle: UInt32, address: UInt32, port: UInt16) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        var a = Self.socketAddress(address, port)
        let r = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            WinSDK.connect(s.fd, $0, Int32(MemoryLayout<sockaddr_in>.size)) } }
        return r == 0 ? 0 : fail(Self.socketError)
    }
    public func send(_ handle: UInt32, _ bytes: [UInt8]) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        if bytes.isEmpty { return 0 }
        let n = bytes.withUnsafeBytes { WinSDK.send(s.fd, $0.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(bytes.count), 0) }
        return n >= 0 ? n : fail(Self.socketError)
    }
    public func sendTo(_ handle: UInt32, _ bytes: [UInt8]) -> Int32 { send(handle, bytes) }
    public func receive(_ handle: UInt32, capacity: Int) -> (result: Int32, bytes: [UInt8]) {
        guard let s = lookup(handle) else { return (Self.socketError, []) }
        guard capacity > 0 else { return (0, []) }
        if s.reset { lastError = Self.connectionReset; return (Self.socketError, []) }
        var buffer = [UInt8](repeating: 0, count: capacity)
        let n = buffer.withUnsafeMutableBytes { recv(s.fd, $0.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(capacity), 0) }
        let error = WSAGetLastError()
        if n < 0 && error == WSAECONNRESET { s.reset = true }
        rearm(s)
        guard n >= 0 else { lastError = error == WSAEWOULDBLOCK ? Self.wouldBlock : error; return (Self.socketError, []) }
        return (n, Array(buffer.prefix(Int(n))))
    }
    public func close(_ handle: UInt32) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        lock.lock(); sockets[handle] = nil; s.watched = false; s.armed = false; lock.unlock()
        closesocket(s.fd); return 0
    }
    public func setNonBlocking(_ handle: UInt32, _ on: Bool) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        if !on && s.selection != nil { lastError = 10022; return Self.socketError }
        return setNonBlocking(s, on)
    }
    public func asyncSelect(_ handle: UInt32, window: UInt32, message: UInt32, events: UInt32) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        lock.lock(); s.watched = false; s.armed = false; s.selection = nil; lock.unlock()
        _ = setNonBlocking(s, true)
        if events != 0 { select(handle, s, .init(window: window, message: message, events: events)) }
        return 0
    }
    public var openHandles: [UInt32] { lock.lock(); defer { lock.unlock() }; return sockets.keys.sorted() }
    public func boundPort(_ handle: UInt32) -> UInt16? {
        guard let s = lookup(handle) else { return nil }
        var a = sockaddr_in(), length = Int32(MemoryLayout<sockaddr_in>.size)
        let r = withUnsafeMutablePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(s.fd, $0, &length) } }
        return r == 0 ? UInt16(bigEndian: a.sin_port) : nil
    }

    // MARK: - Internals

    private func adopt(_ fd: SOCKET) -> UInt32 {
        let handle = nextHandle; nextHandle &+= 4
        lock.lock(); sockets[handle] = Socket(fd); lock.unlock()
        return handle
    }
    private func lookup(_ handle: UInt32) -> Socket? {
        guard started else { lastError = 10093; return nil }
        lock.lock(); let s = sockets[handle]; lock.unlock()
        guard let s else { lastError = 10038; return nil }
        return s
    }
    private func fail<T>(_ value: T) -> T {
        let error = WSAGetLastError()
        lastError = error == WSAEWOULDBLOCK || error == WSAEINPROGRESS ? Self.wouldBlock : error
        return value
    }
    private func setNonBlocking(_ s: Socket, _ on: Bool) -> Int32 {
        var mode: u_long = on ? 1 : 0
        guard ioctlsocket(s.fd, Self.fionbio, &mode) == 0 else { return fail(Self.socketError) }
        s.nonBlocking = on; return 0
    }
    /// Watches readable sockets (accept, read, close) like the BSD adapter's
    /// Dispatch sources: one delivery per arm.
    private func select(_ handle: UInt32, _ s: Socket, _ selection: Selection) {
        s.selection = selection
        let watched = Event.accept.rawValue | Event.read.rawValue | Event.close.rawValue
        guard selection.events & watched != 0 else { return }
        lock.lock(); s.watched = true; s.armed = true; let start = poller == nil; if start { polling = true }; lock.unlock()
        if start {
            let thread = Thread { [weak self] in self?.poll() }
            thread.name = "NTSD.Winsock.readiness"; poller = thread; thread.start()
        }
    }
    private func poll() {
        while true {
            lock.lock()
            guard polling else { lock.unlock(); return }
            let armed = sockets.filter { $0.value.watched && $0.value.armed }
            lock.unlock()
            guard !armed.isEmpty else { Thread.sleep(forTimeInterval: 0.002); continue }
            var fds = armed.map { WSAPOLLFD(fd: $0.value.fd, events: Int16(POLLRDNORM), revents: 0) }
            let ready = WSAPoll(&fds, ULONG(fds.count), 10)
            guard ready > 0 else { if ready < 0 { Thread.sleep(forTimeInterval: 0.002) }; continue }
            for (i, (handle, s)) in armed.enumerated() where fds[i].revents != 0 {
                lock.lock()
                let current = sockets[handle] === s && s.armed && s.watched
                if current { s.armed = false }
                lock.unlock()
                guard current else { continue }
                DispatchQueue.main.async { [weak self] in
                    guard let self, let selection = s.selection else { return }
                    self.lock.lock(); let live = self.sockets[handle] === s && s.watched; self.lock.unlock()
                    if live { self.readable(handle, s, selection) }
                }
            }
        }
    }
    private func readable(_ handle: UInt32, _ s: Socket, _ selection: Selection) {
        func deliver(_ event: Event) {
            post?(.init(window: selection.window, message: selection.message, socket: handle, lParam: event.rawValue))
        }
        if s.listening {
            if selection.events & Event.accept.rawValue != 0 { deliver(.accept) }
            return
        }
        if s.reset { reportClose(handle, s, selection, error: Self.connectionReset); return }
        var byte: CChar = 0
        let n = recv(s.fd, &byte, 1, Int32(MSG_PEEK))
        let error = WSAGetLastError()
        if n == 0 {
            reportClose(handle, s, selection, error: 0)
        } else if n < 0 && error == WSAECONNRESET {
            s.reset = true
            reportClose(handle, s, selection, error: Self.connectionReset)
        } else if n > 0 && selection.events & Event.read.rawValue != 0 { deliver(.read) }
        else if n > 0 { } // data waits for recv; FD_CLOSE comes after it is read
        else { rearm(s) } // a preceding game recv may have consumed the ready data
    }
    private func reportClose(_ handle: UInt32, _ s: Socket, _ selection: Selection, error: Int32) {
        lock.lock(); s.watched = false; s.armed = false; lock.unlock()
        if selection.events & Event.close.rawValue != 0 && !s.closeReported {
            s.closeReported = true
            post?(.init(window: selection.window, message: selection.message, socket: handle,
                        lParam: Event.close.rawValue | (UInt32(bitPattern: error) << 16)))
        }
    }
    private func rearm(_ s: Socket) { lock.lock(); if s.watched { s.armed = true }; lock.unlock() }
    private static func socketAddress(_ address: UInt32, _ port: UInt16) -> sockaddr_in {
        var a = sockaddr_in()
        a.sin_family = ADDRESS_FAMILY(AF_INET); a.sin_port = port.bigEndian; a.sin_addr.S_un.S_addr = address
        return a
    }
}
#endif
