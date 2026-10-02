import AppKit
import NTSDCore

/// Writable user data standing in for files the original writes beside its
/// EXE. Reads prefer these files over the immutable package; effects are
/// applied only after a committed startup, each by atomic replacement.
public struct OriginalMacRuntimeOverlay {
    public enum Boundary: Error, Equatable { case invalidPath(String) }
    public let root: URL
    public init(root: URL) { self.root = root }
    public static func standard() throws -> Self {
        let support = try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
        return .init(root:support.appendingPathComponent("NTSD Native",isDirectory:true))
    }
    public func url(_ path: String) throws -> URL {
        let parts = path.split(separator:"\\",omittingEmptySubsequences:false)
        guard !parts.isEmpty,parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("/") }) else { throw Boundary.invalidPath(path) }
        return parts.reduce(root) { $0.appendingPathComponent(String($1)) }
    }
    public func read(_ path: String) throws -> [UInt8]? {
        let url = try url(path)
        guard FileManager.default.fileExists(atPath:url.path) else { return nil }
        return Array(try Data(contentsOf:url))
    }
    public func apply(_ effects: [OriginalMacRuntimeStartupService.FileEffect]) throws {
        for effect in effects {
            let url = try url(effect.path)
            try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
            try Data(effect.bytes).write(to:url,options:.atomic)
        }
    }
}

/// Runs the recovered WinMain on the real Mac window/display/audio services and
/// the runtime startup service, from the packaged initial image to `.started`.
@MainActor public enum OriginalMacRuntimeStartup {
    public typealias Platform = OriginalApplicationPreparedStartupPlatform
    public typealias Driver = OriginalApplicationObservedStartup<Platform>
    public typealias Host = Driver.Host
    public enum Boundary: Error, Equatable { case attemptBound(Int), unserved(String), missingWindow }
    public struct Started {
        public let host: Host, driver: Driver, sequence: UInt64, window: UInt32
        public let windows: OriginalMacWindowBackend, display: OriginalMacDisplayBackend
        public let audio: OriginalMacAudioBackend, runtime: OriginalMacRuntimeStartupService
        /// Every served request kind in exchange order, with its serving owner.
        public let requests: [(owner: String,kind: String)]
        public let attempts: Int
    }
    /// The five menu WAV bindings the recovered startup requests, destination
    /// 45560c+4i, with mmio results computed from the packaged original bytes.
    public static func prepared(_ inputs: OriginalApplicationStartupInputs) throws -> Platform.Prepared {
        let io = OriginalWinMainStartup.PanelIO(chunk:4096,readFailAt:-1,infoClose:0,contentClose:0,
            outputBacking:[UInt8](repeating:0,count:4096),writeAvailable:true)
        // The legacy aggregate sound value is ignored when observesAudio is set.
        var result = Platform.Prepared(panelIO:io,environmentTZ:nil,sound:.init(createResult:0,createdDevice:0))
        result.observesAudio = true
        result.waveFiles = try OriginalMenuSoundStartup.paths.enumerated().map { index,path in
            guard let bytes = try inputs.file(path) else { throw OriginalMacRuntimeWave.Boundary.malformed(path) }
            return .init(.init(index,path,UInt32(0x45560c+4*index)),try OriginalMacRuntimeWave.input(path,bytes))
        }
        return result
    }
    /// Declared overlay replacement for the only original files startup writes or may read as absent.
    public static func inputs(_ package: OriginalApplicationStartupInputs,overlay: OriginalMacRuntimeOverlay?) throws -> OriginalApplicationStartupInputs {
        guard let overlay else { return package }
        var result = package
        for path in ["data\\adinfo.txt","data\\ad0.txt"] {
            if let bytes = try overlay.read(path) { result = try result.replacingFile(path,with:bytes) }
        }
        return result
    }
    public static func run(inputs package: OriginalApplicationStartupInputs,overlay: OriginalMacRuntimeOverlay?,
        environment: OriginalMacRuntimeStartupService.Environment = .init(),maximumAttempts: Int = 2000) throws -> Started {
        _ = NSApplication.shared
        let inputs = try Self.inputs(package,overlay:overlay)
        let driver = try Driver(platform:Platform(inputs:inputs,prepared:prepared(inputs)),instance:0x400000,show:10,initial:inputs.initial)
        let windows = OriginalMacWindowBackend(instance:0x400000)
        let windowService = OriginalMacWindowStartupService(driver:driver,backend:windows)
        let display = OriginalMacDisplayBackend(windows:windows,maximumBytes:3<<30,freshSurfacesKnownBlack:true,presentUnknownAsBlack:true,rleHolesReadPaletteZero:true,
                                                keepsOperationLogs:false),displayService = OriginalMacDisplayStartupService(driver:driver,backend:display)
        let audio = OriginalMacAudioBackend(windows:windows),audioService = OriginalMacAudioService(backend:audio)
        let runtime = OriginalMacRuntimeStartupService(windows:windows,heap:OriginalMacRuntimeHeap(),environment:environment)
        var requests: [(owner: String,kind: String)] = []
        for attempt in 1...maximumAttempts {
            switch try driver.resume() {
            case .request(let permit):
                let kind = OriginalMacRuntimeStartupService.kind(permit.request)
                switch permit.request {
                case .sound,.waveAudio: try audioService.serve(permit,on:driver); requests.append(("audio",kind))
                case .window(let q) where OriginalMacWindowBackend.handles(q): try windowService.serve(permit); requests.append(("window",kind))
                case .window(let q) where OriginalMacDisplayBackend.handles(q): try displayService.serve(permit); requests.append(("display",kind))
                case let q where OriginalMacRuntimeStartupService.handles(q): try runtime.serve(permit,on:driver); requests.append(("runtime",kind))
                default: try driver.cancel(); throw Boundary.unserved(kind)
                }
            case .started(let sequence,let host):
                guard let window = windows.operations.first(where: { $0.request.kind == "createWindow" }).map({ UInt32(bitPattern:$0.response.result) }),
                      window != 0 else { throw Boundary.missingWindow }
                try overlay?.apply(runtime.staged)
                return .init(host:host,driver:driver,sequence:sequence,window:window,windows:windows,display:display,
                    audio:audio,runtime:runtime,requests:requests,attempts:attempt)
            }
        }
        try driver.cancel(); throw Boundary.attemptBound(maximumAttempts)
    }
}
