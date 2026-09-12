/// Whole43ed10 image/surface loading and4013d0 bitmap copy at declared Win32/COM
/// boundaries. Private stack fields start unknown. API results own their output;
/// numeric errors do not invent missing bytes. Callers buffer external effects.
public enum OriginalBitmapSurfaceLoading {
    public typealias Request = OriginalWindowInitialization.Request
    public struct Write: Codable, Equatable, Sendable {
        public let offset: Int, bytes: [UInt8]
        public init(offset: Int = 0,bytes: [UInt8]) { self.offset = offset;self.bytes = bytes }
    }
    public struct Response: Codable, Equatable, Sendable {
        public let result: Int32, writes: [Write], output: UInt32?
        public init(result: Int32 = 0,writes: [Write] = [],output: UInt32? = nil) {
            self.result = result;self.writes = writes;self.output = output
        }
    }
    public enum Boundary: Error, Equatable {
        case unknownField(String), missingOutput(String)
    }
    static func unknown(_ count: Int) throws -> OriginalStateRecord {
        try .init(bytes:[UInt8](repeating:0,count:count),defined:[Bool](repeating:false,count:count))
    }
    static func apply(_ response: Response,_ storage: inout OriginalStateRecord) throws {
        for w in response.writes {
            guard w.offset >= 0,w.offset+w.bytes.count <= storage.bytes.count else {
                throw OriginalStateError.invalidStorage("Bitmap API output extent")
            }
            for (i,b) in w.bytes.enumerated() { try storage.write(b,at:w.offset+i) }
        }
    }
    static func field(_ record: OriginalStateRecord,_ offset: Int,_ name: String) throws -> UInt32 {
        guard record.defined[offset..<offset+4].allSatisfy({ $0 }) else { throw Boundary.unknownField(name) }
        return try record.integer(at:offset,as:UInt32.self)
    }
    /// Only the copy descriptor's height/width survive the controlled menu's
    /// successive calls at the same frame depth. These bytes come from native
    /// platform responses, never a captured private stack. Current-call request
    /// masks still describe writes since helper entry, independently of lifetime.
    struct CopyScratch {
        var dimensions: OriginalStateRecord
        var acquiredDC: OriginalStateRecord?
        init() throws { dimensions = try unknown(8) }
        mutating func apply(_ response: Response) throws {
            for write in response.writes {
                for (i,byte) in write.bytes.enumerated() where (8..<16).contains(write.offset+i) {
                    try dimensions.write(byte,at:write.offset+i-8)
                }
            }
        }
    }
    /// Loader BITMAP width/height at the same menu-call depth. Before the first
    /// image, these bytes may belong to the native music graph-log string.
    /// Later GetObject writes replace them. No captured stack is accepted.
    struct LoaderScratch {
        var dimensions: OriginalStateRecord
        var descriptorTail: OriginalStateRecord?
        init() throws { dimensions = try unknown(8) }
        mutating func graphLog(_ bytes: [UInt8]) throws {
            for (i,byte) in (bytes+[0]).enumerated() where (4..<12).contains(i) {
                try dimensions.write(byte,at:i-4)
            }
        }
        mutating func apply(_ response: Response) throws {
            for write in response.writes {
                for (i,byte) in write.bytes.enumerated() where (4..<12).contains(write.offset+i) {
                    try dimensions.write(byte,at:write.offset+i-4)
                }
            }
        }
    }
    @discardableResult
    public static func load<Context>(path: [UInt8],device: UInt32,flags: UInt32,
        width: UInt32 = 0,height: UInt32 = 0,pixelFormat: [UInt32]? = nil,
        context: inout Context,
        dimensions: (Int,UInt32,inout Context) throws -> Void = { _,_,_ in },
        perform: (Request,inout Context) throws -> Response) throws -> UInt32 {
        var scratch = try CopyScratch(), loader = try LoaderScratch()
        return try load(path:path,device:device,flags:flags,width:width,height:height,pixelFormat:pixelFormat,
            context:&context,copyScratch:&scratch,loaderScratch:&loader,dimensions:dimensions,perform:perform)
    }
    static func load<Context>(path: [UInt8],device: UInt32,flags: UInt32,
        width: UInt32 = 0,height: UInt32 = 0,pixelFormat: [UInt32]? = nil,
        context: inout Context,copyScratch: inout CopyScratch,loaderScratch: inout LoaderScratch,
        dimensions: (Int,UInt32,inout Context) throws -> Void = { _,_,_ in },
        perform: (Request,inout Context) throws -> Response) throws -> UInt32 {
        guard !path.contains(0),pixelFormat == nil || pixelFormat!.count == 8 else {
            throw OriginalStateError.invalidStorage("Bitmap image name/pixel format")
        }
        var candidate = context, scratch = copyScratch, loader = loaderScratch
        func request(_ q: Request) throws -> Response { try perform(q,&candidate) }
        let module = try request(.init("module",[0]))
        var bitmap = try request(.init("image",[UInt32(bitPattern:module.result),0,width,height,0x2010],strings:[path])).result
        if bitmap == 0 {
            let module = try request(.init("module",[0]))
            bitmap = try request(.init("image",[UInt32(bitPattern:module.result),0,0,0,0x2000],strings:[path])).result
        }
        if bitmap == 0 { context = candidate;return 0 }
        let handle = UInt32(bitPattern:bitmap)
        var object = try unknown(24)
        let description = try request(.init("getObject",[handle,24],structure:object))
        try apply(description,&object) // GetObject's numeric result is ignored.
        try loader.apply(description)
        var surfaceDescription = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:108),defined:[Bool](repeating:true,count:108))
        let w = try field(loader.dimensions,0,"bitmap width")
        try dimensions(0,w,&candidate);try surfaceDescription.write(w,at:12)
        let h = try field(loader.dimensions,4,"bitmap height")
        try dimensions(1,h,&candidate);try surfaceDescription.write(h,at:8)
        try surfaceDescription.write(flags,at:104)
        try surfaceDescription.write(UInt32(108),at:0);try surfaceDescription.write(UInt32(7),at:4)
        if let pixelFormat {
            // Original skips the first pixel-format word: its size remains zero.
            for i in 1..<8 { try surfaceDescription.write(pixelFormat[i],at:72+i*4) }
            try surfaceDescription.write(UInt32(0x1007),at:4)
        }
        loader.descriptorTail = try .init(bytes:Array(surfaceDescription.bytes[72..<80]),
            defined:Array(surfaceDescription.defined[72..<80]))
        let created = try request(.init("createSurface",[device,0],structure:surfaceDescription))
        if created.result != 0 { context = candidate;loaderScratch = loader;return 0 } // No DeleteObject here.
        guard let surface = created.output else { throw Boundary.missingOutput("created surface") }
        _ = try copy(surface:surface,bitmap:handle,context:&candidate,copyScratch:&scratch,perform:perform)
        _ = try request(.init("deleteObject",[handle]))
        context = candidate;copyScratch = scratch;loaderScratch = loader;return surface
    }
    @discardableResult
    public static func copy<Context>(surface: UInt32,bitmap: UInt32,x: UInt32 = 0,y: UInt32 = 0,
        width: UInt32 = 0,height: UInt32 = 0,context: inout Context,
        perform: (Request,inout Context) throws -> Response) throws -> Int32 {
        var scratch = try CopyScratch()
        return try copy(surface:surface,bitmap:bitmap,x:x,y:y,width:width,height:height,
            context:&context,copyScratch:&scratch,perform:perform)
    }
    static func copy<Context>(surface: UInt32,bitmap: UInt32,x: UInt32 = 0,y: UInt32 = 0,
        width: UInt32 = 0,height: UInt32 = 0,context: inout Context,copyScratch: inout CopyScratch,
        perform: (Request,inout Context) throws -> Response) throws -> Int32 {
        if surface == 0 || bitmap == 0 { return Int32(bitPattern:0x80004005) }
        var candidate = context, scratch = copyScratch
        func request(_ q: Request) throws -> Response { try perform(q,&candidate) }
        _ = try request(.init("restore",[surface]))
        let dc = UInt32(bitPattern:try request(.init("createDC",[0])).result)
        _ = try request(.init("selectObject",[dc,bitmap]))
        var object = try unknown(24)
        try apply(request(.init("getObject",[bitmap,24],structure:object)),&object)
        let w = try width == 0 ? field(object,4,"copy bitmap width") : width
        let h = try height == 0 ? field(object,8,"copy bitmap height") : height
        var description = try unknown(108)
        try description.write(UInt32(108),at:0);try description.write(UInt32(6),at:4)
        let descriptionResult = try request(.init("description",[surface],structure:description))
        try apply(descriptionResult,&description)
        try scratch.apply(descriptionResult)
        let acquired = try request(.init("getDC",[surface]))
        var acquiredStorage = try scratch.acquiredDC ?? unknown(8)
        if let output = acquired.output { try acquiredStorage.write(output,at:0) }
        try acquiredStorage.write(acquired.result,at:4)
        scratch.acquiredDC = acquiredStorage
        if acquired.result == 0 {
            guard let targetDC = acquired.output else { throw Boundary.missingOutput("surface DC") }
            let dw = try field(scratch.dimensions,4,"surface width"),dh = try field(scratch.dimensions,0,"surface height")
            _ = try request(.init("stretch",[targetDC,0,0,dw,dh,dc,x,y,w,h,0xcc0020]))
            _ = try request(.init("releaseDC",[surface,targetDC]))
        }
        _ = try request(.init("deleteDC",[dc]))
        context = candidate;copyScratch = scratch;return acquired.result
    }
}

extension OriginalBitmapConstructor {
    /// Whole43ee50 using the actual recovered image/copy rules. In particular,
    /// dimensions written before a failed CreateSurface survive a null surface.
    public static func constructWithSurfaceLoading<Context>(path: String,optional: Bool,
        backing: [UInt8],device: UInt32,flags: UInt32,context: inout Context,
        perform: (OriginalBitmapSurfaceLoading.Request,inout Context) throws -> OriginalBitmapSurfaceLoading.Response) throws -> OriginalLoadedBitmap {
        var scratch = try OriginalBitmapSurfaceLoading.CopyScratch(), loader = try OriginalBitmapSurfaceLoading.LoaderScratch()
        return try constructWithSurfaceLoading(path:path,optional:optional,backing:backing,device:device,flags:flags,
            context:&context,copyScratch:&scratch,loaderScratch:&loader,perform:perform)
    }
    static func constructWithSurfaceLoading<Context>(path: String,optional: Bool,
        backing: [UInt8],device: UInt32,flags: UInt32,context: inout Context,
        copyScratch: inout OriginalBitmapSurfaceLoading.CopyScratch,
        loaderScratch: inout OriginalBitmapSurfaceLoading.LoaderScratch,
        perform: (OriginalBitmapSurfaceLoading.Request,inout Context) throws -> OriginalBitmapSurfaceLoading.Response) throws -> OriginalLoadedBitmap {
        guard backing.count == 0x1f50,!path.utf8.contains(0),path.utf8.count < 200 else {
            throw OriginalStateError.invalidStorage("Bitmap constructor allocation/name boundary")
        }
        var candidate = context, scratch = copyScratch, loader = loaderScratch, record = try OriginalStateRecord(bytes:backing,defined:[Bool](repeating:false,count:backing.count))
        var width: Int32?,height: Int32?
        let surface = try OriginalBitmapSurfaceLoading.load(path:Array(path.utf8),device:device,flags:flags,context:&candidate,copyScratch:&scratch,loaderScratch:&loader,dimensions:{ index,value,_ in
            try record.write(value,at:4+index*4)
            if index == 0 { width = Int32(bitPattern:value) } else { height = Int32(bitPattern:value) }
        },perform:perform)
        try record.write(UInt32(surface == 0 ? 0 : 1),at:0)
        func request(_ q: OriginalBitmapSurfaceLoading.Request) throws -> OriginalBitmapSurfaceLoading.Response { try perform(q,&candidate) }
        if surface == 0 {
            if !optional {
                _ = try request(.init("message",[0,0],strings:[Array("Couldn't create art surface.".utf8),Array(path.utf8)]))
                _ = try request(.init("debug",strings:[Array("Couldn't create art surface.\n".utf8)]))
            }
        } else if try request(.init("colorKey",[surface,8],strings:[[UInt8](repeating:0,count:8)])).result < 0 {
            _ = try request(.init("message",[0,0],strings:[Array("Couldn't set the color key.".utf8),Array("Error".utf8)]))
            _ = try request(.init("debug",strings:[Array("Couldn't set the color key.\n".utf8)]))
            _ = try request(.init("release",[surface]));try record.write(UInt32(0),at:0)
        }
        context = candidate;copyScratch = scratch;loaderScratch = loader
        return .init(input:.init(path:path,present:surface != 0,width:width,height:height),optional:optional,storage:record)
    }
}
