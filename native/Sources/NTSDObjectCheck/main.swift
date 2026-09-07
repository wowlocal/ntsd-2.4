import Foundation
import NTSDReferenceChecks

do {
    guard CommandLine.arguments.count == 2 else { throw NSError(domain: "Usage: NTSDObjectCheck corpus.json", code: 1) }
    let result = try ObjectReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    print("Object stream matches original: \(result.objects) objects, \(result.occurrences) frame occurrences, \(result.finalFrames) final frames, \(result.bytes) storage bytes and masks, \(result.bitmaps) bitmap wrappers, \(result.rawFrames) raw Frame checkpoints, \(result.allocations) Frame allocations; shared checksum/sound cache checked separately")
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
