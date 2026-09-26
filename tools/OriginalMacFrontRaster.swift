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
            guard isKnown else { throw Boundary.unknownPixel }
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
            guard try r.integer(at:0,as:UInt32.self) == 100,r.integer(at:4,as:UInt32.self) == 2 else { throw Boundary.unsupported("front mirror effect") }
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
