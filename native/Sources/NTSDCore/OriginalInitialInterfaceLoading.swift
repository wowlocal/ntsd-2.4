import Foundation

public struct OriginalInterfaceEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case allocate, construct, load, colorKey, message, debug, release }
    public let kind: Kind, arguments: [UInt32], strings: [[UInt8]]
    public init(_ kind: Kind, _ arguments: [UInt32] = [], _ strings: [[UInt8]] = []) {
        self.kind = kind; self.arguments = arguments; self.strings = strings
    }
}

public struct OriginalInterfaceAllocation: Sendable {
    public let address: UInt32, backing: [UInt8]
    public init(address: UInt32, backing: [UInt8]) { self.address = address; self.backing = backing }
}

/// 43ee50: wrapper construction, required-resource diagnostic and SetColorKey.
/// 43ed10/COM results are opaque device inputs. Surface storage is canonical1/0.
public enum OriginalBitmapConstructor {
    public static func construct(_ resource: OriginalBitmapInput, optional: Bool, backing: [UInt8],
                                 device: UInt32, flags: UInt32, surface: UInt32, colorKeyResult: Int32,
                                 observe: (OriginalInterfaceEvent) throws -> Void = { _ in }) throws -> OriginalLoadedBitmap {
        guard (surface != 0) == resource.present, !resource.path.utf8.contains(0), resource.path.utf8.count < 200 else {
            throw OriginalStateError.invalidStorage("Bitmap constructor device/path boundary")
        }
        try observe(.init(.load, [device, flags, 0], [Array(resource.path.utf8)]))
        var record = try OriginalLoadedBitmap.constructionStorage(resource, backing: backing)
        if surface == 0 {
            if !optional {
                try observe(.init(.message, [0, 0], [Array("Couldn't create art surface.".utf8), Array(resource.path.utf8)]))
                try observe(.init(.debug, [], [Array("Couldn't create art surface.\n".utf8)]))
            }
        } else {
            try observe(.init(.colorKey, [surface, 8], [[UInt8](repeating: 0, count: 8)]))
            if colorKeyResult < 0 {
                try observe(.init(.message, [0, 0], [Array("Couldn't set the color key.".utf8), Array("Error".utf8)]))
                try observe(.init(.debug, [], [Array("Couldn't set the color key.\n".utf8)]))
                try observe(.init(.release, [surface]))
                try record.write(UInt32(0), at: 0)
            }
        }
        // Even required-resource failure returns the wrapper; dimensions that
        // were written before a color-key failure remain defined and unchanged.
        return OriginalLoadedBitmap(input: resource, optional: optional, storage: record)
    }
}

/// Parent41c2f5..41c581, immediately after the actual400-slot bootstrap.
/// Allocation failures skip constructors; ordinary device failures keep wrappers.
/// A supplied constructor owns image/copy/device handling. Buffer its external
/// effects in the enclosing candidate; this loader stages only its own globals
/// and bitmap records until all ten stores and the loading-flag clear succeed.
public struct OriginalInitialInterfaceLoading {
    public static let paths = ["PAUSE", "DEMO", "SCORE_BOARD1", "SCORE_BOARD2", "SCORE_BOARD3", "SCORE_BOARD4", "WIN_ALIVE", "WIN_DEAD", "LOSE_DEAD", "BARS"]
    public static let slots = [0x44ff8c, 0x44f8f8, 0x44fcb4, 0x44fd8c, 0x44f88c, 0x44f87c, 0x44fd90, 0x44fd94, 0x44fb64, 0x44fd7c]
    public private(set) var bitmaps: [UInt32: OriginalLoadedBitmap] = [:]
    public init() {}

    public mutating func load(globals: inout OriginalStateRecord,
                              allocate: (Int) throws -> OriginalInterfaceAllocation,
                              source: (Int, String) throws -> OriginalBitmapInput,
                              deviceResult: (Int) throws -> (surface: UInt32, colorKeyResult: Int32),
                              constructBitmap: ((Int, OriginalInterfaceAllocation, UInt32, String) throws -> OriginalLoadedBitmap)? = nil,
                              afterBitmap: (Int, OriginalStateRecord) throws -> Void = { _, _ in },
                              observe: (OriginalInterfaceEvent) throws -> Void = { _ in }) throws {
        let base = OriginalMatchPreparation.globalBase
        var state = globals, candidate = self
        guard state.bytes.count == OriginalMatchPreparation.globalSize,
              try state.integer(at: 0x44d05c-base, as: Int32.self) == 1 else {
            throw OriginalStateError.invalidStorage("Initial interface loading context")
        }
        let device = try state.integer(at: 0x457578-base, as: UInt32.self)
        for (index,path) in Self.paths.enumerated() {
            try observe(.init(.allocate, [0x1f50]))
            let allocation = try allocate(index)
            if allocation.address != 0 {
                guard candidate.bitmaps[allocation.address] == nil else { throw OriginalStateError.invalidStorage("Live bitmap allocation reused") }
                try observe(.init(.construct, [allocation.address, 0x40, 0], [Array(path.utf8)]))
                if let constructBitmap {
                    candidate.bitmaps[allocation.address] = try .checkedConstruction(
                        constructBitmap(index, allocation, device, path), path: path, optional: false)
                } else {
                    let input = try source(index, path), output = try deviceResult(index)
                    guard input.path == path else { throw OriginalStateError.invalidStorage("Initial interface resource binding") }
                    candidate.bitmaps[allocation.address] = try OriginalBitmapConstructor.construct(input, optional: false,
                        backing: allocation.backing, device: device, flags: 0x40, surface: output.surface,
                        colorKeyResult: output.colorKeyResult, observe: observe)
                }
            }
            // No release of the previous global pointer occurs on this path.
            try state.write(allocation.address, at: Self.slots[index]-base)
            try afterBitmap(index,state)
        }
        try state.write(Int32(0), at: 0x44d05c-base) // Actual41c577, after all10 stores.
        self = candidate; globals = state
    }
}
