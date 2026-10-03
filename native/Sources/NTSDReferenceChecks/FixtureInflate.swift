import Foundation
#if canImport(Compression)
import Compression
#endif
import CZlib

/// Raw DEFLATE decode for compressed fixtures, with the contract of
/// `compression_decode_buffer(..., COMPRESSION_ZLIB)`: the number of bytes
/// written, the destination size when the output is truncated, 0 on error.
/// Apple platforms keep Compression; elsewhere the host zlib decodes, and a
/// macOS test requires both to agree on every fixture blob.
enum FixtureInflate {
    static func decode(_ destination: UnsafeMutablePointer<UInt8>, _ capacity: Int,
                       _ source: UnsafePointer<UInt8>, _ count: Int) -> Int {
        #if canImport(Compression)
        return compression_decode_buffer(destination, capacity, source, count, nil, COMPRESSION_ZLIB)
        #else
        return zlib(destination, capacity, source, count)
        #endif
    }

    static func zlib(_ destination: UnsafeMutablePointer<UInt8>, _ capacity: Int,
                     _ source: UnsafePointer<UInt8>, _ count: Int) -> Int {
        guard capacity > 0, count > 0, capacity <= Int(UInt32.max), count <= Int(UInt32.max) else { return 0 }
        var stream = z_stream()
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return 0 }
        defer { inflateEnd(&stream) }
        stream.next_in = UnsafeMutablePointer(mutating: source)
        stream.avail_in = uInt(count)
        stream.next_out = destination
        stream.avail_out = uInt(capacity)
        let status = inflate(&stream, Z_FINISH)
        let written = capacity - Int(stream.avail_out)
        switch status {
        case Z_STREAM_END: return written
        case Z_BUF_ERROR where stream.avail_out == 0: return written
        default: return 0
        }
    }
}
