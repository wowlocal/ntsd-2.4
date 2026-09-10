/// Native ownership of the library's second,20000-byte allocation. Only the
/// first word of an attacker's8-byte row is used by kind824/825 here.
public struct OriginalLibHitState: Equatable {
    public var targets: OriginalStateRecord
    /// Corresponds to the declared zero-filled installation allocation.
    public init() {
        targets = try! .init(bytes: [UInt8](repeating: 0,count: 20000),defined: [Bool](repeating: true,count: 20000))
    }
    public init(targets: OriginalStateRecord) throws {
        guard targets.bytes.count == 20000 else { throw OriginalStateError.invalidStorage("Library hit target extent") }
        self.targets = targets
    }
}

/// Whole42e100 with both installed effect/movement rules. Native data operations
/// preserve the original behavior without loading or executing a DLL.
public enum OriginalLibActorHits {
    public static func apply(slot: Int,state: inout OriginalMatchPreparation,crt: inout OriginalCRTRandom,
                             library: inout OriginalLibHitState,sse2: Bool = false,
                             observe: (OriginalHitEvent) throws -> Void = { _ in }) throws {
        var pass = try OriginalActorHits.makePass(state: state,crt: crt,sse2: sse2,library: library)
        try pass.resolve(slot,observe: observe)
        OriginalActorHits.publish(pass,state: &state,crt: &crt);library = pass.library!
    }

    /// Explicit data providers support controlled callers and unknown backing.
    /// Owned World/Actors/globals/heap/CRT/library storage commit together.
    public static func apply(slot: Int,world: inout OriginalStateRecord,actors: inout [OriginalStateRecord],
                             globals: inout OriginalStateRecord,allocations: inout [OriginalFrameAllocation],
                             crt: inout OriginalCRTRandom,library: inout OriginalLibHitState,objectCount: Int32,
                             header: @escaping (Int) throws -> OriginalStateRecord,
                             frame: @escaping (Int,Int32) throws -> OriginalStateRecord,
                             sse2: Bool = false,precision: OriginalArithmeticPrecision = .bits64,
                             observe: (OriginalHitEvent) throws -> Void = { _ in }) throws {
        var pass = OriginalHitPass(world: world,actors: actors,globals: globals,memory: OriginalContactFrameMemory(allocations),
            crt: crt,objectCount: objectCount,header: header,frame: frame,sse2: sse2,precision: precision,library: library)
        try pass.resolve(slot,observe: observe)
        world = pass.world;actors = pass.actors;globals = pass.globals;allocations = pass.memory.allocations
        crt = pass.crt;library = pass.library!
    }
}

/// Whole two-pass caller retains its item creation and live slot order.
public enum OriginalLibWorldHits {
    public static func apply(state: inout OriginalMatchPreparation,crt: inout OriginalCRTRandom,
                             library: inout OriginalLibHitState,retainedSpawnSlot: Int32? = nil,sse2: Bool = false,
                             observe: (OriginalHitEvent) throws -> Void = { _ in },
                             afterHit: (Int,OriginalStateRecord) throws -> Void = { _,_ in }) throws {
        var pass = try OriginalActorHits.makePass(state: state,crt: crt,sse2: sse2,library: library)
        let backgrounds = state.backgrounds
        try pass.advance(retainedSpawnSlot: retainedSpawnSlot,background: { n in
            guard backgrounds.indices.contains(Int(n)) else { throw OriginalStateError.invalidStorage("Library hit background binding") }
            return backgrounds[Int(n)]
        },observe: observe,afterHit: afterHit)
        OriginalActorHits.publish(pass,state: &state,crt: &crt);library = pass.library!
    }
}

extension OriginalHitPass {
    //42fcb1 loads ITR.effect, NOT a current Actor state. The apparent MP branch
    //at1000138d is unreachable through its preceding signed comparisons.
    mutating func libraryHitEffect(_ defender: Int) throws {
        let effect = try it(0x2c)
        guard effect >= 6000,try h(defender,0x6f8) == 0 else { return }
        let offset = UInt32(bitPattern: try i(defender,0x78)) &* 0xb2 &+ 0x7ac
        if try libraryObjectWord(object(defender),at: offset) != effect { try put(defender,0x70,effect &- 6000) }
    }

    /// Original Object byte offsets can cross two inline Frame records.
    /// Preserve the real0xb2 stride and every byte's initialization mask.
    func libraryObjectWord(_ object: Int,at offset: UInt32) throws -> Int32 {
        guard UInt64(offset)+4 <= UInt64(0x7a4+400*0x178) else {
            throw OriginalStateError.invalidStorage("Library hit read outside recovered Object storage")
        }
        var word: UInt32 = 0
        for n in 0..<4 {
            let at = Int(offset)+n,value: UInt8
            if at < 0x7a4 { value = try header(object).integer(at: at,as: UInt8.self) }
            else { value = try frame(object,Int32((at-0x7a4)/0x178)).integer(at: (at-0x7a4)%0x178,as: UInt8.self) }
            word |= UInt32(value) << (n*8)
        }
        return Int32(bitPattern: word)
    }

    //430c8c: returns true for a library-handled kind, including a target miss.
    mutating func libraryMovement(_ attacker: Int,_ defender: Int,kind: Int32) throws -> Bool {
        guard library != nil else { return false }
        //Bits: timer/frame1, binaryX2, binaryY4, binaryZ8. Writes retain order.
        let operations: Int
        switch kind {
        case 8,808,809,810,817: operations = 11
        case 80,86,802,811,818: operations = 1
        case 81,87,803,812,819: operations = 10
        case 82,88,804,813,820: operations = 12
        case 83,89,805,814,821: operations = 13
        case 84,800,806,815,822: operations = 14
        case 85,801,807,816,823,824,825: operations = 15
        default: return false
        }
        let a = try index(attacker),d = try index(defender)
        if kind == 824 || kind == 825 {
            let target = try library!.targets.integer(at: attacker*8,as: UInt32.self)
            if target == 777 { try library!.targets.write(UInt32(defender),at: attacker*8) }
            else if target != UInt32(defender) { return true }
        }
        if operations & 1 != 0 { try put(d,0xe0,it(0x44) &+ 1000);try put(a,0x70,it(0x14)) }
        if operations & 2 != 0 { try store(a,0x58,v(d,0x58)) }
        if operations & 4 != 0 { try store(a,0x60,v(d,0x60)) }
        if operations & 8 != 0 {
            //DLL10003014 contains two adjacent numeric address literals. FADD
            //reads all eight bytes directly; it does not dereference447a08.
            let addend = Double(bitPattern: 0x004176cb00447a08)
            try store(a,0x68,v(d,0x68)+constant(addend))
        }
        return true
    }
}
