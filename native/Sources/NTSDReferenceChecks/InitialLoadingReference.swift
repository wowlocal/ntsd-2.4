import Foundation
import NTSDCore

public enum InitialLoadingReference {
    public struct Result {
        public let catalog: CatalogSoundsReference.Result
        public let bytes: Int, records: Int, commonLoads: Int, interfaceConstructors: Int, poolConstructors: Int, events: Int
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let initial: String?, bytes: String, defined: String }
    private struct Wave: Decodable {
        let path: [UInt8], file: String, input: OriginalWavePlatform, outputBefore: UInt32, outputAfter: UInt32
        let returned: UInt32, temporaryLive: Bool, afterGlobals: String, stackAfter: UInt32, savedRegisters: [UInt32]
        let temporary: Record?, first: Record, second: Record?, format: Record?, descriptor: Record?
    }
    private struct Common: Decodable { let beforeGlobals: String, afterGlobals: String, loads: [Wave], events: [OriginalInitialSoundEvent] }
    private struct Pool: Decodable { let world: Record, actors: [Record], constructorSlots: [Int] }
    private struct Allocation: Decodable { let address: UInt32, backing: String }
    private struct Input: Decodable { let resource: OriginalBitmapInput, surface: UInt32, colorKeyResult: Int32, dib: String }
    private struct Call: Decodable { let address: UInt32, entrySP: UInt32, returnAddress: UInt32, savedRegisters: [UInt32] }
    private struct Store: Decodable { let slot: Int, value: UInt32, globals: String }
    private struct Bitmap: Decodable { let address: UInt32, storage: Record }
    private struct Interface: Decodable {
        let allocations: [Allocation], inputs: [Input], events: [OriginalInterfaceEvent], calls: [Call], checkpoints: [Store], records: [Bitmap]
    }
    private struct CatalogAllocation: Decodable { let address: UInt32, size: Int, caller: UInt32 }
    private struct Corpus: Decodable {
        let exeSHA256: String, worldAddress: UInt32, actorAddresses: [UInt32], worldBefore: Record
        let beforeGlobals: String, afterPrologue: String, afterCatalog: String, afterGlobals: String
        let common: Common, allocated: Pool, staged: Pool, interface: Interface, catalogAllocation: CatalogAllocation
        let progressCalls: [OriginalLoadingProgressEvent], entrySP: UInt32, bodySP: UInt32, endPC: UInt32, paused: Int, commands: [UInt8]
        let blobs: [String: Blob]
    }
    private struct CatalogIdentity: Decodable { let catalogAddress: UInt32, objectAddresses: [UInt32], initialChecksum: UInt32 }
    private static func error(_ message: String) -> OriginalStateError { .invalidStorage("Initial loading reference: \(message)") }

    public static func compare(loading: Data, catalog: Data, sounds: Data,
                               initialState: (world: OriginalStateRecord, globals: OriginalStateRecord)? = nil,
                               onCommonEvent: (OriginalInitialSoundEvent) throws -> Void = { _ in },
                               onCatalog: (OriginalInitialLoadingContinuation) throws -> Void = { _ in },
                               onLoaded: (OriginalInitialLoading) throws -> Void = { _ in }) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(loading))
        let identity = try JSONDecoder().decode(CatalogIdentity.self, from: MatchPreparationReference.unpack(catalog))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.actorAddresses.count == 400, Set(c.actorAddresses).count == 400, identity.objectAddresses.count == 137,
              c.common.loads.count == 18, c.interface.allocations.count == 10, c.interface.inputs.count == 10,
              c.interface.calls.count == 10, c.interface.checkpoints.count == 10, c.interface.records.count == 10,
              c.catalogAllocation.address == identity.catalogAddress, c.catalogAllocation.size == 0x4d823a8,
              c.catalogAllocation.caller == 0x41bff5, c.endPC == 0x41c581,
              c.bodySP == ((c.entrySP-4) & ~UInt32(63))-0x604,
              c.allocated.actors.count == 400, c.staged.actors.count == 400,
              c.allocated.constructorSlots == Array(0..<400), c.staged.constructorSlots == Array(0..<400)+Array(0..<8)
        else { throw error("Source/continuous parent/constructor inventory") }
        var cache: [String:[UInt8]] = [:], bytes = 0, records = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let raw = cache[key] { return raw }
            guard let b = c.blobs[key], (0...2_000_000).contains(b.count) else { throw error("Missing blob/extent") }
            let raw = try MatchPreparationReference.inflate(b.deflate, count: b.count)
            guard MatchPreparationReference.digest(Data(raw)) == key else { throw error("Blob hash") }
            cache[key] = raw; return raw
        }
        func record(_ item: Record) throws -> OriginalStateRecord {
            let raw = try blob(item.bytes), mask = try blob(item.defined)
            guard raw.count == mask.count, mask.allSatisfy({ $0 < 2 }) else { throw error("Record extent/mask") }
            return try .init(bytes: raw, defined: mask.map { $0 == 1 })
        }
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error(label+" extent") }
            if let i = actual.bytes.indices.first(where: { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
                throw error("\(label)+\(String(i,radix:16)): byte/mask \(actual.bytes[i])/\(actual.defined[i]) vs \(expected.bytes[i])/\(expected.defined[i])")
            }
            bytes += actual.bytes.count; records += 1
        }
        func state(_ raw: [UInt8]) throws -> OriginalStateRecord { try .init(bytes: raw, defined: [Bool](repeating: true,count: raw.count)) }
        func global(_ actual: OriginalStateRecord, _ key: String, _ label: String) throws {
            let raw = try blob(key); guard raw.count == OriginalMatchPreparation.globalSize else { throw error("Globals extent") }
            try check(actual,state(raw),label)
        }
        func optional(_ actual: OriginalStateRecord?, _ expected: Record?, _ label: String) throws {
            guard (actual == nil) == (expected == nil) else { throw error(label+" presence") }
            if let actual, let expected { try check(actual,record(expected),label) }
        }
        func bind(_ record: inout OriginalStateRecord, _ offset: Int, _ address: UInt32, _ ordinal: UInt32) throws {
            guard address != 0, try record.integer(at: offset, as: UInt32.self) == address else { throw error("Known pointer binding") }
            try record.write(ordinal,at: offset)
        }
        func pool(_ actual: OriginalWorldBootstrap, _ expected: Pool) throws {
            var world = try record(expected.world)
            try bind(&world,0x7d4,identity.catalogAddress,0)
            for (i,address) in c.actorAddresses.enumerated() { try bind(&world,0x194+i*4,address,UInt32(i)) }
            try check(actual.world,world,"World")
            for i in 0..<400 {
                var actor = try record(expected.actors[i]); try bind(&actor,0x368,identity.objectAddresses[0],0)
                try check(actual.actors[i],actor,"Actor\(i)")
            }
        }
        var world: OriginalStateRecord
        if let initialState { world = initialState.world }
        else {
            guard let initialWorld = c.worldBefore.initial else { throw error("World allocator input") }
            world = try OriginalStateRecord.worldPrefix(over: blob(initialWorld))
            try world.write(Int32(2),at: 0) // Explicit standalone caller; joined callers supply their own World.
        }
        try check(world,record(c.worldBefore),"World constructor")
        let actorBacking = try c.allocated.actors.map { item -> [UInt8] in
            guard let initial = item.initial else { throw error("Actor allocator input") }; return try blob(initial)
        }
        let before: OriginalStateRecord
        if let initialState { before = initialState.globals;try global(before,c.beforeGlobals,"Own preceding menu globals") }
        else { before = try state(blob(c.beforeGlobals)) }
        var commonEvents: [OriginalInitialSoundEvent] = [], progressEvents: [OriginalLoadingProgressEvent] = [], interfaceEvents: [OriginalInterfaceEvent] = []
        var comparison: CatalogSoundsReference.Result?, timerIndex = 0
        let timerInputs = c.progressCalls.filter { $0.kind == .timeGetTime }.map(\.returned)
        let native = try OriginalInitialLoading.load(globals: before, world: world, actorBacking: actorBacking,
            targetSurface: c.common.loads[0].savedRegisters[2], fileSource: { path in
                guard let item = c.common.loads.first(where: { $0.path == Array(path.utf8) }) else { throw error("Common WAV source") }
                return try blob(item.file)
            }, wavePlatform: { index,path,destination in
                let input = c.common.loads[index]
                guard input.path == Array(path.utf8), input.input.destination == destination else { throw error("Common source/slot order") }
                return input.input
            }, loadCatalog: { checksum,initialSoundBytes,progress in
                guard checksum == identity.initialChecksum else { throw error("Inherited checksum") }
                var resources: OriginalInitialCatalogResources?
                comparison = try CatalogSoundsReference.compare(catalog: catalog, sounds: sounds, initialSoundBytes: initialSoundBytes,
                    onProgress: progress, onLoaded: { resources = .init(catalog: $0,sounds: $1) })
                guard let resources else { throw error("Native catalog construction") }
                return resources
            }, time: {
                guard timerIndex < timerInputs.count else { throw error("Extra time request") }
                defer { timerIndex += 1 }; return timerInputs[timerIndex]
            }, allocateInterface: { index in
                let a = c.interface.allocations[index]; return try .init(address: a.address,backing: blob(a.backing))
            }, interfaceSource: { index,path in
                let input = c.interface.inputs[index], dib = try state(blob(input.dib))
                guard input.resource.path == path, try dib.integer(at: 0,as: UInt32.self) >= 40,
                      try dib.integer(at: 4,as: Int32.self) == input.resource.width,
                      try dib.integer(at: 8,as: Int32.self) == input.resource.height else { throw error("Embedded source DIB dimensions") }
                return input.resource
            }, interfaceDevice: { index in let i = c.interface.inputs[index]; return (i.surface,i.colorKeyResult) },
            afterPrologue: { globals,paused in
                try global(globals,c.afterPrologue,"Prologue globals")
                guard paused == (c.paused == 1), c.common.beforeGlobals == c.afterPrologue else { throw error("Prologue pause/common continuity") }
            }, afterCommonWave: { i,wave,globals in
                let item = c.common.loads[i]
                guard wave.returned == item.returned, wave.output == item.outputAfter, wave.temporaryLive == item.temporaryLive,
                      item.stackAfter == c.bodySP,
                      item.savedRegisters == [c.worldAddress,c.entrySP-4,c.common.loads[0].savedRegisters[2],0x453f50] else { throw error("Common wave return/real ABI") }
                try optional(wave.temporary,item.temporary,"Common temporary\(i)")
                try optional(wave.first,item.first,"Common first\(i)")
                try optional(wave.second,item.second,"Common second\(i)")
                try optional(wave.format,item.format,"Common format\(i)")
                try optional(wave.descriptor,item.descriptor,"Common descriptor\(i)")
                try global(globals,item.afterGlobals,"Common globals\(i)")
            }, afterCommon: { try global($0,c.common.afterGlobals,"After common") },
            afterCatalog: { try global($0,c.afterCatalog,"After catalog") },
            afterCatalogContinuation: onCatalog,
            afterPool: { try pool($0,$1 ? c.staged : c.allocated) },
            afterInterfaceBitmap: { i,globals in
                let point = c.interface.checkpoints[i]
                guard point.slot == OriginalInitialInterfaceLoading.slots[i], point.value == c.interface.allocations[i].address else { throw error("Interface global store") }
                try global(globals,point.globals,"Interface globals\(i)")
            }, observeCommon: { commonEvents.append($0);try onCommonEvent($0) }, observeProgress: { progressEvents.append($0) }, observeInterface: { interfaceEvents.append($0) })
        try global(native.globals,c.afterGlobals,"Final globals")
        guard timerIndex == timerInputs.count, commonEvents == c.common.events, progressEvents == c.progressCalls,
              interfaceEvents == c.interface.events, native.commands == c.commands, native.paused == (c.paused == 1),
              native.commonSounds.count == 18, native.interface.bitmaps.count == 10 else { throw error("Final events/ownership/locals") }
        for (i,item) in c.interface.records.enumerated() {
            let call = c.interface.calls[i]
            guard call.address == item.address, call.entrySP == c.bodySP-16,
                  call.savedRegisters.count == 4, call.savedRegisters[0] == c.worldAddress, call.savedRegisters[1] == c.entrySP-4,
                  let actual = native.interface.bitmaps[item.address] else { throw error("Interface ret12/ownership") }
            var expected = try record(item.storage)
            try bind(&expected,0,c.interface.inputs[i].surface,1)
            try check(actual.storage,expected,"Interface bitmap\(i)")
        }
        guard let comparison else { throw error("Missing catalog comparison") }
        try onLoaded(native)
        return .init(catalog: comparison,bytes: bytes,records: records,commonLoads: native.commonSounds.count,
                     interfaceConstructors: c.interface.calls.count,poolConstructors: c.staged.constructorSlots.count,
                     events: commonEvents.count+progressEvents.count+interfaceEvents.count)
    }
}
