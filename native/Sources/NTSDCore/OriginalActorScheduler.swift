import Foundation

public enum OriginalActorScheduleEvent: Equatable {
    case catalogSound(x: Int32, index: Int32)
}

/// Whole40d960..40de20. This call belongs inside the original per-slot lifecycle
/// loop, after drawing and before that slot's post-schedule creation/deletion.
/// Actor/global changes are staged together; enclosing ticks must buffer events.
public enum OriginalActorScheduler {
    public static func apply(actor: inout OriginalStateRecord, object: OriginalLoadedObject,
                             globals: inout OriginalStateRecord, mode: Int32, slot: Int32,
                             observe: (OriginalActorScheduleEvent) throws -> Void = { _ in }) throws {
        try apply(actor: &actor, header: object.header, globals: &globals, mode: mode, slot: slot, frame: { index in
            guard object.frameStorage.indices.contains(Int(index)) else {
                throw OriginalStateError.invalidStorage("Scheduler frame outside Object: \(index)")
            }
            return object.frameStorage[Int(index)]
        }, observe: observe)
    }

    static func apply(actor: inout OriginalStateRecord, header: OriginalStateRecord,
                      globals: inout OriginalStateRecord, mode: Int32, slot: Int32,
                      frame: (Int32) throws -> OriginalStateRecord,
                      observe: (OriginalActorScheduleEvent) throws -> Void = { _ in }) throws {
        var candidate = actor, owned = globals
        try withoutActuallyEscaping(frame) { frames in
            try withoutActuallyEscaping(observe) { observer in
                var body = Body(actor: candidate, globals: owned, header: header, mode: mode, slot: slot,
                                frame: frames, observe: observer)
                try body.run()
                candidate = body.actor; owned = body.globals
            }
        }
        actor = candidate; globals = owned
    }

    private struct Body {
        var actor: OriginalStateRecord, globals: OriginalStateRecord
        let header: OriginalStateRecord, mode: Int32, slot: Int32
        let frame: (Int32) throws -> OriginalStateRecord
        let observe: (OriginalActorScheduleEvent) throws -> Void
        func i(_ offset: Int) throws -> Int32 { try actor.integer(at: offset, as: Int32.self) }
        func b(_ offset: Int) throws -> UInt8 { try actor.integer(at: offset, as: UInt8.self) }
        func h(_ offset: Int) throws -> Int32 { try header.integer(at: offset, as: Int32.self) }
        func g(_ address: Int) throws -> Int32 { try globals.integer(at: address - OriginalMatchPreparation.globalBase, as: Int32.self) }
        func current(_ offset: Int) throws -> Int32 { try frame(i(0x70)).integer(at: offset, as: Int32.self) }
        mutating func set(_ offset: Int, _ value: Int32) throws { try actor.write(value, at: offset) }
        mutating func face(_ value: UInt8) throws { try actor.write(value, at: 0x80) }
        mutating func sound() throws {
            let index = try current(0x174)
            if index >= 0 {
                let x = try i(0x10)
                try OriginalGameplaySound.queueCatalog(x: x, index: index, globals: &globals)
                try observe(.catalogSound(x: x, index: index))
            }
        }
        mutating func jumpVelocity(_ destination: Int, _ source: Int, negative: Bool = false) throws {
            let value = try header.binary64(at: source)
            guard !value.isNaN else {
                throw OriginalStateError.invalidStorage("Scheduler x87 NaN load/store payload is outside the verified domain")
            }
            // Only fld/fchs/fstp: there is no arithmetic rounding operation.
            // Preserve finite, infinity and signed-zero bits through the store.
            try actor.writeBinary64(negative ? -value : value, at: destination)
        }
        mutating func run() throws {
            if try i(0xb4) != 0 && h(0x6f8) != 3 { return }
            if try i(0xec) > 0 { try set(0xec, i(0xec) &- 1) }
            if try i(0x98) < 0 { return }
            if try current(0x88) == 2 { return }
            if try h(0x6f8) == 3 && current(0x24) > 0 {
                try set(0x2fc, i(0x2fc) &- current(0x24))
                if try i(0x2fc) <= 0 {
                    try set(0x2fc, 0)
                    try set(0x70, current(0x28))
                }
            }
            if try i(8) > 0 { try set(8, i(8) &- 1) }
            if try i(8) < 0 { try set(8, i(8) &+ 1) }
            for offset in [0xb0, 0xb8] {
                if try i(offset) > 0 { try set(offset, i(offset) &- 1) }
            }
            let attackTimer = try actor.integer(at: 0xea, as: Int8.self)
            if attackTimer > 0 { try actor.write(attackTimer &- 1, at: 0xea) }
            if try i(0x70) != i(0x74) {
                try sound()
                try set(0x88, 0)
            }
            try set(0x88, i(0x88) &+ 1)
            if try h(0x6f8) >= 0 && current(8) == 0 && i(0x14) < 0 {
                try set(0x70, 212)
            }
            if try h(0x6f8) == 2 && current(8) == 2000 && i(0x14) == 0 {
                let vx = try actor.binary64(at: 0x40)
                if vx < 0.1 && vx > -0.1 { try set(0x70, 20) }
            }
            if try current(8) == 14 && i(0x2fc) <= 0 {
                if try i(0x2f4) >= 0 || i(0x364) == 5 || slot >= 20 {
                    if try i(8) <= 0 { try set(8, 30) }
                }
                try set(0x88, 0)
            }
            if try current(8) == 2000 {
                // fcomp/test/jp maps zero and unordered comparisons to facing1.
                try face(actor.binary64(at: 0x40) > 0 ? 0 : 1)
            }
            if try i(0x88) > current(0xc) {
                try set(0x88, 0)
                let next = try current(0x10)
                if next != 0 {
                    try set(0x70, next)
                    if next < 0 {
                        try face(1 &- b(0x80))
                        try set(0x70, 0 &- next)
                    }
                    var airReturn = false
                    if try i(0x70) == 999 {
                        airReturn = try i(0x14) != 0 && h(0x6f8) == 0
                        try set(0x70, airReturn ? 212 : 0)
                    }
                    // An invalid next returns with its written value/facing and
                    // WITHOUT updating previousFrame or the common tail counters.
                    if try i(0x70) < 0 || i(0x70) >= 400 { return }
                    if try frame(i(0x74)).integer(at: 8, as: Int32.self) == 14 && current(8) != 13 {
                        let category = try i(0x364)
                        let special = try category == 5 || i(0x344) != 0
                        var delay = true
                        if try special && g(0x450c30) == 2 { delay = false }
                        else if (mode == 1 || mode == 4) && special {
                            let sourceID = try h(0x6f4)
                            if sourceID / 10 == 3 && sourceID != 38 { delay = false }
                        }
                        if delay { try set(8, 15) }
                    }
                    if try i(0x70) == 212 && !airReturn {
                        try jumpVelocity(0x48, 0x50)
                        let right = try b(0xd0), left = try b(0xcf)
                        if right == 1 && left == 0 { try jumpVelocity(0x40, 0x58) }
                        else if left == 1 && right == 0 { try jumpVelocity(0x40, 0x58, negative: true) }
                        let up = try b(0xcd), down = try b(0xce)
                        if up != 0 && down == 0 { try jumpVelocity(0x50, 0x60, negative: true) }
                        else if up == 0 && down != 0 { try jumpVelocity(0x50, 0x60) }
                    }
                    try sound()
                    let cost = try current(0x4c)
                    if try cost < 0 && g(0x44d034) != 0 {
                        if try i(0x308) >= cost {
                            try set(0x308, i(0x308) &+ cost)
                            try set(0x350, i(0x350) &- current(0x4c))
                        } else {
                            try set(0x70, current(0x28))
                        }
                        let hitD = try current(0x28)
                        if hitD > 0 {
                            let left = try b(0xcf)
                            if try left == 1 && b(0xd0) == 0 && i(0x14) == 0 && b(0x80) == 0 {
                                try set(0x70, hitD)
                            }
                            if try left == 0 && b(0xd0) == 1 && i(0x14) == 0 && b(0x80) == 1 {
                                try set(0x70, current(0x28))
                            }
                        }
                    }
                }
            }
            let number = try i(0x70)
            if number == 110 || number == 114 { try actor.write(UInt8(3), at: 0xc1) }
            if number == 202 { try set(8, 20) }
            try set(0x74, number)
        }
    }
}
