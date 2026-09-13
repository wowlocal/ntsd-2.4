import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalMenuStartupTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "original-"+name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let startup = try fixture("menu-startup")
        let result = try MenuStartupReference.compare(startup: startup,menu: fixture("menu-loading"),
            loading: fixture("menu-loading-state"),catalog: fixture("menu-loading-catalog"),sounds: fixture("menu-loading-sounds"),
            onEntry: { loaded,input,entry in
                try self.checkEntry(loaded,input,entry,rollback: !control)
                try OriginalApplicationInputTests.compareSavedEntry(loaded,input,entry,reversed:control)
                if !control { try self.checkMenuRollback(entry,platformCorpus: startup) }
            })
        XCTAssertEqual(result.parent.menu.cases,119)
        XCTAssertEqual(result.parent.loading.catalog.catalog.objects,137)
        XCTAssertEqual(result.localCalls,1)
        XCTAssertEqual(result.receivedCalls,1)
        XCTAssertEqual(result.musicCalls,5)
        XCTAssertEqual(result.constructors,11)
        XCTAssertEqual(result.checkpoints,22)
        XCTAssertEqual(result.events,68)
        XCTAssertEqual(result.records,3412)
        XCTAssertEqual(result.bytes,5_948_634)
    }
    func testOwnMenuLoadingContinuesThroughInputRoundAndCharacterMenuResources() throws { try compare(false) }
    func testSameStartupWithRetainedRampResourcesAndReverseActorAddresses() throws { try compare(true) }

    private struct Environment: Equatable {
        var checkpoints: [OriginalLoadedMatchEntry.Checkpoint] = []
        var committed = 7
    }
    private enum Stop: Error { case injected, unexpectedPlatform }

    /// Only declared responses and allocation backing are decoded. Initial
    /// globals below come from the completed native entry, never source after-state.
    private struct MenuPlatform: Decodable {
        struct Music: Decodable {
            struct Event: Decodable {
                let kind: OriginalMusicEvent.Kind, arguments: [UInt32], strings: [[UInt8]]
                let response: OriginalMusicResponse
            }
            let events: [Event]
        }
        struct Resources: Decodable {
            struct Allocation: Decodable { let address: UInt32, backing: String }
            struct Input: Decodable {
                let index: Int, resource: OriginalBitmapInput, surface: UInt32, colorKeyResult: Int32
            }
            let allocations: [Allocation], inputs: [Input]
        }
        struct Blob: Decodable { let count: Int, deflate: String }
        let music: Music, resources: Resources, blobs: [String:Blob]
    }
    private struct MenuEnvironment: Equatable {
        var musicRequests = 0, allocations = 0, bitmapEvents = 0
        var checkpoints: [String] = []
        var commits = 0
    }
    private func checkMenuRollback(_ entry: OriginalInitialMatchEntry,platformCorpus: Data) throws {
        let data = try MatchPreparationReference.unpack(platformCorpus,maximumCount: 128_000_000)
        let input = try JSONDecoder().decode(MenuPlatform.self,from: data)
        let devices = Dictionary(uniqueKeysWithValues: input.resources.inputs.map { ($0.index,$0) })
        let allocations = try input.resources.allocations.map { value in
            let blob = try XCTUnwrap(input.blobs[value.backing])
            let raw = try MatchPreparationReference.inflate(blob.deflate,count: blob.count)
            XCTAssertEqual(MatchPreparationReference.digest(Data(raw)),value.backing)
            return OriginalInterfaceAllocation(address: value.address,backing: raw)
        }
        let initial = entry.state.globals
        let previous = try initial.integer(at: 0x4512cc-OriginalMatchPreparation.globalBase,as: UInt32.self)
        for failure in ["music","bitmap","flag","final","nullSpark"] {
            var globals = initial, music = OriginalMusicMemory(), resources = OriginalMenuResourceLoading()
            var environment = MenuEnvironment(), result: OriginalCharacterMenuStartup.Result?
            let before = environment
            var reached = false
            XCTAssertThrowsError(try {
                result = try OriginalCharacterMenuStartup.run(globals: &globals,music: &music,resources: &resources,environment: &environment,
                    musicRequest: { event,context in
                        guard context.musicRequests < input.music.events.count else { throw Stop.unexpectedPlatform }
                        let response = input.music.events[context.musicRequests];context.musicRequests += 1
                        XCTAssertEqual(event,.init(response.kind,response.arguments,response.strings))
                        return response.response
                    },allocate: { index,context in
                        XCTAssertEqual(index,context.allocations);context.allocations += 1
                        guard allocations.indices.contains(index) else { throw Stop.unexpectedPlatform }
                        if failure == "nullSpark",index == 10 { return .init(address: 0,backing: []) }
                        return allocations[index]
                    },source: { index,path,_ in
                        let device = try XCTUnwrap(devices[index]);XCTAssertEqual(path,device.resource.path)
                        return device.resource
                    },deviceResult: { index,_ in
                        let device = try XCTUnwrap(devices[index]);return (device.surface,device.colorKeyResult)
                    },afterMusic: { entered,state,owned,context in
                        XCTAssertTrue(entered);XCTAssertEqual(context.musicRequests,input.music.events.count)
                        XCTAssertFalse(owned.allocations.isEmpty);XCTAssertNotEqual(state,initial)
                        XCTAssertEqual(try state.integer(at: 0x4512cc-OriginalMatchPreparation.globalBase,as: UInt32.self),previous)
                        context.checkpoints.append("music")
                        if failure == "music" { reached = true;throw Stop.injected }
                    },checkpoint: { point,_,owned,context in
                        context.checkpoints.append(point.kind.rawValue)
                        if failure == "bitmap",point.kind == .bitmap,point.index == 5 {
                            XCTAssertEqual(owned.count,6);reached = true;throw Stop.injected
                        }
                        if failure == "flag",point.kind == .flag {
                            XCTAssertEqual(owned.count,11);reached = true;throw Stop.injected
                        }
                        if failure == "nullSpark",point.kind == .seats {
                            XCTAssertEqual(owned.count,10);reached = true
                        }
                    },observe: { _,context in context.bitmapEvents += 1 },
                    beforeCommit: { outcome,_,audio,images,context in
                        XCTAssertTrue(outcome.musicEntered);XCTAssertEqual(outcome.resources.continuation,.ready)
                        XCTAssertFalse(audio.allocations.isEmpty);XCTAssertEqual(images.bitmaps.count,11)
                        context.commits += 1
                        if failure == "final" { reached = true;throw Stop.injected }
                    })
            }()) { error in
                if failure == "nullSpark" {
                    XCTAssertEqual(error as? OriginalCharacterMenuStartupError,.nullSpark)
                } else if case Stop.injected = error {} else { XCTFail("Unexpected menu failure: \(error)") }
            }
            XCTAssertTrue(reached);XCTAssertNil(result);XCTAssertEqual(environment,before)
            XCTAssertEqual(globals,initial);XCTAssertEqual(entry.state.globals,initial)
            XCTAssertTrue(music.allocations.isEmpty);XCTAssertTrue(resources.bitmaps.isEmpty)
        }
    }
    private func checkEntry(_ loaded: OriginalInitialLoading,_ input: OriginalInputControlContext,
                            _ entry: OriginalInitialMatchEntry,rollback: Bool) throws {
        XCTAssertEqual(entry.state.arithmeticPrecision,.bits64)
        XCTAssertEqual(entry.commonSounds.count,18);XCTAssertEqual(entry.registeredSounds.buffers.count,400)
        func wave(_ actual: OriginalWaveLoadResult,_ expected: OriginalWaveLoadResult) {
            XCTAssertEqual(actual.exit,expected.exit);XCTAssertEqual(actual.returned,expected.returned)
            XCTAssertEqual(actual.output,expected.output);XCTAssertEqual(actual.temporaryLive,expected.temporaryLive)
            XCTAssertEqual(actual.temporary,expected.temporary);XCTAssertEqual(actual.first,expected.first)
            XCTAssertEqual(actual.second,expected.second);XCTAssertEqual(actual.format,expected.format)
            XCTAssertEqual(actual.descriptor,expected.descriptor)
        }
        for (a,b) in zip(entry.commonSounds,loaded.commonSounds) { wave(a,b) }
        XCTAssertEqual(Set(entry.registeredSounds.buffers.keys),Set(loaded.registeredSounds.buffers.keys))
        for (key,value) in loaded.registeredSounds.buffers { wave(try XCTUnwrap(entry.registeredSounds.buffers[key]),value) }
        XCTAssertEqual(entry.state.interface.bitmaps.count,10)
        for (key,value) in loaded.interface.bitmaps {
            let actual=try XCTUnwrap(entry.state.interface.bitmaps[key])
            XCTAssertEqual(actual.input,value.input);XCTAssertEqual(actual.optional,value.optional)
            XCTAssertEqual(actual.storage,value.storage)
        }
        XCTAssertEqual(entry.paused,loaded.paused);XCTAssertEqual(entry.playbackCommands,Array(loaded.commands.suffix(10)))
        XCTAssertEqual(entry.round.continuation,.menu);XCTAssertEqual(entry.round.stageDefeated,0)
        guard rollback else { return }
        let beforeGlobals=loaded.globals,beforeSaved=input.savedPlayback,beforePointers=input.memory.replayPointers,beforeMemory=input.memory.allocations
        let beforeEntryGlobals=entry.state.globals
        for failure in ["local","round","final"] {
            var environment=Environment(),result: OriginalInitialMatchEntry?
            let before=environment
            XCTAssertThrowsError(try {
                result=try OriginalInitialMatchEntry.run(loading:loaded,inputContext:input,arithmeticPrecision:.bits64,
                    environment:&environment,controlBoundary:{ _,_ in throw Stop.unexpectedPlatform },
                    checkpoint:{ point,_,_,_,state in
                        state.checkpoints.append(point)
                        if point.rawValue==failure { throw Stop.injected }
                    },beforeCommit:{ value,state in
                        XCTAssertEqual(value.round.continuation,.menu)
                        XCTAssertEqual(state.checkpoints,[.localBeforeDispatch,.local,.control,.received,.replay,.round])
                        state.committed += 1
                        if failure=="final" { throw Stop.injected }
                    })
            }()) { error in
                guard case Stop.injected=error else { return XCTFail("Unexpected failure: \(error)") }
            }
            XCTAssertNil(result);XCTAssertEqual(environment,before)
            XCTAssertEqual(loaded.globals,beforeGlobals);XCTAssertEqual(input.savedPlayback,beforeSaved)
            XCTAssertEqual(input.memory.replayPointers,beforePointers);XCTAssertEqual(input.memory.allocations,beforeMemory)
            XCTAssertEqual(entry.state.globals,beforeEntryGlobals)
        }
    }
}
