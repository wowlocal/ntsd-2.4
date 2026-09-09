/// The bundled lib.dll replaces401290 with10001298..10001309. This native
/// implementation requests transparent background mode1 and retains the DC
/// in the library's semantic state. It executes no DLL or machine-code patch.
public struct OriginalLibSurfaceText: Equatable {
    /// Original lib.dll data+0x6e begins zero and changes only after GetDC
    /// returns nonnegative. Separate from the pristine EXE text implementation.
    public private(set) var retainedDC: UInt32
    public init(retainedDC: UInt32 = 0) { self.retainedDC = retainedDC }

    /// Platform results remain declared inputs. GDI/ReleaseDC results are
    /// ignored; the helper returns GetDC's HRESULT. Background color is an
    /// original argument but the replacement requests SetBkMode instead.
    /// Buffer observer effects until the encompassing transaction commits.
    @discardableResult
    public mutating func draw(_ bytes: [UInt8], target: UInt32, background: UInt32,
        color: UInt32, x: Int32, y: Int32, dcResult: Int32, dc: UInt32,
        observe: (OriginalMenuPresentationEvent) throws -> Void) throws -> Int32 {
        guard target != 0 else { throw OriginalStateError.invalidStorage("Null library text surface") }
        guard !bytes.contains(0), bytes.count <= Int(UInt32.max) else {
            throw OriginalStateError.invalidStorage("Library text string extent")
        }
        var next = self
        try observe(.init(.getDC, [target]))
        if dcResult >= 0 {
            next.retainedDC = dc
            try observe(.init(.setBackgroundMode, [dc, 1]))
            try observe(.init(.setTextColor, [dc, color]))
            try observe(.init(.stringLength, [], [bytes]))
            try observe(.init(.textOut, [dc, UInt32(bitPattern: x), UInt32(bitPattern: y), UInt32(bytes.count)], [bytes]))
            try observe(.init(.releaseDC, [target, dc]))
        }
        self = next
        return dcResult
    }
}
