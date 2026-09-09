public enum OriginalActorPhysicsEvent: Equatable {
    case builtinSound(x: Int32,index: Int32),catalogSound(x: Int32,index: Int32)
}

/// Whole40e490..40ef6a. The surrounding World death/spawn pass is separate.
/// Arithmetic uses an explicit x87 precision and retains extended exponents.
public enum OriginalActorPhysics {
    public static func apply(actor: inout OriginalStateRecord,object: OriginalLoadedObject,globals: inout OriginalStateRecord,
                             sse2Conversion: Bool = false,precision: OriginalArithmeticPrecision = .bits64,observe: (OriginalActorPhysicsEvent) throws -> Void = { _ in }) throws {
        try apply(actor: &actor,header: object.header,globals: &globals,sse2Conversion: sse2Conversion,precision: precision,frame: { number in
            guard object.frameStorage.indices.contains(Int(number)) else { throw OriginalStateError.invalidStorage("Physics frame binding") }
            return object.frameStorage[Int(number)]
        },observe: observe)
    }
    static func apply(actor: inout OriginalStateRecord,header: OriginalStateRecord,globals: inout OriginalStateRecord,
                      sse2Conversion: Bool = false,precision: OriginalArithmeticPrecision = .bits64,frame: (Int32) throws -> OriginalStateRecord,
                      observe: (OriginalActorPhysicsEvent) throws -> Void = { _ in }) throws {
        try withoutActuallyEscaping(frame) { frames in
            try withoutActuallyEscaping(observe) { observer in
                var body = Body(actor: actor,globals: globals,precision: precision,header: header,frame: frames,observe: observer)
                try body.run(sse2Conversion: sse2Conversion);actor = body.actor;globals = body.globals
            }
        }
    }
    private struct Body {
        var actor: OriginalStateRecord,globals: OriginalStateRecord
        let precision: OriginalArithmeticPrecision
        let header: OriginalStateRecord,frame: (Int32) throws -> OriginalStateRecord,observe: (OriginalActorPhysicsEvent) throws -> Void
        func i(_ offset: Int) throws -> Int32 { try actor.integer(at: offset,as: Int32.self) }
        func h(_ offset: Int) throws -> Int32 { try header.integer(at: offset,as: Int32.self) }
        func f(_ offset: Int) throws -> Int32 { try frame(i(0x70)).integer(at: offset,as: Int32.self) }
        func constant(_ value: Double) throws -> OriginalExtended { try OriginalExtended(value,precision: precision) }
        func v(_ offset: Int) throws -> OriginalExtended { try constant(actor.binary64(at: offset)) }
        mutating func put(_ offset: Int,_ value: Int32) throws { try actor.write(value,at: offset) }
        mutating func store(_ offset: Int,_ value: OriginalExtended) throws { try actor.writeBinary64(value.double,at: offset) }
        mutating func number(_ offset: Int,_ value: Double) throws { try actor.writeBinary64(value,at: offset) }
        mutating func sound(catalog: Bool,index: Int32) throws {
            let x = try i(0x10) // integer x is refreshed only at the final conversion
            if catalog { try OriginalGameplaySound.queueCatalog(x: x,index: index,globals: &globals);try observe(.catalogSound(x: x,index: index)) }
            else { try OriginalGameplaySound.queueBuiltin(x: x,index: index,globals: &globals);try observe(.builtinSound(x: x,index: index)) }
        }
        mutating func weaponSound() throws { let index = try h(0xa8);if index > -1 { try sound(catalog: true,index: index) } }
        mutating func reverse() throws { try actor.write(UInt8(1) &- actor.integer(at: 0x80,as: UInt8.self),at: 0x80) }
        mutating func friction(_ offset: Int) throws {
            let epsilon = try constant(0.0001),one = try constant(1)
            if try v(offset) > epsilon {
                let next = try v(offset)-one;try store(offset,next)
                if next < epsilon { try number(offset,0) }
            }
            if try v(offset) < -epsilon {
                let next = try v(offset)+one;try store(offset,next)
                // Original40e61f/40e667 compares against POSITIVE epsilon.
                if next > epsilon { try number(offset,0) }
            }
        }
        mutating func run(sse2Conversion: Bool) throws {
            let freeze = try i(0xb4)
            if freeze != 0 { try put(0xb4,freeze > 0 ? freeze &- 1 : freeze &+ 1);return }
            if try i(0x98) < 0 || f(0x88) == 2 { return }
            let zero = try constant(0),epsilon = try constant(0.0001)
            let type = try h(0x6f8),id = try h(0x6f4)
            let vx = try v(0x40),vz = try v(0x50)
            if !(try (vx > zero && i(0x3f4) == 1) || (vx < zero && i(0x3f0) == 1)) { try store(0x58,v(0x58)+vx) }
            if type == 4 || id == 120 { try store(0x58,vx * constant(0.2) + v(0x58)) }
            if id == 101 { try store(0x58,v(0x58)-constant(0.2)*vx) }
            if !(try (vz > zero && i(0x3ec) == 1) || (vz < zero && i(0x3e8) == 1)) { try store(0x68,v(0x68)+vz) }
            for offset in [0x3ec,0x3e8,0x3f0,0x3f4] { try put(offset,0) }
            if type == 3,try f(0x2c) > 0 { try store(0x68,v(0x68)+constant(Double(f(0x2c) &- 50))) }
            if try i(0x14) >= 0 { try friction(0x40);try friction(0x50) }
            if [4,6].contains(type),try f(8) == 1000 {
                let speed = try v(0x40)
                if try speed > constant(9) || speed < constant(-9) { try put(0x70,40) }
            }
            let y = try v(0x60)+v(0x48);try store(0x60,y)
            if y < -epsilon {
                if type != 3 {
                    let gravity: Double
                    if type == 6 { gravity = 1.1333333333333333 }
                    else if type == 4 { gravity = 0.85 }
                    else if try f(8) == 1002 {
                        gravity = id == 124 ? 0.16999999999999998 : id == 120 ? 0.425 : id == 101 ? 1.1333333333333333 : 0.5666666666666667
                    } else { gravity = 1.7 }
                    try store(0x48,v(0x48)+constant(gravity))
                }
                if type == 0 { try airborne() }
            } else if try f(0x88) != 2 {
                if type == 0 { try fighterLanding(y: y) }
                else { try objectLanding(type: type,id: id,y: y) }
            }
            for (from,to) in [(0x58,0x10),(0x60,0x14),(0x68,0x18)] {
                try put(to,OriginalCoordinateConversion.integer(actor.binary64(at: from),sse2: sse2Conversion))
            }
            if try f(8) != 12 { try put(0x320,0) }
        }
        mutating func airborne() throws {
            let speed = try v(0x48),one = try constant(1)
            if try f(8) == 12 {
                let number = try i(0x70)
                if number < 185 {
                    let phase = try speed < constant(-8) ? 0 : speed < one ? 1 : speed < constant(8) ? 2 : 3
                    try put(0x70,Int32(180+phase))
                    if try i(0x320) < 0 {
                        let falling = try speed < constant(12) && globals.integer(at: 0x450bd0-0x44d000,as: Int32.self) >= 6
                        try put(0x70,falling ? 182 : 181)
                    }
                } else if number > 185 && number < 191 {
                    let phase = try speed < constant(-8) ? 0 : speed < one ? 1 : speed < constant(8) ? 2 : 3
                    try put(0x70,Int32(186+phase))
                }
            }
            if try f(8) == 18,try i(0x70) < 205,speed > one { try put(0x70,205) }
        }
        mutating func fighterLanding(y: OriginalExtended) throws {
            let zero = try constant(0),epsilon = try constant(0.0001),three = try constant(3)
            if y > epsilon,try v(0x48) > epsilon,try f(8) == 13 {
                if try v(0x48) > constant(17) || v(0x40) > constant(9) || v(0x40) < constant(-9) {
                    let divisor = try i(0x340)
                    try put(0x2fc,i(0x2fc) &+ (divisor == 0 ? -10 : -1000/divisor))
                    try number(0x60,0);try number(0x48,-3.5)
                    try store(0x40,min(constant(7),max(constant(-7),v(0x40))))
                    try put(0x70,185)
                } else { try number(0x60,0);try number(0x48,0);try store(0x40,v(0x40)/three) }
            }
            let jumpLanding = try v(0x60) > zero && v(0x48) == zero && i(0x70) == 212
            let hitGround = try v(0x60) > epsilon && v(0x48) > epsilon
            if try jumpLanding || (hitGround && f(8) != 12 && f(8) != 18) {
                try number(0x60,0);try number(0x48,0);try store(0x40,v(0x40)/three)
                let state = try f(8),number = try i(0x70)
                try put(0x70,state == 100 ? 94 : number == 212 || state == 6 ? 215 : 219);try put(0x88,0)
            } else if hitGround,try f(8) == 12 || f(8) == 18 {
                try sound(catalog: false,index: 6)
                var hurt = try i(0x320)
                if hurt != 0 {
                    if hurt < 0 { hurt = 0 &- hurt;try put(0x320,hurt) }
                    let divisor = try i(0x340)
                    if divisor > 0 { hurt = (hurt &* 100)/divisor }
                    try put(0x2fc,i(0x2fc) &- hurt);try put(0x300,i(0x300) &- hurt);try put(0x320,0)
                }
                if try v(0x48) <= constant(11) && v(0x40) <= constant(9) && v(0x40) >= constant(-9) && f(8) != 18 {
                    try number(0x60,0);try number(0x48,0);try store(0x40,v(0x40)/three)
                    try put(0x70,i(0x70) >= 186 ? 231 : 230);try put(0x88,0)
                } else {
                    try number(0x60,0);try number(0x48,-3.5)
                    try store(0x40,min(constant(7),max(constant(-7),v(0x40))))
                    try put(0x70,i(0x70) >= 186 && f(8) != 18 ? 191 : 185)
                }
            }
        }
        mutating func objectLanding(type: Int32,id: Int32,y: OriginalExtended) throws {
            let epsilon = try constant(0.0001)
            if ![1,2,4,6].contains(type) {
                if id == 999 && y > -epsilon {
                    try number(0x60,0);try put(0x70,101);try number(0x48,0);try number(0x40,0);try put(0x88,0)
                };return
            }
            if y <= epsilon { return }
            if type != 2,try v(0x48) <= epsilon { return }
            try put(0x31c,i(0x31c) &- (type == 2 ? 1 : h(0x94)))
            if type == 6,try i(0x2fc) <= 0 { try put(0x31c,-1) }
            try number(0x60,0)
            let state = try f(8)
            if type == 1 {
                if try v(0x48) > constant(9.9),state == 1002 {
                    try number(0x48,-8);try put(0x70,7);try reverse()
                    try store(0x40,v(0x40)*constant(0.5));try weaponSound();return
                }
                try put(0x70,state == 1002 ? 70 : 60)
            } else if type == 2 {
                if try v(0x48) > constant(9) {
                    try weaponSound();try number(0x48,-5);try reverse();try store(0x40,v(0x40)*constant(0.5));return
                }
                try put(0x31c,max(0,i(0x31c) &- h(0x94)));try put(0x70,20)
            } else {
                let fast = try v(0x48) > constant(8.5) || v(0x40) < constant(-10) || v(0x40) > constant(10)
                if fast && [1000,1002].contains(state) {
                    try put(0x70,0)
                    let rebound = try v(0x48)*constant(-0.7);try store(0x48,max(constant(-10),rebound))
                    try store(0x40,v(0x40)*constant(0.7));try weaponSound();return
                }
                try put(0x70,state == 1002 ? 70 : 60)
            }
            try number(0x48,0);try put(0x88,0)
            try store(0x40,v(0x40)*constant(type == 4 || type == 6 ? 0.7 : 0.5))
        }
    }
}
