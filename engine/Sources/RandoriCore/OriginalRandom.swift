import Foundation

/// Original 0x417170. Table bytes come from original initialization or replay;
/// its index/counter are separate from OriginalCRTRandom's per-thread state.
public struct OriginalRandom: Codable, Equatable, Sendable {
    public let table: [UInt8]
    public private(set) var index: Int
    public private(set) var counter: Int
    public let source: String
    public let sourceSHA256: String

    public func validate() throws {
        // `!table.contains(0)` with memchr: the same answer, vectorized (the AI
        // pass validates the table at every draw; CORE_REALTIME tier 3 R0).
        guard table.count == 3000, table.withUnsafeBufferPointer({ memchr($0.baseAddress!, 0, $0.count) == nil }),
              (0..<3000).contains(index),
              (0..<1234).contains(counter) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Invalid original replay RNG state")
        }
    }
    /// The 3000-byte table at `offset` of `record`, exactly what reading its
    /// bytes one at a time with `integer(at:as: UInt8.self)` returns: one copy
    /// when every byte is in range and defined (CORE_REALTIME 4e), otherwise
    /// those reads, so the first failing byte throws the same error.
    public static func table(_ record: OriginalStateRecord, at offset: Int) throws -> [UInt8] {
        if let bytes = record.definedBytes(offset, 3000) { return bytes }
        return try (0..<3000).map { try record.integer(at: offset+$0, as: UInt8.self) }
    }
    public mutating func next(_ range: Int) -> Int {
        guard range > 0 else { return 0 }
        counter = (counter + 1) % 1234
        index = (index + 1) % 3000
        return (Int(table[index]) + counter) % range
    }
}
