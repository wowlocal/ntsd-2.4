import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Comparison-only specification for the current finite active control path.
/// Source-first checkpoints validate it before own application comparison.
struct OriginalApplicationActiveBodyControl {
    typealias P = OriginalApplicationGameplayStateProjection
    struct Draw: Equatable { let slot: Int,stream: Int32,range: Int32,result: Int32 }
    struct Point { let slot: Int,label: String,actor: OriginalStateRecord }
    var pool: OriginalStateRecord,globals: OriginalStateRecord
    let objects: [UInt32:OriginalStateRecord],actorTokens: [UInt32]
    var draws: [Draw] = [],points: [Point] = []
    static func slice(_ r: OriginalStateRecord,_ at: Int,_ count: Int) throws -> OriginalStateRecord {
        try P.require(at >= 0 && count >= 0 && at <= r.bytes.count-count,"Active projection slice")
        return try .init(bytes:Array(r.bytes[at..<at+count]),defined:Array(r.defined[at..<at+count]))
    }
    init(_ own: OriginalMatchPreparation) throws {
        let p = try P(own);pool = p.pool;globals = p.globals;actorTokens = (0..<400).map(UInt32.init)
        objects = try Dictionary(uniqueKeysWithValues:own.loadedObjects.enumerated().map { index,o in
            let records = [o.header]+o.frameStorage+[o.nameTail]
            return (UInt32(index),try OriginalStateRecord(bytes:records.flatMap(\.bytes),defined:records.flatMap(\.defined)))
        })
    }
    init(pool: OriginalStateRecord,globals: OriginalStateRecord,objects: [UInt32:OriginalStateRecord],actorTokens: [UInt32]) {
        self.pool = pool;self.globals = globals;self.objects = objects;self.actorTokens = actorTokens
    }
    mutating func advance() throws {
        try P.require(pool.bytes.count == 0x7d8+400*0x420 && globals.bytes.count == 0xb440,"Control whole record extents")
        try P.require(actorTokens.count == 400 && Set(actorTokens).count == 400,"Control distinct finite actors")
        for slot in 0..<400 {
            try P.require(pool.integer(at:4+slot,as:UInt8.self) == (slot < 2 ? 1 : 0),"Control finite activity")
            try P.require(pool.integer(at:0x194+4*slot,as:UInt32.self) == actorTokens[slot],"Control live slot identity")
        }
        for slot in 0..<2 {
            let at = 0x7d8+slot*0x420,record = try Self.slice(pool,at,0x420)
            let object = try XCTUnwrap(objects[record.integer(at:0x368,as:UInt32.self)])
            try P.require(object.integer(at:0x6f8,as:Int32.self) == 0 && object.integer(at:0x6f4,as:Int32.self) == (slot == 0 ? 2 : 11),"Control original type/ID")
            var actor = Actor(value:record,object:object,globals:globals,slot:slot)
            try actor.edges();points.append(.init(slot:slot,label:"buffers",actor:actor.value))
            try actor.combos();points.append(.init(slot:slot,label:"combos",actor:actor.value))
            try actor.frameInput();points.append(.init(slot:slot,label:"frame-input",actor:actor.value))
            try actor.movement();points.append(.init(slot:slot,label:"movement",actor:actor.value))
            try actor.velocity();points.append(.init(slot:slot,label:"control-return",actor:actor.value))
            var bytes = pool.bytes,mask = pool.defined
            bytes.replaceSubrange(at..<at+0x420,with:actor.value.bytes);mask.replaceSubrange(at..<at+0x420,with:actor.value.defined)
            pool = try .init(bytes:bytes,defined:mask)
            globals = actor.globals;draws += actor.draws
        }
    }
    struct Actor {
        var value: OriginalStateRecord
        let object: OriginalStateRecord
        var globals: OriginalStateRecord
        let slot: Int
        var draws: [Draw] = []
        func w(_ at: Int) throws -> Int32 { try value.integer(at:at,as:Int32.self) }
        func b(_ at: Int) throws -> UInt8 { try value.integer(at:at,as:UInt8.self) }
        func s(_ at: Int) throws -> Int8 { try value.integer(at:at,as:Int8.self) }
        static func finite(_ n: Double) throws -> Double {
            // This finite comparison uses host53-bit arithmetic only far from
            // exponent boundaries. CONTROL_PRECISION retains the general
            // extended-exponent/subnormal contract in Core and its own tests.
            try P.require(n.isFinite && abs(n) < 10_000 && (n == 0 || abs(n) >= 1e-100),"Finite normal53-bit active control arithmetic")
            return n
        }
        func d(_ at: Int) throws -> Double { try Self.finite(value.binary64(at:at)) }
        func h(_ at: Int) throws -> Double { try Self.finite(object.binary64(at:at)) }
        func frame() throws -> OriginalStateRecord {
            let n = try w(0x70);try P.require((0..<400).contains(n),"Control current Frame")
            return try OriginalApplicationActiveBodyControl.slice(object,0x7a4+Int(n)*0x178,0x178)
        }
        func state() throws -> Int32 { try frame().integer(at:8,as:Int32.self) }
        mutating func put(_ at: Int,_ n: Int32) throws { try value.write(n,at:at) }
        mutating func byte(_ at: Int,_ n: UInt8) throws { try value.write(n,at:at) }
        mutating func number(_ at: Int,_ n: Double) throws {
            try value.writeBinary64(Self.finite(n),at:at)
        }
        mutating func edges() throws {
            for at in [0xc2,0xc3,0xc4,0xc5,0xbf,0xbe,0xc0,0xc1] {
                if try s(at) > 0 { try byte(at,b(at)-1) }
            }
            for (previous,current,buffer,code): (Int,Int,Int,Int32) in [
                (0xc9,0xd0,0xc2,6),(0xc8,0xcf,0xc3,4),(0xc6,0xcd,0xc4,8),(0xc7,0xce,0xc5,2),
                (0xcc,0xd3,0xc0,9),(0xcb,0xd2,0xbf,0),(0xca,0xd1,0xbe,5)] {
                if try b(previous) == 0 && b(current) == 1 {
                    try byte(buffer,5)
                    for at in [0x408,0x40c,0x410,0x414] { try put(at,w(at+4)) }
                    try put(0x418,code)
                }
            }
        }
        mutating func combos() throws {
            let buffers = [0xbe,0xbf,0xc0,0xc3,0xc4,0xc5,0xc2]
            let routes = [(0xc2,0xbe),(0xc3,0xbe),(0xc4,0xbe),(0xc5,0xbe),(0xc2,0xbf),(0xc3,0xbf),(0xc4,0xbf),(0xc5,0xbf),(0xbf,0xbe)]
            for (route,buttons) in routes.enumerated() {
                let at = 0xd4+route;var advanced = false
                if try b(at) == 0 && b(0xc0) == 5 { try byte(at,1);advanced = true }
                for (progress,accepted,next): (UInt8,Int,Int) in [(1,0xc0,buttons.0),(2,buttons.0,buttons.1)] {
                    if try b(at) != progress { continue }
                    if try b(next) == 5 { try byte(at,progress+1);advanced = true }
                    else if try buffers.contains(where:{ if advanced && $0 == accepted { return false };return try b($0) == 5 }) { try byte(at,0) }
                }
                try P.require(b(at) != 3,"Active control requires combo-transfer projection")
            }
        }
        mutating func frameInput() throws {
            for (field,buffer,others) in [(0x24,0xbe,[0xc0,0xbf]),(0x28,0xc0,[0xbe,0xbf]),(0x2c,0xbf,[0xbe,0xc0])] {
                if try frame().integer(at:field,as:Int32.self) != 0 {
                    try P.require(!others.allSatisfy { try s(buffer) > s($0) },"Active control requires Frame-transfer projection")
                }
            }
        }
        mutating func walk() throws {
            let rate = try object.integer(at:0,as:Int32.self)
            try P.require(rate > 0 && rate < 1000 && w(0) >= 0 && w(0) < 100_000,"Finite walking phase division")
            let phase = try (w(0) &+ 1)%(rate*6),step = phase/rate
            try put(0,phase);try put(0x70,phase < rate*4 ? step+5 : 11-step)
        }
        mutating func random() throws -> Int32 {
            let c = try globals.integer(at:0x450c34-0x44d000,as:Int32.self),i = try globals.integer(at:0x450bcc-0x44d000,as:Int32.self)
            try P.require((0..<1234).contains(c) && (0..<3000).contains(i),"Own active RNG range")
            let counter = (c+1)%1234,index = (i+1)%3000
            try globals.write(counter,at:0x450c34-0x44d000);try globals.write(index,at:0x450bcc-0x44d000)
            let n = try globals.integer(at:0x44ff90-0x44d000+Int(index),as:UInt8.self),result = (Int32(n)+counter)%2
            draws.append(.init(slot:slot,stream:130,range:2,result:result));return result
        }
        mutating func movement() throws {
            try P.require(w(0x98) == 0 && w(0xb4) == 0 && [0,1,3,4,7].contains(state()),"Active type0 control states")
            let keys = try (0xcd...0xd3).map(b)
            try P.require(keys.allSatisfy { $0 < 2 },"Finite boolean live buttons")
            let up = keys[0],down = keys[1],left = keys[2],right = keys[3],attack = keys[4],jump = keys[5],defend = keys[6]
            let grounded = try w(0x14) == 0
            if try w(0x70) == 110 {
                if right == 1 { try byte(0x80,0) };if left == 1 { try byte(0x80,1) }
            }
            if try [0,1].contains(state()) {
                if try w(4) > 0 { try put(4,w(4)-1) }
                if try w(4) < 0 { try put(4,w(4)+1) }
                for (direction,pushed,other,previous): (UInt8,UInt8,UInt8,Int) in [(0,right,left,0xc9),(1,left,right,0xc8)] {
                    if pushed == 1 && other == 0 && grounded {
                        if try b(0x80) != direction { try put(4,0) }
                        try byte(0x80,direction);try walk();try number(0x40,h(8)*Double(1-2*Int(direction)))
                        if try b(previous) == 0 { try put(4,w(4) &+ (direction == 0 ? 10 : -10)) }
                        try P.require(direction == 0 ? w(4) < 11 : w(4) > -11,"Active control requires run-entry projection")
                    }
                }
                if up != down && grounded {
                    if left == right { try walk() }
                    try number(0x50,h(0x10)*(up == 1 ? -1 : 1));try number(0x40,d(0x40)/1.4)
                }
                if try attack == 1 && s(0xbe) > 0 {
                    try put(4,0);try put(0x88,0);try P.require(s(0xea) <= 0,"No strong-attack request")
                    let selected = try (random()+12)*5;try put(0x70,selected)
                    if try globals.integer(at:0x44d034-0x44d000,as:Int32.self) != 0 {
                        let cost = try frame().integer(at:0x4c,as:Int32.self),after = try w(0x308) &- cost
                        if after < 0 { try put(0x308,0) }
                        else { try put(0x308,after);try put(0x350,w(0x350) &+ cost) }
                    }
                }
                if try jump == 1 && s(0xbf) > 0 { try put(0x88,0);try put(4,0);try put(0x70,210) }
                if try defend == 1 && b(0xc1) == 0 && s(0xc0) > 0 { try put(4,0);try put(0x88,0);try put(0x70,110) }
            }
            if try state() == 4 && w(0x14) < 0 {
                if right == 1 && left == 0 { try byte(0x80,0) };if left == 1 && right == 0 { try byte(0x80,1) }
                try P.require(attack == 0,"Active control requires airborne attack projection")
            }
            // Reread the independently selected live Frame after earlier blocks.
            // This finite routing guard excludes both installed85/86 helpers;
            // final Native rows alone would not establish that predicate.
            try P.require([0,1,3,4,7].contains(state()) && ![215,182,188].contains(w(0x70)),"Finite pre-hook control state")
        }
        mutating func velocity() throws {
            let f = try frame(),x = try f.integer(at:0x14,as:Int32.self),y = try f.integer(at:0x18,as:Int32.self),z = try f.integer(at:0x1c,as:Int32.self)
            if x > 500 { try number(0x40,Double(x &- 550)) }
            else if x != 0 {
                let facing = try b(0x80);try P.require(facing < 2,"Finite control facing")
                let sign = Double(1-2*Int(facing)),speed = try d(0x40)*sign
                if (x > 0 && Double(x) > speed) || (x < 0 && Double(x) < speed) { try number(0x40,Double(x)*sign) }
            }
            if y > 500 { try number(0x48,Double(y &- 550)) }
            else if y != 0 { try number(0x48,Double(y)+d(0x48)) }
            if z > 500 { try number(0x50,Double(z &- 550)) }
            else if z != 0 {
                if try b(0xcd) == 1 && s(0xc4) >= s(0xc5) { try number(0x50,-Double(z)) }
                if try b(0xce) == 1 && s(0xc4) <= s(0xc5) { try number(0x50,Double(z)) }
            }
        }
    }
}
