import Foundation
import NTSDRuntime
#if canImport(NTSDFreeTypeText)
import NTSDFreeTypeText
#endif
#if os(Windows)
import WinSDK
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
    #if os(Windows)
    /// Windows draws the original's own SYSTEM_FONT through GDI (user decision
    /// 2026-10-01: the original's font first): TextOutA of the game's bytes
    /// into a monochrome top-down DIB, the 16-pixel cell at the margin. Under
    /// Wine (the test harness) SYSTEM_FONT is Wine's substitute.
    final class GDIText {
        private let dc: HDC
        init?() {
            guard let dc = CreateCompatibleDC(nil) else { return nil }
            self.dc = dc
            SelectObject(dc,GetStockObject(SYSTEM_FONT))
        }
        deinit { DeleteDC(dc) }
        func mask(_ bytes: [UInt8]) -> TextMask {
            let margin = 4,cell = OriginalMacDisplayBackend.textCell
            var extent = SIZE()
            _ = bytes.withUnsafeBufferPointer { $0.withMemoryRebound(to:CHAR.self) { GetTextExtentPoint32A(dc,$0.baseAddress,Int32(bytes.count),&extent) } }
            let advance = max(0,Int(extent.cx)),width = advance+2*margin,height = cell+2*margin
            var info = BITMAPINFO()
            info.bmiHeader.biSize = DWORD(MemoryLayout<BITMAPINFOHEADER>.size)
            info.bmiHeader.biWidth = LONG(width); info.bmiHeader.biHeight = -LONG(height)   // top-down
            info.bmiHeader.biPlanes = 1; info.bmiHeader.biBitCount = 32; info.bmiHeader.biCompression = DWORD(BI_RGB)
            var bits: UnsafeMutableRawPointer?
            guard let bitmap = CreateDIBSection(dc,&info,UINT(DIB_RGB_COLORS),&bits,nil,0),let bits else { return blank(bytes) }
            defer { DeleteObject(bitmap) }
            let previous = SelectObject(dc,bitmap)
            defer { SelectObject(dc,previous) }
            memset(bits,0,width*height*4)
            SetBkMode(dc,TRANSPARENT); SetTextColor(dc,0x00ffffff)
            _ = bytes.withUnsafeBufferPointer { $0.withMemoryRebound(to:CHAR.self) { TextOutA(dc,Int32(margin),Int32(margin),$0.baseAddress,Int32(bytes.count)) } }
            GdiFlush()
            let pixels = bits.assumingMemoryBound(to:UInt32.self)
            let out = (0..<width*height).map { pixels[$0] & 0x00ffffff != 0 ? UInt8(1) : 0 }
            return .init(advance:advance,originX:margin,originY:margin,width:width,height:height,bits:out)
        }
    }
    #endif
    /// The host's glyph masks and the font they come from (nil: none, blank text).
    static func make() -> (mask: ([UInt8]) -> TextMask,font: String?) {
        #if os(Windows)
        if let gdi = GDIText() { return ({ gdi.mask($0) },"GDI SYSTEM_FONT") }
        #endif
        #if canImport(NTSDFreeTypeText)
        if let path = fontPath(),let face = OriginalFreeTypeFace(path:path) { return ({ face.mask($0) },path) }
        #endif
        return (blank,nil)
    }
}
