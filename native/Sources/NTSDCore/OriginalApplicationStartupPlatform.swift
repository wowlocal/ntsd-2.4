/// A transactional adapter for the declared WinMain platform boundaries.
/// All mutable reply positions, allocator identities, file positions and queued
/// operations must belong to the staged copy. Immutable resource bytes may be
/// shared. Neither copy may perform host IO while the Core transaction runs.
/// A different object identity alone does not establish this value-state contract.
public protocol OriginalApplicationStartupPlatform: OriginalWinMainStartupPlatform {
    func stagedCopy() throws -> Self
}

/// Requests at the already recovered startup boundaries. Resource/file inputs
/// remain declared inputs; this is not a Windows implementation or an AppKit
/// command buffer. Sound helper summaries are excluded from terminal operations.
public enum OriginalApplicationStartupOperation: Codable {
    public enum Domain { case input,ownedMemory,platform }
    case milliseconds(UInt32)
    case criticalSection(UInt32,[UInt8])
    case initializeCOM(UInt32)
    case window(OriginalWindowInitialization.Request,OriginalWindowInitialization.Response)
    case file(String,[UInt8]?)
    case panelWrite([UInt8],Int32)
    case panelClose(Int32)
    case panelAllocation(UInt32,[UInt8])
    case panelResource(String,OriginalBitmapInput)
    case panelDevice(UInt32,Int32)
    case filetime(UInt64)
    case timezone(UInt32,OriginalCalendarTime.Zone?)
    case calendarAllocation(Int,UInt32,[UInt8])
    case zoneName(String,Int,[UInt8])
    case music(OriginalMusicEvent,OriginalMusicResponse)
    case cursor(Bool,[UInt32],UInt32)
    case joystick(OriginalInputStartup.Request,OriginalInputStartup.Response)
    case sound(OriginalMenuSoundStartup.Event,OriginalMenuSoundStartup.Platform)
    case wave(OriginalWaveEvent,OriginalWavePlatform)

    /// Classify the log before any future host delivery. Fetching an immutable
    /// file input is not a second mmioOpen, and PCM copies are Core-owned work.
    public var domain: Domain {
        switch self {
        case .file,.panelResource,.panelDevice:return .input
        case .panelAllocation,.calendarAllocation:return .ownedMemory
        case let .music(event,_):return event.kind == .allocate ? .ownedMemory : .platform
        case let .wave(event,_):return [.allocate,.copy,.free].contains(event.kind) ? .ownedMemory : .platform
        default:return .platform
        }
    }
}

/// Private bridge owns only the attempted adapter and attempted operation log.
/// The caller publishes both only after the whole startup and handoff validate.
final class OriginalApplicationStartupBridge<P: OriginalApplicationStartupPlatform>: OriginalWinMainStartupPlatform {
    let platform: P
    var operations: [OriginalApplicationStartupOperation] = []
    var graphics = OriginalApplicationGraphics()
    var graphicsCommands: [OriginalApplicationGraphics.Command] = []
    private var currentWave: OriginalWavePlatform?
    init(_ platform: P) { self.platform = platform }
    var panelIO: OriginalWinMainStartup.PanelIO { platform.panelIO }
    var environmentTZ: [UInt8]? { platform.environmentTZ }
    var sound: OriginalMenuSoundStartup.Platform { platform.sound }
    func milliseconds() throws -> UInt32 {
        let r = try platform.milliseconds();operations.append(.milliseconds(r));return r
    }
    func initializeCriticalSection(_ address: UInt32) throws -> [UInt8] {
        let r = try platform.initializeCriticalSection(address);operations.append(.criticalSection(address,r));return r
    }
    func initializeCOM() throws -> UInt32 {
        let r = try platform.initializeCOM();operations.append(.initializeCOM(r));return r
    }
    func window(_ q: OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response {
        let r = try platform.window(q)
        graphicsCommands.append(try graphics.window(q,r));operations.append(.window(q,r));return r
    }
    func file(_ path: String) throws -> [UInt8]? {
        let r = try platform.file(path);operations.append(.file(path,r));return r
    }
    func writePanel(_ bytes: [UInt8]) throws -> Int32 {
        let r = try platform.writePanel(bytes);operations.append(.panelWrite(bytes,r));return r
    }
    func closePanel() throws -> Int32 {
        let r = try platform.closePanel();operations.append(.panelClose(r));return r
    }
    func allocatePanel() throws -> OriginalInterfaceAllocation {
        let r = try platform.allocatePanel();operations.append(.panelAllocation(r.address,r.backing));return r
    }
    func panelBitmap(_ path: String) throws -> OriginalBitmapInput {
        let r = try platform.panelBitmap(path);operations.append(.panelResource(path,r));return r
    }
    func panelDevice() throws -> (surface: UInt32,colorKeyResult: Int32) {
        let r = try platform.panelDevice();operations.append(.panelDevice(r.surface,r.colorKeyResult));return r
    }
    func filetime() throws -> UInt64 {
        let r = try platform.filetime();operations.append(.filetime(r));return r
    }
    func timezone() throws -> (result: UInt32,zone: OriginalCalendarTime.Zone?) {
        let r = try platform.timezone();operations.append(.timezone(r.result,r.zone));return r
    }
    func allocateCalendar(_ count: Int) throws -> OriginalInterfaceAllocation {
        let r = try platform.allocateCalendar(count);operations.append(.calendarAllocation(count,r.address,r.backing));return r
    }
    func convertZoneName(_ name: String,_ capacity: Int) throws -> [UInt8] {
        let r = try platform.convertZoneName(name,capacity);operations.append(.zoneName(name,capacity,r));return r
    }
    func music(_ q: OriginalMusicEvent) throws -> OriginalMusicResponse {
        let r = try platform.music(q)
        switch q.kind {
        case .helper,.format:break
        default:operations.append(.music(q,r))
        }
        return r
    }
    func cursor(_ load: Bool,_ arguments: [UInt32]) throws -> UInt32 {
        let r = try platform.cursor(load,arguments);operations.append(.cursor(load,arguments,r));return r
    }
    func joystick(_ q: OriginalInputStartup.Request,_ globals: OriginalStateRecord) throws -> OriginalInputStartup.Response {
        let r = try platform.joystick(q,globals);operations.append(.joystick(q,r));return r
    }
    func wave(_ index: Int,_ path: String,_ destination: UInt32,_ device: UInt32) throws -> OriginalWavePlatform {
        let r = try platform.wave(index,path,destination,device);currentWave = r;return r
    }
    func observe(_ observation: OriginalWinMainStartup.Observation) throws {
        if case let .sound(event,_) = observation {
            if let wave = event.wave {
                guard let input = currentWave else { throw OriginalStateError.invalidStorage("Startup WAV response lifetime") }
                if wave.kind != .load { operations.append(.wave(wave,input)) }
            } else if ["deviceCreate","cooperativeLevel","message"].contains(event.kind) {
                operations.append(.sound(event,sound))
            }
        }
        try platform.observe(observation)
    }
}
