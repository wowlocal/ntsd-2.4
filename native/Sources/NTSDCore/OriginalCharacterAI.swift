public enum OriginalCharacterAIEvent: Equatable {
    case random(stream: Int32,range: Int32,result: Int32)
}

/// Character AI child 4094b0(World, slot, mode), called by419a60 for slots
/// 10..399 whose Object type is 0. It emulates a player: the current button
/// bytes (Actor+0xcd up, ce down, cf left, d0 right, d1 attack, d2 jump,
/// d3 defend) and their previous copies (c6..cc), plus special-move command
/// bytes 0xd4..0xdc. Helpers 4034f0, 408cb0 and the special-move selector
/// 403a40 (every own-id block) are complete.
public enum OriginalCharacterAI {
    public static func apply(slot: Int,mode: Int32,state: inout OriginalMatchPreparation,sse2: Bool = false,
                             observe: (OriginalCharacterAIEvent) throws -> Void = { _ in }) throws {
        // All or nothing: the pass runs in place on a copy, whose records are
        // assigned only when it completes.
        var copy = state
        try applyInPlace(slot: slot,mode: mode,state: &copy,sse2: sse2,observe: observe)
        state.world = copy.world; state.actors = copy.actors; state.globals = copy.globals
    }
    /// `apply` with the caller's world, actors and globals moved into the pass
    /// and written back on every path (CORE_REALTIME B2): for callers that drop
    /// the state when this throws.
    package static func applyInPlace(slot: Int,mode: Int32,state: inout OriginalMatchPreparation,sse2: Bool = false,
                                     observe: (OriginalCharacterAIEvent) throws -> Void = { _ in }) throws {
        let catalog = state.catalog
        guard try state.world.integer(at: 0x7d4,as: UInt32.self) == 0,
              let registry = catalog.registry.records[0x4d82380] else { throw OriginalStateError.invalidStorage("Character-AI catalog binding") }
        let objectCount = try registry.integer(at: 0,as: Int32.self),backgrounds = state.backgrounds
        var pass = OriginalCharacterAIPass(world: inPlaceTake(&state.world,leaving: .vacant),actors: inPlaceTake(&state.actors,leaving: []),
                                           globals: inPlaceTake(&state.globals,leaving: .vacant),objects: catalog.objects,
                                           objectCount: objectCount,backgrounds: backgrounds,sse2: sse2)
        defer { state.world = pass.world; state.actors = pass.actors; state.globals = pass.globals }
        try pass.run(slot,mode: mode)
        for event in pass.events { try observe(event) }
    }
}

struct OriginalCharacterAIPass {
    var world: OriginalStateRecord
    var actors: [OriginalStateRecord]
    var globals: OriginalStateRecord
    let objects: [OriginalLoadedObject]
    let objectCount: Int32
    let backgrounds: [OriginalStateRecord]
    let sse2: Bool
    var events: [OriginalCharacterAIEvent] = []

    enum Key: Int { case up = 0xcd, down, left, right, attack, jump, defend }

    func error(_ message: String) -> OriginalStateError { .invalidStorage(message) }
    func g(_ address: Int) throws -> Int32 { try globals.integer(at: address-0x44d000,as: Int32.self) }
    mutating func setG(_ address: Int,_ value: Int32) throws { try globals.write(value,at: address-0x44d000) }
    func active(_ slot: Int) throws -> UInt8 {
        guard (0..<400).contains(slot) else { throw error("Character-AI activity outside slots 0..399") }
        return try world.integer(at: 4+slot,as: UInt8.self)
    }
    func index(_ slot: Int) throws -> Int {
        guard (0..<400).contains(slot) else { throw error("Character-AI Actor table outside slots 0..399") }
        let a = Int(try world.integer(at: 0x194+slot*4,as: UInt32.self))
        guard actors.indices.contains(a) else { throw error("Character-AI Actor binding") }
        return a
    }
    func i(_ a: Int,_ o: Int) throws -> Int32 { try actors[a].integer(at: o,as: Int32.self) }
    func facing(_ a: Int) throws -> UInt8 { try actors[a].integer(at: 0x80,as: UInt8.self) }
    func object(_ a: Int) throws -> Int {
        let n = Int(try actors[a].integer(at: 0x368,as: UInt32.self))
        guard objects.indices.contains(n) else { throw error("Character-AI Object binding") }
        return n
    }
    func id(_ a: Int) throws -> Int32 { try objects[object(a)].header.integer(at: 0x6f4,as: Int32.self) }
    func type(_ a: Int) throws -> Int32 { try objects[object(a)].header.integer(at: 0x6f8,as: Int32.self) }
    func state(_ a: Int) throws -> Int32 {
        let n = try object(a),f = try i(a,0x70)
        guard objects[n].frameStorage.indices.contains(Int(f)) else { throw error("Character-AI Frame binding") }
        return try objects[n].frameStorage[Int(f)].integer(at: 8,as: Int32.self)
    }
    func v(_ a: Int,_ o: Int) throws -> OriginalExtended { try OriginalExtended(actors[a].binary64(at: o)) }
    /// 4450d0 on a loaded binary64 (legacy x87 path or the declared SSE2 path).
    func ftol(_ a: Int,_ o: Int) throws -> Int32 { OriginalCoordinateConversion.integer(try actors[a].binary64(at: o),sse2: sse2) }
    mutating func put(_ a: Int,_ o: Int,_ value: Int32) throws { try actors[a].write(value,at: o) }
    mutating func byte(_ a: Int,_ o: Int,_ value: UInt8) throws { try actors[a].write(value,at: o) }
    mutating func press(_ a: Int,_ key: Key) throws { try byte(a,key.rawValue,1) }
    mutating func release(_ a: Int,_ key: Key) throws { try byte(a,key.rawValue-7,0) }
    /// prev = cur, then cur = 0 for all seven buttons.
    mutating func shift(_ a: Int) throws {
        for n in 0..<7 { try byte(a,0xc6+n,actors[a].integer(at: 0xcd+n,as: UInt8.self)) }
        for n in 0..<7 { try byte(a,0xcd+n,0) }
    }
    func abs(_ value: Int32) -> Int32 { value < 0 ? 0 &- value : value } // 4034e0
    mutating func draw(_ stream: Int32,_ range: Int32) throws -> Int32 {
        var rng = OriginalRandom(table: try OriginalRandom.table(globals, at: 0x44ff90-0x44d000),
            index: Int(try g(0x450bcc)),counter: Int(try g(0x450c34)),source: "owned character AI",sourceSHA256: "")
        try rng.validate(); let result = Int32(rng.next(Int(range)))
        try setG(0x450bcc,Int32(rng.index)); try setG(0x450c34,Int32(rng.counter))
        events.append(.random(stream: stream,range: range,result: result)); return result
    }
    func background(_ bg: Int32,_ o: Int) throws -> Int32 {
        guard backgrounds.indices.contains(Int(bg)) else { throw error("Character-AI background binding") }
        return try backgrounds[Int(bg)].integer(at: o,as: Int32.self)
    }
    /// The recurring "outside 150/240 of the target" test guarded by Actor+0x404.
    func far(_ s: Int,_ t: Int) throws -> Bool {
        try i(s,0x404) != 0 && (abs(i(s,0x18) &- i(t,0x18)) > 150 || abs(i(s,0x10) &- i(t,0x10)) > 240)
    }
    func enemy(_ s: Int,_ t: Int,mode: Int32) throws -> Bool {
        let tt = try i(t,0x364),st = try i(s,0x364)
        return tt != st && (mode != 1 || st == 5 || tt == 5)
    }

    mutating func run(_ slot: Int,mode: Int32) throws {
        let s = try index(slot)
        // A: scripted run to the right (4094c9..409613).
        if mode == 1, try g(0x450bac) == 1 {
            try shift(s); try press(s,.right); try release(s,.right)
            if try i(s,0x3f4) == 1 { try release(s,.attack); try press(s,.attack) }
            return
        }
        // B: walk to a point (409616..409925).
        if try i(s,0x3fc) > -1000 { try walk(s); return }
        var l = Locals(); try setup(s,slot: slot,mode: mode,&l)
        try search(s,slot: slot,mode: mode,&l)
        try shift(s)
        l.self58 = l.target
        guard l.target >= 0 else { try idle(s,&l); return }
        try items(s,&l)
        if l.near48 == 1 { l.target = l.self58 }
        guard l.target >= 0 else { try idle(s,&l); return }
        try fight(s,slot: slot,mode: mode,&l)
    }

    struct Locals {
        var nearest38: Int32 = 10000,lying48: Int32 = 10000,item50: Int32 = 10000,target: Int32 = -1,bg: Int32 = 0
        var aligned34: Int32 = 0,allies10: Int32 = 0,hurt1c: Int32 = 0,healthy18: Int32 = 0,avoid2c: Int32 = 0
        var down3c: Int32 = 0,up40: Int32 = 0,left14: Int32 = 0,right20: Int32 = 0,ball30: Int32 = 0,near48: Int32 = 0,seen44: Int32 = 0
        var self58: Int32 = -1,sState: Int32 = 0,tState: Int32 = 0
    }

    mutating func walk(_ s: Int) throws {
        let st = try state(s)
        try shift(s)
        let x = try i(s,0x10),px = try i(s,0x3fc)
        if x > px &+ 6 {
            try press(s,.left)
            if try i(s,0x10) > i(s,0x3fc) &+ 250, try draw(0x11,g(0x44f61c) &+ 3) == 0 { try release(s,.left) }
            if try i(s,0x10) < i(s,0x3fc) &+ 100, st == 2, try facing(s) == 1 { try press(s,.right) }
        } else if x < px &- 6 {
            try press(s,.right)
            if try i(s,0x10) < i(s,0x3fc) &- 250, try draw(0x12,g(0x44f61c) &+ 3) == 0 { try release(s,.right) }
            if try i(s,0x10) > i(s,0x3fc) &- 100, st == 2, try facing(s) == 0 { try press(s,.left) }
        }
        if try i(s,0x18) < i(s,0x400) &- 3 { try press(s,.down) }
        else if try i(s,0x18) > i(s,0x400) &+ 3 { try press(s,.up) }
        if try i(s,0x3f4) == 1 || i(s,0x3f0) == 1 { try release(s,.attack); try press(s,.attack) }
        if try abs(i(s,0x400) &- i(s,0x18)) > 90 || abs(i(s,0x3fc) &- i(s,0x10)) > 90 { return }
        try put(s,0x3fc,-1000); try put(s,0x400,-1000)
    }

    /// 409928..409ff0: difficulty globals, ally/health flags and avoidance.
    mutating func setup(_ s: Int,slot: Int,mode: Int32,_ l: inout Locals) throws {
        l.bg = try g(0x44d024)
        var width = try g(0x450bb4)
        if width <= 0 { width = try background(l.bg,0) }
        try setG(0x44f604,width)
        var level: Int32 = 0
        if try g(0x450c2c) != 1 {
            let easy = try mode == 1 && i(s,0x364) != 5 && (slot < 20 || id(s) < 30)
            if !easy { level = max(try g(0x450c30),0) }
        }
        try setG(0x44f60c,level)
        try setG(0x44f61c,level &* 3); try setG(0x44f618,level &* 5); try setG(0x44f614,level &* 15); try setG(0x44f610,level &* 20)
        try setG(0x44f608,0)
        if mode == 1 || mode == 4, try i(s,0x364) != 5 {
            let team = try i(s,0x364),max = try i(s,0x304),hp = try i(s,0x2fc)
            l.hurt1c = hp > (max &* 4)/5 || hp > max &- 130 ? 0 : 1
            for k in 0..<400 where k != slot {
                guard try active(k) != 0 else { continue }
                let t = try index(k)
                guard try i(t,0x2fc) > 0, try type(t) == 0, try i(t,0x364) == team else { continue }
                if try i(t,0x2fc) < i(s,0x2fc) { l.hurt1c = 0 }
                l.allies10 &+= 1
            }
            let own = try i(s,0x2fc)
            l.healthy18 = try own > 430 || own > i(s,0x304) &- 130 ? 1 : 0
            for k in 0..<400 where k != slot {
                guard try active(k) != 0 else { continue }
                let t = try index(k)
                guard try i(t,0x2fc) > 0, try type(t) == 0, try i(t,0x364) == team else { continue }
                if try i(t,0x2fc) < own &- 200 { l.healthy18 = 1 }
            }
            if mode == 1 {
                var maxX: Int32 = -1,maxZ: Int32 = 0
                for k in 0..<10 where k != slot {
                    guard try active(k) != 0 else { continue }
                    let t = try index(k)
                    guard try i(t,0x2fc) > 0, try type(t) == 0, try i(t,0x10) > maxX else { continue }
                    maxX = try i(t,0x10); maxZ = try i(t,0x18)
                }
                if maxX > -1 {
                    let x = try i(s,0x10)
                    if x > maxX, try abs(i(s,0x18) &- maxZ)/2 &- maxX &+ x > 200 { try setG(0x44f608,1) }
                    if try i(s,0x10) > maxX &+ 400 { try setG(0x44f608,2) }
                }
            }
            if l.allies10 == 0 { l.hurt1c = 0 }
        }
        if try i(s,0x2f4) > -1 { l.healthy18 = 1; l.avoid2c = 1 }
        if try i(s,0x308) > 250 { l.avoid2c = 1 }
        if try mode == 1 && i(s,0x364) == 1 { l.avoid2c = 1 }
        if slot >= 20 && mode == 4 { l.avoid2c = 1 }
    }

    /// 409ff4..40a31f: nearest standing enemy or approaching projectile, else a
    /// near lying enemy; a remembered target (+0x360) may be kept.
    mutating func search(_ s: Int,slot: Int,mode: Int32,_ l: inout Locals) throws {
        let zero = try OriginalExtended(0)
        for k in 0..<400 where k != slot {
            guard try active(k) != 0 else { continue }
            let t = try index(k)
            if try type(t) != 0 {
                guard try state(t) == 3000 else { continue }
                let tx = try i(t,0x10),sx = try i(s,0x10)
                if tx > sx { guard try zero > v(t,0x40) else { continue } }
                else if tx < sx { guard try zero < v(t,0x40) else { continue } }
                else { continue }
            }
            guard try enemy(s,t,mode: mode), try i(t,0x2fc) > 0, try state(t) != 14, try abs(i(t,8)) <= 2 else { continue }
            let d = try abs(i(t,0x18) &- i(s,0x18)) &+ abs(i(t,0x10) &- i(s,0x10))
            if d < l.nearest38 { l.target = Int32(k); l.nearest38 = d }
        }
        if l.target >= 0, try abs(i(index(Int(l.target)),0x18) &- i(s,0x18)) < 15 { l.aligned34 = 1 }
        if try state(s) != 9 {
            for k in 0..<400 where k != slot {
                guard try active(k) != 0 else { continue }
                let t = try index(k)
                guard try enemy(s,t,mode: mode), try i(t,0x2fc) > 0 else { continue }
                guard try state(t) == 14 || abs(i(t,8)) > 2 else { continue }
                let dz = try abs(i(t,0x18) &- i(s,0x18)),dx = try abs(i(t,0x10) &- i(s,0x10)),d = dz &+ dx
                if d < l.lying48 && dz < 40 && dx < 250 { l.target = Int32(k); l.lying48 = d }
            }
        }
        let remembered = try i(s,0x360)
        if remembered > -1 && remembered < 400 {
            let e = Int(remembered)
            if try active(e) == 1, try i(index(e),0x2fc) > 0, try draw(0x13,30) > 0, try type(index(e)) == 0 { l.target = remembered; return }
        }
        try put(s,0x360,l.target)
    }

    /// 40a43b..40a90a: items, healing balls and dangers in slots 20..399.
    mutating func items(_ s: Int,_ l: inout Locals) throws {
        for k in 20..<400 {
            guard try active(k) != 0 else { continue }
            let t = try index(k),id = try id(t)
            if id == 200 {
                let group = try i(t,0x70)/10
                var go = false
                if try group == 6 && i(t,0x364) != i(s,0x364) { go = true }
                else if group == 5, try [2,34].contains(self.id(s)) {
                    let hp = try i(s,0x2fc),max = try i(s,0x304)
                    let first = hp >= max &- 70 || hp >= max &- 200
                    let second = hp >= (max &* 3)/5 || hp < max &- 200
                    go = try first && second && i(t,0x364) == i(s,0x364)
                }
                if go {
                    l.near48 = 1
                    let dz = try abs(i(t,0x18) &- i(s,0x18))
                    if dz < 25 {
                        let dx = try abs(i(t,0x10) &- i(s,0x10))
                        if dx < 150 {
                            l.ball30 = 1
                            if dz < 20 {
                                if dx < 180 { if try i(t,0x18) > i(s,0x18) { l.down3c = 1 } else { l.up40 = 1 } }
                                if try i(t,0x10) > i(s,0x10) { l.right20 = 1 } else { l.left14 = 1 }
                            }
                        }
                    }
                }
            }
            let frame = try i(t,0x70)
            if try (id == 211 && state(t) == 18) || (id == 212 && frame >= 150 && frame <= 170) {
                let tx = try i(t,0x10),sx = try i(s,0x10)
                if abs(tx &- sx) < 80 {
                    if try i(t,0x18) > i(s,0x18) &+ 20 { l.down3c = 1 }
                    else if try i(t,0x18) < i(s,0x18) &+ -20 { l.up40 = 1 }
                }
                if try abs(i(t,0x18) &- i(s,0x18)) < 20 {
                    if tx > sx &+ 100 { l.right20 = 1 } else if tx < sx &+ -100 { l.left14 = 1 }
                }
            }
            if l.seen44 != 0 { if l.seen44 > 1 { continue } }
            else if l.aligned34 == 0 && l.near48 == 0 {
                let d = try abs(i(t,0x18) &- i(s,0x18)) &+ abs(i(t,0x10) &- i(s,0x10))
                if try i(s,0x98) == 0, d < l.nearest38 &* 2, d < l.item50, id/100 == 1 || id == 213, try i(t,0x98) == 0,
                   try [1004,2004].contains(state(t)), !(l.healthy18 != 0 && id == 122), !(l.avoid2c != 0 && id == 123),
                   try !(i(s,0x404) == 1 && id != 122) {
                    l.target = Int32(k); l.item50 = d
                }
            }
            if id == 200, try i(t,0x70)/10 == 5 {
                if try abs(i(t,0x10) &- i(s,0x10)) < 300, try abs(i(t,0x18) &- i(s,0x18)) < 90, try i(t,0x364) == i(s,0x364) {
                    let hp = try i(s,0x2fc),max = try i(s,0x300)
                    let want: Bool
                    if hp < max &- 70 && hp < 140 { want = true }
                    else { want = !(hp >= (max &* 3)/5) && !(hp < 140) }
                    if want { l.target = Int32(k) }
                    l.seen44 = 1
                }
            }
            if l.hurt1c == 1, id == 122, try state(t) == 1004, try i(s,0x98) == 0 { l.target = Int32(k); l.seen44 = 1 }
        }
    }

    /// 40b7b5..40b846: no target.
    mutating func idle(_ s: Int,_ l: inout Locals) throws {
        // With no target the EXE reads World+0x7d4 (the catalog pointer) as an
        // Actor when +0x404 is set: its "z" is an Object pointer. Every mapped
        // Win32 address is ≥ 0x10000, so the far branch is taken for any sane z.
        var farAway = false
        if try i(s,0x404) != 0 {
            guard try i(s,0x18) > -0x8000 && i(s,0x18) < 0x8000 else {
                throw OriginalLoaderError.outsideVerifiedDomain("Character AI compares z with an Object pointer")
            }
            farAway = true
        }
        if !farAway, try g(0x44f608) == 1 { try press(s,.left) }
        let id = try id(s),frame = try i(s,0x70)
        if (id == 7 && frame >= 255 && frame <= 261) || (id == 9 && frame >= 280 && frame <= 290) || (id == 32 && frame >= 240 && frame <= 245) {
            try press(s,.defend)
        }
    }

    /// 40a925..40b7b0 with a target.
    mutating func fight(_ s: Int,slot: Int,mode: Int32,_ l: inout Locals) throws {
        let t = try index(Int(l.target))
        l.tState = try state(t); l.sState = try state(s)
        if try draw(0x14,g(0x44f618) &+ 8) == 0, try [0x3e8,0x3ec,0x3f0,0x3f4].contains(where: { try i(s,$0) == 1 }) {
            try release(s,.attack); try press(s,.attack)
        }
        let zero = try OriginalExtended(0)
        if l.tState == 3000 {
            if l.sState != 7, try draw(0x15,g(0x44f61c)) == 0 {
                let tx = try i(t,0x10),sx = try i(s,0x10)
                let defend = try (tx > sx && tx < sx &+ 200 && zero > v(t,0x40)) || (tx < sx && tx > sx &+ -200 && zero < v(t,0x40))
                if defend { try release(s,.defend); try press(s,.defend) }
            }
            if try i(t,0x10) > i(s,0x10) && facing(s) == 1 { try press(s,.right) }
            if try i(t,0x10) < i(s,0x10) && facing(s) == 0 { try press(s,.left) }
            return
        }
        if try i(s,0x404) == 1 {
            if try i(s,0x98) > 0, try [122,123].contains(id(index(Int(i(s,0x9c))))) { try release(s,.attack); try press(s,.attack); return }
            var skip = false
            if try i(s,0x3fc) != -1000, try abs(i(s,0x400) &- i(s,0x18)) > 90 || abs(i(s,0x3fc) &- i(s,0x10)) > 90 { skip = true }
            if !skip {
                if try abs(i(s,0x400) &- i(s,0x18)) <= 90 && abs(i(s,0x3fc) &- i(s,0x10)) <= 90 { try put(s,0x3fc,-1000); try put(s,0x400,-1000) }
                if try i(t,0x10) > i(s,0x10) && facing(s) == 1 { try press(s,.right) }
                if try i(t,0x10) < i(s,0x10) && facing(s) == 0 { try press(s,.left) }
                if l.sState == 2 {
                    if try facing(s) == 1 { try press(s,.right) }
                    if try facing(s) == 0 { try press(s,.left) }
                }
            }
        }
        if l.tState == 1004 || l.tState == 2004 { try item(s,t,&l); return }
        if try !far(s,t) {
            if try l.tState == 14 || abs(i(t,8)) > 2 { try flee(s,t,&l); return }
        }
        if try id(t) == 200 {
            if try i(t,0x10) > i(s,0x10) &+ 7 { try press(s,.right) } else if try i(t,0x10) < i(s,0x10) &+ -7 { try press(s,.left) }
            if try i(t,0x18) > i(s,0x18) &+ 2 { try press(s,.down) } else if try i(t,0x18) < i(s,0x18) &+ -2 { try press(s,.up) }
            return
        }
        if try special(s,t,slot: slot,l) { return }
        if try !far(s,t) { try approach(s,t,slot: slot,mode: mode,&l) }
        if try i(s,0x98) > 0, try !weapon(s,t,slot: slot,l) { return }
        try tactics(s,t,slot: slot,mode: mode,&l)
        try attackHelper(s,t,l)
    }

    /// 40adaa..40b0c7: approach, retreat bands and z alignment.
    mutating func approach(_ s: Int,_ t: Int,slot: Int,mode: Int32,_ l: inout Locals) throws {
        if try (l.right20 == 1 || g(0x44f608) == 1) && l.sState == 2 && facing(s) == 0 { try press(s,.left) }
        if try l.left14 == 1 && l.sState == 2 && facing(s) == 1 { try press(s,.right) }
        let own = try id(s)
        var band = [4,5,31].contains(own)
        if !band {
            let hp = try i(s,0x2fc)
            if try i(t,0x2fc) > hp &* 2 || (hp <= 100 && i(s,0x304) > 100) {
                band = try mode == 1 && type(t) == 0 && slot >= 20 && i(s,0x364) != 5
            }
        }
        if band {
            let sx = try i(s,0x10),tx = try i(t,0x10)
            if try tx > sx &+ 170 || ((tx > sx &+ 150 || (l.sState == 7 && tx > sx)) && facing(s) == 1) {
                if l.right20 == 0, try g(0x44f608) == 0 {
                    try press(s,.right); if try draw(0x1a,g(0x44f610) &+ 35) == 0 { try release(s,.right) }
                }
            }
            let sx2 = try i(s,0x10),tx2 = try i(t,0x10)
            if try tx2 < sx2 &- 170 || ((tx2 < sx2 &- 150 || (l.sState == 7 && tx2 < sx2)) && facing(s) == 0) {
                if l.left14 == 0 { try press(s,.left); if try draw(0x1b,g(0x44f610) &+ 35) == 0 { try release(s,.left) } }
            }
        } else if l.sState != 19 {
            let sx = try i(s,0x10),tx = try i(t,0x10)
            if try tx > sx &+ 60 || (tx > sx && facing(s) == 1) {
                if try l.right20 == 0 && (g(0x44f608) == 0 || facing(s) == 1) {
                    try press(s,.right); if try draw(0x1c,g(0x44f610) &+ 35) == 0 { try release(s,.right) }
                }
            }
            let sx2 = try i(s,0x10),tx2 = try i(t,0x10)
            if try tx2 < sx2 &- 60 || (tx2 < sx2 && facing(s) == 0) {
                if l.left14 == 0 { try press(s,.left); if try draw(0x1d,g(0x44f610) &+ 35) == 0 { try release(s,.left) } }
            }
        }
        let side = l.right20 == 1 || l.left14 == 1
        if try (i(t,0x18) > i(s,0x18) &+ 3 && l.ball30 == 0) || (side && l.up40 == 1) {
            if l.down3c == 0 && l.sState != 19 { try press(s,.down) }
        }
        if try (i(t,0x18) < i(s,0x18) &- 3 && l.ball30 == 0) || (side && l.down3c == 1) {
            if l.up40 == 0 && l.sState != 19 { try press(s,.up) }
        }
    }

    /// 40b0fc..40b78f: defend, jump and attack chances.
    mutating func tactics(_ s: Int,_ t: Int,slot: Int,mode: Int32,_ l: inout Locals) throws {
        let level = try g(0x44f60c)
        if try draw(0x1e,level &* 7 &+ 10) == 0, l.tState == 3 || l.tState/100 == 3, try abs(i(t,0x18) &- i(s,0x18)) < 9 {
            let f = try facing(t)
            if try (f == 0 && i(t,0x10) < i(s,0x10)) || (f == 1 && i(t,0x10) > i(s,0x10)) { try press(s,.defend) }
        }
        if try !far(s,t), try draw(0x1f,(level &* 5 &+ 10) &* 2) < 3, try draw(0x20,20) < 3, l.tState != 14 { try press(s,.jump) }
        let own = try id(s)
        let band = [4,5,31].contains(own)
        if !band || l.tState == 16 {
            if try abs(i(t,0x10) &- ftol(s,0x40) &* 2 &- i(s,0x10)) < 80, try abs(i(t,0x18) &- i(s,0x18)) < 5,
               try draw(0x21,g(0x44f61c) &+ 3) == 0, l.tState != 14 { try press(s,.attack) }
        }
        if try i(s,0x98) == 0 {
            if l.tState == 16 && band {
                if try abs(i(t,0x10) &- ftol(s,0x40) &* 2 &- i(s,0x10)) < 350, try abs(i(t,0x18) &- i(s,0x18)) < 5,
                   try draw(0x22,g(0x44f61c) &+ 3) == 0 { try strike(s,t) }
                return
            }
            if l.tState != 16 && (band || own == 36) {
                let flag = try i(t,0x10) &- i(s,0x10) < 100 && abs(i(t,0x18) &- i(s,0x18)) < 80 && draw(0x23,g(0x44f61c) &+ 2) == 0
                if flag && l.sState != 7 {
                    if try !far(s,t) { try escape(s,t) }
                    if try !far(s,t), try draw(0x24,17) == 0 { try press(s,.jump) }
                    return
                }
                if try abs(i(t,0x10) &- ftol(s,0x40) &* 2 &- i(s,0x10)) < 300, try abs(i(t,0x18) &- i(s,0x18)) < 5,
                   try draw(0x25,g(0x44f61c) &+ 3) == 0, l.tState != 14 { try strike(s,t) }
                return
            }
        }
        let hp = try i(s,0x2fc)
        guard try i(t,0x2fc) > hp &* 2 || (hp <= 100 && i(s,0x304) > 100) else { return }
        guard try mode == 1 && type(t) == 0 && slot >= 20 && i(s,0x364) != 5 else { return }
        let flag = try i(t,0x10) &- i(s,0x10) < 100 && abs(i(t,0x18) &- i(s,0x18)) < 80 && draw(0x26,g(0x44f61c) &+ 2) == 0
        guard flag && l.sState != 7 else { return }
        if try !far(s,t) { try escape(s,t) }
        if try !far(s,t), try draw(0x27,17) == 0 { try press(s,.jump) }
    }

    /// 40b590: attack when facing the target.
    mutating func strike(_ s: Int,_ t: Int) throws {
        let tx = try i(t,0x10),sx = try i(s,0x10),f = try facing(s)
        if (tx > sx && f == 0) || (tx <= sx && f == 1) { try press(s,.attack) }
    }

    /// 40b449/40b6cd: run toward the arena side away from the target.
    mutating func escape(_ s: Int,_ t: Int) throws {
        let tx = try i(t,0x10),width = try g(0x44f604)
        if try (tx < 250 || tx < i(s,0x10)) && tx <= width &- 250 { try press(s,.right); try release(s,.right) }
        else if try tx > width &- 250 || tx > i(s,0x10) { try press(s,.left); try release(s,.left) }
    }

    /// 40b84b..40b984: a lying or blinking target nearby.
    mutating func flee(_ s: Int,_ t: Int,_ l: inout Locals) throws {
        let width = try g(0x44f604),tx = try i(t,0x10)
        if tx > width &- 30 { try press(s,.left); try release(s,.left); return }
        if tx < 30 { try press(s,.right); try release(s,.right); return }
        if try abs(i(t,0x18) &- i(s,0x18)) > 45, try abs(tx &- i(s,0x10)) > 350 { return }
        if try tx > i(s,0x10) { try press(s,.left); if try draw(0x18,g(0x44f610) &+ 35) == 0 { try release(s,.left) } }
        else { try press(s,.right); if try draw(0x19,g(0x44f610) &+ 35) == 0 { try release(s,.right) } }
        let tz = try i(t,0x18)
        if try tz < i(s,0x18) { try press(s,.down); return }
        if try tz >= background(l.bg,4) &+ 10 { try press(s,.up) } else { try press(s,.down) }
    }

    /// 40b987..40bba3: walk to an item and pick it up.
    mutating func item(_ s: Int,_ t: Int,_ l: inout Locals) throws {
        let skip = try far(s,t) && ![122,123].contains(id(t))
        if !skip {
            let sx = try i(s,0x10),tx = try i(t,0x10)
            if sx > tx &+ 6 {
                try press(s,.left)
                if try i(s,0x10) > i(t,0x10) &+ 250, try draw(0x16,g(0x44f61c) &+ 3) == 0 { try release(s,.left) }
                if try i(s,0x10) < i(t,0x10) &+ 100, l.sState == 2, try facing(s) == 1 { try press(s,.right) }
            } else if sx < tx &- 6 {
                if try g(0x44f608) == 0 { try press(s,.right) }
                if try i(s,0x10) < i(t,0x10) &- 250, try draw(0x17,g(0x44f61c) &+ 3) == 0, try g(0x44f608) == 0 { try release(s,.right) }
                if try i(s,0x10) > i(t,0x10) &- 100, l.sState == 2, try facing(s) == 0 { try press(s,.left) }
            }
            if try i(s,0x18) < i(t,0x18) &- 3 { try press(s,.down) } else if try i(s,0x18) > i(t,0x18) &+ 3 { try press(s,.up) }
        }
        if try abs(i(t,0x18) &- i(s,0x18)) <= 3, try abs(i(t,0x10) &- i(s,0x10)) <= 6 { try release(s,.attack); try press(s,.attack) }
    }

    /// 403a40: the entry roll, then the block for the AI's own Object id.
    mutating func special(_ s: Int,_ t: Int,slot: Int,_ l: Locals) throws -> Bool {
        if try draw(0x3c,g(0x44f618) &+ 1) > 0 { return false }
        let own = try id(s)
        switch own {
        case 1: return try sakura1(s,t,l)
        case 2: return try naruto2(s,t,slot: slot,l)
        case 4: return try sai4(s,t)
        case 5: return try shino5(s,t)
        case 6: return try hsasori6(s,t)
        case 7: return try lee7(s,t,l)
        case 8: return try chiyo8(s,t,l)
        case 9: return try itachi9(s,t,l)
        case 10: return try deidara10(s,t,slot: slot,l)
        case 11: return try sasuke11(s,t,l)
        case 32: return try hunter32(s,t,l)
        case 33: return try clone33(s,t,l)
        case 34: return try kidomaru34(s,slot: slot,l)
        case 35: return try sakon35(s,t)
        case 36: return try tayuya36(s,t)
        case 38: return try sasukeCS38(s,t)
        case 39: return try sand39(s,t)
        case 50: return try pein50(s,t)
        case 51: return try sasori51(s,t)
        case 52: return try kyubi52(s,t,l)
        default: return false
        }
    }

    /// 408cb0: weapon use; false ends the AI for this call.
    mutating func weapon(_ s: Int,_ t: Int,slot: Int,_ l: Locals) throws -> Bool {
        if try draw(0x28,g(0x44f61c) &+ 1) > 0 { return false }
        let wid = try id(index(Int(i(s,0x9c))))
        var flag = false
        for k in 0..<20 where k != slot {
            guard try active(k) != 0 else { continue }
            let a = try index(k)
            guard try i(a,0x364) != 0, try i(t,0x364) == i(s,0x364), try i(a,0x2fc) > 0, try state(a) != 14,
                  try abs(i(a,8)) <= 2, try abs(i(a,0x18) &- i(s,0x18)) < 15 else { continue }
            let sx = try i(s,0x10),ax = try i(a,0x10),tx = try i(t,0x10)
            if (sx < ax && ax < tx) || (tx < ax && ax < sx) { flag = true } // 4061a0
        }
        if l.sState == 2, try draw(0x29,g(0x44f61c) &+ 5) == 0 { try press(s,flag ? .jump : .attack) }
        if [100,101,120,121,124].contains(wid) {
            if try abs(i(t,0x10) &- ftol(s,0x40) &* 2 &- i(s,0x10)) < 115, try abs(i(t,0x18) &- i(s,0x18)) < 6,
               try draw(0x2a,g(0x44f61c) &+ 3) == 0, l.tState != 14 { try press(s,.attack) }
            if wid == 124, try draw(0x2b,g(0x44f614) &+ 30) == 0 { try press(s,.attack) }
            if try draw(0x2c,g(0x44f61c) &+ 5) == 0, try !far(s,t) {
                if try abs(i(t,0x10) &- i(s,0x10)) < 600, try abs(i(t,0x18) &- i(s,0x18)) < 20 {
                    if try i(t,0x10) > i(s,0x10), try g(0x44f608) == 0 { try press(s,.right); try release(s,.right) }
                    if try i(t,0x10) < i(s,0x10) { try press(s,.left); try release(s,.left) }
                }
            }
        }
        if (wid == 150 || wid == 151) && !flag {
            if try abs(i(t,0x10) &- ftol(s,0x40) &* 2 &- i(s,0x10)) < 300, try abs(i(t,0x18) &- i(s,0x18)) < 6,
               try draw(0x2d,g(0x44f618) &+ 7) == 0, l.tState != 14 { try press(s,.attack) }
        }
        guard wid == 122 || wid == 123 else { return true }
        for key in [Key.defend,.jump,.attack,.down,.up,.left,.right] { try byte(s,key.rawValue,0) }
        if try l.sState == 17 && l.aligned34 == 1 && l.ball30 == 0 && i(s,8) != 0 { try press(s,.defend); return false }
        if try far(s,t) { return false }
        let tz = try i(t,0x18)
        if try tz < background(l.bg,4) &+ 30 { try press(s,.down) }
        else if try tz < background(l.bg,8) &- 30 { try press(s,.up) }
        else if try tz > i(s,0x18) { try press(s,.up) }
        else { try press(s,.down) }
        let tx = try i(t,0x10)
        if try tx < 400 && i(s,0x10) < 200 {
            try press(s,.right); if try draw(0x2e,g(0x44f61c) &+ 7) == 0 { try release(s,.right) }
            if try draw(0x2f,g(0x44f61c) &+ 5) == 0, l.sState == 2 { try press(s,.jump) }
            return false
        }
        let width = try g(0x44f604)
        if try tx > width &- 400 && i(s,0x10) > width &+ -200 {
            try press(s,.left); if try draw(0x30,g(0x44f61c) &+ 7) == 0 { try release(s,.left) }
            if try draw(0x31,g(0x44f61c) &+ 5) == 0, l.sState == 2 { try press(s,.jump) }
            return false
        }
        if try abs(tx &- i(s,0x10)) < 350, try abs(i(t,0x18) &- i(s,0x18)) < 70 {
            if try tx > i(s,0x10) { try press(s,.left); if try draw(0x32,g(0x44f61c) &+ 4) == 0 { try release(s,.left) } }
            if try i(t,0x10) <= i(s,0x10) { try press(s,.right); if try draw(0x33,g(0x44f61c) &+ 4) == 0 { try release(s,.right) } }
            return false
        }
        if l.sState == 2 {
            if try facing(s) == 0 { try press(s,.left) }
            if try facing(s) == 1 { try press(s,.right) }
            return false
        }
        guard try draw(0x34,5) == 0 else { return false }
        if try l.ball30 == 0 && [2,34].contains(id(s)) && i(s,0x308) > 150 && draw(0x35,g(0x44f61c) &+ 3) > 0 {
            try byte(s,tx > i(s,0x10) ? 0xd8 : 0xd9,3); return true
        }
        try press(s,.attack); return false
    }

    /// 4034f0: close-range attacks and dash counters.
    mutating func attackHelper(_ s: Int,_ t: Int,_ l: Locals) throws {
        if try abs(i(t,0x10) &- ftol(s,0x40) &* 2 &- i(s,0x10)) < 80, try abs(i(t,0x18) &- i(s,0x18)) < 5,
           try draw(0x37,g(0x44f61c) &+ 3) == 0, l.tState != 14 { try press(s,.attack) }
        if try l.right20 != 0 && i(t,0x10) > i(s,0x10) { return }
        if try l.left14 != 0 && i(t,0x10) < i(s,0x10) { return }
        if try draw(0x38,g(0x44f61c) &+ 1) != 0 { return }
        let set: Set<Int32> = [2,4,6,9,10,11,8,7,33,34]
        if try set.contains(id(s)) {
            let d = try abs(i(t,0x10) &+ ftol(t,0x40) &* 2 &- i(s,0x10))
            if d > 100, try abs(i(t,0x10) &+ ftol(t,0x40) &* 2 &- i(s,0x10)) < 900, try abs(i(t,0x18) &- i(s,0x18)) < 5,
               try draw(0x39,g(0x44f61c) &+ 10) == 0, l.tState != 14 { try press(s,.defend) }
        }
        if try set.contains(id(s)) {
            try dash(s,t,l,range: 90,z: 13,jumpID: 34)
        }
        if try id(s) == 1 {
            let d = try abs(i(t,0x10) &+ ftol(t,0x40) &* 2 &- i(s,0x10))
            if d > 100, try abs(i(t,0x10) &+ ftol(t,0x40) &* 2 &- i(s,0x10)) < 300, try abs(i(t,0x18) &- i(s,0x18)) < 5,
               try draw(0x3b,g(0x44f618) &+ 10) == 0, l.tState != 14 { try press(s,.defend) }
        }
        if try id(s) == 1 { try dash(s,t,l,range: 90,z: 7,jumpID: nil) }
    }

    mutating func dash(_ s: Int,_ t: Int,_ l: Locals,range: Int32,z: Int32,jumpID: Int32?) throws {
        let sx = try i(s,0x10)
        guard try abs(i(t,0x10) &+ ftol(t,0x40) &* 2 &- sx) > range else { return }
        let f = try facing(s),tx = try i(t,0x10)
        guard (f == 0 && tx > sx) || (f == 1 && tx < sx) else { return }
        let frame = try i(s,0x70)
        guard frame == 110 || frame >= 235, try abs(i(t,0x18) &- i(s,0x18)) < z, l.tState != 14 else { return }
        try release(s,.right); try release(s,.left); try release(s,.attack)
        if try i(t,0x10) > i(s,0x10) { try press(s,.right) } else { try press(s,.left) }
        if let jumpID, try id(s) == jumpID, try draw(0x3a,2) == 0 { try press(s,.jump) } else { try press(s,.attack) }
    }
}
