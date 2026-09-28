import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationInitializedLoadingTests: XCTestCase {
    typealias I = OriginalApplicationMenuInputTests
    typealias L = OriginalApplicationLoadingPrefixTests
    typealias B = OriginalBitmapSurfaceLoadingTests
    typealias E = OriginalApplicationDispatchEntryTests
    typealias F = OriginalApplicationFrontScreenTests
    typealias Body = OriginalApplicationScreenBodyTests
    typealias M = OriginalApplicationMenuReturnTests

    struct Resources {
        let bitmap: B.Resources,entry: E.Resources,front: F.Resources,body: Body.Resources,menu: M.Resources
        let input: I.Resources,loading: L.Resources

        init() throws {
            let url = try XCTUnwrap(Bundle.module.url(forResource:"original-first-damage-loading53",withExtension:"json",subdirectory:"Fixtures"))
            let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:50_000_000)
            XCTAssertEqual(data.count,39_453_480)
            XCTAssertEqual(MatchPreparationReference.digest(data),"ca664022718081a0263c03e664788c7837250f981469627465ccfe887fc7188f")
            let source = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
            let records = try XCTUnwrap(source["records"] as? [String:[String:Any]])
            XCTAssertEqual(Set(records.keys),Set(["winMain","loop","dispatch","frontResources","settings","front","body","menuReturn","menuInput","loadingPrefix"]))
            func record(_ name: String) throws -> [String:Any] { try XCTUnwrap(records[name]) }
            func string(_ value: [String:Any],_ name: String) throws -> String { try XCTUnwrap(value[name] as? String) }
            let startup = try record("winMain"),loop = try record("loop"),dispatch = try record("dispatch")
            let bitmaps = try record("frontResources"),settings = try record("settings")
            let frontCase = try record("front"),bodyCase = try record("body"),menuCase = try record("menuReturn")
            let tuple = try XCTUnwrap(source["parentTuple"] as? [Any])
            XCTAssertEqual(tuple.count,9)
            for (index,name) in [(1,"frontResources"),(3,"settings"),(5,"front"),(6,"body"),(7,"menuReturn"),(8,"menuInput")] {
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
            XCTAssertEqual(sourcePrecisionObservations,139)
            let terminal = try XCTUnwrap(source["terminal"] as? [String:Any])
            XCTAssertEqual(terminal["end"] as? String,"catalogAllocation")
            XCTAssertEqual((terminal["pc"] as? NSNumber)?.uint32Value,0x4450ac)
            XCTAssertEqual((terminal["sp"] as? NSNumber)?.uint32Value,0x1000e430)
            XCTAssertEqual((terminal["cw"] as? NSNumber)?.uint32Value,0x23f)
            let after = try XCTUnwrap(menuCase["after"] as? [String:Any])
            XCTAssertEqual((after["counter"] as? NSNumber)?.uint32Value,2)
            XCTAssertEqual((after["baseline"] as? NSNumber)?.uint32Value,123456822)
            XCTAssertEqual((menuCase["records"] as? [Any])?.count,25)
            let blobs = try XCTUnwrap(source["blobs"] as? [String:Any])
            let assets = try XCTUnwrap(source["assets"] as? [String:Any])
            XCTAssertEqual(blobs.count,3753);XCTAssertEqual(assets.count,24)
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
            let activation = try record("menuInput"),prefix = try record("loadingPrefix")
            let menuKey = try string(activation,"parent")
            let activationSpec = try XCTUnwrap(activation["spec"] as? [String:Any])
            let prefixSpec = try XCTUnwrap(prefix["spec"] as? [String:Any])
            XCTAssertEqual(activationSpec["label"] as? String,"activate-parent-0")
            XCTAssertEqual((activationSpec["parentIndex"] as? NSNumber)?.intValue,0)
            XCTAssertEqual(prefixSpec["label"] as? String,"own-parent-47")
            XCTAssertEqual((prefixSpec["parentIndex"] as? NSNumber)?.intValue,47)
            XCTAssertEqual((activation["callbacks"] as? [Any])?.count,3)
            XCTAssertEqual((activation["randomCalls"] as? [Any])?.count,3000)
            XCTAssertEqual((prefix["loads"] as? [Any])?.count,18)
            let request = try XCTUnwrap(prefix["catalogRequest"] as? [String:NSNumber])
            XCTAssertEqual(request["count"]?.uint32Value,81_273_768)
            XCTAssertEqual(request["returnPC"]?.uint32Value,0x41bff5)
            XCTAssertEqual(request["sp"]?.uint32Value,0x1000e430)
            // Published all-field source audit binds this exact activation to
            // historical graphics/color case47; no expected record is altered.
            input = try I.Resources(menu,supplied:packet(["cases":[activation],"menuParents":[menuKey:menuCase]]),
                expectedCounts:(1,1),referenceIndices:[47])
            loading = try L.Resources(supplied:packet(["cases":[prefix]]),expectedCases:1)
            XCTAssertEqual(input.referenceIndices,[47]);XCTAssertEqual(input.indices,[0])
        }
    }

    func run(_ r: Resources,inputFailure: String? = nil,loadingFailure: String? = nil) throws {
        var called = false,ownerSeen = false
        try I().run(0,r.input,r.menu,r.body,r.front,r.bitmap,r.entry,fail:inputFailure,loading:{ own,pending in
            called = true
            let result = try L().check(r.loading.c.cases[0],r.loading,own,pending,
                responses:r.input.c.cases[0].spec,fail:loadingFailure)
            XCTAssertEqual(result != nil,loadingFailure == nil)
            if let result { XCTAssertEqual(result.sounds.count,18) }
        },ownerAtLoading:{ owner in
            ownerSeen = true
            XCTAssertEqual(owner.loop.counter,7)
            XCTAssertEqual(owner.loop.timer.baseline,123456888)
            XCTAssertEqual(owner.state.random.state,3692555757)
        })
        XCTAssertEqual(called,inputFailure == nil);XCTAssertEqual(ownerSeen,inputFailure == nil)
    }

    func testInitializedBootstrapActivationAndCommonSoundsMatchSource() throws {
        try run(Resources())
        print("LOADING53 Native-owned Bootstrap/menu/input/common prefix;3 callbacks/3000 RNG/18 WAVs;pending catalog81273768;no fabricated loading return")
    }

    func testInitializedActivationFailuresPreservePriorCommittedIterations() throws {
        let r = try Resources()
        for failure in ["windowDefault#1","blit#3","soundMethod#3","write#1500","randomTable#1","free#1","method#3","commit"] {
            try run(r,inputFailure:failure)
        }
        print("LOADING53 eight activation rollback controls preserve prior committed iterations and effects")
    }

    func testInitializedCommonLoadingFailuresPreservePendingOwners() throws {
        let r = try Resources()
        for failure in ["write#1","blit#1","copy#12","method#1","commit"] {
            try run(r,loadingFailure:failure)
        }
        print("LOADING53 five loading rollback controls preserve pending owners and committed menu/effects")
    }
}
