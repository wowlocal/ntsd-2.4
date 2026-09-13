import Foundation
import XCTest
import NTSDCore

/// Three saved whole-child prefixes, reached through actual Native startup,
/// menu and common loading. The twentieth child cancels the full loader; this
/// never accepts a whole source catalog or publishes a partial native catalog.
final class OriginalApplicationCatalogSessionTests: XCTestCase {
    typealias R = OriginalApplicationCatalogSessionReference
    typealias C = OriginalApplicationCatalogSession
    typealias P = OriginalApplicationLoadingPrefixTests
    typealias I = P.I
    enum Stop: Error { case checkpoint, late }

    func inputs(_ r: R,target: UInt32,tokens: [UInt32]? = nil,dc: UInt32 = 0x12345678) throws -> C.Inputs {
        // All controls are declared in the saved harness, with separate input
        // provenance. No captured global/store/output bytes enter this value.
        let presentation = try JSONDecoder().decode(OriginalMenuPresentationInput.self,from:JSONSerialization.data(withJSONObject:[
            "targetSurface":target,"methodResult":0,"queryResult":0,"audioGetResult":0,"audioSetResult":0,
            "queriedAudio":0,"audioVolume":0,"dcResult":0,"dc":dc,"postResult":0]))
        return try .init(files:r.fileInputs,bitmaps:r.bitmapResources,allocationTokens:tokens ?? r.allocationTokens,
            bitmapReplies:r.bitmapControls,fileAllocations:r.fileAllocations,waves:r.waveInputs,volumeReplies:r.volumeControls,times:r.clocks,
            messages:r.c.events.filter { $0.kind == "peekMessage" }.map { e in
                XCTAssertEqual(e.result,0)
                return .init(name:"PeekMessageA",response:.init(result:try XCTUnwrap(e.result)))
            },presentation:presentation,drawResult:0,graphicsResult:0,allocationFill:0xa5)
    }
    func withEntry(_ r: R,_ body: @escaping (OriginalApplicationLoadingSession.PendingCatalog,C.StartupSounds) throws -> Void) throws {
        let fr = try I.F.Resources(),br = try I.Body.Resources(fr),mr = try I.M.Resources(br,fr),ir = try I.Resources(mr)
        let bitmap = try P.B.Resources(),entry = try P.B.Entry.Resources()
        var reached = false
        try I().run(r.prefix.spec.parentIndex,ir,mr,br,fr,bitmap,entry,loading:{ own,pending in
            reached = true
            var loading = try pending.makeLoadingSession()
            let response = ir.c.cases[r.prefix.spec.parentIndex].spec
            let prepared = try loading.prepareCommon(inputs:P.commonInputs.get(),waves:r.prefix.loads.map(\.input),
                drawResult:response.drawResult,presentationResult:response.presentResult)
            XCTAssertTrue(prepared.state.full.bytes == (try r.blob(r.c.before.globals)))
            XCTAssertTrue(prepared.state.full.defined.allSatisfy { $0 })
            XCTAssertEqual(prepared.common.sounds.count,18)
            let startup = try XCTUnwrap(own.bootstrap?.startup?.input?.sounds)
            try body(prepared,.init(owner:startup,platforms:r.startupWaveInputs))
        })
        XCTAssertTrue(reached)
    }
    static func same(_ actual: OriginalStateRecord,_ expected: OriginalStateRecord,_ label: String) throws {
        guard actual == expected else {
            let offset = actual.bytes.count == expected.bytes.count ? actual.bytes.indices.first {
                actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0]
            } : nil
            throw OriginalStateError.invalidStorage(label+" byte/mask mismatch at "+(offset.map { String($0,radix:16) } ?? "extent"))
        }
    }
    static func retained(_ current: OriginalApplicationMenuSession.State,_ old: OriginalApplicationMenuSession.State) {
        XCTAssertEqual(current.full,old.full); XCTAssertEqual(current.memory.allocations,old.memory.allocations)
        XCTAssertEqual(current.memory.replayPointers,old.memory.replayPointers)
        XCTAssertEqual(current.bitmapInputs,old.bitmapInputs); XCTAssertEqual(current.graphics,old.graphics)
        XCTAssertEqual(current.libraryText,old.libraryText); XCTAssertEqual(current.random,old.random)
        XCTAssertEqual(current.front.bitmaps,old.front.bitmaps); XCTAssertEqual(current.screenBody,old.screenBody)
        XCTAssertEqual(current.settings,old.settings)
    }

    final class Comparison {
        let r: R,entry: OriginalApplicationLoadingSession.PendingCatalog
        let events: [R.Event]
        let graphicsComparison: OriginalApplicationCatalogGraphicsComparison
        var index = 0,children: [OriginalCatalogChildObservation] = [],last: C.Snapshot?
        var apiCount = 0,volumeCount = 0,frameCount = 0,allocationCount = 0,fileEvents = 0
        var expectedOperations: [C.Operation]
        init(_ r: R,_ entry: OriginalApplicationLoadingSession.PendingCatalog) throws {
            self.r = r; self.entry = entry
            graphicsComparison = try .init(reference:r,entry:entry)
            events = r.c.events.filter { !($0.kind == "front" && $0.event?.kind == "text") }
            expectedOperations = entry.stagedOperations.map(C.Operation.preceding)
            let kinds = Set(["allocateCatalog","catalogEntry","allocateObject","allocateBitmap","allocateFrame","front","wave",
                "time","sleep","peekMessage","openFile","readFile","writeFile","closeReadFile","closeOutputDescriptor","registeredVolume"])
            guard events.allSatisfy({ $0.request != nil || kinds.contains($0.kind ?? "") }) else {
                throw OriginalStateError.invalidStorage("Unclassified saved catalog event")
            }
            XCTAssertEqual(r.c.end,"continuingCheckpoint"); XCTAssertEqual(r.c.objectReturns.count,20)
            XCTAssertTrue(r.c.catalogChildReturns.isEmpty); XCTAssertNil(r.c.dependency)
            XCTAssertNil(r.c.pendingObject); XCTAssertNil(r.c.pendingCatalogChild); XCTAssertNil(r.c.pendingDecoder); XCTAssertNil(r.c.pendingOutput)
            XCTAssertTrue(r.c.pendingHelpers.isEmpty); XCTAssertTrue(r.c.pendingOutputHelpers.isEmpty)
            XCTAssertEqual(r.tables.snapshots,1006); XCTAssertEqual(r.tables.revisions,7339)
        }
        func next(_ kind: String?,_ state: OriginalApplicationMenuSession.State) throws -> R.Event {
            guard index < events.count else { throw OriginalStateError.invalidStorage("Extra Native catalog event") }
            let e = events[index]; index += 1
            guard e.kind == kind,state.full.bytes == (try r.blob(e.globals)) else {
                throw OriginalStateError.invalidStorage("Catalog event \(index) kind/globals: \(String(describing:kind)) vs \(String(describing:e.kind))")
            }
            return e
        }
        func request(_ q: C.API.Request,_ e: C.API.Request) throws {
            guard q.kind == e.kind,q.words == e.words,q.strings == e.strings,q.defined == e.defined,q.bytes?.count == e.bytes?.count else {
                throw OriginalStateError.invalidStorage("Catalog API request \(index): \(q.kind)")
            }
            if let mask = q.defined,let a = q.bytes,let b = e.bytes {
                guard mask.indices.allSatisfy({ mask[$0] ? a[$0] == b[$0] : a[$0] == 0 }) else {
                    throw OriginalStateError.invalidStorage("Catalog API structure/mask \(index)")
                }
            } else { XCTAssertEqual(q.bytes,e.bytes) }
        }
        func observe(_ event: C.Observation,_ state: OriginalApplicationMenuSession.State) throws {
            switch event {
            case .globalStore,.parentStore,.request: return // Separate actual-write/parent comparisons below.
            case .allocation(let a):
                let kind: String
                switch a.kind {
                case .catalog:kind = "allocateCatalog"
                case .object:kind = "allocateObject"
                case .bitmap:kind = "allocateBitmap"
                case .frame(let frame):
                    kind = "allocateFrame"
                    let source = r.c.frameAllocations[frameCount]; frameCount += 1
                    XCTAssertEqual([0x410935:OriginalFrameAllocationKind.sound,0x4114ab:.interactions,0x411b85:.bodies][Int(source.caller)],frame)
                case .weapon(let slot):
                    kind = "allocateFrame"
                    let source = r.c.frameAllocations[frameCount]; frameCount += 1
                    XCTAssertEqual([0x40fbe6:0,0x40fc65:1,0x40fce8:2][Int(source.caller)],slot)
                }
                let e = try next(kind,state); XCTAssertEqual(e.arguments,[UInt32(a.count),a.token])
                allocationCount += 1; expectedOperations.append(.allocation(a))
            case let .catalogEntry(token,name,target):
                let e = try next("catalogEntry",state),args = try XCTUnwrap(e.arguments)
                XCTAssertEqual(args.count,3); XCTAssertEqual(token,args[0]); XCTAssertEqual(target,args[2])
                XCTAssertEqual(name,r.c.entry.fileName) // Filename pointer remains reference ABI only.
            case let .api(q,response):
                let e = try next(nil,state),expected = try XCTUnwrap(e.request)
                try request(q,expected); XCTAssertEqual(response,e.response); apiCount += 1
                // All request fields/known bytes just compared independently;
                // use its canonical unknown bytes for typed operation equality.
                expectedOperations.append(.menu(.bitmap(q,try XCTUnwrap(e.response))))
            case .file(let f):
                let e = try next(f.kind.rawValue,state)
                XCTAssertEqual(f.arguments,e.arguments); XCTAssertEqual(f.path,e.path); XCTAssertEqual(f.mode,e.mode)
                if let bytes = e.bytes { XCTAssertEqual(f.bytes,try R.hex(bytes)) } else { XCTAssertNil(f.bytes) }
                if f.kind == .closeReadFile || f.kind == .closeOutputDescriptor {
                    // Source events omit the return. The independently pinned
                    // producer inheritance proves its declared ret() control0.
                    XCTAssertNil(e.result); XCTAssertEqual(f.result,0)
                } else { XCTAssertNil(f.result) }
                expectedOperations.append(.file(f)); fileEvents += 1
            case let .wave(i,w):
                let e = try next("wave",state)
                XCTAssertEqual(e.event,.init(w.kind.rawValue,w.arguments,w.strings))
                if w.kind != .load { expectedOperations.append(.wave(i,w)) }
            case let .volume(args,result):
                let e = try next("registeredVolume",state); XCTAssertEqual(args,e.arguments)
                XCTAssertEqual(result,e.result)
                expectedOperations.append(.volume(try XCTUnwrap(e.arguments),ignoredResult:try XCTUnwrap(e.result))); volumeCount += 1
            case .front(let f):
                switch f.kind {
                case "timeGetTime":
                    let e = try next("time",state); XCTAssertEqual(f.arguments,e.arguments)
                    expectedOperations.append(.clock(try XCTUnwrap(e.arguments?.first)))
                case "sleep":
                    let e = try next("sleep",state); XCTAssertEqual(f.arguments,e.arguments)
                    expectedOperations.append(.menu(.sleep(try XCTUnwrap(e.arguments?.first))))
                case "PeekMessageA":
                    let e = try next("peekMessage",state); XCTAssertEqual(e.result,0); XCTAssertEqual(f.arguments,[0,0,0,0,0])
                    expectedOperations.append(.message("PeekMessageA",0,[]))
                default:
                    let e = try next("front",state),saved = try XCTUnwrap(e.event); XCTAssertEqual(f,saved)
                    switch saved.kind {
                    case "blit":expectedOperations.append(.menu(.blit(try XCTUnwrap(saved.blit),result:0)))
                    case "method":expectedOperations.append(.menu(.present(saved,result:0)))
                    case "soundMethod":expectedOperations.append(.menu(.soundMethod(saved,ignoredResult:0)))
                    case "getDC":expectedOperations.append(.menu(.getDC(saved,result:0,output:0x12345678)))
                    case "setBackgroundMode","setTextColor","textOut","releaseDC":expectedOperations.append(.menu(.graphics(saved,result:0)))
                    case "read","clip","draw","panelRead","text","stringLength","soundRequest":break
                    default:throw OriginalStateError.invalidStorage("Unclassified terminal catalog front event")
                    }
                }
            }
        }
        func record(_ address: UInt32,_ records: R.RecordSet) throws -> OriginalStateRecord {
            let saved = try XCTUnwrap(r.record(address,in:records)); XCTAssertTrue(saved.live)
            return try .init(bytes:r.blob(saved.bytes),defined:r.blob(saved.mask).map { $0 == 1 })
        }
        func wave(_ actual: OriginalWaveLoadResult,_ expected: R.Wave) throws {
            XCTAssertEqual(actual.exit,expected.exit); XCTAssertEqual(actual.output,expected.outputAfter)
            XCTAssertEqual(actual.returned,expected.returned); XCTAssertEqual(actual.temporaryLive,expected.temporaryLive)
            for (a,b) in [(actual.temporary,expected.temporary),(actual.first,expected.first),(actual.second,expected.second),
                          (actual.format,expected.format),(actual.descriptor,expected.descriptor)] {
                XCTAssertEqual(a == nil,b == nil)
                if let a,let b { try OriginalApplicationCatalogSessionTests.same(a,.init(bytes:r.blob(b.bytes),defined:r.blob(b.defined).map { $0 == 1 }),"WAV") }
            }
        }
        func child(_ value: OriginalCatalogChildObservation,_ snapshot: C.Snapshot) throws {
            let number = children.count,e = r.c.objectReturns[number]
            children.append(value); last = snapshot
            XCTAssertEqual(value.request.kind,.object); XCTAssertEqual(value.request.index,number)
            XCTAssertEqual(snapshot.objectTokens[number],e.address)
            XCTAssertEqual(e.arguments.prefix(2),[UInt32(bitPattern:try XCTUnwrap(value.request.id)),UInt32(bitPattern:try XCTUnwrap(value.request.objectType))][...])
            XCTAssertEqual(index,r.c.events[..<e.eventEnd].filter { !($0.kind == "front" && $0.event?.kind == "text") }.count)
            XCTAssertEqual(e.returnPC,0x41269a); XCTAssertEqual(e.returnSP,e.sp+20)
            XCTAssertTrue(snapshot.state.full.bytes == (try r.blob(e.after.globals)))
            XCTAssertEqual(snapshot.state.libraryText.retainedDC,e.after.retainedDC)
            XCTAssertEqual(snapshot.state.random.state,e.after.random)
            XCTAssertTrue(snapshot.state.full.defined.allSatisfy { $0 })
            XCTAssertEqual(snapshot.state.memory.allocations,entry.state.memory.allocations)
            XCTAssertEqual(snapshot.operations,expectedOperations)
            try graphicsComparison.compare(snapshot:snapshot,sourceEventEnd:e.eventEnd)
            let mask = try r.blob(e.after.mask).map { $0 == 1 }
            XCTAssertEqual(snapshot.observedGlobalWrites,mask)
            var sourceMask = [Bool](repeating:false,count:mask.count)
            for store in r.globalStores where store.eventIndex < e.eventEnd {
                let at = Int(store.address)-0x44d000
                XCTAssertNotEqual(store.pc,0)
                sourceMask.replaceSubrange(at..<at+store.size,with:repeatElement(true,count:store.size))
            }
            XCTAssertEqual(sourceMask,mask,"Original CPU-write journal independently reproduces the scoped observation mask")
            var ownMask = [Bool](repeating:false,count:mask.count)
            for store in snapshot.globalStores {
                let at = store.address-0x44d000
                ownMask.replaceSubrange(at..<at+store.bytes.count,with:repeatElement(true,count:store.bytes.count))
            }
            XCTAssertEqual(ownMask,mask)
            // Child callback precedes its parent's pointer store/count increment.
            let count = try XCTUnwrap(snapshot.parent[0x4d82380]).integer(at:0,as:UInt32.self)
            XCTAssertEqual(count,UInt32(number))
            let table = try XCTUnwrap(snapshot.parent[0])
            for slot in 0..<number { XCTAssertEqual(try table.integer(at:slot*4,as:UInt32.self),snapshot.objectTokens[slot]) }
            XCTAssertEqual(Array(table.bytes[number*4..<number*4+4]),[0xa5,0xa5,0xa5,0xa5])
            XCTAssertTrue(table.defined[number*4..<number*4+4].allSatisfy { !$0 })
            try storage(snapshot,e.after.records)
            let files = try XCTUnwrap(value.files),sourceFiles = r.c.files.filter { f in
                r.c.events[..<e.eventEnd].contains { $0.kind == "openFile" && $0.arguments?.first == f.address }
            }
            XCTAssertEqual(files.order,sourceFiles.map(\.address))
            for f in sourceFiles {
                let actual = try XCTUnwrap(files.streams[f.address])
                XCTAssertEqual(actual.path,f.path); XCTAssertEqual(actual.mode,f.mode)
                let ended = r.c.events[..<e.eventEnd].contains { x in
                    (x.kind == "closeReadFile" && x.arguments?.first == f.address) ||
                    (x.kind == "closeOutputDescriptor" && x.arguments?.last == f.address)
                }
                XCTAssertEqual(actual.closed,ended)
                if f.mode == "r" {
                    XCTAssertTrue(actual.raw == (try r.blob(f.raw))); XCTAssertTrue(actual.input == (try r.blob(f.logical)))
                    XCTAssertEqual(actual.loaded,f.read)
                    // Private FILE fields are comparison-only evidence of the
                    // logical cursor/EOF. They never initialize Native streams.
                    let descriptor = try XCTUnwrap(r.record(f.address,in:e.after.records))
                    let storage = try OriginalStateRecord(bytes:r.blob(descriptor.bytes),defined:r.blob(descriptor.mask).map { $0 == 1 })
                    XCTAssertEqual(actual.position,f.read-Int(try storage.integer(at:4,as:UInt32.self)))
                    XCTAssertEqual(actual.eof,try storage.integer(at:12,as:UInt32.self)&16 != 0)
                } else {
                    XCTAssertTrue(actual.output == (try r.blob(f.logical))); XCTAssertTrue(actual.pending.isEmpty)
                }
            }
            let parser = try XCTUnwrap(sourceFiles.last { $0.mode == "r" })
            XCTAssertTrue(value.decoded.unicodeScalars.map { UInt8($0.value) } == (try r.blob(parser.logical)))
            XCTAssertEqual(files.files[OriginalLoadingFiles.temporaryPath],Array("Do not erase this file.".utf8))
            XCTAssertEqual(value.soundCount,snapshot.sounds.buffers.count)
            for i in 0..<value.soundCount { try wave(XCTUnwrap(snapshot.sounds.buffers[i]),r.c.registeredWaves[i]) }
            if children.count == r.c.objectReturns.count { throw Stop.checkpoint }
        }
        func storage(_ snapshot: C.Snapshot,_ records: R.RecordSet) throws {
            let bitmapAddresses = snapshot.bitmapTokens
            func bitmap(_ record: inout OriginalStateRecord,_ offset: Int) throws {
                let pointer = try record.integer(at:offset,as:UInt32.self)
                let index = try XCTUnwrap(bitmapAddresses.firstIndex(of:pointer))
                try record.write(UInt32(index+1),at:offset)
            }
            let weaponSites: [UInt32:Int] = [0x40fbe6:0,0x40fc65:1,0x40fce8:2]
            let sourceAllocations = Array(r.c.frameAllocations.prefix(frameCount))
            let allocations = Dictionary(uniqueKeysWithValues:sourceAllocations.map { ($0.address,$0) })
            for (i,child) in children.enumerated() {
                let object = try XCTUnwrap(child.object)
                var expected = try record(r.c.objects[i].address,records)
                for p in [0x6fc,0x728] { try bitmap(&expected,p) }
                let sheets = Int(try expected.integer(at:0x498,as:Int32.self)); XCTAssertTrue((1...10).contains(sheets))
                for j in 1...sheets { try bitmap(&expected,0x750+j*4); try bitmap(&expected,0x778+j*4) }
                for slot in 0..<3 {
                    let pointer = try expected.integer(at:0x98+slot*4,as:UInt32.self)
                    if pointer == 0 { XCTAssertNil(object.weaponSoundPaths[slot]) }
                    else {
                        XCTAssertEqual(weaponSites[try XCTUnwrap(allocations[pointer]).caller],slot)
                        XCTAssertEqual(object.weaponSoundPaths[slot]?.unicodeScalars.map { UInt8($0.value) },Array(try record(pointer,records).bytes.prefix { $0 != 0 }))
                        try expected.write(UInt32(slot+1),at:0x98+slot*4)
                    }
                }
                for a in object.weaponSoundAllocations { try OriginalApplicationCatalogSessionTests.same(a.storage,record(XCTUnwrap(a.token),records),"Weapon allocation") }
                let parts = [object.header]+object.frameStorage+[object.nameTail]
                try OriginalApplicationCatalogSessionTests.same(.init(bytes:parts.flatMap(\.bytes),defined:parts.flatMap(\.defined)),expected,"Object\(i)")
            }
            let latest = try XCTUnwrap(children.last),frames = sourceAllocations.filter { weaponSites[$0.caller] == nil }
            XCTAssertEqual(latest.frameAllocations.count,frames.count)
            for (actual,e) in zip(latest.frameAllocations,frames) {
                XCTAssertEqual(actual.address,e.address)
                try OriginalApplicationCatalogSessionTests.same(actual.storage,record(e.address,records),"Frame")
            }
            XCTAssertEqual(latest.bitmaps.count,bitmapAddresses.count)
            for (i,actual) in latest.bitmaps.enumerated() {
                var expected = try record(bitmapAddresses[i],records)
                let surface = try expected.integer(at:0,as:UInt32.self)
                XCTAssertEqual(surface,snapshot.bitmapSurfaces[i]); try expected.write(UInt32(surface == 0 ? 0 : 1),at:0)
                try OriginalApplicationCatalogSessionTests.same(actual.storage,expected,"Bitmap\(i)")
                XCTAssertNil(actual.mirroredFrom)
            }
        }
        func complete() throws {
            let s = try XCTUnwrap(last)
            XCTAssertEqual(children.count,20); XCTAssertEqual(index,events.count); XCTAssertEqual(apiCount,2918)
            XCTAssertEqual(volumeCount,94); XCTAssertEqual(frameCount,4995); XCTAssertEqual(allocationCount,5210)
            XCTAssertEqual(s.objectTokens,r.c.objects.map(\.address)); XCTAssertEqual(s.bitmapTokens,r.c.bitmaps.map(\.address))
            let raw = try r.blob(r.c.catalogBytes),mask = try r.blob(r.c.catalogMask)
            XCTAssertEqual(raw.count,r.c.catalog.count); XCTAssertEqual(mask.filter { $0 == 1 }.count,188)
            let regions = [0:0x7d0,0x4d81060:0x990,0x4d819f0:0x990,0x4d82380:0x28]
            XCTAssertEqual(Set(s.parent.keys),Set(regions.keys))
            XCTAssertEqual(s.parent.values.reduce(0) { $0+$1.defined.filter { $0 }.count },188)
            for (offset,actual) in s.parent {
                let count = actual.bytes.count
                XCTAssertEqual(count,regions[offset])
                try OriginalApplicationCatalogSessionTests.same(actual,.init(bytes:Array(raw[offset..<offset+count]),
                    defined:mask[offset..<offset+count].map { $0 == 1 }),"Catalog parent\(offset)")
            }
            XCTAssertEqual(s.observedGlobalWrites.filter { $0 }.count,2003)
            XCTAssertGreaterThan(s.graphics.count,entry.stagedGraphics.count)
            XCTAssertEqual(Array(s.graphics.prefix(entry.stagedGraphics.count)),entry.stagedGraphics)
        }
    }
    func testOwnCatalogPrefixesPreserveAllChildrenFilesGlobalsAndOperations() throws {
        for i in 0..<3 {
            let r = try R(parentIndex:i)
            try withEntry(r) { entry,startup in
                var session = try C(pending:entry,startup:startup)
                let compare = try Comparison(r,entry)
                do {
                    try session.load(inputs:self.inputs(r,target:entry.target),observe:compare.observe,afterChild:compare.child)
                    XCTFail("Saved prefix unexpectedly published a catalog")
                } catch Stop.checkpoint {}
                try compare.complete(); XCTAssertNil(session.pendingPool)
                Self.retained(session.entry.state,entry.state)
                XCTAssertEqual(session.startup.owner.loads.count,5)
                print("Own catalog parent\(i):20 child returns/194 bitmaps/4995 malloc/94 WAV; full observed prefix and rollback, no full catalog return")
            }
        }
    }
    func testLateCatalogCancellationAndChangingTextDCDoNotPublishOwners() throws {
        let r = try R(parentIndex:0)
        try withEntry(r) { entry,startup in
            var session = try C(pending:entry,startup:startup),volume = 0
            let compare = try Comparison(r,entry)
            do {
                try session.load(inputs:self.inputs(r,target:entry.target),observe:{ e,state in
                    try compare.observe(e,state)
                    if case .volume = e { volume += 1; if volume == 94 { throw Stop.late } }
                })
                XCTFail("Late catalog observer did not cancel")
            } catch Stop.late {}
            XCTAssertEqual(volume,94); XCTAssertNil(session.pendingPool); Self.retained(session.entry.state,entry.state)
            let changedDC: UInt32 = 0x12345679
            var observed = false
            do {
                try session.load(inputs:self.inputs(r,target:entry.target,dc:changedDC),observe:{ e,state in
                    if case .front(let f) = e,f.kind == "setBackgroundMode" {
                        XCTAssertEqual(f.arguments.first,changedDC); XCTAssertEqual(state.libraryText.retainedDC,changedDC); observed = true
                        throw Stop.late
                    }
                })
                XCTFail("Changed-DC observer did not cancel")
            } catch Stop.late {}
            XCTAssertTrue(observed); XCTAssertNil(session.pendingPool); Self.retained(session.entry.state,entry.state)
        }
    }
    func testCatalogAllocationCannotOverlapRetainedCommonPCM() throws {
        let r = try R(parentIndex:0)
        try withEntry(r) { entry,startup in
            var tokens = r.allocationTokens; tokens[0] = 0x60000020
            var session = try C(pending:entry,startup:startup)
            XCTAssertThrowsError(try session.load(inputs:self.inputs(r,target:entry.target,tokens:tokens))) {
                XCTAssertEqual($0 as? C.Boundary,.overlap(0x60000020))
            }
            XCTAssertNil(session.pendingPool); Self.retained(session.entry.state,entry.state)
        }
    }
}
