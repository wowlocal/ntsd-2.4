/// Value-owned provenance at declared bitmap API boundaries. These handle maps
/// are distinct from game wrapper ownership and actual device lifetime. Numeric
/// replies/tokens remain explicit inputs; no saved structure writes are accepted.
public struct OriginalApplicationBitmapInputs: Equatable {
    public typealias API = OriginalBitmapSurfaceLoading
    public struct Image: Equatable {
        public let bitmap: OriginalApplicationStartupInputs.Bitmap
        public private(set) var deleted = false
        mutating func delete(_ result: Int32) { if result != 0 { deleted = true } }
    }
    public struct Surface: Equatable {
        public let descriptor: OriginalStateRecord
        public fileprivate(set) var releaseResults: [Int32] = []
    }
    public private(set) var images: [UInt32:Image] = [:]
    public private(set) var surfaces: [UInt32:Surface] = [:]
    private let resources: [String:OriginalApplicationStartupInputs.Bitmap]
    public init(resources: [String:OriginalApplicationStartupInputs.Bitmap]) { self.resources = resources }

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
                surfaces[token] = .init(descriptor:try .init(bytes:bytes,defined:mask))
            }
        case "description":
            guard let token = q.words.first,let surface = surfaces[token] else { throw invalid("surface binding") }
            return .init(result:control.result,writes:control.result < 0 ? [] : [.init(bytes:surface.descriptor.bytes)],output:control.output)
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
