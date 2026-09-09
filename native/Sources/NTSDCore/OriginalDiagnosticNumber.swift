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
    // Exact twelve-byte scaling constants from pinned VC80 DLL .6195,
    // 781c1ff0/781c2150; three base8 exponent groups suffice for binary64.
    static let tableHex: [[String]] = [
        [
            "000000000000000000a00240",
            "000000000000000000c80540",
            "000000000000000000fa0840",
            "0000000000000000409c0c40",
            "000000000000000050c30f40",
            "000000000000000024f41240",
            "000000000000008096981640",
            "0000000000000020bcbe1940",
            "000000000004bfc91b8e3440",
            "000000a1edccce1bc2d34e40",
            "20f09eb5702ba8adc59d6940",
            "d05dfd25e51a8e4f19eb8340",
            "7196d795430e058d29af9e40",
            "f9bfa044ed81128f8182b940",
            "bf3cd5a6cfff491f78c2d340",
            "6fc6e08ce980c947ba93a841",
            "bc856b5527398df770e07c42",
            "bcdd8edef99dfbeb7eaa5143",
            "a1e676e3ccf2292f84812644",
            "281017aaf8ae10e3c5c4fa44",
            "eba7d4f3f7ebe14a7a95cf45"
        ],
        [
            "cdcccdccccccccccccccfb3f",
            "713d0ad7a3703d0ad7a3f83f",
            "5a643bdf4f8d976e1283f53f",
            "c3d32c6519e25817b7d1f13f",
            "d00f2384471b47acc5a7ee3f",
            "40a6b6696caf05bd3786eb3f",
            "333dbc427ae5d594bfd6e73f",
            "c2fdfdce61841177ccabe43f",
            "2f4c5be14dc4be9495e6c93f",
            "92c4533b7544cd14be9aaf3f",
            "de67ba943945ad1eb1cf943f",
            "2423c6e2bcba3b31618b7a3f",
            "615559c17eb1537c12bb5f3f",
            "d7ee2f8d06be928515fb443f",
            "243fa5e939a527ea7fa82a3f",
            "7daca1e4bc647c46d0dd553e",
            "637b06cc23547783ff91813d",
            "91fa3a197a63254331c0ac3c",
            "2189d138824797b800fdd73b",
            "dc8858081bb1e8e386a6033b",
            "c684454207b6997537db2e3a"
        ]
    ]
    private static let tables: [[Scaled]] = tableHex.map { table in
        table.map { hex in
            let chars = Array(hex.utf8)
            let bytes = stride(from: 0, to: chars.count, by: 2).map {
                UInt8(String(decoding: chars[$0..<$0+2], as: UTF8.self), radix: 16)!
            }
            let words = stride(from: 0, to: 12, by: 2).map { UInt16(bytes[$0]) | UInt16(bytes[$0+1]) << 8 }
            return .init(words: Array(words.prefix(5)), exponent: Int(words[5]))
        }
    }
}
