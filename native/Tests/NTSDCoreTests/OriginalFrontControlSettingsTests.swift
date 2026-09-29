import Foundation
import XCTest
import NTSDReferenceChecks

/// CONTROL SETTINGS (selector 6) against tools/oracle_front_control_settings.py
/// (APPLICATION_FRONT_MENU_ITEMS_PLAN.md F2).
final class OriginalFrontControlSettingsTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        let url: URL
        if let p = ProcessInfo.processInfo.environment["NTSD_CONTROL_SETTINGS_CORPUS"] { url = URL(fileURLWithPath: p) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-front-control-settings"+suffix,withExtension: "json",subdirectory: "Fixtures")) }
        let r = try FrontControlSettingsReference.compare(Data(contentsOf: url))
        print("CONTROL SETTINGS \(r.cases) cases \(r.events) events \(r.draws) draws \(r.texts) texts \(r.sounds) sounds \(r.keyStates) key states \(r.formats) formats \(r.writes) writes \(r.reloads) reloads \(r.reloadEvents) reload events \(r.releases) releases \(r.links) links \(r.records) records")
        XCTAssertEqual(r.cases,106); XCTAssertEqual(r.writes,8); XCTAssertEqual(r.reloads,8); XCTAssertEqual(r.links,1)
    }
    func testControlSettingsMatchTheOriginal() throws { try compare("") }
    func testControlSettingsWithReverseResourcesAndRampBacking() throws { try compare("-control") }
}
