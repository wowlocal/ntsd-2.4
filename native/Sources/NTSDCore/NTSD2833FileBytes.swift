import Foundation

/// Owned ordinary-file bytes for the target loader. The source helper at
/// 414970..4149d9 decrypts the whole buffer in place and returns its starting
/// cursor separately. This has no text-mode stream or temporary-file stage.
public struct NTSD2833FileBytes: Equatable {
    public enum Boundary: Error, Equatable {
        /// Source suffix reads before a shorter name; embedded NUL would name
        /// a different input. Neither is part of this owned-name interface.
        case filenameExtent
        /// The current owned-file interface covers nonnegative Int32 extents.
        /// Large/short ReadFile responses need the enclosing file-API contract.
        case bufferExtent
        /// The source do/while reads a byte even for a zero-length DAT buffer.
        /// Rejecting this input is not a match to an original memory fault.
        case emptyDATBuffer
    }
    private static let key = Array("SiuHungIsAGoodBearBecauseHeIsVeryGood".utf8)
    public let fileName: [UInt8]
    /// Includes the transformed123-byte header; no source after-state is loaded.
    public let storage: [UInt8]
    /// Preserve123 even when it lies beyond the supplied end of a short file.
    public let cursorOffset: Int
    public var endOffset: Int { storage.count }
    public var isAtEnd: Bool { cursorOffset >= endOffset }
    public var logicalBytes: [UInt8] { Array(storage.dropFirst(cursorOffset)) }

    public init(raw: [UInt8],fileName: [UInt8]) throws {
        guard fileName.count >= 3,!fileName.contains(0) else { throw Boundary.filenameExtent }
        guard raw.count <= Int(Int32.max) else { throw Boundary.bufferExtent }
        self.fileName = fileName
        let suffix = Array(fileName.suffix(3))
        let encrypted = (suffix[0] == 0x64 || suffix[0] == 0x44)
            && (suffix[1] == 0x61 || suffix[1] == 0x41)
            && (suffix[2] == 0x74 || suffix[2] == 0x54)
        if encrypted {
            guard !raw.isEmpty else { throw Boundary.emptyDATBuffer }
            var bytes = raw
            for index in bytes.indices { bytes[index] = bytes[index] &- Self.key[index % 37] }
            storage = bytes;cursorOffset = 123
        } else {
            storage = raw;cursorOffset = 0
        }
    }
}
