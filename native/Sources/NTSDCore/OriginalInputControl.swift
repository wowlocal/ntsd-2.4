import Foundation

public struct OriginalInputControlRequest: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case asyncSelect, ioctl, send, receive, message, method, free, postMessage
        case action, soundRequest, inputReset, restorePlayback
    }
    public let kind: Kind, arguments: [UInt32], data: [[UInt8]]
    public init(_ kind: Kind, _ arguments: [UInt32] = [], _ data: [[UInt8]] = []) {
        self.kind = kind; self.arguments = arguments; self.data = data
    }
}

/// Values returned by the OS/device boundary. Receive payloads and ioctl's
/// optional four-byte output are explicit; no network IO runs inside the core.
public struct OriginalInputControlResponse: Codable, Equatable, Sendable {
    public let result: Int32, bytes: [UInt8]
    public init(result: Int32 = 0, bytes: [UInt8] = []) { self.result = result; self.bytes = bytes }
}

public struct OriginalInputControlContext {
    /// Original saved globals458588..4588a7. These are populated by playback
    /// startup, not inferred from current names/settings when restoring them.
    public var savedPlayback: OriginalStateRecord
    public var memory: OriginalMenuPresentationMemory
    public init(savedPlayback: OriginalStateRecord, memory: OriginalMenuPresentationMemory) {
        self.savedPlayback = savedPlayback; self.memory = memory
    }

    /// Real43df00 plus the caller's saved sound flags in the playback buffer.
    mutating func restorePlayback(globals: inout OriginalStateRecord) throws {
        guard savedPlayback.bytes.count == 0x320 else { throw OriginalStateError.invalidStorage("Playback saved-settings extent") }
        let base = OriginalMatchPreparation.globalBase
        try globals.write(Int32(savedPlayback.integer(at: 0x45877c-0x458588,as: Int8.self)),at: 0x450c30-base)
        for (source,destination) in (0..<8).map({ (0x458850+$0*11,0x44fcc0+$0*11) })
            + [(0x4587e8,0x44fd18),(0x458588,0x44f900),(0x458780,0x44f890)] {
            var i = 0
            while true {
                let byte = try savedPlayback.integer(at: source-0x458588+i,as: UInt8.self)
                try globals.write(byte,at: destination-base+i); i += 1
                if byte == 0 { break }
            }
        }
        let pointer = try memory.replayPointers.integer(at: 4,as: UInt32.self)
        guard let allocation = memory.allocations[pointer], allocation.live else { throw OriginalStateError.invalidStorage("Playback buffer ownership") }
        for (source,destination) in [(0x630bb8,0x458428),(0x630bbc,0x45842c)] {
            try globals.write(allocation.storage.integer(at: source,as: UInt32.self),at: destination-base)
        }
    }
}

extension OriginalMatchPreparation {
    public typealias InputControlBoundary = (OriginalInputControlRequest) throws -> OriginalInputControlResponse

    /// 41c5e5..41d46f: phase0 hotkeys/packet exchange, or the phase!=0 jump.
    /// Returns the original cached menu value in ESI at this boundary. The
    /// caller's local pause and both player command buffers remain separate.
    public mutating func controlInput(commands: inout [UInt8], playbackCommands: [UInt8],
                                      context: inout OriginalInputControlContext,
                                      boundary: InputControlBoundary) throws -> Int32 {
        var state = self, output = commands, resources = context
        let menu = try state.runInputControl(commands: &output,playbackCommands: playbackCommands,context: &resources,boundary: boundary)
        self = state; commands = output; context = resources; return menu
    }

    private mutating func runInputControl(commands: inout [UInt8], playbackCommands: [UInt8],
                                          context: inout OriginalInputControlContext, boundary: InputControlBoundary) throws -> Int32 {
        guard commands.count == 10, playbackCommands.count == 10 else { throw Self.error("Control command extent") }
        if try global(0x450b90) != 0 { return try global(0x44d020) }
        func bits(_ value: Int32) -> UInt32 { UInt32(bitPattern: value) }
        func byte(_ address: Int) throws -> UInt8 { try globals.integer(at: address-Self.globalBase,as: UInt8.self) }
        func request(_ kind: OriginalInputControlRequest.Kind, _ args: [UInt32], _ data: [[UInt8]] = []) throws -> OriginalInputControlResponse {
            try boundary(.init(kind,args,data))
        }
        for socket in [0x44f1b4,0x44f46c] { _ = try request(.asyncSelect,[bits(global(socket)),bits(global(0x4546f4)),0,0]) }
        _ = try request(.ioctl,[bits(global(0x44f1b4)),0x8004667e,0]) // Actual null argp.
        let ioctl = try request(.ioctl,[bits(global(0x44f46c)),0x8004667e,1],[[0,0,0,0]])
        guard ioctl.bytes.isEmpty || ioctl.bytes.count == 4 else { throw Self.error("ioctl output extent") }
        // The OS-written scratch word is not read by this recovered path.
        var menu = try global(0x44d020)
        if try byte(0x44f1af) == 0 {
            let replayControls = try global(0x450b88) != 0
            if !replayControls {
                for (key,helper) in [(0x455471,0x416c70),(0x455470,0x416ca0)] where try byte(key) == 100 {
                    try globals.write(UInt8(117),at: key-Self.globalBase)
                    try inputControlAction(helper,commands: &commands,context: &context,boundary: boundary)
                }
                menu = try global(0x44d020)
                if try byte(0x4553eb) == 100, menu == 0 {
                    try globals.write(UInt8(117),at: 0x4553eb-Self.globalBase)
                    try inputControlAction(0x416cd0,commands: &commands,context: &context,boundary: boundary)
                    menu = try global(0x44d020)
                }
                for (key,helper) in [(0x4553e8,0x416dd0),(0x4553e9,0x416df0),(0x4553ea,0x416e10),(0x4553ec,0x416e30)] where try byte(key) == 100 && menu == 0 {
                    try globals.write(UInt8(117),at: key-Self.globalBase)
                    try inputControlAction(helper,commands: &commands,context: &context,boundary: boundary)
                }
                for (key,helper) in [(0x4553ed,0x416e60),(0x4553ee,0x416eb0),(0x4553ef,0x416f10),(0x4553f0,0x416f60)] where try byte(key) == 100 {
                    try globals.write(UInt8(117),at: key-Self.globalBase)
                    try inputControlAction(helper,commands: &commands,context: &context,boundary: boundary)
                }
            } else {
                if try byte(0x4553eb) == 100 {
                    try inputControlAction(0x416cd0,commands: &commands,context: &context,boundary: boundary)
                    _ = try boundary(.init(.inputReset)); try resetOriginalInput()
                }
                if try byte(0x4553ec) == 100 {
                    try globals.write(UInt8(117),at: 0x4553ec-Self.globalBase)
                    try inputControlAction(0x416e30,commands: &commands,context: &context,boundary: boundary)
                }
                for (mask,helper) in [(UInt8(1),0x416c70),(2,0x416ca0)] where playbackCommands[9] & mask != 0 {
                    try inputControlAction(helper,commands: &commands,context: &context,boundary: boundary)
                }
                for (key,helper) in [(0x4553e8,0x416dd0),(0x4553e9,0x416df0)] where try byte(key) == 100 {
                    try globals.write(UInt8(117),at: key-Self.globalBase)
                    try inputControlAction(helper,commands: &commands,context: &context,boundary: boundary)
                }
                for (mask,helper) in [(UInt8(4),0x416e10),(0x10,0x416e60),(0x20,0x416eb0),(0x40,0x416f10),(0x80,0x416f60)] where playbackCommands[8] & mask != 0 {
                    try inputControlAction(helper,commands: &commands,context: &context,boundary: boundary)
                }
                menu = try global(0x44d020)
            }
        }
        let network = try byte(0x44f1af)
        guard network == 1 || network == 2 else { return menu }
        for (key,offset,mask,requiresMenu) in [(0x455471,12,UInt8(8),false),(0x455470,12,0x10,false),
            (0x4553e8,10,2,true),(0x4553e9,10,0x40,true),(0x4553ea,12,2,true),(0x4553eb,10,4,true),
            (0x4553ec,10,8,true),(0x4553ed,10,0x10,true),(0x4553ee,10,0x20,true),(0x4553ef,12,4,true),(0x4553f0,10,0x80,true)] {
            if try byte(key) == 100, !requiresMenu || menu == 0 {
                try globals.write(byte(0x44d040+offset) | mask,at: 0x44d040+offset-Self.globalBase)
                try globals.write(UInt8(117),at: key-Self.globalBase)
            }
        }
        try setGlobal(0x450bf4,0)
        var sum: Int32 = 0
        for seat in 0..<20 where try byteFromWorld(4+seat) == 1 {
            let actor = try world.integer(at: 0x194+seat*4,as: UInt32.self)
            guard actor < actors.count else { throw Self.error("Control checksum Actor binding") }
            sum = try sum &+ actors[Int(actor)].integer(at: 0x2fc,as: Int32.self)
            try setGlobal(0x450bf4,sum)
        }
        let check = sum%100 &+ 1, sequence = try (global(0x450bf0) &+ 1)%50, catalogChecksum = try global(0x44f620)
        try setGlobal(0x450bf4,check); try setGlobal(0x450bf0,sequence)
        for (offset,value) in [(11,try global(0x44d03c)),(13,check),(9,sequence),(14,catalogChecksum%256),(15,(catalogChecksum/256)%256)] {
            try globals.write(UInt8(truncatingIfNeeded: value),at: 0x44d040+offset-Self.globalBase)
        }
        func sendPacket() throws {
            let packet = try (0..<22).map { try byte(0x44d040+$0) }
            _ = try request(.send,[bits(global(0x44f46c)),22,0],[packet])
        }
        if network == 1 { try sendPacket() }
        var received: UInt32 = 0, last: Int32 = 1
        repeat {
            let count = 22-received
            let response = try request(.receive,[bits(global(0x44f46c)),received,count,0])
            guard response.bytes.count <= count else { throw Self.error("Receive payload extent") }
            for (i,b) in response.bytes.enumerated() { try globals.write(b,at: 0x44f198-Self.globalBase+Int(received)+i) }
            last = response.result; received = received &+ bits(last)
        } while received < 22 && last > 0
        if network == 2 { try sendPacket() }
        // Each mismatch performs shutdown, posts close, then keeps executing.
        // Read later comparison globals again after every boundary.
        for (address,globalAddress,text) in [(0x44f1a1,0x450bf0,UInt32(0x4493b4)),
            (0x44f1a3,0x44d03c,network == 1 ? 0x44939c : 0x449324),(0x44f1a5,0x450bf4,0x449384)] {
            if try Int32(Int8(bitPattern: byte(address))) != global(globalAddress) { try inputControlFailure(text,context: &context,boundary: boundary) }
        }
        let currentChecksum = try global(0x44f620)
        if try byte(0x44f1a6) != UInt8(truncatingIfNeeded: currentChecksum%256)
            || byte(0x44f1a7) != UInt8(truncatingIfNeeded: (currentChecksum/256)%256) {
            try inputControlFailure(0x449340,context: &context,boundary: boundary)
        }
        for (offset,mask,helper) in [(10,UInt8(2),0x416dd0),(10,0x40,0x416df0),(10,4,0x416cd0),(10,8,0x416e30),
            (12,2,0x416e10),(12,8,0x416c70),(12,0x10,0x416ca0),(10,0x10,0x416e60),
            (10,0x20,0x416eb0),(12,4,0x416f10),(10,0x80,0x416f60)] {
            if try (byte(0x44f198+offset) | byte(0x44d040+offset)) & mask != 0 {
                try inputControlAction(helper,commands: &commands,context: &context,boundary: boundary)
            }
        }
        return try global(0x44d020)
    }

    private func byteFromWorld(_ offset: Int) throws -> UInt8 { try world.integer(at: offset,as: UInt8.self) }

    private mutating func inputControlFailure(_ text: UInt32, context: inout OriginalInputControlContext, boundary: InputControlBoundary) throws {
        _ = try boundary(.init(.message,[0,text,0x447850,0]))
        try OriginalMenuPresentation.shutdown(globals: &globals,memory: &context.memory,observe: { event in
            let kind: OriginalInputControlRequest.Kind
            switch event.kind { case .method:kind = .method; case .free:kind = .free; case .postMessage:kind = .postMessage; default:throw Self.error("Shutdown event") }
            _ = try boundary(.init(kind,event.arguments,event.strings))
        })
    }

    /// Shared original hotkey bodies416c70..416fad. Helper addresses identify
    /// recovered rules; no character-specific dispatch is involved.
    private mutating func inputControlAction(_ helper: Int, commands: inout [UInt8],
                                             context: inout OriginalInputControlContext, boundary: InputControlBoundary) throws {
        _ = try boundary(.init(.action,[UInt32(helper)],[commands]))
        switch helper {
        case 0x416c70,0x416ca0:
            let first = helper == 0x416c70, flag = first ? 0x458428 : 0x45842c, sound = first ? 0x455618 : 0x45561c
            commands[9] |= first ? 1 : 2; try setGlobal(flag,1 &- global(flag))
            try OriginalMatchPrelude.playSound(in: globals,slot: sound,observe: { event in
                switch event {
                case .soundRequest: _ = try boundary(.init(.soundRequest,[UInt32(sound),0]))
                case .soundMethod(let resource,let offset,let args): _ = try boundary(.init(.method,[resource,UInt32(offset)]+args))
                default: throw Self.error("Control sound event")
                }
            })
        case 0x416cd0:
            guard try global(0x44d020) == 0 else { return }
            for a in [0x450bfc,0x44fb60,0x44fcb0,0x450c2c] { try setGlobal(a,0) }; try setGlobal(0x44d02c,1)
            if try global(0x451160) != 5 && global(0x450be4) != 0 && global(0x450b80) != 0 {
                try setGlobal(0x450b80,0)
                if try global(0x450bdc) < 101 { try setGlobal(0x450b70,3); try setGlobal(0x450b6c,0) }
            }
            if try global(0x450b88) != 0 {
                try setGlobal(0x451160,6)
                if try context.memory.replayPointers.integer(at: 4,as: UInt32.self) != 0 {
                    _ = try boundary(.init(.restorePlayback)); try context.restorePlayback(globals: &globals)
                }
                for a in [0x450b88,0x450b84,0x450bdc] { try setGlobal(a,0) }; try setGlobal(0x44d020,10)
            } else if try [2,3].contains(global(0x451160)) {
                try setGlobal(0x450bdc,0); try setGlobal(0x44d020,10); try setGlobal(0x457580,0)
            } else { try setGlobal(0x450bdc,350) }
        case 0x416dd0:
            if try global(0x44d020) == 0 { let value = try 1 &- global(0x450bfc); try setGlobal(0x44fb60,value); try setGlobal(0x44fcb0,value) }
        case 0x416df0:
            if try global(0x44d020) == 0 { try setGlobal(0x44fcb0,1); try setGlobal(0x44fb60,0) }
        case 0x416e10:
            if try global(0x44d020) == 0 { commands[8] |= 4; try setGlobal(0x450c28,2) }
        case 0x416e30:
            if try global(0x44d020) == 0 { try globals.write(UInt8(117),at: 0x4553ec-Self.globalBase); try setGlobal(0x44d02c,1 &- global(0x44d02c)) }
        case 0x416e60,0x416eb0,0x416f10,0x416f60:
            guard try global(0x450c28) < 2, try global(0x451160) == 0 || global(0x45842c) == 1, try global(0x44d020) == 0 else { return }
            let mask: UInt8 = [0x416e60:0x10,0x416eb0:0x20,0x416f10:0x40,0x416f60:0x80][helper]!
            commands[8] |= mask
            if helper != 0x416e60, try global(0x450bdc) != 0 { return }
            let counter = [0x416e60:0x450c18,0x416eb0:0x450c1c,0x416f10:0x450c20,0x416f60:0x450c24][helper]!
            try setGlobal(counter,global(counter) &+ 1)
            if helper == 0x416e60 { try setGlobal(0x44d034,1 &- global(0x44d034)) }
            else if helper == 0x416eb0 { try setGlobal(0x450bc0,1 &- global(0x450bc0)) }
            else { try setGlobal(0x450bb8,helper == 0x416f10 ? 1 : 2) }
            try setGlobal(0x450c28,1)
        default: throw Self.error("Unknown control helper")
        }
    }
}
