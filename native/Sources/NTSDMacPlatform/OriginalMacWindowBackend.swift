import AppKit
import NTSDCore

/// Physical window boundary only. This is not a DirectDraw/raster backend or a
/// Windows callback implementation. All methods are called outside Core attempts.
@MainActor public final class OriginalMacWindowBackend {
    public typealias Window = OriginalWindowInitialization
    public enum Boundary: Error, Equatable {
        case unsupported(String), arguments(String), unknownOwner(UInt32)
        case geometry, exhaustedTokens, foreignPreparation, repeatedPreparation
    }
    public struct Observation: Equatable {
        public let token: UInt32, title: String, frame: CGRect, client: CGRect
        public let backingScale: CGFloat, visible: Bool, closed: Bool, windowNumber: Int
    }
    public struct Operation: Equatable {
        public let request: Window.Request, response: Window.Response
    }
    public struct Served {
        public let response: Window.Response
        public let resources: [any OriginalApplicationStartupResource]
    }
    fileprivate final class Identity {}
    fileprivate final class Once { var used = false }
    public struct Prepared {
        fileprivate let request: Window.Request
        fileprivate let owner: Identity, once: Once
    }
    fileprivate final class CursorLease: OriginalApplicationStartupResource {
        let token: UInt32, cursor: NSCursor
        init(_ token: UInt32,_ cursor: NSCursor) { self.token = token; self.cursor = cursor }
    }
    fileprivate final class ClassLease: OriginalApplicationStartupResource {
        let token: UInt32, cursor: CursorLease, source: Window.Request
        init(_ token: UInt32,_ cursor: CursorLease,_ source: Window.Request) {
            self.token = token; self.cursor = cursor; self.source = source
        }
    }
    /// Receipts retain this lease; the registry is weak. Closing is a physical
    /// action, never an effect of Native transaction rollback. Final release may
    /// occur off-main, so the NSWindow's last teardown is queued on main.
    public final class WindowLease: OriginalApplicationStartupResource {
        public let token: UInt32
        fileprivate let window: NSWindow, windowClass: ClassLease
        fileprivate var closed = false, closeDelegate: CloseDelegate?
        /// The full-screen popup of an Alt+Enter recreation shows the game's
        /// image scaled to fit (declared, APPLICATION_FULL_SCREEN_PLAN.md).
        public fileprivate(set) var fullScreen = false
        fileprivate var contentSize: CGSize?
        /// Standard macOS full screen (APPLICATION_MAC_FULL_SCREEN_PLAN.md,
        /// declared): the windowed geometry the game keeps seeing while the
        /// view only scales. nil outside macOS full screen.
        public fileprivate(set) var held: DisplayGeometry?
        fileprivate var observers: [NSObjectProtocol] = []
        /// Either full screen shows the image scaled to fit.
        fileprivate var scaled: Bool { fullScreen || held != nil }
        fileprivate init(_ token: UInt32,_ window: NSWindow,_ windowClass: ClassLease) {
            self.token = token; self.window = window; self.windowClass = windowClass
        }
        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
            guard !closed else { return }
            let retainedWindow = window
            DispatchQueue.main.async { retainedWindow.close() }
        }
    }
    /// The close button asks; the game decides (WM_SYSCOMMAND/SC_CLOSE).
    fileprivate final class CloseDelegate: NSObject, NSWindowDelegate {
        let shouldClose: () -> Bool
        init(_ shouldClose: @escaping () -> Bool) { self.shouldClose = shouldClose }
        func windowShouldClose(_ sender: NSWindow) -> Bool { shouldClose() }
    }
    private final class WeakWindow {
        weak var value: WindowLease?
        init(_ value: WindowLease) { self.value = value }
    }
    private final class ContentView: NSView {
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
    /// Native window decorations are an explicit host policy. The recovered
    /// 10cb0000 style is preserved in requests; Windows zoom/menu/DPI equivalence
    /// is still open. One game client unit maps to one AppKit point here.
    public static let style: NSWindow.StyleMask = [.titled,.closable,.miniaturizable]
    private let identity = Identity(), instance: UInt32
    public let identities: OriginalMacResourceIdentityPool
    private var cursor: CursorLease?, windowClass: ClassLease?
    private var windows: [UInt32:WeakWindow] = [:]
    public private(set) var operations: [Operation] = []
    public private(set) var createdWindowCount = 0
    public init(instance: UInt32,identities: OriginalMacResourceIdentityPool? = nil) {
        self.instance = instance; self.identities = identities ?? OriginalMacResourceIdentityPool()
    }

    public nonisolated static func handles(_ request: Window.Request) -> Bool {
        ["metric","icon","cursor","registerClass","createWindow","updateWindow","showWindow","destroyWindow","clientRect","screenPoint"].contains(request.kind)
    }
    private func token() throws -> UInt32 {
        try identities.take()
    }
    public func lease(_ token: UInt32) throws -> WindowLease {
        guard let value = windows[token]?.value else { throw Boundary.unknownOwner(token) }; return value
    }
    public func observation(_ token: UInt32) throws -> Observation {
        let owner = try lease(token),w = owner.window
        return .init(token:token,title:w.title,frame:w.frame,client:w.contentView?.bounds ?? .zero,
            backingScale:w.backingScaleFactor,visible:w.isVisible,closed:owner.closed,windowNumber:w.windowNumber)
    }
    public typealias DisplayGeometry = OriginalRuntimeDisplayGeometry
    public func displayGeometry(_ token: UInt32) throws -> DisplayGeometry {
        let owner = try lease(token)
        if let held = owner.held,!owner.closed { return held }
        guard !owner.closed,let screen = owner.window.screen,let view = owner.window.contentView else { throw Boundary.geometry }
        return .init(screen:screen.frame,clientOnScreen:owner.window.convertToScreen(view.convert(view.bounds,to:nil)))
    }
    /// Presents a finished framebuffer crop: the same CGImage path as `display`.
    public func present(_ frame: OriginalFramebuffer,in token: UInt32) throws {
        try display(frame.cgImage(),in:token)
    }
    /// Consumes an owned immutable image crop; this is host delivery, not a Core
    /// observer. No implicit presentation is performed by window creation.
    public func display(_ image: CGImage,in token: UInt32) throws {
        let owner = try lease(token)
        guard !owner.closed,let view = owner.window.contentView as? ContentView,
              owner.fullScreen || CGSize(width:image.width,height:image.height) == (owner.held?.clientOnScreen.size ?? view.bounds.size) else {
            throw Boundary.geometry
        }
        owner.contentSize = CGSize(width:image.width,height:image.height)
        view.image = image; view.needsDisplay = true; owner.window.displayIfNeeded()
    }
    /// Called with a window created after the first one (Alt+Enter), so its
    /// owner can move input and close handling to it.
    public var created: ((UInt32) -> Void)?
    /// Actual AppKit view rendering for device checks, distinct from framebuffer
    /// bytes and from a screenshot of the physical display.
    public func captureView(_ token: UInt32) throws -> OriginalMacViewCapture {
        let owner = try lease(token)
        guard !owner.closed,let view = owner.window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) else { throw Boundary.geometry }
        view.cacheDisplay(in:view.bounds,to:bitmap); return try OriginalMacViewCapture(bitmap)
    }
    /// Routes AppKit key/mouse events of the original window to a live consumer
    /// (returns true when consumed) and makes the view first responder.
    public func setInput(_ token: UInt32,_ consumer: @escaping (NSEvent) -> Bool) throws {
        let owner = try lease(token)
        guard !owner.closed,let view = owner.window.contentView as? ContentView else { throw Boundary.geometry }
        view.input = consumer; owner.window.acceptsMouseMovedEvents = true; owner.window.makeFirstResponder(view)
    }
    /// The close button calls `handler`; true lets AppKit close the window.
    public func setCloseRequest(_ token: UInt32,_ handler: @escaping () -> Bool) throws {
        let owner = try lease(token)
        guard !owner.closed else { throw Boundary.geometry }
        let delegate = CloseDelegate(handler); owner.closeDelegate = delegate; owner.window.delegate = delegate
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
        owner.window.toggleFullScreen(nil)
    }
    /// DestroyWindow's visible effect: the window leaves the screen.
    public func hide(_ token: UInt32) throws { try lease(token).window.orderOut(nil) }
    /// Client-area point (top-left origin, logical points) of a window event.
    public func clientPoint(_ token: UInt32,_ event: NSEvent) throws -> (Int32,Int32) {
        let owner = try lease(token)
        guard let view = owner.window.contentView else { throw Boundary.geometry }
        var p = view.convert(event.locationInWindow,from:nil)
        if owner.scaled,let size = owner.contentSize {
            // Back through the aspect-kept scaling to the game's client points.
            let target = ContentView.fit(size,in:view.bounds)
            p = .init(x:(p.x-target.minX)*size.width/target.width,y:(p.y-target.minY)*size.height/target.height)
        }
        return (Int32(p.x.rounded(.down)),Int32(p.y.rounded(.down)))
    }
    /// PNG of the actual cached view rendering, for app-level inspection.
    public func snapshotPNG(_ token: UInt32) throws -> Data {
        let owner = try lease(token)
        // Full screen: the presented game frame itself, not the screen-sized
        // scaled view, so captures do not depend on the display.
        if owner.scaled,let image = (owner.window.contentView as? ContentView)?.image {
            guard let data = NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:]) else { throw Boundary.geometry }
            return data
        }
        return try viewPNG(token)
    }
    /// PNG of the view as AppKit renders it, scaled in either full screen.
    public func viewPNG(_ token: UInt32) throws -> Data {
        let owner = try lease(token)
        guard !owner.closed,let view = owner.window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) else { throw Boundary.geometry }
        view.cacheDisplay(in:view.bounds,to:bitmap)
        guard let data = bitmap.representation(using:.png,properties:[:]) else { throw Boundary.geometry }
        return data
    }
    /// Shared LoadCursor(0, IDC_ARROW) identity once the class cursor exists.
    public var arrowCursorToken: UInt32? { cursor?.token }
    public var retainedResources: [any OriginalApplicationStartupResource] {
        var result: [any OriginalApplicationStartupResource] = windows.values.compactMap { $0.value }
        if let cursor { result.append(cursor) }; if let windowClass { result.append(windowClass) }; return result
    }
    private func classWords(_ q: Window.Request) throws -> [UInt32] {
        guard let b = q.bytes,let mask = q.defined,b.count == 40,mask.count == 40 else { throw Boundary.arguments(q.kind) }
        let r = try OriginalStateRecord(bytes:b,defined:mask)
        return try stride(from:0,to:40,by:4).map { try r.integer(at:$0,as:UInt32.self) }
    }
    /// Pure payload/owner validation: no AppKit calls and no physical service claim.
    public func prepare(_ q: Window.Request) throws -> Prepared {
        try validate(q); return .init(request:q,owner:identity,once:Once())
    }
    private func validate(_ q: Window.Request) throws {
        guard Self.handles(q) else { throw Boundary.unsupported(q.kind) }
        func require(_ valid: Bool) throws { if !valid { throw Boundary.arguments(q.kind) } }
        if !["registerClass","clientRect","screenPoint"].contains(q.kind) { try require(q.bytes == nil && q.defined == nil) }
        if q.kind != "createWindow" { try require(q.strings.isEmpty) }
        switch q.kind {
        case "clientRect","screenPoint": try validateGeometry(q)
        case "metric": try require(q.words.count == 1 && [0,1,7,8,4].contains(q.words[0]))
        case "icon": try require(q.words == [instance,0x7f00])
        case "cursor": try require(q.words == [0,0x7f00])
        case "registerClass":
            try require(q.words.isEmpty)
            if windowClass != nil {
                // 43bdd0's registration again (Alt+Enter): the full-screen helper
                // leaves hCursor (offset 24) as undefined stack backing.
                guard let b = q.bytes,let mask = q.defined,b.count == 40,mask.count == 40 else { throw Boundary.arguments(q.kind) }
                let words = stride(from:0,to:40,by:4).map { o in (0..<4).reduce(UInt32(0)) { $0 | UInt32(b[o+$1]) << ($1*8) } }
                try require((0..<40).allSatisfy { mask[$0] || (24..<28).contains($0) })
                try require(words[0..<6] == [3,0x43b3d0,0,0,instance,0] && words[7...] == [0,0x447634,0x447634])
                try require(!mask[24] || words[6] == cursor?.token)
                break
            }
            let words = try classWords(q)
            guard let cursor else { throw Boundary.unknownOwner(words[6]) }
            try require(words == [3,0x43b3d0,0,0,instance,0,cursor.token,0,0x447634,0x447634])
        case "createWindow":
            try require(q.words.count == 12 && q.strings.count == 2)
            let w = q.words
            // 401b00 (windowed, WS_OVERLAPPEDWINDOW-like 10cb0000) or 401bf0 (full
            // screen: WS_EX_TOPMOST, WS_POPUP at 0,0 with the screen metrics).
            let popup = w[0] == 8 && w[3] == 0x80000000 && w[4] == 0 && w[5] == 0
            if popup { try require(w[6] == UInt32(try metric(0)) && w[7] == UInt32(try metric(1))) }
            try require(w[1] == 0x447634 && w[2] == 0x447620 && w[8] == 0 && w[9] == 0 && w[10] == instance && w[11] == 0)
            try require(popup || (w[0] == 0 && w[3] == 0x10cb0000 && w[4] == 0x80000000 && w[5] == 5))
            try require(q.strings[0] == Array("Marti".utf8) && q.strings[1] == Array("Little Fighter 2".utf8))
            guard w[6] > 0,w[7] > 0,w[6] <= UInt32(Int32.max),w[7] <= UInt32(Int32.max) else { throw Boundary.geometry }
            guard windowClass != nil else { throw Boundary.arguments("unregistered class") }
        case "updateWindow","destroyWindow":
            try require(q.words.count == 1); if q.words[0] != 0 { _ = try lease(q.words[0]) }
        case "showWindow":
            try require(q.words.count == 2 && q.words[1] == 5); if q.words[0] != 0 { _ = try lease(q.words[0]) }
        default: throw Boundary.unsupported(q.kind)
        }
    }
    /// SM_CXSCREEN/SM_CYSCREEN: the main display in logical points (declared).
    private func screenSize() throws -> CGSize {
        guard let screen = NSScreen.screens.first else { throw Boundary.geometry }
        return screen.frame.size
    }
    private func metric(_ index: UInt32) throws -> Int32 {
        if index == 0 || index == 1 {
            let size = try screenSize(),value = index == 0 ? size.width : size.height
            guard value.isFinite,value > 0,value <= CGFloat(Int32.max),value.rounded(.towardZero) == value else { throw Boundary.geometry }
            return Int32(value)
        }
        let client = NSRect(x:100,y:100,width:256,height:256)
        let frame = NSWindow.frameRect(forContentRect:client,styleMask:Self.style)
        let x = client.minX-frame.minX,y = client.minY-frame.minY
        guard x == frame.maxX-client.maxX else { throw Boundary.geometry }
        let value = index == 7 ? x : index == 8 ? y : frame.maxY-client.maxY-y
        guard value.isFinite,value >= 0,value <= CGFloat(Int32.max),value.rounded(.towardZero) == value else { throw Boundary.geometry }
        return Int32(value)
    }
    public func perform(_ prepared: Prepared) throws -> Served {
        guard prepared.owner === identity else { throw Boundary.foreignPreparation }
        guard !prepared.once.used else { throw Boundary.repeatedPreparation }
        try validate(prepared.request)
        prepared.once.used = true
        let q = prepared.request
        var resources: [any OriginalApplicationStartupResource] = []
        let result: Window.Response
        switch q.kind {
        case "clientRect","screenPoint":
            let owner = try lease(q.words[0]);resources = [owner];result = try performGeometry(q)
        case "metric": result = .init(result:try metric(q.words[0]))
        case "icon":
            // Pinned original EXE has group121, not the requested group32512.
            // Do not substitute its unrelated icon or a generic macOS image.
            result = .init(result:0)
        case "cursor":
            if cursor == nil { cursor = try CursorLease(token(),NSCursor.arrow) }
            let value = cursor!; resources = [value]; result = .init(result:Int32(bitPattern:value.token))
        case "registerClass":
            if windowClass != nil { result = .init(result:0); resources = [windowClass!] }
            else {
                let value = try ClassLease(token(),cursor!,q); windowClass = value
                resources = [value]; result = .init(result:Int32(bitPattern:value.token))
            }
        case "createWindow":
            let popup = q.words[3] == 0x80000000
            let id = try token(),cls = windowClass!
            let window: NSWindow
            if popup {
                // Declared full screen: a borderless window over the main display,
                // above the menu bar, hidden while another app is active.
                guard let screen = NSScreen.screens.first else { throw Boundary.geometry }
                window = NSWindow(contentRect:screen.frame,styleMask:[.borderless],backing:.buffered,defer:false,screen:screen)
                window.level = NSWindow.Level(rawValue:NSWindow.Level.mainMenu.rawValue+1)
                window.hidesOnDeactivate = true; window.backgroundColor = .black
                window.contentView = ContentView(frame:NSRect(origin:.zero,size:screen.frame.size),cursor:cls.cursor.cursor)
            } else {
                let frame = NSRect(x:0,y:0,width:CGFloat(q.words[6]),height:CGFloat(q.words[7]))
                let content = NSWindow.contentRect(forFrameRect:frame,styleMask:Self.style)
                guard content.width > 0,content.height > 0 else { throw Boundary.geometry }
                window = NSWindow(contentRect:content,styleMask:Self.style,backing:.buffered,defer:false)
                window.contentView = ContentView(frame:NSRect(origin:.zero,size:content.size),cursor:cls.cursor.cursor)
                window.center(); window.collectionBehavior.insert(.fullScreenPrimary)
            }
            window.colorSpace = .sRGB // Match the explicitly sRGB native image/backing policy.
            window.isReleasedWhenClosed = false; window.title = String(decoding:q.strings[1],as:UTF8.self)
            let owner = WindowLease(id,window,cls); owner.fullScreen = popup
            if !popup {
                for (name,entering) in [(NSWindow.willEnterFullScreenNotification,true),(NSWindow.didExitFullScreenNotification,false)] {
                    owner.observers.append(NotificationCenter.default.addObserver(forName:name,object:window,queue:.main) { [weak self] _ in
                        MainActor.assumeIsolated { try? self?.holdForMacFullScreen(id,entering) }
                    })
                }
            }
            windows[id] = WeakWindow(owner); resources = [owner]; createdWindowCount += 1
            window.orderFront(nil) // Source requests WS_VISIBLE.
            if createdWindowCount > 1 { created?(id) }
            result = .init(result:Int32(bitPattern:id))
        case "updateWindow","showWindow","destroyWindow":
            if q.words[0] == 0 { result = .init(result:0) }
            else {
                let owner = try lease(q.words[0]); resources = [owner]
                if owner.closed { result = .init(result:0) }
                else if q.kind == "updateWindow" { owner.window.displayIfNeeded(); result = .init(result:1) }
                else if q.kind == "showWindow" {
                    let wasVisible = owner.window.isVisible
                    owner.window.makeKeyAndOrderFront(nil); result = .init(result:wasVisible ? 1 : 0)
                } else { owner.window.close(); owner.closed = true; result = .init(result:1) }
            }
        default: throw Boundary.unsupported(q.kind)
        }
        operations.append(.init(request:q,response:result))
        return .init(response:result,resources:resources)
    }
}

extension OriginalMacWindowBackend {
    /// Same integral logical-point policy as the native primary/clipper backing.
    /// Reject unsupported host coordinates without inventing rounded game bytes.
    static func geometryInteger(_ value: CGFloat) throws -> Int32 {
        guard value.isFinite,value >= CGFloat(Int32.min),value <= CGFloat(Int32.max),
              value.rounded(.towardZero) == value else { throw Boundary.geometry }
        return Int32(value)
    }
    private func validateGeometry(_ q: Window.Request) throws {
        guard q.words.count == 2,q.words[1] != 0,let bytes = q.bytes,let mask = q.defined,
              bytes.count == (q.kind == "clientRect" ? 16 : 8),mask.count == bytes.count else {
            throw Boundary.arguments(q.kind)
        }
        let owner = try lease(q.words[0]);guard !owner.closed else { throw Boundary.geometry }
        if q.kind == "screenPoint" {
            let point = try OriginalStateRecord(bytes:bytes,defined:mask)
            _ = try point.integer(at:0,as:Int32.self);_ = try point.integer(at:4,as:Int32.self)
        }
    }
    /// Called only after the external service permit began. Each request samples
    /// the current owned view/window; preparation never freezes geometry.
    private func performGeometry(_ q: Window.Request) throws -> Window.Response {
        let owner = try lease(q.words[0])
        guard !owner.closed,let view = owner.window.contentView as? ContentView,
              view.bounds.origin == .zero,view.bounds.size == view.frame.size else { throw Boundary.geometry }
        let values: [Int32]
        if let held = owner.held {
            // macOS full screen: the client the game had in its window.
            let client = held.clientInDesktop
            if q.kind == "clientRect" {
                values = [0,0,try Self.geometryInteger(client.width),try Self.geometryInteger(client.height)]
            } else {
                guard let bytes = q.bytes,let mask = q.defined else { throw Boundary.geometry }
                let input = try OriginalStateRecord(bytes:bytes,defined:mask)
                values = [try Self.geometryInteger(client.minX+CGFloat(try input.integer(at:0,as:Int32.self))),
                          try Self.geometryInteger(client.minY+CGFloat(try input.integer(at:4,as:Int32.self)))]
            }
        } else if q.kind == "clientRect" {
            guard view.bounds.width >= 0,view.bounds.height >= 0 else { throw Boundary.geometry }
            values = [0,0,try Self.geometryInteger(view.bounds.width),try Self.geometryInteger(view.bounds.height)]
        } else {
            guard let screen = owner.window.screen,let bytes = q.bytes,let mask = q.defined else { throw Boundary.geometry }
            let input = try OriginalStateRecord(bytes:bytes,defined:mask)
            let local = NSPoint(x:CGFloat(try input.integer(at:0,as:Int32.self)),y:CGFloat(try input.integer(at:4,as:Int32.self)))
            let physical = owner.window.convertPoint(toScreen:view.convert(local,to:nil))
            values = [try Self.geometryInteger(physical.x-screen.frame.minX),try Self.geometryInteger(screen.frame.maxY-physical.y)]
        }
        let output = values.flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded:UInt32(bitPattern:word) >> ($0*8)) } }
        return .init(result:1,bytes:output)
    }
}
