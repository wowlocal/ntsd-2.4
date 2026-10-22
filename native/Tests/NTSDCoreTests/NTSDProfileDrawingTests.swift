import XCTest
@testable import RandoriCore
import NTSDProfile

/// ENGINE_SPLIT E5c-1f: the world drawing's shadow (A45) and "Com" label (A46)
/// follow the profile. Synthetic records: one active Actor whose blink counter
/// (+8) leaves only the row under test to draw; the first bitmap fetch stops the
/// pass after its "draw" event.
final class NTSDProfileDrawingTests: XCTestCase {
    enum Stop: Error { case fetch }
    func defined(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0,count: size),defined: [Bool](repeating: true,count: size))
    }
    func drawing(shadowless: OriginalIDSet? = nil,unlabelled: OriginalIDSet? = nil) -> OriginalGameRules {
        let n = NTSDProfile.rules
        return n.with(drawing: .init(shadowless: shadowless ?? n.shadowless,unlabelledComputers: unlabelled ?? n.unlabelledComputers))
    }
    /// The tokens of the "draw" events for an Actor with this ID in this slot and
    /// blink, team and type: 0x77 is the shadow (the background's +0x98c), 0x55
    /// the "Com" label's font (0x44fd80).
    func draws(id: Int32,slot: Int,blink: Int32,team: Int32 = 0,rules: OriginalGameRules) throws -> [UInt32] {
        var world = try defined(0x7d8);try world.write(UInt8(1),at: 4+slot)
        var actors = [try defined(0x420)]
        for (o,v): (Int,Int32) in [(8,blink),(0x364,team)] { try actors[0].write(v,at: o) }
        var globals = try defined(0xb440);try globals.write(Int32(0x55),at: 0x44fd80-0x44d000)
        var bg = try defined(0x990);try bg.write(UInt32(0x77),at: 0x98c)
        var header = try defined(0x7a4);try header.write(id,at: 0x6f4)
        let h = header,frame = try defined(0x178)
        var tokens: [UInt32] = []
        do {
            try OriginalWorldDrawing.draw(world: world,actors: &actors,globals: globals,backgrounds: [bg],target: 0,phase: 0,header: { _ in h },
                frame: { _,_ in frame },catalogBitmap: { _ in throw Stop.fetch },resourceBitmap: { _ in throw Stop.fetch },performBlit: { _ in 0 },
                rules: rules,observe: { if $0.kind == "draw" { tokens.append($0.arguments[0]) } })
        } catch Stop.fetch {}
        return tokens
    }
    func testShadowlessA45() throws {
        // Blink −28: the shadow only (no Actor drawing, no label).
        XCTAssertEqual(try draws(id: 5,slot: 0,blink: -28,rules: NTSDProfile.rules),[0x77])
        XCTAssertEqual(try draws(id: 223,slot: 0,blink: -28,rules: NTSDProfile.rules),[])
        XCTAssertEqual(try draws(id: 224,slot: 0,blink: -28,rules: NTSDProfile.rules),[])
        XCTAssertEqual(try draws(id: 223,slot: 0,blink: -28,rules: drawing(shadowless: OriginalIDSet([5]))),[0x77])
        XCTAssertEqual(try draws(id: 5,slot: 0,blink: -28,rules: drawing(shadowless: OriginalIDSet([5]))),[])
        XCTAssertEqual(try draws(id: 224,slot: 0,blink: -28,rules: drawing(shadowless: OriginalIDSet([5]))),[0x77])
    }
    func testComputerLabelA46() throws {
        // Blink −22: the label only; a team-5 type-0 Actor in slot 20.
        func label(_ id: Int32,_ rules: OriginalGameRules) throws -> Bool { try draws(id: id,slot: 20,blink: -22,team: 5,rules: rules) == [0x55] }
        for id: Int32 in [29,38,50,-1] { XCTAssertTrue(try label(id,NTSDProfile.rules),"\(id)") }
        for id: Int32 in [30,37,39,49] { XCTAssertFalse(try label(id,NTSDProfile.rules),"\(id)") }
        XCTAssertTrue(try label(35,drawing(unlabelled: OriginalIDSet([60]))))
        XCTAssertFalse(try label(60,drawing(unlabelled: OriginalIDSet([60]))))
        XCTAssertFalse(try label(29,drawing(unlabelled: OriginalIDSet([29,38]))));XCTAssertFalse(try label(38,drawing(unlabelled: OriginalIDSet([29,38]))))
    }
}
