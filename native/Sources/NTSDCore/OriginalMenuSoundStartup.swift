/// Controlled WinMain43d08e..43d100 and whole401970. The platform supplies
/// actual device/file responses; no Windows code is used by the native runtime.
public enum OriginalMenuSoundStartup {
    public struct Platform: Codable {
        public let createResult: Int32, createdDevice: UInt32?
        public let cooperativeResult: Int32, messageResult: Int32
        public init(createResult: Int32, createdDevice: UInt32?, cooperativeResult: Int32 = 0,
                    messageResult: Int32 = 0) {
            self.createResult = createResult; self.createdDevice = createdDevice
            self.cooperativeResult = cooperativeResult; self.messageResult = messageResult
        }
    }
    public struct Event: Codable, Equatable {
        public let kind: String, arguments: [UInt32], strings: [[UInt8]]
        public let wave: OriginalWaveEvent?
        public init(_ kind: String, _ arguments: [UInt32] = [], _ strings: [[UInt8]] = [], wave: OriginalWaveEvent? = nil) {
            self.kind = kind; self.arguments = arguments; self.strings = strings; self.wave = wave
        }
    }
    public struct Result {
        public let deviceReady: Bool
        /// All five results, including ordinary failed loads and their retained
        /// temporary allocations. Tokens are supplied by the platform adapter.
        public let loads: [OriginalWaveLoadResult]
    }
    public static let paths = ["data\\m_join.wav", "data\\m_ok.wav", "data\\m_cancel.wav", "data\\m_pass.wav", "data\\m_end.wav"]

    /// Whole401970: only zero DirectSoundCreate succeeds. SetCooperativeLevel's
    /// result is ignored. A failed create clears the live global without Release.
    public static func initializeDevice(globals: inout OriginalStateRecord, window: UInt32, platform: Platform,
        store: (Int, UInt32) throws -> Void = { _, _ in },
        observe: (Event, OriginalStateRecord) throws -> Void = { _, _ in }) throws -> Bool {
        try initializeDevice(globals:&globals,window:window,request:{ try OriginalSoundLegacyReplies.reply(platform,$0) },store:store,observe:observe)
    }
    public static func initializeDevice(globals: inout OriginalStateRecord,window: UInt32,
        request: (Event) throws -> OriginalSoundResponse,
        store: (Int,UInt32) throws -> Void = { _,_ in },
        observe: (Event,OriginalStateRecord) throws -> Void = { _,_ in }) throws -> Bool {
        var candidate = globals
        let base = OriginalMatchPreparation.globalBase
        guard candidate.bytes.count == OriginalMatchPreparation.globalSize else {
            throw OriginalStateError.invalidStorage("Menu sound global extent")
        }
        func put(_ value: UInt32) throws {
            try candidate.write(value, at: 0x44eecc-base); try store(0x44eecc, value)
        }
        let create = Event("deviceCreate",[0,0x44eecc,0]);try observe(create,candidate)
        let response = try request(create)
        if let output = response.output { try put(output) }
        if response.result != 0 {
            try put(0); globals = candidate; return false
        }
        let device = try candidate.integer(at: 0x44eecc-base, as: UInt32.self)
        guard response.output != nil, device != 0 else {
            throw OriginalStateError.invalidStorage("Missing successful DirectSoundCreate output")
        }
        let cooperative = Event("cooperativeLevel",[device,window,1]);try observe(cooperative,candidate);_ = try request(cooperative)
        globals = candidate; return true
    }

    public static func load(globals: inout OriginalStateRecord, platform: Platform,
        wavePlatform: (Int, String, UInt32, UInt32) throws -> OriginalWavePlatform,
        fileSource: (String) throws -> [UInt8],
        afterWave: (Int, OriginalWaveLoadResult, OriginalStateRecord) throws -> Void = { _, _, _ in },
        store: (Int, UInt32) throws -> Void = { _, _ in },
        observe: (Event, OriginalStateRecord) throws -> Void = { _, _ in }) throws -> Result {
        var replies: [Int:OriginalWaveLegacyReplies] = [:]
        return try loadObserved(globals:&globals,soundRequest:{ try OriginalSoundLegacyReplies.reply(platform,$0) },
            waveInput:{ i,path,destination,device in
                let p = try wavePlatform(i,path,destination,device),r = try OriginalWaveLegacyReplies(p)
                replies[i] = r;return r.input
            },waveRequest:{ binding,q in
                guard let r = replies[binding.index] else { throw OriginalStateError.invalidStorage("Legacy WAV call binding") }
                return try r.reply(q)
            },fileSource:fileSource,afterWave:afterWave,store:store,observe:observe)
    }

    public static func loadObserved(globals: inout OriginalStateRecord,
        soundRequest: (Event) throws -> OriginalSoundResponse,
        waveInput: (Int,String,UInt32,UInt32) throws -> OriginalWaveInput,
        waveRequest: (OriginalWaveBinding,OriginalWaveRequest) throws -> OriginalWaveResponse,
        fileSource: (String) throws -> [UInt8],
        afterWave: (Int,OriginalWaveLoadResult,OriginalStateRecord) throws -> Void = { _,_,_ in },
        store: (Int,UInt32) throws -> Void = { _,_ in },
        observe: (Event,OriginalStateRecord) throws -> Void = { _,_ in }) throws -> Result {
        var candidate = globals
        let base = OriginalMatchPreparation.globalBase
        let window = try candidate.integer(at: 0x4546f4-base, as: UInt32.self)
        let ready = try initializeDevice(globals:&candidate,window:window,request:soundRequest,store:store,observe:observe)
        if !ready {
            // The caller reloads the live HWND after the failed helper return.
            let currentWindow = try candidate.integer(at: 0x4546f4-base, as: UInt32.self)
            let message = Event("message",[currentWindow,0x30],[Array("Could not initialize Direct Sound".utf8),[]])
            try observe(message,candidate);_ = try soundRequest(message)
        }
        var loads: [OriginalWaveLoadResult] = []
        for (index, path) in paths.enumerated() {
            let destination = UInt32(0x45560c + 4*index)
            let device = try candidate.integer(at: 0x44eecc-base, as: UInt32.self)
            let p = try waveInput(index,path,destination,device)
            guard p.destination == destination, p.device == device else {
                throw OriginalStateError.invalidStorage("Menu wave device/destination binding")
            }
            let before = try candidate.integer(at: Int(destination)-base, as: UInt32.self)
            try observe(.init("load", [destination], [Array(path.utf8)]), candidate)
            if device != 0 {
                try candidate.write(UInt32(0), at: Int(destination)-base); try store(Int(destination), 0)
            }
            let file = try device == 0 || p.stream == 0 ? [] : fileSource(path)
            let binding = OriginalWaveBinding(index,path,destination,device)
            let result = try OriginalWaveLoader.loadObserved(path:Array(path.utf8),file:file,output:before,input:p,
                request:{ try waveRequest(binding,$0) }) {
                try observe(.init("wave", wave: $0), candidate)
            }
            guard result.exit == .returned else {
                throw OriginalStateError.invalidStorage("Original menu wave reaches invalid CreateSoundBuffer continuation")
            }
            if device != 0 && result.returned == 1 {
                try candidate.write(result.output, at: Int(destination)-base); try store(Int(destination), result.output)
            }
            loads.append(result); try afterWave(index, result, candidate)
        }
        globals = candidate
        return .init(deviceReady: ready, loads: loads)
    }
}
