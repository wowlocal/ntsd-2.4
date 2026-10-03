import AppKit
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform

@MainActor final class OriginalMacDisplayColorTests: XCTestCase {
    func testWholeWindowKeepsSRGBPatternsAndOwnedCapture() throws {
        let old = OriginalMacWindowBackendTests(),run = try old.run(late:false)
        defer { try? old.close(run) }
        let backend = run.service.backend,window = run.controls.window
        let observation = try backend.observation(window)
        let w = Int(observation.client.width),h = Int(observation.client.height)
        let palette: [UInt32] = [0,1,0xff,0xff0000,0xff00,0x123456,0xffabcdef,0x336699,
            0x808080,0xffffff,0x010203,0xfedcba,0x7f00ff,0x32cd71,0x97412e,0x4da870]
        var retained: OriginalMacViewCapture?
        for colors in [palette,Array(palette.reversed())] {
            var words = [UInt32](repeating:0,count:w*h)
            for y in 0..<h { for x in 0..<w { words[y*w+x] = colors[(y*4/h)*4+x*4/w].littleEndian } }
            let data = words.withUnsafeBufferPointer { Data(buffer:$0) }
            let provider = try XCTUnwrap(CGDataProvider(data:data as CFData))
            let image = try XCTUnwrap(CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,
                bytesPerRow:w*4,space:try XCTUnwrap(CGColorSpace(name:CGColorSpace.sRGB)),
                bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.noneSkipFirst.rawValue).union(.byteOrder32Little),
                provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent))
            try backend.display(image,in:window)
            let capture = try backend.captureView(window)
            for i in 0..<16 {
                let x=(2*(i%4)+1)*capture.pixelsWide/8,y=(2*(i/4)+1)*capture.pixelsHigh/8
                let color = try XCTUnwrap(capture.colorAt(x:x,y:y)?.usingColorSpace(.sRGB))
                XCTAssertEqual(color.redComponent,CGFloat((colors[i]>>16)&255)/255,accuracy:2.0/255)
                XCTAssertEqual(color.greenComponent,CGFloat((colors[i]>>8)&255)/255,accuracy:2.0/255)
                XCTAssertEqual(color.blueComponent,CGFloat(colors[i]&255)/255,accuracy:2.0/255)
                XCTAssertEqual(color.alphaComponent,1)
            }
            XCTAssertNil(capture.colorAt(x:-1,y:0));XCTAssertNil(capture.colorAt(x:0,y:-1))
            XCTAssertNil(capture.colorAt(x:capture.pixelsWide,y:0));XCTAssertNil(capture.colorAt(x:0,y:capture.pixelsHigh))
            if let retained {
                let color = try XCTUnwrap(retained.colorAt(x:retained.pixelsWide/8,y:retained.pixelsHigh/8))
                XCTAssertEqual(color.redComponent,0);XCTAssertEqual(color.greenComponent,0);XCTAssertEqual(color.blueComponent,0)
            } else { retained = capture }
        }
        print("Physical sRGB window patterns",w,h,"32 tile samples; previous capture retained")
    }
}
