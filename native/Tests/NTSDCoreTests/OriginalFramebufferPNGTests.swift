import XCTest
import CZlib
@testable import NTSDRuntime

final class OriginalFramebufferPNGTests: XCTestCase {
    private func chunks(_ png: [UInt8]) -> [(type: String,data: [UInt8])] {
        var out: [(String,[UInt8])] = [],i = 8
        func word(_ at: Int) -> Int { png[at..<at+4].reduce(0) { $0 << 8 | Int($1) } }
        while i+12 <= png.count {
            let n = word(i),body = Array(png[i+4..<i+8+n])
            let crc = body.withUnsafeBufferPointer { UInt32(crc32(0,$0.baseAddress,uInt($0.count))) }
            XCTAssertEqual(UInt32(word(i+8+n)),crc)
            out.append((String(decoding:body[0..<4],as:UTF8.self),Array(body[4...]))); i += 12+n
        }
        XCTAssertEqual(i,png.count)
        return out
    }
    private func inflate(_ data: [UInt8],_ capacity: Int) -> [UInt8]? {
        var raw = [UInt8](repeating:0,count:capacity),length = uLongf(capacity)
        guard uncompress(&raw,&length,data,uLong(data.count)) == Z_OK else { return nil }
        return Array(raw[0..<Int(length)])
    }

    func testEncodesXRGBAsRGBRowsWithValidChunks() {
        // XRGB little-endian pixels are stored B, G, R, X.
        let pixels = Data([0x01,0x02,0x03,0xff, 0x10,0x20,0x30,0x00, 0xaa,0xbb,0xcc,0x7f, 0x00,0x00,0x00,0x00])
        let png = [UInt8](OriginalFramebufferPNG.encode(OriginalFramebuffer(width:2,height:2,pixels:pixels)))
        XCTAssertEqual(Array(png[0..<8]),[0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a])
        let c = chunks(png)
        XCTAssertEqual(c.map(\.type),["IHDR","IDAT","IEND"])
        XCTAssertEqual(c[0].data,[0,0,0,2, 0,0,0,2, 8,2,0,0,0])
        XCTAssertEqual(inflate(c[1].data,64),[0, 3,2,1, 0x30,0x20,0x10, 0, 0xcc,0xbb,0xaa, 0,0,0])
    }

    func testLargeFramesSpanSeveralStoredBlocks() {
        let width = 200,height = 200
        let pixels = Data((0..<width*height*4).map { UInt8(truncatingIfNeeded:$0 &* 7) })
        let png = [UInt8](OriginalFramebufferPNG.encode(OriginalFramebuffer(width:width,height:height,pixels:pixels)))
        let c = chunks(png)
        guard let raw = inflate(c[1].data,(width*3+1)*height+1) else { return XCTFail("IDAT does not inflate") }
        XCTAssertEqual(raw.count,(width*3+1)*height)
        XCTAssertGreaterThan((width*3+1)*height,65535)
        let row = 117,x = 42,o = (row*width+x)*4,r = row*(width*3+1)+1+x*3
        XCTAssertEqual(raw[row*(width*3+1)],0)
        XCTAssertEqual(Array(raw[r..<r+3]),[pixels[o+2],pixels[o+1],pixels[o]])
    }
}
