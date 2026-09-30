import Foundation
import NTSDCore

/// Runtime answers for WinMain requests that the window/display/audio services
/// do not own. Every value comes from the Mac environment or a declared runtime
/// policy (see docs/research/APPLICATION_RUNTIME_STARTUP_PLAN.md); no corpus
/// reply or expected state is used. Physical file effects are staged and applied
/// only after the startup commits.
@MainActor public final class OriginalMacRuntimeStartupService {
    public typealias Exchange = OriginalStartupRequestExchange
    public enum Boundary: Error, Equatable {
        case unsupported(String), arguments(String), unknownCursor(UInt32), panelNotOpen
    }
    /// Injected host environment; the app uses the live clocks and zone.
    public struct Environment {
        public var monotonic: () throws -> OriginalMacStartupClock.Sample
        public var realtime: () throws -> OriginalMacStartupClock.Sample
        public var zone: () -> TimeZone
        /// Joysticks 0..<n are connected at startup (APPLICATION_JOYSTICKS_PLAN.md).
        public var joysticks: Int
        public init(monotonic: @escaping () throws -> OriginalMacStartupClock.Sample = OriginalMacStartupClock.monotonicSample,
                    realtime: @escaping () throws -> OriginalMacStartupClock.Sample = OriginalMacStartupClock.realtimeSample,
                    zone: @escaping () -> TimeZone = { TimeZone.current },joysticks: Int = 0) {
            self.monotonic = monotonic; self.realtime = realtime; self.zone = zone; self.joysticks = joysticks
        }
    }
    /// A file replacement staged by a served request, applied after commit.
    public struct FileEffect: Equatable { public let path: String, bytes: [UInt8] }
    public struct Served: Equatable { public let request: String }
    /// WinMM joystick policy: standard driver present; IDs below the declared
    /// count are connected game controllers, the others unplugged.
    public static let joystickDevices: UInt32 = 16, joystickUnplugged: UInt32 = 167
    /// Declared joystick axis range (JOYCAPS wXmin..wXmax, wYmin..wYmax) and centre.
    public static let joystickRange: ClosedRange<UInt32> = 0...65535, joystickCentre: UInt32 = 32767
    private static func little(_ value: UInt32) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0*8)) } }
    public let heap: OriginalMacRuntimeHeap, music: OriginalMacRuntimeMusic
    private let windows: OriginalMacWindowBackend, environment: Environment
    private var panelBytes: [UInt8]?
    public private(set) var staged: [FileEffect] = []
    /// Caller bytes of each `_write`, before text-mode translation.
    public private(set) var panelWrites: [[UInt8]] = []
    public private(set) var served: [Served] = []
    /// OutputDebugStringA text; with no debugger attached Windows shows nothing.
    public private(set) var debugOutput: [[UInt8]] = []
    public init(windows: OriginalMacWindowBackend,heap: OriginalMacRuntimeHeap,environment: Environment = .init()) {
        self.windows = windows; self.heap = heap; self.environment = environment
        music = OriginalMacRuntimeMusic(identities:windows.identities,heap:heap)
    }
    public nonisolated static func handles(_ request: OriginalStartupRequest) -> Bool {
        switch request {
        case .window(let q): return q.kind == "debug"
        case .sound,.waveAudio,.wave: return false
        default: return true
        }
    }
    private func require(_ valid: Bool,_ what: String) throws { if !valid { throw Boundary.arguments(what) } }
    /// Critical-section contents are OS-private; recovered code only emits
    /// enter/leave events for 4554a4 and never reads these bytes.
    public static let criticalSection: [UInt8] = [0,0,0,0,0xff,0xff,0xff,0xff]+[UInt8](repeating:0,count:16)

    func answer(_ request: OriginalStartupRequest) throws -> OriginalStartupResponse {
        switch request {
        case .milliseconds: return .milliseconds(try OriginalMacStartupClock.milliseconds(environment.monotonic()))
        case .filetime: return .filetime(try OriginalMacStartupClock.filetime(environment.realtime()))
        case .initializeCriticalSection(let address):
            try require(address == 0x4554a4,"critical section"); return .initializeCriticalSection(Self.criticalSection)
        case .initializeCOM: return .initializeCOM(0)
        case .timezone:
            let now = Date(timeIntervalSince1970:TimeInterval(try environment.realtime().seconds))
            return .timezone(try OriginalMacRuntimeZone.information(environment.zone(),now:now))
        case .zoneName(let name,let capacity): return .zoneName(try OriginalMacRuntimeZone.convert(name,capacity:capacity))
        case .allocateCalendar(let count): return .allocateCalendar(try heap.allocate(count))
        case .panelWrite(let bytes):
            // Text-mode CRT _write of the "w" stream: each LF becomes CR LF in
            // the file; the result still counts the caller's bytes.
            panelWrites.append(bytes)
            panelBytes = (panelBytes ?? [])+bytes.flatMap { $0 == 10 ? [13,10] : [$0] }
            return .panelWrite(Int32(bytes.count))
        case .panelClose:
            staged.append(.init(path:"data\\adinfo.txt",bytes:panelBytes ?? [])); panelBytes = nil
            return .panelClose(0)
        case .allocatePanel,.panelBitmap,.panelDevice:
            // Only reached when data\ad<N>.txt exists; the shipped data lacks it.
            throw Boundary.unsupported("panel bitmap route")
        case .music(let event): return .music(try music.answer(event))
        case .cursor(let load,let arguments):
            if load {
                try require(arguments == [0,0x7f00],"LoadCursorA")
                let served = try windows.perform(windows.prepare(.init("cursor",[0,0x7f00])))
                return .cursor(UInt32(bitPattern:served.response.result))
            }
            try require(arguments.count == 1,"SetCursor")
            guard let arrow = windows.arrowCursorToken,arguments[0] == arrow else { throw Boundary.unknownCursor(arguments.first ?? 0) }
            // The class cursor is the same shared arrow; recovered code does not store it.
            return .cursor(arrow)
        case .joystick(let q):
            switch q.kind {
            case "numberDevices": try require(q.arguments.isEmpty,"joyGetNumDevs"); return .joystick(.init(result:Self.joystickDevices))
            case "position":
                try require(q.arguments.count == 1 && q.arguments[0] < 2,"joyGetPosEx")
                guard Int(q.arguments[0]) < environment.joysticks else { return .joystick(.init(result:Self.joystickUnplugged)) }
                // JOY_RETURNX|Y|BUTTONS: a centred stick, no button pressed.
                return .joystick(.init(result:0,writes:[.init(offset:8,bytes:Self.little(Self.joystickCentre)),.init(offset:12,bytes:Self.little(Self.joystickCentre)),
                    .init(offset:32,bytes:Self.little(0)),.init(offset:36,bytes:Self.little(0))]))
            case "threshold":
                try require(q.arguments.count == 2 && Int(q.arguments[0]) < environment.joysticks,"joySetThreshold"); return .joystick(.init(result:0))
            case "capture":
                try require(q.arguments.count == 4 && Int(q.arguments[1]) < environment.joysticks,"joySetCapture"); return .joystick(.init(result:0))
            case "capabilities":
                try require(q.arguments.count == 2 && q.arguments[1] == 404 && Int(q.arguments[0]) < environment.joysticks,"joyGetDevCapsA")
                // JOYCAPSA: zero apart from the X/Y ranges (+36..+48) and four buttons (+60).
                var caps = [UInt8](repeating:0,count:404)
                for (offset,value) in [(36,Self.joystickRange.lowerBound),(40,Self.joystickRange.upperBound),(44,Self.joystickRange.lowerBound),(48,Self.joystickRange.upperBound),(60,UInt32(4))] {
                    caps.replaceSubrange(offset..<offset+4,with:Self.little(value))
                }
                return .joystick(.init(result:0,writes:[.init(offset:0,bytes:caps)]))
            default: throw Boundary.unsupported("joystick \(q.kind)")
            }
        case .window(let q) where q.kind == "debug":
            try require(q.words.isEmpty && q.strings.count == 1 && q.bytes == nil,"OutputDebugStringA")
            debugOutput.append(q.strings[0]); return .window(.init(result:0))
        case .window,.sound,.waveAudio,.wave: throw Boundary.unsupported("\(request)")
        }
    }
    public func serve<P>(_ permit: Exchange.Permit,on driver: OriginalApplicationObservedStartup<P>) throws {
        guard Self.handles(permit.request) else { throw Boundary.unsupported("\(permit.request)") }
        try driver.beginService(permit)
        do {
            let response = try answer(permit.request)
            served.append(.init(request:Self.kind(permit.request)))
            try driver.answer(permit,response:response,retaining:windows.retainedResources)
        } catch {
            try driver.fail(permit,diagnostic:String(reflecting:error),retaining:windows.retainedResources); throw error
        }
    }
    public nonisolated static func kind(_ request: OriginalStartupRequest) -> String {
        switch request {
        case .milliseconds: return "milliseconds"
        case .initializeCriticalSection: return "criticalSection"
        case .initializeCOM: return "com"
        case .window(let q): return "window:"+q.kind
        case .panelWrite: return "panelWrite"
        case .panelClose: return "panelClose"
        case .allocatePanel: return "allocatePanel"
        case .panelBitmap: return "panelBitmap"
        case .panelDevice: return "panelDevice"
        case .filetime: return "filetime"
        case .timezone: return "timezone"
        case .allocateCalendar: return "allocateCalendar"
        case .zoneName: return "zoneName"
        case .music(let e): return "music:"+e.kind.rawValue
        case .cursor(let load,_): return load ? "loadCursor" : "setCursor"
        case .joystick(let q): return "joystick:"+q.kind
        case .wave: return "wave"
        case .sound(let e): return "sound:"+e.kind
        case .waveAudio: return "waveAudio"
        }
    }
}

/// mmio results for a well-formed PCM WAV, computed from its own bytes: one
/// stream, three successful descends, an 18-byte WAVEFORMATEX read, the data
/// chunk read and a successful close. Other layouts are an explicit boundary.
public enum OriginalMacRuntimeWave {
    public enum Boundary: Error, Equatable { case malformed(String) }
    public static func input(_ path: String,_ bytes: [UInt8]) throws -> OriginalWaveFileInput {
        func u16(_ i: Int) -> Int { Int(bytes[i])+256*Int(bytes[i+1]) }
        func u32(_ i: Int) -> Int { u16(i)+65536*u16(i+2) }
        guard bytes.count >= 36,Array(bytes[0..<4]) == Array("RIFF".utf8),Array(bytes[8..<12]) == Array("WAVE".utf8),
              Array(bytes[12..<16]) == Array("fmt ".utf8),u16(20) == 1 else { throw Boundary.malformed(path) }
        let limit = u32(4)+8; guard limit <= bytes.count else { throw Boundary.malformed(path) }
        var offset = 12
        for _ in 0..<256 {
            guard offset+8 <= limit else { break }
            let count = u32(offset+4),start = offset+8; guard start+count <= limit else { break }
            if Array(bytes[offset..<(offset+4)]) == Array("data".utf8) {
                return OriginalWaveFileInput(.init(destination:0,device:0,stream:1,descendResults:[0,0,0],
                    formatReadResult:18,ascendResult:0,dataReadResult:Int32(count),closeResult:0,
                    storage:.init(first:.init(bytes:[],defined:[]),second:nil,ramp:false)))
            }
            offset = start+count+(count%2)
        }
        throw Boundary.malformed(path)
    }
}
