/// Finite x87 arithmetic with explicit24/53/64-bit significand precision.
/// Loads are exact; arithmetic rounds, and stores separately round to binary64.
/// Default64 preserves the historical declared control corpora. This contains
/// arithmetic only: no instruction interpreter, EXE or machine emulator.
/// The covered operations start with binary64 values; exponent overflow of
/// the80-bit format and nonfinite operands are outside this finite domain.
struct OriginalExtended: Comparable {
    private var negative: Bool
    private var significand: UInt64
    private var exponent: Int // value = +/- significand * 2^exponent
    private let precision: OriginalArithmeticPrecision
    init(_ value: Double,precision: OriginalArithmeticPrecision = .bits64) throws {
        guard value.isFinite else { throw OriginalStateError.invalidStorage("Nonfinite original arithmetic operand") }
        let bits = value.bitPattern,rawExponent = Int((bits >> 52)&0x7ff)
        let mantissa = (bits & 0xfffffffffffff) | (rawExponent == 0 ? 0 : 0x10000000000000)
        self.init(negative: bits >> 63 != 0,mantissa: mantissa,exponent: rawExponent == 0 ? -1074 : rawExponent-1023-52,precision: precision)
    }
    private init(negative: Bool,mantissa: UInt64,exponent: Int,precision: OriginalArithmeticPrecision) {
        self.precision = precision
        self.negative = negative
        let shift = mantissa == 0 ? 0 : mantissa.leadingZeroBitCount
        significand = mantissa << shift;self.exponent = exponent-shift
    }
    private struct Wide {
        var high: UInt64,low: UInt64
        func shifted(_ count: Int) -> Wide {
            if count == 0 { return self }
            if count < 64 {
                let lost = low << (64-count) != 0
                return .init(high: high >> count,low: (low >> count) | (high << (64-count)) | (lost ? 1 : 0))
            }
            if count < 128 {
                let n = count-64,lost = low != 0 || (n != 0 && high << (64-n) != 0)
                return .init(high: 0,low: (high >> n) | (lost ? 1 : 0))
            }
            return .init(high: 0,low: high != 0 || low != 0 ? 1 : 0)
        }
    }
    private static func rounded(_ value: Wide,negative: Bool,exponent: Int,precision: OriginalArithmeticPrecision) -> Self {
        let length = value.high == 0 ? 64-value.low.leadingZeroBitCount : 128-value.high.leadingZeroBitCount
        if length <= precision.rawValue { return .init(negative: negative,mantissa: value.low,exponent: exponent,precision: precision) }
        let shift = length-precision.rawValue
        var mantissa: UInt64
        let halfway: Bool,sticky: Bool
        if shift <= 64 {
            mantissa = shift == 64 ? value.high : (value.high << (64-shift)) | (value.low >> shift)
            let half = UInt64(1) << (shift-1)
            halfway = value.low & half != 0;sticky = value.low & (half-1) != 0
        } else {
            mantissa = value.high >> (shift-64)
            let half = UInt64(1) << (shift-65)
            halfway = value.high & half != 0;sticky = value.low != 0 || value.high & (half-1) != 0
        }
        if halfway && (sticky || mantissa & 1 != 0) {
            let (next,overflow) = mantissa.addingReportingOverflow(1)
            if overflow { return .init(negative: negative,mantissa: 1 << 63,exponent: exponent+shift+1,precision: precision) };mantissa = next
        }
        return .init(negative: negative,mantissa: mantissa,exponent: exponent+shift,precision: precision)
    }
    static func +(lhs: Self,rhs: Self) -> Self {
        precondition(lhs.precision == rhs.precision,"Arithmetic operands need the same x87 context")
        if lhs.significand == 0 && rhs.significand == 0 { return .init(negative: lhs.negative && rhs.negative,mantissa: 0,exponent: 0,precision: lhs.precision) }
        if lhs.significand == 0 { return rounded(.init(high: 0,low: rhs.significand),negative: rhs.negative,exponent: rhs.exponent,precision: rhs.precision) }
        if rhs.significand == 0 { return rounded(.init(high: 0,low: lhs.significand),negative: lhs.negative,exponent: lhs.exponent,precision: lhs.precision) }
        var a = lhs,b = rhs
        if a.exponent < b.exponent || (a.exponent == b.exponent && a.significand < b.significand) { swap(&a,&b) }
        let x = Wide(high: a.significand >> 1,low: a.significand << 63)
        let y = Wide(high: b.significand >> 1,low: b.significand << 63).shifted(a.exponent-b.exponent)
        let result: Wide
        if a.negative == b.negative {
            let (low,carry) = x.low.addingReportingOverflow(y.low)
            result = .init(high: x.high &+ y.high &+ (carry ? 1 : 0),low: low)
        } else {
            let (low,borrow) = x.low.subtractingReportingOverflow(y.low)
            result = .init(high: x.high &- y.high &- (borrow ? 1 : 0),low: low)
        }
        return rounded(result,negative: result.high == 0 && result.low == 0 ? false : a.negative,exponent: a.exponent-63,precision: a.precision)
    }
    static prefix func -(value: Self) -> Self { var result = value;result.negative.toggle();return result }
    static func -(lhs: Self,rhs: Self) -> Self { lhs + (-rhs) }
    static func *(lhs: Self,rhs: Self) -> Self {
        precondition(lhs.precision == rhs.precision,"Arithmetic operands need the same x87 context")
        let product = lhs.significand.multipliedFullWidth(by: rhs.significand)
        return rounded(.init(high: product.high,low: product.low),negative: lhs.negative != rhs.negative,exponent: lhs.exponent+rhs.exponent,precision: lhs.precision)
    }
    static func /(lhs: Self,rhs: Self) -> Self {
        precondition(lhs.precision == rhs.precision,"Arithmetic operands need the same x87 context")
        precondition(rhs.significand != 0)
        if lhs.significand == 0 { return .init(negative: lhs.negative != rhs.negative,mantissa: 0,exponent: 0,precision: lhs.precision) }
        let shift = lhs.significand >= rhs.significand ? 63 : 64
        let high = shift == 64 ? lhs.significand : lhs.significand >> 1
        let low = shift == 64 ? 0 : lhs.significand << 63
        let divided = rhs.significand.dividingFullWidth((high: high,low: low))
        var mantissa = divided.quotient,exponent = lhs.exponent-rhs.exponent-shift
        let roundUp: Bool
        if lhs.precision == .bits64 {
            roundUp = divided.remainder > rhs.significand-divided.remainder || (divided.remainder == rhs.significand-divided.remainder && mantissa & 1 != 0)
        } else {
            let discarded = 64-lhs.precision.rawValue,half = UInt64(1) << (discarded-1)
            let tail = mantissa & ((UInt64(1) << discarded)-1)
            mantissa >>= discarded;exponent += discarded
            roundUp = tail > half || (tail == half && (divided.remainder != 0 || mantissa & 1 != 0))
        }
        if roundUp {
            let (next,overflow) = mantissa.addingReportingOverflow(1)
            mantissa = overflow ? 1 << 63 : next;if overflow { exponent += 1 }
        }
        return .init(negative: lhs.negative != rhs.negative,mantissa: mantissa,exponent: exponent,precision: lhs.precision)
    }
    static func ==(lhs: Self,rhs: Self) -> Bool {
        if lhs.significand == 0 && rhs.significand == 0 { return true }
        return lhs.negative == rhs.negative && lhs.exponent == rhs.exponent && lhs.significand == rhs.significand
    }
    static func <(lhs: Self,rhs: Self) -> Bool {
        if lhs == rhs { return false }
        if lhs.negative != rhs.negative { return lhs.negative }
        if lhs.significand == 0 { return !rhs.negative };if rhs.significand == 0 { return lhs.negative }
        let less = lhs.exponent == rhs.exponent ? lhs.significand < rhs.significand : lhs.exponent < rhs.exponent
        return lhs.negative ? !less : less
    }
    ///445106's nearest Int64 conversion followed by truncation correction.
    /// The low-zero/high-zero-or-indefinite shortcut must precede correction.
    /// This consumes the extended intermediate without a binary64 store.
    var legacyInteger: Int32 {
        if significand == 0 { return 0 }
        var rounded: UInt64
        if exponent >= 0 {
            guard exponent == 0,negative,significand == 1 << 63 else { return 0 }
            rounded = significand
        } else {
            let shift = -exponent
            rounded = shift >= 64 ? 0 : significand >> shift
            if shift <= 64 {
                let remainder = shift == 64 ? significand : significand & ((UInt64(1) << shift)-1)
                let half = UInt64(1) << (shift-1)
                if remainder > half || (remainder == half && rounded & 1 != 0) { rounded &+= 1 }
            }
            guard rounded < 1 << 63 || (negative && rounded == 1 << 63) else { return 0 }
        }
        if rounded == 0 || rounded == 1 << 63 { return 0 }
        let nearest = Self(negative: negative,mantissa: rounded,exponent: 0,precision: precision)
        var result = Int32(truncatingIfNeeded: negative ? 0 &- rounded : rounded)
        if negative && self > nearest { result &+= 1 }
        else if !negative && self < nearest { result &-= 1 }
        return result
    }
    var double: Double {
        let sign: UInt64 = negative ? 1 << 63 : 0
        if significand == 0 { return Double(bitPattern: sign) }
        var unbiased = exponent+63
        let shift = max(11,-1074-exponent)
        var rounded: UInt64 = shift >= 64 ? 0 : significand >> shift
        if shift <= 64 {
            let tail = shift == 64 ? significand : significand & ((UInt64(1) << shift)-1)
            let half = UInt64(1) << (shift-1)
            if tail > half || (tail == half && rounded & 1 != 0) { rounded += 1 }
        }
        if unbiased < -1022 { return Double(bitPattern: sign | rounded) }
        if rounded == 1 << 53 { rounded >>= 1;unbiased += 1 }
        if unbiased > 1023 { return Double(bitPattern: sign | 0x7ff0000000000000) }
        return Double(bitPattern: sign | (UInt64(unbiased+1023) << 52) | (rounded & 0xfffffffffffff))
    }
}
