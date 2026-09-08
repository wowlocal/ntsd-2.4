import Foundation

public struct OriginalBitmapDrawInput: Codable, Equatable, Sendable {
    public let x: Int32, y: Int32, frame: Int32
    public let colorKey: UInt32, mirrored: UInt32
    public let sourceSurface: UInt32, targetSurface: UInt32
    public let viewportWidth: Int32, viewportHeight: Int32
    public init(x: Int32, y: Int32, frame: Int32, colorKey: UInt32, mirrored: UInt32,
                sourceSurface: UInt32, targetSurface: UInt32, viewportWidth: Int32, viewportHeight: Int32) {
        self.x = x; self.y = y; self.frame = frame; self.colorKey = colorKey; self.mirrored = mirrored
        self.sourceSurface = sourceSurface; self.targetSurface = targetSurface
        self.viewportWidth = viewportWidth; self.viewportHeight = viewportHeight
    }
}

public struct OriginalBitmapBlit: Codable, Equatable, Sendable {
    public let sourceSurface: UInt32, targetSurface: UInt32
    /// Original signed left/top/right/bottom values, including zero/inverted rectangles.
    public let source: [Int32], destination: [Int32]
    public let flags: UInt32
    /// Exact100-byte DDBLTFX at the platform boundary, or nil for a null pointer.
    public let effects: [UInt8]?
}

public struct OriginalBitmapDrawRead: Codable, Equatable, Sendable {
    public let offset: Int, value: UInt32, defined: Bool
}

public struct OriginalBitmapClip: Codable, Equatable, Sendable {
    public let beforeSource: [Int32], beforeDestination: [Int32]
    public let source: [Int32], destination: [Int32], visible: Bool
}

/// Whole43f010/43ef70 through ret24. The platform performs Blt(+14); HRESULT
/// does not control subsequent drawing. Pixel conversion/device IO are separate.
public enum OriginalBitmapDrawing {
    /// Bitmap backing is an explicit input. This helper really reads untouched
    /// allocator words, notably +0c after43ee50 and negative frame indices.
    /// Observe their provenance without marking them initialized or inventing0.
    /// This does not establish where a Windows allocator obtained those bytes.
    @discardableResult
    public static func draw(_ input: OriginalBitmapDrawInput, bitmap: OriginalStateRecord,
                            observeRead: (OriginalBitmapDrawRead) throws -> Void = { _ in },
                            observeClip: (OriginalBitmapClip) throws -> Void = { _ in },
                            perform: (OriginalBitmapBlit) throws -> Int32) throws -> Int32 {
        guard bitmap.bytes.count == 0x1f50 else { throw OriginalStateError.invalidStorage("Bitmap draw extent") }
        func word(_ offset: UInt32) throws -> Int32 {
            let i = Int(offset)
            guard i <= bitmap.bytes.count-4 else { throw OriginalStateError.outOfBounds(offset: i,count: 4) }
            var value = (0..<4).reduce(UInt32(0)) { $0 | UInt32(bitmap.bytes[i+$1]) << ($1*8) }
            if offset == 0 {
                guard value == (input.sourceSurface == 0 ? 0 : 1) else { throw OriginalStateError.invalidStorage("Bitmap surface binding") }
                // Negative/wrapped frame indices can read the pointer AS a
                // coordinate. Rebind this one known word before arithmetic.
                value = input.sourceSurface
            }
            try observeRead(.init(offset: i,value: value,defined: bitmap.defined[i..<i+4].allSatisfy { $0 }))
            return Int32(bitPattern: value)
        }
        func clip(_ destination: inout [Int32], _ source: inout [Int32]) throws -> Bool {
            let beforeSource = source, beforeDestination = destination
            let width = input.viewportWidth, height = input.viewportHeight
            func apply() -> Bool {
            // Strict comparisons: touching an edge can produce a zero-area Blt.
            if destination[0] < 0 && destination[2] < 0 { return false }
            if destination[0] > width && destination[2] > width { return false }
            if destination[1] < 0 && destination[3] < 0 { return false }
            if destination[1] > height && destination[3] > height { return false }
            if destination[0] < 0 { source[0] = source[0] &- destination[0]; destination[0] = 0 }
            if destination[1] < 0 { source[1] = source[1] &- destination[1]; destination[1] = 0 }
            if destination[2] > width { source[2] = source[2] &+ (width &- destination[2]); destination[2] = width }
            if destination[3] > height { source[3] = source[3] &+ (height &- destination[3]); destination[3] = height }
            return true
            }
            let visible = apply()
            try observeClip(.init(beforeSource: beforeSource,beforeDestination: beforeDestination,
                                  source: source,destination: destination,visible: visible))
            return visible
        }
        let effects: [UInt8]?
        if input.mirrored != 0 {
            var bytes = [UInt8](repeating: 0,count: 100); bytes[0] = 100; bytes[4] = 2; effects = bytes
        } else { effects = nil }
        let flags: UInt32 = 0x1000000 | (input.colorKey != 0 ? 0x8000 : 0) | (input.mirrored != 0 ? 0x800 : 0)
        func blit(_ destination: [Int32], _ source: [Int32], whole: Bool = false) throws -> Int32 {
            if whole && input.targetSurface == 0 { throw OriginalStateError.invalidStorage("Null bitmap target surface") }
            _ = try word(0)
            guard input.targetSurface != 0 else { throw OriginalStateError.invalidStorage("Null bitmap target surface") }
            return try perform(.init(sourceSurface: input.sourceSurface,targetSurface: input.targetSurface,
                                     source: source,destination: destination,flags: flags,effects: effects))
        }
        if try word(0x0c) == 0 || input.frame < 0 {
            let width = try word(4), height = try word(8)
            var destination = [input.x,input.y,input.x &+ width,input.y &+ height]
            var source: [Int32] = [0,0,width,height]
            if try clip(&destination,&source) { _ = try blit(destination,source,whole: true) }
            // Deliberate fallthrough: negative frames may draw AGAIN below.
        }
        guard try input.frame < word(0x0c) else { return input.frame }
        let offset = UInt32(bitPattern: input.frame) &* 4
        let x = try word(offset &+ 0x10), width = try word(offset &+ 0xfb0)
        let y = try word(offset &+ 0x7e0), height = try word(offset &+ 0x1780)
        var destination = [input.x,input.y,input.x &+ width,input.y &+ height]
        var source = [x,y,x &+ width,y &+ height]
        guard try clip(&destination,&source) else { return 0 }
        if input.mirrored != 0 {
            let originalX = try word(offset &+ 0x10), originalWidth = try word(offset &+ 0xfb0)
            let clippedLeft = source[0] &- originalX
            source[0] = originalX &+ originalX &- source[2] &+ originalWidth
            source[2] = originalWidth &- clippedLeft &+ originalX
        }
        return try blit(destination,source)
    }
}
