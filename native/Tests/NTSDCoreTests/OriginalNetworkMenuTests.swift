import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks
final class OriginalNetworkMenuTests: XCTestCase {
    enum LateFailure: Error { case observer }
    struct Blob: Decodable { let count: Int,sha256: String,deflate: String }
    struct Storage: Decodable { let bytes: String,defined: String }
    struct Record: Decodable { let address: UInt32,live: Bool,storage: Storage }
    struct Snapshot: Decodable { let globals: String,world: Storage,records: [Record],crtState: UInt32,pointers: [UInt8] }
    struct MenuInput: Decodable { let timers: [UInt32],keyStates: [Int32],dcResult: Int32,dc: UInt32,drawResults: [Int32] }
    struct Request: Decodable { let kind: String,arguments: [UInt32],bytes: [UInt8],response: OriginalNetworkClient.Response }
    struct Fill: Decodable { let backing: String,address: UInt32 }
    struct Entry: Decodable { let pc: UInt32,sp: UInt32,registers: [UInt32] }
    struct BackgroundBoundary: Decodable { let missing: Bool?,colorKeyResult: Int32? }
    struct Allocation: Decodable { let address: UInt32,backing: String? }
    struct Background: Decodable {
        struct Bitmap: Decodable { let resource: OriginalBitmapInput,surface: UInt32,colorKeyResult: Int32 }
        let allocation: Allocation,bitmapInput: Bitmap
    }
    struct ExitFrame: Decodable { let after: String,written: String }
    struct UI: Decodable {
        let input: MenuInput,entry: Entry,before: Snapshot,after: Snapshot,hostnameBefore: Storage,hostnameAfter: Storage
        let libraryDCBefore: UInt32,libraryDCAfter: UInt32,events: [OriginalFrontScreenEvent],networkRequests: [Request],fills: [Fill]
        let localAfter: String,localWritten: String,continuation: OriginalNetworkMenu.Continuation
        let backgroundBoundary: BackgroundBoundary?,background: Background?
        let exitFrame: ExitFrame?
    }
    struct TailInput: Decodable { let presentation: OriginalMenuPresentationInput,drawResults: [Int32] }
    struct Tail: Decodable { let input: TailInput,events: [OriginalFrontScreenEvent],after: Snapshot,libraryDCBefore: UInt32,libraryDCAfter: UInt32 }
    func testOwnNetworkSelectionHostnameAndDeferredClient() throws {
        let paths: [String]
        if let supplied = ProcessInfo.processInfo.environment["NTSD_NETWORK_MENU_UI"] { paths = supplied.components(separatedBy: "\n") }
        else { paths = try ["original-network-menu","original-network-menu-control","original-network-menu-partial-greeting","original-network-menu-partial-flags","original-network-menu-partial-names","original-network-menu-sound","original-network-menu-sound-control"].map { try XCTUnwrap(Bundle.module.url(forResource: $0+".json",withExtension: nil,subdirectory: "Fixtures")).path } }
        for path in paths { try compareOwnCorpus(path) }
    }
    private func compareOwnCorpus(_ path: String) throws {
        let raw = try MatchPreparationReference.unpack(Data(contentsOf: URL(fileURLWithPath: path)),maximumCount: 128_000_000),document = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String:Any])
        let calls = try XCTUnwrap(document["calls"] as? [[String:Any]])
        let blobs = try JSONDecoder().decode([String:Blob].self,from: JSONSerialization.data(withJSONObject: try XCTUnwrap(document["blobs"])))
        var cache: [String:[UInt8]] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let b = cache[key] { return b };let ref = try XCTUnwrap(blobs[key]);XCTAssertEqual(ref.sha256,key)
            let bytes = try MatchPreparationReference.inflate(ref.deflate,count: ref.count,maximumCount: 2_000_000)
            XCTAssertEqual(MatchPreparationReference.digest(Data(bytes)),key);cache[key] = bytes;return bytes
        }
        func storage(_ ref: Storage) throws -> OriginalStateRecord {
            try .init(bytes: blob(ref.bytes),defined: blob(ref.defined).map { $0 != 0 })
        }
        func snapshot(_ s: Snapshot,_ w: OriginalStateRecord,_ g: OriginalStateRecord,_ c: OriginalCRTRandom,_ m: OriginalMenuPresentationMemory) throws {
            XCTAssertEqual(w,try storage(s.world));XCTAssertEqual(g.bytes,try blob(s.globals));XCTAssertEqual(c.state,s.crtState);XCTAssertEqual(m.replayPointers.bytes,s.pointers)
            XCTAssertEqual(m.allocations.count,s.records.count)
            for r in s.records { let own = try XCTUnwrap(m.allocations[r.address]);XCTAssertEqual(own.live,r.live);XCTAssertEqual(own.storage,try storage(r.storage)) }
        }
        let control = document["control"] as? Bool ?? false
        var host = try OriginalStateRecord(bytes: control ? Array(0..<51) : [UInt8](repeating: 0xa5,count: 51),defined: [Bool](repeating: false,count: 51))
        var loop = document;loop.removeValue(forKey: "calls");loop.removeValue(forKey: "checkpointParts");loop["cases"] = try calls.map { try XCTUnwrap($0["loop"]) }
        let parent = try XCTUnwrap(document["parent"] as? [String:Any])
        // Resource source metadata is part of the independently executed parent.
        var cursor = parent,sources: [Any] = []
        while true {
            if let s = cursor["sources"] as? [Any] { sources += s }
            guard let next = cursor["parent"] as? [String:Any] else { break };cursor = next
        }
        if let all = document["sources"] as? [Any] { sources = all }
        var backgrounds: [String:Any] = [:]
        for case let source as [String:Any] in sources {
            if let path = source["path"] as? String,path.hasPrefix("MENU_BACK") { backgrounds[path] = source }
        }
        loop["sources"] = Array(backgrounds.values)
        var uiCount = 0,networkCount = 0,rollbacks = 0,rejected = 0
        let unsupported = document["unsupportedOwnRead"] as? [String:Int]
        let result = try FrontMenuLoopReference.compare(JSONSerialization.data(withJSONObject: loop),libraryEnabled: true,continueNetwork: { index,world,state,crt,memory,text,bodyLocal,prefix in
            let call = calls[index],ui = try JSONDecoder().decode(UI.self,from: JSONSerialization.data(withJSONObject: try XCTUnwrap(call["network"])))
            if ui.backgroundBoundary != nil { try state.write(UInt32(0),at: 0x4511ac-OriginalMatchPreparation.globalBase) }
            try snapshot(ui.before,world,state,crt,memory);XCTAssertEqual(host,try storage(ui.hostnameBefore));XCTAssertEqual(text.retainedDC,ui.libraryDCBefore)
            XCTAssertEqual(ui.entry.pc,0x427ca7);XCTAssertEqual(ui.entry.sp,0x1000f000);XCTAssertEqual(ui.entry.registers[0],0);XCTAssertEqual(ui.entry.registers[1],19)
            var local = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 0x400),defined: [Bool](repeating: false,count: 0x400))
            if let bodyLocal {
                for i in 0x14..<bodyLocal.bytes.count where bodyLocal.defined[i] { try local.write(bodyLocal.bytes[i],at: i-0x14) }
            }
            var eventIndex = 0,blits = 0,timers = 0,keys = 0,requests = 0,fills = 0,failureAt: Int?
            func event(_ e: OriginalFrontScreenEvent) throws {
                guard eventIndex < ui.events.count,e == ui.events[eventIndex] else { throw OriginalStateError.invalidStorage("Network UI case\(index) event\(eventIndex): \(e), expected \(eventIndex < ui.events.count ? String(describing:ui.events[eventIndex]) : "end")") }
                if eventIndex == failureAt { throw LateFailure.observer };eventIndex += 1
            }
            let width = try state.integer(at: 0x44d78c-OriginalMatchPreparation.globalBase,as: Int32.self),height = try state.integer(at: 0x44d790-OriginalMatchPreparation.globalBase,as: Int32.self)
            func draw(_ args: [UInt32],_ owned: OriginalMenuPresentationMemory,_ results: [Int32],_ observe: (OriginalFrontScreenEvent) throws -> Void) throws {
                let bitmap = try XCTUnwrap(owned.allocations[args[0]]);XCTAssertTrue(bitmap.live)
                let surface = try bitmap.storage.integer(at: 0,as: UInt32.self)
                var canonical = bitmap.storage;try canonical.write(UInt32(surface == 0 ? 0 : 1),at: 0)
                let input = OriginalBitmapDrawInput(x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),frame: Int32(bitPattern: args[3]),colorKey: args[4],mirrored: args[5],sourceSurface: surface,targetSurface: args[6],viewportWidth: width,viewportHeight: height)
                _ = try OriginalBitmapDrawing.draw(input,bitmap: canonical,observeRead: { r in var e = OriginalFrontScreenEvent("read");e.read = r;try observe(e) },observeClip: { c in var e = OriginalFrontScreenEvent("clip");e.clip = c;try observe(e) },perform: { b in
                    var e = OriginalFrontScreenEvent("blit");e.blit = b;try observe(e);defer { blits += 1 };return results[blits%results.count]
                })
            }
            func networkRequest(_ kind: String,_ arguments: [UInt32],_ bytes: [UInt8]) throws -> OriginalNetworkClient.Response {
                let expected = try XCTUnwrap(ui.networkRequests.indices.contains(requests) ? ui.networkRequests[requests] : nil)
                XCTAssertEqual(kind,expected.kind);XCTAssertEqual(arguments,expected.arguments);XCTAssertEqual(bytes,expected.bytes)
                try event(.init("network",[UInt32(requests)]));requests += 1;return expected.response
            }
            func request(_ r: OriginalNetworkClient.Request) throws -> OriginalNetworkClient.Response {
                if r.kind == .sleep { try event(.init("sleep",r.arguments));return .init() }
                return try networkRequest(r.kind.rawValue,r.arguments,r.bytes)
            }
            let selector = try state.integer(at: 0x44d064-OriginalMatchPreparation.globalBase,as: Int32.self)
            let initialWorld = world,initialHost = host,initialState = state,initialLocal = local,initialText = text,initialMemory = memory
            func run(_ world: inout OriginalStateRecord,_ host: inout OriginalStateRecord,_ state: inout OriginalStateRecord,_ local: inout OriginalStateRecord,_ text: inout OriginalLibSurfaceText,_ memory: inout OriginalMenuPresentationMemory) throws -> OriginalNetworkMenu.Continuation {
             var candidatePrefix = prefix
             let result = try OriginalNetworkMenu.run(world: &world,hostname: &host,globals: &state,local: &local,libraryText: &text,memory: &memory,
                input: .init(selector: selector,worldAddress: 0x22000020,drawTarget: 0x28002020,dcResult: ui.input.dcResult,dc: ui.input.dc),
                background: { g,m in
                    let b = try XCTUnwrap(ui.background),milliseconds = try XCTUnwrap(ui.input.timers.indices.contains(timers) ? ui.input.timers[timers] : nil);timers += 1
                    let loaded = try OriginalMenuBackground.load(globals: &g,milliseconds: milliseconds,allocate: {
                        XCTAssertNil(m.allocations[b.allocation.address]);return try .init(address: b.allocation.address,backing: blob(XCTUnwrap(b.allocation.backing)))
                    },source: { path in
                        XCTAssertEqual(path,b.bitmapInput.resource.path);let source = try XCTUnwrap(backgrounds[path] as? [String:Any])
                        if b.bitmapInput.resource.present { XCTAssertEqual(source["width"] as? Int32,b.bitmapInput.resource.width);XCTAssertEqual(source["height"] as? Int32,b.bitmapInput.resource.height) }
                        return (b.bitmapInput.resource,b.bitmapInput.surface,b.bitmapInput.colorKeyResult)
                    },observe: event)
                    if let bitmap = loaded.bitmap {
                        var raw = bitmap.storage;try raw.write(loaded.surface,at: 0);m.allocations[loaded.address] = .init(storage: raw)
                        var bitmaps = candidatePrefix.bitmaps,surfaces = candidatePrefix.surfaces;bitmaps[loaded.address] = bitmap;surfaces[loaded.address] = loaded.surface
                        candidatePrefix = try .init(bitmaps: bitmaps,surfaces: surfaces)
                    }
                },draw: { try draw($0,$1,ui.input.drawResults,event) },fill: { args in
                    let f = try XCTUnwrap(ui.fills.indices.contains(fills) ? ui.fills[fills] : nil);fills += 1
                    let value = try OriginalSurfaceFilling.request(target: args[0],x: Int32(bitPattern: args[1]),y: Int32(bitPattern: args[2]),width: Int32(bitPattern: args[3]),height: Int32(bitPattern: args[4]),color: args[5],backing: blob(f.backing))
                    var e = OriginalFrontScreenEvent("fill");e.fill = value;try event(e)
                },timer: { defer { timers += 1 };return try XCTUnwrap(ui.input.timers.indices.contains(timers) ? ui.input.timers[timers] : nil) },keyState: { k in
                    XCTAssertEqual(k,20);defer { keys += 1 };return try XCTUnwrap(ui.input.keyStates.indices.contains(keys) ? ui.input.keyStates[keys] : nil)
                },client: { g,l,w in try OriginalNetworkClient.attempt(globals: &g,local: &l,world: w,request: request) },exit: { g in
                    var temporary = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 256),defined: [Bool](repeating: false,count: 256))
                    _ = try OriginalNetworkExit.run(globals: &g,local: &temporary,request: { r in try networkRequest(r.kind.rawValue,r.arguments,r.bytes).result })
                    if let frame = ui.exitFrame {
                        let bytes = try blob(frame.after),written = try blob(frame.written)
                        for i in written.indices where written[i] != 0 { XCTAssertTrue(temporary.defined[i]);XCTAssertEqual(temporary.bytes[i],bytes[i]) }
                    }
                },observe: event)
             prefix = candidatePrefix;return result
            }
            if unsupported?["case"] == index {
                do { _ = try run(&world,&host,&state,&local,&text,&memory);XCTFail("Unknown own caller read was accepted") }
                catch OriginalStateError.undefinedBytes(let offset,let count) { XCTAssertEqual(offset,unsupported?["offset"]);XCTAssertEqual(count,unsupported?["count"]) }
                XCTAssertEqual(world,initialWorld);XCTAssertEqual(host,initialHost);XCTAssertEqual(state,initialState)
                XCTAssertEqual(local,initialLocal);XCTAssertEqual(text,initialText);XCTAssertEqual(memory.allocations,initialMemory.allocations)
                XCTAssertEqual(memory.replayPointers,initialMemory.replayPointers);rejected += 1;return
            }
            let end = try run(&world,&host,&state,&local,&text,&memory)
            XCTAssertEqual(end,ui.continuation);XCTAssertEqual(eventIndex,ui.events.count);XCTAssertEqual(requests,ui.networkRequests.count)
            XCTAssertEqual(host,try storage(ui.hostnameAfter));XCTAssertEqual(text.retainedDC,ui.libraryDCAfter);try snapshot(ui.after,world,state,crt,memory)
            if (call["loop"] as? [String:Any])?["label"] as? String == "client-type" { XCTAssertEqual(try host.integer(at: 0,as: UInt8.self),97) }
            let expected = try blob(ui.localAfter),written = try blob(ui.localWritten)
            // Preserve all source bytes. Unwritten private caller backing is
            // not imported; compare the actual new writes against own bytes.
            for i in written.indices where written[i] != 0 { XCTAssertTrue(local.defined[i],"Caller local+\(String(i,radix:16))");XCTAssertEqual(local.bytes[i],expected[i],"Caller local+\(String(i,radix:16))") }
            let label = (call["loop"] as? [String:Any])?["label"] as? String
            if ["client-idle","client-type","client-connect","choice-cancel","background-boundary-loaded","background-boundary-missing","background-boundary-color-key-error"].contains(label) {
                var w = initialWorld,h = initialHost,g = initialState,l = initialLocal,t = initialText,m = initialMemory
                let initialPrefix = prefix
                eventIndex = 0;blits = 0;timers = 0;keys = 0;requests = 0;fills = 0;failureAt = ui.events.count-1
                do { _ = try run(&w,&h,&g,&l,&t,&m);XCTFail("Missing late observer failure") }
                catch LateFailure.observer {} // All earlier events/requests still match source order.
                XCTAssertEqual(eventIndex,ui.events.count-1);XCTAssertEqual(w,initialWorld);XCTAssertEqual(h,initialHost)
                XCTAssertEqual(g,initialState);XCTAssertEqual(l,initialLocal);XCTAssertEqual(t,initialText)
                XCTAssertEqual(m.allocations,initialMemory.allocations);XCTAssertEqual(m.replayPointers,initialMemory.replayPointers)
                XCTAssertEqual(prefix.bitmaps,initialPrefix.bitmaps);XCTAssertEqual(prefix.surfaces,initialPrefix.surfaces)
                failureAt = nil;rollbacks += 1
            }
            let tail = try JSONDecoder().decode(Tail.self,from: JSONSerialization.data(withJSONObject: try XCTUnwrap(call["tail"])))
            XCTAssertEqual(text.retainedDC,tail.libraryDCBefore);eventIndex = 0;blits = 0
            func tailEvent(_ e: OriginalFrontScreenEvent) throws {
                guard eventIndex < tail.events.count,e == tail.events[eventIndex] else { throw OriginalStateError.invalidStorage("Network tail case\(index) event\(eventIndex)") };eventIndex += 1
            }
            let owned = memory
            try OriginalMenuPresentation.applyWithLibrary(end == .presentation ? .tail : .epilogue,input: tail.input.presentation,world: &world,globals: &state,memory: &memory,libraryText: &text) { e in
                if e.kind == .bitmap { try tailEvent(.init("draw",e.arguments));try draw(e.arguments,owned,tail.input.drawResults,tailEvent) }
                else { try tailEvent(.init(e.kind.rawValue,e.arguments,e.strings)) }
            }
            XCTAssertEqual(eventIndex,tail.events.count);XCTAssertEqual(text.retainedDC,tail.libraryDCAfter);try snapshot(tail.after,world,state,crt,memory)
            uiCount += 1;networkCount += ui.networkRequests.count
        })
        XCTAssertEqual(uiCount+rejected,calls.filter { $0["network"] != nil }.count);XCTAssertEqual(result.cases,calls.count)
        XCTAssertEqual(rejected,unsupported == nil ? 0 : 1)
        XCTAssertEqual(rollbacks,4+calls.filter { (($0["loop"] as? [String:Any])?["label"] as? String)?.hasPrefix("background-boundary-") == true }.count)
        print("NETWORK MENU \(result.cases) calls \(uiCount) network bodies \(networkCount) network requests \(rollbacks) late rollbacks \(rejected) explicit own rejections")
    }
    func testLibraryInstalledBeforeFreshOwnMenuReturn() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_NETWORK_MENU_PARENT"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-network-menu.json",withExtension: nil,subdirectory: "Fixtures")) }
        let data = try MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 128_000_000)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String:Any])
        let install = try XCTUnwrap(document["installation"] as? [String:Any])
        XCTAssertEqual(install["libSHA256"] as? String,"28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba")
        XCTAssertEqual((install["patches"] as? [Any])?.count,13)
        var parent = try XCTUnwrap(document["parent"] as? [String:Any]);parent["blobs"] = document["blobs"]
        let r = try FrontMenuCompletionReference.compare(JSONSerialization.data(withJSONObject: parent),libraryEnabled: true)
        XCTAssertEqual(r.cases,1);XCTAssertEqual(r.main,1)
        XCTAssertEqual(r.libraryText?.retainedDC,document["libraryDCAfter"] as? UInt32)
        XCTAssertEqual(r.parent.parent.parent.parent.parent.front.constructors,24)
        print("NETWORK MENU LIB PARENT 1 own whole return \(r.parent.parent.texts) body texts DC \(r.libraryText!.retainedDC)")
    }
}
