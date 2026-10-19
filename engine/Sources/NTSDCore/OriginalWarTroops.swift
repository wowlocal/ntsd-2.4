/// War troop arithmetic and ordered table updates recovered from438b40.
/// This dependency does not execute the enclosing menu or prepare a battle.
public enum OriginalWarTroops {
    public enum Change: Equatable, Sendable { case active, reserve }
    public typealias Store = (Int,Int32) throws -> Void
    private static let base=OriginalMatchPreparation.globalBase
    private static func word(_ g: OriginalStateRecord,_ a: Int) throws -> Int32 {
        try g.integer(at:a-base,as:Int32.self)
    }
    private static func put(_ g: inout OriginalStateRecord,_ a: Int,_ v: Int32,_ observe: Store) throws {
        try g.write(v,at:a-base);try observe(a,v)
    }
    private static func validate(_ g: OriginalStateRecord,_ side: Int) throws {
        guard (0..<2).contains(side),try word(g,0x44d37c)==11 else {
            throw OriginalStateError.invalidStorage("War troop side/unit count")
        }
    }
    private static func table(_ g: inout OriginalStateRecord,_ side: Int,_ preset: Int,_ strength: Int32,_ observe: Store) throws {
        guard (0..<5).contains(preset),(1...3).contains(strength) else {
            throw OriginalStateError.invalidStorage("War troop preset/strength")
        }
        for i in 0..<11 {
            let total=try (word(g,0x44d388+(preset*11+i)*4) &* strength)/3
            var active=try (word(g,0x44d468+(preset*11+i)*4) &* strength)/3
            if active<1 && total>0 { active=1 }
            let reserve=total &- active
            try put(&g,0x44d5f8+(side*11+i)*4,active,observe)
            try put(&g,0x44d650+(side*11+i)*4,reserve,observe)
            if reserve<0 { try put(&g,0x44d650+(side*11+i)*4,0,observe) }
        }
    }
    public static func initialize(_ globals: inout OriginalStateRecord,observe: Store = { _,_ in }) throws {
        var g=globals
        for side in 0..<2 { try validate(g,side);try table(&g,side,0,1,observe) }
        globals=g
    }
    public static func selectPreset(_ globals: inout OriginalStateRecord,side: Int,preset: Int,observe: Store = { _,_ in }) throws {
        var g=globals;try validate(g,side)
        if try word(g,0x451b98+side*4) == -1 { try put(&g,0x451b98+side*4,0,observe) }
        try put(&g,0x44d380+side*4,Int32(preset)+1,observe)
        let strength=try word(g,0x451b98+side*4)
        try put(&g,0x451b74+side*4,strength,observe)
        try put(&g,0x451b90+side*4,Int32(preset),observe)
        try table(&g,side,preset,strength &+ 1,observe);globals=g
    }
    public static func selectStrength(_ globals: inout OriginalStateRecord,side: Int,strength: Int32,observe: Store = { _,_ in }) throws {
        var g=globals;try validate(g,side)
        try put(&g,0x451b98+side*4,strength,observe)
        if try word(g,0x451b90+side*4) == -1 { try put(&g,0x451b90+side*4,0,observe) }
        let preset=try word(g,0x451b90+side*4)
        try table(&g,side,Int(preset),strength &+ 1,observe)
        try put(&g,0x451b74+side*4,strength,observe)
        try put(&g,0x44d380+side*4,preset &+ 1,observe);globals=g
    }
    public static func selectNone(_ globals: inout OriginalStateRecord,side: Int,observe: Store = { _,_ in }) throws {
        var g=globals;try validate(g,side)
        try put(&g,0x451b98+side*4,-1,observe);try put(&g,0x451b90+side*4,-1,observe)
        for a in [0x44d650,0x44d5f8] { for i in 0..<11 { try put(&g,a+(side*11+i)*4,0,observe) } }
        try put(&g,0x44d380+side*4,0,observe);globals=g
    }
    public static func selectAll(_ globals: inout OriginalStateRecord,side: Int,observe: Store = { _,_ in }) throws {
        var g=globals;try validate(g,side)
        try put(&g,0x451b98+side*4,-1,observe);try put(&g,0x451b90+side*4,-1,observe)
        for i in 0..<11 { try put(&g,0x44d650+(side*11+i)*4,30,observe) }
        for i in 0..<11 { try put(&g,0x44d5f8+(side*11+i)*4,2,observe) }
        try put(&g,0x44d5f8+(side*11+7)*4,1,observe)
        try put(&g,0x44d650+(side*11+7)*4,15,observe)
        for i in [9,10] { try put(&g,0x44d5f8+(side*11+i)*4,3,observe) }
        try put(&g,0x44d380+side*4,6,observe);globals=g
    }
    public static func adjust(_ globals: inout OriginalStateRecord,side: Int,unit: Int,change: Change,
        attack: Bool,jump: Bool,defense: Bool,observe: Store = { _,_ in }) throws {
        var g=globals;try validate(g,side)
        guard (0..<11).contains(unit) else { throw OriginalStateError.invalidStorage("War troop cell") }
        guard attack || jump || defense else { return }
        try put(&g,0x44d380+side*4,-1,observe);try put(&g,0x451b74+side*4,-1,observe)
        let a=(change == .active ? 0x44d5f8 : 0x44d650)+(side*11+unit)*4
        let maximum: Int32=change == .active ? 10 : 30
        if attack { try put(&g,a,word(g,a) &+ 1,observe) }
        if defense {
            try put(&g,a,word(g,a) &+ 5,observe)
            if try word(g,a)>maximum && word(g,a)<maximum &+ 5 { try put(&g,a,maximum,observe) }
        }
        if jump { try put(&g,a,word(g,a) &- 1,observe) }
        let value=try word(g,a)
        if value<0 { try put(&g,a,maximum,observe) }
        else if value>maximum { try put(&g,a,0,observe) }
        globals=g
    }
    public static func backup(_ globals: inout OriginalStateRecord,side: Int,observe: Store = { _,_ in }) throws {
        var g=globals;try validate(g,side)
        for (from,to) in [(0x44d650,0x44d5a0),(0x44d5f8,0x44d548)] {
            for i in 0..<22 { try put(&g,to+i*4,word(g,from+i*4),observe) }
        }
        try put(&g,0x451b8c,word(g,0x451b98+side*4),observe)
        try put(&g,0x451b88,word(g,0x451b90+side*4),observe);globals=g
    }
    public static func restore(_ globals: inout OriginalStateRecord,side: Int,jump: Bool,observe: Store = { _,_ in }) throws {
        var g=globals;try validate(g,side)
        for (from,to) in [(0x44d5a0,0x44d650),(0x44d548,0x44d5f8)] {
            for i in 0..<22 { try put(&g,to+i*4,word(g,from+i*4),observe) }
        }
        if jump {
            try put(&g,0x451b98+side*4,word(g,0x451b8c),observe)
            try put(&g,0x451b90+side*4,word(g,0x451b88),observe)
        }
        globals=g
    }
    public static func finalize(_ globals: inout OriginalStateRecord,observe: Store = { _,_ in }) throws {
        var g=globals;try validate(g,0)
        for i in 0..<22 {
            let active=try word(g,0x44d5f8+i*4)
            let total=try active>0 ? active &+ word(g,0x44d650+i*4) : 0
            try put(&g,0x44d6a8+i*4,total,observe);try put(&g,0x44d700+i*4,active,observe)
        }
        globals=g
    }
}
