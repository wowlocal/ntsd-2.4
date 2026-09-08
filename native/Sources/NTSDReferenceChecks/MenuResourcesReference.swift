import Foundation
import NTSDCore

public enum MenuResourcesReference {
    public struct Result {
        public let parent: MusicPlaybackReference.Result
        public let cases: Int, checkpoints: Int, events: Int, constructors: Int, allocations: Int, nullAllocations: Int
        public let messages: Int, releases: Int, nullSpark: Int, records: Int, bytes: Int
    }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Record: Decodable { let address: UInt32, storage: Storage }
    private struct Allocation: Decodable { let address: UInt32, backing: String? }
    private struct Input: Decodable { let index: Int, resource: OriginalBitmapInput, surface: UInt32, colorKeyResult: Int32 }
    private struct Source: Decodable { let path: String, width: Int32, height: Int32, dib: String }
    private struct Call: Decodable { let index: Int, address: UInt32, entrySP: UInt32, returnAddress: UInt32, saved: [UInt32], returnSP: UInt32 }
    private struct Checkpoint: Decodable { let kind: OriginalMenuResourceCheckpoint.Kind, index: Int, globals: String, records: [Record] }
    private struct Case: Decodable {
        let label: String, stimulus: [InputControlReference.GlobalWrite], inherited: Bool, allocations: [Allocation], inputs: [Input]
        let events: [OriginalInterfaceEvent], calls: [Call], checkpoints: [Checkpoint]
        let continuation: OriginalMenuResourceResult.Continuation, selectionAtEntry: UInt32, endPC: UInt32, endSP: UInt32, globals: String, records: [Record]
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, control: Bool, parents: [String:InputControlReference.Parent], initialGlobals: String
        let sources: [Source], cases: [Case], blobs: [String:InputControlReference.Blob]
    }
    private struct Music: Decodable {
        struct Case: Decodable { let afterGlobals: String }
        let control: Bool, cases: [Case]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Menu resources reference: "+text) }
    private static func hex(_ text: String) throws -> [UInt8] {
        let b = Array(text.utf8); guard b.count%2 == 0 else { throw error("Hex extent") }
        func digit(_ x: UInt8) throws -> UInt8 {
            switch x { case 48...57:return x-48;case 97...102:return x-87;default:throw error("Hex digit") }
        }
        return try stride(from: 0,to: b.count,by: 2).map { try digit(b[$0])*16+digit(b[$0+1]) }
    }
    public static func compare(resources: Data, music: Data, round: Data, replay: Data, control: Data, local: Data,
                               loading: Data, catalog: Data, sounds: Data) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(resources,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c", !c.cases.isEmpty,
              c.sources.count == 11, Set(c.sources.map(\.path)) == Set(OriginalMenuResourceLoading.paths) else { throw error("Source identity") }
        for (key,data) in [("music-playback",music),("match-round",round),("replay-tick",replay),("input-control",control),("local-input",local),
                           ("initial-loading",loading),("initial-loading-catalog",catalog),("initial-loading-sounds",sounds)] {
            guard let p = c.parents[key], MatchPreparationReference.digest(data) == p.sha256 else { throw error("Parent SHA "+key) }
        }
        let m = try JSONDecoder().decode(Music.self,from: MatchPreparationReference.unpack(music,maximumCount: 128_000_000))
        guard m.control == c.control, m.cases.first?.afterGlobals == c.initialGlobals else { throw error("Natural music identity") }
        var blobs: [String:[UInt8]] = [:], normalized: [String:OriginalStateRecord] = [:], surfaces: [String:UInt32] = [:]
        var callbacks = 0, checkpoints = 0, events = 0, constructors = 0, allocations = 0, nulls = 0, messages = 0, releases = 0, faults = 0, records = 0, bytes = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let raw = blobs[key] { return raw }
            guard let item = c.blobs[key], (0...2_000_000).contains(item.count) else { throw error("Blob extent") }
            let raw = try MatchPreparationReference.inflate(item.deflate,count: item.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(raw)) == key else { throw error("Blob SHA") }
            blobs[key] = raw; return raw
        }
        func same<T>(_ left: [T], _ right: [T]) -> Bool {
            guard left.count == right.count else { return false }
            return left.withUnsafeBytes { l in right.withUnsafeBytes { r in l.isEmpty || memcmp(l.baseAddress!,r.baseAddress!,l.count) == 0 } }
        }
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw error(label+" extent") }
            if !same(actual.bytes,expected.bytes) || !(same(actual.defined,expected.defined) || actual.defined == expected.defined) {
                let i = actual.bytes.indices.first { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }!
                throw error("\(label)+\(String(i,radix:16)): \(actual.bytes[i])/\(actual.defined[i]) vs \(expected.bytes[i])/\(expected.defined[i])")
            }
            records += 1; bytes += actual.bytes.count
        }
        func globals(_ key: String) throws -> OriginalStateRecord {
            let cache = "global"+key
            if let value = normalized[cache] { return value }
            let raw = try blob(key); guard raw.count == OriginalMatchPreparation.globalSize else { throw error("Global extent") }
            let value = try OriginalStateRecord(bytes: raw,defined: [Bool](repeating: true,count: raw.count));normalized[cache] = value;return value
        }
        var inputByAddress: [UInt32:Input] = [:]
        func bitmap(_ item: Record, _ actual: OriginalLoadedBitmap, _ label: String) throws {
            guard let input = inputByAddress[item.address], actual.input == input.resource, !actual.optional else { throw error("Bitmap ownership/input") }
            let key = item.storage.bytes+item.storage.defined
            let expected: OriginalStateRecord
            if let cached = normalized[key] { expected = cached }
            else {
                let raw = try blob(item.storage.bytes), mask = try blob(item.storage.defined)
                guard raw.count == 0x1f50, mask.count == raw.count, mask.allSatisfy({ $0<2 }) else { throw error("Bitmap extent/mask") }
                var record = try OriginalStateRecord(bytes: raw,defined: mask.map { $0 == 1 })
                let surface = try record.integer(at: 0,as: UInt32.self);surfaces[key] = surface
                try record.write(UInt32(surface == 0 ? 0 : 1),at: 0)
                normalized[key] = record; expected = record
            }
            guard surfaces[key] == 0 || surfaces[key] == input.surface else { throw error("Surface normalization") }
            try check(actual.storage,expected,label)
        }
        var sources: [String:Source] = [:]
        for source in c.sources {
            let raw = try blob(source.dib);guard raw.count >= 40 else { throw error("DIB extent") }
            let record = try OriginalStateRecord(bytes: raw,defined: [Bool](repeating: true,count: raw.count))
            guard try record.integer(at: 0,as: UInt32.self) >= 40, try record.integer(at: 4,as: Int32.self) == source.width,
                  try record.integer(at: 8,as: Int32.self) == source.height, source.width > 0, source.height > 0 else { throw error("DIB dimensions") }
            sources[source.path] = source
        }
        let returns: [UInt32] = [0x429812,0x429851,0x429890,0x4298cf,0x42990e,0x42994d,0x42998c,0x4299cb,0x429a0a,0x429a49,0x429a88]
        let parent = try MusicPlaybackReference.compare(music: music,round: round,replay: replay,control: control,local: local,loading: loading,catalog: catalog,sounds: sounds,onNatural: { initial,_ in
            callbacks += 1;guard callbacks == 1 else { throw error("Repeated parent callback") }
            var state = initial, loader = OriginalMenuResourceLoading()
            try check(state,globals(c.initialGlobals),"Initial resource globals")
            for (caseIndex,item) in c.cases.enumerated() {
                guard item.inherited == (caseIndex == 0), caseIndex != 0 || item.stimulus.isEmpty, item.endSP == 0x1000df48,
                      item.allocations.count == 0 || item.allocations.count == 11 else { throw error("Entry provenance") }
                for w in item.stimulus { for (i,b) in try hex(w.bytes).enumerated() { try state.write(b,at: Int(w.address)-OriginalMatchPreparation.globalBase+i) } }
                let inputs = Dictionary(uniqueKeysWithValues: item.inputs.map { ($0.index,$0) })
                guard inputs.count == item.calls.count else { throw error("Constructor input count") }
                var allocationIndex = 0, eventIndex = 0, checkpointIndex = 0
                let result = try loader.load(globals: &state,allocate: { index in
                    guard index == allocationIndex, index < item.allocations.count else { throw error("Allocation order") }
                    let a = item.allocations[index];allocationIndex += 1;allocations += 1
                    if a.address == 0 { nulls += 1;guard a.backing == nil, inputs[index] == nil else { throw error("Null allocation") };return .init(address: 0,backing: []) }
                    guard let backing = a.backing, let input = inputs[index], inputByAddress[a.address] == nil else { throw error("Allocation provenance") }
                    inputByAddress[a.address] = input
                    return try .init(address: a.address,backing: blob(backing))
                },source: { index,path in
                    guard let input = inputs[index], let source = sources[path], input.resource.path == path,
                          input.resource.present == (input.surface != 0), input.resource.width == (input.surface == 0 ? nil : source.width),
                          input.resource.height == (input.surface == 0 ? nil : source.height) else { throw error("Device/DIB input") }
                    return input.resource
                },deviceResult: { index in
                    guard let input = inputs[index] else { throw error("Missing device result") };return (input.surface,input.colorKeyResult)
                },checkpoint: { point,g,owned in
                    guard checkpointIndex < item.checkpoints.count else { throw error(item.label+" extra checkpoint") }
                    let expected = item.checkpoints[checkpointIndex];checkpointIndex += 1;checkpoints += 1
                    guard point == .init(expected.kind,index: expected.index) else { throw error("Checkpoint order") }
                    try check(g,globals(expected.globals),item.label+" \(point.kind) globals")
                    for record in expected.records {
                        guard let actual = owned[record.address] else { throw error("Checkpoint bitmap") }
                        try bitmap(record,actual,item.label+" \(point.kind) bitmap")
                    }
                },observe: { event in
                    guard eventIndex < item.events.count, event == item.events[eventIndex] else { throw error("\(item.label) event\(eventIndex): \(event)") }
                    eventIndex += 1;events += 1
                    if event.kind == .message { messages += 1 };if event.kind == .release { releases += 1 }
                })
                guard result.continuation == item.continuation, result.selectionAtEntry == item.selectionAtEntry,
                      item.endPC == (result.continuation == .ready ? 0x429e5a : 0x429b21), allocationIndex == item.allocations.count,
                      eventIndex == item.events.count, checkpointIndex == item.checkpoints.count, loader.bitmaps.count == item.records.count else { throw error(item.label+" continuation/lifetime") }
                if result.continuation == .nullSpark { faults += 1 }
                for call in item.calls {
                    guard (0..<11).contains(call.index), call.address == item.allocations[call.index].address,
                          call.returnAddress == returns[call.index], call.entrySP == 0x1000df38, call.returnSP == 0x1000df48, call.saved.count == 4 else { throw error("Constructor ret12 ABI") }
                    constructors += 1
                }
                try check(state,globals(item.globals),item.label+" final globals")
                for record in item.records {
                    guard let actual = loader.bitmaps[record.address] else { throw error("Retained bitmap") }
                    try bitmap(record,actual,item.label+" final bitmap")
                }
            }
        })
        guard callbacks == 1 else { throw error("Missing parent callback") }
        return .init(parent: parent,cases: c.cases.count,checkpoints: checkpoints,events: events,constructors: constructors,allocations: allocations,
                     nullAllocations: nulls,messages: messages,releases: releases,nullSpark: faults,records: records,bytes: bytes)
    }
}
