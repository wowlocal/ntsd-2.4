import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDRuntime

/// ENGINE_SPLIT E6d-1: the bundled library is a value of the game's rules.
/// LF2 2.0a's rules have none; the synthetic pack's have it, because the
/// application's sessions are modelled only with it; without it a session
/// stops with the typed `OriginalLibData.Required` before it changes anything.
final class SyntheticLibraryTests: XCTestCase {
    func testTheLF2DefaultHasNoLibraryAndTheSyntheticPackHasIt() {
        XCTAssertNil(OriginalGameRules.lf2(profile: "LF2 2.0a", interface: SyntheticNames.interface).library)
        XCTAssertNil(OriginalGameRules.engineTests.library)
        XCTAssertEqual(OriginalGameRules.syntheticPack.library, OriginalGameRules.syntheticLibrary)
    }

    func testRulesDifferingOnlyInTheLibraryAreUnequal() {
        let off = OriginalGameRules.lf2(profile: "p", interface: SyntheticNames.interface)
        func library(_ others: String) -> OriginalLibData {
            OriginalLibData(loadingLabels: .init(belowTwo: Array("a".utf8), fiveToSeven: Array("b".utf8), others: Array(others.utf8)))
        }
        let on = OriginalGameRules.lf2(profile: "p", interface: SyntheticNames.interface, library: library("c"))
        XCTAssertNotEqual(off, on)
        XCTAssertEqual(on, OriginalGameRules.lf2(profile: "p", interface: SyntheticNames.interface, library: library("c")))
        XCTAssertNotEqual(on, OriginalGameRules.lf2(profile: "p", interface: SyntheticNames.interface, library: library("d")))
    }

    /// The recovered startup (OriginalMacRuntimeStartup's driver) on the pack's
    /// own inputs, with the pack's rules but no library: the start throws
    /// `Required` before staging an attempt, and the host commits no startup,
    /// session or batch.
    func testStartupWithoutTheLibraryStopsBeforeStarting() throws {
        try SyntheticContentPack.withWrittenPack { root, pack in
            try MainActor.assumeIsolated {
                guard let bundle = Bundle(path: root.path) else { throw SyntheticRunError.noBundle(root.path) }
                let content = OriginalContentLocation(appBundle: bundle, identity: pack.identity, fallback: { nil })
                let inputs = try OriginalApplicationStartupInputs.bundled(in: content)
                XCTAssertEqual(inputs.rules, .syntheticPack)
                let base = OriginalGameRules.syntheticPack
                let off = OriginalGameRules(profile: base.profile, reflection: base.reflection, armour: base.armour,
                    interaction: base.interaction, impact: base.impact, items: base.items, roster: base.roster, modes: base.modes,
                    physics: base.physics, drawing: base.drawing, effects: base.effects, lifecycle: base.lifecycle,
                    fusion: base.fusion, weaponBreak: base.weaponBreak, interface: base.interface, characterAI: base.characterAI,
                    characterAISpecial: base.characterAISpecial)
                XCTAssertNil(off.library)
                let platform = OriginalMacRuntimeStartup.Platform(inputs: inputs, prepared: try OriginalMacRuntimeStartup.prepared(inputs))
                let driver = try OriginalMacRuntimeStartup.Driver(platform: platform, instance: 0x400000, show: 10,
                                                                  initial: inputs.initial, rules: off)
                var prepared = 0, failed = 0
                XCTAssertThrowsError(try driver.resume(prepare: { _ in prepared += 1 }, failedAttempt: { _, _ in failed += 1 })) { error in
                    XCTAssertEqual(error as? OriginalLibData.Required,
                                   OriginalLibData.Required(site: "Bootstrap start: the front screen's library text"))
                }
                XCTAssertEqual([prepared, failed], [0, 0], "the guard runs before any attempt is staged")
                XCTAssertNil(driver.snapshot.startup)
                XCTAssertNil(driver.snapshot.session)
                XCTAssertEqual(driver.pendingBatchCount, 0)
            }
        }
    }
}
