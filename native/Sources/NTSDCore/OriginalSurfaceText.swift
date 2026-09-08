import Foundation

/// Whole401290: platform responses stay at GetDC/GDI/ReleaseDC boundaries.
/// The return is the original GetDC HRESULT, even after later failures.
public enum OriginalSurfaceText {
    @discardableResult
    public static func draw(_ bytes: [UInt8], target: UInt32, background: UInt32, color: UInt32,
                            x: Int32, y: Int32, dcResult: Int32, dc: UInt32,
                            observe: (OriginalMenuPresentationEvent) throws -> Void) throws -> Int32 {
        guard target != 0 else { throw OriginalStateError.invalidStorage("Null text surface") }
        guard !bytes.contains(0), bytes.count <= Int(UInt32.max) else { throw OriginalStateError.invalidStorage("Text string extent") }
        try observe(.init(.getDC,[target]))
        if dcResult >= 0 {
            try observe(.init(.setBackgroundColor,[dc,background]))
            try observe(.init(.setTextColor,[dc,color]))
            try observe(.init(.stringLength,[],[bytes]))
            try observe(.init(.textOut,[dc,UInt32(bitPattern: x),UInt32(bitPattern: y),UInt32(bytes.count)],[bytes]))
            try observe(.init(.releaseDC,[target,dc]))
        }
        return dcResult
    }
}
