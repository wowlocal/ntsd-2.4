import Foundation
import NTSDCore

public enum LocalInputReference {
    public struct Result {
        public let initial: InitialLoadingReference.Result
        public let cases: Int, bytes: Int, records: Int, calls: Int, characterAI: Int, objectInput: Int
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let bytes: String, defined: String }
    private struct Snapshot: Decodable { let world: Record, actors: [Record], globals: String }
    private struct GlobalWrite: Decodable { let address: UInt32, bytes: String }
    private struct WorldWrite: Decodable { let offset: Int, bytes: String }
    private struct ActorWrite: Decodable { let slot: Int, offset: Int, bytes: String }
    private struct Binding: Decodable { let slot: Int, object: UInt32, frame: UInt32 }
    private struct Stimulus: Decodable { let globals: [GlobalWrite], actors: [ActorWrite], world: [WorldWrite], bindings: [Binding] }
    private struct Call: Decodable { let entrySP: UInt32, returnAddress: UInt32, arguments: [UInt32], saved: [UInt32] }
    private struct Dispatch: Decodable { let kind: OriginalLocalInputDispatch.Kind, arguments: [UInt32], world: UInt32, caller: UInt32 }
    private struct Case: Decodable {
        let label: String, stimulus: Stimulus, parent: Bool, natural: Bool, paused: Int32, phase: UInt32, mode: UInt32
        let commandsBefore: [UInt8], commandsAfter: [UInt8], call: Call?, beforeDispatch: Snapshot?, dispatch: [Dispatch]
        let after: Snapshot, stackAfter: UInt32, endPC: UInt32
    }
    private struct Parent: Decodable { let fixture: String, sha256: String }
    private struct Corpus: Decodable {
        let exeSHA256: String, parents: [String: Parent], worldAddress: UInt32, objectAddresses: [UInt32], actorAddresses: [UInt32]
        let template: [UInt8], commandsAddress: UInt32, bodySP: UInt32, cases: [Case], blobs: [String: Blob]
    }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Local-input reference: \(message)") }
    private static func hex(_ text: String) throws -> [UInt8] {
        let utf8 = Array(text.utf8); guard utf8.count%2 == 0 else { throw error("Hex extent") }
        func value(_ c: UInt8) throws -> UInt8 {
            switch c { case 48...57:return c-48;case 97...102:return c-87;default:throw error("Hex digit") }
        }
        return try stride(from: 0,to: utf8.count,by: 2).map { try value(utf8[$0])*16+value(utf8[$0+1]) }
    }
    public static func compare(input: Data, loading: Data, catalog: Data, sounds: Data,
                               onNatural: (OriginalMatchPreparation, [UInt8], Bool) throws -> Void = { _, _, _ in }) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(input))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.objectAddresses.count == 137, Set(c.objectAddresses).count == 137,
              c.actorAddresses.count == 400, Set(c.actorAddresses).count == 400,
              c.template == [UInt8](repeating: 1,count: 20)+[0], !c.cases.isEmpty,
              c.commandsAddress == c.bodySP+0x434 else { throw error("Source/parent identity") }
        for (key,data) in [("initial-loading",loading),("initial-loading-catalog",catalog),("initial-loading-sounds",sounds)] {
            guard let parent = c.parents[key], MatchPreparationReference.digest(data) == parent.sha256 else { throw error("Pinned initial loading \(key)") }
        }
        var blobs: [String:[UInt8]] = [:], stored: [String:OriginalStateRecord] = [:], actorCache: [String:OriginalStateRecord] = [:]
        var bytes = 0, records = 0, calls = 0, characterAI = 0, objectInput = 0
        let objects = Dictionary(uniqueKeysWithValues: c.objectAddresses.enumerated().map { ($0.element,UInt32($0.offset)) })
        func blob(_ key: String) throws -> [UInt8] {
            if let raw = blobs[key] { return raw }
            guard let b = c.blobs[key], (0...2_000_000).contains(b.count) else { throw error("Blob extent") }
            let raw = try MatchPreparationReference.inflate(b.deflate,count: b.count)
            guard MatchPreparationReference.digest(Data(raw)) == key else { throw error("Blob hash") }
            blobs[key] = raw; return raw
        }
        func record(_ item: Record) throws -> OriginalStateRecord {
            let key = item.bytes+item.defined
            if let value = stored[key] { return value }
            let raw = try blob(item.bytes), mask = try blob(item.defined)
            guard raw.count == mask.count, mask.allSatisfy({ $0<2 }) else { throw error("Mask") }
            let value = try OriginalStateRecord(bytes: raw,defined: mask.map { $0==1 }); stored[key] = value; return value
        }
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error(label+" extent") }
            if actual != expected {
                let offset = actual.bytes.indices.first { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }!
                throw error("\(label)+\(String(offset,radix:16)): \(actual.bytes[offset])/\(actual.defined[offset]) vs \(expected.bytes[offset])/\(expected.defined[offset])")
            }
            bytes += actual.bytes.count; records += 1
        }
        func snapshot(_ state: OriginalMatchPreparation, _ expected: Snapshot, _ label: String) throws {
            guard expected.actors.count == 400 else { throw error("Pool extent") }
            let global = try blob(expected.globals)
            try check(state.globals,.init(bytes: global,defined: [Bool](repeating: true,count: global.count)),label+" globals")
            var world = try record(expected.world)
            guard try world.integer(at: 0x7d4,as: UInt32.self) == 0x60000020 else { throw error("World catalog binding") }
            try world.write(UInt32(0),at: 0x7d4)
            for (i,address) in c.actorAddresses.enumerated() {
                guard try world.integer(at: 0x194+i*4,as: UInt32.self) == address else { throw error("World Actor table") }
                try world.write(UInt32(i),at: 0x194+i*4)
            }
            try check(state.world,world,label+" World")
            for (i,item) in expected.actors.enumerated() {
                let key = item.bytes+item.defined
                var value: OriginalStateRecord
                if let cached = actorCache[key] { value = cached }
                else {
                    value = try record(item)
                    guard let object = objects[try value.integer(at: 0x368,as: UInt32.self)] else { throw error("Known Actor Object pointer") }
                    try value.write(object,at: 0x368); actorCache[key] = value
                }
                try check(state.actors[i],value,label+" Actor\(i)")
            }
        }
        let initial = try InitialLoadingReference.compare(loading: loading,catalog: catalog,sounds: sounds,onLoaded: { loaded in
            var state = try OriginalMatchPreparation(loading: loaded,arithmeticPrecision: .bits64)
            var commands = Array(loaded.commands.prefix(10))
            for (index,item) in c.cases.enumerated() {
                guard item.natural == (index == 0), item.commandsBefore.count == 10, item.commandsAfter.count == 10 else { throw error("Case order/commands") }
                for write in item.stimulus.globals {
                    for (i,b) in try hex(write.bytes).enumerated() { try state.globals.write(b,at: Int(write.address)-OriginalMatchPreparation.globalBase+i) }
                }
                for write in item.stimulus.world {
                    for (i,b) in try hex(write.bytes).enumerated() { try state.world.write(b,at: write.offset+i) }
                }
                for write in item.stimulus.actors {
                    guard (0..<400).contains(write.slot) else { throw error("Actor stimulus") }
                    for (i,b) in try hex(write.bytes).enumerated() { try state.actors[write.slot].write(b,at: write.offset+i) }
                }
                for binding in item.stimulus.bindings {
                    guard (0..<400).contains(binding.slot), binding.object < loaded.catalog.objects.count, binding.frame < 400 else { throw error("Source binding stimulus") }
                    try state.actors[binding.slot].write(binding.object,at: 0x368)
                    try state.actors[binding.slot].write(binding.frame,at: 0x70)
                }
                if item.natural {
                    guard commands == item.commandsBefore, loaded.paused == (item.paused != 0), item.parent else { throw error("Natural continuity") }
                } else { commands = item.commandsBefore }
                let phase = try item.parent ? state.globals.integer(at: 0x450b90-OriginalMatchPreparation.globalBase,as: UInt32.self) : item.phase
                let mode = try item.parent ? state.globals.integer(at: 0x451160-OriginalMatchPreparation.globalBase,as: UInt32.self) : item.mode
                var beforeCount = 0, dispatchCount = 0
                let before: (OriginalMatchPreparation,[UInt8]) throws -> Void = { value,output in
                    guard beforeCount == 0, let expected = item.beforeDispatch else { throw error("Before-dispatch checkpoint") }
                    try snapshot(value,expected,item.label+" local")
                    // The declared child boundary doesn't mutate local command memory.
                    guard output == item.commandsAfter else { throw error(item.label+" packed commands before children") }
                    beforeCount += 1
                }
                let dispatch: (OriginalLocalInputDispatch,inout OriginalMatchPreparation) throws -> Void = { request,_ in
                    guard dispatchCount < item.dispatch.count else { throw error("Extra native AI request") }
                    let expected = item.dispatch[dispatchCount]
                    guard request.kind == expected.kind, request.arguments == expected.arguments, expected.world == c.worldAddress,
                          expected.caller == (request.kind == .characterAI ? 0x419df9 : 0x419e1b) else { throw error("Child dispatch/real call ABI") }
                    if request.kind == .characterAI { characterAI += 1 } else { objectInput += 1 }
                    dispatchCount += 1 // Explicit no-effect child response, not an AI implementation.
                }
                if item.parent { try state.beginLocalInput(paused: item.paused != 0,commands: &commands,beforeDispatch: before,dispatch: dispatch) }
                else { try state.localInput(phase: Int32(bitPattern: phase),mode: Int32(bitPattern: mode),commands: &commands,beforeDispatch: before,dispatch: dispatch) }
                guard commands == item.commandsAfter, dispatchCount == item.dispatch.count else { throw error(item.label+" command/dispatch result") }
                try snapshot(state,item.after,item.label+" final")
                // Native ownership check, separate from source snapshot counts.
                guard state.interface.bitmaps.count == loaded.interface.bitmaps.count else { throw error("Retained loaded UI inventory") }
                for (address,bitmap) in loaded.interface.bitmaps {
                    guard let retained = state.interface.bitmaps[address], retained.input == bitmap.input,
                          retained.optional == bitmap.optional, retained.storage == bitmap.storage else { throw error("Retained loaded UI bytes/masks") }
                }
                if let call = item.call {
                    guard call.arguments == [phase,mode,c.commandsAddress], call.saved.count == 4, beforeCount == 1,
                          call.returnAddress == item.endPC, item.stackAfter == call.entrySP+16,
                          call.entrySP == (item.parent ? c.bodySP-16 : 0x1000d000),
                          item.endPC == (item.parent ? 0x41c5e5 : 0x30000000) else { throw error("ret12/parent stack witness") }
                    calls += 1
                } else {
                    guard item.parent, item.paused != 0, item.beforeDispatch == nil, beforeCount == 0, item.stackAfter == c.bodySP else { throw error("Paused caller skip") }
                }
                if item.natural { try onNatural(state,commands,item.paused != 0) }
            }
        })
        return .init(initial: initial,cases: c.cases.count,bytes: bytes,records: records,calls: calls,characterAI: characterAI,objectInput: objectInput)
    }
}
