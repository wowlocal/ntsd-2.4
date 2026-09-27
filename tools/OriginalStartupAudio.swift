import Foundation

/// Value storage with explicit known bytes. No source-private or expected state.
public struct OriginalAudioBytes: Codable, Equatable, Sendable {
    public let bytes: [UInt8], defined: [Bool]
    public init(bytes: [UInt8],defined: [Bool]) { self.bytes = bytes;self.defined = defined }
    public init(_ record: OriginalStateRecord) { self.init(bytes:record.bytes,defined:record.defined) }
    public func record() throws -> OriginalStateRecord { try .init(bytes:bytes,defined:defined) }
}

/// Prior Native storage is independent of outputs from a later device Lock.
public struct OriginalWaveStorage: Codable, Equatable, Sendable {
    public let first: OriginalAudioBytes, second: OriginalAudioBytes?
    public let ramp: Bool
    public init(first: OriginalAudioBytes,second: OriginalAudioBytes?,ramp: Bool) {
        self.first = first;self.second = second;self.ramp = ramp
    }
    public func backing(_ count: Int,_ origin: Int = 0) throws -> OriginalStateRecord {
        guard (0...2_000_000).contains(count) else { throw OriginalStateError.invalidStorage("Wave backing extent") }
        return try .init(bytes:(0..<count).map { ramp ? UInt8(truncatingIfNeeded:origin+$0) : 0xa5 },
            defined:Array(repeating:false,count:count))
    }
}

/// Prepared file/MMIO inputs and own storage; contains no future audio reply.
public struct OriginalWaveInput: Codable, Equatable, Sendable {
    public let destination: UInt32, device: UInt32, stream: UInt32
    public let descendResults: [Int32], formatReadResult: Int32, ascendResult: Int32, dataReadResult: Int32, closeResult: Int32
    public let storage: OriginalWaveStorage
    public init(destination: UInt32,device: UInt32,stream: UInt32,descendResults: [Int32],formatReadResult: Int32,
        ascendResult: Int32,dataReadResult: Int32,closeResult: Int32,storage: OriginalWaveStorage) {
        self.destination = destination;self.device = device;self.stream = stream;self.descendResults = descendResults
        self.formatReadResult = formatReadResult;self.ascendResult = ascendResult;self.dataReadResult = dataReadResult
        self.closeResult = closeResult;self.storage = storage
    }
    public init(legacy p: OriginalWavePlatform) throws {
        guard p.descendResults.count == 3,p.lockResults.count == 2,
            (0...2_000_000).contains(p.firstCount),(0...2_000_000).contains(p.secondCount) else {
            throw OriginalStateError.invalidStorage("Wave loading: Platform input extent")
        }
        func bytes(_ count: Int) -> OriginalAudioBytes {
            .init(bytes:(0..<count).map { p.ramp ? UInt8(truncatingIfNeeded:$0) : 0xa5 },defined:Array(repeating:false,count:count))
        }
        self.init(destination:p.destination,device:p.device,stream:p.stream,descendResults:p.descendResults,
            formatReadResult:p.formatReadResult,ascendResult:p.ascendResult,dataReadResult:p.dataReadResult,
            closeResult:p.closeResult,storage:.init(first:bytes(p.firstCount),
                second:p.secondPointer == 0 ? nil : bytes(p.secondCount),ramp:p.ramp))
    }
}

public struct OriginalWaveBinding: Codable, Equatable, Sendable {
    public let index: Int, path: String, destination: UInt32, device: UInt32
    public init(_ index: Int,_ path: String,_ destination: UInt32,_ device: UInt32) {
        self.index = index;self.path = path;self.destination = destination;self.device = device
    }
}

public struct OriginalSoundResponse: Codable, Equatable, Sendable {
    public let result: Int32, output: UInt32?
    public init(result: Int32,output: UInt32? = nil) { self.result = result;self.output = output }
}

public struct OriginalWaveRegion: Codable, Equatable, Sendable {
    public let token: UInt32, storage: OriginalAudioBytes
    public init(token: UInt32,storage: OriginalAudioBytes) { self.token = token;self.storage = storage }
}

/// A separate snapshot for every Lock, including the ignored first lost-buffer
/// outputs. Counts and pointer presence remain independent until consumed.
public struct OriginalWaveLock: Codable, Equatable, Sendable {
    public let firstPointer: UInt32, secondPointer: UInt32, firstCount: Int, secondCount: Int
    public let first: OriginalWaveRegion?, second: OriginalWaveRegion?
    public init(firstPointer: UInt32,firstCount: Int,secondPointer: UInt32,secondCount: Int,
        first: OriginalWaveRegion?,second: OriginalWaveRegion?) {
        self.firstPointer = firstPointer;self.firstCount = firstCount;self.secondPointer = secondPointer
        self.secondCount = secondCount;self.first = first;self.second = second
    }
}

public enum OriginalWaveResponse: Codable, Equatable, Sendable {
    case created(Int32,UInt32?), locked(UInt32,OriginalWaveLock?), result(Int32), copied
}

public struct OriginalWaveRequest: Codable, Equatable, Sendable {
    public typealias Handler = (OriginalWaveRequest) throws -> OriginalWaveResponse
    public typealias Factory = (OriginalWavePlatform) throws -> Handler
    public let event: OriginalWaveEvent, target: UInt32?
    public let bytes: [UInt8]?, defined: [Bool]?, structures: [OriginalAudioBytes]
    public init(_ event: OriginalWaveEvent,target: UInt32? = nil,bytes: [UInt8]? = nil,
        defined: [Bool]? = nil,structures: [OriginalAudioBytes] = []) {
        self.event = event;self.target = target;self.bytes = bytes;self.defined = defined;self.structures = structures
    }
    public func accepts(_ response: OriginalWaveResponse) -> Bool {
        switch (event.kind,response) {
        case (.create,.created),(.lock,.locked),(.restore,.result),(.unlock,.result),(.message,.result),(.copy,.copied):return true
        default:return false
        }
    }
    /// Pure request-shape check before an external service begins. Ownership and
    /// device support must additionally be checked by that service's real owner.
    public func validate() throws {
        func require(_ value: Bool) throws {
            guard value else { throw OriginalStateError.invalidStorage("Audio request shape") }
        }
        let a = event.arguments
        if event.kind == .copy {
            try require(a.count == 3 && event.strings.isEmpty && structures.isEmpty)
            guard let target,let bytes,let defined else { throw OriginalStateError.invalidStorage("Audio copy payload") }
            try require(target != 0 && a[0] < 2 && bytes.count == Int(a[2]) && defined.count == bytes.count)
            return
        }
        try require(target == nil && bytes == nil && defined == nil)
        switch event.kind {
        case .create:
            try require(a.count == 2 && event.strings.count == 2 && structures.count == 2)
            try require(structures.map(\.bytes) == event.strings && structures.map { $0.bytes.count } == [36,18])
            for s in structures { _ = try s.record();try require(s.defined.allSatisfy { $0 }) }
        case .lock:try require(a.count == 4 && event.strings.isEmpty && structures.isEmpty)
        case .restore:try require(a.count == 1 && event.strings.isEmpty && structures.isEmpty)
        case .unlock:try require(a.count == 5 && event.strings.isEmpty && structures.isEmpty)
        case .message:try require(a.count == 2 && event.strings.count == 2 && structures.isEmpty)
        default:throw OriginalStateError.invalidStorage("Unsupported audio request")
        }
    }
}

/// Declared legacy responses only. This adapter owns its reply index and derives
/// backing solely from input controls. It never reads a reference after-state.
public final class OriginalWaveLegacyReplies {
    private let platform: OriginalWavePlatform
    public let input: OriginalWaveInput
    private var lockIndex = 0
    public init(_ platform: OriginalWavePlatform) throws {
        self.platform = platform;input = try .init(legacy:platform)
    }
    public func reply(_ q: OriginalWaveRequest) throws -> OriginalWaveResponse {
        try q.validate()
        let p = platform
        switch q.event.kind {
        case .create:
            // The aggregate adapter historically rejects a null first pointer
            // after Create's observation and before Lock. Keep that boundary
            // inside this legacy adapter; real per-call replies have no such
            // knowledge until a Lock response is consumed.
            guard p.createResult != 0 || (p.buffer != 0 && p.firstPointer != 0) else {
                throw OriginalStateError.invalidStorage("Wave loading: Null device output")
            }
            lockIndex = 0;return .created(p.createResult,p.buffer)
        case .lock:
            guard lockIndex < p.lockResults.count else { throw OriginalStateError.invalidStorage("Legacy Lock replies exhausted") }
            defer { lockIndex += 1 }
            let regions = OriginalWaveLock(firstPointer:p.firstPointer,firstCount:p.firstCount,
                secondPointer:p.secondPointer,secondCount:p.secondCount,
                first:.init(token:p.firstPointer,storage:input.storage.first),
                second:input.storage.second.map { .init(token:p.secondPointer,storage:$0) })
            return .locked(p.lockResults[lockIndex],regions)
        case .restore:return .result(p.restoreResult)
        case .unlock:return .result(p.unlockResult)
        // The old WAV aggregate has no message result. This explicit ignored
        // control is not an observed Win32 return or a fabricated device success.
        case .message:return .result(0)
        case .copy:return .copied
        default:throw OriginalStateError.invalidStorage("Legacy audio request")
        }
    }
}

public enum OriginalSoundLegacyReplies {
    public static func reply(_ p: OriginalMenuSoundStartup.Platform,_ event: OriginalMenuSoundStartup.Event) throws -> OriginalSoundResponse {
        guard event.wave == nil else { throw OriginalStateError.invalidStorage("Nested sound request") }
        switch event.kind {
        case "deviceCreate":return .init(result:p.createResult,output:p.createdDevice)
        case "cooperativeLevel":return .init(result:p.cooperativeResult)
        case "message":return .init(result:p.messageResult)
        default:throw OriginalStateError.invalidStorage("Legacy sound request")
        }
    }
}
