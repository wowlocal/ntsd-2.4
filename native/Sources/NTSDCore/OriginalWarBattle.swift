/// A call of the War battle logic to an already accepted callee. `caller` is the
/// EXE return address of the call site. Text pointers into the caller's stack
/// are not reported; `text` carries the bytes.
public struct OriginalWarBattleCall: Equatable, Sendable {
    public enum Kind: String, Sendable { case text, format, bitmapFont }
    public let kind: Kind, caller: UInt32, arguments: [UInt32], text: [UInt8]
    public init(_ kind: Kind,caller: UInt32,arguments: [UInt32] = [],text: [UInt8] = []) {
        self.kind = kind;self.caller = caller;self.arguments = arguments;self.text = text
    }
}

public enum OriginalWarBattleEvent: Equatable, Sendable {
    case call(OriginalWarBattleCall)
    case random(stream: Int32,range: Int32,result: Int32)
    case constructor(seat: Int)
}

/// War battle logic 43a860(World; unused), called by the post-draw 41f4ac when
/// mode 451160 is 4: counts live troops per side and unit type, spawns reserve
/// troops (44d6a8) into free seats 20..399 while fewer than the on-screen limit
/// (44d700) are alive, sets the battle-over flag 451b7c, and reports the two
/// status lines (sprintf + 401290) and the preset labels built in 451c80
/// (423a70). Calls are reported for the caller to perform; the labels' bytes
/// travel with the call. The label construction writes 451c80/451bb8 as the
/// original does. APPLICATION_WAR_PLAN.md W3.
public enum OriginalWarBattle {
    public static func apply(state: inout OriginalMatchPreparation,
                             observe: (OriginalWarBattleEvent) throws -> Void = { _ in }) throws {
        let catalog = state.catalog
        guard try state.world.integer(at: 0x7d4,as: UInt32.self) == 0,
              let registry = catalog.registry.records[0x4d82380] else { throw OriginalStateError.invalidStorage("War battle catalog binding") }
        var pass = OriginalWarBattlePass(world: state.world,actors: state.actors,globals: state.globals,objects: catalog.objects,
            objectCount: try registry.integer(at: 0,as: Int32.self),backgrounds: state.backgrounds)
        try pass.run()
        for event in pass.events { try observe(event) }
        state.world = pass.world;state.actors = pass.actors;state.globals = pass.globals
    }
}

struct OriginalWarBattlePass {
    var world: OriginalStateRecord
    var actors: [OriginalStateRecord]
    var globals: OriginalStateRecord
    let objects: [OriginalLoadedObject]
    let objectCount: Int32
    let backgrounds: [OriginalStateRecord]
    var events: [OriginalWarBattleEvent] = []

    func error(_ message: String) -> OriginalStateError { .invalidStorage("War battle: "+message) }
    func g(_ address: Int) throws -> Int32 { try globals.integer(at: address-0x44d000,as: Int32.self) }
    mutating func setG(_ address: Int,_ value: Int32) throws { try globals.write(value,at: address-0x44d000) }
    func active(_ seat: Int) throws -> UInt8 { try world.integer(at: 4+seat,as: UInt8.self) }
    func index(_ seat: Int) throws -> Int {
        let a = Int(try world.integer(at: 0x194+seat*4,as: UInt32.self))
        guard actors.indices.contains(a) else { throw error("Actor binding") }
        return a
    }
    func i(_ a: Int,_ o: Int) throws -> Int32 { try actors[a].integer(at: o,as: Int32.self) }
    mutating func put(_ a: Int,_ o: Int,_ value: Int32) throws { try actors[a].write(value,at: o) }
    mutating func putDouble(_ a: Int,_ o: Int,_ value: Double) throws { try actors[a].write(value.bitPattern,at: o) }
    func object(_ a: Int) throws -> Int {
        let n = Int(try actors[a].integer(at: 0x368,as: UInt32.self))
        guard objects.indices.contains(n) else { throw error("Object binding") }
        return n
    }
    func header(_ n: Int,_ o: Int) throws -> Int32 { try objects[n].header.integer(at: o,as: Int32.self) }
    func arena(_ o: Int) throws -> Int32 {
        let n = Int(try g(0x44d024))
        guard backgrounds.indices.contains(n) else { throw error("Arena binding") }
        return try backgrounds[n].integer(at: o,as: Int32.self)
    }
    mutating func draw(_ stream: Int32,_ range: Int32) throws -> Int32 {
        var rng = OriginalRandom(table: try (0..<3000).map { try globals.integer(at: 0x44ff90-0x44d000+$0,as: UInt8.self) },
            index: Int(try g(0x450bcc)),counter: Int(try g(0x450c34)),source: "owned War battle",sourceSHA256: "")
        try rng.validate();let result = Int32(rng.next(Int(range)))
        try setG(0x450bcc,Int32(rng.index));try setG(0x450c34,Int32(rng.counter))
        events.append(.random(stream: stream,range: range,result: result));return result
    }
    mutating func call(_ kind: OriginalWarBattleCall.Kind,_ caller: UInt32,_ arguments: [UInt32] = [],text: [UInt8] = []) {
        events.append(.call(.init(kind,caller: caller,arguments: arguments,text: text)))
    }
    // The C string at a global address and its in-place concatenation.
    func string(_ address: Int) throws -> [UInt8] {
        var bytes: [UInt8] = [],p = address-0x44d000
        while true {
            let b = try globals.integer(at: p,as: UInt8.self)
            if b == 0 { return bytes }
            bytes.append(b);p += 1
            guard bytes.count < 0x100 else { throw error("Label string extent") }
        }
    }
    mutating func store(_ address: Int,_ bytes: [UInt8]) throws {
        for (n,b) in bytes.enumerated() { try globals.write(b,at: address-0x44d000+n) }
    }
    mutating func append(_ address: Int,_ bytes: [UInt8]) throws { try store(address+string(address).count,bytes) }

    mutating func run() throws {
        let count = try g(0x44d37c)
        // 43a910: live troops by side and unit type (stack array of 2×11), and
        // living characters per team with their HP.
        var counts = [Int32](repeating: 0,count: 22),alive: [Int32] = [0,0],hp: [Int32] = [0,0]
        for seat in 0..<400 where try active(seat) != 0 {
            let a = try index(seat),side = try i(a,0x344)
            if side > 0 && side < 3 && seat >= 20 {
                let id = try header(object(a),0x6f4)
                if (UInt32(bitPattern: id &- 30) <= 9 && id != 38) || id == 122 || id == 123 {
                    if count > 0 {
                        for c in 0..<count where try g(0x44d350+Int(c)*4) == id {
                            let n = (side &- 1) &* count &+ c
                            guard (0..<22).contains(n) else { throw error("Unit count outside the 2×11 caller array") }
                            counts[Int(n)] &+= 1
                        }
                    }
                }
            }
            let life = try i(a,0x2fc)
            if try header(object(a),0x6f8) == 0 && life > 0 {
                let t = try i(a,0x364) == 1 ? 0 : 1
                alive[t] &+= 1;hp[t] &+= life
            }
        }
        // 43a9f7: one spawn per unit type and side while reserves remain.
        if count >= 0 {
            guard count != 0 else { throw error("Unit count 0 does not terminate") }
            var s: Int32 = 0
            repeat {
                for c in 0..<count {
                    let k = Int(s &+ c)
                    guard (0..<22).contains(k) else { throw error("Unit table outside the 2×11 tables") }
                    guard try g(0x44d6a8+k*4) > 0,try g(0x44d700+k*4) > counts[k] else { continue }
                    guard let seat = try (20..<400).first(where: { try active($0) == 0 }) else { continue }
                    let unit = try g(0x44d350+Int(c)*4)
                    guard Int(objectCount) <= objects.count else { throw error("Object count binding") }
                    // First matching Object; none leaves the reserve unchanged.
                    guard objectCount > 0,
                          let ordinal = try (0..<Int(objectCount)).first(where: { try header($0,0x6f4) == unit }) else { continue }
                    try spawn(seat: seat,ordinal: ordinal,unit: unit,side: s,count: count)
                    try setG(0x44d6a8+k*4,g(0x44d6a8+k*4) &- 1)
                }
                s &+= count
            } while s <= count
        }
        // 43ae02: reserves of the first count-2 unit types per side.
        var reserve: [Int32] = [0,0]
        for side in 0..<2 where count &- 2 > 0 {
            for k in 0..<Int(count &- 2) { reserve[side] &+= try g(0x44d6a8+(side*Int(count)+k)*4) }
        }
        try setG(0x451b7c,1)
        if reserve[0] > 0 && reserve[1] > 0 { try setG(0x451b7c,0) }
        if alive[0] > 0 && alive[1] > 0 { try setG(0x451b7c,0) }
        let surface = UInt32(bitPattern: try g(0x455608))
        for (side,(x,color,caller)) in [(Int32(10),UInt32(0xffb294),UInt32(0x43aea1)),(0x1c2,0xada6ff,0x43aedb)].enumerated() {
            func pad(_ v: Int32,_ width: Int) -> String { let d = String(v);return String(repeating: " ",count: max(0,width-d.count))+d }
            let die = try g(side == 0 ? 0x451b64 : 0x451b68)
            let text = Array(("Man: "+pad(alive[side],3)+"     HP: "+pad(hp[side],4)+"     Reserve: "+pad(reserve[side],3)+"     Die: "+pad(die,3)).utf8)
            call(.format,caller,[UInt32(bitPattern: alive[side]),UInt32(bitPattern: hp[side]),UInt32(bitPattern: reserve[side]),UInt32(bitPattern: die)],text: text)
            call(.text,side == 0 ? 0x43aebd : 0x43aefd,[surface,0,color,UInt32(bitPattern: x),0x6e],text: text)
        }
        try label(display: g(0x44d380),strength: g(0x451b74),multiplier: g(0x44d758),style: 1)
        try label(display: g(0x44d384),strength: g(0x451b78),multiplier: g(0x44d75c),style: 2)
    }

    /// 43aefd/43b146: the preset/strength/defense label in 451c80 and its
    /// bitmap-font draw (style 1 at x10, style 2 right-aligned at 0x311).
    mutating func label(display: Int32,strength: Int32,multiplier: Int32,style: Int32) throws {
        try store(0x451c80,[0])
        let names: [Int32:String] = [0:"Zero",1:"Balanced",2:"Inferior",3:"Ranged attack",4:"Melee attack",5:"Giant",6:"Full"]
        if let name = names[display] { try store(0x451c80,Array(name.utf8)+[0]) }
        if (1...5).contains(display),let suffix = [Int32(0):"(S)",1:"(M)",2:"(L)"][strength] {
            try append(0x451c80,Array(suffix.utf8)+[0])
        }
        if multiplier != 100 {
            if display != -1 { try append(0x451c80,Array("    ".utf8)+[0]) }
            let defense = Array("Defense: \(multiplier/100).\((multiplier%100)/10)".utf8)
            call(.format,style == 1 ? 0x43b0f4 : 0x43b344,[UInt32(bitPattern: multiplier/100),UInt32(bitPattern: (multiplier%100)/10)],text: defense)
            try store(0x451bb8,defense+[0])
            try append(0x451c80,defense+[0])
        }
        let text = try string(0x451c80)
        // 423a70 writes its terminator at the end of each pass; with at most 64
        // columns and no newline that is the existing NUL.
        guard text.count < 0x40,!text.contains(10) else { throw error("Label beyond one bitmap-font line") }
        let x: Int32 = style == 1 ? 10 : 0x311 &- Int32(text.count) &* 8
        call(.bitmapFont,style == 1 ? 0x43b146 : 0x43b3b6,[UInt32(bitPattern: x),0x85,0x40,4,UInt32(bitPattern: style),0],text: text)
    }

    /// 43aaab..43adbd: one troop in `seat` for side s (0 or count).
    mutating func spawn(seat: Int,ordinal: Int,unit: Int32,side s: Int32,count: Int32) throws {
        try world.write(UInt8(1),at: 4+seat)
        let a = try index(seat)
        try actors[a].reconstructActor();events.append(.constructor(seat: seat))
        try putDouble(a,0x58,350)
        try actors[a].write(UInt32(ordinal),at: 0x368)
        try actors[a].write(try objects[ordinal].header.integer(at: 0x90,as: UInt32.self),at: 0x31c)
        try putDouble(a,0x60,0);try putDouble(a,0x68,300)
        let lower = try arena(4),upper = try arena(8)
        try put(a,0x18,draw(0x128,upper &- lower) &+ lower)
        let type = try header(object(a),0x6f8),width = try arena(0)
        if s == 0 { try put(a,0x10,type != 0 ? 50 : -100) }
        else { try put(a,0x10,type == 0 ? width &+ 100 : width &- 50) }
        try putDouble(a,0x58,Double(i(a,0x10)));try putDouble(a,0x68,Double(i(a,0x18)))
        // 43abe2..43ac75: hit points by unit ID; side-1 characters' 318.
        var life: Int32 = 500,at43 = false
        if s == 0 && type == 0 {
            try put(a,0x318,0x8c)
            if unit == 0x25 { try put(a,0x318,0x72);at43 = true }
        }
        if !at43 && unit == 0x24 { life = 250 }
        else {
            if at43 || unit == 0x25 || unit == 0x23 || unit == 0x20 { life = 200 }
            if unit == 0x27 || unit == 0x21 { life = 150 }
            if unit == 0x22 { life = 100 }
            else {
                if unit == 0x1f || unit == 0x1e { life = 50 }
                if unit == 0x7a { life = 200 }
            }
        }
        try put(a,0x308,500);try put(a,0x300,life);try put(a,0x2fc,life);try put(a,0x304,life)
        try put(a,0x354,Int32(seat))
        let team = s/count &+ 1
        let kind = try header(object(a),0x6f8)
        if kind != 0 && kind != 5 {
            try put(a,8,0);try put(a,0x364,0);try put(a,0x344,team)
            try put(a,0x14,-300);try putDouble(a,0x60,-300)
        } else {
            try put(a,8,20)
            try actors[a].write(UInt8(try i(a,0x10) > width/2 ? 1 : 0),at: 0x80)
            try put(a,0x364,team);try put(a,0x344,team)
            try put(a,0x14,-300);try putDouble(a,0x60,-300);try putDouble(a,0x48,0)
        }
    }
}
