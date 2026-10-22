import Foundation

/// A finished presentation crop: `width × height` 32-bit words, row-major,
/// each stored little-endian as 0x00RRGGBB (XRGB8888, the high byte unused).
/// Backends turn it into their own image type; the Mac builds an sRGB
/// `noneSkipFirst | byteOrder32Little` CGImage from these exact bytes.
public struct OriginalFramebuffer: Equatable, Sendable {
    public let width: Int, height: Int, pixels: Data
    public init(width: Int, height: Int, pixels: Data) {
        precondition(width >= 0 && height >= 0 && pixels.count == width*height*4, "framebuffer size")
        self.width = width; self.height = height; self.pixels = pixels
    }
}
