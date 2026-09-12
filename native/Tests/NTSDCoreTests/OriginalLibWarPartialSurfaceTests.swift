import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

/// Six saved whole War returns after image/CreateSurface/colorKey failures.
/// Native builds each prefix and all owners itself; no source execution or
/// source after-state supplies Native state. Following source faults are separate.
final class OriginalLibWarPartialSurfaceTests: XCTestCase {
    typealias Test = OriginalLibWarPreparationTests
    private struct Envelope: Decodable { let count: Int,sha256: String,deflate: String }

    private func resources(_ scenario: Int,_ index: Test.Index,
                           _ catalog: OriginalLoadedCatalog) throws -> Test.Resources {
        let pins: [Int:(Int,String)]=[
            4:(35_669_702,"d3c0825f0d854cd5f07b4541bf1724b920ad19aac37ded3e032c544f4cd4f36e"),
            5:(35_670_064,"3fb890f433a2a441242cb5bc4c90f4e8c7f26f0ed837b82b475ccbd18e81d34b"),
            6:(35_676_576,"69bb9f8d5b4baf84571410f6dee2e74df8d5d6c597d8b6c9a63b40eb85d30977"),
            7:(35_677_671,"41cacc90f44579bd2be4a9c6c6f07cb74bb8e8b344e55878269f06466b3982ab"),
            8:(35_698_247,"e1b3dec0f3fd59a39fcc77f3607b46aae8b92e45a8a337562b3ac2eec2fa120c"),
            9:(35_698_291,"e6ed43c9988301c61a1ccf22cebd54bcb4c06cb88c76e71d3b44151942799fdd")]
        let (count,sha)=try XCTUnwrap(pins[scenario])
        let raw: Data
        if let directory=ProcessInfo.processInfo.environment["NTSD_WAR_PARTIAL_SURFACE_DIRECTORY"] {
            let path=String(format:"war-preparation-fs-errors-s%02d-capture2.parts/call-00.json",scenario)
            raw=try Data(contentsOf:URL(fileURLWithPath:directory).appendingPathComponent(path))
        } else {
            let name=String(format:"original-lib-war-partial-surface-s%02d-call-00",scenario)
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

    func testWholeReturnedPartialSurfacesAndCoupledRollback() throws {
        let index=try Test.Index(),test=Test()
        let url=try XCTUnwrap(Bundle.module.url(forResource:"original-loaded-catalog",withExtension:"json",subdirectory:"Fixtures"))
        var loaded: OriginalLoadedCatalog?
        _=try LoadedCatalogReference.compare(Data(contentsOf:url),onLoaded:{ loaded=$0 })
        let catalog=try XCTUnwrap(loaded),base=catalog.bitmaps.count
        var compared=0,numeric=0,rollbacks=0,events=0,prefixCalls=0
        for scenario in 4...9 {
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
                let layer=scenario.isMultiple(of:2) ? 0 : 4
                XCTAssertEqual(graphics.allocations.count,5);XCTAssertEqual(graphics.records.count,5)
                XCTAssertEqual(graphics.allocationStart,0);XCTAssertNil(input.nullAllocationOrdinal)
                if scenario<6 {
                    XCTAssertEqual(input.missingLoaderIndices,[13+layer]);XCTAssertNil(input.results)
                } else {
                    XCTAssertNil(input.missingLoaderIndices)
                    let kind=scenario<8 ? "createSurface" : "colorKey"
                    XCTAssertEqual(input.results,[kind+"#\(14+layer)":Int32(-1)])
                }
                let points=item.points.filter { $0.kind.hasPrefix("war-preparation-numeric-") }
                XCTAssertEqual(points.count,16);numeric += points.count
                for failure in ["partialBitmap","recording","beforeReturn"] {
                    var trial=retained
                    _=try test.run(item,r,&trial,failure:failure);rollbacks += 1
                }
                let before=try XCTUnwrap(retained).environment.warGraphics
                events += try test.run(item,r,&retained);compared += 1
                let current=try XCTUnwrap(retained),platform=current.environment.preparationGraphics
                XCTAssertEqual(current.prepared.bitmaps.count,base+5)
                let arena=current.prepared.backgrounds[10]
                XCTAssertEqual(try (0..<5).map { try arena.integer(at:0x914+$0*4,as:UInt32.self) },
                               (1...5).map { UInt32(base+$0) })
                XCTAssertTrue(arena.defined[0x914..<0x928].allSatisfy { $0 })
                XCTAssertTrue(current.prepared.releasedBitmapOrder.isEmpty)
                for owner in base..<base+5 { XCTAssertFalse(current.prepared.releasedBitmaps.contains(owner)) }
                let bitmap=current.prepared.bitmaps[base+layer]
                XCTAssertEqual(try bitmap.storage.integer(at:0,as:UInt32.self),0)
                XCTAssertEqual(bitmap.storage.defined.filter { $0 }.count,scenario<6 ? 4 : 12)
                XCTAssertEqual(bitmap.input.present,scenario>=8)
                if scenario<6 {
                    XCTAssertNil(bitmap.input.width);XCTAssertNil(bitmap.input.height)
                    XCTAssertEqual(Array(bitmap.storage.bytes[4..<12]),[UInt8](repeating:0xa5,count:8))
                } else {
                    XCTAssertEqual(bitmap.input.width,layer==0 ? 384 : 37)
                    XCTAssertEqual(bitmap.input.height,layer==0 ? 383 : 9)
                }
                let wrappers=(0..<5).map { UInt32(0x76004020)+UInt32($0)*0x2000 }
                XCTAssertEqual(Array(platform.allocations.suffix(5)),wrappers)
                let targetSurface=platform.surfaceForWrapper[wrappers[layer]]
                if scenario<8 { XCTAssertNil(targetSurface) }
                else { XCTAssertEqual(platform.surfacesReleased[try XCTUnwrap(targetSurface)],true) }
                let images=Set(platform.imagesDeleted.keys).subtracting(before.imagesDeleted.keys)
                let surfaces=Set(platform.surfacesReleased.keys).subtracting(before.surfacesReleased.keys)
                XCTAssertEqual(images.count,scenario<6 ? 4 : 5)
                XCTAssertEqual(surfaces.count,scenario<8 ? 4 : 5)
                XCTAssertEqual(images.filter { platform.imagesDeleted[$0]==false }.count,(6...7).contains(scenario) ? 1 : 0)
                XCTAssertEqual(surfaces.filter { platform.surfacesReleased[$0]==false }.count,4)
                if (6...7).contains(scenario) {
                    let image=try XCTUnwrap(images.first { platform.imagePaths[$0]==bitmap.input.path })
                    XCTAssertEqual(platform.imagesDeleted[image],false)
                }
                FileHandle.standardError.write(Data("Partial surface War compared s\(scenario): 5 retained wrappers, failed layer\(layer)\n".utf8))
            }
        }
        XCTAssertEqual(compared,6);XCTAssertEqual(events,7884);XCTAssertEqual(numeric,96)
        XCTAssertEqual(rollbacks,18);XCTAssertEqual(prefixCalls,60)
        print("Partial surface War:6 whole returned callers,7884 ordered events,96 numeric checkpoints,18 coupled rollbacks,60 overlapping Native prefix calls. Six following source faults remain separate; release flags are requests, not device destruction.")
    }
}
