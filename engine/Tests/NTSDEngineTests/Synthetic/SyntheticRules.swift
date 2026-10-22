@testable import NTSDCore

/// ENGINE_SPLIT E7c: the synthetic pack's rules, `OriginalGameRules.engineTests`
/// (EngineTestRules.swift, unchanged) with interface lists filled in (and, E7d,
/// Random's candidates; E6d, the bundled library the sessions need). Every
/// name is invented here; only the list lengths are the engine's, because the
/// engine binds one name to each slot or destination of its record layout:
///
/// - frontBitmaps: 24 (`OriginalFrontMenuResources.slots`, OriginalFrontMenuResources.swift:21-22, checked :42)
/// - interfaceBitmaps: 10 (`OriginalInitialInterfaceLoading.slots`, :53, checked :72)
/// - commonSounds: 18 (`OriginalInitialSoundLoading.destinationCount`, :14, checked :44)
/// - menuBitmaps: 11 (`OriginalMenuResourceLoading.slots`, :21, checked :37)
/// - warBitmaps: 2 (OriginalWarSetup.swift:120)
/// - menuSounds: 5 (`OriginalMenuSoundStartup.destinationCount`, :27, checked :31)
///
/// Name forms the loaders impose: a common sound's name is a five-character
/// prefix and its file name in the package (OriginalApplicationLoadingInputs.swift:46,
/// `dropFirst(5)`); a menu WAV is a startup `data\` file, the only startup
/// files `file(_:)` serves (OriginalApplicationStartupInputs.swift:200).
/// No sheets, panel atlas or War mode frames: no loader in this rung reads them.
enum SyntheticNames {
    static let frontBitmaps = (0..<24).map { "SY_FRONT_\(two($0))" }
    static let interfaceBitmaps = (0..<10).map { "SY_IFACE_\(two($0))" }
    static let commonSounds = (0..<18).map { "data\\sy_common_\(two($0)).wav" }
    static let menuBitmaps = (0..<11).map { "SY_MENU_\(two($0))" }
    static let warBitmaps = ["SY_WAR_00", "SY_WAR_01"]
    static let menuSounds = (0..<5).map { "data\\sy_menu_\($0).wav" }
    static func two(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }

    /// E7d: Random's candidates are the pack's character IDs (1-8); the
    /// engine-tests rules have none, so confirming no computer players found
    /// no candidate (OriginalMatchSelection.swift:139). No hidden roster.
    static let roster = OriginalGameRules.Roster(hiddenRoster: OriginalIDSet([]), randomCandidates: OriginalIDRange(1..<9),
                                                 bracketFavourites: OriginalIDSet([]))

    static let interface = OriginalGameRules.Interface(
        frontBitmaps: frontBitmaps, frontSheets: [], interfaceBitmaps: interfaceBitmaps, commonSounds: commonSounds,
        menuBitmaps: menuBitmaps, warBitmaps: warBitmaps, menuSounds: menuSounds, panelFrames: [], warModeFrames: [])
}

extension OriginalGameRules {
    static let syntheticLibrary = OriginalLibData(loadingLabels: .init(belowTwo: Array("Reading pack.".utf8),
        fiveToSeven: Array("Pack reading.".utf8), others: Array("Still reading".utf8)))
    /// `engineTests` with the synthetic pack's interface names, Random's candidates and the library.
    static let syntheticPack: OriginalGameRules = {
        let base = OriginalGameRules.engineTests
        return OriginalGameRules(profile: "engine tests synthetic pack (ENGINE_SPLIT E7c)",
            reflection: base.reflection, armour: base.armour, interaction: base.interaction, impact: base.impact,
            items: base.items, roster: SyntheticNames.roster, modes: base.modes, physics: base.physics, drawing: base.drawing,
            effects: base.effects, lifecycle: base.lifecycle, fusion: base.fusion, weaponBreak: base.weaponBreak,
            interface: SyntheticNames.interface, characterAI: base.characterAI, characterAISpecial: base.characterAISpecial,
            // The application's sessions are modelled only with the library (E6d);
            // invented loading labels (E6d-2).
            library: syntheticLibrary)
    }()
}
