import RandoriRuntime

/// TextOutA's glyph masks in the browser, drawn by the page's fonts (user
/// 2026-10-13): GDI's SYSTEM_FONT ships with Windows, not the game, so as on
/// macOS (the system font) the page's standard sans-serif bold stands in, a
/// declared temporary deviation — 13 px em, monochrome (half coverage and
/// up), baseline at the 16-pixel cell's row 13. Without the page's font
/// service the text is blank, as on the headless host.
enum WebGlyphs {
    typealias TextMask = OriginalMacDisplayBackend.TextMask
    static let blank = TextMask(advance:0,originX:0,originY:0,width:0,height:0,bits:[])
    static func mask(_ bytes: [UInt8]) -> TextMask {
        let margin = 4,height = OriginalMacDisplayBackend.textCell+2*margin
        var out = [UInt8](repeating:0,count:(bytes.count*16+2*margin)*height)
        // A first guess of 16 pixels a byte; once more at the size the page asks for.
        for _ in 0..<2 {
            let advance = Int(bytes.withUnsafeBytes { text in out.withUnsafeMutableBytes { mask in
                withUnsafeBytes(of:UInt8(0)) { empty in
                    ntsdText(text.baseAddress ?? empty.baseAddress!,Int32(text.count),mask.baseAddress!,Int32(mask.count))
                }
            } })
            guard advance >= 0 else { return blank }
            let width = advance+2*margin
            if width*height <= out.count {
                return TextMask(advance:advance,originX:margin,originY:margin,width:width,height:height,bits:Array(out[0..<width*height]))
            }
            out = [UInt8](repeating:0,count:width*height)
        }
        return blank
    }
}
