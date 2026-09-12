import Foundation
import CryptoKit
import NTSDCore

enum LoadedSessionError: Error {
    case input(String), lifecycle, deliberateRollback, continuation(String)
}

/// A declared headless platform input, not a Windows allocator/device model.
enum LoadedPlatformProfile: UInt32 {
    case ascendingA5 = 0, reverseRamp = 1
    func backing(_ count: Int) -> [UInt8] {
        (0..<count).map { self == .ascendingA5 ? 0xa5 : UInt8(truncatingIfNeeded: $0) }
    }
    func allocation(_ index: Int) -> UInt32 {
        0x28000020 + UInt32(self == .ascendingA5 ? index + 8 : 6144 - index) * 0x2000
    }
    static let device: UInt32 = 0x28002020
    static let world: UInt32 = 0x22000020
    static let file: UInt32 = 0x20001000
    static let scratch: UInt32 = 0x1000ee04
}

struct ResourceManifest: Decodable {
    let schemaVersion: Int, originalEXESHA256: String, runtimeContainsOriginalExecutable: Bool
    struct Globals: Decodable {
        let base, count, fileBytes, zeroFillStart, zeroFillEnd: Int
        let dataPath, sha256: String
    }
    struct Embedded: Decodable {
        let key: String, language: Int, dibPath: String, dibSHA256: String
        let width, height: Int32
    }
    struct Original: Decodable { let path, source, sha256: String; let bytes: Int }
    let globals: Globals, embedded: [Embedded], original: [Original]
}

struct LoadedRecordExport: Encodable {
    let bytes: String, defined: String
    init(_ record: OriginalStateRecord) {
        bytes = Data(record.bytes).base64EncodedString()
        defined = Data(record.defined.map { $0 ? 1 : 0 }).base64EncodedString()
    }
}

private struct SettingsExport: Encodable {
    let kind: String, arguments: [UInt32], strings: [String]
    let format: String?, before: Int?, position: Int?, eof: Bool?, result: UInt32?
    let globals: LoadedRecordExport, scratch: LoadedRecordExport
    init(_ event: OriginalSettingsEvent, _ globals: OriginalStateRecord, _ scratch: OriginalStateRecord) {
        kind = event.kind.rawValue; arguments = event.arguments; strings = event.strings
        format = event.format; before = event.before; position = event.position; eof = event.eof; result = event.result
        self.globals = .init(globals); self.scratch = .init(scratch)
    }
}

/// Persistent future gameplay owner. No finished World/global/reference snapshot
/// can enter this initializer. Only original resource bytes and a declared provider.
struct LoadedSession {
    var lifecycle: UInt32 = 2 // PRISTINE_BOOT
    var world: OriginalStateRecord
    var globals: OriginalStateRecord
    let savedPlayback: OriginalStateRecord
    var replayPointers: OriginalStateRecord
    let profile: LoadedPlatformProfile
    let resourceRoot: URL, manifestSHA256: String
    private let rawControl: [UInt8], dibs: [String: [UInt8]], inputs: [String: OriginalBitmapInput]
    private let initialGlobals: OriginalStateRecord
    private var front = OriginalFrontMenuResources()
    private var frontEvents: [OriginalFrontMenuEvent] = []
    private var frontGlobals: OriginalStateRecord?
    private var settingsEvents: [SettingsExport] = []
    private var scratch: OriginalStateRecord?
    private var settingsContinuation: String?
    private var frontScreen: LoadedFrontScreen?

    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    init(root: String, profile: LoadedPlatformProfile) throws {
        let url = URL(fileURLWithPath: root, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.hasPrefix("/"), !root.utf8.contains(0) else { throw LoadedSessionError.input("Resource root") }
        func read(_ relative: String, maximum: Int, hash: String? = nil, exact: Int? = nil) throws -> Data {
            guard !relative.isEmpty, !relative.hasPrefix("/"), !relative.split(separator: "/").contains(".."),
                  !relative.utf8.contains(0), !relative.contains("\\") else { throw LoadedSessionError.input("Resource path") }
            let path = url.appendingPathComponent(relative).standardizedFileURL.resolvingSymlinksInPath()
            guard path.path.hasPrefix(url.path + "/") else { throw LoadedSessionError.input("Resource escapes root") }
            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? NSNumber, size.intValue <= maximum,
                  exact == nil || size.intValue == exact else { throw LoadedSessionError.input("Resource extent: " + relative) }
            let data = try Data(contentsOf: path)
            guard data.count <= maximum, exact == nil || data.count == exact,
                  hash == nil || Self.digest(data) == hash else { throw LoadedSessionError.input("Resource bytes: " + relative) }
            return data
        }
        let manifestBytes = try read("manifest.json", maximum: 4_000_000)
        let manifest = try JSONDecoder().decode(ResourceManifest.self, from: manifestBytes)
        guard manifest.schemaVersion == 1, !manifest.runtimeContainsOriginalExecutable,
              manifest.originalEXESHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c" else {
            throw LoadedSessionError.input("Resource manifest contract")
        }
        let g = manifest.globals
        guard g.base == 0x44d000, g.count == 0xb440, g.fileBytes == 8192,
              g.zeroFillStart == 0x44f000, g.zeroFillEnd == 0x459724,
              g.dataPath == "static/globals-data.bin",
              g.sha256 == "b8eab0fcf4226195ff6ce9ed88800e220f3fa89c200718cd52c134b481406036" else { throw LoadedSessionError.input("PE recipe") }
        let data = try read(g.dataPath, maximum: 8192, hash: g.sha256, exact: 8192)
        var globals = try OriginalStateRecord(bytes: Array(data) + [UInt8](repeating: 0, count: g.count - data.count),
                                              defined: [Bool](repeating: true, count: g.count))
        try globals.write(LoadedPlatformProfile.device, at: 0x457578 - g.base)
        self.globals = globals; initialGlobals = globals
        world = try .worldPrefix(over: profile.backing(OriginalStateRecord.worldPrefixSize))
        savedPlayback = try .init(bytes: [UInt8](repeating: 0, count: 0x320), defined: [Bool](repeating: true, count: 0x320))
        replayPointers = try .init(bytes: [UInt8](repeating: 0, count: 8), defined: [Bool](repeating: true, count: 8))
        let controls = manifest.original.filter { $0.source == "data/control.txt" }
        guard controls.count == 1, let control = controls.first, control.path == "original/data/control.txt",
              control.sha256 == "cc7f84872d9b95fe64c1c95cc7895b3e2c0a52a3ae0f7f7970f0b3c56b7037c0" else {
            throw LoadedSessionError.input("Original control binding")
        }
        rawControl = Array(try read(control.path, maximum: 1_000_000, hash: control.sha256, exact: control.bytes))
        var ownedDIBs: [String: [UInt8]] = [:], ownedInputs: [String: OriginalBitmapInput] = [:], dibBytes = 0
        for key in Set(OriginalFrontMenuResources.paths) {
            let matches = manifest.embedded.filter { $0.key == key }
            guard matches.count == 1, let entry = matches.first else { throw LoadedSessionError.input("Embedded resource/language binding: " + key) }
            let bytes = Array(try read(entry.dibPath, maximum: 32_000_000, hash: entry.dibSHA256))
            dibBytes += bytes.count
            guard dibBytes <= 32_000_000 else { throw LoadedSessionError.input("Total owned DIB extent") }
            guard bytes.count >= 40 else { throw LoadedSessionError.input("DIB header") }
            let record = try OriginalStateRecord(bytes: bytes, defined: [Bool](repeating: true, count: bytes.count))
            guard try record.integer(at: 0, as: UInt32.self) >= 40,
                  try record.integer(at: 4, as: Int32.self) == entry.width,
                  try record.integer(at: 8, as: Int32.self) == entry.height,
                  entry.width > 0, entry.height > 0 else { throw LoadedSessionError.input("DIB dimensions") }
            ownedDIBs[key] = bytes
            ownedInputs[key] = .init(path: key, present: true, width: entry.width, height: entry.height)
        }
        dibs = ownedDIBs; inputs = ownedInputs; self.profile = profile; resourceRoot = url
        manifestSHA256 = Self.digest(manifestBytes)
    }

    mutating func loadFrontSettings(failBeforeCommit: Bool = false) throws {
        guard lifecycle == 2 else { throw LoadedSessionError.lifecycle }
        var candidate = self
        var frontEvents: [OriginalFrontMenuEvent] = []
        let profile = self.profile, resources = inputs
        let result = try candidate.front.load(world: candidate.world, globals: &candidate.globals,
            allocate: { index in .init(address: profile.allocation(index), backing: profile.backing(0x1f50)) },
            source: { _, path in
                guard let resource = resources[path] else { throw LoadedSessionError.input("Unowned bitmap") }
                return resource
            }, deviceResult: { index in (LoadedPlatformProfile.device + UInt32(index) * 16, 0) },
            observe: { frontEvents.append($0) })
        guard result.continuation == .settings else { throw LoadedSessionError.continuation(result.continuation.rawValue) }
        candidate.frontEvents = frontEvents; candidate.frontGlobals = candidate.globals
        var privateScratch = try OriginalStateRecord(bytes: profile.backing(0x1f4), defined: [Bool](repeating: false, count: 0x1f4))
        var translated: [UInt8] = [], index = 0
        while index < rawControl.count {
            if rawControl[index] == 13, index + 1 < rawControl.count, rawControl[index + 1] == 10 { index += 1 }
            translated.append(rawControl[index]); index += 1
        }
        var events: [SettingsExport] = []
        let continuation = try OriginalSettingsLoading.loadAndContinueStartup(globals: &candidate.globals,
            scratch: &privateScratch, translatedBytes: translated, file: LoadedPlatformProfile.file,
            scratchAddress: LoadedPlatformProfile.scratch, closeResult: 0, requireDefinedStrings: true,
            observe: { events.append(.init($0, $1, $2)) })
        guard continuation == .ready else { throw LoadedSessionError.continuation(continuation.rawValue) }
        candidate.settingsEvents = events; candidate.scratch = privateScratch
        candidate.settingsContinuation = continuation.rawValue; candidate.lifecycle = 3
        // Test-only late observer failure: even completed nested consumers have
        // not published state/effects. It is an error, never tick-success.
        if failBeforeCommit { throw LoadedSessionError.deliberateRollback }
        self = candidate
    }

    mutating func continueFrontScreen(milliseconds: UInt32, failBeforeCommit: Bool = false) throws {
        guard lifecycle == 3 else { throw LoadedSessionError.lifecycle }
        var candidate = self
        var screen = try LoadedFrontScreen(front: front, profile: profile, replayPointers: replayPointers)
        try screen.run(world: &candidate.world, globals: &candidate.globals, milliseconds: milliseconds,
                       profile: profile, root: resourceRoot, manifestSHA256: manifestSHA256)
        candidate.replayPointers = screen.memory.replayPointers
        candidate.frontScreen = screen; candidate.lifecycle = 4
        if failBeforeCommit { throw LoadedSessionError.deliberateRollback }
        self = candidate
    }

    func snapshot(revision: UInt64) throws -> Data {
        struct Bitmap: Encodable { let address: UInt32, input: OriginalBitmapInput, optional: Bool, storage: LoadedRecordExport }
        struct Export: Encodable {
            let schema: Int, lifecycle: UInt32, revision: UInt64, profile: UInt32, manifestSHA256: String
            let initialGlobals, world, globals, savedPlayback, replayPointers: LoadedRecordExport
            let frontGlobals: LoadedRecordExport?, frontEvents: [OriginalFrontMenuEvent], bitmaps: [Bitmap]
            let settingsEvents: [SettingsExport], scratch: LoadedRecordExport?, settingsContinuation: String?
            let ownedDIBCount, ownedDIBBytes, rawControlBytes: Int
            let frontScreen: LoadedFrontScreen.Export?
        }
        let value = Export(schema: 1, lifecycle: lifecycle, revision: revision, profile: profile.rawValue,
            manifestSHA256: manifestSHA256, initialGlobals: .init(initialGlobals), world: .init(world), globals: .init(globals),
            savedPlayback: .init(savedPlayback), replayPointers: .init(replayPointers), frontGlobals: frontGlobals.map(LoadedRecordExport.init),
            frontEvents: frontEvents, bitmaps: front.bitmaps.keys.sorted().map { address in
                let b = front.bitmaps[address]!
                return Bitmap(address: address, input: b.input, optional: b.optional, storage: .init(b.storage))
            }, settingsEvents: settingsEvents, scratch: scratch.map(LoadedRecordExport.init), settingsContinuation: settingsContinuation,
            ownedDIBCount: dibs.count, ownedDIBBytes: dibs.values.reduce(0) { $0 + $1.count }, rawControlBytes: rawControl.count,
            frontScreen: frontScreen?.export())
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}
