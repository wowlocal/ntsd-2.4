import Foundation
import NTSDCore

/// Checks captured original parent bytes/masks and boundary call order. Child
/// contents remain opaque; no loaded-object equality is inferred here.
public enum CatalogReference {
    public struct Result { public let cases: Int, records: Int, bytes: Int, requests: Int }
    private struct Corpus: Decodable { let exeSHA256: String; let cases: [Case] }
    private struct Case: Decodable {
        let label: String, source: String, fileName: String
        let initialChecksum: UInt32, checksum: UInt32
        let records: [Record], events: [OriginalCatalogLoadRequest]
        let outerTokens: [String]
        let objectAddresses: [UInt32], bitmapAddresses: [UInt32]
    }
    private struct Record: Decodable { let offset: Int; let initial: String, bytes: String, defined: String }

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
            throw OriginalStateError.invalidStorage("Unknown or empty catalog corpus")
        }
        var bytes = 0, records = 0, requests = 0
        for item in corpus.cases {
            guard Set(item.records.map(\.offset)) == Set(OriginalCatalogRegistry.regionSizes.keys), item.records.count == 4,
                  Set(item.objectAddresses).count == item.objectAddresses.count,
                  Set(item.bitmapAddresses).count == 4, item.bitmapAddresses.count == 4 else {
                throw OriginalStateError.invalidStorage("\(item.label): incomplete or aliased storage")
            }
            var backing: [Int: OriginalStateRecord] = [:]
            for record in item.records {
                let initial = try hex(record.initial)
                backing[record.offset] = try .init(bytes: initial, defined: Array(repeating: false, count: initial.count))
            }
            let native = try OriginalCatalogRegistry(source: hex(item.source), fileName: hex(item.fileName),
                                                     initialChecksum: item.initialChecksum, backing: backing)
            guard native.requests == item.events, native.parentChecksum == item.checksum,
                  native.outerTokens == (try item.outerTokens.map { try hex($0) }) else {
                throw OriginalStateError.invalidStorage("\(item.label): child calls or parent checksum/token order differ")
            }
            let objects = item.events.filter { $0.kind == .object }
            guard objects.count == item.objectAddresses.count else { throw OriginalStateError.invalidStorage("Missing object allocation") }
            for record in item.records {
                let mask = try hex(record.defined)
                guard mask.allSatisfy({ $0 <= 1 }) else { throw OriginalStateError.invalidStorage("Invalid initialization mask") }
                var expected = try OriginalStateRecord(bytes: hex(record.bytes), defined: mask.map { $0 == 1 })
                func bind(_ address: UInt32, ordinal: Int, offset: Int) throws {
                    guard address != 0, try expected.integer(at: offset, as: UInt32.self) == address else {
                        throw OriginalStateError.invalidStorage("Wrong/null/undefined original catalog pointer")
                    }
                    try expected.write(UInt32(ordinal), at: offset)
                }
                if record.offset == 0 {
                    for (i, address) in item.objectAddresses.enumerated() { try bind(address, ordinal: i, offset: i * 4) }
                } else if record.offset == 0x4d81060 {
                    for (i, offset) in [0x98c, 0x914, 0x918, 0x91c].enumerated() {
                        try bind(item.bitmapAddresses[i], ordinal: i, offset: offset)
                    }
                }
                guard let actual = native.records[record.offset], actual.bytes.count == expected.bytes.count else {
                    throw OriginalStateError.invalidStorage("Missing catalog region")
                }
                if let offset = actual.bytes.indices.first(where: { actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }) {
                    throw OriginalStateError.invalidStorage("\(item.label) Catalog+\(String(record.offset + offset, radix: 16)): byte/mask differs")
                }
                records += 1; bytes += expected.bytes.count
            }
            requests += native.requests.count
        }
        return Result(cases: corpus.cases.count, records: records, bytes: bytes, requests: requests)
    }
}
