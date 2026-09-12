import Foundation
import XCTest
@testable import NTSDCore
import NTSDReferenceChecks

/// Controlled raw 4122f0 corpora: preserve all existing game bytes/masks plus
/// original declared open/close/image order. This is not own application/CRT
/// buffering, Windows files or device execution.
final class OriginalLoadedCatalogFilesTests: XCTestCase {
    private func data(_ suffix: String) throws -> Data {
        let count: Int, sha: String
        switch suffix {
        case "":
            count = 95289959; sha = "8ff43ea70036d84dbbea5309387176595658b0246aa3ff5773e8e22d08f12dee"
        case "-raw-zero":
            count = 95252389; sha = "7c9c839ea3cea8733ddb4c4e8ec9218ee4b982dc1ca8df52632d381efa40dd40"
        case "-interleaved":
            count = 5383412; sha = "57d71e09189e52254d03b78d0c2f66cdbc1011acadb0e389c88968a30ed8419c"
        default: throw OriginalStateError.invalidStorage("Unknown retained file catalog")
        }
        return try OriginalLoadingFilesFixture.data("original-loaded-catalog-files" + suffix,
                                                    expectedCount: count, expectedSHA256: sha)
    }
    private func whole(_ suffix: String, checksum: UInt32) throws {
        var files: OriginalLoadingFiles?
        let result = try LoadedCatalogReference.compare(data(suffix), useLoadingFiles: true, onLoadingFiles: { files = $0 })
        XCTAssertEqual(result.objects, 137); XCTAssertEqual(result.backgrounds, 17)
        XCTAssertEqual(result.stages, 25); XCTAssertEqual(result.phases, 138)
        XCTAssertEqual(result.frames, 15388); XCTAssertEqual(result.bitmaps, 829)
        XCTAssertEqual(result.allocations, 14586); XCTAssertEqual(result.bytes, 112063739)
        XCTAssertEqual(result.checksum, checksum); XCTAssertEqual(result.fileEvents, 1242)
        XCTAssertEqual(result.weaponSoundAllocations, 130); XCTAssertEqual(result.weaponSoundBytes, 1700)
        XCTAssertEqual(try XCTUnwrap(files).decoderReturns, Array(repeating: 0, count: 155))
    }
    func testWholeTextCatalogThroughOwnedFiles() throws { try whole("", checksum: 31475378) }
    func testWholeRawCatalogThroughOwnedFiles() throws { try whole("-raw-zero", checksum: 31461560) }
    func testInterleavedDuplicateSourcesThroughOwnedFiles() throws {
        let result = try LoadedCatalogReference.compare(data("-interleaved"), useLoadingFiles: true)
        XCTAssertEqual(result.objects, 3); XCTAssertEqual(result.backgrounds, 2)
        XCTAssertEqual(result.stages, 25); XCTAssertEqual(result.phases, 138)
        XCTAssertEqual(result.frames, 720); XCTAssertEqual(result.bitmaps, 26)
        XCTAssertEqual(result.allocations, 744); XCTAssertEqual(result.bytes, 82089953)
        XCTAssertEqual(result.checksum, 1496213); XCTAssertEqual(result.fileEvents, 50)
        XCTAssertEqual(result.weaponSoundAllocations, 0); XCTAssertEqual(result.weaponSoundBytes, 0)
    }
    func testFinalStageCleanupFailureDoesNotPublishCatalogOrFiles() throws {
        enum Late: Error { case cleanup }
        var filesPublished = false, catalogPublished = false, closes = 0
        do {
            _ = try LoadedCatalogReference.compare(data("-interleaved"), useLoadingFiles: true, onFile: { event in
                if event.kind == .closeReadFile || event.kind == .closeOutputDescriptor { closes += 1 }
                if event.kind == .closeOutputDescriptor && event.arguments.last == 25 { throw Late.cleanup }
            }, onLoadingFiles: { _ in filesPublished = true }, onLoaded: { _ in catalogPublished = true })
            XCTFail("Expected the final Stage cleanup observer to reject the candidate")
        } catch Late.cleanup {}
        XCTAssertEqual(closes, 25)
        XCTAssertFalse(filesPublished); XCTAssertFalse(catalogPublished)
    }
    func testRepeatedWeaponPathAllocationsAndLateRollback() throws {
        struct Record: Decodable { let address: UInt32, initial: String, bytes: String, defined: String }
        struct Allocation: Decodable { let address: UInt32, size: Int, kind: String, caller: String }
        struct Case: Decodable { let id: Int32, type: Int32, decoded: String, storage: Record }
        struct Corpus: Decodable { let bitmapFill: UInt8, cases: [Case], allocations: [Allocation], regions: [Record], assetInputs: [OriginalBitmapInput] }
        func hex(_ s: String) throws -> [UInt8] {
            let b = Array(s.utf8);XCTAssertEqual(b.count%2, 0)
            return try stride(from: 0, to: b.count, by: 2).map { try XCTUnwrap(UInt8(String(decoding: b[$0..<$0+2], as: UTF8.self), radix: 16)) }
        }
        let data = try OriginalLoadingFilesFixture.data("original-loading-files-weapon-control", expectedCount: 3400976,
            expectedSHA256: "a55aa30fc50fafc885957c8682fb646820f12f4bf80db6cf493349917a4979de")
        let c = try JSONDecoder().decode(Corpus.self, from: data)
        let item = try XCTUnwrap(c.cases.first), initial = try hex(item.storage.initial)
        let text = try String(String.UnicodeScalarView(hex(item.decoded).map { UnicodeScalar($0) }))
        let expected = c.allocations.filter { ["0x40fbe6", "0x40fc65", "0x40fce8"].contains($0.caller) }
        XCTAssertEqual(expected.count, 2)
        let assets = Dictionary(uniqueKeysWithValues: c.assetInputs.map { ($0.path, $0) })
        func bitmap(_ path: String) throws -> OriginalBitmapInput { try XCTUnwrap(assets[path]) }
        var loader = OriginalObjectLoader(), requests = 0
        let result = try loader.load(decoded: text, id: item.id, type: item.type,
            headerBacking: Array(initial[..<0x7a4]), tailBacking: Array(initial.suffix(0x3c)), bitmapFill: c.bitmapFill,
            frameBacking: Array(initial[0x7a4..<initial.count-0x3c]), weaponSoundAllocation: { slot, count in
                guard expected.indices.contains(requests) else { throw OriginalStateError.invalidStorage("Extra weapon path allocation") }
                XCTAssertEqual(slot, 0);XCTAssertEqual(count, expected[requests].size)
                defer { requests += 1 };return expected[requests].address
            }, bitmapSource: bitmap)
        XCTAssertEqual(requests, expected.count);XCTAssertEqual(result.weaponSoundAllocations.count, expected.count)
        for (actual, allocation) in zip(result.weaponSoundAllocations, expected) {
            let r = try XCTUnwrap(c.regions.first { $0.address == allocation.address })
            XCTAssertEqual(actual.token, allocation.address);XCTAssertEqual(actual.slot, 0)
            XCTAssertEqual(actual.storage.bytes, try hex(r.bytes));XCTAssertEqual(actual.storage.defined, try hex(r.defined).map { $0 != 0 })
        }
        guard result.weaponSoundAllocations.count == 2 else { throw OriginalStateError.invalidStorage("Missing retained weapon path allocation") }
        XCTAssertNotEqual(result.weaponSoundAllocations[0].storage.bytes, result.weaponSoundAllocations[1].storage.bytes)
        XCTAssertEqual(result.weaponSoundPaths[0]?.unicodeScalars.map { UInt8($0.value) } ?? [], Array(result.weaponSoundAllocations[1].storage.bytes.dropLast()))
        enum Late: Error { case allocation }
        let previous = loader;var attempts = 0
        do {
            _ = try loader.load(decoded: text, id: item.id, type: item.type,
                headerBacking: Array(initial[..<0x7a4]), tailBacking: Array(initial.suffix(0x3c)), bitmapFill: c.bitmapFill,
                frameBacking: Array(initial[0x7a4..<initial.count-0x3c]), weaponSoundAllocation: { _, _ in
                    attempts += 1;if attempts == 2 { throw Late.allocation };return nil
                }, bitmapSource: bitmap)
            XCTFail("Late allocation observer should reject the Object candidate")
        } catch Late.allocation {}
        XCTAssertEqual(attempts, 2);XCTAssertEqual(loader.checksum, previous.checksum)
        XCTAssertEqual(loader.soundCount, previous.soundCount);XCTAssertEqual(loader.soundBytes, previous.soundBytes)
        XCTAssertEqual(loader.bitmaps, previous.bitmaps);XCTAssertEqual(loader.frameAllocations, previous.frameAllocations)
    }
}
