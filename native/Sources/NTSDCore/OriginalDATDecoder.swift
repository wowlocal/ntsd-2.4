import Foundation

/// Explicit stdio boundary selection. `.text` models Microsoft's documented
/// CRLF/CTRL-Z contract; `.raw` reproduces the earlier oracle's untranslated bytes.
/// Neither mode by itself proves which concrete MSVCR80 installation ran the game.
public enum OriginalFileTranslation: String, Codable, Sendable {
    case text, raw

    func read(_ bytes: [UInt8]) -> [UInt8] {
        guard self == .text else { return bytes }
        var output: [UInt8] = [], index = 0
        while index < bytes.count, bytes[index] != 0x1a {
            if bytes[index] == 13, index + 1 < bytes.count, bytes[index + 1] == 10 { index += 1 }
            output.append(bytes[index]); index += 1
        }
        return output
    }
    func write(_ bytes: [UInt8]) -> [UInt8] {
        guard self == .text else { return bytes }
        return bytes.flatMap { $0 == 10 ? [13, 10] : [$0] }
    }
}

public enum OriginalDATDecoder {
    private static let key = Array("SiuHungIsAGoodBearBecauseHeIsVeryGood".utf8)
    static func byte(_ value: UInt8, at position: Int) -> UInt8 {
        value &- key[position % key.count]
    }

    static func encrypted(_ fileName: String) throws -> Bool {
        guard fileName.unicodeScalars.allSatisfy({ $0.value <= 255 }), fileName.unicodeScalars.count >= 3 else {
            throw OriginalLoaderError.outsideVerifiedDomain("Original filename suffix domain")
        }
        return Array(fileName.unicodeScalars.suffix(3).map { UInt8($0.value) | 0x20 }) == Array("dat".utf8)
    }
    /// 40f0c2..40f124 chooses by the last three filename bytes, without checking
    /// for a dot or a plaintext marker. 4148a0 advances the key during all 123
    /// skipped header bytes, then writes through a temporary text-mode stream.
    public static func decode(_ source: [UInt8], fileName: String, translation: OriginalFileTranslation) throws -> String {
        let encrypted = try encrypted(fileName)
        guard !source.starts(with: Array("version https://git-lfs.github.com/spec/v1".utf8)) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Git LFS pointer is not original game data")
        }
        let input = translation.read(source)
        let logical: [UInt8]
        if encrypted {
            guard input.count >= 123 else { throw OriginalLoaderError.outsideVerifiedDomain("Truncated DAT header") }
            let decoded = input.dropFirst(123).enumerated().map { byte($0.element, at: $0.offset + 123) }
            logical = translation.read(translation.write(decoded))
        } else { logical = input }
        return String(String.UnicodeScalarView(logical.map { UnicodeScalar($0) }))
    }
}
