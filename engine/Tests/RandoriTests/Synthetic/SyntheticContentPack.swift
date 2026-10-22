import Foundation
@testable import RandoriCore

/// ENGINE_SPLIT E7c: a content pack for the engine's own tests, generated in
/// memory and written to a temporary folder (nothing binary is committed).
/// Every byte is authored in this folder's code: images and sounds
/// (SyntheticMedia), DAT text encrypted by the engine's decoder rule
/// (SyntheticDAT), the 0xc3a8-byte initial record, the manifests and the
/// `OriginalContentIdentity` computed from them with `OriginalGameRules.syntheticPack`.
/// No original file is read; no value is copied from one.
///
/// Folder names are the engine's package names (`OriginalContentLocation.directory`
/// callers: OriginalApplicationStartupInputs.swift:127, OriginalApplicationCatalogInputs.swift:27,
/// OriginalApplicationLoadingInputs.swift:22, OriginalApplicationInterfaceInputs.swift:16,
/// OriginalApplicationMenuInputs.swift:15,25, OriginalApplicationArenaInputs.swift:16,
/// RandoriMacPlatform/OriginalMacMusicPlayer.swift:10), so the written root can stand
/// where a `--resources` directory does (OriginalRuntimeSession.swift:155-156).
struct SyntheticContentPack {
    static let startup = "OriginalStartup", catalog = "OriginalCatalog", commonSounds = "OriginalCommonSounds"
    static let loadingInterface = "OriginalLoadingInterface", characterMenu = "OriginalCharacterMenu", warMenu = "OriginalWarMenu"
    static let arenas = "OriginalMatchArenas", music = "OriginalMusic"

    /// Package folder → (package-relative path → bytes), manifest.json included.
    let packages: [String: [String: [UInt8]]]
    let identity: OriginalContentIdentity

    /// The invented reference-EXE identity every manifest names: the SHA-256 of
    /// a label (the loaders compare it as a string, e.g. OriginalApplicationStartupInputs.swift:145,
    /// OriginalApplicationCatalogInputs.swift:60).
    static let exeSHA256 = hex(PortableSHA256.hash(data: Array("NTSD engine tests: synthetic content pack, invented EXE identity (ENGINE_SPLIT E7c)".utf8)))

    // MARK: The initial record

    /// A word the generator writes into initial.bin; every other byte is zero
    /// and every mask byte is 1 (the startup loader requires an all-ones mask,
    /// OriginalApplicationStartupInputs.swift:187-188).
    struct RecordWord: Equatable { let offset: Int, value: UInt32, check: String }
    /// The words an engine check needs, each with the check (E7c needed none:
    /// the startup loader checks only the record's length and mask, and the
    /// catalog load does not read it). E7d's start, front menu, first loading,
    /// menus and VS match need the six below; values are invented wherever the
    /// engine tests only for nonzero. E7f's match end writes the replay and
    /// needs the two at the end.
    static let recordWords: [RecordWord] = [
        // E7d: the game window's client size. WinMain's window setup adds the
        // frame metrics to them for CreateWindow (OriginalWindowInitialization.swift:90-91,
        // 107-110) and sizes the back buffer by them (:136, :146-147); the runtime
        // refuses a zero width or height (OriginalRuntimeWindowBackend.swift:261).
        // Invented: 800 x 600.
        RecordWord(offset: 0x44d78c, value: 800, check: "OriginalWindowInitialization.swift:90,107; OriginalRuntimeWindowBackend.swift:261"),
        RecordWord(offset: 0x44d790, value: 600, check: "OriginalWindowInitialization.swift:91,107; OriginalRuntimeWindowBackend.swift:261"),
        // E7d: the front menu's first-load flag: its 24 bitmaps are loaded only
        // while it is nonzero (OriginalFrontMenuResources.swift:62); settings
        // loading clears it afterwards (OriginalSettingsLoading.swift:139).
        // Without them the front screen's body stops at a null bitmap
        // (OriginalFrontScreenBody.swift:147, OriginalFrontMenuLoop.swift:33).
        // Invented nonzero value: 0xe7d.
        RecordWord(offset: 0x44d068, value: 0xe7d, check: "OriginalFrontMenuResources.swift:62"),
        // E7d: the first loading's flag. The loading prefix, the initial loading
        // and the interface loading require exactly 1 (OriginalInitialSoundLoading.swift:41,
        // OriginalInitialLoading.swift:128, OriginalInitialInterfaceLoading.swift:69);
        // the interface loading then clears it (:95). Value fixed by the engine.
        RecordWord(offset: 0x44d05c, value: 1, check: "OriginalInitialSoundLoading.swift:41; OriginalInitialLoading.swift:128; OriginalInitialInterfaceLoading.swift:69"),
        // E7d: the menu state after the first loading. The first loaded input
        // step continues to the loaded menu only while it is nonzero
        // (OriginalMatchRound.swift:137, OriginalApplicationLoadedMenuSession.swift:112),
        // and the loaded menu shows the mode screen only for 10
        // (OriginalModeScreen.swift:17, OriginalApplicationLoadedMenuSession.swift:615;
        // other values go to the character screen's dispatcher). Value fixed by the engine.
        RecordWord(offset: 0x44d020, value: 10, check: "OriginalMatchRound.swift:137; OriginalModeScreen.swift:17"),
        // E7d: the loaded menu's bitmaps are loaded only while this flag is
        // nonzero (OriginalMenuResourceLoading.swift:41); the loader clears it
        // (:89). Invented nonzero value: 0xe7d.
        RecordWord(offset: 0x44d07c, value: 0xe7d, check: "OriginalMenuResourceLoading.swift:41"),
        // E7f: the replay codec's version pointer. The match's end writes its
        // replay (OriginalResultRecording.swift:107,170) and the writer stops
        // unless this word is exactly 0x44a2b4 (OriginalReplayWriter.swift:85-87:
        // the EXE dereferences it, and only that address is modelled). Value
        // fixed by the engine.
        RecordWord(offset: 0x44dce8, value: 0x44a2b4, check: "OriginalReplayWriter.swift:85"),
        // E7f: the game's version word. No check needs a value: the recording
        // copies it to +0x748 (OriginalReplayRecording.swift:91), playback
        // compares it with the running game's (OriginalReplayPlayback.swift:166),
        // and the network packet carries its low byte (OriginalInputControl.swift:150).
        // Invented nonzero (and above the panel's -99 update marker,
        // OriginalMenuPanelDrawing.swift:128, so no panel changes), so the
        // written replay shows the copy: 0xe7f.
        RecordWord(offset: 0x44d03c, value: 0xe7f, check: "OriginalReplayRecording.swift:91; OriginalReplayPlayback.swift:166; OriginalInputControl.swift:150"),
    ]

    static func initialRecord() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: OriginalRecordLayout.size)
        for word in recordWords {
            for i in 0..<4 { bytes[word.offset - OriginalRecordLayout.base + i] = UInt8(truncatingIfNeeded: word.value >> (8*i)) }
        }
        return bytes
    }

    // MARK: Authored content

    /// One fighting character: its catalog ID, DAT, pictures and colours.
    struct Character {
        let id: Int32, name: String, stem: String, body: SyntheticMedia.RGB, accent: SyntheticMedia.RGB, pace: Int
        var dat: String { "data\\sy_\(stem).dat" }
        var sheet: String { "sprite\\sy\\\(stem)_0.bmp" }
        var mirror: String { "sprite\\sy\\\(stem)_0_mirror.bmp" }
        var head: String { "sprite\\sy\\\(stem)_f.bmp" }
        var small: String { "sprite\\sy\\\(stem)_s.bmp" }
    }
    /// E7d: eight characters. Confirming no computer players draws a Random
    /// character for every seat still on Random, each distinct and never
    /// ordinal 0 (OriginalMatchSelection.swift:131-143, OriginalMatchContinuation.swift:30-36):
    /// two players choosing ordinals 0 and 1 leave the six empty seats ordinals 2-7.
    static let characters = [
        Character(id: 1, name: "SyOne", stem: "one", body: .init(r: 200, g: 64, b: 40), accent: .init(r: 248, g: 216, b: 88), pace: 0),
        Character(id: 2, name: "SyTwo", stem: "two", body: .init(r: 40, g: 96, b: 200), accent: .init(r: 120, g: 232, b: 248), pace: 1)]
        + [(3, "Three", "three"), (4, "Four", "four"), (5, "Five", "five"), (6, "Six", "six"), (7, "Seven", "seven"), (8, "Eight", "eight")].map { id, name, stem in
            Character(id: Int32(id), name: "Sy" + name, stem: stem, body: .init(r: UInt8(30*id), g: UInt8(160 - 12*id), b: UInt8(40 + 20*id)),
                      accent: .init(r: UInt8(250 - 10*id), g: UInt8(100 + 15*id), b: UInt8(60 + 5*id)), pace: id % 2)
        }
    /// E7d: one light weapon (type 1). Each gameplay tick with fewer than four
    /// items out draws 1 in 200 for a random drop among the objects whose ID is
    /// in the rules' item range (EngineTestRules: 100..<200); with none the
    /// candidate draw has range 0 and the engine stops (OriginalWorldHits.swift:43-68,
    /// OriginalActorHits.swift:106). Invented ID 150 (the engine-tests rules give
    /// 100 weapon-break rows; 150 has none).
    struct Item {
        let id: Int32, name: String, stem: String, color: SyntheticMedia.RGB
        var dat: String { "data\\sy_\(stem).dat" }
        var sheet: String { "sprite\\sy\\\(stem)_0.bmp" }
        var mirror: String { "sprite\\sy\\\(stem)_0_mirror.bmp" }
    }
    static let items = [Item(id: 150, name: "SyStick", stem: "stick", color: .init(r: 168, g: 120, b: 72))]
    static let itemCell = (w: 23, h: 15, row: 4, col: 1)
    /// Sheet cells (w+1)×(h+1) in `row` columns and `col` rows (the DAT's own field names).
    static let cell = (w: 23, h: 31, row: 4, col: 3)
    static let swingSound = "data\\sy_swing.wav"
    static let backgroundDAT = "bg\\sy\\field\\bg.dat"
    static let backgroundShadow = "bg\\sy\\field\\s.bmp"
    static let backgroundLayers = ["bg\\sy\\field\\sky.bmp", "bg\\sy\\field\\land.bmp"]
    /// The catalog's file name and the Stage file are fixed by the engine
    /// (OriginalApplicationCatalogSession.swift:389; OriginalLoadedCatalog.swift:225,
    /// OriginalLoadingFiles.swift:212).
    static let catalogFile = "data\\data.txt", stageFile = "data\\stage.dat"
    /// The four built-in bitmaps the registry requests before reading the
    /// catalog (OriginalCatalogRegistry.swift:96-97).
    static let builtInBitmaps = ["shadow1", "back99_1", "back99_2", "back99_3"]
    /// The music paths the engine's tables name (OriginalMusicConfiguration.swift:50,
    /// OriginalMusicPlayback.swift:75-76, :137).
    static let musicNames = ["main", "stage1", "stage2", "stage3", "stage4", "stage5", "boss1", "boss2"].map { "bgm\\\($0).wma" }
    /// The startup panel's info file and the content file its index selects
    /// (OriginalMenuInfoReading.swift:77,105; `data\ad0.txt` is the absent file
    /// the runtime overlay knows, OriginalMacRuntimeStartup.swift:88).
    static let adinfo = "dont_update 0 5 <end>\r\n"
    static let absentFiles = ["data/ad0.txt"]
    /// The music package's rate: any rate (the manifest's own is read; the silent
    /// player's clock uses it, OriginalRuntimeSilentMusic.swift:19).
    static let musicRate = 16000

    /// data\control.txt in the grammar of OriginalSettingsLoading (423480): 4×11
    /// numbers, four names, two numbers, two lines, then free lines. A player's
    /// eleven numbers are the control table's words 0-10 (OriginalSettingsLoading.swift:107):
    /// the device (0: keyboard; OriginalFrontControlSettings.swift:6-9), seven
    /// key VKs for up, down, left, right, attack, jump, defend (read for a
    /// keyboard player, OriginalLocalInput.swift:82-88) and three joystick
    /// button numbers (read only for a joystick, :91-92). E7d: every player is
    /// a keyboard player (E7c's first number per player was nonzero, a
    /// joystick, so no key reached a seat). The VKs are invented: letters from
    /// A for players 1-3, digits for player 4; the button numbers too. The last
    /// line has no line end, so the reader's end test stops after it.
    static let keyVKs: [[UInt32]] = [Array(0x41...0x47), Array(0x48...0x4e), Array(0x4f...0x55), Array(0x30...0x36)]
    static let joystickButtons: [UInt32] = [5, 6, 7]
    enum Key: Int { case up, down, left, right, attack, jump, defend }
    static func vk(player: Int, _ key: Key) -> UInt32 { keyVKs[player][key.rawValue] }
    static let controlText: String = {
        var lines: [String] = []
        for player in 0..<4 { lines.append(([0] + keyVKs[player] + joystickButtons).map { String($0) }.joined(separator: " ")) }
        lines += ["Ann Bo Cy Di", "2", "1", "synthetic pack settings", "made by NTSDEngineTests", "end of synthetic settings"]
        return lines.joined(separator: "\r\n")
    }()

    static func catalogText() -> String {
        var text = "<object>\r\n"
        for c in characters { text += "id: \(c.id) type: 0 file: \(c.dat)\r\n" }
        for item in items { text += "id: \(item.id) type: 1 file: \(item.dat)\r\n" }
        text += "<object_end>\r\n\r\n<background>\r\nid: 0 file: \(backgroundDAT)\r\n<background_end>\r\n"
        return text
    }

    /// One frame of a character DAT (only fields the frame loader knows,
    /// OriginalFrameLoader.swift:134-161), one space between tokens (the grammar
    /// ignores whitespace, SyntheticDAT). The frame numbers are the format's
    /// conventions the engine's state code addresses (e.g. OriginalCharacterAI.swift:637).
    private static func frame(_ number: Int, _ name: String, pic: Int, state: Int, wait: Int, next: Int,
                              body: Bool = true, extra: String = "", center: (x: Int, y: Int) = (12, 31)) -> String {
        var text = "<frame> \(number) \(name)\npic: \(pic) state: \(state) wait: \(wait) next: \(next) dvx: 0 dvy: 0 dvz: 0 centerx: \(center.x) centery: \(center.y)\n"
        text += extra
        if body { text += "bdy:\nkind: 0 x: 5 y: 4 w: 14 h: 27\nbdy_end:\n" }
        return text + "<frame_end>\n\n"
    }

    static func characterText(_ c: Character) -> String {
        let p = c.pace
        var text = "\n<bmp_begin>\nname: \(c.name)\nhead: \(c.head)\nsmall: \(c.small)\n"
        text += "file(0-\(cell.row*cell.col - 1)): \(c.sheet)  w: \(cell.w)  h: \(cell.h)  row: \(cell.row)  col: \(cell.col)\n"
        text += "walking_frame_rate \(3 + p)\nwalking_speed 4.25\nwalking_speedz 2.0\nrunning_frame_rate \(3 + p)\n"
        text += "running_speed 8.5\nrunning_speedz 1.25\nheavy_walking_speed 3.0\nheavy_walking_speedz 1.5\n"
        text += "heavy_running_speed 5.0\nheavy_running_speedz 0.75\njump_height -15.0\njump_distance 9.0\n"
        text += "jump_distancez 3.5\ndash_height -9.0\ndash_distance 16.0\ndash_distancez 3.5\n"
        text += "rowing_height -2.0\nrowing_distance 4.0\n<bmp_end>\n\n"
        for i in 0..<4 { text += frame(i, "standing", pic: i, state: 0, wait: 6 + p, next: i == 3 ? 999 : i + 1) }
        for i in 0..<4 { text += frame(5 + i, "walking", pic: 4 + i, state: 1, wait: 3, next: 999) }
        for i in 0..<3 { text += frame(9 + i, "running", pic: 8 + i, state: 2, wait: 2, next: 999) }
        if c.id <= 2 {
            text += frame(60, "punch", pic: 11, state: 3, wait: 2, next: 61, extra:
                "sound: \(swingSound)\nitr:\nkind: 0 x: 16 y: 10 w: 20 h: 12 dvx: \(6 + p) fall: 25 arest: 9 bdefend: 14 injury: \(23 + 4*p)\nitr_end:\n")
            text += frame(61, "punch", pic: 3, state: 3, wait: 3, next: 999)
        } else {
            // E7f: characters 3-8, the computer player's pool, hit harder and
            // further, so a computer player ends a match within a few hundred
            // bodies (a character's HP is the engine's fixed 500,
            // OriginalStateRecord.swift:1025). A standing attack is frame 60
            // or 65 by a draw (OriginalActorControl.swift:162; E7d's
            // characters have no 65, an empty frame, so a punch of theirs can
            // land in it). The reach (x 16..72 from centerx 12, about 60 plus the
            // target body's half-width) covers the character AI's 60 band (it
            // stops walking within 60 of its target, OriginalCharacterAI.swift:
            // 428-436) but not all of the 80 it attacks within (:458, 610). No
            // frame 70: the engine takes it only after a kind-6 itr
            // (OriginalHitSpecial.swift:8), which the pack has none of.
            // Characters 1 and 2 (E7d's match) are unchanged.
            func punch(_ number: Int) -> String {
                frame(number, "punch", pic: 11, state: 3, wait: 2, next: number + 1, extra:
                    "sound: \(swingSound)\nitr:\nkind: 0 x: 16 y: 10 w: 56 h: 12 dvx: \(6 + p) fall: 25 arest: 9 bdefend: 14 injury: \(90 + 4*p)\nitr_end:\n")
                    + frame(number + 1, "punch", pic: 3, state: 3, wait: 3, next: 999)
            }
            text += punch(60) + punch(65)
        }
        text += frame(110, "defend", pic: 2, state: 7, wait: 10, next: 999)
        // E7d: the frames a hit and a fall select. Injured by the defender's
        // accumulated fall: 220, 222/224 (by facing), 226 (OriginalHitDamage.swift:19-31);
        // falling 180-185 in front, 186-191 behind (:55), whose frame the
        // airborne fall picks by vertical speed, with 185/191 the bounce
        // (OriginalActorPhysics.swift:108-124, 154-158); lying 230/231 after
        // a slow landing (:154). E7c had 180, 220 and 230 only. The falling
        // frames hold (next 0): the physics chooses among them.
        for n in 180...185 { text += frame(n, "falling", pic: 9, state: 12, wait: 2, next: 0) }
        for n in 186...191 { text += frame(n, "falling", pic: 8, state: 12, wait: 2, next: 0) }
        text += frame(220, "injured", pic: 6, state: 11, wait: 4, next: 999)
        for n in [222, 224] {
            text += frame(n, "injured", pic: 6, state: 11, wait: 2, next: n + 1)
            text += frame(n + 1, "injured", pic: 7, state: 11, wait: 2, next: 999)
        }
        text += frame(226, "injured", pic: 6, state: 16, wait: 2, next: 227)
        text += frame(227, "injured", pic: 7, state: 16, wait: 4, next: 999)
        text += frame(230, "lying", pic: 10, state: 14, wait: 30, next: 999, body: false)
        text += frame(231, "lying", pic: 10, state: 14, wait: 30, next: 999, body: false)
        // E7d: the jump (212 is where a jump's velocity starts, OriginalActorScheduler.swift:110,155-156)
        // and the landings a fighter's landing selects (215 after a jump, 219
        // otherwise, as when the match drops the fighters in; OriginalActorPhysics.swift:142).
        // Without 219 a landed fighter held an empty frame and was not drawn.
        text += frame(210, "jump", pic: 4, state: 4, wait: 1, next: 211)
        text += frame(211, "jump", pic: 5, state: 4, wait: 1, next: 212)
        text += frame(212, "jump", pic: 6, state: 4, wait: 1, next: 0)
        text += frame(215, "crouch", pic: 7, state: 15, wait: 2, next: 999)
        text += frame(219, "crouch", pic: 7, state: 15, wait: 2, next: 999)
        return text
    }

    /// E7d: the light weapon's DAT: in the sky (state 1000, frames 0-3, where a
    /// dropped item starts) and on the ground (frame 60; 70 after a throw), the
    /// frames a type-1 landing selects (OriginalActorPhysics.swift:162-181).
    /// Its HP (header 0x90) and the HP a landing costs (0x94) are invented.
    static func itemText(_ item: Item) -> String {
        var text = "\n<bmp_begin>\nname: \(item.name)\n"
        text += "file(0-\(itemCell.row*itemCell.col - 1)): \(item.sheet)  w: \(itemCell.w)  h: \(itemCell.h)  row: \(itemCell.row)  col: \(itemCell.col)\n"
        text += "weapon_hp: 60\nweapon_drop_hurt: 7\n<bmp_end>\n\n"
        for i in 0..<4 { text += frame(i, "in_the_sky", pic: i, state: 1000, wait: 1, next: i == 3 ? 0 : i + 1, body: false, center: (12, 15)) }
        text += frame(60, "on_ground", pic: 0, state: 1004, wait: 1, next: 0, body: false, center: (12, 15))
        text += frame(70, "on_ground", pic: 1, state: 1004, wait: 1, next: 0, body: false, center: (12, 15))
        return text
    }

    /// Every DAT text starts and ends with whitespace, and ends with at least
    /// two characters of it: with VC80's fscanf lookahead the decoder drops the
    /// final character (OriginalLoadingFiles.scanfLookahead), and a text then
    /// ending in a token would end the outer loop one pass earlier (the loaders
    /// count the last token again when whitespace follows it), changing the
    /// checksum. With two, both decodings give the same token stream.
    static func backgroundText() -> String {
        // `shadow:` takes the path, a label and two numbers the record keeps at
        // 0x14/0x18 (OriginalBackgroundLoader.swift:67-74): half the generated
        // 30x9 shadow image here.
        "\nname: Sy_Field\nwidth: 1000\nzboundary: 320 460\nshadow: \(backgroundShadow) shadowsize: 15 4\n"
            + "layer: \(backgroundLayers[0])\ntransparency: 0 width: 160 x: 0 y: 0 height: 96 loop: 160\nlayer_end\n"
            + "layer: \(backgroundLayers[1])\ntransparency: 0 width: 160 x: 0 y: 300 height: 160 loop: 160\nlayer_end\n\n"
    }

    static func stageText() -> String {
        "\n<stage> id: 0\n<phase> bound: 900\nid: 2 x: 700 hp: 150 times: 1\n<phase_end>\n<stage_end>\n\n"
    }

    // MARK: Generation

    /// The whole pack, in memory.
    static func make() throws -> SyntheticContentPack {
        let exe = exeSHA256
        var packages: [String: [String: [UInt8]]] = [:]

        // OriginalStartup (OriginalApplicationStartupInputs.load).
        var startupFiles: [String: [UInt8]] = [:]
        startupFiles["initial.bin"] = initialRecord()
        startupFiles["initial.mask"] = [UInt8](repeating: 1, count: OriginalRecordLayout.size)
        for n in 1...13 {   // MENU_BACK%d, 1...13 (OriginalMenuBackground.swift:17-20)
            startupFiles["bitmaps/MENU_BACK\(n).dib"] = SyntheticMedia.panel(width: 64, height: 48,
                fill: .init(r: UInt8(16*n), g: UInt8(200 - 12*n), b: 96), edge: .init(r: 255, g: 255, b: 255))
        }
        for (i, name) in SyntheticNames.frontBitmaps.enumerated() {
            startupFiles["bitmaps/\(name).dib"] = SyntheticMedia.panel(width: 32, height: 16,
                fill: .init(r: UInt8(10*i), g: 128, b: UInt8(255 - 10*i)), edge: .init(r: 0, g: 0, b: 0))
        }
        startupFiles["data/control.txt"] = Array(controlText.utf8)
        startupFiles["data/adinfo.txt"] = Array(adinfo.utf8)
        for (i, name) in SyntheticNames.menuSounds.enumerated() {
            startupFiles[packagePath(name)] = SyntheticMedia.wav(rate: 16000, samples: 1600 + 200*i, period: 20 + 4*i, amplitude: 60)
        }
        let startupEntries: [JSON] = startupFiles.keys.sorted().map { path in
            .object([("path", .string(path)), ("count", .int(startupFiles[path]!.count)), ("sha256", .string(digest(startupFiles[path]!)))])
        }
        let startupManifest = JSON.object([("version", .int(1)), ("generator", .string(generator)),
            ("globalAddress", .int(OriginalRecordLayout.base)), ("globalCount", .int(OriginalRecordLayout.size)),
            ("exeSHA256", .string(exe)), ("absentFiles", .array(absentFiles.map(JSON.string))), ("entries", .array(startupEntries))]).bytes
        startupFiles["manifest.json"] = startupManifest
        packages[startup] = startupFiles

        // OriginalCatalog (OriginalApplicationCatalogInputs.load): name, kind, path.
        var catalogEntries: [(name: String, kind: String, bytes: [UInt8])] = []
        catalogEntries.append((catalogFile, "file", Array(catalogText().utf8)))
        catalogEntries.append((stageFile, "file", try SyntheticDAT.encrypt(stageText(), fileName: stageFile)))
        for c in characters { catalogEntries.append((c.dat, "file", try SyntheticDAT.encrypt(characterText(c), fileName: c.dat))) }
        for item in items { catalogEntries.append((item.dat, "file", try SyntheticDAT.encrypt(itemText(item), fileName: item.dat))) }
        catalogEntries.append((backgroundDAT, "file", try SyntheticDAT.encrypt(backgroundText(), fileName: backgroundDAT)))
        catalogEntries.append((swingSound, "file", SyntheticMedia.wav(rate: 16000, samples: 2400, period: 12, amplitude: 90)))
        for c in characters {
            for mirrored in [false, true] {
                catalogEntries.append((mirrored ? c.mirror : c.sheet, "bitmapFile", SyntheticMedia.sheet(w: cell.w, h: cell.h, row: cell.row,
                    col: cell.col, body: c.body, accent: c.accent, mirrored: mirrored)))
            }
            // Portraits of an invented size (no engine rule fixes one).
            catalogEntries.append((c.head, "bitmapFile", SyntheticMedia.bands(width: 37, height: 41, colors: [c.accent, c.body])))
            catalogEntries.append((c.small, "bitmapFile", SyntheticMedia.bands(width: 37, height: 41, colors: [c.body, c.accent])))
        }
        for item in items {
            for mirrored in [false, true] {
                catalogEntries.append((mirrored ? item.mirror : item.sheet, "bitmapFile", SyntheticMedia.sheet(w: itemCell.w, h: itemCell.h,
                    row: itemCell.row, col: itemCell.col, body: item.color, accent: .init(r: 240, g: 240, b: 240), mirrored: mirrored)))
            }
        }
        let shadow = SyntheticMedia.bmp(width: 30, height: 9) { x, y in
            let dx = 2*x - 29, dy = 2*y - 8
            return dx*dx*16 + dy*dy*225 <= 225*16*4 ? .init(r: 32, g: 32, b: 32) : SyntheticMedia.black
        }
        catalogEntries.append((backgroundShadow, "bitmapFile", shadow))
        for (i, name) in builtInBitmaps.enumerated() {
            catalogEntries.append((name, "dib", SyntheticMedia.panel(width: 48 + 16*i, height: 24,
                fill: .init(r: 60, g: UInt8(80 + 40*i), b: 60), edge: .init(r: 20, g: 20, b: 20))))
        }
        for name in musicNames {
            catalogEntries.append((name, "music", Array("NTSD engine tests synthetic placeholder for \(name); not audio (ENGINE_SPLIT E7c)\n".utf8)))
        }
        var catalogFiles: [String: [UInt8]] = [:]
        var catalogJSON: [JSON] = []
        for e in catalogEntries {
            let path = packagePath(e.name)
            precondition(catalogFiles[path] == nil, "duplicate catalog path \(path)")
            catalogFiles[path] = e.bytes
            catalogJSON.append(.object([("name", .string(e.name)), ("kind", .string(e.kind)), ("path", .string(path)),
                                        ("count", .int(e.bytes.count)), ("sha256", .string(digest(e.bytes)))]))
        }
        let catalogManifest = JSON.object([("version", .int(1)), ("generator", .string(generator)), ("exeSHA256", .string(exe)),
                                           ("entries", .array(catalogJSON))]).bytes
        catalogFiles["manifest.json"] = catalogManifest
        packages[catalog] = catalogFiles

        // OriginalCommonSounds (OriginalApplicationLoadingInputs.load): name, count, sha256; file = name minus 5.
        var loadingFiles: [String: [UInt8]] = [:], loadingJSON: [JSON] = []
        for (i, name) in SyntheticNames.commonSounds.enumerated() {
            let bytes = SyntheticMedia.wav(rate: 16000, samples: 800 + 100*i, period: 8 + 2*i, amplitude: 40 + i)
            loadingFiles[String(name.dropFirst(5))] = bytes
            loadingJSON.append(.object([("name", .string(name)), ("count", .int(bytes.count)), ("sha256", .string(digest(bytes)))]))
        }
        let loadingManifest = JSON.object([("version", .int(1)), ("generator", .string(generator)), ("exeSHA256", .string(exe)),
                                           ("entries", .array(loadingJSON))]).bytes
        loadingFiles["manifest.json"] = loadingManifest
        packages[commonSounds] = loadingFiles

        // OriginalLoadingInterface, OriginalCharacterMenu, OriginalWarMenu: name, path = name.dib, count, sha256.
        func dibPackage(_ names: [String], width: Int, height: Int, seed: Int) -> (files: [String: [UInt8]], manifest: [UInt8]) {
            var files: [String: [UInt8]] = [:], entries: [JSON] = []
            for (i, name) in names.enumerated() {
                let bytes = SyntheticMedia.panel(width: width, height: height,
                    fill: .init(r: UInt8((seed + 23*i) % 256), g: UInt8((seed*3 + 41*i) % 256), b: UInt8((seed*7 + 59*i) % 256)),
                    edge: .init(r: 250, g: 250, b: 250))
                files[name + ".dib"] = bytes
                entries.append(.object([("name", .string(name)), ("path", .string(name + ".dib")), ("count", .int(bytes.count)),
                                        ("sha256", .string(digest(bytes)))]))
            }
            let manifest = JSON.object([("version", .int(1)), ("generator", .string(generator)), ("exeSHA256", .string(exe)),
                                        ("entries", .array(entries))]).bytes
            files["manifest.json"] = manifest
            return (files, manifest)
        }
        let interface = dibPackage(SyntheticNames.interfaceBitmaps, width: 40, height: 20, seed: 11)
        let menu = dibPackage(SyntheticNames.menuBitmaps, width: 48, height: 24, seed: 29)
        let war = dibPackage(SyntheticNames.warBitmaps, width: 56, height: 28, seed: 53)
        packages[loadingInterface] = interface.files
        packages[characterMenu] = menu.files
        packages[warMenu] = war.files

        // OriginalMatchArenas (OriginalApplicationArenaInputs.load): every BMP of
        // the background's folder; name = path with backslashes, `bytes` not `count`.
        var arenaFiles: [String: [UInt8]] = [:], arenaJSON: [JSON] = []
        let layerImages = [SyntheticMedia.bands(width: 160, height: 96, colors: [.init(r: 96, g: 160, b: 232), .init(r: 168, g: 208, b: 248)]),
                           SyntheticMedia.bands(width: 160, height: 160, colors: [.init(r: 72, g: 136, b: 56), .init(r: 120, g: 96, b: 64)])]
        for (name, bytes) in [(backgroundShadow, shadow)] + Array(zip(backgroundLayers, layerImages)) {
            let path = packagePath(name)
            arenaFiles[path] = bytes
            arenaJSON.append(.object([("name", .string(name)), ("path", .string(path)), ("bytes", .int(bytes.count)), ("sha256", .string(digest(bytes)))]))
        }
        let arenaManifest = JSON.object([("version", .int(1)), ("generator", .string(generator)), ("exeSHA256", .string(exe)),
                                         ("entries", .array(arenaJSON))]).bytes
        arenaFiles["manifest.json"] = arenaManifest
        packages[arenas] = arenaFiles

        // OriginalMusic (OriginalMacMusicOutput.silent/bundled): sampleRate,
        // entries of name, resource, frames; short quiet WAV tracks.
        var musicFiles: [String: [UInt8]] = [:], musicJSON: [JSON] = []
        for (i, name) in musicNames.enumerated() {
            let resource = String(name.dropFirst(4).dropLast(4)) + ".wav", frames = musicRate/2 + 1000*i
            musicFiles[resource] = SyntheticMedia.wav(rate: musicRate, samples: frames, period: 64 + 8*i, amplitude: 12)
            musicJSON.append(.object([("name", .string(name)), ("resource", .string(resource)), ("frames", .int(frames))]))
        }
        musicFiles["manifest.json"] = JSON.object([("version", .int(1)), ("generator", .string(generator)),
            ("sampleRate", .int(musicRate)), ("entries", .array(musicJSON))]).bytes
        packages[music] = musicFiles

        let counts = (files: catalogEntries.filter { $0.kind == "file" }.count,
                      bitmaps: catalogEntries.filter { $0.kind == "bitmapFile" || $0.kind == "dib" }.count,
                      music: catalogEntries.filter { $0.kind == "music" }.count)
        let identity = OriginalContentIdentity(exeSHA256: exe,
            catalog: .init(manifestSHA256: digest(catalogManifest), entries: catalogEntries.count,
                           files: counts.files, bitmaps: counts.bitmaps, music: counts.music),
            startup: .init(manifestSHA256: digest(startupManifest), entries: startupEntries.count, absentFiles: absentFiles),
            loadingManifestSHA256: digest(loadingManifest), interfaceManifestSHA256: digest(interface.manifest),
            menuManifestSHA256: digest(menu.manifest), warMenuManifestSHA256: digest(war.manifest),
            arenaManifestSHA256: digest(arenaManifest), rules: .syntheticPack)
        return .init(packages: packages, identity: identity)
    }

    /// The pack, made once per test process.
    static let shared: Result<SyntheticContentPack, Error> = Result { try make() }

    /// Writes every package under `root` (which must not exist yet).
    func write(to root: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: false)
        for (package, files) in packages {
            for (path, bytes) in files {
                let url = root.appendingPathComponent(package).appendingPathComponent(path)
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(bytes).write(to: url)
            }
        }
    }

    /// The folder packs are written under: `TMPDIR` when set (Darwin's
    /// `FileManager.temporaryDirectory` ignores it and names the per-user
    /// folder on the system disk), else `FileManager.temporaryDirectory`.
    static var temporaryParent: URL {
        if let path = ProcessInfo.processInfo.environment["TMPDIR"], !path.isEmpty { return URL(fileURLWithPath: path, isDirectory: true) }
        return FileManager.default.temporaryDirectory
    }

    /// Runs `body` with the pack written to a fresh temporary folder, removed afterwards.
    static func withWrittenPack<T>(_ body: (URL, SyntheticContentPack) throws -> T) throws -> T {
        let pack = try shared.get()
        let root = temporaryParent.appendingPathComponent("ntsd-synthetic-pack-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try pack.write(to: root)
        return try body(root, pack)
    }

    // MARK: Helpers

    static let generator = "NTSDEngineTests SyntheticContentPack (ENGINE_SPLIT E7c); authored, no original bytes"
    /// A Windows path's package path: backslashes as folder separators.
    static func packagePath(_ name: String) -> String { name.replacingOccurrences(of: "\\", with: "/") }
    static func digest(_ bytes: [UInt8]) -> String { hex(PortableSHA256.hash(data: bytes)) }
    static func hex(_ bytes: [UInt8]) -> String { OriginalConcurrentInputs.hex(bytes) }

    /// A minimal JSON writer with ordered keys, so a manifest's bytes (and its
    /// digest in the identity) are the same on every host.
    indirect enum JSON {
        case int(Int), string(String), array([JSON]), object([(String, JSON)])
        var text: String {
            switch self {
            case .int(let value): return String(value)
            case .string(let value):
                var out = "\""
                for scalar in value.unicodeScalars {
                    switch scalar {
                    case "\"": out += "\\\""
                    case "\\": out += "\\\\"
                    case "\n": out += "\\n"
                    case "\r": out += "\\r"
                    case "\t": out += "\\t"
                    default:
                        if scalar.value < 0x20 {
                            let digits = String(scalar.value, radix: 16)
                            out += "\\u" + String(repeating: "0", count: 4 - digits.count) + digits
                        } else { out.unicodeScalars.append(scalar) }
                    }
                }
                return out + "\""
            case .array(let items): return "[" + items.map(\.text).joined(separator: ",\n") + "]"
            case .object(let members): return "{" + members.map { JSON.string($0.0).text + ": " + $0.1.text }.joined(separator: ",\n") + "}"
            }
        }
        var bytes: [UInt8] { Array((text + "\n").utf8) }
    }
}
