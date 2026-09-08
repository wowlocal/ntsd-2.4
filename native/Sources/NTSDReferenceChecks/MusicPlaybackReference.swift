import Foundation
import NTSDCore

public enum MusicPlaybackReference {
    public struct Result {
        public let parent: MatchRoundReference.Result
        public let cases: Int, events: Int, calls: Int, allocations: Int, records: Int, bytes: Int, messages: Int, formats: Int
    }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Allocation: Decodable { let address: UInt32, storage: Storage }
    private struct Event: Decodable {
        let kind: OriginalMusicEvent.Kind, arguments: [UInt32], strings: [[UInt8]], response: OriginalMusicResponse
    }
    private struct Call: Decodable { let entry: UInt32, entrySP: UInt32, returnAddress: UInt32, saved: [UInt32], returnSP: UInt32, returned: UInt32 }
    private struct Format: Decodable { let result: Int32, bytes: String }
    private struct Case: Decodable {
        let label: String, path: [UInt8], kind: String, inherited: Bool, stimulus: [InputControlReference.GlobalWrite]
        let events: [Event], calls: [Call], formats: [Format], afterGlobals: String, allocations: [Allocation], endPC: UInt32, endSP: UInt32
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, dllSHA256: String, control: Bool, parents: [String:InputControlReference.Parent]
        let initialContext: InputControlReference.Snapshot, cases: [Case], blobs: [String:InputControlReference.Blob]
    }
    private struct Round: Decodable {
        struct Case: Decodable { let after: InputControlReference.Snapshot }
        let cases: [Case]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Music reference: "+text) }
    private static func hex(_ text: String) throws -> [UInt8] {
        let b = Array(text.utf8); guard b.count%2 == 0 else { throw error("Hex extent") }
        func digit(_ x: UInt8) throws -> UInt8 {
            switch x { case 48...57:return x-48;case 97...102:return x-87;default:throw error("Hex digit") }
        }
        return try stride(from: 0,to: b.count,by: 2).map { try digit(b[$0])*16+digit(b[$0+1]) }
    }
    public static func compare(music: Data, round: Data, replay: Data, control: Data, local: Data,
                               loading: Data, catalog: Data, sounds: Data) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(music,maximumCount: 128_000_000))
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d", !c.cases.isEmpty else { throw error("Original identity") }
        for (key,data) in [("match-round",round),("replay-tick",replay),("input-control",control),("local-input",local),
                           ("initial-loading",loading),("initial-loading-catalog",catalog),("initial-loading-sounds",sounds)] {
            guard let pin = c.parents[key], MatchPreparationReference.digest(data) == pin.sha256 else { throw error("Parent SHA "+key) }
        }
        // Exact blob identities connect ALL initial state to the independently
        // compared first round. No after-state is supplied to the native engine.
        let sourceRound = try JSONDecoder().decode(Round.self,from: MatchPreparationReference.unpack(round,maximumCount: 128_000_000))
        guard c.initialContext == sourceRound.cases.first?.after else { throw error("Round continuation identity") }
        var blobs: [String:[UInt8]] = [:], callbacks = 0, events = 0, calls = 0, allocations = 0, records = 0, bytes = 0, messages = 0, formats = 0
        func blob(_ key: String) throws -> [UInt8] {
            if let raw = blobs[key] { return raw }
            guard let item = c.blobs[key], (0...8_000_000).contains(item.count) else { throw error("Blob extent") }
            let raw = try MatchPreparationReference.inflate(item.deflate,count: item.count,maximumCount: 8_000_000)
            guard MatchPreparationReference.digest(Data(raw)) == key else { throw error("Blob SHA") }
            blobs[key] = raw; return raw
        }
        func check(_ actual: OriginalStateRecord, _ raw: [UInt8], _ mask: [UInt8], _ label: String) throws {
            guard actual.bytes.count == raw.count, raw.count == mask.count, mask.allSatisfy({ $0<2 }) else { throw error(label+" extent/mask") }
            if let i = raw.indices.first(where: { actual.bytes[$0] != raw[$0] || actual.defined[$0] != (mask[$0] == 1) }) {
                throw error("\(label)+\(String(i,radix:16)): \(actual.bytes[i])/\(actual.defined[i]) vs \(raw[i])/\(mask[i])")
            }
            records += 1; bytes += raw.count
        }
        let parent = try MatchRoundReference.compare(round: round,replay: replay,control: control,local: local,loading: loading,catalog: catalog,sounds: sounds,onNatural: { initial,_,continuation in
            callbacks += 1
            guard callbacks == 1, continuation == (c.control ? .pausedRendering : .menu) else { throw error("Natural caller") }
            var globals = initial.globals, memory = OriginalMusicMemory()
            let fullMask = [UInt8](repeating: 1,count: OriginalMatchPreparation.globalSize)
            try check(globals,blob(c.initialContext.globals),fullMask,"Initial globals")
            for (index,item) in c.cases.enumerated() {
                guard item.inherited == (index == 0 && !c.control), index != 0 || (item.kind == "menu" && item.stimulus.isEmpty) else { throw error("Initial entry provenance") }
                for w in item.stimulus {
                    for (i,b) in try hex(w.bytes).enumerated() { try globals.write(b,at: Int(w.address)-OriginalMatchPreparation.globalBase+i) }
                }
                var eventIndex = 0, formatIndex = 0
                let request: OriginalMusicPlayback.Request = { event in
                    guard eventIndex < item.events.count else { throw error(item.label+" extra request") }
                    let expected = item.events[eventIndex];eventIndex += 1;events += 1
                    guard event == .init(expected.kind,expected.arguments,expected.strings) else {
                        throw error("\(item.label) event\(eventIndex): \(event) vs \(expected.kind)/\(expected.arguments)/\(expected.strings)")
                    }
                    if event.kind == .allocate { allocations += 1 }
                    if event.kind == .message { messages += 1 }
                    if event.kind == .format {
                        guard formatIndex < item.formats.count else { throw error("Missing actual CRT format") }
                        let format = item.formats[formatIndex];formatIndex += 1;formats += 1
                        guard event.arguments == [UInt32(bitPattern: format.result)], event.strings.count == 2,
                              try hex(format.bytes) == event.strings[1]+[0] else { throw error("CRT format witness") }
                    }
                    return expected.response
                }
                if item.kind == "menu" {
                    guard item.endPC == 0x4297ae, item.endSP == 0x1000df48 else { throw error("Menu prologue/stack") }
                    try OriginalMusicPlayback.enterMenu(globals: &globals,memory: &memory,request: request)
                } else {
                    guard item.kind == "play", item.endPC == 0x30000000, item.endSP == 0x1000f008 else { throw error("Music return/stack") }
                    try OriginalMusicPlayback.play(item.path,globals: &globals,memory: &memory,request: request)
                }
                guard eventIndex == item.events.count, formatIndex == item.formats.count else { throw error(item.label+" missing request") }
                let helpers = item.events.filter { $0.kind == .helper }
                guard helpers.count == item.calls.count else { throw error("Helper call count") }
                let returns: [UInt32:[UInt32]] = [0x402020:[0x4297ab,0x30000000],0x401d30:[0x402085],0x401c90:[0x40208a],0x401da0:[0x4020a2],0x401f30:[0x4020c9]]
                for call in item.calls {
                    guard returns[call.entry]?.contains(call.returnAddress) == true, call.returnSP == call.entrySP+4, call.saved.count == 4 else { throw error("Real helper ABI") }
                    calls += 1
                }
                guard helpers.map({ $0.arguments[0] }).sorted() == item.calls.map(\.entry).sorted(), memory.allocations.count == item.allocations.count else { throw error("Helpers/allocation lifetime") }
                try check(globals,blob(item.afterGlobals),fullMask,item.label+" globals")
                for allocation in item.allocations {
                    guard let actual = memory.allocations[allocation.address] else { throw error("Missing retained allocation") }
                    try check(actual,blob(allocation.storage.bytes),blob(allocation.storage.defined),item.label+" wide path")
                }
            }
        })
        guard callbacks == 1 else { throw error("Missing parent callback") }
        return .init(parent: parent,cases: c.cases.count,events: events,calls: calls,allocations: allocations,records: records,bytes: bytes,messages: messages,formats: formats)
    }
}
