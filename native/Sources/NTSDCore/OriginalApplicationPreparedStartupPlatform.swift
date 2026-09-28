/// An opaque lifetime owner acquired outside the Core transaction. Copies retain
/// it; the platform never invokes it or uses it as mutable response storage.
public protocol OriginalApplicationStartupResource: AnyObject {}

/// Production adapter for the existing prepared WinMain boundaries. Load package
/// inputs before entering Core. Observations are prepared values or replies to
/// a suspended whole-startup request serviced outside Core. This class performs no
/// host IO and does not derive clock, allocation, codepage or device responses.
public final class OriginalApplicationPreparedStartupPlatform: OriginalApplicationWindowStartupPlatform, OriginalApplicationObservedStartupPlatform, OriginalApplicationObservedBitmapPlatform, OriginalApplicationObservedLifecyclePlatform, OriginalApplicationObservedGraphicsPlatform {
    public enum Kind: String, CaseIterable, Equatable {
        case milliseconds, criticalSection, com, panelWrite, panelClose, panelAllocation
        case panelBitmap, panelDevice, filetime, timezone, calendarAllocation, zoneName
        case music, cursor, joystick, wave
    }
    public enum Boundary: Error, Equatable {
        case missing(Kind,Int), mismatched(Kind,Int), unconsumed(Kind,Int), missingWindowCursor, invalidResponse
    }
    public struct Reply<Request: Equatable,Value> {
        public let request: Request, value: Value
        public init(_ request: Request,_ value: Value) { self.request = request; self.value = value }
    }
    public struct Name: Equatable {
        public let text: String, capacity: Int
        public init(_ text: String,_ capacity: Int) { self.text = text; self.capacity = capacity }
    }
    public struct Cursor: Equatable {
        public let load: Bool, arguments: [UInt32]
        public init(_ load: Bool,_ arguments: [UInt32]) { self.load = load; self.arguments = arguments }
    }
    public struct WaveFile: Equatable {
        public let index: Int, path: String, destination: UInt32
        public init(_ index: Int,_ path: String,_ destination: UInt32) {
            self.index = index;self.path = path;self.destination = destination
        }
    }
    public struct Wave: Equatable {
        public let index: Int, path: String, destination: UInt32, device: UInt32
        public init(_ index: Int,_ path: String,_ destination: UInt32,_ device: UInt32) {
            self.index = index; self.path = path; self.destination = destination; self.device = device
        }
    }
    public struct Zone {
        public let result: UInt32, value: OriginalCalendarTime.Zone?
        public init(_ result: UInt32,_ value: OriginalCalendarTime.Zone?) { self.result = result; self.value = value }
    }
    public struct PanelDevice {
        public let surface: UInt32, colorKeyResult: Int32
        public init(_ surface: UInt32,_ colorKeyResult: Int32) { self.surface = surface; self.colorKeyResult = colorKeyResult }
    }
    public enum File: Equatable { case absent, bytes([UInt8]) }

    /// Value preparation, independently copied at construction. Empty arrays mean
    /// unavailable observations, never default success. Request bindings include
    /// complete byte arguments; unknown backing is not made defined here.
    public struct Prepared {
        public var panelIO: OriginalWinMainStartup.PanelIO
        public var environmentTZ: [UInt8]?
        public var sound: OriginalMenuSoundStartup.Platform
        public var observesAudio = false
        public var waveInputs: [Reply<OriginalWaveBinding,OriginalWaveInput>] = []
        public var waveFiles: [Reply<WaveFile,OriginalWaveFileInput>] = []
        public var files: [String:File] = [:]
        public var milliseconds: [UInt32] = []
        public var criticalSections: [Reply<UInt32,[UInt8]>] = []
        public var com: [UInt32] = []
        public var panelWrites: [Reply<[UInt8],Int32>] = []
        public var panelCloses: [Int32] = []
        public var panelAllocations: [OriginalInterfaceAllocation] = []
        public var panelBitmaps: [Reply<String,OriginalBitmapInput>] = []
        public var panelDevices: [PanelDevice] = []
        public var filetimes: [UInt64] = []
        public var zones: [Zone] = []
        public var calendarAllocations: [Reply<Int,OriginalInterfaceAllocation>] = []
        public var zoneNames: [Reply<Name,[UInt8]>] = []
        public var music: [Reply<OriginalMusicEvent,OriginalMusicResponse>] = []
        public var cursors: [Reply<Cursor,UInt32>] = []
        public var joysticks: [Reply<OriginalInputStartup.Request,OriginalInputStartup.Response>] = []
        public var waves: [Reply<Wave,OriginalWavePlatform>] = []
        public var resources: [any OriginalApplicationStartupResource] = []
        public init(panelIO: OriginalWinMainStartup.PanelIO, environmentTZ: [UInt8]?,
                    sound: OriginalMenuSoundStartup.Platform) {
            self.panelIO = panelIO; self.environmentTZ = environmentTZ; self.sound = sound
        }
    }
    public struct Snapshot: Equatable {
        public fileprivate(set) var positions: [Kind:Int] = [:]
        /// Attempted bytes and close results, not physical IO or a second FILE.
        public fileprivate(set) var panelWrites: [[UInt8]] = []
        public fileprivate(set) var panelCloses: [Int32] = []
    }
    public let inputs: OriginalApplicationStartupInputs
    private let prepared: Prepared
    private var state = Snapshot()
    public var windowExchange: OriginalWindowRequestExchange.Cursor?
    public var startupExchange: OriginalStartupRequestExchange.Cursor?
    public var bitmapDelivery = OriginalBitmapDelivery()
    public var lifecycleDelivery = OriginalLifecycleDelivery()
    public var graphicsDelivery = OriginalMenuGraphicsDelivery()
    public var snapshot: Snapshot { state }
    public var panelIO: OriginalWinMainStartup.PanelIO { prepared.panelIO }
    public var environmentTZ: [UInt8]? { prepared.environmentTZ }
    public var sound: OriginalMenuSoundStartup.Platform { prepared.sound }
    public var observesAudio: Bool { prepared.observesAudio }

    public init(inputs: OriginalApplicationStartupInputs, prepared: Prepared) {
        self.inputs = inputs; self.prepared = prepared
    }
    public func stagedCopy() throws -> OriginalApplicationPreparedStartupPlatform {
        let copy = OriginalApplicationPreparedStartupPlatform(inputs:inputs,prepared:prepared)
        copy.state = state; copy.windowExchange = windowExchange; copy.startupExchange = startupExchange; copy.bitmapDelivery = bitmapDelivery; copy.lifecycleDelivery = lifecycleDelivery; copy.graphicsDelivery = graphicsDelivery
        return copy
    }
    private func take<T>(_ kind: Kind,_ values: [T],matching matches: (T) -> Bool = { _ in true }) throws -> T {
        let index = state.positions[kind,default:0]
        guard values.indices.contains(index) else { throw Boundary.missing(kind,index) }
        let value = values[index]
        guard matches(value) else { throw Boundary.mismatched(kind,index) }
        state.positions[kind] = index+1
        return value
    }
    private func take<Q: Equatable,V>(_ kind: Kind,_ values: [Reply<Q,V>],_ request: Q) throws -> V {
        try take(kind,values,matching:{ $0.request == request }).value
    }
    /// With a cursor installed, every throwing external boundary is acquired
    /// through the single journal. The fallback is lazy and never consumed then.
    private func response<T>(_ request: OriginalStartupRequest,
        _ value: (OriginalStartupResponse) -> T?, otherwise fallback: @autoclosure () throws -> T) throws -> T {
        guard var cursor = startupExchange else { return try fallback() }
        defer { startupExchange = cursor }
        let reply = try cursor.response(for:request)
        guard let result = value(reply) else { throw Boundary.invalidResponse }
        return result
    }
    /// Called by the enclosing owner's final validation. It does not consume or
    /// finish the separate window exchange, whose completion is owned by Driver.
    public func validatePreparedConsumption() throws {
        let counts: [Kind:Int] = [
            .milliseconds:prepared.milliseconds.count,.criticalSection:prepared.criticalSections.count,
            .com:prepared.com.count,.panelWrite:prepared.panelWrites.count,.panelClose:prepared.panelCloses.count,
            .panelAllocation:prepared.panelAllocations.count,.panelBitmap:prepared.panelBitmaps.count,
            .panelDevice:prepared.panelDevices.count,.filetime:prepared.filetimes.count,
            .timezone:prepared.zones.count,.calendarAllocation:prepared.calendarAllocations.count,
            .zoneName:prepared.zoneNames.count,.music:prepared.music.count,.cursor:prepared.cursors.count,
            .joystick:prepared.joysticks.count,.wave:prepared.observesAudio ? prepared.waveInputs.count+prepared.waveFiles.count : prepared.waves.count]
        guard prepared.observesAudio ? (prepared.waves.isEmpty && (prepared.waveInputs.isEmpty || prepared.waveFiles.isEmpty)) : (prepared.waveInputs.isEmpty && prepared.waveFiles.isEmpty) else {
            throw Boundary.unconsumed(.wave,prepared.waves.count+prepared.waveInputs.count+prepared.waveFiles.count)
        }
        for kind in Kind.allCases {
            let remaining = counts[kind,default:0]-state.positions[kind,default:0]
            if remaining != 0 { throw Boundary.unconsumed(kind,remaining) }
        }
    }
    public func milliseconds() throws -> UInt32 { try response(.milliseconds, { if case .milliseconds(let v) = $0 { return v }; return nil }, otherwise: take(.milliseconds,prepared.milliseconds)) }
    public func initializeCriticalSection(_ address: UInt32) throws -> [UInt8] {
        try response(.initializeCriticalSection(address), { if case .initializeCriticalSection(let v) = $0 { return v }; return nil }, otherwise: take(.criticalSection,prepared.criticalSections,address))
    }
    public func initializeCOM() throws -> UInt32 { try response(.initializeCOM, { if case .initializeCOM(let v) = $0 { return v }; return nil }, otherwise: take(.com,prepared.com)) }
    public func window(_ request: OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response {
        if startupExchange != nil {
            return try response(.window(request), { if case .window(let v) = $0 { return v }; return nil },
                otherwise: { throw Boundary.missingWindowCursor }())
        }
        guard var cursor = windowExchange else { throw Boundary.missingWindowCursor }
        defer { windowExchange = cursor }
        return try cursor.response(for:request)
    }
    public func file(_ path: String) throws -> [UInt8]? {
        if let file = prepared.files[path] {
            switch file { case .absent:return nil; case .bytes(let bytes):return bytes }
        }
        return try inputs.file(path)
    }
    public func writePanel(_ bytes: [UInt8]) throws -> Int32 {
        let result = try response(.panelWrite(bytes), { if case .panelWrite(let v) = $0 { return v }; return nil }, otherwise: take(.panelWrite,prepared.panelWrites,bytes))
        state.panelWrites.append(bytes); return result
    }
    public func closePanel() throws -> Int32 {
        let result = try response(.panelClose, { if case .panelClose(let v) = $0 { return v }; return nil }, otherwise: take(.panelClose,prepared.panelCloses))
        state.panelCloses.append(result); return result
    }
    public func allocatePanel() throws -> OriginalInterfaceAllocation { try response(.allocatePanel, { if case .allocatePanel(let v) = $0 { return v }; return nil }, otherwise: take(.panelAllocation,prepared.panelAllocations)) }
    public func panelBitmap(_ path: String) throws -> OriginalBitmapInput { try response(.panelBitmap(path), { if case .panelBitmap(let v) = $0 { return v }; return nil }, otherwise: take(.panelBitmap,prepared.panelBitmaps,path)) }
    public func panelDevice() throws -> (surface: UInt32,colorKeyResult: Int32) {
        let value = try response(.panelDevice, { if case .panelDevice(let v) = $0 { return v }; return nil }, otherwise: take(.panelDevice,prepared.panelDevices)); return (value.surface,value.colorKeyResult)
    }
    public func filetime() throws -> UInt64 { try response(.filetime, { if case .filetime(let v) = $0 { return v }; return nil }, otherwise: take(.filetime,prepared.filetimes)) }
    public func timezone() throws -> (result: UInt32,zone: OriginalCalendarTime.Zone?) {
        let value = try response(.timezone, { if case .timezone(let v) = $0 { return v }; return nil }, otherwise: take(.timezone,prepared.zones)); return (value.result,value.value)
    }
    public func allocateCalendar(_ count: Int) throws -> OriginalInterfaceAllocation {
        try response(.allocateCalendar(count), { if case .allocateCalendar(let v) = $0 { return v }; return nil }, otherwise: take(.calendarAllocation,prepared.calendarAllocations,count))
    }
    public func convertZoneName(_ name: String,_ capacity: Int) throws -> [UInt8] {
        try response(.zoneName(name,capacity), { if case .zoneName(let v) = $0 { return v }; return nil }, otherwise: take(.zoneName,prepared.zoneNames,Name(name,capacity)))
    }
    public func music(_ event: OriginalMusicEvent) throws -> OriginalMusicResponse {
        // The shared child discards these notification return values; they are
        // neither COM calls nor fabricated replies to terminal device requests.
        if event.kind == .helper || event.kind == .format { return .init() }
        return try response(.music(event), { if case .music(let v) = $0 { return v }; return nil }, otherwise: take(.music,prepared.music,event))
    }
    public func cursor(_ load: Bool,_ arguments: [UInt32]) throws -> UInt32 {
        try response(.cursor(load,arguments), { if case .cursor(let v) = $0 { return v }; return nil }, otherwise: take(.cursor,prepared.cursors,Cursor(load,arguments)))
    }
    public func joystick(_ request: OriginalInputStartup.Request,_ globals: OriginalStateRecord) throws -> OriginalInputStartup.Response {
        try response(.joystick(request), { if case .joystick(let v) = $0 { return v }; return nil }, otherwise: take(.joystick,prepared.joysticks,request))
    }
    public func wave(_ index: Int,_ path: String,_ destination: UInt32,_ device: UInt32) throws -> OriginalWavePlatform {
        try response(.wave(Wave(index,path,destination,device)), { if case .wave(let v) = $0 { return v }; return nil }, otherwise: take(.wave,prepared.waves,Wave(index,path,destination,device)))
    }
    public func soundRequest(_ event: OriginalMenuSoundStartup.Event) throws -> OriginalSoundResponse {
        guard observesAudio,startupExchange != nil else { throw Boundary.invalidResponse }
        return try response(.sound(event),{ if case .sound(let v) = $0 { return v };return nil },
            otherwise:{ throw Boundary.invalidResponse }())
    }
    public func waveInput(_ index: Int,_ path: String,_ destination: UInt32,_ device: UInt32) throws -> OriginalWaveInput {
        guard observesAudio,prepared.waves.isEmpty,
              prepared.waveInputs.isEmpty || prepared.waveFiles.isEmpty else { throw Boundary.invalidResponse }
        if !prepared.waveFiles.isEmpty {
            return try take(.wave,prepared.waveFiles,WaveFile(index,path,destination)).bind(destination:destination,device:device)
        }
        return try take(.wave,prepared.waveInputs,OriginalWaveBinding(index,path,destination,device))
    }
    public func waveRequest(_ binding: OriginalWaveBinding,_ request: OriginalWaveRequest) throws -> OriginalWaveResponse {
        guard observesAudio,startupExchange != nil else { throw Boundary.invalidResponse }
        return try response(.waveAudio(binding,request),{ if case .waveAudio(let v) = $0 { return v };return nil },
            otherwise:{ throw Boundary.invalidResponse }())
    }
    public func observe(_ event: OriginalWinMainStartup.Observation) throws {}
}
