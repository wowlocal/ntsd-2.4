import XCTest
@testable import NTSDCore

/// CORE_REALTIME 4e: `OriginalRandom.table` returns what reading the 3000
/// bytes one at a time returned, and throws the same first error.
final class OriginalRandomTableTests: XCTestCase {
    static func perByte(_ record: OriginalStateRecord,_ offset: Int) throws -> [UInt8] {
        try (0..<3000).map { try record.integer(at: offset+$0, as: UInt8.self) }
    }
    func same(_ record: OriginalStateRecord,_ offset: Int,_ label: String,file: StaticString = #filePath,line: UInt = #line) {
        func outcome(_ body: () throws -> [UInt8]) -> String {
            do { return "value \(try body())" } catch { return "error \(error)" }
        }
        XCTAssertEqual(outcome { try OriginalRandom.table(record, at: offset) },outcome { try Self.perByte(record, offset) },
                       label,file: file,line: line)
    }
    func record(_ count: Int,undefined: [Int] = []) throws -> OriginalStateRecord {
        var defined = [Bool](repeating: true, count: count)
        for i in undefined { defined[i] = false }
        return try .init(bytes: (0..<count).map { UInt8(truncatingIfNeeded: $0 &* 131 &+ 7) }, defined: defined)
    }
    func testTableEqualsTheByteReads() throws {
        let base = 0x44ff90-0x44d000
        let flat = try record(OriginalMatchPreparation.globalSize)
        same(flat, base, "defined")
        XCTAssertEqual(try OriginalRandom.table(flat, at: base), Array(flat.bytes[base..<base+3000]))
        for i in [0, 1, 1499, 2998, 2999] { same(try record(OriginalMatchPreparation.globalSize, undefined: [base+i]), base, "undefined \(i)") }
        same(try record(OriginalMatchPreparation.globalSize, undefined: [base+3000, base-1]), base, "undefined just outside")
        same(try record(OriginalMatchPreparation.globalSize, undefined: [base+2000, base+10]), base, "two undefined")
        same(flat, flat.byteCount-3000, "ends at the last byte")
        same(flat, flat.byteCount-2999, "one byte past the end")
        same(flat, flat.byteCount, "starts at the end")
        same(flat, -1, "negative offset")
        same(try record(2999), 0, "record shorter than the table")
        same(try record(0), 0, "empty record")
        // Paged records (the replay buffers' representation) take the same checks.
        let paged = try record(OriginalStateRecord.pagedThreshold+0x1000, undefined: [0x123456+700])
        same(paged, 0x123456, "paged, one undefined")
        same(paged, 0x200000, "paged, defined")
        same(paged, (1 << 14)-1000, "paged, across a page boundary")
        same(paged, paged.byteCount-100, "paged, past the end")
    }
}
