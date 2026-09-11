import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

/// Reuse the immutable whole UI corpus. Constructor states are independently
/// replayed from its original writes, solely as comparison operands.
final class OriginalInitialPoolAndInterfaceTests: XCTestCase {
    typealias U = OriginalInitialInterfaceSurfaceTests
    struct Write: Decodable { let address: UInt32, bytes: String }
    struct Helper: Decodable { let kind: String, entry: UInt32, wrapper: UInt32?, firstStore: Int, lastStore: Int, eventStart: Int, eventEnd: Int }
    struct Read: Decodable { let address: UInt32, count: Int, bytes: String, known: [Int], region: String, storeCount: Int }
    struct Trace: Decodable { let writes: [Write], helpers: [Helper], reads: [Read] }
    struct Corpus: Decodable { let cases: [Trace] }
    struct Context: Equatable {
        var ui = U.Context()
        var actorTokens: [UInt32] = [], constructed: [Int] = [], poolChecks: [Bool] = []
        var retainedMarker: UInt32 = 0x12345678
    }
    struct Bytes { var bytes: [UInt8], mask: [Bool] }
    final class ConstructorComparison {
        let c: U.Case, trace: Trace, helpers: [Helper], addresses: [UInt32]
        var storage: [UInt32:Bytes], cursor = 0, index = 0
        init(_ c: U.Case,_ trace: Trace,_ pattern: [UInt8]) {
            self.c=c;self.trace=trace;helpers=trace.helpers.filter { $0.kind == "actor" }
            addresses=c.actorAddresses.sorted()
            storage=Dictionary(uniqueKeysWithValues:c.actorAddresses.map { ($0,Bytes(bytes:pattern,mask:[Bool](repeating:false,count:0x420))) })
            XCTAssertEqual(helpers.count,408)
        }
        func check(_ slot: Int,_ staging: Bool,_ actual: OriginalStateRecord) throws {
            let h=helpers[index]
            XCTAssertEqual(h.entry,0x4061d0);XCTAssertEqual(h.wrapper,c.actorAddresses[slot])
            XCTAssertEqual(slot,c.constructorSlots[index]);XCTAssertEqual(staging,index>=400)
            XCTAssertEqual(h.eventStart,staging ? 401 : slot+2);XCTAssertEqual(h.eventEnd,h.eventStart)
            XCTAssertLessThanOrEqual(h.firstStore,h.lastStore)
            guard cursor<=h.lastStore,h.lastStore<=trace.writes.count else { throw OriginalStateError.invalidStorage("Constructor write boundary") }
            while cursor<h.lastStore {
                let w=trace.writes[cursor];cursor += 1
                var lo=0,hi=addresses.count
                while lo<hi { let mid=(lo+hi)/2;if addresses[mid]<=w.address { lo=mid+1 } else { hi=mid } }
                guard lo>0 else { continue }
                let address=addresses[lo-1],offset=Int(w.address-address)
                guard offset<0x420 else { continue }
                let chars=Array(w.bytes.utf8)
                let bytes=try stride(from:0,to:chars.count,by:2).map { p in
                    try XCTUnwrap(UInt8(String(decoding:chars[p..<p+2],as:UTF8.self),radix:16))
                }
                guard offset+bytes.count<=0x420 else { throw OriginalStateError.invalidStorage("Actor write extent") }
                storage[address]!.bytes.replaceSubrange(offset..<offset+bytes.count,with:bytes)
                storage[address]!.mask.replaceSubrange(offset..<offset+bytes.count,with:repeatElement(true,count:bytes.count))
            }
            let bytes=try XCTUnwrap(storage[c.actorAddresses[slot]])
            var expected=try OriginalStateRecord(bytes:bytes.bytes,defined:bytes.mask)
            if expected.defined[0x368..<0x36c].allSatisfy({ $0 }) {
                XCTAssertEqual(try expected.integer(at:0x368,as:UInt32.self),c.objectAddress)
                try expected.write(UInt32(0),at:0x368)
            }
            XCTAssertEqual(actual.bytes,expected.bytes,"\(c.spec.label) constructor\(index) slot\(slot)")
            XCTAssertEqual(actual.defined,expected.defined,"constructor masks\(index)")
            index += 1
        }
    }
    func traces() throws -> [Trace] {
        let url=try XCTUnwrap(Bundle.module.url(forResource:"original-initial-interface-surface",withExtension:"json",subdirectory:"Fixtures"))
        let raw=try MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:120_000_000)
        return try JSONDecoder().decode(Corpus.self,from:raw).cases
    }
    func run(_ c: U.Case,_ r: U.Resources,_ trace: Trace,failure: String? = nil) throws -> OriginalInitialPoolAndInterface? {
        let a=try U.Adapter(c,r,failure:failure),constructors=ConstructorComparison(c,trace,a.pattern(0x420))
        let wordReads=trace.reads.filter { $0.region == "object-word90" }
        XCTAssertEqual(wordReads.count,8)
        var wordReadIndex=0
        var world=try OriginalStateRecord.worldPrefix(over:a.pattern(0x7d8))
        try world.write(c.selector,at:0)
        let initial=try r.blob(c.initial.globals)
        let globals=try OriginalStateRecord(bytes:Array(initial.prefix(OriginalMatchPreparation.globalSize)),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
        var context=Context(),result: OriginalInitialPoolAndInterface?
        let before=context
        do {
            result=try OriginalInitialPoolAndInterface.load(world:world,globals:globals,
                firstObjectWord90:{
                    let read=wordReads[wordReadIndex],helper=constructors.helpers[400+wordReadIndex]
                    XCTAssertEqual(constructors.index,401+wordReadIndex)
                    XCTAssertEqual(read.address,c.objectAddress+0x90);XCTAssertEqual(read.count,4)
                    XCTAssertEqual(read.known,[1,1,1,1]);XCTAssertEqual(read.storeCount,helper.lastStore+1)
                    let bytes=(0..<4).map { UInt8(truncatingIfNeeded:c.firstObjectWord90 >> ($0*8)) }
                    XCTAssertEqual(read.bytes,bytes.map { String(format:"%02x",$0) }.joined())
                    wordReadIndex += 1
                    if failure=="word90#8" && wordReadIndex==8 { throw U.Stop.injected }
                    return Int32(bitPattern:c.firstObjectWord90)
                },context:&context,
                allocateActor:{ slot,count,state in
                    XCTAssertEqual(slot,state.actorTokens.count);XCTAssertEqual(state.constructed.count,slot)
                    let e=c.events[slot+1],token=0x75000020+UInt32(c.spec.reverse == true ? 399-slot : slot)*0x500
                    XCTAssertEqual(e.kind,"allocateActor");XCTAssertEqual(e.index,slot);XCTAssertEqual(e.address,token)
                    XCTAssertEqual(e.count,count);XCTAssertEqual(count,0x420);XCTAssertEqual(c.actorAddresses[slot],token)
                    state.actorTokens.append(token)
                    if failure=="allocate399" && slot==399 { throw U.Stop.injected }
                    return a.pattern(count)
                },allocateInterface:{ i,state in
                    XCTAssertEqual(state.actorTokens.count,400);XCTAssertEqual(state.constructed.count,408)
                    XCTAssertEqual(state.poolChecks,[false,true]);return try a.allocate(i,&state.ui)
                },perform:{ try a.perform($0,&$1.ui) },afterActorConstructor:{ slot,staging,record,state in
                    try constructors.check(slot,staging,record);state.constructed.append(slot)
                    if failure=="constructor407" && state.constructed.count==408 { throw U.Stop.injected }
                },afterPool:{ _,staging,state in
                    state.poolChecks.append(staging)
                    if failure=="poolComplete" && staging { throw U.Stop.injected }
                },afterBitmap:{ try a.stored($0,$1,&$2.ui) },observeInterface:{ try a.observe($0,&$1.ui) })
            XCTAssertNil(failure)
        } catch {
            guard failure != nil,case U.Stop.injected=error else { throw error }
            XCTAssertEqual(context,before);XCTAssertNil(result)
            return nil
        }
        let value=try XCTUnwrap(result)
        XCTAssertEqual(constructors.index,408);XCTAssertEqual(context.constructed,c.constructorSlots)
        XCTAssertEqual(wordReadIndex,8)
        XCTAssertEqual(context.actorTokens,c.actorAddresses);XCTAssertEqual(context.retainedMarker,before.retainedMarker)
        XCTAssertEqual(a.index,a.events.count);XCTAssertEqual(a.stores,10)
        XCTAssertEqual(value.globals.bytes+a.suffix,try r.blob(c.after.globals))
        XCTAssertEqual(context.ui.imagesDeleted,Dictionary(uniqueKeysWithValues:c.images.map { (UInt32($0.key)!,$0.value.deleted) }))
        XCTAssertEqual(context.ui.surfacesReleased,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.released) }))
        XCTAssertEqual(context.ui.surfaceDescriptions,Dictionary(uniqueKeysWithValues:c.surfaces.map { (UInt32($0.key)!,$0.value.description) }))
        XCTAssertEqual(context.ui.dcs,Dictionary(uniqueKeysWithValues:c.dcs.map { (UInt32($0.key)!,$0.value) }))
        func bind(_ bytes: inout [UInt8],_ offset: Int,_ address: UInt32,_ ordinal: UInt32) {
            XCTAssertEqual(Array(bytes[offset..<offset+4]),(0..<4).map { UInt8(truncatingIfNeeded:address >> ($0*8)) })
            bytes.replaceSubrange(offset..<offset+4,with:(0..<4).map { UInt8(truncatingIfNeeded:ordinal >> ($0*8)) })
        }
        for record in c.records {
            var expected=try r.blob(record.bytes);let mask=try r.blob(record.mask)
            XCTAssertEqual(try r.blob(record.initial),a.pattern(record.count))
            let actual: OriginalStateRecord
            if record.kind=="world" {
                actual=value.bootstrap.world;bind(&expected,0x7d4,c.catalogAddress,0)
                for i in 0..<400 { bind(&expected,0x194+i*4,c.actorAddresses[i],UInt32(i)) }
            } else if record.kind=="actor" {
                let i=try XCTUnwrap(c.actorAddresses.firstIndex(of:record.address));actual=value.bootstrap.actors[i]
                bind(&expected,0x368,c.objectAddress,0)
            } else {
                XCTAssertEqual(record.kind,"bitmap");actual=try XCTUnwrap(value.interface.bitmaps[record.address]).storage
                let pointer=(0..<4).reduce(UInt32(0)) { $0 | UInt32(expected[$1]) << ($1*8) }
                if pointer != 0 { XCTAssertEqual(context.ui.surfaceForWrapper[record.address],pointer) }
                bind(&expected,0,pointer,pointer == 0 ? 0 : 1)
            }
            XCTAssertEqual(actual.bytes,expected,"\(c.spec.label) \(record.kind) final bytes")
            XCTAssertEqual(actual.defined,mask.map { $0 != 0 },"final masks")
        }
        return value
    }
    func testCompletePoolAndUIWithEveryOriginalConstructorReturn() throws {
        let r=try U.Resources(),t=try traces();XCTAssertEqual(t.count,r.c.cases.count)
        for (c,trace) in zip(r.c.cases,t) { _=try run(c,r,trace) }
        print("INITIAL POOL/UI10 controlled chains:4000 lazy allocations,4080 full constructor records/4308480 bytes+masks, then original UI resource/global/final-record comparisons. Full own catalog/application/Windows remain open.")
    }
    func testLateAllocationConstructorAndUIFailuresRetainContext() throws {
        let r=try U.Resources(),t=try traces()
        for failure in ["allocate399","constructor407","word90#8","poolComplete","createSurface#10","deleteObject#10","lastGlobal"] {
            XCTAssertNil(try run(r.c.cases[0],r,t[0],failure:failure))
        }
    }
    func testLateStagingObserverRetainsPreviouslyConstructedPool() throws {
        var pool=try OriginalWorldBootstrap(worldBacking:[UInt8](repeating:0xa5,count:0x7d8),actorBacking:[[UInt8]](repeating:[UInt8](repeating:0xa5,count:0x420),count:400),selector:2)
        let before=pool
        XCTAssertThrowsError(try pool.activateStagingActors(firstObjectWord90:0x12345678,afterConstructor:{ slot,_ in
            if slot==7 { throw U.Stop.injected }
        })) { error in guard case U.Stop.injected=error else { return XCTFail("Unexpected error: \(error)") } }
        XCTAssertEqual(pool,before)
    }
}
