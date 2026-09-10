/// Whole43b3d0 input-message callbacks. Platform responses are explicit; this
/// does not execute the other WndProc messages or import a Windows runtime.
public enum OriginalWindowInput {
    public static let localBase = 0x458440
    public static let localCount = 0x140
    public struct Message: Codable, Equatable, Sendable {
        public let window: UInt32, message: UInt32, wParam: UInt32, lParam: UInt32
        public init(window: UInt32, message: UInt32, wParam: UInt32, lParam: UInt32) {
            self.window = window; self.message = message; self.wParam = wParam; self.lParam = lParam
        }
    }
    public struct Request: Codable, Equatable, Sendable {
        public enum Kind: String, Codable, Sendable { case windowDefault, message, method, free, postMessage }
        public let kind: Kind, arguments: [UInt32], strings: [[UInt8]]
        public init(_ kind: Kind, _ arguments: [UInt32] = [], _ strings: [[UInt8]] = []) {
            self.kind = kind; self.arguments = arguments; self.strings = strings
        }
    }
    public typealias Store = (Int, [UInt8]) throws -> Void
    private static let base = OriginalMatchPreparation.globalBase
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Window input: "+message) }
    private static func little(_ value: UInt32) -> [UInt8] {
        (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0*8)) }
    }
    ///4031b0 clears three words; it leaves the text bytes and sequence state.
    /// Accept the enclosing startup record or the explicitly owned local region.
    public static func initializeText(_ storage: inout OriginalStateRecord,
                                     store: Store = { _,_ in }) throws {
        guard storage.bytes.count >= 0x138 else { throw error("Text constructor storage extent") }
        var next = storage
        for offset in [0,0x130,0x134] {
            try next.write(UInt32(0),at: offset); try store(localBase+offset,little(0))
        }
        storage = next
    }
    /// Shared with the retained original mouse API. Button events do not read
    /// packed coordinates; move zero-extends both halves, even outside the client.
    static func mouse(_ message: UInt32, _ packed: UInt32,
        globals: inout OriginalStateRecord, store: Store = { _,_ in }) throws {
        var next = globals
        let writes: [(Int,UInt32)]
        switch message {
        case 0x200: writes = [(0x4546f0,packed & 0xffff),(0x453cdc,packed >> 16)]
        case 0x201: writes = [(0x457580,1)]
        case 0x202: writes = [(0x457580,0)]
        case 0x203: writes = []
        case 0x204: writes = [(0x4527e4,1)]
        case 0x205: writes = [(0x4527e4,0)]
        default: throw error("Unrecovered mouse message")
        }
        for (address,value) in writes { try next.write(value,at: address-base);try store(address,little(value)) }
        globals = next
    }
    /// Both storage records and allocation ownership commit together. Observers
    /// may fail late; callers buffer external effects until this returns.
    public static func receive(_ input: Message, globals: inout OriginalStateRecord,
        local: inout OriginalStateRecord, memory: inout OriginalMenuPresentationMemory,
        request: (Request) throws -> Int32, store: Store = { _,_ in }) throws -> Int32 {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize,
              local.bytes.count == localCount else { throw error("Global/local extents") }
        var state = globals, retained = local, owned = memory
        func word(_ address: Int) throws -> UInt32 {
            if address >= localBase { return try retained.integer(at: address-localBase,as: UInt32.self) }
            return try state.integer(at: address-base,as: UInt32.self)
        }
        func put(_ address: Int, _ value: UInt32) throws {
            if address >= localBase { try retained.write(value,at: address-localBase) }
            else { try state.write(value,at: address-base) }
            try store(address,little(value))
        }
        func byte(_ address: Int, _ value: UInt8) throws {
            if address >= localBase { try retained.write(value,at: address-localBase) }
            else { try state.write(value,at: address-base) }
            try store(address,[value])
        }
        func textAddress(_ index: UInt32) throws -> Int {
            let address = UInt32(localBase) &+ 4 &+ index
            guard address >= localBase && address < localBase+localCount else { throw error("Text write outside owned storage") }
            return Int(address)
        }
        func textKey(_ key: UInt32) throws {
            // The source accepts B..Y, not A/Z. This is a VK byte operation,
            // not host Unicode or keyboard-layout text conversion.
            if key == 0x20 || key == 0xbe || (0x42...0x59).contains(key) || (0x30...0x39).contains(key) {
                try byte(textAddress(word(localBase+0x130)),key == 0xbe ? 0x2e : UInt8(key))
                try put(localBase+0x134,word(localBase+0x134) &+ 1)
                try put(localBase+0x130,word(localBase+0x130) &+ 1)
                // Reread the live index. At299 the terminating NUL writes into
                // the index's low byte; preserve that observed data alias.
                try byte(textAddress(word(localBase+0x130)),0)
            } else if key == 8 {
                let current = try word(localBase+0x130)
                if Int32(bitPattern: current) > 0 {
                    let previous = current &- 1;try put(localBase+0x130,previous)
                    try byte(textAddress(previous),0)
                }
            } else if key == 13 { try put(localBase,0) }
        }
        func sequence(_ keys: [UInt32], _ address: Int, _ sentinel: Int) throws {
            let current = try word(address)
            if current < keys.count {
                let index = Int(current)
                if input.wParam == keys[index] {
                    if index == keys.count-1 { try byte(sentinel,100) }
                    else { try put(address,current+1) }
                    return
                }
                if index > 0 && input.wParam == keys[index-1] { return }
            }
            try put(address,0)
        }
        func position(_ address: Int) throws {
            let left = Int32(bitPattern: try word(address)),top = Int32(bitPattern: try word(address+4))
            let right = Int32(bitPattern: try word(address+8)),bottom = Int32(bitPattern: try word(address+12))
            let x = Int32(input.lParam & 0xffff),y = Int32(input.lParam >> 16)
            try put(address+16,UInt32(x));try put(address+20,UInt32(y))
            for offset in [26,27,25,24] { try byte(address+offset,0) }
            if x < (left &* 3 &+ right)/4 { try byte(address+27,1) }
            else if x > (left &+ right &* 3)/4 { try byte(address+26,1) }
            if y < (top &* 3 &+ bottom)/4 { try byte(address+24,1) }
            else if y > (top &+ bottom &* 3)/4 { try byte(address+25,1) }
        }
        var returned: Int32?
        switch input.message {
        case 0x100,0x101:
            guard input.wParam <= 255 else { throw error("Keyboard VK outside declared Windows input domain") }
            if input.message == 0x101 { try byte(0x455378+Int(input.wParam),117) }
            else {
                if try word(localBase) == 1 { try textKey(input.wParam) }
                try byte(0x455378+Int(input.wParam),100)
                try sequence([0x4c,0x46,0x32,0xbe,0x4e,0x45,0x54],0x45857c,0x455471)
                try sequence([0x48,0x45,0x52,0x4f,0x46,0x49,0x47,0x48,0x54,0x45,0x52,0xbe,0x43,0x4f,0x4d],0x458578,0x455470)
                if input.wParam == 0x90 { returned = 0 }
                else if input.wParam == 27 {
                    let answer = try request(.init(.message,[input.window,4],
                        [Array("Are you sure to quit?".utf8),Array("LF2".utf8)]))
                    if answer == 6 {
                        try OriginalMenuPresentation.releaseResources(globals: &state,memory: &owned,observe: { event in
                            let kind: Request.Kind
                            switch event.kind {
                            case .method:kind = .method
                            case .free:kind = .free
                            default:throw error("Unexpected shutdown operation")
                            }
                            _ = try request(.init(kind,event.arguments,event.strings))
                        },wrote: { address,value in try store(address,little(value)) })
                        _ = try request(.init(.postMessage,[input.window,0x10,0,0]))
                    }
                    returned = 0
                }
            }
        case 0x200...0x205:try mouse(input.message,input.lParam,globals: &state,store: store)
        case 0x3a0:try position(0x453fd8)
        case 0x3a1:try position(0x454008)
        case 0x3b5,0x3b6,0x3b7,0x3b8:
            let start = (input.message == 0x3b5 || input.message == 0x3b7) ? 0x453ff4 : 0x454024
            let down = input.message == 0x3b5 || input.message == 0x3b6
            for index in 0..<4 {
                let set = input.wParam & (1 << index) != 0
                if down && set { try byte(start+index,1) }
                else if !down && !set { try byte(start+index,0) }
            }
        default:throw error("Unrecovered window message")
        }
        let result: Int32
        if let returned { result = returned }
        else { result = try request(.init(.windowDefault,[input.window,input.message,input.wParam,input.lParam])) }
        globals = state; local = retained; memory = owned
        return result
    }
}
