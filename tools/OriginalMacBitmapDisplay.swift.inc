
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
            let storage = try Storage(Int(r.integer(at:12,as:UInt32.self)),Int(r.integer(at:8,as:UInt32.self)),budget)
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
