import Foundation
import NTSDCore

struct Corpus: Decodable { let exeSHA256: String; let cases: [Case] }
struct Case: Decodable { let label: String; let definitions: [String]; let snapshots: [OriginalFrameRecord] }

do {
    guard CommandLine.arguments.count == 2 else { throw OriginalLoaderError.outsideVerifiedDomain("Usage: NTSDFrameCheck oracle.json") }
    let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let corpus = try JSONDecoder().decode(Corpus.self, from: data)
    guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c" else {
        throw OriginalLoaderError.outsideVerifiedDomain("Unknown oracle EXE hash")
    }
    var checked = 0
    for item in corpus.cases {
        guard !item.definitions.isEmpty, item.definitions.count == item.snapshots.count else {
            throw OriginalLoaderError.outsideVerifiedDomain("Invalid fixture: \(item.label)")
        }
        var loader = OriginalFrameLoader()
        for (index, source) in item.definitions.enumerated() {
            let actual = try loader.apply(source), expected = item.snapshots[index]
            guard actual == expected else {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let details = "\(item.label), occurrence \(index)\nActual: \(String(decoding: try encoder.encode(actual), as: UTF8.self))\nExpected: \(String(decoding: try encoder.encode(expected), as: UTF8.self))"
                throw OriginalLoaderError.outsideVerifiedDomain(details)
            }
            checked += 1
        }
    }
    print("Swift matches original x86 frame records: \(checked) definitions in \(corpus.cases.count) groups")
} catch {
    FileHandle.standardError.write(Data("Frame comparison failed: \(error)\n".utf8)); exit(1)
}
