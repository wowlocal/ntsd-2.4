/// One original no-message timer decision, EXE43d157..43d1ef. The caller
/// supplies its established baseline and live platform/dispatcher operations.
/// Message handling, surface recovery and the dispatcher body remain outside
/// this operation. Each time request obtains a fresh UInt32 millisecond value.
public struct OriginalApplicationTimer {
    public private(set) var baseline: UInt32
    public init(baseline: UInt32) { self.baseline = baseline }

    /// Owned state at the dispatcher call, or at the tail when no call is due.
    /// The clock samples and target used by the prefix are never reacquired.
    struct Prepared {
        let baseline: UInt32, interval: UInt32, target: UInt32?
    }
    func prepare(speedFlag: Int32,time: () throws -> UInt32,
                 target: () throws -> UInt32) throws -> Prepared {
        var next = baseline
        let interval: UInt32 = speedFlag == 0 ? 3 : 33
        var surface: UInt32?
        if try time() &- next > interval {
            if try time() &- next > 100 { next = try time() &- 100 }
            surface = try target()
            next &+= interval
        }
        return .init(baseline:next,interval:interval,target:surface)
    }
    mutating func finish(_ prepared: Prepared,dispatchResult: Int32?,
        time: () throws -> UInt32,recoverSurface: () throws -> Void,
        sleep: (UInt32) throws -> Void) throws {
        guard (prepared.target == nil) == (dispatchResult == nil) else {
            throw OriginalStateError.invalidStorage("Timer dispatch continuation result")
        }
        if let dispatchResult,dispatchResult < 0 { try recoverSurface() }
        let remainder = try Int32(bitPattern:prepared.baseline &- time() &+ prepared.interval)
        if remainder > 0 { try sleep(UInt32(min(remainder,5))) }
        baseline = prepared.baseline
    }

    /// Only the timer baseline commits here. An enclosing game operation must
    /// stage its own state and buffer external requests until its full commit.
    public mutating func iterate(speedFlag: Int32,time: () throws -> UInt32,
        target: () throws -> UInt32,dispatch: (UInt32) throws -> Int32,
        recoverSurface: () throws -> Void,sleep: (UInt32) throws -> Void) throws {
        let prepared = try prepare(speedFlag:speedFlag,time:time,target:target)
        let result = try prepared.target.map(dispatch)
        try finish(prepared,dispatchResult:result,time:time,recoverSurface:recoverSurface,sleep:sleep)
    }
}
