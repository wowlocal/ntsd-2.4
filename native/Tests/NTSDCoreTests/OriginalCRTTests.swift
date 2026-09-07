import Foundation
import XCTest
@testable import NTSDCore

final class OriginalCRTTests: XCTestCase {
    private struct Corpus: Decodable {
        let dllSHA256: String
        let cases: [Case]
    }
    private struct Case: Decodable {
        let input, format: String
        let result, position, errno: Int
        let eof: Bool
        let outputs: [String]
    }

    func testIntegersAgainstMicrosoftInstructions() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_CRT_CORPUS"] {
            url = URL(fileURLWithPath: path)
        } else {
            url = try XCTUnwrap(Bundle.module.url(forResource: "original-crt-integers", withExtension: "json", subdirectory: "Fixtures"))
        }
        let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
        XCTAssertEqual(corpus.dllSHA256, "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        XCTAssertGreaterThan(corpus.cases.count, 5000)
        for item in corpus.cases {
            let bytes = stride(from: 0, to: item.input.count, by: 2).map { offset -> UInt8 in
                let start = item.input.index(item.input.startIndex, offsetBy: offset)
                return UInt8(item.input[start..<item.input.index(start, offsetBy: 2)], radix: 16)!
            }
            var scanner = try OriginalFrameScanner(String(String.UnicodeScalarView(bytes.map { UnicodeScalar($0) })))
            var outputs = Array(repeating: "", count: 8)
            var assignments = 0
            for spec in item.format.split(separator: " ") {
                XCTAssertTrue(spec == "%d" || spec == "%ld")
                guard let value = try scanner.integer() else { break }
                let bits = UInt32(bitPattern: value)
                outputs[assignments] = (0..<4).map { String(format: "%02x", (bits >> ($0*8)) & 255) }.joined()
                assignments += 1
            }
            let label = "\(item.format), bytes \(item.input.prefix(100))"
            XCTAssertEqual(outputs, item.outputs, label)
            XCTAssertEqual(scanner.position, item.position, label)
            XCTAssertEqual(scanner.eof, item.eof, label)
            XCTAssertEqual(assignments == 0 && scanner.eof ? -1 : assignments, item.result, label)
            XCTAssertEqual(item.errno, 0, label)
        }
    }
}
