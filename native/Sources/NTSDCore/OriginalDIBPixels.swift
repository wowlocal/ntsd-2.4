/// Immutable source colors, before any surface conversion, color key or alpha.
/// Unwritten RLE positions retain false masks; their zero backing is not black.
public struct OriginalDIBPixels: Equatable {
    public enum Boundary: String, Error {
        case header, format, pixelLimit, extent, palette, paletteIndex, stream, output, undefinedPixel
    }
    public let width: Int, height: Int
    public let pixelOffset: Int
    public let rgb: [UInt8]
    public let defined: [Bool]

    /// The pixel budget is a caller allocation boundary, not an original rule.
    public init(dib: [UInt8], maximumPixels: Int = 16_777_216, pixelOffset: Int? = nil) throws {
        guard dib.count >= 40 else { throw Boundary.header }
        func word(_ at: Int) -> UInt32 {
            UInt32(dib[at]) | UInt32(dib[at+1]) << 8 | UInt32(dib[at+2]) << 16 | UInt32(dib[at+3]) << 24
        }
        let width = Int(Int32(bitPattern:word(4))),height = Int(Int32(bitPattern:word(8)))
        guard word(0) == 40,width > 0,height > 0,dib[12] == 1,dib[13] == 0 else { throw Boundary.header }
        let bits = Int(dib[14]) | Int(dib[15]) << 8,compression = word(16)
        guard ([4,8,24].contains(bits) && compression == 0) || (bits == 8 && compression == 1) else { throw Boundary.format }
        let (count,overflow) = width.multipliedReportingOverflow(by:height)
        let (byteCount,byteOverflow) = count.multipliedReportingOverflow(by:3)
        guard !overflow,!byteOverflow,maximumPixels > 0,count <= maximumPixels else { throw Boundary.pixelLimit }
        let imageSize = Int(word(20)),colors = Int(word(32))
        let paletteCount = bits == 24 ? colors : (colors == 0 ? 1 << bits : colors)
        guard (bits == 24 || paletteCount <= 1 << bits),
              paletteCount <= (dib.count-40)/4 else { throw Boundary.palette }
        let minimumOffset = 40+paletteCount*4,start = pixelOffset ?? minimumOffset
        guard start >= minimumOffset,start <= dib.count else { throw Boundary.extent }
        var rgb = [UInt8](repeating:0,count:byteCount),defined = [Bool](repeating:false,count:count)
        if compression == 0 {
            // Width is positive Int32; these products fit Int on native macOS.
            let stride = ((width*bits+31)/32)*4
            let (extent,extentOverflow) = stride.multipliedReportingOverflow(by:height)
            guard !extentOverflow,extent <= dib.count-start,imageSize == 0 || imageSize == extent else { throw Boundary.extent }
            for row in 0..<height {
                let source = start+row*stride,destination = (height-1-row)*width
                for x in 0..<width {
                    let input: Int,output = (destination+x)*3
                    if bits == 24 { input = source+x*3 }
                    else {
                        let value = Int(dib[source+(bits == 8 ? x : x/2)])
                        let index = bits == 8 ? value : (x%2 == 0 ? value >> 4 : value & 15)
                        guard index < paletteCount else { throw Boundary.paletteIndex }
                        input = 40+index*4
                    }
                    rgb[output] = dib[input+2];rgb[output+1] = dib[input+1];rgb[output+2] = dib[input]
                    defined[destination+x] = true
                }
            }
        } else {
            guard imageSize > 0,imageSize <= dib.count-start else { throw Boundary.extent }
            let end = start+imageSize
            var position = start,x = 0,y = 0,finished = false
            func next() throws -> Int {
                guard position < end else { throw Boundary.stream }
                defer { position += 1 };return Int(dib[position])
            }
            func checkOutput(_ length: Int) throws {
                guard y < height,length <= width-x else { throw Boundary.output }
            }
            func write(_ index: Int) throws {
                guard index < paletteCount else { throw Boundary.paletteIndex }
                let source = 40+index*4,pixel = (height-1-y)*width+x
                rgb[pixel*3] = dib[source+2];rgb[pixel*3+1] = dib[source+1];rgb[pixel*3+2] = dib[source]
                defined[pixel] = true;x += 1
            }
            while !finished {
                let length = try next(),value = try next()
                guard y < height || (length == 0 && value == 1) else { throw Boundary.output }
                if length != 0 {
                    try checkOutput(length)
                    for _ in 0..<length { try write(value) }
                } else {
                    switch value {
                    case 0:x = 0;y += 1
                    case 1:finished = true
                    case 2:
                        let dx = try next(),dy = try next()
                        guard dx <= width-x,dy < height-y else { throw Boundary.output }
                        x += dx;y += dy
                    default:
                        guard value+value%2 <= end-position else { throw Boundary.stream }
                        try checkOutput(value)
                        for _ in 0..<value { try write(next()) }
                        if value%2 != 0 { _ = try next() }
                    }
                }
            }
            // EOB ends decoding. Declared stream padding/tails remain raw DIB data.
        }
        self.width = width;self.height = height;self.pixelOffset = start;self.rgb = rgb;self.defined = defined
    }

    public func color(x: Int,y: Int) throws -> [UInt8] {
        guard x >= 0,x < width,y >= 0,y < height else { throw Boundary.output }
        let pixel = y*width+x
        guard defined[pixel] else { throw Boundary.undefinedPixel }
        return Array(rgb[pixel*3..<pixel*3+3])
    }
}
