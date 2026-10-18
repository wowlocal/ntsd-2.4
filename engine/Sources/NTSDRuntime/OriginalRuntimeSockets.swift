import Foundation

/// A window message the original's WndProc receives for a selected socket
/// (wParam = socket, lParam = event | error << 16).
public struct OriginalRuntimeSocketNotification: Equatable {
    public let window: UInt32, message: UInt32, socket: UInt32, lParam: UInt32
    public init(window: UInt32, message: UInt32, socket: UInt32, lParam: UInt32) {
        self.window = window; self.message = message; self.socket = socket; self.lParam = lParam
    }
}

/// Winsock's pure conversions, the same on every host.
public enum OriginalRuntimeSocketText {
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
}

/// The Winsock calls the original's network code makes, answered by a host's
/// sockets (docs/research/CROSS_PLATFORM_RUNTIME.md). FD_* readiness arrives
/// through `post` as window messages.
public protocol OriginalRuntimeSockets: AnyObject {
    var post: ((OriginalRuntimeSocketNotification) -> Void)? { get set }
    var started: Bool { get }
    var openHandles: [UInt32] { get }
    /// WSAGetLastError: the last failing call's Winsock error code.
    var lastError: Int32 { get }
    /// The local port a socket is bound to, if any (getsockname).
    func boundPort(_ handle: UInt32) -> UInt16?
    func startup(_ requested: UInt16) -> (result: Int32, data: [UInt8])
    func cleanup() -> Int32
    func hostName(capacity: Int) -> (result: Int32, name: [UInt8])
    func hostAddresses(_ name: [UInt8]) -> [UInt32]?
    func hostAddresses(address: UInt32) -> [UInt32]?
    func socket(family: Int32, type: Int32, protocol proto: Int32) -> UInt32
    func bind(_ handle: UInt32, address: UInt32, port: UInt16) -> Int32
    func listen(_ handle: UInt32, backlog: Int32) -> Int32
    func accept(_ handle: UInt32) -> UInt32
    func connect(_ handle: UInt32, address: UInt32, port: UInt16) -> Int32
    func send(_ handle: UInt32, _ bytes: [UInt8]) -> Int32
    func sendTo(_ handle: UInt32, _ bytes: [UInt8]) -> Int32
    func receive(_ handle: UInt32, capacity: Int) -> (result: Int32, bytes: [UInt8])
    func close(_ handle: UInt32) -> Int32
    func setNonBlocking(_ handle: UInt32, _ on: Bool) -> Int32
    func asyncSelect(_ handle: UInt32, window: UInt32, message: UInt32, events: UInt32) -> Int32
}
