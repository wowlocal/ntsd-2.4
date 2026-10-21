import Foundation
import XCTest
@testable import NTSDCore
import NTSDRuntime

/// ENGINE_SPLIT E7c, first rung: the synthetic content pack (SyntheticContentPack)
/// loads through the engine's public package loaders and builds a loaded
/// catalog, checked against the identity computed from its own manifests; a
/// changed file fails that identity with the loader's declared error. Second
/// rung: the common-sound, interface, menu, War-menu and arena packages and the
/// music manifest. No original content is read.
final class SyntheticContentPackTests: XCTestCase {
    typealias Pack = SyntheticContentPack

    private func directory(_ root: URL, _ package: String) -> URL { root.appendingPathComponent(package, isDirectory: true) }
    private func cString(_ record: OriginalStateRecord, at offset: Int) throws -> String {
        var bytes: [UInt8] = [], at = offset
        while true {
            let byte = try record.integer(at: at, as: UInt8.self)
            if byte == 0 { return String(decoding: bytes, as: UTF8.self) }
            bytes.append(byte); at += 1
        }
    }
    private func word(_ record: OriginalStateRecord, _ address: Int) throws -> Int32 {
        try record.integer(at: address - OriginalRecordLayout.base, as: Int32.self)
    }

    // MARK: Startup

    func testStartupPackageLoadsThroughItsLoader() throws {
        try Pack.withWrittenPack { root, pack in
            let inputs = try OriginalApplicationStartupInputs.load(directory: directory(root, Pack.startup), identity: pack.identity)
            XCTAssertEqual(inputs.initial.byteCount, 0xc3a8)
            // Generator invariants (read back, not computed by the engine): the
            // record holds the table's words (E7d) and zero elsewhere.
            var expected = [UInt8](repeating: 0, count: 0xc3a8)
            for w in Pack.recordWords {
                XCTAssertEqual(try inputs.initial.integer(at: w.offset - OriginalRecordLayout.base, as: UInt32.self), w.value, w.check)
                for i in 0..<4 { expected[w.offset - OriginalRecordLayout.base + i] = UInt8(truncatingIfNeeded: w.value >> (8*i)) }
            }
            XCTAssertEqual(Set(Pack.recordWords.map(\.offset)).count, Pack.recordWords.count, "one entry per word")
            XCTAssertTrue(inputs.initial.bytes == expected, "only the table's words are nonzero")
            XCTAssertEqual(Set(inputs.bitmaps.keys), Set((1...13).map { "MENU_BACK\($0)" } + SyntheticNames.frontBitmaps))
            XCTAssertEqual(inputs.bitmaps["MENU_BACK13"].map { [$0.width, $0.height, Int32($0.bitsPerPixel)] }, [64, 48, 24])
            XCTAssertEqual(inputs.bitmaps["SY_FRONT_23"].map { [$0.width, $0.height] }, [32, 16])
            XCTAssertEqual(try inputs.file("data\\control.txt"), Array(Pack.controlText.utf8))
            XCTAssertEqual(try inputs.file("data\\adinfo.txt"), Array(Pack.adinfo.utf8))
            XCTAssertNil(try inputs.file("data\\ad0.txt"), "declared absent")
            XCTAssertThrowsError(try inputs.file("data\\undeclared.txt")) {
                XCTAssertEqual($0 as? OriginalApplicationStartupInputs.Boundary, .unsupportedName("data\\undeclared.txt"))
            }
            XCTAssertEqual(try inputs.controlBytes(), Array(Pack.controlText.replacingOccurrences(of: "\r\n", with: "\n").utf8))
            XCTAssertEqual(inputs.rules, .syntheticPack)
            // The menu WAVs parse as the runtime's startup reads them.
            for name in inputs.rules.interface.menuSounds {
                XCTAssertNoThrow(try OriginalMacRuntimeWave.input(name, XCTUnwrap(inputs.file(name))), name)
            }
        }
    }

    /// control.txt and adinfo.txt in the grammar the engine's readers recover.
    func testStartupTextFilesReadThroughTheEngineReaders() throws {
        try Pack.withWrittenPack { root, pack in
            let inputs = try OriginalApplicationStartupInputs.load(directory: directory(root, Pack.startup), identity: pack.identity)
            let size = OriginalMatchPreparation.globalSize
            var globals = try OriginalStateRecord(bytes: Array(inputs.initial.bytes.prefix(size)), defined: [Bool](repeating: true, count: size))
            let settings = try OriginalSettingsLoading.loadOwnStartup(globals: &globals, translatedBytes: inputs.controlBytes(),
                                                                      file: 0x1000, scratchAddress: 0x2000, target: 0x3000)
            XCTAssertEqual(settings.continuation, .ready)
            // Player 1: keyboard (device 0), up 'A'; player 4's defend '6' and last joystick button 7.
            XCTAssertEqual(try [word(globals, 0x44fb70), word(globals, 0x44fb74)], [0, 0x41])
            XCTAssertEqual(try [word(globals, 0x44fb70 + 0x50*3 + 4*7), word(globals, 0x44fb70 + 0x50*3 + 4*10)], [0x36, 7])
            XCTAssertEqual(try (0..<4).map { try cString(globals, at: 0x44fcc0 + 11*$0 - OriginalRecordLayout.base) }, ["Ann", "Bo", "Cy", "Di"])
            XCTAssertEqual(try [word(globals, 0x450be8), word(globals, 0x450be4)], [2, 1])
            XCTAssertEqual(try cString(globals, at: 0x44fd18 - OriginalRecordLayout.base), "synthetic pack settings")
            XCTAssertEqual(try cString(globals, at: 0x44f900 - OriginalRecordLayout.base), "end of synthetic settings")

            var local = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: OriginalMenuInfoReading.localCount),
                                                defined: [Bool](repeating: false, count: OriginalMenuInfoReading.localCount))
            let info = try OriginalMenuInfoReading.load(globals: &globals, local: &local, translatedBytes: inputs.file("data\\adinfo.txt"))
            XCTAssertEqual(info, 1)
            XCTAssertEqual(try [word(globals, 0x44d784), word(globals, 0x44d788)], [0, 5])
            XCTAssertEqual(try cString(globals, at: 0x453c68 - OriginalRecordLayout.base), "data\\ad0.txt")
            XCTAssertEqual(pack.identity.startup.absentFiles, ["data/ad0.txt"])
        }
    }

    // MARK: Catalog

    private struct LoadedCatalog {
        let catalog: OriginalLoadedCatalog, requestedBitmaps: [String], sounds: [String]
    }
    /// `loadWithFiles` over the catalog inputs, as the app's catalog session
    /// calls it (text translation, data\data.txt), with logical allocations.
    private func loadCatalog(_ inputs: OriginalApplicationCatalogInputs, scanfLookahead: Bool) throws -> LoadedCatalog {
        func unknown(_ count: Int) throws -> OriginalStateRecord {
            try .init(bytes: [UInt8](repeating: 0xa5, count: count), defined: [Bool](repeating: false, count: count))
        }
        var parent = try OriginalCatalogRegistry.regionSizes.mapValues { try unknown($0) }
        let background = try unknown(OriginalBackgroundLoader.recordSize), stage = try unknown(OriginalStageLoader.stageSize).paged()
        let backgrounds = [OriginalStateRecord](repeating: background, count: 101)
        parent[0x4d81060] = backgrounds[99]; parent[0x4d819f0] = backgrounds[100]
        var next: UInt32 = 0x100, requested: [String] = [], sounds: [String] = []
        let result = try OriginalLoadedCatalog.loadWithFiles(files: .init(translation: .text, scanfLookahead: scanfLookahead),
            fileName: Pack.catalogFile, rules: inputs.rules, parentBacking: parent, backgroundBacking: backgrounds,
            stageBacking: [OriginalStateRecord](repeating: stage, count: 60),
            fileSource: { path in
                guard let bytes = try inputs.file(path) else { throw OriginalStateError.invalidStorage("Missing catalog file \(path)") }
                return bytes
            },
            fileAllocation: { _, _ in
                next += 0x10
                return .init(token: next, buffer: next << 12, descriptor: 3, capacity: 0x1000, readLimit: 0x1000)
            },
            bitmapSource: { path in
                requested.append(path)
                guard let bitmap = inputs.bitmaps[path] else { return .init(path: path, present: false) }
                return .init(path: path, present: true, width: bitmap.width, height: bitmap.height)
            },
            onNewSound: { _, registration in sounds.append(registration.path) })
        return .init(catalog: result.catalog, requestedBitmaps: requested, sounds: sounds)
    }

    func testCatalogLoadsAndBuildsALoadedCatalog() throws {
        try Pack.withWrittenPack { root, pack in
            let inputs = try OriginalApplicationCatalogInputs.load(directory: directory(root, Pack.catalog), identity: pack.identity)
            let objectFiles = Pack.characters.map(\.dat) + Pack.items.map(\.dat)
            XCTAssertEqual(Set(inputs.files.keys), Set([Pack.catalogFile, Pack.stageFile, Pack.backgroundDAT, Pack.swingSound] + objectFiles))
            XCTAssertEqual(inputs.bitmaps.count, 4 + 4*Pack.characters.count + 2*Pack.items.count + 1,
                           "built-ins, each character's four, each item's two, the shadow")
            XCTAssertEqual(Set(Pack.builtInBitmaps).subtracting(inputs.bitmaps.keys), [])
            XCTAssertEqual(Set(inputs.music.keys), Set(Pack.musicNames))
            XCTAssertEqual(inputs.rules, .syntheticPack)

            let expectedBitmaps = Pack.builtInBitmaps + Pack.characters.flatMap { [$0.head, $0.small, $0.sheet, $0.mirror] }
                + Pack.items.flatMap { [$0.sheet, $0.mirror] } + [Pack.backgroundShadow]
            var checksums: [UInt32] = []
            for lookahead in [false, true] {
                let loaded = try loadCatalog(inputs, scanfLookahead: lookahead)
                let catalog = loaded.catalog
                // The registry's requests: built-ins, then each object after its progress step, the background, the Stage file.
                let objectCount = Pack.characters.count + Pack.items.count
                XCTAssertEqual(catalog.registry.requests.map(\.kind), [.bitmap, .bitmap, .bitmap, .bitmap]
                    + (0..<objectCount).flatMap { _ in [OriginalCatalogLoadRequest.Kind.progress, .object] } + [.background, .stages])
                XCTAssertEqual(catalog.registry.requests.filter { $0.kind == .object }.map { [$0.id, $0.objectType] },
                               Pack.characters.map { [$0.id, 0] } + Pack.items.map { [$0.id, 1] })
                // Objects: IDs, names, the sheet and the frames the DATs define.
                XCTAssertEqual(catalog.objects.count, objectCount)
                for (object, character) in zip(catalog.objects, Pack.characters) {
                    XCTAssertEqual(try object.header.integer(at: 0x6f4, as: Int32.self), character.id)
                    XCTAssertEqual(try object.header.integer(at: 0x6f8, as: Int32.self), 0)
                    XCTAssertEqual(try cString(object.nameTail, at: 0), character.name)
                    XCTAssertEqual(try object.header.integer(at: 0x498, as: Int32.self), 1, "one sprite sheet")
                    XCTAssertEqual(try [0x650, 0x678, 0x6a0, 0x6c8].map { try object.header.integer(at: $0 + 4, as: Int32.self) }, [23, 31, 4, 3])
                    let written = object.frames.filter { !$0.name.isEmpty }.map(\.number)
                    // E7f: characters 3-8 also have the second punch.
                    let punches = character.id <= 2 ? [60, 61] : [60, 61, 65, 66]
                    XCTAssertEqual(written, [0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11] + punches + [110] + Array(180...191)
                                   + [210, 211, 212, 215, 219] + Array(220...227).filter { $0 != 221 } + [230, 231])
                    XCTAssertEqual(object.frames[3].field("next"), 999)
                    for punch in punches where punch % 5 == 0 {
                        XCTAssertEqual(object.frames[punch].sound, Pack.swingSound)
                        XCTAssertEqual(object.frames[punch].interactions.count, 1)
                        XCTAssertEqual(object.frames[punch].interactions.first?[17], (character.id <= 2 ? 23 : 90) + 4*Int32(character.pace), "injury")
                    }
                    XCTAssertEqual(object.frames[0].bodies.count, 1)
                    XCTAssertEqual(object.frames[230].bodies.count, 0)
                }
                // Bitmaps: every request found in the package, none mirrored by the fallback.
                XCTAssertEqual(loaded.requestedBitmaps, expectedBitmaps)
                XCTAssertEqual(catalog.bitmaps.map(\.input.path), expectedBitmaps)
                XCTAssertTrue(catalog.bitmaps.allSatisfy { $0.input.present && $0.mirroredFrom == nil })
                // One frame sound, registered once for both characters.
                XCTAssertEqual(loaded.sounds, [Pack.swingSound])
                XCTAssertEqual(catalog.soundCount, 1)
                // The background record (OriginalBackgroundLoader offsets).
                let field = catalog.backgrounds[0]
                XCTAssertEqual(try field.integer(at: 0, as: Int32.self), 1000)
                XCTAssertEqual(try [field.integer(at: 4, as: Int32.self), field.integer(at: 8, as: Int32.self)], [320, 460])
                XCTAssertEqual(try cString(field, at: 0x3cc), "Sy Field")
                XCTAssertEqual(try cString(field, at: 0x3a4), Pack.backgroundShadow)
                XCTAssertEqual(try [field.integer(at: 0x14, as: Int32.self), field.integer(at: 0x18, as: Int32.self)], [15, 4], "shadow size")
                XCTAssertEqual(try field.integer(at: 0x1c, as: Int32.self), 2, "layers")
                XCTAssertEqual(try cString(field, at: 0x20 + 30), Pack.backgroundLayers[1])
                // The Stage table: stage 0 has one phase with one entry; the others stay unset.
                let stage = catalog.stages[0]
                XCTAssertEqual(try stage.integer(at: 0, as: Int32.self), 1)
                XCTAssertEqual(try stage.integer(at: 8, as: Int32.self), 900)
                XCTAssertEqual(try [0, 4, 8].map { try stage.integer(at: 0xec + $0, as: Int32.self) }, [2, 700, 150])
                XCTAssertEqual(try catalog.stages[1].integer(at: 0, as: Int32.self), -1)
                XCTAssertNotEqual(catalog.checksum, 0)
                checksums.append(catalog.checksum)
            }
            // Every DAT ends in two whitespace characters, so the scanf lookahead drops nothing that counts.
            XCTAssertEqual(checksums[0], checksums[1])
        }
    }

    // MARK: Identity

    /// Mostly a generator invariant: the identity's digests and counts read back
    /// what the generator wrote; the loaders' acceptance is tested above.
    func testIdentityIsComputedFromTheWrittenManifests() throws {
        try Pack.withWrittenPack { root, pack in
            func manifestDigest(_ package: String) throws -> String {
                Pack.digest(Array(try Data(contentsOf: directory(root, package).appendingPathComponent("manifest.json"))))
            }
            let identity = pack.identity
            XCTAssertEqual(identity.exeSHA256, Pack.exeSHA256)
            XCTAssertEqual(identity.exeSHA256.count, 64)
            XCTAssertTrue(identity.exeSHA256.allSatisfy { "0123456789abcdef".contains($0) })
            XCTAssertEqual(identity.startup.manifestSHA256, try manifestDigest(Pack.startup))
            XCTAssertEqual(identity.catalog.manifestSHA256, try manifestDigest(Pack.catalog))
            XCTAssertEqual(identity.loadingManifestSHA256, try manifestDigest(Pack.commonSounds))
            XCTAssertEqual(identity.interfaceManifestSHA256, try manifestDigest(Pack.loadingInterface))
            XCTAssertEqual(identity.menuManifestSHA256, try manifestDigest(Pack.characterMenu))
            XCTAssertEqual(identity.warMenuManifestSHA256, try manifestDigest(Pack.warMenu))
            XCTAssertEqual(identity.arenaManifestSHA256, try manifestDigest(Pack.arenas))
            // initial.bin and .mask, 13 MENU_BACK and 24 front DIBs, control, adinfo and 5 menu WAVs; the catalog's
            // entries by role: data.txt, stage.dat, a DAT per character and item, the background DAT and the swing WAV; the
            // built-ins, four images per character, two per item and the shadow; eight music names
            // (8 characters and an item: 60 entries).
            let n = Pack.characters.count, m = Pack.items.count
            XCTAssertEqual(identity.startup.entries, 2 + 13 + 24 + 2 + 5)
            XCTAssertEqual([identity.catalog.entries, identity.catalog.files, identity.catalog.bitmaps, identity.catalog.music],
                           [(4 + n + m) + (5 + 4*n + 2*m) + 8, 4 + n + m, 5 + 4*n + 2*m, 8])
            XCTAssertEqual(identity.catalog.entries, 60)
            XCTAssertEqual(identity.rules, .syntheticPack)
            // The generator is deterministic: a second pack has the same bytes.
            XCTAssertEqual(try Pack.make().packages, pack.packages)
            syntheticLog("synthetic pack written under \(root.deletingLastPathComponent().path)")
            for (package, files) in pack.packages.sorted(by: { $0.key < $1.key }) {
                syntheticLog("synthetic pack: \(package) \(files.count) files \(files.values.map(\.count).reduce(0, +)) bytes")
            }
        }
    }

    func testPackRootServesAsAResourcesDirectory() throws {
        try Pack.withWrittenPack { root, pack in
            let bundle = try XCTUnwrap(Bundle(path: root.path))
            let content = OriginalContentLocation(appBundle: bundle, identity: pack.identity, fallback: { nil })
            XCTAssertEqual(try OriginalApplicationStartupInputs.bundled(in: content).bitmaps.count, 37)
            XCTAssertEqual(try OriginalApplicationCatalogInputs.bundled(in: content).files.count, 4 + Pack.characters.count + Pack.items.count)
            XCTAssertEqual(try OriginalApplicationInterfaceInputs.bundled(in: content).bitmaps.count, 10)
            XCTAssertEqual(try OriginalApplicationMenuInputs.bundledWithWar(in: content).bitmaps.count, 13)
            XCTAssertEqual(try OriginalApplicationArenaInputs.bundled(in: content).bitmaps.count, 3)
            XCTAssertNoThrow(try OriginalApplicationLoadingInputs.bundled(in: content))
        }
    }

    // MARK: Changed files

    func testChangedCatalogFileFailsItsDigest() throws {
        try Pack.withWrittenPack { root, pack in
            let url = directory(root, Pack.catalog).appendingPathComponent("data/sy_one.dat")
            var bytes = Array(try Data(contentsOf: url)); bytes[200] ^= 0x01
            try Data(bytes).write(to: url)
            XCTAssertThrowsError(try OriginalApplicationCatalogInputs.load(directory: directory(root, Pack.catalog), identity: pack.identity)) {
                XCTAssertEqual($0 as? OriginalApplicationCatalogInputs.Boundary, .invalid("data\\sy_one.dat"))
            }
        }
    }

    func testChangedStartupFileFailsItsDigest() throws {
        try Pack.withWrittenPack { root, pack in
            let url = directory(root, Pack.startup).appendingPathComponent("data/control.txt")
            var bytes = Array(try Data(contentsOf: url)); bytes[0] ^= 0x01
            try Data(bytes).write(to: url)
            XCTAssertThrowsError(try OriginalApplicationStartupInputs.load(directory: directory(root, Pack.startup), identity: pack.identity)) {
                XCTAssertEqual($0 as? OriginalApplicationStartupInputs.Boundary, .invalid("data/control.txt"))
            }
        }
    }

    func testChangedManifestFailsTheIdentity() throws {
        try Pack.withWrittenPack { root, pack in
            for package in [Pack.startup, Pack.catalog] {
                let url = directory(root, package).appendingPathComponent("manifest.json")
                try Data(Array(try Data(contentsOf: url)) + [0x20]).write(to: url)
            }
            XCTAssertThrowsError(try OriginalApplicationStartupInputs.load(directory: directory(root, Pack.startup), identity: pack.identity)) {
                XCTAssertEqual($0 as? OriginalApplicationStartupInputs.Boundary, .invalid("Manifest digest"))
            }
            XCTAssertThrowsError(try OriginalApplicationCatalogInputs.load(directory: directory(root, Pack.catalog), identity: pack.identity)) {
                XCTAssertEqual($0 as? OriginalApplicationCatalogInputs.Boundary, .invalid("Manifest digest"))
            }
        }
    }

    /// An identity that declares other counts, or a package with an extra file, is refused.
    func testIdentityCountsAndPackageCompositionAreChecked() throws {
        try Pack.withWrittenPack { root, pack in
            let i = pack.identity, c = i.catalog
            let wrong = OriginalContentIdentity(exeSHA256: i.exeSHA256,
                catalog: .init(manifestSHA256: c.manifestSHA256, entries: c.entries, files: c.files - 1, bitmaps: c.bitmaps + 1, music: c.music),
                startup: .init(manifestSHA256: i.startup.manifestSHA256, entries: i.startup.entries + 1, absentFiles: i.startup.absentFiles),
                loadingManifestSHA256: i.loadingManifestSHA256, interfaceManifestSHA256: i.interfaceManifestSHA256,
                menuManifestSHA256: i.menuManifestSHA256, warMenuManifestSHA256: i.warMenuManifestSHA256,
                arenaManifestSHA256: i.arenaManifestSHA256, rules: i.rules)
            XCTAssertThrowsError(try OriginalApplicationCatalogInputs.load(directory: directory(root, Pack.catalog), identity: wrong)) {
                XCTAssertEqual($0 as? OriginalApplicationCatalogInputs.Boundary, .invalid("Input roles"))
            }
            XCTAssertThrowsError(try OriginalApplicationStartupInputs.load(directory: directory(root, Pack.startup), identity: wrong)) {
                XCTAssertEqual($0 as? OriginalApplicationStartupInputs.Boundary, .invalid("Manifest contract"))
            }
            try Data([0x41]).write(to: directory(root, Pack.startup).appendingPathComponent("data/extra.txt"))
            XCTAssertThrowsError(try OriginalApplicationStartupInputs.load(directory: directory(root, Pack.startup), identity: i)) {
                XCTAssertEqual($0 as? OriginalApplicationStartupInputs.Boundary, .invalid("Package composition or PE masks"))
            }
        }
    }

    // MARK: Second rung: the other packages

    func testInterfaceMenuSoundAndArenaPackagesLoad() throws {
        try Pack.withWrittenPack { root, pack in
            let identity = pack.identity
            let loading = try OriginalApplicationLoadingInputs.load(directory: directory(root, Pack.commonSounds), identity: identity)
            for name in SyntheticNames.commonSounds { XCTAssertNoThrow(try OriginalMacRuntimeWave.input(name, loading.file(name)), name) }
            let interface = try OriginalApplicationInterfaceInputs.load(directory: directory(root, Pack.loadingInterface), identity: identity)
            XCTAssertEqual(Set(interface.bitmaps.keys), Set(SyntheticNames.interfaceBitmaps))
            let menu = try OriginalApplicationMenuInputs.load(directory: directory(root, Pack.characterMenu), identity: identity)
            XCTAssertEqual(Set(menu.bitmaps.keys), Set(SyntheticNames.menuBitmaps))
            let war = try OriginalApplicationMenuInputs.load(directory: directory(root, Pack.warMenu), identity: identity,
                                                             manifest: identity.warMenuManifestSHA256, names: identity.rules.interface.warBitmaps)
            XCTAssertEqual(Set(war.bitmaps.keys), Set(SyntheticNames.warBitmaps))
            let arenas = try OriginalApplicationArenaInputs.load(directory: directory(root, Pack.arenas), identity: identity)
            XCTAssertEqual(Set(arenas.bitmaps.keys), Set([Pack.backgroundShadow] + Pack.backgroundLayers))
            XCTAssertEqual(arenas.bitmaps[Pack.backgroundLayers[1]].map { [$0.width, $0.height] }, [160, 160])
            // The War menu's manifest is not the character menu's.
            XCTAssertThrowsError(try OriginalApplicationMenuInputs.load(directory: directory(root, Pack.warMenu), identity: identity)) {
                XCTAssertEqual($0 as? OriginalApplicationMenuInputs.Boundary, .invalid("Manifest digest"))
            }
        }
    }

    /// The music manifest's form (as OriginalMacMusicOutput.silent/bundled read it):
    /// its tracks are the engine's `bgm\` names; each frame count is its WAV's.
    /// Mostly a generator invariant (the manifest names the engine's eight tracks);
    /// the tracks' playback is SyntheticContentPackMusicTests'.
    func testMusicManifestNamesTheEngineTracks() throws {
        try Pack.withWrittenPack { root, _ in
            let folder = directory(root, Pack.music)
            let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("manifest.json"))) as? [String: Any])
            XCTAssertEqual((manifest["sampleRate"] as? NSNumber)?.intValue, Pack.musicRate)
            let entries = try XCTUnwrap(manifest["entries"] as? [[String: Any]])
            XCTAssertEqual(entries.compactMap { $0["name"] as? String }, Pack.musicNames)
            for entry in entries {
                let resource = try XCTUnwrap(entry["resource"] as? String)
                let wave = Array(try Data(contentsOf: folder.appendingPathComponent(resource)))
                XCTAssertNoThrow(try OriginalMacRuntimeWave.input(resource, wave))
                let dataSize = Int(wave[42]) | Int(wave[43]) << 8 | Int(wave[44]) << 16 | Int(wave[45]) << 24  // after RIFF, WAVE, an 18-byte fmt and "data"
                XCTAssertEqual((entry["frames"] as? NSNumber)?.intValue, dataSize, resource)
            }
        }
    }

    /// Writes the pack to `SYNTHETIC_PACK_OUT` (a folder that must not exist) for
    /// tools/scan_original_bytes.py's `--engine-files`; skipped when unset.
    func testWritesThePackWhereAsked() throws {
        guard let out = ProcessInfo.processInfo.environment["SYNTHETIC_PACK_OUT"], !out.isEmpty else {
            throw XCTSkip("SYNTHETIC_PACK_OUT not set")
        }
        try SyntheticContentPack.shared.get().write(to: URL(fileURLWithPath: out, isDirectory: true))
    }

    /// One SHA-256 over every generated file (package, path and bytes in order)
    /// and the catalog checksum, pinned: macOS and Linux must generate and load
    /// the same pack (the generator uses integer arithmetic only).
    func testPackAndCatalogChecksumAreTheSameOnEveryHost() throws {
        let pack = try Pack.shared.get()
        var all: [UInt8] = []
        for package in pack.packages.keys.sorted() {
            for path in pack.packages[package]!.keys.sorted() {
                all += Array("\(package)/\(path)\0".utf8) + pack.packages[package]![path]!
            }
        }
        let digest = PortableSHA256.hash(data: Data(all)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, Self.pinnedPackSHA256)
        try Pack.withWrittenPack { root, pack in
            let inputs = try OriginalApplicationCatalogInputs.load(directory: directory(root, Pack.catalog), identity: pack.identity)
            XCTAssertEqual(try loadCatalog(inputs, scanfLookahead: true).catalog.checksum, Self.pinnedCatalogChecksum)
        }
    }
    /// E7d: the pack grew (record words, keyboard control.txt, six characters, an item,
    /// more frames); E7c's values were b99cd1f4… and 123223. E7f: two record
    /// words (initial.bin) and characters 3-8's punches (their DATs); E7d's
    /// values were 2f16f591… and 761717.
    static let pinnedPackSHA256 = "d4363b8a3089ad0aeadf0592307208531e6c1c3fc3abda4f8ea8ad5f75abc9d4"
    static let pinnedCatalogChecksum: UInt32 = 784925
}
