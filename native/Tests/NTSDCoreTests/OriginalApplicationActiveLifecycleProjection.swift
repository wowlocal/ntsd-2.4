import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Comparison-only current-input specification. Production lifecycle, scheduler,
/// constructor and sound routines never supply this model's expected state.
struct OriginalApplicationActiveLifecycleProjection {
    typealias S = OriginalApplicationActiveBodyControl
    typealias P = S.P
    typealias Event = GameplayLifecycleReference.Input.Event
    struct Helper {
        let entry: UInt32,returnPC: UInt32,slot: Int,args: [UInt32]
        var receiver: UInt32? = nil,result: UInt32? = nil
    }
    var state: S
    let objectOrder: [UInt32]
    var events: [Event] = [],helpers: [Helper] = []
    var scheduled: [Int] = [],created: [Int] = [],removed: [Int] = []
    init(_ own: OriginalMatchPreparation) throws {
        state = try S(own);objectOrder = own.loadedObjects.indices.map(UInt32.init)
    }
    init(_ source: S,objects: [UInt32]) { state = source;objectOrder = objects }
    func at(_ slot: Int,_ offset: Int) -> Int { 0x7d8+slot*0x420+offset }
    func i(_ slot: Int,_ offset: Int) throws -> Int32 { try state.pool.integer(at:at(slot,offset),as:Int32.self) }
    func b(_ slot: Int,_ offset: Int) throws -> UInt8 { try state.pool.integer(at:at(slot,offset),as:UInt8.self) }
    func d(_ slot: Int,_ offset: Int) throws -> Double { try S.Actor.finite(state.pool.binary64(at:at(slot,offset))) }
    func g(_ address: Int) throws -> Int32 { try state.globals.integer(at:address-0x44d000,as:Int32.self) }
    func object(_ slot: Int) throws -> OriginalStateRecord { try XCTUnwrap(state.objects[UInt32(bitPattern:i(slot,0x368))]) }
    func h(_ slot: Int,_ offset: Int) throws -> Int32 { try object(slot).integer(at:offset,as:Int32.self) }
    func frame(_ slot: Int,_ number: Int32) throws -> OriginalStateRecord {
        try P.require((0..<400).contains(number),"Lifecycle current Frame extent")
        return try S.slice(object(slot),0x7a4+Int(number)*0x178,0x178)
    }
    func f(_ slot: Int,_ offset: Int) throws -> Int32 { try frame(slot,i(slot,0x70)).integer(at:offset,as:Int32.self) }
    mutating func put(_ slot: Int,_ offset: Int,_ value: Int32) throws { try state.pool.write(value,at:at(slot,offset)) }
    mutating func byte(_ slot: Int,_ offset: Int,_ value: UInt8) throws { try state.pool.write(value,at:at(slot,offset)) }
    mutating func number(_ slot: Int,_ offset: Int,_ value: Double) throws { try state.pool.writeBinary64(S.Actor.finite(value),at:at(slot,offset)) }
    mutating func global(_ address: Int,_ value: Int32) throws { try state.globals.write(value,at:address-0x44d000) }
    mutating func sound(_ slot: Int,_ index: Int32,_ returnPC: UInt32) throws {
        try P.require((0..<400).contains(index),"Lifecycle catalog sound extent")
        let x = try i(slot,0x10),position = try x &- g(0x450bc4)
        try P.require(abs(Int64(position)) < 100_000,"Finite sound distance")
        func weight(_ center: Int32) -> Int32 {
            let distance = abs(position-center)
            return distance < 200 ? 100 : distance < 400 ? (400-distance)*100/200 : 0
        }
        let flag = 0x457588+4*Int(index),left = 0x457bc8+4*Int(index),right = 0x452170+4*Int(index)
        if try g(flag) == 0 { try global(left,0);try global(right,0) }
        try global(left,g(left) &+ weight(200));try global(right,g(right) &+ weight(600));try global(flag,1)
        events.append(.init(kind:"catalogSound",slot:slot,arguments:[UInt32(bitPattern:x),UInt32(index)]))
        helpers.append(.init(entry:0x416fb0,returnPC:returnPC,slot:slot,args:[UInt32(bitPattern:x),UInt32(index)],result:UInt32(bitPattern:weight(600))))
    }
    mutating func currentSound(_ slot: Int,_ pc: UInt32) throws {
        let index = try f(slot,0x174);if index >= 0 { try sound(slot,index,pc) }
    }
    mutating func prefix(_ slot: Int) throws {
        let type = try h(slot,0x6f8),value = try f(slot,8)
        try P.require(![9995,9996].contains(value) && !(4000..<4999).contains(value) && !(8000..<9000).contains(value),"Lifecycle transform/particle requires its comparison")
        if type == 0 {
            try P.require(i(slot,0x2fc) > 0 && i(slot,0x2fc) == i(slot,0x300) && i(slot,0x320) == 0,"Lifecycle finite healthy resource path")
            if try (i(slot,0x2f4) == -1 || i(slot,0x308) < 150) && i(slot,0x308) < 500 && g(0x450bd4) == 0 && i(slot,8) >= 0 {
                var hp = try min(i(slot,0x2fc),500)
                if try [51,52].contains(h(slot,0x6f4)) { hp /= 2 }
                try put(slot,0x308,i(slot,0x308) &+ ((500 &- hp)/100 &+ 1))
            }
        }
    }
    mutating func scheduler(_ slot: Int) throws {
        scheduled.append(slot)
        var result: UInt32?
        defer { helpers.append(.init(entry:0x40d960,returnPC:0x41fb0b,slot:slot,args:[0,UInt32(slot)],receiver:state.actorTokens[slot],result:result)) }
        let type = try h(slot,0x6f8)
        try P.require(i(slot,0xb4) == 0 || type == 3,"Lifecycle held scheduler return requires comparison")
        if try i(slot,0xec) > 0 { try put(slot,0xec,i(slot,0xec) &- 1) }
        try P.require(i(slot,0x98) >= 0 && f(slot,0x88) != 2,"Lifecycle skipped scheduler return requires comparison")
        try P.require(type != 3 || f(slot,0x24) == 0,"Lifecycle projectile HP transfer requires comparison")
        if try i(slot,8) > 0 { try put(slot,8,i(slot,8) &- 1) }
        if try i(slot,8) < 0 { try put(slot,8,i(slot,8) &+ 1) }
        for offset in [0xb0,0xb8] { if try i(slot,offset) > 0 { try put(slot,offset,i(slot,offset) &- 1) } }
        if try state.pool.integer(at:at(slot,0xea),as:Int8.self) > 0 { try byte(slot,0xea,b(slot,0xea)-1) }
        if try i(slot,0x70) != i(slot,0x74) { try currentSound(slot,0x40da70);try put(slot,0x88,0) }
        try put(slot,0x88,i(slot,0x88) &+ 1)
        if try type >= 0 && f(slot,8) == 0 && i(slot,0x14) < 0 { try put(slot,0x70,212) }
        try P.require(![14,2000].contains(f(slot,8)),"Lifecycle death/weapon scheduling requires comparison")
        if try i(slot,0x88) > f(slot,0xc) {
            try put(slot,0x88,0)
            let next = try f(slot,0x10)
            if next != 0 {
                try put(slot,0x70,next)
                if next < 0 { try byte(slot,0x80,1 &- b(slot,0x80));try put(slot,0x70,0 &- next) }
                var airReturn = false
                if try i(slot,0x70) == 999 {
                    airReturn = try type == 0 && i(slot,0x14) != 0
                    try put(slot,0x70,airReturn ? 212 : 0)
                }
                if try !(0..<400).contains(i(slot,0x70)) { result = UInt32(bitPattern:try i(slot,0x70));return }
                try P.require(frame(slot,i(slot,0x74)).integer(at:8,as:Int32.self) != 14,"Lifecycle previous death recovery requires comparison")
                if try i(slot,0x70) == 212 && !airReturn {
                    let header = try object(slot)
                    try number(slot,0x48,header.binary64(at:0x50))
                    if try b(slot,0xd0) == 1 && b(slot,0xcf) == 0 { try number(slot,0x40,header.binary64(at:0x58)) }
                    else if try b(slot,0xcf) == 1 && b(slot,0xd0) == 0 { try number(slot,0x40,-header.binary64(at:0x58)) }
                    if try b(slot,0xcd) != 0 && b(slot,0xce) == 0 { try number(slot,0x50,-header.binary64(at:0x60)) }
                    else if try b(slot,0xcd) == 0 && b(slot,0xce) != 0 { try number(slot,0x50,header.binary64(at:0x60)) }
                }
                try currentSound(slot,0x40dd24)
                try P.require(f(slot,0x4c) >= 0 || g(0x44d034) == 0,"Lifecycle negative MP redirect requires comparison")
            }
        }
        let number = try i(slot,0x70)
        if number == 110 || number == 114 { try byte(slot,0xc1,3) }
        if number == 202 { try put(slot,8,20) }
        try put(slot,0x74,number);result = UInt32(bitPattern:number)
    }
    mutating func construct(_ parent: Int,_ child: Int) throws {
        events.append(.init(kind:"reconstruct",slot:parent,arguments:[UInt32(child)]));created.append(child)
        helpers.append(.init(entry:0x4061d0,returnPC:0x41fd9d,slot:parent,args:[],receiver:state.actorTokens[child],result:0xfffffc18))
        // Recovered sparse4061d0 stores, preserving untouched backing AND masks.
        for range in [0..<0x24,0x58..<0x81,0x84..<0xbd,0xbe..<0xdd,0xe0..<0x31c,0x320..<0x368,0x36c..<0x370,0x3e8..<0x41c] {
            for offset in range { try byte(child,offset,0) }
        }
        for offset in stride(from:0x28,through:0x50,by:8) { try state.pool.write(UInt64(0x3fb999999999999a),at:at(child,offset)) }
        for offset in [0x2e8,0x2ec,0x2f0] { try put(child,offset,1000) }
        for offset in [0x2f4,0x2f8,0x324,0x328,0x32c,0x33c,0x360,0x3f8] { try put(child,offset,-1) }
        for offset in [0x2fc,0x300,0x304,0x308] { try put(child,offset,500) }
        try put(child,0x354,99)
        for offset in [0x3fc,0x400] { try put(child,offset,-1000) }
    }
    mutating func post(_ slot: Int) throws {
        let current = try i(slot,0x70)
        try P.require(current/100 != 11 && current/100 != 12,"Lifecycle linked lifetime requires comparison")
        if !(0..<400).contains(current) {
            try put(slot,0x70,0);try state.pool.write(UInt8(0),at:4+slot);removed.append(slot);return
        }
        let type = try h(slot,0x6f8)
        if type == 0 {
            try P.require(i(slot,0x2fc) > 0,"Lifecycle death launch requires comparison")
            if try i(slot,0x14) == 0 && d(slot,0x60) == 0 && d(slot,0x48) == 0 && d(slot,0x30) == 0 {
                try P.require(!((180...189).contains(current) && current != 184) && !(212...214).contains(current),"Lifecycle grounded launch requires comparison")
            }
        }
        let op = try frame(slot,current)
        func word(_ at: Int) throws -> Int32 { try op.integer(at:at,as:Int32.self) }
        let attempting = try word(0x58) > 0 && word(0x70) > 0 && i(slot,0x88) == 0 && !(i(slot,0xb4) != 0 && type == 0)
        if attempting {
            try P.require(word(0x58) == 1 && word(0x74) == 0,"Lifecycle opoint multiplicity/hold requires comparison")
            let selected = try objectOrder.first { try XCTUnwrap(state.objects[$0]).integer(at:0x6f4,as:Int32.self) == word(0x70) }
            let free = try (50..<400).first { try state.pool.integer(at:4+$0,as:UInt8.self) == 0 }
            if let selected,let child = free {
                let header = try XCTUnwrap(state.objects[selected])
                try P.require(header.integer(at:0x6f8,as:Int32.self) == 3 && header.integer(at:0x6f4,as:Int32.self) == 203,"Lifecycle finite effect Object")
                try construct(slot,child)
                try put(child,0x368,Int32(bitPattern:selected));try number(child,0x58,580)
                try put(child,0x31c,header.integer(at:0x90,as:Int32.self));try number(child,0x60,-200);try number(child,0x68,300)
                try put(child,0x354,i(slot,0x354))
                for live in 0..<400 where try state.pool.integer(at:4+live,as:UInt8.self) != 0 { try byte(live,0xf0+child,0) }
                try state.pool.write(UInt8(1),at:4+child)
                let facing = try b(slot,0x80);try P.require(facing < 2,"Lifecycle facing input")
                let x = try facing == 0 ? i(slot,0x10) &- f(slot,0x50) &+ word(0x5c) : f(slot,0x50) &- word(0x5c) &+ i(slot,0x10)
                let y = try i(slot,0x14) &- f(slot,0x54) &+ word(0x60)
                try put(child,0x10,x);try put(child,0x14,y);try put(child,0x364,i(slot,0x364))
                try number(child,0x68,d(slot,0x68)+1);try number(child,0x60,Double(y))
                try put(child,0x70,word(0x64));try number(child,0x48,Double(word(0x6c)));try number(child,0x50,0)
                try P.require(f(child,8) == 3005,"Lifecycle alternate projectile direction requires comparison")
                try byte(child,0x80,facing)
                let speed = try Double(word(0x68));try number(child,0x40,facing == 0 ? speed : -speed)
                try number(child,0x58,Double(x))
                for (decimal,integer,pc): (Int,Int,UInt32) in [(0x58,0x10,0x420232),(0x60,0x14,0x42024b),(0x68,0x18,0x420264)] {
                    let n = try d(child,decimal);try P.require(abs(n) < 100_000,"Finite lifecycle conversion")
                    let value = Int32(n.rounded(.towardZero));try put(child,integer,value)
                    helpers.append(.init(entry:0x4450d0,returnPC:pc,slot:slot,args:[],result:UInt32(bitPattern:value)))
                }
            }
        } else {
            try P.require(type == 0,"Lifecycle weapon continuation requires comparison")
            let words = try [0x40c,0x410,0x414,0x418].map { try i(slot,$0) }
            try P.require(![[9,0,9,0],[9,9,9,9],[9,5,9,5]].contains(words),"Lifecycle team command requires comparison")
        }
        let previous = try i(slot,0x78),oldState = try frame(slot,previous).integer(at:8,as:Int32.self)
        try P.require(!((oldState == 13 || previous == 200) && f(slot,8) != 13 && i(slot,0x70) != 200) && ![18,19].contains(oldState),"Lifecycle late death/fire requires comparison")
        try put(slot,0x78,i(slot,0x70))
    }
    mutating func advance() throws {
        try P.require(state.pool.bytes.count == 0x7d8+400*0x420 && state.globals.bytes.count == 0xb440 && g(0x451160) == 0,"Lifecycle whole records/mode")
        try P.require(state.actorTokens.count == 400 && Set(state.actorTokens).count == 400 && Set(objectOrder) == Set(state.objects.keys) && Set(objectOrder).count == objectOrder.count && objectOrder.count == 137,"Lifecycle finite distinct bindings")
        for slot in 0..<400 {
            try P.require(state.pool.integer(at:0x194+4*slot,as:UInt32.self) == state.actorTokens[slot],"Lifecycle live Actor mapping")
            try P.require(state.pool.integer(at:4+slot,as:UInt8.self) == (slot < 2 ? 1 : 0),"Lifecycle finite entry activity")
        }
        for slot in 0..<400 where try state.pool.integer(at:4+slot,as:UInt8.self) != 0 {
            try P.require(h(slot,0x6f8) == (slot < 2 ? 0 : 3) && [2,11,203].contains(h(slot,0x6f4)),"Lifecycle finite Object types")
            try prefix(slot);try scheduler(slot);try post(slot)
        }
    }
}
