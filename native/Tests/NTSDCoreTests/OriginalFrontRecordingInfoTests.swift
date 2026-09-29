import Foundation
import XCTest
import NTSDReferenceChecks

/// RECORDING INFO (selectors 7 and 8) against tools/oracle_front_recording_info.py
/// (APPLICATION_FRONT_MENU_ITEMS_PLAN.md F3).
final class OriginalFrontRecordingInfoTests: XCTestCase {
    private func compare(_ suffix: String) throws {
        let url: URL
        if let p = ProcessInfo.processInfo.environment["NTSD_RECORDING_INFO_CORPUS"] { url = URL(fileURLWithPath: p) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-front-recording-info"+suffix,withExtension: "json",subdirectory: "Fixtures")) }
        let r = try FrontRecordingInfoReference.compare(Data(contentsOf: url))
        print("RECORDING INFO \(r.cases) cases (\(r.pages) page 8) \(r.events) events \(r.draws) draws \(r.blits) blits \(r.fontPasses) font passes \(r.sounds) sounds \(r.keyStates) key states \(r.writes) writes \(r.reloads) reloads \(r.reloadEvents) reload events \(r.releases) releases \(r.links) links \(r.records) records")
        XCTAssertEqual(r.cases,129); XCTAssertEqual(r.pages,17); XCTAssertEqual(r.writes,2); XCTAssertEqual(r.reloads,2); XCTAssertEqual(r.links,3)
    }
    func testRecordingInfoMatchesTheOriginal() throws { try compare("") }
    func testRecordingInfoWithReverseResourcesAndRampBacking() throws { try compare("-control") }
}
