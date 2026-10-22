import Foundation
#if canImport(Dispatch)
import Dispatch
#endif
import RandoriCore

/// The main thread's deferred calls (TVOS_WEB W0). Where Dispatch exists
/// they go to the main dispatch queue exactly as the runtime called it
/// before. A host without threads (WASI) has no main queue: its calls wait
/// here, and the host's main loop calls `run()`, which serves them in
/// deadline order, calls with equal deadlines in the order they were made,
/// as a serial queue serves them.
public enum OriginalMainQueue {
    /// Runs `body` on the main thread after `milliseconds`.
    public static func after(milliseconds: Int,_ body: @escaping @MainActor () -> Void) {
        #if os(WASI)
        Timers.add(delay:Double(milliseconds)/1000,body)
        #else
        DispatchQueue.main.asyncAfter(deadline:.now() + .milliseconds(milliseconds)) { MainActor.assumeIsolated { body() } }
        #endif
    }
    /// Runs `body` on the main thread after `seconds`.
    public static func after(seconds: TimeInterval,_ body: @escaping @MainActor () -> Void) {
        #if os(WASI)
        Timers.add(delay:seconds,body)
        #else
        DispatchQueue.main.asyncAfter(deadline:.now()+seconds) { MainActor.assumeIsolated { body() } }
        #endif
    }
    #if os(WASI)
    /// Serves the waiting calls until none is left: the host's main loop.
    @MainActor public static func run() {
        while let next = Timers.takeNext() {
            let wait = next.deadline-Timers.now()
            if wait > 0 { Thread.sleep(forTimeInterval:wait) }
            next.body()
        }
    }
    private enum Timers {
        struct Call { let deadline: Double, order: Int, body: @MainActor () -> Void }
        nonisolated(unsafe) static var calls: [Call] = []
        nonisolated(unsafe) static var made = 0
        static func now() -> Double {
            guard let sample = try? OriginalMacStartupClock.monotonicSample() else { return 0 }
            return Double(sample.seconds)+Double(sample.nanoseconds)/1e9
        }
        static func add(delay: Double,_ body: @escaping @MainActor () -> Void) {
            made &+= 1; calls.append(.init(deadline:now()+max(0,delay),order:made,body:body))
        }
        static func takeNext() -> Call? {
            guard let i = calls.indices.min(by:{ (calls[$0].deadline,calls[$0].order) < (calls[$1].deadline,calls[$1].order) }) else { return nil }
            return calls.remove(at:i)
        }
    }
    #endif
}

#if os(WASI)
/// Sockets on a host without them (WASI, TVOS_WEB W0): the session creates
/// sockets only without `--no-network`; every call fails as a network that is
/// down (WSAStartup: WSASYSNOTREADY; the others: SOCKET_ERROR or
/// INVALID_SOCKET with WSAENETDOWN).
public final class OriginalUnavailableSockets: OriginalRuntimeSockets {
    public var post: ((OriginalRuntimeSocketNotification) -> Void)?
    public init() {}
    public var started: Bool { false }
    public var openHandles: [UInt32] { [] }
    public var lastError: Int32 { 10050 }
    public func boundPort(_ handle: UInt32) -> UInt16? { nil }
    public func startup(_ requested: UInt16) -> (result: Int32, data: [UInt8]) { (10091,[]) }
    public func cleanup() -> Int32 { -1 }
    public func hostName(capacity: Int) -> (result: Int32, name: [UInt8]) { (-1,[]) }
    public func hostAddresses(_ name: [UInt8]) -> [UInt32]? { nil }
    public func hostAddresses(address: UInt32) -> [UInt32]? { nil }
    public func socket(family: Int32, type: Int32, protocol proto: Int32) -> UInt32 { UInt32.max }
    public func bind(_ handle: UInt32, address: UInt32, port: UInt16) -> Int32 { -1 }
    public func listen(_ handle: UInt32, backlog: Int32) -> Int32 { -1 }
    public func accept(_ handle: UInt32) -> UInt32 { UInt32.max }
    public func connect(_ handle: UInt32, address: UInt32, port: UInt16) -> Int32 { -1 }
    public func send(_ handle: UInt32, _ bytes: [UInt8]) -> Int32 { -1 }
    public func sendTo(_ handle: UInt32, _ bytes: [UInt8]) -> Int32 { -1 }
    public func receive(_ handle: UInt32, capacity: Int) -> (result: Int32, bytes: [UInt8]) { (-1,[]) }
    public func close(_ handle: UInt32) -> Int32 { -1 }
    public func setNonBlocking(_ handle: UInt32, _ on: Bool) -> Int32 { -1 }
    public func asyncSelect(_ handle: UInt32, window: UInt32, message: UInt32, events: UInt32) -> Int32 { -1 }
}
#endif
