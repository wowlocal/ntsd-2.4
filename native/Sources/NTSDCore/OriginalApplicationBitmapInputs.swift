/// Value-owned provenance at declared bitmap API boundaries. These handle maps
/// are distinct from game wrapper ownership and actual device lifetime. Numeric
/// replies/tokens remain explicit inputs; no saved structure writes are accepted.
public struct OriginalApplicationBitmapInputs: Equatable {
    public typealias API = OriginalBitmapSurfaceLoading
    public enum Boundary: Error, Equatable { case unsupportedSelection }
    public struct Image: Equatable {
        public let bitmap: OriginalApplicationStartupInputs.Bitmap
        public private(set) var deleted = false
        mutating func delete(_ result: Int32) { if result != 0 { deleted = true } }
    }
    public struct Surface: Equatable {
        public let descriptor: OriginalStateRecord
        public fileprivate(set) var releaseResults: [Int32] = []
        public fileprivate(set) var sourceColors: OriginalSurfaceSourceColors
        public fileprivate(set) var copies: [Copy] = []
    }
    public struct Copy: Equatable {
        public let words: [UInt32],result: Int32,sourceImage: UInt32
        public let memoryGeneration: Int,surfaceGeneration: Int
    }
    public struct Selection: Equatable {
        public let image: UInt32,result: Int32
    }
    public struct MemoryDC: Equatable {
        public let token: UInt32
        public fileprivate(set) var selectedImage: UInt32?
        public fileprivate(set) var selections: [Selection] = []
        public fileprivate(set) var deleteResults: [Int32] = []
    }
    public struct SurfaceDC: Equatable {
        public let token: UInt32,surface: UInt32,acquireResult: Int32
        public fileprivate(set) var releaseResults: [Int32] = []
    }
    public private(set) var images: [UInt32:Image] = [:]
    public private(set) var surfaces: [UInt32:Surface] = [:]
    /// Array positions identify generations; token reuse never revives a retired
    /// generation. These associations describe our logical API boundary only.
    public private(set) var memoryDCs: [MemoryDC] = []
    public private(set) var surfaceDCs: [SurfaceDC] = []
    public private(set) var activeMemoryDCs: [UInt32:Int] = [:]
    public private(set) var activeSurfaceDCs: [UInt32:Int] = [:]
    private let resources: [String:OriginalApplicationStartupInputs.Bitmap]
    private let maximumSurfacePixels: Int
    public init(resources: [String:OriginalApplicationStartupInputs.Bitmap],maximumSurfacePixels: Int = 16_777_216) {
        self.resources = resources;self.maximumSurfacePixels = maximumSurfacePixels
    }

    public func pixels(forImage handle: UInt32) throws -> OriginalDIBPixels {
        guard let image = images[handle],!image.deleted else {
            throw OriginalStateError.invalidStorage("Bitmap input live image pixels")
        }
        return image.bitmap.pixels
    }

    public func sourceColors(forSurface handle: UInt32) throws -> OriginalSurfaceSourceColors {
        guard let surface = surfaces[handle] else { throw OriginalStateError.invalidStorage("Bitmap input surface colors") }
        return surface.sourceColors
    }

    public mutating func response(_ q: API.Request,control: API.Response) throws -> API.Response {
        var next = self
        let result = try next.perform(q,control:control)
        self = next;return result
    }
    private mutating func perform(_ q: API.Request,control: API.Response) throws -> API.Response {
        func invalid(_ name: String) -> OriginalStateError { .invalidStorage("Bitmap input "+name) }
        guard control.writes.isEmpty else { throw invalid("captured structure writes") }
        switch q.kind {
        case "image":
            guard q.words.count == 5,q.strings.count == 1 else { throw invalid("image request") }
            if control.result != 0 {
                let name = String(decoding:q.strings[0],as:UTF8.self),handle = UInt32(bitPattern:control.result)
                guard q.words[4] == 0x2000,let bitmap = resources[name],images[handle] == nil else { throw invalid("image binding") }
                images[handle] = .init(bitmap:bitmap)
            }
        case "getObject":
            guard q.words.count == 2,q.words[1] == 24,let image = images[q.words[0]],!image.deleted else { throw invalid("live image") }
            return .init(result:control.result,writes:control.result == 0 ? [] : [.init(bytes:try image.bitmap.objectBytes())],output:control.output)
        case "createSurface":
            if let token = control.output {
                guard control.result >= 0 else { throw invalid("negative CreateSurface with output") }
                // Positive results can supply an out token even though the
                // recovered loader continues only on exact zero HRESULT.
                guard token != 0,surfaces[token] == nil,let bytes = q.bytes,let mask = q.defined,
                      bytes.count == 108,mask.count == 108,mask.allSatisfy({ $0 }) else { throw invalid("surface descriptor") }
                let descriptor = try OriginalStateRecord(bytes:bytes,defined:mask)
                guard try descriptor.integer(at:0,as:UInt32.self) == 108,
                      try descriptor.integer(at:4,as:UInt32.self) & 6 == 6 else { throw invalid("surface dimensions") }
                let colors = try OriginalSurfaceSourceColors(width:Int(descriptor.integer(at:12,as:Int32.self)),
                    height:Int(descriptor.integer(at:8,as:Int32.self)),maximumPixels:maximumSurfacePixels)
                surfaces[token] = .init(descriptor:descriptor,sourceColors:colors)
            }
        case "description":
            guard let token = q.words.first,let surface = surfaces[token] else { throw invalid("surface binding") }
            return .init(result:control.result,writes:control.result < 0 ? [] : [.init(bytes:surface.descriptor.bytes)],output:control.output)
        case "createDC":
            guard q.words == [0] else { throw invalid("memory DC request") }
            if control.result != 0 {
                let token = UInt32(bitPattern:control.result)
                guard activeMemoryDCs[token] == nil,activeSurfaceDCs[token] == nil else { throw invalid("live DC token reuse") }
                activeMemoryDCs[token] = memoryDCs.count;memoryDCs.append(.init(token:token))
            }
        case "selectObject":
            guard q.words.count == 2,let generation = activeMemoryDCs[q.words[0]],
                  let image = images[q.words[1]],!image.deleted else { throw invalid("DC image selection") }
            guard control.result != -1 else { throw Boundary.unsupportedSelection }
            memoryDCs[generation].selections.append(.init(image:q.words[1],result:control.result))
            if control.result != 0 { memoryDCs[generation].selectedImage = q.words[1] }
        case "getDC":
            guard q.words.count == 1,surfaces[q.words[0]] != nil else { throw invalid("DC surface binding") }
            if control.result < 0 {
                guard control.output == nil else { throw invalid("failed GetDC output") }
            } else if let token = control.output {
                guard token != 0,activeMemoryDCs[token] == nil,activeSurfaceDCs[token] == nil else { throw invalid("live DC token reuse") }
                // A positive HRESULT output is retained, but the recovered
                // caller grants a copy path only on exact zero.
                if control.result == 0 { activeSurfaceDCs[token] = surfaceDCs.count }
                surfaceDCs.append(.init(token:token,surface:q.words[0],acquireResult:control.result))
            } else if control.result == 0 { throw invalid("successful GetDC output") }
        case "stretch":
            guard q.words.count == 11,q.words[10] == 0x00cc0020,q.words[3] == q.words[8],q.words[4] == q.words[9],
                  let target = activeSurfaceDCs[q.words[0]],let source = activeMemoryDCs[q.words[5]],
                  let image = memoryDCs[source].selectedImage else { throw invalid("one-to-one copy ownership") }
            let pixels = try pixels(forImage:image),token = surfaceDCs[target].surface
            guard var surface = surfaces[token] else { throw invalid("copy surface") }
            let x = Int(Int32(bitPattern:q.words[1])),y = Int(Int32(bitPattern:q.words[2]))
            let width = Int(Int32(bitPattern:q.words[3])),height = Int(Int32(bitPattern:q.words[4]))
            let sx = Int(Int32(bitPattern:q.words[6])),sy = Int(Int32(bitPattern:q.words[7]))
            // Validate both rectangles even on a failed BOOL response, before
            // publishing any owner or history changes.
            try surface.sourceColors.copy(pixels,sourceX:sx,sourceY:sy,width:width,height:height,x:x,y:y)
            if control.result == 0 { try surface.sourceColors.invalidate(x:x,y:y,width:width,height:height) }
            surface.copies.append(.init(words:q.words,result:control.result,sourceImage:image,memoryGeneration:source,surfaceGeneration:target))
            surfaces[token] = surface
        case "releaseDC":
            guard q.words.count == 2,let generation = activeSurfaceDCs[q.words[1]],
                  surfaceDCs[generation].surface == q.words[0] else { throw invalid("surface DC release") }
            surfaceDCs[generation].releaseResults.append(control.result)
            if control.result == 0 { activeSurfaceDCs.removeValue(forKey:q.words[1]) }
        case "deleteDC":
            guard q.words.count == 1,let generation = activeMemoryDCs[q.words[0]] else { throw invalid("memory DC deletion") }
            memoryDCs[generation].deleteResults.append(control.result)
            if control.result != 0 { activeMemoryDCs.removeValue(forKey:q.words[0]) }
        case "deleteObject":
            guard let token = q.words.first,var image = images[token],!image.deleted else { throw invalid("image deletion") }
            image.delete(control.result);images[token] = image
        case "release":
            guard let token = q.words.first,var surface = surfaces[token] else { throw invalid("surface release") }
            surface.releaseResults.append(control.result);surfaces[token] = surface
        default:break
        }
        return control
    }
}
