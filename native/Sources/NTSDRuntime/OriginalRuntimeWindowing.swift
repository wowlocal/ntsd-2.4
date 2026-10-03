import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import NTSDCore

/// A host window held by a display resource (a DirectDraw object's cooperative
/// window or a clipper's window); holding it keeps the window's token alive.
@MainActor public protocol OriginalRuntimeWindowLease: OriginalApplicationStartupResource {
    var token: UInt32 { get }
}

/// A window's screen and client rectangles in the host's logical points.
public struct OriginalRuntimeDisplayGeometry: Equatable {
    public let screen: CGRect, clientOnScreen: CGRect
    public init(screen: CGRect, clientOnScreen: CGRect) { self.screen = screen; self.clientOnScreen = clientOnScreen }
    /// Top-left desktop coordinates in logical points.
    public var clientInDesktop: CGRect {
        .init(x:clientOnScreen.minX-screen.minX,y:screen.maxY-clientOnScreen.maxY,
              width:clientOnScreen.width,height:clientOnScreen.height)
    }
}

/// What the display backend needs from the host's windows
/// (docs/research/CROSS_PLATFORM_RUNTIME.md).
@MainActor public protocol OriginalRuntimeWindowing: AnyObject {
    var identities: OriginalMacResourceIdentityPool { get }
    func windowLease(_ token: UInt32) throws -> any OriginalRuntimeWindowLease
    func displayGeometry(_ token: UInt32) throws -> OriginalRuntimeDisplayGeometry
    /// Shows a finished crop in the window's client area.
    func present(_ frame: OriginalFramebuffer, in token: UInt32) throws
}
