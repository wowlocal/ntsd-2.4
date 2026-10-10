import XCTest
@testable import NTSDCore

/// CORE_REALTIME e4: the mode-3 present's 16-byte rectangle is read in place
/// and equals the whole-array slice for flat and parted globals, undefined
/// bytes included.
final class OriginalMenuPresentationSurfaceTests: XCTestCase {
    func testModeThreeRectangleEqualsTheWholeArraySlice() throws {
        let base = OriginalMatchPreparation.globalBase,size = OriginalMatchPreparation.globalSize
        var bytes = [UInt8](repeating:0,count:size),defined = [Bool](repeating:true,count:size)
        func put(_ address: Int,_ value: UInt32) { withUnsafeBytes(of:value.littleEndian) { for (i,b) in $0.enumerated() { bytes[address-base+i] = b } } }
        put(0x458348,3); put(0x455634,0x1234_5678); put(0x455608,0x9abc)
        let start = 0x453ccc-base
        for i in 0..<16 { bytes[start+i] = UInt8(0xa0+i); defined[start+i] = i % 3 != 0 }   // some undefined
        let flat = try OriginalStateRecord(bytes:bytes,defined:defined)
        // Parts boundaries inside and around the rectangle.
        let parted = flat.partitioned(at:[0,start-3,start+5,start+16,size-8])
        XCTAssertTrue(parted.isPartitioned)
        var events: [[OriginalMenuPresentationEvent]] = []
        for globals in [flat,parted] {
            var seen: [OriginalMenuPresentationEvent] = []
            try OriginalMenuPresentation.presentSurface(globals:globals) { seen.append($0) }
            events.append(seen)
            XCTAssertEqual(seen.count,1)
            XCTAssertEqual(seen.first?.arguments,[0x1234_5678,0x14,0x453ccc,0x9abc,0,0x1000000,0])
            XCTAssertEqual(seen.first?.strings,[Array(globals.bytes[start..<(start+16)])])
        }
        XCTAssertEqual(events[0],events[1])
        XCTAssertEqual(events[0].first?.strings,[(0..<16).map { UInt8(0xa0+$0) }])
    }
}
