import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

/// Eight saved whole War returns with declared graphics API error responses.
/// Each Native chain owns its prefix/resources. No source execution or expected
/// after-state is used to produce Native state; device flags are request records.
final class OriginalLibWarGraphicsErrorTests: XCTestCase {
    typealias Test = OriginalLibWarPreparationTests
    private struct Envelope: Decodable { let count: Int,sha256: String,deflate: String }

    private func resources(_ scenario: Int,_ index: Test.Index,
                           _ catalog: OriginalLoadedCatalog) throws -> Test.Resources {
        let pins: [Int:(Int,String)]=[
            12:(35_689_891,"8ce2af0a628240712ccfbe0298b81ee7c09e365ca3c713e9e06ac0aa2bd6090d"),
            13:(35_693_556,"eb4ca720501d22fd79d48b6a14e9a2b9dcb0aa81b75d81f0ba28281a8bd33812"),
            14:(35_693_475,"dc8977708f22ba866e69a08f571a036683a37bf3fb6111b5809abc5a857559d3"),
            15:(35_693_579,"f856ef19296c29eb00b56b80785cd491556ac8eb0f20cda19010514e698670f0"),
            16:(35_693_550,"4cbe26293644d0926fbbcacd078458e467a9a9b0c7296225a3664342e85f0f0e"),
            17:(35_693_574,"0f32f8f594f18271c2380c9ee714c568c993189c2f3d903ff428f7599791dea1"),
            18:(35_693_559,"b75cbf0cce90476bd3b5e758f5846f0a2cce4b8428e27150ea6592591ff93755"),
            19:(35_693_596,"598ad400df2a97d1707015afce02fd2907d6beda0c4a9185ab44a571f47eb899")]
        let (count,sha)=try XCTUnwrap(pins[scenario])
        let raw: Data
        if let directory=ProcessInfo.processInfo.environment["NTSD_WAR_GRAPHICS_ERROR_DIRECTORY"] {
            let path=String(format:"war-preparation-fs-errors-s%02d-capture2.parts/call-00.json",scenario)
            raw=try Data(contentsOf:URL(fileURLWithPath:directory).appendingPathComponent(path))
        } else {
            let name=String(format:"original-lib-war-graphics-error-s%02d-call-00",scenario)
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
        var document=index.metadata
        document["cases"]=[item]
        for key in ["assets","blobs","roster","exeSHA256"] { document[key]=try XCTUnwrap(source[key]) }
        let installation=try XCTUnwrap(source["installation"] as? [String:Any])
        document["libSHA256"]=try XCTUnwrap(installation["libSHA256"])
        let spec=try XCTUnwrap(item["spec"] as? [String:Any])
        return try Test.Resources(document:document,expectedLabel:XCTUnwrap(spec["label"] as? String),catalog:catalog)
    }

    func testWholeGraphicsErrorsAndExactAPIRollback() throws {
        let index=try Test.Index(),test=Test()
        let url=try XCTUnwrap(Bundle.module.url(forResource:"original-loaded-catalog",withExtension:"json",subdirectory:"Fixtures"))
        var loaded: OriginalLoadedCatalog?
        _=try LoadedCatalogReference.compare(Data(contentsOf:url),onLoaded:{ loaded=$0 })
        let catalog=try XCTUnwrap(loaded),base=catalog.bitmaps.count
        let kinds=["getDC","restore","createDC","selectObject","stretch","releaseDC","deleteDC","deleteObject"]
        var compared=0,numeric=0,rollbacks=0,events=0,prefixCalls=0,apiRequests=0
        for scenario in 12...19 {
            var retained: Test.Retained?
            for number in 0..<10 {
                try autoreleasepool {
                    let r=try Test.Resources(index,number,catalog:catalog),item=r.corpus.cases[0]
                    if number==0 { try test.compareParent(item,r,firstCase:0) }
                    _=try test.run(item,r,&retained);prefixCalls += 1
                }
            }
            try autoreleasepool {
                let r=try resources(scenario,index,catalog),item=r.corpus.cases[0]
                let graphics=try XCTUnwrap(item.preparationGraphics),input=try XCTUnwrap(item.resourceFailureInput).graphics
                let kind=kinds[scenario-12],key=kind+"#14",result: Int32=[12,13,17].contains(scenario) ? -1 : 0
                XCTAssertEqual(input.results,[key:result]);XCTAssertNil(input.nullAllocationOrdinal);XCTAssertNil(input.missingLoaderIndices)
                XCTAssertEqual(graphics.allocations.count,5);XCTAssertEqual(graphics.records.count,5);XCTAssertEqual(graphics.allocationStart,0)
                let target=try XCTUnwrap(graphics.events.firstIndex { $0.key==key })
                XCTAssertEqual(graphics.events.filter { $0.key==key }.count,1)
                XCTAssertEqual(graphics.events[target].response?.result,result)
                let front=item.events.enumerated().filter { $0.element.kind=="preparationBitmap" }.map(\.offset)
                XCTAssertEqual(front.count,graphics.events.count)
                var trial=retained
                let stoppedAt=try test.run(item,r,&trial,failure:"graphicsAPI:"+key)
                XCTAssertEqual(stoppedAt,front[target]+1,"Rollback immediately after the declared API event");rollbacks += 1
                for failure in ["recording","beforeReturn"] {
                    var trial=retained
                    _=try test.run(item,r,&trial,failure:failure);rollbacks += 1
                }
                // Limit this assertion to the first constructor: after GetDC
                // fails, later layers reuse the first stretch/releaseDC ordinal.
                let nextAllocation=try XCTUnwrap(graphics.events.firstIndex { $0.kind=="allocate" && $0.index==1 })
                let first=graphics.events[..<nextAllocation].compactMap(\.request)
                let normal=["module","image","getObject","createSurface","restore","createDC","selectObject",
                            "getObject","description","getDC","stretch","releaseDC","deleteDC","deleteObject","colorKey"]
                XCTAssertEqual(first.map(\.kind),scenario==12 ? normal.filter { $0 != "stretch" && $0 != "releaseDC" } : normal)
                if scenario==14 {
                    XCTAssertEqual(try XCTUnwrap(first.first { $0.kind=="selectObject" }).words[0],0)
                    XCTAssertEqual(try XCTUnwrap(first.first { $0.kind=="stretch" }).words[5],0)
                    XCTAssertEqual(try XCTUnwrap(first.first { $0.kind=="deleteDC" }).words[0],0)
                }
                apiRequests += graphics.events.filter { $0.request != nil }.count
                let points=item.points.filter { $0.kind.hasPrefix("war-preparation-numeric-") }
                XCTAssertEqual(points.count,16);numeric += points.count
                let before=try XCTUnwrap(retained).environment.warGraphics
                events += try test.run(item,r,&retained);compared += 1
                let current=try XCTUnwrap(retained),platform=current.environment.preparationGraphics
                XCTAssertEqual(current.prepared.bitmaps.count,base+5)
                XCTAssertEqual(try (0..<5).map { try current.prepared.backgrounds[10].integer(at:0x914+$0*4,as:UInt32.self) },(1...5).map { UInt32(base+$0) })
                XCTAssertTrue(current.prepared.releasedBitmapOrder.isEmpty)
                let dimensions:[(Int32,Int32)]=[(384,383),(799,546),(799,47),(799,47),(37,9)]
                for layer in 0..<5 {
                    let bitmap=current.prepared.bitmaps[base+layer]
                    XCTAssertFalse(current.prepared.releasedBitmaps.contains(base+layer));XCTAssertTrue(bitmap.input.present)
                    XCTAssertEqual(try bitmap.storage.integer(at:0,as:UInt32.self),1)
                    XCTAssertEqual(bitmap.input.width,dimensions[layer].0);XCTAssertEqual(bitmap.input.height,dimensions[layer].1)
                    XCTAssertTrue(bitmap.storage.defined.prefix(12).allSatisfy { $0 })
                    XCTAssertTrue(bitmap.storage.defined.dropFirst(12).allSatisfy { !$0 })
                }
                let images=Set(platform.imagesDeleted.keys).subtracting(before.imagesDeleted.keys)
                let surfaces=Set(platform.surfacesReleased.keys).subtracting(before.surfacesReleased.keys)
                let dcs=Set(platform.dcs.keys).subtracting(before.dcs.keys)
                XCTAssertEqual(images.count,5);XCTAssertEqual(surfaces.count,5);XCTAssertEqual(dcs.count,5)
                XCTAssertTrue(surfaces.allSatisfy { platform.surfacesReleased[$0]==false })
                XCTAssertTrue(dcs.allSatisfy { platform.dcs[$0]==true },"DeleteDC request flags, including failure/zero handle")
                XCTAssertEqual(images.filter { platform.imagesDeleted[$0]==false }.count,scenario==19 ? 1 : 0)
                if scenario==14 { XCTAssertTrue(dcs.contains(0));XCTAssertEqual(platform.dcs[0],true) }
                if scenario==19 {
                    let image=try XCTUnwrap(images.first { platform.imagePaths[$0]==current.prepared.bitmaps[base].input.path })
                    XCTAssertEqual(platform.imagesDeleted[image],false)
                }
                FileHandle.standardError.write(Data("Graphics error War compared s\(scenario): \(key)=\(result), exact rollback event\(stoppedAt)\n".utf8))
            }
        }
        XCTAssertEqual(compared,8);XCTAssertEqual(events,10550);XCTAssertEqual(apiRequests,598)
        XCTAssertEqual(numeric,128);XCTAssertEqual(rollbacks,24);XCTAssertEqual(prefixCalls,80)
        print("Graphics error War:8 whole returned callers,10550 ordered events,598 graphics API requests,128 numeric checkpoints,24 coupled rollbacks,80 overlapping Native prefix calls. Flags are controlled request records, not Windows device ownership/destruction; source faults remain separate.")
    }
}
