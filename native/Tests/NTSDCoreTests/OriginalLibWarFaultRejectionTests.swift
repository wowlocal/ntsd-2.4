import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

/// Saved source faults establish boundaries, not successful matches. Every
/// Native chain builds its own ten-call prefix and retains its returned parents.
/// Only the reached request/checkpoint prefix is compared before full rollback.
final class OriginalLibWarFaultRejectionTests: XCTestCase {
    typealias Test = OriginalLibWarPreparationTests
    private struct Envelope: Decodable { let count: Int,sha256: String,deflate: String }
    private let pins: [Int:(Int,String)] = [
        31:(16391099,"208455097ad0acbc4be61381917b3ebadcb84f4cedb276d1b50f6b5d3da95c34"),
        41:(16389111,"2ed8eddf4a36609e93b85493680a59420aa755eabededf7bdd4697cd0ac0e02a"),
        51:(16397379,"80b11129381214fcc57762b452ba6698b22e0854d004944d272ffc1697326232"),
        61:(16389408,"4ff6f3383b86bd7b0ecb91eb0455f20ba27a6a58d4002c835827af9cf352b7db"),
        71:(16398469,"62b7ab8accb33326f2a9f75fedf6b6f6df0db7944d61c09635ca0fd3830d1fcf"),
        81:(16390364,"4e7d45db5e68ba4a5b80b2ef9c91adbd86b955ade3d0fc5c71feccf3272db96c"),
        91:(16398157,"4e255a6b4fdf37e23009d61405f56a09333b33832b8cbdd60d2261a13aded724"),
        220:(23916521,"0ad21c2e4b63bb19b7dfed20163015cc0e635c622cf9a07f9faa095fd4a7f45e"),
        280:(32841343,"3df59245ed7dd20cd8046076cbc32cbeeac7e130b85e96964f77765c9b7132ce"),
        30:(35639552,"d333c0f19de94ac0cfa92c5354a7e335c33e85eb0bb20d52b9aeb3f627e7de56"),
        40:(35669702,"d3c0825f0d854cd5f07b4541bf1724b920ad19aac37ded3e032c544f4cd4f36e"),
        50:(35670064,"3fb890f433a2a441242cb5bc4c90f4e8c7f26f0ed837b82b475ccbd18e81d34b"),
        60:(35676576,"69bb9f8d5b4baf84571410f6dee2e74df8d5d6c597d8b6c9a63b40eb85d30977"),
        70:(35677671,"41cacc90f44579bd2be4a9c6c6f07cb74bb8e8b344e55878269f06466b3982ab"),
        80:(35698247,"e1b3dec0f3fd59a39fcc77f3607b46aae8b92e45a8a337562b3ac2eec2fa120c"),
        90:(35698291,"e6ed43c9988301c61a1ccf22cebd54bcb4c06cb88c76e71d3b44151942799fdd"),
    ]
    private func resources(_ scenario: Int,_ ordinal: Int,_ index: Test.Index,
                           _ catalog: OriginalLoadedCatalog,fault: Bool) throws -> Test.Resources {
        let (count,sha)=try XCTUnwrap(pins[scenario*10+ordinal])
        let raw: Data
        if let directory=ProcessInfo.processInfo.environment["NTSD_WAR_FAULT_REJECTION_DIRECTORY"] {
            let path=String(format:"war-preparation-fs-errors-s%02d-capture2.parts/call-%02d.json",scenario,ordinal)
            raw=try Data(contentsOf:URL(fileURLWithPath:directory).appendingPathComponent(path))
        } else {
            let family=fault ? "fault-rejection" : (scenario==3 ? "nullable" : "partial-surface")
            let name=String(format:"original-lib-war-%@-s%02d-call-%02d",family,scenario,ordinal)
            let url=try XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures"))
            let envelope=try JSONDecoder().decode(Envelope.self,from:Data(contentsOf:url))
            guard envelope.count==count,envelope.sha256==sha else { throw Test.Stop.unexpected }
            raw=Data(try MatchPreparationReference.inflate(envelope.deflate,count:count,maximumCount:40_000_000))
        }
        guard raw.count==count,MatchPreparationReference.digest(raw)==sha else { throw Test.Stop.unexpected }
        let source=try XCTUnwrap(JSONSerialization.jsonObject(with:raw) as? [String:Any])
        let item=try XCTUnwrap(source["case"] as? [String:Any])
        XCTAssertEqual(item["end"] as? String,fault ? "sourceFault" : "returned")
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

    func testNineNativeGuardsRetainWholeCallerState() throws {
        let index=try Test.Index(),test=Test()
        let url=try XCTUnwrap(Bundle.module.url(forResource:"original-loaded-catalog",withExtension:"json",subdirectory:"Fixtures"))
        var loaded: OriginalLoadedCatalog?
        _=try LoadedCatalogReference.compare(Data(contentsOf:url),onLoaded:{ loaded=$0 })
        let catalog=try XCTUnwrap(loaded)
        var prefixCalls=0,parentCalls=0,rejected=0,events=0,points=0,numeric=0,music=0,graphics=0,pairs=0
        for scenario in Array(3...9)+[22,28] {
            var retained: Test.Retained?
            for number in 0..<10 {
                try autoreleasepool {
                    let r=try Test.Resources(index,number,catalog:catalog),item=r.corpus.cases[0]
                    if number==0 { try test.compareParent(item,r,firstCase:0) }
                    _=try test.run(item,r,&retained);prefixCalls += 1
                }
            }
            if scenario<10 {
                try autoreleasepool {
                    let r=try resources(scenario,0,index,catalog,fault:false)
                    _=try test.run(r.corpus.cases[0],r,&retained);parentCalls += 1
                }
            }
            try autoreleasepool {
                let r=try resources(scenario,scenario<10 ? 1 : 0,index,catalog,fault:true),item=r.corpus.cases[0]
                let releasePairs=[3,5,7,9].contains(scenario) ? 4 : 0
                let eventCount=scenario==22 ? 917 : (scenario==28 ? 1316 : (releasePairs==4 ? 805 : 797))
                let message=scenario==3 ? "BG release ownership" : (scenario<10 ? "Arena bitmap release ownership" :
                    (scenario==22 ? "Original music: Null COM continuation" : "War preparation: Recording allocation unavailable or live alias"))
                let pg=try XCTUnwrap(item.preparationGraphics)
                if scenario<10 {
                    XCTAssertEqual(pg.allocationStart,5)
                    XCTAssertEqual(pg.events.count,releasePairs*2)
                    let releaseStart=scenario==9 ? 2 : 1
                    for pair in 0..<releasePairs {
                        XCTAssertEqual(pg.events[pair*2].key,"release#\(releaseStart+pair)")
                        XCTAssertEqual(pg.events[pair*2+1].key,"free#\(pair+1)")
                        XCTAssertEqual(pg.events[pair*2+1].request?.words,[UInt32(0x76004020)+UInt32(pair)*0x2000])
                    }
                    if scenario>3 {
                        let own=try XCTUnwrap(retained),layer=scenario.isMultiple(of:2) ? 0 : 4
                        let bitmap=own.prepared.bitmaps[catalog.bitmaps.count+layer]
                        let wrapper=UInt32(0x76004020)+UInt32(layer)*0x2000
                        XCTAssertEqual(try bitmap.storage.integer(at:0,as:UInt32.self),0)
                        if scenario<8 {
                            XCTAssertFalse(bitmap.input.present)
                            XCTAssertNil(own.environment.preparationGraphics.surfaceForWrapper[wrapper])
                        } else {
                            XCTAssertTrue(bitmap.input.present)
                            let surface=try XCTUnwrap(own.environment.preparationGraphics.surfaceForWrapper[wrapper])
                            XCTAssertEqual(own.environment.preparationGraphics.surfacesReleased[surface],true)
                        }
                    }
                }
                if scenario==22 {
                    let input=try XCTUnwrap(item.resourceFailureInput?.music)
                    XCTAssertEqual(input.queryResults,[0,-1,0,0]);XCTAssertEqual(input.queryPointers,[0x2c002100,0,0x2c002300,0x2c002400])
                    XCTAssertEqual(item.bodyMusic.filter { $0.kind == .queryInterface }.count,3)
                    XCTAssertFalse(item.bodyMusic.contains { $0.kind == .allocate })
                }
                events += try test.run(item,r,&retained,rejection:.init(message:message,frontEvents:eventCount,
                    releaseFreePairs:releasePairs,replayNull:scenario==28))
                rejected += 1;points += item.points.count;pairs += releasePairs
                numeric += item.points.filter { $0.kind.hasPrefix("war-preparation-numeric-") }.count
                music += item.bodyMusic.count;graphics += pg.events.count
                FileHandle.standardError.write(Data("War Native rejected s\(scenario) at \(message): \(eventCount) prefix events, whole caller rollback\n".utf8))
            }
        }
        XCTAssertEqual(prefixCalls,90);XCTAssertEqual(parentCalls,7);XCTAssertEqual(rejected,9)
        XCTAssertEqual(events,7844);XCTAssertEqual(points,214);XCTAssertEqual(numeric,32)
        XCTAssertEqual(music,38);XCTAssertEqual(graphics,202);XCTAssertEqual(pairs,16)
        print("War fault boundaries:97 returned parent invocations,9 exact Native rejections/whole rollbacks,7844 front events plus one declared NULL allocator result,214 checkpoints/32 numeric,38 music/202 graphics events,16 staged Release/free pairs. Source faults are not matched; no original execution.")
    }
}
