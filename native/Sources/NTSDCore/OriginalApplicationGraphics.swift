/// Owned identities and resolved requests at the declared graphics boundary.
/// This is not a rasterizer: source colors, device pixels and HRESULTs are
/// distinct. No recorded reply proves a Windows object was created or destroyed.
public struct OriginalApplicationGraphics: Equatable {
    public typealias Window = OriginalWindowInitialization
    public typealias Bitmap = OriginalBitmapSurfaceLoading
    public enum Boundary: Error, Equatable {
        case request(String), owner(UInt32), dc(UInt32), duplicate(UInt32)
    }
    public struct Reference: Codable, Equatable, Hashable {
        public let kind: String, token: UInt32, generation: Int
        public init(kind: String,token: UInt32,generation: Int) {
            self.kind = kind;self.token = token;self.generation = generation
        }
    }
    public struct Binding: Codable, Equatable {
        public let role: String, ref: Reference?
    }
    public struct OpaqueReference: Codable, Equatable {
        public let role: String, token: UInt32
    }
    public struct Resource: Equatable {
        public let ref: Reference, creation: Window.Request, createResult: Int32
        public fileprivate(set) var releaseResults: [Int32] = []
        /// Last requested metadata and its reply, including failures. These
        /// fields do not assert an effective device association or conversion.
        public fileprivate(set) var colorKey: Window.Request?
        public fileprivate(set) var colorKeyResult: Int32?
        public fileprivate(set) var clipper: Reference?
        public fileprivate(set) var clipperResult: Int32?
        public fileprivate(set) var palette: UInt32?
        public fileprivate(set) var paletteResult: Int32?
        public fileprivate(set) var pixelFormat: Window.Response?
    }
    public struct TextLease: Equatable {
        public let ref: Reference, owner: Reference, acquireResult: Int32
        public fileprivate(set) var releaseResults: [Int32] = []
    }
    /// Immutable resolved view of one terminal operation, not a second effect
    /// to deliver alongside the original operation. Unknown request bytes keep
    /// their masks. NULL rectangles are distinct from four explicit zero words.
    public struct Command: Equatable {
        public let family: String, request: Window.Request?
        public let windowResponse: Window.Response?, bitmapResponse: Bitmap.Response?
        public let event: OriginalFrontScreenEvent?, result: Int32, output: UInt32?
        public let bindings: [Binding], dependencies: [String], opaqueReferences: [OpaqueReference]
        public let sourceRectangle: [Int32]?, destinationRectangle: [Int32]?
        public let sourceColors: OriginalSurfaceSourceColors?
    }
    public static let rasterDependencies = [
        "primary/offscreen actual format", "palette entries/realization",
        "bitmap-to-device conversion", "color key", "font/glyph/codepage/DPI",
        "clipper geometry", "device errors and actual lease validity", "initial pixels",
        "clipping/scaling/Blt/text/presentation raster outcomes"
    ]
    public private(set) var resources: [Reference:Resource] = [:]
    public private(set) var currentResources: [UInt32:Reference] = [:]
    public private(set) var displayModes: [Reference:Window.Request] = [:]
    public private(set) var nextTextGeneration = 0
    /// Successful cleanup removes just its own lease. Older failed generations
    /// remain explicit even if the same numeric token is acquired again.
    public private(set) var textLeases: [Int:TextLease] = [:]
    private var currentTextDCs: [UInt32:Int] = [:]
    private var nextGeneration: [String:Int] = [:]
    public init() {}

    private func resource(_ token: UInt32,_ kinds: [String]? = nil) throws -> Reference {
        guard let r = currentResources[token],kinds == nil || kinds!.contains(r.kind) else { throw Boundary.owner(token) }
        return r
    }
    private func surface(_ token: UInt32) throws -> Reference {
        try resource(token,["primary","backbuffer","bitmapSurface"])
    }
    private mutating func create(_ kind: String,_ token: UInt32,_ q: Window.Request,_ result: Int32) throws -> Reference {
        guard token != 0 else { throw Boundary.owner(token) }
        if let old = currentResources[token],resources[old]?.releaseResults.isEmpty != false {
            throw Boundary.duplicate(token)
        }
        let generation = nextGeneration[kind,default:0]
        guard generation < Int.max else { throw Boundary.request("generation overflow") }
        let r = Reference(kind:kind,token:token,generation:generation)
        nextGeneration[kind] = generation+1;currentResources[token] = r
        resources[r] = .init(ref:r,creation:q,createResult:result)
        return r
    }

    public mutating func window(_ q: Window.Request,_ r: Window.Response) throws -> Command {
        var next = self
        let command = try next.performWindow(q,r)
        self = next;return command
    }
    private mutating func performWindow(_ q: Window.Request,_ r: Window.Response) throws -> Command {
        var bindings: [Binding] = [],opaque: [OpaqueReference] = []
        func word(_ i: Int) throws -> UInt32 {
            guard i < q.words.count else { throw Boundary.request(q.kind) };return q.words[i]
        }
        var createdKind: String?
        switch q.kind {
        case "directDrawCreate":createdKind = "draw"
        case "createSurface":
            bindings.append(.init(role:"owner",ref:try resource(word(0),["draw"])))
            guard let b = q.bytes,let m = q.defined,b.count == 108,m.count == 108 else { throw Boundary.request(q.kind) }
            let descriptor = try OriginalStateRecord(bytes:b,defined:m)
            let flags = try descriptor.integer(at:4,as:UInt32.self)
            guard flags & 1 != 0 else { throw Boundary.request("surface caps provenance") }
            let caps = try descriptor.integer(at:104,as:UInt32.self)
            if caps & 0x200 != 0 { createdKind = "primary" }
            else if caps & 0x40 != 0 { createdKind = "backbuffer" }
            else { throw Boundary.request("display surface caps") }
        case "attachedSurface":
            bindings.append(.init(role:"owner",ref:try resource(word(0),["primary"])))
            createdKind = "backbuffer"
        case "createClipper":
            bindings.append(.init(role:"owner",ref:try resource(word(0),["draw"])));createdKind = "clipper"
        case "cooperativeLevel","displayMode":
            let owner = try resource(word(0),["draw"]);bindings.append(.init(role:"owner",ref:owner))
            if q.kind == "cooperativeLevel" { opaque.append(.init(role:"window",token:try word(1))) }
            else if r.result >= 0 { displayModes[owner] = q }
        case "clipperWindow":
            bindings.append(.init(role:"owner",ref:try resource(word(0),["clipper"])))
            opaque.append(.init(role:"window",token:try word(2)))
        case "setClipper":
            let owner = try surface(word(0)),clipper = try resource(word(1),["clipper"])
            bindings = [.init(role:"owner",ref:owner),.init(role:"source",ref:clipper)]
            resources[owner]?.clipper = clipper;resources[owner]?.clipperResult = r.result
        case "setPalette":
            let owner = try surface(word(0)),palette = try word(1)
            bindings.append(.init(role:"owner",ref:owner));opaque.append(.init(role:"palette",token:palette))
            resources[owner]?.palette = palette;resources[owner]?.paletteResult = r.result
        case "pixelFormat":
            let owner = try surface(word(0));bindings.append(.init(role:"owner",ref:owner))
            resources[owner]?.pixelFormat = r
        case "blt":
            guard q.words.count == 5,q.words[1...3].allSatisfy({ $0 == 0 }),q.words[4] & 0x400 != 0 else { throw Boundary.request("display clear") }
            bindings = [.init(role:"target",ref:try surface(word(0))),.init(role:"source",ref:nil)]
        case "release":
            let owner = try resource(word(0));bindings.append(.init(role:"owner",ref:owner));resources[owner]?.releaseResults.append(r.result)
        case "invalidate":opaque.append(.init(role:"window",token:try word(0)))
        case "metric","icon","cursor","registerClass","createWindow","updateWindow","showWindow","debug",
             "destroyWindow","clientRect","screenPoint","setRect","setCursor","postQuit","windowDefault":break
        default:throw Boundary.request(q.kind)
        }
        if let kind = createdKind,r.result >= 0 {
            guard let token = r.output else { throw Boundary.request("display output") }
            bindings.append(.init(role:"created",ref:try create(kind,token,q,r.result)))
        }
        return .init(family:"window",request:q,windowResponse:r,bitmapResponse:nil,event:nil,result:r.result,output:r.output,
            bindings:bindings,dependencies:[],opaqueReferences:opaque,sourceRectangle:nil,destinationRectangle:nil,sourceColors:nil)
    }

    /// Bitmap inputs already performed this request transactionally. Its own
    /// image/DC generations authorize these bindings; no expected state enters.
    public mutating func bitmap(_ q: Bitmap.Request,_ r: Bitmap.Response,inputs: OriginalApplicationBitmapInputs) throws -> Command {
        var next = self
        let command = try next.performBitmap(q,r,inputs:inputs)
        self = next;return command
    }
    private mutating func performBitmap(_ q: Bitmap.Request,_ r: Bitmap.Response,inputs: OriginalApplicationBitmapInputs) throws -> Command {
        var bindings: [Binding] = []
        func word(_ i: Int) throws -> UInt32 {
            guard i < q.words.count else { throw Boundary.request(q.kind) };return q.words[i]
        }
        func memory(_ token: UInt32) throws -> Reference {
            guard let i = inputs.memoryDCs.lastIndex(where:{ $0.token == token }) else { throw Boundary.dc(token) }
            return .init(kind:"memoryDC",token:token,generation:i)
        }
        func dc(_ token: UInt32) throws -> Reference {
            guard let i = inputs.surfaceDCs.lastIndex(where:{ $0.token == token }) else { throw Boundary.dc(token) }
            return .init(kind:"bitmapDC",token:token,generation:i)
        }
        switch q.kind {
        case "createSurface":
            bindings.append(.init(role:"owner",ref:try resource(word(0),["draw"])))
            if let token = r.output {
                guard inputs.surfaces[token] != nil else { throw Boundary.owner(token) }
                bindings.append(.init(role:"created",ref:try create("bitmapSurface",token,q,r.result)))
            }
        case "image":
            if r.result != 0 {
                let token = UInt32(bitPattern:r.result)
                guard inputs.images[token] != nil else { throw Boundary.owner(token) }
                bindings.append(.init(role:"created",ref:try create("image",token,q,r.result)))
            }
        case "getObject","deleteObject":bindings.append(.init(role:"owner",ref:try resource(word(0),["image"])))
        case "selectObject":
            bindings = [.init(role:"source",ref:try resource(word(1),["image"])),.init(role:"selectedDC",ref:try memory(word(0)))]
        case "createDC":if r.result != 0 { bindings.append(.init(role:"created",ref:try memory(UInt32(bitPattern:r.result)))) }
        case "deleteDC":bindings.append(.init(role:"dc",ref:try memory(word(0))))
        case "stretch":bindings = [.init(role:"target",ref:try dc(word(0))),.init(role:"source",ref:try memory(word(5)))]
        case "restore","description","getDC","releaseDC","colorKey","release":
            let owner = try resource(word(0),["bitmapSurface"]);bindings.append(.init(role:"owner",ref:owner))
            if q.kind == "getDC",let token = r.output,r.result >= 0 { bindings.append(.init(role:"created",ref:try dc(token))) }
            if q.kind == "releaseDC" { bindings.append(.init(role:"dc",ref:try dc(word(1)))) }
            if q.kind == "colorKey" { resources[owner]?.colorKey = q;resources[owner]?.colorKeyResult = r.result }
            if q.kind == "release" { resources[owner]?.releaseResults.append(r.result) }
        case "module","message","debug":break
        default:throw Boundary.request(q.kind)
        }
        return .init(family:"bitmap",request:q,windowResponse:nil,bitmapResponse:r,event:nil,result:r.result,output:r.output,
            bindings:bindings,dependencies:[],opaqueReferences:[],sourceRectangle:nil,destinationRectangle:nil,sourceColors:nil)
    }

    public mutating func front(_ e: OriginalFrontScreenEvent,result: Int32,output: UInt32? = nil,
        inputs: OriginalApplicationBitmapInputs? = nil) throws -> Command {
        var next = self
        let command = try next.performFront(e,result:result,output:output,inputs:inputs)
        self = next;return command
    }
    private mutating func performFront(_ e: OriginalFrontScreenEvent,result: Int32,output: UInt32?,
        inputs: OriginalApplicationBitmapInputs?) throws -> Command {
        var bindings: [Binding] = [],dependencies: [String] = []
        var sourceRect: [Int32]?,destinationRect: [Int32]?,colors: OriginalSurfaceSourceColors?,dcToken: UInt32?
        func arg(_ i: Int) throws -> UInt32 {
            guard i < e.arguments.count else { throw Boundary.request(e.kind) };return e.arguments[i]
        }
        switch e.kind {
        case "blit":
            guard let b = e.blit,b.source.count == 4,b.destination.count == 4 else { throw Boundary.request(e.kind) }
            let source = try b.sourceSurface == 0 ? nil : surface(b.sourceSurface)
            bindings = [.init(role:"target",ref:try surface(b.targetSurface)),.init(role:"source",ref:source)]
            sourceRect = b.source;destinationRect = b.destination
            if let source,source.kind == "bitmapSurface" {
                guard let inputs else { throw Boundary.owner(source.token) }
                colors = try inputs.sourceColors(forSurface:source.token)
            } else if source == nil { dependencies.append("nullSource") }
        case "fill":
            guard let f = e.fill,f.rectangle.count == 4 else { throw Boundary.request(e.kind) }
            bindings.append(.init(role:"target",ref:try surface(f.target)));destinationRect = f.rectangle
        case "getDC":
            let owner = try surface(arg(0));bindings.append(.init(role:"owner",ref:owner))
            // A new text helper starts a new sequence. Its failed GetDC must
            // not authorize GDI through an older unresolved acquisition.
            currentTextDCs.removeAll()
            if result >= 0 {
                guard let token = output,nextTextGeneration < Int.max else { throw Boundary.request("text DC output") }
                let ref = Reference(kind:"textDC",token:token,generation:nextTextGeneration)
                textLeases[nextTextGeneration] = .init(ref:ref,owner:owner,acquireResult:result)
                currentTextDCs[token] = nextTextGeneration;nextTextGeneration += 1
                bindings.append(.init(role:"created",ref:ref));dcToken = token
            }
        case "setBackgroundMode","setTextColor","textOut","releaseDC":
            let token = try arg(e.kind == "releaseDC" ? 1 : 0);dcToken = token
            guard let i = currentTextDCs[token],var lease = textLeases[i] else { throw Boundary.dc(token) }
            if e.kind == "releaseDC" {
                let owner = try surface(arg(0));guard owner == lease.owner else { throw Boundary.owner(owner.token) }
                bindings.append(.init(role:"owner",ref:owner));lease.releaseResults.append(result)
                if result == 0 { textLeases.removeValue(forKey:i);currentTextDCs.removeValue(forKey:token) }
                else { textLeases[i] = lease }
            }
            bindings.append(.init(role:"dc",ref:lease.ref))
        case "method":
            let owner = try surface(arg(0));bindings.append(.init(role:"owner",ref:owner))
            switch try arg(1) {
            case 8:resources[owner]?.releaseResults.append(result)
            case 0x14:
                guard e.arguments.count == 7 else { throw Boundary.request("presentation") }
                bindings += [.init(role:"target",ref:owner),.init(role:"source",ref:try surface(arg(3)))]
                // A NULL destination is allowed as its own supplemental input.
                // Non-NULL pointer data must be present even for an empty rect.
                var strings = e.strings.makeIterator()
                func rectangle(_ pointer: UInt32) throws -> [Int32]? {
                    if pointer == 0 { return nil }
                    guard let bytes = strings.next(),bytes.count == 16 else { throw Boundary.request("presentation rectangle") }
                    return stride(from:0,to:16,by:4).map { i in
                        Int32(bitPattern:(0..<4).reduce(UInt32(0)) { $0 | UInt32(bytes[i+$1]) << ($1*8) })
                    }
                }
                destinationRect = try rectangle(arg(2));sourceRect = try rectangle(arg(4))
                guard strings.next() == nil,try arg(6) == 0 else { throw Boundary.request("presentation effects") }
            case 0x2c:
                guard e.arguments.count == 4 else { throw Boundary.request("flip") }
                bindings.append(.init(role:"target",ref:owner))
            default:throw Boundary.request("surface method")
            }
        default:throw Boundary.request(e.kind)
        }
        if let token = dcToken,textLeases.values.contains(where:{ $0.ref.token == token && $0.releaseResults.contains(where:{ $0 != 0 }) }) {
            dependencies.append("unresolvedTextLease")
        }
        return .init(family:"front",request:nil,windowResponse:nil,bitmapResponse:nil,event:e,result:result,output:output,
            bindings:bindings,dependencies:dependencies,opaqueReferences:[],sourceRectangle:sourceRect,destinationRectangle:destinationRect,sourceColors:colors)
    }

    /// Resolve once at the actual effect boundary. Other terminal effects keep
    /// their place in the enclosing batch but have no graphics command here.
    public mutating func consume(_ effect: OriginalApplicationMenuSession.Effect,
        inputs: OriginalApplicationBitmapInputs?) throws -> Command? {
        switch effect {
        case let .surface(q,r),let .lifecycle(q,r):return try window(q,r)
        case let .bitmap(q,r):
            guard let inputs else { throw Boundary.request("bitmap inputs") };return try bitmap(q,r,inputs:inputs)
        case let .blit(b,r):var e = OriginalFrontScreenEvent("blit");e.blit = b;return try front(e,result:r,inputs:inputs)
        case let .fill(f,r):var e = OriginalFrontScreenEvent("fill");e.fill = f;return try front(e,result:r,inputs:inputs)
        case let .release(e,r),let .present(e,r),let .graphics(e,r),let .startupGraphics(e,r):return try front(e,result:r,inputs:inputs)
        case let .getDC(e,r,output):return try front(e,result:r,output:output,inputs:inputs)
        default:return nil
        }
    }
}
