import Foundation
import CryptoKit
import Compression
import NTSDCore

/// Test-only reader. Saved records/masks are comparison operands; only original
/// asset bytes and separately declared numeric controls leave this reference.
/// The complete original JSON and external files remain available unchanged.
final class OriginalApplicationCatalogSessionReference {
    typealias API = OriginalBitmapSurfaceLoading
    enum Boundary: Error { case invalid(String) }

    struct Pin: Decodable, Equatable { let bytes: Int, sha256: String }
    struct Blob: Decodable { let count: Int, deflate: String, sha256: String? }
    struct Record: Decodable, Equatable {
        let address: UInt32, live: Bool, bytes: String, mask: String
    }
    struct RecordSet: Decodable {
        let inline: [Record]?, snapshot: Int?
        private enum CodingKeys: String, CodingKey { case encoding, snapshot }
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let records = try? value.decode([Record].self) {
                inline = records; snapshot = nil; return
            }
            let c = try decoder.container(keyedBy: CodingKeys.self)
            guard try c.decode(String.self, forKey: .encoding) == "addressed-record-table-delta-v1" else {
                throw Boundary.invalid("Record-set encoding")
            }
            inline = nil; snapshot = try c.decode(Int.self, forKey: .snapshot)
        }
    }
    struct State: Decodable {
        let pc: UInt32, sp: UInt32, eax: UInt32, cw: UInt32, retainedDC: UInt32, random: UInt32
        let globals: String, mask: String, stack: String, knownStack: String
        let local: String, localMask: String, library: String, message: String, messageMask: String
        let seh: UInt32, registers: [UInt32], baseline: UInt32, counter: UInt32, storeCount: Int
        let records: RecordSet
    }
    struct Allocation: Decodable { let address: UInt32, count: Int, initial: String, caller: UInt32 }
    struct Entry: Decodable { let sp: UInt32, returnPC: UInt32, arguments: [UInt32], fileName: String, saved: [UInt32] }
    struct Event: Decodable {
        let globals: String, pc: UInt32?, storeCount: Int
        let kind: String?, key: String?, arguments: [UInt32]?, event: OriginalFrontScreenEvent?
        let request: API.Request?, response: API.Response?, returnPC: UInt32?
        let path: String?, mode: String?, bytes: String?, result: Int32?
        /// No captured structure writes can become a platform input.
        var replyControl: API.Response? {
            response.map { .init(result: $0.result, output: $0.output) }
        }
    }
    struct File: Decodable {
        let address: UInt32, buffer: UInt32, path: String, mode: String
        let raw: String, logical: String, read: Int, closed: Bool, initial: String?
    }
    struct Child: Decodable {
        let kind: String?, address: UInt32?, arguments: [UInt32], saved: [UInt32]
        let sp: UInt32, returnPC: UInt32, returnSP: UInt32
        let eventStart: Int, eventEnd: Int, storeStart: Int?, storeEnd: Int?
        let after: State
    }
    struct Progress: Decodable {
        let sp: UInt32, returnPC: UInt32, returnSP: UInt32, result: UInt32
        let saved: [UInt32], arguments: [UInt32], eventStart: Int, eventEnd: Int
        let before: State, after: State
    }
    struct DecoderResult: Decodable {
        let sp: UInt32, returnPC: UInt32, returnSP: UInt32, result: UInt32
        let saved: [UInt32], path: String, eventStart: Int, eventEnd: Int, storeStart: Int, storeEnd: Int
    }
    struct Helper: Decodable {
        let entry: UInt32, kind: String?, sp: UInt32, returnPC: UInt32, returnSP: UInt32, result: UInt32
        let saved: [UInt32], pop: Int, firstStore: Int, lastStore: Int, eventStart: Int, eventEnd: Int
    }
    struct WaveRecord: Decodable { let bytes: String, defined: String, initial: String? }
    struct Wave: Decodable {
        let label: String, path: [UInt8], file: String, input: OriginalWavePlatform
        let outputBefore: UInt32, outputAfter: UInt32, beforeGlobals: String, afterGlobals: String
        let temporary: WaveRecord?, first: WaveRecord?, second: WaveRecord?, format: WaveRecord?, descriptor: WaveRecord?
        let temporaryLive: Bool, exit: OriginalWaveExit, returned: UInt32?, events: [OriginalWaveEvent]
        let registryIndex: Int?
    }
    struct Asset: Decodable {
        let path: String, kind: String, raw: String, width: Int, height: Int, planes: Int, bpp: Int
    }
    struct Binding: Decodable { let address: UInt32, before: UInt32, after: UInt32 }
    struct Ignored: Decodable { init(from decoder: Decoder) throws {} }
    struct Case: Decodable {
        let parent: String, parentIndex: Int, end: String, before: State, after: State, entry: Entry
        let events: [Event], catalog: Allocation, catalogBytes: String, catalogMask: String
        let objects: [Allocation], bitmaps: [Allocation], frameAllocations: [Allocation]
        let objectReturns: [Child], catalogChildReturns: [Child], progressReturns: [Progress]
        let files: [File], decoders: [DecoderResult], registeredWaves: [Wave], bindings: [Binding]
        let helpers: [Helper], outputHelpers: [Helper], virtualFiles: [String: String]
        let dependency: Ignored?, pendingObject: Ignored?, pendingCatalogChild: Ignored?, pendingDecoder: Ignored?, pendingOutput: Ignored?
        let pendingHelpers: [Ignored], pendingOutputHelpers: [Ignored]
        let recordTables: PartManifest, globalStores: PartManifest
    }
    typealias Prefix = OriginalApplicationLoadingPrefixTests.Case
    struct Parents: Decodable {
        struct Window: Decodable {
            struct Bridge: Decodable {
                struct Parent: Decodable {
                    struct Input: Decodable { let loads: [Wave] }
                    let input: Input
                }
                let parent: Parent
            }
            let parents: Bridge
        }
        let startupLoads: [Wave]
        init(from decoder: Decoder) throws {
            var values = try decoder.unkeyedContainer()
            _ = try values.decode(String.self)
            startupLoads = try values.decode(Window.self).parents.parent.input.loads
            while !values.isAtEnd { _ = try values.decode(Ignored.self) }
        }
    }
    struct Corpus: Decodable {
        let exeSHA256: String, crtSHA256: String, libSHA256: String
        let c: Case, prefix: Prefix, parents: Parents, blobs: [String: Blob], assets: [String: Asset]
        enum CodingKeys: String, CodingKey { case exeSHA256, crtSHA256, libSHA256, c = "case", prefix, parents, blobs, assets }
    }
    struct PartManifest: Decodable {
        struct Part: Decodable {
            let path: String, first: Int, count: Int, rawBytes: Int, rawSHA256: String, packedBytes: Int, packedSHA256: String
        }
        let encoding: String, directory: String, count: Int, parts: [Part]
    }
    struct GlobalStore: Decodable {
        let pc: UInt32, address: UInt32, bytes: String, eventIndex: Int
        let decodedBytes: [UInt8], size: Int, value: UInt64
        private enum CodingKeys: String, CodingKey { case pc, address, bytes, eventIndex }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            pc = try c.decode(UInt32.self, forKey: .pc); address = try c.decode(UInt32.self, forKey: .address)
            bytes = try c.decode(String.self, forKey: .bytes); eventIndex = try c.decode(Int.self, forKey: .eventIndex)
            decodedBytes = try OriginalApplicationCatalogSessionReference.hex(bytes)
            guard [1, 4].contains(decodedBytes.count) else { throw Boundary.invalid("Saved CPU global store size") }
            size = decodedBytes.count
            value = decodedBytes.enumerated().reduce(UInt64(0)) { $0 | UInt64($1.element) << (8 * $1.offset) }
        }
    }

    final class RecordTables {
        struct Row: Decodable { let index: Int, previous: Int?, count: Int, updates: [Record] }
        private var history: [UInt32: [(Int, Record)]] = [:], order: [UInt32] = [], counts: [Int] = []
        private(set) var revisions = 0, parts = 0
        var snapshots: Int { counts.count }
        init(_ manifest: PartManifest, files: [String: Data]) throws {
            let rows: [[Row]] = try OriginalApplicationCatalogSessionReference.partRows(manifest, files: files)
            for part in rows {
                for row in part {
                    guard row.index == counts.count, row.previous == (counts.isEmpty ? nil : counts.count - 1),
                          Set(row.updates.map(\.address)).count == row.updates.count else { throw Boundary.invalid("Record-table chain") }
                    for record in row.updates {
                        if history[record.address] == nil { order.append(record.address) }
                        history[record.address, default: []].append((row.index, record)); revisions += 1
                    }
                    guard row.count == history.count else { throw Boundary.invalid("Record-table inventory") }
                    counts.append(row.count)
                }
                parts += 1
            }
            guard counts.count == manifest.count else { throw Boundary.invalid("Record-table snapshot count") }
        }
        func record(_ address: UInt32, in set: RecordSet) throws -> Record? {
            if let records = set.inline { return records.first { $0.address == address } }
            guard let snapshot = set.snapshot, counts.indices.contains(snapshot) else { throw Boundary.invalid("Record snapshot") }
            guard let rows = history[address] else { return nil }
            var low = 0, high = rows.count
            while low < high {
                let middle = low + (high - low) / 2
                if rows[middle].0 <= snapshot { low = middle + 1 } else { high = middle }
            }
            return low == 0 ? nil : rows[low - 1].1
        }
        func records(in set: RecordSet) throws -> [Record] {
            if let records = set.inline { return records }
            guard let snapshot = set.snapshot, counts.indices.contains(snapshot) else { throw Boundary.invalid("Record snapshot") }
            return try order.prefix(counts[snapshot]).map {
                guard let r = try record($0, in: set) else { throw Boundary.invalid("Missing historical record") }; return r
            }
        }
    }

    struct FileInput: Decodable { let gamePath: String, baselinePath: String, bytes: Int, sha256: String, logical: Pin? }
    struct ImageResource: Decodable, Equatable {
        let name: String, kind: String, input: String, dibSHA256: String, rgb: String, mask: String
        let width: Int, height: Int, bits: Int, compression: Int, colorsUsed: Int, pixelOffset: Int, writtenPixels: Int, unknownPixels: Int
    }
    struct ImageInput: Decodable {
        struct Origin: Decodable { let name: String, kind: String, raw: Pin, width: Int, height: Int, planes: Int, bpp: Int }
        let gameName: String, origin: Origin, acceptedResource: ImageResource
    }
    struct PacketPin: Decodable {
        struct Part: Decodable {
            let relativePath: String, sourcePath: String, bytes: Int, sha256: String
            let rawBytes: Int, rawSHA256: String, first: Int, count: Int
        }
        let caseID: String, parentIndex: Int, sourcePath: String, fixtureName: String
        let rawBytes: Int, rawSHA256: String, packedBytes: Int, packedSHA256: String, sourcePin: Pin
        let recordParts: [Part], globalStoreParts: [Part]
    }
    struct Index: Decodable {
        struct Inputs: Decodable { let files: [FileInput], waves: [FileInput], catalogImages: [ImageInput] }
        let schema: Int, compression: String, packets: [PacketPin], inputs: Inputs
    }
    struct EncodedFile: Decodable { let path: String, bytes: Int, sha256: String, base64: String }
    struct Packet: Decodable {
        let schema: Int, caseID: String, parentIndex: Int, source: EncodedFile
        let recordTables: [EncodedFile], globalStores: [EncodedFile]
    }
    private struct AcceptedImages: Decodable { let resources: [ImageResource], blobs: [String: Blob] }

    static let index: Result<Index, Error> = Result {
        let packed = try bundled("original-application-catalog-session.json.zlib")
        try verify(packed, .init(bytes: 33_079, sha256: "7daa37e67afe67f0512d1fa5f773057de21ddcab4dc59807a9163b790c4e288f"))
        let raw = try inflate(packed, count: 153_736, maximum: 1_000_000)
        try verify(raw, .init(bytes: 153_736, sha256: "eb0980f5cece0057e23cb6c6ac8d9aee32e0544315ad00c5a25e97bb16666866"))
        let index = try JSONDecoder().decode(Index.self, from: raw)
        guard index.schema == 1, index.compression == "raw-deflate", index.packets.count == 3,
              Set(index.packets.map(\.parentIndex)) == Set(0..<3), index.inputs.files.count == 21,
              index.inputs.waves.count == 84, index.inputs.catalogImages.count == 139 else { throw Boundary.invalid("Catalog transport index") }
        return index
    }
    private static let acceptedImages: Result<AcceptedImages, Error> = Result {
        let packed = try bundled("original-catalog-dib-pixels.json.zlib")
        try verify(packed, .init(bytes: 48_082_802, sha256: "05c80127a13d8991ae9ca62a785bc416527ff8de52fc3e3630ab0f46ba174eb1"))
        let raw = try inflate(packed, count: 66_335_316, maximum: 100_000_000)
        try verify(raw, .init(bytes: 66_335_316, sha256: "35c483a8fdf469670ac2ecfd758d088b8e526fcc4b95fc912f8bf099f718ae0d"))
        return try JSONDecoder().decode(AcceptedImages.self, from: raw)
    }

    let corpus: Corpus, rawCaseData: Data, originalParts: [String: Data], tables: RecordTables, globalStores: [GlobalStore]
    var c: Case { corpus.c }
    var prefix: Prefix { corpus.prefix }
    var blobs: [String: Blob] { corpus.blobs }
    private var cache: [String: [UInt8]] = [:]
    private(set) var fileInputs: [String: [UInt8]] = [:]
    private(set) var bitmapResources: [String: OriginalApplicationStartupInputs.Bitmap] = [:]
    let bitmapControls: [API.Response], allocationTokens: [UInt32], clocks: [UInt32], volumeControls: [Int32]
    let fileAllocations: [OriginalLoadingFileAllocation], waveInputs: [OriginalWavePlatform], startupWaveInputs: [OriginalWavePlatform]

    init(parentIndex: Int) throws {
        let index = try Self.index.get()
        guard let pin = index.packets.first(where: { $0.parentIndex == parentIndex }) else { throw Boundary.invalid("Parent ordinal") }
        guard pin.packedBytes < 100_000_000, pin.rawBytes < 250_000_000 else { throw Boundary.invalid("Packet limits") }
        let packed = try Self.bundled(pin.fixtureName)
        try Self.verify(packed, .init(bytes: pin.packedBytes, sha256: pin.packedSHA256))
        let raw = try Self.inflate(packed, count: pin.rawBytes, maximum: 250_000_000)
        try Self.verify(raw, .init(bytes: pin.rawBytes, sha256: pin.rawSHA256))
        let packet = try JSONDecoder().decode(Packet.self, from: raw)
        guard packet.schema == 1, packet.caseID == pin.caseID, packet.parentIndex == parentIndex,
              packet.source.path == pin.sourcePath, packet.recordTables.count == 6, packet.globalStores.count == 2 else {
            throw Boundary.invalid("Packet identity or composition")
        }
        rawCaseData = try Self.decodedFile(packet.source, expected: pin.sourcePin)
        corpus = try JSONDecoder().decode(Corpus.self, from: rawCaseData)
        guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              corpus.crtSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              corpus.libSHA256 == "28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba",
              corpus.c.parentIndex == parentIndex, corpus.c.end == "continuingCheckpoint",
              corpus.c.objectReturns.count == 20, corpus.c.catalogChildReturns.isEmpty else { throw Boundary.invalid("Source case boundary") }
        var files: [String: Data] = [:]
        for (actual, expected) in zip(packet.recordTables + packet.globalStores, pin.recordParts + pin.globalStoreParts) {
            guard actual.path == expected.relativePath, files[actual.path] == nil else { throw Boundary.invalid("Original part identity") }
            files[actual.path] = try Self.decodedFile(actual, expected: .init(bytes: expected.bytes, sha256: expected.sha256))
        }
        guard files.count == 8, pin.recordParts.count == 6, pin.globalStoreParts.count == 2 else { throw Boundary.invalid("Original parts") }
        originalParts = files
        tables = try RecordTables(corpus.c.recordTables, files: files)
        let journalParts: [[GlobalStore]] = try Self.partRows(corpus.c.globalStores, files: files)
        globalStores = journalParts.flatMap { $0 }
        guard tables.parts == 6, tables.snapshots == 1_006, tables.revisions == 7_339, globalStores.count == 9_698 else {
            throw Boundary.invalid("Saved table or journal counts")
        }
        for (i, row) in globalStores.enumerated() {
            guard row.address >= 0x44d000, UInt64(row.address) + UInt64(row.size) <= 0x44d000 + 0xc3a8,
                  (0...corpus.c.events.count).contains(row.eventIndex), i == 0 || globalStores[i - 1].eventIndex <= row.eventIndex else {
                throw Boundary.invalid("CPU global journal extent/order")
            }
        }
        let api = corpus.c.events.filter { $0.request != nil }
        guard api.count == 2_918, api.allSatisfy({ $0.response != nil }) else { throw Boundary.invalid("Bitmap reply inventory") }
        bitmapControls = api.map { $0.replyControl! }
        volumeControls = try corpus.c.events.filter { $0.kind == "registeredVolume" }.map {
            guard let result = $0.result else { throw Boundary.invalid("Missing registered-volume reply") }; return result
        }
        guard volumeControls.count == 94 else { throw Boundary.invalid("Registered-volume reply count") }
        let allocationKinds: Set<String> = ["allocateCatalog", "allocateObject", "allocateBitmap", "allocateFrame"]
        allocationTokens = try corpus.c.events.filter { allocationKinds.contains($0.kind ?? "") }.map {
            guard let words = $0.arguments, words.count == 2 else { throw Boundary.invalid("Allocation token event") }; return words[1]
        }
        guard allocationTokens.count == 5_210 else { throw Boundary.invalid("Allocation token count") }
        clocks = try corpus.c.events.filter { $0.kind == "time" }.map {
            guard let words = $0.arguments, words.count == 1 else { throw Boundary.invalid("Clock event") }; return words[0]
        }
        guard clocks.count == 3_178, clocks.enumerated().allSatisfy({ $0.element == 123_457_000 + UInt32($0.offset) * 20 }) else {
            throw Boundary.invalid("Declared catalog clock profile")
        }
        // Declared CRT adapter controls: 64 KiB buffering, 4 KiB translated reads;
        // close-control-provenance1 proves the inherited CRT.ret(value: 0) default.
        fileAllocations = corpus.c.files.map { .init(token: $0.address, buffer: $0.buffer, descriptor: .max, capacity: 65_536, readLimit: 4_096, closeResult: 0) }
        waveInputs = corpus.c.registeredWaves.map(\.input)
        startupWaveInputs = corpus.parents.startupLoads.map(\.input)
        guard fileAllocations.count == 81, waveInputs.count == 94, startupWaveInputs.count == 5,
              corpus.parents.startupLoads.map({ String(bytes: $0.path, encoding: .ascii) }) == ["data\\m_join.wav", "data\\m_ok.wav", "data\\m_cancel.wav", "data\\m_pass.wav", "data\\m_end.wav"] else {
            throw Boundary.invalid("File/WAV control inventory")
        }
        for (key, value) in corpus.blobs { guard value.sha256 == nil || value.sha256 == key else { throw Boundary.invalid("Blob identity") } }
        for input in index.inputs.files + index.inputs.waves {
            let bytes = try blob(input.sha256)
            guard bytes.count == input.bytes, fileInputs[input.gamePath] == nil else { throw Boundary.invalid("Original file input") }
            fileInputs[input.gamePath] = bytes
        }
        guard fileInputs.count == 105 else { throw Boundary.invalid("Original file map names") }
        let accepted = try Self.acceptedImages.get()
        guard accepted.resources.count == 669, Set(accepted.resources.map(\.name)).count == 669 else { throw Boundary.invalid("Accepted image inventory") }
        let byName = Dictionary(uniqueKeysWithValues: accepted.resources.map { ($0.name, $0) })
        for input in index.inputs.catalogImages {
            let r = input.acceptedResource
            guard byName[input.gameName] == r, input.origin.raw.sha256 == r.input,
                  let encoded = accepted.blobs[r.input], let sourceAsset = corpus.assets[input.gameName], sourceAsset.raw == r.input else {
                throw Boundary.invalid("Catalog image input provenance")
            }
            let bytes = try Self.decodedBlob(encoded, key: r.input)
            guard bytes.count == input.origin.raw.bytes, bytes == (try blob(r.input)) else { throw Boundary.invalid("Catalog image source bytes") }
            let bitmap: OriginalApplicationStartupInputs.Bitmap
            if r.kind == "bmp" { bitmap = try .init(bitmapFile: bytes) }
            else if r.kind == "dib" { bitmap = try .init(dib: bytes) }
            else { throw Boundary.invalid("Catalog image source kind") }
            bitmapResources[input.gameName] = bitmap
        }
        guard bitmapResources.count == 139 else { throw Boundary.invalid("Catalog image map") }
    }

    func blob(_ key: String) throws -> [UInt8] {
        if let bytes = cache[key] { return bytes }
        guard let value = corpus.blobs[key] else { throw Boundary.invalid("Missing blob " + key) }
        let bytes = try Self.decodedBlob(value, key: key); cache[key] = bytes; return bytes
    }
    func record(_ address: UInt32, in set: RecordSet) throws -> Record? { try tables.record(address, in: set) }
    func records(in set: RecordSet) throws -> [Record] { try tables.records(in: set) }
    func file(_ path: String) throws -> [UInt8] {
        guard let bytes = fileInputs[path] else { throw Boundary.invalid("Undeclared source file " + path) }; return bytes
    }
    func replyControl(atSourceEvent index: Int) throws -> API.Response {
        guard c.events.indices.contains(index), let result = c.events[index].replyControl else { throw Boundary.invalid("Reply cursor") }; return result
    }

    private static func bundled(_ name: String) throws -> Data {
        guard !name.contains("/"), !name.contains("\\"), let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw Boundary.invalid("Missing bundled fixture " + name)
        }
        let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard attributes.isRegularFile == true, attributes.isSymbolicLink != true else { throw Boundary.invalid("Fixture file type") }
        return try Data(contentsOf: url)
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func verify(_ data: Data, _ pin: Pin) throws {
        guard data.count == pin.bytes, digest(data) == pin.sha256 else { throw Boundary.invalid("Data length/SHA") }
    }
    private static func decodedFile(_ file: EncodedFile, expected: Pin) throws -> Data {
        guard file.bytes == expected.bytes, file.sha256 == expected.sha256, let data = Data(base64Encoded: file.base64) else {
            throw Boundary.invalid("Encoded original file")
        }
        try verify(data, expected); return data
    }
    private static func decodedBlob(_ blob: Blob, key: String) throws -> [UInt8] {
        guard blob.sha256 == nil || blob.sha256 == key, let data = Data(base64Encoded: blob.deflate) else { throw Boundary.invalid("Blob encoding") }
        let raw = try inflate(data, count: blob.count, maximum: 100_000_000)
        try verify(raw, .init(bytes: blob.count, sha256: key)); return Array(raw)
    }
    private static func inflate(_ packed: Data, count: Int, maximum: Int) throws -> Data {
        guard count >= 0, count < maximum, !packed.isEmpty else { throw Boundary.invalid("Compressed bounds") }
        var output = Data(count: count + 1)
        let actual = output.withUnsafeMutableBytes { destination in
            packed.withUnsafeBytes { source in
                compression_decode_buffer(destination.bindMemory(to: UInt8.self).baseAddress!, destination.count,
                    source.bindMemory(to: UInt8.self).baseAddress!, source.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard actual == count else { throw Boundary.invalid("Inflated length") }
        output.removeLast(); return output
    }
    private static func partRows<T: Decodable>(_ manifest: PartManifest, files: [String: Data]) throws -> [[T]] {
        func simple(_ value: String) -> Bool { !value.isEmpty && value != "." && value != ".." && !value.contains("/") && !value.contains("\\") }
        guard manifest.encoding == "ordered-json-array-zlib-parts-v1", simple(manifest.directory) else { throw Boundary.invalid("Part manifest") }
        var result: [[T]] = [], count = 0
        for part in manifest.parts {
            guard simple(part.path), part.first == count, part.count > 0, let packed = files[manifest.directory + "/" + part.path] else {
                throw Boundary.invalid("Part name/ordinal")
            }
            try verify(packed, .init(bytes: part.packedBytes, sha256: part.packedSHA256))
            guard packed.count >= 6 else { throw Boundary.invalid("Zlib part frame") }
            let header = Int(packed[0]) * 256 + Int(packed[1])
            guard packed[0] & 15 == 8, packed[0] >> 4 <= 7, packed[1] & 32 == 0, header % 31 == 0 else { throw Boundary.invalid("Zlib header") }
            let raw = try inflate(Data(packed.dropFirst(2).dropLast(4)), count: part.rawBytes, maximum: 100_000_000)
            try verify(raw, .init(bytes: part.rawBytes, sha256: part.rawSHA256))
            var a: UInt32 = 1, b: UInt32 = 0
            for byte in raw { a = (a + UInt32(byte)) % 65_521; b = (b + a) % 65_521 }
            let trailer = packed.suffix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
            guard (b << 16 | a) == trailer else { throw Boundary.invalid("Zlib Adler32") }
            let rows = try JSONDecoder().decode([T].self, from: raw)
            guard rows.count == part.count else { throw Boundary.invalid("Part row count") }
            result.append(rows); count += rows.count
        }
        guard count == manifest.count else { throw Boundary.invalid("Manifest row total") }; return result
    }
    static func hex(_ text: String) throws -> [UInt8] {
        let bytes = Array(text.utf8)
        guard bytes.count % 2 == 0 else { throw Boundary.invalid("Hex length") }
        func digit(_ value: UInt8) throws -> UInt8 {
            switch value { case 48...57: return value - 48; case 97...102: return value - 87; case 65...70: return value - 55
            default: throw Boundary.invalid("Hex digit") }
        }
        return try stride(from: 0, to: bytes.count, by: 2).map { (try digit(bytes[$0])) << 4 | (try digit(bytes[$0 + 1])) }
    }
}
