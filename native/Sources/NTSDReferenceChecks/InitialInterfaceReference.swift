import Foundation
import NTSDCore

public enum InitialInterfaceReference {
    public struct Result {
        public var cases = 0, sources = 0, constructors = 0, poolConstructors = 0, records = 0, bytes = 0
        public var events = 0, nullAllocations = 0, messages = 0, releases = 0
        public var providedConstructors = 0
    }
    private struct Source: Decodable { let path: String, sha256: String, bytes: String; let width: Int32, height: Int32 }
    private struct Allocation: Decodable { let address: UInt32; let backing: String }
    private struct Input: Decodable { let index: Int, resource: OriginalBitmapInput, surface: UInt32, colorKeyResult: Int32 }
    private struct Call: Decodable { let address: UInt32, stackAfter: UInt32; let savedRegisters: [UInt32] }
    private struct Checkpoint: Decodable { let slot: Int, value: UInt32, globals: String }
    private struct Record: Decodable { let bytes: String, defined: String }
    private struct Bitmap: Decodable { let address: UInt32, bytes: String, defined: String }
    private struct Pool: Decodable { let world: Record, actors: [Record], allocations: Int, constructorSlots: [Int] }
    private struct Addresses: Decodable { let world: UInt32, catalog: UInt32, object: UInt32; let actors: [UInt32] }
    private struct Case: Decodable {
        let label: String, actorInitial: String, worldInitial: String, selector: UInt32, firstObjectWord90: UInt32
        let addresses: Addresses, beforeGlobals: String, afterGlobals: String, allocations: [Allocation], inputs: [Input]
        let events: [OriginalInterfaceEvent], calls: [Call], checkpoints: [Checkpoint], records: [Bitmap], pool: Pool
        let endPC: String, stackAfter: UInt32, restoredEDI: UInt32
    }
    private struct Corpus: Decodable { let exeSHA256: String, sources: [Source], cases: [Case], blobs: [String: String] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Initial interface reference: \(text)") }
    private static func hex(_ text: String) throws -> [UInt8] {
        let raw = Array(text.utf8)
        guard raw.count % 2 == 0 else { throw error("Odd hex extent") }
        func nibble(_ value: UInt8) throws -> UInt8 {
            switch value { case 48...57: return value-48; case 97...102: return value-87; default: throw error("Invalid hex") }
        }
        return try stride(from: 0, to: raw.count, by: 2).map { try nibble(raw[$0])*16+nibble(raw[$0+1]) }
    }
    /// The supplied-constructor route retains this corpus's explicit43ed10
    /// device-result boundary; it does not turn these cases into whole GDI runs.
    public static func compare(_ data: Data, useProvidedConstructor: Bool = false) throws -> Result {
        let corpus = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(data))
        guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              corpus.sources.count == 10, Set(corpus.sources.map(\.path)).count == 10 else { throw error("Source identity") }
        var result = Result(), blobs: [String: [UInt8]] = [:]
        for (key,value) in corpus.blobs {
            let raw = try hex(value)
            guard MatchPreparationReference.digest(Data(raw)) == key else { throw error("Pool blob hash") }
            blobs[key] = raw
        }
        var sources: [String: Source] = [:]
        for item in corpus.sources {
            let raw = try hex(item.bytes)
            guard raw.count >= 40, MatchPreparationReference.digest(Data(raw)) == item.sha256 else { throw error("Resource DIB hash/extent") }
            let record = try OriginalStateRecord(bytes: raw, defined: [Bool](repeating: true, count: raw.count))
            guard try record.integer(at: 0, as: UInt32.self) >= 40,
                  try record.integer(at: 4, as: Int32.self) == item.width,
                  try record.integer(at: 8, as: Int32.self) == item.height else { throw error("Source DIB dimensions") }
            sources[item.path] = item; result.sources += 1
        }
        func check(_ actual: OriginalStateRecord, _ bytes: [UInt8], _ mask: [UInt8], _ label: String) throws {
            guard bytes.count == actual.bytes.count, mask.count == bytes.count, mask.allSatisfy({ $0 < 2 }) else { throw error(label+" extent/mask") }
            if let offset = bytes.indices.first(where: { actual.bytes[$0] != bytes[$0] || actual.defined[$0] != (mask[$0] == 1) }) {
                throw error("\(label)+\(String(offset,radix:16)): byte/mask differs")
            }
            result.bytes += bytes.count; result.records += 1
        }
        func pooled(_ input: Record) throws -> OriginalStateRecord {
            guard let bytes = blobs[input.bytes], let mask = blobs[input.defined], mask.allSatisfy({ $0 < 2 }) else { throw error("Pool record") }
            return try .init(bytes: bytes, defined: mask.map { $0 == 1 })
        }
        func bind(_ input: inout OriginalStateRecord, _ offset: Int, _ address: UInt32, _ ordinal: UInt32) throws {
            guard address != 0, try input.integer(at: offset, as: UInt32.self) == address else { throw error("Established bootstrap pointer") }
            try input.write(ordinal, at: offset)
        }
        for item in corpus.cases {
            guard item.allocations.count == 10, item.checkpoints.count == 10, item.endPC == "0x41c581",
                  item.stackAfter == 0x1000f000, item.restoredEDI == 0x12345678,
                  item.addresses.actors.count == 400, Set(item.addresses.actors).count == 400,
                  item.pool.allocations == 400, item.pool.actors.count == 400,
                  item.pool.constructorSlots == Array(0..<400)+Array(0..<8) else { throw error("Parent/pool context") }
            var bootstrap = try OriginalWorldBootstrap(worldBacking: hex(item.worldInitial),
                actorBacking: [Array<UInt8>](repeating: hex(item.actorInitial), count: 400), selector: Int32(bitPattern: item.selector))
            try bootstrap.activateStagingActors(firstObjectWord90: Int32(bitPattern: item.firstObjectWord90))
            let before = try hex(item.beforeGlobals)
            var globals = try OriginalStateRecord(bytes: before, defined: [Bool](repeating: true, count: before.count))
            var loader = OriginalInitialInterfaceLoading(), events: [OriginalInterfaceEvent] = []
            guard Set(item.inputs.map(\.index)).count == item.inputs.count else { throw error("Duplicate device result index") }
            let inputs = Dictionary(uniqueKeysWithValues: item.inputs.map { ($0.index,$0) })
            func resource(_ index: Int, _ path: String) throws -> OriginalBitmapInput {
                guard let input = inputs[index], let source = sources[path], input.resource.path == path else { throw error("Device/source binding") }
                if input.resource.present {
                    guard input.resource.width == source.width, input.resource.height == source.height else { throw error("Device/source dimensions") }
                }
                return input.resource
            }
            var constructor: ((Int, OriginalInterfaceAllocation, UInt32, String) throws -> OriginalLoadedBitmap)?
            if useProvidedConstructor {
                let expectedDevice = try globals.integer(at: 0x457578-OriginalMatchPreparation.globalBase, as: UInt32.self)
                constructor = { index,allocation,device,path in
                    guard device == expectedDevice, allocation.address == item.allocations[index].address,
                          allocation.backing == (try hex(item.allocations[index].backing)),
                          path == OriginalInitialInterfaceLoading.paths[index], let output = inputs[index] else {
                        throw error("Supplied constructor binding")
                    }
                    result.providedConstructors += 1
                    return try OriginalBitmapConstructor.construct(resource(index,path), optional: false,
                        backing: allocation.backing, device: device, flags: 0x40, surface: output.surface,
                        colorKeyResult: output.colorKeyResult) { events.append($0) }
                }
            }
            try loader.load(globals: &globals, allocate: { index in
                let a = item.allocations[index]
                return try .init(address: a.address, backing: hex(a.backing))
            }, source: { index,path in
                guard !useProvidedConstructor else { throw error("Unexpected legacy source request") }
                return try resource(index,path)
            }, deviceResult: { index in
                guard !useProvidedConstructor else { throw error("Unexpected legacy device request") }
                guard let input = inputs[index] else { throw error("Missing device result") }
                return (input.surface,input.colorKeyResult)
            }, constructBitmap: constructor, afterBitmap: { index,state in
                let point = item.checkpoints[index], raw = try hex(point.globals)
                guard point.slot == OriginalInitialInterfaceLoading.slots[index],
                      point.value == item.allocations[index].address else { throw error("Original global assignment") }
                try check(state,raw,[UInt8](repeating: 1,count: raw.count),"\(item.label) global store\(index)")
            }) { events.append($0) }
            guard events == item.events else {
                let i = zip(events,item.events).enumerated().first { $0.element.0 != $0.element.1 }?.offset
                throw error("\(item.label) event \(i.map(String.init) ?? "count")")
            }
            let after = try hex(item.afterGlobals)
            try check(globals,after,[UInt8](repeating: 1,count: after.count),item.label+" final globals")
            let nonnull = item.allocations.filter { $0.address != 0 }
            guard item.records.count == nonnull.count, item.calls.map(\.address) == nonnull.map(\.address),
                  inputs.count == nonnull.count, loader.bitmaps.count == nonnull.count else { throw error("Allocation/constructor inventory") }
            for call in item.calls {
                let first = call.address == item.allocations[0].address
                guard call.stackAfter == 0x1000f000,
                      call.savedRegisters == [item.addresses.world, 0, first ? item.addresses.object : UInt32.max, item.addresses.actors[7]] else {
                    throw error("Real constructor ret12/nonvolatile-register witness")
                }
            }
            for bitmap in item.records {
                guard let native = loader.bitmaps[bitmap.address], let index = item.allocations.firstIndex(where: { $0.address == bitmap.address }),
                      let input = inputs[index] else { throw error("Bitmap allocation binding") }
                let raw = try hex(bitmap.bytes), mask = try hex(bitmap.defined)
                var expected = try OriginalStateRecord(bytes: raw, defined: mask.map { $0 == 1 })
                let pointer: UInt32 = input.colorKeyResult < 0 ? 0 : input.surface
                guard try expected.integer(at: 0, as: UInt32.self) == pointer else { throw error("Surface lifecycle") }
                try expected.write(UInt32(pointer == 0 ? 0 : 1),at: 0)
                try check(native.storage,expected.bytes,mask,item.label+" bitmap")
            }
            var world = try pooled(item.pool.world)
            try bind(&world,0x7d4,item.addresses.catalog,0)
            for slot in 0..<400 {
                try bind(&world,0x194+slot*4,item.addresses.actors[slot],UInt32(slot))
                var actor = try pooled(item.pool.actors[slot])
                try bind(&actor,0x368,item.addresses.object,0)
                try check(bootstrap.actors[slot],actor.bytes,actor.defined.map { $0 ? 1 : 0 },item.label+" Actor\(slot)")
            }
            try check(bootstrap.world,world.bytes,world.defined.map { $0 ? 1 : 0 },item.label+" World")
            result.cases += 1; result.poolConstructors += 408; result.constructors += item.calls.count
            result.events += events.count; result.nullAllocations += 10-nonnull.count
            result.messages += events.filter { $0.kind == .message }.count
            result.releases += events.filter { $0.kind == .release }.count
        }
        return result
    }
}
