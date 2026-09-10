import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalInputStartupTests: XCTestCase {
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let bytes: String, defined: String }
    private struct Store: Decodable { let address: Int, bytes: String, eventIndex: Int }
    private struct Event: Decodable { let event: OriginalMenuSoundStartup.Event, globals: String }
    private struct Request: Decodable {
        let request: OriginalInputStartup.Request, response: OriginalInputStartup.Response, globals: String
    }
    private struct Caps: Decodable { let id: Int, bytes: String, defined: String }
    private struct Boundary: Decodable { let eventCount: Int, storeCount: Int, globals: String, offset: Int, count: Int }
    private struct Spec: Decodable { let label: String, device: OriginalMenuSoundStartup.Platform }
    private struct JoyReturn: Decodable { let eax: UInt32, globals: String }
    private struct Load: Decodable {
        let path: [UInt8], file: String, input: OriginalWavePlatform, afterGlobals: String
        let outputAfter: UInt32, returned: UInt32?, temporaryLive: Bool
        let first: Record, second: Record?, temporary: Record?, format: Record?, descriptor: Record?
    }
    private struct Callback: Decodable {
        let message: OriginalWindowInput.Message, beforeGlobals: String, afterGlobals: String, globalMask: String
        let stores: [Store], events: [Event], returned: UInt32, stackAfter: UInt32
    }
    private struct Case: Decodable {
        let spec: Spec, beforeGlobals: String, afterGlobals: String, globalMask: String
        let events: [Event], stores: [Store], joyRequests: [Request], capsStates: [Caps], loads: [Load]
        let ownBoundary: Boundary?, joystickReturn: JoyReturn, callbacks: [Callback]
    }
    private struct Source: Decodable { let path: String, sha256: String, count: Int }
    private struct Corpus: Decodable { let exeSHA256: String, sources: [Source], cases: [Case], blobs: [String: Blob] }
    private enum Trial: Error { case late }
    private func read() throws -> Corpus {
        let override = ProcessInfo.processInfo.environment["NTSD_INPUT_STARTUP"]
        let urls = try override.map { $0.split(separator:"\n").map { URL(fileURLWithPath:String($0)) } } ?? ["original-input-startup","original-input-startup-success"].map {
            try XCTUnwrap(Bundle.module.url(forResource:$0,withExtension:"json",subdirectory:"Fixtures"))
        }
        let corpora = try urls.map { try JSONDecoder().decode(Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:$0))) }
        let first = try XCTUnwrap(corpora.first);var blobs: [String:Blob] = [:]
        for c in corpora { XCTAssertEqual(c.exeSHA256,first.exeSHA256);for (h,b) in c.blobs { blobs[h] = b } }
        return Corpus(exeSHA256:first.exeSHA256,sources:first.sources,cases:corpora.flatMap(\.cases),blobs:blobs)
    }
    func testInputSoundProducerAndOwnJoystickCallbacks() throws {
        let corpus = try read();var cache: [String:[UInt8]] = [:]
        XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = cache[key] { return bytes }
            let b = try XCTUnwrap(corpus.blobs[key]),bytes = try MatchPreparationReference.inflate(b.deflate,count:b.count)
            XCTAssertEqual(MatchPreparationReference.digest(Data(bytes)),key);cache[key] = bytes;return bytes
        }
        func record(_ key: String) throws -> OriginalStateRecord {
            let bytes = try blob(key);return try .init(bytes:bytes,defined:[Bool](repeating:true,count:bytes.count))
        }
        func check(_ actual: OriginalStateRecord?, _ expected: Record?, _ label: String) throws {
            XCTAssertEqual(actual == nil,expected == nil,label)
            if let actual, let expected {
                XCTAssertTrue(actual.bytes == (try blob(expected.bytes)),label+" bytes")
                XCTAssertTrue(actual.defined == (try blob(expected.defined).map { $0 == 1 }),label+" masks")
            }
        }
        let sources = Dictionary(uniqueKeysWithValues:corpus.sources.map { ($0.path,$0.sha256) })
        var whole = 0,rejected = 0,waves = 0,callbacks = 0,eventTotal = 0,capsTotal = 0
        for item in corpus.cases {
            var globals = try record(item.beforeGlobals);let initial = globals
            var emitted: [OriginalMenuSoundStartup.Event] = [],writes: [(Int,[UInt8],Int)] = []
            var requestIndex = 0,capsIndex = 0
            func event(_ event: OriginalMenuSoundStartup.Event, _ state: OriginalStateRecord) throws {
                let i = emitted.count;guard i < item.events.count else { XCTFail("Excess event");throw Trial.late }
                XCTAssertEqual(event,item.events[i].event,item.spec.label+" event \(i)")
                XCTAssertTrue(state.bytes == (try blob(item.events[i].globals)),item.spec.label+" request globals \(i)")
                emitted.append(event)
            }
            var result: OriginalInputStartup.Result?
            do {
                result = try OriginalInputStartup.load(globals:&globals,request:{ r,state in
                    let expected = item.joyRequests[requestIndex];requestIndex += 1
                    XCTAssertEqual(r,expected.request,item.spec.label)
                    try event(.init(r.kind,r.arguments,r.information.map { [$0] } ?? []),state)
                    return expected.response
                },soundPlatform:item.spec.device,wavePlatform:{ i,path,destination,device in
                    let l = item.loads[i];XCTAssertEqual(Array(path.utf8),l.path);XCTAssertEqual(l.file,sources[path]);XCTAssertEqual(destination,l.input.destination);XCTAssertEqual(device,l.input.device);return l.input
                },fileSource:{ path in try blob(XCTUnwrap(sources[path])) },store:{ writes.append(($0,$1,emitted.count)) },capabilities:{ id,state in
                    let c = item.capsStates[capsIndex];capsIndex += 1;XCTAssertEqual(id,c.id)
                    let expected = try blob(c.bytes),mask = try blob(c.defined)
                    XCTAssertEqual(state.defined,mask.map { $0 == 1 })
                    XCTAssertTrue(mask.indices.allSatisfy { mask[$0] == 0 || state.bytes[$0] == expected[$0] })
                    capsTotal += 1
                },afterWave:{ i,native,state in
                    let l = item.loads[i];XCTAssertEqual(native.output,l.outputAfter);XCTAssertEqual(native.returned,l.returned);XCTAssertEqual(native.temporaryLive,l.temporaryLive)
                    XCTAssertTrue(state.bytes == (try blob(l.afterGlobals)),item.spec.label+" wave globals")
                    try check(native.first,l.first,"first");try check(native.second,l.second,"second");try check(native.temporary,l.temporary,"temporary")
                    try check(native.format,l.format,"format");try check(native.descriptor,l.descriptor,"descriptor");waves += 1
                },observeSound:event)
            } catch OriginalStateError.undefinedBytes(let offset,let count) {
                let boundary = try XCTUnwrap(item.ownBoundary);XCTAssertEqual(offset,boundary.offset);XCTAssertEqual(count,boundary.count)
                XCTAssertEqual(globals,initial);rejected += 1
            }
            let eventCount = item.ownBoundary?.eventCount ?? item.events.count
            let storeCount = item.ownBoundary?.storeCount ?? item.stores.count
            XCTAssertEqual(emitted,Array(item.events.prefix(eventCount)).map(\.event),item.spec.label)
            XCTAssertEqual(writes.count,storeCount,item.spec.label)
            var staged = initial,mask = [UInt8](repeating:0,count:initial.bytes.count)
            for (actual,expected) in zip(writes,item.stores.prefix(storeCount)) {
                XCTAssertEqual(actual.0,expected.address);XCTAssertEqual(actual.2,expected.eventIndex)
                XCTAssertEqual(actual.1.map { String(format:"%02x",$0) }.joined(),expected.bytes)
                for (i,byte) in actual.1.enumerated() { let o = actual.0-OriginalMatchPreparation.globalBase+i;try staged.write(byte,at:o);mask[o] = 1 }
            }
            XCTAssertTrue(staged.bytes == (try blob(item.ownBoundary?.globals ?? item.afterGlobals)),item.spec.label+" own staged bytes")
            eventTotal += emitted.count
            if let result {
                whole += 1;XCTAssertNil(item.ownBoundary);XCTAssertEqual(result.joystickReturn,item.joystickReturn.eax)
                XCTAssertEqual(globals,staged);XCTAssertTrue(mask == (try blob(item.globalMask)))
                XCTAssertEqual(result.sounds.loads.count,5);XCTAssertEqual(requestIndex,item.joyRequests.count)
                // Native starts every callback with its own initialized bounds.
                var local = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:OriginalWindowInput.localCount),defined:[Bool](repeating:false,count:OriginalWindowInput.localCount))
                var memory = OriginalMenuPresentationMemory(replayPointers:try .init(bytes:[UInt8](repeating:0,count:8),defined:[Bool](repeating:false,count:8)))
                for callback in item.callbacks {
                    XCTAssertTrue(globals.bytes == (try blob(callback.beforeGlobals)))
                    var stores: [(Int,[UInt8])] = [],calls = 0
                    let returned = try OriginalWindowInput.receive(callback.message,globals:&globals,local:&local,memory:&memory,request:{ r in
                        let expected = callback.events[calls];calls += 1
                        XCTAssertEqual(r.kind,.windowDefault);XCTAssertEqual(r.arguments,expected.event.arguments);return -123
                    },store:{ stores.append(($0,$1)) })
                    XCTAssertEqual(UInt32(bitPattern:returned),callback.returned);XCTAssertEqual(callback.stackAfter,0x1000f014)
                    XCTAssertEqual(calls,1);XCTAssertEqual(stores.count,callback.stores.count)
                    var callbackMask = [UInt8](repeating:0,count:globals.bytes.count)
                    for (a,e) in zip(stores,callback.stores) {
                        XCTAssertEqual(a.0,e.address);XCTAssertEqual(a.1.map { String(format:"%02x",$0) }.joined(),e.bytes)
                        for i in a.1.indices { callbackMask[a.0-OriginalMatchPreparation.globalBase+i] = 1 }
                    }
                    XCTAssertTrue(callbackMask == (try blob(callback.globalMask)));XCTAssertTrue(globals.bytes == (try blob(callback.afterGlobals)))
                    callbacks += 1
                }
            } else { XCTAssertNotNil(item.ownBoundary) }
        }
        XCTAssertEqual(whole,56);XCTAssertEqual(rejected,4);XCTAssertEqual(waves,280)
        XCTAssertEqual(callbacks,1900)
        print("InputStartup:",whole,"whole input/sound segments",rejected,"explicit unknown-capability rejections",waves,"WAV loads",callbacks,"own callbacks",eventTotal,"startup events",capsTotal,"capability checkpoints")
    }

    func testLateStartupAndCallbackRollback() throws {
        let c = try read(),item = try XCTUnwrap(c.cases.first { !$0.capsStates.isEmpty && $0.ownBoundary == nil })
        func blob(_ key: String) throws -> [UInt8] { let b = try XCTUnwrap(c.blobs[key]);return try MatchPreparationReference.inflate(b.deflate,count:b.count) }
        let before = try OriginalStateRecord(bytes:blob(item.beforeGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
        for lateCaps in [true,false] {
            var globals = before,index = 0,completed = 0
            XCTAssertThrowsError(try OriginalInputStartup.load(globals:&globals,request:{ _,_ in defer { index += 1 };return item.joyRequests[index].response },soundPlatform:item.spec.device,
                wavePlatform:{ i,_,_,_ in item.loads[i].input },fileSource:{ path in try blob(XCTUnwrap(c.sources.first { $0.path == path }).sha256) },
                capabilities:{ _,_ in if lateCaps { throw Trial.late } },afterWave:{ i,_,_ in completed += 1;if i == 4 { throw Trial.late } })) { XCTAssertTrue($0 is Trial) }
            XCTAssertEqual(globals,before);XCTAssertEqual(completed,lateCaps ? 0 : 5)
        }
        let callback = try XCTUnwrap(item.callbacks.last)
        var globals = try OriginalStateRecord(bytes:blob(callback.beforeGlobals),defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
        let initial = globals
        var local = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:OriginalWindowInput.localCount),defined:[Bool](repeating:false,count:OriginalWindowInput.localCount))
        let localBefore = local
        var memory = OriginalMenuPresentationMemory(replayPointers:try .init(bytes:[UInt8](repeating:0,count:8),defined:[Bool](repeating:false,count:8)))
        XCTAssertThrowsError(try OriginalWindowInput.receive(callback.message,globals:&globals,local:&local,memory:&memory,request:{ _ in throw Trial.late }))
        XCTAssertEqual(globals,initial);XCTAssertEqual(local,localBefore)
    }
}
