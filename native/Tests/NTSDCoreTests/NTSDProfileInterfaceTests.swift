import Foundation
import XCTest
@testable import NTSDCore
import NTSDProfile

/// ENGINE_SPLIT E5f-1/2a/2b/3: the front menu's bitmaps and rectangle sheets, the
/// ENDING screen's sheet, the initial interface's bitmaps, the common WAVs, the
/// menu's and War's bitmaps and the menu WAVs come from the game's `Interface`.
final class NTSDProfileInterfaceTests: XCTestCase {
    func zero(_ size: Int) throws -> OriginalStateRecord {
        try .init(bytes: [UInt8](repeating: 0, count: size), defined: [Bool](repeating: true, count: size))
    }
    let n = NTSDProfile.rules.interface
    func interface(names: [String]? = nil, sheets: [OriginalBitmapSheet]? = nil) -> OriginalGameRules.Interface {
        .init(frontBitmaps: names ?? n.frontBitmaps, frontSheets: sheets ?? n.frontSheets, interfaceBitmaps: n.interfaceBitmaps,
              commonSounds: n.commonSounds, menuBitmaps: n.menuBitmaps, warBitmaps: n.warBitmaps, menuSounds: n.menuSounds)
    }
    func testProfileSheetsAgreeWithTheEndingCapture() throws {
        // The ENDING oracle's declared frames (original-stage-ending.json): a copy of the same
        // table, so this pins the two copies together; the generator's --check against the
        // pinned EXE is what proves the table.
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-stage-ending", withExtension: "json", subdirectory: "Fixtures"))
        let capture = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let frames = try XCTUnwrap(capture?["frames"] as? [[Int]]).map { $0.map(Int32.init) }
        XCTAssertEqual(n.frontSheets.first { $0.slot == 0x451190 }?.frames, frames)
        XCTAssertEqual(n.frontSheets.count, 9); XCTAssertEqual(n.frontSheets.reduce(0) { $0 + $1.frames.count }, 151)
        XCTAssertEqual(n.frontBitmaps.count, OriginalFrontMenuResources.slots.count)
    }
    func testEndingSheetFollowsTheProfile() throws {
        let ntsd = try OriginalStageEnding.endingSheet(n)
        let ending = try XCTUnwrap(n.frontSheets.first { $0.slot == 0x451190 })
        XCTAssertEqual(try ntsd.integer(at: 0x0c, as: Int32.self), Int32(ending.frames.count))
        for (field, offset) in [0x10, 0x7e0, 0xfb0, 0x1780].enumerated() {
            XCTAssertEqual(try ntsd.integer(at: offset, as: Int32.self), ending.frames[0][field])
        }
        let moved = try OriginalStageEnding.endingSheet(interface(sheets: [OriginalBitmapSheet(slot: 0x451190, frames: [[1, 2, 3, 4]])]))
        XCTAssertEqual(try [0x0c, 0x10, 0x7e0, 0xfb0, 0x1780].map { try moved.integer(at: $0, as: Int32.self) }, [1, 1, 2, 3, 4])
        XCTAssertThrowsError(try OriginalStageEnding.endingSheet(interface(sheets: []))) {
            XCTAssertEqual("\($0)", "\(OriginalStateError.invalidStorage("Stage ending: ENDING sheet"))")
        }
    }
    /// The front menu's load (flag 0x44d068 set unless `skip`): the first bitmap it
    /// constructs, or its error; `events` counts every event it reported.
    func firstConstructed(_ interface: OriginalGameRules.Interface, skip: Bool = false, events: UnsafeMutablePointer<Int>? = nil) throws -> String {
        var globals = try zero(OriginalMatchPreparation.globalSize)
        if !skip { try globals.write(UInt32(1), at: 0x44d068-OriginalMatchPreparation.globalBase) }
        var resources = OriginalFrontMenuResources(interface: interface), constructed: [String] = []
        struct Stop: Error {}
        do {
            _ = try resources.load(world: try zero(0x7d8), globals: &globals,
                allocate: { _ in OriginalInterfaceAllocation(address: 0x1000, backing: [UInt8](repeating: 0, count: 0x1f50)) },
                source: { _, _ in throw Stop() }, deviceResult: { _ in throw Stop() },
                observe: { event in
                    events?.pointee += 1
                    if event.kind == .construct { constructed.append(String(decoding: event.strings[0], as: UTF8.self)) }
                })
        } catch is Stop { return constructed.first ?? "" } catch { return "\(error)" }
        return constructed.first ?? "ready"
    }
    func testFrontLoadTakesTheProfilesNames() throws {
        XCTAssertEqual(try firstConstructed(n), "LF2_CURSOR")
        var names = n.frontBitmaps; names[0] = "MY_CURSOR"
        XCTAssertEqual(try firstConstructed(interface(names: names)), "MY_CURSOR")
        let invalid = "\(OriginalStateError.invalidStorage("Front menu interface: one name per slot, sheets in the first eleven"))"
        XCTAssertEqual(try firstConstructed(interface(names: Array(n.frontBitmaps.dropLast()))), invalid)
        XCTAssertEqual(try firstConstructed(interface(sheets: n.frontSheets + [OriginalBitmapSheet(slot: 0x44faf4, frames: [])])), invalid)
        XCTAssertEqual(try firstConstructed(interface(sheets: n.frontSheets + [n.frontSheets[0]])), invalid, "a slot twice")
        let long = OriginalBitmapSheet(slot: n.frontSheets[0].slot, frames: Array(repeating: [0, 0, 1, 1], count: 501))
        XCTAssertEqual(try firstConstructed(interface(sheets: [long] + n.frontSheets.dropFirst())), invalid, "501 frames")
        // The check comes before any effect: no event on an invalid profile, even where the
        // flag 0x44d068 = 0 makes a valid one return at once (after its phase write).
        var count = 0
        XCTAssertEqual(try firstConstructed(interface(names: []), events: &count), invalid); XCTAssertEqual(count, 0)
        XCTAssertEqual(try firstConstructed(interface(names: []), skip: true, events: &count), invalid); XCTAssertEqual(count, 0)
        XCTAssertEqual(try firstConstructed(n, skip: true, events: &count), "ready"); XCTAssertEqual(count, 1, "the phase write only")
    }
    func testInterfaceTakesPartInTheRulesEquality() {
        let rules = NTSDProfile.rules
        var names = n.frontBitmaps; names[0] = "MY_CURSOR"
        XCTAssertNotEqual(rules, rules.with(profile: rules.profile, interface: interface(names: names)))
        XCTAssertEqual(rules, rules.with(profile: rules.profile, interface: n))
    }
    /// Loading's globals with the flag 0x44d05c = 1.
    func loadingGlobals() throws -> OriginalStateRecord {
        var globals = try zero(OriginalMatchPreparation.globalSize)
        try globals.write(Int32(1), at: 0x44d05c-OriginalMatchPreparation.globalBase); return globals
    }
    struct Stop: Error {}
    /// The initial interface's load under these names: the first name it asks a source
    /// for, or its error.
    func firstInterfaceRequest(_ names: [String], effects: UnsafeMutablePointer<Int>? = nil) throws -> String {
        var globals = try loadingGlobals(), loader = OriginalInitialInterfaceLoading(), requested: String?
        do {
            try loader.load(globals: &globals, names: names,
                allocate: { _ in effects?.pointee += 1; return OriginalInterfaceAllocation(address: 0x1000, backing: [UInt8](repeating: 0, count: 0x1f50)) },
                source: { _, path in requested = path; throw Stop() }, deviceResult: { _ in throw Stop() },
                observe: { _ in effects?.pointee += 1 })
        } catch is Stop { return requested ?? "" } catch { return "\(error)" }
        return requested ?? ""
    }
    /// The common WAVs' load under these names: the first path it prepares, or its error.
    func firstSoundRead(_ names: [String], effects: UnsafeMutablePointer<Int>? = nil) throws -> String {
        var globals = try loadingGlobals(), read: String?
        do {
            try OriginalInitialSoundLoading.load(globals: &globals, targetSurface: 0, names: names,
                fileSource: { _ in throw Stop() }, platform: { _, path, _ in read = path; throw Stop() },
                store: { _, _ in effects?.pointee += 1 }, observe: { _ in effects?.pointee += 1 })
        } catch is Stop { return read ?? "" } catch { return "\(error)" }
        return read ?? ""
    }
    func testInterfaceAndCommonSoundNames() throws {
        XCTAssertEqual(n.interfaceBitmaps.count, OriginalInitialInterfaceLoading.slots.count); XCTAssertEqual(n.commonSounds.count, 18)
        XCTAssertEqual(try firstInterfaceRequest(n.interfaceBitmaps), "PAUSE")
        var names = n.interfaceBitmaps; names[0] = "MY_PAUSE"
        XCTAssertEqual(try firstInterfaceRequest(names), "MY_PAUSE")
        XCTAssertEqual(try firstInterfaceRequest(Array(names.dropLast())),
                       "\(OriginalStateError.invalidStorage("Initial interface names: one per slot"))")
        XCTAssertEqual(try firstSoundRead(n.commonSounds), "data\\001.wav")
        var sounds = n.commonSounds; sounds[0] = "data\\777.wav"
        XCTAssertEqual(try firstSoundRead(sounds), "data\\777.wav")
        XCTAssertEqual(try firstSoundRead(Array(sounds.dropLast())), "\(OriginalStateError.invalidStorage("Initial sound names: one per destination"))")
        // The loaders check the count before any effect of their own.
        var effects = 0
        _ = try firstInterfaceRequest([], effects: &effects); _ = try firstSoundRead([], effects: &effects)
        XCTAssertEqual(effects, 0)
        _ = try firstSoundRead(n.commonSounds, effects: &effects); XCTAssertGreaterThan(effects, 0, "a valid list gets to its effects")
        let rules = NTSDProfile.rules
        XCTAssertNotEqual(rules, rules.with(profile: rules.profile, interface: .init(frontBitmaps: n.frontBitmaps, frontSheets: n.frontSheets,
            interfaceBitmaps: names, commonSounds: n.commonSounds, menuBitmaps: n.menuBitmaps, warBitmaps: n.warBitmaps, menuSounds: n.menuSounds)))
        XCTAssertNotEqual(rules, rules.with(profile: rules.profile, interface: .init(frontBitmaps: n.frontBitmaps, frontSheets: n.frontSheets,
            interfaceBitmaps: n.interfaceBitmaps, commonSounds: sounds, menuBitmaps: n.menuBitmaps, warBitmaps: n.warBitmaps, menuSounds: n.menuSounds)))
    }
    /// The character menu's resource load (flag 0x44d07c set) under these names: the
    /// first name it asks a source for, or its error.
    func firstMenuRequest(_ names: [String]) throws -> String {
        var globals = try zero(OriginalMatchPreparation.globalSize), loader = OriginalMenuResourceLoading(), requested: String?
        try globals.write(UInt32(1), at: 0x44d07c-OriginalMatchPreparation.globalBase)
        do {
            _ = try loader.load(globals: &globals, names: names,
                allocate: { _ in OriginalInterfaceAllocation(address: 0x1000, backing: [UInt8](repeating: 0, count: 0x1f50)) },
                source: { _, path in requested = path; throw Stop() }, deviceResult: { _ in throw Stop() })
        } catch is Stop { return requested ?? "" } catch { return "\(error)" }
        return requested ?? ""
    }
    func testMenuAndWarNames() throws {
        XCTAssertEqual(n.menuBitmaps.count, OriginalMenuResourceLoading.slots.count); XCTAssertEqual(n.warBitmaps, ["BATTLEMODE", "BATTLETROOPS"])
        XCTAssertEqual(try firstMenuRequest(n.menuBitmaps), "CHARMENU")
        var names = n.menuBitmaps; names[0] = "MY_MENU"
        XCTAssertEqual(try firstMenuRequest(names), "MY_MENU")
        XCTAssertEqual(try firstMenuRequest(Array(names.dropLast())), "\(OriginalStateError.invalidStorage("Menu resource names: one per slot"))")
        let rules = NTSDProfile.rules
        XCTAssertNotEqual(rules, rules.with(profile: rules.profile, interface: .init(frontBitmaps: n.frontBitmaps, frontSheets: n.frontSheets,
            interfaceBitmaps: n.interfaceBitmaps, commonSounds: n.commonSounds, menuBitmaps: names, warBitmaps: n.warBitmaps, menuSounds: n.menuSounds)))
        XCTAssertNotEqual(rules, rules.with(profile: rules.profile, interface: .init(frontBitmaps: n.frontBitmaps, frontSheets: n.frontSheets,
            interfaceBitmaps: n.interfaceBitmaps, commonSounds: n.commonSounds, menuBitmaps: n.menuBitmaps, warBitmaps: ["BATTLEMODE"], menuSounds: n.menuSounds)))
    }
    /// The menu WAV load under these names with a failed DirectSoundCreate: the
    /// first name it binds, or its error, and the sound requests made before.
    func firstMenuSound(_ names: [String]) throws -> (String, Int) {
        var globals = try zero(OriginalMatchPreparation.globalSize), requests = 0, bound: String?
        do {
            _ = try OriginalMenuSoundStartup.loadObserved(globals: &globals, names: names,
                soundRequest: { e in requests += 1; return .init(result: e.kind == "deviceCreate" ? -1 : 0) },
                waveInput: { _, path, _, _ in bound = path; throw Stop() },
                waveRequest: { _, _ in throw Stop() }, fileSource: { _ in throw Stop() })
        } catch is Stop { return (bound ?? "", requests) } catch { return ("\(error)", requests) }
        return (bound ?? "", requests)
    }
    func testMenuSoundNames() throws {
        XCTAssertEqual(n.menuSounds.count, OriginalMenuSoundStartup.destinationCount)
        XCTAssertEqual(try firstMenuSound(n.menuSounds).0, "data\\m_join.wav")
        var names = n.menuSounds; names[0] = "data\\my_join.wav"
        XCTAssertEqual(try firstMenuSound(names).0, "data\\my_join.wav")
        let short = try firstMenuSound(Array(names.dropLast()))
        XCTAssertEqual(short.0, "\(OriginalStateError.invalidStorage("Menu sound names: one per destination"))")
        XCTAssertEqual(short.1, 0, "no sound request before the check")
        // The input startup checks before its key table and joystick requests.
        var globals = try zero(OriginalMatchPreparation.globalSize), requests = 0, stores = 0
        XCTAssertThrowsError(try OriginalInputStartup.load(globals: &globals, menuSounds: Array(names.dropLast()),
            request: { _, _ in requests += 1; throw Stop() }, soundPlatform: .init(createResult: -1, createdDevice: nil),
            wavePlatform: { _, _, _, _ in throw Stop() }, fileSource: { _ in throw Stop() }, store: { _, _ in stores += 1 })) {
            XCTAssertEqual("\($0)", "\(OriginalStateError.invalidStorage("Menu sound names: one per destination"))")
        }
        XCTAssertEqual(requests + stores, 0)
        let rules = NTSDProfile.rules
        XCTAssertNotEqual(rules, rules.with(profile: rules.profile, interface: .init(frontBitmaps: n.frontBitmaps, frontSheets: n.frontSheets,
            interfaceBitmaps: n.interfaceBitmaps, commonSounds: n.commonSounds, menuBitmaps: n.menuBitmaps, warBitmaps: n.warBitmaps, menuSounds: names)))
    }
}
