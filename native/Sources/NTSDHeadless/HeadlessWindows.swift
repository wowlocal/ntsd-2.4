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
    /// The backend keeps the presented crop (`WindowLease.presented`).
    func present(_ frame: OriginalFramebuffer,in window: AnyObject) throws {}
    var presentsConcurrently: Bool { true }
    func concurrentPresenter(_ window: AnyObject,width: Int,height: Int) -> (@Sendable (OriginalFramebuffer) -> Void)? { { _ in } }
}
