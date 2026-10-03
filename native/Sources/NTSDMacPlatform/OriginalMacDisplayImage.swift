import AppKit
import NTSDCore

/// The Mac display: AppKit windows, CoreText glyph masks and CGImage output
/// around the portable display backend in NTSDRuntime.
extension OriginalMacDisplayBackend {
    public convenience init(windows: OriginalMacWindowBackend,maximumBytes: Int = 256*1024*1024,freshSurfacesKnownBlack: Bool = false,
                            presentUnknownAsBlack: Bool = false,rleHolesReadPaletteZero: Bool = false,keepsOperationLogs: Bool = true) {
        self.init(windows:windows as any OriginalRuntimeWindowing,maximumBytes:maximumBytes,freshSurfacesKnownBlack:freshSurfacesKnownBlack,
                  presentUnknownAsBlack:presentUnknownAsBlack,rleHolesReadPaletteZero:rleHolesReadPaletteZero,
                  keepsOperationLogs:keepsOperationLogs,textMask:Self.textMask)
    }
    /// The AppKit window backend this display was created with.
    var macWindows: OriginalMacWindowBackend {
        guard let windows = windows as? OriginalMacWindowBackend else { preconditionFailure("Mac display without Mac windows") }
        return windows
    }
    public func image(_ token: UInt32) throws -> CGImage { try framebuffer(token).cgImage() }
    /// Declared temporary stand-in for SYSTEM_FONT (user decision 2026-10-01):
    /// the macOS system font, bold, 13 px em, baseline at the cell's +13.
    public static func textMask(_ bytes: [UInt8]) -> TextMask {
        let font = NSFont.systemFont(ofSize:CGFloat(textCell-3),weight:.bold)
        let attributes: [NSAttributedString.Key:Any] = [.font:font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:1,alpha:1)]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string:String(decoding:bytes,as:UTF8.self),attributes:attributes))
        let advance = max(0,Int(CTLineGetTypographicBounds(line,nil,nil,nil).rounded()))
        let margin = 4,width = advance+2*margin,height = textCell+2*margin
        var bits = [UInt8](repeating:0,count:width*height)
        bits.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data:raw.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width,
                                          space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue) else { return }
            context.setAllowsAntialiasing(false); context.setShouldAntialias(false)
            context.setAllowsFontSmoothing(false); context.setShouldSmoothFonts(false)
            // Memory row 0 is the image top; the cell spans rows margin..<margin+16.
            context.textPosition = CGPoint(x:margin,y:margin+textCell-textAscent)
            CTLineDraw(line,context)
        }
        return .init(advance:advance,originX:margin,originY:margin,width:width,height:height,bits:bits.map { $0 >= 128 ? 1 : 0 })
    }
}

extension OriginalFramebuffer {
    /// The sRGB `noneSkipFirst | byteOrder32Little` CGImage over these bytes.
    func cgImage() throws -> CGImage {
        guard let provider = CGDataProvider(data:pixels as CFData),let space = CGColorSpace(name:CGColorSpace.sRGB),
            let result = CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:space,
                bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.noneSkipFirst.rawValue).union(.byteOrder32Little),
                provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent) else { throw OriginalMacDisplayBackend.Boundary.image }
        return result
    }
}

extension OriginalMacWindowBackend: OriginalRuntimeWindowing {
    public func windowLease(_ token: UInt32) throws -> any OriginalRuntimeWindowLease { try lease(token) }
    public func windowClosed(_ token: UInt32) throws -> Bool { try observation(token).closed }
}
extension OriginalMacWindowBackend.WindowLease: OriginalRuntimeWindowLease {}
