import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Saved-data integrity only. This does not execute a gameplay handler or
/// establish that the application's own gameplay state matches the source.
final class OriginalApplicationGameplaySourceTests: XCTestCase {
    func testPrimarySavedSequence() throws { try verify(false) }
    func testControlSavedSequence() throws { try verify(true) }

    private func verify(_ reverse: Bool) throws {
        let source = try OriginalApplicationGameplaySource(reverse)
        XCTAssertEqual(source.calls.count,17)
        XCTAssertEqual(source.initializedImpulseControlWord,0x23f)
        var endpoints = 0,writeCount = 0,outputWriteCount = 0
        for (index,call) in source.calls.enumerated() {
            XCTAssertEqual(call.sections.map(\.stage),OriginalApplicationGameplaySource.specifications.map(\.0))
            for section in call.sections {
                XCTAssertFalse(section.pcs.isEmpty,"Missing PC inventory at call \(index) \(section.stage)")
                for state in [section.before,section.after] {
                    let raw = try source.record(state.state.poolBytes,state.state.poolMask)
                    var normalized = try source.pool(state)
                    // Normalization changes only known identity words and
                    // round-trips every original byte, including unknown backing.
                    XCTAssertTrue(normalized.defined == raw.defined,"Normalization changed a mask")
                    for slot in 0..<400 {
                        let worldOffset = 0x194+4*slot,objectOffset = 0x7d8+slot*0x420+0x368
                        let actor = try normalized.integer(at:worldOffset,as:UInt32.self)
                        let object = try normalized.integer(at:objectOffset,as:UInt32.self)
                        guard source.actorAddresses.indices.contains(Int(actor)),source.objectAddresses.indices.contains(Int(object)) else {
                            throw OriginalApplicationGameplaySource.error("Normalized owner range")
                        }
                        try normalized.write(source.actorAddresses[Int(actor)],at:worldOffset)
                        try normalized.write(source.objectAddresses[Int(object)],at:objectOffset)
                    }
                    XCTAssertEqual(try normalized.integer(at:0x7d4,as:UInt32.self),0)
                    try normalized.write(UInt32(0x60000020),at:0x7d4)
                    XCTAssertTrue(normalized == raw,"Pool identity round trip at call \(index) \(section.stage)")
                    _ = try source.globals(state)
                    endpoints += 1
                }
            }
            let output = try XCTUnwrap(call.sections.last)
            var projected = try source.globals(output.before)
            XCTAssertEqual(output.writes.count,index == 0 ? 13 : 12)
            for write in output.writes {
                let offset = Int(write.address)-0x44d000
                guard [1,4].contains(write.size),offset >= 0,offset <= projected.bytes.count-write.size else {
                    throw OriginalApplicationGameplaySource.error("Output store extent")
                }
                XCTAssertTrue(output.pcs.contains(write.pc),"Output store PC")
                if write.size == 1 { try projected.write(UInt8(truncatingIfNeeded:write.value),at:offset) }
                else { try projected.write(UInt32(truncatingIfNeeded:write.value),at:offset) }
                outputWriteCount += 1
            }
            XCTAssertTrue(try projected == source.globals(output.after),"Complete output stores")
            if let before = call.beforeInput {
                var bytes = try source.globals(before).bytes
                for write in call.writes {
                    let offset = Int(write.address)-0x44d000
                    guard [1,4].contains(write.size),offset >= 0,offset <= bytes.count-write.size else {
                        throw OriginalApplicationGameplaySource.error("Global store extent")
                    }
                    for n in 0..<write.size { bytes[offset+n] = UInt8(truncatingIfNeeded:write.value >> (8*n)) }
                    writeCount += 1
                }
                let after = try source.globals(XCTUnwrap(call.sections.last).after)
                XCTAssertTrue(bytes == after.bytes,"Ordered global stores at call \(index)")
            } else {
                XCTAssertEqual(index,0)
                XCTAssertTrue(call.writes.isEmpty)
            }
        }
        // Verify every distinct merged blob, rather than just records accessed
        // by the future comparator. Outer fixture SHA pins each source transport.
        for key in source.blobs.keys.sorted() { _ = try source.bytes(key) }
        XCTAssertEqual(endpoints,646)
        XCTAssertEqual(writeCount,576)
        XCTAssertEqual(outputWriteCount,205)
        print("Saved gameplay integrity: control=\(reverse), 16 fixtures + 1 parent bridge, 17 calls, 323 sections, \(endpoints) pool/global endpoints, \(writeCount) ordered global stores, \(source.blobs.count) distinct blobs; no Native gameplay comparison")
    }
}
