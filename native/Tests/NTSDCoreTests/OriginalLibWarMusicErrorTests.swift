import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

/// Saved whole War preparations with explicit music error responses and two
/// nominal controls. Native owns every prefix, global, bitmap and wide buffer;
/// reference execution and actual Windows/device behavior are outside this test.
final class OriginalLibWarMusicErrorTests: XCTestCase {
    typealias Test = OriginalLibWarPreparationTests
    private struct Envelope: Decodable { let count: Int,sha256: String,deflate: String }
    private func resources(_ scenario: Int,_ index: Test.Index,
                           _ catalog: OriginalLoadedCatalog) throws -> Test.Resources {
        let pins: [Int:(Int,String)]=[
            0:(35_693_376,"d2f7d69e00c60b8d318031b1e2c504d33ebacb5af0663af9d627abe495e92c4e"),
            1:(36_477_194,"c3b690f058b5e61ce4a53fd87a7f8ed7ce324b3cf0450fcb7080fae8516510a4"),
            20:(35_581_171,"537484b91657dee9fd75c7fb802797f3b91d31c802006d98587f1d48a6f06e31"),
            21:(35_690_051,"be22744d4f16b9be72ea0c26d9cc5a7518d3e115606f2a4597ae3ef79ede4de1"),
            23:(35_693_391,"ff03fe3bb21b5c69c129b5f2b7fc52cd9577ccba504ce52f5c9b4fe2ad500345"),
            24:(35_690_035,"365e33658ccb9a9bd9d6b3bd401340fba4ab3297c83d0c5c7c252e12830a0027"),
            25:(35_689_931,"c6d5113efb4d07aa62e84dcedf61a12b5e68753d15b9b1e499d0c51bb7f8d7c2"),
            26:(35_703_463,"e694f2d4fd08522595af34ad5140a40b5c5e9d8bcd2868c764c4ad57f5e81620"),
            27:(35_693_190,"728d541297433ef509c342694b5f9996c4b8a54f3f7da7abc463aacc93b2eabf")]
        let (count,sha)=try XCTUnwrap(pins[scenario])
        let raw: Data
        if let directory=ProcessInfo.processInfo.environment["NTSD_WAR_MUSIC_ERROR_DIRECTORY"] {
            let name=String(format:"war-preparation-fs-errors-s%02d-capture2.parts/call-00.json",scenario)
            raw=try Data(contentsOf:URL(fileURLWithPath:directory).appendingPathComponent(name))
        } else {
            let name=String(format:"original-lib-war-music-error-s%02d-call-00",scenario)
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
        let first=scenario==1 ? 11 : 0
        for (i,proof) in proofs.enumerated() {
            XCTAssertEqual(proof["index"] as? Int,i,"Source proof ordinal is local to this chain")
            XCTAssertEqual(proof["normalizedSHA256"] as? String,index.c.cases[first+i].sha256)
        }
        var document=index.metadata
        document["cases"]=[item]
        for key in ["assets","blobs","roster","exeSHA256"] { document[key]=try XCTUnwrap(source[key]) }
        let installation=try XCTUnwrap(source["installation"] as? [String:Any])
        document["libSHA256"]=try XCTUnwrap(installation["libSHA256"])
        let spec=try XCTUnwrap(item["spec"] as? [String:Any])
        return try Test.Resources(document:document,expectedLabel:XCTUnwrap(spec["label"] as? String),catalog:catalog)
    }

    func testWholeMusicErrorsAndCoupledRollback() throws {
        let index=try Test.Index(),test=Test()
        let url=try XCTUnwrap(Bundle.module.url(forResource:"original-loaded-catalog",withExtension:"json",subdirectory:"Fixtures"))
        var loaded: OriginalLoadedCatalog?
        _=try LoadedCatalogReference.compare(Data(contentsOf:url),onLoaded:{ loaded=$0 })
        let catalog=try XCTUnwrap(loaded),base=catalog.bitmaps.count
        let trials:[(Int,String,Int)]=[(0,"render",926),(1,"render",1096),(20,"message",915),
            (21,"eventQuery",916),(23,"eventNotify",918),(24,"run",930),
            (25,"render",926),(26,"message",928),(27,"render",926)]
        var compared=0,numeric=0,rollbacks=0,events=0,prefixCalls=0,graphicsAPIs=0
        var musicEvents=0,messages=0,wrapperOwners=0,wideOwners=0,wideBytes=0
        for (scenario,key,stop) in trials {
            var retained: Test.Retained?
            let first=scenario==1 ? 11 : 0
            for number in first..<first+10 {
                try autoreleasepool {
                    let r=try Test.Resources(index,number,catalog:catalog),item=r.corpus.cases[0]
                    if number==first { try test.compareParent(item,r,firstCase:first) }
                    _=try test.run(item,r,&retained);prefixCalls += 1
                }
            }
            try autoreleasepool {
                let r=try resources(scenario,index,catalog),item=r.corpus.cases[0]
                let graphics=try XCTUnwrap(item.preparationGraphics)
                let input=try XCTUnwrap(XCTUnwrap(item.resourceFailureInput).music)
                XCTAssertNil(item.spec.music);XCTAssertEqual(item.spec.control,scenario==1)
                XCTAssertEqual(input.nullAllocation,scenario==25)
                XCTAssertEqual(input.conversion,scenario==27 ? "none" : "complete")
                XCTAssertEqual(input.conversionResult,scenario==27 ? 0 : nil)
                let messageCount=[20,26].contains(scenario) ? 1 : 0
                XCTAssertEqual(graphics.events.filter { $0.request?.kind=="message" }.count,messageCount)
                if messageCount==1 {
                    XCTAssertEqual(graphics.events.last?.key,"message#1")
                    XCTAssertEqual(item.events[stop-1].kind,"preparationBitmap")
                } else {
                    let target=item.events[stop-1]
                    let request=OriginalMusicEvent(try XCTUnwrap(OriginalMusicEvent.Kind(rawValue:target.kind)),target.arguments,target.strings)
                    XCTAssertEqual(OriginalWarPreparationMusicAdapter.rollbackKey(request),key)
                }
                var trial=retained
                let stoppedAt=try test.run(item,r,&trial,failure:"musicAPI:"+key)
                XCTAssertEqual(stoppedAt,stop,"Exact request after the target result was processed");rollbacks += 1
                for failure in ["recording","beforeReturn"] {
                    var trial=retained
                    _=try test.run(item,r,&trial,failure:failure);rollbacks += 1
                }
                let before=try XCTUnwrap(retained)
                events += try test.run(item,r,&retained);compared += 1
                let current=try XCTUnwrap(retained)
                let wrappers=scenario==1 ? 15 : 5
                XCTAssertEqual(current.prepared.bitmaps.count,base+wrappers);wrapperOwners += wrappers
                XCTAssertTrue(current.prepared.releasedBitmapOrder.isEmpty)
                for bitmap in current.prepared.bitmaps.dropFirst(base) {
                    XCTAssertTrue(bitmap.input.present)
                    XCTAssertEqual(try bitmap.storage.integer(at:0,as:UInt32.self),1)
                    XCTAssertTrue(bitmap.storage.defined.prefix(12).allSatisfy { $0 })
                    XCTAssertTrue(bitmap.storage.defined.dropFirst(12).allSatisfy { !$0 })
                }
                let ownGlobals=current.prepared.globals
                func word(_ address: Int) throws -> UInt32 {
                    try ownGlobals.integer(at:address-OriginalMatchPreparation.globalBase,as:UInt32.self)
                }
                XCTAssertEqual(try word(0x44f040),scenario==20 ? 0 : 0x2c002000)
                XCTAssertEqual(try word(0x44f044),[20,21].contains(scenario) ? 0 : 0x2c002100)
                XCTAssertEqual(try word(0x44f048),scenario==20 ? 0 : 0x2c002200)
                XCTAssertEqual(try word(0x44f04c),[20,23].contains(scenario) ? 0 : 0x2c002300)
                let newWide=Set(current.music.allocations.keys).subtracting(before.music.allocations.keys)
                XCTAssertEqual(newWide.count,[20,25].contains(scenario) ? 0 : 1);wideOwners += newWide.count
                for pointer in newWide {
                    XCTAssertEqual(pointer,0x2c020020)
                    let record=try XCTUnwrap(current.music.allocations[pointer])
                    XCTAssertEqual(record.bytes.count,30);wideBytes += record.bytes.count
                    if scenario==27 {
                        XCTAssertEqual(record.bytes,[UInt8](repeating:0xa5,count:30))
                        XCTAssertTrue(record.defined.allSatisfy { !$0 },"Declared backing remains opaque after conversion writes nothing")
                    } else { XCTAssertTrue(record.defined.allSatisfy { $0 }) }
                }
                let newMusic=current.environment.music.suffix(current.environment.music.count-before.environment.music.count)
                XCTAssertEqual(newMusic.count,item.bodyMusic.count+messageCount)
                XCTAssertEqual(newMusic.filter { $0.kind == .message }.count,messageCount)
                if scenario==25 {
                    let render=try XCTUnwrap(newMusic.first { $0.kind == .method && $0.arguments.first==0x2c002000 && $0.arguments[1]==0x34 })
                    XCTAssertEqual(render.arguments,[0x2c002000,0x34,0,0]);XCTAssertTrue(render.strings.isEmpty)
                }
                let points=item.points.filter { $0.kind.hasPrefix("war-preparation-numeric-") }
                XCTAssertEqual(points.count,16);numeric += points.count
                graphicsAPIs += graphics.events.filter { $0.request != nil }.count
                musicEvents += item.bodyMusic.count;messages += messageCount
                FileHandle.standardError.write(Data("Music error War compared s\(scenario): \(key), exact rollback event\(stoppedAt)\n".utf8))
            }
        }
        XCTAssertEqual(compared,9);XCTAssertEqual(events,12028);XCTAssertEqual(numeric,144)
        XCTAssertEqual(rollbacks,27);XCTAssertEqual(prefixCalls,90);XCTAssertEqual(graphicsAPIs,827)
        XCTAssertEqual(musicEvents,221);XCTAssertEqual(messages,2);XCTAssertEqual(wrapperOwners,55)
        XCTAssertEqual(wideOwners,7);XCTAssertEqual(wideBytes,210)
        print("Music error War:9 whole returned callers,12028 ordered events,221 body music events,2 messages,827 graphics API requests,144 numeric checkpoints,55 wrapper owners,7 wide owners/210 bytes,27 coupled rollbacks,90 overlapping Native prefix calls/20 distinct references. No original execution or Windows/device claim.")
    }
}
