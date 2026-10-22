import NTSDCore

/// NTSD 2.4's game profile (ENGINE_SPLIT E5, E6b, E6c, E6d). NTSD 2.4.exe is LF2 2.0a's
/// lf2.exe code plus a lib.dll loader (E6a), so its object-ID rules are LF2 2.0a's
/// (OriginalGameRules.lf2, OriginalLF2Rules.swift), and so are its special
/// moves (OriginalLF2CharacterAISpecial, E6c); the game supplies its interface
/// and its bundled lib.dll (E6d).
public enum NTSDProfile {
    public static let rules = OriginalGameRules.lf2(profile: "NTSD 2.4 2.0a",
        // The front menu's bitmaps in load order and its rectangle sheets (NTSDFrontMenuRectangles.swift).
        interface: .init(frontBitmaps: ["LF2_CURSOR", "MENU_CLIP", "MENU_CLIP2", "MENU_CLIP3", "MENU_CLIP4", "MENU_CLIP5",
                                        "MENU_CLIP6", "MENU_CLIP7", "MENU_WAIT", "SLOGAN", "ENDING", "LF2_CURSOR", "CS2", "CS3",
                                        "CS4", "CS5", "CS6", "FRAME", "WORDS0", "WORDS1", "WORDS2", "WORDS3", "WORDS4", "WORDS5"],
                         frontSheets: frontSheets,
                         // The initial interface's bitmaps and the common WAVs loading reads first.
                         interfaceBitmaps: ["PAUSE", "DEMO", "SCORE_BOARD1", "SCORE_BOARD2", "SCORE_BOARD3", "SCORE_BOARD4", "WIN_ALIVE",
                                            "WIN_DEAD", "LOSE_DEAD", "BARS"],
                         commonSounds: ["data\\001.wav", "data\\002.wav", "data\\006.wav", "data\\010.wav", "data\\011.wav",
                                        "data\\004.wav", "data\\016.wav", "data\\017.wav", "data\\020.wav", "data\\021.wav",
                                        "data\\025.wav", "data\\032.wav", "data\\033.wav", "data\\039.wav", "data\\065.wav",
                                        "data\\066.wav", "data\\068.wav", "data\\085.wav"],
                         // The character menu's bitmaps and War's two.
                         menuBitmaps: ["CHARMENU", "CM1", "CM2", "CM3", "CM4", "CM5", "CMA", "CMA2", "CMC", "RFACE", "SPARK"],
                         warBitmaps: ["BATTLEMODE", "BATTLETROOPS"],
                         // The menu WAVs WinMain's input startup loads.
                         menuSounds: ["data\\m_join.wav", "data\\m_ok.wav", "data\\m_cancel.wav", "data\\m_pass.wav", "data\\m_end.wav"],
                         // The information panel's atlas (x, y, width, height) and BATTLEMODE's two frames.
                         panelFrames: [[0, 0, 397, 34], [397, 0, 397, 34],
                                       [0, 34, 198, 194], [198, 34, 198, 194], [396, 34, 198, 194], [594, 34, 198, 194],
                                       [0, 228, 198, 194], [198, 228, 198, 194], [396, 228, 198, 194], [594, 228, 198, 194],
                                       [0, 422, 794, 128]],
                         warModeFrames: [[0, 0, 705, 400], [0, 471, 705, 16]]),
        // NTSD 2.4's bundled lib.dll (its loader in the EXE's entry, E6a) and its
        // three loading labels, the same 13 bytes (DLL data 10003040, 1000304e,
        // 1000305c; E6d-2).
        library: OriginalLibData(loadingLabels: .init(belowTwo: Array("Loading files".utf8), fiveToSeven: Array("Loading files".utf8),
                                                      others: Array("Loading files".utf8))))
}
