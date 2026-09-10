import Foundation

public struct OriginalMusicEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case helper, method, queryInterface, audioVolumeRead, createInstance
        case format, createFile, allocate, convert, closeHandle, message
    }
    public let kind: Kind, arguments: [UInt32], strings: [[UInt8]]
    public init(_ kind: Kind, _ arguments: [UInt32] = [], _ strings: [[UInt8]] = []) {
        self.kind = kind; self.arguments = arguments; self.strings = strings
    }
}

/// Explicit OS/COM/allocator responses. A missing pointer means that the API
/// leaves its output word untouched. Conversion bytes are writes, not a decoded
/// Windows code page guessed by the native engine.
public struct OriginalMusicResponse: Codable, Equatable, Sendable {
    public let result: Int32, pointer: UInt32?, bytes: [UInt8]?
    public init(result: Int32 = 0, pointer: UInt32? = nil, bytes: [UInt8]? = nil) {
        self.result = result; self.pointer = pointer; self.bytes = bytes
    }
}

/// 401da0 does not free its wide-path allocation, including failed RenderFile.
/// Preserve its backing and defined bytes until the surrounding lifetime is known.
public struct OriginalMusicMemory {
    public var allocations: [UInt32: OriginalStateRecord] = [:]
    public init() {}
}

public enum OriginalMusicPlayback {
    public typealias Request = (OriginalMusicEvent) throws -> OriginalMusicResponse
    private static let base = OriginalMatchPreparation.globalBase
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Original music: "+text) }
    private static func word(_ state: OriginalStateRecord, _ address: Int) throws -> UInt32 {
        try state.integer(at: address-base,as: UInt32.self)
    }
    private static func string(_ state: OriginalStateRecord, _ address: Int) throws -> [UInt8] {
        let start = address-base
        guard start >= 0, start < state.bytes.count,
              let end = state.bytes[start...].firstIndex(of: 0) else { throw error("String outside owned globals") }
        guard state.defined[start...end].allSatisfy({ $0 }) else { throw error("Undefined global string") }
        return Array(state.bytes[start..<end])
    }
    @discardableResult
    private static func method(_ resource: UInt32, _ offset: UInt32, _ args: [UInt32] = [],
                               _ strings: [[UInt8]] = [], request: Request) throws -> Int32 {
        guard resource != 0 else { throw error("Null COM continuation") }
        return try request(.init(.method,[resource,offset]+args,strings)).result
    }

    /// Whole402100: a missing position interface skips both calls. HRESULTs
    /// are ignored; seek receives the original binary64 positive zero.
    public static func stop(globals: OriginalStateRecord, request: Request) throws {
        let position = try word(globals,0x44f04c)
        guard position != 0 else { return }
        try method(word(globals,0x44f044),0x24,request: request)
        try method(position,0x20,[0,0],request: request)
    }

    /// Entire4025b0. The selected path belongs to the preceding menu; an empty
    /// first byte skips402020 altogether, including its helper notification.
    public static func resumeMatch(globals: inout OriginalStateRecord, memory: inout OriginalMusicMemory, request: Request) throws {
        let path = try string(globals,0x44eed0)
        if !path.isEmpty { try play(path,globals: &globals,memory: &memory,request: request) }
    }

    /// Whole401d30, shared by track replacement and application shutdown.
    public static func release(globals: inout OriginalStateRecord, request: Request,
                               wrote: (Int, UInt32) throws -> Void = { _,_ in }) throws {
        var state = globals
        for address in [0x44f04c,0x44f048,0x44f044,0x44f040] {
            let pointer = try word(state,address)
            if pointer != 0 {
                try method(pointer,8,request: request)
                try state.write(UInt32(0),at: address-base)
                try wrote(address,0)
            }
        }
        globals = state
    }

    /// Whole401f30. Query failures return0; get/set failures retain their exact
    /// HRESULT. Even E_NOTIMPL releases the queried interface before returning.
    @discardableResult
    public static func setVolume(_ volume: Int32, globals: OriginalStateRecord, request: Request) throws -> Int32 {
        let graph = try word(globals,0x44f040)
        if graph == 0 { return 0 }
        let iid: [UInt8] = [0xb3,0x68,0xa8,0x56,0xd4,0x0a,0xce,0x11,0xb0,0x3a,0,0x20,0xaf,0x0b,0xa7,0x70]
        let query = try request(.init(.queryInterface,[graph],[iid]))
        if query.result < 0 { return 0 }
        let audio = query.pointer ?? 0
        guard audio != 0 else { throw error("Null successful audio query") }
        let get = try request(.init(.audioVolumeRead,[audio]))
        var result = get.result
        if result >= 0 {
            let level: Int32 = volume == 0 ? -10000 : (volume &* 34) &- 3900
            result = try method(audio,0x1c,[UInt32(bitPattern: level)],request: request)
        }
        try method(audio,8,request: request)
        return result
    }

    /// Actual4229cc->429730 through4297ae, before menu resource initialization.
    /// Neither caller menu nor previous-menu word is rewritten to enter this path.
    @discardableResult
    public static func enterMenu(globals: inout OriginalStateRecord, memory: inout OriginalMusicMemory,
                                 request: Request) throws -> Bool {
        if try word(globals,0x4512cc) != 10, try word(globals,0x44d020) == 10 {
            try play(Array("bgm\\main.wma".utf8),globals: &globals,memory: &memory,request: request)
            return true
        }
        return false
    }

    /// Whole402020 with401d30/401c90/401da0/401f30. Device and file APIs remain
    /// requests; no DirectShow or Windows implementation is shipped in the core.
    public static func play(_ path: [UInt8], globals: inout OriginalStateRecord,
                             memory: inout OriginalMusicMemory, request: Request) throws {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize, !path.contains(0) else { throw error("Globals/path extent") }
        var state = globals, owned = memory
        _ = try request(.init(.helper,[0x402020],[path]))
        if try word(state,0x44d010) == 0 { return }
        if try string(state,0x44ef04) == path {
            let control = try word(state,0x44f044)
            if control != 0 { try method(control,0x1c,request: request) }
            return
        }
        _ = try request(.init(.helper,[0x401d30]))
        try release(globals: &state,request: request)
        _ = try request(.init(.helper,[0x401c90]))
        let create = try request(.init(.createInstance,[0x44a2a4,0,1,0x44a254,0x44f040]))
        if let pointer = create.pointer { try state.write(pointer,at: 0x44f040-base) }
        if create.result < 0 {
            _ = try request(.init(.message,[0,0],[Array("Could not initialize DirectShow!".utf8),Array("ERROR".utf8)]))
        } else {
            for (address,firstByte) in [(0x44f044,UInt8(0xb1)),(0x44f048,UInt8(0xb6)),(0x44f04c,UInt8(0xb2))] {
                let graph = try word(state,0x44f040)
                guard graph != 0 else { throw error("Null successful graph creation") }
                let guid = [firstByte]+[0x68,0xa8,0x56,0xd4,0x0a,0xce,0x11,0xb0,0x3a,0,0x20,0xaf,0x0b,0xa7,0x70]
                let response = try request(.init(.queryInterface,[graph],[guid]))
                if let pointer = response.pointer { try state.write(pointer,at: address-base) }
                // The original ignores all three QueryInterface HRESULTs.
            }
            let event = try word(state,0x44f048)
            try method(event,0x34,[word(state,0x4546f4),0x400,0],request: request)
            try method(word(state,0x44f048),0x38,[0],request: request)
            try state.write(UInt8(0),at: 0x44ef04-base)
            _ = try request(.init(.helper,[0x401da0],[path]))
            let log = try string(state,0x44ef38)+Array("\\graph.log".utf8)
            guard log.count < 260, path.count <= (Int(UInt32.max)/2)-1 else { throw error("Graph stack/path extent") }
            _ = try request(.init(.format,[UInt32(log.count)],[Array("%s\\graph.log".utf8),log]))
            let file = try request(.init(.createFile,[0x40000000,0,0,2,0x80,0],[log]))
            let handle = UInt32(bitPattern: file.result)
            try method(word(state,0x44f040),0x3c,[handle],request: request)
            let count = (path.count+1)*2
            let allocation = try request(.init(.allocate,[UInt32(count)]))
            let pointer = allocation.pointer ?? 0
            if pointer != 0 {
                guard owned.allocations[pointer] == nil, let backing = allocation.bytes, backing.count == count else { throw error("Wide-path allocation") }
                owned.allocations[pointer] = try .init(bytes: backing,defined: [Bool](repeating: false,count: count))
            }
            let converted = try request(.init(.convert,[0,0,UInt32.max,pointer,UInt32(path.count+1)],[path]))
            if let bytes = converted.bytes, !bytes.isEmpty {
                guard var record = owned.allocations[pointer], bytes.count <= count else { throw error("Conversion write extent") }
                for (index,byte) in bytes.enumerated() { try record.write(byte,at: index) }
                owned.allocations[pointer] = record
            }
            let render = try method(word(state,0x44f040),0x34,[pointer,0],
                                    pointer == 0 ? [] : [owned.allocations[pointer]!.bytes],request: request)
            _ = try request(.init(.closeHandle,[handle]))
            if render < 0 {
                _ = try request(.init(.message,[0,0],[Array("Could not create a filter graph for this file!".utf8),Array("ERROR".utf8)]))
            }
        }
        _ = try request(.init(.helper,[0x401f30,word(state,0x44d000)]))
        try setVolume(Int32(bitPattern: word(state,0x44d000)),globals: state,request: request)
        let control = try word(state,0x44f044)
        if control != 0 {
            let offset = 0x44ef04-base
            guard path.count < state.bytes.count-offset else { throw error("Cached path extent") }
            for (index,byte) in (path+[0]).enumerated() { try state.write(byte,at: offset+index) }
            try method(control,0x1c,request: request)
        }
        globals = state; memory = owned
    }
}
