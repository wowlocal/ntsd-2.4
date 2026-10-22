/// Text the original reads as Latin-1 bytes, one Unicode scalar per byte
/// (MEMORY_LOADING L7). The same Strings and bytes as building them scalar by
/// scalar, without doing so: ASCII text (every DAT token and nearly every file)
/// converts as UTF-8 directly; other bytes are transcoded to UTF-8.
enum OriginalLatin1 {
    static func string<Bytes: Collection>(_ bytes: Bytes) -> String where Bytes.Element == UInt8 {
        if bytes.allSatisfy({ $0 < 0x80 }) { return String(decoding: bytes, as: UTF8.self) }
        var utf8: [UInt8] = []; utf8.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            if byte < 0x80 { utf8.append(byte) } else { utf8.append(0xc0 | byte >> 6); utf8.append(0x80 | byte & 0x3f) }
        }
        return String(decoding: utf8, as: UTF8.self)
    }
    /// The bytes of a String of scalars up to 255, or nil if another scalar occurs.
    static func bytes(_ text: String) -> [UInt8]? {
        if text.utf8.allSatisfy({ $0 < 0x80 }) { return Array(text.utf8) }
        guard text.unicodeScalars.allSatisfy({ $0.value <= 255 }) else { return nil }
        return text.unicodeScalars.map { UInt8($0.value) }
    }
}
