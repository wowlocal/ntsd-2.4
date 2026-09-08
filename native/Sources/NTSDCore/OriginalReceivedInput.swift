import Foundation

/// The following caller stage is deliberately explicit: playback checksum and
/// per-tick recording are separate original mechanisms, not implied by decoding.
public enum OriginalReceivedInputContinuation: String, Codable, Sendable {
    case playbackChecksum, recording
}

extension OriginalMatchPreparation {
    /// 41d469..41d4b7 (playback) or41d5db (no playback/paused), after the
    /// phase0 network/hotkey path has produced44f198 and the local pause value.
    public mutating func receiveInput(paused: Bool, commands: inout [UInt8], playbackCommands: [UInt8],
                                     afterRemote: (Self, [UInt8]) throws -> Void = { _, _ in }) throws -> OriginalReceivedInputContinuation {
        if paused { return .recording }
        var candidate = self, output = commands
        let phase = try candidate.globals.integer(at: 0x450b90-Self.globalBase,as: Int32.self)
        let packet = try (0..<10).map { try candidate.globals.integer(at: 0x44f198-Self.globalBase+$0,as: UInt8.self) }
        try candidate.remoteInput(packet: packet,phase: phase,commands: &output)
        try afterRemote(candidate,output)
        let playback = try candidate.globals.integer(at: 0x450b84-Self.globalBase,as: Int32.self) != 0
        if playback { try candidate.playbackInput(packet: playbackCommands,phase: phase) }
        self = candidate; commands = output
        return playback ? .playbackChecksum : .recording
    }

    /// 4198f0/ret12. Only status==-1 seats receive network input. Recording
    /// replaces the entire packet byte, including bit0; it does not OR buttons.
    public mutating func remoteInput(packet: [UInt8], phase: Int32, commands: inout [UInt8]) throws {
        guard commands.count == 10 else { throw OriginalStateError.invalidStorage("Remote command extent") }
        var candidate = self, output = commands
        try candidate.applyReceivedInput(packet: packet,phase: phase,remote: true,commands: &output)
        self = candidate; commands = output
    }

    /// 4197a0/ret8. Playback visits all eight seats, ignoring status/activity.
    public mutating func playbackInput(packet: [UInt8], phase: Int32) throws {
        var candidate = self, unused: [UInt8] = []
        try candidate.applyReceivedInput(packet: packet,phase: phase,remote: false,commands: &unused)
        self = candidate
    }

    private mutating func applyReceivedInput(packet: [UInt8], phase: Int32, remote: Bool, commands: inout [UInt8]) throws {
        guard packet.count == 10, world.bytes.count == OriginalStateRecord.worldPrefixSize,
              actors.count == 400, globals.bytes.count == Self.globalSize else {
            throw OriginalStateError.invalidStorage("Received-input storage")
        }
        let masks: [UInt8] = [0x80,0x40,0x20,0x10,8,4,2]
        for seat in 0..<8 {
            if remote, try globals.integer(at: 0x450b4c-Self.globalBase+seat*4,as: Int32.self) != -1 { continue }
            let index = try world.integer(at: 0x194+seat*4,as: UInt32.self)
            guard index < actors.count else { throw OriginalStateError.invalidStorage("Received-input Actor binding") }
            let a = Int(index)
            // Resolve every seat in order. Multiple slots can refer to one Actor;
            // the later seat observes the earlier seat's new current buttons.
            for button in 0..<7 {
                try actors[a].write(actors[a].integer(at: 0xcd+button,as: UInt8.self),at: 0xc6+button)
            }
            guard phase == 0 else { continue }
            for button in (0..<7).reversed() { try actors[a].write(UInt8(0),at: 0xcd+button) }
            for button in 0..<7 where packet[seat] & masks[button] != 0 { try actors[a].write(UInt8(1),at: 0xcd+button) }
            if remote, try globals.integer(at: 0x450b80-Self.globalBase,as: Int32.self) != 0 { commands[seat] = packet[seat] }
        }
    }
}
