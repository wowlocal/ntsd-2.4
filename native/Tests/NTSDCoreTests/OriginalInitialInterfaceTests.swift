import Foundation
import XCTest
import NTSDCore
import NTSDReferenceChecks

final class OriginalInitialInterfaceTests: XCTestCase {
    func testInitialInterfaceAfterRealPoolAgainstEXE() throws {
        try compare(useProvidedConstructor: false)
    }
    func testProvidedConstructorRetainsWholeInterfaceCorpus() throws {
        try compare(useProvidedConstructor: true)
    }
    private func compare(useProvidedConstructor: Bool) throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "original-initial-interface", withExtension: "json", subdirectory: "Fixtures"))
        let result = try InitialInterfaceReference.compare(Data(contentsOf: url), useProvidedConstructor: useProvidedConstructor)
        XCTAssertEqual(result.cases, 13)
        XCTAssertEqual(result.sources, 10)
        XCTAssertEqual(result.constructors, 114)
        XCTAssertEqual(result.poolConstructors, 5304)
        XCTAssertEqual(result.records, 5470)
        XCTAssertEqual(result.bytes, 13_029_720)
        XCTAssertEqual(result.events, 519)
        XCTAssertEqual(result.nullAllocations, 16)
        XCTAssertEqual(result.messages, 23)
        XCTAssertEqual(result.releases, 12)
        XCTAssertEqual(result.providedConstructors, useProvidedConstructor ? 114 : 0)
    }

    private enum Stop: Error { case late, unexpectedLegacyProvider }
    private let base = OriginalMatchPreparation.globalBase
    private func globals() throws -> OriginalStateRecord {
        var state = try OriginalStateRecord(bytes: [UInt8](repeating: 0xa5, count: OriginalMatchPreparation.globalSize),
            defined: [Bool](repeating: true, count: OriginalMatchPreparation.globalSize))
        try state.write(Int32(1), at: 0x44d05c-base)
        try state.write(UInt32(0x10203040), at: 0x457578-base)
        return state
    }
    private func bitmap(_ path: String, _ backing: [UInt8], optional: Bool = false) throws -> OriginalLoadedBitmap {
        try OriginalBitmapConstructor.construct(.init(path: path, present: true, width: 84, height: 23),
            optional: optional, backing: backing, device: 0x10203040, flags: 0x40, surface: 0x32001000, colorKeyResult: 0)
    }

    // Native composition control, not a newly executed original UI/GDI corpus.
    // The legacy image-result boundary cannot express known dimensions with a
    // failed CreateSurface; the whole constructor must retain those writes.
    func testWholeSurfaceFailureRetainsProducedDimensions() throws {
        var state = try globals(), loader = OriginalInitialInterfaceLoading(), requests: [String] = []
        var constructors = 0, stores = 0
        try loader.load(globals: &state, allocate: { index in
            .init(address: index == 0 ? 0x28000020 : 0, backing: index == 0 ? [UInt8](repeating: 0xa5, count: 0x1f50) : [])
        }, source: { _,_ in throw Stop.unexpectedLegacyProvider }, deviceResult: { _ in throw Stop.unexpectedLegacyProvider },
        constructBitmap: { index,allocation,device,path in
            XCTAssertEqual(index, 0); XCTAssertEqual(path, "PAUSE"); XCTAssertEqual(device, 0x10203040)
            constructors += 1
            return try OriginalBitmapConstructor.constructWithSurfaceLoading(path: path, optional: false,
                backing: allocation.backing, device: device, flags: 0x40, context: &requests) { request, pending in
                pending.append(request.kind)
                switch request.kind {
                case "module": return .init(result: 0x400000)
                case "image":
                    XCTAssertEqual(request.strings, [Array("PAUSE".utf8)])
                    return .init(result: 0x34000010)
                case "getObject":
                    return .init(result: 24, writes: [.init(offset: 4, bytes: [84,0,0,0,23,0,0,0])])
                case "createSurface":
                    XCTAssertEqual(request.words, [device,0])
                    let bytes = try XCTUnwrap(request.bytes)
                    XCTAssertEqual(Array(bytes[8..<16]), [23,0,0,0,84,0,0,0])
                    return .init(result: -1)
                case "message":
                    XCTAssertEqual(request.strings, [Array("Couldn't create art surface.".utf8),Array("PAUSE".utf8)])
                    return .init()
                case "debug": return .init()
                default: XCTFail("Unexpected surface request \(request.kind)"); throw Stop.late
                }
            }
        }, afterBitmap: { index, pending in
            XCTAssertEqual(index, stores); stores += 1
            XCTAssertEqual(try pending.integer(at: 0x44d05c-self.base, as: Int32.self), 1)
        })
        XCTAssertEqual(constructors, 1); XCTAssertEqual(stores, 10)
        XCTAssertEqual(requests, ["module","image","getObject","createSurface","message","debug"])
        XCTAssertEqual(loader.bitmaps.count, 1)
        let loaded = try XCTUnwrap(loader.bitmaps[0x28000020])
        XCTAssertFalse(loaded.input.present)
        XCTAssertEqual(Array(loaded.storage.bytes[..<12]), [0,0,0,0,84,0,0,0,23,0,0,0])
        XCTAssertEqual(Array(loaded.storage.bytes.dropFirst(12)), [UInt8](repeating: 0xa5, count: 0x1f50-12))
        XCTAssertEqual(loaded.storage.defined, [Bool](repeating: true, count: 12)+[Bool](repeating: false, count: 0x1f50-12))
        for (index,slot) in OriginalInitialInterfaceLoading.slots.enumerated() {
            XCTAssertEqual(try state.integer(at: slot-base, as: UInt32.self), index == 0 ? 0x28000020 : 0)
        }
        XCTAssertEqual(try state.integer(at: 0x44d05c-base, as: Int32.self), 0)
    }

    func testLateProvidedConstructorFailureKeepsCommittedInterface() throws {
        var state = try globals(), loader = OriginalInitialInterfaceLoading()
        try loader.load(globals: &state, allocate: { i in
            .init(address: 0x28000020+UInt32(i)*0x2000, backing: [UInt8](repeating: 0xa5, count: 0x1f50))
        }, source: { _,_ in throw Stop.unexpectedLegacyProvider }, deviceResult: { _ in throw Stop.unexpectedLegacyProvider },
        constructBitmap: { _,allocation,_,path in try self.bitmap(path,allocation.backing) })
        try state.write(Int32(1), at: 0x44d05c-base)
        let before = state, previous = loader.bitmaps
        var constructors = 0, stores = 0
        XCTAssertThrowsError(try loader.load(globals: &state, allocate: { i in
            .init(address: 0x29000020+UInt32(i)*0x2000, backing: [UInt8](repeating: 0x5a, count: 0x1f50))
        }, source: { _,_ in throw Stop.unexpectedLegacyProvider }, deviceResult: { _ in throw Stop.unexpectedLegacyProvider },
        constructBitmap: { index,allocation,_,path in
            constructors += 1
            if index == 9 { throw Stop.late }
            return try self.bitmap(path,allocation.backing)
        }, afterBitmap: { index,pending in
            XCTAssertEqual(index, stores); stores += 1
            XCTAssertEqual(try pending.integer(at: OriginalInitialInterfaceLoading.slots[index]-self.base, as: UInt32.self), 0x29000020+UInt32(index)*0x2000)
        })) { error in
            guard case Stop.late = error else { return XCTFail("Unexpected error \(error)") }
        }
        XCTAssertEqual(constructors, 10); XCTAssertEqual(stores, 9)
        XCTAssertEqual(state, before); XCTAssertEqual(loader.bitmaps, previous)
    }

    func testProvidedConstructorBindingFailuresRollBack() throws {
        for wrongPath in [true,false] {
            var state = try globals(), loader = OriginalInitialInterfaceLoading()
            let before = state
            XCTAssertThrowsError(try loader.load(globals: &state, allocate: { i in
                .init(address: 0x28000020+UInt32(i)*0x2000, backing: [UInt8](repeating: 0xa5, count: 0x1f50))
            }, source: { _,_ in throw Stop.unexpectedLegacyProvider }, deviceResult: { _ in throw Stop.unexpectedLegacyProvider },
            constructBitmap: { index,allocation,_,path in
                try self.bitmap(index == 9 && wrongPath ? "PAUSE" : path, allocation.backing, optional: index == 9 && !wrongPath)
            })) { error in
                guard case OriginalStateError.invalidStorage(let reason) = error else { return XCTFail("Unexpected error \(error)") }
                XCTAssertEqual(reason, "Loader bitmap constructor binding")
            }
            XCTAssertEqual(state, before); XCTAssertTrue(loader.bitmaps.isEmpty)
        }
    }
}
