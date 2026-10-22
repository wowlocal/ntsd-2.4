/// VC80's fixed diagnostic formats %2.3f/%2.4f. Integer arithmetic reproduces
/// binary64->LD10, the80-bit decimal scaling significand,17-digit I10_OUTPUT,
/// decimal rounding and fixed layout. No host printf, CRT DLL or interpreter.
public enum OriginalDiagnosticNumber {
    struct Intermediate: Equatable {
        let negative: Bool, finite: Bool
        var decimalPosition: Int, digits: [UInt8]
    }
    private struct Scaled {
        var words: [UInt16] // five little-endian significand words
        var exponent: Int  // original biased15-bit exponent
    }
    private struct Wide {
        var words = [UInt16](repeating: 0, count: 6)
        mutating func add(_ value: UInt32, at offset: Int) {
            var carry = UInt64(value), index = offset
            while carry != 0 {
                precondition(index < 6)
                let sum = UInt64(words[index])+(carry & 0xffff)
                words[index] = UInt16(truncatingIfNeeded: sum)
                carry = (carry >> 16)+(sum >> 16); index += 1
            }
        }
        mutating func shiftLeft() {
            var carry: UInt16 = 0
            for i in words.indices {
                let next = words[i] >> 15
                words[i] = (words[i] << 1) | carry; carry = next
            }
        }
        mutating func shiftRight() {
            var carry: UInt16 = 0
            for i in words.indices.reversed() {
                let next = words[i] << 15
                words[i] = (words[i] >> 1) | carry; carry = next
            }
        }
        mutating func multiplyByTen() {
            var carry: UInt32 = 0
            for i in words.indices {
                let next = UInt32(words[i])*10+carry
                words[i] = UInt16(truncatingIfNeeded: next); carry = next >> 16
            }
            precondition(carry == 0)
        }
    }
    // 7814a1cf..7814a356 and7814a428..7814a5c4. Only the upper convolution
    // diagonals are accumulated: do not add carries from omitted low products.
    // All scalings reachable from binary64 remain normal in this wider format.
    private static func multiply(_ a: Scaled, _ b: Scaled) -> Scaled {
        var product = Wide()
        for diagonal in 4...8 {
            for i in 0..<5 {
                let j = diagonal-i
                if (0..<5).contains(j) { product.add(UInt32(a.words[i])*UInt32(b.words[j]), at: diagonal-4) }
            }
        }
        var exponent = a.exponent+b.exponent-0x3ffe
        while product.words[5] & 0x8000 == 0 { product.shiftLeft(); exponent -= 1 }
        precondition(exponent > 0 && exponent < 0x7fff)
        let guardWord = product.words[0]
        var words = Array(product.words.dropFirst())
        if guardWord > 0x8000 || (guardWord == 0x8000 && words[0] & 1 != 0) {
            var carry: UInt32 = 1
            for i in words.indices {
                let sum = UInt32(words[i])+carry
                words[i] = UInt16(truncatingIfNeeded: sum); carry = sum >> 16
            }
            if carry != 0 { words = [0,0,0,0,0x8000]; exponent += 1 }
        }
        return .init(words: words, exponent: exponent)
    }
    static func intermediate(bits: UInt64) -> Intermediate {
        let negative = bits >> 63 != 0, rawExponent = Int((bits >> 52) & 0x7ff)
        let fraction = bits & 0xfffffffffffff
        if rawExponent == 0x7ff {
            let literal: String
            if fraction == 0 { literal = "1#INF" }
            else if fraction & (1 << 51) == 0 { literal = "1#SNAN" }
            else if negative && fraction == 1 << 51 { literal = "1#IND" }
            else { literal = "1#QNAN" }
            return .init(negative: negative, finite: false, decimalPosition: 1, digits: Array(literal.utf8))
        }
        if rawExponent == 0 && fraction == 0 {
            return .init(negative: negative, finite: true, decimalPosition: 0, digits: [48])
        }
        var mantissa = fraction | (rawExponent == 0 ? 0 : 1 << 52)
        let shift = mantissa.leadingZeroBitCount
        mantissa <<= shift
        let exponent = (rawExponent == 0 ? 1 : rawExponent)+0x3c00+11-shift
        var position = (exponent*0x4d10+((exponent >> 8)+2*Int(mantissa >> 56))*0x4d-0x134312f4) >> 16
        var value = Scaled(words: [0, UInt16(truncatingIfNeeded: mantissa), UInt16(truncatingIfNeeded: mantissa >> 16),
            UInt16(truncatingIfNeeded: mantissa >> 32), UInt16(truncatingIfNeeded: mantissa >> 48)], exponent: exponent)
        var scale = abs(position), group = 0
        let table = tables[position > 0 ? 1 : 0]
        while scale != 0 {
            let digit = scale & 7; scale >>= 3
            if digit != 0 {
                var factor = table[group+digit-1]
                // Source adjusts only this32-bit word; no propagated borrow.
                if factor.words[0] >= 0x8000 {
                    let middle = (UInt32(factor.words[1]) | UInt32(factor.words[2]) << 16) &- 1
                    factor.words[1] = UInt16(truncatingIfNeeded: middle)
                    factor.words[2] = UInt16(truncatingIfNeeded: middle >> 16)
                }
                value = multiply(value, factor)
            }
            group += 7
        }
        if value.exponent >= 0x3fff {
            position += 1
            value = multiply(value, .init(words: [UInt16](repeating: 0xcccc, count: 5), exponent: 0x3ffb))
        }
        var fractionBits = Wide(words: value.words+[0])
        for _ in 0..<8 { fractionBits.shiftLeft() }
        for _ in 0..<max(0, 0x3ffe-value.exponent) { fractionBits.shiftRight() }
        var digits: [UInt8] = []
        for _ in 0..<18 {
            fractionBits.multiplyByTen()
            let digit = fractionBits.words[5] >> 8
            precondition(digit < 10)
            digits.append(UInt8(digit)+48); fractionBits.words[5] &= 0xff
        }
        if digits.removeLast() >= 53 {
            var index = 16
            while index >= 0 && digits[index] == 57 { digits[index] = 48; index -= 1 }
            if index < 0 { digits[0] = 49; position += 1 }
            else { digits[index] += 1 }
        }
        while digits.count > 1 && digits.last == 48 { digits.removeLast() }
        return .init(negative: negative, finite: true, decimalPosition: position, digits: digits)
    }
    /// Raw bits preserve signed zero and the source's NaN payload distinction.
    /// A caller which first loads/stores through x87 must supply that resulting
    /// bit pattern; direct sprintf varargs do not perform that load themselves.
    public static func fixed(bits: UInt64, fractionDigits: Int) throws -> [UInt8] {
        guard fractionDigits == 3 || fractionDigits == 4 else { throw OriginalStateError.invalidStorage("Unrecovered diagnostic precision") }
        let value = intermediate(bits: bits)
        var position = value.decimalPosition
        let count = position+fractionDigits
        var rounded: [UInt8] = [48]
        if count > 0 {
            rounded += value.digits.prefix(count)
            rounded += [UInt8](repeating: 48, count: max(0, count-value.digits.count))
        }
        // 7814d531 compares bytes even for INF/NAN text. Preserve such outputs
        // as1.#IO and1.#QNB instead of substituting host infinity/NaN spelling.
        if count >= 0 && count < value.digits.count && value.digits[count] >= 53 {
            var index = rounded.count-1
            while rounded[index] == 57 { rounded[index] = 48; index -= 1 }
            rounded[index] += 1
        }
        if rounded[0] == 49 { position += 1 } else { rounded.removeFirst() }
        var result: [UInt8] = value.negative ? [45] : []
        if position <= 0 {
            result += [48,46]+[UInt8](repeating: 48, count: min(-position, fractionDigits))+rounded
        } else {
            result += rounded.prefix(position)
            result.append(46); result += rounded.dropFirst(position)
        }
        return result
    }
    // The twelve-byte scaling constants of the pinned VC80 DLL .6195 (its two
    // tables at 781c1ff0/781c2150: 10^p and 10^-p for p = 1...8, 16...64 by 8,
    // 128...448 by 64; three base8 exponent groups suffice for binary64), computed
    // here instead of copied (ENGINE_SPLIT E7e-1): the top 64 significand bits are
    // 10^±p rounded to the nearest 64-bit value (ties to even), the low 16 bits
    // those of 10^±p rounded to 80 bits. Equal to the DLL's 42 entries (the
    // diagnostic-number corpus compares tableHex; the engine's test their digest).
    /// d·8^g for g = 0...2, d = 1...7: the groups the scaling looks up (group += 7).
    static let powers = (0..<3).flatMap { group in (1...7).map { $0 << (3*group) } }
    private static let tables: [[Scaled]] = [powers.map { scaled(power: $0) }, powers.map { scaled(power: -$0) }]
    /// The tables in hex, in the DLL's byte layout (five significand words, then the exponent word).
    static var tableHex: [[String]] {
        tables.map { table in
            table.map { entry in
                let digits = Array("0123456789abcdef".utf8)
                let bytes = (entry.words + [UInt16(entry.exponent)]).flatMap { [UInt8($0 & 0xff), UInt8($0 >> 8)] }
                return String(decoding: bytes.flatMap { [digits[Int($0 >> 4)], digits[Int($0 & 15)]] }, as: UTF8.self)
            }
        }
    }
    /// 10^power in the twelve-byte format, by the rounding above.
    private static func scaled(power: Int) -> Scaled {
        var ten = Natural(1)
        for _ in 0..<abs(power) { ten.multiply(by: 10) }
        let width = ten.bitWidth, high: UInt64, low: UInt64, exponent: Int
        if power > 0 {
            high = ten.rounded(shiftingRightBy: width-64).value
            low = UInt64(ten.rounded(shiftingRightBy: width-80).limbs[0] & 0xffff)
            exponent = width-1+0x3fff
        } else {
            // 2^-width < 10^power < 2^(1-width): 10^-power is no power of two.
            high = Natural.roundedQuotient(Natural(1).shiftedLeft(by: width+63), ten).value
            low = UInt64(Natural.roundedQuotient(Natural(1).shiftedLeft(by: width+79), ten).limbs[0] & 0xffff)
            exponent = -width+0x3fff
        }
        precondition(high >> 63 == 1, "a normalized 64-bit rounding")
        return .init(words: [UInt16(low)] + (0..<4).map { UInt16(truncatingIfNeeded: high >> (16*$0)) }, exponent: exponent)
    }
    /// Unsigned integers of any width in little-endian 32-bit limbs: only what
    /// the table's computation needs.
    private struct Natural {
        var limbs: [UInt32]
        init(_ value: UInt32) { limbs = [value] }
        init(limbs: [UInt32]) { self.limbs = limbs; while self.limbs.count > 1 && self.limbs.last == 0 { self.limbs.removeLast() } }
        var bitWidth: Int { 32*(limbs.count-1) + (32-(limbs.last ?? 0).leadingZeroBitCount) }
        var value: UInt64 { precondition(bitWidth <= 64); return limbs.prefix(2).enumerated().reduce(0) { $0 | UInt64($1.element) << (32*$1.offset) } }
        func bit(_ index: Int) -> Bool { index >= 0 && index/32 < limbs.count && limbs[index/32] >> (index%32) & 1 == 1 }
        mutating func multiply(by factor: UInt32) {
            var carry: UInt64 = 0
            for i in limbs.indices { let p = UInt64(limbs[i])*UInt64(factor)+carry; limbs[i] = UInt32(truncatingIfNeeded: p); carry = p >> 32 }
            if carry != 0 { limbs.append(UInt32(carry)) }
        }
        func shiftedLeft(by count: Int) -> Natural {
            var out = [UInt32](repeating: 0, count: count/32) + limbs + [0]
            if count%32 != 0 {
                for i in stride(from: out.count-1, through: count/32, by: -1) {
                    out[i] = out[i] << (count%32) | (i > count/32 ? out[i-1] >> (32-count%32) : 0)
                }
            }
            return .init(limbs: out)
        }
        func shiftedRight(by count: Int) -> Natural {
            guard count > 0 else { return shiftedLeft(by: -count) }
            var out: [UInt32] = []
            for i in (count/32)..<limbs.count {
                let next = i+1 < limbs.count ? limbs[i+1] : 0
                out.append(count%32 == 0 ? limbs[i] : limbs[i] >> (count%32) | next << (32-count%32))
            }
            return .init(limbs: out.isEmpty ? [0] : out)
        }
        /// self / 2^count rounded to the nearest, ties to even (exact for count <= 0).
        func rounded(shiftingRightBy count: Int) -> Natural {
            var q = shiftedRight(by: count)
            guard count > 0, bit(count-1) else { return q }
            let sticky = (0..<(count-1)).contains { bit($0) }
            if sticky || q.bit(0) { q.add(1) }
            return q
        }
        mutating func add(_ value: UInt32) {
            var carry = UInt64(value), i = 0
            while carry != 0 {
                if i == limbs.count { limbs.append(0) }
                let sum = UInt64(limbs[i])+carry; limbs[i] = UInt32(truncatingIfNeeded: sum); carry = sum >> 32; i += 1
            }
        }
        static func < (a: Natural, b: Natural) -> Bool {
            if a.limbs.count != b.limbs.count { return a.limbs.count < b.limbs.count }
            for i in a.limbs.indices.reversed() where a.limbs[i] != b.limbs[i] { return a.limbs[i] < b.limbs[i] }
            return false
        }
        func subtracting(_ b: Natural) -> Natural {
            var out = limbs, borrow: Int64 = 0
            for i in out.indices {
                let d = Int64(out[i]) - Int64(i < b.limbs.count ? b.limbs[i] : 0) - borrow
                out[i] = UInt32(truncatingIfNeeded: d); borrow = d < 0 ? 1 : 0
            }
            return .init(limbs: out)
        }
        /// a / d rounded to the nearest, ties to even (bitwise long division).
        static func roundedQuotient(_ a: Natural, _ d: Natural) -> Natural {
            var q = Natural(0), r = Natural(0)
            for i in stride(from: a.bitWidth-1, through: 0, by: -1) {
                r = r.shiftedLeft(by: 1); if a.bit(i) { r.add(1) }
                q = q.shiftedLeft(by: 1)
                if !(r < d) { r = r.subtracting(d); q.add(1) }
            }
            let twice = r.shiftedLeft(by: 1)
            if d < twice || (!(twice < d) && q.bit(0)) { q.add(1) }
            return q
        }
    }
}
