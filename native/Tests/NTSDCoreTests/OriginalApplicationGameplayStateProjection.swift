import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Independent finite arithmetic for the saved neutral gameplay path. These
/// records are comparison outputs only; no projected state is passed to Core.
/// The complete graphics/ownership comparator is a separate caller of this model.
struct OriginalApplicationGameplayStateProjection {
    typealias Source = OriginalApplicationGameplaySource
    typealias Stage = OriginalGameplayBody.Stage
    struct Store: Equatable {
        let pc: UInt32,region: String,offset: Int,bytes: [UInt8]
    }
    struct Sound: Equatable { let slot: Int,x: Int32,index: Int32 }
    var pool: OriginalStateRecord,globals: OriginalStateRecord,backgrounds: [OriginalStateRecord]
    let objects: [OriginalLoadedObject]
    let installedRequestedID: Int32?
    let ownedFrames: [OriginalFrameAllocation]?
    var stores: [Store] = [],sounds: [Sound] = [],draw: Int32?

    init(_ state: OriginalMatchPreparation) throws {
        try Self.require(state.arithmeticPrecision == .bits53,"Own precision")
        pool = try .init(bytes:state.world.bytes+state.actors.flatMap(\.bytes),
            defined:state.world.defined+state.actors.flatMap(\.defined))
        globals = state.globals;backgrounds = state.backgrounds;objects = state.loadedObjects
        installedRequestedID = state.libraryCommands?.requestedObjectID;ownedFrames = state.frameAllocations
    }
    init(_ state: MatchLaunchReference.State,source: Source,objects: [OriginalLoadedObject]) throws {
        pool = try source.pool(state);globals = try source.globals(state)
        backgrounds = try state.backgrounds.map(source.record);self.objects = objects;installedRequestedID = nil;ownedFrames = nil
    }
    static func require(_ condition: Bool,_ detail: String) throws {
        guard condition else { throw Source.error("Projection "+detail) }
    }
    static func same(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
        try require(actual.bytes.count == expected.bytes.count,label+" extent")
        if let n = actual.bytes.indices.first(where:{ actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
            throw Source.error("Projection \(label) at \(String(n,radix:16)): \(actual.bytes[n])/\(actual.defined[n]) versus \(expected.bytes[n])/\(expected.defined[n])")
        }
    }
    func actor(_ slot: Int) throws -> Int {
        let index = Int(try pool.integer(at:0x194+4*slot,as:UInt32.self))
        try Self.require((0..<400).contains(index),"Actor binding")
        return 0x7d8+index*0x420
    }
    func i(_ slot: Int,_ at: Int) throws -> Int32 { try pool.integer(at:actor(slot)+at,as:Int32.self) }
    func b(_ slot: Int,_ at: Int) throws -> Int8 { try pool.integer(at:actor(slot)+at,as:Int8.self) }
    func d(_ slot: Int,_ at: Int) throws -> Double { try pool.binary64(at:actor(slot)+at) }
    func g(_ at: Int) throws -> Int32 { try globals.integer(at:at-0x44d000,as:Int32.self) }
    func object(_ slot: Int) throws -> OriginalLoadedObject {
        let n = Int(try i(slot,0x368));try Self.require(objects.indices.contains(n),"Object binding");return objects[n]
    }
    func h(_ slot: Int,_ at: Int) throws -> Int32 { try object(slot).header.integer(at:at,as:Int32.self) }
    func frame(_ slot: Int,_ number: Int32? = nil) throws -> OriginalStateRecord {
        let n = Int(try number ?? i(slot,0x70)),object = try object(slot)
        try Self.require(object.frameStorage.indices.contains(n),"Frame binding");return object.frameStorage[n]
    }
    func f(_ slot: Int,_ at: Int) throws -> Int32 { try frame(slot).integer(at:at,as:Int32.self) }
    mutating func put(_ slot: Int,_ at: Int,_ value: Int32,_ pc: UInt32) throws {
        let offset = try actor(slot)+at;try pool.write(value,at:offset)
        stores.append(.init(pc:pc,region:"pool",offset:offset,bytes:Array(pool.bytes[offset..<offset+4])))
    }
    mutating func number(_ slot: Int,_ at: Int,_ value: Double,_ pc: UInt32) throws {
        // Finite53-bit domain: each intermediate fits binary64's exponent range.
        // A separately stored sum is required before later arithmetic/conversion.
        try Self.require(value.isFinite && abs(value) < 10_000,"Numeric finite domain")
        let offset = try actor(slot)+at;try pool.writeBinary64(value,at:offset)
        stores.append(.init(pc:pc,region:"pool",offset:offset,bytes:Array(pool.bytes[offset..<offset+8])))
    }
    mutating func global(_ at: Int,_ value: Int32,_ pc: UInt32) throws {
        try globals.write(value,at:at-0x44d000)
        stores.append(.init(pc:pc,region:"globals",offset:at-0x44d000,bytes:Array(globals.bytes[(at-0x44d000)..<(at-0x44d000+4)])))
    }
    mutating func byte(_ at: Int,_ value: UInt8,_ pc: UInt32) throws {
        try globals.write(value,at:at-0x44d000)
        stores.append(.init(pc:pc,region:"globals",offset:at-0x44d000,bytes:[value]))
    }
    func livePair() throws {
        try Self.require(objects.count == 137, "Catalog extent")
        for slot in 0..<400 {
            let activity = try pool.integer(at:4+slot,as:UInt8.self)
            try Self.require(activity == (slot < 2 ? 1 : 0),"Neutral activity \(slot)")
            try Self.require(actor(slot) == 0x7d8+slot*0x420,"Distinct slot binding")
        }
        for slot in 0..<2 {
            try Self.require(i(slot,0x368) == (slot == 0 ? 17 : 21),"Selected Object")
            try Self.require(h(slot,0x6f8) == 0 && h(slot,0x6f4) == (slot == 0 ? 2 : 11),"Fighter type/ID")
            try Self.require(i(slot,0xb4) == 0 && i(slot,0x98) == 0 && f(slot,0x88) == 0,"Freeze/held/cpoint")
            try Self.require(i(slot,0x2fc) == 500 && i(slot,0x300) == 500,"Living HP")
            try Self.require(i(slot,0x14) == 0 && d(slot,0x60) == 0,"Grounded entry")
            try Self.require([0,15].contains(f(slot,8)),"Neutral Frame state")
        }
    }

    mutating func physics() throws {
        try livePair()
        for slot in 0..<2 {
            let vx = try d(slot,0x40),vz = try d(slot,0x50),vy = try d(slot,0x48)
            try Self.require([0,0.1].contains(vx) && vx == vz && vy == vx,"Neutral velocity")
            for at in [0x3ec,0x3e8,0x3f0,0x3f4] { try Self.require(i(slot,at) == 0,"Obstruction") }
            try number(slot,0x58,d(slot,0x58)+vx,0x40e523)
            try number(slot,0x68,d(slot,0x68)+vz,0x40e58d)
            for (at,pc): (Int,UInt32) in [(0x3ec,0x40e592),(0x3e8,0x40e598),(0x3f0,0x40e59e),(0x3f4,0x40e5a4)] { try put(slot,at,0,pc) }
            for (at,pc,zero): (Int,UInt32,UInt32) in [(0x40,0x40e5f8,0x40e606),(0x50,0x40e640,0x40e64e)] {
                if try d(slot,at) > 0.0001 {
                    let value = try d(slot,at)-1;try number(slot,at,value,pc)
                    if value < 0.0001 { try number(slot,at,0,zero) }
                }
                try Self.require(d(slot,at) == 0,"Neutral post-friction")
            }
            try number(slot,0x60,d(slot,0x60)+vy,0x40e6c8)
            if try d(slot,0x60) > 0.0001 && vy > 0.0001 {
                try Self.require(f(slot,8) == 0 && i(slot,0x70) == 0,"Ordinary landing")
                try number(slot,0x60,0,0x40ea4f);try number(slot,0x48,0,0x40ea54)
                try number(slot,0x40,d(slot,0x40)/3,0x40ea60)
                try put(slot,0x70,219,0x40eaaf);try put(slot,0x88,0,0x40eab6)
            }
            for (from,to,pc): (Int,Int,UInt32) in [(0x58,0x10,0x40ef2d),(0x60,0x14,0x40ef38),(0x68,0x18,0x40ef49)] {
                let value = try d(slot,from)
                try Self.require(value.isFinite && abs(value) < 10_000,"Legacy conversion domain")
                try put(slot,to,Int32(value.rounded(.towardZero)),pc)
            }
            try Self.require(f(slot,8) != 12,"Final falling state");try put(slot,0x320,0,0x40ef5e)
        }
    }
    mutating func hits() throws {
        for slot in 0..<2 { try Self.require(i(slot,0xec) == 0 && i(slot,0x2e4) == 0,"No collected hits") }
        try global(0x45115c,0,0x41ef03)
        let counter = try (g(0x450c34) &+ 1)%1234,index = try (g(0x450bcc) &+ 1)%3000
        try Self.require(counter >= 0 && index >= 0,"RNG index")
        let value = try globals.integer(at:0x44ff90-0x44d000+Int(index),as:UInt8.self)
        try global(0x450c34,counter,0x4171a1);try global(0x450bcc,index,0x4171b0)
        draw = (Int32(value)+counter)%200
        try Self.require(draw != 0,"Nonzero item draw; additional item path requires a separate contract")
    }
    mutating func contacts() throws {
        try livePair();try Self.require(g(0x44d05c) != 2,"Contact enabled path")
        for slot in 0..<20 { try Self.require(i(slot,0x338) == 0,"Fusion cooldown") }
        for slot in 0..<2 {
            try Self.require(f(slot,0x128) == 0,"Empty ITR")
            for other in 0..<2 { try Self.require(b(slot,0xf0+other) == 0,"No victim rest") }
            try put(slot,0x7c,i(slot,0x70),slot == 0 ? 0x4193ac : 0x419426)
            try put(slot,0xec,0,slot == 0 ? 0x419412 : 0x419486)
        }
    }
    mutating func camera() throws {
        try livePair();try Self.require(backgrounds.count == 101 && g(0x44d024) == 0,"District selection")
        let bg = backgrounds[0],width = try bg.integer(at:0,as:Int32.self)
        try Self.require(width == 960 && bg.integer(at:4,as:Int32.self) == 450 && bg.integer(at:8,as:Int32.self) == 525,"District bounds")
        for at in [0x450bb0,0x450bb4,0x450b74] { try Self.require(g(at) == 0,"Ordinary camera guard") }
        var sum: Int32 = 0
        for slot in 0..<2 {
            let x = try d(slot,0x58),z = try d(slot,0x68)
            try Self.require(x >= 0 && x <= 960 && z >= 450 && z <= 525,"Unclamped fighter")
            try put(slot,0x18,Int32(z.rounded(.towardZero)),0x41b6bd)
            try put(slot,0x10,Int32(x.rounded(.towardZero)),0x41b8c3)
            try Self.require(g(0x450b4c+slot*4) > 0 && b(slot,0x80) == 0,"Priority seat/facing")
            sum = try sum &+ (i(slot,0x10) &- Int32(b(slot,0x80)) &* 260 &+ 130)
        }
        let target = min(max(sum/2-397,0),width-794),old = try g(0x450bc4)
        var velocity = try ((g(0x450bc8) &* 6) &+ ((target &- old)/14))/7
        try global(0x450bc8,velocity,0x41bbf7)
        if velocity == 0 && target != old {
            velocity = target > old ? 1 : -1;try global(0x450bc8,velocity,0x41bc0e)
        }
        let current = old &+ velocity
        try Self.require(current >= 0 && current <= width-794,"Camera limit branch")
        try global(0x450bc4,current,0x41bc23)
        try Self.require(bg.integer(at:0x1c,as:Int32.self) == 15,"District layer count")
        for layer in 0..<15 {
            try Self.require(bg.integer(at:0x89c+4*layer,as:Int32.self) == 0 && bg.integer(at:0x644+4*layer,as:Int32.self) == 0,"Non-fill, non-loop layer")
            let period = try bg.integer(at:0x7ac+4*layer,as:Int32.self)
            if period > 0 {
                let at = 0x824+4*layer,next = try (bg.integer(at:at,as:Int32.self) &+ 1)%period
                try backgrounds[0].write(next,at:at)
                stores.append(.init(pc:0x41a35a,region:"background0",offset:at,bytes:Array(backgrounds[0].bytes[at..<at+4])))
            }
        }
    }
    mutating func impulses() throws {
        for slot in 0..<2 {
            try Self.require(i(slot,0xb4) == 0 && i(slot,0x20) == 0,"No accumulated impulse")
            for (at,pc): (Int,UInt32) in [(0x28,0x419772),(0x30,0x419777),(0x38,0x41977c)] { try number(slot,at,0,pc) }
        }
    }
    mutating func queue(_ slot: Int,_ index: Int32) throws {
        try Self.require(index == 6,"Finite catalog sound")
        let x = try i(slot,0x10),position = try x &- g(0x450bc4)
        func weight(_ center: Int32) -> Int32 {
            let distance = abs(position &- center)
            return distance < 200 ? 100 : distance < 400 ? ((400 &- distance) &* 100)/200 : 0
        }
        let flag = 0x457588+4*Int(index),left = 0x457bc8+4*Int(index),right = 0x452170+4*Int(index)
        if try g(flag) == 0 { try global(left,0,0x41704a);try global(right,0,0x417055) }
        try global(left,g(left) &+ weight(200),0x417060);try global(right,g(right) &+ weight(600),0x417067)
        try global(flag,1,0x41706e);sounds.append(.init(slot:slot,x:x,index:index))
    }
    mutating func lifecycle() throws {
        try livePair()
        for slot in 0..<2 {
            try Self.require(i(slot,0x2f4) == -1 && i(slot,0x320) == 0,"Resource owner/damage")
            try Self.require(i(slot,8) > 0 && i(slot,0xec) == 0 && i(slot,0xb0) == 0 && i(slot,0xb8) == 0 && b(slot,0xea) == 0,"Scheduler timers")
            if try g(0x450bd4) == 0 {
                let amount = try (500-min(i(slot,0x2fc),500))/100+1
                try Self.require(i(slot,0x308) < 500 && ![51,52].contains(h(slot,0x6f4)),"MP regeneration")
                try put(slot,0x308,i(slot,0x308) &+ amount,0x41faf2)
            }
            try put(slot,8,i(slot,8) &- 1,0x40da05)
            if try i(slot,0x70) != i(slot,0x74) {
                let sound = try f(slot,0x174);if sound >= 0 { try queue(slot,sound) }
                try put(slot,0x88,0,0x40da73)
            }
            try put(slot,0x88,i(slot,0x88) &+ 1,0x40da7f)
            if try i(slot,0x88) > f(slot,0xc) {
                try put(slot,0x88,0,0x40db9c)
                let next = try f(slot,0x10)
                if next != 0 {
                    try Self.require(next > 0 && (next < 400 || next == 999),"Neutral next frame")
                    try put(slot,0x70,next,0x40dbb5)
                    if next == 999 { try put(slot,0x70,0,0x40dbf6) }
                    let sound = try f(slot,0x174);if sound >= 0 { try queue(slot,sound) }
                    try Self.require(f(slot,0x4c) >= 0,"No MP command cost")
                }
            }
            try Self.require([0,1,2,3,219].contains(i(slot,0x70)),"Finite neutral animation")
            try put(slot,0x74,i(slot,0x70),0x40de1a)
            try Self.require(f(slot,0x58) <= 0,"No opoint creation")
            for at in [0x40c,0x410,0x414,0x418] { try Self.require(i(slot,at) == 0,"No late command") }
            try Self.require(i(slot,0x78) != 200 && [0,15].contains(frame(slot,i(slot,0x78)).integer(at:8,as:Int32.self)),"No late particles")
            try put(slot,0x78,i(slot,0x70),0x4213a1)
        }
    }

    /// Input history is carried from the previous projected whole return.
    /// Ordered saved stores verify the rules on source; their values are never
    /// used as own inputs. The retained input contract supplies neutral bytes.
    mutating func input(_ writes: [Source.Write],sourceValues: Bool) throws {
        stores = [];sounds = [];draw = nil;try livePair()
        for w in writes {
            if w.pc == 0x41ef03 { break }
            let at = Int(w.address),value: Int32
            switch w.pc {
            case 0x41bcf3:
                try Self.require(at == 0x450b90 && [0,1].contains(g(at)),"Input phase")
                value = try 1 &- g(at)
            case 0x41bd06:try Self.require(at == 0x450bfc && g(0x450b90) == 0,"Input clear");value = 0
            case 0x41bd0c:try Self.require(at == 0x44fb60 && g(0x450b90) == 0,"Command clear");value = 0
            case 0x41c594,0x41c5a0,0x41c5aa,0x41c5b6,0x41c5bc:
                let addresses: [UInt32:Int] = [0x41c594:0x44d040,0x41c5a0:0x44d044,0x41c5aa:0x44d048,0x41c5b6:0x44d04c,0x41c5bc:0x44d050]
                try Self.require(at == addresses[w.pc],"Input neutral flags");value = 0x01010101
            case 0x41c5c1:try Self.require(at == 0x44d054 && w.size == 1,"Input flag terminator");value = 0
            case 0x41d6cd:try Self.require(at == 0x450b8c && g(at) < 100,"Retained round counter");value = try g(at) &+ 1
            case 0x41d71f:try Self.require(at == 0x450c00 && g(0x450bfc) == 0,"Unpaused round");value = 0
            case 0x41d7bd:try Self.require(at == 0x450bd8 && [0,1].contains(g(at)),"Round phase");value = try 1 &- g(at)
            case 0x41d7df:try Self.require(at == 0x450bd0,"HP phase");value = try (g(at) &+ 1)%12
            case 0x41d7ee:try Self.require(at == 0x450bd4,"MP phase");value = try (g(at) &+ 1)%3
            case 0x41dabc:try Self.require(at == 0x450bf8 && i(0,0x364) == 10,"First live team");value = 10
            case 0x41dacd:try Self.require(at == 0x450bf8 && i(1,0x364) == 11,"Second live team");value = 11
            case 0x41dbb3:try Self.require(at == 0x450bf8 && g(0x451160) == 0,"No winner");value = -1
            default:throw Source.error("Projection input store PC "+String(w.pc,radix:16))
            }
            if sourceValues { try Self.require(UInt64(UInt32(bitPattern:value)) == w.value,"Input source store value") }
            if w.size == 1 { try byte(at,UInt8(truncatingIfNeeded:value),w.pc) }
            else { try Self.require(w.size == 4,"Input store size");try global(at,value,w.pc) }
        }
    }

    mutating func output(_ writes: [Source.Write],sourceValues: Bool) throws {
        try Self.require(g(0x451160) == 0 && g(0x450c30) == 0 && g(0x450b84) == 0,"VS Difficult label")
        try Self.require((1..<240).contains(g(0x450b6c)) && g(0x450bfc) == 0 && g(0x450b70) == 1,"Retained recording notice")
        for at in [0x4553f2,0x4553f3] {
            try Self.require(globals.integer(at:at-0x44d000,as:UInt8.self) != 0x64,"No volume overlay key")
        }
        try Self.require(g(0x4575a0) == (writes.contains { $0.address == 0x4575a0 } ? 1 : 0),"Exact pending sound footprint")
        // Only catalog6 is pending, once on the first body. Check every flag.
        for at in stride(from:0x457588,to:0x457bc8,by:4) where at != 0x4575a0 { try Self.require(g(at) == 0,"Other catalog sound flag") }
        for n in 0..<80 { try Self.require(g(0x453e10+4*n) == 0,"Other builtin sound flag") }
        try Self.require(g(0x44eecc) != 0 && g(0x44d000) == 100,"Enabled sound/master")
        let mode = Array("VS mode ".utf8)+[0],suffix = Array("(Difficult)".utf8)+[0]
        for w in writes {
            let at = Int(w.address),value: UInt32
            if (0x450c38...0x450c4b).contains(at) {
                let bytes: [UInt8],offset: Int
                if at < 0x450c40 || (at == 0x450c40 && w.size == 1) { bytes = mode;offset = at-0x450c38 }
                else { bytes = suffix;offset = at-0x450c40 }
                try Self.require(offset >= 0 && offset+w.size <= bytes.count && [1,4].contains(w.size),"Label store extent")
                value = (0..<w.size).reduce(UInt32(0)) { $0 | UInt32(bytes[offset+$1]) << ($1*8) }
            } else if at == 0x450b6c {
                value = UInt32(bitPattern:try g(at) &+ 1)
            } else if at == 0x4575a0 {
                try Self.require(g(at) == 1,"Pending sound clear");value = 0
            } else if at == 0x457580 { value = 0 }
            else { throw Source.error("Projection output store address "+String(at,radix:16)) }
            if sourceValues { try Self.require(UInt64(value) == w.value,"Output source store value") }
            if w.size == 1 { try byte(at,UInt8(truncatingIfNeeded:value),w.pc) }
            else { try Self.require(w.size == 4,"Output word size");try global(at,Int32(bitPattern:value),w.pc) }
        }
    }

    mutating func advance(_ section: Source.Section,sourceValues: Bool) throws {
        stores = [];sounds = [];draw = nil;try livePair()
        switch section.stage {
        case .control:
            for slot in 0..<2 {
                try Self.require(i(slot,4) == 0,"No run tap timer")
                for at in [0x14,0x18,0x1c] { try Self.require(f(slot,at) == 0,"No Frame velocity") }
                for at in 0xbe...0xdc { try Self.require(b(slot,at) == 0,"Neutral control history") }
            }
        case .links,.attachments:
            for slot in 0..<2 {
                let z = try d(slot,0x68)
                try Self.require(z >= 450 && z <= 525,"Unclamped links depth")
                try put(slot,0x18,Int32(z.rounded(.towardZero)),0x41800b)
            }
        case .cpointActions,.cpointPlacement,.cpointCleanup:
            for slot in 0..<2 {
                try Self.require(frame(slot,i(slot,0x7c)).integer(at:0x88,as:Int32.self) == 0,"No collision cpoint")
            }
        case .physics:try physics()
        case .contacts:try contacts()
        case .hits:try hits()
        case .camera:try camera()
        case .impulses:try impulses()
        case .lifecycle:try lifecycle()
        case .hud:try global(0x450bc0,0,0x421a1c);try global(0x450bb8,0,0x421a22)
        case .recording:
            try Self.require(g(0x450bdc) == 0,"Neutral recording")
            try global(0x450bbc,g(0x450bbc) &+ 1,0x421ce6)
        case .output:try output(section.writes,sourceValues:sourceValues)
        case .commands:
            try Self.require(g(0x450bc0) == 0 && g(0x451160) == 0,"No recovery command")
            let command = try g(0x450bb8)
            try Self.require(command == 0 || (command == 3 && installedRequestedID == 0),"No requested spawn")
            for slot in 0..<2 {
                try Self.require(i(slot,0xe0) == 0 && i(slot,0xe4) == 0,"No healing timer")
                for (at,pc): (Int,UInt32) in [(0x2e8,0x4219dd),(0x2ec,0x4219e3),(0x2f0,0x4219e9)] { try put(slot,at,1000,pc) }
                try put(slot,0x2e4,0,0x4219ef)
                let at = try actor(slot)+0xeb;try pool.write(UInt8(0),at:at)
                stores.append(.init(pc:0x4219f5,region:"pool",offset:at,bytes:[0]))
            }
        case .notices:
            for at in [0x450bec,0x450c2c,0x450c28] { try Self.require(g(at) == 0,"No diagnostic notice") }
        case .layout:try Self.require(g(0x450bdc) == 0 && g(0x450b84) == 0,"No result layout/indicator")
        case .drawing:break // Graphics output is outside this scalar checkpoint.
        }
        if sourceValues {
            for store in stores { try Self.require(section.pcs.contains(store.pc),"Unobserved source store PC "+String(store.pc,radix:16)) }
        }
    }
}
