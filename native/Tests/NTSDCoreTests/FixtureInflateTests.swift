import Foundation
import XCTest
#if canImport(Compression)
import Compression
#endif
import CZlib
@testable import NTSDReferenceChecks

/// Hosts without Compression decode fixtures with zlib, so on every fixture
/// DEFLATE blob zlib must equal Compression in bytes, length and truncation.
/// The first blob of each fixture runs by default; NTSD_FIXTURE_INFLATE_ALL=1
/// runs all of them.
final class FixtureInflateTests: XCTestCase {
    func testZlibMatchesCompressionOnFixtureBlobs() throws {
        #if canImport(Compression)
        let all = ProcessInfo.processInfo.environment["NTSD_FIXTURE_INFLATE_ALL"] == "1"
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
        let iterator = try XCTUnwrap(FileManager.default.enumerator(at: fixtures, includingPropertiesForKeys: nil))
        let files = iterator.compactMap { $0 as? URL }.filter { $0.pathExtension == "json" }.sorted { $0.path < $1.path }
        let key = Data(#""deflate""#.utf8), quote = UInt8(ascii: "\"")
        var blobs = 0, wrapped = 0, packedBytes = 0, inflatedBytes = 0
        for url in files {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            var cursor = data.startIndex
            while let found = data.range(of: key, in: cursor..<data.endIndex) {
                var i = found.upperBound
                while i < data.endIndex, [0x20, 0x09, 0x0a, 0x0d].contains(data[i]) { i += 1 }
                guard i < data.endIndex, data[i] == UInt8(ascii: ":") else { cursor = found.upperBound; continue }
                i += 1
                while i < data.endIndex, [0x20, 0x09, 0x0a, 0x0d].contains(data[i]) { i += 1 }
                guard i < data.endIndex, data[i] == quote, let end = data[(i + 1)...].firstIndex(of: quote) else { cursor = found.upperBound; continue }
                cursor = end + 1
                var packed = [UInt8](try XCTUnwrap(Data(base64Encoded: data[(i + 1)..<end]), url.lastPathComponent))
                var size = Self.inflatedSize(packed)
                // original-window-close.json stores zlib streams; its test strips the
                // 2-byte header and 4-byte Adler-32 before the raw decode.
                if size == nil, packed.count > 6, packed[0] & 0x0f == 8, (Int(packed[0]) << 8 | Int(packed[1])) % 31 == 0 {
                    packed = Array(packed.dropFirst(2).dropLast(4)); size = Self.inflatedSize(packed); wrapped += 1
                }
                let count = try XCTUnwrap(size, "\(url.lastPathComponent) blob \(blobs) is not DEFLATE")
                try Self.compare(packed, count: count, capacity: count + 1, context: url.lastPathComponent)
                if count > 1 && count <= 4 << 20 { try Self.compare(packed, count: count - 1, capacity: count - 1, context: url.lastPathComponent) }
                blobs += 1; packedBytes += packed.count; inflatedBytes += count
                if !all { break }
            }
        }
        XCTAssertGreaterThan(blobs, 0)
        print("FixtureInflate zlib matched Compression on \(blobs) blobs (\(wrapped) zlib-wrapped) from \(files.count) fixtures: \(packedBytes) packed, \(inflatedBytes) inflated bytes, all=\(all)")
        #else
        throw XCTSkip("Compression is the reference and exists only on Apple platforms")
        #endif
    }

    #if canImport(Compression)
    /// Both decoders write `capacity` bytes at most and must return `count`.
    private static func compare(_ packed: [UInt8], count: Int, capacity: Int, context: String) throws {
        var viaZlib = [UInt8](repeating: 0, count: capacity), viaCompression = viaZlib
        let z = packed.withUnsafeBufferPointer { s in viaZlib.withUnsafeMutableBufferPointer { FixtureInflate.zlib($0.baseAddress!, $0.count, s.baseAddress!, s.count) } }
        let c = packed.withUnsafeBufferPointer { s in viaCompression.withUnsafeMutableBufferPointer {
            compression_decode_buffer($0.baseAddress!, $0.count, s.baseAddress!, s.count, nil, COMPRESSION_ZLIB) } }
        XCTAssertEqual(z, count, context); XCTAssertEqual(c, count, context)
        let same = viaZlib.withUnsafeBytes { a in viaCompression.withUnsafeBytes { b in memcmp(a.baseAddress!, b.baseAddress!, capacity) == 0 } }
        XCTAssertTrue(same, "\(context): decoded bytes differ")
    }
    #endif

    /// Full raw-DEFLATE length via streaming zlib, or nil if the stream is invalid.
    private static func inflatedSize(_ packed: [UInt8]) -> Int? {
        var stream = z_stream()
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return nil }
        defer { inflateEnd(&stream) }
        var scratch = [UInt8](repeating: 0, count: 1 << 20), total = 0
        return packed.withUnsafeBufferPointer { input -> Int? in
            stream.next_in = UnsafeMutablePointer(mutating: input.baseAddress)
            stream.avail_in = uInt(input.count)
            while true {
                let status = scratch.withUnsafeMutableBufferPointer { out -> Int32 in
                    stream.next_out = out.baseAddress; stream.avail_out = uInt(out.count)
                    return inflate(&stream, Z_NO_FLUSH)
                }
                total += scratch.count - Int(stream.avail_out)
                if status == Z_STREAM_END { return total }
                guard status == Z_OK else { return nil }
            }
        }
    }
}
