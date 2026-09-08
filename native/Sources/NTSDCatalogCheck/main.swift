import Foundation
import NTSDReferenceChecks

do {
    if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--match-prelude" {
        let loaded = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let corpora = try CommandLine.arguments.dropFirst(3).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let result = try MatchPreludeReference.compare(loaded: loaded, corpora: corpora)
        print("Match prelude matches original: \(result.cases) cases, \(result.bytes) global bytes/masks, \(result.formatCalls) real CRT calls, \(result.soundCalls) sound methods, \(result.fills) fills; chained preparation: \(result.replay.preparation.records) records, \(result.replay.preparation.bytes) bytes/masks; recording: \(result.replay.buffers) buffers, \(result.replay.bytes) bytes/masks, \(result.replay.allocations) allocations / \(result.replay.releases) releases")
        exit(0)
    }
    if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--replay-initialization" {
        let loaded = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let corpora = try CommandLine.arguments.dropFirst(3).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let result = try ReplayInitializationReference.compare(loaded: loaded, corpora: corpora)
        print("Replay initialization matches original: \(result.buffers) complete buffers, \(result.bytes) bytes/masks, \(result.allocations) allocations / \(result.releases) releases; \(result.preparation.cases) chained preparations, \(result.preparation.records) state records, \(result.preparation.bytes) state bytes/masks")
        exit(0)
    }
    if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--match-preparation" {
        let loaded = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let corpora = try CommandLine.arguments.dropFirst(3).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let result = try MatchPreparationReference.compare(loaded: loaded, corpora: corpora)
        print("Match preparation matches original: \(result.cases) cases, \(result.records) records, \(result.bytes) bytes/masks, \(result.constructors) constructors, \(result.randomCalls) RNG calls, \(result.bitmaps) new bitmaps, \(result.releases) releases")
        exit(0)
    }
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
