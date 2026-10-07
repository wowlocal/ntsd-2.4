import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import NTSDCore

/// Windowed host resources. XRGB8888 and logical desktop points describe this
/// native backend, not an observed Windows display mode or offscreen conversion.
@MainActor public final class OriginalMacDisplayBackend {
    public typealias Window = OriginalWindowInitialization
    public enum Boundary: Error, Equatable {
        case unsupported(String), arguments(String), owner(UInt32), released(UInt32)
        case geometry, allocationBudget, allocationFailed, unknownPixel, image
        case foreignPreparation, repeatedPreparation, referenceOverflow
    }
    public enum Kind: String { case display, primary, backbuffer, clipper, offscreen, module, bitmap, stockBitmap, memoryDC, surfaceDC }
    public struct Observation: Equatable {
        public let token: UInt32, kind: Kind, references: UInt32, width: Int, height: Int
        public let window: UInt32?, clipper: UInt32?, knownPixels: Int
    }
    public struct Pixels: Equatable {
        public let width: Int, height: Int, values: [UInt32], defined: [Bool]
    }
    public struct Served {
        public let response: Window.Response
        public let resources: [any OriginalApplicationStartupResource]
    }
    public struct Operation: Equatable {
        public let request: Window.Request, response: Window.Response
    }
    fileprivate final class Identity {}
    fileprivate final class Once { var used = false }
    public struct Prepared {
        fileprivate let request: Window.Request, identity: Identity, once: Once
    }
    public class Resource: OriginalApplicationStartupResource {
        public let token: UInt32, kind: Kind
        fileprivate var references: UInt32 = 1
        fileprivate init(_ token: UInt32,_ kind: Kind) { self.token = token; self.kind = kind }
    }
    private final class Draw: Resource {
        var window: (any OriginalRuntimeWindowLease)?
        /// Exclusive full-screen level (0x11) and its declared display mode
        /// (APPLICATION_FULL_SCREEN_PLAN.md: answered DD_OK, shown scaled).
        var exclusive = false, mode: (width: Int,height: Int)?
        init(_ token: UInt32) { super.init(token,.display) }
    }
    /// Accounting may be released when a retained context dies off-main.
    private final class Budget {
        private let lock = NSLock(), maximum: Int
        private var used = 0
        init(_ maximum: Int) { self.maximum = maximum }
        var allocated: Int { lock.lock(); defer { lock.unlock() }; return used }
        func reserve(_ bytes: Int) throws {
            lock.lock(); defer { lock.unlock() }
            guard bytes >= 0,bytes <= maximum,used <= maximum-bytes else { throw Boundary.allocationBudget }
            used += bytes
        }
        func release(_ bytes: Int) { lock.lock(); used -= bytes; lock.unlock() }
    }
    /// Pixel knowledge, one bit per pixel (it was one byte; MEMORY_FOOTPRINT
    /// step 2). The subscript reads and writes 0 or 1 like the byte mask did.
    private struct KnownMask {
        let words: UnsafeMutablePointer<UInt64>, count: Int
        /// True only while every pixel is known (CORE_REALTIME 1g): cleared by
        /// any write that can clear a bit, set where an operation is known to
        /// set every bit. While true, `allKnown` answers at once and
        /// `setRange` has nothing to do.
        private let fullFlag: UnsafeMutablePointer<Bool>
        init?(_ count: Int) {
            guard let raw = calloc((count+63)/64,8) else { return nil }
            guard let flag = calloc(1,1) else { Foundation.free(raw); return nil }
            words = raw.assumingMemoryBound(to:UInt64.self); self.count = count
            fullFlag = flag.assumingMemoryBound(to:Bool.self)
        }
        var isFull: Bool { fullFlag.pointee }
        /// The caller has just set every bit.
        func markFull() { fullFlag.pointee = true }
        /// Recompute the flag from the bits (after each batch of recorded writes).
        func refreshFull() {
            let full = count/64
            var all = true
            for w in 0..<full where words[w] != ~0 { all = false; break }
            if all && count%64 != 0 { all = words[full] == (UInt64(1) << UInt64(count%64))-1 }
            fullFlag.pointee = all
        }
        subscript(i: Int) -> UInt8 {
            get { UInt8(truncatingIfNeeded:words[i >> 6] >> UInt64(i & 63)) & 1 }
            nonmutating set {
                let bit = UInt64(1) << UInt64(i & 63)
                if newValue != 0 { words[i >> 6] |= bit } else { words[i >> 6] &= ~bit; fullFlag.pointee = false }
            }
        }
        /// Marks pixels start..<start+length known (whole words at once).
        func setRange(_ start: Int,_ length: Int) {
            assert(start >= 0 && length >= 0 && start+length <= count,"known range")
            if fullFlag.pointee { return }
            var i = start
            let end = start+length
            while i < end && i & 63 != 0 { words[i >> 6] |= UInt64(1) << UInt64(i & 63); i += 1 }
            while end-i >= 64 { words[i >> 6] = ~0; i += 64 }
            while i < end { words[i >> 6] |= UInt64(1) << UInt64(i & 63); i += 1 }
        }
        /// Sets the `set` bits and clears the `clear` bits of word `w` (disjoint).
        func merge(_ w: Int,set: UInt64,clear: UInt64) {
            if clear != 0 { fullFlag.pointee = false }
            if set|clear != 0 { words[w] = (words[w] & ~clear) | set }
        }
        /// Every pixel known (bits past `count` stay clear).
        func setAll() {
            let full = count/64
            for w in 0..<full { words[w] = ~0 }
            if count%64 != 0 { words[full] = (UInt64(1) << UInt64(count%64))-1 }
            fullFlag.pointee = true
        }
        var knownCount: Int { (0..<(count+63)/64).reduce(0) { $0+words[$1].nonzeroBitCount } }
        /// Whether pixels start..<start+length are all known (whole words at once).
        func allKnown(_ start: Int,_ length: Int) -> Bool {
            assert(start >= 0 && length >= 0 && start+length <= count,"known range")
            if fullFlag.pointee { return true }
            var i = start
            let end = start+length
            while i < end && i & 63 != 0 { if self[i] == 0 { return false }; i += 1 }
            while end-i >= 64 { if words[i >> 6] != ~0 { return false }; i += 64 }
            while i < end { if self[i] == 0 { return false }; i += 1 }
            return true
        }
        var bools: [Bool] { (0..<count).map { self[$0] != 0 } }
        func free() { Foundation.free(words); Foundation.free(fullFlag) }
    }
    private final class Storage {
        let width: Int, height: Int, count: Int, byteCount: Int, budget: Budget
        private let valuesStorage: UnsafeMutablePointer<UInt32>, knownStorage: KnownMask
        /// Writes recorded but not yet applied, in order. A copy of a whole loaded
        /// image into a surface is recorded and written at the surface's first
        /// pixel access: the allocation stays at creation (zero pages cost no
        /// physical memory until written) and most image surfaces are never read
        /// in a match (MEMORY_FOOTPRINT step 3). Every access goes through
        /// `values`/`known`, which apply the recorded writes first.
        private var pending: [(UnsafeMutablePointer<UInt32>,KnownMask) -> Void] = []
        var values: UnsafeMutablePointer<UInt32> { if !pending.isEmpty { applyPending() }; return valuesStorage }
        var known: KnownMask { if !pending.isEmpty { applyPending() }; return knownStorage }
        func record(_ write: @escaping (UnsafeMutablePointer<UInt32>,KnownMask) -> Void) { pending.append(write) }
        private func applyPending() {
            let writes = pending; pending = []
            for write in writes { write(valuesStorage,knownStorage) }
            knownStorage.refreshFull()
        }
        init(_ width: Int,_ height: Int,_ budget: Budget) throws {
            guard width > 0,height > 0,width <= Int.max/height,width*height <= Int.max/5 else { throw Boundary.geometry }
            // The budget still counts five bytes per pixel, as the byte mask did,
            // so allocation-budget boundaries fall where they did.
            self.width = width; self.height = height; count = width*height; byteCount = count*5; self.budget = budget
            try budget.reserve(byteCount)
            guard let pixels = calloc(count,4) else { budget.release(byteCount); throw Boundary.allocationFailed }
            guard let mask = KnownMask(count) else { free(pixels); budget.release(byteCount); throw Boundary.allocationFailed }
            valuesStorage = pixels.assumingMemoryBound(to:UInt32.self); knownStorage = mask
            // Zero allocation bytes are not an original initialized framebuffer.
        }
        deinit { free(valuesStorage); knownStorage.free(); budget.release(byteCount) }
    }
    private final class Surface: Resource {
        let draw: Draw, width: Int, height: Int, screen: CGRect?
        var storage: Storage?, clipper: Clipper?
        var activeBitmapDC: UInt32?, sourceColorKey: [UInt32]?
        /// A flipping primary's back buffers, in chain order.
        var chain: [Surface] = []
        init(_ token: UInt32,_ kind: Kind,_ draw: Draw,_ storage: Storage,_ screen: CGRect?) {
            self.draw = draw; self.storage = storage; self.screen = screen
            width = storage.width; height = storage.height; super.init(token,kind)
        }
    }
    private final class Clipper: Resource {
        let draw: Draw
        var window: (any OriginalRuntimeWindowLease)?
        init(_ token: UInt32,_ draw: Draw) { self.draw = draw; super.init(token,.clipper) }
    }
    private final class WeakResource {
        weak var value: Resource?
        init(_ value: Resource) { self.value = value }
    }
    public let windows: any OriginalRuntimeWindowing
    /// Glyph masks for TextOutA; the Mac rasterises with CoreText.
    private let textMask: ([UInt8]) -> TextMask
    /// `textMask`'s results by string (CORE_REALTIME 4h; see `mask`).
    private var textMasks: [[UInt8]: TextMask] = [:]
    private var bitmapModule: Resource?
    /// Served operations in order, kept only with `keepsOperationLogs`; the
    /// counts are always kept.
    public private(set) var bitmapOperations: [BitmapOperation] = []
    public private(set) var frontOperations: [FrontOperation] = []
    public private(set) var operationCount = 0, bitmapOperationCount = 0, frontOperationCount = 0
    private let identity = Identity(), budget: Budget
    private var live: [UInt32:Resource] = [:], history: [UInt32:WeakResource] = [:]
    /// The surface DC that TextOut draws through (APPLICATION_GDI_TEXT_PLAN.md).
    /// One at a time: both text routines release their DC before the next.
    private final class TextDC {
        let surface: Surface
        var opaque = true, background: UInt32 = 0xffffff, color: UInt32 = 0
        init(_ surface: Surface) { self.surface = surface }
    }
    private var textDC: TextDC?
    public private(set) var operations: [Operation] = []
    public private(set) var allocationCount = 0
    public var allocatedBytes: Int { budget.allocated }
    /// While set (the runtime's replay of a committed gameplay batch), front
    /// fill/copy/flip and text validate and update metadata here and queue their
    /// pixels and present on the render thread; every other entry point except a
    /// queued back-buffer fill (`pipelinesBackFill`) first waits for that work
    /// (CORE_REALTIME phases 1c, 1e, 1f). Needs presentUnknownAsBlack, so
    /// validation never reads pixels.
    public var pipelinesFront = false
    /// Queue back-buffer colour fills on the render thread (CORE_REALTIME 1f);
    /// set by the runtime on hosts that present concurrently.
    public var pipelinesBackFill = false
    private let renderer = RenderExecutor()
    /// Waits for queued pixel work; rethrows an error the queued work threw
    /// (none can: presenters cannot fail and the crop of a black-filled
    /// front buffer never throws).
    public func flushRendering() throws { try renderer.flush() }
    /// One serial render thread for pipelined pixel work.
    private final class RenderExecutor: @unchecked Sendable {
        private let queue = DispatchQueue(label:"ntsd.render")
        private let lock = NSLock()
        private var failure: Error?, queued = false
        func submit(_ work: @escaping @Sendable () throws -> Void) {
            queued = true
            queue.async { do { try work() } catch { self.lock.lock(); if self.failure == nil { self.failure = error }; self.lock.unlock() } }
        }
        func flush() throws {
            guard queued else { return }
            queue.sync {}; queued = false
            lock.lock(); let held = failure; failure = nil; lock.unlock()
            if let held { throw held }
        }
    }
    /// For a present of `region`: nil when it must stay synchronous (the host
    /// presents on the main thread), .some(nil) when there is no window.
    private func pipelinedPresent(_ region: (Int,Int,Int,Int,UInt32?)) throws -> OriginalPresentDelivery?? {
        guard let window = region.4 else { return .some(nil) }
        guard let delivery = try windows.preparePresent(width:region.2,height:region.3,in:window) else { return nil }
        return .some(delivery)
    }
    public var retainedResources: [any OriginalApplicationStartupResource] { Array(live.values) }
    /// Declared live-app policies: fresh surfaces start as known black, and
    /// presentation shows still-unknown pixels as black. The defaults keep
    /// unwritten pixels unknown, as the comparison tests require.
    public let freshSurfacesKnownBlack: Bool, presentUnknownAsBlack: Bool
    /// Declared live-app policy: an RLE8 hole reads as palette entry 0. The
    /// LR_CREATEDIBSECTION bitmap starts zero-filled and the RLE stream never
    /// writes its holes, so StretchBlt copies index 0. With the WORDS keys
    /// (black, palette 0) the holes then key out, as observed under CrossOver
    /// (APPLICATION_RLE_HOLES.md); unknown holes would present as black boxes.
    public let rleHolesReadPaletteZero: Bool
    /// The live app keeps no operation logs: a match replays ≈130 draws per
    /// gameplay body, so a log would grow without bound.
    public let keepsOperationLogs: Bool
    public init(windows: any OriginalRuntimeWindowing,maximumBytes: Int = 256*1024*1024,freshSurfacesKnownBlack: Bool = false,
                presentUnknownAsBlack: Bool = false,rleHolesReadPaletteZero: Bool = false,keepsOperationLogs: Bool = true,
                textMask: @escaping ([UInt8]) -> TextMask) {
        self.windows = windows; self.textMask = textMask; budget = Budget(maximumBytes); self.freshSurfacesKnownBlack = freshSurfacesKnownBlack
        self.presentUnknownAsBlack = presentUnknownAsBlack; self.rleHolesReadPaletteZero = rleHolesReadPaletteZero
        self.keepsOperationLogs = keepsOperationLogs
    }
    private func storage(_ width: Int,_ height: Int) throws -> Storage {
        let value = try Storage(width,height,budget)
        if freshSurfacesKnownBlack { value.known.setAll() }
        return value
    }
    public nonisolated static func handles(_ q: Window.Request) -> Bool {
        ["directDrawCreate","cooperativeLevel","displayMode","createSurface","attachedSurface","createClipper","clipperWindow","setClipper","release","pixelFormat","blt"].contains(q.kind)
    }
    public func lease(_ token: UInt32) throws -> Resource {
        guard let resource = history[token]?.value else { throw Boundary.owner(token) }; return resource
    }
    private func resource<T:Resource>(_ token: UInt32,as type: T.Type) throws -> T {
        guard let value = try lease(token) as? T else { throw Boundary.owner(token) }
        guard value.references > 0 else { throw Boundary.released(token) }; return value
    }
    private func install(_ value: Resource) {
        live[value.token] = value; history[value.token] = WeakResource(value); allocationCount += 1
    }
    public func observation(_ token: UInt32) throws -> Observation {
        try renderer.flush()
        let value = try lease(token),s = value as? Surface,c = value as? Clipper,d = value as? Draw
        let known: Int
        if let storage = s?.storage {
            known = storage.known.knownCount
        } else { known = 0 }
        return .init(token:token,kind:value.kind,references:value.references,width:s?.width ?? 0,height:s?.height ?? 0,
            window:c?.window?.token ?? d?.window?.token ?? s?.draw.window?.token,clipper:s?.clipper?.token,knownPixels:known)
    }
    public func pixels(_ token: UInt32) throws -> Pixels {
        try renderer.flush()
        let s = try resource(token,as:Surface.self)
        guard let data = s.storage else { throw Boundary.released(token) }
        return .init(width:data.width,height:data.height,
            values:Array(UnsafeBufferPointer(start:data.values,count:data.count)),
            defined:data.known.bools)
    }
    private func record(_ q: Window.Request,_ size: Int) throws -> OriginalStateRecord {
        guard let b = q.bytes,let m = q.defined,b.count == size,m.count == size else { throw Boundary.arguments(q.kind) }
        return try .init(bytes:b,defined:m)
    }
    /// Pure payload/identity validation. Only flagged structure fields are read;
    /// ignored private bytes stay untouched and do not become known zero.
    public func prepare(_ q: Window.Request) throws -> Prepared {
        let queuesFill = queuesBackFill(q)
        if !queuesFill { try renderer.flush() }
        do { try validate(q) } catch { if queuesFill { try renderer.flush() }; throw error }
        return .init(request:q,identity:identity,once:Once())
    }
    /// Whether a DirectDraw colour fill (Blt) skips waiting for the queued
    /// pixel work (CORE_REALTIME 1f): its checks read no pixels, the queue keeps
    /// its order, and every reader of pixels flushes first. `perform` queues
    /// only a fill with nothing to present (a back buffer) and flushes before a
    /// primary's fill and present; a failed check flushes before it throws, as
    /// the old order did.
    private func queuesBackFill(_ q: Window.Request) -> Bool {
        pipelinesBackFill && presentUnknownAsBlack && q.kind == "blt"
    }
    private func validate(_ q: Window.Request) throws {
        guard Self.handles(q) else { throw Boundary.unsupported(q.kind) }
        func require(_ condition: Bool) throws { if !condition { throw Boundary.arguments(q.kind) } }
        try require(q.strings.isEmpty)
        if !["createSurface","pixelFormat","blt"].contains(q.kind) { try require(q.bytes == nil && q.defined == nil) }
        switch q.kind {
        case "directDrawCreate": try require(q.words == [0,0x457578,0])
        case "cooperativeLevel":
            // DDSCL_NORMAL (windowed) or DDSCL_EXCLUSIVE|DDSCL_FULLSCREEN (Alt+Enter).
            try require(q.words.count == 3 && (q.words[2] == 8 || q.words[2] == 0x11))
            _ = try resource(q.words[0],as:Draw.self); _ = try windows.windowLease(q.words[1])
        case "displayMode":
            try require(q.words.count == 4 && q.words[3] == 8 && q.words[1] > 0 && q.words[2] > 0 &&
                q.words[1] <= 0x4000 && q.words[2] <= 0x4000)
            try require(try resource(q.words[0],as:Draw.self).exclusive)
        case "attachedSurface":
            // GetAttachedSurface(DDSCAPS_BACKBUFFER) of a flipping primary.
            try require(q.words.count == 3 && q.words[1] == 4 && q.words[2] == 0x455608)
            try require(!(try resource(q.words[0],as:Surface.self)).chain.isEmpty)
        case "createSurface":
            try require(q.words.count == 3 && q.words[2] == 0)
            let draw = try resource(q.words[0],as:Draw.self);try require(draw.window != nil)
            let r = try record(q,108),flags = try r.integer(at:4,as:UInt32.self),caps = try r.integer(at:104,as:UInt32.self)
            try require(try r.integer(at:0,as:UInt32.self) == 108)
            if flags == 0x21 && caps == 0x4218 {
                // 401380's flip chain: primary, flip, complex, video memory, 1 or 2 back buffers.
                try require(q.words[1] == 0x455634 && draw.exclusive && draw.mode != nil)
                try require([1,2].contains(try r.integer(at:20,as:UInt32.self)))
            } else if flags == 1 && caps == 0x200 { try require(q.words[1] == 0x455634) }
            else if flags == 7 && caps == 0x40 {
                try require(q.words[1] == 0x455608)
                try require(try r.integer(at:8,as:UInt32.self) > 0 && r.integer(at:12,as:UInt32.self) > 0)
            } else { throw Boundary.unsupported("surface flags/caps") }
        case "createClipper":
            try require(q.words.count == 4 && q.words[1...3] == [0,0x457584,0]); _ = try resource(q.words[0],as:Draw.self)
        case "clipperWindow":
            try require(q.words.count == 3 && q.words[1] == 0)
            _ = try resource(q.words[0],as:Clipper.self); _ = try windows.windowLease(q.words[2])
        case "setClipper":
            try require(q.words.count == 2)
            let s = try resource(q.words[0],as:Surface.self)
            if let old = s.clipper,old.references == 0 { throw Boundary.released(old.token) }
            if q.words[1] != 0 {
                let c = try resource(q.words[1],as:Clipper.self)
                try require(c.draw === s.draw)
                if s.clipper !== c { guard c.references < UInt32.max else { throw Boundary.referenceOverflow } }
            }
        case "release":
            try require(q.words.count == 1)
            let value = try resource(q.words[0],as:Resource.self)
            try require([Kind.display,.primary,.backbuffer,.offscreen,.clipper].contains(value.kind))
            guard (value as? Surface)?.activeBitmapDC == nil else { throw Boundary.unsupported("surface DC still acquired") }
            if let c = (value as? Surface)?.clipper,c.references == 0 { throw Boundary.released(c.token) }
        case "pixelFormat":
            try require(q.words.count == 1); _ = try resource(q.words[0],as:Surface.self)
            try require(try record(q,32).integer(at:0,as:UInt32.self) == 32)
        case "blt":
            try require(q.words.count == 5 && q.words[1...4] == [0,0,0,0x1000400])
            _ = try resource(q.words[0],as:Surface.self)
            let r = try record(q,100);try require(try r.integer(at:0,as:UInt32.self) == 100)
            _ = try r.integer(at:80,as:UInt32.self)
        default:throw Boundary.unsupported(q.kind)
        }
    }
    private func dimensions(_ size: CGSize) throws -> (Int,Int) {
        guard size.width.isFinite,size.height.isFinite,size.width > 0,size.height > 0,
            size.width <= CGFloat(Int32.max),size.height <= CGFloat(Int32.max),
            size.width.rounded(.towardZero) == size.width,size.height.rounded(.towardZero) == size.height else { throw Boundary.geometry }
        return (Int(size.width),Int(size.height))
    }
    private func release(_ r: Resource) {
        r.references -= 1
        if r.references == 0 {
            if let s = r as? Surface {
                if let c = s.clipper { s.clipper = nil; release(c) }; s.storage = nil
                let chain = s.chain; s.chain = []; for back in chain { release(back) }
            }
            live.removeValue(forKey:r.token)
        }
    }
    /// The primary represents this screen's logical desktop, while its clipper
    /// limits writes/delivery to our own window. No desktop pixels are sampled.
    private func rectangle(_ s: Surface) throws -> (Int,Int,Int,Int,UInt32?) {
        if s.kind == .backbuffer || s.kind == .offscreen { return (0,0,s.width,s.height,nil) }
        if s.screen == nil,s.draw.exclusive,let window = s.draw.window { return (0,0,s.width,s.height,window.token) }
        guard let clipper = s.clipper,let window = clipper.window,let screen = s.screen else { throw Boundary.unsupported("primary without native window clipper") }
        guard clipper.references > 0 else { throw Boundary.released(clipper.token) }
        let geometry = try windows.displayGeometry(window.token)
        guard geometry.screen == screen else { throw Boundary.unsupported("screen changed") }
        let rect = geometry.clientInDesktop,(w,h) = try dimensions(rect.size)
        guard rect.minX >= 0,rect.minY >= 0,rect.minX.rounded(.towardZero) == rect.minX,
              rect.minY.rounded(.towardZero) == rect.minY,rect.maxX <= CGFloat(s.width),rect.maxY <= CGFloat(s.height) else { throw Boundary.geometry }
        return (Int(rect.minX),Int(rect.minY),w,h,window.token)
    }
    /// The region's presentation words; unknown pixels are black only when
    /// `presentUnknownAsBlack` allows it.
    private func framebuffer(_ data: Storage,_ region: (Int,Int,Int,Int,UInt32?)) throws -> OriginalFramebuffer {
        try Self.crop(data,region,black:presentUnknownAsBlack,pool:framePool)
    }
    /// The region as a framebuffer; unknown pixels are black or a boundary.
    /// The buffers of the last few presented crops, reused once nothing else
    /// holds them (CORE_REALTIME 1i): a fresh 1.75 MB buffer per present cost
    /// an allocation, page faults and zero-filling, and returning the pages
    /// on free. A reused buffer still referenced elsewhere is copied on write;
    /// crop overwrites every byte, so the frame is the same either way.
    final class FramePool: @unchecked Sendable {
        private let lock = NSLock()
        private var buffers: [Data] = []
        /// The oldest of the last three buffers, when it has this size.
        func take(_ count: Int) -> Data? {
            lock.lock(); defer { lock.unlock() }
            guard buffers.count >= 3,buffers[0].count == count else { return nil }
            return buffers.removeFirst()
        }
        func keep(_ buffer: Data) {
            lock.lock(); defer { lock.unlock() }
            buffers.append(buffer); if buffers.count > 3 { buffers.removeFirst() }
        }
    }
    private let framePool = FramePool()
    private nonisolated static func crop(_ data: Storage,_ region: (Int,Int,Int,Int,UInt32?),black presentUnknownAsBlack: Bool,
                                         pool: FramePool) throws -> OriginalFramebuffer {
        let (x,y,w,h,_) = region
        var bytes = pool.take(w*h*4) ?? Data(count:w*h*4)
        let values = data.values,known = data.known   // once per frame (MOBILE_PERFORMANCE step 2)
        try bytes.withUnsafeMutableBytes { destination in
            for row in 0..<h {
                let start = (y+row)*data.width+x
                if known.allKnown(start,w) {
                    destination.baseAddress!.advanced(by:row*w*4).copyMemory(from:values+start,byteCount:w*4)
                } else {
                    guard presentUnknownAsBlack else { throw Boundary.unknownPixel }
                    let out = destination.baseAddress!.advanced(by:row*w*4).assumingMemoryBound(to:UInt32.self)
                    for i in 0..<w { out[i] = known[start+i] != 0 ? values[start+i] : 0 }
                }
            }
        }
        pool.keep(bytes)
        return OriginalFramebuffer(width:w,height:h,pixels:bytes)
    }
    /// The surface's presentation rectangle as a framebuffer.
    public func framebuffer(_ token: UInt32) throws -> OriginalFramebuffer {
        try renderer.flush()
        let s = try resource(token,as:Surface.self)
        guard let data = s.storage else { throw Boundary.released(token) }
        return try framebuffer(data,rectangle(s))
    }
    public func perform(_ prepared: Prepared) throws -> Served {
        let queuesFill = queuesBackFill(prepared.request)
        if !queuesFill { try renderer.flush() }
        do { return try perform(prepared,queuesFill:queuesFill) }
        catch { if queuesFill { try renderer.flush() }; throw error }
    }
    private func perform(_ prepared: Prepared,queuesFill: Bool) throws -> Served {
        guard prepared.identity === identity else { throw Boundary.foreignPreparation }
        guard !prepared.once.used else { throw Boundary.repeatedPreparation }
        try validate(prepared.request); prepared.once.used = true
        let q = prepared.request
        var retained: [any OriginalApplicationStartupResource] = []
        let response: Window.Response
        switch q.kind {
        case "directDrawCreate":
            let d = try Draw(windows.identities.take()); install(d);retained = [d];response = .init(output:d.token)
        case "cooperativeLevel":
            let d = try resource(q.words[0],as:Draw.self),w = try windows.windowLease(q.words[1])
            _ = try windows.displayGeometry(w.token);d.window = w;d.exclusive = q.words[2] == 0x11;retained = [d,w];response = .init()
        case "displayMode":
            let d = try resource(q.words[0],as:Draw.self)
            d.mode = (Int(q.words[1]),Int(q.words[2]));retained = [d];response = .init()
        case "attachedSurface":
            let primary = try resource(q.words[0],as:Surface.self),back = primary.chain[0]
            guard back.references < UInt32.max else { throw Boundary.referenceOverflow }
            back.references += 1;retained = [primary,back];response = .init(output:back.token)
        case "createSurface" where try record(q,108).integer(at:4,as:UInt32.self) == 0x21:
            let d = try resource(q.words[0],as:Draw.self),r = try record(q,108),(width,height) = d.mode!
            let s = try Surface(windows.identities.take(),.primary,d,self.storage(width,height),nil)
            for _ in 0..<Int(try r.integer(at:20,as:UInt32.self)) {
                let back = try Surface(windows.identities.take(),.backbuffer,d,self.storage(width,height),nil)
                install(back);s.chain.append(back)
            }
            install(s);retained = [s]+s.chain;response = .init(output:s.token)
        case "createSurface":
            let d = try resource(q.words[0],as:Draw.self),r = try record(q,108)
            let primary = try r.integer(at:104,as:UInt32.self) == 0x200
            let width: Int,height: Int,screen: CGRect?
            if primary,let mode = d.mode,d.exclusive {
                // The fake flipper in full screen: a mode-sized primary, no desktop.
                (width,height) = mode;screen = nil
            } else if primary {
                let geometry = try windows.displayGeometry(d.window!.token)
                (width,height) = try dimensions(geometry.screen.size);screen = geometry.screen
            } else {
                width = Int(try r.integer(at:12,as:UInt32.self));height = Int(try r.integer(at:8,as:UInt32.self));screen = nil
            }
            let storage = try self.storage(width,height)
            let s = try Surface(windows.identities.take(),primary ? .primary : .backbuffer,d,storage,screen)
            install(s);retained = [s];response = .init(output:s.token)
        case "createClipper":
            let d = try resource(q.words[0],as:Draw.self),c = try Clipper(windows.identities.take(),d)
            install(c);retained = [c];response = .init(output:c.token)
        case "clipperWindow":
            let c = try resource(q.words[0],as:Clipper.self),w = try windows.windowLease(q.words[2])
            _ = try windows.displayGeometry(w.token);c.window = w;retained = [c,w];response = .init()
        case "setClipper":
            let s = try resource(q.words[0],as:Surface.self)
            let c = try q.words[1] == 0 ? nil : resource(q.words[1],as:Clipper.self)
            if s.clipper !== c {
                if let old = s.clipper { release(old) };s.clipper = c
                if let c { c.references += 1 }
            }
            retained = [s];if let c { retained.append(c) };response = .init()
        case "release":
            let r = try resource(q.words[0],as:Resource.self);release(r);retained = [r];response = .init(result:Int32(bitPattern:r.references))
        case "pixelFormat":
            let s = try resource(q.words[0],as:Surface.self);retained = [s]
            let words: [UInt32] = [32,0x40,0,32,0x00ff0000,0x0000ff00,0x000000ff,0]
            response = .init(bytes:words.flatMap { value in (0..<4).map { UInt8(truncatingIfNeeded:value >> ($0*8)) } })
        case "blt":
            let s = try resource(q.words[0],as:Surface.self),color = try record(q,100).integer(at:80,as:UInt32.self)
            guard let data = s.storage else { throw Boundary.released(s.token) }
            let rect = try rectangle(s),(x,y,w,h,window) = rect
            if queuesFill && window == nil {
                let rows = y..<(y+h),right = x+w
                renderer.submit { Self.fillRows(data,rows,x,right,color) }
            } else {
                if queuesFill { try renderer.flush() }
                Self.fillRows(data,y..<(y+h),x,x+w,color)
                if let window { try windows.present(framebuffer(data,rect),in:window) }
            }
            retained = [s];response = .init()
        default:throw Boundary.unsupported(q.kind)
        }
        operationCount += 1; if keepsOperationLogs { operations.append(.init(request:q,response:response)) }
        return .init(response:response,resources:retained)
    }
}

// Original bitmap helpers use the same display registry/storage as startup.
// This is native XRGB policy; it does not assert Windows GDI raster equivalence.
extension OriginalMacDisplayBackend {
    public typealias BitmapAPI = OriginalBitmapSurfaceLoading
    public struct BitmapInputs {
        public enum File { case bitmap(OriginalApplicationStartupInputs.Bitmap), missing }
        public let resources: [String:OriginalApplicationStartupInputs.Bitmap]
        public let files: [String:File]
        public init(resources: [String:OriginalApplicationStartupInputs.Bitmap],files: [String:File]) {
            self.resources = resources;self.files = files
        }
    }
    public struct BitmapOperation: Equatable {
        public let request: BitmapAPI.Request,response: BitmapAPI.Response
    }
    public struct BitmapServed {
        public let response: BitmapAPI.Response,resources: [any OriginalApplicationStartupResource]
    }
    public struct BitmapPrepared {
        fileprivate let request: BitmapAPI.Request,inputs: BitmapInputs,identity: Identity,once: Once
    }
    public struct BitmapObservation: Equatable {
        public let selected: UInt32?,surface: UInt32?,activeDC: UInt32?,colorKey: [UInt32]?
    }
    private final class Bitmap: Resource {
        let input: OriginalApplicationStartupInputs.Bitmap?
        init(_ token: UInt32,_ input: OriginalApplicationStartupInputs.Bitmap?) {
            self.input = input;super.init(token,input == nil ? .stockBitmap : .bitmap)
        }
    }
    private final class MemoryDC: Resource {
        let stock: Bitmap
        var selected: Bitmap
        init(_ token: UInt32,_ stock: Bitmap) { self.stock = stock;self.selected = stock;super.init(token,.memoryDC) }
    }
    private final class SurfaceDC: Resource {
        let surface: Surface
        init(_ token: UInt32,_ surface: Surface) { self.surface = surface;super.init(token,.surfaceDC) }
    }
    public func bitmapObservation(_ token: UInt32) throws -> BitmapObservation {
        try renderer.flush()
        let r = try lease(token),m = r as? MemoryDC,d = r as? SurfaceDC,s = r as? Surface
        return .init(selected:m?.selected.token,surface:d?.surface.token,activeDC:s?.activeBitmapDC,colorKey:s?.sourceColorKey)
    }
    public nonisolated static func handlesBitmap(_ q: BitmapAPI.Request) -> Bool {
        ["module","image","getObject","createSurface","restore","createDC","selectObject","description",
         "getDC","stretch","releaseDC","deleteDC","deleteObject","colorKey","release"].contains(q.kind)
    }
    public func prepareBitmap(_ q: BitmapAPI.Request,inputs: BitmapInputs) throws -> BitmapPrepared {
        try renderer.flush()
        _ = try validateBitmap(q,inputs:inputs)
        return .init(request:q,inputs:inputs,identity:identity,once:Once())
    }
    private func bitmapRect(_ x: UInt32,_ y: UInt32,_ w: UInt32,_ h: UInt32,_ width: Int,_ height: Int) throws -> (Int,Int,Int,Int) {
        let x = Int(Int32(bitPattern:x)),y = Int(Int32(bitPattern:y)),w = Int(Int32(bitPattern:w)),h = Int(Int32(bitPattern:h))
        guard x >= 0,y >= 0,w > 0,h > 0,x <= width,y <= height,w <= width-x,h <= height-y else { throw Boundary.geometry }
        return (x,y,w,h)
    }
    private func bitmapSurface(_ token: UInt32) throws -> Surface {
        let s = try resource(token,as:Surface.self)
        guard s.kind == .offscreen || s.kind == .backbuffer else { throw Boundary.unsupported("bitmap DC on primary") }
        guard s.storage != nil else { throw Boundary.released(token) };return s
    }
    private func validateBitmap(_ q: BitmapAPI.Request,inputs: BitmapInputs) throws -> OriginalApplicationStartupInputs.Bitmap? {
        guard Self.handlesBitmap(q) else { throw Boundary.unsupported(q.kind) }
        func require(_ yes: Bool) throws { if !yes { throw Boundary.arguments(q.kind) } }
        if !["image","colorKey"].contains(q.kind) { try require(q.strings.isEmpty) }
        if !["getObject","createSurface","description"].contains(q.kind) { try require(q.bytes == nil && q.defined == nil) }
        switch q.kind {
        case "module":try require(q.words == [0])
        case "image":
            try require(q.words.count == 5 && q.strings.count == 1 && q.words[1] == 0)
            try require(q.words[0] == bitmapModule?.token)
            guard !q.strings[0].contains(0),let name = String(bytes:q.strings[0],encoding:.utf8) else { throw Boundary.arguments("image name") }
            let bitmap: OriginalApplicationStartupInputs.Bitmap?
            if q.words[4] == 0x2010 {
                guard let file = inputs.files[name] else { throw Boundary.unsupported("undeclared bitmap file: "+name) }
                switch file { case .bitmap(let input):bitmap = input;case .missing:bitmap = nil }
            } else if q.words[4] == 0x2000 { bitmap = inputs.resources[name] }
            else { throw Boundary.unsupported("image flags") }
            if let bitmap {
                guard (q.words[2] == 0 || q.words[2] == UInt32(bitmap.width)),
                      (q.words[3] == 0 || q.words[3] == UInt32(bitmap.height)) else { throw Boundary.unsupported("image scaling") }
            }
            return bitmap
        case "getObject":
            try require(q.words.count == 2 && q.words[1] == 24);_ = try record(q,24)
            guard try resource(q.words[0],as:Bitmap.self).input != nil else { throw Boundary.unsupported("stock bitmap description") }
        case "createSurface":
            try require(q.words.count == 2 && q.words[1] == 0)
            let d = try resource(q.words[0],as:Draw.self);try require(d.window != nil)
            let r = try record(q,108),flags = try r.integer(at:4,as:UInt32.self)
            try require(try r.integer(at:0,as:UInt32.self) == 108 && r.integer(at:104,as:UInt32.self) == 0x40)
            let w = try r.integer(at:12,as:UInt32.self),h = try r.integer(at:8,as:UInt32.self)
            _ = try bitmapRect(0,0,w,h,Int(Int32.max),Int(Int32.max))
            if flags == 0x1007 {
                let expected: [UInt32] = [0,0x40,0,32,0xff0000,0xff00,0xff,0]
                for i in 0..<8 { try require(try r.integer(at:72+i*4,as:UInt32.self) == expected[i]) }
            } else { try require(flags == 7) }
        case "restore":try require(q.words.count == 1);_ = try bitmapSurface(q.words[0])
        case "createDC":try require(q.words == [0])
        case "selectObject":
            try require(q.words.count == 2)
            let dc = try resource(q.words[0],as:MemoryDC.self),b = try resource(q.words[1],as:Bitmap.self)
            try require(b.input != nil || b === dc.stock)
        case "description":
            try require(q.words.count == 1);_ = try bitmapSurface(q.words[0])
            let r = try record(q,108)
            try require(try r.integer(at:0,as:UInt32.self) == 108 && r.integer(at:4,as:UInt32.self) == 6)
        case "getDC":
            try require(q.words.count == 1);let s = try bitmapSurface(q.words[0])
            guard s.activeBitmapDC == nil else { throw Boundary.unsupported("surface DC already acquired") }
        case "stretch":
            try require(q.words.count == 11 && q.words[10] == 0xcc0020)
            let dc = try resource(q.words[0],as:SurfaceDC.self),s = try bitmapSurface(dc.surface.token)
            try require(s.activeBitmapDC == dc.token)
            let source = try resource(q.words[5],as:MemoryDC.self)
            guard let b = source.selected.input else { throw Boundary.unsupported("copy from stock bitmap") }
            _ = try resource(source.selected.token,as:Bitmap.self)
            _ = try bitmapRect(q.words[1],q.words[2],q.words[3],q.words[4],s.width,s.height)
            _ = try bitmapRect(q.words[6],q.words[7],q.words[8],q.words[9],Int(b.width),Int(b.height))
            guard q.words[3] == q.words[8],q.words[4] == q.words[9] else { throw Boundary.unsupported("bitmap stretching") }
        case "releaseDC":
            try require(q.words.count == 2)
            let s = try bitmapSurface(q.words[0]),dc = try resource(q.words[1],as:SurfaceDC.self)
            try require(dc.surface === s && s.activeBitmapDC == dc.token)
        case "deleteDC":try require(q.words.count == 1);_ = try resource(q.words[0],as:MemoryDC.self)
        case "deleteObject":
            try require(q.words.count == 1);let b = try resource(q.words[0],as:Bitmap.self)
            try require(b.input != nil)
        case "colorKey":
            try require(q.words.count == 2 && q.words[1] == 8 && q.strings.count == 1 && q.strings[0].count == 8)
            _ = try bitmapSurface(q.words[0])
            let r = try OriginalStateRecord(bytes:q.strings[0],defined:Array(repeating:true,count:8))
            try require(try r.integer(at:0,as:UInt32.self) <= r.integer(at:4,as:UInt32.self))
        case "release":try validate(q)
        default:throw Boundary.unsupported(q.kind)
        }
        return nil
    }
    public func performBitmap(_ prepared: BitmapPrepared) throws -> BitmapServed {
        try renderer.flush()
        guard prepared.identity === identity else { throw Boundary.foreignPreparation }
        guard !prepared.once.used else { throw Boundary.repeatedPreparation }
        let q = prepared.request,input = try validateBitmap(q,inputs:prepared.inputs)
        prepared.once.used = true
        var owners: [any OriginalApplicationStartupResource] = []
        let response: BitmapAPI.Response
        switch q.kind {
        case "module":
            if bitmapModule == nil { let r = try Resource(windows.identities.take(),.module);install(r);bitmapModule = r }
            let m = bitmapModule!;owners = [m];response = .init(result:Int32(bitPattern:m.token))
        case "image":
            if let input { let b = try Bitmap(windows.identities.take(),input);install(b);owners = [b];response = .init(result:Int32(bitPattern:b.token)) }
            else { response = .init() }
        case "getObject":
            let b = try resource(q.words[0],as:Bitmap.self),bytes = try b.input!.objectBytes()
            owners = [b];response = .init(result:24,writes:[.init(offset:4,bytes:Array(bytes[4..<20]))])
        case "createSurface":
            let d = try resource(q.words[0],as:Draw.self),r = try record(q,108)
            let storage = try self.storage(Int(r.integer(at:12,as:UInt32.self)),Int(r.integer(at:8,as:UInt32.self)))
            let s = try Surface(windows.identities.take(),.offscreen,d,storage,nil)
            install(s);owners = [s];response = .init(output:s.token)
        case "restore":let s = try bitmapSurface(q.words[0]);owners = [s];response = .init()
        case "createDC":
            let stock = try Bitmap(windows.identities.take(),nil),dc = try MemoryDC(windows.identities.take(),stock)
            install(stock);install(dc);owners = [dc,stock];response = .init(result:Int32(bitPattern:dc.token))
        case "selectObject":
            let dc = try resource(q.words[0],as:MemoryDC.self),b = try resource(q.words[1],as:Bitmap.self)
            let elsewhere = live.values.compactMap { $0 as? MemoryDC }.contains { $0 !== dc && $0.selected === b }
            owners = [dc,b]
            if elsewhere { response = .init() }
            else { let old = dc.selected;dc.selected = b;owners.append(old);response = .init(result:Int32(bitPattern:old.token)) }
        case "description":
            let s = try bitmapSurface(q.words[0]);owners = [s]
            let bytes = [UInt32(s.height),UInt32(s.width)].flatMap { v in (0..<4).map { UInt8(truncatingIfNeeded:v >> ($0*8)) } }
            response = .init(writes:[.init(offset:8,bytes:bytes)])
        case "getDC":
            let s = try bitmapSurface(q.words[0]),dc = try SurfaceDC(windows.identities.take(),s)
            install(dc);s.activeBitmapDC = dc.token;owners = [dc,s];response = .init(output:dc.token)
        case "stretch":
            let dc = try resource(q.words[0],as:SurfaceDC.self),memory = try resource(q.words[5],as:MemoryDC.self)
            let input = memory.selected.input!,s = dc.surface,data = s.storage!
            let (x,y,w,h) = try bitmapRect(q.words[1],q.words[2],q.words[3],q.words[4],s.width,s.height)
            let sx = Int(q.words[6]),sy = Int(q.words[7]),holes = rleHolesReadPaletteZero,width = data.width
            // Recorded, applied at the surface's first pixel access (the image is
            // decoded then; nothing else changes the image in between).
            data.record { values,known in
                let p = input.pixels,hole = holes ? p.paletteZero : nil
                for row in 0..<h { for column in 0..<w {
                    let a = (sy+row)*p.width+sx+column,b = (y+row)*width+x+column,i = a*3
                    if !p.defined[a],let hole {
                        values[b] = (UInt32(hole[0]) << 16 | UInt32(hole[1]) << 8 | UInt32(hole[2])).littleEndian
                        known[b] = 1;continue
                    }
                    values[b] = (UInt32(p.rgb[i]) << 16 | UInt32(p.rgb[i+1]) << 8 | UInt32(p.rgb[i+2])).littleEndian
                    known[b] = p.defined[a] ? 1 : 0
                } }
            }
            owners = [dc,memory,s,memory.selected];response = .init(result:1)
        case "releaseDC":
            let s = try bitmapSurface(q.words[0]),dc = try resource(q.words[1],as:SurfaceDC.self)
            s.activeBitmapDC = nil;release(dc);owners = [s,dc];response = .init()
        case "deleteDC":
            let dc = try resource(q.words[0],as:MemoryDC.self);release(dc.stock);release(dc)
            owners = [dc,dc.stock,dc.selected];response = .init(result:1)
        case "deleteObject":
            let b = try resource(q.words[0],as:Bitmap.self)
            let selected = live.values.compactMap { $0 as? MemoryDC }.contains { $0.selected === b }
            if !selected { release(b) };owners = [b];response = .init(result:selected ? 0 : 1)
        case "colorKey":
            let s = try bitmapSurface(q.words[0]),r = try OriginalStateRecord(bytes:q.strings[0],defined:Array(repeating:true,count:8))
            s.sourceColorKey = try [r.integer(at:0,as:UInt32.self),r.integer(at:4,as:UInt32.self)]
            owners = [s];response = .init()
        case "release":
            let r = try resource(q.words[0],as:Resource.self);release(r);owners = [r];response = .init(result:Int32(bitPattern:r.references))
        default:throw Boundary.unsupported(q.kind)
        }
        bitmapOperationCount += 1; if keepsOperationLogs { bitmapOperations.append(.init(request:q,response:response)) }
        return .init(response:response,resources:owners)
    }
}

// Appended to the existing display owner so front and bitmap work share storage.
// Native XRGB policy; original Windows raster and font observations remain open.
extension OriginalMacDisplayBackend {
    public struct FrontOperation: Equatable {
        public let request: OriginalFrontScreenEvent, response: OriginalLibSurfaceText.Response
    }
    public struct FrontServed {
        public let response: OriginalLibSurfaceText.Response
        public let resources: [any OriginalApplicationStartupResource]
    }
    public struct FrontPrepared {
        fileprivate let request: OriginalFrontScreenEvent, identity: Identity, once: Once
    }
    private struct FrontRect {
        let left: Int, top: Int, right: Int, bottom: Int
        var width: Int { right-left };var height: Int { bottom-top }
        func contains(_ x: Int,_ y: Int) -> Bool { x >= left && x < right && y >= top && y < bottom }
        func intersection(_ other: FrontRect) -> FrontRect? {
            let l = max(left,other.left),t = max(top,other.top),r = min(right,other.right),b = min(bottom,other.bottom)
            return l < r && t < b ? .init(left:l,top:t,right:r,bottom:b) : nil
        }
    }
    private struct FrontTarget {
        let surface: Surface, region: FrontRect?
        let delivery: (Int,Int,Int,Int,UInt32?)
    }
    private struct FrontCopy {
        let target: FrontTarget, source: Surface, sourceRect: FrontRect, destination: FrontRect
        let mirrored: Bool, key: [UInt32]?
        func sourceIndex(_ x: Int,_ y: Int) -> Int {
            let column = mirrored ? sourceRect.right-1-(x-destination.left) : sourceRect.left+x-destination.left
            return (sourceRect.top+y-destination.top)*source.width+column
        }
    }
    private enum FrontAction {
        case fill(FrontTarget,UInt32), copy(FrontCopy), release(Surface), text(TextStep), flip(Surface)
        /// DirectDraw Blt with a rectangle outside its surface (or empty):
        /// DDERR_INVALIDRECT, no pixels change.
        case rejected([Surface])
    }
    public static let invalidRect = Int32(bitPattern:0x88760096)
    private enum TextStep { case acquire(Surface), mode(Bool), background(UInt32), color(UInt32), out(Int,Int,[UInt8]), release }
    /// The declared HDC of a surface's text DC (an opaque handle to the Core).
    public static let textDCHandle: UInt32 = 0x0d0c0001
    /// GDI's default SYSTEM_FONT cell at 96 DPI: 16 px high, ascent 13,
    /// internal leading 3, so a 13 px em with the baseline 13 px below the top.
    public nonisolated static let textCell = 16, textAscent = 13
    /// One TextOutA's glyph pixels (no smoothing): `bits[row*width+column]` is
    /// set for the cell pixel (column−originX, row−originY); `advance` is the
    /// text extent's width.
    public struct TextMask: Equatable {
        public let advance: Int, originX: Int, originY: Int, width: Int, height: Int, bits: [UInt8]
        public init(advance: Int, originX: Int, originY: Int, width: Int, height: Int, bits: [UInt8]) {
            self.advance = advance; self.originX = originX; self.originY = originY
            self.width = width; self.height = height; self.bits = bits
        }
    }
    /// A COLORREF (0x00BBGGRR) as the native XRGB surface value.
    static func xrgb(_ color: UInt32) -> UInt32 { (color & 0xff) << 16 | (color & 0xff00) | (color >> 16) & 0xff }
    private func heldDC(_ dc: UInt32) throws -> TextDC {
        guard let textDC,dc == Self.textDCHandle else { throw Boundary.owner(dc) }
        return textDC
    }
    /// One TextOutA's pixels: the storage, the glyph mask and the DC's state
    /// when it was drawn (values only, for the render thread).
    private struct TextPlan {
        let data: Storage, mask: TextMask, x: Int, y: Int, opaque: Bool, background: UInt32, color: UInt32
        /// The glyphs' bounding rectangle clipped to the surface (nil: empty).
        var bounds: FrontRect? {
            let left = max(0,x-mask.originX),top = max(0,y-mask.originY)
            let right = min(data.width,x-mask.originX+mask.width),bottom = min(data.height,y-mask.originY+mask.height)
            return left < right && top < bottom ? .init(left:left,top:top,right:right,bottom:bottom) : nil
        }
    }
    /// TextOut glyph masks by string (CORE_REALTIME 4h): every host's provider
    /// is a fixed function of the bytes (one font for the run) and the game
    /// draws the same strings every frame. Bounded; main thread only.
    private func mask(_ bytes: [UInt8]) -> TextMask {
        if let known = textMasks[bytes] { return known }
        let made = textMask(bytes)
        if textMasks.count >= 256 { textMasks.removeAll(keepingCapacity:true) }
        textMasks[bytes] = made
        return made
    }
    private func textPlan(_ bytes: [UInt8],x: Int,y: Int,_ dc: TextDC,_ data: Storage) -> TextPlan {
        .init(data:data,mask:mask(bytes),x:x,y:y,opaque:dc.opaque,background:Self.xrgb(dc.background),color:Self.xrgb(dc.color))
    }
    private nonisolated static func textPixels(_ p: TextPlan) {
        let data = p.data,mask = p.mask,values = data.values,known = data.known
        func set(_ column: Int,_ row: Int,_ value: UInt32) {
            guard column >= 0,row >= 0,column < data.width,row < data.height else { return }
            let i = row*data.width+column;values[i] = value.littleEndian;known[i] = 1
        }
        if p.opaque { for row in 0..<textCell { for column in 0..<mask.advance { set(p.x+column,p.y+row,p.background) } } }
        for row in 0..<mask.height { for column in 0..<mask.width where mask.bits[row*mask.width+column] != 0 {
            set(p.x+column-mask.originX,p.y+row-mask.originY,p.color)
        } }
    }
    private func drawText(_ bytes: [UInt8],x: Int,y: Int,_ dc: TextDC) throws {
        let s = dc.surface
        guard pipelinesFront && presentUnknownAsBlack else {
            // Synchronous: the pixels, then the target check and the present.
            try renderer.flush()
            guard let data = s.storage else { throw Boundary.released(s.token) }
            let plan = textPlan(bytes,x:x,y:y,dc,data)
            Self.textPixels(plan)
            if let r = plan.bounds {
                let target = try frontTarget(s,r)
                if let window = target.delivery.4 { try windows.present(framebuffer(data,target.delivery),in:window) }
            }
            return
        }
        // Pipelined (CORE_REALTIME 1e): the checks and the glyph mask on the
        // main thread, the pixels and the present on the render thread. A check
        // that fails leaves the state the synchronous order leaves: nothing
        // drawn when the surface is released, the pixels drawn when the target
        // or present check fails. frontTarget reads no pixels (rectangle and
        // geometry only), so checking it before the pixels changes nothing.
        guard let data = s.storage else { try renderer.flush(); throw Boundary.released(s.token) }
        let plan = textPlan(bytes,x:x,y:y,dc,data)
        guard let r = plan.bounds else { renderer.submit { Self.textPixels(plan) }; return }
        let target: FrontTarget
        do { target = try frontTarget(s,r) } catch { try renderer.flush(); Self.textPixels(plan); throw error }
        let rect = target.delivery
        if let present = try pipeline(rect,pixels:{ Self.textPixels(plan) }) {
            let pool = framePool
            renderer.submit { Self.textPixels(plan); if let present { present.deliver(try Self.crop(data,rect,black:true,pool:pool)) } }
        } else {
            Self.textPixels(plan)
            if let window = rect.4 { try windows.present(framebuffer(data,rect),in:window) }
        }
    }
    /// Whether a Blt rectangle (nil: whole surface) lies inside the surface with
    /// a positive area; a malformed rectangle stays a boundary.
    private func frontRectInside(_ values: [Int32]?,_ surface: Surface) throws -> Bool {
        guard let values else { return surface.width > 0 && surface.height > 0 }
        guard values.count == 4 else { throw Boundary.geometry }
        return values[0] >= 0 && values[1] >= 0 && values[2] > values[0] && values[3] > values[1] &&
            Int(values[2]) <= surface.width && Int(values[3]) <= surface.height
    }
    private func frontRect(_ values: [Int32]?,_ surface: Surface) throws -> FrontRect {
        let r: FrontRect
        if let values {
            guard values.count == 4 else { throw Boundary.geometry }
            r = .init(left:Int(values[0]),top:Int(values[1]),right:Int(values[2]),bottom:Int(values[3]))
        } else { r = .init(left:0,top:0,right:surface.width,bottom:surface.height) }
        guard r.left >= 0,r.top >= 0,r.width > 0,r.height > 0,
            r.right <= surface.width,r.bottom <= surface.height else { throw Boundary.geometry }
        return r
    }
    private func frontSurface(_ token: UInt32) throws -> Surface {
        let s = try resource(token,as:Surface.self)
        guard s.storage != nil else { throw Boundary.released(token) }
        guard s.activeBitmapDC == nil,textDC?.surface !== s else { throw Boundary.unsupported("surface DC still acquired") }
        return s
    }
    private func frontTarget(_ surface: Surface,_ destination: FrontRect) throws -> FrontTarget {
        let delivery = try rectangle(surface), (x,y,w,h,_) = delivery
        let clip = FrontRect(left:x,top:y,right:x+w,bottom:y+h)
        return .init(surface:surface,region:destination.intersection(clip),delivery:delivery)
    }
    private func frontKnown(_ target: FrontTarget,replacing known: (Int,Int) -> Bool) throws {
        // The scan can only throw unknownPixel, which presentUnknownAsBlack rules
        // out (every host's runtime sets it): it ran over the whole delivered
        // rectangle twice per blit (MOBILE_PERFORMANCE step 1).
        guard target.delivery.4 != nil,!presentUnknownAsBlack else { return }
        let (x,y,w,h,_) = target.delivery,data = target.surface.storage!,mask = data.known
        for row in y..<(y+h) { for column in x..<(x+w) {
            let isKnown = target.region?.contains(column,row) == true ? known(column,row) : mask[row*data.width+column] != 0
            guard isKnown || presentUnknownAsBlack else { throw Boundary.unknownPixel }
        } }
    }
    private func frontCopy(_ destinationToken: UInt32,_ sourceToken: UInt32,
        destination: [Int32]?,source: [Int32]?,flags: UInt32,effects: [UInt8]?) throws -> FrontCopy {
        guard flags & 0x1000000 != 0,flags & ~UInt32(0x1008800) == 0 else { throw Boundary.unsupported("front Blt flags") }
        let target = try frontSurface(destinationToken),src = try frontSurface(sourceToken)
        guard target !== src else { throw Boundary.unsupported("same-surface Blt") }
        // Sprites of the DirectDraw object Alt+Enter released keep their own
        // references and are drawn to the new target (declared, FULL_SCREEN_PLAN 2).
        guard target.draw === src.draw || src.draw.references == 0 else { throw Boundary.arguments("cross-display Blt") }
        guard src.kind != .primary else { throw Boundary.unsupported("primary Blt source") }
        let d = try frontRect(destination,target),s = try frontRect(source,src)
        guard d.width == s.width,d.height == s.height else { throw Boundary.unsupported("front stretching") }
        let mirrored = flags & 0x800 != 0
        if mirrored {
            guard let effects,effects.count == 100 else { throw Boundary.arguments("front mirror effects") }
            let r = try OriginalStateRecord(bytes:effects,defined:Array(repeating:true,count:100))
            guard try r.integer(at:0,as:UInt32.self) == 100,try r.integer(at:4,as:UInt32.self) == 2 else { throw Boundary.unsupported("front mirror effect") }
        } else { guard effects == nil else { throw Boundary.arguments("unused front effects") } }
        let key: [UInt32]?
        if flags & 0x8000 != 0 {
            guard let values = src.sourceColorKey,values.count == 2,values[0] <= values[1],values[1] <= 0xffffff else { throw Boundary.unsupported("native XRGB source key") }
            key = values
        } else { key = nil }
        let copy = FrontCopy(target:try frontTarget(target,d),source:src,sourceRect:s,destination:d,mirrored:mirrored,key:key)
        let input = src.storage!,output = target.storage!
        try frontKnown(copy.target) { x,y in
            let i = copy.sourceIndex(x,y),inputKnown = input.known
            guard inputKnown[i] != 0 else { return false }
            let value = UInt32(littleEndian:input.values[i]) & 0xffffff
            if let key, value >= key[0] && value <= key[1] { return output.known[y*output.width+x] != 0 }
            return true
        }
        return copy
    }
    private func validateFront(_ q: OriginalFrontScreenEvent) throws -> FrontAction {
        guard q.read == nil,q.clip == nil else { throw Boundary.arguments("front internal observation") }
        switch q.kind {
        case "fill":
            guard q.arguments.isEmpty,q.strings.isEmpty,q.blit == nil,let f = q.fill,
                f.flags == 0x1000400,f.effects.count == 100,f.defined.count == 100 else { throw Boundary.arguments("front fill") }
            let r = try OriginalStateRecord(bytes:f.effects,defined:f.defined)
            guard try r.integer(at:0,as:UInt32.self) == 100 else { throw Boundary.arguments("front fill size") }
            let color = try r.integer(at:80,as:UInt32.self),s = try frontSurface(f.target)
            if try s.kind != .primary && !frontRectInside(f.rectangle,s) { return .rejected([s]) }
            let target = try frontTarget(s,frontRect(f.rectangle,s))
            try frontKnown(target) { _,_ in true };return .fill(target,color)
        case "blit":
            guard q.arguments.isEmpty,q.strings.isEmpty,q.fill == nil,let b = q.blit else { throw Boundary.arguments("front bitmap Blt") }
            guard b.flags & 0x1000000 != 0,b.flags & ~UInt32(0x1008800) == 0 else { throw Boundary.unsupported("front Blt flags") }
            let target = try frontSurface(b.targetSurface),src = try frontSurface(b.sourceSurface)
            if try target.kind != .primary && src.kind != .primary && (!frontRectInside(b.destination,target) || !frontRectInside(b.source,src)) {
                return .rejected([target,src])
            }
            return .copy(try frontCopy(b.targetSurface,b.sourceSurface,destination:b.destination,source:b.source,flags:b.flags,effects:b.effects))
        case "method":
            guard q.arguments.count >= 2,q.fill == nil,q.blit == nil else { throw Boundary.arguments("front method") }
            let a = q.arguments
            if a[1] == 8 {
                guard a.count == 2,q.strings.isEmpty else { throw Boundary.arguments("front Release") }
                try validate(.init("release",[a[0]]));return .release(try frontSurface(a[0]))
            }
            if a[1] == 0x2c {
                // IDirectDrawSurface::Flip(NULL, flags) on a flipping primary (present mode 2).
                guard a.count == 4,a[2] == 0,q.strings.isEmpty else { throw Boundary.arguments("front Flip") }
                let primary = try frontSurface(a[0])
                guard !primary.chain.isEmpty,primary.draw.window != nil else { throw Boundary.unsupported("Flip without a flip chain") }
                return .flip(primary)
            }
            guard a[1] == 0x14 else { throw Boundary.unsupported("front surface method") }
            guard a.count == 7,a[6] == 0 else { throw Boundary.arguments("front presentation") }
            var strings = q.strings.makeIterator()
            func rect(_ pointer: UInt32) throws -> [Int32]? {
                if pointer == 0 { return nil }
                guard let bytes = strings.next(),bytes.count == 16 else { throw Boundary.arguments("front rectangle payload") }
                let r = try OriginalStateRecord(bytes:bytes,defined:Array(repeating:true,count:16))
                return try (0..<4).map { try r.integer(at:$0*4,as:Int32.self) }
            }
            let destination = try rect(a[2]),source = try rect(a[4])
            guard strings.next() == nil else { throw Boundary.arguments("extra front rectangle") }
            return .copy(try frontCopy(a[0],a[3],destination:destination,source:source,flags:a[5],effects:nil))
        case "getDC":
            guard q.arguments.count == 1,q.strings.isEmpty,q.fill == nil,q.blit == nil else { throw Boundary.arguments("front GetDC") }
            guard textDC == nil else { throw Boundary.unsupported("second surface DC") }
            return .text(.acquire(try frontSurface(q.arguments[0])))
        case "setBackgroundMode","setBackgroundColor","setTextColor":
            guard q.arguments.count == 2,q.strings.isEmpty,q.fill == nil,q.blit == nil else { throw Boundary.arguments("front "+q.kind) }
            _ = try heldDC(q.arguments[0])
            let value = q.arguments[1]
            if q.kind == "setBackgroundMode" {
                guard value == 1 || value == 2 else { throw Boundary.unsupported("background mode \(value)") }
                return .text(.mode(value == 2))
            }
            guard value <= 0xffffff else { throw Boundary.unsupported("COLORREF \(value)") }
            return .text(q.kind == "setTextColor" ? .color(value) : .background(value))
        case "textOut":
            guard q.arguments.count == 4,q.strings.count == 1,q.fill == nil,q.blit == nil,
                  q.strings[0].count == Int(q.arguments[3]) else { throw Boundary.arguments("front TextOut") }
            _ = try heldDC(q.arguments[0])
            // Until the strings are surveyed for a code page, only ASCII is drawn.
            guard q.strings[0].allSatisfy({ $0 >= 0x20 && $0 < 0x7f }) else { throw Boundary.unsupported("non-ASCII TextOut") }
            return .text(.out(Int(Int32(bitPattern:q.arguments[1])),Int(Int32(bitPattern:q.arguments[2])),q.strings[0]))
        case "releaseDC":
            guard q.arguments.count == 2,q.strings.isEmpty,q.fill == nil,q.blit == nil else { throw Boundary.arguments("front ReleaseDC") }
            guard try heldDC(q.arguments[1]).surface.token == q.arguments[0] else { throw Boundary.owner(q.arguments[0]) }
            return .text(.release)
        default:throw Boundary.unsupported("front "+q.kind)
        }
    }
    public func prepareFront(_ q: OriginalFrontScreenEvent) throws -> FrontPrepared {
        _ = try validateFront(q);return .init(request:q,identity:identity,once:Once())
    }
    /// Whether a front draw is pipelined: nil runs it synchronously (after the
    /// queued work); otherwise its present delivery (nil without a window). A
    /// failed present check applies the pixels first, as the synchronous order
    /// did, then throws.
    private func pipeline(_ rect: (Int,Int,Int,Int,UInt32?),pixels: () -> Void) throws -> OriginalPresentDelivery?? {
        guard pipelinesFront && presentUnknownAsBlack else { try renderer.flush(); return nil }
        do {
            guard let present = try pipelinedPresent(rect) else { try renderer.flush(); return nil }
            return .some(present)
        } catch { try renderer.flush(); pixels(); throw error }
    }
    private nonisolated static func fillPixels(_ data: Storage,_ region: FrontRect?,_ color: UInt32) {
        guard let rect = region else { return }
        fillRows(data,rect.top..<rect.bottom,rect.left,rect.right,color)
    }
    /// One colour over columns left..<right of each row: a row store and whole
    /// mask words instead of a store and a bit per pixel (CORE_REALTIME 1d).
    /// The same pixels and bits; the column range is formed per row, as the
    /// per-pixel loops did.
    private nonisolated static func fillRows(_ data: Storage,_ rows: Range<Int>,_ left: Int,_ right: Int,_ color: UInt32) {
        let values = data.values,known = data.known,value = color.littleEndian
        for row in rows {
            let columns = left..<right
            guard !columns.isEmpty else { continue }
            let start = row*data.width+left
            values.advanced(by:start).update(repeating:value,count:columns.count)
            known.setRange(start,columns.count)
        }
        // A fill of the whole storage made every pixel known (1g).
        if rows == 0..<data.height && left == 0 && right == data.width { known.markFull() }
    }
    /// What a copy's pixel loop needs, without the surfaces (the render thread
    /// holds only storages and values).
    private struct CopyPlan {
        let region: FrontRect?, sourceRect: FrontRect, destination: FrontRect, mirrored: Bool, key: [UInt32]?, sourceWidth: Int
        init(_ copy: FrontCopy) {
            region = copy.target.region; sourceRect = copy.sourceRect; destination = copy.destination
            mirrored = copy.mirrored; key = copy.key; sourceWidth = copy.source.width
        }
        func sourceIndex(_ x: Int,_ y: Int) -> Int {
            let column = mirrored ? sourceRect.right-1-(x-destination.left) : sourceRect.left+x-destination.left
            return (sourceRect.top+y-destination.top)*sourceWidth+column
        }
    }
    private nonisolated static func copyPixels(_ copy: CopyPlan,_ input: Storage,_ output: Storage) {
        if let rect = copy.region {
            let inputValues = input.values,inputKnown = input.known,outputValues = output.values,outputKnown = output.known
            // Row by row: the source index steps by one pixel (back for a
            // mirrored copy), the key bounds are read once, a fully known
            // source span skips the per-pixel test, and the target's known
            // bits are gathered per 64-bit word and written once
            // (MOBILE_PERFORMANCE steps 4-5). Same pixels and bits; the
            // loop never reads the target's mask.
            let keyed = copy.key != nil,low = copy.key?[0] ?? 0,high = copy.key?[1] ?? 0,step = copy.mirrored ? -1 : 1
            let width = rect.right-rect.left
            for y in rect.top..<rect.bottom {
                var a = copy.sourceIndex(rect.left,y),b = y*output.width+rect.left
                let sourceKnown = inputKnown.allKnown(step > 0 ? a : a-(width-1),width)
                if sourceKnown && !keyed && step > 0 {
                    // Every pixel is known and written as is: one row copy and
                    // whole mask words. Two thirds of a match's copied pixels
                    // take this path (whole-screen copies; MOBILE_PERFORMANCE step 7).
                    outputValues.advanced(by:b).update(from:inputValues.advanced(by:a),count:width)
                    outputKnown.setRange(b,width)
                    continue
                }
                if sourceKnown && outputKnown.isFull {
                    // Every source pixel is known and every target bit is
                    // already set: the bits this row would gather are set and
                    // none is cleared, so only the pixels change. The key test
                    // and the store alone (the live app's targets are always
                    // full; on the A12 40% less time per keyed sprite pixel;
                    // CORE_REALTIME 1j).
                    if keyed {
                        for _ in 0..<width {
                            let pixel = inputValues[a],value = UInt32(littleEndian:pixel) & 0xffffff
                            if value < low || value > high { outputValues[b] = pixel }
                            a += step;b += 1
                        }
                    } else {
                        for _ in 0..<width { outputValues[b] = inputValues[a];a += step;b += 1 }
                    }
                    continue
                }
                var word = b >> 6,set: UInt64 = 0,clear: UInt64 = 0
                for _ in 0..<width {
                    if b >> 6 != word { outputKnown.merge(word,set:set,clear:clear);word = b >> 6;set = 0;clear = 0 }
                    let bit = UInt64(1) << UInt64(b & 63)
                    if !sourceKnown && inputKnown[a] == 0 { clear |= bit } else {
                        let pixel = inputValues[a],value = UInt32(littleEndian:pixel) & 0xffffff
                        if !keyed || value < low || value > high { outputValues[b] = pixel;set |= bit }
                    }
                    a += step;b += 1
                }
                outputKnown.merge(word,set:set,clear:clear)
            }
            // An unkeyed copy of fully known pixels over the whole output made
            // every pixel known (1g).
            if copy.key == nil && inputKnown.isFull && rect.left == 0 && rect.top == 0
                && rect.right == output.width && rect.bottom == output.height { outputKnown.markFull() }
        }
    }
    public func performFront(_ prepared: FrontPrepared) throws -> FrontServed {
        guard prepared.identity === identity else { throw Boundary.foreignPreparation }
        guard !prepared.once.used else { throw Boundary.repeatedPreparation }
        let action = try validateFront(prepared.request);prepared.once.used = true
        return try serveFront(action,request:prepared.request)
    }
    /// `performFront(prepareFront(q))` validating once instead of twice:
    /// nothing runs between those two calls, and validation changes no state a
    /// second validation or the perform could observe (its only mutation,
    /// applying recorded pixel writes, is idempotent), so both give the same
    /// action or the same error (CORE_REALTIME 4g; the committed-batch replay
    /// draws this way).
    public func prepareAndPerformFront(_ q: OriginalFrontScreenEvent) throws -> FrontServed {
        try serveFront(validateFront(q),request:q)
    }
    private func serveFront(_ action: FrontAction,request: OriginalFrontScreenEvent) throws -> FrontServed {
        let owners: [any OriginalApplicationStartupResource],response: OriginalLibSurfaceText.Response
        switch action {
        case let .fill(target,color):
            let data = target.surface.storage!,region = target.region,rect = target.delivery
            if let present = try pipeline(rect,pixels:{ Self.fillPixels(data,region,color) }) {
                let pool = framePool
                renderer.submit { Self.fillPixels(data,region,color); if let present { present.deliver(try Self.crop(data,rect,black:true,pool:pool)) } }
            } else {
                Self.fillPixels(data,region,color)
                if let window = rect.4 { try windows.present(framebuffer(data,rect),in:window) }
            }
            owners = [target.surface];response = .init(result:0)
        case .copy(let copy):
            let input = copy.source.storage!,output = copy.target.surface.storage!,rect = copy.target.delivery,plan = CopyPlan(copy)
            if let present = try pipeline(rect,pixels:{ Self.copyPixels(plan,input,output) }) {
                let pool = framePool
                renderer.submit { Self.copyPixels(plan,input,output); if let present { present.deliver(try Self.crop(output,rect,black:true,pool:pool)) } }
            } else {
                Self.copyPixels(plan,input,output)
                if let window = rect.4 { try windows.present(framebuffer(output,rect),in:window) }
            }
            owners = [copy.target.surface,copy.source];response = .init(result:0)
        case .release(let s):
            release(s);owners = [s];response = .init(result:Int32(bitPattern:s.references))
        case .rejected(let surfaces):
            owners = surfaces;response = .init(result:Self.invalidRect)
        case .flip(let primary):
            // The chain's memory rotates: the front shows the first back buffer, each
            // back buffer takes the next one's, the last takes the old front's.
            let surfaces = [primary]+primary.chain,storages = surfaces.map(\.storage)
            for (i,s) in surfaces.enumerated() { s.storage = storages[(i+1)%surfaces.count] }
            let data = primary.storage!,window = primary.draw.window!.token
            let rect: (Int,Int,Int,Int,UInt32?) = (0,0,data.width,data.height,window)
            if let present = try pipeline(rect,pixels:{}) {
                let pool = framePool
                renderer.submit { if let present { present.deliver(try Self.crop(data,rect,black:true,pool:pool)) } }
            } else {
                try windows.present(framebuffer(data,rect),in:window)
            }
            owners = surfaces;response = .init(result:0)
        case .text(let step):
            // Only TextOutA touches pixels (drawText orders it); the DC steps
            // change the DC's state alone.
            switch step {
            case .acquire(let s):
                textDC = TextDC(s);owners = [s];response = .init(result:0,output:Self.textDCHandle)
            case .mode(let opaque):
                let dc = textDC!,previous: Int32 = dc.opaque ? 2 : 1
                dc.opaque = opaque;owners = [dc.surface];response = .init(result:previous)
            case .background(let value):
                let dc = textDC!,previous = dc.background
                dc.background = value;owners = [dc.surface];response = .init(result:Int32(bitPattern:previous))
            case .color(let value):
                let dc = textDC!,previous = dc.color
                dc.color = value;owners = [dc.surface];response = .init(result:Int32(bitPattern:previous))
            case let .out(x,y,bytes):
                let dc = textDC!
                try drawText(bytes,x:x,y:y,dc);owners = [dc.surface];response = .init(result:1)
            case .release:
                let dc = textDC!
                textDC = nil;owners = [dc.surface];response = .init(result:0)
            }
        }
        frontOperationCount += 1; if keepsOperationLogs { frontOperations.append(.init(request:request,response:response)) }
        return .init(response:response,resources:owners)
    }
}
