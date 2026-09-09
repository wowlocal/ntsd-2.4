// Whole4064d0..406a1f, called unconditionally at the end of419380.
// Source IDs7/8/51 are explicit EXE branches. Catalog entries remain ordinals;
// duplicate IDs and World Actor aliases retain their original ordered effects.
extension OriginalContactPass {
    mutating func fusion(observe: (OriginalWorldContactsEvent) throws -> Void = { _ in }) throws {
        for slot in 0..<20 {
            let a = try index(slot)
            if try i(a,0x338) > 0 { try put(a,0x338,i(a,0x338) &- 1) }
            guard try active(slot) == 1 else { continue }
            if try [7,8].contains(h(a,0x6f4)) && i(a,0x2fc) > 0 && f(a,8) == 2 && i(a,0x338) == 0 &&
                (i(a,0x2fc) < 177 || globals.integer(at: 0x458428-0x44d000,as: Int32.self) == 1) {
                for other in 0..<20 where try active(other) == 1 {
                    let d = try index(other)
                    guard try h(d,0x6f4) == 15 &- h(a,0x6f4) else { continue }
                    let otherHP = try i(d,0x2fc)
                    guard otherHP > 0,try i(a,0x364) == i(d,0x364),try i(d,0x338) == 0,
                          try otherHP < 177 || globals.integer(at: 0x458428-0x44d000,as: Int32.self) == 1,
                          try (0..<400).contains(i(d,0x70)) else { continue }
                    let otherState = try f(d,8)
                    guard try otherState == 2 || (otherState != 14 && i(d,0x14) == 0 && other > 9),
                          try Self.magnitude(i(a,0x10) &- i(d,0x10)) < 50,
                          try Self.magnitude(i(a,0x18) &- i(d,0x18)) < 8,
                          try i(a,0x10) > i(d,0x10) || other > 9,slot < 10 else { continue }
                    var replacement: Int?
                    if objectCount > 0 {
                        for n in 0..<Int(objectCount) where try header(n).integer(at: 0x6f4,as: Int32.self) == 51 { replacement = n;break }
                    }
                    guard let replacement else { continue }
                    try put(a,0x2fc,i(a,0x2fc) &+ otherHP);try put(a,0x300,i(a,0x300) &+ i(d,0x300))
                    if try i(a,0x300) > i(a,0x304) { try put(a,0x300,i(a,0x304)) }
                    if try i(a,0x2fc) > i(a,0x300) { try put(a,0x2fc,i(a,0x300)) }
                    try put(a,0x70,290);try put(a,0x328,1);try store(a,0x40,0);try store(d,0x48,0)
                    try put(a,0x10,(i(d,0x10) &+ i(a,0x10))/2);try put(a,0x18,(i(d,0x18) &+ i(a,0x18))/2)
                    try store(a,0x58,Double(i(a,0x10)));try store(a,0x68,Double(i(a,0x18)))
                    try put(a,0x32c,Int32(other));try put(a,0x338,4500)
                    try put(a,0x330,h(a,0x6f4));try put(a,0x334,h(d,0x6f4))
                    try actors[a].write(UInt32(replacement),at: 0x368);try put(a,0x308,500);try world.write(UInt8(0),at: 4+other)
                    // No early break: the source continues, reloading the new ID.
                }
            } else if try h(a,0x6f4) == 51 && i(a,0x328) == 1 && (i(a,0x70) < 9 || i(a,0x70) > 260) && i(a,0x338) <= 0 {
                let other = Int(try i(a,0x32c))
                try put(a,0x328,-1);try put(a,0x338,900)
                if objectCount > 0 {
                    for n in 0..<Int(objectCount) {
                        let id = try header(n).integer(at: 0x6f4,as: Int32.self)
                        if try id == i(a,0x330) { try actors[a].write(UInt32(n),at: 0x368) }
                        else if try id == i(a,0x334) {
                            let d = try index(other)
                            try observe(.reconstruct(slot: slot,created: other));try actors[d].reconstructActor()
                            try actors[d].write(UInt32(n),at: 0x368);try store(d,0x58,580)
                            try put(d,0x31c,header(n).integer(at: 0x90,as: Int32.self));try store(d,0x60,-200);try store(d,0x68,300)
                            try world.write(UInt8(1),at: 4+other)
                        }
                    }
                }
                let d = try index(other)
                try put(d,0x2fc,i(a,0x2fc)/2);try put(d,0x300,i(a,0x300)/2)
                try put(a,0x2fc,i(a,0x2fc)/2);try put(a,0x300,i(a,0x300)/2)
                try put(d,0x10,i(a,0x10));try put(d,0x18,i(a,0x18));try put(d,0x14,0)
                try store(d,0x58,Double(i(d,0x10)));try store(d,0x68,Double(i(d,0x18)));try store(d,0x60,0)
                try store(a,0x40,0);try store(d,0x40,0);try actors[d].write(UInt8(1) &- b(a,0x80),at: 0x80)
                try put(a,0x70,112);try put(d,0x70,112);try put(a,0x308,0);try put(d,0x308,0);try put(d,0x364,i(a,0x364))
            }
        }
    }
}
