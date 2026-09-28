/// The bundled lib.dll replaces401290 with10001298..10001309. This native
/// implementation requests transparent background mode1 and retains the DC
/// in the library's semantic state. It executes no DLL or machine-code patch.
public struct OriginalLibSurfaceText: Equatable {
    /// Original lib.dll data+0x6e begins zero and changes only after GetDC
    /// returns nonnegative. Separate from the pristine EXE text implementation.
    public private(set) var retainedDC: UInt32
    public init(retainedDC: UInt32 = 0) { self.retainedDC = retainedDC }

    /// A reply to one platform request. Only GetDC consumes an output value;
    /// nil means no declared output, while .some(0) is an explicit null DC.
    public struct Response: Equatable, Sendable {
        public let result: Int32
        public let output: UInt32?
        public init(result: Int32, output: UInt32? = nil) {
            self.result = result; self.output = output
        }
    }

    /// Retain the prepared-input entry point for existing callers. Later API
    /// results do not affect this helper's return value or semantic DC state.
    @discardableResult
    public mutating func draw(_ bytes: [UInt8], target: UInt32, background: UInt32,
        color: UInt32, x: Int32, y: Int32, dcResult: Int32, dc: UInt32,
        observe: (OriginalMenuPresentationEvent) throws -> Void) throws -> Int32 {
        try draw(bytes, target: target, background: background, color: color, x: x, y: y,
            perform: { q in .init(result: q.kind == .getDC ? dcResult : 0,
                                 output: q.kind == .getDC ? dc : nil) }, observe: observe)
    }

    /// Obtain each reply at its request. Background is an original argument;
    /// the installed replacement uses transparent SetBkMode instead. String
    /// length is derived from these validated bytes, not a platform request.
    /// Numeric GDI/ReleaseDC failures are ignored; return GetDC's HRESULT.
    /// Callbacks must stage effects for the encompassing transaction. Native
    /// rollback here does not reverse physical IO performed by a callback.
    @discardableResult
    public mutating func draw(_ bytes: [UInt8], target: UInt32, background: UInt32,
        color: UInt32, x: Int32, y: Int32,
        perform: (OriginalMenuPresentationEvent) throws -> Response,
        didRespond: (OriginalMenuPresentationEvent, Response) throws -> Void = { _,_ in },
        observe: (OriginalMenuPresentationEvent) throws -> Void) throws -> Int32 {
        guard target != 0 else { throw OriginalStateError.invalidStorage("Null library text surface") }
        guard !bytes.contains(0), bytes.count <= Int(UInt32.max) else {
            throw OriginalStateError.invalidStorage("Library text string extent")
        }
        var next = self
        @discardableResult
        func request(_ q: OriginalMenuPresentationEvent) throws -> Response {
            let r = try perform(q)
            try didRespond(q, r)
            try observe(q)
            return r
        }
        let acquired = try request(.init(.getDC, [target]))
        if acquired.result >= 0 {
            guard let dc = acquired.output else {
                throw OriginalStateError.invalidStorage("Missing successful library GetDC output")
            }
            next.retainedDC = dc
            try request(.init(.setBackgroundMode, [dc, 1]))
            try request(.init(.setTextColor, [dc, color]))
            try observe(.init(.stringLength, [], [bytes]))
            try request(.init(.textOut, [dc, UInt32(bitPattern: x), UInt32(bitPattern: y), UInt32(bytes.count)], [bytes]))
            try request(.init(.releaseDC, [target, dc]))
        }
        self = next
        return acquired.result
    }
}
