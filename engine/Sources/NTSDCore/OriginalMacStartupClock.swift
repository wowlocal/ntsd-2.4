#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#elseif canImport(WASILibc)
import WASILibc
#elseif os(Windows)
import WinSDK
#endif

/// Host IO boundary. Call only while servicing a returned startup permit, never
/// from a Core transaction or its observers. macOS clock origin/resolution is not
/// claimed to equal measured Windows WinMM behavior.
public enum OriginalMacStartupClock {
    public enum Boundary: Error, Equatable {
        case systemCall(Int32), invalidNanoseconds, negativeMonotonic, filetimeRange, unsupportedRequest
    }
    public struct Sample: Equatable {
        public let seconds: Int64, nanoseconds: Int64
        public init(seconds: Int64, nanoseconds: Int64) {
            self.seconds = seconds; self.nanoseconds = nanoseconds
        }
    }
    #if os(Windows)
    /// Windows hosts: QueryPerformanceCounter and GetSystemTimePreciseAsFileTime
    /// as the declared monotonic and wall clocks (not WinMM's timeGetTime).
    public static func monotonicSample() throws -> Sample {
        var frequency = LARGE_INTEGER(),counter = LARGE_INTEGER()
        guard QueryPerformanceFrequency(&frequency) != false,QueryPerformanceCounter(&counter) != false,frequency.QuadPart > 0
        else { throw Boundary.systemCall(Int32(bitPattern:GetLastError())) }
        let f = frequency.QuadPart,c = counter.QuadPart
        return .init(seconds:c/f,nanoseconds:(c%f)*1_000_000_000/f)
    }
    public static func realtimeSample() throws -> Sample {
        var value = FILETIME(); GetSystemTimePreciseAsFileTime(&value)
        // 100 ns ticks since 1601 to seconds and nanoseconds since 1970.
        let ticks = Int64(bitPattern:UInt64(value.dwHighDateTime) << 32 | UInt64(value.dwLowDateTime))-116_444_736_000_000_000
        let seconds = ticks >= 0 ? ticks/10_000_000 : (ticks-9_999_999)/10_000_000
        return .init(seconds:seconds,nanoseconds:(ticks-seconds*10_000_000)*100)
    }
    #elseif os(WASI)
    /// WASI hosts (TVOS_WEB W0): wasi-libc's clock ids are the addresses of
    /// opaque structs that Swift cannot name, so the clocks are read through
    /// WASI's `clock_time_get` with preview 1's ids (0 realtime, 1 monotonic),
    /// in nanoseconds. WASI has no raw monotonic clock: its monotonic clock
    /// is the host's.
    private static func read(_ clock: __wasi_clockid_t) throws -> Sample {
        var time: __wasi_timestamp_t = 0
        let status = __wasi_clock_time_get(clock,1,&time)
        guard status == 0 else { throw Boundary.systemCall(Int32(status)) }
        return .init(seconds:Int64(time/1_000_000_000),nanoseconds:Int64(time%1_000_000_000))
    }
    public static func monotonicSample() throws -> Sample { try read(1) }
    public static func realtimeSample() throws -> Sample { try read(0) }
    #else
    private static func read(_ clock: clockid_t) throws -> Sample {
        var value = timespec()
        guard clock_gettime(clock,&value) == 0 else { throw Boundary.systemCall(errno) }
        return .init(seconds:Int64(value.tv_sec),nanoseconds:Int64(value.tv_nsec))
    }
    public static func monotonicSample() throws -> Sample { try read(CLOCK_MONOTONIC_RAW) }
    public static func realtimeSample() throws -> Sample { try read(CLOCK_REALTIME) }
    #endif
    private static func validate(_ sample: Sample) throws {
        guard sample.nanoseconds >= 0 && sample.nanoseconds < 1_000_000_000 else { throw Boundary.invalidNanoseconds }
    }
    public static func milliseconds(_ sample: Sample) throws -> UInt32 {
        try validate(sample)
        guard sample.seconds >= 0 else { throw Boundary.negativeMonotonic }
        // Wrapping UInt64 first preserves the required low32 even for huge samples.
        return UInt32(truncatingIfNeeded: UInt64(sample.seconds) &* 1000 &+ UInt64(sample.nanoseconds)/1_000_000)
    }
    public static func filetime(_ sample: Sample) throws -> UInt64 {
        try validate(sample)
        let (shifted,overflow) = sample.seconds.addingReportingOverflow(11_644_473_600)
        guard !overflow && shifted >= 0 else { throw Boundary.filetimeRange }
        let (whole,productOverflow) = UInt64(shifted).multipliedReportingOverflow(by:10_000_000)
        let (result,sumOverflow) = whole.addingReportingOverflow(UInt64(sample.nanoseconds)/100)
        guard !productOverflow && !sumOverflow else { throw Boundary.filetimeRange }
        return result
    }
    public static func answer(_ request: OriginalStartupRequest) throws -> OriginalStartupResponse {
        switch request {
        case .milliseconds: return .milliseconds(try milliseconds(monotonicSample()))
        case .filetime: return .filetime(try filetime(realtimeSample()))
        default: throw Boundary.unsupportedRequest
        }
    }
}
