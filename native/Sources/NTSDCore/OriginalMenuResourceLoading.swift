import Foundation

public struct OriginalMenuResourceCheckpoint: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case prefix, bitmap, seats, flag, complete }
    public let kind: Kind, index: Int
    public init(_ kind: Kind, index: Int = -1) { self.kind = kind; self.index = index }
}

public struct OriginalMenuResourceResult: Codable, Equatable, Sendable {
    public enum Continuation: String, Codable, Sendable { case ready, nullSpark }
    public let continuation: Continuation
    /// Original caller local+3c, captured BEFORE constructors/seat initialization.
    public let selectionAtEntry: UInt32
}

/// 4297ae..429e5a, after the real menu prologue/music request. All eleven
/// resources share43ee50. The SPARK rectangle writes leave every other byte
/// and initialization mask untouched. A supplied constructor owns image/copy/
/// device handling; the enclosing operation must stage its external effects.
public struct OriginalMenuResourceLoading {
    public static let paths = ["CHARMENU","CM1","CM2","CM3","CM4","CM5","CMA","CMA2","CMC","RFACE","SPARK"]
    public static let slots = [0x4512c4,0x4512b0,0x4512b4,0x4512b8,0x4512bc,0x4512c0,0x4512ac,0x4512a8,0x44fd88,0x44fd84,0x44f8fc]
    public private(set) var bitmaps: [UInt32: OriginalLoadedBitmap] = [:]
    public init() {}

    @discardableResult
    public mutating func load(globals: inout OriginalStateRecord,
                              allocate: (Int) throws -> OriginalInterfaceAllocation,
                              source: (Int, String) throws -> OriginalBitmapInput,
                              deviceResult: (Int) throws -> (surface: UInt32, colorKeyResult: Int32),
                              constructBitmap: ((Int, OriginalInterfaceAllocation, UInt32, String) throws -> OriginalLoadedBitmap)? = nil,
                              checkpoint: (OriginalMenuResourceCheckpoint, OriginalStateRecord, [UInt32:OriginalLoadedBitmap]) throws -> Void = { _,_,_ in },
                              observe: (OriginalInterfaceEvent) throws -> Void = { _ in }) throws -> OriginalMenuResourceResult {
        let base = OriginalMatchPreparation.globalBase
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else { throw OriginalStateError.invalidStorage("Menu resource globals extent") }
        var state = globals, candidate = self
        let current = try state.integer(at: 0x44d020-base,as: UInt32.self)
        let selection = try state.integer(at: 0x4512c8-base,as: UInt32.self)
        let load = try state.integer(at: 0x44d07c-base,as: UInt32.self) != 0
        try state.write(current,at: 0x4512cc-base)
        try checkpoint(.init(.prefix),state,candidate.bitmaps)
        if load {
            let device = try state.integer(at: 0x457578-base,as: UInt32.self)
            for (index,path) in Self.paths.enumerated() {
                try observe(.init(.allocate,[0x1f50]))
                let allocation = try allocate(index)
                if allocation.address != 0 {
                    guard candidate.bitmaps[allocation.address] == nil else { throw OriginalStateError.invalidStorage("Live menu bitmap allocation reused") }
                    try observe(.init(.construct,[allocation.address,0x40,0],[Array(path.utf8)]))
                    if let constructBitmap {
                        candidate.bitmaps[allocation.address] = try .checkedConstruction(
                            constructBitmap(index,allocation,device,path),path: path,optional: false)
                    } else {
                        let input = try source(index,path), output = try deviceResult(index)
                        guard input.path == path else { throw OriginalStateError.invalidStorage("Menu resource binding") }
                        candidate.bitmaps[allocation.address] = try OriginalBitmapConstructor.construct(input,optional: false,backing: allocation.backing,
                            device: device,flags: 0x40,surface: output.surface,colorKeyResult: output.colorKeyResult,observe: observe)
                    }
                }
                // This path replaces old global pointers without releasing them.
                try state.write(allocation.address,at: Self.slots[index]-base)
                try checkpoint(.init(.bitmap,index: index),state,candidate.bitmaps)
            }
            for index in 0..<8 {
                try state.write(UInt32(0),at: 0x451288+index*4-base)
                try state.write(UInt32(0),at: 0x451268+index*4-base)
                try state.write(UInt32.max,at: 0x451248+index*4-base)
            }
            try checkpoint(.init(.seats),state,candidate.bitmaps)
            let address = try state.integer(at: 0x44f8fc-base,as: UInt32.self)
            if address == 0 {
                // Explicit boundary BEFORE original429b21 writes through NULL.
                // Preserve the partial state; this result must not enter dispatch.
                self = candidate; globals = state
                return .init(continuation: .nullSpark,selectionAtEntry: selection)
            }
            guard var spark = candidate.bitmaps[address] else { throw OriginalStateError.invalidStorage("SPARK ownership") }
            try spark.storage.write(Int32(20),at: 0x0c)
            for i in 1...4 {
                for row in 0...1 {
                    let index = i+row*10
                    try spark.storage.write(Int32(i*102),at: 0x10+index*4)
                    try spark.storage.write(Int32(row*128),at: 0x7e0+index*4)
                    try spark.storage.write(Int32(102),at: 0xfb0+index*4)
                    if index == 13 {
                        //429c50 clears the load flag BEFORE height[13].
                        try state.write(UInt32(0),at: 0x44d07c-base)
                        candidate.bitmaps[address] = spark
                        try checkpoint(.init(.flag),state,candidate.bitmaps)
                    }
                    try spark.storage.write(Int32(80),at: 0x1780+index*4)
                }
            }
            for i in 1...4 {
                for row in 0...1 {
                    let index = i+5+row*10
                    try spark.storage.write(Int32(i*61),at: 0x10+index*4)
                    try spark.storage.write(Int32(80+row*128),at: 0x7e0+index*4)
                    try spark.storage.write(Int32(61),at: 0xfb0+index*4)
                    try spark.storage.write(Int32(48),at: 0x1780+index*4)
                }
            }
            candidate.bitmaps[address] = spark
        }
        try checkpoint(.init(.complete),state,candidate.bitmaps)
        self = candidate; globals = state
        return .init(continuation: .ready,selectionAtEntry: selection)
    }
}
