import Foundation

public enum OriginalActorControlEvent: Equatable {
    case random(stream: Int32, range: Int32, result: Int32)
    case sound(x: Int32, index: Int32)
}

/// Whole413080..4143cb. The two original caller arguments have no effect in
/// this EXE: the second is forwarded to412f40, which does not read it.
/// The400-slot caller and physics are separate stages. No host physics/AI.
public enum OriginalActorControl {
    public static func apply(actor: inout OriginalStateRecord, object: OriginalLoadedObject,
                             globals: inout OriginalStateRecord, phase _: Int32, mode _: Int32,
                             observe: (OriginalActorControlEvent) throws -> Void = { _ in }) throws {
        try apply(actor: &actor, header: object.header, globals: &globals, frame: { index in
            guard object.frameStorage.indices.contains(Int(index)) else {
                throw OriginalStateError.invalidStorage("Actor control frame outside Object: \(index)")
            }
            return object.frameStorage[Int(index)]
        }, observe: observe)
    }

    static func apply(actor: inout OriginalStateRecord, header: OriginalStateRecord,
                      globals: inout OriginalStateRecord, frame: (Int32) throws -> OriginalStateRecord,
                      observe: (OriginalActorControlEvent) throws -> Void = { _ in }) throws {
        var candidate = actor, owned = globals
        try OriginalActorInput.apply(actor: &candidate, sourceID: header.integer(at: 0x6f4, as: Int32.self), globals: owned, frame: frame)
        try withoutActuallyEscaping(frame) { frames in
            try withoutActuallyEscaping(observe) { observer in
                var body = Body(actor: candidate, globals: owned, header: header, frame: frames, observe: observer)
                try body.run()
                candidate = body.actor; owned = body.globals
            }
        }
        actor = candidate; globals = owned
    }

    private struct Body {
        var actor: OriginalStateRecord, globals: OriginalStateRecord
        let header: OriginalStateRecord
        let frame: (Int32) throws -> OriginalStateRecord
        let observe: (OriginalActorControlEvent) throws -> Void
        func i(_ offset: Int) throws -> Int32 { try actor.integer(at: offset, as: Int32.self) }
        func b(_ offset: Int) throws -> UInt8 { try actor.integer(at: offset, as: UInt8.self) }
        func signed(_ offset: Int) throws -> Int8 { try actor.integer(at: offset, as: Int8.self) }
        func v(_ offset: Int) throws -> Double { try actor.binary64(at: offset) }
        func h(_ offset: Int) throws -> Double { try header.binary64(at: offset) }
        func g(_ address: Int) throws -> Int32 { try globals.integer(at: address-OriginalMatchPreparation.globalBase, as: Int32.self) }
        func state() throws -> Int32 { try frame(i(0x70)).integer(at: 8, as: Int32.self) }
        mutating func set(_ offset: Int,_ value: Int32) throws { try actor.write(value, at: offset) }
        mutating func face(_ value: UInt8) throws { try actor.write(value, at: 0x80) }
        mutating func velocity(_ offset: Int,_ value: Double) throws { try actor.writeBinary64(value, at: offset) }
        mutating func draw(_ tag: Int32) throws -> Int32 {
            var random = OriginalRandom(table: try (0..<3000).map { try globals.integer(at: 0x44ff90-OriginalMatchPreparation.globalBase+$0, as: UInt8.self) },
                index: Int(try g(0x450bcc)), counter: Int(try g(0x450c34)), source: "owned Actor control globals", sourceSHA256: "")
            try random.validate()
            let result = Int32(random.next(2))
            try globals.write(Int32(random.index), at: 0x450bcc-OriginalMatchPreparation.globalBase)
            try globals.write(Int32(random.counter), at: 0x450c34-OriginalMatchPreparation.globalBase)
            try observe(.random(stream: tag, range: 2, result: result))
            return result
        }
        mutating func dashSound() throws {
            let x = try i(0x10)
            try OriginalGameplaySound.queueBuiltin(x: x, index: 7, globals: &globals)
            try observe(.sound(x: x, index: 7))
        }
        func divide(_ value: Int32,_ divisor: Int32) throws -> (Int32,Int32) {
            guard divisor != 0, !(value == .min && divisor == -1) else {
                throw OriginalStateError.invalidStorage("Original Actor control idiv fault")
            }
            return (value/divisor,value%divisor)
        }
        mutating func walkPhase(heavy: Bool) throws {
            let rate = try header.integer(at: 0, as: Int32.self)
            let phase = try divide(i(0) &+ 1,rate &* 6).1
            try set(0,phase)
            let step = try divide(phase,rate).0
            try set(0x70, phase < rate &* 4 ? step &+ (heavy ? 12 : 5) : (heavy ? 18 : 11) &- step)
        }
        mutating func runPhase(heavy: Bool) throws {
            let rate = try header.integer(at: 0x18, as: Int32.self)
            let phase = try divide(i(0) &+ 1,rate &* 4).1
            try set(0,phase)
            if phase < rate &* 3 { try set(0x70, divide(phase,rate).0 &+ (heavy ? 16 : 9)) }
            else { try set(0x70,heavy ? 17 : 10) }
        }
        /// Standing/airborne attacks clamp exhausted MP, while run/dash attacks
        /// require affordability. Both use the entire mp field, not combo packing.
        mutating func attack(_ number: Int32, requireFunds: Bool, clearWait: Bool = false) throws {
            if clearWait { try set(0x88,0) }
            if !requireFunds { try set(0x70,number) }
            if try g(0x44d034) != 0 {
                let cost = try frame(number).integer(at: 0x4c, as: Int32.self)
                let before = try i(0x308)
                if requireFunds && before < cost { return }
                let after = before &- cost
                if !requireFunds && after < 0 { try set(0x308,0) }
                else { try set(0x308,after); try set(0x350,i(0x350) &+ cost) }
            }
            if requireFunds { try set(0x70,number) }
        }
        mutating func run() throws {
            let right = try b(0xd0),left = try b(0xcf),up = try b(0xcd),down = try b(0xce)
            let attackHeld = try b(0xd1),jump = try b(0xd2),defend = try b(0xd3)
            let rightOnly = right == 1 && left == 0,leftOnly = left == 1 && right == 0
            let upOnly = up == 1 && down == 0,downOnly = down == 1 && up == 0
            let grounded = try i(0x14) == 0
            let kind = try i(0x98)
            if try i(0x70) == 110 {
                if right == 1 { try face(0) }
                if left == 1 { try face(1) }
            }
            if try [19,301].contains(state()) && grounded {
                if upOnly { try velocity(0x50,-h(0x28)) }
                if downOnly { try velocity(0x50,h(0x28)) }
            }
            if try [0,1].contains(state()) {
                if try i(4) > 0 { try set(4,i(4) &- 1) }
                if try i(4) < 0 { try set(4,i(4) &+ 1) }
                let heavy = kind == 2
                if try heavy && i(0x70) < 12 { try set(0x70,12) }
                if rightOnly && grounded {
                    if try b(0x80) == 1 { try set(4,0) }
                    try face(0); try walkPhase(heavy: heavy); try velocity(0x40,h(heavy ? 0x30 : 8))
                    if try b(0xc9) == 0 { try set(4,i(4) &+ 10) }
                    if try i(4) >= 11 { try set(0x70,heavy ? 16 : 9); try set(0,0); try set(4,0) }
                }
                if leftOnly && grounded {
                    if try b(0x80) == 0 { try set(4,0) }
                    try face(1); try walkPhase(heavy: heavy); try velocity(0x40,-h(heavy ? 0x30 : 8))
                    if try b(0xc8) == 0 { try set(4,i(4) &- 10) }
                    if try i(4) <= -11 { try set(0x70,heavy ? 16 : 9); try set(0,0); try set(4,0) }
                }
                if (upOnly || downOnly) && grounded {
                    if (left == 0) == (right == 0) { try walkPhase(heavy: heavy) }
                    let speed = try h(heavy ? 0x38 : 0x10)
                    try velocity(0x50,upOnly ? -speed : speed)
                    try velocity(0x40,v(0x40)/1.4)
                }
                if try attackHeld == 1 && signed(0xbe) > 0 {
                    try set(4,0); try set(0x88,0)
                    if heavy { try set(0x70,50) }
                    else if kind == 0 {
                        if try signed(0xea) > 0 { try set(0x70,70) }
                        else { let number = try (draw(0x82) &+ 12) &* 5; try attack(number,requireFunds: false) }
                    } else if kind%100 == 1 {
                        if kind == 101 && (right != 0 || left != 0 || up != 0 || down != 0) { try set(0x70,45) }
                        else { try set(0x70,(draw(kind == 101 ? 0x83 : 0x84) &+ 4) &* 5) }
                    } else if kind == 4 { try set(0x70,45) }
                    else if kind == 6 { try set(0x70,55) }
                }
                if !heavy {
                    if try jump == 1 && signed(0xbf) > 0 { try set(0x88,0); try set(4,0); try set(0x70,210) }
                    if try defend == 1 && b(0xc1) == 0 && signed(0xc0) > 0 { try set(4,0); try set(0x88,0); try set(0x70,110) }
                }
            }
            // Earlier transitions can enter a later block during this same call.
            if try state() == 4 && i(0x14) < 0 {
                if rightOnly { try face(0) }; if leftOnly { try face(1) }
                if attackHeld != 0 {
                    if kind == 0 { try attack(80,requireFunds: false,clearWait: true) }
                    else if kind%100 == 1 {
                        try set(0x88,0); try set(0x70,(left == 0 && right == 0 && up == 0 && down == 0) ? 30 : 52)
                    } else if kind == 4 || kind == 6 { try set(0x70,52) }
                }
            }
            if try state() == 2 {
                let heavy = kind == 2
                try set(0x88,0); try runPhase(heavy: heavy)
                if try b(0x80) == 0 {
                    try velocity(0x40,h(heavy ? 0x40 : 0x20))
                    if left == 1 { try set(0x70,heavy ? 19 : 218) }
                }
                if try b(0x80) == 1 {
                    try velocity(0x40,-h(heavy ? 0x40 : 0x20))
                    if right == 1 { try set(0x70,heavy ? 19 : 218) }
                }
                if (upOnly || downOnly) && grounded {
                    let speed = try h(heavy ? 0x48 : 0x28)
                    try velocity(0x50,upOnly ? -speed : speed); try velocity(0x40,v(0x40)/1.2)
                }
                if try attackHeld == 1 && signed(0xbe) > 0 {
                    if heavy { try set(0x70,50) }
                    else if kind == 0 { try attack(85,requireFunds: true) }
                    else if kind%100 == 1 { try set(0x70,(left == 0 && right == 0 && up == 0 && down == 0) ? 35 : 45) }
                    else if kind == 4 { try set(0x70,45) }
                    else if kind == 6 { try set(0x70,(left == 0 && right == 0 && up == 0 && down == 0) ? 55 : 45) }
                }
                if !heavy {
                    if try defend == 1 && signed(0xc0) > 0 { try set(0x70,102) }
                    if try jump == 1 && signed(0xbf) > 0 {
                        try dashSound(); try set(4,0); try set(0x70,213)
                        try velocity(0x40,Double(1 &- (Int32(signed(0x80)) &* 2))*h(0x70)); try velocity(0x48,h(0x68))
                        if up != 0 && down == 0 { try velocity(0x50,-h(0x78)) }
                        if down != 0 && up == 0 { try velocity(0x50,h(0x78)) }
                    }
                }
            }
            if try i(0x70) == 215 {
                if try defend == 1 && signed(0xc0) > 0 { try set(0x70,102) }
                if try jump != 0 && (right != 0 || v(0x40) > 0.001) && signed(0xbf) > 0 {
                    try dashSound(); try set(0x70,213 &+ Int32(signed(0x80))); try set(4,0)
                    try velocity(0x40,h(0x70)); try velocity(0x48,h(0x68))
                }
                if try jump != 0 && (left != 0 || v(0x40) < -0.001) && signed(0xbf) > 0 {
                    try dashSound(); try set(0x70,214 &- Int32(signed(0x80))); try set(4,0)
                    try velocity(0x40,-h(0x70)); try velocity(0x48,h(0x68))
                }
                if up != 0 && down == 0 { try velocity(0x50,-h(0x78)) }
                if down != 0 && up == 0 { try velocity(0x50,h(0x78)) }
            }
            if try [182,188].contains(i(0x70)) && i(0x320) >= 0 && jump == 1 && signed(0xbf) > 0 && i(0x2fc) > 0 {
                let facing = try b(0x80),vx = try v(0x40)
                try set(0x70,(facing == 0 && vx <= 0) || (facing == 1 && vx >= 0) ? 100 : 108)
                try set(0x88,0)
                if try h(0x80) < v(0x48) { try velocity(0x48,h(0x80)) }
                let speed = try h(0x88)
                if vx > -1 && vx < 1 { try velocity(0x40,facing == 1 ? speed : -speed) }
                else { try velocity(0x40,vx > 0 ? speed : -speed) }
            }
            if try state() == 5 {
                if rightOnly { try face(0) }
                if try b(0x80) == 0 {
                    if try i(0x70) != 217 && v(0x40) < 0 { try set(0x70,214) }
                    if try i(0x70) != 216 && v(0x40) > 0 { try set(0x70,213) }
                }
                if leftOnly { try face(1) }
                if try b(0x80) == 1 {
                    if try i(0x70) != 217 && v(0x40) > 0 { try set(0x70,214) }
                    if try i(0x70) != 216 && v(0x40) < 0 { try set(0x70,213) }
                }
                if try ((b(0x80) == 0 && v(0x40) > 0) || (b(0x80) == 1 && v(0x40) < 0)) && attackHeld != 0 {
                    if kind == 0 { try attack(90,requireFunds: true) }
                    else if kind%100 == 1 || ((kind == 4 || kind == 6) && (left != 0 || right != 0 || up != 0 || down != 0)) {
                        try set(0x70,(kind == 4 || kind == 6) ? 52 : 40)
                        try set(0x88,0); try velocity(0x48,v(0x48)-1)
                    }
                }
            }
            try frameVelocity()
        }
        mutating func frameVelocity() throws {
            let current = try frame(i(0x70))
            let x = try current.integer(at: 0x14, as: Int32.self)
            if x > 500 { try velocity(0x40,Double(x &- 550)) }
            else if x > 0 {
                if try b(0x80) == 0 && Double(x) > v(0x40) { try velocity(0x40,Double(x)) }
                if try b(0x80) == 1 && -v(0x40) < Double(x) { try velocity(0x40,-Double(x)) }
            } else if x < 0 {
                if try b(0x80) == 0 && Double(x) < v(0x40) { try velocity(0x40,Double(x)) }
                if try b(0x80) == 1 && -v(0x40) > Double(x) { try velocity(0x40,-Double(x)) }
            }
            let y = try current.integer(at: 0x18, as: Int32.self)
            if y != 0 { try velocity(0x48,y > 500 ? Double(y &- 550) : v(0x48)+Double(y)) }
            let z = try current.integer(at: 0x1c, as: Int32.self)
            if z > 500 { try velocity(0x50,Double(z &- 550)) }
            else if z != 0 {
                if try b(0xcd) == 1 && signed(0xc4) >= signed(0xc5) { try velocity(0x50,-Double(z)) }
                if try b(0xce) == 1 && signed(0xc4) <= signed(0xc5) { try velocity(0x50,Double(z)) }
            }
        }
    }
}

///417090..417162 queues channel contributions; actual device playback is later.
public enum OriginalGameplaySound {
    public static func queueBuiltin(x: Int32, index: Int32, globals: inout OriginalStateRecord) throws {
        let base = OriginalMatchPreparation.globalBase
        let position = try x &- globals.integer(at: 0x450bc4-base, as: Int32.self)
        func volume(_ center: Int32) -> Int32 {
            let delta = position &- center,distance = delta < 0 ? 0 &- delta : delta
            if distance < 200 { return 100 }
            if distance < 400 { return ((400 &- distance) &* 100)/200 }
            return 0
        }
        func offset(_ address: UInt32) -> Int { Int(address &+ (UInt32(bitPattern: index) &* 4))-base }
        let flag = offset(0x453e10),left = offset(0x4527e8),right = offset(0x4554c8)
        if try globals.integer(at: flag, as: Int32.self) == 0 {
            try globals.write(Int32(0), at: left); try globals.write(Int32(0), at: right)
        }
        try globals.write(globals.integer(at: left, as: Int32.self) &+ volume(200), at: left)
        try globals.write(globals.integer(at: right, as: Int32.self) &+ volume(600), at: right)
        try globals.write(Int32(1), at: flag)
    }
}
