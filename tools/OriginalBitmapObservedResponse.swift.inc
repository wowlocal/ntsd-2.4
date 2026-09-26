
extension OriginalApplicationBitmapInputs {
    /// Record an actually served Native response without replacing its writes
    /// with the declared-input projection. Only our finite owned metadata fields
    /// are supported; private BITMAP pointers/type and descriptor tails stay unknown.
    public mutating func observed(_ q: API.Request,response: API.Response) throws -> API.Response {
        var next = self
        let allowed: Range<Int>,bytes: [UInt8]
        switch q.kind {
        case "getObject":
            guard q.words.count == 2,let image = images[q.words[0]],!image.deleted else {
                throw OriginalStateError.invalidStorage("Observed bitmap image owner")
            }
            allowed = 4..<20;bytes = try image.bitmap.objectBytes()
        case "description":
            guard q.words.count == 1,let surface = surfaces[q.words[0]] else {
                throw OriginalStateError.invalidStorage("Observed bitmap surface owner")
            }
            allowed = 8..<16;bytes = surface.descriptor.bytes
        default:allowed = 0..<0;bytes = []
        }
        for write in response.writes {
            guard write.offset >= allowed.lowerBound,write.offset <= allowed.upperBound,
                  write.bytes.count <= allowed.upperBound-write.offset else {
                throw OriginalStateError.invalidStorage("Observed bitmap output extent")
            }
            guard Array(bytes[write.offset..<write.offset+write.bytes.count]) == write.bytes else {
                throw OriginalStateError.invalidStorage("Observed bitmap output conflicts with owner")
            }
        }
        // Existing numeric/ownership semantics still validate/update all owners.
        // Its generated structure bytes are deliberately not returned to Core.
        _ = try next.perform(q,control:.init(result:response.result,output:response.output))
        self = next;return response
    }
}
