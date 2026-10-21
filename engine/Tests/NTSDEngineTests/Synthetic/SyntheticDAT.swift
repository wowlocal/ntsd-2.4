import Foundation
@testable import NTSDCore

/// ENGINE_SPLIT E7c: encrypted DAT files for the synthetic pack, made with the
/// engine's own decoder rule rather than a copy of its key.
///
/// `OriginalDATDecoder` (OriginalDATDecoder.swift:35-37, 50-65) skips a 123-byte
/// header and decodes each later byte at stream position i as
/// `byte(value, at: i) = value &- key[i % key.count]`. So the byte that decodes
/// to `plain` at position i is `plain &- byte(0, at: i)`: the generator asks
/// the decoder for `byte(0, at: i)` and never holds the key.
///
/// The catalog reads DATs through `.text` translation (OriginalApplicationCatalogSession.swift:395,
/// OriginalFileTranslation.read): a 0x1a byte ends the stream and CR LF becomes
/// LF *before* decoding. The encrypted bytes must contain neither, or the
/// decoded text would differ from the authored one. When a position would
/// produce one, the generator doubles the whitespace before it (the DAT
/// grammar ignores the amount of whitespace) and encrypts again; `encrypt`
/// checks the result with the engine's decoder.
enum SyntheticDAT {
    /// The decoder's skipped header length (OriginalDATDecoder.swift:60, OriginalLoadingFiles.decodeDAT).
    static let headerLength = 123
    /// The skipped header: authored ASCII, padded to 123 bytes.
    static let header: [UInt8] = {
        let label = Array("NTSD engine tests synthetic DAT (ENGINE_SPLIT E7c); this header is skipped by the decoder. ".utf8)
        return Array((label + [UInt8](repeating: 0x2e, count: headerLength)).prefix(headerLength))
    }()

    enum Failure: Error, CustomStringConvertible {
        case notASCII, unresolvedHazard(Int), roundTrip(String)
        var description: String {
            switch self {
            case .notASCII: return "DAT text must be ASCII without NUL or 0x1a"
            case .unresolvedHazard(let at): return "No whitespace before the text-mode hazard at \(at)"
            case .roundTrip(let name): return "The engine's decoder does not return the authored text of \(name)"
            }
        }
    }

    /// The raw file bytes of `text` for `fileName` (whose last three bytes must
    /// select decoding, as `.dat` does: OriginalDATDecoder.encrypted).
    static func encrypt(_ text: String, fileName: String) throws -> [UInt8] {
        var plain = Array(text.utf8)
        guard plain.allSatisfy({ $0 < 0x80 && $0 != 0 && $0 != 0x1a }) else { throw Failure.notASCII }
        guard try OriginalDATDecoder.encrypted(fileName) else { throw Failure.roundTrip(fileName) }
        while true {
            var raw = header
            for (offset, byte) in plain.enumerated() {
                raw.append(byte &- OriginalDATDecoder.byte(0, at: headerLength + offset))
            }
            if let hazard = firstHazard(raw) {
                // Double the whitespace at or before the hazard's plaintext position.
                let position = max(hazard - headerLength, 0)
                guard let space = plain[...min(position, plain.count - 1)].lastIndex(where: { $0 == 0x20 || $0 == 0x0a }) else {
                    throw Failure.unresolvedHazard(hazard)
                }
                plain.insert(0x20, at: space)
                continue
            }
            // The engine's decoder, as the catalog uses it, returns the authored text.
            let decoded = try OriginalDATDecoder.decode(raw, fileName: fileName, translation: .text)
            guard decoded == String(decoding: plain, as: UTF8.self) else { throw Failure.roundTrip(fileName) }
            return raw
        }
    }

    /// The first position where `.text` reading would change the bytes: a 0x1a
    /// or a CR followed by LF.
    static func firstHazard(_ raw: [UInt8]) -> Int? {
        for i in raw.indices {
            if raw[i] == 0x1a { return i }
            if raw[i] == 13, i + 1 < raw.count, raw[i + 1] == 10 { return i }
        }
        return nil
    }
}
