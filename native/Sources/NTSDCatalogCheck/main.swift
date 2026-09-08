import Foundation
import NTSDReferenceChecks

do {
    if CommandLine.arguments.count == 6, CommandLine.arguments[1] == "--local-input" {
        let values = try CommandLine.arguments.dropFirst(2).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let r = try LocalInputReference.compare(input: values[0],loading: values[1],catalog: values[2],sounds: values[3])
        print("Local input matches original: \(r.cases) cases, \(r.calls) real ret12, \(r.records) records, \(r.bytes) bytes/masks, \(r.characterAI) character AI /\(r.objectInput) object requests at explicit child boundaries; full first loading \(r.initial.commonLoads)+\(r.initial.catalog.calls) WAVs /\(r.initial.catalog.catalog.objects) Objects")
        exit(0)
    }
    if CommandLine.arguments.count == 5, CommandLine.arguments[1] == "--initial-loading" {
        let r = try InitialLoadingReference.compare(loading: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])), catalog: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3])), sounds: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[4])))
        print("Initial loading matches original: \(r.commonLoads) common +\(r.catalog.calls) registry WAVs, \(r.catalog.catalog.objects) Objects, \(r.poolConstructors) Actor /\(r.interfaceConstructors) UI constructors, \(r.bytes) loading +\(r.catalog.bytes) audio +\(r.catalog.catalog.bytes) catalog bytes/masks, \(r.records) loading records, \(r.events) loading events, checksum \(r.catalog.catalog.checksum)")
        exit(0)
    }
    if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--catalog-sounds" {
        let r = try CatalogSoundsReference.compare(catalog: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])), sounds: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3])))
        print("Catalog sounds match original: \(r.catalog.objects) Objects, \(r.catalog.frames) Frames, \(r.calls) real WAV loads (\(r.weaponCalls) weapon / \(r.frameCalls) frame), \(r.sources) source files, \(r.bytes) audio bytes/masks + \(r.catalog.bytes) catalog bytes/masks, \(r.events) audio events, \(r.restores) restores, checksum \(r.catalog.checksum)")
        exit(0)
    }
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--initial-interface" {
        let r = try InitialInterfaceReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Initial interface matches original: \(r.cases) passes, \(r.sources) embedded DIBs, \(r.constructors) bitmap / \(r.poolConstructors) Actor constructors, \(r.records) records, \(r.bytes) bytes/masks, \(r.events) events, \(r.nullAllocations) null allocations, \(r.messages) messages, \(r.releases) surface releases")
        exit(0)
    }
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--wave-loader" {
        let result = try WaveLoaderReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Wave loader matches original: \(result.sources) source WAVs, \(result.cases) cases, \(result.startupPasses) startup passes / \(result.startupLoads) real child loads, \(result.bytes) bytes/masks, \(result.events) events, \(result.restores) restores, \(result.messages) messages, \(result.leaks) retained short-read allocations, \(result.invalidContinuations) invalid create continuations")
        exit(0)
    }
    if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--menu-presentation" {
        let loaded = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let corpora = try CommandLine.arguments.dropFirst(3).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let result = try MenuPresentationReference.compare(loaded: loaded, corpora: corpora)
        print("Menu presentation matches original: \(result.steps) returns, \(result.transitions) World1-to-2 transitions, \(result.bytes) bytes/masks, \(result.events) events, \(result.formats) actual CRT formats, \(result.frees) frees, \(result.quits) quit requests; \(result.menu.probes) menu probes, \(result.menu.initialization.match.cases) chained match/recording preparations, \(result.menu.initialization.match.replay.bytes) recording bytes/masks")
        exit(0)
    }
    if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--main-menu" {
        let loaded = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let corpora = try CommandLine.arguments.dropFirst(3).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let result = try MainMenuReference.compare(loaded: loaded, corpora: corpora)
        print("Main menu matches original: \(result.probes) probes, \(result.mouseMessages) mouse messages, \(result.bytes) bytes/masks, \(result.events) events, \(result.tables) menu-generated tables, \(result.formats) actual CRT formats, \(result.networkFailures) network error exits; \(result.initialization.match.cases) chained match/recording preparations, \(result.initialization.match.replay.bytes) recording bytes/masks")
        exit(0)
    }
    if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--random-initialization" {
        let loaded = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let corpora = try CommandLine.arguments.dropFirst(3).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let result = try RandomInitializationReference.compare(loaded: loaded, corpora: corpora)
        print("Random initialization matches original: \(result.tables) tables, \(result.seedCalls) seeds, \(result.tableCalls) table / \(result.interveningCalls) intervening real CRT draws, \(result.bytes) global bytes/masks; chained preparation: \(result.match.replay.preparation.records) records, \(result.match.replay.preparation.bytes) bytes/masks, \(result.match.replay.preparation.randomCalls) game RNG calls; recording: \(result.match.replay.buffers) buffers, \(result.match.replay.bytes) bytes/masks")
        exit(0)
    }
    if CommandLine.arguments.count >= 5, CommandLine.arguments[1] == "--match-continuation", CommandLine.arguments.count % 2 == 1 {
        let loaded = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        var parents: [Data] = [], corpora: [Data] = []
        for i in stride(from: 3, to: CommandLine.arguments.count, by: 2) {
            parents.append(try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[i])))
            corpora.append(try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[i+1])))
        }
        let result = try MatchContinuationReference.compare(loaded: loaded, parents: parents, corpora: corpora)
        print("Match continuation matches original: \(result.cases) returns, \(result.records) records, \(result.bytes) bytes/masks, \(result.randomCalls) RNG calls, \(result.constructors) constructors, \(result.bitmaps) bitmaps; parent: \(result.parent.cases) complete prelude/preparation/recording chains")
        exit(0)
    }
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
