import XCTest
@testable import RandoriCore

/// MEMORY_LOADING L6: the frame heap finds allocations by binary search over
/// its address order. Against the scans it replaced (a model kept here), every
/// allocation, write, box read and string lookup gives the same result or error.
final class OriginalFrameHeapIndexTests: XCTestCase {
    struct Generator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9; z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
            return z ^ (z >> 31)
        }
    }
    /// The linear scans of the heap before L6.
    struct Model {
        var allocations: [OriginalFrameAllocation] = []
        var next: UInt32 = 0x10000
        mutating func allocate(_ size: Int, kind: OriginalFrameAllocationKind, address: UInt32?) throws -> UInt32 {
            let base = address ?? next
            guard size > 0, size <= 400, base != 0, UInt64(base) + UInt64(size) + 15 <= UInt64(UInt32.max),
                  !allocations.contains(where: { UInt64(base) < UInt64($0.address) + UInt64($0.storage.byteCount) && UInt64($0.address) < UInt64(base) + UInt64(size) }) else {
                throw OriginalStateError.invalidStorage("Overlapping or invalid Frame allocation")
            }
            let record = try OriginalStateRecord(bytes: Array(repeating: 0xa5, count: size), defined: Array(repeating: false, count: size))
            allocations.append(.init(address: base, kind: kind, storage: record))
            next = max(next, (base + UInt32(size) + 15) & ~15)
            return base
        }
        mutating func write(_ value: Int32, at address: UInt32, offset: Int) throws {
            guard let index = allocations.lastIndex(where: { $0.address == address }) else { throw OriginalStateError.invalidStorage("Unknown Frame allocation") }
            try allocations[index].storage.write(value, at: offset)
        }
        func words(at address: UInt32, count: Int) throws -> [Int32] {
            guard let record = allocations.last(where: { $0.address == address })?.storage else { throw OriginalStateError.invalidStorage("Unknown Frame box reference") }
            return try (0..<count).map { try record.integer(at: $0*4, as: Int32.self) }
        }
        func string(at address: UInt32) throws -> String? {
            guard let a = allocations.last(where: { $0.address <= address && UInt64(address) < UInt64($0.address) + UInt64($0.storage.byteCount) }) else { return nil }
            return try OriginalFrameHeap.string(in: a.storage, at: Int(address - a.address))
        }
    }
    func outcome<T: Equatable>(_ body: () throws -> T) -> String {
        do { return "value \(try body())" } catch { return "error \(error)" }
    }

    /// Boundaries: a range may end exactly where another starts but not one
    /// byte into it, on either side; a probe just below a start finds nothing.
    func testRangesTouchingAndOverlappingByOneByte() {
        var heap = OriginalFrameHeap(), model = Model()
        for (size, base) in [(40, 0x20000), (40, 0x20000 - 40), (40, 0x20000 - 39), (40, 0x20000 + 40), (40, 0x20000 + 39),
                             (1, 0x20000 - 41), (8, 0x20000 + 80), (8, 0x20000 + 79), (4, 0x20000 + 88)] as [(Int, UInt32)] {
            XCTAssertEqual(outcome { try heap.allocate(size, kind: .sound, address: base) },
                           outcome { try model.allocate(size, kind: .sound, address: base) }, "\(size) at \(base)")
        }
        XCTAssertEqual(heap.allocations, model.allocations)
        let addresses: [UInt32] = [0x20000 - 42, 0x20000 - 41, 0x20000 - 40, 0x20000 - 1, 0x20000, 0x20000 + 39, 0x20000 + 40,
                                   0x20000 + 79, 0x20000 + 80, 0x20000 + 87, 0x20000 + 88, 0x20000 + 92, 0x10000]
        for address in addresses {
            XCTAssertEqual(outcome { try heap.string(at: address) }, outcome { try model.string(at: address) }, "\(address)")
            XCTAssertEqual(outcome { try heap.words(at: address, count: 1) }, outcome { try model.words(at: address, count: 1) }, "\(address)")
        }
    }

    func testIndexedLookupsMatchTheScans() {
        var random = Generator(state: 5)
        for round in 0..<20 {
            var heap = OriginalFrameHeap(), model = Model()
            var known: [UInt32] = []
            for step in 0..<1500 {
                let size = [0, 1, 4, 20, 200, 400, 401, Int.random(in: 1...400, using: &random)].randomElement(using: &random)!
                let address: UInt32? = switch Int.random(in: 0..<6, using: &random) {
                case 0: nil
                case 1: known.randomElement(using: &random).map { $0 &+ UInt32.random(in: 0...30, using: &random) } ?? 0x20000
                case 2: 0
                case 3: UInt32.max - UInt32.random(in: 0...500, using: &random)
                default: UInt32.random(in: 0x10000...0x80000, using: &random)
                }
                let kind: OriginalFrameAllocationKind = [.interactions, .bodies, .sound].randomElement(using: &random)!
                let a = outcome { try heap.allocate(size, kind: kind, address: address) }
                let b = outcome { try model.allocate(size, kind: kind, address: address) }
                XCTAssertEqual(a, b, "round \(round) step \(step)")
                if a.hasPrefix("value"), let made = model.allocations.last?.address { known.append(made) }
                let probe = (known.randomElement(using: &random) ?? 0x10000) &+ UInt32.random(in: 0...3, using: &random) * (step % 2 == 0 ? 1 : 4)
                let value = Int32.random(in: .min ... .max, using: &random), offset = Int.random(in: 0...12, using: &random) * 4
                XCTAssertEqual(outcome { try heap.write(value, at: probe, offset: offset); return 0 },
                               outcome { try model.write(value, at: probe, offset: offset); return 0 })
                XCTAssertEqual(outcome { try heap.words(at: probe, count: 3) }, outcome { try model.words(at: probe, count: 3) })
                XCTAssertEqual(outcome { try heap.string(at: probe) }, outcome { try model.string(at: probe) })
                if step % 97 == 0 { XCTAssertEqual(heap.allocations, model.allocations) }
            }
            XCTAssertEqual(heap.allocations, model.allocations)
        }
    }
}
