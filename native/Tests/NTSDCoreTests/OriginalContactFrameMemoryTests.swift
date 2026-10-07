import XCTest
@testable import NTSDCore

/// CORE_REALTIME 4p: contact frame memory built with a precomputed address
/// order (the catalog's) resolves every address, value and error as the
/// sorting initializer and a search over all allocations do.
final class OriginalContactFrameMemoryTests: XCTestCase {
    func allocation(_ address: UInt32,_ count: Int,_ fill: UInt8) throws -> OriginalFrameAllocation {
        let bytes = (0..<count).map { UInt8(truncatingIfNeeded: Int(fill)+$0) }
        return OriginalFrameAllocation(address: address,kind: .bodies,storage: try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: count)))
    }
    func describe(_ body: () throws -> Int32) -> String {
        do { return "value \(try body())" } catch { return "error \(error)" }
    }
    func testOrderedAndUnorderedAllocationsResolveLikeASearch() throws {
        let increasing = try [allocation(0x1000,16,1),allocation(0x1010,8,2),allocation(0x2000,32,3),allocation(0x2400,12,4)]
        var state: UInt64 = 5
        func next(_ n: Int) -> Int { state = state &* 6364136223846793005 &+ 1442695040888963407; return Int((state >> 33) % UInt64(n)) }
        var layouts = [increasing,Array(increasing.reversed()),[increasing[2],increasing[0],increasing[3],increasing[1]],[increasing[0]],[]]
        layouts.append(increasing+[try allocation(0x2400,12,9)])   // a tie: the sort's order decides
        for allocations in layouts {
            let order = allocations.indices.sorted { allocations[$0].address < allocations[$1].address }
            let memory = OriginalContactFrameMemory(allocations), given = OriginalContactFrameMemory(allocations,order: order)
            // The reference: the allocation with the largest address at or below
            // the target, ties resolved as the stable sort orders them.
            let sorted = allocations.indices.sorted { allocations[$0].address < allocations[$1].address }
            func expected(_ address: UInt32) throws -> Int32 {
                guard let i = sorted.last(where: { allocations[$0].address <= address }) else {
                    throw OriginalStateError.invalidStorage("Unknown contact box reference")
                }
                return try allocations[i].storage.integer(at: Int(address-allocations[i].address),as: Int32.self)
            }
            for _ in 0..<400 {
                let address = UInt32(0x0ff0+next(0x1500))
                XCTAssertEqual(describe { try memory.word(address) },describe { try expected(address) },"\(allocations.map(\.address)) \(address)")
                XCTAssertEqual(describe { try given.word(address) },describe { try expected(address) },"given order \(address)")
            }
        }
    }
}
