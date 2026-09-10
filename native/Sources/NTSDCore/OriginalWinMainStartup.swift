import Foundation

/// Declared platform/file boundaries for the continuous original startup.
/// Implementations stage external effects until the encompassing caller commits.
public protocol OriginalWinMainStartupPlatform: AnyObject {
    var panelIO: OriginalWinMainStartup.PanelIO { get }
    var environmentTZ: [UInt8]? { get }
    var sound: OriginalMenuSoundStartup.Platform { get }
    func milliseconds() throws -> UInt32
    func initializeCriticalSection(_ address: UInt32) throws -> [UInt8]
    func initializeCOM() throws -> UInt32
    func window(_ request: OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response
    func file(_ path: String) throws -> [UInt8]?
    func writePanel(_ bytes: [UInt8]) throws -> Int32
    func closePanel() throws -> Int32
    func allocatePanel() throws -> OriginalInterfaceAllocation
    func panelBitmap(_ path: String) throws -> OriginalBitmapInput
    func panelDevice() throws -> (surface: UInt32,colorKeyResult: Int32)
    func filetime() throws -> UInt64
    func timezone() throws -> (result: UInt32,zone: OriginalCalendarTime.Zone?)
    func allocateCalendar(_ count: Int) throws -> OriginalInterfaceAllocation
    func convertZoneName(_ name: String,_ capacity: Int) throws -> [UInt8]
    func music(_ event: OriginalMusicEvent) throws -> OriginalMusicResponse
    func cursor(_ load: Bool,_ arguments: [UInt32]) throws -> UInt32
    func joystick(_ request: OriginalInputStartup.Request,_ globals: OriginalStateRecord) throws -> OriginalInputStartup.Response
    func wave(_ index: Int,_ path: String,_ destination: UInt32,_ device: UInt32) throws -> OriginalWavePlatform
    func observe(_ event: OriginalWinMainStartup.Observation) throws
}

/// Actual WinMain entry through43d100, before its first message-loop setup.
/// Earlier CRT/loader inputs remain explicit. No expected child state, native
/// private stack bytes, Windows execution or complete WinMain return is implied.
public struct OriginalWinMainStartup {
    public struct PanelIO {
        public let chunk: Int,readFailAt: Int,infoClose: Int32,contentClose: Int32
        public let outputBacking: [UInt8],writeAvailable: Bool
        public init(chunk: Int = 4096,readFailAt: Int = -1,infoClose: Int32 = 0,contentClose: Int32 = 0,
            outputBacking: [UInt8],writeAvailable: Bool = true) {
            self.chunk = chunk;self.readFailAt = readFailAt;self.infoClose = infoClose;self.contentClose = contentClose
            self.outputBacking = outputBacking;self.writeAvailable = writeAvailable
        }
    }
    public enum Boundary: Error, Equatable { case unknownFullscreenCursor }
    public enum Observation {
        case stage(String,OriginalStateRecord)
        case panel(OriginalStartupPanel.Observation)
        case calendar(OriginalCalendarEvent)
        case calendarReturn(Int64,[Int32]?)
        case date(Int,[Int32],[UInt8])
        case capabilities(Int,OriginalStateRecord)
        case wave(Int,OriginalWaveLoadResult,OriginalStateRecord)
        case sound(OriginalMenuSoundStartup.Event,OriginalStateRecord)
    }
    public private(set) var random = OriginalCRTRandom()
    public private(set) var panel = OriginalStartupPanel()
    public private(set) var output = OriginalStartupOutput()
    public private(set) var input: OriginalInputStartup.Result?
    public private(set) var dates: OriginalStartupOutput.Result?
    public init() {}

    /// All owned generations and globals commit together, after the fifth WAV.
    /// Unknown fullscreen hCursor is rejected before RegisterClass. Other opaque
    /// platform structure bytes retain false masks; only owned fields compare.
    public mutating func run(instance: UInt32,show: Int32,globals: inout OriginalStateRecord,
        platform p: any OriginalWinMainStartupPlatform,
        store: OriginalWindowInput.Store = { _,_ in },
        after: (OriginalWinMainStartup,OriginalStateRecord) throws -> Void = { _,_ in }) throws {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else {
            throw OriginalStateError.invalidStorage("WinMain startup globals extent")
        }
        var candidate = self,state = globals
        func write(_ address: Int,_ bytes: [UInt8]) throws {
            for (i,b) in bytes.enumerated() { try state.write(b,at:address-OriginalMatchPreparation.globalBase+i) }
            try store(address,bytes)
        }
        try write(0x458420,[0,0,0,0])
        candidate.random.seed(try p.milliseconds())
        try p.observe(.stage("seed-return",state))
        let critical = try p.initializeCriticalSection(0x4554a4)
        guard critical.count == 24 else { throw OriginalStateError.invalidStorage("Critical section platform output extent") }
        try write(0x4554a4,critical)
        _ = try p.initializeCOM()
        try p.observe(.stage("window-entry",state))
        _ = try OriginalWindowInitialization.initialize(instance:instance,show:show,globals:&state,
            backing:{ _,count in [UInt8](repeating:0,count:count) },perform:{ request in
                if request.kind == "registerClass",let defined = request.defined,
                   !defined[24..<28].allSatisfy({ $0 }) { throw Boundary.unknownFullscreenCursor }
                return try p.window(request)
            },store:store)
        try p.observe(.stage("window-return",state))
        try p.observe(.stage("panel-entry",state))
        let io = p.panelIO
        _ = try candidate.panel.run(globals:&state,infoBytes:p.file("data\\adinfo.txt"),contentSource:p.file,
            chunk:io.chunk,infoReadFailAt:io.readFailAt,infoClose:io.infoClose,contentClose:io.contentClose,
            outputBacking:io.outputBacking,writeAvailable:io.writeAvailable,write:p.writePanel,close:p.closePanel,
            allocate:p.allocatePanel,bitmapSource:p.panelBitmap,deviceResult:p.panelDevice,
            observe:{ try p.observe(.panel($0)) },written:store)
        try p.observe(.stage("panel-return",state))
        candidate.dates = try candidate.output.run(globals:&state,filetime:p.filetime,environmentTZ:p.environmentTZ,
            timezoneSource:p.timezone,allocateCalendar:p.allocateCalendar,convertName:p.convertZoneName,
            observeCalendar:{ try p.observe(.calendar($0)) },returnedCalendar:{ try p.observe(.calendarReturn($0,$1)) },
            formatted:{ try p.observe(.date($0,$1,$2)) },requestMusic:p.music,requestCursor:p.cursor,store:store)
        try p.observe(.stage("output-return",state))
        try p.observe(.stage("input-entry",state))
        candidate.input = try OriginalInputStartup.load(globals:&state,request:p.joystick,soundPlatform:p.sound,
            wavePlatform:p.wave,fileSource:{ path in
                guard let bytes = try p.file(path) else { throw OriginalStateError.invalidStorage("Missing declared menu WAV source") }
                return bytes
            },store:store,capabilities:{ try p.observe(.capabilities($0,$1)) },
            afterWave:{ try p.observe(.wave($0,$1,$2)) },observeSound:{ try p.observe(.sound($0,$1)) })
        try p.observe(.stage("input-return",state))
        try after(candidate,state)
        self = candidate;globals = state
    }
}
