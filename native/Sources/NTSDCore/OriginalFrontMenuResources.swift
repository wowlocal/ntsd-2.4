import Foundation

public struct OriginalFrontMenuEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case allocate, construct, load, colorKey, message, debug, release, write }
    public let kind: Kind, arguments: [UInt32], strings: [[UInt8]]
    public init(_ kind: Kind, _ arguments: [UInt32] = [], _ strings: [[UInt8]] = []) {
        self.kind = kind; self.arguments = arguments; self.strings = strings
    }
}

public struct OriginalFrontMenuResourceResult: Codable, Equatable, Sendable {
    public enum Continuation: String, Codable, Sendable { case settings, ready, nullBitmap }
    public let continuation: Continuation
    public let nullBitmapSlot: Int?
}

/// Original424755..427089 startup resources, or flag0 skip to42709b. Uses the
/// shared constructor and recovered resource metadata. Settings423480 and the
/// later flag clear have not executed when this returns .settings.
public struct OriginalFrontMenuResources {
    public static let paths = ["LF2_CURSOR","MENU_CLIP","MENU_CLIP2","MENU_CLIP3","MENU_CLIP4","MENU_CLIP5","MENU_CLIP6","MENU_CLIP7","MENU_WAIT","SLOGAN","ENDING",
                               "LF2_CURSOR","CS2","CS3","CS4","CS5","CS6","FRAME","WORDS0","WORDS1","WORDS2","WORDS3","WORDS4","WORDS5"]
    public static let slots = [0x451170,0x4511a0,0x451168,0x451178,0x45116c,0x45117c,0x4511a4,0x451188,0x45118c,0x45119c,0x451190,
                               0x451198,0x451174,0x451164,0x451184,0x451194,0x451180,0x4511a8,0x44faf4,0x44f888,0x44fcbc,0x44fb68,0x44faf8,0x44fd80]
    public private(set) var bitmaps: [UInt32:OriginalLoadedBitmap] = [:]
    public init() {}

    @discardableResult
    public mutating func load(world: OriginalStateRecord, globals: inout OriginalStateRecord,
                              allocate: (Int) throws -> OriginalInterfaceAllocation,
                              source: (Int,String) throws -> OriginalBitmapInput,
                              deviceResult: (Int) throws -> (surface: UInt32,colorKeyResult: Int32),
                              observe: (OriginalFrontMenuEvent) throws -> Void = { _ in }) throws -> OriginalFrontMenuResourceResult {
        let base = OriginalMatchPreparation.globalBase
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else { throw OriginalStateError.invalidStorage("Front menu globals extent") }
        let selector = try world.integer(at: 0,as: Int32.self)
        guard selector != 1 && selector != 2 else { throw OriginalStateError.invalidStorage("Front menu World dispatch requires its other branch") }
        var state = globals, candidate = self
        var addresses: [UInt32] = [], loaded: [OriginalLoadedBitmap?] = [], issued = Set(candidate.bitmaps.keys)
        func finish(_ continuation: OriginalFrontMenuResourceResult.Continuation, slot: Int? = nil) -> OriginalFrontMenuResourceResult {
            for (index,address) in addresses.enumerated() where address != 0 { candidate.bitmaps[address] = loaded[index]! }
            self = candidate; globals = state
            return .init(continuation: continuation,nullBitmapSlot: slot)
        }
        func global(_ address: Int, _ value: UInt32, size: Int = 4) throws {
            if size == 2 { try state.write(UInt16(truncatingIfNeeded: value),at: address-base) }
            else { try state.write(value,at: address-base) }
            try observe(.init(.write,[0,UInt32(address),UInt32(size),value]))
        }
        let phase = try state.integer(at: 0x4511f8-base,as: UInt32.self)
        try global(0x4511f8,UInt32(1) &- phase)
        if try state.integer(at: 0x44d068-base,as: UInt32.self) == 0 { return finish(.ready) }
        let device = try state.integer(at: 0x457578-base,as: UInt32.self)
        func construct(_ index: Int) throws {
            try observe(.init(.allocate,[0x1f50]))
            let allocation = try allocate(index), path = Self.paths[index]
            addresses.append(allocation.address)
            if allocation.address == 0 { loaded.append(nil) }
            else {
                guard issued.insert(allocation.address).inserted else { throw OriginalStateError.invalidStorage("Front menu reused live allocation") }
                try observe(.init(.construct,[allocation.address,0x40,0],[Array(path.utf8)]))
                let input = try source(index,path), output = try deviceResult(index)
                guard input.path == path else { throw OriginalStateError.invalidStorage("Front menu resource binding") }
                let bitmap = try OriginalBitmapConstructor.construct(input,optional: false,backing: allocation.backing,
                    device: device,flags: 0x40,surface: output.surface,colorKeyResult: output.colorKeyResult) { event in
                        try observe(.init(OriginalFrontMenuEvent.Kind(rawValue: event.kind.rawValue)!,event.arguments,event.strings))
                    }
                loaded.append(bitmap)
            }
            try global(Self.slots[index],allocation.address)
            if index == 0 {
                // Eight two-byte names, not whole11-byte field clears.
                for seat in 0..<8 { try global(0x44fcc0+11*seat,UInt32(0x31+seat),size: 2) }
            }
        }
        func write(_ index: Int, _ offset: Int, _ value: Int32) throws {
            try loaded[index]!.storage.write(value,at: offset)
            try observe(.init(.write,[addresses[index],UInt32(offset),4,UInt32(bitPattern: value)]))
        }
        for index in 0..<11 { try construct(index) }
        for sheet in OriginalFrontMenuRectangles.sheets {
            let index = Self.slots.firstIndex(of: sheet.slot)!
            guard loaded[index] != nil else { return finish(.nullBitmap,slot: sheet.slot) }
            for (frame,rectangle) in sheet.frames.enumerated() {
                for (field,offset) in [0x10,0x7e0,0xfb0,0x1780].enumerated() {
                    try write(index,offset+frame*4,rectangle[field])
                }
            }
            try write(index,0x0c,Int32(sheet.frames.count))
        }
        for index in 11..<24 { try construct(index) }
        for index in 18..<24 {
            guard loaded[index] != nil else { return finish(.nullBitmap,slot: Self.slots[index]) }
            try write(index,0x0c,256)
        }
        // All six counts are written BEFORE the interleaved glyph loop.
        for glyph in 0..<256 {
            let rectangle: [Int32] = [Int32((glyph & 15)*16),Int32((glyph >> 4)*16+1),8,16]
            for index in 18..<24 {
                for (field,offset) in [0x10,0x7e0,0xfb0,0x1780].enumerated() {
                    try write(index,offset+glyph*4,rectangle[field])
                }
            }
        }
        return finish(.settings)
    }
}
