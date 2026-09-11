import Foundation
import XCTest
import NTSDCore
import NTSDReferenceChecks

final class OriginalMenuStartupTests: XCTestCase {
    private func compare(_ control: Bool) throws {
        let suffix = control ? "-control" : ""
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "original-"+name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let result = try MenuStartupReference.compare(startup: fixture("menu-startup"),menu: fixture("menu-loading"),
            loading: fixture("menu-loading-state"),catalog: fixture("menu-loading-catalog"),sounds: fixture("menu-loading-sounds"),
            onEntry: { try self.checkEntry($0,$1,$2,rollback: !control) })
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
