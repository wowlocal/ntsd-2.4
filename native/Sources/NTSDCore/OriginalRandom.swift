import Foundation

/// Original 0x417170. Initial bytes/index come from the supplied Windows replay;
/// no macOS RNG, guessed CRT generator, or emulator runs in the application.
public struct OriginalRandom: Codable, Equatable, Sendable {
    public let table: [UInt8]
    public private(set) var index: Int
    public private(set) var counter: Int
    public let source: String
    public let sourceSHA256: String

    public func validate() throws {
        guard table.count == 3000, !table.contains(0), (0..<3000).contains(index),
              (0..<1234).contains(counter) else {
            throw OriginalLoaderError.outsideVerifiedDomain("Invalid original replay RNG state")
        }
    }
    public mutating func next(_ range: Int) -> Int {
        guard range > 0 else { return 0 }
        counter = (counter + 1) % 1234
        index = (index + 1) % 3000
        return (Int(table[index]) + counter) % range
    }
}
