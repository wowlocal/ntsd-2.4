import Foundation

/// Owned cursor for the target's custom 414520/414920 scanner. It has no CRT
/// translation, implicit EOF terminator or baseline scanf fallback.
public struct NTSD2833TokenStream: Sendable {
    public enum Boundary: Error, Equatable {
        case readOutsideBuffer(offset: Int, count: Int)
        case closed
    }
    public struct StringRead: Equatable, Sendable {
        public let bytes: [UInt8]
        public let before: Int, after: Int
        /// 41455c copies the token, then 414560 stores a whole zero dword.
        public var terminatedBytes: [UInt8] { bytes + [0, 0, 0, 0] }
        public var cStringBytes: [UInt8] { Array(bytes.prefix(while: { $0 != 0 })) }
    }
    public struct IntegerRead: Equatable, Sendable {
        public let bits: UInt32
        public let before: Int, after: Int
        public var value: Int32 { Int32(bitPattern: bits) }
    }
    private var bytes: [UInt8]
    public let byteCount: Int
    public private(set) var cursorOffset: Int
    public private(set) var isClosed = false

    public init(_ file: NTSD2833FileBytes) {
        bytes = file.storage; byteCount = file.endOffset; cursorOffset = file.cursorOffset
    }
    private func read(at offset: Int) throws -> UInt8 {
        guard !isClosed else { throw Boundary.closed }
        guard offset >= 0, offset < byteCount else {
            throw Boundary.readOutsideBuffer(offset: offset, count: byteCount)
        }
        return bytes[offset]
    }
    private static func whitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x0a || byte == 0x0d || byte == 0x09
    }
    public mutating func readString() throws -> StringRead {
        let before = cursorOffset
        var start = before
        while Self.whitespace(try read(at: start)) { start += 1 }
        var end = start
        while true {
            if Self.whitespace(try read(at: end)) { break }
            end += 1
            if end >= byteCount { break }
        }
        // The source cursor stops before a delimiter, at the buffer end for a
        // last token. A later scanner/EOF call sees the delimiter again.
        cursorOffset = end
        return .init(bytes: Array(bytes[start..<end]), before: before, after: end)
    }
    public func isAtEnd() throws -> Bool {
        guard !isClosed else { throw Boundary.closed }
        if cursorOffset >= byteCount { return true }
        var probe = cursorOffset
        // The source checks the end only before this loop. Trailing whitespace
        // can read beyond the declared file. Preserve that unsupported boundary;
        // appending a NUL or treating it as ordinary EOF would change the rule.
        while Self.whitespace(try read(at: probe)) { probe += 1 }
        return false
    }
    /// Actual414570..4145d0. Nondigits are ignored, only a leading minus sets
    /// sign, and accumulation/negation wrap32 bits. The next byte is loaded
    /// before the end test: a one-byte final number can read beyond the buffer;
    /// a last loaded byte at the end is not accumulated. This is not scanf.
    public mutating func readInteger() throws -> IntegerRead {
        let before = cursorOffset
        var position = before
        while Self.whitespace(try read(at: position)) { position += 1 }
        var current = try read(at: position)
        position += 1
        let negative = current == 0x2d
        if negative { current = try read(at: position); position += 1 }
        var value: UInt32 = 0
        while true {
            if current >= 0x30 && current <= 0x39 {
                value = value &* 10 &+ UInt32(current - 0x30)
            }
            current = try read(at: position)
            position += 1
            if Self.whitespace(current) { break }
            if position >= byteCount { position += 1; break }
        }
        position -= 1
        if negative { value = 0 &- value }
        cursorOffset = position
        return .init(bits: value, before: before, after: position)
    }
    public mutating func close() {
        bytes.removeAll(keepingCapacity: false)
        isClosed = true
    }
}
