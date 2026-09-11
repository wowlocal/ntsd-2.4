import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

extension OriginalLibWarPreparationTests {
    /// Controlled source success matrix. These are retained confirmations;
    /// no played battle, Windows device or own full-startup claim follows.
    func testWholeMatrixAndRetainedReleaseRollback() throws {
        let index=try Index(.matrix)
        let url=try XCTUnwrap(Bundle.module.url(forResource:"original-loaded-catalog",withExtension:"json",subdirectory:"Fixtures"))
        var loaded: OriginalLoadedCatalog?
        _ = try LoadedCatalogReference.compare(Data(contentsOf:url),onLoaded:{ loaded=$0 })
        let catalog=try XCTUnwrap(loaded)
        var retained: Retained?,events=0,expectedEvents=0,parents=0,preparations=0,rollbacks=0,numericPoints=0
        for number in index.c.cases.indices {
            try autoreleasepool {
                let r=try Resources(index,number,catalog:catalog),item=r.corpus.cases[0]
                if item.spec.chain != true { retained=nil;try compareParent(item,r,firstCase:number);parents += 1 }
                if item.spec.generation==1,item.spec.matrixOrdinal.map({ [0,1].contains($0) })==true {
                    for failure in ["release","free","replayFree"] {
                        var trial=retained;_ = try run(item,r,&trial,failure:failure);rollbacks += 1
                    }
                }
                if item.spec.expectedPreparation == true { preparations += 1 }
                events += try run(item,r,&retained);expectedEvents += item.events.count
                numericPoints += item.points.filter { $0.kind.hasPrefix("war-preparation-numeric-") }.count
                XCTAssertEqual(item.end,"returned")
                FileHandle.standardError.write(Data("War preparation matrix compared \(number): \(item.spec.label)\n".utf8))
            }
        }
        XCTAssertEqual(parents,20);XCTAssertEqual(preparations,56);XCTAssertEqual(rollbacks,6)
        XCTAssertEqual(numericPoints,680);XCTAssertEqual(events,expectedEvents)
    }
}
