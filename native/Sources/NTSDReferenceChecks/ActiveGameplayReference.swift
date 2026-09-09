import Foundation
import NTSDCore

/// Declared keyboard acquisition and primitive-effect assertions for the own
/// active trajectory. These helpers belong only to reference comparison.
enum ActiveGameplayReference {
    struct Plan: Decodable, Equatable {
        let index: Int, segment: String, buttons: [[String]]
    }
    struct Acquisition: Decodable {
        struct Binding: Decodable, Equatable { let seat: Int,status: UInt32,config: UInt32,device: UInt32,keys: [UInt32] }
        struct Change: Decodable, Equatable { let key: UInt32,address: UInt32,before: UInt8,after: UInt8 }
        let plan: Plan,bindings: [Binding],changes: [Change],before: [UInt8],after: [UInt8]
    }
    struct Effect: Decodable {
        struct Context: Decodable {
            struct Parent: Decodable { let entry: UInt32,entrySP: UInt32,returnPC: UInt32,this: UInt32,arguments: [UInt32] }
            let pc: UInt32,sp: UInt32,this: UInt32,registers: [UInt32],root3c: UInt32,parents: [Parent]
        }
        let kind: String,arguments: [UInt32],context: Context
    }
    static let buttons = ["up","down","left","right","attack","jump","defend"]
    static var schedule: [Plan] {
        let segments: [(String,Int,[String],[String])] = [
            ("approach",16,["left"],["right"]),("moving-attacks",8,["left","attack"],["right","attack"]),
            ("release",4,[],[]),("guard-and-attack",8,["defend"],["attack"]),
            ("jump",4,["jump"],["jump"]),("depth-movement",4,["up"],["down"]),("release-final",4,[],[])]
        var result: [Plan] = []
        for (label,count,a,b) in segments { for _ in 0..<count { result.append(.init(index:result.count+1,segment:label,buttons:[a,b])) } }
        return result
    }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Active gameplay reference: "+message) }

    /// Derive virtual keys from native loaded bindings; only requested key
    /// transitions are external input. Expected pool/commands never seed Native.
    static func acquire(_ source: Acquisition, index: Int, state: inout OriginalMatchPreparation,
        held: inout Set<UInt32>) throws {
        guard schedule.indices.contains(index),source.plan == schedule[index] else { throw error("Input schedule") }
        var globals = state.globals,desired = Set<UInt32>(),bindings: [Acquisition.Binding] = []
        let first = 0x455378-0x44d000
        let before = Array(globals.bytes[first..<first+300])
        for (seat,names) in source.plan.buttons.enumerated() {
            let status = try globals.integer(at:0x450b4c-0x44d000+seat*4,as:UInt32.self)
            guard (1...4).contains(status) else { throw error("Own keyboard seat") }
            let config = 0x44fb20+status*80
            guard try globals.integer(at:Int(config)-0x44d000,as:UInt32.self) == 0 else { throw error("Own keyboard device") }
            let keys = try (0..<7).map { try globals.integer(at:Int(config)-0x44d000+4+$0*4,as:UInt32.self) }
            guard keys.allSatisfy({ $0 < 300 }) else { throw error("Own key mapping") }
            bindings.append(.init(seat:seat,status:status,config:config,device:0,keys:keys))
            for name in names {
                guard let n = buttons.firstIndex(of:name) else { throw error("Unknown declared button") };desired.insert(keys[n])
            }
        }
        var changes: [Acquisition.Change] = []
        for key in held.union(desired).sorted() {
            let value: UInt8 = desired.contains(key) ? 100 : 117
            if before[Int(key)] != value {
                changes.append(.init(key:key,address:0x455378+key,before:before[Int(key)],after:value))
                try globals.write(value,at:first+Int(key))
            }
        }
        guard source.bindings == bindings,source.changes == changes,source.before == before,
              source.after == Array(globals.bytes[first..<first+300]),
              source.after == (0..<300).map({ desired.contains(UInt32($0)) ? UInt8(100) : UInt8(117) }) else { throw error("Acquired keyboard witness") }
        state.globals = globals;held = desired
    }

    final class Effects {
        typealias Stage = OriginalGameplayBody.Stage
        let sections: [Stage:ContinuousGameplayReference.Section]
        private var counts: [Stage:Int] = [:]
        init(_ sections: [Stage:ContinuousGameplayReference.Section]) { self.sections = sections }
        private func next(_ stage: Stage,_ kind: String,_ arguments: [UInt32]) throws -> Effect {
            let n = counts[stage,default:0]
            guard let values = sections[stage]?.effects,n < values.count,
                  values[n].kind == kind,values[n].arguments == arguments else { throw error("\(stage) primitive effect\(n): \(kind) \(arguments)") }
            counts[stage] = n+1;return values[n]
        }
        private func physicsOwner(_ e: Effect) throws -> UInt32 {
            if let parent = e.context.parents.last(where:{ $0.entry == 0x40e490 }) {
                guard let h = sections[.physics]?.helpers.first(where:{ $0.entry == parent.entry && $0.entrySP == parent.entrySP && $0.this == parent.this }),h.saved.count == 4 else { throw error("Physics sound owner") }
                return h.saved[3]
            }
            guard e.context.registers.count == 4 else { throw error("Physics caller registers") };return e.context.registers[3]
        }
        func control(_ value: OriginalActorControlEvent,slot: Int) throws {
            let e: Effect
            switch value {
            case let .random(stream,range,result):e = try next(.control,"random",[stream,range,result].map(UInt32.init(bitPattern:)))
            case let .sound(x,index):e = try next(.control,"builtinSound",[x,index].map(UInt32.init(bitPattern:)))
            }
            guard e.context.root3c == UInt32(slot) else { throw error("Control effect owner") }
        }
        func physics(_ value: OriginalWorldPhysicsEvent) throws {
            let e: Effect,slot: Int
            switch value {
            case let .random(owner,stream,range,result):slot = owner;e = try next(.physics,"random",[stream,range,result].map(UInt32.init(bitPattern:)))
            case let .reconstruct(owner,created):slot = owner;e = try next(.physics,"reconstruct",[UInt32(created)])
            case let .sound(owner,event):
                slot = owner
                switch event {
                case let .builtinSound(x,n):e = try next(.physics,"builtinSound",[x,n].map(UInt32.init(bitPattern:)))
                case let .catalogSound(x,n):e = try next(.physics,"catalogSound",[x,n].map(UInt32.init(bitPattern:)))
                }
            }
            guard try physicsOwner(e) == UInt32(slot) else { throw error("Physics effect slot") }
        }
        func contacts(_ value: OriginalWorldContactsEvent) throws {
            switch value {
            case let .random(a,b,stream,range,result):
                let e = try next(.contacts,"random",[stream,range,result].map(UInt32.init(bitPattern:)))
                guard let pair = e.context.parents.last(where:{ $0.entry == 0x417400 }),Array(pair.arguments.prefix(2)) == [UInt32(a),UInt32(b)] else { throw error("Contact RNG pair") }
            case .reconstruct:throw error("Contact reconstruction needs recovered caller-slot context")
            }
        }
        func hits(_ value: OriginalHitEvent) throws {
            switch value {
            case let .random(stream,range,result):_ = try next(.hits,"random",[stream,range,result].map(UInt32.init(bitPattern:)))
            case let .builtinSound(x,n):_ = try next(.hits,"builtinSound",[x,n].map(UInt32.init(bitPattern:)))
            case let .catalogSound(x,n):_ = try next(.hits,"catalogSound",[x,n].map(UInt32.init(bitPattern:)))
            case let .reconstruct(slot):_ = try next(.hits,"reconstruct",[UInt32(slot)])
            case .crtRandom:throw error("Own CRT random event requires original boundary evidence")
            }
        }
        func finish() throws {
            for (stage,section) in sections { guard counts[stage,default:0] == (section.effects?.count ?? 0) else { throw error("Incomplete \(stage) primitive effects") } }
        }
    }
}
