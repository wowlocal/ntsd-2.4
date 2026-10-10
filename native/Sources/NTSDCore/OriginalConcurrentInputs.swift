import Foundation
#if canImport(Dispatch)
import Dispatch
#endif

/// Package entries are independent files. Reading, verifying and decoding them
/// on every core computes the same values as one after another (MEMORY_LOADING
/// L3); callers take the results in manifest order, so the first failing entry
/// in that order still fails first, with its own error. Later entries are read
/// meanwhile, which costs only time.
enum OriginalConcurrentInputs {
    static func map<Element, Value>(_ elements: [Element], _ transform: (Element) throws -> Value) -> [Result<Value, Error>] {
        var results = [Result<Value, Error>?](repeating: nil, count: elements.count)
        results.withUnsafeMutableBufferPointer { slots in
            DispatchQueue.concurrentPerform(iterations: elements.count) { i in
                slots[i] = Result { try transform(elements[i]) }
            }
        }
        return results.map { $0! }
    }

    /// Lowercase hexadecimal, as `String(format: "%02x")` per byte.
    static func hex<Bytes: Sequence>(_ bytes: Bytes) -> String where Bytes.Element == UInt8 {
        let digits = Array("0123456789abcdef".utf8)
        var text: [UInt8] = []
        for byte in bytes { text.append(digits[Int(byte >> 4)]); text.append(digits[Int(byte & 15)]) }
        return String(decoding: text, as: UTF8.self)
    }
}
