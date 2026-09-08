import Foundation
import NTSDCore

/// Original menu decisions consume the same native CRT state as initialization;
/// the resulting World/globals/table then flow into full match/replay comparison.
public enum MainMenuReference {
    public struct Result {
        public var initialization = RandomInitializationReference.Result()
        public var probes = 0, bytes = 0, tables = 0, formats = 0, events = 0, networkFailures = 0, mouseMessages = 0
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let bytes: String, defined: String }
    private struct Snapshot: Decodable { let globals: String, world: Record, crtState: UInt32 }
    private struct Write: Decodable { let address: UInt32, bytes: String }
    private struct Table: Decodable { let calls: Int, sha256: String }
    private struct Format: Decodable { let result: Int, bytes: String }
    private struct Mouse: Decodable {
        let input: OriginalMenuMouseInput, beforeGlobals: String, afterGlobals: String, result: Int32
        let stackAfter: UInt32, savedRegisters: [UInt32]
    }
    private struct Probe: Decodable {
        let label: String, input: OriginalMainMenuInput, stimulus: [Write]
        let before: Snapshot, after: Snapshot, events: [OriginalMainMenuEvent], tables: [Table], formats: [Format]
        let mouse: [Mouse]
        let exit: OriginalMainMenuExit, endPC: String, stackAfter: UInt32
    }
    private struct Case: Decodable { let mainMenu: [Probe] }
    private struct Corpus: Decodable {
        let worldAddress: UInt32, catalogAddress: UInt32, actorAddresses: [UInt32]
        let cases: [Case], blobs: [String: Blob]
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Main menu reference: \(text)") }
    private static func hex(_ text: String) throws -> [UInt8] {
        let bytes = Array(text.utf8)
        guard bytes.count % 2 == 0 else { throw error("Hex width") }
        return try stride(from: 0, to: bytes.count, by: 2).map { i in
            guard let value = UInt8(String(decoding: bytes[i..<(i+2)], as: UTF8.self), radix: 16) else { throw error("Invalid hex") }
            return value
        }
    }

    public static func compare(loaded: Data, corpora: [Data]) throws -> Result {
        let inputs = try corpora.map { try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack($0)) }
        var result = Result()
        result.initialization = try RandomInitializationReference.compare(loaded: loaded, corpora: corpora) { corpusIndex, caseIndex, state, crt in
            let corpus = inputs[corpusIndex]
            var cache: [String: [UInt8]] = [:]
            func blob(_ key: String) throws -> [UInt8] {
                if let bytes = cache[key] { return bytes }
                guard let b = corpus.blobs[key] else { throw error("Missing blob") }
                let bytes = try MatchPreparationReference.inflate(b.deflate, count: b.count)
                guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob digest") }
                cache[key] = bytes; return bytes
            }
            func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
                guard actual.bytes.count == expected.bytes.count else { throw error("\(label): size") }
                if actual != expected {
                    let offset = actual.bytes.indices.first { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }!
                    throw error("\(label)+\(String(offset, radix: 16)): \(actual.bytes[offset]) vs \(expected.bytes[offset])")
                }
                result.bytes += actual.bytes.count
            }
            func snapshot(_ expected: Snapshot, _ label: String) throws {
                let raw = try blob(expected.globals)
                try check(state.globals, .init(bytes: raw, defined: [Bool](repeating: true, count: raw.count)), label+" globals")
                let mask = try blob(expected.world.defined)
                guard mask.allSatisfy({ $0 < 2 }), corpus.actorAddresses.count == 400 else { throw error("World mask/inventory") }
                var world = try OriginalStateRecord(bytes: blob(expected.world.bytes), defined: mask.map { $0 == 1 })
                guard try world.integer(at: 0x7d4, as: UInt32.self) == corpus.catalogAddress else { throw error("World catalog binding") }
                try world.write(UInt32(0), at: 0x7d4)
                for (index, pointer) in corpus.actorAddresses.enumerated() {
                    guard try world.integer(at: 0x194+index*4, as: UInt32.self) == pointer else { throw error("World Actor binding") }
                    try world.write(UInt32(index), at: 0x194+index*4)
                }
                try check(state.world, world, label+" World")
                guard crt.state == expected.crtState else { throw error("\(label): CRT state") }
            }
            for probe in corpus.cases[caseIndex].mainMenu {
                for write in probe.stimulus {
                    let bytes = try hex(write.bytes)
                    guard bytes.count == 4 else { throw error("Input width") }
                    if write.address == corpus.worldAddress {
                        for (i, byte) in bytes.enumerated() { try state.world.write(byte, at: i) }
                    } else {
                        guard [0x453da4,0x4546f0,0x453cdc,0x44d060,0x457580,0x44d064,0x4511e0,
                               0x45117c,0x4511a0,0x4546f4,0x458420].contains(write.address) else { throw error("Unrecovered menu input") }
                        for (i, byte) in bytes.enumerated() { try state.globals.write(byte, at: Int(write.address)-OriginalMatchPreparation.globalBase+i) }
                    }
                }
                var events: [OriginalMainMenuEvent] = []
                for mouse in probe.mouse {
                    func checkMouse(_ key: String) throws {
                        let bytes = try blob(key)
                        try check(state.globals, .init(bytes: bytes, defined: [Bool](repeating: true, count: bytes.count)), probe.label+" mouse globals")
                    }
                    try checkMouse(mouse.beforeGlobals)
                    let returned = try state.receiveMenuMouse(mouse.input) { events.append($0) }
                    guard returned == mouse.result, mouse.stackAfter == 0x1000f014,
                          mouse.savedRegisters == [0x11111111,0x22222222,0x33333333,0x44444444] else { throw error("Mouse ABI/return") }
                    try checkMouse(mouse.afterGlobals)
                    result.mouseMessages += 1
                }
                try snapshot(probe.before, probe.label+" before")
                let exit = try state.runMainMenu(crt: &crt, input: probe.input) { events.append($0) }
                guard events == probe.events else {
                    let i = zip(events, probe.events).enumerated().first { $0.element.0 != $0.element.1 }?.offset
                    throw error("\(probe.label): event order/value at \(i.map(String.init) ?? "count"), \(events.count) vs \(probe.events.count)")
                }
                guard exit == probe.exit, probe.endPC == (exit == .present ? "0x42873e" : "0x4287de"),
                      probe.stackAfter == 0x1000f000,
                      probe.tables.count == events.filter({ $0.kind == .randomTable }).count,
                      probe.tables.allSatisfy({ $0.calls == 3000 && $0.sha256.count == 64 }) else { throw error("Menu exit/generator witness") }
                let formatted = events.filter { $0.kind == .formatAddress }
                guard formatted.count == probe.formats.count else { throw error("Format count") }
                for (event, format) in zip(formatted, probe.formats) {
                    guard event.strings.count == 1, format.result == event.strings[0].count,
                          try hex(format.bytes) == event.strings[0]+[0] else { throw error("Real sprintf witness") }
                }
                try snapshot(probe.after, probe.label+" after")
                result.probes += 1; result.events += events.count; result.tables += probe.tables.count; result.formats += formatted.count
                if exit == .returnWithoutPresentation { result.networkFailures += 1 }
            }
        }
        return result
    }
}
