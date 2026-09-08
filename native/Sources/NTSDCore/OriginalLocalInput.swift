import Foundation

public struct OriginalLocalInputDispatch: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case characterAI, objectInput }
    public let kind: Kind, arguments: [UInt32]
    public init(_ kind: Kind, slot: Int, mode: Int32) {
        self.kind = kind
        arguments = kind == .characterAI ? [UInt32(slot),UInt32(bitPattern: mode)] : [UInt32(slot)]
    }
}

extension OriginalMatchPreparation {
    /// Caller41c581..41c5e5. The network template is copied even while paused.
    /// Commands are the first10-byte local buffer; the second buffer is untouched.
    public mutating func beginLocalInput(paused: Bool, commands: inout [UInt8],
                                        beforeDispatch: (Self, [UInt8]) throws -> Void = { _, _ in },
                                        dispatch: (OriginalLocalInputDispatch, inout Self) throws -> Void = { _, _ in
                                            throw OriginalStateError.invalidStorage("Local-input AI/object child has not been supplied")
                                        }) throws {
        var candidate = self, output = commands
        for i in 0..<21 { try candidate.globals.write(UInt8(i == 20 ? 0 : 1),at: 0x44d040-Self.globalBase+i) }
        if !paused {
            let phase = try candidate.globals.integer(at: 0x450b90-Self.globalBase,as: Int32.self)
            let mode = try candidate.globals.integer(at: 0x451160-Self.globalBase,as: Int32.self)
            try candidate.localInput(phase: phase,mode: mode,commands: &output,beforeDispatch: beforeDispatch,dispatch: dispatch)
        }
        self = candidate; commands = output
    }

    /// Real419a60 caller rules. Keyboard/joystick bytes are already acquired
    /// platform state. The AI children remain explicit mechanisms to implement.
    public mutating func localInput(phase: Int32, mode: Int32, commands: inout [UInt8],
                                    beforeDispatch: (Self, [UInt8]) throws -> Void = { _, _ in },
                                    dispatch: (OriginalLocalInputDispatch, inout Self) throws -> Void = { _, _ in
                                        throw OriginalStateError.invalidStorage("Local-input AI/object child has not been supplied")
                                    }) throws {
        guard commands.count == 10, world.bytes.count == OriginalStateRecord.worldPrefixSize,
              actors.count == 400, actors.allSatisfy({ $0.bytes.count == OriginalStateRecord.actorSize }),
              globals.bytes.count == Self.globalSize else { throw OriginalStateError.invalidStorage("Local-input storage") }
        var candidate = self, output = commands
        func integer(_ address: Int) throws -> Int32 { try candidate.globals.integer(at: address-Self.globalBase,as: Int32.self) }
        func byte(_ address: UInt32) throws -> UInt8 {
            guard address >= Self.globalBase, address < Self.globalBase+Self.globalSize else {
                throw OriginalStateError.invalidStorage("Input mapping points outside recovered globals")
            }
            return try candidate.globals.integer(at: Int(address)-Self.globalBase,as: UInt8.self)
        }
        func actor(_ slot: Int) throws -> Int {
            let index = try candidate.world.integer(at: 0x194+slot*4,as: UInt32.self)
            guard index < 400 else { throw OriginalStateError.invalidStorage("Input Actor-table binding") }
            return Int(index)
        }
        let masks: [UInt8] = [0x80,0x40,0x20,0x10,8,4,2]
        if try integer(0x450b84) == 0 {
            for seat in 0..<8 {
                let status = try integer(0x450b4c+seat*4)
                guard status > 0 else { continue }
                for button in 0..<7 {
                    let a = try actor(seat)
                    try candidate.actors[a].write(candidate.actors[a].integer(at: 0xcd+button,as: UInt8.self),at: 0xc6+button)
                }
                guard phase == 0 else { continue }
                for button in (0..<7).reversed() { try candidate.actors[actor(seat)].write(UInt8(0),at: 0xcd+button) }
                if (1...4).contains(status) {
                    let config = 0x44fb20+Int(status)*80, device = try integer(config)
                    if device >= 0 {
                        for button in 0..<7 {
                            let pressed: Bool
                            if device == 0 {
                                let key = UInt32(bitPattern: try integer(config+4+button*4))
                                pressed = try byte(0x455378 &+ key) == 100
                            } else {
                                let joystick = (UInt32(bitPattern: device) &* 3 &- 3) &* 16
                                let offset: UInt32
                                if button < 4 { offset = [0,1,3,2][button] }
                                else { offset = 4 &+ UInt32(bitPattern: try integer(config+0x20+(button-4)*4)) }
                                pressed = try byte(0x453ff0 &+ joystick &+ offset) != 0
                            }
                            if pressed {
                                try candidate.actors[actor(seat)].write(UInt8(1),at: 0xcd+button)
                                if try integer(0x450b80) != 0 { output[seat] |= masks[button] }
                            }
                        }
                    }
                }
                if Int8(bitPattern: try byte(0x44f1af)) > 0 {
                    for button in 0..<7 where try candidate.actors[actor(seat)].integer(at: 0xcd+button,as: UInt8.self) != 0 {
                        let at = 0x44d040-Self.globalBase+seat
                        try candidate.globals.write(candidate.globals.integer(at: at,as: UInt8.self) | masks[button],at: at)
                    }
                }
            }
        }
        try beforeDispatch(candidate,output)
        // The original tail runs in either phase and even during playback.
        // Read current state after each child, rather than queueing stale requests.
        for slot in 10..<400 {
            guard try candidate.world.integer(at: 4+slot,as: UInt8.self) != 0 else { continue }
            let a = try actor(slot), object = try candidate.actors[a].integer(at: 0x368,as: UInt32.self)
            guard object < candidate.catalog.objects.count else { throw OriginalStateError.invalidStorage("Input Object binding") }
            let source = candidate.catalog.objects[Int(object)]
            let kind: OriginalLocalInputDispatch.Kind
            if try source.header.integer(at: 0x6f8,as: Int32.self) == 0 { kind = .characterAI }
            else {
                let frame = try candidate.actors[a].integer(at: 0x70,as: UInt32.self)
                guard frame < 400 else { throw OriginalStateError.invalidStorage("Input Frame outside source storage") }
                guard try source.frameStorage[Int(frame)].integer(at: 0x30,as: Int32.self) > 0 else { continue }
                kind = .objectInput
            }
            try dispatch(.init(kind,slot: slot,mode: mode),&candidate)
        }
        self = candidate; commands = output
    }
}
