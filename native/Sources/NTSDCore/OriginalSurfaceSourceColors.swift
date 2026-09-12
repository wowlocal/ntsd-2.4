/// Lossless source RGB and knowledge owned by a logical surface. This is before
/// device format conversion, palette realization, color key and presentation.
/// An unknown pixel has deterministic zero backing, not an established color.
public struct OriginalSurfaceSourceColors: Equatable {
    public enum Boundary: String, Error {
        case extent, pixelLimit, rectangle, undefinedPixel
    }
    public let width: Int, height: Int
    public private(set) var rgb: [UInt8]
    public private(set) var defined: [Bool]

    public init(width: Int,height: Int,maximumPixels: Int = 16_777_216) throws {
        guard width > 0,height > 0 else { throw Boundary.extent }
        let (count,overflow) = width.multipliedReportingOverflow(by:height)
        let (bytes,byteOverflow) = count.multipliedReportingOverflow(by:3)
        guard !overflow,!byteOverflow,maximumPixels > 0,count <= maximumPixels else { throw Boundary.pixelLimit }
        self.width = width;self.height = height
        rgb = [UInt8](repeating:0,count:bytes);defined = [Bool](repeating:false,count:count)
    }

    private static func rectangle(x: Int,y: Int,width: Int,height: Int,inWidth: Int,inHeight: Int) throws {
        guard x >= 0,y >= 0,width > 0,height > 0,x <= inWidth,y <= inHeight,
              width <= inWidth-x,height <= inHeight-y else { throw Boundary.rectangle }
    }

    /// Bounded one-to-one SRCCOPY of the source representation. False source
    /// flags replace destination knowledge too; they are not transparency.
    public mutating func copy(_ source: OriginalDIBPixels,sourceX: Int = 0,sourceY: Int = 0,
                              width: Int,height: Int,x: Int = 0,y: Int = 0) throws {
        try Self.rectangle(x:sourceX,y:sourceY,width:width,height:height,inWidth:source.width,inHeight:source.height)
        try Self.rectangle(x:x,y:y,width:width,height:height,inWidth:self.width,inHeight:self.height)
        if sourceX == 0,sourceY == 0,x == 0,y == 0,width == self.width,height == self.height,
           width == source.width,height == source.height {
            // Swift value ownership retains the complete arrays after image
            // deletion; later partial writes use normal copy-on-write storage.
            rgb = source.rgb;defined = source.defined;return
        }
        for row in 0..<height {
            let input = (sourceY+row)*source.width+sourceX,output = (y+row)*self.width+x
            rgb.replaceSubrange(output*3..<(output+width)*3,with:source.rgb[input*3..<(input+width)*3])
            defined.replaceSubrange(output..<output+width,with:source.defined[input..<input+width])
        }
    }

    /// Conservative Native policy for failed copies: the affected region loses
    /// knowledge. This does not assert the original device's failure pixels.
    public mutating func invalidate(x: Int,y: Int,width: Int,height: Int) throws {
        try Self.rectangle(x:x,y:y,width:width,height:height,inWidth:self.width,inHeight:self.height)
        for row in 0..<height {
            let start = (y+row)*self.width+x
            for pixel in start..<start+width {
                defined[pixel] = false
                for channel in 0..<3 { rgb[pixel*3+channel] = 0 }
            }
        }
    }

    public func color(x: Int,y: Int) throws -> [UInt8] {
        try Self.rectangle(x:x,y:y,width:1,height:1,inWidth:width,inHeight:height)
        let pixel = y*width+x
        guard defined[pixel] else { throw Boundary.undefinedPixel }
        return Array(rgb[pixel*3..<pixel*3+3])
    }
}
