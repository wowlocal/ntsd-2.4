import Foundation

/// Frees values the caller has finished with on a thread of its own
/// (CORE_REALTIME R3): the end of a loaded cycle frees a whole copied State
/// (the continuation's, the body's return, the drained batches), element by
/// element, ~5% of the main thread. The game never observes when Swift frees
/// a value. The retired values are Core data (records, arrays, the sessions'
/// storage) whose deinits free memory; on a committed step the platform's
/// append-only receipt histories keep every resource they name alive, so
/// nothing with an external effect is freed here. After a failed step a
/// retired driver may hold the last reference to a new window lease or
/// display storage; their deinits already run on any thread (the budget's
/// lock, the lease's hand-off to the main thread). A retired value shares
/// buffers with live state only through atomic reference counts, so a write
/// that finds one still held here copies it, as while any other copy lives.
public final class OriginalDeferredRelease: @unchecked Sendable {
    public static let shared = OriginalDeferredRelease()
    /// Runs first on the release thread (the Android host pins it to the
    /// slowest cores, away from the main thread). Set before the first retire.
    nonisolated(unsafe) public static var threadStart: (() -> Void)?
    /// Values beyond this many waiting are freed by their caller instead: a
    /// starved release thread must not hold memory without bound.
    static let backlogLimit = 256
    /// The release thread wakes on its own this often instead of being
    /// signalled for every value: a signal to a sleeping thread is a kernel
    /// call on the caller's thread (~0.6% of the A12's main thread, R3b). It
    /// is still signalled once half the backlog is waiting.
    static let interval: TimeInterval = 0.016
    private let condition = NSCondition()
    private var pending: [Any] = []
    private var started = false,count = 0
    private let begin: (() -> Void)?
    /// `threadStart` overrides the static one for this instance (tests).
    init(threadStart: (() -> Void)? = nil) { begin = threadStart }
    /// Values handed to the release thread so far.
    var retired: Int { condition.lock(); defer { condition.unlock() }; return count }
    /// Takes `value` (pass it with `consume`, so this holds its last
    /// reference); the release thread frees it. Never `consume` a variable
    /// declared outside a `defer` from inside it: the compiler still released
    /// that array at the scope's end, a double release (seen in a debug build,
    /// R3). A binding made inside the `defer` is fine.
    public func retire(_ value: consuming Any) {
        condition.lock()
        guard pending.count < Self.backlogLimit else { condition.unlock(); return }
        pending.append(value); count += 1
        if !started { started = true; start() }
        if pending.count == Self.backlogLimit/2 { condition.signal() }
        condition.unlock()
    }
    private func start() {
        let begin = self.begin ?? Self.threadStart
        // Named inside the thread as well: on Android a thread otherwise keeps
        // the name of the one that made it (the main thread's).
        let thread = Thread { [self] in Thread.current.name = "NTSD.release"; begin?(); run() }
        thread.name = "NTSD.release"; thread.qualityOfService = .utility; thread.start()
    }
    private func run() {
        var taken: [Any] = []
        while true {
            condition.lock()
            while pending.isEmpty { _ = condition.wait(until:Date(timeIntervalSinceNow:Self.interval)) }
            swap(&taken,&pending)
            condition.unlock()
            taken.removeAll(keepingCapacity:true)
        }
    }
}
