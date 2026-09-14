import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Observation-only Native diagnostic. These records never become game inputs
/// or original expected values; the old finite behavioral projections stay intact.
enum OriginalApplicationFirstDamageDiagnostic {
    typealias C = OriginalApplicationLoadedCycleTests
    typealias I = OriginalApplicationActiveGameplayInput
    enum Failure: Error { case provider(String), route(String), diagnostic(String), injected }
    static func require(_ value: Bool,_ message: String) throws {
        if !value { throw Failure.diagnostic(message) }
    }
    static func observe<T>(_ context: String,_ body: () throws -> T) throws -> T {
        do { return try body() }
        catch { throw Failure.diagnostic("\(context): \(error)") }
    }
    static func coherent(_ b: OriginalApplicationMatchBindings,_ m: OriginalMatchPreparation,_ state: OriginalApplicationMenuSession.State) throws {
        try observe("Current ownership coherence") {
            func slice(_ at: Int,_ count: Int) throws -> OriginalStateRecord {
                try require(at>=0 && count>=0 && at+count<=state.full.bytes.count,"Full state slice extent")
                return try .init(bytes:Array(state.full.bytes[at..<at+count]),defined:Array(state.full.defined[at..<at+count]))
            }
            try require(slice(0,OriginalMatchPreparation.globalSize)==m.globals,"Current globals")
            try require(state.full.integer(at:0xbb00+0x7d4,as:UInt32.self)==b.catalogToken,"Catalog identity")
            var world = try slice(0xbb00,0x7d8);try world.write(UInt32(0),at:0x7d4)
            try require(m.actors.count==400 && b.actorTokens.count==400,"Actor owner extent")
            for seat in 0..<400 {
                let ordinal = try m.world.integer(at:0x194+4*seat,as:UInt32.self)
                try require(b.actorTokens.indices.contains(Int(ordinal)),"World ordinal")
                try require(state.full.integer(at:0xbb00+0x194+4*seat,as:UInt32.self)==b.actorTokens[Int(ordinal)],"World Actor identity")
                try world.write(ordinal,at:0x194+4*seat)
            }
            try require(world==m.world,"Current World")
            for i in 0..<400 {
                guard var r = state.memory.allocations[b.actorTokens[i]] else { throw Failure.diagnostic("Missing Actor owner") }
                try require(r.live,"Live Actor owner")
                let object = try m.actors[i].integer(at:0x368,as:UInt32.self)
                try require(b.objectTokens.indices.contains(Int(object)),"Actor Object ordinal")
                try require(r.storage.integer(at:0x368,as:UInt32.self)==b.objectTokens[Int(object)],"Actor Object identity")
                try r.storage.write(object,at:0x368);try require(r.storage==m.actors[i],"Complete Actor storage")
            }
            try require(slice(0xb8a8,8)==state.memory.replayPointers,"Replay pointer coherence")
        }
    }
    struct Contact: Equatable {
        let target: Int32,itr: Int8,frame: Int32,kind: Int32
        var json: [String:Any] { ["targetActor":target,"itrIndex":itr,"collisionFrame":frame,"kind":kind] }
    }
    static func contacts(_ m: OriginalMatchPreparation,_ seat: Int) throws -> [Contact] {
        let a = m.actors[try actor(m,seat)],count = try a.integer(at:0x2e4,as:Int32.self)
        if count<=0 { return [] }
        try require(Int(count)<=min((a.bytes.count-0x280)/4,a.bytes.count-0x2d0),"Contact observation extent")
        let object = try a.integer(at:0x368,as:UInt32.self),frame = try a.integer(at:0x7c,as:Int32.self)
        try require(m.loadedObjects.indices.contains(Int(object)),"Contact Object")
        let frames = m.loadedObjects[Int(object)].frameStorage
        try require(frames.indices.contains(Int(frame)),"Contact collision Frame")
        let pointer = try frames[Int(frame)].integer(at:0x130,as:UInt32.self)
        return try (0..<Int(count)).map { n in
            let target = try a.integer(at:0x280+n*4,as:Int32.self),itr = try a.integer(at:0x2d0+n,as:Int8.self)
            let address = pointer &+ UInt32(bitPattern:Int32(itr) &* 80)
            guard let heap = m.frameAllocations.first(where:{ UInt64(address)>=UInt64($0.address) && UInt64(address)+4<=UInt64($0.address)+UInt64($0.storage.bytes.count) }) else {
                throw Failure.diagnostic("Contact ITR observation allocation")
            }
            let kind = try heap.storage.integer(at:Int(address-heap.address),as:Int32.self)
            return Contact(target:target,itr:itr,frame:frame,kind:kind)
        }
    }
    static func acquisition(_ app: C.A) throws -> [String:Any] {
        try observe("Acquisition observation") {
            let session = try XCTUnwrap(app.session)
            return ["full":record(session.state.full),"keyboard":I.keyboard(session.state.full),
                "message":record(session.loop.message),"counter":session.loop.counter,"baseline":session.loop.timer.baseline]
        }
    }
    static func json(_ value: Any) throws -> String {
        String(decoding:try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]),as:UTF8.self)
    }
    static func emit(_ value: [String:Any]) throws {
        FileHandle.standardOutput.write(Data(("FIRST_DAMAGE "+(try json(value))+"\n").utf8))
    }
    static func digest(_ bytes: [UInt8]) -> String { MatchPreparationReference.digest(Data(bytes)) }
    static func record(_ r: OriginalStateRecord) -> [String:Any] {
        ["bytes":Data(r.bytes).base64EncodedString(),"defined":Data(r.defined.map { $0 ? 1 : 0 }).base64EncodedString()]
    }
    static func pin(_ r: OriginalStateRecord) -> [String:Any] {
        ["count":r.bytes.count,"bytesSHA256":digest(r.bytes),"maskSHA256":digest(r.defined.map { $0 ? 1 : 0 })]
    }
    static func actor(_ m: OriginalMatchPreparation,_ seat: Int) throws -> Int {
        let n = Int(try m.world.integer(at:0x194+seat*4,as:UInt32.self))
        try require(m.actors.indices.contains(n),"Diagnostic Actor ordinal");return n
    }
    static func word(_ m: OriginalMatchPreparation,_ seat: Int,_ offset: Int) throws -> Int32 {
        try m.actors[actor(m,seat)].integer(at:offset,as:Int32.self)
    }
    static func fighters(_ m: OriginalMatchPreparation) throws -> [[String:Any]] {
        try (0..<2).map { s in
            let a = m.actors[try actor(m,s)]
            var result: [String:Any] = ["seat":s,"actor":try actor(m,s)]
            for (n,o) in [("protection",8),("x",0x10),("y",0x14),("z",0x18),("frame",0x70),("previousFrame",0x74),("contactFilterFrame",0x78),("collisionFrame",0x7c),("hp",0x2fc),("mp",0x308),("damageTaken",0x34c),("contacts",0x2e4),("object",0x368)] {
                result[n] = (try? a.integer(at:o,as:Int32.self)).map { $0 as Any } ?? NSNull()
            }
            result["facing"] = (try? a.integer(at:0x80,as:UInt8.self)).map { $0 as Any } ?? NSNull()
            return result
        }
    }
    static func causal(_ m: OriginalMatchPreparation) throws -> [[String:Any]] {
        try (0..<2).map { seat in
            let a = m.actors[try actor(m,seat)]
            var result: [String:Any] = ["seat":seat,"actorRecord":record(a)]
            guard let oi = try? a.integer(at:0x368,as:UInt32.self),m.loadedObjects.indices.contains(Int(oi)) else {
                result["unavailable"] = "Object identity";return result
            }
            let object = m.loadedObjects[Int(oi)];result["header"] = record(object.header)
            var frames: [[String:Any]] = []
            for o in [0x70,0x74,0x78,0x7c] {
                guard let n = try? a.integer(at:o,as:Int32.self),object.frameStorage.indices.contains(Int(n)) else {
                    frames.append(["actorOffset":o,"unavailable":"Frame identity"]);continue
                }
                let f = object.frameStorage[Int(n)];var heaps: [[String:Any]] = []
                for (countOffset,pointerOffset) in [(0x128,0x130),(0x12c,0x134)] {
                    guard let count = try? f.integer(at:countOffset,as:Int32.self),let address = try? f.integer(at:pointerOffset,as:UInt32.self) else {
                        heaps.append(["pointerOffset":pointerOffset,"unavailable":"Count/pointer bytes"]);continue
                    }
                    var heap: [String:Any] = ["pointerOffset":pointerOffset,"count":count,"pointer":address]
                    if let allocation = m.frameAllocations.first(where:{ UInt64(address)>=UInt64($0.address) && UInt64(address)<UInt64($0.address)+UInt64($0.storage.bytes.count) }) {
                        heap["base"] = allocation.address;heap["kind"] = allocation.kind.rawValue;heap["allocation"] = record(allocation.storage)
                    } else { heap["unavailable"] = "No containing current allocation; zero count is distinct" }
                    heaps.append(heap)
                }
                frames.append(["actorOffset":o,"frame":n,"record":record(f),"heap":heaps])
            }
            result["frames"] = frames;return result
        }
    }
    static func snapshot(_ m: OriginalMatchPreparation,_ causalFields: Bool = false) throws -> [String:Any] {
        do {
        var value: [String:Any] = ["fighters":try fighters(m),"world":pin(m.world),"globals":pin(m.globals),
            "allActorBytesSHA256":digest(m.actors.flatMap(\.bytes)),
            "allActorMaskSHA256":digest(m.actors.flatMap { $0.defined.map { $0 ? 1 : 0 } }),
            "frameAllocations":m.frameAllocations.count]
        value["rng"] = try [m.globals.integer(at:0x450bcc-0x44d000,as:Int32.self),m.globals.integer(at:0x450c34-0x44d000,as:Int32.self)]
        var globals: [String:Any] = [:]
        for address in [0x44d020,0x450b90,0x450b88,0x450bfc,0x450bdc,0x450bd0,0x450bd4,0x450bd8,0x450c00] {
            globals[String(format:"%x",address)] = (try? m.globals.integer(at:address-0x44d000,as:Int32.self)).map { $0 as Any } ?? NSNull()
        }
        value["phaseAndRoundGlobals"] = globals
        if causalFields { value["causal"] = try causal(m) };return value
        } catch { throw Failure.diagnostic("Observation encoding: \(error)") }
    }
    struct Controller {
        let attacker: Int
        var phase = "align",remaining = 0
        mutating func plan(_ m: OriginalMatchPreparation,_ index: Int) throws -> ActiveGameplayReference.Plan {
            var buttons = [[String](),[String]()],segment = phase
            if try (0..<2).contains(where:{ try word(m,$0,8) != 0 }) { segment = "wait-protection" }
            else if remaining > 0 {
                if phase == "attack" { buttons[attacker] = ["attack"] }
                remaining -= 1
                if remaining == 0 {
                    switch phase {
                    case "release":phase = "attack";remaining = 2
                    case "attack":phase = "recover";remaining = 12
                    default:phase = "align"
                    }
                }
            } else {
                let other = 1-attacker,dx = Int64(try word(m,other,0x10))-Int64(try word(m,attacker,0x10))
                let dz = Int64(try word(m,other,0x18))-Int64(try word(m,attacker,0x18))
                let facing = try m.actors[actor(m,attacker)].integer(at:0x80,as:UInt8.self)
                if abs(dz)>2 { buttons[attacker] = [dz>0 ? "down":"up"] }
                else if abs(dx)>28 { buttons[attacker] = [dx>0 ? "right":"left"] }
                else if abs(dx)<20 { buttons[attacker] = [dx>0 ? "left":"right"] }
                else if facing != (dx>0 ? 0:1) { buttons[attacker] = [dx>0 ? "right":"left"] }
                else { phase = "release";remaining = 1;segment = "release" }
            }
            return .init(index:index,segment:segment,buttons:buttons)
        }
    }
    /// Out-of-band attempted observations survive rollback for diagnosis only.
    /// A retained candidate snapshot is a value copy for retry equality only; it never
    /// becomes game input or submits device/file effects.
    final class Trace {
        var phase = "acquisition",lastCompleted = "none",rows: [String] = []
        var pending: OriginalApplicationLoadedMenuSession.PendingReturn?
        func append(_ value: [String:Any]) throws { rows.append(try json(value)) }
    }
    struct Input: Equatable { var requests = 0,points: [String] = [] }
    static func input(_ cycle: inout OriginalApplicationLoadedCycleSession,_ env: inout Input,_ trace: Trace) throws -> OriginalApplicationInputSession.PendingContinuation {
        let g = cycle.entry.state.full,binding = cycle.bindings
        func w(_ a: Int) throws -> UInt32 { try g.integer(at:a-0x44d000,as:UInt32.self) }
        let expected: [OriginalInputControlRequest] = try [.init(.asyncSelect,[w(0x44f1b4),w(0x4546f4),0,0]),.init(.asyncSelect,[w(0x44f46c),w(0x4546f4),0,0]),.init(.ioctl,[w(0x44f1b4),0x8004667e,0]),.init(.ioctl,[w(0x44f46c),0x8004667e,1],[[0,0,0,0]])]
        return try cycle.advance(environment:&env,dispatch:{ _,_,_ in throw Failure.provider("Local AI/object child") },controlBoundary:{ q,e in
            guard e.requests<expected.count,q==expected[e.requests] else { throw Failure.provider("Undeclared input request: \(q)") }
            let n = e.requests;e.requests += 1
            let r = OriginalInputControlResponse(result:[-1,1,-1,0][n],bytes:n==3 ? [120,86,52,18]:[])
            try trace.append(["inputRequest":String(describing:q),"response":String(describing:r)]);return r
        },replayEvent:{ q,_ in try trace.append(["replay":String(describing:q)]) },roundEvent:{ q,_ in try trace.append(["round":String(describing:q)]) },prologue:{ m,s,paused,commands,playback,e in
            try coherent(binding,m,s)
            try trace.append(["input":"prologue","paused":paused,"commands":commands,"playback":playback,"snapshot":snapshot(m)])
            try require(e.points.isEmpty,"Input prologue order");e.points.append("prologue")
        },checkpoint:{ p,m,s,commands,e in
            try coherent(binding,m,s)
            let order = ["prologue","localBeforeDispatch","local","control","received","replay","round"]
            try require(e.points.count<order.count && order[e.points.count]==p.rawValue,"Input checkpoint order")
            e.points.append(p.rawValue)
            try trace.append(["input":p.rawValue,"commands":commands,"snapshot":snapshot(m)])
        })
    }
    static func classification(_ error: Error) -> String {
        if let e = error as? Failure {
            switch e { case .provider:return "provider-dependency";case .route:return "routing-boundary";case .diagnostic,.injected:return "diagnostic-error" }
        }
        if let e = error as? OriginalStateError {
            if case .invalidStorage(let s) = e,(s.hasPrefix("Active gameplay") || s.hasPrefix("Owned gameplay source:")) { return "comparison-domain" }
            return "core-boundary"
        }
        if let e = error as? OriginalApplicationLoadedMenuSession.Boundary {
            if case .dependency = e { return "provider-dependency" }
            return "diagnostic-session-error"
        }
        if let e = error as? OriginalApplicationMenuSession.Boundary {
            if case .dependency = e { return "provider-dependency" }
            return "diagnostic-session-error"
        }
        return "diagnostic-or-unclassified-error"
    }
}
