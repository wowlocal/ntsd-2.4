import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Independent expected command expansion. Reads only the retained input
/// records; never calls Core drawing/clipping or consumes a Native event as input.
struct OriginalApplicationGameplayDrawingProjection {
    typealias P = OriginalApplicationGameplayStateProjection
    typealias S = OriginalApplicationGameplaySource
    typealias E = OriginalFrontScreenEvent
    struct Bitmap { let record: OriginalStateRecord,surface: UInt32 }
    let catalog: [UInt32:Bitmap],resources: [UInt32:Bitmap],catalogTokens: [UInt32:UInt32]
    var events: [E] = []

    init(_ state: OriginalMatchPreparation,_ memory: OriginalApplicationMenuSession.State) throws {
        var c: [UInt32:Bitmap] = [:],r: [UInt32:Bitmap] = [:]
        for n in state.bitmaps.indices {
            try P.require(!state.releasedBitmaps.contains(n),"Retained drawing bitmap")
            let surface = try XCTUnwrap(state.bitmapSurfaceOwners[n]),wrapper = try XCTUnwrap(state.bitmapOwners[n])
            let b = Bitmap(record:state.bitmaps[n].storage,surface:surface)
            c[UInt32(n+1)] = b;r[wrapper] = b
        }
        for (token,a) in memory.memory.allocations where a.live && a.storage.bytes.count == 0x1f50 {
            var record = a.storage
            let surface = try record.integer(at:0,as:UInt32.self)
            try record.write(UInt32(surface == 0 ? 0 : 1),at:0)
            // The model may also retain this wrapper's catalog view. The
            // current allocator view owns resource reads; verify the alias.
            if let old = r[token] {
                try P.require(old.surface == surface,"Bitmap alias surface \(token)")
                try P.same(old.record,record,"Bitmap alias record \(token)")
            }
            r[token] = .init(record:record,surface:surface)
        }
        for b in Array(c.values)+Array(r.values) {
            try P.require(b.surface == 0 || memory.graphics?.currentResources[b.surface]?.kind == "bitmapSurface","Drawing surface owner")
        }
        catalog = c;resources = r;catalogTokens = Dictionary(uniqueKeysWithValues:c.keys.map { ($0,$0) })
    }
    init(_ state: MatchLaunchReference.State,_ source: S) throws {
        var c: [UInt32:Bitmap] = [:],r: [UInt32:Bitmap] = [:],tokens: [UInt32:UInt32] = [:]
        func bitmap(_ storage: MatchLaunchReference.Storage) throws -> Bitmap {
            var record = try source.record(storage)
            let surface = try record.integer(at:0,as:UInt32.self)
            try record.write(UInt32(surface == 0 ? 0 : 1),at:0)
            return .init(record:record,surface:surface)
        }
        for (n,a) in state.bitmaps.enumerated() {
            let token = UInt32(n+1),b = try bitmap(a.storage)
            c[token] = b;r[token] = b;r[a.address] = b;tokens[a.address] = token
        }
        for a in state.early.records where a.live {
            if try source.bytes(a.storage.bytes).count == 0x1f50 { r[a.address] = try bitmap(a.storage) }
        }
        for a in state.menuBitmaps ?? [] { r[a.address] = try bitmap(a.storage) }
        catalog = c;resources = r;catalogTokens = tokens
    }
    func token(_ value: UInt32) throws -> UInt32 { try XCTUnwrap(catalogTokens[value]) }
    func resourceToken(_ value: UInt32) -> UInt32 { catalogTokens[value] ?? value }
    func resolve(_ token: UInt32,_ isCatalog: Bool) throws -> Bitmap {
        try XCTUnwrap((isCatalog ? catalog : resources)[token],"Drawing bitmap \(token),catalog=\(isCatalog)")
    }
    static func compare(_ actual: [E],_ expected: [E],_ label: String) throws {
        try P.require(actual.count == expected.count,"\(label) event count \(actual.count)/\(expected.count)")
        if let n = actual.indices.first(where:{ actual[$0] != expected[$0] }) {
            throw S.error("\(label) event \(n): \(actual[n]) versus \(expected[n])")
        }
    }
    mutating func read(_ b: Bitmap,_ offset: UInt32) throws -> Int32 {
        let n = Int(offset)
        try P.require(b.record.bytes.count == 0x1f50 && n <= 0x1f50-4,"Drawing read extent")
        var value = (0..<4).reduce(UInt32(0)) { $0 | UInt32(b.record.bytes[n+$1]) << (8*$1) }
        if n == 0 {
            try P.require(value == (b.surface == 0 ? 0 : 1),"Drawing surface presence")
            value = b.surface
        }
        var e = E("read");e.read = .init(offset:n,value:value,defined:b.record.defined[n..<n+4].allSatisfy { $0 })
        events.append(e);return Int32(bitPattern:value)
    }
    mutating func blit(_ b: Bitmap,_ target: UInt32,_ src: [Int32],_ dst: [Int32],_ key: UInt32) throws {
        _ = try read(b,0);try P.require(target != 0,"Drawing target")
        var e = E("blit");e.blit = .init(sourceSurface:b.surface,targetSurface:target,source:src,destination:dst,
            flags:0x1000000 | (key == 0 ? 0 : 0x8000),effects:nil);events.append(e)
    }
    mutating func clipped(_ b: Bitmap,_ target: UInt32,_ originalSource: [Int32],_ originalDestination: [Int32],_ key: UInt32) throws {
        var src = originalSource,dst = originalDestination
        let visible = !((dst[0] < 0 && dst[2] < 0) || (dst[0] > 794 && dst[2] > 794) ||
            (dst[1] < 0 && dst[3] < 0) || (dst[1] > 550 && dst[3] > 550))
        if visible {
            for axis in 0..<2 {
                if dst[axis] < 0 { src[axis] = src[axis] &- dst[axis];dst[axis] = 0 }
                let end = axis+2,limit: Int32 = axis == 0 ? 794 : 550
                if dst[end] > limit { src[end] = src[end] &+ (limit &- dst[end]);dst[end] = limit }
            }
        }
        var e = E("clip");e.clip = .init(beforeSource:originalSource,beforeDestination:originalDestination,source:src,destination:dst,visible:visible)
        events.append(e)
        if visible { try blit(b,target,src,dst,key) }
    }
    mutating func picture(_ token: UInt32,_ isCatalog: Bool,_ x: Int32,_ y: Int32,_ picture: Int32,_ key: UInt32,_ target: UInt32) throws {
        events.append(.init("draw",[token,UInt32(bitPattern:x),UInt32(bitPattern:y),UInt32(bitPattern:picture),key,0,target]))
        let b = try resolve(token,isCatalog),count = try read(b,0xc)
        if count == 0 || picture < 0 {
            let width = try read(b,4),height = try read(b,8)
            try clipped(b,target,[0,0,width,height],[x,y,x &+ width,y &+ height],key)
        }
        if try picture < read(b,0xc) {
            let offset = UInt32(bitPattern:picture) &* 4
            let sx = try read(b,offset &+ 0x10),width = try read(b,offset &+ 0xfb0)
            let sy = try read(b,offset &+ 0x7e0),height = try read(b,offset &+ 0x1780)
            try clipped(b,target,[sx,sy,sx &+ width,sy &+ height],[x,y,x &+ width,y &+ height],key)
        }
    }
    mutating func rectangle(_ token: UInt32,_ width: Int32,_ row: Int32,_ x: Int32,_ y: Int32,_ target: UInt32) throws {
        events.append(.init("rectangle",[token,0,UInt32(bitPattern:row),UInt32(bitPattern:width),10,UInt32(bitPattern:x),UInt32(bitPattern:y),target]))
        try blit(resolve(token,false),target,[0,row,width,row &+ 10],[x,y,x &+ width,y &+ 10],0)
    }
    func viewport(_ p: P) throws {
        try p.livePair();try P.require(p.g(0x44d78c) == 794 && p.g(0x44d790) == 550,"Drawing viewport")
    }
    mutating func camera(_ before: P,_ after: P,_ target: UInt32) throws {
        try viewport(before)
        let bg = before.backgrounds[0],next = after.backgrounds[0],camera = try after.g(0x450bc4)
        try P.require(bg.integer(at:0,as:Int32.self) == 960 && bg.integer(at:0x1c,as:Int32.self) == 15,"District drawing")
        for layer in 0..<15 {
            func v(_ at: Int) throws -> Int32 { try bg.integer(at:at+4*layer,as:Int32.self) }
            try P.require(v(0x89c) == 0 && v(0x644) == 0,"Finite non-fill non-loop background")
            let period = try v(0x7ac)
            if period > 0 {
                let counter = try next.integer(at:0x824+4*layer,as:Int32.self)
                if try counter < v(0x6bc) || counter > v(0x734) { continue }
            }
            let shift = try 0 &- (((v(0x464) &- 794) &* camera)/166)
            let bitmap = try token(bg.integer(at:0x914+4*layer,as:UInt32.self))
            try picture(bitmap,true,v(0x4dc) &+ shift,v(0x554),-1,UInt32(bitPattern:v(0x3ec)),target)
        }
    }
    mutating func world(_ p: P,_ target: UInt32) throws {
        try viewport(p)
        let camera = try p.g(0x450bc4),bg = p.backgrounds[0]
        let order = try [0,1].sorted { a,b in try p.i(a,0x18) == p.i(b,0x18) ? a < b : p.i(a,0x18) < p.i(b,0x18) }
        for slot in order {
            let x = try p.i(slot,0x10) &- camera,z = try p.i(slot,0x18),blink = try p.i(slot,8)
            try P.require(p.i(slot,0x1c) == 0 && p.i(slot,0x30c) == 0 && p.i(slot,0x36c) == 0,"No extra drawing effects/lives")
            try P.require(p.b(slot,0x80) == 0 && p.i(slot,0x318) == 0 && blink > 0,"Ordinary facing/blink")
            if blink%4 < 2 {
                let shadow = try token(bg.integer(at:0x98c,as:UInt32.self))
                try picture(shadow,true,x &- bg.integer(at:0x14,as:Int32.self)/2,z &- bg.integer(at:0x18,as:Int32.self)/2,-1,1,target)
                let frame = try p.frame(slot),header = try p.object(slot).header
                try P.require(frame.integer(at:0,as:UInt8.self) != 0,"Drawable Frame")
                let number = try frame.integer(at:4,as:Int32.self),count = try header.integer(at:0x498,as:Int32.self)
                try P.require(count >= 0 && count <= 30,"Sheet count")
                var selected = false
                for n in 0..<Int(count) {
                    let first = try header.integer(at:0x62c+4*n,as:Int32.self)
                    let columns = try header.integer(at:0x6a4+4*n,as:Int32.self),rows = try header.integer(at:0x6cc+4*n,as:Int32.self)
                    if number >= first && number < first &+ (rows &* columns) {
                        let bitmap = try header.integer(at:0x754+4*n,as:UInt32.self)
                        try picture(bitmap,true,x &- p.f(slot,0x50),z &- p.f(slot,0x54),number &- first,1,target)
                        selected = true;break
                    }
                }
                try P.require(selected && p.i(slot,0x2fc) >= p.i(slot,0x304)/3,"Ordinary sprite/no low-HP marker")
            }
            var label: [UInt8] = []
            for n in 0..<11 {
                let b = try p.globals.integer(at:0x44fcc0-0x44d000+11*slot+n,as:UInt8.self)
                if b == 0 { break };label.append(b)
            }
            try P.require(label == [UInt8(slot+49)] && p.g(0x450b4c+4*slot) != -1 && p.i(slot,0x364) == Int32(slot+10),"Finite human name/team")
            let width = Int32(label.count*9),left = min(max(x-width/2,0),794-width)
            for (n,b) in label.enumerated() {
                try picture(resourceToken(UInt32(bitPattern:p.g(0x44faf4))),false,left+Int32(9*n),z+3,Int32(Int8(bitPattern:b)),1,UInt32(bitPattern:p.g(0x455608)))
            }
        }
    }
    mutating func hud(_ p: P) throws {
        try viewport(p)
        let target = UInt32(bitPattern:try p.g(0x455608)),font = resourceToken(UInt32(bitPattern:try p.g(0x44faf4)))
        for cell in 0..<8 {
            let x = Int32(cell%4)*198,y = Int32(cell/4)*54
            try picture(resourceToken(UInt32(bitPattern:p.g(0x4511a8))),false,x,y,-1,0,target)
            if cell >= 2 { continue } // livePair guards all400 activity bytes.
            try picture(UInt32(bitPattern:p.h(cell,0x728)),true,x+9,y+7,-1,0,target)
            let bar = resourceToken(UInt32(bitPattern:try p.g(0x44fd7c)))
            try P.require(p.i(cell,0xe0) == 0 && p.i(cell,0xe4) == 0,"No HUD healing flash")
            for (value,row) in [(try p.i(cell,0x300),Int32(30)),(try p.i(cell,0x2fc),Int32(20))] {
                try rectangle(bar,(value &* 31)/125,row,x+57,y+16,target)
            }
            try rectangle(bar,124,10,x+57,y+36,target)
            try rectangle(bar,(p.i(cell,0x308) &* 31)/125,0,x+57,y+36,target)
            try P.require(p.i(cell,0x364) == Int32(cell+10),"Neutral HUD font team")
            try picture(font,false,x+5,y,254,1,target)
        }
    }
}
