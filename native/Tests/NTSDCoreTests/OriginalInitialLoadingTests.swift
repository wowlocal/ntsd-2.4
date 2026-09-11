import Foundation
import XCTest
import NTSDCore
import NTSDReferenceChecks

final class OriginalInitialLoadingTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        func fixture(_ name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name+suffix,withExtension: "json",subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
        let result = try InitialLoadingReference.compare(loading: fixture("original-initial-loading"),
            catalog: fixture("original-initial-loading-catalog"), sounds: fixture("original-initial-loading-sounds"),
            onCatalog: { if suffix.isEmpty { try self.checkNativeContinuation($0) } })
        XCTAssertEqual(result.catalog.catalog.objects,137)
        XCTAssertEqual(result.catalog.catalog.frames,15388)
        XCTAssertEqual(result.catalog.catalog.checksum,31_475_378)
        XCTAssertEqual(result.commonLoads,18)
        XCTAssertEqual(result.catalog.calls,400)
        XCTAssertEqual(result.poolConstructors,408)
        XCTAssertEqual(result.interfaceConstructors,10)
    }
    func testContinuousFirstLoadingFromRealPrologue() throws { try compare("") }
    func testPhaseZeroPauseAndReversedActorAllocations() throws { try compare("-control") }

    private struct Context: Equatable {
        var actors: [Int] = [], constructors: [Int] = [], images: [Int] = [], requests: [String] = []
        var committed = 0
    }
    private enum Stop: Error { case injected }
    /// The catalog/prefix here were constructed natively by the full comparison.
    /// Missing UI images are a separate native platform control, not source data.
    private func checkNativeContinuation(_ entry: OriginalInitialLoadingContinuation) throws {
        var current = entry.globals
        let markerOffset=0x458430-OriginalMatchPreparation.globalBase
        let originalMarker=try current.integer(at:markerOffset,as:UInt32.self)
        XCTAssertNotEqual(originalMarker,0x13579bdf)
        try current.write(UInt32(0x13579bdf),at:markerOffset)
        let continuation=try OriginalInitialLoadingContinuation(prefix:entry.prefix,resources:entry.resources,
            world:entry.world,globals:current)
        var context=Context()
        func complete(_ fail: Bool) throws -> OriginalInitialLoading {
            try continuation.complete(context:&context,allocateActor:{ slot,count,state in
                XCTAssertEqual(state.actors.count % 400,slot);state.actors.append(slot)
                return [UInt8](repeating:0xa5,count:count)
            },allocateInterface:{ index,state in
                state.images.append(index)
                return .init(address:0x76000020+UInt32(index)*0x2000,backing:[UInt8](repeating:0xa5,count:0x1f50))
            },perform:{ request,state in
                XCTAssertTrue(["module","image","message","debug"].contains(request.kind))
                state.requests.append(request.kind);return .init(result:0)
            },afterActorConstructor:{ slot,_,_,state in state.constructors.append(slot) },beforeCommit:{ loaded,state in
                XCTAssertEqual(loaded.catalog.objects.count,137);XCTAssertEqual(loaded.registeredSounds.buffers.count,400)
                XCTAssertEqual(loaded.commonSounds.count,18);XCTAssertEqual(loaded.interface.bitmaps.count,10)
                XCTAssertEqual(loaded.paused,entry.prefix.paused);XCTAssertEqual(loaded.commands,entry.prefix.commands.flatMap { $0 })
                XCTAssertEqual(try loaded.globals.integer(at:markerOffset,as:UInt32.self),0x13579bdf)
                XCTAssertEqual(try loaded.globals.integer(at:0x44d05c-OriginalMatchPreparation.globalBase,as:UInt32.self),0)
                XCTAssertEqual(state.actors.count,fail ? 800 : 400);XCTAssertEqual(state.constructors.count,fail ? 816 : 408)
                state.committed += 1
                if fail { throw Stop.injected }
            })
        }
        let loaded=try complete(false),before=context
        XCTAssertEqual(context.committed,1);XCTAssertEqual(context.images,Array(0..<10))
        XCTAssertEqual(context.requests.filter { $0 == "image" }.count,20)
        XCTAssertThrowsError(try complete(true)) { error in
            guard case Stop.injected=error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertEqual(context,before)
        XCTAssertEqual(loaded.bootstrap.actors.count,400)
        XCTAssertEqual(try entry.globals.integer(at:markerOffset,as:UInt32.self),originalMarker)
    }
}
