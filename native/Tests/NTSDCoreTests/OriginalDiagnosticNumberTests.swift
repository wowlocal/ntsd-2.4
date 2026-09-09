import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalDiagnosticNumberTests: XCTestCase {
    private struct Intermediate: Decodable {
        let negative: Bool, finite: Bool, decimalPosition: Int, digits: String
    }
    private struct Case: Decodable {
        let bits: String, precision: Int, output: String, intermediate: Intermediate, fpswAfter: UInt16
    }
    private struct Corpus: Decodable {
        let exeSHA256: String, dllSHA256: String, fpcw: UInt16, tables: [[String]], cases: [Case]
    }
    func testOriginalFixedDiagnosticFormatsAndDecimalIntermediate() throws {
        let url: URL
        if let path = ProcessInfo.processInfo.environment["NTSD_DIAGNOSTIC_NUMBERS_CORPUS"] { url = URL(fileURLWithPath: path) }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-diagnostic-numbers", withExtension: "json", subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self, from: MatchPreparationReference.unpack(Data(contentsOf: url), maximumCount: 128_000_000))
        XCTAssertEqual(c.exeSHA256, "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.dllSHA256, "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d")
        XCTAssertEqual(c.fpcw, 0x23f); XCTAssertEqual(c.tables, OriginalDiagnosticNumber.tableHex)
        XCTAssertEqual(c.cases.count, 74424)
        for item in c.cases {
            let bits = try XCTUnwrap(UInt64(item.bits, radix: 16)), expected = item.intermediate
            XCTAssertEqual(item.fpswAfter, 0)
            let actual = OriginalDiagnosticNumber.intermediate(bits: bits)
            guard actual == .init(negative: expected.negative, finite: expected.finite,
                                 decimalPosition: expected.decimalPosition, digits: Array(expected.digits.utf8)) else {
                return XCTFail("Decimal intermediate \(item.bits): \(actual)")
            }
            let output = try OriginalDiagnosticNumber.fixed(bits: bits, fractionDigits: item.precision)
            guard output == Array(item.output.utf8) else {
                return XCTFail("Fixed \(item.bits)/\(item.precision): \(String(decoding: output, as: UTF8.self)) vs \(item.output)")
            }
        }
        print("DIAGNOSTIC NUMBERS", c.cases.count, "whole sprintf outputs and decimal intermediates compared")
    }
}
