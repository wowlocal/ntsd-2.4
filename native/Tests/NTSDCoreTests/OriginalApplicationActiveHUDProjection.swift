import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Current-input HUD equations and accepted independent bitmap expansion.
/// No Frame/physics assumption and no Core HUD/renderer or expected snapshot.
struct OriginalApplicationActiveHUDProjection {
    typealias S = OriginalApplicationActiveBodyControl
    typealias P = S.P
    typealias D = OriginalApplicationGameplayDrawingProjection
    struct Request { let token: UInt32,pc: UInt32,events: Range<Int> }
    var state: S,drawing: D
    var selected: [Int] = [],requests: [Request] = []
    init(_ match: OriginalMatchPreparation,_ memory: OriginalApplicationMenuSession.State) throws {
        state = try S(match);drawing = try D(match,memory)
    }
    init(state: S,drawing: D) { self.state = state;self.drawing = drawing }
    func at(_ slot: Int,_ offset: Int) -> Int { 0x7d8+slot*0x420+offset }
    func i(_ slot: Int,_ offset: Int) throws -> Int32 { try state.pool.integer(at:at(slot,offset),as:Int32.self) }
    func g(_ address: Int) throws -> Int32 { try state.globals.integer(at:address-0x44d000,as:Int32.self) }
    mutating func put(_ slot: Int,_ offset: Int,_ value: Int32) throws { try state.pool.write(value,at:at(slot,offset)) }
    mutating func picture(_ token: UInt32,_ catalog: Bool,_ x: Int32,_ y: Int32,_ frame: Int32,_ key: UInt32,_ pc: UInt32) throws {
        let start = drawing.events.count
        try drawing.picture(token,catalog,x,y,frame,key,UInt32(bitPattern:g(0x455608)))
        requests.append(.init(token:token,pc:pc,events:start..<drawing.events.count))
    }
    mutating func rectangle(_ value: Int32,_ row: Int32,_ x: Int32,_ y: Int32,_ pc: UInt32) throws {
        let token = drawing.resourceToken(UInt32(bitPattern:try g(0x44fd7c))),start = drawing.events.count
        try drawing.rectangle(token,value,row,x,y,UInt32(bitPattern:g(0x455608)))
        requests.append(.init(token:token,pc:pc,events:start..<drawing.events.count))
    }
    mutating func advance() throws {
        try P.require(state.pool.bytes.count == 0x7d8+400*0x420 && state.globals.bytes.count == 0xb440,"HUD full records")
        try P.require(state.actorTokens.count == 400 && Set(state.actorTokens).count == 400,"HUD allocation identities")
        try P.require(g(0x44d78c) == 794 && g(0x44d790) == 550,"HUD finite viewport expansion")
        // Write-only command flags become known even when their old masks are not.
        try state.globals.write(Int32(0),at:0x450bc0-0x44d000)
        try state.globals.write(Int32(0),at:0x450bb8-0x44d000)
        drawing.events = [];selected = [];requests = []
        for cell in 0..<8 {
            let x = Int32(cell&3)*198,y = Int32(cell>>2)*54
            try picture(drawing.resourceToken(UInt32(bitPattern:g(0x4511a8))),false,x,y,-1,0,0x41aea0)
            let slot: Int
            if try state.pool.integer(at:4+cell,as:UInt8.self) != 0 { slot = cell }
            else if try state.pool.integer(at:14+cell,as:UInt8.self) != 0 { slot = cell+10 }
            else { continue }
            let token = try state.pool.integer(at:0x194+slot*4,as:UInt32.self)
            let actor = try XCTUnwrap(state.actorTokens.firstIndex(of:token),"HUD current Actor binding")
            selected.append(actor)
            let objectToken = UInt32(bitPattern:try i(actor,0x368))
            let object = try XCTUnwrap(state.objects[objectToken],"HUD current Object")
            try picture(drawing.token(object.integer(at:0x728,as:UInt32.self)),true,x+9,y+7,-1,0,0x41aefa)
            let hp = try i(actor,0x2fc)
            if hp > 0 {
                try rectangle((i(actor,0x300) &* 31)/125,30,x+57,y+16,0x41af54)
                try rectangle((hp &* 31)/125,20,x+57,y+16,0x41af97)
                if try (i(actor,0xe0)/1000 == 1 || i(actor,0xe4) > 0) && g(0x450bd0)%2 == 0 {
                    try rectangle((hp &* 31)/125,40,x+57,y+16,0x41b021)
                }
                try rectangle(124,10,x+57,y+36,0x41b040)
                try rectangle((i(actor,0x308) &* 31)/125,0,x+57,y+36,0x41b083)
            }
            let team = try i(actor,0x364)
            let resource = [Int32(1):0x44f888,2:0x44fcbc,3:0x44fb68,4:0x44faf8][team] ?? 0x44faf4
            try picture(drawing.resourceToken(UInt32(bitPattern:g(resource))),false,x+5,y,254,1,0x41b112)
        }
    }
}
