import Foundation
import XCTest
@testable import NTSDCore

/// Preservation of the pre-optimization Native implementation, not a new CRT
/// oracle. OriginalCatalogPrecisionTests remains the actual-DAT reference.
/// In particular the known original/Native incomplete-exponent gap stays open.
final class OriginalDecimalMaterializationTests: XCTestCase {
    private enum Stop: Error { case read }
    private enum Outcome: Equatable { case value(UInt64?), failure(String) }
    private func outcome(_ body: () throws -> Double?) -> Outcome {
        do { return .value(try body()?.bitPattern) }
        catch { return .failure(String(reflecting:error)) }
    }
    private struct PriorScanner {
        let bytes: [UInt8]
        var position = 0, eof = false
        let observeRead: ((Int) throws -> Void)?
        mutating func skipSpace() {
            while position < bytes.count && (bytes[position] == 32 || (9...13).contains(bytes[position])) { position += 1 }
        }
        // Frozen parent binary64 body, reindented without changing statements.
        mutating func binary64() throws -> Double? {
            skipSpace()
            let suffix = String(String.UnicodeScalarView(bytes[position...].map { UnicodeScalar($0) }))
            guard let range = suffix.range(of: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"#, options: .regularExpression) else { try observeRead?(position); return nil }
            let literal = String(suffix[range])
            guard let value = Double(literal), value.isFinite else {
                throw OriginalLoaderError.outsideVerifiedDomain("Non-finite decimal is outside the object-loader domain")
            }
            position += literal.utf8.count
            if position == bytes.count { eof = true }
            try observeRead?(position)
            return value
        }
    }
    func testMaterializationPreservesExistingNativeReadProtocol() throws {
        var cases = [
            "",
            " \t\n\r\u{b}\u{c}",
            "+",
            "-",
            ".",
            "+.",
            "-.",
            "e10",
            "0",
            "-0",
            "+0",
            "1.",
            ".5",
            "-.5",
            "+1e2",
            "1e",
            "1e+",
            "1e-",
            "1e+2",
            "1e-2",
            "1..2",
            "1e2e3",
            "1+2",
            "1-2",
            "1.25 3.5",
            "-0\t2e3",
            "nan",
            "inf",
            "-infinity",
            "0x1p2",
            "1e309",
            "-1e309",
            "1e-9999",
            "2.2250738585072014e-308",
            "4.9406564584124654e-324",
            "1.7976931348623157e308",
            "nope\n12.5",
            "1.00000000000000011102230246251565404236316680908203125"
        ]
        cases += [String(repeating:"9",count:1024),String(repeating:"0",count:1024)+"1",
                  "7.125 "+String(repeating:"tail ",count:16000)]
        for byte in UInt16(0)...255 {
            let scalar = String(UnicodeScalar(UInt8(byte)))
            cases.append(scalar+"12.5e-2 tail")
            cases.append(" \t-12.5e+2"+scalar+"tail")
        }
        XCTAssertEqual(cases.count,553)
        var readsChecked = 0
        for (index,text) in cases.enumerated() {
            XCTAssertTrue(text.unicodeScalars.allSatisfy { $0.value <= 255 })
            for throwsOnRead in [false,true] {
                var priorReads: [Int] = [],nativeReads: [Int] = []
                var prior = PriorScanner(bytes:text.unicodeScalars.map { UInt8($0.value) },observeRead:{ value in
                    priorReads.append(value);if throwsOnRead { throw Stop.read }
                })
                var native = try OriginalFrameScanner(text,observeRead:{ value in
                    nativeReads.append(value);if throwsOnRead { throw Stop.read }
                })
                for step in 0..<2 {
                    let label = "control \(index), observer throws \(throwsOnRead), step \(step)"
                    let expected = outcome { try prior.binary64() }
                    let actual = outcome { try native.binary64() }
                    XCTAssertEqual(actual,expected,label)
                    XCTAssertEqual(native.position,prior.position,label)
                    XCTAssertEqual(native.eof,prior.eof,label)
                    XCTAssertEqual(nativeReads,priorReads,label)
                    readsChecked += 1
                }
            }
        }
        XCTAssertEqual(readsChecked,2212)
        print("Native decimal materialization",cases.count,"texts,",readsChecked,"paired sequential reads; no new CRT-domain claim")
    }
}
