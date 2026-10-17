import Foundation
import CryptoKit
import XCTest
import NTSDCore
import NTSDRuntime

@MainActor final class NTSD2833FileBytesTests: XCTestCase {
    struct Fixture: Decodable {
        struct Case: Decodable {
            struct Input: Decodable { let inputHex: String?, count: Int, sha256: String, fileNameHex: String }
            let id: String, input: Input, outcome: String, decodedBufferHex: String, cursorOffset: Int
            let returnedESP: UInt32, expectedReturnedESP: UInt32, preservedRegisters: Bool
            let bufferWrites: Int, ascendingSingleByteWrites: Bool, filenameUnchanged: Bool, keyUnchanged: Bool
        }
        let cases: [Case]
    }
    var native: URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }
    func hex(_ value: String) throws -> [UInt8] {
        let bytes = Array(value.utf8)
        guard bytes.count%2 == 0 else { throw CocoaError(.fileReadCorruptFile) }
        return try stride(from:0,to:bytes.count,by:2).map {
            guard let byte = UInt8(String(decoding:bytes[$0..<$0+2],as:UTF8.self),radix:16) else { throw CocoaError(.fileReadCorruptFile) }
            return byte
        }
    }
    func fixture() throws -> Fixture {
        // A regular source-produced fixture, independent of the Native decoder.
        let url = native.appendingPathComponent("Tests/NTSDCoreTests/Fixtures/ntsd-2.8.3.3-file-buffer1.json")
        return try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:url))
    }
    func raw(_ c: Fixture.Case) throws -> [UInt8] {
        let bytes: [UInt8]
        if let value = c.input.inputHex { bytes = try hex(value) }
        else {
            let name = String(decoding:try hex(c.input.fileNameHex),as:UTF8.self).replacingOccurrences(of:"\\",with:"/")
            bytes = Array(try Data(contentsOf:native.appendingPathComponent("TargetInputs/NTSD2833Partial/"+name)))
        }
        XCTAssertEqual(bytes.count,c.input.count)
        XCTAssertEqual(SHA256.hash(data:Data(bytes)).map { String(format:"%02x",$0) }.joined(),c.input.sha256)
        return bytes
    }
    func testCompleteSourceRoutineBuffersAndCursorOffsets() throws {
        let f = try fixture();XCTAssertEqual(f.cases.count,20)
        var returned = 0
        for c in f.cases where c.outcome == "returned" {
            let before = try raw(c),name = try hex(c.input.fileNameHex)
            let input = try NTSD2833FileBytes(raw:before,fileName:name)
            XCTAssertEqual(input.storage,try hex(c.decodedBufferHex),c.id)
            XCTAssertEqual(input.cursorOffset,c.cursorOffset,c.id)
            XCTAssertEqual(input.endOffset,before.count)
            XCTAssertEqual(input.logicalBytes,Array(input.storage.dropFirst(c.cursorOffset)))
            XCTAssertEqual(input.isAtEnd,c.cursorOffset >= before.count)
            XCTAssertEqual(before,try raw(c),"Raw ownership remains unchanged")
            XCTAssertEqual(c.returnedESP,c.expectedReturnedESP)
            XCTAssertTrue(c.preservedRegisters && c.ascendingSingleByteWrites && c.filenameUnchanged && c.keyUnchanged)
            XCTAssertEqual(c.bufferWrites,c.cursorOffset == 123 ? before.count : 0)
            returned += 1
        }
        XCTAssertEqual(returned,18)
    }
    func testSourceReadBoundariesRemainSeparateFromNativeRejections() throws {
        let cases = try fixture().cases.filter { $0.outcome != "returned" }
        XCTAssertEqual(Set(cases.map(\.id)),["empty-dat","short-name"])
        for c in cases {
            XCTAssertEqual(c.outcome,"unsupported-input-read","A controlled read boundary is not Windows fault evidence")
            let before = try raw(c)
            XCTAssertThrowsError(try NTSD2833FileBytes(raw:before,fileName:hex(c.input.fileNameHex))) {
                XCTAssertEqual($0 as? NTSD2833FileBytes.Boundary,c.id == "empty-dat" ? .emptyDATBuffer : .filenameExtent)
            }
            XCTAssertEqual(before,try raw(c))
        }
    }
    func testRealContentOwnerSuppliesAllNineDecodedFilesWithoutBaselineFallback() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-target-decoded-\(UUID().uuidString)")
        let content = try OriginalRuntimeContentInputs.targetPartial(directory:native.appendingPathComponent("TargetInputs/NTSD2833Partial"),writableParent:parent)
        for c in try fixture().cases where c.id.hasPrefix("ordinary-") {
            let name = String(decoding:try hex(c.input.fileNameHex),as:UTF8.self).replacingOccurrences(of:"\\",with:"/")
            let original = try content.rawTargetFile(name),owned = try content.decodedTargetFile(name)
            XCTAssertEqual(owned.storage,try hex(c.decodedBufferHex),name)
            XCTAssertEqual(owned.cursorOffset,c.cursorOffset)
            var changed = owned.storage;changed[0] ^= 1
            XCTAssertEqual(try content.rawTargetFile(name),original)
            XCTAssertEqual(try content.decodedTargetFile(name),owned)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath:parent.path))
        XCTAssertThrowsError(try content.decodedTargetFile("m/ton/ton.dat"))
        XCTAssertThrowsError(try OriginalRuntimeContentInputs.baseline().decodedTargetFile("data/data.txt"))
        XCTAssertThrowsError(try content.acquireStartup())
    }
}
