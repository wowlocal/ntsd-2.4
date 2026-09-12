import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

/// Two saved whole War returns consume fields produced by the earlier menu.
/// Each Native chain owns its prefix/resources. No source execution or expected
/// after-state is used to produce Native state; device flags are request records.
final class OriginalLibWarRetainedScratchTests: XCTestCase {
    typealias Test = OriginalLibWarPreparationTests
    private struct Envelope: Decodable { let count: Int,sha256: String,deflate: String }

    private func resources(_ scenario: Int,_ index: Test.Index,
                           _ catalog: OriginalLoadedCatalog) throws -> Test.Resources {
        let pins: [Int:(Int,String)]=[
            10:(35_693_238,"ce3c1e43d09403356fe0e93258eaa9c62d723d2c31337c0271e85e85e74f63cb"),
            11:(35_692_906,"b8b09cc3f84f9766a4db3269bf122e3645a24645b32d2b775a76ff7b3d959a4a")]
        let (count,sha)=try XCTUnwrap(pins[scenario])
        let raw: Data
        if let directory=ProcessInfo.processInfo.environment["NTSD_WAR_RETAINED_SCRATCH_DIRECTORY"] {
            let path=String(format:"war-preparation-fs-errors-s%02d-capture2.parts/call-00.json",scenario)
            raw=try Data(contentsOf:URL(fileURLWithPath:directory).appendingPathComponent(path))
        } else {
            let name=String(format:"original-lib-war-retained-scratch-s%02d-call-00",scenario)
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

    func testWholeRetainedScratchAndCoupledRollback() throws {
        let index=try Test.Index(),test=Test()
        let url=try XCTUnwrap(Bundle.module.url(forResource:"original-loaded-catalog",withExtension:"json",subdirectory:"Fixtures"))
        var loaded: OriginalLoadedCatalog?
        _=try LoadedCatalogReference.compare(Data(contentsOf:url),onLoaded:{ loaded=$0 })
        let catalog=try XCTUnwrap(loaded),base=catalog.bitmaps.count
        var events=0,numeric=0,apiRequests=0,rollbacks=0,prefixCalls=0,guards=0
        for scenario in 10...11 {
            var retained: Test.Retained?
            for number in 0..<10 {
                try autoreleasepool {
                    let r=try Test.Resources(index,number,catalog:catalog),item=r.corpus.cases[0]
                    if number==0 { try test.compareParent(item,r,firstCase:0) }
                    // One trial at each late producer boundary. The second is
                    // after War has returned, proving outer transaction ownership.
                    if number==1 {
                        var trial=retained
                        let failure=scenario==10 ? "secondResource" : "beforeReturn"
                        let stopped=try test.run(item,r,&trial,failure:failure,compareRetainedScratch:true)
                        XCTAssertEqual(stopped,scenario==10 ? 38 : 773);rollbacks += 1
                    }
                    _=try test.run(item,r,&retained,compareRetainedScratch:true);prefixCalls += 1
                }
            }
            try autoreleasepool {
                let r=try resources(scenario,index,catalog),item=r.corpus.cases[0]
                let graphics=try XCTUnwrap(item.preparationGraphics)
                let failed=scenario==10 ? "getObject#27" : "description#14"
                let result:Int32=scenario==10 ? 0 : -1
                XCTAssertEqual(item.resourceFailureInput?.graphics.results,[failed:result])
                let failureEvent=try XCTUnwrap(graphics.events.first { $0.key==failed })
                XCTAssertEqual(failureEvent.response,.init(result:result),"No output writes on failure")
                let stopKey=scenario==10 ? "createSurface#14" : "stretch#14"
                var trial=retained
                let stopped=try test.run(item,r,&trial,failure:"graphicsAPI:"+stopKey,compareRetainedScratch:true)
                XCTAssertEqual(stopped,scenario==10 ? 811 : 818);rollbacks += 1
                for failure in ["scratchMusicFormat","recording","beforeReturn"] {
                    var trial=retained
                    let count=try test.run(item,r,&trial,failure:failure,compareRetainedScratch:true)
                    if failure=="scratchMusicFormat" { XCTAssertEqual(count,921) }
                    rollbacks += 1
                }
                let menuScratch=try XCTUnwrap(retained).war.bitmapScratch
                events += try test.run(item,r,&retained,compareRetainedScratch:true)
                numeric += item.points.filter { $0.kind.hasPrefix("war-preparation-numeric-") }.count
                apiRequests += graphics.events.filter { $0.request != nil }.count
                let current=try XCTUnwrap(retained)
                XCTAssertTrue(current.war.bitmapScratch.loaderInvalidatedByPreparationMusicFormat)
                XCTAssertNil(current.war.bitmapScratch.loaderDimensions)
                if scenario==10 {
                    // Native guard controls, not additional original matches.
                    // No-op, disabled and cached music must retain supported fields.
                    for mode in 0..<3 {
                        var fields=menuScratch,globals=current.prepared.globals,audio=current.music
                        let base=OriginalMatchPreparation.globalBase
                        if mode==0 { try globals.write(UInt8(0),at:0x44eed0-base) }
                        if mode==1 { try globals.write(UInt32(0),at:0x44d010-base) }
                        var formats=0
                        try fields.resumePreparationMusic(globals:&globals,memory:&audio) { request in
                            if request.kind == .format { formats += 1 }
                            return .init(result:0)
                        }
                        XCTAssertEqual(formats,0);XCTAssertEqual(fields,menuScratch);guards += 1
                    }
                    let invalid=current.war.bitmapScratch
                    var missing=invalid,missingContext:[String]=[]
                    let absent=try missing.constructPreparationBitmap(path:"absent image guard",optional:true,
                        backing:[UInt8](repeating:0xa5,count:0x1f50),device:1,flags:0x40,context:&missingContext) { request,events in
                        events.append(request.kind)
                        guard ["module","image"].contains(request.kind) else { throw Test.Stop.unexpected }
                        return .init(result:request.kind=="module" ? 1 : 0)
                    }
                    XCTAssertFalse(absent.input.present);XCTAssertNil(absent.input.width);XCTAssertNil(absent.input.height)
                    XCTAssertEqual(missing,invalid);XCTAssertEqual(missingContext,["module","image","module","image"]);guards += 1
                    for output in 0..<3 {
                        var fields=invalid,context:[String]=[]
                        let perform: (OriginalBitmapSurfaceLoading.Request,inout [String]) throws -> OriginalBitmapSurfaceLoading.Response = { request,events in
                            events.append(request.kind)
                            switch request.kind {
                            case "module":return .init(result:1)
                            case "image":return .init(result:2)
                            case "getObject":
                                if output==0 { return .init(result:0) }
                                var bytes=[UInt8](repeating:0,count:output==1 ? 4 : 8)
                                bytes[0]=64;if output==2 { bytes[4]=32 }
                                return .init(result:24,writes:[.init(offset:4,bytes:bytes)])
                            case "createSurface":return .init(result:-1)
                            default:throw Test.Stop.unexpected
                            }
                        }
                        do {
                            let bitmap=try fields.constructPreparationBitmap(path:"owned metadata guard",optional:true,
                                backing:[UInt8](repeating:0xa5,count:0x1f50),device:1,flags:0x40,context:&context,perform:perform)
                            XCTAssertEqual(output,2);XCTAssertFalse(fields.loaderInvalidatedByPreparationMusicFormat)
                            XCTAssertEqual(bitmap.input.width,64);XCTAssertEqual(bitmap.input.height,32)
                            XCTAssertEqual(fields.loaderDimensions?.bytes,[64,0,0,0,32,0,0,0])
                            XCTAssertEqual(fields.loaderDimensions?.defined,[Bool](repeating:true,count:8))
                            XCTAssertEqual(fields.copyDimensions,invalid.copyDimensions)
                            XCTAssertEqual(context,["module","image","getObject","createSurface"])
                        } catch let error as OriginalBitmapSurfaceLoading.Boundary {
                            XCTAssertEqual(error,.unknownField(output==0 ? "bitmap width" : "bitmap height"))
                            XCTAssertLessThan(output,2);XCTAssertEqual(fields,invalid);XCTAssertTrue(context.isEmpty)
                        }
                        guards += 1
                    }
                }
                XCTAssertEqual(current.prepared.bitmaps.count,base+5)
                XCTAssertTrue(current.prepared.releasedBitmapOrder.isEmpty)
                let dimensions:[(Int32,Int32)]=[(scenario==10 ? 0 : 384,scenario==10 ? 0 : 383),(799,546),(799,47),(799,47),(37,9)]
                for layer in 0..<5 {
                    let bitmap=current.prepared.bitmaps[base+layer]
                    XCTAssertFalse(current.prepared.releasedBitmaps.contains(base+layer));XCTAssertTrue(bitmap.input.present)
                    XCTAssertEqual(bitmap.input.width,dimensions[layer].0);XCTAssertEqual(bitmap.input.height,dimensions[layer].1)
                    XCTAssertEqual(try bitmap.storage.integer(at:0,as:UInt32.self),1)
                    XCTAssertTrue(bitmap.storage.defined.prefix(12).allSatisfy { $0 })
                    XCTAssertTrue(bitmap.storage.defined.dropFirst(12).allSatisfy { !$0 })
                }
                FileHandle.standardError.write(Data("Retained scratch War compared s\(scenario): \(failed), exact rollback event\(stopped)\n".utf8))
            }
        }
        XCTAssertEqual(events,2638);XCTAssertEqual(apiRequests,150);XCTAssertEqual(numeric,32)
        XCTAssertEqual(rollbacks,10);XCTAssertEqual(prefixCalls,20);XCTAssertEqual(guards,7)
        print("Retained scratch War:2 whole returned callers,2638 ordered events,150 graphics API requests,32 numeric checkpoints,10 coupled rollbacks,20 overlapping Native prefix calls,10 constructor field comparisons,7 Native guard controls. Loader lifetime ends at actual music format; source ABI bytes and faults remain separate.")
    }
}
