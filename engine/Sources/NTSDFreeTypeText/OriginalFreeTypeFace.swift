import CFreeType
import NTSDRuntime

/// TextOutA's glyph masks from a FreeType face, for hosts without CoreText
/// or GDI (Linux, Android): 13 px em, monochrome, baseline at the 16-pixel
/// cell's ascent row. The face is kept for the process (TextOutA runs on the
/// main actor). `weight` sets a variable font's `wght` axis (Android's system
/// sans-serif, Roboto, is one variable font).
public final class OriginalFreeTypeFace {
    public typealias TextMask = OriginalMacDisplayBackend.TextMask
    static let blank = TextMask(advance:0,originX:0,originY:0,width:0,height:0,bits:[])
    private var library: FT_Library?, face: FT_Face?
    public let path: String
    public init?(path: String,weight: Double? = nil) {
        self.path = path
        guard FT_Init_FreeType(&library) == 0 else { return nil }
        guard FT_New_Face(library,path,0,&face) == 0 else { FT_Done_FreeType(library); return nil }
        if let weight {
            var axes: UnsafeMutablePointer<FT_MM_Var>?
            guard FT_Get_MM_Var(face,&axes) == 0,let axes else { FT_Done_Face(face); FT_Done_FreeType(library); return nil }
            defer { FT_Done_MM_Var(library,axes) }
            var coordinates = (0..<Int(axes.pointee.num_axis)).map { axes.pointee.axis[$0].def }
            for i in coordinates.indices where axes.pointee.axis[i].tag == 0x7767_6874 { coordinates[i] = FT_Fixed(weight*65536) }   // 'wght'
            guard FT_Set_Var_Design_Coordinates(face,FT_UInt(coordinates.count),&coordinates) == 0 else {
                FT_Done_Face(face); FT_Done_FreeType(library); return nil
            }
        }
        guard FT_Set_Pixel_Sizes(face,0,13) == 0 else { FT_Done_Face(face); FT_Done_FreeType(library); return nil }
    }
    public func mask(_ bytes: [UInt8]) -> TextMask {
        guard let face else { return Self.blank }
        let cell = OriginalMacDisplayBackend.textCell,ascent = OriginalMacDisplayBackend.textAscent,margin = 4
        struct Glyph { let x: Int, top: Int, left: Int, rows: Int, width: Int, pitch: Int, bits: [UInt8] }
        var glyphs: [Glyph] = [],pen = 0,previous: FT_UInt = 0
        for scalar in String(decoding:bytes,as:UTF8.self).unicodeScalars {
            let index = FT_Get_Char_Index(face,FT_ULong(scalar.value))
            if previous != 0,index != 0,ntsd_ft_has_kerning(face) != 0 {
                var kerning = FT_Vector()
                if FT_Get_Kerning(face,previous,index,FT_UInt(FT_KERNING_DEFAULT.rawValue),&kerning) == 0 { pen += Int(kerning.x) }
            }
            guard FT_Load_Glyph(face,index,NTSD_FT_LOAD_MONO) == 0,let slot = face.pointee.glyph else { continue }
            let bitmap = slot.pointee.bitmap,rows = Int(bitmap.rows),width = Int(bitmap.width),pitch = Int(bitmap.pitch)
            let bits = rows > 0 && pitch > 0 && bitmap.buffer != nil ? Array(UnsafeBufferPointer(start:bitmap.buffer,count:rows*pitch)) : []
            glyphs.append(Glyph(x:pen,top:Int(slot.pointee.bitmap_top),left:Int(slot.pointee.bitmap_left),rows:rows,width:width,pitch:pitch,bits:bits))
            pen += Int(slot.pointee.advance.x); previous = index
        }
        // Pen positions are 26.6 fixed point; the extent rounds like CoreText's width.
        let advance = max(0,(pen+32) >> 6),width = advance+2*margin,height = cell+2*margin
        var out = [UInt8](repeating:0,count:width*height)
        for g in glyphs where !g.bits.isEmpty {
            let originX = margin+((g.x+32) >> 6)+g.left,originY = margin+ascent-g.top
            for row in 0..<g.rows { for column in 0..<g.width where g.bits[row*g.pitch+column/8] & (0x80 >> UInt8(column%8)) != 0 {
                let x = originX+column,y = originY+row
                if x >= 0,x < width,y >= 0,y < height { out[y*width+x] = 1 }
            } }
        }
        return .init(advance:advance,originX:margin,originY:margin,width:width,height:height,bits:out)
    }
}
