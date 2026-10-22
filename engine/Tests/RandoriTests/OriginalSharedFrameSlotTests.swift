import Foundation
import XCTest
@testable import RandoriCore

/// MEMORY_LOADING L19: slots no frame wrote are built from their backing slice
/// alone; equal slices share one record and one projection (but for the
/// number), with the values the slot would have had on its own.
final class OriginalSharedFrameSlotTests: XCTestCase {
    let text = """
    <bmp_begin>
    file(anything): sheet.bmp w: 7 h: 7 row: 1 col: 1
    <bmp_end>
    <frame> 3 stand pic: 0 state: 1 wait: 2 next: 3 <frame_end>
    <frame> 7 walk pic: 1 state: 2 wait: 3 next: 0 sound: data\\001.wav <frame_end>
    """
    func load(backing: [UInt8]?) throws -> OriginalLoadedObject {
        var loader = OriginalObjectLoader()
        return try loader.load(decoded: text, id: 1, type: 0, headerBacking: Array(repeating: 0xa5, count: 0x7a4), tailBacking: Array(repeating: 0xa5, count: 0x3c),
                               frameBacking: backing, bitmapSource: { .init(path: $0, present: true, width: 8, height: 8) })
    }

    func testUnwrittenSlotsAreTheirSlicesRecordsAndShareWhenEqual() throws {
        let uniform = Array(repeating: UInt8(0x5a), count: 400 * 0x178)
        // Slots alternating between two patterns, with runs.
        let varying = (0..<400).flatMap { slot in Array(repeating: UInt8(slot % 3 == 0 ? 0x11 : 0x22), count: 0x178) }
        for backing in [uniform, varying, nil] {
            let object = try load(backing: backing)
            XCTAssertEqual(object.frameStorage.count, 400); XCTAssertEqual(object.frames.count, 400)
            for slot in 0..<400 where slot != 3 && slot != 7 {
                // Without a backing a slot starts from 0xa5 bytes.
                let slice = backing.map { Array($0[slot*0x178..<(slot+1)*0x178]) } ?? Array(repeating: 0xa5, count: 0x178)
                let expected = try OriginalStateRecord.frame(over: slice)
                XCTAssertTrue(object.frameStorage[slot] == expected, "slot \(slot)")
                let fresh = try OriginalFrameLoader().projected(at: slot, record: expected)
                XCTAssertEqual(object.frames[slot], fresh, "slot \(slot)")
                XCTAssertEqual(object.frames[slot].number, slot)
            }
            for slot in [3, 7] { XCTAssertNotEqual(object.frameStorage[slot], object.frameStorage[0]) }
        }
        // A uniform backing: every unwritten slot shares one record.
        let object = try load(backing: uniform)
        let identities = Set((0..<400).filter { $0 != 3 && $0 != 7 }.compactMap { object.frameStorage[$0].storageIdentity?.0 })
        XCTAssertEqual(identities.count, 1)
    }
}
