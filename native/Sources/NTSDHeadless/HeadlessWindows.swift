import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import NTSDCore
import NTSDRuntime

/// An offscreen original window: its client geometry and the last presented crop.
final class HeadlessWindow {
    let popup: Bool, title: String, client: CGSize
    /// Client top-left in desktop coordinates (top-left origin).
    let origin: CGPoint
    var visible = false, closed = false
    var frame: OriginalFramebuffer?
    init(popup: Bool,title: String,client: CGSize,origin: CGPoint) {
        self.popup = popup; self.title = title; self.client = client; self.origin = origin
    }
}
final class HeadlessCursor {}

/// Windows without a display. Geometry follows the macOS host's declared policy:
/// a titled window has no side or bottom frame and a `caption`-point title bar,
/// the full-screen popup covers the screen, and windows are centred.
@MainActor final class HeadlessWindowHost: OriginalRuntimeWindowHost {
    let screen: CGSize, caption: CGFloat
    private(set) var windows: [HeadlessWindow] = []
    init(screen: CGSize,caption: CGFloat) { self.screen = screen; self.caption = caption }
    private static func window(_ object: AnyObject) -> HeadlessWindow { object as! HeadlessWindow }
    func screenSize() throws -> CGSize { screen }
    func frameMetric(_ index: UInt32) throws -> CGFloat { index == 4 ? caption : 0 }
    func arrowCursor() -> AnyObject { HeadlessCursor() }
    func createWindow(popup: Bool,width: CGFloat,height: CGFloat,title: String,cursor: AnyObject) throws -> AnyObject {
        let client = popup ? screen : CGSize(width:width,height:height-caption)
        guard client.width > 0,client.height > 0 else { throw OriginalRuntimeWindowBackend.Boundary.geometry }
        let origin = popup ? CGPoint.zero : CGPoint(x:((screen.width-width)/2).rounded(.down),y:((screen.height-height)/2).rounded(.down)+caption)
        let window = HeadlessWindow(popup:popup,title:title,client:client,origin:origin)
        windows.append(window)
        return window
    }
    func windowCreated(_ lease: OriginalRuntimeWindowBackend.WindowLease,popup: Bool,backend: OriginalRuntimeWindowBackend) {}
    func orderFront(_ window: AnyObject) { Self.window(window).visible = true }
    func update(_ window: AnyObject) {}
    func show(_ window: AnyObject) -> Bool {
        let w = Self.window(window),wasVisible = w.visible
        w.visible = true; return wasVisible
    }
    func close(_ window: AnyObject) { let w = Self.window(window); w.closed = true; w.visible = false }
    nonisolated func released(_ window: AnyObject,closed: Bool,platformState: AnyObject?) {}
    func clientBounds(_ window: AnyObject) throws -> CGRect { CGRect(origin:.zero,size:Self.window(window).client) }
    func clientFrame(_ window: AnyObject) throws -> CGRect { CGRect(origin:.zero,size:Self.window(window).client) }
    func displayGeometry(_ window: AnyObject) throws -> OriginalRuntimeDisplayGeometry {
        let w = Self.window(window)
        // Host logical points with a bottom-left origin, as the AppKit host reports.
        return .init(screen:CGRect(origin:.zero,size:screen),
                     clientOnScreen:CGRect(x:w.origin.x,y:screen.height-w.origin.y-w.client.height,width:w.client.width,height:w.client.height))
    }
    func desktopPoint(_ window: AnyObject,client point: CGPoint) throws -> CGPoint {
        let w = Self.window(window); return CGPoint(x:w.origin.x+point.x,y:w.origin.y+point.y)
    }
    func present(_ frame: OriginalFramebuffer,in window: AnyObject) throws { Self.window(window).frame = frame }
    func frame(_ token: UInt32,in backend: OriginalRuntimeWindowBackend) throws -> OriginalFramebuffer {
        guard let frame = Self.window(try backend.lease(token).window).frame else { throw OriginalRuntimeWindowBackend.Boundary.geometry }
        return frame
    }
}

/// A PNG (8-bit RGB, stored deflate blocks) of an XRGB framebuffer.
enum HeadlessPNG {
    private static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1 }
        return c
    }
    private static func crc(_ bytes: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xffffffff
        for b in bytes { c = crcTable[Int((c ^ UInt32(b)) & 0xff)] ^ (c >> 8) }
        return c ^ 0xffffffff
    }
    private static func big(_ value: UInt32) -> [UInt8] { [24,16,8,0].map { UInt8(truncatingIfNeeded:value >> UInt32($0)) } }
    private static func chunk(_ type: String,_ data: [UInt8]) -> [UInt8] {
        let body = Array(type.utf8)+data
        return big(UInt32(data.count))+body+big(crc(body))
    }
    static func encode(_ frame: OriginalFramebuffer) -> Data {
        var raw: [UInt8] = []; raw.reserveCapacity((frame.width*3+1)*frame.height)
        frame.pixels.withUnsafeBytes { p in
            for y in 0..<frame.height {
                raw.append(0)
                for x in 0..<frame.width {
                    let o = (y*frame.width+x)*4
                    raw.append(p[o+2]); raw.append(p[o+1]); raw.append(p[o])
                }
            }
        }
        var zlib: [UInt8] = [0x78,0x01]
        var offset = 0
        repeat {
            let count = min(65535,raw.count-offset),last = offset+count == raw.count
            zlib.append(last ? 1 : 0)
            zlib += [UInt8(count & 0xff),UInt8(count >> 8),UInt8(~count & 0xff),UInt8((~count >> 8) & 0xff)]
            zlib += raw[offset..<offset+count]; offset += count
        } while offset < raw.count
        var a: UInt32 = 1,b: UInt32 = 0
        for byte in raw { a = (a+UInt32(byte)) % 65521; b = (b+a) % 65521 }
        zlib += big(b << 16 | a)
        let header = big(UInt32(frame.width))+big(UInt32(frame.height))+[8,2,0,0,0]
        return Data([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]+chunk("IHDR",header)+chunk("IDAT",zlib)+chunk("IEND",[]))
    }
}
