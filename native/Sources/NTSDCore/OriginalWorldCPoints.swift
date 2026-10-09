///41f2ac..41f484: cpoint actions, placement, held-owner cleanup and second417f80.
public enum OriginalWorldCPoints {
    public enum Stage: String { case actions,placement,cleanup,attachments }
    public static func apply(state: inout OriginalMatchPreparation,retainedPartnerSlot: Int32? = nil,
                             sse2Conversion: Bool = false,
                             observe: (OriginalWorldLinksEvent) throws -> Void = { _ in },
                             afterStage: (Stage,OriginalMatchPreparation) throws -> Void = { _,_ in },
                             afterDepth: (Int,OriginalStateRecord) throws -> Void = { _,_ in }) throws {
        var next = state
        try applyInPlace(state: &next,retainedPartnerSlot: retainedPartnerSlot,sse2Conversion: sse2Conversion,observe: observe,
                         afterStage: afterStage,afterDepth: afterDepth)
        state = next
    }
    /// `apply` on the caller's state (CORE_REALTIME B2 P4): its actors and
    /// globals move into the pass, back into the state around each stage's
    /// observer, and the second links pass runs in place; on a throw the state
    /// holds them again. For callers that drop the state when this throws.
    package static func applyInPlace(state next: inout OriginalMatchPreparation,retainedPartnerSlot: Int32? = nil,
                                     sse2Conversion: Bool = false,
                                     observe: (OriginalWorldLinksEvent) throws -> Void = { _ in },
                                     afterStage: (Stage,OriginalMatchPreparation) throws -> Void = { _,_ in },
                                     afterDepth: (Int,OriginalStateRecord) throws -> Void = { _,_ in }) throws {
        var stage = Stage.actions
        let catalog = next.catalog
        var pass = OriginalCPointPass(world: next.world,actors: inPlaceTake(&next.actors,leaving: []),globals: inPlaceTake(&next.globals,leaving: .vacant),
            header: { n in
                guard catalog.objects.indices.contains(n) else { throw OriginalStateError.invalidStorage("Cpoint Object binding") }
                return catalog.objects[n].header
            },frame: { n,f in
                guard catalog.objects.indices.contains(n) else { throw OriginalStateError.invalidStorage("Cpoint Frame binding") }
                if catalog.objects[n].frameStorage.indices.contains(Int(f)) { return catalog.objects[n].frameStorage[Int(f)] }
                return try OriginalCPointPass.headerFrame(f,header: catalog.objects[n].header,object: n,site: "cpoint "+stage.rawValue)
            })
        var passHolds = true
        defer { if passHolds { next.actors = pass.actors;next.globals = pass.globals } }
        /// The stage's records into the state for its observer; `resume` takes
        /// them back for the next stage.
        func publish(_ done: Stage,resume: Bool) throws {
            next.actors = inPlaceTake(&pass.actors,leaving: []);next.globals = inPlaceTake(&pass.globals,leaving: .vacant);passHolds = false
            try afterStage(done,next)
            if resume { pass.actors = inPlaceTake(&next.actors,leaving: []);pass.globals = inPlaceTake(&next.globals,leaving: .vacant);passHolds = true }
        }
        try pass.actions(retainedPartnerSlot: retainedPartnerSlot)
        try publish(.actions,resume: true)
        stage = .placement;try pass.placement()
        try publish(.placement,resume: true)
        stage = .cleanup;try pass.cleanup()
        try publish(.cleanup,resume: false)
        try OriginalWorldLinks.applyInPlace(state: &next,sse2Conversion: sse2Conversion,observe: observe,afterDepth: afterDepth)
        try afterStage(.attachments,next)
    }
}

struct OriginalCPointPass {
    let world: OriginalStateRecord
    var actors: [OriginalStateRecord]
    var globals: OriginalStateRecord
    let header: (Int) throws -> OriginalStateRecord
    let frame: (Int,Int32) throws -> OriginalStateRecord
    //418a8a indexes the caught cpoint with raw signed vaction even after the
    //current frame has been negated. -1..-5 address the retained Object header.
    //Only a complete known extent is exposed; its initialization mask is kept.
    //
    //Frame f starts at Object+0x7a4+f·0x178, so frames ≥ 401 or ≤ −7 lie wholly
    //outside the 0x25360-byte Object allocation (400 and −6 straddle its ends).
    //The original reads them unchecked (cpoints 418c30/4187b0, links 417f80,
    //drawing 41a5a0, the post-draw scheduler), e.g. a kind-8 heal ball its hit
    //sent to frame 1000, or an item a wpoint's weaponact 1000/9998/−888 gave up.
    //That is other Windows heap memory, not recovered. Declared policy
    //(APPLICATION_OUT_OF_OBJECT_FRAMES.md, not the EXE): it reads as an absent
    //Frame — the EXE's own Frame constructor state (40bbf0: presence 0, sound
    //−1) with its untouched bytes zero. Frames 400 and −6 stay boundaries.
    static let beyondAllocation: OriginalStateRecord = {
        let absent = try! OriginalStateRecord.frame(over: [UInt8](repeating: 0,count: OriginalStateRecord.frameSize))
        return try! OriginalStateRecord(bytes: absent.bytes,defined: [Bool](repeating: true,count: OriginalStateRecord.frameSize))
    }()
    static func outsideAllocation(_ number: Int32) -> Bool { number >= 401 || number <= -7 }
    static func headerFrame(_ number: Int32,header: OriginalStateRecord,object: Int,site: String) throws -> OriginalStateRecord {
        if outsideAllocation(number) { return beyondAllocation }
        let offset = Int(UInt32(bitPattern: Int32(0x7a4) &+ number &* 0x178))
        guard offset <= header.byteCount-0x178 else {
            throw OriginalStateError.invalidStorage("Cpoint Frame outside known Object storage (\(site): Object \(object), frame \(number), header \(header.byteCount) bytes)")
        }
        return try OriginalStateRecord(bytes: Array(header.bytes[offset..<offset+0x178]),defined: Array(header.defined[offset..<offset+0x178]))
    }
    func active(_ slot: Int) throws -> UInt8 { try world.integer(at: 4+slot,as: UInt8.self) }
    func index(_ slot: Int) throws -> Int {
        guard (0..<400).contains(slot) else { throw OriginalStateError.invalidStorage("Cpoint slot extent") }
        let n = Int(try world.integer(at: 0x194+4*slot,as: UInt32.self))
        guard actors.indices.contains(n) else { throw OriginalStateError.invalidStorage("Cpoint Actor binding") };return n
    }
    func i(_ a: Int,_ o: Int) throws -> Int32 { try actors[a].integer(at: o,as: Int32.self) }
    func b(_ a: Int,_ o: Int) throws -> UInt8 { try actors[a].integer(at: o,as: UInt8.self) }
    func object(_ a: Int) throws -> Int { Int(try actors[a].integer(at: 0x368,as: UInt32.self)) }
    func f(_ a: Int,_ o: Int,_ at: Int = 0x70) throws -> Int32 { try frame(object(a),i(a,at)).integer(at: o,as: Int32.self) }
    func field(_ record: OriginalStateRecord,_ o: Int) throws -> Int32 { try record.integer(at: o,as: Int32.self) }
    mutating func put(_ a: Int,_ o: Int,_ v: Int32) throws { try actors[a].write(v,at: o) }
    mutating func add(_ a: Int,_ o: Int,_ v: Int32) throws { try put(a,o,i(a,o) &+ v) }
    mutating func number(_ a: Int,_ o: Int,_ v: Double) throws { try actors[a].writeBinary64(v,at: o) }
    mutating func face(_ a: Int,_ v: UInt8) throws { try actors[a].write(v,at: 0x80) }
    mutating func transition(_ a: Int,_ partner: Int,_ number: Int32) throws {
        try put(a,0x70,number)
        if try i(a,0x70) < 0 { try face(a,1 &- b(a,0x80));try put(a,0x70,0 &- i(a,0x70)) }
        try put(partner,0x70,f(a,0x9c));try put(partner,0x88,0);try put(a,0x88,0)
    }

    //418c30. ESI survives slot iterations; its entry value comes from caller
    //storage and is required only when a path actually dereferences it.
    mutating func actions(retainedPartnerSlot: Int32?) throws {
        var retained = retainedPartnerSlot
        func partner() throws -> Int {
            guard let retained else { throw OriginalStateError.invalidStorage("Cpoint retained partner provenance") }
            return try index(Int(retained))
        }
        for slot in 0..<400 where try active(slot) != 0 {
            let a = try index(slot),point = try frame(object(a),i(a,0x7c))
            func cp(_ o: Int) throws -> Int32 { try field(point,0x88+o) }
            if try cp(0) == 1 && i(a,0xb4) >= 0 {
                let target = try i(a,0x8c),d = try index(Int(target))
                var linked = try i(d,0x90) == Int32(slot)
                if linked { retained = target;linked = try f(d,0x88,0x7c) == 2 }
                if linked {
                    if try cp(0x30) > 0 { try add(a,0x94,0 &- cp(0x30)) }
                    if try cp(0x30) < 0 {
                        try add(a,0x94,cp(0x30))
                        if try i(a,0x94) < 0 {
                            try put(a,0x70,0);try put(partner(),0x70,0)
                            try put(a,0x20,1);try put(partner(),0x20,1)
                            let impulse: Double = try i(a,0x10) > i(partner(),0x10) ? -4 : 4
                            try number(partner(),0x28,impulse);try number(partner(),0x30,-3)
                            try put(partner(),0x70,181);linked = false
                        }
                    }
                }
                if !linked { try put(a,0x70,0) }
                else {
                    if try b(a,0xd1) != 0 && actors[a].integer(at: 0xbe,as: Int8.self) > 0 && cp(0x18) != 0 {
                        if try (b(a,0xcf) == 0 && b(a,0xd0) == 0) || cp(0x38) == 0 { try transition(a,partner(),cp(0x18)) }
                    }
                    if try b(a,0xd1) != 0 && actors[a].integer(at: 0xbe,as: Int8.self) > 0 &&
                        (b(a,0xcf) != 0 || b(a,0xd0) != 0 || b(a,0xcd) != 0 || b(a,0xce) != 0) && cp(0x38) != 0 {
                        try transition(a,partner(),cp(0x38))
                    }
                    if try b(a,0xd2) != 0 && actors[a].integer(at: 0xbf,as: Int8.self) > 0 && cp(0x1c) != 0 { try transition(a,partner(),cp(0x1c)) }
                }
                //The original continues here even after a broken reciprocal link.
                if try cp(0x24) != 0 {
                    if try cp(0x3c) > 0 { try put(partner(),0x320,cp(0x3c)) }
                    else if try cp(0x3c) == -1 {
                        try put(a,0x324,header(object(a)).integer(at: 0x6f4,as: Int32.self))
                        try put(a,0x33c,header(object(partner())).integer(at: 0x6f4,as: Int32.self))
                        try put(a,0x368,Int32(object(partner())));try put(a,0x70,0)
                        for other in 0..<400 where try active(other) != 0 {
                            let clone = try index(other)
                            if try i(clone,0x2f4) == Int32(slot) { try put(clone,0x368,Int32(object(partner()))) }
                        }
                    }
                    try put(partner(),0x14,i(a,0x14) &- f(a,0x54) &+ cp(8))
                    try number(partner(),0x60,Double(i(partner(),0x14)))
                    let x = try b(a,0x80) == 0 ? i(a,0x10) &- f(a,0x50) &+ cp(4) : f(a,0x50) &- cp(4) &+ i(a,0x10)
                    try put(partner(),0x10,x);try number(partner(),0x58,Double(i(partner(),0x10)))
                    try put(a,0x70,f(a,0x10));try put(a,0x7c,i(a,0x70));try put(a,0x88,0)
                    try number(partner(),0x40,Double(b(a,0x80) == 0 ? cp(0x24) : 0 &- cp(0x24)))
                    try put(partner(),0x70,cp(0x14));try put(partner(),0x7c,i(partner(),0x70))
                    try number(partner(),0x48,Double(cp(0x28)))
                    if try b(a,0xcd) != 0 && b(a,0xce) == 0 { try number(partner(),0x50,Double(0 &- cp(0x40))) }
                    else if try b(a,0xcd) == 0 && b(a,0xce) != 0 { try number(partner(),0x50,Double(cp(0x40))) }
                }
                if try [1,-1].contains(cp(0x34)) && i(a,0x88) == 2 {
                    if try b(a,0xd0) != 0 && b(a,0xcf) == 0 { try face(a,cp(0x34) == 1 ? 0 : 1) }
                    if try b(a,0xd0) == 0 && b(a,0xcf) != 0 { try face(a,cp(0x34) == 1 ? 1 : 0) }
                }
            } else if try f(a,0x88) == 2 {
                let owner = try i(a,0x90),d = try index(Int(owner))
                var linked = try i(d,0x8c) == Int32(slot)
                if linked { retained = owner;linked = try f(d,0x88) == 1 }
                if !linked {
                    try put(a,0x70,212);try number(a,0x48,-3)
                    let y = try actors[a].binary64(at: 0x60)
                    guard y.isFinite else { throw OriginalStateError.invalidStorage("Nonfinite caught release height") }
                    if y > -2 { try number(a,0x60,-2) }
                }
            }
        }
    }

    //41f2b8..41f47d. Clear only the owner's held-type field on invalid linkage.
    mutating func cleanup() throws {
        for slot in 0..<400 where try active(slot) != 0 {
            let a = try index(slot)
            if try i(a,0x98) <= 0 { continue }
            let target = try i(a,0x9c)
            if !(0..<400).contains(target) { try put(a,0x98,0);continue }
            if try active(Int(target)) == 0 || i(index(Int(target)),0xa0) != Int32(slot) { try put(a,0x98,0) }
        }
    }
}
