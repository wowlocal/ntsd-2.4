import Foundation
import NTSDRuntime
#if canImport(CFreeType)
import CFreeType
#endif

/// TextOutA's glyph masks on hosts without CoreText (user decision
/// 2026-10-01): the original draws GDI's SYSTEM_FONT, which ships with
/// Windows, not with the game; like macOS with its system font, these hosts
/// use the platform's standard sans-serif bold as a declared temporary
/// deviation: 13 px em, monochrome, baseline at the 16-pixel cell's row 13.
enum SDLGlyphs {
    typealias TextMask = OriginalMacDisplayBackend.TextMask
    static let blank: ([UInt8]) -> TextMask = { _ in .init(advance:0,originX:0,originY:0,width:0,height:0,bits:[]) }
    /// Standard Linux fonts in order of how closely their 13 px bold widths
    /// match the macOS stand-in (measured 2026-10-04 on UI strings: DejaVu Sans
    /// Condensed within ±3 px, Liberation and Noto within a few per cent, plain
    /// DejaVu Sans about 15 % wider, which clips the original's layout).
    static let preferred: [(family: String,files: [String])] = [
        ("DejaVu Sans Condensed",["dejavu/DejaVuSansCondensed-Bold.ttf","DejaVuSansCondensed-Bold.ttf"]),
        ("Liberation Sans",["liberation/LiberationSans-Bold.ttf","LiberationSans-Bold.ttf"]),
        ("Noto Sans",["noto/NotoSans-Bold.ttf","NotoSans-Bold.ttf"]),
        ("FreeSans",["freefont/FreeSansBold.ttf","FreeSansBold.ttf"])]
    private static func run(_ tool: String,_ arguments: [String]) -> String? {
        guard FileManager.default.isExecutableFile(atPath:tool) else { return nil }
        let process = Process(),pipe = Pipe()
        process.executableURL = URL(fileURLWithPath:tool); process.arguments = arguments
        process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let output = String(decoding:pipe.fileHandleForReading.readDataToEndOfFile(),as:UTF8.self)
        process.waitUntilExit()
        return process.terminationStatus == 0 ? output : nil
    }
    /// `NTSD_FONT`; else the first installed preferred font (fontconfig, then
    /// common paths); else fontconfig's standard sans-serif bold.
    static func fontPath() -> String? {
        if let path = ProcessInfo.processInfo.environment["NTSD_FONT"] { return path }
        let tools = ["/usr/bin","/usr/local/bin"]
        func exists(_ path: String) -> Bool { FileManager.default.fileExists(atPath:path) }
        for font in preferred {
            for dir in tools {
                if let files = run(dir+"/fc-list",["-f","%{file}\n","\(font.family):style=Bold"]),
                   let file = files.split(separator:"\n").map(String.init).sorted().first(where:exists) { return file }
            }
            for root in ["/usr/share/fonts/truetype/","/usr/share/fonts/TTF/","/usr/share/fonts/"] {
                if let file = font.files.map({ root+$0 }).first(where:exists) { return file }
            }
        }
        for dir in tools {
            if let file = run(dir+"/fc-match",["-f","%{file}","sans-serif:bold"]),exists(file) { return file }
        }
        return nil
    }
    #if canImport(CFreeType)
    /// FreeType face kept for the process (TextOutA runs on the main actor).
    final class Face {
        private var library: FT_Library?, face: FT_Face?
        let path: String
        init?(path: String) {
            self.path = path
            guard FT_Init_FreeType(&library) == 0 else { return nil }
            guard FT_New_Face(library,path,0,&face) == 0,FT_Set_Pixel_Sizes(face,0,13) == 0 else { FT_Done_FreeType(library); return nil }
        }
        func mask(_ bytes: [UInt8]) -> TextMask {
            guard let face else { return blank(bytes) }
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
    #endif
    /// The host's glyph masks and the font they come from (nil: none, blank text).
    static func make() -> (mask: ([UInt8]) -> TextMask,font: String?) {
        #if canImport(CFreeType)
        if let path = fontPath(),let face = Face(path:path) { return ({ face.mask($0) },path) }
        #endif
        return (blank,nil)
    }
}
