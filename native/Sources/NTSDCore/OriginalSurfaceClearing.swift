/// Original401250 passes null source and destination rectangles. A clear is
/// for the entire target surface; it must not invent a viewport rectangle.
public struct OriginalSurfaceClearRequest: Codable, Equatable, Sendable {
    public let target: UInt32, flags: UInt32
    public let effects: [UInt8], defined: [Bool]
}

/// Whole401250..401281. Only size and fill color are written into the100-byte
/// DDBLTFX local; the remaining92 bytes keep supplied caller backing. The COM
/// result is returned unchanged. Actual raster submission is a device boundary.
public enum OriginalSurfaceClearing {
    public static func clear(target: UInt32, color: UInt32, backing: [UInt8],
        perform: (OriginalSurfaceClearRequest) throws -> Int32) throws -> Int32 {
        guard backing.count == 100 else {
            throw OriginalStateError.invalidStorage("Surface clear effects extent")
        }
        var effects = try OriginalStateRecord(bytes: backing, defined: Array(repeating: false, count: 100))
        try effects.write(UInt32(100), at: 0)
        try effects.write(color, at: 0x50)
        guard target != 0 else { throw OriginalStateError.invalidStorage("Null surface clear target") }
        return try perform(.init(target: target, flags: 0x1000400, effects: effects.bytes, defined: effects.defined))
    }
}
