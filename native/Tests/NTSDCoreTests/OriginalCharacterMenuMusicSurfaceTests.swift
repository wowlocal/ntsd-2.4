import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalCharacterMenuMusicSurfaceTests: XCTestCase {
    typealias Base = OriginalCharacterMenuSurfaceTests
    struct MusicSpec: Decodable { let nullAllocation: Bool? }
    struct Spec: Decodable { let label: String, music: MusicSpec? }
    struct MusicEvent: Decodable {
        let kind: OriginalMusicEvent.Kind, arguments: [UInt32], strings: [[UInt8]], response: OriginalMusicResponse
    }
    struct Event: Decodable { let music: MusicEvent? }
    struct Boundary: Decodable { let snapshot: Base.Snapshot, allocations: [Base.Record], eventCount: Int }
    struct Case: Decodable {
        let spec: Spec, events: [Event], musicBoundary: Boundary, musicAllocations: [Base.Record], rootSP: UInt32, bodySP: UInt32
    }
    struct Corpus: Decodable { let cases: [Case] }
    struct Environment: Equatable {
        var graphics = Base.Context()
        var music: [OriginalMusicEvent] = []
    }
    func resources() throws -> (Base.Resources,Corpus) {
        let url = try ProcessInfo.processInfo.environment["NTSD_CHARACTER_MENU_MUSIC_SURFACE"].map { URL(fileURLWithPath:$0) }
            ?? XCTUnwrap(Bundle.module.url(forResource:"original-character-menu-music-surface",withExtension:"json",subdirectory:"Fixtures"))
        let data = try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:120_000_000)
        return (try Base.Resources(url:url,expectedCases:21),try JSONDecoder().decode(Corpus.self,from:data))
    }
    func compareMusic(_ records: [Base.Record],_ memory: OriginalMusicMemory,_ a: Base.Adapter) throws {
        XCTAssertEqual(records.count,memory.allocations.count)
        for record in records {
            XCTAssertEqual(record.kind,"music-wide"); XCTAssertEqual(record.count,26)
            XCTAssertEqual(try a.r.blob(record.initial),a.pattern(record.count))
            let value = try XCTUnwrap(memory.allocations[record.address])
            XCTAssertEqual(value.bytes,try a.r.blob(record.bytes))
            XCTAssertEqual(value.defined,try a.r.blob(record.mask).map { $0 != 0 })
        }
    }
    @discardableResult
    func run(_ index: Int,_ r: Base.Resources,_ extra: Corpus,failure: String? = nil) throws -> Int {
        let c=r.c.cases[index], x=extra.cases[index], a=try Base.Adapter(c,r,failure:failure)
        XCTAssertEqual(c.spec.label,x.spec.label)
        let initial=try r.blob(c.before.globals)
        var globals=try OriginalStateRecord(bytes:Array(initial.prefix(OriginalMatchPreparation.globalSize)),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
        var music=OriginalMusicMemory(), resources=OriginalMenuResourceLoading(), env=Environment()
        let before=globals,beforeEnv=env,beforeMusic=music.allocations
        let unavailable: String?
        switch c.spec.label {
        case "first-description-after-music": unavailable="surface width"
        case "object-after-create-negative","object-after-cached","object-after-disabled": unavailable="bitmap width"
        case "object-after-empty-directory": unavailable="bitmap height"
        default: unavailable=nil
        }
        do {
            let result=try OriginalCharacterMenuStartup.runWithSurfaceLoading(globals:&globals,music:&music,resources:&resources,environment:&env,
                musicRequest: { event,env in
                    let expected=try XCTUnwrap(x.events[a.index].music); _=try a.next("music")
                    XCTAssertEqual(event,.init(expected.kind,expected.arguments,expected.strings),"\(c.spec.label) music event\(a.index-1)")
                    var response=expected.response
                    if event.kind == .allocate {
                        let pointer: UInt32 = x.spec.music?.nullAllocation == true ? 0 : 0x2c010020
                        response = .init(pointer:pointer,bytes:pointer == 0 ? nil : a.pattern(Int(event.arguments[0])))
                    } else if event.kind == .convert {
                        XCTAssertTrue(event.strings[0].allSatisfy { $0<128 })
                        let bytes=(event.strings[0]+[0]).flatMap { [$0,UInt8(0)] }
                        response = .init(result:event.arguments[3] == 0 ? 0 : Int32(event.strings[0].count+1),bytes:event.arguments[3] == 0 ? [] : bytes)
                    }
                    XCTAssertEqual(response,expected.response,"Own controlled music backing/conversion")
                    env.music.append(event)
                    return response
                }, allocate: { try a.allocate($0,&$1.graphics) }, perform: { try a.perform($0,&$1.graphics) },
                afterMusic: { entered,state,memory,env in
                    XCTAssertEqual(entered,!env.music.isEmpty)
                    XCTAssertEqual(a.index,x.musicBoundary.eventCount)
                    a.shadow=state.bytes+a.suffix
                    XCTAssertEqual(a.shadow,try r.blob(x.musicBoundary.snapshot.globals))
                    try compareMusic(x.musicBoundary.allocations,memory,a)
                    if failure=="afterMusic" { throw Base.Stop.injected }
                }, checkpoint: { try a.stored($0,$1,$2,&$3.graphics) }, observe: { try a.observe($0,&$1.graphics) },
                beforeCommit: { _,state,memory,images,env in
                    XCTAssertEqual(state.bytes+a.suffix,try r.blob(c.after.globals))
                    try compareMusic(x.musicAllocations,memory,a)
                    try a.compare(c.records,images.bitmaps,env.graphics)
                    if failure=="beforeCommit" { throw Base.Stop.injected }
                })
            XCTAssertNil(failure); XCTAssertNil(unavailable)
            XCTAssertEqual(result.resources.continuation.rawValue,c.end)
            XCTAssertEqual(result.resources.selectionAtEntry,try before.integer(at:0x4512c8-OriginalMatchPreparation.globalBase,as:UInt32.self))
        } catch {
            if let unavailable {
                XCTAssertEqual(error as? Base.API.Boundary,.unknownField(unavailable))
                XCTAssertEqual(a.index,x.musicBoundary.eventCount+(unavailable=="surface width" ? 14 : 7))
            } else { guard failure != nil, case Base.Stop.injected = error else { throw error } }
            XCTAssertEqual(globals,before); XCTAssertEqual(music.allocations,beforeMusic)
            XCTAssertEqual(env,beforeEnv); XCTAssertTrue(resources.bitmaps.isEmpty)
            return a.unknown
        }
        XCTAssertEqual(a.index,c.events.count); XCTAssertEqual(a.stores,c.checkpoints.count)
        XCTAssertEqual(globals.bytes+a.suffix,try r.blob(c.after.globals))
        try compareMusic(x.musicAllocations,music,a); try a.compare(c.records,resources.bitmaps,env.graphics)
        XCTAssertEqual(env.graphics.imagesDeleted,Dictionary(uniqueKeysWithValues:c.images.map { (UInt32($0.key)!,$0.value.deleted) }))
        XCTAssertEqual(env.graphics.surfacesReleased,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.released) }))
        XCTAssertEqual(env.graphics.surfaceDescriptions,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.description) }))
        XCTAssertEqual(env.graphics.dcs,Dictionary(uniqueKeysWithValues:c.dcs.map { (UInt32($0.key)!,$0.value) }))
        for h in c.helpers { XCTAssertEqual(h.returnSP,h.sp+4+h.pop) }
        XCTAssertEqual(c.before.cw,0x37f); XCTAssertEqual(c.after.cw,0x37f)
        XCTAssertEqual(c.before.sp,x.rootSP); XCTAssertEqual(c.after.sp,x.bodySP); XCTAssertEqual(x.rootSP-x.bodySP,0xab4)
        return a.unknown
    }
    func testContinuousMusicAndWholeBitmapMenuWithOwnedLogStorage() throws {
        let (r,x)=try resources(); var unknown=0
        for i in r.c.cases.indices { unknown += try run(i,r,x) }
        XCTAssertGreaterThan(unknown,0)
        print("CHARACTER MENU MUSIC SURFACE16 complete controlled matches;5 explicit unknown-operand rollback rejections; private current-call API bytes remain unknown: \(unknown)")
    }
    func testLateCombinedErrorsRollBackMusicResourcesGlobalsAndEnvironment() throws {
        let (r,x)=try resources()
        for failure in ["afterMusic","bitmap5","createSurface#11","deleteObject#11","colorKey#11","flag","complete","beforeCommit"] {
            try run(0,r,x,failure:failure)
        }
    }
}
