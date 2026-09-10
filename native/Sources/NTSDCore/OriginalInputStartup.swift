/// Whole43bf10 joystick initialization and caller43d078..43d100.
/// WinMM results/output bytes are explicit inputs; native never imports unknown
/// caller stack or executes Windows code. External effects must be staged.
public enum OriginalInputStartup {
    public struct Write: Codable {
        public let offset: Int, bytes: [UInt8]
        public init(offset: Int, bytes: [UInt8]) { self.offset = offset; self.bytes = bytes }
    }
    public struct Response: Codable {
        public let result: UInt32, writes: [Write]
        public init(result: UInt32, writes: [Write] = []) { self.result = result; self.writes = writes }
    }
    public struct Request: Codable, Equatable {
        public let kind: String, arguments: [UInt32], information: [UInt8]?
        public init(_ kind: String, _ arguments: [UInt32] = [], information: [UInt8]? = nil) {
            self.kind = kind; self.arguments = arguments; self.information = information
        }
    }
    public struct Result {
        public let joystickReturn: UInt32
        public let sounds: OriginalMenuSoundStartup.Result
    }
    private static let base = OriginalMatchPreparation.globalBase
    private static func little<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        (0..<T.bitWidth/8).map { UInt8(truncatingIfNeeded: value >> ($0*8)) }
    }
    public static func initializeJoysticks(globals: inout OriginalStateRecord,
        request: (Request, OriginalStateRecord) throws -> Response,
        store: OriginalWindowInput.Store = { _,_ in },
        capabilities: (Int, OriginalStateRecord) throws -> Void = { _,_ in }) throws -> UInt32 {
        var state = globals
        guard state.bytes.count == OriginalMatchPreparation.globalSize else {
            throw OriginalStateError.invalidStorage("Input startup global extent")
        }
        func put<T: FixedWidthInteger>(_ address: Int, _ value: T) throws {
            try state.write(value,at:address-base);try store(address,little(value))
        }
        for address in stride(from:0x453fec,to:0x4540ac,by:0x30) {
            let left = try state.integer(at:address+7-base,as:UInt8.self)
            for offset in [6,5,4] { try put(address+offset,left) }
            for offset in [-0x1c,0,-4,8] { try put(address+offset,UInt32(0)) }
            try put(address+12,UInt16(0))
        }
        let count = try request(.init("numberDevices"),state).result
        guard count != 0 else { globals = state; return count }
        // The source clears this structure only once, before probing both IDs.
        var info = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:52),defined:[Bool](repeating:true,count:52))
        try info.write(UInt32(52),at:0);try info.write(UInt32(0x83),at:4)
        // Capabilities backing is private caller storage. Only actual API
        // outputs become known, and the second device reuses those own bytes.
        var caps = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:404),defined:[Bool](repeating:false,count:404))
        func output(_ response: Response, _ record: inout OriginalStateRecord) throws {
            for write in response.writes {
                guard write.offset >= 0, write.offset <= record.bytes.count-write.bytes.count else {
                    throw OriginalStateError.invalidStorage("Input startup API output extent")
                }
                for (i,byte) in write.bytes.enumerated() { try record.write(byte,at:write.offset+i) }
            }
        }
        var returned: UInt32 = count
        for id in 0..<2 {
            let position = try request(.init("position",[UInt32(id)],information:info.bytes),state)
            try output(position,&info);returned = position.result
            if position.result == 167 { continue }
            let address = 0x453fd0+id*0x30
            try put(address,UInt32(1));try put(address+4,UInt32(id))
            _ = try request(.init("threshold",[UInt32(id),100]),state)
            let window = try state.integer(at:0x4546f4-base,as:UInt32.self)
            _ = try request(.init("capture",[window,UInt32(id),25,1]),state)
            let response = try request(.init("capabilities",[UInt32(id),404]),state)
            try output(response,&caps);try capabilities(id,caps)
            let xMin = try caps.integer(at:36,as:UInt32.self),xMax = try caps.integer(at:40,as:UInt32.self)
            let yMin = try caps.integer(at:44,as:UInt32.self),yMax = try caps.integer(at:48,as:UInt32.self)
            let x = UInt32(bitPattern:Int32(bitPattern:xMin &+ xMax)/2)
            let y = UInt32(bitPattern:Int32(bitPattern:yMin &+ yMax)/2)
            try put(address+8,xMin);try put(address+24,x)
            try put(address+16,xMax);try put(address+12,yMin)
            try put(address+20,yMax);try put(address+28,y)
            returned = y
        }
        globals = state;return returned
    }

    public static func load(globals: inout OriginalStateRecord,
        request: (Request, OriginalStateRecord) throws -> Response,
        soundPlatform: OriginalMenuSoundStartup.Platform,
        wavePlatform: (Int, String, UInt32, UInt32) throws -> OriginalWavePlatform,
        fileSource: (String) throws -> [UInt8],
        store: OriginalWindowInput.Store = { _,_ in },
        capabilities: (Int, OriginalStateRecord) throws -> Void = { _,_ in },
        afterWave: (Int, OriginalWaveLoadResult, OriginalStateRecord) throws -> Void = { _,_,_ in },
        observeSound: (OriginalMenuSoundStartup.Event, OriginalStateRecord) throws -> Void = { _,_ in }) throws -> Result {
        var state = globals
        let keyBytes = [UInt8](repeating:117,count:256)
        for (i,byte) in keyBytes.enumerated() { try state.write(byte,at:0x455378-base+i) }
        try store(0x455378,keyBytes)
        let joystickReturn = try initializeJoysticks(globals:&state,request:request,store:store,capabilities:capabilities)
        let sounds = try OriginalMenuSoundStartup.load(globals:&state,platform:soundPlatform,wavePlatform:wavePlatform,
            fileSource:fileSource,afterWave:afterWave,store:{ try store($0,little($1)) },observe:observeSound)
        globals = state;return .init(joystickReturn:joystickReturn,sounds:sounds)
    }
}
