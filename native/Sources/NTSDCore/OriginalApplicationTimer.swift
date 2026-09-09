/// One original no-message timer decision, EXE43d157..43d1ef. The caller
/// supplies its established baseline and live platform/dispatcher operations.
/// Message handling, surface recovery and the dispatcher body remain outside
/// this operation. Each time request obtains a fresh UInt32 millisecond value.
public struct OriginalApplicationTimer {
    public private(set) var baseline: UInt32
    public init(baseline: UInt32) { self.baseline = baseline }

    /// Only the timer baseline commits here. An enclosing game operation must
    /// stage its own state and buffer external requests until its full commit.
    public mutating func iterate(speedFlag: Int32,time: () throws -> UInt32,
        target: () throws -> UInt32,dispatch: (UInt32) throws -> Int32,
        recoverSurface: () throws -> Void,sleep: (UInt32) throws -> Void) throws {
        var next = baseline
        let interval: UInt32 = speedFlag == 0 ? 3 : 33
        if try time() &- next > interval {
            if try time() &- next > 100 { next = try time() &- 100 }
            let surface = try target()
            next &+= interval
            if try dispatch(surface) < 0 { try recoverSurface() }
        }
        let remainder = try Int32(bitPattern:next &- time() &+ interval)
        if remainder > 0 { try sleep(UInt32(min(remainder,5))) }
        baseline = next
    }
}
