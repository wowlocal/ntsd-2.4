import Foundation
import NTSDCore
import NTSDRuntime

/// An original window in the page: its client geometry; the page shows the
/// last crop presented to any visible window on its canvas.
final class WebWindow {
    let popup: Bool, title: String, client: CGSize
    /// Client top-left in desktop coordinates (top-left origin).
    let origin: CGPoint
    var visible = false, closed = false
    init(popup: Bool,title: String,client: CGSize,origin: CGPoint) {
        self.popup = popup; self.title = title; self.client = client; self.origin = origin
    }
}
final class WebCursor {}

/// Windows on the page's canvas. Geometry follows the headless host's
/// declared policy (the macOS host's): a titled window has no side or bottom
/// frame and a `caption`-point title bar, the full-screen popup covers the
/// screen, and windows are centred on a screen of the size the page gives.
@MainActor final class WebWindowHost: OriginalRuntimeWindowHost {
    let screen: CGSize, caption: CGFloat
    /// The client origin of the window whose crop the page shows (the last
    /// one presented, as the iOS and Android hosts track it): mouse positions
    /// are its client points. Written by the presenter, which on WASI runs on
    /// the only thread.
    nonisolated(unsafe) static var presentedOrigin: CGPoint?
    init(screen: CGSize,caption: CGFloat) { self.screen = screen; self.caption = caption }
    private static func window(_ object: AnyObject) -> WebWindow { object as! WebWindow }
    func screenSize() throws -> CGSize { screen }
    func frameMetric(_ index: UInt32) throws -> CGFloat { index == 4 ? caption : 0 }
    func arrowCursor() -> AnyObject { WebCursor() }
    func createWindow(popup: Bool,width: CGFloat,height: CGFloat,title: String,cursor: AnyObject) throws -> AnyObject {
        let client = popup ? screen : CGSize(width:width,height:height-caption)
        guard client.width > 0,client.height > 0 else { throw OriginalRuntimeWindowBackend.Boundary.geometry }
        let origin = popup ? CGPoint.zero : CGPoint(x:((screen.width-width)/2).rounded(.down),y:((screen.height-height)/2).rounded(.down)+caption)
        return WebWindow(popup:popup,title:title,client:client,origin:origin)
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
    /// The crop goes to the page, which draws it on its canvas (the backend
    /// also keeps it as the window's presented frame).
    func present(_ frame: OriginalFramebuffer,in window: AnyObject) throws {
        let w = Self.window(window); Self.show(frame,origin:w.origin,popup:w.popup)
    }
    /// The headless host's presentation path (presents pipelined, which on
    /// WASI run inline), so `--web` and `--browser` differ only in the page:
    /// the page copies the crop before the call returns, so a reused frame is
    /// safe.
    var presentsConcurrently: Bool { true }
    func concurrentPresenter(_ window: AnyObject,width: Int,height: Int) -> (@Sendable (OriginalFramebuffer) -> Void)? {
        let w = Self.window(window),origin = w.origin,popup = w.popup
        return { Self.show($0,origin:origin,popup:popup) }
    }
    nonisolated static func show(_ frame: OriginalFramebuffer,origin: CGPoint,popup: Bool) {
        presentedOrigin = origin
        frame.pixels.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            ntsdPresent(base,Int32(frame.width),Int32(frame.height),popup ? 1 : 0)
        }
    }
}
