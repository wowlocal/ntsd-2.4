import Foundation

public struct OriginalMenuPanelBitmapEvent: Codable, Equatable, Sendable {
    public let kind: String, arguments: [UInt32], strings: [[UInt8]]
    public init(_ kind: String,_ arguments: [UInt32] = [],_ strings: [[UInt8]] = []) {
        self.kind = kind;self.arguments = arguments;self.strings = strings
    }
}

/// Whole43cc60. Retain allocation generations separately, including freed
/// storage; a later malloc may return the same opaque address with new backing.
/// Path, allocator and graphics-device input remain platform boundaries.
public struct OriginalMenuPanelBitmap {
    public struct Record: Sendable {
        public let address: UInt32
        public fileprivate(set) var bitmap: OriginalLoadedBitmap, surface: UInt32, live: Bool
    }
    public private(set) var records: [Record] = []
    public init() {}
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Menu panel bitmap: "+text) }

    /// At most 500 frames: the room of each of the four rectangle arrays. (A
    /// frame of other than four values traps at its first missing field, as
    /// `Interface.init`'s precondition does; a declared check here moved the
    /// optimiser's inlining of WinMain's startup: E5f-4's evidence.)
    static func checkFrames(_ frames: [[Int32]]) throws {
        guard frames.count <= 500 else { throw error("At most 500 atlas frames") }
    }

    /// `frames`: the game's panel atlas rectangles (ENGINE_SPLIT E5f-4:
    /// `Interface.panelFrames`), checked with the globals' extent.
    @discardableResult
    public mutating func load(globals: inout OriginalStateRecord, frames: [[Int32]],
        allocate: () throws -> OriginalInterfaceAllocation,
        source: (String) throws -> OriginalBitmapInput,
        deviceResult: () throws -> (surface: UInt32,colorKeyResult: Int32),
        observe: (OriginalMenuPanelBitmapEvent) throws -> Void = { _ in }) throws -> Bool {
        let base = OriginalMatchPreparation.globalBase
        guard globals.byteCount == OriginalMatchPreparation.globalSize else { throw Self.error("Global extent") }
        try Self.checkFrames(frames)
        var state = globals, candidate = self
        func global(_ address: Int,_ value: UInt32) throws {
            try state.write(value,at: address-base)
            try observe(.init("write",[0,UInt32(address),4,value]))
        }
        func finish(_ result: Bool) -> Bool { globals = state;self = candidate;return result }
        let old = try state.integer(at: 0x458420-base,as: UInt32.self)
        if old != 0 {
            guard let i = candidate.records.lastIndex(where: { $0.live && $0.address == old }) else { throw Self.error("Unknown/dead prior bitmap") }
            try observe(.init("destroy",[old]))
            let surface = candidate.records[i].surface
            guard try candidate.records[i].bitmap.storage.integer(at: 0,as: UInt32.self) == (surface == 0 ? 0 : 1) else { throw Self.error("Surface binding") }
            if surface != 0 {
                try observe(.init("release",[surface]))
                try candidate.records[i].bitmap.storage.write(UInt32(0),at: 0)
                candidate.records[i].surface = 0
            }
            try observe(.init("free",[old]));candidate.records[i].live = false
            try global(0x458420,0)
        }
        try observe(.init("allocate",[0x1f50]))
        let allocation = try allocate(), address = allocation.address
        if address == 0 { try global(0x458420,0);return finish(false) }
        guard !candidate.records.contains(where: { $0.live && $0.address == address }) else { throw Self.error("Reused live allocation") }
        var pathBytes: [UInt8] = [], offset = 0x453d40-base
        while true {
            let byte = try state.integer(at: offset,as: UInt8.self);if byte == 0 { break }
            pathBytes.append(byte);offset += 1
        }
        guard let path = String(bytes: pathBytes,encoding: .utf8) else { throw Self.error("Unsupported path encoding") }
        try observe(.init("construct",[address,0x40,0],[pathBytes]))
        let input = try source(path), output = try deviceResult()
        guard input.path == path else { throw Self.error("Path binding") }
        let device = try state.integer(at: 0x457578-base,as: UInt32.self)
        var bitmap = try OriginalBitmapConstructor.construct(input,optional: false,backing: allocation.backing,
            device: device,flags: 0x40,surface: output.surface,colorKeyResult: output.colorKeyResult) { event in
                try observe(.init(event.kind.rawValue,event.arguments,event.strings))
            }
        try global(0x458420,address)
        let surface: UInt32 = output.colorKeyResult < 0 ? 0 : output.surface
        if surface != 0 {
            // Original43ccf2..43cf10: fixed atlas metadata (the game's frames),
            // independent of DIB dimensions. Count is written after all the
            // rectangle fields.
            for (frame,rectangle) in frames.enumerated() {
                for (field,start) in [0x10,0x7e0,0xfb0,0x1780].enumerated() {
                    let offset = start+4*frame, value = rectangle[field]
                    try bitmap.storage.write(value,at: offset)
                    try observe(.init("write",[address,UInt32(offset),4,UInt32(bitPattern: value)]))
                }
            }
            try bitmap.storage.write(Int32(frames.count),at: 0x0c)
            try observe(.init("write",[address,0x0c,4,UInt32(frames.count)]))
        }
        candidate.records.append(.init(address: address,bitmap: bitmap,surface: surface,live: true))
        return finish(surface != 0)
    }
}
