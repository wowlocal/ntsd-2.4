import Foundation

public enum OriginalReplayTickEntry: String, Codable, Sendable {
    case playbackChecksum, recording
}

/// Observations of real replay operations; only MessageBox's result is supplied
/// by the platform. Observations never replace packet/checksum/reset helpers.
public struct OriginalReplayTickEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case readPacket, writePacket, readChecksum, writeChecksum, message, inputReset, restorePlayback
    }
    public let kind: Kind, arguments: [UInt32], data: [[UInt8]]
    public init(_ kind: Kind, _ arguments: [UInt32] = [], _ data: [[UInt8]] = []) {
        self.kind = kind; self.arguments = arguments; self.data = data
    }
}

extension OriginalInputControlContext {
    /// Original address arithmetic wraps before accessing an owned allocation.
    /// Negative or wrapped ticks may address metadata inside the same buffer.
    /// An address outside that allocation is unsupported, never silently clamped.
    private func replayRange(pointerOffset: Int, offset: UInt32, count: Int) throws -> (UInt32, Int) {
        let pointer = try memory.replayPointers.integer(at: pointerOffset,as: UInt32.self)
        guard pointer != 0, let allocation = memory.allocations[pointer], allocation.live else {
            throw OriginalStateError.invalidStorage("Replay tick buffer ownership")
        }
        let address = pointer &+ offset
        guard address >= pointer, UInt64(address)+UInt64(count) <= UInt64(pointer)+UInt64(allocation.storage.bytes.count) else {
            throw OriginalStateError.invalidStorage("Replay tick address outside owned allocation")
        }
        return (pointer,Int(address-pointer))
    }

    /// Whole43dc50, with the caller's separate ten-byte output value.
    public func replayPacket(tick: Int32, observe: (OriginalReplayTickEvent) throws -> Void = { _ in }) throws -> [UInt8] {
        let offset = UInt32(bitPattern: tick) &* 10 &+ 0x2b38
        let (pointer,index) = try replayRange(pointerOffset: 4,offset: offset,count: 10)
        try observe(.init(.readPacket,[UInt32(bitPattern: tick),pointer]))
        return try (0..<10).map { try memory.allocations[pointer]!.storage.integer(at: index+$0,as: UInt8.self) }
    }

    /// Whole43db40. The command region can overlap saved metadata/checksums;
    /// do not substitute an independent Swift array of replay frames.
    mutating func recordReplayPacket(tick: Int32, commands: [UInt8], observe: (OriginalReplayTickEvent) throws -> Void) throws {
        guard commands.count == 10 else { throw OriginalStateError.invalidStorage("Replay packet extent") }
        let offset = UInt32(bitPattern: tick) &* 10 &+ 0x2b38
        let (pointer,index) = try replayRange(pointerOffset: 0,offset: offset,count: 10)
        try observe(.init(.writePacket,[UInt32(bitPattern: tick),pointer],[commands]))
        for (i,byte) in commands.enumerated() { try memory.allocations[pointer]!.storage.write(byte,at: index+i) }
    }

    func replayChecksum(tick: Int32, sum: Int32, observe: (OriginalReplayTickEvent) throws -> Void) throws -> Int32 {
        let offset = UInt32(bitPattern: tick/150) &* 4 &+ 0x14b8
        let (pointer,index) = try replayRange(pointerOffset: 4,offset: offset,count: 4)
        let stored = try memory.allocations[pointer]!.storage.integer(at: index,as: Int32.self)
        try observe(.init(.readChecksum,[pointer,offset,UInt32(bitPattern: sum),UInt32(bitPattern: stored)]))
        return stored
    }

    mutating func recordReplayChecksum(tick: Int32, sum: Int32, observe: (OriginalReplayTickEvent) throws -> Void) throws {
        let offset = UInt32(bitPattern: tick/150) &* 4 &+ 0x14b8
        let (pointer,index) = try replayRange(pointerOffset: 0,offset: offset,count: 4)
        try observe(.init(.writeChecksum,[pointer,offset,UInt32(bitPattern: sum)]))
        try memory.allocations[pointer]!.storage.write(sum,at: index)
    }
}

extension OriginalMatchPreparation {
    /// 41bdce..41be8b: reset BOTH ten-byte buffers, then read43dc50 only for
    /// unpaused playback. Earlier playback-camera/hotkey branches are separate.
    public func prepareReplayCommands(paused: Bool, commands: inout [UInt8], playbackCommands: inout [UInt8],
                                      context: OriginalInputControlContext,
                                      observe: (OriginalReplayTickEvent) throws -> Void = { _ in }) throws {
        guard commands.count == 10, playbackCommands.count == 10 else { throw Self.error("Replay command extent") }
        let output = [UInt8](repeating: 0,count: 10)
        let playback = try global(0x450b84) != 0 && !paused
            ? context.replayPacket(tick: global(0x450b8c),observe: observe) : output
        commands = output; playbackCommands = playback
    }

    /// 41d4b7/41d5db..41d714. Entry is the actual continuation returned by
    /// receiveInput. Paused is the caller's local state, not the pause queue.
    /// No pause/menu processing after41d714 is implied by returning here.
    public mutating func finishReplayInput(entry: OriginalReplayTickEntry, paused: Bool,
                                           commands: [UInt8], playbackCommands: [UInt8],
                                           context: inout OriginalInputControlContext,
                                           observe: (OriginalReplayTickEvent) throws -> Void = { _ in }) throws {
        var state = self, owned = context
        try state.runReplayInput(entry: entry,paused: paused,commands: commands,playbackCommands: playbackCommands,context: &owned,observe: observe)
        self = state; context = owned
    }

    private func replayHitPointSum() throws -> Int32 {
        var sum: Int32 = 0
        for seat in 0..<20 where try world.integer(at: 4+seat,as: UInt8.self) == 1 {
            let actor = try world.integer(at: 0x194+seat*4,as: UInt32.self)
            guard actor < actors.count else { throw Self.error("Replay checksum Actor binding") }
            sum = try sum &+ actors[Int(actor)].integer(at: 0x2fc,as: Int32.self)
        }
        return sum
    }

    private mutating func runReplayInput(entry: OriginalReplayTickEntry, paused: Bool, commands: [UInt8], playbackCommands: [UInt8],
                                         context: inout OriginalInputControlContext, observe: (OriginalReplayTickEvent) throws -> Void) throws {
        guard commands.count == 10, playbackCommands.count == 10 else { throw Self.error("Replay command extent") }
        if entry == .playbackChecksum {
            let tick = try global(0x450b8c)
            if tick%150 == 0 {
                let sum = try replayHitPointSum()
                if try context.replayChecksum(tick: tick,sum: sum,observe: observe) != sum {
                    try observe(.init(.message,[0,0x4492f8,0,0]))
                    try observe(.init(.inputReset)); try resetOriginalInput()
                    if try global(0x450b84) != 0 && global(0x44d020) != 10 {
                        try setGlobal(0x451160,6)
                        if try context.memory.replayPointers.integer(at: 4,as: UInt32.self) != 0 && global(0x450b88) != 0 {
                            try observe(.init(.restorePlayback)); try context.restorePlayback(globals: &globals)
                        }
                        try setGlobal(0x450b88,0); try setGlobal(0x450b84,0); try setGlobal(0x44d020,10)
                    }
                }
            }
        }
        guard !paused else { return }
        if try global(0x450b80) != 0 {
            let tick = try global(0x450b8c)
            let packet = try global(0x450b84) != 0 ? playbackCommands : commands
            try context.recordReplayPacket(tick: tick,commands: packet,observe: observe)
            if tick%150 == 0 { try context.recordReplayChecksum(tick: tick,sum: replayHitPointSum(),observe: observe) }
        }
        let tick = try global(0x450b8c)
        if tick < 0x9e33f { try setGlobal(0x450b8c,min(tick &+ 1,0x9e33f)) }
        else {
            try setGlobal(0x450b8c,0x9e33f)
            if try global(0x450b80) != 0 {
                try setGlobal(0x450b80,0)
                try observe(.init(.message,[0,0x4492b8,0,0]))
            }
        }
    }
}
