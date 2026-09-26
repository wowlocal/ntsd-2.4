
extension OriginalMacWindowBackend {
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
    /// the current owned view/window; preparation never freezes geometry.
    private func performGeometry(_ q: Window.Request) throws -> Window.Response {
        let owner = try lease(q.words[0])
        guard !owner.closed,let view = owner.window.contentView as? ContentView,
              view.bounds.origin == .zero,view.bounds.size == view.frame.size else { throw Boundary.geometry }
        let values: [Int32]
        if q.kind == "clientRect" {
            guard view.bounds.width >= 0,view.bounds.height >= 0 else { throw Boundary.geometry }
            values = [0,0,try Self.geometryInteger(view.bounds.width),try Self.geometryInteger(view.bounds.height)]
        } else {
            guard let screen = owner.window.screen,let bytes = q.bytes,let mask = q.defined else { throw Boundary.geometry }
            let input = try OriginalStateRecord(bytes:bytes,defined:mask)
            let local = NSPoint(x:CGFloat(try input.integer(at:0,as:Int32.self)),y:CGFloat(try input.integer(at:4,as:Int32.self)))
            let physical = owner.window.convertPoint(toScreen:view.convert(local,to:nil))
            values = [try Self.geometryInteger(physical.x-screen.frame.minX),try Self.geometryInteger(screen.frame.maxY-physical.y)]
        }
        let output = values.flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded:UInt32(bitPattern:word) >> ($0*8)) } }
        return .init(result:1,bytes:output)
    }
}
