import Foundation
import NTSDCore

/// Named, controlled platform replies used by the two retained pristine parents.
/// They are inputs to Core, not implementations of macOS graphics/network APIs.
enum FrontPlatform {
    static let target = LoadedPlatformProfile.device
    static func completion() throws -> CompletionInput {
        let network: [String: Any] = [
            "startupResult": 0, "version": 257, "hostnameResult": 0,
            "hostname": Array("ntsd-reference".utf8), "hostEntryAddress": UInt32(687865888),
            "addresses": zip([33554442,67217600,84213417,16777343,124846283],
                ["10.0.0.2","192.168.1.4","169.254.4.5","127.0.0.1","203.0.113.7"]).map {
                    ["word": $0.0, "text": Array($0.1.utf8)] as [String: Any]
                },
            "socketResult": UInt32(878051329), "asyncResult": 0, "bindResult": 0, "listenResult": 0]
        let presentation: [String: Any] = ["targetSurface": target, "methodResult": 0, "queryResult": 0,
                "audioGetResult": 0, "audioSetResult": 0, "queriedAudio": target + 48,
                "audioVolume": Int32(-1234), "dcResult": 0, "dc": UInt32(0x12345678), "postResult": 0]
        let fields: [String: Any] = [
            "menu": ["targetSurface": target, "panelWord": NSNull(), "network": network],
            "presentation": presentation,
            "drawResults": [0,1]]
        // Core's public Codable inputs intentionally expose no memberwise init.
        return try JSONDecoder().decode(CompletionInput.self, from: JSONSerialization.data(withJSONObject: fields))
    }
    struct CompletionInput: Codable {
        let menu: OriginalMainMenuInput, presentation: OriginalMenuPresentationInput, drawResults: [Int32]
        private enum CodingKeys: String, CodingKey { case menu, presentation, drawResults }
        private enum MenuKeys: String, CodingKey { case targetSurface, panelWord, network }
        func encode(to encoder: Encoder) throws {
            var fields = encoder.container(keyedBy: CodingKeys.self)
            var menuFields = fields.nestedContainer(keyedBy: MenuKeys.self, forKey: .menu)
            try menuFields.encode(menu.targetSurface, forKey: .targetSurface)
            if let word = menu.panelWord { try menuFields.encode(word, forKey: .panelWord) }
            else { try menuFields.encodeNil(forKey: .panelWord) }
            try menuFields.encode(menu.network, forKey: .network)
            try fields.encode(presentation, forKey: .presentation)
            try fields.encode(drawResults, forKey: .drawResults)
        }
    }
}

/// Reads only the requested original resource; a successful request owns its bytes.
/// The unchanged manifest digest binds lookup to the owner's create-time catalog.
private struct FrontDIBProvider {
    let root: URL, manifestSHA256: String
    private(set) var bytes: [String: Data] = [:]
    private(set) var inputs: [String: OriginalBitmapInput] = [:]
    func read(_ relative: String, maximum: Int, hash: String) throws -> Data {
        guard !relative.isEmpty, !relative.hasPrefix("/"), !relative.contains("\\"),
              !relative.utf8.contains(0), !relative.split(separator: "/").contains("..") else {
            throw LoadedSessionError.input("Front resource path")
        }
        let url = root.appendingPathComponent(relative).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.hasPrefix(root.path + "/") else { throw LoadedSessionError.input("Front resource escapes root") }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.intValue <= maximum else {
            throw LoadedSessionError.input("Front resource extent")
        }
        let data = try Data(contentsOf: url)
        guard data.count <= maximum, LoadedSession.digest(data) == hash else { throw LoadedSessionError.input("Front resource bytes") }
        return data
    }
    mutating func resource(_ key: String) throws -> OriginalBitmapInput {
        guard (1...13).contains(where: { key == "MENU_BACK\($0)" }) else { throw LoadedSessionError.input("Front embedded key") }
        if let input = inputs[key] { return input }
        let data = try read("manifest.json", maximum: 4_000_000, hash: manifestSHA256)
        let manifest = try JSONDecoder().decode(ResourceManifest.self, from: data)
        let matches = manifest.embedded.filter { $0.key == key }
        guard matches.count == 1, let entry = matches.first else { throw LoadedSessionError.input("Front embedded language binding") }
        let dib = try read(entry.dibPath, maximum: 32_000_000, hash: entry.dibSHA256)
        guard dib.count >= 40, bytes.values.reduce(dib.count, { $0 + $1.count }) <= 32_000_000 else {
            throw LoadedSessionError.input("Front owned DIB extent")
        }
        let record = try OriginalStateRecord(bytes: Array(dib), defined: [Bool](repeating: true, count: dib.count))
        guard try record.integer(at: 0, as: UInt32.self) >= 40,
              try record.integer(at: 4, as: Int32.self) == entry.width,
              try record.integer(at: 8, as: Int32.self) == entry.height,
              entry.width > 0, entry.height > 0 else { throw LoadedSessionError.input("Front DIB dimensions") }
        let input = OriginalBitmapInput(path: key, present: true, width: entry.width, height: entry.height)
        bytes[key] = dib; inputs[key] = input
        return input
    }
}

/// Own local storage plus an event-time read-provenance audit. No source stack
/// backing/cookie/register is imported, and zero/unknown is never a read default.
private final class FrontBodyAudit {
    var record: OriginalStateRecord
    private var writes = 0, texts = 0
    private let offsets = [0x48,0x84,0x64]
    init(target: UInt32) throws {
        record = try .init(bytes: [UInt8](repeating: 0, count: 0xc0), defined: [Bool](repeating: false, count: 0xc0))
        try record.write(target, at: 0x20)
    }
    func string(_ offset: Int) throws -> [UInt8] {
        var result: [UInt8] = []
        for i in offset..<record.bytes.count {
            let byte = try record.integer(at: i, as: UInt8.self)
            if byte == 0 { return result }; result.append(byte)
        }
        throw OriginalStateError.invalidStorage("Front private string extent")
    }
    func observe(_ event: OriginalFrontScreenEvent) throws {
        if event.kind == "writeLocal" {
            guard event.arguments.count == 3 else { throw LoadedSessionError.input("Body local write") }
            let offset = Int(event.arguments[0]), count = Int(event.arguments[1]), value = event.arguments[2]
            guard [1,2,4].contains(count), offset >= 0, offset + count <= 0xc0 else { throw LoadedSessionError.input("Body write bounds") }
            // 24 literal-copy stores plus the y DWORD precede every raw decode
            // read in this pristine path. Each subsequent store reads known text.
            if writes >= 25 {
                for start in offsets { _ = try string(start) }
                for i in offset..<offset+count { _ = try record.integer(at: i, as: UInt8.self) }
            }
            for i in 0..<count { try record.write(UInt8(truncatingIfNeeded: value >> (i*8)), at: offset+i) }
            writes += 1
        } else if event.kind == "text" {
            guard texts < offsets.count, event.strings.count == 1,
                  event.strings[0] == (try string(offsets[texts])) else {
                throw LoadedSessionError.continuation("Body text outside natural owned path")
            }
            texts += 1
        } else if event.kind == "draw" {
            guard event.arguments.count == 7,
                  event.arguments[6] == (try record.integer(at: 0x20, as: UInt32.self)) else {
                throw OriginalStateError.undefinedBytes(offset: 0x20, count: 4)
            }
        } else if ["shell","sleep","soundRequest","soundMethod"].contains(event.kind) {
            throw LoadedSessionError.continuation("Body external action outside natural path")
        }
    }
    func finish(_ local: OriginalStateRecord) throws {
        guard texts == 3, record == local else { throw LoadedSessionError.input("Body local producer disagreement") }
    }
}

struct LoadedFrontScreen {
    struct Asset: Encodable {
        let address: UInt32, generation: UInt32, resourceKey: String, rawSurface: UInt32
        let input: OriginalBitmapInput
    }
    struct Record: Encodable { let address: UInt32, live: Bool, storage: LoadedRecordExport }
    struct DrawOwner: Encodable {
        let eventIndex: Int, address: UInt32, generation: UInt32, resourceKey: String
        let rawSource: UInt32, rawTarget: UInt32
        let targetRole = "backbuffer"
    }
    struct Phase: Encodable {
        let name: String, continuation: String, events: [OriginalFrontScreenEvent], drawOwners: [DrawOwner]
        let world: LoadedRecordExport, globals: LoadedRecordExport, records: [Record], replayPointers: LoadedRecordExport
        let crtState: UInt32, local: LoadedRecordExport?, retainedOperation: String?
    }
    struct Inputs: Encodable {
        let prefix: OriginalFrontScreenInput, body: OriginalFrontScreenBodyInput
        let alternate: OriginalFrontScreenAlternateInput, completion: FrontPlatform.CompletionInput
    }
    struct Export: Encodable {
        let phases: [Phase], assets: [Asset], records: [Record], crtState: UInt32
        let local: LoadedRecordExport, retainedOperation: String?, replayPointers: LoadedRecordExport
        let ownedDIBCount: Int, ownedDIBBytes: Int, ownedDIBSHA256: [String: String], inputs: Inputs
    }
    private(set) var memory: OriginalMenuPresentationMemory
    private var assets: [UInt32: Asset] = [:]
    private var prefix = OriginalFrontScreenPrelude()
    private var crt = OriginalCRTRandom()
    private var local: OriginalStateRecord?
    private var phases: [Phase] = []
    private var provider: FrontDIBProvider?
    private var inputs: Inputs?

    init(front: OriginalFrontMenuResources, profile: LoadedPlatformProfile, replayPointers: OriginalStateRecord) throws {
        memory = .init(replayPointers: replayPointers)
        guard front.bitmaps.count == OriginalFrontMenuResources.paths.count else { throw LoadedSessionError.input("Front owner inventory") }
        for (index, key) in OriginalFrontMenuResources.paths.enumerated() {
            let address = profile.allocation(index), surface = LoadedPlatformProfile.device + UInt32(index)*16
            guard let bitmap = front.bitmaps[address], bitmap.input.path == key else { throw LoadedSessionError.input("Front owner binding") }
            var raw = bitmap.storage; try raw.write(surface, at: 0)
            memory.allocations[address] = .init(storage: raw)
            assets[address] = .init(address: address, generation: 1, resourceKey: key, rawSurface: surface, input: bitmap.input)
        }
    }

    private func records() -> [Record] {
        memory.allocations.keys.sorted().map { address in
            let value = memory.allocations[address]!
            return .init(address: address, live: value.live, storage: .init(value.storage))
        }
    }
    private mutating func checkpoint(_ name: String, _ continuation: String, _ world: OriginalStateRecord,
                                    _ globals: OriginalStateRecord, _ recorder: FrontEvents) {
        phases.append(.init(name: name, continuation: continuation, events: recorder.events, drawOwners: recorder.owners,
            world: .init(world), globals: .init(globals), records: records(), replayPointers: .init(memory.replayPointers),
            crtState: crt.state, local: local.map(LoadedRecordExport.init), retainedOperation: prefix.retainedOperation == .sleep ? "sleep" : nil))
    }

    mutating func run(world: inout OriginalStateRecord, globals: inout OriginalStateRecord, milliseconds: UInt32,
                      profile: LoadedPlatformProfile, root: URL, manifestSHA256: String) throws {
        let base = OriginalMatchPreparation.globalBase, target = FrontPlatform.target
        for address in [0x455608,0x44eecc,0x453e0c,0x455634] { try globals.write(target, at: address-base) }
        try globals.write(UInt32(profile == .ascendingA5 ? 1 : 3), at: 0x458348-base)
        var source = FrontDIBProvider(root: root, manifestSHA256: manifestSHA256)
        let prefixInput = OriginalFrontScreenInput(drawTarget: target, milliseconds: milliseconds,
            threadHandle: 0x12345678, threadID: 0xabcd, lastError: 5, fillResult: 0, drawResults: [0])
        let bodyInput = OriginalFrontScreenBodyInput(dcResult: 0, dc: 0x12345678, methodResult: 0, drawResults: [0], shellResult: 33)
        let completionInput = try FrontPlatform.completion()
        let pre = FrontEvents(assets: assets), nextAddress = profile.allocation(memory.allocations.count)
        let end = try prefix.advance(globals: &globals, input: prefixInput, fillBacking: [UInt8](repeating: 0, count: 100),
            allocate: { .init(address: nextAddress, backing: profile.backing(0x1f50)) }, source: { key in
                let input = try source.resource(key), surface: UInt32 = 0x28006400
                pre.assets[nextAddress] = .init(address: nextAddress, generation: 1, resourceKey: key, rawSurface: surface, input: input)
                return (input,surface,0)
            }, observe: pre.observe)
        guard end == .critical else { throw LoadedSessionError.continuation(end.rawValue) }
        for (address, bitmap) in prefix.bitmaps {
            guard memory.allocations[address] == nil, let asset = pre.assets[address] else { throw LoadedSessionError.input("Background owner collision") }
            var raw = bitmap.storage; try raw.write(asset.rawSurface, at: 0)
            memory.allocations[address] = .init(storage: raw); assets[address] = asset
        }
        provider = source
        checkpoint("prefix", end.rawValue, world, globals, pre)

        let panel = FrontEvents(assets: assets)
        let update = try OriginalMenuPanelUpdate.run(globals: &globals,
            content: { _ in throw LoadedSessionError.continuation("Panel content request") },
            bitmap: { _ in throw LoadedSessionError.continuation("Panel bitmap request") },
            write: { _,_ in throw LoadedSessionError.continuation("Panel settings write") },
            observe: { event,_ in try panel.observe(.init(event.kind,event.arguments)) })
        guard update == .ready else { throw LoadedSessionError.continuation("Panel boundary") }
        checkpoint("panel", "ready", world, globals, panel)

        let body = FrontEvents(assets: assets), audit = try FrontBodyAudit(target: target)
        var privateLocal = audit.record
        let width = try globals.integer(at: 0x44d78c-base, as: Int32.self), height = try globals.integer(at: 0x44d790-base, as: Int32.self)
        let drawRecords = memory.allocations // Immutable read view; no release/allocation in this bounded body/completion.
        var bodyBlits = 0
        let bodyEnd = try OriginalFrontScreenBody.advance(globals: &globals, local: &privateLocal, input: bodyInput,
            draw: { args in try body.draw(args, records: drawRecords, width: width, height: height, results: bodyInput.drawResults, blits: &bodyBlits) },
            observe: { try audit.observe($0); try body.observe($0) })
        guard bodyEnd == .alternateDispatch else { throw LoadedSessionError.continuation(bodyEnd.rawValue) }
        let selector = try globals.integer(at: 0x44d064-base, as: Int32.self)
        try audit.finish(privateLocal); local = privateLocal
        checkpoint("body", bodyEnd.rawValue, world, globals, body)

        let alternateInput = OriginalFrontScreenAlternateInput(selector: selector, drawTarget: target, timers: [100,100,100],
            methodResult: 0, drawResults: [0], fillResult: 0, threadHandle: 0x12345678, threadID: 0xabcd, lastError: 5)
        let alt = FrontEvents(assets: assets)
        let alternateEnd = try OriginalFrontScreenAlternate.advance(globals: &globals, input: alternateInput,
            draw: { _ in throw LoadedSessionError.continuation("Alternate draw") },
            fill: { _ in throw LoadedSessionError.continuation("Alternate fill") },
            writeSettings: { _ in throw LoadedSessionError.continuation("Alternate settings write") }, observe: alt.observe)
        guard alternateEnd == .mainMenu else { throw LoadedSessionError.continuation(alternateEnd.rawValue) }
        checkpoint("alternate", alternateEnd.rawValue, world, globals, alt)

        let tail = FrontEvents(assets: assets)
        var completionBlits = 0
        func draw(_ args: [UInt32]) throws {
            try tail.observe(.init("draw",args))
            try tail.draw(args, records: drawRecords, width: width, height: height, results: completionInput.drawResults, blits: &completionBlits)
        }
        let mainEnd = try OriginalMainMenu.run(world: &world, globals: &globals, crt: &crt, input: completionInput.menu, observe: { event in
            if event.kind == .bitmap { try draw(event.arguments) }
            else {
                guard event.kind == .panel else { throw LoadedSessionError.continuation("Main platform action: " + event.kind.rawValue) }
                try tail.observe(.init(event.kind.rawValue,event.arguments,event.strings))
            }
        })
        checkpoint("main", mainEnd.rawValue, world, globals, tail)
        try OriginalMenuPresentation.apply(mainEnd == .present ? .tail : .epilogue, input: completionInput.presentation,
            world: &world, globals: &globals, memory: &memory, observe: { event in
                guard event.kind != .free else { throw LoadedSessionError.continuation("Front release outside first return") }
                if event.kind == .bitmap { try draw(event.arguments) }
                else { try tail.observe(.init(event.kind.rawValue,event.arguments,event.strings)) }
            })
        checkpoint("completion", "returned", world, globals, tail)
        inputs = .init(prefix: prefixInput, body: bodyInput, alternate: alternateInput, completion: completionInput)
    }

    func export() -> Export {
        .init(phases: phases, assets: assets.keys.sorted().map { assets[$0]! }, records: records(), crtState: crt.state,
            local: .init(local!), retainedOperation: prefix.retainedOperation == .sleep ? "sleep" : nil,
            replayPointers: .init(memory.replayPointers), ownedDIBCount: provider!.bytes.count,
            ownedDIBBytes: provider!.bytes.values.reduce(0) { $0 + $1.count },
            ownedDIBSHA256: provider!.bytes.mapValues(LoadedSession.digest), inputs: inputs!)
    }
}

private final class FrontEvents {
    var assets: [UInt32: LoadedFrontScreen.Asset]
    var events: [OriginalFrontScreenEvent] = [], owners: [LoadedFrontScreen.DrawOwner] = []
    init(assets: [UInt32: LoadedFrontScreen.Asset]) { self.assets = assets }
    func observe(_ event: OriginalFrontScreenEvent) throws {
        if event.kind == "draw" {
            guard event.arguments.count == 7, let asset = assets[event.arguments[0]] else { throw LoadedSessionError.input("Draw owner") }
            owners.append(.init(eventIndex: events.count, address: asset.address, generation: asset.generation,
                resourceKey: asset.resourceKey, rawSource: asset.rawSurface, rawTarget: event.arguments[6]))
        }
        events.append(event)
    }
    func draw(_ args: [UInt32], records: [UInt32: OriginalMenuPresentationMemory.Allocation], width: Int32, height: Int32,
              results: [Int32], blits: inout Int) throws {
        guard args.count == 7, !results.isEmpty, let record = records[args[0]], record.live else { throw LoadedSessionError.input("Unowned bitmap draw") }
        let input = OriginalBitmapDrawInput(x: Int32(bitPattern: args[1]), y: Int32(bitPattern: args[2]), frame: Int32(bitPattern: args[3]),
            colorKey: args[4], mirrored: args[5], sourceSurface: try record.storage.integer(at: 0, as: UInt32.self), targetSurface: args[6],
            viewportWidth: width, viewportHeight: height)
        var canonical = record.storage; try canonical.write(UInt32(input.sourceSurface == 0 ? 0 : 1), at: 0)
        _ = try OriginalBitmapDrawing.draw(input, bitmap: canonical, observeRead: { r in
            var e = OriginalFrontScreenEvent("read"); e.read = r; try self.observe(e)
        }, observeClip: { c in
            var e = OriginalFrontScreenEvent("clip"); e.clip = c; try self.observe(e)
        }, perform: { b in
            var e = OriginalFrontScreenEvent("blit"); e.blit = b; try self.observe(e)
            defer { blits += 1 }; return results[blits % results.count]
        })
    }
}
