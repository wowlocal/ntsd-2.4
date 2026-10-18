/// Finite4450d0/_ftol2 result under the declared legacy or SSE2 CPU contract.
/// The CPU flag45971c is not part of the main game-global storage snapshot.
enum OriginalCoordinateConversion {
    static func integer(_ value: OriginalExtended,sse2: Bool) -> Int32 {
        sse2 ? integer(value.double,sse2: true) : value.legacyInteger
    }
    static func integer(_ value: Double,sse2: Bool) -> Int32 {
        let truncated = value.rounded(.towardZero)
        if sse2 { return truncated >= -2147483648 && truncated < 2147483648 ? Int32(truncated) : .min }
        return truncated >= -9223372036854775808 && truncated < 9223372036854775808 ? Int32(truncatingIfNeeded: Int64(truncated)) : 0
    }
}
