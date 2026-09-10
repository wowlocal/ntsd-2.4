import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalMenuSoundStartupTests: XCTestCase {
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct Record: Decodable { let bytes: String, defined: String }
    private struct Spec: Decodable {
        let label: String, ramp: Bool, window: UInt32, device: OriginalMenuSoundStartup.Platform
    }
    private struct ObservedEvent: Decodable {
        let event: OriginalMenuSoundStartup.Event, globals: String
    }
    private struct Store: Decodable { let address: Int, bytes: String, eventIndex: Int }
    private struct Load: Decodable {
        let label: String, path: [UInt8], file: String, input: OriginalWavePlatform
        let outputBefore: UInt32, outputAfter: UInt32, beforeGlobals: String, afterGlobals: String
        let temporary: Record?, temporaryLive: Bool, first: Record, second: Record?, format: Record?, descriptor: Record?
        let events: [OriginalWaveEvent], exit: OriginalWaveExit, returned: UInt32?, stackAfter: UInt32
    }
    private struct Case: Decodable {
        let spec: Spec, beforeGlobals: String, afterGlobals: String, globalMask: String
        let events: [ObservedEvent], stores: [Store], loads: [Load]
        let exit: String, endPC: UInt32, stackAfter: UInt32, controlWord: UInt32
    }
    private struct Source: Decodable { let path: String, sha256: String, count: Int }
    private struct Corpus: Decodable { let exeSHA256: String, sources: [Source], cases: [Case], blobs: [String: Blob] }
    private enum Trial: Error { case late }
    private func corpus() throws -> Corpus {
        let path = ProcessInfo.processInfo.environment["NTSD_MENU_SOUND_STARTUP"]
        let url = try path.map { URL(fileURLWithPath: $0) } ?? XCTUnwrap(Bundle.module.url(
            forResource: "original-menu-sound-startup", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url)))
    }
    func testWholeMenuSoundStartupAgainstOriginal() throws {
        let c = try corpus()
        XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.sources.map(\.path), OriginalMenuSoundStartup.paths)
        var cache: [String: [UInt8]] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = cache[key] { return bytes }
            let b = try XCTUnwrap(c.blobs[key]);let bytes = try MatchPreparationReference.inflate(b.deflate, count: b.count)
            XCTAssertEqual(MatchPreparationReference.digest(Data(bytes)), key)
            cache[key] = bytes;return bytes
        }
        var bytesChecked = 0, eventCount = 0, whole = 0, rejected = 0, loadsChecked = 0, leaks = 0
        func check(_ actual: OriginalStateRecord?, _ expected: Record?, _ label: String) throws {
            XCTAssertEqual(actual == nil, expected == nil, label)
            guard let actual, let expected else { return }
            let bytes = try blob(expected.bytes), mask = try blob(expected.defined)
            XCTAssertEqual(actual.bytes, bytes, label+" bytes")
            XCTAssertEqual(actual.defined, mask.map { $0 == 1 }, label+" mask")
            bytesChecked += bytes.count
        }
        func checkLoad(_ native: OriginalWaveLoadResult, _ item: Load) throws {
            XCTAssertEqual(native.output, item.outputAfter, item.label)
            XCTAssertEqual(native.returned, item.returned, item.label)
            XCTAssertEqual(native.exit, item.exit, item.label)
            XCTAssertEqual(native.temporaryLive, item.temporaryLive, item.label)
            try check(native.temporary, item.temporary, item.label+" temporary")
            try check(native.first, item.first, item.label+" first")
            try check(native.second, item.second, item.label+" second")
            try check(native.format, item.format, item.label+" format")
            try check(native.descriptor, item.descriptor, item.label+" descriptor")
            loadsChecked += 1;if native.temporaryLive { leaks += 1 }
        }
        let sources = Dictionary(uniqueKeysWithValues: c.sources.map { ($0.path, $0) })
        for item in c.cases {
            let before = try blob(item.beforeGlobals)
            var globals = try OriginalStateRecord(bytes: before, defined: [Bool](repeating: true, count: before.count))
            let initial = globals
            var events: [OriginalMenuSoundStartup.Event] = [], stores: [(Int, UInt32, Int)] = []
            var result: OriginalMenuSoundStartup.Result?
            var caught = false
            do {
                result = try OriginalMenuSoundStartup.load(globals: &globals, platform: item.spec.device, wavePlatform: { index,path,destination,device in
                    let l = item.loads[index]
                    XCTAssertEqual(l.path, Array(path.utf8));XCTAssertEqual(l.input.destination, destination);XCTAssertEqual(l.input.device, device)
                    XCTAssertEqual(l.file, sources[path]?.sha256)
                    return l.input
                }, fileSource: { path in
                    let s = try XCTUnwrap(sources[path]);let raw = try blob(s.sha256);XCTAssertEqual(raw.count, s.count);return raw
                }, afterWave: { index,native,state in
                    let l = item.loads[index];try checkLoad(native, l)
                    XCTAssertEqual(state.bytes, try blob(l.afterGlobals), item.spec.label+" child globals")
                    XCTAssertEqual(l.stackAfter, 0x1000f00c)
                }, store: { address,value in stores.append((address,value,events.count)) }, observe: { event,state in
                    let index = events.count
                    guard index < item.events.count else { XCTFail("Excess event "+item.spec.label);throw Trial.late }
                    XCTAssertEqual(event, item.events[index].event, item.spec.label+" event \(index)")
                    XCTAssertEqual(state.bytes, try blob(item.events[index].globals), item.spec.label+" event globals \(index)")
                    bytesChecked += state.bytes.count;events.append(event)
                })
            } catch OriginalStateError.invalidStorage(let message) {
                XCTAssertEqual(item.exit, "invalidCreateContinuation", message)
                XCTAssertEqual(message, "Original menu wave reaches invalid CreateSoundBuffer continuation")
                caught = true
            }
            XCTAssertEqual(events, item.events.map(\.event), item.spec.label)
            XCTAssertEqual(stores.count, item.stores.count, item.spec.label+" stores")
            var reconstructed = initial
            var writeMask = [UInt8](repeating:0,count:before.count)
            for (actual, expected) in zip(stores,item.stores) {
                XCTAssertEqual(actual.0, expected.address);XCTAssertEqual(actual.2, expected.eventIndex)
                let raw = (0..<4).map { UInt8(truncatingIfNeeded: actual.1 >> ($0*8)) }
                XCTAssertEqual(raw.map { String(format:"%02x",$0) }.joined(), expected.bytes)
                try reconstructed.write(actual.1, at: actual.0-OriginalMatchPreparation.globalBase)
                for i in 0..<4 { writeMask[actual.0-OriginalMatchPreparation.globalBase+i] = 1 }
            }
            XCTAssertEqual(reconstructed.bytes, try blob(item.afterGlobals), item.spec.label+" staged globals")
            XCTAssertEqual(writeMask, try blob(item.globalMask), item.spec.label+" observed write mask")
            if item.exit == "segmentEnd" {
                XCTAssertFalse(caught);let result = try XCTUnwrap(result)
                XCTAssertEqual(result.deviceReady, item.spec.device.createResult == 0)
                XCTAssertEqual(result.loads.count, 5);XCTAssertEqual(item.endPC, 0x43d100);XCTAssertEqual(item.stackAfter, 0x1000f00c)
                XCTAssertEqual(globals.bytes, reconstructed.bytes);XCTAssertEqual(globals.defined, reconstructed.defined)
                // The returned aggregate retains every earlier allocation and
                // buffer after all later loads have completed.
                for (native, expected) in zip(result.loads, item.loads) {
                    XCTAssertEqual(native.first.bytes, try blob(expected.first.bytes))
                    XCTAssertEqual(native.temporaryLive, expected.temporaryLive)
                }
                whole += 1
            } else {
                XCTAssertTrue(caught);XCTAssertEqual(item.endPC,0x40187a)
                XCTAssertEqual(globals.bytes,initial.bytes);XCTAssertEqual(globals.defined,initial.defined)
                // Independently compare the stopped helper's data, while the
                // whole caller remains an explicit rejection with rollback.
                let failed = try XCTUnwrap(item.loads.last)
                let native = try OriginalWaveLoader.load(path: failed.path, file: blob(failed.file), output: failed.outputBefore, platform: failed.input)
                try checkLoad(native,failed);rejected += 1
            }
            XCTAssertEqual(item.controlWord,0x37f)
            eventCount += events.count;bytesChecked += before.count*2
        }
        XCTAssertEqual(whole,112);XCTAssertEqual(rejected,10);XCTAssertEqual(loadsChecked,590)
        print("MenuSoundStartup:",whole,"whole segments",rejected,"explicit rejected create continuations",loadsChecked,"loads",eventCount,"events",bytesChecked,"bytes",leaks,"retained temporaries")
    }

    func testMissingDeviceAndLateObserverRollback() throws {
        let c = try corpus(), item = try XCTUnwrap(c.cases.first)
        func blob(_ key: String) throws -> [UInt8] {
            let b = try XCTUnwrap(c.blobs[key]);return try MatchPreparationReference.inflate(b.deflate,count:b.count)
        }
        let before = try OriginalStateRecord(bytes: blob(item.beforeGlobals), defined:[Bool](repeating:true,count:OriginalMatchPreparation.globalSize))
        var globals = before
        XCTAssertThrowsError(try OriginalMenuSoundStartup.initializeDevice(globals:&globals,window:item.spec.window,
            platform:.init(createResult:0,createdDevice:nil)))
        XCTAssertEqual(globals.bytes,before.bytes);XCTAssertEqual(globals.defined,before.defined)
        var completed = 0, events = 0
        XCTAssertThrowsError(try OriginalMenuSoundStartup.load(globals:&globals,platform:item.spec.device,
            wavePlatform:{ i,_,_,_ in item.loads[i].input },fileSource:{ path in
                try blob(XCTUnwrap(c.sources.first { $0.path == path }).sha256)
            },afterWave:{ i,_,_ in completed += 1;if i == 4 { throw Trial.late } },observe:{ _,_ in events += 1 })) { error in
                XCTAssertTrue(error is Trial)
            }
        XCTAssertEqual(completed,5);XCTAssertGreaterThan(events,70)
        XCTAssertEqual(globals.bytes,before.bytes);XCTAssertEqual(globals.defined,before.defined)
    }
}
