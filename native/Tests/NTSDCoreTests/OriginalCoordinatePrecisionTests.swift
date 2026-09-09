import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalCoordinatePrecisionTests: XCTestCase {
    private struct Case: Decodable {
        let label: String,operations: [String],inputs: [String],fpcw: UInt16,sse2: Bool,eax: UInt32,mxcsr: UInt32
    }
    private struct Corpus: Decodable {
        let exeSHA256: String,entry: UInt32,flag: UInt32,mxcsr: UInt32,callerSP: UInt32
        let arithmeticInstructions: [UInt32],conversionInstructions: [UInt32],cases: [Case]
    }
    private func bits(_ text: String) throws -> UInt64 {
        let bytes = Array(text.utf8);XCTAssertEqual(bytes.count,16)
        return try (0..<8).reduce(0) {
            $0 | (UInt64(try XCTUnwrap(UInt8(String(decoding: bytes[2*$1..<2*$1+2],as: UTF8.self),radix: 16))) << (8*$1))
        }
    }
    func testWholeLegacyAndSSE2AfterOriginalArithmetic() throws {
        let url: URL
        if let directory = ProcessInfo.processInfo.environment["NTSD_COORDINATE_PRECISION_DIRECTORY"] {
            url = URL(fileURLWithPath: directory).appendingPathComponent("coordinate-precision.json")
        } else {
            url = try XCTUnwrap(Bundle.module.url(forResource: "original-coordinate-precision",withExtension: "json",subdirectory: "Fixtures"))
        }
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(Data(contentsOf: url),maximumCount: 64_000_000))
        XCTAssertEqual(c.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        XCTAssertEqual(c.entry,0x4450d0);XCTAssertEqual(c.flag,0x45971c)
        XCTAssertEqual(c.mxcsr,0x1f80);XCTAssertEqual(c.callerSP,0x24001003)
        XCTAssertEqual(c.cases.count,63006);XCTAssertEqual(Set(c.conversionInstructions).count,47)
        XCTAssertTrue(Set([0x4450d0,0x4450e2,0x4450e5,0x445106,0x445115,0x445129,0x445165,0x44517a]).isSubset(of: Set(c.conversionInstructions)))
        XCTAssertEqual(Set(c.arithmeticInstructions),Set([0x40e51d,0x40e520,0x40e523,0x4307be,0x40e556,0x408425,0x419791]))
        for word: UInt16 in [0x7f,0x27f,0x37f] {
            for sse2 in [false,true] { XCTAssertEqual(c.cases.filter { $0.fpcw == word && $0.sse2 == sse2 }.count,10501) }
        }
        for item in c.cases {
            let precision = try OriginalArithmeticPrecision(controlWord: item.fpcw)
            let values = try item.inputs.map { Double(bitPattern: try bits($0)) }
            var result = try OriginalExtended(XCTUnwrap(values.first),precision: precision),operand = 1
            for operation in item.operations {
                if operation == "store-load" {
                    result = try OriginalExtended(result.double,precision: precision)
                    continue
                }
                let other = try OriginalExtended(values[operand],precision: precision)
                switch operation {
                case "add":result = result + other
                case "subtract":result = result - other
                case "multiply":result = result * other
                case "divide":result = result / other
                default:XCTFail("Unknown conversion prefix "+operation);return
                }
                operand += 1
            }
            let actual = UInt32(bitPattern: OriginalCoordinateConversion.integer(result,sse2: item.sse2))
            guard actual == item.eax else {
                XCTFail("\(item.label) CW\(String(item.fpcw,radix:16)) SSE2\(item.sse2) got\(String(actual,radix:16)) expected\(String(item.eax,radix:16))")
                return
            }
            if item.operations.isEmpty {
                XCTAssertEqual(UInt32(bitPattern: OriginalCoordinateConversion.integer(values[0],sse2: item.sse2)),item.eax,item.label)
            }
            XCTAssertEqual(item.mxcsr & ~0x3f,0x1f80,item.label)
        }
        print("COORDINATE PRECISION",c.cases.count,"whole original conversions compared")
    }
}
