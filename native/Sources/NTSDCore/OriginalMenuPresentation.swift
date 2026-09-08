import Foundation

/// Supplied COM/GDI/window responses. Tokens identify platform resources, never
/// host pointers. Helpers execute their original decisions around these results.
public struct OriginalMenuPresentationInput: Codable, Sendable {
    public let targetSurface: UInt32
    public let methodResult: Int32, queryResult: Int32, audioGetResult: Int32, audioSetResult: Int32
    public let queriedAudio: UInt32, audioVolume: Int32
    public let dcResult: Int32, dc: UInt32, postResult: Int32
}

public struct OriginalMenuPresentationEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case bitmap, method, queryInterface, audioVolumeRead, getDC
        case setTextColor, setBackgroundColor, stringLength, textOut, releaseDC
        case format, free, postMessage
    }
    public let kind: Kind
    public let arguments: [UInt32]
    public let strings: [[UInt8]]
    public init(_ kind: Kind, _ arguments: [UInt32] = [], _ strings: [[UInt8]] = []) {
        self.kind = kind; self.arguments = arguments; self.strings = strings
    }
}

/// Explicit allocator ownership for menu bitmap/replay releases. This preserves
/// whole records, including dead bytes/masks; it doesn't invent loaded pixels.
public struct OriginalMenuPresentationMemory {
    public struct Allocation: Equatable {
        public var storage: OriginalStateRecord
        public var live: Bool
        public init(storage: OriginalStateRecord, live: Bool = true) { self.storage = storage; self.live = live }
    }
    public var allocations: [UInt32: Allocation] = [:]
    /// 4588a8 and 4588ac are outside the ordinary globals region.
    public var replayPointers: OriginalStateRecord
    public init(replayPointers: OriginalStateRecord) { self.replayPointers = replayPointers }
}

public enum OriginalMenuPresentationEntry: String, Codable, Sendable {
    case tail, epilogue, worldOne, overlay
}

/// Shared 4246b0 presentation/return, and its exact World+0==1 branch.
/// Rendering, COM/GDI and allocator IO are explicit requests. No Windows runtime.
public enum OriginalMenuPresentation {
    /// Entire423910/43ef50. Reused by the early menu and mode confirmation.
    public static func releaseBackground(globals: inout OriginalStateRecord, memory: inout OriginalMenuPresentationMemory,
                                         observe: (OriginalMenuPresentationEvent) throws -> Void) throws {
        var state = globals, owned = memory
        let offset = 0x4511ac-OriginalMatchPreparation.globalBase
        let pointer = try state.integer(at: offset, as: UInt32.self)
        if pointer == 0 { return }
        guard var allocation = owned.allocations[pointer], allocation.live,
              allocation.storage.bytes.count == 0x1f50 else {
            throw OriginalStateError.invalidStorage("Menu bitmap ownership")
        }
        let surface = try allocation.storage.integer(at: 0, as: UInt32.self)
        if surface != 0 {
            try observe(.init(.method, [surface,8]))
            try allocation.storage.write(UInt32(0), at: 0)
        }
        try observe(.init(.free, [pointer]))
        allocation.live = false; owned.allocations[pointer] = allocation
        try state.write(UInt32(0), at: offset)
        globals = state; memory = owned
    }
    /// Entire4019b0, also called alone by the mode screen. Other shutdown
    /// children belong to their callers. Keep stale buffer slots/counts.
    public static func releaseSoundDevice(globals: inout OriginalStateRecord,
                                          observe: (OriginalMenuPresentationEvent) throws -> Void) throws {
        var state = globals
        func word(_ address: Int) throws -> UInt32 { try state.integer(at: address-OriginalMatchPreparation.globalBase,as: UInt32.self) }
        func method(_ resource: UInt32) throws {
            guard resource != 0 else { throw OriginalStateError.invalidStorage("Null shutdown COM resource") }
            try observe(.init(.method,[resource,8]))
        }
        if try word(0x44eecc) != 0 {
            for (countAddress,arrayAddress) in [(0x458438,0x452948),(0x45843c,0x451db0)] {
                let count = Int32(bitPattern: try word(countAddress))
                guard count <= (OriginalMatchPreparation.globalBase+state.bytes.count-arrayAddress)/4 else { throw OriginalStateError.invalidStorage("Sound release list extent") }
                if count > 0 { for index in 0..<Int(count) { try method(word(arrayAddress+index*4)) } }
            }
            try method(word(0x44eecc)); try state.write(UInt32(0),at: 0x44eecc-OriginalMatchPreparation.globalBase)
        }
        globals = state
    }
    /// Shared4019b0/401d30/43d2a0 then PostMessage(close), also called on
    /// network mismatches. Keep stale buffer slots/counts after device release.
    public static func shutdown(globals: inout OriginalStateRecord, memory: inout OriginalMenuPresentationMemory,
                                observe: (OriginalMenuPresentationEvent) throws -> Void) throws {
        var state = globals, owned = memory
        try releaseSoundDevice(globals: &state, observe: observe)
        try OriginalMusicPlayback.release(globals: &state) { event in
            try observe(.init(.method,event.arguments,event.strings))
            return .init()
        }
        for offset in [0,4] {
            let pointer = try owned.replayPointers.integer(at: offset,as: UInt32.self)
            if pointer != 0 {
                guard var allocation = owned.allocations[pointer], allocation.live else { throw OriginalStateError.invalidStorage("Unknown/dead shutdown allocation") }
                try observe(.init(.free,[pointer])); allocation.live = false; owned.allocations[pointer] = allocation
                try owned.replayPointers.write(UInt32(0),at: offset)
            }
        }
        try observe(.init(.postMessage,[state.integer(at: 0x4546f4-OriginalMatchPreparation.globalBase,as: UInt32.self),0x10,0,0]))
        globals = state; memory = owned
    }
    /// 43e940 is shared by startup, menus and the match display path.
    public static func presentSurface(globals: OriginalStateRecord,
                                      observe: (OriginalMenuPresentationEvent) throws -> Void = { _ in }) throws {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else { throw OriginalStateError.invalidStorage("Present globals extent") }
        func word(_ address: Int) throws -> UInt32 { try globals.integer(at: address-OriginalMatchPreparation.globalBase, as: UInt32.self) }
        let mode = try word(0x458348)
        if mode == 1 || mode == 2 {
            let resource = try word(mode == 1 ? 0x453e0c : 0x455634)
            guard resource != 0 else { throw OriginalStateError.invalidStorage("Null flip surface") }
            try observe(.init(.method, [resource, 0x2c, 0, 1]))
        } else if mode == 3 {
            let resource = try word(0x455634), start = 0x453ccc-OriginalMatchPreparation.globalBase
            guard resource != 0 else { throw OriginalStateError.invalidStorage("Null blit destination") }
            try observe(.init(.method, [resource, 0x14, 0x453ccc, word(0x455608), 0, 0x1000000, 0], [Array(globals.bytes[start..<(start+16)])]))
        }
    }
    public static func apply(_ entry: OriginalMenuPresentationEntry, input: OriginalMenuPresentationInput,
                             world: inout OriginalStateRecord, globals: inout OriginalStateRecord,
                             memory: inout OriginalMenuPresentationMemory,
                             observe: (OriginalMenuPresentationEvent) throws -> Void = { _ in }) throws {
        var execution = Execution(world: world, globals: globals, memory: memory, input: input)
        try execution.run(entry, observe)
        world = execution.world; globals = execution.globals; memory = execution.memory
    }

    private struct Execution {
        var world: OriginalStateRecord, globals: OriginalStateRecord, memory: OriginalMenuPresentationMemory
        let input: OriginalMenuPresentationInput
        typealias Observer = (OriginalMenuPresentationEvent) throws -> Void
        func bits(_ x: Int32) -> UInt32 { UInt32(bitPattern: x) }
        func word(_ address: Int) throws -> UInt32 {
            try globals.integer(at: address-OriginalMatchPreparation.globalBase, as: UInt32.self)
        }
        func signed(_ address: Int) throws -> Int32 { try Int32(bitPattern: word(address)) }
        mutating func write(_ address: Int, _ value: UInt32) throws {
            try globals.write(value, at: address-OriginalMatchPreparation.globalBase)
        }
        func string(_ address: Int) throws -> [UInt8] {
            var value: [UInt8] = [], current = address
            while true {
                let byte = try globals.integer(at: current-OriginalMatchPreparation.globalBase, as: UInt8.self)
                if byte == 0 { return value }
                value.append(byte); current += 1
            }
        }
        func method(_ resource: UInt32, _ offset: UInt32, _ args: [UInt32] = [],
                    _ observe: Observer) throws {
            guard resource != 0 else { throw error("Null COM resource") }
            try observe(.init(.method, [resource, offset]+args))
        }
        mutating func free(_ address: UInt32, _ observe: Observer) throws {
            guard var allocation = memory.allocations[address], allocation.live else { throw error("Unknown/dead allocation") }
            try observe(.init(.free, [address]))
            allocation.live = false; memory.allocations[address] = allocation
        }
        mutating func releaseMenuBitmap(_ observe: Observer) throws {
            try OriginalMenuPresentation.releaseBackground(globals: &globals, memory: &memory, observe: observe)
        }
        /// 401f30: query IBasicAudio, read volume, set it only after a successful
        /// read, release the queried interface on both read/set outcomes.
        func musicVolume(_ volume: Int32, _ observe: Observer) throws {
            try OriginalMusicPlayback.setVolume(volume,globals: globals) { event in
                guard let kind = OriginalMenuPresentationEvent.Kind(rawValue: event.kind.rawValue) else { throw error("Music volume event") }
                try observe(.init(kind,event.arguments,event.strings))
                switch event.kind {
                case .queryInterface: return .init(result: input.queryResult,pointer: input.queriedAudio)
                case .audioVolumeRead: return .init(result: input.audioGetResult)
                case .method: return .init(result: event.arguments[1] == 0x1c ? input.audioSetResult : input.methodResult)
                default: throw error("Music volume response")
                }
            }
        }
        mutating func changeVolume(_ direction: Int32, _ observe: Observer) throws {
            let volume = max(0, min(100, try signed(0x44d000) &+ direction))
            try write(0x44d000, bits(volume))
            try musicVolume(volume, observe)
            let level: Int32 = volume > 0 ? ((volume-100)*3800)/100 : -10000
            for address in stride(from: 0x45560c, to: 0x455620, by: 4) {
                try method(word(address), 0x3c, [bits(level)], observe)
            }
        }
        /// 401290 executes GetDC -> GDI text setup/output -> ReleaseDC. Failed
        /// GetDC skips GDI and release. Colors are raw COLORREF, not RGB guesses.
        func text(_ bytes: [UInt8], color: UInt32, _ observe: Observer) throws {
            guard bytes.count < 512 else { throw error("Overlay stack string extent") }
            try OriginalSurfaceText.draw(bytes,target: word(0x455608),background: 0,color: color,
                                         x: 3,y: 531,dcResult: input.dcResult,dc: input.dc,observe: observe)
        }
        func formatted(_ format: String, _ bytes: [UInt8], color: UInt32, _ observe: Observer) throws {
            // Recording strings start at local+18 and the cookie is at+20c:
            // 500 bytes including NUL. Stack overwrites are outside this API.
            if format != "Volume: %d", bytes.count >= 500 { throw error("Recording notice stack extent") }
            try observe(.init(.format, [UInt32(bytes.count)], [Array(format.utf8), bytes]))
            try text(bytes, color: color, observe)
        }
        mutating func overlay(_ observe: Observer) throws {
            var direction: Int32 = 0
            if try globals.integer(at: 0x4553f2-OriginalMatchPreparation.globalBase, as: UInt8.self) == 0x64 { direction = -1 }
            if try globals.integer(at: 0x4553f3-OriginalMatchPreparation.globalBase, as: UInt8.self) == 0x64 { direction = 1 }
            if direction != 0 {
                try changeVolume(direction, observe)
                try write(0x44f190, 100)
            }
            if try signed(0x44f190) > 0, try word(0x450b70) == 0 {
                try formatted("Volume: %d", Array("Volume: \(signed(0x44d000))".utf8), color: 0x00ff00, observe)
                try write(0x44f190, word(0x44f190) &- 1)
            }
            let notice = try signed(0x450b70)
            if notice > 0, try word(0x450bfc) == 0 {
                let timer = try signed(0x450b6c) &+ 1
                try write(0x450b6c, bits(timer))
                if timer > 240 {
                    try write(0x450b6c, 0); try write(0x450b70, 0)
                    return
                }
            }
            if notice == 1 {
                try formatted("Start recording '%s'...", Array("Start recording '".utf8)+string(0x44fd98)+Array("'...".utf8), color: 0xff7800, observe)
            }
            if try word(0x450b70) == 2 {
                try formatted("Recording file '%s' saved!", Array("Recording file '".utf8)+string(0x44fd98)+Array("' saved!".utf8), color: 0x00ff00, observe)
            }
            if try word(0x450b70) == 3 {
                // The second increment also happens when 450bfc suppresses the
                // earlier increment. It is deliberately not folded into it.
                let bytes = Array("Recording canceled!".utf8)
                try observe(.init(.format, [UInt32(bytes.count)], [bytes, bytes]))
                try write(0x450b6c, word(0x450b6c) &+ 1)
                try text(bytes, color: 0x0000ff, observe)
            }
        }
        func present(_ observe: Observer) throws {
            try OriginalMenuPresentation.presentSurface(globals: globals, observe: observe)
        }
        mutating func shutdown(_ observe: Observer) throws {
            try OriginalMenuPresentation.shutdown(globals: &globals,memory: &memory,observe: observe)
        }
        mutating func run(_ entry: OriginalMenuPresentationEntry, _ observe: Observer) throws {
            guard world.bytes.count == OriginalStateRecord.worldPrefixSize,
                  globals.bytes.count == OriginalMatchPreparation.globalSize,
                  memory.replayPointers.bytes.count == 8 else { throw error("Storage sizes") }
            switch entry {
            case .epilogue: return
            case .overlay: try overlay(observe)
            case .worldOne:
                guard try world.integer(at: 0, as: Int32.self) == 1 else { throw error("Dispatcher requires World=1") }
                try releaseMenuBitmap(observe)
                try observe(.init(.bitmap, [word(0x45118c), 0, 0, UInt32.max, 0, 0, input.targetSurface]))
                try world.write(Int32(2), at: 0)
                try overlay(observe); try present(observe)
            case .tail:
                let x = min(775, try signed(0x4546f0)), y = min(535, try signed(0x453cdc) &+ 2)
                try observe(.init(.bitmap, [word(0x451170), bits(x), bits(y), UInt32.max, 1, 0, input.targetSurface]))
                try overlay(observe); try present(observe)
                if try signed(0x4546f0) < 63, try signed(0x453cdc) >= 514,
                   try word(0x44d060) == 0, try word(0x457580) == 1 { try shutdown(observe) }
                try write(0x44d060, word(0x457580))
            }
        }
        func error(_ text: String) -> OriginalStateError { .invalidStorage("Menu presentation: \(text)") }
    }
}
