import AppKit
import NTSDCore

/// The Mac window backend: the runtime's window family over AppKit windows.
public typealias OriginalMacWindowBackend = OriginalRuntimeWindowBackend

/// Physical AppKit windows for `OriginalRuntimeWindowBackend`. This is not a
/// DirectDraw/raster backend or a Windows callback implementation.
@MainActor public final class OriginalMacWindowHost: OriginalRuntimeWindowHost {
    typealias Boundary = OriginalRuntimeWindowBackend.Boundary
    /// Per-window AppKit state kept in the lease: full-screen observers and the
    /// close-button delegate.
    fileprivate final class State {
        var observers: [NSObjectProtocol] = []
        var closeDelegate: CloseDelegate?
    }
    /// The close button asks; the game decides (WM_SYSCOMMAND/SC_CLOSE).
    fileprivate final class CloseDelegate: NSObject, NSWindowDelegate {
        let shouldClose: () -> Bool
        init(_ shouldClose: @escaping () -> Bool) { self.shouldClose = shouldClose }
        func windowShouldClose(_ sender: NSWindow) -> Bool { shouldClose() }
    }
    fileprivate final class ContentView: NSView {
        let cursor: NSCursor
        var image: CGImage?
        /// Live-app input consumer; without one AppKit's default handling applies.
        var input: ((NSEvent) -> Bool)?
        override var acceptsFirstResponder: Bool { input != nil }
        override func keyDown(with event: NSEvent) { if input?(event) != true { super.keyDown(with:event) } }
        override func keyUp(with event: NSEvent) { if input?(event) != true { super.keyUp(with:event) } }
        override func flagsChanged(with event: NSEvent) { if input?(event) != true { super.flagsChanged(with:event) } }
        override func mouseDown(with event: NSEvent) { if input?(event) != true { super.mouseDown(with:event) } }
        override func mouseUp(with event: NSEvent) { if input?(event) != true { super.mouseUp(with:event) } }
        override func rightMouseDown(with event: NSEvent) { if input?(event) != true { super.rightMouseDown(with:event) } }
        override func rightMouseUp(with event: NSEvent) { if input?(event) != true { super.rightMouseUp(with:event) } }
        override func mouseMoved(with event: NSEvent) { if input?(event) != true { super.mouseMoved(with:event) } }
        override func mouseDragged(with event: NSEvent) { if input?(event) != true { super.mouseDragged(with:event) } }
        override func draw(_ dirtyRect: NSRect) {
            guard let image else { return }
            NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
            NSGraphicsContext.current?.imageInterpolation = .none
            let size = CGSize(width:image.width,height:image.height),target = Self.fit(size,in:bounds)
            if target != bounds { NSColor.black.setFill(); bounds.fill() }
            NSImage(cgImage:image,size:size).draw(in:target,from:.zero,operation:.copy,fraction:1,respectFlipped:true,hints:nil)
        }
        /// The image's aspect-kept placement, centred (the whole bounds when equal).
        static func fit(_ size: CGSize,in bounds: CGRect) -> CGRect {
            guard size.width > 0,size.height > 0,size != bounds.size else { return bounds }
            let scale = min(bounds.width/size.width,bounds.height/size.height)
            let w = size.width*scale,h = size.height*scale
            return .init(x:bounds.midX-w/2,y:bounds.midY-h/2,width:w,height:h)
        }
        init(frame: CGRect,cursor: NSCursor) { self.cursor = cursor; super.init(frame:frame) }
        required init?(coder: NSCoder) { fatalError("Programmatic original window only") }
        override var isFlipped: Bool { true }
        override func resetCursorRects() { addCursorRect(bounds,cursor:cursor) }
    }
    public init() {}
    fileprivate static func window(_ object: AnyObject) -> NSWindow { object as! NSWindow }
    fileprivate static func content(_ object: AnyObject) throws -> ContentView {
        guard let view = window(object).contentView as? ContentView else { throw Boundary.geometry }
        return view
    }
    /// SM_CXSCREEN/SM_CYSCREEN: the main display in logical points (declared).
    public func screenSize() throws -> CGSize {
        guard let screen = NSScreen.screens.first else { throw Boundary.geometry }
        return screen.frame.size
    }
    public func frameMetric(_ index: UInt32) throws -> CGFloat {
        let client = NSRect(x:100,y:100,width:256,height:256)
        let frame = NSWindow.frameRect(forContentRect:client,styleMask:OriginalMacWindowBackend.style)
        let x = client.minX-frame.minX,y = client.minY-frame.minY
        guard x == frame.maxX-client.maxX else { throw Boundary.geometry }
        return index == 7 ? x : index == 8 ? y : frame.maxY-client.maxY-y
    }
    public func arrowCursor() -> AnyObject { NSCursor.arrow }
    public func createWindow(popup: Bool,width: CGFloat,height: CGFloat,title: String,cursor: AnyObject) throws -> AnyObject {
        let cursor = cursor as! NSCursor
        let window: NSWindow
        if popup {
            // Declared full screen: a borderless window over the main display,
            // above the menu bar, hidden while another app is active.
            guard let screen = NSScreen.screens.first else { throw Boundary.geometry }
            window = NSWindow(contentRect:screen.frame,styleMask:[.borderless],backing:.buffered,defer:false,screen:screen)
            window.level = NSWindow.Level(rawValue:NSWindow.Level.mainMenu.rawValue+1)
            window.hidesOnDeactivate = true; window.backgroundColor = .black
            window.contentView = ContentView(frame:NSRect(origin:.zero,size:screen.frame.size),cursor:cursor)
        } else {
            let frame = NSRect(x:0,y:0,width:width,height:height)
            let content = NSWindow.contentRect(forFrameRect:frame,styleMask:OriginalMacWindowBackend.style)
            guard content.width > 0,content.height > 0 else { throw Boundary.geometry }
            window = NSWindow(contentRect:content,styleMask:OriginalMacWindowBackend.style,backing:.buffered,defer:false)
            window.contentView = ContentView(frame:NSRect(origin:.zero,size:content.size),cursor:cursor)
            window.center(); window.collectionBehavior.insert(.fullScreenPrimary)
        }
        window.colorSpace = .sRGB // Match the explicitly sRGB native image/backing policy.
        window.isReleasedWhenClosed = false; window.title = title
        return window
    }
    public func windowCreated(_ lease: OriginalRuntimeWindowBackend.WindowLease,popup: Bool,backend: OriginalRuntimeWindowBackend) {
        let state = State(); lease.platformState = state
        guard !popup else { return }
        let id = lease.token,window = Self.window(lease.window)
        for (name,entering) in [(NSWindow.willEnterFullScreenNotification,true),(NSWindow.didExitFullScreenNotification,false)] {
            state.observers.append(NotificationCenter.default.addObserver(forName:name,object:window,queue:.main) { [weak backend] _ in
                MainActor.assumeIsolated { try? backend?.holdForMacFullScreen(id,entering) }
            })
        }
    }
    public func orderFront(_ window: AnyObject) { Self.window(window).orderFront(nil) }
    public func update(_ window: AnyObject) { Self.window(window).displayIfNeeded() }
    public func show(_ window: AnyObject) -> Bool {
        let w = Self.window(window),wasVisible = w.isVisible
        w.makeKeyAndOrderFront(nil); return wasVisible
    }
    public func close(_ window: AnyObject) { Self.window(window).close() }
    /// Final release may occur off-main, so the NSWindow's last teardown is queued on main.
    public nonisolated func released(_ window: AnyObject,closed: Bool,platformState: AnyObject?) {
        (platformState as? State)?.observers.forEach(NotificationCenter.default.removeObserver)
        guard !closed else { return }
        let retainedWindow = window as! NSWindow
        DispatchQueue.main.async { retainedWindow.close() }
    }
    public func clientBounds(_ window: AnyObject) throws -> CGRect { try Self.content(window).bounds }
    public func clientFrame(_ window: AnyObject) throws -> CGRect { try Self.content(window).frame }
    public func displayGeometry(_ window: AnyObject) throws -> OriginalRuntimeDisplayGeometry {
        let w = Self.window(window)
        guard let screen = w.screen,let view = w.contentView else { throw Boundary.geometry }
        return .init(screen:screen.frame,clientOnScreen:w.convertToScreen(view.convert(view.bounds,to:nil)))
    }
    public func desktopPoint(_ window: AnyObject,client point: CGPoint) throws -> CGPoint {
        let w = Self.window(window),view = try Self.content(window)
        guard let screen = w.screen else { throw Boundary.geometry }
        let physical = w.convertPoint(toScreen:view.convert(point,to:nil))
        return .init(x:physical.x-screen.frame.minX,y:screen.frame.maxY-physical.y)
    }
    public func present(_ frame: OriginalFramebuffer,in window: AnyObject) throws {
        let view = try Self.content(window)
        view.image = try frame.cgImage(); view.needsDisplay = true; Self.window(window).displayIfNeeded()
    }
}

/// AppKit-only window services for the live app and its checks.
extension OriginalRuntimeWindowBackend {
    /// Native window decorations are an explicit host policy. The recovered
    /// 10cb0000 style is preserved in requests; Windows zoom/menu/DPI equivalence
    /// is still open. One game client unit maps to one AppKit point here.
    public static let style: NSWindow.StyleMask = [.titled,.closable,.miniaturizable]
    public struct Observation: Equatable {
        public let token: UInt32, title: String, frame: CGRect, client: CGRect
        public let backingScale: CGFloat, visible: Bool, closed: Bool, windowNumber: Int
    }
    public convenience init(instance: UInt32,identities: OriginalMacResourceIdentityPool? = nil) {
        self.init(instance:instance,identities:identities,host:OriginalMacWindowHost())
    }
    private func nsWindow(_ owner: WindowLease) -> NSWindow { OriginalMacWindowHost.window(owner.window) }
    public func observation(_ token: UInt32) throws -> Observation {
        let owner = try lease(token),w = nsWindow(owner)
        return .init(token:token,title:w.title,frame:w.frame,client:w.contentView?.bounds ?? .zero,
            backingScale:w.backingScaleFactor,visible:w.isVisible,closed:owner.closed,windowNumber:w.windowNumber)
    }
    /// Consumes an owned immutable image crop; this is host delivery, not a Core
    /// observer. No implicit presentation is performed by window creation.
    public func display(_ image: CGImage,in token: UInt32) throws {
        let owner = try lease(token),w = nsWindow(owner)
        guard !owner.closed,let view = w.contentView as? OriginalMacWindowHost.ContentView,
              owner.fullScreen || CGSize(width:image.width,height:image.height) == (owner.held?.clientOnScreen.size ?? view.bounds.size) else {
            throw Boundary.geometry
        }
        owner.contentSize = CGSize(width:image.width,height:image.height)
        view.image = image; view.needsDisplay = true; w.displayIfNeeded()
    }
    /// Actual AppKit view rendering for device checks, distinct from framebuffer
    /// bytes and from a screenshot of the physical display.
    public func captureView(_ token: UInt32) throws -> OriginalMacViewCapture {
        let owner = try lease(token),w = nsWindow(owner)
        guard !owner.closed,let view = w.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) else { throw Boundary.geometry }
        view.cacheDisplay(in:view.bounds,to:bitmap); return try OriginalMacViewCapture(bitmap)
    }
    /// Routes AppKit key/mouse events of the original window to a live consumer
    /// (returns true when consumed) and makes the view first responder.
    public func setInput(_ token: UInt32,_ consumer: @escaping (NSEvent) -> Bool) throws {
        let owner = try lease(token),w = nsWindow(owner)
        guard !owner.closed,let view = w.contentView as? OriginalMacWindowHost.ContentView else { throw Boundary.geometry }
        view.input = consumer; w.acceptsMouseMovedEvents = true; w.makeFirstResponder(view)
    }
    /// The close button calls `handler`; true lets AppKit close the window.
    public func setCloseRequest(_ token: UInt32,_ handler: @escaping () -> Bool) throws {
        let owner = try lease(token)
        guard !owner.closed else { throw Boundary.geometry }
        let delegate = OriginalMacWindowHost.CloseDelegate(handler)
        (owner.platformState as? OriginalMacWindowHost.State)?.closeDelegate = delegate; nsWindow(owner).delegate = delegate
    }
    /// Enters or leaves the held geometry of macOS full screen. The window's
    /// will-enter/did-exit notifications call this; it sends the game nothing.
    public func holdForMacFullScreen(_ token: UInt32,_ entering: Bool) throws {
        let owner = try lease(token)
        guard !owner.closed,!owner.fullScreen else { throw Boundary.geometry }
        if entering {
            guard owner.held == nil else { return }
            owner.held = try displayGeometry(token)
        } else { owner.held = nil }
    }
    /// The standard macOS full-screen toggle of the game's window.
    public func toggleMacFullScreen(_ token: UInt32) throws {
        let owner = try lease(token)
        guard !owner.closed,!owner.fullScreen else { throw Boundary.geometry }
        nsWindow(owner).toggleFullScreen(nil)
    }
    /// DestroyWindow's visible effect: the window leaves the screen.
    public func hide(_ token: UInt32) throws { nsWindow(try lease(token)).orderOut(nil) }
    /// Client-area point (top-left origin, logical points) of a window event.
    public func clientPoint(_ token: UInt32,_ event: NSEvent) throws -> (Int32,Int32) {
        let owner = try lease(token)
        guard let view = nsWindow(owner).contentView else { throw Boundary.geometry }
        var p = view.convert(event.locationInWindow,from:nil)
        if owner.scaled,let size = owner.contentSize {
            // Back through the aspect-kept scaling to the game's client points.
            let target = OriginalMacWindowHost.ContentView.fit(size,in:view.bounds)
            p = .init(x:(p.x-target.minX)*size.width/target.width,y:(p.y-target.minY)*size.height/target.height)
        }
        return (Int32(p.x.rounded(.down)),Int32(p.y.rounded(.down)))
    }
    /// PNG of the actual cached view rendering, for app-level inspection.
    public func snapshotPNG(_ token: UInt32) throws -> Data {
        let owner = try lease(token)
        // Full screen: the presented game frame itself, not the screen-sized
        // scaled view, so captures do not depend on the display.
        if owner.scaled,let image = (nsWindow(owner).contentView as? OriginalMacWindowHost.ContentView)?.image {
            guard let data = NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:]) else { throw Boundary.geometry }
            return data
        }
        return try viewPNG(token)
    }
    /// PNG of the view as AppKit renders it, scaled in either full screen.
    public func viewPNG(_ token: UInt32) throws -> Data {
        let owner = try lease(token)
        guard !owner.closed,let view = nsWindow(owner).contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) else { throw Boundary.geometry }
        view.cacheDisplay(in:view.bounds,to:bitmap)
        guard let data = bitmap.representation(using:.png,properties:[:]) else { throw Boundary.geometry }
        return data
    }
}
