import Foundation
import NTSDReferenceChecks

do {
    if CommandLine.arguments.count == 8,CommandLine.arguments[1] == "--mode-screen" {
        let inputs = try CommandLine.arguments.dropFirst(2).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let r = try ModeScreenReference.compare(screen: inputs[0],startup: inputs[1],menu: inputs[2],loading: inputs[3],catalog: inputs[4],sounds: inputs[5])
        print("Mode screen matches original: own startup -> \(r.cases) screens /\(r.playback) playback boundaries, \(r.draws) draws /\(r.keys) key names /\(r.backgrounds) backgrounds, \(r.events) events /\(r.helpers) helpers /\(r.records) records /\(r.bytes) bytes+masks. Whole ordinary screen ret16; worker/panel/playback file boundaries, app UI, selected match and Windows open")
        exit(0)
    }
    if CommandLine.arguments.count == 3,CommandLine.arguments[1] == "--mode-selection" {
        let r = try ModeSelectionReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Mode selection matches original: \(r.cases) cases /\(r.input) input /\(r.selections) selection /\(r.playback) playback boundaries, \(r.events) events /\(r.helpers) helpers /\(r.records) records /\(r.bytes) bytes+masks. Supplied caller probes; whole screen, startup integration, playback files, app UI and Windows open")
        exit(0)
    }
    if CommandLine.arguments.count == 7,CommandLine.arguments[1] == "--menu-startup" {
        let inputs = try CommandLine.arguments.dropFirst(2).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let r = try MenuStartupReference.compare(startup: inputs[0],menu: inputs[1],loading: inputs[2],catalog: inputs[3],sounds: inputs[4])
        print("Menu startup matches original: own \(r.parent.menu.cases) early calls/loading -> \(r.localCalls) local /\(r.receivedCalls) received calls -> round/menu -> \(r.musicCalls) music helpers /\(r.constructors) character-menu constructors; \(r.checkpoints) checkpoints /\(r.events) events /\(r.records) records /\(r.bytes) bytes+masks. Actual continuation reaches429e5a on the same World; selection dispatch, full match, app UI and Windows open")
        exit(0)
    }
    if CommandLine.arguments.count == 6,CommandLine.arguments[1] == "--menu-loading" {
        let inputs = try CommandLine.arguments.dropFirst(2).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let r = try MenuLoadingReference.compare(menu: inputs[0],loading: inputs[1],catalog: inputs[2],sounds: inputs[3])
        print("Menu to loading matches original: \(r.menu.cases) menu calls /\(r.menu.phases) phases -> \(r.loading.commonLoads)+\(r.loading.catalog.calls) WAVs /\(r.loading.catalog.catalog.objects) Objects /\(r.loading.poolConstructors) Actor /\(r.loading.interfaceConstructors) UI constructors; common bitmap \(r.draws) draws /\(r.reads) reads /\(r.clips) clips /\(r.blits) blits /\(r.helpers) helper returns; \(r.records) retained records /\(r.bytes) retained +\(r.loading.bytes) loading +\(r.loading.catalog.bytes) audio +\(r.loading.catalog.catalog.bytes) catalog bytes/masks; checksum \(r.loading.catalog.catalog.checksum). Same own World/globals/resources across the loading caller; full loading return, app UI and Windows open")
        exit(0)
    }
    if CommandLine.arguments.count == 3,CommandLine.arguments[1] == "--front-menu-loop" {
        let r = try FrontMenuLoopReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Front menu loop matches original: \(r.cases) calls /\(r.phases) phases /\(r.returns) returns /\(r.boundaries) boundaries /\(r.loading) loading entries; \(r.bodies) bodies /\(r.main) main menus /\(r.tails) tails /\(r.worldOne) World1 transitions; \(r.helpers) helper returns /\(r.events) events, \(r.draws) draws /\(r.reads) reads /\(r.clips) clips /\(r.blits) blits /\(r.fills) fills; \(r.constructors) constructors /\(r.frees) frees /\(r.tables) RNG tables /\(r.random) actual DLL draws; \(r.settings) settings calls /\(r.settingsReturns) returns /\(r.settingsEvents) writer events /\(r.prints) fprintf /\(r.fileWrites) writes /\(r.failedWrites) failed or short; \(r.records) records /\(r.bytes) bytes/masks, own first return \(r.parent.cases). Loading body, other selectors, app UI and Windows remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 3,CommandLine.arguments[1] == "--front-menu-completion" {
        let r = try FrontMenuCompletionReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Front menu completion matches original: \(r.cases) returns /\(r.main) main menus /\(r.tails) tails /\(r.worldOne) World1 transitions /\(r.errors) network exits, \(r.helpers) helper returns /\(r.events) events, \(r.draws) draws /\(r.reads) reads /\(r.clips) clips /\(r.blits) blits, \(r.tables) RNG tables /\(r.random) actual DLL draws, \(r.formats) formats /\(r.frees) frees /\(r.posts) quit requests; \(r.records) records /\(r.bytes) bytes/masks, own fresh alternate parent \(r.parent.cases). Screen loop, app UI and Windows remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 3,CommandLine.arguments[1] == "--front-screen-alternate" {
        let r = try FrontScreenAlternateReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Front screen alternates match original: \(r.cases) cases, \(r.helpers) helper returns, \(r.events) parent /\(r.settingsEvents) writer events, \(r.draws) draws /\(r.reads) reads /\(r.clips) clips /\(r.blits) blits /\(r.fills) fills, \(r.sounds) sounds /\(r.timers) timers /\(r.workers) worker requests; \(r.settings) settings calls /\(r.settingsReturns) returns /\(r.prints) fprintf /\(r.fileWrites) writes /\(r.failedWrites) failed or short; \(r.boundaries) boundaries, \(r.records) records /\(r.bytes) bytes/masks; own fresh screen body \(r.parent.cases). Full screen loop, device output and Windows open")
        exit(0)
    }
    if CommandLine.arguments.count == 3,CommandLine.arguments[1] == "--settings-writing" {
        let r = try SettingsWritingReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Settings writing matches original: \(r.cases) cases /\(r.returns) returns /\(r.nullFiles) null FILE /\(r.stringBoundaries) string boundaries, \(r.prints) fprintf /\(r.closes) fclose, \(r.fileWrites) writes /\(r.failedWrites) failed or short, \(r.events) events /\(r.parentWrites) parent writes, \(r.records) records /\(r.bytes) bytes/masks; original control bytes roundtrip. Menu caller, full FILE/Windows IO remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 3,CommandLine.arguments[1] == "--front-screen-body" {
        let r = try FrontScreenBodyReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Front screen body matches original: \(r.cases) cases, \(r.helpers) child returns, \(r.events) events, \(r.texts) texts /\(r.draws) draws /\(r.reads) reads /\(r.clips) clips /\(r.blits) blits, \(r.sounds) sounds /\(r.shells) links, \(r.boundaries) boundaries, \(r.records) records /\(r.bytes) bytes/masks; own fresh panel parent \(r.parent.cases). Alternate screens, platform output and Windows open")
        exit(0)
    }
    if CommandLine.arguments.count == 3,CommandLine.arguments[1] == "--menu-panel-update" {
        let r = try MenuPanelUpdateReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Menu panel update matches original: \(r.cases) cases, \(r.content) content /\(r.bitmaps) bitmap /\(r.defaults) default /\(r.caches) cache calls, \(r.returns) child returns /\(r.constructors) constructors /\(r.destructors) destructors, \(r.events) parent /\(r.childEvents) child events, \(r.boundaries) pending-content boundaries, \(r.records) records /\(r.bytes) bytes/masks; own fresh prefix parent \(r.parent.cases). Remaining screen, worker, file/device output and Windows open")
        exit(0)
    }
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--menu-info-writing" {
        let r = try MenuInfoWritingReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Menu info writing matches original: \(r.cases) cases /\(r.defaults) defaults /\(r.caches) caches, \(r.formats) sprintf /\(r.prints) fprintf /\(r.closes) fclose, \(r.fileWrites) low-level writes /\(r.failedWrites) failed or short, \(r.events) events /\(r.parentWrites) parent writes, \(r.records) records /\(r.bytes) bytes/masks. Declared user-buffered FILE; Windows translation, real file IO and parent4236d0 remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--menu-panel-bitmap" {
        let r = try MenuPanelBitmapReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Menu panel bitmap matches original: \(r.cases) cases /\(r.sources) DIBs, \(r.helpers) helper returns /\(r.constructors) constructors /\(r.destructors) destructors, \(r.allocations) malloc /\(r.nullAllocations) null /\(r.reused) reused addresses, \(r.events) events /\(r.writes) parent writes /\(r.releases) releases /\(r.frees) frees, \(r.success) successful /\(r.failure) failed returns, \(r.records) records /\(r.bytes) bytes/masks. Independent helper; parent4236d0, pixels and Windows remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--menu-content" {
        let r = try MenuContentReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Menu content matches original: \(r.cases) cases, \(r.formats) actual formats /\(r.gets) fgets /\(r.scans) sscanf, \(r.events) events /\(r.writes) parent writes, \(r.success) successful /\(r.failure) failed returns /\(r.boundaries) unterminated-input boundaries, \(r.records) records /\(r.bytes) bytes/masks. Independent helper; full menu-information lifecycle, Windows and network remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--front-screen-prelude" {
        let r = try FrontScreenPreludeReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Front screen prelude matches original: \(r.cases) cases /\(r.sources) backgrounds, \(r.helpers) real helper returns, \(r.events) events, \(r.fills) fills /\(r.draws) draws /\(r.blits) Blt requests, \(r.reads) bitmap reads /\(r.undefinedReads) undefined, \(r.clips) clips, \(r.constructors) constructors /\(r.formats) actual CRT formats /\(r.threads) thread requests, \(r.boundaries) invalid-access boundaries, \(r.records) records /\(r.bytes) bytes/masks; settings parent \(r.parent.cases). Next screen bodies, worker, pixels and Windows remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--settings-loading" {
        let r = try SettingsLoadingReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Settings loading matches original: \(r.cases) cases, \(r.scans) actual VC80 scans /\(r.gets) gets /\(r.eof) EOF checks, \(r.returns) settings returns /\(r.nullFiles) null-file boundaries, \(r.events) events /\(r.writes) ordered parent writes, \(r.records) records /\(r.bytes) bytes/masks; native parent \(r.front.constructors) constructors. File opening/translation, full menu and Windows remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--front-menu-resources" {
        let r = try FrontMenuResourcesReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Front menu resources match original: \(r.cases) cases, \(r.sources) source DIBs, \(r.allocations) allocations /\(r.nullAllocations) null, \(r.constructors) real constructors, \(r.events) events /\(r.writes) ordered writes, \(r.settings) settings boundaries /\(r.skipped) skips /\(r.nullBitmaps) null-bitmap boundaries, \(r.records) records /\(r.bytes) bytes/masks. Settings423480, full menu, pixels and Windows remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--bitmap-drawing" {
        let r = try BitmapDrawingReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        print("Bitmap drawing matches original: \(r.cases) cases, \(r.setups) setups /\(r.sources) source DIBs /\(r.constructors) real constructors, \(r.reads) reads /\(r.undefinedReads) from untouched backing, \(r.clips) real clip returns, \(r.blits) Blt requests /\(r.dualBlits) double-draw cases, \(r.boundaries) explicit invalid-access boundaries, \(r.records) full records /\(r.bytes) bytes/masks. Device raster, startup provenance and Windows remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 11, CommandLine.arguments[1] == "--menu-resources" {
        let v = try CommandLine.arguments.dropFirst(2).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let r = try MenuResourcesReference.compare(resources: v[0],music: v[1],round: v[2],replay: v[3],control: v[4],local: v[5],loading: v[6],catalog: v[7],sounds: v[8])
        print("Menu resources match original: \(r.cases) cases, \(r.constructors) real constructors, \(r.allocations) allocations /\(r.nullAllocations) null, \(r.checkpoints) checkpoints, \(r.events) events, \(r.messages) messages /\(r.releases) surface releases, \(r.nullSpark) null-SPARK boundaries, \(r.records) records /\(r.bytes) bytes/masks; linked \(r.parent.cases) music cases and complete round/input/loading. Menu dispatch, pixels and Windows remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 10, CommandLine.arguments[1] == "--music-playback" {
        let v = try CommandLine.arguments.dropFirst(2).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let r = try MusicPlaybackReference.compare(music: v[0],round: v[1],replay: v[2],control: v[3],local: v[4],loading: v[5],catalog: v[6],sounds: v[7])
        print("Music playback matches original: \(r.cases) cases, \(r.calls) real helper returns, \(r.events) events, \(r.allocations) allocations, \(r.messages) messages, \(r.formats) CRT formats, \(r.records) records /\(r.bytes) bytes/masks; linked \(r.parent.cases) round cases and complete replay/input/loading. Device output, menu remainder and Windows remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 9, CommandLine.arguments[1] == "--match-round" {
        let values = try CommandLine.arguments.dropFirst(2).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let r = try MatchRoundReference.compare(round: values[0],replay: values[1],control: values[2],local: values[3],loading: values[4],catalog: values[5],sounds: values[6])
        let exits = r.continuations.keys.sorted().map { "\($0)=\(r.continuations[$0]!)" }.joined(separator: ", ")
        print("Match round matches original: \(r.cases) cases, \(r.constructors) constructors, \(r.teams) team /\(r.stages) stage scans, \(r.events) events, \(r.records) records /\(r.bytes) bytes/masks; \(exits); linked \(r.parent.cases) replay cases and complete input/loading. Paused rendering, gameplay, Windows and full match remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 8, CommandLine.arguments[1] == "--replay-tick" {
        let values = try CommandLine.arguments.dropFirst(2).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let r = try ReplayTickReference.compare(replay: values[0],control: values[1],local: values[2],loading: values[3],catalog: values[4],sounds: values[5])
        print("Replay tick matches original: \(r.cases) cases, \(r.reads) packet reads /\(r.writes) writes, \(r.checks) checksum operations, \(r.messages) messages, \(r.chains) connected input chains, \(r.events) events, \(r.records) records /\(r.bytes) bytes/masks; linked \(r.parent.cases) control cases and complete loading. Playback startup, Windows and full match remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 7, CommandLine.arguments[1] == "--input-control" {
        let values = try CommandLine.arguments.dropFirst(2).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let r = try InputControlReference.compare(control: values[0],local: values[1],loading: values[2],catalog: values[3],sounds: values[4])
        print("Input control matches original: \(r.cases) cases, \(r.actions) real hotkey calls, \(r.events) ordered events, \(r.sends) send /\(r.receives) receive boundaries, \(r.messages) messages, \(r.restores) playback restores /\(r.resets) input resets, \(r.records) records /\(r.bytes) bytes/masks; linked \(r.local.cases) local cases and complete first loading. Windows transport, playback startup and full match remain open")
        exit(0)
    }
    if CommandLine.arguments.count == 7, CommandLine.arguments[1] == "--received-input" {
        let values = try CommandLine.arguments.dropFirst(2).map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
        let r = try ReceivedInputReference.compare(received: values[0],local: values[1],loading: values[2],catalog: values[3],sounds: values[4])
        print("Received input matches original: \(r.cases) cases, \(r.remoteCalls) remote ret12 /\(r.playbackCalls) playback ret8, \(r.records) records, \(r.bytes) bytes/masks, \(r.continuous) continuous phase1 caller; linked \(r.local.cases) local-input cases and complete first loading. Network transport, playback checksum/recording and Practice remain open")
        exit(0)
    }
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
