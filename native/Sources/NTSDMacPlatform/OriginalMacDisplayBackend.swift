import AppKit
import Darwin
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
        var window: OriginalMacWindowBackend.WindowLease?
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
    private final class Storage {
        let width: Int, height: Int, count: Int, byteCount: Int
        let values: UnsafeMutablePointer<UInt32>, known: UnsafeMutablePointer<UInt8>, budget: Budget
        init(_ width: Int,_ height: Int,_ budget: Budget) throws {
            guard width > 0,height > 0,width <= Int.max/height,width*height <= Int.max/5 else { throw Boundary.geometry }
            self.width = width; self.height = height; count = width*height; byteCount = count*5; self.budget = budget
            try budget.reserve(byteCount)
            guard let pixels = calloc(count,4) else { budget.release(byteCount); throw Boundary.allocationFailed }
            guard let mask = calloc(count,1) else { free(pixels); budget.release(byteCount); throw Boundary.allocationFailed }
            values = pixels.assumingMemoryBound(to:UInt32.self); known = mask.assumingMemoryBound(to:UInt8.self)
            // Zero allocation bytes are not an original initialized framebuffer.
        }
        deinit { free(values); free(known); budget.release(byteCount) }
    }
    private final class Surface: Resource {
        let draw: Draw, width: Int, height: Int, screen: CGRect?
        var storage: Storage?, clipper: Clipper?
        var activeBitmapDC: UInt32?, sourceColorKey: [UInt32]?
        init(_ token: UInt32,_ kind: Kind,_ draw: Draw,_ storage: Storage,_ screen: CGRect?) {
            self.draw = draw; self.storage = storage; self.screen = screen
            width = storage.width; height = storage.height; super.init(token,kind)
        }
    }
    private final class Clipper: Resource {
        let draw: Draw
        var window: OriginalMacWindowBackend.WindowLease?
        init(_ token: UInt32,_ draw: Draw) { self.draw = draw; super.init(token,.clipper) }
    }
    private final class WeakResource {
        weak var value: Resource?
        init(_ value: Resource) { self.value = value }
    }
    public let windows: OriginalMacWindowBackend
    private var bitmapModule: Resource?
    public private(set) var bitmapOperations: [BitmapOperation] = []
    public private(set) var frontOperations: [FrontOperation] = []
    private let identity = Identity(), budget: Budget
    private var live: [UInt32:Resource] = [:], history: [UInt32:WeakResource] = [:]
    public private(set) var operations: [Operation] = []
    public private(set) var allocationCount = 0
    public var allocatedBytes: Int { budget.allocated }
    public var retainedResources: [any OriginalApplicationStartupResource] { Array(live.values) }
    /// Declared live-app policies: fresh surfaces start as known black, and
    /// presentation shows still-unknown pixels (e.g. RLE holes) as black. The
    /// defaults keep unwritten pixels unknown, as the comparison tests require.
    public let freshSurfacesKnownBlack: Bool, presentUnknownAsBlack: Bool
    public init(windows: OriginalMacWindowBackend,maximumBytes: Int = 256*1024*1024,freshSurfacesKnownBlack: Bool = false,
                presentUnknownAsBlack: Bool = false) {
        self.windows = windows; budget = Budget(maximumBytes); self.freshSurfacesKnownBlack = freshSurfacesKnownBlack
        self.presentUnknownAsBlack = presentUnknownAsBlack
    }
    private func storage(_ width: Int,_ height: Int) throws -> Storage {
        let value = try Storage(width,height,budget)
        if freshSurfacesKnownBlack { memset(value.known,1,value.count) }
        return value
    }
    public nonisolated static func handles(_ q: Window.Request) -> Bool {
        ["directDrawCreate","cooperativeLevel","createSurface","createClipper","clipperWindow","setClipper","release","pixelFormat","blt"].contains(q.kind)
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
        let value = try lease(token),s = value as? Surface,c = value as? Clipper,d = value as? Draw
        let known: Int
        if let storage = s?.storage {
            known = Array(UnsafeBufferPointer(start:storage.known,count:storage.count)).filter { $0 != 0 }.count
        } else { known = 0 }
        return .init(token:token,kind:value.kind,references:value.references,width:s?.width ?? 0,height:s?.height ?? 0,
            window:c?.window?.token ?? d?.window?.token ?? s?.draw.window?.token,clipper:s?.clipper?.token,knownPixels:known)
    }
    public func pixels(_ token: UInt32) throws -> Pixels {
        let s = try resource(token,as:Surface.self)
        guard let data = s.storage else { throw Boundary.released(token) }
        return .init(width:data.width,height:data.height,
            values:Array(UnsafeBufferPointer(start:data.values,count:data.count)),
            defined:UnsafeBufferPointer(start:data.known,count:data.count).map { $0 != 0 })
    }
    private func record(_ q: Window.Request,_ size: Int) throws -> OriginalStateRecord {
        guard let b = q.bytes,let m = q.defined,b.count == size,m.count == size else { throw Boundary.arguments(q.kind) }
        return try .init(bytes:b,defined:m)
    }
    /// Pure payload/identity validation. Only flagged structure fields are read;
    /// ignored private bytes stay untouched and do not become known zero.
    public func prepare(_ q: Window.Request) throws -> Prepared {
        try validate(q); return .init(request:q,identity:identity,once:Once())
    }
    private func validate(_ q: Window.Request) throws {
        guard Self.handles(q) else { throw Boundary.unsupported(q.kind) }
        func require(_ condition: Bool) throws { if !condition { throw Boundary.arguments(q.kind) } }
        try require(q.strings.isEmpty)
        if !["createSurface","pixelFormat","blt"].contains(q.kind) { try require(q.bytes == nil && q.defined == nil) }
        switch q.kind {
        case "directDrawCreate": try require(q.words == [0,0x457578,0])
        case "cooperativeLevel":
            try require(q.words.count == 3 && q.words[2] == 8)
            _ = try resource(q.words[0],as:Draw.self); _ = try windows.lease(q.words[1])
        case "createSurface":
            try require(q.words.count == 3 && q.words[2] == 0)
            let draw = try resource(q.words[0],as:Draw.self);try require(draw.window != nil)
            let r = try record(q,108),flags = try r.integer(at:4,as:UInt32.self),caps = try r.integer(at:104,as:UInt32.self)
            try require(try r.integer(at:0,as:UInt32.self) == 108)
            if flags == 1 && caps == 0x200 { try require(q.words[1] == 0x455634) }
            else if flags == 7 && caps == 0x40 {
                try require(q.words[1] == 0x455608)
                try require(try r.integer(at:8,as:UInt32.self) > 0 && r.integer(at:12,as:UInt32.self) > 0)
            } else { throw Boundary.unsupported("surface flags/caps") }
        case "createClipper":
            try require(q.words.count == 4 && q.words[1...3] == [0,0x457584,0]); _ = try resource(q.words[0],as:Draw.self)
        case "clipperWindow":
            try require(q.words.count == 3 && q.words[1] == 0)
            _ = try resource(q.words[0],as:Clipper.self); _ = try windows.lease(q.words[2])
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
            }
            live.removeValue(forKey:r.token)
        }
    }
    /// The primary represents this screen's logical desktop, while its clipper
    /// limits writes/delivery to our own window. No desktop pixels are sampled.
    private func rectangle(_ s: Surface) throws -> (Int,Int,Int,Int,UInt32?) {
        if s.kind == .backbuffer || s.kind == .offscreen { return (0,0,s.width,s.height,nil) }
        guard let clipper = s.clipper,let window = clipper.window,let screen = s.screen else { throw Boundary.unsupported("primary without native window clipper") }
        guard clipper.references > 0 else { throw Boundary.released(clipper.token) }
        let geometry = try windows.displayGeometry(window.token)
        guard geometry.screen == screen else { throw Boundary.unsupported("screen changed") }
        let rect = geometry.clientInDesktop,(w,h) = try dimensions(rect.size)
        guard rect.minX >= 0,rect.minY >= 0,rect.minX.rounded(.towardZero) == rect.minX,
              rect.minY.rounded(.towardZero) == rect.minY,rect.maxX <= CGFloat(s.width),rect.maxY <= CGFloat(s.height) else { throw Boundary.geometry }
        return (Int(rect.minX),Int(rect.minY),w,h,window.token)
    }
    private func image(_ data: Storage,_ region: (Int,Int,Int,Int,UInt32?)) throws -> CGImage {
        let (x,y,w,h,_) = region
        var bytes = Data(count:w*h*4)
        try bytes.withUnsafeMutableBytes { destination in
            for row in 0..<h {
                let start = (y+row)*data.width+x
                if UnsafeBufferPointer(start:data.known+start,count:w).allSatisfy({ $0 != 0 }) {
                    destination.baseAddress!.advanced(by:row*w*4).copyMemory(from:data.values+start,byteCount:w*4)
                } else {
                    guard presentUnknownAsBlack else { throw Boundary.unknownPixel }
                    let out = destination.baseAddress!.advanced(by:row*w*4).assumingMemoryBound(to:UInt32.self)
                    for i in 0..<w { out[i] = data.known[start+i] != 0 ? data.values[start+i] : 0 }
                }
            }
        }
        guard let provider = CGDataProvider(data:bytes as CFData),let space = CGColorSpace(name:CGColorSpace.sRGB),
            let result = CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:space,
                bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.noneSkipFirst.rawValue).union(.byteOrder32Little),
                provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent) else { throw Boundary.image }
        return result
    }
    public func image(_ token: UInt32) throws -> CGImage {
        let s = try resource(token,as:Surface.self)
        guard let data = s.storage else { throw Boundary.released(token) }
        return try image(data,rectangle(s))
    }
    public func perform(_ prepared: Prepared) throws -> Served {
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
            let d = try resource(q.words[0],as:Draw.self),w = try windows.lease(q.words[1])
            _ = try windows.displayGeometry(w.token);d.window = w;retained = [d,w];response = .init()
        case "createSurface":
            let d = try resource(q.words[0],as:Draw.self),r = try record(q,108)
            let primary = try r.integer(at:104,as:UInt32.self) == 0x200
            let width: Int,height: Int,screen: CGRect?
            if primary {
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
            let c = try resource(q.words[0],as:Clipper.self),w = try windows.lease(q.words[2])
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
            for row in y..<(y+h) { for column in x..<(x+w) { let i = row*data.width+column;data.values[i] = color.littleEndian;data.known[i] = 1 } }
            if let window { try windows.display(image(data,rect),in:window) }
            retained = [s];response = .init()
        default:throw Boundary.unsupported(q.kind)
        }
        operations.append(.init(request:q,response:response));return .init(response:response,resources:retained)
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
        let r = try lease(token),m = r as? MemoryDC,d = r as? SurfaceDC,s = r as? Surface
        return .init(selected:m?.selected.token,surface:d?.surface.token,activeDC:s?.activeBitmapDC,colorKey:s?.sourceColorKey)
    }
    public nonisolated static func handlesBitmap(_ q: BitmapAPI.Request) -> Bool {
        ["module","image","getObject","createSurface","restore","createDC","selectObject","description",
         "getDC","stretch","releaseDC","deleteDC","deleteObject","colorKey","release"].contains(q.kind)
    }
    public func prepareBitmap(_ q: BitmapAPI.Request,inputs: BitmapInputs) throws -> BitmapPrepared {
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
            let p = memory.selected.input!.pixels,s = dc.surface,data = s.storage!
            let (x,y,w,h) = try bitmapRect(q.words[1],q.words[2],q.words[3],q.words[4],s.width,s.height)
            let sx = Int(q.words[6]),sy = Int(q.words[7])
            for row in 0..<h { for column in 0..<w {
                let a = (sy+row)*p.width+sx+column,b = (y+row)*data.width+x+column,i = a*3
                data.values[b] = (UInt32(p.rgb[i]) << 16 | UInt32(p.rgb[i+1]) << 8 | UInt32(p.rgb[i+2])).littleEndian
                data.known[b] = p.defined[a] ? 1 : 0
            } }
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
        bitmapOperations.append(.init(request:q,response:response));return .init(response:response,resources:owners)
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
        case fill(FrontTarget,UInt32), copy(FrontCopy), release(Surface)
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
        guard s.activeBitmapDC == nil else { throw Boundary.unsupported("surface DC still acquired") }
        return s
    }
    private func frontTarget(_ surface: Surface,_ destination: FrontRect) throws -> FrontTarget {
        let delivery = try rectangle(surface), (x,y,w,h,_) = delivery
        let clip = FrontRect(left:x,top:y,right:x+w,bottom:y+h)
        return .init(surface:surface,region:destination.intersection(clip),delivery:delivery)
    }
    private func frontKnown(_ target: FrontTarget,replacing known: (Int,Int) -> Bool) throws {
        guard target.delivery.4 != nil else { return }
        let (x,y,w,h,_) = target.delivery,data = target.surface.storage!
        for row in y..<(y+h) { for column in x..<(x+w) {
            let isKnown = target.region?.contains(column,row) == true ? known(column,row) : data.known[row*data.width+column] != 0
            guard isKnown || presentUnknownAsBlack else { throw Boundary.unknownPixel }
        } }
    }
    private func frontCopy(_ destinationToken: UInt32,_ sourceToken: UInt32,
        destination: [Int32]?,source: [Int32]?,flags: UInt32,effects: [UInt8]?) throws -> FrontCopy {
        guard flags & 0x1000000 != 0,flags & ~UInt32(0x1008800) == 0 else { throw Boundary.unsupported("front Blt flags") }
        let target = try frontSurface(destinationToken),src = try frontSurface(sourceToken)
        guard target !== src else { throw Boundary.unsupported("same-surface Blt") }
        guard target.draw === src.draw else { throw Boundary.arguments("cross-display Blt") }
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
            let i = copy.sourceIndex(x,y)
            guard input.known[i] != 0 else { return false }
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
            let target = try frontTarget(s,frontRect(f.rectangle,s))
            try frontKnown(target) { _,_ in true };return .fill(target,color)
        case "blit":
            guard q.arguments.isEmpty,q.strings.isEmpty,q.fill == nil,let b = q.blit else { throw Boundary.arguments("front bitmap Blt") }
            return .copy(try frontCopy(b.targetSurface,b.sourceSurface,destination:b.destination,source:b.source,flags:b.flags,effects:b.effects))
        case "method":
            guard q.arguments.count >= 2,q.fill == nil,q.blit == nil else { throw Boundary.arguments("front method") }
            let a = q.arguments
            if a[1] == 8 {
                guard a.count == 2,q.strings.isEmpty else { throw Boundary.arguments("front Release") }
                try validate(.init("release",[a[0]]));return .release(try frontSurface(a[0]))
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
        default:throw Boundary.unsupported("front "+q.kind)
        }
    }
    public func prepareFront(_ q: OriginalFrontScreenEvent) throws -> FrontPrepared {
        _ = try validateFront(q);return .init(request:q,identity:identity,once:Once())
    }
    public func performFront(_ prepared: FrontPrepared) throws -> FrontServed {
        guard prepared.identity === identity else { throw Boundary.foreignPreparation }
        guard !prepared.once.used else { throw Boundary.repeatedPreparation }
        let action = try validateFront(prepared.request);prepared.once.used = true
        let owners: [any OriginalApplicationStartupResource],response: OriginalLibSurfaceText.Response
        switch action {
        case let .fill(target,color):
            let data = target.surface.storage!
            if let rect = target.region {
                for y in rect.top..<rect.bottom { for x in rect.left..<rect.right {
                    let i = y*data.width+x;data.values[i] = color.littleEndian;data.known[i] = 1
                } }
            }
            if let window = target.delivery.4 { try windows.display(image(data,target.delivery),in:window) }
            owners = [target.surface];response = .init(result:0)
        case .copy(let copy):
            let input = copy.source.storage!,output = copy.target.surface.storage!
            if let rect = copy.target.region {
                for y in rect.top..<rect.bottom { for x in rect.left..<rect.right {
                    let a = copy.sourceIndex(x,y),b = y*output.width+x
                    guard input.known[a] != 0 else { output.known[b] = 0;continue }
                    let value = UInt32(littleEndian:input.values[a]) & 0xffffff
                    if let key = copy.key,value >= key[0] && value <= key[1] { continue }
                    output.values[b] = input.values[a];output.known[b] = 1
                } }
            }
            if let window = copy.target.delivery.4 { try windows.display(image(output,copy.target.delivery),in:window) }
            owners = [copy.target.surface,copy.source];response = .init(result:0)
        case .release(let s):
            release(s);owners = [s];response = .init(result:Int32(bitPattern:s.references))
        }
        frontOperations.append(.init(request:prepared.request,response:response))
        return .init(response:response,resources:owners)
    }
}
