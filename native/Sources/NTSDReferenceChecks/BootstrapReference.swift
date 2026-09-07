import CryptoKit
import Foundation
import NTSDCore

/// Development-only corpus reader; the native application does not depend on this target.
public enum BootstrapReference {
    public struct Result {
        public let cases: Int, checkpoints: Int, records: Int, bytes: Int
    }
    private struct Corpus: Decodable { let exeSHA256: String; let cases: [Case]; let blobs: [String: String] }
    private struct Case: Decodable {
        let label: String, actorInitial: String, worldInitial: String
        let selector: Int32, firstObjectWord90: Int32
        let addresses: Addresses
        let checkpoints: [Checkpoint]
    }
    private struct Addresses: Decodable { let world: UInt32, catalog: UInt32, object: UInt32; let actors: [UInt32] }
    private struct Checkpoint: Decodable {
        let name: String, world: Record
        let actors: [Record]
        let allocations: Int, constructorSlots: [Int]
    }
    private struct Record: Decodable { let bytes: String, defined: String }

    private static func hex(_ text: String) throws -> [UInt8] {
        let chars = Array(text.utf8)
        guard chars.count % 2 == 0 else { throw OriginalStateError.invalidStorage("Odd hex length") }
        return try stride(from: 0, to: chars.count, by: 2).map { index in
            guard let byte = UInt8(String(decoding: chars[index..<(index + 2)], as: UTF8.self), radix: 16) else {
                throw OriginalStateError.invalidStorage("Invalid hex")
            }
            return byte
        }
    }

    public static func compare(_ data: Data) throws -> Result {
        let corpus = try JSONDecoder().decode(Corpus.self, from: data)
        guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c", !corpus.cases.isEmpty else {
            throw OriginalStateError.invalidStorage("Unknown or empty bootstrap corpus")
        }
        let blobs = try corpus.blobs.mapValues { try hex($0) }
        for (digest, bytes) in blobs {
            let actual = SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
            guard actual == digest else { throw OriginalStateError.invalidStorage("Corrupt bootstrap blob: \(digest)") }
        }
        func record(_ item: Record) throws -> OriginalStateRecord {
            guard let bytes = blobs[item.bytes], let mask = blobs[item.defined], mask.allSatisfy({ $0 <= 1 }) else {
                throw OriginalStateError.invalidStorage("Missing blob or invalid initialization mask")
            }
            return try OriginalStateRecord(bytes: bytes, defined: mask.map { $0 == 1 })
        }
        func bind(_ expectedAddress: UInt32, ordinal: UInt32, offset: Int, in record: inout OriginalStateRecord) throws {
            guard try record.integer(at: offset, as: UInt32.self) == expectedAddress, expectedAddress != 0 else {
                throw OriginalStateError.invalidStorage("Wrong/uninitialized/null bootstrap pointer at \(offset)")
            }
            try record.write(ordinal, at: offset)
        }
        var bytesChecked = 0, recordsChecked = 0, checkpoints = 0
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, label: String) throws {
            guard actual.bytes.count == expected.bytes.count else { throw OriginalStateError.invalidStorage("\(label): size differs") }
            if let offset = actual.bytes.indices.first(where: { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
                throw OriginalStateError.invalidStorage("\(label) +0x\(String(offset, radix: 16)): byte or initialization mask differs")
            }
            bytesChecked += actual.bytes.count; recordsChecked += 1
        }
        for item in corpus.cases {
            guard item.addresses.actors.count == 400, Set(item.addresses.actors).count == 400,
                  item.checkpoints.map(\.name) == ["allocated", "staged"] else {
                throw OriginalStateError.invalidStorage("\(item.label): incomplete pool/checkpoints")
            }
            var actual = try OriginalWorldBootstrap(worldBacking: hex(item.worldInitial),
                actorBacking: Array(repeating: hex(item.actorInitial), count: 400), selector: item.selector)
            for checkpoint in item.checkpoints {
                if checkpoint.name == "staged" { try actual.activateStagingActors(firstObjectWord90: item.firstObjectWord90) }
                let calls = Array(0..<400) + (checkpoint.name == "staged" ? Array(0..<8) : [])
                guard checkpoint.allocations == 400, checkpoint.constructorSlots == calls, checkpoint.actors.count == 400 else {
                    throw OriginalStateError.invalidStorage("\(item.label): allocation/constructor order differs")
                }
                var world = try record(checkpoint.world)
                try bind(item.addresses.catalog, ordinal: 0, offset: 0x7d4, in: &world)
                for slot in 0..<400 {
                    try bind(item.addresses.actors[slot], ordinal: UInt32(slot), offset: 0x194 + slot * 4, in: &world)
                    var actor = try record(checkpoint.actors[slot])
                    try bind(item.addresses.object, ordinal: 0, offset: 0x368, in: &actor)
                    try check(actual.actors[slot], actor, label: "\(item.label) \(checkpoint.name) Actor \(slot)")
                }
                try check(actual.world, world, label: "\(item.label) \(checkpoint.name) World")
                checkpoints += 1
            }
        }
        return Result(cases: corpus.cases.count, checkpoints: checkpoints, records: recordsChecked, bytes: bytesChecked)
    }
}
