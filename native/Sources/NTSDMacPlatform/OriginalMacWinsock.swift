import Darwin
import Dispatch

/// Winsock 1.1 for the original's network code over BSD sockets
/// (NETWORK_PLAY_PLAN.md N1). The operations follow what the EXE calls through
/// its WSOCK32 stubs 43f38a..43f3fc; where Windows behaviour is not fixed by
/// the EXE the answers below are declared:
/// - SOCKET values are small handles starting at 0x100, step 4;
/// - sockets block until WSAAsyncSelect makes them non-blocking; cancelling
///   (message 0, events 0) keeps them non-blocking until FIONBIO 0;
/// - accept() returns a socket with the listener's selection and mode;
/// - FD_ACCEPT is posted once per readable listener and re-armed by accept;
///   FD_READ is re-armed by recv; FD_CLOSE is posted once when the peer closes;
/// - recv returns what has arrived (0 on an orderly close, −1 on error);
/// - bind may reuse a port in TIME_WAIT (SO_REUSEADDR, Windows' default
///   behaviour); send never raises SIGPIPE (SO_NOSIGPIPE).
/// Notifications are delivered on the main queue through `post`.
public final class OriginalMacWinsock {
    public static let socketError: Int32 = -1
    public static let invalidSocket: UInt32 = 0xffff_ffff
    public static let wouldBlock: Int32 = 10035 // WSAEWOULDBLOCK
    private static let connectionReset: Int32 = 10054 // WSAECONNRESET
    public enum Event: UInt32 { case read = 1, write = 2, accept = 8, connect = 16, close = 32 }
    /// A window message the original's WndProc receives (wParam = socket,
    /// lParam = event | error << 16).
    public struct Notification: Equatable {
        public let window: UInt32, message: UInt32, socket: UInt32, lParam: UInt32
    }
    private struct Selection { let window: UInt32, message: UInt32, events: UInt32 }
    private final class Socket {
        let fd: Int32
        var nonBlocking = false, listening = false, closeReported = false
        // A kernel error observed by either recv or the readiness probe must
        // remain visible to the other consumer until this socket is closed.
        var reset = false
        var selection: Selection?
        var source: DispatchSourceRead?, suspended = false
        init(_ fd: Int32) { self.fd = fd }
    }
    private var sockets: [UInt32: Socket] = [:]
    private var nextHandle: UInt32 = 0x100
    public private(set) var started = false
    /// The last error of a failed call (WSAGetLastError; the EXE does not import it).
    public private(set) var lastError: Int32 = 0
    /// Receives FD_* notifications on the main queue.
    public var post: ((Notification) -> Void)?
    public init() {}
    deinit { for socket in sockets.values { release(socket) } }

    // MARK: - Startup

    /// WSAStartup: a Winsock 2.2 stack answering a 1.1 request. Returns the
    /// result and the 400-byte WSADATA (wVersion, wHighVersion, description,
    /// status, iMaxSockets, iMaxUdpDg, lpVendorInfo).
    public func startup(_ requested: UInt16) -> (result: Int32, data: [UInt8]) {
        var data = [UInt8](repeating: 0, count: 400)
        let version: UInt16 = requested >= 0x0202 ? 0x0202 : requested
        put16(&data, 0, version); put16(&data, 2, 0x0202)
        for (i, byte) in Array("WinSock 2.0".utf8).enumerated() { data[4+i] = byte }
        for (i, byte) in Array("Running".utf8).enumerated() { data[4+257+i] = byte }
        started = true
        return (0, data)
    }
    public func cleanup() -> Int32 {
        guard started else { lastError = 10093; return Self.socketError } // WSANOTINITIALISED
        for (handle, socket) in sockets { release(socket); sockets[handle] = nil }
        started = false; return 0
    }

    // MARK: - Names and addresses

    /// gethostname into `capacity` bytes, NUL-terminated.
    public func hostName(capacity: Int) -> (result: Int32, name: [UInt8]) {
        var buffer = [CChar](repeating: 0, count: 256)
        guard Darwin.gethostname(&buffer, buffer.count) == 0 else { lastError = 10022; return (Self.socketError, []) }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        guard bytes.count < capacity else { lastError = 10014; return (Self.socketError, []) } // WSAEFAULT
        return (0, bytes + [0])
    }
    /// gethostbyname's IPv4 list as in-memory address words (127.0.0.1 is
    /// 0x0100007f); nil when the name does not resolve.
    public func hostAddresses(_ name: [UInt8]) -> [UInt32]? {
        var hints = addrinfo(); hints.ai_family = AF_INET; hints.ai_socktype = SOCK_STREAM
        var list: UnsafeMutablePointer<addrinfo>?
        let text = String(decoding: name.prefix { $0 != 0 }, as: UTF8.self)
        guard getaddrinfo(text, nil, &hints, &list) == 0, let first = list else { lastError = 11001; return nil } // WSAHOST_NOT_FOUND
        defer { freeaddrinfo(first) }
        var words: [UInt32] = [], cursor: UnsafeMutablePointer<addrinfo>? = first
        while let node = cursor {
            if let address = node.pointee.ai_addr, node.pointee.ai_family == AF_INET {
                let word = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
                if !words.contains(word) { words.append(word) }
            }
            cursor = node.pointee.ai_next
        }
        return words.isEmpty ? nil : words
    }
    /// inet_addr: dotted decimal to an address word, INADDR_NONE when invalid.
    public static func address(_ text: [UInt8]) -> UInt32 {
        let parts = String(decoding: text.prefix { $0 != 0 }, as: UTF8.self).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return 0xffff_ffff }
        var word: UInt32 = 0
        for (i, part) in parts.enumerated() {
            guard let value = UInt8(part) else { return 0xffff_ffff }
            word |= UInt32(value) << (8*UInt32(i))
        }
        return word
    }
    /// inet_ntoa of an address word.
    public static func text(_ word: UInt32) -> [UInt8] {
        Array((0..<4).map { String((word >> (8*UInt32($0))) & 0xff) }.joined(separator: ".").utf8)
    }
    public static func htons(_ value: UInt16) -> UInt16 { value.byteSwapped }

    // MARK: - Sockets

    public func socket(family: Int32, type: Int32, protocol proto: Int32) -> UInt32 {
        guard started else { lastError = 10093; return Self.invalidSocket }
        guard family == AF_INET, type == SOCK_STREAM, proto == 0 || proto == IPPROTO_TCP else { lastError = 10047; return Self.invalidSocket }
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return fail(Self.invalidSocket) }
        return adopt(fd)
    }
    /// bind to an address word and a port in host order.
    public func bind(_ handle: UInt32, address: UInt32, port: UInt16) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        var reuse: Int32 = 1
        setsockopt(s.fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var a = Self.socketAddress(address, port)
        let r = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.bind(s.fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        return r == 0 ? 0 : fail(Self.socketError)
    }
    public func listen(_ handle: UInt32, backlog: Int32) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        guard Darwin.listen(s.fd, backlog) == 0 else { return fail(Self.socketError) }
        s.listening = true; return 0
    }
    /// accept; the new socket keeps the listener's mode and selection.
    public func accept(_ handle: UInt32) -> UInt32 {
        guard let s = lookup(handle) else { return Self.invalidSocket }
        let fd = Darwin.accept(s.fd, nil, nil)
        rearm(s)
        guard fd >= 0 else { return fail(Self.invalidSocket) }
        let accepted = adopt(fd), child = sockets[accepted]!
        if s.nonBlocking { _ = setNonBlocking(child, true) }
        if let selection = s.selection { select(accepted, child, selection) }
        return accepted
    }
    /// connect to an address word and a port in host order (blocking unless
    /// the socket is non-blocking, then −1 with WSAEWOULDBLOCK).
    public func connect(_ handle: UInt32, address: UInt32, port: UInt16) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        var a = Self.socketAddress(address, port)
        let r = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.connect(s.fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        return r == 0 ? 0 : fail(Self.socketError)
    }
    public func send(_ handle: UInt32, _ bytes: [UInt8]) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        if bytes.isEmpty { return 0 }
        let n = bytes.withUnsafeBytes { Darwin.send(s.fd, $0.baseAddress, bytes.count, 0) }
        return n >= 0 ? Int32(n) : fail(Self.socketError)
    }
    /// sendto on a stream socket: Windows ignores the address of a connected
    /// socket, so this is send.
    public func sendTo(_ handle: UInt32, _ bytes: [UInt8]) -> Int32 { send(handle, bytes) }
    /// recv up to `capacity` bytes: what has arrived, 0 at an orderly close.
    public func receive(_ handle: UInt32, capacity: Int) -> (result: Int32, bytes: [UInt8]) {
        guard let s = lookup(handle) else { return (Self.socketError, []) }
        guard capacity > 0 else { return (0, []) }
        if s.reset { lastError = Self.connectionReset; return (Self.socketError, []) }
        var buffer = [UInt8](repeating: 0, count: capacity)
        let n = buffer.withUnsafeMutableBytes { Darwin.recv(s.fd, $0.baseAddress, capacity, 0) }
        let error = errno
        if n < 0 && error == ECONNRESET { s.reset = true }
        rearm(s)
        guard n >= 0 else { return (fail(Self.socketError, error: error), []) }
        return (Int32(n), Array(buffer.prefix(n)))
    }
    public func close(_ handle: UInt32) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        release(s); sockets[handle] = nil; return 0
    }
    /// ioctlsocket(FIONBIO).
    public func setNonBlocking(_ handle: UInt32, _ on: Bool) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        if !on && s.selection != nil { lastError = 10022; return Self.socketError } // WSAEINVAL while selected
        return setNonBlocking(s, on)
    }
    /// WSAAsyncSelect; message 0 with events 0 cancels.
    public func asyncSelect(_ handle: UInt32, window: UInt32, message: UInt32, events: UInt32) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        stopWatching(s); s.selection = nil
        _ = setNonBlocking(s, true)
        if events != 0 { select(handle, s, .init(window: window, message: message, events: events)) }
        return 0
    }
    public var openHandles: [UInt32] { sockets.keys.sorted() }
    /// The bound local port in host order (getsockname; for checks, not a call the EXE makes).
    public func boundPort(_ handle: UInt32) -> UInt16? {
        guard let s = lookup(handle) else { return nil }
        var a = sockaddr_in(), length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let r = withUnsafeMutablePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(s.fd, $0, &length) } }
        return r == 0 ? UInt16(bigEndian: a.sin_port) : nil
    }

    // MARK: - Internals

    private func adopt(_ fd: Int32) -> UInt32 {
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        let handle = nextHandle; nextHandle &+= 4
        sockets[handle] = Socket(fd); return handle
    }
    private func lookup(_ handle: UInt32) -> Socket? {
        guard started else { lastError = 10093; return nil }
        guard let s = sockets[handle] else { lastError = 10038; return nil } // WSAENOTSOCK
        return s
    }
    private func fail<T>(_ value: T, error: Int32 = errno) -> T {
        lastError = error == EWOULDBLOCK || error == EAGAIN || error == EINPROGRESS ? Self.wouldBlock : 10000 + error
        return value
    }
    private func setNonBlocking(_ s: Socket, _ on: Bool) -> Int32 {
        let flags = fcntl(s.fd, F_GETFL)
        guard flags >= 0, fcntl(s.fd, F_SETFL, on ? flags | O_NONBLOCK : flags & ~O_NONBLOCK) == 0 else { return fail(Self.socketError) }
        s.nonBlocking = on; return 0
    }
    private func select(_ handle: UInt32, _ s: Socket, _ selection: Selection) {
        s.selection = selection
        let watched = Event.accept.rawValue | Event.read.rawValue | Event.close.rawValue
        guard selection.events & watched != 0 else { return }
        let source = DispatchSource.makeReadSource(fileDescriptor: s.fd, queue: .main)
        source.setEventHandler { [weak self, weak s] in
            guard let self, let s, let selection = s.selection else { return }
            self.readable(handle, s, selection)
        }
        s.source = source; source.resume()
    }
    private func readable(_ handle: UInt32, _ s: Socket, _ selection: Selection) {
        func deliver(_ event: Event) {
            pause(s)
            post?(.init(window: selection.window, message: selection.message, socket: handle, lParam: event.rawValue))
        }
        if s.listening {
            if selection.events & Event.accept.rawValue != 0 { deliver(.accept) } else { pause(s) }
            return
        }
        if s.reset { reportClose(handle, s, selection, error: Self.connectionReset); return }
        var byte: UInt8 = 0
        let n = Darwin.recv(s.fd, &byte, 1, MSG_PEEK | MSG_DONTWAIT)
        if n == 0 {
            reportClose(handle, s, selection, error: 0)
        } else if n < 0 && errno == ECONNRESET {
            s.reset = true
            reportClose(handle, s, selection, error: Self.connectionReset)
        } else if n > 0 && selection.events & Event.read.rawValue != 0 { deliver(.read) }
        else if n > 0 { pause(s) } // data waits for recv; FD_CLOSE comes after it is read
    }
    private func reportClose(_ handle: UInt32, _ s: Socket, _ selection: Selection, error: Int32) {
        stopWatching(s)
        if selection.events & Event.close.rawValue != 0 && !s.closeReported {
            s.closeReported = true
            post?(.init(window: selection.window, message: selection.message, socket: handle,
                        lParam: Event.close.rawValue | (UInt32(bitPattern: error) << 16)))
        }
    }
    private func pause(_ s: Socket) { if let source = s.source, !s.suspended { source.suspend(); s.suspended = true } }
    private func rearm(_ s: Socket) { if let source = s.source, s.suspended { s.suspended = false; source.resume() } }
    private func stopWatching(_ s: Socket) {
        guard let source = s.source else { return }
        if s.suspended { s.suspended = false; source.resume() }
        source.cancel(); s.source = nil
    }
    private func release(_ s: Socket) { stopWatching(s); Darwin.close(s.fd) }
    private static func socketAddress(_ address: UInt32, _ port: UInt16) -> sockaddr_in {
        var a = sockaddr_in()
        a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); a.sin_family = sa_family_t(AF_INET)
        a.sin_port = port.bigEndian; a.sin_addr.s_addr = address
        return a
    }
    private func put16(_ data: inout [UInt8], _ offset: Int, _ value: UInt16) {
        data[offset] = UInt8(value & 0xff); data[offset+1] = UInt8(value >> 8)
    }
}
