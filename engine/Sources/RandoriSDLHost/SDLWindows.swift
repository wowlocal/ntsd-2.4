import CSDL3
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import RandoriCore
import RandoriRuntime

/// An SDL window with its renderer and the streaming texture of the presented
/// framebuffer. `origin` is the client top-left on the desktop, as placed.
final class SDLWindow {
    let window: OpaquePointer, renderer: OpaquePointer, popup: Bool, client: CGSize
    /// The scalable window (WINDOW_SCALING S4): the game keeps the client and
    /// position it was created with while the picture scales with the window.
    var scalable = false
    /// Where the host placed the client (desktop, top-left origin).
    var placed = CGPoint.zero
    var texture: UnsafeMutablePointer<SDL_Texture>?, textureSize = CGSize.zero
    /// Where the last frame was drawn in window points (full screen scales it to fit).
    var drawn = CGRect.zero
    var visible = false, closed = false
    var id: SDL_WindowID { SDL_GetWindowID(window) }
    init(window: OpaquePointer,renderer: OpaquePointer,popup: Bool,client: CGSize) {
        self.window = window; self.renderer = renderer; self.popup = popup; self.client = client
    }
    func destroy() {
        if let texture { SDL_DestroyTexture(texture) }
        SDL_DestroyRenderer(renderer); SDL_DestroyWindow(window)
    }
}
final class SDLCursor { let cursor: OpaquePointer?; init(_ cursor: OpaquePointer?) { self.cursor = cursor } }

/// The original's windows on SDL. Geometry follows the host policy the game
/// is told about: `metrics` are SM_CXFIXEDFRAME, SM_CYFIXEDFRAME and
/// SM_CYCAPTION; a titled window is centred with its client inside that frame,
/// and the full-screen popup covers the main display.
@MainActor final class SDLWindowHost: OriginalRuntimeWindowHost {
    enum Failure: Error { case sdl(String) }
    let metrics: (frameX: CGFloat,frameY: CGFloat,caption: CGFloat)
    init(metrics: (CGFloat,CGFloat,CGFloat)) { self.metrics = (metrics.0,metrics.1,metrics.2) }
    /// The scalable window (WINDOW_SCALING S4): the game's titled window is
    /// resizable and maximisable with its aspect kept, at high pixel density,
    /// opens larger than 1× where the display allows and keeps its size for
    /// the next window; the game keeps its creation geometry. False keeps the
    /// original fixed window.
    var scalable = false
    /// The size of the game's last scalable window when the game destroyed it.
    var lastSize: CGSize?
    /// A scalable window's first size, as on macOS: the last one (no larger
    /// than the display allows), else the largest whole multiple of the client
    /// within 85% of the usable display when that is 2× or more, else the
    /// fraction that fits there (at least half).
    func initialSize(_ client: CGSize) -> CGSize {
        var r = SDL_Rect()
        guard SDL_GetDisplayUsableBounds(SDL_GetPrimaryDisplay(),&r),client.width > 0,client.height > 0 else { return lastSize ?? client }
        let room = CGSize(width:CGFloat(r.w)-2*metrics.frameX,height:CGFloat(r.h)-metrics.caption-2*metrics.frameY)
        let fit = min(room.width/client.width,room.height/client.height)*0.85
        var scale = fit >= 2 ? fit.rounded(.down) : max(0.5,fit)
        if let last = lastSize { scale = max(0.5,min(last.width/client.width,room.width/client.width,room.height/client.height)) }
        let width = (client.width*scale).rounded()
        return CGSize(width:width,height:(width*client.height/client.width).rounded())
    }
    static func window(_ object: AnyObject) -> SDLWindow { object as! SDLWindow }
    static func error() -> Failure { .sdl(String(cString:SDL_GetError())) }
    func screenSize() throws -> CGSize {
        var r = SDL_Rect()
        guard SDL_GetDisplayBounds(SDL_GetPrimaryDisplay(),&r) else { throw Self.error() }
        return CGSize(width:CGFloat(r.w),height:CGFloat(r.h))
    }
    func frameMetric(_ index: UInt32) throws -> CGFloat {
        switch index {
        case 7: return metrics.frameX
        case 8: return metrics.frameY
        case 4: return metrics.caption
        default: throw OriginalRuntimeWindowBackend.Boundary.arguments("metric \(index)")
        }
    }
    func arrowCursor() -> AnyObject { SDLCursor(SDL_GetDefaultCursor()) }
    func createWindow(popup: Bool,width: CGFloat,height: CGFloat,title: String,cursor: AnyObject) throws -> AnyObject {
        let screen = try screenSize()
        let client = popup ? screen : CGSize(width:width-2*metrics.frameX,height:height-metrics.caption-2*metrics.frameY)
        guard client.width > 0,client.height > 0 else { throw OriginalRuntimeWindowBackend.Boundary.geometry }
        let scalable = self.scalable && !popup
        let flags = NTSD_SDL_WINDOW_HIDDEN | (popup ? NTSD_SDL_WINDOW_FULLSCREEN : 0)
            | (scalable ? NTSD_SDL_WINDOW_RESIZABLE | NTSD_SDL_WINDOW_HIGH_PIXEL_DENSITY : 0)
        guard let window = SDL_CreateWindow(title,Int32(client.width),Int32(client.height),flags) else { throw Self.error() }
        guard let renderer = SDL_CreateRenderer(window,nil) else { SDL_DestroyWindow(window); throw Self.error() }
        let w = SDLWindow(window:window,renderer:renderer,popup:popup,client:client)
        if !popup {
            let x = ((screen.width-width)/2).rounded(.down)+metrics.frameX
            let y = ((screen.height-height)/2).rounded(.down)+metrics.caption+metrics.frameY
            w.placed = CGPoint(x:x,y:y)
            if scalable {
                // The game keeps the centred client it asked for (`placed`);
                // the real window is larger, centred, and only scales the picture.
                w.scalable = true
                let aspect = Float(client.width/client.height),size = initialSize(client)
                _ = SDL_SetWindowAspectRatio(window,aspect,aspect)
                _ = SDL_SetWindowMinimumSize(window,Int32((client.width/2).rounded()),Int32((client.height/2).rounded()))
                _ = SDL_SetWindowSize(window,Int32(size.width),Int32(size.height))
                _ = SDL_SetWindowPosition(window,NTSD_SDL_WINDOWPOS_CENTERED,NTSD_SDL_WINDOWPOS_CENTERED)
            } else {
                _ = SDL_SetWindowPosition(window,Int32(x),Int32(y))
            }
        }
        return w
    }
    func windowCreated(_ lease: OriginalRuntimeWindowBackend.WindowLease,popup: Bool,backend: OriginalRuntimeWindowBackend) {}
    func orderFront(_ window: AnyObject) {
        let w = Self.window(window); _ = SDL_ShowWindow(w.window); _ = SDL_RaiseWindow(w.window); w.visible = true
    }
    func update(_ window: AnyObject) {}
    func show(_ window: AnyObject) -> Bool {
        let w = Self.window(window),wasVisible = w.visible
        _ = SDL_ShowWindow(w.window); w.visible = true; return wasVisible
    }
    func close(_ window: AnyObject) { let w = Self.window(window); _ = SDL_HideWindow(w.window); w.closed = true; w.visible = false }
    nonisolated func released(_ window: AnyObject,closed: Bool,platformState: AnyObject?) {
        let box = UncheckedBox(window)
        DispatchQueue.main.async { MainActor.assumeIsolated { Self.window(box.value).destroy() } }
    }
    func clientBounds(_ window: AnyObject) throws -> CGRect { CGRect(origin:.zero,size:Self.window(window).client) }
    func clientFrame(_ window: AnyObject) throws -> CGRect { CGRect(origin:.zero,size:Self.window(window).client) }
    /// Wayland does not expose window positions (SDL reports 0,0), and the
    /// game offset its whole scene by the difference from where it asked the
    /// window to be: there the host reports the position it placed.
    private static let positionsKnown = SDL_GetCurrentVideoDriver().map { String(cString:$0) } != "wayland"
    private func origin(_ w: SDLWindow) -> CGPoint {
        guard Self.positionsKnown,!w.scalable else { return w.placed }
        var x: Int32 = 0,y: Int32 = 0
        guard SDL_GetWindowPosition(w.window,&x,&y) else { return w.placed }
        return CGPoint(x:CGFloat(x),y:CGFloat(y))
    }
    func displayGeometry(_ window: AnyObject) throws -> OriginalRuntimeDisplayGeometry {
        let w = Self.window(window),screen = try screenSize(),o = origin(w)
        // Host logical points with a bottom-left origin, as the AppKit host reports.
        return .init(screen:CGRect(origin:.zero,size:screen),
                     clientOnScreen:CGRect(x:o.x,y:screen.height-o.y-w.client.height,width:w.client.width,height:w.client.height))
    }
    func desktopPoint(_ window: AnyObject,client point: CGPoint) throws -> CGPoint {
        let o = origin(Self.window(window)); return CGPoint(x:o.x+point.x,y:o.y+point.y)
    }
    func present(_ frame: OriginalFramebuffer,in window: AnyObject) throws {
        let w = Self.window(window),size = CGSize(width:frame.width,height:frame.height)
        if w.texture == nil || w.textureSize != size {
            if let texture = w.texture { SDL_DestroyTexture(texture) }
            guard let texture = SDL_CreateTexture(w.renderer,SDL_PIXELFORMAT_XRGB8888,SDL_TEXTUREACCESS_STREAMING,Int32(frame.width),Int32(frame.height))
            else { throw Self.error() }
            _ = SDL_SetTextureScaleMode(texture,SDL_SCALEMODE_NEAREST)
            w.texture = texture; w.textureSize = size
        }
        frame.pixels.withUnsafeBytes { _ = SDL_UpdateTexture(w.texture,nil,$0.baseAddress,Int32(frame.width*4)) }
        if w.scalable { draw(w); return }
        var ww: Int32 = 0,wh: Int32 = 0; _ = SDL_GetWindowSize(w.window,&ww,&wh)
        var destination: SDL_FRect
        do {
            let scale = min(CGFloat(ww)/size.width,CGFloat(wh)/size.height)
            w.drawn = size == w.client ? CGRect(origin:.zero,size:size)
                : CGRect(x:(CGFloat(ww)-size.width*scale)/2,y:(CGFloat(wh)-size.height*scale)/2,width:size.width*scale,height:size.height*scale)
            destination = SDL_FRect(x:Float(w.drawn.minX),y:Float(w.drawn.minY),w:Float(w.drawn.width),h:Float(w.drawn.height))
        }
        _ = SDL_SetRenderDrawColor(w.renderer,0,0,0,255); _ = SDL_RenderClear(w.renderer)
        _ = SDL_RenderTexture(w.renderer,w.texture,nil,&destination); _ = SDL_RenderPresent(w.renderer)
    }
    /// A scalable window's picture box for its current size: in the output's
    /// pixels (high pixel density) for drawing, and in window points, where
    /// mouse events arrive.
    func box(_ w: SDLWindow,_ size: CGSize) -> (pixels: CGRect,points: CGRect) {
        var ww: Int32 = 0,wh: Int32 = 0; _ = SDL_GetWindowSize(w.window,&ww,&wh)
        var pw: Int32 = 0,ph: Int32 = 0
        if !SDL_GetRenderOutputSize(w.renderer,&pw,&ph) || pw <= 0 || ph <= 0 { pw = ww; ph = wh }
        let scale = min(CGFloat(pw)/size.width,CGFloat(ph)/size.height)
        let pixels = CGRect(x:((CGFloat(pw)-size.width*scale)/2).rounded(),y:((CGFloat(ph)-size.height*scale)/2).rounded(),
                            width:(size.width*scale).rounded(),height:(size.height*scale).rounded())
        let density = CGFloat(pw)/max(1,CGFloat(ww))
        return (pixels,CGRect(x:pixels.minX/density,y:pixels.minY/density,width:pixels.width/density,height:pixels.height/density))
    }
    /// Draws a scalable window's last frame at its current size (each present,
    /// and again when the window's size changes).
    func draw(_ w: SDLWindow) {
        guard w.scalable,let texture = w.texture,w.textureSize != .zero else { return }
        let (pixels,points) = box(w,w.textureSize); w.drawn = points
        var destination = SDL_FRect(x:Float(pixels.minX),y:Float(pixels.minY),w:Float(pixels.width),h:Float(pixels.height))
        _ = SDL_SetRenderDrawColor(w.renderer,0,0,0,255); _ = SDL_RenderClear(w.renderer)
        _ = SDL_RenderTexture(w.renderer,texture,nil,&destination); _ = SDL_RenderPresent(w.renderer)
    }
    /// A rectangle of the game's client (the drawn frame's pixels) in window
    /// points: `clientPoint` the other way.
    func windowRect(_ w: SDLWindow,client r: CGRect,frame: CGSize) -> CGRect {
        if w.scalable,w.drawn.width <= 0 || w.drawn.height <= 0 { w.drawn = box(w,w.client).points }
        guard w.drawn.width > 0,w.drawn.height > 0,frame.width > 0,frame.height > 0 else { return r }
        let sx = w.drawn.width/frame.width,sy = w.drawn.height/frame.height
        return CGRect(x:w.drawn.minX+r.minX*sx,y:w.drawn.minY+r.minY*sy,width:r.width*sx,height:r.height*sy)
    }
    /// A window point as the game's client point (the drawn frame's pixels).
    func clientPoint(_ w: SDLWindow,x: Float,y: Float,frame: CGSize) -> (Int32,Int32) {
        // A scalable window before its first frame maps through its client's box.
        if w.scalable,w.drawn.width <= 0 || w.drawn.height <= 0 { w.drawn = box(w,w.client).points }
        guard w.drawn.width > 0,w.drawn.height > 0 else { return (Int32(x.rounded(.down)),Int32(y.rounded(.down))) }
        let px = (CGFloat(x)-w.drawn.minX)*frame.width/w.drawn.width,py = (CGFloat(y)-w.drawn.minY)*frame.height/w.drawn.height
        return (Int32(px.rounded(.down)),Int32(py.rounded(.down)))
    }
}

struct UncheckedBox<T>: @unchecked Sendable { let value: T; init(_ value: T) { self.value = value } }
