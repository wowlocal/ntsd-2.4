import Foundation
import XCTest
@testable import NTSDReferenceChecks

/// Additional immutable inputs for owned file loading. The complete catalog
/// envelopes retain the original raw JSON bytes, including all scan records;
/// the explicitly named first-Object fixture is a file-only projection.
enum OriginalLoadingFilesFixture {
    private struct Envelope: Decodable { let count: Int, sha256: String, deflate: String }

    static func data(_ name: String, expectedCount: Int, expectedSHA256: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: url))
        XCTAssertEqual(envelope.count, expectedCount)
        XCTAssertEqual(envelope.sha256, expectedSHA256)
        let bytes = try MatchPreparationReference.inflate(envelope.deflate, count: expectedCount, maximumCount: 100_000_000)
        let raw = Data(bytes)
        XCTAssertEqual(MatchPreparationReference.digest(raw), expectedSHA256)
        return raw
    }
}
