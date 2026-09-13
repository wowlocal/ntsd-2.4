import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Independent comparison value for the finite active fighter physics path.
/// It uses record utilities, never OriginalActorPhysics/OriginalWorldPhysics.
struct OriginalApplicationActivePhysicsProjection {
    typealias S = OriginalApplicationActiveBodyControl
    typealias P = S.P
    var state: S
    var points: [S.Point] = []
    init(_ own: OriginalMatchPreparation) throws { state = try S(own) }
    init(_ source: S) { state = source }
    mutating func advance() throws {
        try P.require(state.pool.bytes.count == 0x7d8+400*0x420 && state.globals.bytes.count == 0xb440,"Physics complete records")
        try P.require(state.actorTokens.count == 400 && Set(state.actorTokens).count == 400,"Physics distinct finite actors")
        for slot in 0..<400 {
            try P.require(state.pool.integer(at:4+slot,as:UInt8.self) == (slot < 2 ? 1 : 0),"Physics finite activity")
            try P.require(state.pool.integer(at:0x194+4*slot,as:UInt32.self) == state.actorTokens[slot],"Physics finite live identity")
        }
        for slot in 0..<2 {
            let at = 0x7d8+slot*0x420,record = try S.slice(state.pool,at,0x420)
            let object = try XCTUnwrap(state.objects[record.integer(at:0x368,as:UInt32.self)])
            try P.require(object.integer(at:0x6f8,as:Int32.self) == 0 && object.integer(at:0x6f4,as:Int32.self) == (slot == 0 ? 2 : 11),"Physics finite original fighters")
            var actor = S.Actor(value:record,object:object,globals:state.globals,slot:slot)
            try actor.activePhysics()
            points.append(.init(slot:slot,label:"physics-return",actor:actor.value))
            // Reread the final Frame for caller deactivation/death predicates.
            // These schedules retain living fighter states and no reversion ID;
            // constructor/respawn effects are not imported from a source case.
            try P.require([0,1,3,4,7].contains(actor.state()) && actor.w(0x324) == -1,"Physics caller requires no death/deactivation/reversion")
            var bytes = state.pool.bytes,mask = state.pool.defined
            bytes.replaceSubrange(at..<at+0x420,with:actor.value.bytes)
            mask.replaceSubrange(at..<at+0x420,with:actor.value.defined)
            state.pool = try .init(bytes:bytes,defined:mask)
        }
    }
}

extension OriginalApplicationActiveBodyControl.Actor {
    typealias P = OriginalApplicationGameplayStateProjection
    mutating func activePhysics() throws {
        try P.require(w(0xb4) == 0 && w(0x98) == 0 && frame().integer(at:0x88,as:Int32.self) == 0,"Finite physics early-return predicates")
        try P.require([0,1,3,4,7].contains(state()),"Finite physics Frame states")
        let vx = try d(0x40),vz = try d(0x50)
        if !(try (vx > 0 && w(0x3f4) == 1) || (vx < 0 && w(0x3f0) == 1)) { try number(0x58,d(0x58)+vx) }
        if !(try (vz > 0 && w(0x3ec) == 1) || (vz < 0 && w(0x3e8) == 1)) { try number(0x68,d(0x68)+vz) }
        for at in [0x3ec,0x3e8,0x3f0,0x3f4] { try put(at,0) }
        if try w(0x14) >= 0 {
            for at in [0x40,0x50] {
                if try d(at) > 0.0001 {
                    let next = try d(at)-1;try number(at,next)
                    if next < 0.0001 { try number(at,0) }
                }
                if try d(at) < -0.0001 {
                    let next = try d(at)+1;try number(at,next)
                    // Original compares this negative-side result with +epsilon.
                    if next > 0.0001 { try number(at,0) }
                }
            }
        }
        let y = try d(0x60)+d(0x48);try number(0x60,y)
        if y < -0.0001 { try number(0x48,d(0x48)+1.7) }
        else {
            // Neither source48 nor the declared own path has a landing here.
            // A new landing requires its complete damage/frame/sound contract.
            try P.require(!(d(0x60) > 0.0001 && d(0x48) > 0.0001) && !(d(0x60) > 0 && d(0x48) == 0 && w(0x70) == 212),"Physics landing requires extended comparison")
        }
        for (from,to) in [(0x58,0x10),(0x60,0x14),(0x68,0x18)] {
            let value = try d(from)
            // Within this guarded normal domain both declared conversion paths
            // truncate identically, far from Int32 and exponent boundaries.
            try put(to,Int32(value.rounded(.towardZero)))
        }
        try put(0x320,0)
    }
}
