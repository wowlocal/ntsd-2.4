import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationDispatchPrefixTests: XCTestCase {
    struct Store: Decodable, Equatable {
        let address: UInt32, value: UInt32
    }
    struct KeyCase: Decodable {
        let index: Int, sequence: Int32, enabled: Int32, mode: Int32, keys: String
        let before: String, after: String, sequenceAfter: Int32, enabledAfter: Int32, modeAfter: Int32
        let writes: [Store]
    }
    struct ClearCase: Decodable {
        let index: Int, target: UInt32, color: UInt32, backing: [UInt8], response: Int32
        let request: OriginalSurfaceClearRequest, result: Int32, effectsAfter: [UInt8], mask: [UInt8]
    }
    struct World: Decodable {
        let address: UInt32, initializer: UInt32, pointerSlot: UInt32, before: String, after: String, mask: String
    }
    struct Corpus: Decodable {
        let exeSHA256: String, globalAddress: Int, globalSize: Int, ordinaryGlobalSize: Int, globalTemplate: String
        let keys: [KeyCase], clears: [ClearCase], staticWorld: World, blobs: [String: InputControlReference.Blob]
        func blob(_ key: String) throws -> [UInt8] {
            let b = try XCTUnwrap(blobs[key])
            let raw = try MatchPreparationReference.inflate(b.deflate, count: b.count)
            XCTAssertEqual(MatchPreparationReference.digest(Data(raw)), key)
            return raw
        }
    }
    private func corpus() throws -> Corpus {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_APPLICATION_DISPATCH_PREFIX_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-application-dispatch-prefix.json", withExtension: nil, subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 32_000_000))
        XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        return c
    }
    func testWholeServiceKeyPrefix() throws {
        let c = try corpus(), template = try c.blob(c.globalTemplate)
        XCTAssertEqual(c.keys.count, 4348); XCTAssertEqual(c.globalAddress, 0x44d000)
        XCTAssertEqual(c.globalSize, 0xc3a8); XCTAssertEqual(c.ordinaryGlobalSize, OriginalMatchPreparation.globalSize)
        for item in c.keys {
            var full = try OriginalStateRecord(bytes: template, defined: Array(repeating: true, count: template.count))
            let keys = try c.blob(item.keys); XCTAssertEqual(keys.count, 300)
            for (i, byte) in keys.enumerated() { try full.write(byte, at: 0x455378-c.globalAddress+i) }
            try full.write(item.sequence, at: 0x4593a4-c.globalAddress)
            try full.write(item.enabled, at: 0x450bec-c.globalAddress)
            try full.write(item.mode, at: 0x4593a0-c.globalAddress)
            XCTAssertEqual(full.bytes, try c.blob(item.before), "Declared source input \(item.index)")
            var service = OriginalApplicationKeyScan(sequence: UInt32(bitPattern: item.sequence),
                diagnostics: UInt32(bitPattern: item.enabled), mode: UInt32(bitPattern: item.mode))
            var stores: [Store] = []
            try service.apply(keyboard: keys) { stores.append(Store(address: $0, value: $1)) }
            XCTAssertEqual(stores, item.writes, "Ordered source stores \(item.index)")
            XCTAssertEqual(Int32(bitPattern: service.sequence), item.sequenceAfter, "sequence \(item.index)")
            XCTAssertEqual(Int32(bitPattern: service.mode), item.modeAfter, "mode \(item.index)")
            XCTAssertEqual(Int32(bitPattern: service.diagnostics), item.enabledAfter, "enabled \(item.index)")
            for store in stores { try full.write(store.value, at: Int(store.address)-c.globalAddress) }
            XCTAssertTrue(full.defined.allSatisfy { $0 })
            XCTAssertEqual(full.bytes, try c.blob(item.after), "Complete source storage \(item.index)")
        }
    }
    func testWholeSurfaceClearRequestsAndReturns() throws {
        let c = try corpus(); XCTAssertEqual(c.clears.count, 420)
        for item in c.clears {
            var calls = 0
            let result = try OriginalSurfaceClearing.clear(target: item.target, color: item.color, backing: item.backing) { request in
                calls += 1
                XCTAssertEqual(request, item.request, "request \(item.index)")
                XCTAssertEqual(request.effects, item.effectsAfter)
                XCTAssertEqual(request.defined, item.mask.map { $0 != 0 })
                return item.response
            }
            XCTAssertEqual(calls, 1); XCTAssertEqual(result, item.result, "HRESULT \(item.index)")
        }
    }
    func testEmbeddedWorldInitializerOverPEZeroFill() throws {
        let c = try corpus(), world = c.staticWorld
        XCTAssertEqual(world.address, 0x458b00); XCTAssertEqual(world.initializer, 0x446300); XCTAssertEqual(world.pointerSlot, 0x4472d0)
        let before = try c.blob(world.before)
        XCTAssertEqual(before, Array(repeating: 0, count: OriginalStateRecord.worldPrefixSize))
        let native = try OriginalStateRecord.worldPrefix(over: before)
        XCTAssertEqual(native.bytes, try c.blob(world.after))
        XCTAssertEqual(native.defined, try c.blob(world.mask).map { $0 != 0 })
    }
}
