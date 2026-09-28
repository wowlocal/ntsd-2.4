import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationInitializedMenuTests: XCTestCase {
    typealias B = OriginalBitmapSurfaceLoadingTests
    typealias E = OriginalApplicationDispatchEntryTests
    typealias F = OriginalApplicationFrontScreenTests
    typealias Body = OriginalApplicationScreenBodyTests
    typealias M = OriginalApplicationMenuReturnTests

    struct Resources {
        let bitmap: B.Resources,entry: E.Resources,front: F.Resources,body: Body.Resources,menu: M.Resources

        init() throws {
            let url = try XCTUnwrap(Bundle.module.url(forResource:"original-first-damage-menu53",withExtension:"json",subdirectory:"Fixtures"))
            let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:16_000_000)
            XCTAssertEqual(data.count,12_492_813)
            XCTAssertEqual(MatchPreparationReference.digest(data),"4d8a2e52deeb88bcefa8d1a80553fb739fa69e06ed6c24e4bbe6472c8037370a")
            let source = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
            let records = try XCTUnwrap(source["records"] as? [String:[String:Any]])
            XCTAssertEqual(Set(records.keys),Set(["winMain","loop","dispatch","frontResources","settings","front","body","menuReturn"]))
            func record(_ name: String) throws -> [String:Any] { try XCTUnwrap(records[name]) }
            func string(_ value: [String:Any],_ name: String) throws -> String { try XCTUnwrap(value[name] as? String) }
            let startup = try record("winMain"),loop = try record("loop"),dispatch = try record("dispatch")
            let bitmaps = try record("frontResources"),settings = try record("settings")
            let frontCase = try record("front"),bodyCase = try record("body"),menuCase = try record("menuReturn")
            let tuple = try XCTUnwrap(source["parentTuple"] as? [Any])
            XCTAssertEqual(tuple.count,8)
            for (index,name) in [(1,"frontResources"),(3,"settings"),(5,"front"),(6,"body"),(7,"menuReturn")] {
                XCTAssertEqual(try XCTUnwrap(tuple[index] as? NSDictionary),try record(name) as NSDictionary)
            }
            let bitmapKey = try string(settings,"parent"),settingsKey = try string(frontCase,"parent")
            let frontKey = try string(bodyCase,"parent"),bodyKey = try string(menuCase,"parent")
            XCTAssertEqual(tuple[0] as? String,bitmapKey);XCTAssertEqual(tuple[2] as? String,settingsKey)
            XCTAssertEqual(tuple[4] as? String,frontKey)
            XCTAssertEqual(try string(loop,"parent"),try string(dispatch,"parent"))
            let nested = try XCTUnwrap(bitmaps["parents"] as? [String:[String:Any]])
            XCTAssertEqual(try XCTUnwrap(nested["parent"]) as NSDictionary,startup as NSDictionary)
            XCTAssertEqual(try XCTUnwrap(nested["loop"]) as NSDictionary,loop as NSDictionary)
            XCTAssertEqual(try XCTUnwrap(nested["entry"]) as NSDictionary,dispatch as NSDictionary)

            // This validates source CPU observations, not Native hardware FPU state.
            var sourcePrecisionObservations = 0
            func precision(_ value: Any) {
                if let dictionary = value as? [String:Any] {
                    for (key,child) in dictionary {
                        if key == "cw" || key == "controlWord" {
                            XCTAssertEqual((child as? NSNumber)?.uint32Value,0x23f)
                            sourcePrecisionObservations += 1
                        } else { precision(child) }
                    }
                } else if let array = value as? [Any] { array.forEach(precision) }
            }
            precision(records)
            XCTAssertEqual(sourcePrecisionObservations,78)
            let terminal = try XCTUnwrap(source["terminal"] as? [String:Any])
            XCTAssertEqual(terminal["end"] as? String,"iteration")
            XCTAssertEqual((terminal["pc"] as? NSNumber)?.uint32Value,0x43d110)
            XCTAssertEqual((terminal["sp"] as? NSNumber)?.uint32Value,0x1000effc)
            XCTAssertEqual((terminal["cw"] as? NSNumber)?.uint32Value,0x23f)
            let after = try XCTUnwrap(menuCase["after"] as? [String:Any])
            XCTAssertEqual((after["counter"] as? NSNumber)?.uint32Value,2)
            XCTAssertEqual((after["baseline"] as? NSNumber)?.uint32Value,123456822)
            XCTAssertEqual((menuCase["records"] as? [Any])?.count,25)
            let blobs = try XCTUnwrap(source["blobs"] as? [String:Any])
            let assets = try XCTUnwrap(source["assets"] as? [String:Any])
            XCTAssertEqual(blobs.count,468);XCTAssertEqual(assets.count,24)
            let exe = try string(source,"exeSHA256")
            // Project complete immutable records into the existing comparator
            // schemas. No expected after-state is passed to a Core initializer.
            func packet(_ fields: [String:Any]) throws -> Data {
                try JSONSerialization.data(withJSONObject:fields.merging(["blobs":blobs,"assets":assets,"exeSHA256":exe]) { first,_ in first })
            }
            bitmap = try B.Resources(supplied:packet(["cases":[bitmaps]]),expectedCases:1)
            entry = try E.Resources(supplied:packet(["cases":[dispatch],
                "parents":[try string(loop,"parent"):startup],
                "loops":[try string(dispatch,"loop"):loop]]),expectedCases:1)
            front = try F.Resources(supplied:packet(["cases":[frontCase],
                "settingsParents":[settingsKey:settings],"bitmapParents":[bitmapKey:bitmaps]]),
                expectedCounts:(1,1),sourceControlWord:0x23f)
            body = try Body.Resources(front,supplied:packet(["cases":[bodyCase],"frontParents":[frontKey:frontCase]]),expectedCounts:(1,1))
            menu = try M.Resources(body,front,supplied:packet(["cases":[menuCase],
                "bodyParents":[bodyKey:bodyCase],"frontParents":[frontKey:frontCase]]),expectedCounts:(1,1,1))
            XCTAssertEqual(front.settings.c.cases.count,1)
        }
    }

    func testInitializedSourceMatchesOwnBootstrapAndWholeMenu() throws {
        let r = try Resources()
        try OriginalApplicationBootstrapTests().runMenu(0,r.menu,r.body,r.front,r.bitmap,r.entry)
        print("MENU53 native own Bootstrap/whole first-menu source comparison;8 retained stages;25 bitmap owners;World0/dispatcher1;counter2/baseline123456822")
    }

    func testInitializedMenuLateFailuresRetainCommittedStartupAndResize() throws {
        let r = try Resources()
        let failures = ["settings:scan#47","settings:gets#3","settings:eof#2","settings:close#1","settings:settingsReturn#1",
            "prefix:fill","prefix:format","prefix:createSurface#1","prefix:deleteObject#1","prefix:backgroundStore","prefix:blit",
            "body:enter#1","body:leave#1","body:writeLocal#50","body:setBackgroundMode#2","body:releaseDC#3","body:blit#2",
            "blit#1","panel#1","blit#2","method#1","write#2","dispatchReturn","time#1","write#3","commit"]
        XCTAssertEqual(failures.count,26)
        for failure in failures {
            try OriginalApplicationBootstrapTests().runMenu(0,r.menu,r.body,r.front,r.bitmap,r.entry,fail:failure)
        }
        print("MENU53 native26 late rollback controls;committed startup/resize and whole attempted state/effects retained;not original API-fault matches")
    }
}
