extension OriginalHitPass {
    //42e87d..42fdf2; true is the original ID300 whole-function return.
    mutating func damageHit(_ attacker: Int,_ defender: Int,_ body: OriginalStateRecord,spark: inout Int32,
                            observe: (OriginalHitEvent) throws -> Void) throws -> Bool {
        let a = try index(attacker),d = try index(defender)
        try put(d,0xb8,45)
        if try h(d,0x6f4) == 300 {
            if try f(d,0x12c) > 0 {
                let first = try memory.word(UInt32(bitPattern: f(d,0x134)))
                if first > 1000 { try put(d,0x364,1);try put(d,0x70,first &- 1000);try put(a,0xb4,3);try put(d,0xb4,-3) }
            };return true
        }
        try damage(a,d)
        if try i(d,0x2fc) <= 0 || it(0x2c) == 4 { try put(d,0xb0,80) }
        try durability(d)
        if try h(d,0x6f8) != 2 || it(0x1c) > 40 { try add(d,0x20,1) }
        try add(d,0xb0,it(0x1c) == 0 ? 20 : it(0x1c))
        if try f(d,8,0x78) == 13 || f(d,8,0x7c) == 12 || [1,2,4,6].contains(h(d,0x6f8)) { try put(d,0xb0,80) }
        if try h(d,0x6f8) != 3 {
            let fall = try i(d,0xb0)
            if fall > 60 { try put(d,0xb0,80) }
            else if fall > 40 {
                try put(d,0x70,226);try put(d,0xb0,60)
                if try i(d,0x14) < 0 { try put(d,0xb0,80) }
            } else if fall > 20 {
                try put(d,0x70,b(a,0x80) == b(d,0x80) ? 224 : 222);try put(d,0xb0,40)
                if try i(d,0x14) < 0 { try put(d,0xb0,80) }
            } else if fall > 0 {
                try put(d,0x70,220);try put(d,0xb0,20)
                if try i(d,0x14) < 0 { try put(d,0x70,b(a,0x80) == b(d,0x80) ? 224 : 222) }
            }
        }
        if try h(a,0x6f8) == 3 && h(a,0xac) > -1 { try sound(a,h(a,0xac),catalog: true,observe: observe) }
        if try h(d,0x6f8) == 0 {
            if try it(0x2c) == 0 { try sound(d,i(d,0xb0) == 80 ? 2 : 0,observe: observe) }
            if try it(0x2c) == 1 {
                spark = 1
                if try i(d,0xb0) == 80 { try sound(d,12,observe: observe);try sound(d,2,observe: observe) }
                else { try sound(d,11,observe: observe);try sound(d,0,observe: observe) }
            }
        } else if try h(d,0x6f8) > 0 && h(d,0xa4) > -1 { try sound(d,h(d,0xa4),catalog: true,observe: observe) }
        try hitHorizontal(a,d,observe: observe)
        if try f(a,8) == 3000 {
            let keep = try h(d,0x6f8) != 0 && h(a,0x6f4) == 209 && (Self.reflectable.contains(h(d,0x6f4)) || (h(d,0x6f4) == 209 && i(d,0x70) == 40))
            if !keep { try put(a,0x70,10);try put(a,0x88,0);try number(a,0x40,0);try number(a,0x50,Double(f(a,0x18))) }
        }
        if try i(d,0xb0) == 80 {
            let weak = try [2,3].contains(h(d,0x6f8)) && it(0x1c) <= 40
            if try it(0x18) != 0 {
                if !weak { try store(d,0x30,constant(Double(it(0x18))) + v(d,0x30)) }
                let y = try constant(Double(i(d,0x14))) + v(d,0x30)
                if OriginalCoordinateConversion.integer(y,sse2: sse2) > 0 { try number(d,0x30,12) }
            } else if !weak { try store(d,0x30,v(d,0x30)-constant(7)) }
            let front = try (b(d,0x80) == 0 && v(d,0x28) <= constant(0)) || (b(d,0x80) == 1 && v(d,0x28) >= constant(0))
            try put(d,0x70,front ? 180 : 186)
            if try i(d,0x98) > 0 && i(index(Int(i(d,0x9c))),0xa0) == defender {
                try byte(a,0xf0+Int(i(d,0x9c)),45);try byte(d,0xf0+Int(i(d,0x9c)),30)
            }
        }
        if try i(a,0xb4) >= 0 { try put(a,0xb4,3) };try put(d,0xb4,-3)
        try put(a,0xec,it(0x20) < 4 && it(0x24) == 0 ? 4 : it(0x20))
        if try it(0x24) > 0 { try byte(d,0xf0+attacker,UInt8(truncatingIfNeeded: it(0x24))) }
        if try f(d,0x88,0x7c) == 2 && i(index(Int(i(d,0x90))),0x8c) == defender && i(d,0xb0) != 80 && f(d,0x94,0x7c) != 0 {
            try put(d,0x70,f(d,b(a,0x80) != b(d,0x80) ? 0x94 : 0x98,0x7c))
        }
        if try i(d,0xb0) == 80 { try put(d,0xb0,0) }
        if try i(a,0x98) < 0 { try put(index(Int(i(a,0xa0))),0xb4,i(a,0xb4)) }
        if try f(a,8) == 1002 {
            let next = try draw(238,16,observe: observe);try put(a,0x70,next)
            try store(a,0x40,-(v(d,0x28)*constant(0.5)));try number(a,0x48,-4)
            if try h(a,0x6f8) == 4 && h(d,0x6f8) == 4 { try store(a,0x28,-v(d,0x28)) }
        }
        if try h(d,0x6f8) == 1 {
            try byte(d,0xeb,1);let next = try draw(239,16,observe: observe);try put(d,0x70,next);try put(d,0x364,i(a,0x364))
        }
        if try [4,6].contains(h(d,0x6f8)) {
            try byte(a,0xf0+defender,30);try byte(d,0xeb,1)
            let next = try draw(240,16,observe: observe);try put(d,0x70,next);try put(d,0x364,i(a,0x364))
        }
        if try h(d,0x6f8) == 2 {
            try byte(d,0xeb,1)
            let rest: UInt8 = try it(0x1c) > 40 || it(0x2c) == 4 ? 19 : 3
            if try i(a,0x98) == -2 { try byte(index(Int(i(a,0xa0))),0xf0+defender,rest) }
            else if try h(a,0x6f8) != 2 { try byte(a,0xf0+defender,rest) }
            try byte(d,0x80,b(a,0x80))
            if try it(0x1c) > 40 || i(d,0x14) < 0 || it(0x2c) == 4 { let next = try draw(241,6,observe: observe);try put(d,0x70,next) }
            else { try put(d,0x70,20) }
            try put(d,0x364,i(a,0x364))
        }
        if try h(a,0x6f4) == 201 && h(d,0x6f8) == 0 { try world.write(UInt8(0),at: 4+attacker) }
        if try h(a,0x6f4) == 214 && h(d,0x6f8) == 0 { try put(a,0x2fc,0) }
        if try h(d,0x6f8) == 3 { try projectileHit(attacker,defender) }
        if library != nil { try libraryHitEffect(d) }
        if try [3,30].contains(it(0x2c)) && h(d,0x6f8) == 0 && f(d,8,0x78) != 13 {
            try put(d,0x70,200);try put(d,0x88,0);try sound(d,14,observe: observe)
        }
        if try ([2,21,22].contains(it(0x2c)) || (it(0x2c) == 20 && f(d,8,0x78) != 18)) && h(d,0x6f8) == 0 {
            try put(d,0x70,203);try put(d,0x88,0);try sound(d,16,observe: observe)
            try byte(d,0x80,v(d,0x28) >= constant(0) ? 1 : 0)
        }
        if try it(0x2c) == 23 { try sound(d,16,observe: observe) }
        return false
    }

    mutating func hitHorizontal(_ a: Int,_ d: Int,observe: (OriginalHitEvent) throws -> Void) throws {
        if try i(d,0xb0) == 80 && v(d,0x40) > constant(-5) && v(d,0x40) < constant(5) && it(0x14) == 0 {
            let scale: Int32 = try f(a,8) == 2000 ? 1 : 1 &- 2 &* Int32(Int8(bitPattern: b(a,0x80)))
            try store(d,0x28,constant(5)*constant(Double(scale))+v(d,0x28));return
        }
        if try f(a,8) == 2000 {
            let delta = try constant(Double(it(0x14)))
            try store(d,0x28,i(a,0x10) < i(d,0x10) ? v(d,0x28)+delta : v(d,0x28)-delta);return
        }
        if try [4,6].contains(h(d,0x6f8)) {
            let vx = try v(d,0x40),zero = try constant(0),scaled = try (vx < zero ? -vx : vx)*constant(0.55)
            let delta = try constant(Double(it(0x14))),facing = try b(a,0x80)
            //42ef45 pops the magnitude while retaining zero under the ITR dvx.
            let apply = try delta > scaled || (facing == 0 && v(d,0x28) > zero) || (facing == 1 && v(d,0x28) < zero)
            if apply { try facingImpulse(a,d,delta) }
            else if (facing == 1 && vx > zero) || (facing == 0 && vx < zero) { try store(d,0x28,-(vx*constant(0.55))) }
            if try h(a,0x6f4) == 100 && i(a,0x98) < 0 {
                try store(d,0x28,v(d,0x28)*constant(2.5));try sound(d,13,observe: observe)
                if try v(d,0x28) > zero && v(d,0x28) < constant(10) { try number(d,0x28,10) }
                if try v(d,0x28) < zero && v(d,0x28) > constant(-10) { try number(d,0x28,-10) }
            }
        } else if try [22,23].contains(it(0x2c)) {
            let delta = try constant(Double(it(0x14)))
            try store(d,0x28,i(d,0x10) <= i(a,0x10) ? v(d,0x28)+delta : v(d,0x28)-delta)
        } else { try facingImpulse(a,d,constant(Double(it(0x14)))) }
    }
    mutating func facingImpulse(_ a: Int,_ d: Int,_ delta: OriginalExtended) throws {
        if try b(a,0x80) == 0 { try store(d,0x28,delta+v(d,0x28)) }
        if try b(a,0x80) == 1 { try store(d,0x28,v(d,0x28)-delta) }
    }
    static let reflectable: Set<Int32> = [200,203,205,206,207,215,216]
    mutating func copyCredit(_ from: Int,_ to: Int) throws { try put(to,0x364,i(from,0x364));try put(to,0x354,i(from,0x354)) }
    mutating func rebindReflection(_ d: Int) throws {
        if let replacement = try find(209) {
            try put(d,0x368,Int32(replacement));try put(d,0x74,i(d,0x70));try put(d,0x78,i(d,0x70))
        }
    }
    //42f70f..42fcaa. Re-read states after rebind/frame writes, including aliases.
    mutating func projectileHit(_ attacker: Int,_ defender: Int) throws {
        let a = try index(attacker),d = try index(defender)
        if try f(d,8) != 3005 && !(f(d,8) == 3006 && f(a,8) != 3005) {
            if try i(a,0x98) < 0 { try copyCredit(index(Int(i(a,0xa0))),d) } else { try copyCredit(a,d) }
            try byte(d,0xeb,1);try put(d,0x88,0)
            for o in [0x30,0x28,0x38] { try number(d,o,0) }
            if try h(a,0x6f4) == 209 && Self.reflectable.contains(h(d,0x6f4)) {
                try copyCredit(a,d);try put(d,0x368,Int32(object(a)))
                for o in [0x70,0x74,0x78] { try put(d,o,40) }
            } else if try (h(a,0x6f8) == 0 || i(a,0x98) < 0) && ![2,20].contains(it(0x2c)) {
                try put(d,0x70,30)
                if try h(a,0x6f4) == 8 && Self.reflectable.contains(h(d,0x6f4)) { try rebindReflection(d) }
            } else { try put(d,0x70,20) }
            if try i(a,0x98) < 0 {
                try put(d,0,i(a,0xa0))
                if try h(a,0x6f4) == 213 && Self.reflectable.contains(h(d,0x6f4)) { try rebindReflection(d);try copyCredit(index(Int(i(a,0xa0))),d) }
            } else { try put(d,0,Int32(attacker)) }
        }
        if try (f(d,8) == 3005 && f(a,8) == 3005) || (f(d,8) == 3006 && f(a,8) == 3006) {
            for actor in [d,a] { try put(actor,0x70,20);try put(actor,0x88,0);for o in [0x30,0x28,0x38] { try number(actor,o,0) } }
        }
        let owner = try i(a,0x98) < 0 ? index(Int(i(a,0xa0))) : a
        if try i(owner,0xb4) > 0 { try put(owner,0xb4,0 &- i(owner,0xb4)) }
    }
}
