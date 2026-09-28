import AppKit

/// Owned sRGB readback of actual cached view pixels. Not a framebuffer oracle.
public struct OriginalMacViewCapture {
    public enum Boundary: Error { case image, size, allocation }
    public let pixelsWide: Int, pixelsHigh: Int
    private let rgba: [UInt8]

    public init(_ bitmap: NSBitmapImageRep, maximumBytes: Int = 256 * 1024 * 1024) throws {
        guard let image = bitmap.cgImage, image.colorSpace != nil else { throw Boundary.image }
        let w = image.width, h = image.height
        let (row, rowOverflow) = w.multipliedReportingOverflow(by:4)
        let (count, countOverflow) = row.multipliedReportingOverflow(by:h)
        guard w > 0, h > 0, !rowOverflow, !countOverflow, count <= maximumBytes else { throw Boundary.size }
        guard let space = CGColorSpace(name:CGColorSpace.sRGB),
            let context = CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:row,
                space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            let data = context.data else { throw Boundary.allocation }
        context.interpolationQuality = .none
        context.setBlendMode(.copy)
        context.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
        pixelsWide = w; pixelsHigh = h
        rgba = Array(UnsafeBufferPointer(start:data.assumingMemoryBound(to:UInt8.self),count:count))
    }

    public func colorAt(x: Int,y: Int) -> NSColor? {
        guard x >= 0, y >= 0, x < pixelsWide, y < pixelsHigh else { return nil }
        let i = (y * pixelsWide + x) * 4, a = CGFloat(rgba[i+3])
        guard a > 0 else { return NSColor(srgbRed:0,green:0,blue:0,alpha:0) }
        return NSColor(srgbRed:CGFloat(rgba[i])/a,green:CGFloat(rgba[i+1])/a,
            blue:CGFloat(rgba[i+2])/a,alpha:a/255)
    }
}
