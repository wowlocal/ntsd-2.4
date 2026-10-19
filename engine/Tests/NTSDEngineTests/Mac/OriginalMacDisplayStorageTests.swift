import Foundation
import XCTest
@testable import NTSDRuntime

/// CORE_REALTIME P2: a storage lends its values buffer as a frame without
/// copying; from the loan the frame owns those bytes, and every way of
/// writing the storage (a pixel, a whole fill, a recorded write) first moves
/// it to a buffer of its own, so no lent frame ever changes.
final class OriginalMacDisplayStorageTests: XCTestCase {
    typealias B = OriginalMacDisplayBackend

    func testLentFramesNeverChange() throws {
        let pool = B.PixelPool(),budget = B.Budget(1 << 30)
        let storage = try B.Storage(7,5,budget,pool:pool)
        let s = storage,count = s.count
        func contents() -> [UInt32] { Array(UnsafeBufferPointer(start:s.values,count:count)) }
        func pixels(_ frame: OriginalFramebuffer) -> [UInt32] {
            frame.pixels.withUnsafeBytes { Array($0.bindMemory(to:UInt32.self)) }
        }
        let a = (0..<UInt32(count)).map { $0 &* 2654435761 }
        let written = s.writableValues
        for i in 0..<count { written[i] = a[i] }
        s.known.setAll()

        // A loan is the storage's bytes as they are, without a copy.
        let first = s.lend()
        XCTAssertEqual(first.width,7);XCTAssertEqual(first.height,5);XCTAssertEqual(pixels(first),a)
        XCTAssertEqual(first.pixels.withUnsafeBytes { $0.baseAddress },UnsafeRawPointer(s.values),"lent, not copied")
        XCTAssertEqual(s.lend(),first,"a second loan without a write is the same frame")
        XCTAssertEqual(s.lend().pixels.withUnsafeBytes { $0.baseAddress },first.pixels.withUnsafeBytes { $0.baseAddress })

        // One pixel written: the storage moves to a copy; the frame keeps its bytes.
        s.writableValues[3] = 0xdead
        var expected = a;expected[3] = 0xdead
        XCTAssertEqual(contents(),expected);XCTAssertEqual(pixels(first),a)
        XCTAssertNotEqual(UnsafeRawPointer(s.values),first.pixels.withUnsafeBytes { $0.baseAddress })

        // A whole fill: the storage moves without copying; the frame keeps its bytes.
        let second = s.lend()
        XCTAssertEqual(pixels(second),expected)
        let whole = s.overwrittenValues
        for i in 0..<count { whole[i] = 0x123456 }
        XCTAssertEqual(contents(),[UInt32](repeating:0x123456,count:count))
        XCTAssertEqual(pixels(second),expected);XCTAssertEqual(pixels(first),a)

        // A recorded write, applied at the next read: the same.
        let third = s.lend()
        s.record { values,known in values[0] = 0xbeef;known[0] = 1 }
        XCTAssertEqual(contents()[0],0xbeef)
        XCTAssertEqual(pixels(third),[UInt32](repeating:0x123456,count:count))

        XCTAssertEqual(pixels(first),a);XCTAssertEqual(pixels(second),expected)
        withExtendedLifetime(storage) {}
    }

    /// A storage freed while lent leaves the frame its bytes (the frame
    /// returns the buffer when let go) and releases its budget.
    func testFreedStorageLeavesTheLentFrame() throws {
        let pool = B.PixelPool(),budget = B.Budget(1 << 20)
        func lent() throws -> OriginalFramebuffer {
            let s = try B.Storage(6,3,budget,pool:pool),values = s.writableValues
            for i in 0..<s.count { values[i] = UInt32(i) * 7 }
            s.known.setAll()
            return s.lend()
        }
        let frame = try lent()
        XCTAssertEqual(budget.allocated,0,"the budget is released with the storage")
        XCTAssertEqual(frame.pixels.withUnsafeBytes { Array($0.bindMemory(to:UInt32.self)) },(0..<18).map { UInt32($0) * 7 })
    }

    /// Frames let go return their buffers to the pool, which hands them to the
    /// next storage write of the same size and frees beyond four.
    func testReturnedBuffersAreReused() throws {
        let pool = B.PixelPool(),s = try B.Storage(4,4,B.Budget(1 << 20),pool:pool)
        s.known.setAll()
        var seen = Set<UnsafeRawPointer>()
        for round in 0..<12 {
            let frame = s.lend()
            seen.insert(try XCTUnwrap(frame.pixels.withUnsafeBytes { $0.baseAddress }))
            let values = s.overwrittenValues
            for i in 0..<s.count { values[i] = UInt32(round) }
            XCTAssertEqual(frame.pixels.withUnsafeBytes { $0.load(as:UInt32.self) },round == 0 ? 0 : UInt32(round - 1))
        }
        XCTAssertLessThanOrEqual(seen.count,3,"the buffers of released frames come back")
    }

    /// A storage too small for a lent buffer (Data would keep its bytes
    /// inline and release the buffer at once) presents a copy and keeps its
    /// buffer (P2's review).
    func testTinyStoragesPresentCopies() throws {
        let pool = B.PixelPool()
        for count in 1...20 {
            let s = try B.Storage(count,1,B.Budget(1 << 20),pool:pool),values = s.writableValues
            for i in 0..<count { values[i] = UInt32(i + 1) * 0x01010101 }
            s.known.setAll()
            let frame = s.lend(),expected = (0..<count).map { UInt32($0 + 1) * 0x01010101 }
            XCTAssertEqual(frame.pixels.withUnsafeBytes { Array($0.bindMemory(to:UInt32.self)) },expected)
            s.writableValues[0] = 7
            XCTAssertEqual(frame.pixels.withUnsafeBytes { $0.load(as:UInt32.self) },expected[0],"\(count) pixels")
            XCTAssertEqual(s.values[0],7)
            let taken = pool.take(count)
            XCTAssertNotEqual(taken,s.values,"the pool never holds a buffer in use (\(count) pixels)")
            free(taken)
        }
    }

    /// A whole overwrite of a lent storage with recorded writes pending moves
    /// to a new buffer without copying: the recorded writes' known bits stay,
    /// their values are overwritten, the frame keeps its bytes.
    func testWholeOverwriteAfterRecordedWrites() throws {
        let s = try B.Storage(8,8,B.Budget(1 << 20),pool:B.PixelPool()),values = s.writableValues
        for i in 0..<s.count { values[i] = 0x55 }
        s.known.setAll()
        let frame = s.lend()
        s.record { values,known in values[9] = 0x99;known[9] = 1 }
        let whole = s.overwrittenValues
        for i in 0..<s.count { whole[i] = 0x11 }
        XCTAssertEqual(Array(UnsafeBufferPointer(start:s.values,count:s.count)),[UInt32](repeating:0x11,count:s.count))
        XCTAssertEqual(s.known[9],1)
        XCTAssertEqual(frame.pixels.withUnsafeBytes { Array($0.bindMemory(to:UInt32.self)) },[UInt32](repeating:0x55,count:s.count))
    }

    /// Frames let go on other threads while the storage keeps writing and
    /// lending: every frame keeps the bytes it was lent with.
    func testFramesReleasedOnOtherThreads() throws {
        let s = try B.Storage(32,32,B.Budget(1 << 24),pool:B.PixelPool())
        s.known.setAll()
        let group = DispatchGroup(),queue = DispatchQueue(label:"frames",attributes:.concurrent)
        let failures = NSLock();var bad = 0
        for round in 0..<300 {
            let values = round % 3 == 0 ? s.writableValues : s.overwrittenValues
            for i in 0..<s.count { values[i] = UInt32(round) }
            let frame = s.lend()
            queue.async(group:group) {
                let ok = frame.pixels.withUnsafeBytes { $0.bindMemory(to:UInt32.self).allSatisfy { $0 == UInt32(round) } }
                if !ok { failures.lock(); bad += 1; failures.unlock() }
            }
        }
        group.wait()
        XCTAssertEqual(bad,0)
    }
}
