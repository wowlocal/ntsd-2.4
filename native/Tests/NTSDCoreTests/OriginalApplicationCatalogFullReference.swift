import Foundation
import XCTest
import NTSDCore

/// Comparison-only full controlled catalog and WAV records. Original source
/// files and declared replies are separate inputs; no Native run produces these
/// expectations. The current application's whole source return is unavailable.
final class OriginalApplicationCatalogFullReference {
    typealias C = OriginalApplicationCatalogSession
    typealias Pixels = OriginalCatalogDIBPixelsTests
    struct Blob: Decodable { let count: Int,deflate: String }
    struct Record: Decodable { let bytes: String,defined: String }
    struct Bitmap: Decodable { let address: UInt32,path: String,optional: UInt32,storage: Record }
    struct Allocation: Decodable { let address: UInt32,size: Int,kind: String,caller: String,storage: Record }
    struct Child: Decodable {
        let kind: OriginalCatalogLoadRequest.Kind,path: String,index: Int?,id: Int32?,objectType: Int32?
        let source: String,decoded: String,initialChecksum: UInt32,checksum: UInt32
        let bitmapStart: Int,bitmapEnd: Int,allocationStart: Int,allocationEnd: Int,soundCount: Int,soundBytes: String
        let frameOccurrences: Int?,storage: Record?
    }
    struct Event: Decodable { let kind: String,path: String?,mode: String?,handle: UInt32?,bitmap: Int? }
    struct Catalog: Decodable {
        let exeSHA256: String,crtSHA256: String,fileName: String,source: String,bitmapFill: UInt8
        let initialChecksum: UInt32,checksum: UInt32,objectAddresses: [UInt32],surfaceAddress: UInt32
        let requests: [OriginalCatalogLoadRequest],outerTokens: [String],children: [Child],regions: [Int:Record],stages: [Record]
        let bitmaps: [Bitmap],allocations: [Allocation],soundCount: Int,soundBytes: String,events: [Event],blobs: [String:Blob]
    }
    struct Wave: Decodable {
        let index: Int,kind: OriginalSoundRegistration.Kind,path: [UInt8],file: String,objectPath: String
        let input: OriginalWavePlatform,cacheBefore: String,outputBefore: UInt32,outputAfter: UInt32,returned: UInt32
        let temporary: Record?,first: Record,second: Record?,format: Record?,descriptor: Record?,temporaryLive: Bool
        let events: [OriginalWaveEvent],volume: [UInt32]
    }
    struct Audio: Decodable {
        struct Source: Decodable { let path: String,sha256: String,bytes: Int }
        let exeSHA256: String,calls: [Wave],sources: [Source],blobs: [String:Blob]
    }
    let catalog: Catalog,audio: Audio,golden: Pixels.Golden
    var files: [String:[UInt8]] = [:],images: [String:OriginalApplicationStartupInputs.Bitmap] = [:]
    private var decoded: [String:[UInt8]] = [:]
    private var cacheWrites: [[UInt8]] = []
    let frameKinds: [String:OriginalFrameAllocationKind] = ["0x410935":.sound,"0x4114ab":.interactions,"0x411b85":.bodies]
    let weaponSlots = ["0x40fbe6":0,"0x40fc65":1,"0x40fce8":2]
    struct Envelope: Decodable { let count: Int,sha256: String,deflate: String }
    static func corpus<T: Decodable>(_ name: String,_ count: Int,_ hash: String,as: T.Type) throws -> T {
        let p = try XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures"))
        let e = try JSONDecoder().decode(Envelope.self,from:Data(contentsOf:p))
        guard e.count == count,e.sha256 == hash else { throw OriginalStateError.invalidStorage("Full catalog envelope pin") }
        let b = try Pixels.inflate(e.deflate,count:count,maximumCount:100_000_000)
        guard Pixels.digest(b) == hash else { throw OriginalStateError.invalidStorage("Full catalog raw SHA") }
        return try JSONDecoder().decode(T.self,from:Data(b))
    }
    init() throws {
        catalog = try Self.corpus("original-loaded-catalog-files",95_289_959,"8ff43ea70036d84dbbea5309387176595658b0246aa3ff5773e8e22d08f12dee",as:Catalog.self)
        audio = try Self.corpus("original-catalog-sounds",47_296_738,"4283fc01113f09533428ca43ec1df25b1c80a2fbea2df58f1053cf44e3122e53",as:Audio.self)
        golden = try Pixels.golden.get()
        guard catalog.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              audio.exeSHA256 == catalog.exeSHA256,catalog.crtSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              catalog.children.count == 155,catalog.bitmaps.count == 829,catalog.allocations.count == 15545,
              audio.calls.count == 400,audio.sources.count == 365,golden.resources.count == 669 else {
            throw OriginalStateError.invalidStorage("Full catalog reference inventory")
        }
        files[catalog.fileName] = try blob(catalog.source)
        for c in catalog.children { files[c.path] = try blob(c.source) }
        XCTAssertEqual(files.count,156)
        for s in audio.sources { let b = try blob(s.sha256);XCTAssertEqual(b.count,s.bytes);files[s.path] = b }
        XCTAssertEqual(files.count,521)
        for r in golden.resources { images[r.name] = try golden.bitmap(r) }
        XCTAssertEqual(images.count,669)
        // Independently replay the recovered stride-20/full-path-with-NUL
        // stores and first require every immutable controlled cache to agree.
        var cache = try blob(audio.calls[0].cacheBefore)
        cacheWrites.append(cache)
        for (i,w) in audio.calls.enumerated() {
            XCTAssertEqual(w.index,i)
            guard cache == (try blob(w.cacheBefore)) else { throw OriginalStateError.invalidStorage("Source cache write provenance") }
            let bytes = w.path+[0],start = i*20
            cache.replaceSubrange(start..<start+bytes.count,with:bytes);cacheWrites.append(cache)
        }
        guard cache == (try blob(catalog.soundBytes)) else { throw OriginalStateError.invalidStorage("Source final cache provenance") }
        for c in catalog.children {
            guard cacheWrites[c.soundCount] == (try blob(c.soundBytes)) else { throw OriginalStateError.invalidStorage("Source child cache provenance") }
        }
    }
    func blob(_ key: String) throws -> [UInt8] {
        if let b = decoded[key] { return b }
        let r = try XCTUnwrap(catalog.blobs[key] ?? audio.blobs[key])
        let b = try Pixels.inflate(r.deflate,count:r.count,maximumCount:100_000_000)
        guard Pixels.digest(b) == key else { throw OriginalStateError.invalidStorage("Full catalog blob SHA") }
        decoded[key] = b;return b
    }
    func record(_ r: Record) throws -> OriginalStateRecord {
        let b = try blob(r.bytes),m = try blob(r.defined)
        guard b.count == m.count,m.allSatisfy({ $0 < 2 }) else { throw OriginalStateError.invalidStorage("Full catalog mask") }
        return try .init(bytes:b,defined:m.map { $0 == 1 })
    }
    func same(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
        try OriginalApplicationCatalogSessionTests.same(actual,expected,label)
    }
    func bindBitmap(_ r: inout OriginalStateRecord,_ at: Int,ordinal: Bool = false,nullable: Bool = false) throws {
        guard r.defined[at..<at+4].allSatisfy({ $0 }) else { return }
        let p = try r.integer(at:at,as:UInt32.self)
        if nullable && p == 0 { return }
        let i = try XCTUnwrap(catalog.bitmaps.firstIndex { $0.address == p })
        try r.write(UInt32(i+(ordinal ? 0 : 1)),at:at)
    }
    func cache(_ count: Int,entry: [UInt8]) throws -> [UInt8] {
        guard entry.count == 0x2e00,(0...400).contains(count) else { throw OriginalStateError.invalidStorage("Entry cache extent") }
        var expected = entry
        for i in 0..<count {
            let bytes = audio.calls[i].path+[0],start = i*20
            expected.replaceSubrange(start..<start+bytes.count,with:bytes)
        }
        return expected
    }
    func child(_ own: OriginalCatalogChildObservation,_ index: Int,entryChecksum: UInt32,entryCache: [UInt8]) throws {
        let c = catalog.children[index],q = own.request
        XCTAssertEqual(q.kind,c.kind);XCTAssertEqual(q.index,c.index);XCTAssertEqual(q.id,c.id);XCTAssertEqual(q.objectType,c.objectType)
        if q.kind != .stages { XCTAssertEqual(q.path,c.path) }
        XCTAssertEqual(own.initialChecksum,c.initialChecksum &+ entryChecksum &- catalog.initialChecksum);XCTAssertEqual(own.checksum,c.checksum &+ entryChecksum &- catalog.initialChecksum)
        XCTAssertEqual(own.bitmapCount,c.bitmapEnd);XCTAssertEqual(own.soundCount,c.soundCount)
        XCTAssertTrue(own.soundBytes == (try cache(c.soundCount,entry:entryCache)),"Whole child cache with retained entry backing");XCTAssertEqual(own.frameOccurrences,c.frameOccurrences ?? 0)
        XCTAssertEqual(own.decoded.unicodeScalars.map { UInt8($0.value) },try blob(c.decoded))
        if let object = own.object { try checkObject(object,c) }
        let fs = try XCTUnwrap(own.files)
        XCTAssertTrue(fs.streams.values.allSatisfy { $0.closed || $0.path == catalog.fileName })
        XCTAssertEqual(fs.files[OriginalLoadingFiles.temporaryPath],Array("Do not erase this file.".utf8))
    }
    func checkObject(_ own: OriginalLoadedObject,_ c: Child) throws {
        var e = try record(XCTUnwrap(c.storage))
        for at in [0x6fc,0x728] { try bindBitmap(&e,at) }
        let sheets = Int(try e.integer(at:0x498,as:Int32.self));XCTAssertTrue((1...10).contains(sheets))
        for i in 1...sheets { try bindBitmap(&e,0x750+i*4);try bindBitmap(&e,0x778+i*4) }
        let paths = catalog.allocations[c.allocationStart..<c.allocationEnd].filter { weaponSlots[$0.caller] != nil }
        XCTAssertEqual(own.weaponSoundAllocations.count,paths.count)
        for (a,b) in zip(own.weaponSoundAllocations,paths) {
            XCTAssertEqual(a.slot,weaponSlots[b.caller]);XCTAssertEqual(a.token,b.address);try same(a.storage,record(b.storage),"Weapon path")
        }
        for i in 0..<3 {
            let p = try e.integer(at:0x98+i*4,as:UInt32.self)
            if p == 0 { XCTAssertNil(own.weaponSoundPaths[i]);continue }
            let a = try XCTUnwrap(catalog.allocations.first { $0.address == p })
            XCTAssertEqual(own.weaponSoundPaths[i]?.unicodeScalars.map { UInt8($0.value) },Array(try blob(a.storage.bytes).prefix { $0 != 0 }))
            try e.write(UInt32(i+1),at:0x98+i*4)
        }
        let all = [own.header]+own.frameStorage+[own.nameTail]
        try same(.init(bytes:all.flatMap(\.bytes),defined:all.flatMap(\.defined)),e,c.path)
    }
    func complete(_ p: C.PendingPool) throws {
        let a = p.catalog,s = p.snapshot
        let entryChecksum = try p.entry.state.full.integer(at:0x44f620-0x44d000,as:UInt32.self)
        let entryCache = Array(p.entry.state.full.bytes[(0x455638-0x44d000)..<(0x458438-0x44d000)])
        XCTAssertEqual(a.registry.requests,catalog.requests);XCTAssertEqual(a.checksum,catalog.checksum &+ entryChecksum &- catalog.initialChecksum)
        XCTAssertEqual(a.registry.outerTokens.map { $0.map { String(format:"%02x",$0) }.joined() },catalog.outerTokens)
        XCTAssertEqual(a.soundCount,400);XCTAssertTrue(a.soundBytes == (try cache(400,entry:entryCache)),"Whole final cache with retained entry backing")
        XCTAssertEqual(a.objects.count,137);XCTAssertEqual(a.bitmaps.count,829);XCTAssertEqual(a.backgrounds.count,101);XCTAssertEqual(a.stages.count,60)
        let regions = [0:0x7d0,0x4d81060:0x990,0x4d819f0:0x990,0x4d82380:0x28]
        XCTAssertEqual(Set(s.parent.keys),Set(regions.keys));XCTAssertEqual(Set(a.registry.records.keys),Set(regions.keys))
        for (key,size) in regions {
            let expected = try record(XCTUnwrap(catalog.regions[key]))
            XCTAssertEqual(expected.bytes.count,size);XCTAssertEqual(s.parent[key]?.bytes.count,size);XCTAssertEqual(a.registry.records[key]?.bytes.count,size)
            // Game tokens deliberately retain the old non-overlapping Object and
            // bitmap addresses; only the enclosing catalog base was relocated.
            try same(XCTUnwrap(s.parent[key]),expected,"Full parent actual pointer bindings")
            var normalized = expected
            if key == 0 { for i in catalog.objectAddresses.indices { try normalized.write(UInt32(i),at:i*4) } }
            if key == 0x4d81060 { for at in [0x98c,0x914,0x918,0x91c] { try bindBitmap(&normalized,at,ordinal:true) } }
            try same(XCTUnwrap(a.registry.records[key]),normalized,"Full parent ordinals")
        }
        for i in 0..<101 {
            var e = try record(XCTUnwrap(catalog.regions[0x4d45db0+i*OriginalBackgroundLoader.recordSize]))
            if i != 100 {
                try bindBitmap(&e,0x98c,nullable:true)
                for j in 0..<30 { try bindBitmap(&e,0x914+j*4,nullable:true) }
            }
            try same(a.backgrounds[i],e,"Full BG \(i)")
        }
        for c in catalog.children where c.kind == .object { try checkObject(a.objects[c.index!],c) }
        for i in 0..<60 { try same(a.stages[i],record(catalog.stages[i]),"Full Stage \(i)") }
        for (i,b) in catalog.bitmaps.enumerated() {
            var e = try record(b.storage);try e.write(UInt32(1),at:0)
            let x = a.bitmaps[i];XCTAssertEqual(x.input.path,b.path);XCTAssertEqual(x.optional,b.optional != 0);XCTAssertNil(x.mirroredFrom)
            try same(x.storage,e,"Full bitmap \(i)")
        }
        let frames = catalog.allocations.filter { frameKinds[$0.caller] != nil };XCTAssertEqual(a.frameAllocations.count,14586)
        for (a,b) in zip(a.frameAllocations,frames) {
            XCTAssertEqual(a.kind,frameKinds[b.caller]);XCTAssertEqual(a.address,b.address);try same(a.storage,record(b.storage),"Full frame allocation")
        }
        XCTAssertEqual(p.files.streams.count,621);XCTAssertTrue(p.files.streams.values.allSatisfy { $0.closed })
        XCTAssertEqual(p.files.decoderReturns,Array(repeating:0,count:155))
        XCTAssertEqual(p.files.files[OriginalLoadingFiles.temporaryPath],Array("Do not erase this file.".utf8))
        XCTAssertEqual(s.sounds.buffers.count,400);XCTAssertEqual(s.waveInputs.count,400)
        for (i,w) in audio.calls.enumerated() {
            let x = try XCTUnwrap(s.sounds.buffers[i]);XCTAssertEqual(x.exit,.returned);XCTAssertEqual(x.returned,w.returned)
            XCTAssertEqual(x.output,s.waveInputs[i].buffer);XCTAssertEqual(x.temporaryLive,w.temporaryLive)
            for (a,b) in [(x.temporary,w.temporary),(Optional(x.first),Optional(w.first)),(x.second,w.second),(x.format,w.format),(x.descriptor,w.descriptor)] {
                XCTAssertEqual(a == nil,b == nil)
                if let a,let b { try same(a,record(b),"Full WAV \(i)") }
            }
        }
    }
}
