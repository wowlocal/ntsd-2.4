import Foundation

public enum OriginalMatchContinuationEvent {
    case state(OriginalMatchPreparationEvent)
    case device(OriginalMatchPreludeEvent)
    case musicSelection
    case candidates(seat: Int, ordinals: [Int])
}

extension OriginalMatchPreparation {
    /// Original 42d704..42e0d2 state effects. Confirmation is the original menu
    /// stack local, not a newly interpreted keyboard action. Native execution
    /// needs no SEH/cookie wrapper; the oracle separately checks the real return.
    public mutating func continueMenu(confirmation: Int32, bitmapFill: UInt8 = 0xa5,
                                      bitmapSource: (String) throws -> OriginalBitmapInput,
                                      observe: (OriginalMatchContinuationEvent) throws -> Void = { _ in }) throws {
        var candidate = self
        try candidate.consumeContinuation(confirmation: confirmation, bitmapFill: bitmapFill,
                                           bitmapSource: bitmapSource, observe: observe)
        self = candidate
    }

    private mutating func consumeContinuation(confirmation: Int32, bitmapFill: UInt8,
                                               bitmapSource: (String) throws -> OriginalBitmapInput,
                                               observe: (OriginalMatchContinuationEvent) throws -> Void) throws {
        guard actors.count == 400, backgrounds.count == 101 else { throw Self.error("Continuation storage") }
        let mode = try global(0x451160), action = try global(0x44d06c)
        let count = try catalog.registry.records[0x4d82380]!.integer(at: 4, as: Int32.self)
        guard (0...99).contains(count) else { throw Self.error("Continuation BG count") }
        releasedBitmapOrder = []
        var random = OriginalRandom(table: try (0..<3000).map { try globals.integer(at: 0x44ff90-Self.globalBase+$0, as: UInt8.self) },
                                    index: Int(try global(0x450bcc)), counter: Int(try global(0x450c34)),
                                    source: "supplied menu continuation", sourceSHA256: "")
        try random.validate()
        func draw(_ stream: Int32, _ range: Int32) throws -> Int32 {
            let bi = random.index, bc = random.counter
            let value = Int32(random.next(Int(range)))
            try observe(.state(.random(stream: stream, range: range, result: value, beforeIndex: bi,
                                       beforeCounter: bc, index: random.index, counter: random.counter)))
            return value
        }
        func sound() throws {
            try OriginalMatchPrelude.confirmationSound(in: globals) { try observe(.device($0)) }
        }
        func choices() throws -> [Int] {
            let selected = try Set((0..<8).map { try global(0x451248+$0*4) })
            return try catalog.objects.indices.dropFirst().filter { ordinal in
                let object = catalog.objects[ordinal].header
                return try object.integer(at: 0x6f8, as: Int32.self) == 0
                    && object.integer(at: 0x6f4, as: Int32.self) < 30 && !selected.contains(Int32(ordinal))
            }
        }
        if confirmation != 0 {
            if action == 4 {
                var difficulty = try global(0x450c30) &- 1
                if try difficulty < 0 && global(0x458428) == 0 || difficulty < -1 { difficulty = 2 }
                try setGlobal(0x450c30, difficulty)
                try sound()
            }
            if action == 5 {
                try sound()
                try setGlobal(0x44d020, 10); try setGlobal(0x457580, 0)
                try observe(.state(.resetInput)); try resetOriginalInput()
            }
        }
        if try global(0x450c2c) == 1 {
            try observe(.musicSelection)
            guard try global(0x44d010) == 0 else { throw Self.error("Enabled 4025d0 music selection") }
            try setGlobal(0x44d020, 0)
            for slot in 0..<400 { try world.write(UInt8(0), at: 4+slot) }
            try setGlobal(0x44d028, 1)
            var background = try draw(0xe0, count &- 2)
            if background == count &- 3 { background = 99 }
            guard (0..<count).contains(background) || background == 99 else { throw Self.error("Continuation arena") }
            try setGlobal(0x44d024, background)
            for seat in 0..<8 {
                let candidates = try choices()
                guard !candidates.isEmpty else { throw Self.error("Empty random roster requires original stack scratch provenance") }
                try observe(.candidates(seat: seat, ordinals: candidates))
                let ordinal = candidates[Int(try draw(0xe1, Int32(candidates.count)))]
                try setGlobal(0x451248+seat*4, Int32(ordinal))
                try actors[seat].write(UInt32(ordinal), at: 0x368)
            }
            try setGlobal(0x450c2c, 1)
            let arena = backgrounds[Int(background)]
            let width = try arena.integer(at: 0, as: Int32.self)
            let lower = try arena.integer(at: 4, as: Int32.self), upper = try arena.integer(at: 8, as: Int32.self)
            for slot in 10..<18 {
                let ordinal = Int(try actors[slot-10].integer(at: 0x368, as: UInt32.self))
                try observe(.state(.reconstruct(slot))); try actors[slot].reconstructActor()
                try actors[slot].write(UInt32(ordinal), at: 0x368)
                try actors[slot].write(catalog.objects[ordinal].header.integer(at: 0x90, as: UInt32.self), at: 0x31c)
                try actors[slot].write(Int32(75), at: 8)
                let x = try draw(0xe2, width/2) &+ (width/4), z = try draw(0xe3, upper &- lower) &+ lower
                try actors[slot].write(x, at: 0x10); try actors[slot].write(z, at: 0x18)
                try actors[slot].writeBinary64(Double(x), at: 0x58); try actors[slot].writeBinary64(0, at: 0x60)
                try actors[slot].writeBinary64(Double(z), at: 0x68)
                try actors[slot].write(Int32(200), at: 0x308); try actors[slot].write(Int32(slot), at: 0x354)
            }
            let teamPattern = try draw(0xe4, 30)
            if teamPattern < 7 {
                try world.write(UInt8(1), at: 14); try actors[10].write(Int32(0), at: 0x364)
                for slot in 11..<18 {
                    try actors[slot].write(draw(0xe5, 5), at: 0x364); try world.write(UInt8(1), at: 4+slot)
                }
            } else if teamPattern < 18 {
                for slot in 10..<18 {
                    try actors[slot].write(Int32(slot < 14 ? 1 : 2), at: 0x364); try world.write(UInt8(1), at: 4+slot)
                }
                if try draw(0xe6, 3) == 0 { try world.write(UInt8(0), at: 21); try world.write(UInt8(0), at: 17) }
                if try draw(0xe7, 6) == 0 { try actors[17].write(Int32(3), at: 0x364); try actors[13].write(Int32(3), at: 0x364) }
            } else if teamPattern < 25 {
                for slot in 10..<18 { try actors[slot].write(Int32((slot-10)/2+1), at: 0x364) }
                let activeCount = Int(try draw(0xe8, 3))*2+4
                for slot in 10..<(10+activeCount) { try world.write(UInt8(1), at: 4+slot) }
            } else {
                for slot in 10..<14 { try actors[slot].write(Int32(0), at: 0x364) }
                let activeCount = Int(try draw(0xe9, 3))+2
                for slot in 10..<(10+activeCount) { try world.write(UInt8(1), at: 4+slot) }
            }
            for slot in 0..<400 where try active(slot) {
                if try actors[slot].integer(at: 0x364, as: Int32.self) == 0 { try actors[slot].write(Int32(slot+10), at: 0x364) }
            }
            for address in stride(from: 0x450c04, through: 0x450c28, by: 4) { try setGlobal(address, 0) }
            for index in 0..<Int(count) {
                try observe(.state(.releaseLayers(index)))
                releasedBitmapOrder += try backgroundLoader.releaseLayers(in: &backgrounds[index])
            }
            if background != 99 {
                try observe(.state(.loadLayers(Int(background))))
                try backgroundLoader.loadLayers(in: &backgrounds[Int(background)], bitmapFill: bitmapFill, bitmapSource: bitmapSource)
            }
            try setGlobal(0x44d034, 1); try setGlobal(0x450bbc, 0)
            let resource = try globals.integer(at: 0x455608-Self.globalBase, as: UInt32.self)
            guard resource != 0 else { throw Self.error("Missing continuation surface") }
            try observe(.device(.fillRectangle(resource: resource, x: 0, y: 0, width: 794, height: 550, color: 0)))
            try setGlobal(0x450bdc, 0)
        }
        if confirmation != 0 {
            if action == 1 {
                try sound()
                for seat in 0..<8 {
                    try setGlobal(0x451288+seat*4, 0); try setGlobal(0x451268+seat*4, 1)
                    if try global(0x451228+seat*4) == 1 { try setGlobal(0x451248+seat*4, -1) }
                }
                try setGlobal(0x44d078, 150); try setGlobal(0x4512c8, 0)
            }
            if action == 3 {
                try sound()
                if mode == 1 {
                    let stage = try global(0x450b94) &+ 10
                    try setGlobal(0x450b94, stage == 60 ? 0 : stage)
                } else {
                    let background = try global(0x44d024)
                    try setGlobal(0x44d028, 0)
                    if background == 100 { try setGlobal(0x44d024, 99) }
                    else if background == 99 { try setGlobal(0x44d024, 0) }
                    else {
                        let next = background &+ 1
                        try setGlobal(0x44d024, next == count ? 100 : next)
                        if next == count { try setGlobal(0x44d028, 1) }
                    }
                }
            }
            if action == 2 {
                try sound()
                for seat in 0..<8 where try global(0x451228+seat*4) != 0 {
                    let candidates = try choices()
                    guard !candidates.isEmpty else { throw Self.error("Empty random roster requires original stack scratch provenance") }
                    try observe(.candidates(seat: seat, ordinals: candidates))
                    let ordinal = candidates[Int(try draw(0xea, Int32(candidates.count)))]
                    try setGlobal(0x451248+seat*4, Int32(ordinal)); try actors[seat].write(UInt32(ordinal), at: 0x368)
                }
            }
        }
        if try global(0x44d078) <= 0 && global(0x4512c8) == 0 { try setGlobal(0x4512c8, 1) }
        try setGlobal(0x450bcc, Int32(random.index)); try setGlobal(0x450c34, Int32(random.counter))
    }
}
