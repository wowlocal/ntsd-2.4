import Foundation
import XCTest
@testable import NTSDCore
import NTSDReferenceChecks

final class OriginalLoadingAudioTests: XCTestCase {
    enum Stop: Error { case late }
    final class Marker: OriginalApplicationStartupResource {}
    func fixture(_ name: String) throws -> Data {
        try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:name,withExtension:"json",subdirectory:"Fixtures")))
    }
    func testWholeCommonAndInitialLoadingWithObservedReplies() throws {
        try OriginalApplicationLoadingPrefixTests().run(Array(0..<12),failures:[nil],observedAudio:true)
        try OriginalApplicationLoadingPrefixTests().run([0],
            failures:["write#1","blit#1","copy#12","method#1","commit"],observedAudio:true)
        for suffix in ["","-control"] {
            let r = try InitialLoadingReference.compare(loading:fixture("original-initial-loading"+suffix),
                catalog:fixture("original-initial-loading-catalog"+suffix),
                sounds:fixture("original-initial-loading-sounds"+suffix),observedAudio:true)
            XCTAssertEqual(r.commonLoads,18);XCTAssertEqual(r.catalog.calls,400)
            XCTAssertEqual(r.catalog.catalog.objects,137);XCTAssertEqual(r.catalog.catalog.frames,15388)
            XCTAssertEqual(r.catalog.catalog.checksum,31_475_378)
            XCTAssertEqual(r.poolConstructors,408);XCTAssertEqual(r.interfaceConstructors,10)
        }
    }
    func testWholeSourceCatalogAndInterleavedObservedReplies() throws {
        for suffix in ["","-interleaved"] {
            let r = try CatalogSoundsReference.compare(catalog:fixture("original-loaded-catalog-audio"+suffix),
                sounds:fixture("original-catalog-sounds"+suffix),observedAudio:true)
            if suffix.isEmpty {
                XCTAssertEqual(r.catalog.objects,137);XCTAssertEqual(r.catalog.frames,15388)
                XCTAssertEqual(r.catalog.bytes,112_063_739);XCTAssertEqual(r.catalog.checksum,31_475_378)
                XCTAssertEqual(r.calls,400);XCTAssertEqual(r.sources,365)
                XCTAssertEqual(r.weaponCalls,14);XCTAssertEqual(r.frameCalls,386)
                XCTAssertEqual(r.bytes,66_210_142);XCTAssertEqual(r.events,6426);XCTAssertEqual(r.restores,80)
            } else {
                XCTAssertEqual(r.catalog.objects,3);XCTAssertEqual(r.catalog.frames,720)
                XCTAssertEqual(r.catalog.bytes,82_089_953);XCTAssertEqual(r.catalog.checksum,1_496_213)
                XCTAssertEqual(r.calls,29);XCTAssertEqual(r.sources,28)
                XCTAssertEqual(r.weaponCalls,0);XCTAssertEqual(r.frameCalls,29)
                XCTAssertEqual(r.bytes,4_157_380);XCTAssertEqual(r.events,466);XCTAssertEqual(r.restores,6)
            }
        }
    }
    /// Declared four-byte mono PCM control; no expected game after-state.
    func wav() -> [UInt8] {
        var b = Array("RIFF".utf8)+[UInt8](repeating:0,count:4)+Array("WAVEfmt ".utf8)
        b += [16,0,0,0,1,0,1,0,0x40,0x1f,0,0,0x40,0x1f,0,0,1,0,8,0]
        b += Array("data".utf8)+[4,0,0,0,0,127,128,255]
        b[4] = UInt8(b.count-8);return b
    }
    func platform(_ index: Int,alias: Bool = false) -> OriginalWavePlatform {
        .init(destination:0x452948+UInt32(index)*4,device:17,stream:18,
            buffer:UInt32(100+index),firstPointer:0x800000+UInt32(index)*16,
            secondPointer:alias ? 0x800000+UInt32(index)*16 : 0,
            descendResults:[0,0,0],formatReadResult:18,ascendResult:0,dataReadResult:4,
            createResult:0,lockResults:[0,0],restoreResult:0,unlockResult:0,closeResult:0,
            firstCount:alias ? 2 : 4,secondCount:alias ? 2 : 0,ramp:false)
    }
    func testOwnershipDomainsAndOrderedCacheControls() throws {
        var registry = OriginalSoundRegistry(),loader = OriginalRegisteredSoundLoading(),order: [String] = []
        let long = "abcdefghijklmnopqrstu"
        func register(_ path: String,previous: Int32 = -1,failVolume: Bool = false) throws -> Int32 {
            try registry.register(path,previous:previous,assignIndex:{ order.append("assign\($0)") },onNewSound:{ q in
                let replies = try OriginalWaveLegacyReplies(self.platform(q.index))
                let preparation = OriginalWavePreparation.observed(replies.input,{ request in
                    order.append(request.event.kind.rawValue);return try replies.reply(request)
                },.addressed,{ nil })
                try loader.load(q,device:17,outputBefore:0,preparation:preparation,fileSource:{ _ in self.wav() },
                    onVolume:{ args in
                        XCTAssertEqual(args,[UInt32(100+q.index),UInt32(bitPattern:-10000)])
                        order.append("volume");if failVolume { throw Stop.late }
                    })
            },onCommit:{ bytes,count in
                XCTAssertEqual(Array(bytes[(count-1)*20..<(count-1)*20+path.utf8.count+1]),Array(path.utf8)+[0])
                order.append("commit\(count)")
            })
        }
        XCTAssertEqual(try register(long),0)
        XCTAssertEqual(order,["assign0","create","lock","copy","unlock","volume","commit1"])
        order = [];XCTAssertEqual(try register(long),0);XCTAssertEqual(order,["assign0"])
        order = [];XCTAssertEqual(try register("two.wav"),1)
        XCTAssertEqual(order,["assign1","create","lock","copy","unlock","volume","commit2"])
        order = [];XCTAssertEqual(try register(long),2)
        XCTAssertEqual(order,["assign2","create","lock","copy","unlock","volume","commit3"])
        XCTAssertEqual(loader.buffers.count,3);XCTAssertEqual(loader.owners.count,3)
        XCTAssertNotEqual(loader.buffers[0]?.output,loader.buffers[2]?.output)
        order = [];XCTAssertEqual(try register("missing.wav",previous:9),9);XCTAssertTrue(order.isEmpty)
        let cache = registry.bytes,count = registry.count
        XCTAssertThrowsError(try register("failed.wav",failVolume:true))
        XCTAssertEqual(registry.bytes,cache);XCTAssertEqual(registry.count,count);XCTAssertEqual(loader.buffers.count,3)
        let owner = try XCTUnwrap(loader.owners[0]),spans = try owner.addressedRegions()
        XCTAssertEqual(spans.map(\.token),[0x800000]);XCTAssertEqual(spans.map(\.count),[4])
        XCTAssertThrowsError(try owner.validate(device:18,destination:owner.binding.destination,
            output:owner.result.output,domain:.addressed))
        var incomplete = owner.result;incomplete.temporaryLive = true
        XCTAssertThrowsError(try OriginalWaveOwnership(binding:owner.binding,result:incomplete,domain:.addressed).addressedRegions())
        let domain = OriginalAudioIdentityDomain(),other = OriginalAudioIdentityDomain()
        let lease = OriginalWaveResourceLease(domain:domain,binding:owner.binding,buffer:owner.result.output,
            regions:owner.result.regions,resources:[Marker()])
        let opaque = OriginalWaveOwnership(binding:owner.binding,result:owner.result,domain:.opaque(domain),lease:lease)
        XCTAssertTrue(try opaque.addressedRegions().isEmpty)
        XCTAssertThrowsError(try opaque.validate(device:17,destination:owner.binding.destination,
            output:owner.result.output,domain:.opaque(other)))
        let bad = OriginalWaveResourceLease(domain:domain,binding:owner.binding,buffer:owner.result.output,
            regions:[:],resources:[Marker()])
        XCTAssertThrowsError(try OriginalWaveOwnership(binding:owner.binding,result:owner.result,
            domain:.opaque(domain),lease:bad).addressedRegions())
        XCTAssertThrowsError(try OriginalWaveOwnership(binding:owner.binding,result:owner.result,domain:.opaque(domain)).addressedRegions())
        let p = platform(0,alias:true),replies = try OriginalWaveLegacyReplies(p)
        let preparation = OriginalWavePreparation.observed(replies.input,replies.reply,.addressed,{ nil })
        let result = try preparation.load(path:Array(long.utf8),file:wav(),output:0,outputStored:{ _ in },observe:{ _ in })
        XCTAssertEqual(result.first.bytes,[128,255]);XCTAssertEqual(result.second,result.first)
        let aliases = preparation.ownership(index:0,path:long,result:result)
        XCTAssertEqual(try aliases.addressedRegions().count,1)
        let legacy = OriginalWaveOwnership(binding:aliases.binding,result:result,legacy:p)
        XCTAssertEqual(try legacy.addressedRegions().count,2) // Historical addressed overlap is not erased.
    }
}
