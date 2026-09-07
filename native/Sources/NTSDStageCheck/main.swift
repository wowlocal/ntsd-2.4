import Foundation
import NTSDReferenceChecks

do {
    guard CommandLine.arguments.count == 2 else { throw NSError(domain: "Usage: NTSDStageCheck corpus.json", code: 1) }
    let result = try StageReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    print("Stage loader matches original: \(result.loads) loads, \(result.initializations) stage initializations, \(result.phases) phases, \(result.checkpoints) checkpoints, \(result.records) complete records / \(result.bytes) bytes and masks")
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
