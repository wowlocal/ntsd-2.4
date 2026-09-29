/// A call of the Mission stage logic to an already accepted callee. `caller` is
/// the EXE return address of the call site; `this` is ECX for thiscall callees.
public struct OriginalMissionStageCall: Equatable, Sendable {
    public enum Kind: String, Sendable { case bitmapDraw, fill, text, sound, music, musicStop, format }
    public let kind: Kind, caller: UInt32, this: UInt32?, arguments: [UInt32], text: [UInt8]?
    public init(_ kind: Kind,caller: UInt32,this: UInt32? = nil,arguments: [UInt32] = [],text: [UInt8]? = nil) {
        self.kind = kind;self.caller = caller;self.this = this;self.arguments = arguments;self.text = text
    }
}

public enum OriginalMissionStageEvent: Equatable, Sendable {
    case call(OriginalMissionStageCall)
    case random(stream: Int32,range: Int32,result: Int32)
    case constructor(seat: Int)
}

/// Mission Mode stage logic 437860(World; target, 0x44d020), called by the
/// post-draw 41f4ac when mode 451160 is 1, with its helpers 437400 (one phase
/// spawn) and 436fc0 (next stage). Stage records are the catalog's
/// (7d0 + s·149b08); the logic writes their spawn-slot runtime words. Bitmap
/// draws (43f010), fills (415160), surface text (401290), sounds (401a30),
/// music (402020/402100) are reported as calls for the caller to perform;
/// sprintf's output is written to 451418 as the original does.
public enum OriginalMissionStage {
    public static func apply(state: inout OriginalMatchPreparation,target: UInt32,sse2: Bool = false,
                             observe: (OriginalMissionStageEvent) throws -> Void = { _ in }) throws {
        let catalog = state.catalog
        guard try state.world.integer(at: 0x7d4,as: UInt32.self) == 0,
              let registry = catalog.registry.records[0x4d82380] else { throw OriginalStateError.invalidStorage("Mission stage catalog binding") }
        var pass = OriginalMissionStagePass(world: state.world,actors: state.actors,globals: state.globals,stages: state.stages,
            objects: catalog.objects,objectCount: try registry.integer(at: 0,as: Int32.self),backgrounds: state.backgrounds,
            precision: state.arithmeticPrecision,sse2: sse2,target: target)
        try pass.run()
        for event in pass.events { try observe(event) }
        state.world = pass.world;state.actors = pass.actors;state.globals = pass.globals;state.stages = pass.stages
    }
}

struct OriginalMissionStagePass {
    static let stride = 0x149b08,phase = 0x34c0,slot = 0xe0
    var world: OriginalStateRecord
    var actors: [OriginalStateRecord]
    var globals: OriginalStateRecord
    var stages: [OriginalStateRecord]
    let objects: [OriginalLoadedObject]
    let objectCount: Int32
    let backgrounds: [OriginalStateRecord]
    let precision: OriginalArithmeticPrecision
    let sse2: Bool
    let target: UInt32
    var events: [OriginalMissionStageEvent] = []

    func error(_ message: String) -> OriginalStateError { .invalidStorage("Mission stage: "+message) }
    func g(_ address: Int) throws -> Int32 { try globals.integer(at: address-0x44d000,as: Int32.self) }
    func gu(_ address: Int) throws -> UInt32 { try globals.integer(at: address-0x44d000,as: UInt32.self) }
    mutating func setG(_ address: Int,_ value: Int32) throws { try globals.write(value,at: address-0x44d000) }
    func active(_ seat: Int) throws -> UInt8 {
        guard (0..<400).contains(seat) else { throw error("activity outside seats 0..399") }
        return try world.integer(at: 4+seat,as: UInt8.self)
    }
    mutating func setActive(_ seat: Int,_ value: UInt8) throws { try world.write(value,at: 4+seat) }
    func index(_ seat: Int) throws -> Int {
        guard (0..<400).contains(seat) else { throw error("Actor table outside seats 0..399") }
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
    func type(_ a: Int) throws -> Int32 { try objects[object(a)].header.integer(at: 0x6f8,as: Int32.self) }
    func id(_ a: Int) throws -> Int32 { try objects[object(a)].header.integer(at: 0x6f4,as: Int32.self) }
    // Stage record words: offsets from catalog+7d0+s·149b08.
    func c(_ s: Int32,_ o: Int) throws -> Int32 {
        guard stages.indices.contains(Int(s)),o >= 0,o+4 <= Self.stride else { throw error("stage record extent") }
        return try stages[Int(s)].integer(at: o,as: Int32.self)
    }
    mutating func setC(_ s: Int32,_ o: Int,_ value: Int32) throws {
        guard stages.indices.contains(Int(s)),o >= 0,o+4 <= Self.stride else { throw error("stage record extent") }
        try stages[Int(s)].write(value,at: o)
    }
    func ratio(_ s: Int32,_ o: Int) throws -> Double {
        guard stages.indices.contains(Int(s)),o >= 0,o+8 <= Self.stride else { throw error("stage record extent") }
        return try stages[Int(s)].binary64(at: o)
    }
    func ext(_ value: Double) throws -> OriginalExtended { try OriginalExtended(value,precision: precision) }
    func ftol(_ value: OriginalExtended) -> Int32 { OriginalCoordinateConversion.integer(value,sse2: sse2) }
    /// Signed 32-bit division by 10 and its remainder, as the compiler's magic multiply.
    static func tenths(_ v: Int32) -> (Int32,Int32) { (v/10,v%10) }
    mutating func draw(_ stream: Int32,_ range: Int32) throws -> Int32 {
        var rng = OriginalRandom(table: try (0..<3000).map { try globals.integer(at: 0x44ff90-0x44d000+$0,as: UInt8.self) },
            index: Int(try g(0x450bcc)),counter: Int(try g(0x450c34)),source: "owned mission stage",sourceSHA256: "")
        try rng.validate();let result = Int32(rng.next(Int(range)))
        try setG(0x450bcc,Int32(rng.index));try setG(0x450c34,Int32(rng.counter))
        events.append(.random(stream: stream,range: range,result: result));return result
    }
    mutating func call(_ kind: OriginalMissionStageCall.Kind,_ caller: UInt32,this: UInt32? = nil,_ arguments: [UInt32] = [],text: [UInt8]? = nil) {
        events.append(.call(.init(kind,caller: caller,this: this,arguments: arguments,text: text)))
    }
    mutating func bitmap(_ caller: UInt32,_ holder: Int,_ x: UInt32,_ y: UInt32,_ frame: Int32) throws {
        call(.bitmapDraw,caller,this: try gu(holder),[x,y,UInt32(bitPattern: frame),1,0,target])
    }
    /// VC80 sprintf of the four HUD formats into 451418 (NUL written).
    mutating func format(_ caller: UInt32,_ pieces: [(String,Int32,Int)]) throws {
        var text = ""
        for (literal,value,width) in pieces {
            text += literal
            if width >= 0 {
                let digits = String(value)
                text += String(repeating: " ",count: max(0,width-digits.count))+digits
            }
        }
        let bytes = Array(text.utf8)
        for (n,b) in (bytes+[0]).enumerated() { try globals.write(b,at: 0x451418-0x44d000+n) }
        call(.format,caller,[0x451418]+pieces.filter { $0.2 >= 0 }.map { UInt32(bitPattern: $0.1) },text: bytes)
    }
    mutating func text(_ caller: UInt32,color: UInt32,x: UInt32) throws {
        var bytes: [UInt8] = [],n = 0
        while true {
            let b = try globals.integer(at: 0x451418-0x44d000+n,as: UInt8.self)
            if b == 0 { break };bytes.append(b);n += 1
        }
        call(.text,caller,[try gu(0x455608),0x451418,0,color,x,0x6e],text: bytes)
    }
    mutating func fill(_ caller: UInt32,_ x: UInt32,_ height: Int32) {
        call(.fill,caller,[0,x,0x31a,UInt32(bitPattern: height),0])
    }

    // MARK: 437860
    mutating func run() throws {
        for n in 0..<400 { try setG(0x4514e0+4*n,0) }
        let stageState = try g(0x450ba8)
        if stageState >= 3 { try setTail(stageState);return }
        var s = try g(0x450b94)
        var p = try g(0x44fb6c)
        if p == -1,Self.tenths(s).1 == 0 { try setG(0x44d34c,-1) }
        let count = try c(s,0)
        var start = true
        if p >= count &- 1 {
            if p < 0 { start = false }
            else if try c(s,Self.phase+Int(p)*Self.phase) == -1 { start = false }
        }
        if start,p != -1,try g(0x451b34) != 1 { start = false }
        if start {
            try setG(0x451b34,0);try setG(0x451b30,0);try setG(0x450bac,0)
            var weight: Int32 = 0
            for seat in 0..<20 where try active(seat) != 0 {
                let a = try index(seat)
                guard try type(a) == 0 else { continue }
                let id = try id(a);weight &+= 1
                if id == 0x33 { weight &+= 1 }
                if id == 0x34 { weight &+= 2 }
            }
            if try g(0x450c30) == -1 { weight = ftol(try ext(Double(weight))*ext(1.5)+ext(1.0)) }
            try setG(0x44f880,g(0x44f880) &+ 1)
            if Self.tenths(s).0 == 5 { try setG(0x450ba0,1) }
            if p >= 0 {
                let next = try c(s,Self.phase+Int(p)*Self.phase)
                p = next != -1 ? next : p &+ 1
            } else { p &+= 1 }
            try setG(0x44fb6c,p)
            let music = 0xc+Int(p)*Self.phase
            guard stages.indices.contains(Int(s)),music >= 0,music < Self.stride else { throw error("stage record extent") }
            if try stages[Int(s)].integer(at: music,as: UInt8.self) != 0 {
                var path: [UInt8] = [],n = music
                while n < Self.stride,let b = try? stages[Int(s)].integer(at: n,as: UInt8.self),b != 0 { path.append(b);n += 1 }
                call(.music,0x437aee,[UInt32(music)],text: path)
                p = try g(0x44fb6c)
            }
            s = try g(0x450b94)
            let bound = try c(s,8+Int(p)*Self.phase)
            try setG(0x450bb0,bound &- 0x31a);try setG(0x450bb4,bound)
            if Self.tenths(s).0 == 5 {
                for seat in 0..<20 {
                    let a = try index(seat)
                    guard try i(a,0x2fc) <= 0 else { continue }
                    if try i(a,0x300) < 5 { try put(a,0x300,5) }
                    try put(a,0x2fc,5);try put(a,0x308,500);try put(a,0x10,100);try putDouble(a,0x58,100.0)
                }
            }
            for k in 0..<60 {
                p = try g(0x44fb6c);s = try g(0x450b94)
                let base = 0x40+Int(p)*Self.phase+k*Self.slot
                try setC(s,base,0)
                guard try c(s,base+0xac) > -1 else { continue }
                let r = try ratio(s,base+0xd0)
                if r > 0 {
                    let product = try ext(Double(weight))*ext(r)
                    try setC(s,base+4,ftol(try ext(Double(c(s,base+0xb8)))*product))
                    let listed = ftol(product)
                    try setC(s,base+8,listed > 0x28 ? 0x28 : listed)
                } else {
                    try setC(s,base+4,c(s,base+0xb8));try setC(s,base+8,1)
                }
                var n: Int32 = 0
                while n < (try c(s,base+8)) { try spawn(s,base,n);n += 1 }
            }
        }
        // 437e63
        p = try g(0x44fb6c)
        try setG(0x451b34,1);try setG(0x451b30,0)
        s = try g(0x450b94)
        if p > -1 {
            for k in 0..<60 {
                let base = 0x40+Int(p)*Self.phase+k*Self.slot
                guard try c(s,base+0xac) > -1,try c(s,base+0xd8) > 1 else { continue }
                var n: Int32 = 0
                while n < (try c(s,base+8)) {
                    let seat = try c(s,base+0xc+4*Int(n))
                    if seat > -1 {
                        try setG(0x4514e0+Int(seat)*4,1)
                        if try active(Int(seat)) == 1 {
                            let a = try index(Int(seat))
                            if try i(a,0x364) == 5,try type(a) == 0 { try setG(0x451b30,1) }
                        }
                    }
                    n += 1
                }
            }
            for pass in 0..<2 {
                for k in 0..<60 {
                    p = try g(0x44fb6c)
                    let base = 0x40+Int(p)*Self.phase+k*Self.slot
                    guard try c(s,base+0xac) > -1 else { continue }
                    var n: Int32 = 0
                    while n < (try c(s,base+8)) {
                        let entry = base+0xc+4*Int(n)
                        let seat = try c(s,entry)
                        if seat > -1,try active(Int(seat)) == 0 {
                            if pass == 0 {
                                var mark = false
                                if try c(s,base+0xd8) == 1 {
                                    if try g(0x451b30) == 0 || c(s,base) >= c(s,base+4) { mark = true }
                                } else if try c(s,base) >= c(s,base+4) { mark = true }
                                if mark { try setC(s,entry,-1);try setC(s,base,c(s,base+4)) }
                            } else if try c(s,base) < c(s,base+4) {
                                try spawn(s,base,n);try setG(0x451b34,0)
                            }
                        }
                        n += 1
                    }
                    s = try g(0x450b94)
                }
            }
        }
        // 438062
        s = try g(0x450b94)
        var enemy = false
        for seat in 20..<400 where try active(seat) != 0 {
            let a = try index(seat)
            if try type(a) == 0,try i(a,0x364) == 5 { enemy = true;break }
        }
        if enemy { try setG(0x451b34,0) }
        var timer = try g(0x450b9c)
        var flash = false  // reached 438236
        if !enemy,try g(0x451b34) == 1,timer == 0 {
            if try g(0x450bac) == 0 {
                try setG(0x450b9c,0xa9);timer = 0xa9
                if try g(0x44fb6c) == c(s,0) &- 1 { try setG(0x450bac,1);try setG(0x450bb4,0) }
                flash = true
            }
        } else {
            if timer > 0 && timer < 100 {
                let (q,r) = Self.tenths(s)
                if q >= 5 { try bitmap(0x438202,0x451168,0xa5,0x12b,3) }
                else {
                    try bitmap(0x438162,0x451178,0x109,0x12b,0x19)
                    try bitmap(0x43817e,0x451178,0x1ea,0x12b,0x24)
                    try bitmap(0x4381b2,0x451178,0x1cc,0x12b,q &+ 0x1b)
                    try bitmap(0x438202,0x451178,0x208,0x12b,r &+ 0x1b)
                }
                timer &-= 1;try setG(0x450b9c,timer);s = try g(0x450b94)
            }
            if timer > 100 && timer < 0x12c { flash = true }
        }
        if flash {
            let p = try g(0x44fb6c)
            if UInt32(bitPattern: p) <= 0x62 {
                if try c(s,8+Int(p)*Self.phase) == c(s,Self.phase+8+Int(p)*Self.phase),try g(0x450bac) != 1 {
                    timer = 0;try setG(0x450b9c,0)
                }
            }
            let q = timer/10
            if q%2 == 1 {
                if timer%10 == 0,timer < 0xc8 { call(.sound,0x4382b4,this: 0x455610,[0]) }
                try bitmap(0x4382d0,0x451178,0x294,0x12b,0x18)
                s = try g(0x450b94);timer = try g(0x450b9c)
            }
            timer &-= 1;try setG(0x450b9c,timer)
            if timer == 0x65 || timer == 0xc9 {
                try setG(0x450b9c,try g(0x450bac) == 1 ? 0x118 : 0)
            }
        }
        // 438311
        var wipe = try g(0x450ba4)
        if try g(0x450bac) == 1,wipe == 0 {
            let setEnd = Self.tenths(s).1 == 9 ? true : try nextStage(s) == -1
            if setEnd {
                // 4384d7: end of the stage set
                if try g(0x450bdc) == 1 {
                    try setG(0x44d02c,1);call(.musicStop,0x4384ef)
                    call(.sound,0x4384fc,this: 0x455618,[0])
                }
                if try g(0x450bdc) < 0x5a { try bitmap(0x438523,0x451178,0xd7,0x12a,0x25) }
                if try g(0x450ba8) == 0 { try setG(0x450ba8,1) }
                try setG(0x450bac,0);try setG(0x450b9c,0);try setG(0x450ba4,0)
                try hud();return
            }
            var past = true
            let p = try g(0x44fb6c)
            for seat in 0..<20 where try active(seat) != 0 {
                let a = try index(seat)
                if try type(a) == 0,try i(a,0x2fc) > 0,try i(a,0x10) < c(s,8+Int(p)*Self.phase) { past = false }
            }
            if !past { try hud();return }
            wipe = 1;try setG(0x450ba4,1)
            try wipeOut(&wipe)
        } else if (wipe &- 11) >= 0 && (wipe &- 11) <= 9 {
            var x: UInt32 = 0x87
            while x < 0x235 { fill(0x43858b,x,((21 &- wipe) &* 0x2b)/10);wipe = try g(0x450ba4);x += 0x2b }
            wipe &+= 1;try setG(0x450ba4,wipe)
            if wipe == 21 { try setG(0x450ba4,0) }
        } else if wipe > 0 && wipe <= 10 {
            try wipeOut(&wipe)
        }
        try hud()
    }
    func nextStage(_ s: Int32) throws -> Int32 {
        guard stages.indices.contains(Int(s)+1) else { throw error("next stage record outside the stage table") }
        return try stages[Int(s)+1].integer(at: 0,as: Int32.self)
    }
    mutating func wipeOut(_ wipe: inout Int32) throws {
        var x: UInt32 = 0x87
        while x < 0x235 { fill(0x4385eb,x,(wipe &* 0x2b)/10);wipe = try g(0x450ba4);x += 0x2b }
        wipe &+= 1;try setG(0x450ba4,wipe)
        if wipe == 11 { try nextStage() }
    }
    /// 438614..4388ac: the players/enemies summary and the stage line.
    mutating func hud() throws {
        var otherTeam = false
        for seat in 0..<20 where try active(seat) != 0 {
            let a = try index(seat)
            if try type(a) == 0,try i(a,0x2fc) > 0,try i(a,0x364) != 5 { otherTeam = true;break }
        }
        var playerHP: Int32 = 0,players: Int32 = 0,enemyHP: Int32 = 0,enemies: Int32 = 0,reserve: Int32 = 0
        for seat in 0..<400 where try active(seat) != 0 {
            let a = try index(seat)
            guard try type(a) == 0 else { continue }
            let hp = try i(a,0x2fc)
            if try i(a,0x364) == 5 {
                if hp > 0 { enemyHP &+= hp;enemies &+= 1 }
                continue
            }
            if hp > 0 { playerHP &+= hp;players &+= 1 }
            let lives = try i(a,0x30c)
            if otherTeam {
                if lives > 1 { reserve &+= lives &- 1 }
                else if lives < 0 { try put(a,0x30c,0 &- lives) }
            } else if lives > 1 { try put(a,0x30c,0 &- lives) }
        }
        let s = try g(0x450b94)
        if s < 0x32 {
            let (q,r) = Self.tenths(s)
            try format(0x438759,[("STAGE ",q &+ 1,0),("-",r &+ 1,0)])
            try text(0x438777,color: 0xc8c8c8,x: 0x168)
        } else {
            let survival = try g(0x44f880)
            if survival > -1 {
                var blink = try g(0x450ba0)
                if blink > 0 { blink &+= 1;try setG(0x450ba0,blink) }
                if blink >= 0x46 { try setG(0x450ba0,0) }
                try format(0x4387bb,[("Survival Stage: ",survival,0)])
                let value = try g(0x450ba0)
                let color: UInt32 = value != 0 && (value/10)%2 != 1 ? 0xc85a5a : 0xc8c8c8
                try text(0x438825,color: color,x: 0x154)
            }
        }
        if reserve == 0 { try format(0x43883a,[("Man: ",players,3),("      HP: ",playerHP,4)]) }
        else { try format(0x43884e,[("Man: ",players,3),("      HP: ",playerHP,4),("     Reserve: ",reserve,3)]) }
        try text(0x43886d,color: 0xff7878,x: 0x0a)
        try format(0x438883,[("Man: ",enemies,3),("      HP: ",enemyHP,4)])
        try text(0x4388a2,color: 0xff00ff,x: 0x285)
    }
    /// 4388af..43899d: the stage-set wipe after 450ba8 reached 3.
    mutating func setTail(_ stageState: Int32) throws {
        guard stageState == 3 else { return }
        var wipe = try g(0x450ba4)
        try setG(0x450bdc,0)
        guard UInt32(bitPattern: wipe) <= 20 else { return }
        if wipe < 10 {
            let h = (wipe &* 0x2b)/10
            var x: UInt32 = 0x87
            while x < 0x235 { fill(0x438900,x,h);x += 0x2b }
        } else { call(.fill,0x438925,[0,0x6d,0x31a,0x1b8,0]) }
        wipe = try g(0x450ba4) &+ 1;try setG(0x450ba4,wipe)
        guard wipe == 21 else { return }
        let q = Self.tenths(try g(0x450b94)).0
        if q == 4 {
            if try g(0x450b88) == 0 || g(0x44d020) == 10 { try setG(0x44d020,0x12c);return }
            try setG(0x450bdc,0x15e);return
        }
        try setG(0x450b94,(q &* 5 &+ 5) &* 2);try setG(0x450b98,1);try setG(0x450bdc,0x15e)
    }

    // MARK: 437400
    mutating func spawn(_ s: Int32,_ base: Int,_ n: Int32) throws {
        let entry = base+0xc+4*Int(n)
        var seat = 20
        while seat < 400 {
            if try active(seat) == 0,try g(0x4514e0+seat*4) == 0 { break }
            seat += 1
        }
        guard seat < 400 else { try setC(s,entry,-1);return }
        var hp = try c(s,base+0xb4)
        var id = try c(s,base+0xac)
        let difficulty = try g(0x450c30)
        if difficulty == -1,id != 0x12c { hp = ftol(try ext(Double(hp))*ext(1.5)) }
        else if difficulty == 2,id != 0x12c { hp = ftol(try ext(Double(hp))*ext(0.75)) }
        if id == 0x3e8 {
            var at = try g(0x44d34c)
            if at == 10 || at == -1 {
                for _ in 0..<50 {
                    let a = Int(try draw(0x10f,10)),b = Int(try draw(0x110,10))
                    let va = try g(0x44d324+a*4),vb = try g(0x44d324+b*4)
                    try setG(0x44d324+a*4,vb);try setG(0x44d324+b*4,va)
                }
                at = 0
            }
            id = try g(0x44d324+Int(at)*4);try setG(0x44d34c,at &+ 1)
        } else if id == 0xbb8 {
            id = try draw(0x111,2) &+ 0x1e
        } else if id == 0xbb9 {
            if try draw(0x112,7) == 0 { id = 0x20;hp &*= 4 }
            else { id = try draw(0x113,2) &+ 0x1e }
        }
        var ordinal: Int?
        for n in 0..<Int(max(objectCount,0)) {
            guard objects.indices.contains(n) else { throw error("catalog Object table") }
            if try objects[n].header.integer(at: 0x6f4,as: Int32.self) == id { ordinal = n;break }
        }
        guard let ordinal else { try setC(s,entry,-1);return }
        try setC(s,entry,Int32(seat));try setActive(seat,1)
        let a = try index(seat)
        try actors[a].reconstructActor();events.append(.constructor(seat: seat))
        try actors[a].write(UInt32(ordinal),at: 0x368)
        try putDouble(a,0x58,350.0)
        try put(a,0x31c,objects[ordinal].header.integer(at: 0x90,as: Int32.self))
        try putDouble(a,0x60,0.0);try putDouble(a,0x68,300.0)
        let bg = try g(0x44d024)
        guard backgrounds.indices.contains(Int(bg)) else { throw error("background binding") }
        let top = try backgrounds[Int(bg)].integer(at: 4,as: Int32.self),bottom = try backgrounds[Int(bg)].integer(at: 8,as: Int32.self)
        try put(a,0x18,draw(0x114,bottom &- top) &+ top)
        let x = try c(s,base+0xb0)
        if x != -1000 { try put(a,0x10,draw(0x115,0x12c) &+ x) }
        else if try draw(0x116,2) == 0 { try put(a,0x10,draw(0x117,0x12c) &+ g(0x450bb4) &+ 0x96) }
        else { try put(a,0x10,-150 &- draw(0x118,0x12c)) }
        try put(a,0x30c,c(s,base+0xbc));try put(a,0x314,c(s,base+0xc0));try put(a,0x310,c(s,base+0xc4))
        try putDouble(a,0x58,Double(i(a,0x10)));try putDouble(a,0x68,Double(i(a,0x18)))
        try put(a,0x308,500);try put(a,0x300,hp);try put(a,0x2fc,hp);try put(a,0x304,hp);try put(a,0x354,Int32(seat))
        let kind = try objects[ordinal].header.integer(at: 0x6f8,as: Int32.self)
        if kind != 0 && kind != 5 {
            try put(a,8,0);try put(a,0x364,0);try put(a,0x14,-300);try putDouble(a,0x60,Double(i(a,0x14)))
        } else {
            try put(a,8,0x14)
            let limit = try g(0x450bb4) &+ -794
            try actors[a].write(UInt8(try i(a,0x10) > limit ? 1 : 0),at: 0x80)
            try put(a,0x70,c(s,base+0xc8));try put(a,0x364,5)
            try put(a,0x14,c(s,base+0xcc));try putDouble(a,0x60,Double(i(a,0x14)));try putDouble(a,0x48,0.0)
        }
        if try objects[ordinal].header.integer(at: 0x6f4,as: Int32.self) == 0x7a { try put(a,0x2fc,200) }
        try setC(s,base,c(s,base) &+ 1)
    }

    // MARK: 436fc0
    mutating func nextStage() throws {
        try setG(0x450b94,g(0x450b94) &+ 1)
        var owned = [Int32](repeating: 0,count: 20)
        try setG(0x450b9c,0x46);try setG(0x450ba8,0);try setG(0x450bac,0)
        try setG(0x44fb6c,-1);try setG(0x44f880,-1);try setG(0x450bc8,0);try setG(0x450bc4,0)
        for seat in 0..<400 where try active(seat) != 0 {
            let a = try index(seat)
            guard try type(a) == 0 else { continue }
            try put(a,0x10,draw(0x10d,0x1e) &+ 0x32);try putDouble(a,0x58,Double(i(a,0x10)))
            try put(a,0x300,i(a,0x300) &+ (g(0x450c30) &+ 2) &* 0x32)
            if try i(a,0x300) > i(a,0x304) { try put(a,0x300,i(a,0x304)) }
            try put(a,0x2fc,i(a,0x300));try put(a,0x308,500)
            let frame = try i(a,0x70)
            if frame >= 9 && frame <= 0xb { try put(a,0x70,0) }
            let now = try i(a,0x70)
            if now >= 0x10 && now <= 0x12 { try put(a,0x70,0xc) }
            let bg = try g(0x44d024)
            guard backgrounds.indices.contains(Int(bg)) else { throw error("background binding") }
            let top = try backgrounds[Int(bg)].integer(at: 4,as: Int32.self),bottom = try backgrounds[Int(bg)].integer(at: 8,as: Int32.self)
            try put(a,0x18,draw(0x10e,bottom &- top) &+ top);try putDouble(a,0x68,Double(i(a,0x18)))
        }
        for seat in 0..<400 {
            let a = try index(seat)
            try put(a,0x3fc,-1000);try put(a,0x400,-1000)
        }
        for seat in 20..<400 {
            let a = try index(seat)
            if try active(seat) != 0,try type(a) > 0,try i(a,0x98) >= 0 { try setActive(seat,0);continue }
            let owner = try i(a,0x2f4)
            if owner >= 0 && owner < 20 {
                if owned[Int(owner)] >= 2 { try setActive(seat,0) }
                else { owned[Int(owner)] += 1 }
            }
        }
    }
}
