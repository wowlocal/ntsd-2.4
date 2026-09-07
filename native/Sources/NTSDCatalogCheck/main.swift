import Foundation
import NTSDReferenceChecks

do {
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--loaded" {
        let result = try LoadedCatalogReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Loaded catalog matches original: \(result.objects) objects, \(result.backgrounds) backgrounds, \(result.stages) stages / \(result.phases) phases, \(result.frames) frame occurrences, \(result.bitmaps) bitmaps, \(result.allocations) Frame allocations, \(result.bytes) bytes/masks, checksum \(result.checksum)")
        exit(0)
    }
    guard CommandLine.arguments.count == 2 else { throw NSError(domain: "Usage: NTSDCatalogCheck corpus.json", code: 1) }
    let result = try CatalogReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    print("Catalog parent matches original: \(result.cases) cases, \(result.records) records, \(result.bytes) bytes/masks, \(result.requests) ordered load requests")
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
