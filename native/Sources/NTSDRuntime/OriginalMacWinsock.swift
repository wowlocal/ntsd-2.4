// BSD sockets only: Windows hosts will use real Winsock (a separate adapter).
#if !os(Windows)
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
import Dispatch
import Foundation

/// The host's BSD socket calls (the class's own Winsock methods share their names).
private enum Sys {
    #if canImport(Darwin)
    static func socket(_ a: Int32,_ b: Int32,_ c: Int32) -> Int32 { Darwin.socket(a,b,c) }
    static func bind(_ fd: Int32,_ a: UnsafePointer<sockaddr>,_ n: socklen_t) -> Int32 { Darwin.bind(fd,a,n) }
    static func listen(_ fd: Int32,_ n: Int32) -> Int32 { Darwin.listen(fd,n) }
    static func accept(_ fd: Int32) -> Int32 { Darwin.accept(fd,nil,nil) }
    static func connect(_ fd: Int32,_ a: UnsafePointer<sockaddr>,_ n: socklen_t) -> Int32 { Darwin.connect(fd,a,n) }
    static func send(_ fd: Int32,_ p: UnsafeRawPointer?,_ n: Int) -> Int { Darwin.send(fd,p,n,0) }
    static func recv(_ fd: Int32,_ p: UnsafeMutableRawPointer?,_ n: Int,_ flags: Int32) -> Int { Darwin.recv(fd,p,n,flags) }
    static func close(_ fd: Int32) -> Int32 { Darwin.close(fd) }
    static func gethostname(_ p: UnsafeMutablePointer<CChar>,_ n: Int) -> Int32 { Darwin.gethostname(p,n) }
    static func gethostbyaddr(_ p: UnsafeRawPointer,_ n: socklen_t,_ t: Int32) -> UnsafeMutablePointer<hostent>? { Darwin.gethostbyaddr(p,n,t) }
    static var hostError: Int32 { h_errno }
    static let stream = SOCK_STREAM, tcp = IPPROTO_TCP, peekNow = MSG_PEEK | MSG_DONTWAIT
    static let up = IFF_UP, loopback = IFF_LOOPBACK
    /// Darwin's errno values are BSD's, which Winsock's WSAE codes follow.
    static func bsd(_ error: Int32) -> Int32 { error }
    #else
    #if canImport(Glibc)
    static func socket(_ a: Int32,_ b: Int32,_ c: Int32) -> Int32 { Glibc.socket(a,b,c) }
    static func bind(_ fd: Int32,_ a: UnsafePointer<sockaddr>,_ n: socklen_t) -> Int32 { Glibc.bind(fd,a,n) }
    static func listen(_ fd: Int32,_ n: Int32) -> Int32 { Glibc.listen(fd,n) }
    static func accept(_ fd: Int32) -> Int32 { Glibc.accept(fd,nil,nil) }
    static func connect(_ fd: Int32,_ a: UnsafePointer<sockaddr>,_ n: socklen_t) -> Int32 { Glibc.connect(fd,a,n) }
    // MSG_NOSIGNAL: send never raises SIGPIPE (Darwin uses SO_NOSIGPIPE).
    static func send(_ fd: Int32,_ p: UnsafeRawPointer?,_ n: Int) -> Int { Glibc.send(fd,p,n,Int32(MSG_NOSIGNAL)) }
    static func recv(_ fd: Int32,_ p: UnsafeMutableRawPointer?,_ n: Int,_ flags: Int32) -> Int { Glibc.recv(fd,p,n,flags) }
    static func close(_ fd: Int32) -> Int32 { Glibc.close(fd) }
    static func gethostname(_ p: UnsafeMutablePointer<CChar>,_ n: Int) -> Int32 { Glibc.gethostname(p,n) }
    static func gethostbyaddr(_ p: UnsafeRawPointer,_ n: socklen_t,_ t: Int32) -> UnsafeMutablePointer<hostent>? { Glibc.gethostbyaddr(p,n,t) }
    static let stream = Int32(SOCK_STREAM.rawValue), tcp = Int32(IPPROTO_TCP), peekNow = Int32(MSG_PEEK) | Int32(MSG_DONTWAIT)
    static let up = Int32(IFF_UP), loopback = Int32(IFF_LOOPBACK)
    #else
    static func socket(_ a: Int32,_ b: Int32,_ c: Int32) -> Int32 { Musl.socket(a,b,c) }
    static func bind(_ fd: Int32,_ a: UnsafePointer<sockaddr>,_ n: socklen_t) -> Int32 { Musl.bind(fd,a,n) }
    static func listen(_ fd: Int32,_ n: Int32) -> Int32 { Musl.listen(fd,n) }
    static func accept(_ fd: Int32) -> Int32 { Musl.accept(fd,nil,nil) }
    static func connect(_ fd: Int32,_ a: UnsafePointer<sockaddr>,_ n: socklen_t) -> Int32 { Musl.connect(fd,a,n) }
    static func send(_ fd: Int32,_ p: UnsafeRawPointer?,_ n: Int) -> Int { Musl.send(fd,p,n,MSG_NOSIGNAL) }
    static func recv(_ fd: Int32,_ p: UnsafeMutableRawPointer?,_ n: Int,_ flags: Int32) -> Int { Musl.recv(fd,p,n,flags) }
    static func close(_ fd: Int32) -> Int32 { Musl.close(fd) }
    static func gethostname(_ p: UnsafeMutablePointer<CChar>,_ n: Int) -> Int32 { Musl.gethostname(p,n) }
    static func gethostbyaddr(_ p: UnsafeRawPointer,_ n: socklen_t,_ t: Int32) -> UnsafeMutablePointer<hostent>? { Musl.gethostbyaddr(p,n,t) }
    static let stream = SOCK_STREAM, tcp = Int32(IPPROTO_TCP), peekNow = MSG_PEEK | MSG_DONTWAIT
    static let up = IFF_UP, loopback = IFF_LOOPBACK
    #endif
    static var hostError: Int32 { __h_errno_location().pointee }
    /// Linux errno values differ from BSD's; map the socket errors to the BSD
    /// numbers, so `10000 + errno` names the same WSAE code as on Darwin.
    static func bsd(_ error: Int32) -> Int32 {
        switch error {
        case EINTR: 4
        case EBADF: 9
        case EACCES: 13
        case EFAULT: 14
        case EINVAL: 22
        case EMFILE: 24
        case EPIPE: 32
        case EAGAIN: 35
        case EINPROGRESS: 36
        case EALREADY: 37
        case ENOTSOCK: 38
        case EDESTADDRREQ: 39
        case EMSGSIZE: 40
        case EPROTOTYPE: 41
        case ENOPROTOOPT: 42
        case EPROTONOSUPPORT: 43
        case ESOCKTNOSUPPORT: 44
        case EOPNOTSUPP: 45
        case EPFNOSUPPORT: 46
        case EAFNOSUPPORT: 47
        case EADDRINUSE: 48
        case EADDRNOTAVAIL: 49
        case ENETDOWN: 50
        case ENETUNREACH: 51
        case ENETRESET: 52
        case ECONNABORTED: 53
        case ECONNRESET: 54
        case ENOBUFS: 55
        case EISCONN: 56
        case ENOTCONN: 57
        case ESHUTDOWN: 58
        case ETOOMANYREFS: 59
        case ETIMEDOUT: 60
        case ECONNREFUSED: 61
        case ELOOP: 62
        case ENAMETOOLONG: 63
        case EHOSTDOWN: 64
        case EHOSTUNREACH: 65
        default: error
        }
    }
    #endif
}

/// Winsock 1.1 for the original's network code over BSD sockets (Darwin, and
/// Linux with glibc or musl; the name stays from its Mac origin)
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
///   behaviour); send never raises SIGPIPE (SO_NOSIGPIPE, MSG_NOSIGNAL on Linux).
/// The game calls this service on the main thread. Notifications are delivered
/// on the main queue through `post`; only readiness observation runs elsewhere.
public final class OriginalMacWinsock {
    public static let socketError: Int32 = -1
    public static let invalidSocket: UInt32 = 0xffff_ffff
    public static let wouldBlock: Int32 = 10035 // WSAEWOULDBLOCK
    private static let connectionReset: Int32 = 10054 // WSAECONNRESET
    public enum Event: UInt32 { case read = 1, write = 2, accept = 8, connect = 16, close = 32 }
    /// A window message the original's WndProc receives (wParam = socket,
    /// lParam = event | error << 16).
    public typealias Notification = OriginalRuntimeSocketNotification
    private struct Selection { let window: UInt32, message: UInt32, events: UInt32 }
    private final class Socket {
        let fd: Int32
        var nonBlocking = false, listening = false, closeReported = false
        /// Connected by connect or accept (readiness is watched only on
        /// listening or connected sockets on Linux; see `select`).
        var connected = false
        // A kernel error observed by either recv or the readiness probe must
        // remain visible to the other consumer until this socket is closed.
        var reset = false
        var selection: Selection?
        var observation: ReadObservation?
        init(_ fd: Int32) { self.fd = fd }
    }
    /// Keeps source cancellation independent of the game's main queue. The
    /// completion barrier lets close release the descriptor synchronously,
    /// after Dispatch has relinquished it, even inside a `post` callback.
    private final class ReadObservation {
        private static let queue = DispatchQueue(label: "NTSD.Winsock.readiness")
        private let source: DispatchSourceRead
        private let lock = NSLock()
        private let finished = DispatchGroup()
        private var suspended = false, cancelled = false

        init(_ fd: Int32, ready: @escaping (ReadObservation) -> Void) {
            source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: Self.queue)
            finished.enter()
            let completion = finished
            source.setCancelHandler { completion.leave() }
            source.setEventHandler { [weak self] in
                guard let self, self.pause() else { return }
                // One pending delivery per arm; unread data must not flood
                // the main queue while the game is sleeping or receiving.
                ready(self)
            }
            source.resume()
        }
        @discardableResult func pause() -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard !cancelled, !suspended else { return false }
            source.suspend(); suspended = true; return true
        }
        func rearm() {
            lock.lock(); defer { lock.unlock() }
            guard !cancelled, suspended else { return }
            suspended = false; source.resume()
        }
        func cancelAndWait() {
            lock.lock()
            if !cancelled {
                cancelled = true
                if suspended { suspended = false; source.resume() }
                source.cancel()
            }
            lock.unlock()
            finished.wait()
        }
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
        guard Sys.gethostname(&buffer, buffer.count) == 0 else { lastError = 10022; return (Self.socketError, []) }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        guard bytes.count < capacity else { lastError = 10014; return (Self.socketError, []) } // WSAEFAULT
        return (0, bytes + [0])
    }
    /// gethostbyname's IPv4 list as in-memory address words (127.0.0.1 is
    /// 0x0100007f); nil when the name does not resolve. For this machine's own
    /// name Windows lists its interface addresses (declared): the up,
    /// non-loopback IPv4 interfaces in system order, not a DNS answer that
    /// can be loopback on macOS.
    public func hostAddresses(_ name: [UInt8]) -> [UInt32]? {
        let own = hostName(capacity: 256)
        if own.result == 0, Array(own.name.dropLast()) == Array(name.prefix { $0 != 0 }), let local = Self.interfaceAddresses(), !local.isEmpty {
            return local
        }
        var hints = addrinfo(); hints.ai_family = AF_INET; hints.ai_socktype = Sys.stream
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
    /// gethostbyaddr(raw IPv4, 4, AF_INET), used by the client's name-lookup
    /// fallback. Copy the resolver's borrowed storage before the next lookup.
    public func hostAddresses(address: UInt32) -> [UInt32]? {
        guard started else { lastError = 10093; return nil } // WSANOTINITIALISED
        var raw = address
        let entry = withUnsafePointer(to: &raw) { Sys.gethostbyaddr($0, 4, AF_INET) }
        guard let entry else {
            switch Sys.hostError {
            case HOST_NOT_FOUND: lastError = 11001
            case TRY_AGAIN: lastError = 11002
            case NO_DATA: lastError = 11004
            default: lastError = 11003 // WSANO_RECOVERY
            }
            return nil
        }
        guard entry.pointee.h_addrtype == AF_INET, entry.pointee.h_length == 4,
              let addresses = entry.pointee.h_addr_list else { lastError = 11004; return nil }
        var words: [UInt32] = [], index = 0
        while let bytes = addresses[index] {
            words.append(UnsafeRawPointer(bytes).loadUnaligned(as: UInt32.self))
            index += 1
        }
        guard !words.isEmpty else { lastError = 11004; return nil }
        return words
    }
    /// The up, non-loopback IPv4 interface addresses (getifaddrs order).
    public static func interfaceAddresses() -> [UInt32]? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(first) }
        var words: [UInt32] = [], cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let node = cursor {
            let flags = Int32(node.pointee.ifa_flags)
            if let address = node.pointee.ifa_addr, address.pointee.sa_family == sa_family_t(AF_INET),
               flags & Sys.up != 0, flags & Sys.loopback == 0 {
                let word = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
                if !words.contains(word) { words.append(word) }
            }
            cursor = node.pointee.ifa_next
        }
        return words
    }
    /// inet_addr: dotted decimal to an address word, INADDR_NONE when invalid.
    public static func address(_ text: [UInt8]) -> UInt32 { OriginalRuntimeSocketText.address(text) }
    /// inet_ntoa of an address word.
    public static func text(_ word: UInt32) -> [UInt8] { OriginalRuntimeSocketText.text(word) }
    public static func htons(_ value: UInt16) -> UInt16 { OriginalRuntimeSocketText.htons(value) }

    // MARK: - Sockets

    public func socket(family: Int32, type: Int32, protocol proto: Int32) -> UInt32 {
        guard started else { lastError = 10093; return Self.invalidSocket }
        // Winsock's values (AF_INET 2, SOCK_STREAM 1, IPPROTO_TCP 6), as the EXE passes them.
        guard family == 2, type == 1, proto == 0 || proto == 6 else { lastError = 10047; return Self.invalidSocket }
        let fd = Sys.socket(AF_INET, Sys.stream, Sys.tcp)
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
            Sys.bind(s.fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        return r == 0 ? 0 : fail(Self.socketError)
    }
    public func listen(_ handle: UInt32, backlog: Int32) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        guard Sys.listen(s.fd, backlog) == 0 else { return fail(Self.socketError) }
        s.listening = true; watchDeferred(handle, s); return 0
    }
    /// accept; the new socket keeps the listener's mode and selection.
    public func accept(_ handle: UInt32) -> UInt32 {
        guard let s = lookup(handle) else { return Self.invalidSocket }
        let fd = Sys.accept(s.fd)
        let error = errno
        rearm(s)
        guard fd >= 0 else { return fail(Self.invalidSocket, error: error) }
        let accepted = adopt(fd), child = sockets[accepted]!
        child.connected = true
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
            Sys.connect(s.fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        let error = errno
        if r == 0 || error == EINPROGRESS { s.connected = true; watchDeferred(handle, s) }
        return r == 0 ? 0 : fail(Self.socketError, error: error)
    }
    public func send(_ handle: UInt32, _ bytes: [UInt8]) -> Int32 {
        guard let s = lookup(handle) else { return Self.socketError }
        if bytes.isEmpty { return 0 }
        let n = bytes.withUnsafeBytes { Sys.send(s.fd, $0.baseAddress, bytes.count) }
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
        let n = buffer.withUnsafeMutableBytes { Sys.recv(s.fd, $0.baseAddress, capacity, 0) }
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
        #if canImport(Darwin)
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        #endif
        let handle = nextHandle; nextHandle &+= 4
        sockets[handle] = Socket(fd); return handle
    }
    private func lookup(_ handle: UInt32) -> Socket? {
        guard started else { lastError = 10093; return nil }
        guard let s = sockets[handle] else { lastError = 10038; return nil } // WSAENOTSOCK
        return s
    }
    private func fail<T>(_ value: T, error: Int32 = errno) -> T {
        lastError = error == EWOULDBLOCK || error == EAGAIN || error == EINPROGRESS ? Self.wouldBlock : 10000 + Sys.bsd(error)
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
        #if !canImport(Darwin)
        // Linux epoll reports a socket that is neither listening nor connected
        // as hung up, and Dispatch then stops watching it: start once listen,
        // connect or accept has made the socket meaningful (`watchDeferred`).
        guard s.listening || s.connected else { return }
        #endif
        s.observation = ReadObservation(s.fd) { [weak self, weak s] observation in
            DispatchQueue.main.async { [weak self, weak s, weak observation] in
                guard let self, let s, let observation,
                      s.observation === observation, let selection = s.selection else { return }
                self.readable(handle, s, selection)
            }
        }
    }
    /// A selection made before listen or connect starts watching now (Linux).
    private func watchDeferred(_ handle: UInt32, _ s: Socket) {
        #if !canImport(Darwin)
        if let selection = s.selection, s.observation == nil { select(handle, s, selection) }
        #endif
    }
    private func readable(_ handle: UInt32, _ s: Socket, _ selection: Selection) {
        func deliver(_ event: Event) {
            pause(s)
            post?(.init(window: selection.window, message: selection.message, socket: handle, lParam: event.rawValue))
        }
        if s.listening {
            #if !canImport(Darwin)
            // Linux reports a socket selected before listen() as readable (an
            // unconnected TCP socket polls as hung up); FD_ACCEPT needs a
            // pending connection, which kqueue guarantees on Darwin.
            guard Self.pendingConnection(s.fd) else { rearm(s); return }
            #endif
            if selection.events & Event.accept.rawValue != 0 { deliver(.accept) } else { pause(s) }
            return
        }
        if s.reset { reportClose(handle, s, selection, error: Self.connectionReset); return }
        var byte: UInt8 = 0
        let n = Sys.recv(s.fd, &byte, 1, Sys.peekNow)
        if n == 0 {
            reportClose(handle, s, selection, error: 0)
        } else if n < 0 && errno == ECONNRESET {
            s.reset = true
            reportClose(handle, s, selection, error: Self.connectionReset)
        } else if n > 0 && selection.events & Event.read.rawValue != 0 { deliver(.read) }
        else if n > 0 { pause(s) } // data waits for recv; FD_CLOSE comes after it is read
        else { rearm(s) } // a preceding game recv may have consumed the ready data
    }
    private func reportClose(_ handle: UInt32, _ s: Socket, _ selection: Selection, error: Int32) {
        stopWatching(s)
        if selection.events & Event.close.rawValue != 0 && !s.closeReported {
            s.closeReported = true
            post?(.init(window: selection.window, message: selection.message, socket: handle,
                        lParam: Event.close.rawValue | (UInt32(bitPattern: error) << 16)))
        }
    }
    #if !canImport(Darwin)
    private static func pendingConnection(_ fd: Int32) -> Bool {
        var p = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        return poll(&p, 1, 0) > 0 && p.revents & Int16(POLLIN) != 0
    }
    #endif
    private func pause(_ s: Socket) { s.observation?.pause() }
    private func rearm(_ s: Socket) { s.observation?.rearm() }
    private func stopWatching(_ s: Socket) {
        guard let observation = s.observation else { return }
        s.observation = nil // invalidate already-enqueued main-queue deliveries
        observation.cancelAndWait()
    }
    private func release(_ s: Socket) { stopWatching(s); _ = Sys.close(s.fd) }
    private static func socketAddress(_ address: UInt32, _ port: UInt16) -> sockaddr_in {
        var a = sockaddr_in()
        #if canImport(Darwin)
        a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        a.sin_family = sa_family_t(AF_INET)
        a.sin_port = port.bigEndian; a.sin_addr.s_addr = address
        return a
    }
    private func put16(_ data: inout [UInt8], _ offset: Int, _ value: UInt16) {
        data[offset] = UInt8(value & 0xff); data[offset+1] = UInt8(value >> 8)
    }
}

extension OriginalMacWinsock: OriginalRuntimeSockets {}

#endif
