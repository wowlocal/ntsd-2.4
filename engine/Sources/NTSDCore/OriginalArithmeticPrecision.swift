/// x87 precision control for round-to-nearest arithmetic. This specifies
/// significand precision, not binary32/binary64 exponent range or an OS FPU.
public enum OriginalArithmeticPrecision: Int, Codable, Sendable {
    case bits24 = 24,bits53 = 53,bits64 = 64

    public init(controlWord: UInt16) throws {
        guard controlWord & 0x0c00 == 0 else { throw OriginalStateError.invalidStorage("Unsupported x87 rounding mode") }
        switch controlWord & 0x0300 {
        case 0:self = .bits24
        case 0x0200:self = .bits53
        case 0x0300:self = .bits64
        default:throw OriginalStateError.invalidStorage("Reserved x87 precision mode")
        }
    }
}
