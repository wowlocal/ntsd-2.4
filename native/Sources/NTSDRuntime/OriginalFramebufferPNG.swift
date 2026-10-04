import Foundation
import NTSDCore

/// A PNG (8-bit RGB, stored deflate blocks) of an XRGB framebuffer, written the
/// same way by every host so presented frames can be compared byte for byte.
public enum OriginalFramebufferPNG {
    private static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1 }
        return c
    }
    private static func crc(_ bytes: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xffffffff
        for b in bytes { c = crcTable[Int((c ^ UInt32(b)) & 0xff)] ^ (c >> 8) }
        return c ^ 0xffffffff
    }
    private static func big(_ value: UInt32) -> [UInt8] { [24,16,8,0].map { UInt8(truncatingIfNeeded:value >> UInt32($0)) } }
    private static func chunk(_ type: String,_ data: [UInt8]) -> [UInt8] {
        let body = Array(type.utf8)+data
        return big(UInt32(data.count))+body+big(crc(body))
    }
    public static func encode(_ frame: OriginalFramebuffer) -> Data {
        var raw: [UInt8] = []; raw.reserveCapacity((frame.width*3+1)*frame.height)
        frame.pixels.withUnsafeBytes { p in
            for y in 0..<frame.height {
                raw.append(0)
                for x in 0..<frame.width {
                    let o = (y*frame.width+x)*4
                    raw.append(p[o+2]); raw.append(p[o+1]); raw.append(p[o])
                }
            }
        }
        var zlib: [UInt8] = [0x78,0x01]
        var offset = 0
        repeat {
            let count = min(65535,raw.count-offset),last = offset+count == raw.count
            zlib.append(last ? 1 : 0)
            zlib += [UInt8(count & 0xff),UInt8(count >> 8),UInt8(~count & 0xff),UInt8((~count >> 8) & 0xff)]
            zlib += raw[offset..<offset+count]; offset += count
        } while offset < raw.count
        var a: UInt32 = 1,b: UInt32 = 0
        for byte in raw { a = (a+UInt32(byte)) % 65521; b = (b+a) % 65521 }
        zlib += big(b << 16 | a)
        let header = big(UInt32(frame.width))+big(UInt32(frame.height))+[8,2,0,0,0]
        return Data([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]+chunk("IHDR",header)+chunk("IDAT",zlib)+chunk("IEND",[]))
    }
}
