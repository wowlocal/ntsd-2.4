import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

/// Three saved returned War calls with declared first/last allocation NULL.
/// Native first produces the ten accepted parent calls from its own state.
/// Full source files are fixtures, not an input after-state or original runtime.
final class OriginalLibWarNullableBitmapTests: XCTestCase {
    typealias Test = OriginalLibWarPreparationTests
    private struct Envelope: Decodable { let count: Int,sha256: String,deflate: String }

    private func resources(_ scenario: Int,_ ordinal: Int,_ index: Test.Index,
                           _ catalog: OriginalLoadedCatalog) throws -> Test.Resources {
        let count: Int,sha: String
        switch (scenario,ordinal) {
        case (2,0): count=35_621_490;sha="29364c720cdc4bcda666576556a99001344900b3cc56bb2e356575ee87a3280c"
        case (2,1): count=35_764_638;sha="dbee1a12634438351a39005f40fb7562bc2a79eeea6dbbd2840e6e4c4276c5f0"
        case (3,0): count=35_639_552;sha="d333c0f19de94ac0cfa92c5354a7e335c33e85eb0bb20d52b9aeb3f627e7de56"
        default: throw Test.Stop.unexpected
        }
        let name=String(format:"original-lib-war-nullable-s%02d-call-%02d",scenario,ordinal)
        let raw: Data
        if let directory=ProcessInfo.processInfo.environment["NTSD_WAR_NULLABLE_DIRECTORY"] {
            let path=String(format:"war-preparation-fs-errors-s%02d-capture2.parts/call-%02d.json",scenario,ordinal)
            raw=try Data(contentsOf:URL(fileURLWithPath:directory).appendingPathComponent(path))
        } else {
            let url=try XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures"))
            let envelope=try JSONDecoder().decode(Envelope.self,from:Data(contentsOf:url))
            guard envelope.count==count,envelope.sha256==sha else { throw Test.Stop.unexpected }
            raw=Data(try MatchPreparationReference.inflate(envelope.deflate,count:count,maximumCount:40_000_000))
        }
        guard raw.count==count,MatchPreparationReference.digest(raw)==sha else { throw Test.Stop.unexpected }
        let source=try XCTUnwrap(JSONSerialization.jsonObject(with:raw) as? [String:Any])
        let item=try XCTUnwrap(source["case"] as? [String:Any])
        XCTAssertEqual(item["end"] as? String,"returned")
        let proofs=try XCTUnwrap(source["prefixProof"] as? [[String:Any]])
        XCTAssertEqual(proofs.count,10)
        for (i,proof) in proofs.enumerated() {
            XCTAssertEqual(proof["index"] as? Int,i)
            XCTAssertEqual(proof["normalizedSHA256"] as? String,index.c.cases[i].sha256)
        }
        // Shared metadata contains the declared source address bindings only.
        // Fresh case assets are original files; Native rebuilds the catalog.
        var document=index.metadata
        document["cases"]=[item]
        for key in ["assets","blobs","roster","exeSHA256"] { document[key]=try XCTUnwrap(source[key]) }
        let installation=try XCTUnwrap(source["installation"] as? [String:Any])
        document["libSHA256"]=try XCTUnwrap(installation["libSHA256"])
        let spec=try XCTUnwrap(item["spec"] as? [String:Any])
        return try Test.Resources(document:document,expectedLabel:XCTUnwrap(spec["label"] as? String),catalog:catalog)
    }

    func testReturnedAllocationFailuresRetainOwnedLayersAndRollback() throws {
        let index=try Test.Index(),test=Test()
        let url=try XCTUnwrap(Bundle.module.url(forResource:"original-loaded-catalog",withExtension:"json",subdirectory:"Fixtures"))
        var loaded: OriginalLoadedCatalog?
        _=try LoadedCatalogReference.compare(Data(contentsOf:url),onLoaded:{ loaded=$0 })
        let catalog=try XCTUnwrap(loaded),base=catalog.bitmaps.count
        var compared=0,numeric=0,rollbacks=0,events=0,prefixCalls=0
        for scenario in [2,3] {
            var retained: Test.Retained?
            for number in 0..<10 {
                try autoreleasepool {
                    let r=try Test.Resources(index,number,catalog:catalog),item=r.corpus.cases[0]
                    if number==0 { try test.compareParent(item,r,firstCase:0) }
                    _=try test.run(item,r,&retained);prefixCalls += 1
                }
            }
            for ordinal in 0..<(scenario==2 ? 2 : 1) {
                try autoreleasepool {
                    let r=try resources(scenario,ordinal,index,catalog),item=r.corpus.cases[0]
                    let graphics=try XCTUnwrap(item.preparationGraphics)
                    XCTAssertEqual(graphics.allocations.count,5)
                    XCTAssertEqual(graphics.records.count,4)
                    XCTAssertEqual(graphics.allocationStart,ordinal==0 ? 0 : 5)
                    XCTAssertEqual(item.resourceFailureInput?.graphics.nullAllocationOrdinal,
                                   ordinal==0 ? (scenario==2 ? 0 : 4) : nil)
                    let points=item.points.filter { $0.kind.hasPrefix("war-preparation-numeric-") }
                    XCTAssertEqual(points.count,16);numeric += points.count
                    let failures=ordinal==0 ? ["nullBitmap","participants","recording","beforeReturn"]
                                           : ["replayFree","recording","beforeReturn"]
                    for failure in failures {
                        var trial=retained
                        _=try test.run(item,r,&trial,failure:failure);rollbacks += 1
                    }
                    let before=try XCTUnwrap(retained)
                    events += try test.run(item,r,&retained);compared += 1
                    let current=try XCTUnwrap(retained)
                    XCTAssertEqual(current.prepared.bitmaps.count,base+4)
                    let arena=current.prepared.backgrounds[10]
                    let pointers=try (0..<5).map { try arena.integer(at:0x914+$0*4,as:UInt32.self) }
                    let owners=(1...4).map { UInt32(base+$0) }
                    XCTAssertEqual(pointers,scenario==2 ? [0]+owners : owners+[0])
                    XCTAssertTrue(arena.defined[0x914..<0x928].allSatisfy { $0 })
                    XCTAssertTrue(current.prepared.releasedBitmapOrder.isEmpty)
                    for owner in base..<base+4 { XCTAssertFalse(current.prepared.releasedBitmaps.contains(owner)) }
                    if ordinal==1 {
                        XCTAssertTrue(graphics.events.isEmpty)
                        XCTAssertEqual(current.prepared.backgrounds[10],before.prepared.backgrounds[10])
                        XCTAssertEqual(current.prepared.bitmaps,before.prepared.bitmaps)
                        XCTAssertEqual(current.prepared.releasedBitmaps,before.prepared.releasedBitmaps)
                        XCTAssertEqual(current.environment.preparationGraphics,before.environment.preparationGraphics)
                    }
                    FileHandle.standardError.write(Data("Nullable War compared s\(scenario)/call-\(ordinal): 5 requests, 4 retained owners\n".utf8))
                }
            }
        }
        XCTAssertEqual(compared,3);XCTAssertEqual(numeric,48);XCTAssertEqual(rollbacks,11)
        XCTAssertEqual(prefixCalls,20)
        print("Nullable War:3 returned whole callers,48 numeric checkpoints,11 coupled rollbacks,20 overlapping Native parent calls,\(events) ordered events. Four s02 owners survive Start99; separate s03 source fault is not matched.")
    }
}
