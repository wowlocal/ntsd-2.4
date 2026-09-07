import Foundation
import NTSDReferenceChecks

do {
    guard CommandLine.arguments.count == 2 else { throw NSError(domain: "Usage: NTSDBGCheck corpus.json", code: 1) }
    let result = try BackgroundReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    print("Backgrounds match original: \(result.calls) calls, \(result.parses) parses, \(result.bitmaps) bitmap wrappers, \(result.releases) releases, \(result.bytes) complete record bytes/masks; decoder, checksum and resource order checked")
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
