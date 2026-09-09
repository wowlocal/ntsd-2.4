import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalArithmeticPrecisionTests: XCTestCase {
    private struct Case: Decodable { let label: String,operations: [String],inputs: [String],fpcw: UInt16,result: String }
    private struct Corpus: Decodable { let exeSHA256: String,instructions: [UInt32],cases: [Case] }
    private func bits(_ text: String) throws -> UInt64 {
        let bytes = Array(text.utf8);XCTAssertEqual(bytes.count,16)
        return try (0..<8).reduce(0) { $0 | (UInt64(try XCTUnwrap(UInt8(String(decoding: bytes[2*$1..<2*$1+2],as: UTF8.self),radix: 16))) << (8*$1)) }
    }
    func testOriginalArithmeticAtAllPrecisions() throws {
        let url: URL
        if let directory = ProcessInfo.processInfo.environment["NTSD_PRECISION_DIRECTORY"] { url = URL(fileURLWithPath: directory).appendingPathComponent("arithmetic-precision.json") }
        else { url = try XCTUnwrap(Bundle.module.url(forResource: "original-arithmetic-precision",withExtension: "json",subdirectory: "Fixtures")) }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 64_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(Set(c.instructions),Set([0x40e51d,0x40e520,0x4307be,0x40e556,0x408425,0x40e523,0x419791]))
        XCTAssertEqual(c.cases.count,54201)
        for item in c.cases {
            let precision = try OriginalArithmeticPrecision(controlWord: item.fpcw)
            let values = try item.inputs.map { try OriginalExtended(Double(bitPattern: bits($0)),precision: precision) }
            var result = try XCTUnwrap(values.first)
            for (n,op) in item.operations.enumerated() {
                switch op {
                case "add":result = result+values[n+1]
                case "subtract":result = result-values[n+1]
                case "multiply":result = result*values[n+1]
                case "divide":result = result/values[n+1]
                default:XCTFail("Unknown source operation "+op);return
                }
            }
            let expected = try bits(item.result)
            if result.double.bitPattern != expected {
                XCTFail(item.label+" CW\(String(item.fpcw,radix:16)) got\(String(result.double.bitPattern,radix:16)) expected\(String(expected,radix:16))");return
            }
        }
        print("ARITHMETIC PRECISION",c.cases.count,"original instruction sequences compared")
    }
    func testControlWordDecodingRejectsUnrecoveredModes() throws {
        for word: UInt16 in [0,0x7f] { XCTAssertEqual(try OriginalArithmeticPrecision(controlWord: word),.bits24) }
        for word: UInt16 in [0x200,0x23f,0x27f] { XCTAssertEqual(try OriginalArithmeticPrecision(controlWord: word),.bits53) }
        XCTAssertEqual(try OriginalArithmeticPrecision(controlWord: 0x37f),.bits64)
        for word: UInt16 in [0x17f,0x47f,0x87f,0xc7f] { XCTAssertThrowsError(try OriginalArithmeticPrecision(controlWord: word)) }
    }
}
