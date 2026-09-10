/// Whole43e8e0..43e934 with actual401250 semantics. The query uses455634;
/// clearing rereads455608 after the query callback. The query result and
/// OutputDebugStringA result are ignored. Platform effects must be buffered
/// until the encompassing operation commits; Context must have value semantics.
public enum OriginalApplicationArtSetup {
    public struct Write: Codable, Equatable, Sendable {
        public let offset: Int, bytes: [UInt8]
        public init(offset: Int, bytes: [UInt8]) { self.offset = offset; self.bytes = bytes }
    }
    public struct Query: Equatable, Sendable {
        public let target: UInt32, bytes: [UInt8], defined: [Bool]
    }
    public struct Response: Equatable, Sendable {
        public let result: Int32, writes: [Write]
        public init(result: Int32, writes: [Write] = []) { self.result = result; self.writes = writes }
    }
    public struct Result: Equatable, Sendable {
        public let value: Int32, query: OriginalStateRecord
    }
    /// Local backing is an explicit caller boundary. This function never reads
    /// the query's retained/output fields, and does not infer their provenance.
    public static func run<Context>(context: inout Context, queryBacking: OriginalStateRecord,
        clearBacking: [UInt8], querySurface: (Context) throws -> UInt32,
        clearSurface: (Context) throws -> UInt32,
        query: (Query, inout Context) throws -> Response,
        clear: (OriginalSurfaceClearRequest, inout Context) throws -> Int32,
        debug: ([UInt8], inout Context) throws -> Void,
        beforeCommit: (Result, Context) throws -> Void = { _, _ in }) throws -> Result {
        guard queryBacking.bytes.count == 32 else {
            throw OriginalStateError.invalidStorage("Art setup query extent")
        }
        var staged = context, local = queryBacking
        try local.write(UInt32(32), at: 0)
        let target = try querySurface(staged)
        guard target != 0 else { throw OriginalStateError.invalidStorage("Null art setup query surface") }
        let response = try query(.init(target: target, bytes: local.bytes, defined: local.defined), &staged)
        for w in response.writes {
            guard w.offset >= 0, w.offset <= 32 - w.bytes.count else {
                throw OriginalStateError.invalidStorage("Art setup query output extent")
            }
            for (i,b) in w.bytes.enumerated() { try local.write(b, at: w.offset + i) }
        }
        let hresult = try OriginalSurfaceClearing.clear(target: clearSurface(staged), color: 0, backing: clearBacking) {
            try clear($0, &staged)
        }
        let text = hresult < 0 ? "UpdateFrame: Couldn't fill back buffer.\n" : "LoadGameArt: Art loaded.\n"
        try debug(Array(text.utf8), &staged)
        let result = Result(value: hresult < 0 ? 0 : 1, query: local)
        try beforeCommit(result, staged)
        context = staged
        return result
    }
}
