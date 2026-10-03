import Foundation

/// `NSDictionary(dictionary: a).isEqual(to: b)` for JSONSerialization objects.
/// Darwin bridges JSON numbers and booleans to NSNumber, so `true` equals `1`;
/// swift-corelibs-foundation keeps Bool and Int distinct. Elsewhere this gives
/// the Darwin result for JSON values: numbers and booleans by numeric value,
/// strings by UTF-16 units, arrays element-wise, objects by keys and values.
func sameJSONObject(_ a: [String: Any], _ b: [String: Any]) -> Bool {
    #if canImport(Darwin)
    return NSDictionary(dictionary: a).isEqual(to: b)
    #else
    return sameJSONValue(a, b)
    #endif
}

#if !canImport(Darwin)
private enum JSONNumber { case integer(negative: Bool, magnitude: UInt64), floating(Double) }

private func jsonNumber(_ value: Any) -> JSONNumber? {
    switch value {
    case let v as Bool: return .integer(negative: false, magnitude: v ? 1 : 0)
    case let v as Int: return .integer(negative: v < 0, magnitude: UInt64(v.magnitude))
    case let v as UInt64: return .integer(negative: false, magnitude: v)
    case let v as Int64: return .integer(negative: v < 0, magnitude: UInt64(v.magnitude))
    case let v as Double: return .floating(v)
    case let v as Decimal: return .floating(NSDecimalNumber(decimal: v).doubleValue)
    case let v as NSNumber: return .floating(v.doubleValue)
    default: return nil
    }
}

private func sameJSONValue(_ a: Any, _ b: Any) -> Bool {
    if let x = jsonNumber(a), let y = jsonNumber(b) {
        switch (x, y) {
        case let (.integer(n1, m1), .integer(n2, m2)): return m1 == m2 && (n1 == n2 || m1 == 0)
        case let (.integer(n, m), .floating(d)), let (.floating(d), .integer(n, m)): return (n ? -Double(m) : Double(m)) == d
        case let (.floating(d1), .floating(d2)): return d1 == d2
        }
    }
    switch (a, b) {
    case let (x as String, y as String): return Array(x.utf16) == Array(y.utf16)
    case (is NSNull, is NSNull): return true
    case let (x as [Any], y as [Any]): return x.count == y.count && zip(x, y).allSatisfy { sameJSONValue($0, $1) }
    case let (x as [String: Any], y as [String: Any]):
        return x.count == y.count && x.allSatisfy { key, value in y[key].map { sameJSONValue(value, $0) } ?? false }
    default: return false
    }
}
#endif
