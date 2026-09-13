import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

/// Comparison-only replay of saved original stores. The new native continuation
/// receives its own current entry/resources, never this expected state or trace.
final class OriginalApplicationPoolReference {
    typealias U = OriginalInitialInterfaceSurfaceTests
    typealias P = OriginalApplicationPoolSession
    struct Write: Decodable { let pc: UInt32?,address: UInt32,bytes: String }
    struct Event: Decodable { let kind: String?,storeCount: Int? }
    struct Trace: Decodable {
        let writes: [Write],helpers: [OriginalInitialPoolAndInterfaceTests.Helper]
        let reads: [OriginalInitialPoolAndInterfaceTests.Read],events: [Event]
    }
    struct Corpus: Decodable { let cases: [Trace] }
    let r: U.Resources,c: U.Case,t: Trace
    let entry: P.Catalog.PendingPool,helpers: [OriginalInitialPoolAndInterfaceTests.Helper]
    let lateStores: Set<Int>,word90: UInt32
    var world: OriginalStateRecord,actors: [OriginalStateRecord],cursor = 109,constructed = 0,phases = 0
    static let actorTokens = (0..<400).map { UInt32(0x75000020)+UInt32($0)*0x500 }
    static let uiTokens = (0..<10).map { UInt32(0x76000020)+UInt32($0)*0x2000 }
    init(_ entry: P.Catalog.PendingPool) throws {
        self.entry = entry;r = try U.Resources();c = r.c.cases[0]
        let raw = try MatchPreparationReference.unpack(Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:"original-initial-interface-surface",withExtension:"json",subdirectory:"Fixtures"))),maximumCount:120_000_000)
        t = try JSONDecoder().decode(Corpus.self,from:raw).cases[0]
        helpers = t.helpers.filter { $0.kind == "actor" }
        let reads = t.reads.filter { $0.region == "object-word90" };lateStores = Set(reads.map { $0.storeCount+1 })
        XCTAssertEqual(helpers.count,408);XCTAssertEqual(reads.count,8)
        XCTAssertEqual(t.writes[109].pc,0x41c052);XCTAssertEqual(t.writes[109].address,c.worldAddress+0x7d4)
        for i in 0..<8 { XCTAssertEqual(reads[i].storeCount,helpers[400+i].lastStore+1);XCTAssertEqual(reads[i].known,[1,1,1,1]);XCTAssertEqual(t.writes[reads[i].storeCount+1].address,c.actorAddresses[i]+0x31c) }
        word90 = try entry.catalog.objects[0].header.integer(at:0x90,as:UInt32.self)
        XCTAssertEqual(word90,0);XCTAssertEqual(c.firstObjectWord90,0x12345678)
        let full = entry.snapshot.state.full
        world = try .init(bytes:Array(full.bytes[0xbb00..<0xc2d8]),defined:Array(full.defined[0xbb00..<0xc2d8]))
        actors = try [OriginalStateRecord](repeating:.init(bytes:[UInt8](repeating:0xa5,count:0x420),defined:[Bool](repeating:false,count:0x420)),count:400)
    }
    static func bytes(_ hex: String) throws -> [UInt8] {
        let b = Array(hex.utf8)
        return try stride(from:0,to:b.count,by:2).map { try XCTUnwrap(UInt8(String(decoding:b[$0..<$0+2],as:UTF8.self),radix:16)) }
    }
    static func put(_ bytes: [UInt8],_ at: Int,_ record: inout OriginalStateRecord) throws {
        for (i,b) in bytes.enumerated() { try record.write(b,at:at+i) }
    }
    func replay(_ end: Int) throws {
        guard cursor <= end,end <= t.writes.count else { throw OriginalStateError.invalidStorage("Pool replay extent") }
        while cursor < end {
            let index = cursor,w = t.writes[cursor];cursor += 1
            let bytes = try Self.bytes(w.bytes)
            if w.address >= c.worldAddress,UInt64(w.address)+UInt64(bytes.count) <= UInt64(c.worldAddress)+0x7d8 {
                let at = Int(w.address-c.worldAddress)
                try Self.put(bytes,at,&world)
                if at == 0x7d4 { XCTAssertEqual(try world.integer(at:at,as:UInt32.self),c.catalogAddress);try world.write(UInt32(0),at:at) }
                if at >= 0x194,at < 0x7d4,bytes.count == 4 {
                    let slot = (at-0x194)/4;XCTAssertEqual(try world.integer(at:at,as:UInt32.self),c.actorAddresses[slot]);try world.write(UInt32(slot),at:at)
                }
            } else if w.address >= 0x75000020 {
                let delta = Int(w.address-0x75000020),slot = delta/0x500,at = delta%0x500
                guard slot < 400,at+bytes.count <= 0x420 else { continue }
                try Self.put(bytes,at,&actors[slot])
                if at == 0x368 {
                    XCTAssertEqual(bytes.count,4);XCTAssertEqual(try actors[slot].integer(at:at,as:UInt32.self),c.objectAddress)
                    try actors[slot].write(UInt32(0),at:at)
                }
                if lateStores.contains(index) {
                    XCTAssertEqual(at,0x31c);XCTAssertEqual(try actors[slot].integer(at:at,as:UInt32.self),c.firstObjectWord90)
                    try actors[slot].write(word90,at:at)
                }
            }
        }
    }
    func constructor(_ slot: Int,_ staging: Bool,_ actual: OriginalStateRecord) throws {
        let h = helpers[constructed]
        XCTAssertEqual(h.wrapper,c.actorAddresses[slot]);XCTAssertEqual(slot,c.constructorSlots[constructed]);XCTAssertEqual(staging,constructed >= 400)
        try replay(h.lastStore)
        XCTAssertTrue(actual.bytes == actors[slot].bytes,"Whole original constructor\(constructed)")
        XCTAssertEqual(actual.defined,actors[slot].defined);constructed += 1
    }
    func pool(_ p: OriginalWorldBootstrap,_ staging: Bool) throws {
        XCTAssertEqual(staging,phases == 1);XCTAssertEqual(constructed,staging ? 408 : 400)
        let end = staging ? try XCTUnwrap(t.events.first { $0.kind == "allocate" }?.storeCount) : helpers[400].firstStore
        try replay(end);XCTAssertEqual(p.world,world);XCTAssertTrue(p.actors == actors,"Whole400 pool records/masks");phases += 1
    }
    func globals(_ index: Int,cleared: Bool = false) throws -> OriginalStateRecord {
        let full = entry.snapshot.state.full,count = OriginalMatchPreparation.globalSize
        var result = try OriginalStateRecord(bytes:Array(full.bytes.prefix(count)),defined:Array(full.defined.prefix(count)))
        let start = try XCTUnwrap(t.events.first { $0.kind == "allocate" }?.storeCount)
        let writes = t.writes.dropFirst(start).filter { $0.address >= 0x44d000 && $0.address < 0x44d000+UInt32(count) }
        XCTAssertEqual(writes.count,11)
        for i in 0...index {
            let w = writes[i],bytes = try Self.bytes(w.bytes),cp = c.checkpoints[i]
            XCTAssertEqual(bytes.count,4);XCTAssertEqual(w.address,UInt32(cp.slot));XCTAssertEqual(cp.value,c.allocations[i].address)
            let captured = try OriginalStateRecord(bytes:bytes,defined:[Bool](repeating:true,count:4))
            XCTAssertEqual(try captured.integer(at:0,as:UInt32.self),cp.value)
            try result.write(Self.uiTokens[i],at:Int(w.address)-0x44d000)
        }
        if cleared {
            let w = writes[10],bytes = try Self.bytes(w.bytes)
            XCTAssertEqual(w.pc,0x41c577);XCTAssertEqual(w.address,0x44d05c);XCTAssertEqual(bytes,[0,0,0,0])
            try Self.put(bytes,Int(w.address)-0x44d000,&result)
        }
        return result
    }
    func complete(_ p: P.PendingInput) throws {
        XCTAssertEqual(constructed,408);XCTAssertEqual(phases,2)
        XCTAssertEqual(p.loaded.bootstrap.world,world)
        XCTAssertTrue(p.loaded.bootstrap.actors == actors,"Whole final canonical Actor records/masks")
        XCTAssertEqual(p.actorTokens,Self.actorTokens);XCTAssertEqual(p.interfaceTokens,Self.uiTokens)
        XCTAssertEqual(p.interfaceSurfaces,(0..<10).map { UInt32(0x7b100000)+UInt32($0)*16 })
        var boundWorld = world
        try boundWorld.write(XCTUnwrap(entry.snapshot.allocations.first { $0.kind == .catalog }).token,at:0x7d4)
        for i in 0..<400 {
            try boundWorld.write(Self.actorTokens[i],at:0x194+4*i)
            var expected = actors[i];try expected.write(entry.snapshot.objectTokens[0],at:0x368)
            XCTAssertEqual(p.state.memory.allocations[Self.actorTokens[i]],.init(storage:expected))
        }
        let g = try globals(9,cleared:true)
        var full = entry.snapshot.state.full
        // Preserve masks as well as bytes outside the actual pool/UI stores.
        var b = full.bytes,m = full.defined
        b.replaceSubrange(0..<g.bytes.count,with:g.bytes);m.replaceSubrange(0..<g.defined.count,with:g.defined)
        b.replaceSubrange(0xbb00..<0xc2d8,with:boundWorld.bytes);m.replaceSubrange(0xbb00..<0xc2d8,with:boundWorld.defined)
        full = try .init(bytes:b,defined:m);XCTAssertEqual(p.state.full,full);XCTAssertEqual(p.loaded.globals,g)
        for (token,a) in entry.snapshot.state.memory.allocations { XCTAssertEqual(p.state.memory.allocations[token],a) }
        XCTAssertEqual(p.state.memory.allocations.count,entry.snapshot.state.memory.allocations.count+410)
        XCTAssertEqual(p.state.memory.replayPointers,entry.snapshot.state.memory.replayPointers)
        XCTAssertEqual(p.state.random,entry.snapshot.state.random)
        let oldState = entry.snapshot.state
        XCTAssertEqual(p.state.front.bitmaps,oldState.front.bitmaps)
        XCTAssertEqual(p.state.earlyScreen.bitmaps,oldState.earlyScreen.bitmaps)
        XCTAssertEqual(p.state.earlyScreen.surfaces,oldState.earlyScreen.surfaces)
        XCTAssertEqual(p.state.earlyScreen.retainedOperation,oldState.earlyScreen.retainedOperation)
        XCTAssertEqual(p.state.libraryText,oldState.libraryText);XCTAssertEqual(p.state.screenBody,oldState.screenBody)
        XCTAssertEqual(p.state.settings,oldState.settings)
        XCTAssertEqual(Set(p.loaded.interface.bitmaps.keys),Set(Self.uiTokens))
        for (i,a) in c.allocations.enumerated() {
            let source = try XCTUnwrap(c.records.first { $0.kind == "bitmap" && $0.address == a.address })
            var expected = try OriginalStateRecord(bytes:r.blob(source.bytes),defined:r.blob(source.mask).map { $0 != 0 })
            let surface = try expected.integer(at:0,as:UInt32.self);XCTAssertNotEqual(surface,0)
            try expected.write(UInt32(1),at:0)
            let bitmap = try XCTUnwrap(p.loaded.interface.bitmaps[Self.uiTokens[i]])
            XCTAssertEqual(bitmap.storage,expected)
            let name = try XCTUnwrap(c.events.first { $0.kind == "construct" && $0.index == i }?.path),asset = try XCTUnwrap(r.c.assets[name])
            XCTAssertEqual(bitmap.input,.init(path:name,present:true,width:asset.width,height:asset.height))
            XCTAssertFalse(bitmap.optional);XCTAssertNil(bitmap.mirroredFrom)
            try expected.write(p.interfaceSurfaces[i],at:0)
            XCTAssertEqual(p.state.memory.allocations[Self.uiTokens[i]],.init(storage:expected))
        }
        XCTAssertEqual(p.loaded.commands,entry.entry.common.commands.flatMap { $0 });XCTAssertEqual(p.loaded.commands.count,20)
        XCTAssertEqual(p.loaded.paused,entry.entry.common.paused)
        XCTAssertEqual(p.loaded.catalog.objects.count,137);XCTAssertEqual(p.loaded.registeredSounds.buffers.count,400)
        XCTAssertEqual(p.loaded.commonSounds.count,18);XCTAssertEqual(p.entry.startup.owner.loads.count,5)
        let a = p.loaded.catalog,retainedCatalog = entry.catalog
        XCTAssertEqual(a.registry,retainedCatalog.registry);XCTAssertTrue(a.objects == retainedCatalog.objects,"Retained whole Objects")
        XCTAssertTrue(a.backgrounds == retainedCatalog.backgrounds);XCTAssertTrue(a.stages == retainedCatalog.stages)
        XCTAssertTrue(a.bitmaps == retainedCatalog.bitmaps);XCTAssertEqual(a.frameAllocations,retainedCatalog.frameAllocations)
        XCTAssertEqual(a.checksum,retainedCatalog.checksum);XCTAssertEqual(a.soundCount,retainedCatalog.soundCount);XCTAssertEqual(a.soundBytes,retainedCatalog.soundBytes)
        XCTAssertEqual(Set(p.loaded.registeredSounds.buffers.keys),Set(entry.snapshot.sounds.buffers.keys))
        for (i,sound) in p.loaded.registeredSounds.buffers { Self.wave(sound,try XCTUnwrap(entry.snapshot.sounds.buffers[i])) }
        for (a,b) in zip(p.loaded.commonSounds,entry.entry.common.sounds) { Self.wave(a,b) }
        for (a,b) in zip(p.entry.startup.owner.loads,entry.startup.owner.loads) { Self.wave(a,b) }
    }
    static func wave(_ a: OriginalWaveLoadResult,_ b: OriginalWaveLoadResult) {
        XCTAssertEqual(a.exit,b.exit);XCTAssertEqual(a.returned,b.returned);XCTAssertEqual(a.output,b.output)
        XCTAssertEqual(a.temporary,b.temporary);XCTAssertEqual(a.temporaryLive,b.temporaryLive)
        XCTAssertEqual(a.first,b.first);XCTAssertEqual(a.second,b.second);XCTAssertEqual(a.format,b.format);XCTAssertEqual(a.descriptor,b.descriptor)
    }
}
