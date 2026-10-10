/// Lossless source RGB and knowledge owned by a logical surface. This is before
/// device format conversion, palette realization, color key and presentation.
/// An unknown pixel has deterministic zero backing, not an established color.
public struct OriginalSurfaceSourceColors: Equatable {
    public enum Boundary: String, Error {
        case extent, pixelLimit, rectangle, undefinedPixel
    }
    public let width: Int, height: Int
    /// The colours: materialized, or after a whole-surface copy of a bitmap that
    /// bitmap, decoded when read. A whole copy is how every loaded image reaches
    /// its surface, and keeping each decoded (three colour bytes and a knowledge
    /// byte per pixel) held about 1 GB (MEMORY_FOOTPRINT step 1). The values read
    /// are the same: decoding is a pure function of the bitmap's bytes.
    private var content: Content
    private enum Content { case pixels([UInt8],[Bool]), bitmap(Decoded) }
    /// A copied bitmap and, once something reads its colours, their decoded
    /// arrays (so repeated reads decode once; the game itself never reads them).
    private final class Decoded {
        let bitmap: OriginalApplicationStartupInputs.Bitmap
        private var cached: (rgb: [UInt8],defined: [Bool])?
        init(_ bitmap: OriginalApplicationStartupInputs.Bitmap) { self.bitmap = bitmap }
        var colors: (rgb: [UInt8],defined: [Bool]) {
            if let cached { return cached }
            let p = bitmap.pixels,value = (p.rgb,p.defined); cached = value; return value
        }
    }
    private var materialized: (rgb: [UInt8],defined: [Bool]) {
        switch content {
        case let .pixels(rgb,defined):return (rgb,defined)
        case let .bitmap(d):return d.colors
        }
    }
    /// The arrays to start a write from, decoded without filling the shared
    /// cache (snapshots taken before the write keep only the bitmap).
    private var writable: (rgb: [UInt8],defined: [Bool]) {
        switch content {
        case let .pixels(rgb,defined):return (rgb,defined)
        case let .bitmap(d):let p = d.bitmap.pixels;return (p.rgb,p.defined)
        }
    }
    public var rgb: [UInt8] { materialized.rgb }
    public var defined: [Bool] { materialized.defined }
    public static func == (a: Self,b: Self) -> Bool {
        guard a.width == b.width,a.height == b.height else { return false }
        if case let .bitmap(x) = a.content,case let .bitmap(y) = b.content,x === y || x.bitmap == y.bitmap { return true }
        let l = a.materialized,r = b.materialized
        return l.rgb == r.rgb && l.defined == r.defined
    }

    public init(width: Int,height: Int,maximumPixels: Int = 16_777_216) throws {
        guard width > 0,height > 0 else { throw Boundary.extent }
        let (count,overflow) = width.multipliedReportingOverflow(by:height)
        let (bytes,byteOverflow) = count.multipliedReportingOverflow(by:3)
        guard !overflow,!byteOverflow,maximumPixels > 0,count <= maximumPixels else { throw Boundary.pixelLimit }
        self.width = width;self.height = height
        content = .pixels([UInt8](repeating:0,count:bytes),[Bool](repeating:false,count:count))
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
            content = .pixels(source.rgb,source.defined);return
        }
        var (rgb,defined) = writable; content = .pixels([],[])
        for row in 0..<height {
            let input = (sourceY+row)*source.width+sourceX,output = (y+row)*self.width+x
            rgb.replaceSubrange(output*3..<(output+width)*3,with:source.rgb[input*3..<(input+width)*3])
            defined.replaceSubrange(output..<output+width,with:source.defined[input..<input+width])
        }
        content = .pixels(rgb,defined)
    }

    /// The same copy from a loaded bitmap. A whole-surface copy keeps the bitmap
    /// itself (its value retained after image deletion, like the arrays were);
    /// any other copy decodes it and copies the region.
    public mutating func copy(_ source: OriginalApplicationStartupInputs.Bitmap,sourceX: Int = 0,sourceY: Int = 0,
                              width: Int,height: Int,x: Int = 0,y: Int = 0) throws {
        let sourceWidth = Int(source.width),sourceHeight = Int(source.height)
        if sourceX == 0,sourceY == 0,x == 0,y == 0,width == self.width,height == self.height,
           width == sourceWidth,height == sourceHeight {
            try Self.rectangle(x:0,y:0,width:width,height:height,inWidth:sourceWidth,inHeight:sourceHeight)
            try Self.rectangle(x:0,y:0,width:width,height:height,inWidth:self.width,inHeight:self.height)
            content = .bitmap(Decoded(source));return
        }
        try copy(source.pixels,sourceX:sourceX,sourceY:sourceY,width:width,height:height,x:x,y:y)
    }

    /// Conservative Native policy for failed copies: the affected region loses
    /// knowledge. This does not assert the original device's failure pixels.
    public mutating func invalidate(x: Int,y: Int,width: Int,height: Int) throws {
        try Self.rectangle(x:x,y:y,width:width,height:height,inWidth:self.width,inHeight:self.height)
        var (rgb,defined) = writable; content = .pixels([],[])
        for row in 0..<height {
            let start = (y+row)*self.width+x
            for pixel in start..<start+width {
                defined[pixel] = false
                for channel in 0..<3 { rgb[pixel*3+channel] = 0 }
            }
        }
        content = .pixels(rgb,defined)
    }

    public func color(x: Int,y: Int) throws -> [UInt8] {
        try Self.rectangle(x:x,y:y,width:1,height:1,inWidth:width,inHeight:height)
        let pixel = y*width+x,(rgb,defined) = materialized
        guard defined[pixel] else { throw Boundary.undefinedPixel }
        return Array(rgb[pixel*3..<pixel*3+3])
    }
}
