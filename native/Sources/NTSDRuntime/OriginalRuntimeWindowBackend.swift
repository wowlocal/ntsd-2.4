import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import NTSDCore

/// What a platform supplies for the original's window family. Host windows and
/// cursors are opaque objects owned by the host; the runtime keeps the original
/// request rules, tokens, leases and operation order
/// (docs/research/CROSS_PLATFORM_RUNTIME.md).
@MainActor public protocol OriginalRuntimeWindowHost: AnyObject {
    /// SM_CXSCREEN/SM_CYSCREEN: the main display in logical points.
    func screenSize() throws -> CGSize
    /// SM_CXFIXEDFRAME (7), SM_CYFIXEDFRAME (8) or SM_CYCAPTION (4) of the
    /// windowed style, in logical points; the runtime requires an integer.
    func frameMetric(_ index: UInt32) throws -> CGFloat
    /// LoadCursor(0, IDC_ARROW)'s host cursor.
    func arrowCursor() -> AnyObject
    /// A configured, not yet ordered-front window: full screen (`popup`) over the
    /// main display, otherwise a centred window of the given outer size.
    func createWindow(popup: Bool, width: CGFloat, height: CGFloat, title: String, cursor: AnyObject) throws -> AnyObject
    /// Called once the lease exists, before the window is shown.
    func windowCreated(_ lease: OriginalRuntimeWindowBackend.WindowLease, popup: Bool, backend: OriginalRuntimeWindowBackend)
    func orderFront(_ window: AnyObject)
    /// UpdateWindow on an open window.
    func update(_ window: AnyObject)
    /// ShowWindow(SW_SHOW) on an open window; returns whether it was visible.
    func show(_ window: AnyObject) -> Bool
    /// DestroyWindow on an open window.
    func close(_ window: AnyObject)
    /// The last lease went away (possibly off the main thread); `closed` says
    /// whether DestroyWindow already ran.
    nonisolated func released(_ window: AnyObject, closed: Bool, platformState: AnyObject?)
    /// The open client view's bounds; `Boundary.geometry` without one.
    func clientBounds(_ window: AnyObject) throws -> CGRect
    /// The open client view's frame; `Boundary.geometry` without one.
    func clientFrame(_ window: AnyObject) throws -> CGRect
    /// The window's screen and client rectangle in host logical points.
    func displayGeometry(_ window: AnyObject) throws -> OriginalRuntimeDisplayGeometry
    /// A client point (top-left origin) in desktop coordinates (top-left origin).
    func desktopPoint(_ window: AnyObject, client point: CGPoint) throws -> CGPoint
    /// Shows a finished crop; the runtime has checked the window and the size.
    func present(_ frame: OriginalFramebuffer, in window: AnyObject) throws
}

/// The original's window family (metrics, icon, cursor, class, CreateWindow,
/// Update/Show/DestroyWindow, client rectangle and screen point) over a host.
/// All methods are called outside Core attempts.
@MainActor public final class OriginalRuntimeWindowBackend: OriginalRuntimeWindowing {
    public typealias Window = OriginalWindowInitialization
    public typealias DisplayGeometry = OriginalRuntimeDisplayGeometry
    public enum Boundary: Error, Equatable {
        case unsupported(String), arguments(String), unknownOwner(UInt32)
        case geometry, exhaustedTokens, foreignPreparation, repeatedPreparation
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
    public final class CursorLease: OriginalApplicationStartupResource {
        public let token: UInt32, cursor: AnyObject
        init(_ token: UInt32,_ cursor: AnyObject) { self.token = token; self.cursor = cursor }
    }
    public final class ClassLease: OriginalApplicationStartupResource {
        public let token: UInt32, cursor: CursorLease, source: Window.Request
        init(_ token: UInt32,_ cursor: CursorLease,_ source: Window.Request) {
            self.token = token; self.cursor = cursor; self.source = source
        }
    }
    /// Receipts retain this lease; the registry is weak. Closing is a physical
    /// action, never an effect of Native transaction rollback. The host decides
    /// how a released, still open window is torn down.
    public final class WindowLease: OriginalApplicationStartupResource, OriginalRuntimeWindowLease {
        public let token: UInt32
        public let window: AnyObject, windowClass: ClassLease
        public internal(set) var closed = false
        /// The full-screen popup of an Alt+Enter recreation shows the game's
        /// image scaled to fit (declared, APPLICATION_FULL_SCREEN_PLAN.md).
        public internal(set) var fullScreen = false
        /// The last presented crop's size.
        public var contentSize: CGSize?
        /// Host full screen (APPLICATION_MAC_FULL_SCREEN_PLAN.md, declared): the
        /// windowed geometry the game keeps seeing while the view only scales.
        public var held: DisplayGeometry?
        /// Host-owned per-window state (observers, delegates).
        public var platformState: AnyObject?
        /// Either full screen shows the image scaled to fit.
        public var scaled: Bool { fullScreen || held != nil }
        fileprivate var release: ((Bool,AnyObject?) -> Void)?
        init(_ token: UInt32,_ window: AnyObject,_ windowClass: ClassLease) {
            self.token = token; self.window = window; self.windowClass = windowClass
        }
        deinit { release?(closed,platformState) }
    }
    private final class WeakWindow {
        weak var value: WindowLease?
        init(_ value: WindowLease) { self.value = value }
    }
    public let host: any OriginalRuntimeWindowHost
    private let identity = Identity(), instance: UInt32
    public let identities: OriginalMacResourceIdentityPool
    private var cursor: CursorLease?, windowClass: ClassLease?
    private var windows: [UInt32:WeakWindow] = [:]
    public private(set) var operations: [Operation] = []
    public private(set) var createdWindowCount = 0
    /// Called with a window created after the first one (Alt+Enter), so its
    /// owner can move input and close handling to it.
    public var created: ((UInt32) -> Void)?
    public init(instance: UInt32,identities: OriginalMacResourceIdentityPool? = nil,host: any OriginalRuntimeWindowHost) {
        self.instance = instance; self.identities = identities ?? OriginalMacResourceIdentityPool(); self.host = host
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
    public func windowLease(_ token: UInt32) throws -> any OriginalRuntimeWindowLease { try lease(token) }
    public func windowClosed(_ token: UInt32) throws -> Bool { try lease(token).closed }
    public func displayGeometry(_ token: UInt32) throws -> DisplayGeometry {
        let owner = try lease(token)
        if let held = owner.held,!owner.closed { return held }
        guard !owner.closed else { throw Boundary.geometry }
        return try host.displayGeometry(owner.window)
    }
    /// Shows a finished crop. Outside full screen it must be the client size the
    /// game sees (the held windowed client while the host scales).
    public func present(_ frame: OriginalFramebuffer,in token: UInt32) throws {
        let owner = try lease(token)
        guard !owner.closed else { throw Boundary.geometry }
        let size = CGSize(width:frame.width,height:frame.height),bounds = try host.clientBounds(owner.window)
        guard owner.fullScreen || size == (owner.held?.clientOnScreen.size ?? bounds.size) else { throw Boundary.geometry }
        owner.contentSize = size
        try host.present(frame,in:owner.window)
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
    /// Pure payload/owner validation: no host calls and no physical service claim.
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
    private func metric(_ index: UInt32) throws -> Int32 {
        if index == 0 || index == 1 {
            let size = try host.screenSize(),value = index == 0 ? size.width : size.height
            guard value.isFinite,value > 0,value <= CGFloat(Int32.max),value.rounded(.towardZero) == value else { throw Boundary.geometry }
            return Int32(value)
        }
        let value = try host.frameMetric(index)
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
            // Do not substitute its unrelated icon or a generic host image.
            result = .init(result:0)
        case "cursor":
            if cursor == nil { cursor = try CursorLease(token(),host.arrowCursor()) }
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
            let window = try host.createWindow(popup:popup,width:CGFloat(q.words[6]),height:CGFloat(q.words[7]),
                                               title:String(decoding:q.strings[1],as:UTF8.self),cursor:cls.cursor.cursor)
            let owner = WindowLease(id,window,cls); owner.fullScreen = popup
            let host = self.host
            // The host tears down a still open window even after this backend is gone.
            owner.release = { closed,state in host.released(window,closed:closed,platformState:state) }
            host.windowCreated(owner,popup:popup,backend:self)
            windows[id] = WeakWindow(owner); resources = [owner]; createdWindowCount += 1
            host.orderFront(window) // Source requests WS_VISIBLE.
            if createdWindowCount > 1 { created?(id) }
            result = .init(result:Int32(bitPattern:id))
        case "updateWindow","showWindow","destroyWindow":
            if q.words[0] == 0 { result = .init(result:0) }
            else {
                let owner = try lease(q.words[0]); resources = [owner]
                if owner.closed { result = .init(result:0) }
                else if q.kind == "updateWindow" { host.update(owner.window); result = .init(result:1) }
                else if q.kind == "showWindow" { result = .init(result:host.show(owner.window) ? 1 : 0) }
                else { host.close(owner.window); owner.closed = true; result = .init(result:1) }
            }
        default: throw Boundary.unsupported(q.kind)
        }
        operations.append(.init(request:q,response:result))
        return .init(response:result,resources:resources)
    }
}

extension OriginalRuntimeWindowBackend {
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
    /// the current host window; preparation never freezes geometry.
    private func performGeometry(_ q: Window.Request) throws -> Window.Response {
        let owner = try lease(q.words[0])
        guard !owner.closed else { throw Boundary.geometry }
        let bounds = try host.clientBounds(owner.window),frame = try host.clientFrame(owner.window)
        guard bounds.origin == .zero,bounds.size == frame.size else { throw Boundary.geometry }
        let values: [Int32]
        if let held = owner.held {
            // Host full screen: the client the game had in its window.
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
            guard bounds.width >= 0,bounds.height >= 0 else { throw Boundary.geometry }
            values = [0,0,try Self.geometryInteger(bounds.width),try Self.geometryInteger(bounds.height)]
        } else {
            guard let bytes = q.bytes,let mask = q.defined else { throw Boundary.geometry }
            let input = try OriginalStateRecord(bytes:bytes,defined:mask)
            let local = CGPoint(x:CGFloat(try input.integer(at:0,as:Int32.self)),y:CGFloat(try input.integer(at:4,as:Int32.self)))
            let desktop = try host.desktopPoint(owner.window,client:local)
            values = [try Self.geometryInteger(desktop.x),try Self.geometryInteger(desktop.y)]
        }
        let output = values.flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded:UInt32(bitPattern:word) >> ($0*8)) } }
        return .init(result:1,bytes:output)
    }
}
