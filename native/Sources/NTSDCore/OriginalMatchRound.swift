import Foundation

public enum OriginalMatchRoundContinuation: String, Codable, Sendable {
    case pausedRendering, gameplay, menu, epilogue
}

/// Observations, including real helpers and their COM requests. No observation
/// substitutes a game function; the original ignores these COM return values.
public struct OriginalMatchRoundEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case teams, stageScan, stopMusic, soundRequest, method, reconstruct, inputReset, restorePlayback
    }
    public let kind: Kind, arguments: [UInt32]
    public init(_ kind: Kind, _ arguments: [UInt32] = []) { self.kind = kind; self.arguments = arguments }
}

public struct OriginalMatchRoundResult {
    public let continuation: OriginalMatchRoundContinuation
    /// Caller local+64 on the unpaused path. Paused rendering has not assigned
    /// this local; the restoration loop reuses it and leaves zero on completion.
    public let stageDefeated: UInt32?
}

extension OriginalMatchPreparation {
    /// 41d714 through round control, ending at41d73b/41e339/4229cc/422a95.
    /// Paused rendering, gameplay, the menu body and caller epilogue are explicit
    /// continuations. The cached incoming menu is the preceding replay result.
    public mutating func beginMatchRound(paused: Bool, context: inout OriginalInputControlContext,
                                         observe: (OriginalMatchRoundEvent) throws -> Void = { _ in }) throws -> OriginalMatchRoundResult {
        var state = self, owned = context
        let result = try state.runMatchRound(paused: paused,context: &owned,observe: observe)
        self = state; context = owned; return result
    }

    private func roundActor(_ seat: Int) throws -> Int {
        guard (0..<400).contains(seat) else { throw Self.error("Round Actor seat") }
        let ordinal = try world.integer(at: 0x194+seat*4,as: UInt32.self)
        guard ordinal < actors.count else { throw Self.error("Round Actor binding") }
        return Int(ordinal)
    }

    private func roundObject(_ actor: Int) throws -> Int {
        let ordinal = try actors[actor].integer(at: 0x368,as: UInt32.self)
        guard ordinal < catalog.objects.count else { throw Self.error("Round Object binding") }
        return Int(ordinal)
    }

    private func roundTeam(_ seat: Int) throws -> Int? {
        guard try world.integer(at: 4+seat,as: UInt8.self) != 0 else { return nil }
        let actor = try roundActor(seat)
        guard try actors[actor].integer(at: 0x2fc,as: Int32.self) > 0,
              try catalog.objects[roundObject(actor)].header.integer(at: 0x6f8,as: Int32.self) == 0 else { return nil }
        let team = try actors[actor].integer(at: 0x364,as: Int32.self)
        return team > 0 && team < 40 && team != 5 ? Int(team) : nil
    }

    private func roundStopMusic(observe: (OriginalMatchRoundEvent) throws -> Void) throws {
        try observe(.init(.stopMusic))
        try OriginalMusicPlayback.stop(globals: globals) { event in
            guard event.kind == .method else { throw Self.error("Round music method") }
            try observe(.init(.method,event.arguments));return .init()
        }
    }

    private func roundSound(observe: (OriginalMatchRoundEvent) throws -> Void) throws {
        try OriginalMatchPrelude.playSound(in: globals,slot: 0x45561c) { event in
            switch event {
            case .soundRequest: try observe(.init(.soundRequest,[0x45561c,0]))
            case let .soundMethod(resource,offset,arguments): try observe(.init(.method,[resource,UInt32(offset)]+arguments))
            default: throw Self.error("Round sound event")
            }
        }
    }

    private mutating func runMatchRound(paused: Bool, context: inout OriginalInputControlContext,
                                        observe: (OriginalMatchRoundEvent) throws -> Void) throws -> OriginalMatchRoundResult {
        try setGlobal(0x450c00,global(0x450bfc) == 2 ? 1 : 0)
        if paused { return .init(continuation: .pausedRendering,stageDefeated: nil) }
        if try global(0x450bfc) == 2 { try setGlobal(0x450bfc,1) }
        try setGlobal(0x450bd8,1 &- global(0x450bd8))
        try setGlobal(0x450bd0,(global(0x450bd0) &+ 1)%12)
        try setGlobal(0x450bd4,(global(0x450bd4) &+ 1)%3)
        var defeated: UInt32 = 0
        let mode = try global(0x451160)
        if mode != 1 {
            var teams = [Int32](repeating: 0,count: 40)
            for seat in 0..<400 { if let team = try roundTeam(seat) { teams[team] &+= 1 } }
            var living = 0
            for team in 0..<40 where teams[team] > 0 {
                living += 1; try setGlobal(0x450bf8,Int32(team))
            }
            try observe(.init(.teams,teams.map { UInt32(bitPattern: $0) }))
            if try living < 2 && global(0x44d020) == 0 && (global(0x451b7c) == 1 || mode != 4) {
                if living == 0 { try setGlobal(0x450bf8,-1) }
                try setGlobal(0x450bdc,global(0x450bdc) &+ 1)
                if try global(0x450bdc) == 80 {
                    if ![Int32(0),2,3,4,5].contains(mode) { try roundStopMusic(observe: observe) }
                    if mode != 5 { try setGlobal(0x44d02c,1) }
                    try roundSound(observe: observe)
                }
            } else if mode != 2 && mode != 3 { try setGlobal(0x450bf8,-1) }
        } else if try global(0x44d020) == 0 {
            defeated = 1
            // The original scans all400 seats even after finding a survivor.
            for seat in 0..<400 { if try roundTeam(seat) != nil { defeated = 0 } }
            try observe(.init(.stageScan,[defeated]))
            let stage = try global(0x450ba8)
            if defeated == 1 || stage > 0 {
                try setGlobal(0x450bdc,global(0x450bdc) &+ 1)
                if try stage <= 0 && global(0x450bdc) == 80 {
                    try setGlobal(0x44d02c,1); try roundStopMusic(observe: observe); try roundSound(observe: observe)
                }
            }
        }
        var timer = try global(0x450bdc)
        if try timer == 145 && global(0x450c2c) == 0 { timer = 144; try setGlobal(0x450bdc,timer) }
        if timer >= 350 {
            try restoreRoundActors(observe: observe)
            try setGlobal(0x44d020,mode == 2 ? 28 : mode == 3 ? 128 : mode == 4 ? 202 : 2)
            try setGlobal(0x450bdc,0)
            try observe(.init(.inputReset)); try resetOriginalInput()
            if try global(0x450b88) != 0 && global(0x44d020) != 10 {
                try setGlobal(0x451160,6)
                if try context.memory.replayPointers.integer(at: 4,as: UInt32.self) != 0 {
                    try observe(.init(.restorePlayback)); try context.restorePlayback(globals: &globals)
                }
                try setGlobal(0x450b88,0); try setGlobal(0x450b84,0); try setGlobal(0x44d020,10)
            }
            return .init(continuation: .epilogue,stageDefeated: 0)
        }
        if try global(0x44d020) != 0 { return .init(continuation: .menu,stageDefeated: defeated) }
        if timer >= 144 {
            var stage = try global(0x450ba8), automatic = try global(0x450c2c), stageIndex = try global(0x450b94)
            // These eight seats are read regardless of activity, HP and status.
            for seat in 0..<8 {
                let actor = try roundActor(seat)
                guard try actors[actor].integer(at: 0xd1,as: UInt8.self) == 1 || actors[actor].integer(at: 0xd2,as: UInt8.self) == 1 else { continue }
                if automatic == 0 && mode == 1 && stage == 1 {
                    stage = 3; try setGlobal(0x450ba8,stage); continue
                }
                if mode == 1 && stage != 2 && stage != 0 { continue }
                stageIndex = (stageIndex/10) &* 10
                try setGlobal(0x450b94,stageIndex); try setGlobal(0x450bdc,350)
                automatic = 0; try setGlobal(0x450c2c,automatic)
            }
        }
        return .init(continuation: .gameplay,stageDefeated: defeated)
    }

    /// Whole41ddf2..41e0e1, with live seat/Actor accesses. A later seat can see
    /// an Actor activated or reconstructed earlier in this same400-seat loop.
    private mutating func restoreRoundActors(observe: (OriginalMatchRoundEvent) throws -> Void) throws {
        guard let registry = catalog.registry.records[0x4d82380] else { throw Self.error("Round catalog count") }
        let count = try registry.integer(at: 0,as: Int32.self)
        guard count >= 0 && count <= catalog.objects.count else { throw Self.error("Round catalog extent") }
        func sourceID(_ ordinal: Int) throws -> Int32 { try catalog.objects[ordinal].header.integer(at: 0x6f4,as: Int32.self) }
        func firstObject(_ id: Int32) throws -> Int? {
            for ordinal in 0..<Int(count) where try sourceID(ordinal) == id { return ordinal }; return nil
        }
        for seat in 0..<400 where try world.integer(at: 4+seat,as: UInt8.self) != 0 {
            let actor = try roundActor(seat)
            let previous = try actors[actor].integer(at: 0x324,as: Int32.self)
            if previous > -1 {
                if let ordinal = try firstObject(previous) {
                    try actors[actor].write(UInt32(ordinal),at: 0x368); try actors[actor].write(Int32(-1),at: 0x324)
                }
                continue
            }
            if try sourceID(roundObject(actor)) == 50 && global(0x458428) == 0 {
                if let ordinal = try firstObject(6) { try actors[actor].write(UInt32(ordinal),at: 0x368) }
                continue
            }
            guard try actors[actor].integer(at: 0x328,as: Int32.self) > -1 else { continue }
            let targetSeat = Int(try actors[actor].integer(at: 0x32c,as: Int32.self))
            _ = try roundActor(targetSeat)
            try actors[actor].write(Int32(-1),at: 0x328); try actors[actor].write(Int32(900),at: 0x338)
            for ordinal in 0..<Int(count) {
                let id = try sourceID(ordinal)
                // Re-read these fields after every constructor: the target may
                // alias the source Actor, which changes the later comparisons.
                if try id == actors[actor].integer(at: 0x330,as: Int32.self) {
                    try actors[actor].write(UInt32(ordinal),at: 0x368)
                } else if try id == actors[actor].integer(at: 0x334,as: Int32.self) {
                    let target = try roundActor(targetSeat)
                    try observe(.init(.reconstruct,[UInt32(target)])); try actors[target].reconstructActor()
                    try actors[target].write(UInt32(ordinal),at: 0x368)
                    try actors[target].write(catalog.objects[ordinal].header.integer(at: 0x90,as: UInt32.self),at: 0x31c)
                    for (offset,value) in [(0x58,580.0),(0x60,-200.0),(0x68,300.0)] { try actors[target].writeBinary64(value,at: offset) }
                    try world.write(UInt8(1),at: 4+targetSeat)
                }
            }
            // Preserve the order of these reads/writes, including self-aliasing.
            for offset in [0x2fc,0x300] {
                let half = try actors[actor].integer(at: offset,as: Int32.self)/2
                try actors[roundActor(targetSeat)].write(half,at: offset)
            }
            for offset in [0x2fc,0x300] { try actors[actor].write(actors[actor].integer(at: offset,as: Int32.self)/2,at: offset) }
            for offset in [0x10,0x18] {
                let value = try actors[actor].integer(at: offset,as: Int32.self)
                try actors[roundActor(targetSeat)].write(value,at: offset)
            }
            var target = try roundActor(targetSeat)
            try actors[target].write(Int32(0),at: 0x14)
            for (source,destination) in [(0x10,0x58),(0x18,0x68)] {
                target = try roundActor(targetSeat)
                try actors[target].writeBinary64(Double(actors[target].integer(at: source,as: Int32.self)),at: destination)
            }
            try actors[roundActor(targetSeat)].writeBinary64(0,at: 0x60)
            try actors[actor].writeBinary64(0,at: 0x40); try actors[roundActor(targetSeat)].writeBinary64(0,at: 0x40)
            let facing = try UInt8(1) &- actors[actor].integer(at: 0x80,as: UInt8.self)
            try actors[roundActor(targetSeat)].write(facing,at: 0x80)
            try actors[actor].write(Int32(112),at: 0x70); try actors[roundActor(targetSeat)].write(Int32(112),at: 0x70)
            try actors[actor].write(Int32(0),at: 0x308); try actors[roundActor(targetSeat)].write(Int32(0),at: 0x308)
            let team = try actors[actor].integer(at: 0x364,as: Int32.self)
            try actors[roundActor(targetSeat)].write(team,at: 0x364)
        }
    }
}
