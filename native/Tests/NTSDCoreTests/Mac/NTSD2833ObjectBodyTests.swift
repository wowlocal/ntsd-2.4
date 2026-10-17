import Foundation
import CryptoKit
import XCTest
import NTSDCore
import NTSDRuntime
import NTSDReferenceChecks

@MainActor final class NTSD2833ObjectBodyTests: XCTestCase {
    private var native: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }
    private func prepared(name: [UInt8] = Array("owned-unit.txt".utf8)) throws -> NTSD2833ObjectStorage {
        var record = try OriginalStateRecord(
            bytes: Array(repeating: 0xa5, count: NTSD2833ObjectStorage.allocationSize),
            defined: Array(repeating: false, count: NTSD2833ObjectStorage.allocationSize))
        let fields: [(Int, UInt32)] = [(0, 30), (0x18, 7), (0x704, 0), (0x740, 0),
                                       (0x748, 0), (0x714, 0), (0x7a8, 0x23000000)]
        for (offset, value) in fields {
            try record.write(value, at: offset)
        }
        return try .init(storage: record, fileName: name)
    }
    func testWholeConstructorAndRepeatedOwnersMatchSource() throws {
        let data = try Data(contentsOf: native.appendingPathComponent("Tests/NTSDCoreTests/Fixtures/ntsd-2.8.3.3-object-body1.json"))
        XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                       "1fe018d88e54061c9a3494f853d6442a2fcec6e8165e12a72e3ea9d886951d89")
        let result = try NTSD2833ObjectReference.compare(data)
        XCTAssertEqual(result.cases, 4)
        XCTAssertEqual(result.calls, 6)
        XCTAssertEqual(result.postCallBytes, 2_601_984)
        XCTAssertEqual(result.sourceBoundaries, 0)
    }
    func testLoadingHelperThresholdKeepsSourceBoundarySeparateFromNativeRollback() throws {
        let data = try Data(contentsOf: native.appendingPathComponent("Tests/NTSDCoreTests/Fixtures/ntsd-2.8.3.3-object-body-counter1.json"))
        XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                       "f64fd21cbf27410fed693628bce0e7c65cba0a4a18d48c105a9b49f1fea54697")
        let result = try NTSD2833ObjectReference.compare(data)
        XCTAssertEqual(result.cases, 2)
        XCTAssertEqual(result.calls, 1, "Only the31-token source call returned")
        XCTAssertEqual(result.sourceBoundaries, 1, "The32-token source stopped before425010; Native rollback is not a return match")
        XCTAssertEqual(result.postCallBytes, 433_664)
    }
    func testCursorDelimiterAndTerminatorOwnership() throws {
        let input = Array(" \ta\r\nbc".utf8)
        let file = try NTSD2833FileBytes(raw: input, fileName: Array("owned-unit.txt".utf8))
        var stream = NTSD2833TokenStream(file)
        let first = try stream.readString()
        XCTAssertEqual(first.bytes, [0x61])
        XCTAssertEqual(first.terminatedBytes, [0x61, 0, 0, 0, 0], "Actual scanner STOSD terminator")
        XCTAssertEqual(first.before, 0)
        XCTAssertEqual(first.after, 3)
        XCTAssertFalse(try stream.isAtEnd())
        XCTAssertEqual(stream.cursorOffset, 3, "EOF peeks without advancing the owner")
        let second = try stream.readString()
        XCTAssertEqual(second.bytes, [0x62, 0x63])
        XCTAssertEqual(second.before, 3)
        XCTAssertEqual(second.after, 7)
        XCTAssertTrue(try stream.isAtEnd())
        stream.close()
        XCTAssertTrue(stream.isClosed)
        XCTAssertThrowsError(try stream.readString()) { XCTAssertEqual($0 as? NTSD2833TokenStream.Boundary, .closed) }
        XCTAssertThrowsError(try stream.isAtEnd()) { XCTAssertEqual($0 as? NTSD2833TokenStream.Boundary, .closed) }
        XCTAssertEqual(file.storage, input)
    }
    func testFailedCandidatesRollbackAndFrameViewsKeepOwnedBacking() throws {
        var object = try prepared()
        let file = try NTSD2833FileBytes(raw: Array("noop".utf8), fileName: object.fileName)
        let receipt = try object.loadBody(file)
        XCTAssertEqual(receipt.liveStreamOwners, 0)
        let before = object.storage
        for text in ["", "noop\n", "<frame> 0 idle"] {
            let rejected = try NTSD2833FileBytes(raw: Array(text.utf8), fileName: object.fileName)
            XCTAssertThrowsError(try object.loadBody(rejected))
            XCTAssertEqual(object.storage, before, "Native rollback is separate from source boundary/fault matching")
            XCTAssertEqual(rejected.storage, Array(text.utf8))
        }
        let view = try object.frameStorage(at: 0)
        let snapshot = object
        try object.writeIncomingWord(42, at: 0x838)
        XCTAssertEqual(try object.frameState(at: 0), 42)
        XCTAssertEqual(try view.integer(at: 8, as: Int32.self), 0)
        XCTAssertEqual(try snapshot.frameState(at: 0), 0)
        XCTAssertEqual(try object.frameState(at: 998), 0)
        XCTAssertThrowsError(try object.frameStorage(at: 999)) {
            XCTAssertEqual($0 as? NTSD2833ObjectStorage.Boundary, .frameOutsideAllocation(999))
        }
        try object.loadBody(file)
        XCTAssertEqual(try object.frameState(at: 0), 0)
    }
    func testRealTargetContentOwnerContinuesIntoCheckedStorageAndKeepsResourceGate() throws {
        let name = "custom/1genma/genma.dat"
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("ntsd-target-object-\(UUID().uuidString)")
        let owner = try OriginalRuntimeContentInputs.targetPartial(
            directory: native.appendingPathComponent("TargetInputs/NTSD2833Partial"), writableParent: parent)
        var object = try prepared(name: Array(name.replacingOccurrences(of: "/", with: "\\").utf8))
        let before = object.storage, raw = try owner.rawTargetFile(name)
        XCTAssertThrowsError(try owner.loadTargetObjectBody(name, into: &object)) {
            XCTAssertEqual($0 as? NTSD2833ObjectStorage.Boundary, .unsupportedOuterTag(Array("<bmp_begin>".utf8)))
        }
        XCTAssertEqual(object.storage, before)
        XCTAssertEqual(try owner.rawTargetFile(name), raw)
        XCTAssertThrowsError(try owner.loadTargetObjectBody("m/ton/ton.dat", into: &object))
        XCTAssertEqual(object.storage, before)
        XCTAssertThrowsError(try OriginalRuntimeContentInputs.baseline().loadTargetObjectBody(name, into: &object))
        XCTAssertEqual(object.storage, before)
        XCTAssertFalse(FileManager.default.fileExists(atPath: parent.path))
        XCTAssertThrowsError(try owner.acquireStartup())
    }
}
