extension OriginalHitPass {
    //42fdf2..43056e. The guard reaction itself requires type0; the caller can
    // nevertheless reach this label for another type and still draw a spark.
    mutating func guardHit(_ attacker: Int,_ defender: Int,_ body: OriginalStateRecord,
                           observe: (OriginalHitEvent) throws -> Void) throws {
        let a = try index(attacker),d = try index(defender)
        if try h(d,0x6f8) != 0 { return }
        if try h(a,0x6f8) == 3 {
            if try h(a,0xac) > -1 { try sound(a,h(a,0xac),catalog: true,observe: observe) }
        } else { try sound(d,[37,6].contains(h(d,0x6f4)) ? 17 : 1,observe: observe) }
        try damage(a,d,guarded: true);try durability(d)
        if try i(d,0x2fc) <= 0 { try put(d,0xb0,80) }
        try put(d,0x88,0);try add(d,0xb8,it(0x40));try add(d,0x20,1)
        try put(a,0xb4,3);try put(d,0xb4,-5)
        let grounded = try i(d,0x14) == 0
        if grounded {
            if try i(d,0xb8) > 30 && field(body,8) == 7 { try put(d,0x70,112) }
            else if try i(d,0x70) == 110 { try put(d,0x70,111) }
        }
        if grounded {
            if try i(d,0xb0) == 80 && v(d,0x40) < constant(3) && v(d,0x40) > constant(-3) && it(0x14) == 0 {
                if try f(a,8) == 2000 {
                    try store(d,0x28,i(a,0x10) < i(d,0x10) ? v(d,0x28)+constant(6) : v(d,0x28)-constant(6))
                } else { try store(d,0x28,constant(3)*constant(Double(1 &- 2 &* Int32(Int8(bitPattern: b(a,0x80)))))+v(d,0x28)) }
            } else if try f(a,8) == 2000 {
                let delta = try constant(Double(it(0x14)))
                try store(d,0x28,i(a,0x10) < i(d,0x10) ? v(d,0x28)+delta : v(d,0x28)-delta)
            } else if try [22,23].contains(it(0x2c)) { try radialImpulse(a,d) }
            else { try facingImpulse(a,d,constant(Double(it(0x14)/2))) }
        } else if try i(d,0xb0) == 80 && v(d,0x40) < constant(6) && v(d,0x40) > constant(-6) && it(0x14) < 6 {
            try store(d,0x28,constant(6)*constant(Double(1 &- 2 &* Int32(Int8(bitPattern: b(a,0x80)))))+v(d,0x28))
        } else if try [22,23].contains(it(0x2c)) { try radialImpulse(a,d) }
        else { try facingImpulse(a,d,constant(Double(it(0x14)))) }
        if try it(0x20) < 4 && it(0x24) == 0 { try put(a,0xec,4) }
        else { try put(a,0xec,it(0x20));if try i(a,0xec) > 12 { try put(a,0xec,12) } }
        if try it(0x24) > 0 {
            if try it(0x24) <= 4 { try byte(d,0xf0+attacker,4) }
            else {
                try byte(d,0xf0+attacker,UInt8(truncatingIfNeeded: it(0x24)))
                if try actors[d].integer(at: 0xf0+attacker,as: Int8.self) > 12 { try byte(d,0xf0+attacker,12) }
            }
        }
        if try i(a,0x98) < 0 { try put(index(Int(i(a,0xa0))),0xb4,i(a,0xb4)) }
        if try f(a,8) == 1002 {
            let next = try draw(243,16,observe: observe);try put(a,0x70,next)
            try store(a,0x40,-(v(d,0x28)*constant(0.5)));try number(a,0x48,-4);try store(a,0x50,v(a,0x50)/constant(-1.5))
        }
        if try f(a,8) == 2000 && ((i(a,0x10) > i(d,0x10) && v(a,0x40) < constant(0)) || (i(a,0x10) < i(d,0x10) && v(a,0x40) > constant(0))) {
            try store(a,0x40,v(a,0x40)/constant(2.5));try store(a,0x50,v(a,0x50)/constant(2.5))
        }
        if try f(a,8) == 3000 { try put(a,0x70,10);try put(a,0x88,0);try number(a,0x40,0) }
    }
    mutating func radialImpulse(_ a: Int,_ d: Int) throws {
        let delta = try constant(Double(it(0x14)))
        try store(d,0x28,i(d,0x10) <= i(a,0x10) ? v(d,0x28)+delta : v(d,0x28)-delta)
    }
}
