import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Comparison-only equations for the active District path. Source and own
/// inputs keep their separate identities and bitmap backing. No Core renderer,
/// camera or impulse handler constructs these expected values.
struct OriginalApplicationActiveGraphicsProjection {
    typealias S = OriginalApplicationActiveBodyControl
    typealias P = S.P
    typealias D = OriginalApplicationGameplayDrawingProjection
    typealias Stage = OriginalGameplayBody.Stage
    static let stages: [Stage] = [.camera,.drawing,.impulses]
    struct Helper { let entry: UInt32,args: [UInt32],result: UInt32?,returnPC: UInt32 }
    var state: S
    var backgrounds: [OriginalStateRecord]
    var drawing: D
    var stores: [P.Store] = []
    var helpers: [Helper] = [],blits = 0
    init(_ match: OriginalMatchPreparation,_ memory: OriginalApplicationMenuSession.State) throws {
        state = try S(match);backgrounds = match.backgrounds;drawing = try D(match,memory)
    }
    init(state: S,backgrounds: [OriginalStateRecord],drawing: D) {
        self.state = state;self.backgrounds = backgrounds;self.drawing = drawing
    }
    func at(_ slot: Int,_ offset: Int) -> Int { 0x7d8+slot*0x420+offset }
    func w(_ slot: Int,_ offset: Int) throws -> Int32 { try state.pool.integer(at:at(slot,offset),as:Int32.self) }
    func b(_ slot: Int,_ offset: Int) throws -> Int8 { try state.pool.integer(at:at(slot,offset),as:Int8.self) }
    func d(_ slot: Int,_ offset: Int) throws -> Double { try S.Actor.finite(state.pool.binary64(at:at(slot,offset))) }
    func h(_ slot: Int,_ offset: Int) throws -> Int32 {
        try XCTUnwrap(state.objects[UInt32(bitPattern:w(slot,0x368))]).integer(at:offset,as:Int32.self)
    }
    func frame(_ slot: Int) throws -> OriginalStateRecord {
        let n = try w(slot,0x70);try P.require((0..<400).contains(n),"Graphics current Frame")
        return try S.slice(XCTUnwrap(state.objects[UInt32(bitPattern:w(slot,0x368))]),0x7a4+Int(n)*0x178,0x178)
    }
    func f(_ slot: Int,_ offset: Int) throws -> Int32 { try frame(slot).integer(at:offset,as:Int32.self) }
    func g(_ address: Int) throws -> Int32 { try state.globals.integer(at:address-0x44d000,as:Int32.self) }
    mutating func put(_ slot: Int,_ offset: Int,_ value: Int32) throws { try state.pool.write(value,at:at(slot,offset)) }
    mutating func global(_ address: Int,_ value: Int32,_ pc: UInt32) throws {
        let offset = address-0x44d000;try state.globals.write(value,at:offset)
        stores.append(.init(pc:pc,region:"globals",offset:offset,bytes:Array(state.globals.bytes[offset..<offset+4])))
    }
    func domain() throws {
        try P.require(state.pool.bytes.count == 0x7d8+400*0x420 && state.globals.bytes.count == 0xb440,"Graphics full records")
        try P.require(state.actorTokens.count == 400 && Set(state.actorTokens).count == 400,"Graphics distinct finite identities")
        for slot in 0..<400 {
            try P.require(state.pool.integer(at:4+slot,as:UInt8.self) == (slot < 2 ? 1 : 0),"Graphics finite activity")
            try P.require(state.pool.integer(at:0x194+4*slot,as:UInt32.self) == state.actorTokens[slot],"Graphics live Actor binding")
        }
        try P.require(backgrounds.count == 101 && g(0x44d024) == 0 && g(0x451160) == 0,"Graphics District VS selection")
        try P.require(g(0x44d78c) == 794 && g(0x44d790) == 550,"Graphics viewport")
        for slot in 0..<2 {
            try P.require(h(slot,0x6f8) == 0 && h(slot,0x6f4) == (slot == 0 ? 2 : 11),"Graphics current finite fighter type/ID")
            try P.require(w(slot,0x1c) == 0,"Finite drawing horizontal offset boundary")
        }
    }
    mutating func advance(_ stage: Stage,_ target: UInt32,_ installed: Bool) throws {
        try domain();drawing.events = [];stores = [];helpers = [];blits = 0
        switch stage {
        case .camera:try camera(target)
        case .drawing:try world(target)
        case .impulses:try diagnostic(installed);try impulses()
        default:throw OriginalApplicationGameplaySource.error("Outside active graphics stages")
        }
    }
    mutating func helper(_ entry: UInt32,_ args: [UInt32] = [],_ result: UInt32? = nil,_ pc: UInt32) {
        helpers.append(.init(entry:entry,args:args,result:result,returnPC:pc))
    }
    mutating func picture(_ token: UInt32,_ catalog: Bool,_ x: Int32,_ y: Int32,_ pic: Int32,_ key: UInt32,_ target: UInt32,_ pc: UInt32) throws {
        let start = drawing.events.count
        try drawing.picture(token,catalog,x,y,pic,key,target)
        var last: UInt32?
        for e in drawing.events.dropFirst(start) {
            if let clip = e.clip { helper(0x43ef70,[],clip.visible ? 1 : 0,pic < 0 ? 0x43f0d5 : 0x43f212) }
            if e.blit != nil { last = UInt32(blits%2);blits += 1 }
        }
        helper(0x43f010,[UInt32(bitPattern:x),UInt32(bitPattern:y),UInt32(bitPattern:pic),key,0,target],pic < 0 ? UInt32.max : last,pc)
    }
    mutating func camera(_ target: UInt32) throws {
        let bg = backgrounds[0],width = try bg.integer(at:0,as:Int32.self)
        let lowZ = try bg.integer(at:4,as:Int32.self),highZ = try bg.integer(at:8,as:Int32.self)
        try P.require(width == 960 && lowZ == 450 && highZ == 525,"Finite District bounds")
        for address in [0x450bb0,0x450bb4,0x450b74] { try P.require(g(address) == 0,"Finite camera override boundary") }
        var sum: Int32 = 0,count: Int32 = 0
        for slot in 0..<2 {
            let z = try d(slot,0x68),x = try d(slot,0x58)
            let nextZ = min(max(z,Double(lowZ)),Double(highZ))
            if z < Double(lowZ) || z > Double(highZ) { try state.pool.writeBinary64(nextZ,at:at(slot,0x68)) }
            try put(slot,0x18,Int32(nextZ.rounded(.towardZero)))
            helper(0x4450d0,[],UInt32(bitPattern:Int32(nextZ.rounded(.towardZero))),0x41b6bd)
            let lowX: Double = try w(slot,0x364) == 5 ? -300 : 0,nextX = min(max(x,lowX),Double(width))
            if x < lowX || x > Double(width) { try state.pool.writeBinary64(nextX,at:at(slot,0x58)) }
            try put(slot,0x10,Int32(nextX.rounded(.towardZero)))
            helper(0x4450d0,[],UInt32(bitPattern:Int32(nextX.rounded(.towardZero))),0x41b8b9)
            if try w(slot,0x2fc) > 0 && g(0x450b4c+slot*4) > 0 {
                let position = try f(slot,8) == 14 ? w(slot,0x10) : w(slot,0x10) &- (Int32(b(slot,0x80)) &* 260) &+ 130
                sum = sum &+ position;count += 1
            }
        }
        if count == 0 {
            for slot in 0..<2 where try w(slot,0x2fc) > 0 { sum = try sum &+ w(slot,0x10);count += 1 }
        }
        if count == 0 { sum = 800;count = 1 }
        let desired = min(max((sum/count) &- 397,0),width &- 794),old = try g(0x450bc4)
        var velocity = try ((g(0x450bc8) &* 6) &+ ((desired &- old)/14))/7
        try global(0x450bc8,velocity,0x41bbf7)
        if velocity == 0 && desired != old {
            velocity = desired > old ? 1 : -1;try global(0x450bc8,velocity,0x41bc0e)
        }
        let position = old &+ velocity
        // This path has no final clamp store; retain an explicit boundary until
        // its distinct store PCs are added to the comparison.
        try P.require(position >= 0 && position <= width-794,"Finite camera final clamp boundary")
        try global(0x450bc4,position,0x41bc23)
        try P.require(bg.integer(at:0x1c,as:Int32.self) == 15,"Finite District layers")
        for layer in 0..<15 {
            func v(_ offset: Int) throws -> Int32 { try bg.integer(at:offset+4*layer,as:Int32.self) }
            try P.require(v(0x89c) == 0 && v(0x644) == 0,"Finite non-fill non-loop BG")
            let shift = try 0 &- (((v(0x464) &- 794) &* position)/(width &- 794))
            if try v(0x7ac) > 0 {
                let offset = 0x824+4*layer,value = try (v(0x824) &+ 1)%v(0x7ac)
                try backgrounds[0].write(value,at:offset)
                stores.append(.init(pc:0x41a35a,region:"background0",offset:offset,bytes:Array(backgrounds[0].bytes[offset..<offset+4])))
                if try value < v(0x6bc) || value > v(0x734) { continue }
            }
            let bitmap = try drawing.token(UInt32(bitPattern:v(0x914)))
            try picture(bitmap,true,v(0x4dc) &+ shift,v(0x554),-1,UInt32(bitPattern:v(0x3ec)),target,0x41a3ce)
        }
        helper(0x41a250,[target],nil,0x41bc80)
        helper(0x41b5d0,[target,0],nil,0x41f496)
    }
    func sheet(_ slot: Int,_ pic: Int32) throws -> (index:Int,first:Int32)? {
        let count = try h(slot,0x498);try P.require((0...10).contains(count),"Graphics DAT sheet count")
        for index in 0..<Int(count) {
            let first = try h(slot,0x62c+4*index),end = try first &+ (h(slot,0x6a4+4*index) &* h(slot,0x6cc+4*index))
            if pic >= first && pic < end { return (index,first) }
        }
        return nil
    }
    mutating func world(_ target: UInt32) throws {
        let camera = try g(0x450bc4),bg = backgrounds[0]
        let order = try [0,1].sorted { a,b in try w(a,0x18) == w(b,0x18) ? a < b : w(a,0x18) < w(b,0x18) }
        for slot in order {
            let x = try w(slot,0x10) &- camera,z = try w(slot,0x18),blink = try w(slot,8)
            let magnitude = blink < 0 ? 0 &- blink : blink,visible = magnitude%4 < 2
            let frameState = try f(slot,8)
            try P.require(w(slot,0x30c) <= 1 && w(slot,0x36c) == 0,"Finite no extra lives/sparks")
            if try w(slot,0x98) >= 0 && ![3005,9997].contains(frameState) && blink > -70 && visible {
                let shadow = try drawing.token(bg.integer(at:0x98c,as:UInt32.self))
                try picture(shadow,true,w(slot,0x1c) &+ x &- bg.integer(at:0x14,as:Int32.self)/2,z &- bg.integer(at:0x18,as:Int32.self)/2,-1,1,target,0x41a76c)
            }
            if blink > -25 && visible {
                let face = try b(slot,0x80),pic = try f(slot,4),offset = try w(slot,0x318)
                let shiftedX = try w(slot,0xb4) < 0 ? x &+ (g(0x450bd8) &* 6) &- 3 : x
                var left = shiftedX
                if face == 0 { left = try shiftedX &- f(slot,0x50) }
                if face == 1 {
                    var width: Int32 = 0
                    if try frame(slot).integer(at:0,as:UInt8.self) != 0,let normal = try sheet(slot,pic) {
                        let token = try drawing.token(UInt32(bitPattern:h(slot,0x754+4*normal.index)))
                        let at = UInt32(bitPattern:pic &- normal.first) &* 4 &+ 0xfb0
                        drawing.events.append(.init("width",[token,at]))
                        width = try drawing.read(drawing.resolve(token,true),at)
                    }
                    left = try shiftedX &+ f(slot,0x50) &- width
                    helper(0x40bf30,[UInt32(bitPattern:try w(slot,0x70))],UInt32(bitPattern:width),0x40e092)
                }
                if frameState == 9997 { left = min(max(left,0),714) }
                if [0,1].contains(face),try frame(slot).integer(at:0,as:UInt8.self) != 0,let sheet = try sheet(slot,pic &+ offset) {
                    let token = try drawing.token(UInt32(bitPattern:h(slot,(face == 0 ? 0x754 : 0x77c)+4*sheet.index)))
                    let y = try z &- f(slot,0x54) &+ w(slot,0x14)
                    try picture(token,true,left,y,(pic &+ offset) &- sheet.first,1,target,face == 0 ? 0x40bf1b : 0x40bf08)
                    helper(0x40be70,[UInt32(bitPattern:left),UInt32(bitPattern:y),UInt32(bitPattern:try w(slot,0x70)),1,UInt32(bitPattern:Int32(face)),UInt32(bitPattern:offset),target],helpers.last?.result,face == 0 ? 0x40e051 : 0x40e0ba)
                }
                if frameState != 9997 { try P.require(w(slot,0x2fc) >= w(slot,0x304)/3 || f(slot,0x80) <= 0,"Low-HP marker needs comparison extension") }
                helper(0x40de30,[UInt32(bitPattern:camera),target,UInt32(bitPattern:try g(0x450bd8))],nil,0x41a7a4)
            }
            if blink > -25 {
                var label: [UInt8] = []
                for n in 0..<11 {
                    let byte = try state.globals.integer(at:0x44fcc0-0x44d000+11*slot+n,as:UInt8.self)
                    if byte == 0 { break };label.append(byte)
                }
                try P.require(label.count < 11 && g(0x450b4c+4*slot) != -1,"Finite unbracketed name")
                let team = try w(slot,0x364),fonts: [Int32:Int] = [1:0x44f888,2:0x44fcbc,3:0x44fb68,4:0x44faf8]
                let font = drawing.resourceToken(UInt32(bitPattern:try g(fonts[team] ?? 0x44faf4)))
                let width = Int32(label.count*9),left = min(max(x &- width/2,0),794 &- width)
                for (n,byte) in label.enumerated() {
                    try picture(font,false,left &+ Int32(9*n),z &+ 3,Int32(Int8(bitPattern:byte)),1,UInt32(bitPattern:g(0x455608)),0x41ab26)
                }
            }
        }
        helper(0x4450b2,[],2,0x41ae4a)
        helper(0x41a5a0,[target,UInt32(bitPattern:try g(0x450bd8)),0],2,0x41f4ac)
    }
    mutating func diagnostic(_ installed: Bool) throws {
        let values = try [0xc4,0xc5,0xc3,0xc2,0xbe,0xc0].map { try b(10,$0) }
        let label = zip(["u","d","l","r","a","d"],values).map { $0.0+String($0.1)+" " }.joined()
        let bytes = Array(label.utf8)
        drawing.events.append(.init("format",[UInt32(bytes.count)],[Array("u%d d%d l%d r%d a%d d%d ".utf8),bytes]))
        try drawing.surfaceText(bytes,UInt32(bitPattern:g(0x455608)),0,30,0xffffff,installed)
        helper(0x7817775d,[0x1000ee48,0x449288]+values.map { UInt32(bitPattern:Int32($0)) },UInt32(bytes.count),0x41f51c)
        helper(0x401290,[UInt32(bitPattern:try g(0x455608)),0x1000ee48,0,0xffffff,0,30],0,0x41f53b)
    }
    mutating func impulses() throws {
        for slot in 0..<2 {
            if try w(slot,0xb4) != 0 { continue }
            try P.require(w(slot,0x20) == 0,"Nonzero accumulated impulse needs finite arithmetic comparison")
            for offset in [0x28,0x30,0x38] { try state.pool.writeBinary64(0,at:at(slot,offset)) }
        }
        helper(0x4196f0,[],nil,0x41f545)
    }
}

extension OriginalApplicationGameplayDrawingProjection {
    init(active state: MatchLaunchReference.State,_ input: OriginalApplicationActiveGameplayInput) throws {
        var c: [UInt32:Bitmap] = [:],r: [UInt32:Bitmap] = [:],tokens: [UInt32:UInt32] = [:]
        func bitmap(_ storage: MatchLaunchReference.Storage) throws -> Bitmap {
            var record = try input.record(storage.bytes,storage.defined)
            let surface = try record.integer(at:0,as:UInt32.self)
            try record.write(UInt32(surface == 0 ? 0 : 1),at:0)
            return .init(record:record,surface:surface)
        }
        for (index,value) in state.bitmaps.enumerated() {
            let token = UInt32(index+1),b = try bitmap(value.storage)
            c[token] = b;r[token] = b;r[value.address] = b;tokens[value.address] = token
        }
        for value in state.early.records where value.live {
            if try input.bytes(value.storage.bytes).count == 0x1f50 { r[value.address] = try bitmap(value.storage) }
        }
        for value in state.menuBitmaps ?? [] { r[value.address] = try bitmap(value.storage) }
        catalog = c;resources = r;catalogTokens = tokens
    }
}
