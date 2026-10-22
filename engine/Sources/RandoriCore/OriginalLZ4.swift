import Foundation

/// The LZ4 block format, for bytes the port keeps in memory but reads rarely
/// (MEMORY_LOADING M1: the 24-bit sprite sheets' file bytes, ~13x smaller).
/// Lossless: `decompress(compress(x), count: x.count) == x` for every input.
/// Not a game format; nothing original is stored or read this way.
enum OriginalLZ4 {
    enum Failure: Error, Equatable { case corrupt }

    static func compress(_ bytes: UnsafeRawBufferPointer) -> [UInt8] {
        let n = bytes.count
        var out: [UInt8] = []; out.reserveCapacity(n / 8 + 64)
        guard n > 0, let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return [0] }
        func load32(_ i: Int) -> UInt32 { UnsafeRawPointer(base + i).loadUnaligned(as: UInt32.self) }
        func length(_ value: Int) { var v = value; while v >= 255 { out.append(255); v -= 255 }; out.append(UInt8(v)) }
        func sequence(literals start: Int, _ end: Int, match: Int, offset: Int) {
            let literals = end - start
            let token = UInt8(min(literals, 15) << 4) | (match == 0 ? 0 : UInt8(min(match - 4, 15)))
            out.append(token)
            if literals >= 15 { length(literals - 15) }
            out.append(contentsOf: UnsafeBufferPointer(start: base + start, count: literals))
            guard match > 0 else { return }
            out.append(UInt8(truncatingIfNeeded: offset)); out.append(UInt8(truncatingIfNeeded: offset >> 8))
            if match - 4 >= 15 { length(match - 4 - 15) }
        }
        // A match starts at least 12 bytes before the end and ends at least 5
        // before it; the last bytes are always literals (the format's rules).
        let matchStartLimit = n - 12, matchEndLimit = n - 5
        var table = [Int32](repeating: -1, count: 1 << 16)
        var anchor = 0, i = 0
        table.withUnsafeMutableBufferPointer { table in
            while i < matchStartLimit {
                let sequenceWord = load32(i)
                let h = Int((sequenceWord &* 2654435761) >> 16)
                let candidate = Int(table[h]); table[h] = Int32(i)
                if candidate >= 0, i - candidate <= 65535, load32(candidate) == sequenceWord {
                    // Extended eight bytes at a time, then byte by byte.
                    var match = 4
                    while i + match + 8 <= matchEndLimit {
                        let difference = UnsafeRawPointer(base + candidate + match).loadUnaligned(as: UInt64.self)
                            ^ UnsafeRawPointer(base + i + match).loadUnaligned(as: UInt64.self)
                        if difference != 0 { match += difference.littleEndian.trailingZeroBitCount >> 3; break }
                        match += 8
                    }
                    while i + match < matchEndLimit, base[candidate + match] == base[i + match] { match += 1 }
                    sequence(literals: anchor, i, match: match, offset: i - candidate)
                    i += match; anchor = i
                    if i - 2 >= 0 && i - 2 < matchStartLimit { table[Int((load32(i - 2) &* 2654435761) >> 16)] = Int32(i - 2) }
                } else {
                    i += 1 + (i - anchor) >> 6
                }
            }
        }
        sequence(literals: anchor, n, match: 0, offset: 0)
        return out
    }

    static func decompress(_ input: [UInt8], count: Int) throws -> [UInt8] {
        try [UInt8](unsafeUninitializedCapacity: count) { output, initialized in
            initialized = 0
            try input.withUnsafeBufferPointer { input in
                var ip = 0, op = 0
                func length() throws -> Int {
                    var total = 0
                    while true {
                        guard ip < input.count else { throw Failure.corrupt }
                        let b = Int(input[ip]); ip += 1; total += b
                        if b != 255 { return total }
                    }
                }
                while true {
                    guard ip < input.count else { throw Failure.corrupt }
                    let token = Int(input[ip]); ip += 1
                    var literals = token >> 4
                    if literals == 15 { literals += try length() }
                    guard literals <= input.count - ip, literals <= count - op else { throw Failure.corrupt }
                    if literals > 0 {
                        (output.baseAddress! + op).initialize(from: input.baseAddress! + ip, count: literals)
                    }
                    ip += literals; op += literals
                    if ip == input.count { break }
                    guard input.count - ip >= 2 else { throw Failure.corrupt }
                    let offset = Int(input[ip]) | Int(input[ip + 1]) << 8; ip += 2
                    var match = token & 15
                    if match == 15 { match += try length() }
                    match += 4
                    guard offset > 0, offset <= op, match <= count - op else { throw Failure.corrupt }
                    let out = output.baseAddress!
                    if offset >= match {
                        (out + op).initialize(from: out + op - offset, count: match)
                    } else {
                        for k in 0..<match { (out + op + k).initialize(to: out[op + k - offset]) }
                    }
                    op += match
                }
                guard op == count else { throw Failure.corrupt }
                initialized = op
            }
        }
    }
}

/// A bitmap's DIB bytes as the port keeps them (MEMORY_LOADING M1). Images of
/// 64 KiB or more (the sprite sheets: 678 MB of the game's 24-bit files) are
/// kept compressed and decompressed on each read; a surface reads them once,
/// when it first needs its pixels (77 reads in a whole vs match). Smaller
/// images and incompressible ones keep their bytes as they are.
final class OriginalBitmapBytes: Sendable {
    static let threshold = 65_536
    private let raw: [UInt8]?, compressed: [UInt8], count: Int
    init(_ dib: [UInt8]) {
        count = dib.count
        let packed = dib.count >= Self.threshold ? dib.withUnsafeBytes { OriginalLZ4.compress($0) } : nil
        // Kept at its own size: the compressor's buffer keeps the capacity it
        // reserved (an eighth of the input, or more after growing), which held
        // 130 MB for 52 MB of compressed sheets (MEMORY_LOADING M3).
        if let packed, packed.count < dib.count { raw = nil; compressed = packed.withUnsafeBufferPointer { Array($0) } } else { raw = dib; compressed = [] }
    }
    var dib: [UInt8] { raw ?? (try! OriginalLZ4.decompress(compressed, count: count)) }
    var isCompressed: Bool { raw == nil }
    /// The bytes held, for tests: the compressed array's capacity (M3).
    var heldCapacity: Int { raw?.capacity ?? compressed.capacity }
}
