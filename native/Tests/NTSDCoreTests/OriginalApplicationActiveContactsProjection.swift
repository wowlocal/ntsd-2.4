import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Independent finite specification. Reads current owned data; never runs a
/// Core contact/hit/link handler or supplies an expected state to the game.
struct OriginalApplicationActiveContactsProjection {
    typealias S = OriginalApplicationActiveBodyControl
    typealias P = S.P
    typealias Stage = OriginalGameplayBody.Stage
    struct Helper { let entry: UInt32,args: [UInt32],result: UInt32?,returnPC: UInt32 }
    struct Point { let slot: Int,label: String,pc: UInt32,actor: OriginalStateRecord }
    static let stages: [Stage] = [.links,.contacts,.hits,.cpointActions,.cpointPlacement,.cpointCleanup,.attachments]
    var state: S
    let backgrounds: [OriginalStateRecord]
    var heap: [OriginalFrameAllocation]
    var helpers: [Helper] = [],points: [Point] = []
    var random: Int32?,broadPairs = 0,filteredITRs = 0
    init(_ own: OriginalMatchPreparation) throws {
        state = try S(own);backgrounds = own.backgrounds;heap = own.frameAllocations
    }
    init(state: S,backgrounds: [OriginalStateRecord],heap: [OriginalFrameAllocation]) {
        self.state = state;self.backgrounds = backgrounds;self.heap = heap
    }
    func at(_ slot: Int,_ offset: Int) -> Int { 0x7d8+slot*0x420+offset }
    func w(_ slot: Int,_ offset: Int) throws -> Int32 { try state.pool.integer(at:at(slot,offset),as:Int32.self) }
    func b(_ slot: Int,_ offset: Int) throws -> UInt8 { try state.pool.integer(at:at(slot,offset),as:UInt8.self) }
    func h(_ slot: Int,_ offset: Int) throws -> Int32 {
        let token = try state.pool.integer(at:at(slot,0x368),as:UInt32.self)
        return try XCTUnwrap(state.objects[token]).integer(at:offset,as:Int32.self)
    }
    func f(_ slot: Int,_ offset: Int,_ field: Int = 0x70) throws -> Int32 {
        let n = try w(slot,field);try P.require((0..<400).contains(n),"Contact current/collision/previous Frame extent")
        return try h(slot,0x7a4+Int(n)*0x178+offset)
    }
    func g(_ address: Int) throws -> Int32 { try state.globals.integer(at:address-0x44d000,as:Int32.self) }
    mutating func put(_ slot: Int,_ offset: Int,_ value: Int32) throws { try state.pool.write(value,at:at(slot,offset)) }
    mutating func global(_ address: Int,_ value: Int32) throws { try state.globals.write(value,at:address-0x44d000) }
    mutating func helper(_ entry: UInt32,_ args: [UInt32] = [],_ result: UInt32? = nil,returnPC: UInt32? = nil) {
        let fixed: [UInt32:UInt32] = [0x4450d0:0x41800b,0x4171c0:0x4173e6,0x4064d0:0x4196da,0x419380:0x41eefb,0x42e100:0x41ef47,0x417170:0x41ef71,0x418c30:0x41f2b3,0x4187b0:0x41f2b8]
        let pc = returnPC ?? fixed[entry] ?? 0
        helpers.append(.init(entry:entry,args:args,result:result,returnPC:pc))
    }
    mutating func point(_ slot: Int,_ label: String,_ pc: UInt32) throws {
        points.append(.init(slot:slot,label:label,pc:pc,actor:try S.slice(state.pool,at(slot,0),0x420)))
    }
    // Independent containment lookup, including interior offsets and known masks.
    // The opaque32-bit address is never converted into a host pointer.
    func heapWord(_ address: UInt32) throws -> Int32 {
        let matches = heap.filter { address >= $0.address && UInt64(address)-UInt64($0.address)+4 <= $0.storage.bytes.count }
        try P.require(matches.count == 1,"Contact raw allocation provenance")
        let allocation = matches[0]
        return try allocation.storage.integer(at:Int(address-allocation.address),as:Int32.self)
    }
    mutating func advance(_ stage: Stage) throws {
        try P.require(Self.stages.contains(stage),"Contact stage boundary")
        try P.require(state.pool.bytes.count == 0x7d8+400*0x420 && state.globals.bytes.count == 0xb440,"Contact whole extents")
        try P.require(state.actorTokens.count == 400 && Set(state.actorTokens).count == 400,"Contact finite distinct identities")
        for slot in 0..<400 {
            try P.require(state.pool.integer(at:4+slot,as:UInt8.self) == (slot < 2 ? 1 : 0),"Contact finite activity")
            try P.require(state.pool.integer(at:0x194+4*slot,as:UInt32.self) == state.actorTokens[slot],"Contact current slot binding")
        }
        for slot in 0..<2 {
            try P.require(h(slot,0x6f8) == 0 && h(slot,0x6f4) == (slot == 0 ? 2 : 11),"Contact finite fighter type/ID")
        }
        switch stage {
        case .links,.attachments:try depth(stage)
        case .contacts:try contacts()
        case .hits:try hits()
        case .cpointActions:
            for slot in 0..<2 {
                try P.require(f(slot,0x88,0x7c) != 1 && f(slot,0x88) != 2,"Cpoint actions need extended comparison")
            }
            helper(0x418c30)
        case .cpointPlacement:
            for slot in 0..<2 { try P.require(f(slot,0x88) != 1 || f(slot,8) != 9,"Cpoint placement needs extended comparison") }
            helper(0x4187b0)
        case .cpointCleanup:
            for slot in 0..<2 { try P.require(w(slot,0x98) <= 0,"Positive held cleanup needs extended comparison") }
        default:throw OriginalApplicationGameplaySource.error("Contact stage")
        }
    }
    mutating func depth(_ stage: Stage) throws {
        let ordinal = Int(try g(0x44d024));try P.require(backgrounds.indices.contains(ordinal),"Depth current arena")
        let bg = backgrounds[ordinal]
        for slot in 0..<2 {
            var z = try S.Actor.finite(state.pool.binary64(at:at(slot,0x68)))
            let lower = Double(try bg.integer(at:4,as:Int32.self)),upper = Double(try bg.integer(at:8,as:Int32.self))
            if z < lower { z = lower;try state.pool.writeBinary64(z,at:at(slot,0x68)) }
            if z > upper { z = upper;try state.pool.writeBinary64(z,at:at(slot,0x68)) }
            try P.require(z.isFinite && z >= Double(Int32.min) && z <= Double(Int32.max),"Depth finite conversion")
            try put(slot,0x18,Int32(z));try point(slot,"depth-return",0x41800e)
            helper(0x4450d0,[],UInt32(bitPattern:Int32(z)))
        }
        for slot in 0..<2 { try P.require(w(slot,0x98) >= 0,"Held item needs extended comparison") }
        helper(0x417f80,returnPC:stage == .links ? 0x41eed8 : 0x41f484)
    }
    func box(_ slot: Int,_ base: Int) throws -> [Int32] {
        let box = try (0..<4).map { try f(slot,base+$0*4,0x7c) }
        let x = try b(slot,0x80) == 0 ? w(slot,0x10) &- f(slot,0x50,0x7c) &+ box[0] : f(slot,0x50,0x7c) &+ w(slot,0x10) &- box[2] &- box[0]
        return try [x,w(slot,0x14) &- f(slot,0x54,0x7c) &+ box[1],box[2],box[3]]
    }
    mutating func broad(_ attack: Int,_ defend: Int) throws -> Bool {
        if try f(attack,0x128) == 0 || f(defend,0x12c) == 0 || w(attack,0xec) > 0 || Int8(bitPattern:b(defend,0xf0+attack)) > 0 { return false }
        let a = try box(attack,0x138),d = try box(defend,0x148)
        let accepted = a[0] &- d[0] < d[2] && d[0] &- a[0] < a[2] && a[1] &- d[1] < d[3] && d[1] &- a[1] < a[3]
        helper(0x4171c0,(d+a).map { UInt32(bitPattern:$0) },accepted ? 1 : 0)
        return accepted
    }
    mutating func rejectedPair(_ attack: Int,_ defend: Int) throws {
        let count = try f(attack,0x128,0x7c),bodyCount = try f(defend,0x12c,0x7c)
        if count <= 0 || bodyCount <= 0 { return }
        // The two Frame references are frozen for this pair. No branch below
        // modifies either binding; each rejection advances to the next ITR.
        let start = UInt32(bitPattern:try f(attack,0x130,0x7c))
        try P.require(count <= 1000,"Finite raw ITR loop")
        for n in 0..<Int(count) {
            let pointer = start &+ UInt32(n*80),kind = try heapWord(pointer)
            var rejected = false
            if kind == 3 { rejected = try h(defend,0x6f8) != 0 }
            if kind == 0 {
                let effect = try heapWord(pointer &+ 0x2c)
                switch effect {
                case 4:rejected = try h(defend,0x6f8) == 0
                case 20:rejected = try h(defend,0x6f8) != 0 || [18,19].contains(f(defend,8,0x78))
                case 21:rejected = try [18,19].contains(f(defend,8,0x78))
                case 30:rejected = try (200...202).contains(w(defend,0x70))
                case 2:rejected = try f(attack,8,0x78) == 19 && f(defend,8,0x78) == 18
                default:break
                }
            }
            if !rejected {
                // Installed type hook precedes invulnerability. No catalog-wide
                // absence claim substitutes for these current raw reads.
                switch kind {
                case 8,36,80...85,824:rejected = try h(defend,0x6f8) != 0
                case 86...89,800,801,808,825:rejected = try h(defend,0x6f8) != 3
                case 802...807,809:_ = try h(defend,0x6f8)
                case 810...816:rejected = try ![1,2,4,6].contains(h(defend,0x6f8))
                case 817...823:rejected = try h(defend,0x6f8) != 1
                default:break
                }
            }
            if !rejected { rejected = try w(defend,8) != 0 && kind != 8 && kind != 14 }
            try P.require(rejected,"Narrow contact/team/geometry needs extended comparison")
            filteredITRs += 1
        }
    }
    mutating func contacts() throws {
        try P.require(g(0x44d05c) != 2,"Skipped contact caller needs extended comparison")
        let mode = try g(0x451160)
        for slot in 0..<2 {
            try put(slot,0x7c,w(slot,0x70))
            if try f(slot,0x128) == 0 { try put(slot,0xec,0) }
            else { try P.require(f(slot,8) != 1001,"Weapon prefix needs extended comparison") }
        }
        for (slot,other) in [(0,1),(1,0)] {
            let rest = Int8(bitPattern:try b(slot,0xf0+other))
            if rest > 0 { try state.pool.write(rest-1,at:at(slot,0xf0+other)) }
        }
        for (attack,defend) in [(0,1),(1,0)] {
            let accepted = try broad(attack,defend)
            helper(0x417200,[UInt32(attack),UInt32(defend)],accepted ? 1 : 0,returnPC:attack == 0 ? 0x41967a : 0x419695)
            if accepted {
                broadPairs += 1;try rejectedPair(attack,defend)
                helper(0x417400,[UInt32(attack),UInt32(defend),UInt32(bitPattern:mode)],returnPC:attack == 0 ? 0x41968c : 0x4196a7)
            }
        }
        for slot in 0..<20 {
            let cooldown = try w(slot,0x338)
            if cooldown > 0 { try put(slot,0x338,cooldown-1) }
            if slot < 2 { try P.require(![7,8,51].contains(h(slot,0x6f4)),"Fusion requires extended comparison") }
        }
        helper(0x4064d0);helper(0x419380,[UInt32(bitPattern:mode)])
    }
    mutating func hits() throws {
        try global(0x45115c,0)
        for slot in 0..<2 {
            // Both finite live types are0. Empty contact count returns before
            // collision Frame/ITR reads and installed effect/movement hooks.
            try P.require(w(slot,0x2e4) == 0,"Hit resolution requires extended comparison")
            try point(slot,"hit-return",0x41ef47);helper(0x42e100,[UInt32(slot)],state.actorTokens[slot])
        }
        var index = try g(0x450bcc),counter = try g(0x450c34)
        try P.require((0..<3000).contains(index) && (0..<1234).contains(counter),"Own item RNG state")
        index = (index+1)%3000;counter = (counter+1)%1234
        let byte = try state.globals.integer(at:0x44ff90-0x44d000+Int(index),as:UInt8.self)
        let result = (Int32(byte)+counter)%200
        try global(0x450c34,counter);try global(0x450bcc,index)
        random = result;helper(0x417170,[146,200],UInt32(bitPattern:result))
        try P.require(result != 0,"Item creation requires extended comparison")
        // Second ascending pass has no signed-positive types after no creation.
    }
}
