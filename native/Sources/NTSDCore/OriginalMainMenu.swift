import Foundation

/// Requests at the recovered main-menu platform/render boundaries. They do not
/// perform network IO, open a browser, sleep, or draw from within the core.
public struct OriginalMainMenuEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case bitmap, soundRequest, soundMethod, randomTable, panel
        case startup, hostname, hostLookup, htons, addressText, formatAddress
        case socket, asyncSelect, bind, listen, closeSocket, message, sleep, shell, windowDefault
    }
    public let kind: Kind
    public let arguments: [UInt32]
    public let strings: [[UInt8]]
    public init(_ kind: Kind, _ arguments: [UInt32] = [], _ strings: [[UInt8]] = []) {
        self.kind = kind; self.arguments = arguments; self.strings = strings
    }
}

/// Supplied Winsock boundaries for 402b60/402ad0 and the main-menu caller.
/// Pointer/handle values remain opaque UInt32 tokens, never host memory.
public struct OriginalMenuNetworkInput: Codable, Equatable, Sendable {
    public struct Address: Codable, Equatable, Sendable {
        public let word: UInt32
        public let text: [UInt8]
    }
    public let startupResult: Int32, version: UInt16, hostnameResult: Int32
    public let hostname: [UInt8], hostEntryAddress: UInt32, addresses: [Address]
    public let socketResult: UInt32, asyncResult: Int32, bindResult: Int32, listenResult: Int32
}

public struct OriginalMainMenuInput: Codable, Equatable, Sendable {
    public let targetSurface: UInt32
    /// Contents of *458420 when that optional resource pointer is non-null.
    /// Only the original absent/empty panel path has been recovered here.
    public let panelWord: UInt32?
    public let network: OriginalMenuNetworkInput
}

public enum OriginalMainMenuExit: String, Codable, Sendable {
    case present, returnWithoutPresentation
}

public struct OriginalMenuMouseInput: Codable, Equatable, Sendable {
    public let window: UInt32, message: UInt32, wParam: UInt32, lParam: UInt32
    public let defaultResult: Int32
}

extension OriginalMatchPreparation {
    /// WndProc43b3d0 for messages200..205, through its DefWindowProc boundary.
    /// Coordinates are zero-extended words; button messages don't update them.
    public mutating func receiveMenuMouse(_ input: OriginalMenuMouseInput,
                                         observe: (OriginalMainMenuEvent) throws -> Void = { _ in }) throws -> Int32 {
        var candidate = self
        try OriginalWindowInput.mouse(input.message,input.lParam,globals: &candidate.globals)
        try observe(.init(.windowDefault, [input.window, input.message, input.wParam, input.lParam]))
        self = candidate
        return input.defaultResult
    }

    /// Main-menu body with the same shared storage runner used by early startup.
    public mutating func runMainMenu(crt: inout OriginalCRTRandom, input: OriginalMainMenuInput,
                                    observe: (OriginalMainMenuEvent) throws -> Void = { _ in }) throws -> OriginalMainMenuExit {
        try OriginalMainMenu.run(world: &world,globals: &globals,crt: &crt,input: input,observe: observe)
    }
}

///427915..427ca7 needs World/globals and CRT state; it does not depend on a
///loaded match catalog. The existing preparation API delegates to this runner.
public enum OriginalMainMenu {
    public static func run(world: inout OriginalStateRecord,globals: inout OriginalStateRecord,
        crt: inout OriginalCRTRandom,input: OriginalMainMenuInput,
        store: @escaping OriginalWindowInput.Store = { _,_ in },
        observe: (OriginalMainMenuEvent) throws -> Void = { _ in }) throws -> OriginalMainMenuExit {
        guard world.bytes.count == OriginalStateRecord.worldPrefixSize,globals.bytes.count == OriginalMatchPreparation.globalSize else { throw OriginalStateError.invalidStorage("Main menu storage sizes") }
        var execution = Execution(world: world,globals: globals,store:store),random = crt
        let result = try execution.consumeMainMenu(crt: &random,input: input,observe: observe)
        world = execution.world;globals = execution.globals;crt = random;return result
    }
    private struct Execution {
        var world: OriginalStateRecord,globals: OriginalStateRecord
        let store: OriginalWindowInput.Store
        static let globalBase = OriginalMatchPreparation.globalBase
        static func error(_ text: String) -> OriginalStateError { .invalidStorage("Main menu: "+text) }
        func global(_ address: Int) throws -> Int32 { try globals.integer(at: address-Self.globalBase,as: Int32.self) }
        mutating func setGlobal(_ address: Int,_ value: Int32) throws {
            try globals.write(value,at: address-Self.globalBase)
            let bits = UInt32(bitPattern:value)
            try store(address,(0..<4).map { UInt8(truncatingIfNeeded:bits >> ($0*8)) })
        }
    mutating func consumeMainMenu(crt: inout OriginalCRTRandom, input: OriginalMainMenuInput,
                                         observe: (OriginalMainMenuEvent) throws -> Void) throws -> OriginalMainMenuExit {
        func event(_ kind: OriginalMainMenuEvent.Kind, _ words: [UInt32] = [], _ strings: [[UInt8]] = []) throws {
            try observe(.init(kind, words, strings))
        }
        func bits(_ value: Int32) -> UInt32 { UInt32(bitPattern: value) }
        func draw(_ resourceGlobal: Int, _ x: Int32, _ y: Int32, _ frame: Int32) throws {
            try event(.bitmap, [bits(global(resourceGlobal)), bits(x), bits(y), bits(frame), 1, 0, input.targetSurface])
        }
        func sound() throws {
            try OriginalMatchPrelude.confirmationSound(in: globals) { request in
                switch request {
                case .soundRequest(let loop): try event(.soundRequest, [loop ? 1 : 0])
                case .soundMethod(let resource, let offset, let arguments):
                    try event(.soundMethod, [resource, UInt32(offset)]+arguments)
                default: throw Self.error("Unexpected main-menu sound event")
                }
            }
        }
        func message(_ text: String) throws {
            try event(.message, [0, 0], [Array(text.utf8), Array("Error".utf8)])
        }
        func rebuild() throws {
            let before = crt.state
            try crt.rebuildGameTable(globals: &globals)
            try event(.randomTable, [before, crt.state])
        }

        let base = try global(0x453da4) &+ 202
        try draw(0x45117c, 263, base, 0)
        try setGlobal(0x4511e0, 0)
        let x = try global(0x4546f0), y = try global(0x453cdc)
        var row = 0
        if x >= 276 && x <= 520 {
            // Compare wrapped endpoints separately, just as the signed x86
            // comparisons do. Subtracting base from y changes overflow cases.
            for (index, range) in [(15, 39), (45, 70), (77, 102), (107, 132), (137, 162)].enumerated() {
                if y >= base &+ Int32(range.0) && y <= base &+ Int32(range.1) { row = index+1 }
            }
        }
        if row == 2 { try rebuild() }  // BEFORE highlight and confirmation
        switch row {
        case 1: try draw(0x4511a0, 277, base &+ 13, 7)
        case 2: try draw(0x4511a0, 277, base &+ 45, 8)
        case 3: try draw(0x4511a0, 277, base &+ 76, 9)
        case 4: try draw(0x45117c, 279, base &+ 107, 1)
        case 5: try draw(0x45117c, 279, base &+ 139, 2)
        default: break
        }
        if row != 0, try global(0x44d060) == 0, try global(0x457580) == 1 {
            if row == 1 || row == 2 { try setGlobal(0x457580, 0) }
            try sound()
            switch row {
            case 1:
                try globals.write(UInt8(0x75), at: 0x4553bf-Self.globalBase)
                try setGlobal(0x44d064, 0)
                try world.write(Int32(1), at: 0)
                try rebuild()
                for i in 0..<4 { try setGlobal(0x450b4c+i*4, Int32(i+1)) }
            case 2:
                try setGlobal(0x44d064, 1)
                guard try initializeMenuNetwork(input.network, observe: observe) else {
                    try message("InitWinSock()")
                    return .returnWithoutPresentation
                }
                for i in 0..<200 { try globals.write(UInt8(0), at: 0x44f340-Self.globalBase+i) }
                let address = try globals.integer(at: 0x44f264-Self.globalBase, as: UInt32.self)
                guard let selected = input.network.addresses.first(where: { $0.word == address }), selected.text.count < 200 else {
                    throw Self.error("Menu address text boundary")
                }
                try event(.addressText, [address], [selected.text])
                for (i, byte) in (selected.text+[0]).enumerated() { try globals.write(byte, at: 0x44f340-Self.globalBase+i) }
                let socket = try globals.integer(at: 0x44f1b4-Self.globalBase, as: UInt32.self)
                let sockaddr = Array(globals.bytes[(0x44f58c-Self.globalBase)..<(0x44f59c-Self.globalBase)])
                try event(.bind, [socket, 16], [sockaddr])
                if input.network.bindResult == -1 {
                    try event(.closeSocket, [socket])
                    return .returnWithoutPresentation
                }
                try event(.listen, [socket, 5])
                if input.network.listenResult == -1 {
                    try message("Listening() error")
                    try event(.closeSocket, [socket])
                    return .returnWithoutPresentation
                }
            case 3: try setGlobal(0x44d064, 6)
            case 4: try setGlobal(0x44d064, 7)
            case 5:
                try event(.sleep, [300])
                try event(.shell, [0, 0, 0, 1], [Array("open".utf8), Array("http://littlefighter.com".utf8)])
            default: break
            }
        }
        try event(.panel, [0x44d060, input.targetSurface])
        guard try global(0x458420) == 0 || input.panelWord == 0 else { throw Self.error("Enabled optional main-menu panel") }
        return .present
    }

    /// Entire 402b60 with 402ad0/402a60 address selection; OS results supplied.
    private mutating func initializeMenuNetwork(_ input: OriginalMenuNetworkInput,
                                               observe: (OriginalMainMenuEvent) throws -> Void) throws -> Bool {
        func event(_ kind: OriginalMainMenuEvent.Kind, _ words: [UInt32] = [], _ strings: [[UInt8]] = []) throws {
            try observe(.init(kind, words, strings))
        }
        func message(_ text: String) throws { try event(.message, [0, 0], [Array(text.utf8), Array("Error".utf8)]) }
        func port(_ value: UInt16) throws -> UInt16 {
            try event(.htons, [UInt32(value)])
            return value.byteSwapped
        }
        func checkString(_ bytes: [UInt8], maximum: Int) throws {
            guard bytes.count <= maximum, !bytes.contains(0) else { throw Self.error("Network C-string boundary") }
        }
        try event(.startup, [0x101])
        // WSAStartup's return is ignored; the original checks wVersion instead.
        guard input.version == 0x101 else { try message("WSAStartup()"); return false }
        try event(.hostname, [256])
        guard input.hostnameResult != -1 else { try message("gethostname()"); return false }
        try checkString(input.hostname, maximum: 255)
        try event(.hostLookup, [], [input.hostname])
        try globals.write(input.hostEntryAddress, at: 0x44f2d4-Self.globalBase)
        guard input.hostEntryAddress != 0 else { try message("gethostbyname()"); return false }
        guard !input.addresses.isEmpty else { throw Self.error("Empty successful host address list") }
        var selectedIndex = 0
        for (index, address) in input.addresses.enumerated() {
            try checkString(address.text, maximum: 1023)
            _ = try port(0)
            try event(.addressText, [address.word], [address.text])
            try event(.formatAddress, [UInt32(address.text.count)], [address.text])
            // Original byte-prefix checks, not modern IP classification. In
            // particular 172.16/12 is not excluded and 127 has no dot check.
            let excluded = ["10.", "192.168", "169.254", "127"].contains { address.text.starts(with: $0.utf8) }
            if !excluded { selectedIndex = index; break }
        }
        let address = input.addresses[selectedIndex].word
        try globals.write(UInt16(2), at: 0x44f260-Self.globalBase)
        try globals.write(address, at: 0x44f264-Self.globalBase)
        try globals.write(port(5000), at: 0x44f262-Self.globalBase)
        try setGlobal(0x44f1b4, 0); try setGlobal(0x44f1b0, 0)
        try event(.socket, [2, 1, 6])
        try globals.write(input.socketResult, at: 0x44f1b4-Self.globalBase)
        guard input.socketResult != UInt32.max else { try message("socket()"); return false }
        let window = try globals.integer(at: 0x4546f4-Self.globalBase, as: UInt32.self)
        try event(.asyncSelect, [input.socketResult, window, 0x401, 0x38])
        guard input.asyncResult == 0 else { try message("WSAAsyncSelect()"); return false }
        try globals.write(UInt16(2), at: 0x44f58c-Self.globalBase)
        try globals.write(address, at: 0x44f590-Self.globalBase)
        try globals.write(port(12345), at: 0x44f58e-Self.globalBase)
        try globals.write(UInt8(0), at: 0x44f1ae-Self.globalBase)
        return true
    }
}
}
