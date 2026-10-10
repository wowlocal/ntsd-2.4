import CSDL3
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import NTSDCore
import NTSDRuntime

/// An SDL window with its renderer and the streaming texture of the presented
/// framebuffer. `origin` is the client top-left on the desktop, as placed.
final class SDLWindow {
    let window: OpaquePointer, renderer: OpaquePointer, popup: Bool, client: CGSize
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
    static func window(_ object: AnyObject) -> SDLWindow { object as! SDLWindow }
    private static func error() -> Failure { .sdl(String(cString:SDL_GetError())) }
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
        let flags = NTSD_SDL_WINDOW_HIDDEN | (popup ? NTSD_SDL_WINDOW_FULLSCREEN : 0)
        guard let window = SDL_CreateWindow(title,Int32(client.width),Int32(client.height),flags) else { throw Self.error() }
        guard let renderer = SDL_CreateRenderer(window,nil) else { SDL_DestroyWindow(window); throw Self.error() }
        let w = SDLWindow(window:window,renderer:renderer,popup:popup,client:client)
        if !popup {
            let x = ((screen.width-width)/2).rounded(.down)+metrics.frameX
            let y = ((screen.height-height)/2).rounded(.down)+metrics.caption+metrics.frameY
            _ = SDL_SetWindowPosition(window,Int32(x),Int32(y))
            w.placed = CGPoint(x:x,y:y)
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
        guard Self.positionsKnown else { return w.placed }
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
        var ww: Int32 = 0,wh: Int32 = 0; _ = SDL_GetWindowSize(w.window,&ww,&wh)
        let scale = min(CGFloat(ww)/size.width,CGFloat(wh)/size.height)
        w.drawn = size == w.client ? CGRect(origin:.zero,size:size)
            : CGRect(x:(CGFloat(ww)-size.width*scale)/2,y:(CGFloat(wh)-size.height*scale)/2,width:size.width*scale,height:size.height*scale)
        var destination = SDL_FRect(x:Float(w.drawn.minX),y:Float(w.drawn.minY),w:Float(w.drawn.width),h:Float(w.drawn.height))
        _ = SDL_SetRenderDrawColor(w.renderer,0,0,0,255); _ = SDL_RenderClear(w.renderer)
        _ = SDL_RenderTexture(w.renderer,w.texture,nil,&destination); _ = SDL_RenderPresent(w.renderer)
    }
    /// A window point as the game's client point (the drawn frame's pixels).
    func clientPoint(_ w: SDLWindow,x: Float,y: Float,frame: CGSize) -> (Int32,Int32) {
        guard w.drawn.width > 0,w.drawn.height > 0 else { return (Int32(x.rounded(.down)),Int32(y.rounded(.down))) }
        let px = (CGFloat(x)-w.drawn.minX)*frame.width/w.drawn.width,py = (CGFloat(y)-w.drawn.minY)*frame.height/w.drawn.height
        return (Int32(px.rounded(.down)),Int32(py.rounded(.down)))
    }
}

struct UncheckedBox<T>: @unchecked Sendable { let value: T; init(_ value: T) { self.value = value } }
