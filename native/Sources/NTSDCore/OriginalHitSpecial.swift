extension OriginalHitPass {
    //43056e..43187a. These are ITR mechanisms; source IDs only occur at the
    // explicit original item/projectile exceptions.
    mutating func specialHit(_ attacker: Int,_ defender: Int,observe: (OriginalHitEvent) throws -> Void) throws {
        let a = try index(attacker),d = try index(defender),kind = try it(0)
        switch kind {
        case 6: try byte(d,0xea,3)
        case 1,3: try catchHit(attacker,defender)
        case 7:
            if try i(a,0x98) != 0 { return }
            try put(a,0x98,1);try put(d,0x98,-1);try put(d,0x364,i(a,0x364))
            try put(a,0x9c,Int32(defender));try put(d,0xa0,Int32(attacker));try put(d,0x354,Int32(attacker));try add(a,0x35c,1)
            if try [120,124].contains(h(d,0x6f4)) { try put(a,0x98,101) }
            if try h(d,0x6f8) == 4 { try put(a,0x98,4);try put(d,0x98,-4) }
            if try h(d,0x6f8) == 6 {
                if try i(d,0x2fc) > 0 { try put(a,0x98,6) }
                else { try put(a,0x98,4);try put(d,0x31c,0) }
                try put(d,0x98,0 &- i(a,0x98))
            }
        case 2:
            // The original tests each live type separately, then resets wait
            // even if no type matched. Existing ownership is not a gate here.
            for type: Int32 in [1,4,6,2] where try h(d,0x6f8) == type {
                try put(a,0x70,type == 2 ? 116 : 115)
                if type == 6 {
                    if try i(d,0x2fc) > 0 { try put(a,0x98,6) }
                    else { try put(a,0x98,4);try put(d,0x31c,0) }
                    try put(d,0x98,0 &- i(a,0x98))
                } else {
                    try put(a,0x98,type)
                    if try type == 1 && [120,124].contains(h(d,0x6f4)) { try put(a,0x98,101) }
                    try put(d,0x98,0 &- type)
                }
                //Type4/6 link writes precede the team copy in the source.
                if type == 4 || type == 6 { try put(a,0x9c,Int32(defender));try put(d,0xa0,Int32(attacker)) }
                try put(d,0x364,i(a,0x364))
                if type == 1 || type == 2 { try put(a,0x9c,Int32(defender));try put(d,0xa0,Int32(attacker)) }
                try put(d,0x354,Int32(attacker));try add(a,0x35c,1)
            }
            try put(a,0x88,0)
        case 8:
            try put(d,0xe0,it(0x44) &+ 1000);try put(a,0x70,it(0x14))
            try store(a,0x58,v(d,0x58));try store(a,0x68,v(d,0x68)+constant(1))
        case 9:
            if try h(d,0x6f8) == 3 {
                if try h(d,0xac) > -1 { try sound(d,h(d,0xac),catalog: true,observe: observe) }
                if try f(d,8) == 3005 { try put(a,0xb4,-3);try byte(d,0xeb,1);try put(d,0x70,40) }
                else {
                    try put(a,0xb4,-3);try copyCredit(a,d);try byte(d,0xeb,1);try put(d,0x354,i(a,0x354));try put(d,0x70,30);try put(d,0x88,0)
                    for o in [0x30,0x48,0x28,0x40,0x38,0x50] { try number(d,o,0) };try put(d,0,Int32(attacker))
                }
            } else if try h(d,0x6f8) == 0 { try put(a,0x2fc,0) }
        case 10,11:
            if try kind == 10 || i(d,0x320) < 0 { try pullingHit(a,d,damped: true) }
        case 14: try obstructionHit(a,d)
        case 15,16:
            if try h(d,0x6f8) == 0 && kind == 16 {
                try damage(a,d);try put(d,0x70,200);try put(d,0x88,0);try sound(d,14,observe: observe)
                if try it(0x24) > 0 { try byte(d,0xf0+attacker,UInt8(truncatingIfNeeded: it(0x24))) }
                try dropHeavy(attacker,defender,stream: 244,observe: observe)
            } else { try pullingHit(a,d,damped: false) }
        default: break
        }
    }
    //The two original catch bodies430593/430ea4 have identical operations.
    mutating func catchHit(_ attacker: Int,_ defender: Int) throws {
        let a = try index(attacker),d = try index(defender)
        try number(d,0x40,0);try number(a,0x40,0)
        try byte(a,0x80,i(a,0x10) > i(d,0x10) ? 1 : 0);try byte(d,0x80,1 &- b(a,0x80))
        try put(a,0x70,it(0x30));try put(d,0x70,it(0x38))
        let ax = try field(frame(object(a),it(0x30)),0x8c),dx = try field(frame(object(d),it(0x38)),0x8c)
        try number(a,0x58,Double(i(a,0x10)));try number(a,0x60,Double(i(a,0x14)))
        //Both horizontal centers intentionally come from the ATTACKER Object,
        //including the one indexed by the defender's catchingact frame.
        let cx1 = try field(frame(object(a),it(0x30)),0x50),cx2 = try field(frame(object(a),it(0x38)),0x50)
        let x = try b(a,0x80) == 0 ? i(a,0x10) &- cx1 &- cx2 &+ dx &+ ax : cx1 &+ cx2 &+ i(a,0x10) &- dx &- ax
        try number(d,0x58,Double(x))
        let y = try field(frame(object(d),it(0x38)),0x54) &- field(frame(object(a),it(0x30)),0x54) &+ i(a,0x14)
        try number(d,0x60,Double(y))
        let half = try (constant(Double(i(d,0x10)))-v(d,0x58))*constant(0.5)
        try store(d,0x58,v(d,0x58)+half);try store(a,0x58,half+v(a,0x58))
        try put(d,0x10,OriginalCoordinateConversion.integer(v(d,0x58),sse2: sse2))
        try put(a,0x10,OriginalCoordinateConversion.integer(v(a,0x58),sse2: sse2))
        try put(a,0x8c,Int32(defender));try put(d,0x90,Int32(attacker));try put(a,0x94,300);try put(d,0xb0,0)
    }
    mutating func obstructionHit(_ a: Int,_ d: Int) throws {
        let zero = try constant(0)
        if try i(a,0x10) > i(d,0x10) &+ 5 && (v(d,0x40) > zero || v(d,0x28) > zero) { try put(d,0x3f4,1) }
        else if try i(a,0x10) < i(d,0x10) &- 5 && (v(d,0x40) < zero || v(d,0x28) < zero) { try put(d,0x3f0,1) }
        if try i(a,0x18) > i(d,0x18) &+ 2 && (v(d,0x50) > zero || v(d,0x38) > zero) { try put(d,0x3ec,1) }
        else if try i(a,0x18) < i(d,0x18) &- 2 && (v(d,0x50) < zero || v(d,0x38) < zero) { try put(d,0x3e8,1) }
    }
    //10/11 use damping;15/16 pull toward the source. Type2 uses2.3 rather
    //than3 for vertical acceleration. The source does not update binary y.
    mutating func pullingHit(_ a: Int,_ d: Int,damped: Bool) throws {
        let type = try h(d,0x6f8)
        if type == 0 && damped {
            try put(d,0x320,-20)
            if try h(d,0x6f8) == 0 && i(d,0x2f4) == -1 && globals.integer(at: 0x450bd0-0x44d000,as: Int32.self) == 0 { try add(index(Int(i(a,0x354))),0x348,11) }
            let team = try i(d,0x344)
            if (1...2).contains(team) { let o = 0x451b68-0x44d000+Int(team)*4;try globals.write(globals.integer(at: o,as: Int32.self) &+ 11,at: o) }
        } else if [1,4,6].contains(type) {
            if try [201,202].contains(h(d,0x6f4)) { return }
            if try f(d,8) != 1000 { try put(d,0x70,0) }
        } else if type == 2 {
            if try f(d,8) != 2000 { try put(d,0x70,0) }
        } else if type != 0 { return }
        if damped { try store(d,0x28,v(d,0x40)/constant(1.07)) }
        else { try store(d,0x28,i(d,0x10) > i(a,0x10) ? v(d,0x40)-constant(1) : v(d,0x40)+constant(1)) }
        try store(d,0x40,v(d,0x28))
        if damped { try store(d,0x38,v(d,0x50)/constant(1.07)) }
        else { try store(d,0x38,i(d,0x18) > i(a,0x18) ? v(d,0x50)-constant(0.5) : v(d,0x50)+constant(0.5)) }
        try store(d,0x50,v(d,0x38))
        if type == 0 && damped { try put(d,0x70,182) }
        if try i(d,0x14) >= -2 { try put(d,0x14,-2);try number(d,0x48,-6) }
        if try v(d,0x48) > constant(-6) {
            try store(d,0x48,v(d,0x48)-constant(type == 2 ? 2.3 : 3));try store(d,0x30,v(d,0x48))
        }
    }
}
