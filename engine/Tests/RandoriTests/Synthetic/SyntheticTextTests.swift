import Foundation
import XCTest
@testable import RandoriCore
@testable import RandoriRuntime

/// ENGINE_SPLIT E7f, rung 4: text. The engine's GDI text (the Core's GetDC,
/// SetBkMode, SetBkColor, SetTextColor, TextOutA and ReleaseDC, replayed on the
/// display, OriginalMacRuntimeLoading.swift:640-645) is drawn through the host's
/// glyph source; E7d's runs gave every string an empty mask. Here the match of
/// rungs 1-3 runs again with SyntheticGlyphs, an invented 3×5 font, and these
/// now draw: the menus' labels (the character and computer screens' names
/// and teams, the settings' difficulty, music and arena name), every
/// gameplay body's input line (OriginalPostDrawImpulses.swift:5-10, 39-41) and
/// recording notices ("Start recording '…'", "Recording file '…' saved!",
/// OriginalMenuPresentation.swift:286-291, with the run's host-independent
/// replay name), and the result screen's numbers and time
/// (OriginalResultLayout.swift:129-131, 154-159). Those frames are pinned. The HUD
/// draws no names, only the team mark (frame 254 of the team font,
/// OriginalWorldHUD.swift:116); the result's player labels ("P1", "Com") are
/// bitmap-font draws of the pack's own pictures (OriginalResultLayout.swift:113-125),
/// not GDI text, so the glyph source does not reach them.
final class SyntheticTextTests: XCTestCase {
    typealias Match = SyntheticComputerMatch

    func testGlyphSourceMasks() {
        let zero = SyntheticGlyphs.mask(Array("0".utf8))
        XCTAssertEqual([zero.advance, zero.width, zero.height, zero.originX, zero.originY], [8, 8, 16, 0, 0])
        XCTAssertEqual(zero.bits.filter { $0 != 0 }.count, 12 * 4, "twelve pixels of the 3×5 glyph, each 2×2")
        XCTAssertEqual(SyntheticGlyphs.mask(Array("Ab".utf8)), SyntheticGlyphs.mask(Array("aB".utf8)), "lower case draws as upper case")
        XCTAssertEqual(SyntheticGlyphs.mask([0x7e]).bits.filter { $0 != 0 }.count, 15 * 4, "a byte without a glyph is a block")
        XCTAssertEqual(SyntheticGlyphs.mask(Array("  ".utf8)).bits.filter { $0 != 0 }.count, 0)
        // Rows 0-2 and 13-15 stay empty: the glyphs stand on the baseline (13).
        for row in [0, 1, 2, 13, 14, 15] { XCTAssertEqual(zero.bits[(row*8)..<(row*8 + 8)].filter { $0 != 0 }.count, 0) }
    }

    func testTextDrawsInTheMenusAndTheResultScreen() throws {
        let (g, o) = try MainActor.assumeIsolated { (try Match.observation(glyphs: true), try Match.observation(glyphs: false)) }
        syntheticLog("E7F rung4 menuFrames \(g.menuFrames.sorted { $0.key < $1.key }) plain \(o.menuFrames.sorted { $0.key < $1.key })")
        syntheticLog("E7F rung4 frames \(g.frames.sorted { $0.key < $1.key }) after \(g.afterFrames.sorted { $0.key < $1.key })")
        syntheticLog("E7F rung4 chains fight \(String(g.fightChain, radix: 16)) all \(String(g.chain, radix: 16)) replayedText \(g.counts.replayedText) fight \(g.fightReplayedText) plain \(o.counts.replayedText)")

        // The same match: the glyph source changes pixels only.
        XCTAssertEqual([g.koBody, g.timerStartBody, g.resultBody, g.waitBody, g.lastBody, g.epilogueCycle, g.cycles],
                       [o.koBody, o.timerStartBody, o.resultBody, o.waitBody, o.lastBody, o.epilogueCycle, o.cycles])
        XCTAssertEqual(g.states, o.states)
        XCTAssertEqual(g.endWorldActors, o.endWorldActors)
        XCTAssertEqual(g.aiKeys, o.aiKeys)
        XCTAssertEqual(g.replays.map(\.bytes), o.replays.map(\.bytes))
        XCTAssertEqual(g.counts.replayedText, o.counts.replayedText, "the same GDI calls replayed")
        XCTAssertGreaterThan(g.counts.replayedText, 0)
        XCTAssertEqual(g.log, [])
        // Text draws in every pinned menu frame and on the result screen.
        for cycle in Match.menuCycles { XCTAssertNotEqual(g.menuFrames[cycle], o.menuFrames[cycle], "menu cycle \(cycle)") }
        for body in g.frames.keys { XCTAssertNotEqual(g.frames[body], o.frames[body], "body \(body)") }
        for cycle in g.afterFrames.keys { XCTAssertNotEqual(g.afterFrames[cycle], o.afterFrames[cycle], "after cycle \(cycle)") }
        XCTAssertEqual(g.menuFrames, Self.pinnedMenuFrames)
        XCTAssertEqual(g.frames, Self.pinnedFrames)
        XCTAssertEqual(g.afterFrames, Self.pinnedAfterFrames)
        XCTAssertEqual([String(g.fightChain, radix: 16), String(g.chain, radix: 16)], Self.pinnedChains)
        XCTAssertEqual([g.fightReplayedText, g.counts.replayedText], Self.pinnedReplayedText)
    }
    /// FNV-64 of the menu frames with text (SyntheticComputerMatch.menuCycles):
    /// the character screen (player 1 ready), the computer's character and
    /// team, the settings.
    static let pinnedMenuFrames = [24: "f2edec7f0a374585", 190: "72b318d70bf78125", 202: "c96bfeb50b6b5df2", 216: "8759ba83668bc06e"]
    /// SHA-256 of gameplay frames: bodies 1, 75 and 150 (the input line and
    /// the start notice), the result screen at 400 and 443 (its numbers and
    /// time, the saved notice).
    static let pinnedFrames = [1: "3857248c9ecf5a8074365de7e630137a7cd553bde0f073c70a64d538bc6ed776",
                               75: "f4e7e622f562fd72d452a2e34bfaabb27bc231c9ead0f6bd02f54f86cbf43aab",
                               150: "7da44e510d98434a14474b49541577bc9fe3ba62f150043c17b01efba61336a7",
                               400: "1f5354be5ac6fe421c04432bc75b54e7f51a8153970f25a8104e1a6e7c395ae7",
                               443: "08d8501d15d9070acd649f20f432ff4ab5e3cbb9dd58ef92c3b7703f15ae1a6a"]
    /// FNV-64 of the epilogue's frame and the character screen after it.
    static let pinnedAfterFrames = [683: "7d4b80ee144d51fc", 684: "0b03e42a3a15b316"]
    /// The frame chains through body 150 and through the last body.
    static let pinnedChains = ["b9ab0a74582ad8a9", "9fb6421546c3e6b3"]
    /// GDI calls replayed through body 150 and in the whole run (the same with empty masks).
    static let pinnedReplayedText = [13240, 19055]
}
