extension OriginalCPointPass {
    //4187b0..418c2f uses CURRENT Frames, after the entire action pass.
    mutating func placement() throws {
        for slot in 0..<400 where try active(slot) != 0 {
            let a = try index(slot),point = try frame(object(a),i(a,0x70))
            func cp(_ o: Int) throws -> Int32 { try field(point,0x88+o) }
            if try cp(0) != 1 || f(a,8) != 9 { continue }
            let d = try index(Int(i(a,0x8c)))
            if try i(d,0x90) != Int32(slot) || f(d,0x88) != 2 { continue }
            if try (i(d,0xb4) == 0 && cp(0x2c) == 1) || cp(0x2c) == 0 { try put(d,0x70,cp(0x14)) }
            if try i(d,0x70) < 0 { try face(d,1 &- b(d,0x80));try put(d,0x70,0 &- i(d,0x70)) }
            if try cp(0xc) != 0 && i(a,0x88) == 0 {
                if try cp(0xc) > 0 {
                    var injury = try cp(0xc)
                    let divisor = try i(d,0x340)
                    if divisor > 0 { injury = (injury &* 100)/divisor }
                    if try i(d,0x2fc) > 0 && injury >= i(d,0x2fc) && i(d,0x2f4) == -1 {
                        try add(index(Int(i(a,0x354))),0x358,1)
                        let team = try i(d,0x344)
                        if (1...2).contains(team) { let o = 0x451b60-0x44d000+Int(team)*4;try globals.write(globals.integer(at: o,as: Int32.self) &+ 1,at: o) }
                    }
                    try add(d,0x2fc,0 &- injury);try add(d,0x300,0 &- (injury/3))
                    try put(a,0x88,1);try put(a,0xb4,2);try put(d,0xb4,-3)
                    try add(d,0x34c,injury);try add(index(Int(i(a,0x354))),0x348,injury)
                    let team = try i(d,0x344)
                    if (1...2).contains(team) { let o = 0x451b68-0x44d000+Int(team)*4;try globals.write(globals.integer(at: o,as: Int32.self) &+ injury,at: o) }
                } else {
                    try add(d,0x2fc,cp(0xc));try add(d,0x300,cp(0xc)/3);try put(a,0x88,1)
                }
            }
            let x = try b(a,0x80) == 0 ? i(a,0x10) &- f(a,0x50) &+ cp(4) : f(a,0x50) &- cp(4) &+ i(a,0x10)
            let y = try i(a,0x14) &- f(a,0x54) &+ cp(8)
            //The caught cpoint is indexed by the captor's raw vaction, while
            //caught centers use the partner's possibly different current Frame.
            let caught = try frame(object(d),cp(0x14))
            if try b(d,0x80) == 0 { try put(d,0x10,f(d,0x50) &- field(caught,0x8c) &+ x) }
            else { try put(d,0x10,field(caught,0x8c) &- f(d,0x50) &+ x) }
            try put(d,0x14,f(d,0x54) &- field(caught,0x90) &+ y);try put(d,0x18,i(a,0x18))
            if try cp(0x10)%10 != 0 { try add(d,0x18,1);try add(d,0x14,-1) }
            else { try add(d,0x18,-1);try add(d,0x14,1) }
            if try cp(0x10)/10 == 1 { try face(d,b(a,0x80)) }
            else if try cp(0x10)/10 == 2 { try face(d,1 &- b(a,0x80)) }
            for (integer,binary) in [(0x18,0x68),(0x10,0x58),(0x14,0x60)] { try number(d,binary,Double(i(d,integer))) }
        }
    }
}
