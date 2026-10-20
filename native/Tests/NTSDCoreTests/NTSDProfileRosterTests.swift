import XCTest
@testable import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E5c-2d: Random's roster candidates (OriginalMatchContinuation,
/// A74), the tournament roster's hidden characters (A72) and the bracket's
/// favourites (A78) follow the profile. A small declared catalog (the
/// OriginalWarSetupNativeTests pattern), every Object type 0.
final class NTSDProfileRosterTests: XCTestCase {
    enum Stop: Error { case here }
    /// A state over these catalog IDs: globals unknown but the eight selected seats
    /// (−1, none), or (`zeroGlobals`) all zero with an RNG table of ones.
    func state(ids: [Int],rules: OriginalGameRules,zeroGlobals: Bool = false) throws -> OriginalMatchPreparation {
        try NTSDProfileCatalog.state(ids: ids,rules: rules,zeroGlobals: zeroGlobals)
    }
    func testRandomCandidatesA74() throws {
        let ids=[1,5,29,30,35,49,50,2,-3]
        // Ordinal 0 never (no seat selects it); then IDs below 30 under NTSD's profile.
        XCTAssertEqual(try state(ids:ids,rules:NTSDProfile.rules).randomRosterCandidates(),[1,2,7,8])
        let n=NTSDProfile.rules
        let moved=n.with(roster:.init(hiddenRoster:n.hiddenRoster,randomCandidates:OriginalIDRange(30..<50),bracketFavourites:n.bracketFavourites))
        XCTAssertEqual(try state(ids:ids,rules:moved).randomRosterCandidates(),[3,4,5])
    }
    /// The tournament setup (mode 2, menu 20) with Right pressed on the first seat:
    /// the ordinal its roster stops at, from −1 (A72).
    func rosterStop(ids: [Int],unlocked: Int32,rules: OriginalGameRules) throws -> Int32 {
        var s=try state(ids:ids,rules:rules,zeroGlobals:true),text: OriginalLibSurfaceText? = .init(),past=false,stop: Int32?
        for (a,v): (Int,Int32) in [(0x451160,2),(0x44d020,20),(0x458428,unlocked),(0x455608,0x26006000)] { try s.setGlobal(a,v) }
        // Right (+0xd0) on the first seat's Actor; the menu input step turns it into 0x4513b0.
        let first=Int(try s.world.integer(at:0x194,as:UInt32.self));try s.actors[first].write(UInt8(1),at:0xd0)
        do {
            _ = try OriginalTournamentSetup.advance(state:&s,libraryText:&text,target:0x26006000,
                input:.init(dcResult:0,dc:0x70000000,methodResult:-1,drawResults:[-1],shellResult:33),fillBacking:[UInt8](repeating:0xa5,count:100),
                draw:{ _,globals in
                    if past { stop=try globals.integer(at:0x44d0c0-OriginalMatchPreparation.globalBase,as:Int32.self);throw Stop.here }
                },observe:{ _ in },checkpoint:{ cp,_ in if cp.pc==0x432c76 { past=true } })
        } catch Stop.here {}
        return try XCTUnwrap(stop)
    }
    func testHiddenRosterA72() throws {
        // Ordinals 0…8 are the 30s, 9 is 122.
        let ids=[30,31,33,34,39,32,35,36,37,122,123,1]
        XCTAssertEqual(try rosterStop(ids:ids,unlocked:0,rules:NTSDProfile.rules),9)
        XCTAssertEqual(try rosterStop(ids:ids,unlocked:1,rules:NTSDProfile.rules),0)
        let n=NTSDProfile.rules
        let moved=n.with(roster:.init(hiddenRoster:OriginalIDSet([30,31]),randomCandidates:n.randomCandidates,bracketFavourites:n.bracketFavourites))
        XCTAssertEqual(try rosterStop(ids:ids,unlocked:0,rules:moved),2)
    }
    /// A computer-only bracket match between ordinals 1 and 2 (menu 26, scores 0):
    /// the side-selecting coin flip's stream (nil without one) and the two scores.
    func bracket(ids: [Int],rules: OriginalGameRules) throws -> (stream: UInt32?,scores: [Int32]) {
        var s=try state(ids:ids,rules:rules,zeroGlobals:true),locals: [Int:Int32]=[:],text: OriginalLibSurfaceText? = .init()
        for (a,v): (Int,Int32) in [(0x44d020,26),(0x4513b8,1),(0x44d0e4,1),(0x44d0c0,1),(0x44d0c4,2)] { try s.setGlobal(a,v) }
        var events: [OriginalFrontScreenEvent]=[],scores: [Int32]?
        do {
            _ = try OriginalTournamentBracket.advance(state:&s,locals:&locals,libraryText:&text,initialize:false,target:0x26006000,
                fillBacking:[UInt8](repeating:0xa5,count:100),resumeMusic:{ _ in },draw:{ _,_ in },observe:{ events.append($0) },
                checkpoint:{ cp,st in
                    if cp.pc==0x433c22 { scores=try [0x451384,0x451388].map { try st.global($0) };throw Stop.here }
                })
        } catch Stop.here {}
        let flip=events.first { $0.kind=="random" && [0xfa,0xfb].contains($0.arguments.first) }
        return (flip?.arguments.first,try XCTUnwrap(scores))
    }
    func testBracketFavouritesA78() throws {
        let ids=[1,55,5]
        let n=NTSDProfile.rules
        func favourites(_ ids: [Int32]) -> OriginalGameRules {
            n.with(roster:.init(hiddenRoster:n.hiddenRoster,randomCandidates:n.randomCandidates,bracketFavourites:OriginalIDSet(ids)))
        }
        var r=try bracket(ids:ids,rules:n)
        XCTAssertNil(r.stream,"55 beats 5 without a coin flip");XCTAssertEqual(r.scores,[2,1])
        r=try bracket(ids:ids,rules:favourites([5]))
        XCTAssertNil(r.stream);XCTAssertEqual(r.scores,[1,2],"5 beats 55")
        r=try bracket(ids:ids,rules:favourites([55,5]));XCTAssertEqual(r.stream,0xfb,"both: a flip, the first a member")
        r=try bracket(ids:ids,rules:favourites([]));XCTAssertEqual(r.stream,0xfa,"neither")
    }
}

/// A match preparation over a small declared catalog (shared by the roster and
/// lifecycle tests).
enum NTSDProfileCatalog {
    static func unknown(_ count: Int) throws -> OriginalStateRecord {
        try .init(bytes:[UInt8](repeating:0xa5,count:count),defined:[Bool](repeating:false,count:count))
    }
    static func defined(_ count: Int) throws -> OriginalStateRecord {
        try .init(bytes:[UInt8](repeating:0,count:count),defined:[Bool](repeating:true,count:count))
    }
    static func state(ids: [Int],rules: OriginalGameRules,zeroGlobals: Bool = false) throws -> OriginalMatchPreparation {
        var parent=try OriginalCatalogRegistry.regionSizes.mapValues { try NTSDProfileCatalog.unknown($0) }
        let background=try NTSDProfileCatalog.unknown(0x990),stage=try NTSDProfileCatalog.unknown(OriginalStageLoader.stageSize)
        let backgrounds=[OriginalStateRecord](repeating:background,count:101)
        parent[0x4d81060]=backgrounds[99];parent[0x4d819f0]=backgrounds[100]
        let source="<object> "+ids.enumerated().map { "id: \($0.element) type: 0 file: object\($0.offset).txt" }.joined(separator:" ")+" <object_end>"
        let object="<bmp_begin> name: RosterTrial head: head.bmp small: small.bmp file(0-0): sheet.bmp w: 40 h: 40 row: 1 col: 1 <bmp_end>"
        let key=Array("SiuHungIsAGoodBearBecauseHeIsVeryGood".utf8)
        let stages=[UInt8](repeating:0,count:123)+Array("end".utf8).enumerated().map { $0.element &+ key[($0.offset+123)%key.count] }
        let catalog=try OriginalLoadedCatalog(source:Array(source.utf8),fileName:"data.txt",translation:.raw,rules:rules,
            parentBacking:parent,backgroundBacking:backgrounds,stageBacking:[OriginalStateRecord](repeating:stage,count:60),
            fileSource:{ $0=="data\\stage.dat" ? stages : Array(object.utf8) },
            bitmapSource:{ .init(path:$0,present:true,width:80,height:80) })
        let bootstrap=try OriginalWorldBootstrap(worldBacking:[UInt8](repeating:0xa5,count:OriginalStateRecord.worldPrefixSize),
            actorBacking:[[UInt8]](repeating:[UInt8](repeating:0xa5,count:OriginalStateRecord.actorSize),count:400),selector:4)
        let base=OriginalMatchPreparation.globalBase
        var g=try zeroGlobals ? defined(OriginalMatchPreparation.globalSize) : unknown(OriginalMatchPreparation.globalSize)
        if zeroGlobals { for i in 0..<3000 { try g.write(UInt8(1),at:0x44ff90+i-base) } }
        else { for seat in 0..<8 { try g.write(Int32(-1),at:0x451248+seat*4-base) } }
        return try .init(catalog:catalog,bootstrap:bootstrap,globals:g)
    }
}
