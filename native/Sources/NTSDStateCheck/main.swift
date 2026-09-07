import Foundation
import NTSDCore

private struct Corpus: Decodable { let exeSHA256: String; let cases: [Case] }
private struct Case: Decodable {
    let kind: String, label: String, initial: String, bytes: String
    let defined: [Bool]
}

private func decodeHex(_ text: String) throws -> [UInt8] {
    let chars = Array(text.utf8)
    guard chars.count % 2 == 0 else { throw OriginalStateError.invalidStorage("Odd hexadecimal length") }
    return try stride(from: 0, to: chars.count, by: 2).map {
        guard let byte = UInt8(String(decoding: chars[$0..<($0 + 2)], as: UTF8.self), radix: 16) else {
            throw OriginalStateError.invalidStorage("Invalid hexadecimal bytes")
        }
        return byte
    }
}

do {
    guard CommandLine.arguments.count == 2 else {
        throw OriginalStateError.invalidStorage("Usage: NTSDStateCheck oracle.json")
    }
    let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
          !corpus.cases.isEmpty else { throw OriginalStateError.invalidStorage("Unknown or empty corpus") }
    var checked = 0
    for item in corpus.cases {
        let initial = try decodeHex(item.initial), expected = try decodeHex(item.bytes)
        let actual: OriginalStateRecord
        switch item.kind {
        case "actor": actual = try .actor(over: initial)
        case "world": actual = try .worldPrefix(over: initial)
        default: throw OriginalStateError.invalidStorage("Unknown constructor: \(item.kind)")
        }
        guard actual.bytes.count == expected.count, actual.defined.count == item.defined.count else {
            throw OriginalStateError.invalidStorage("\(item.label): corpus lengths differ")
        }
        for offset in expected.indices {
            guard actual.bytes[offset] == expected[offset], actual.defined[offset] == item.defined[offset] else {
                throw OriginalStateError.invalidStorage("\(item.label) +0x\(String(offset, radix: 16)): " +
                    "actual byte=\(actual.bytes[offset]), defined=\(actual.defined[offset]); " +
                    "original byte=\(expected[offset]), defined=\(item.defined[offset])")
            }
            checked += 1
        }
    }
    print("Swift matches original constructors: \(corpus.cases.count) cases, \(checked) bytes and initialization flags")
} catch {
    FileHandle.standardError.write(Data("State comparison failed: \(error)\n".utf8)); exit(1)
}
