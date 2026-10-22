import Foundation

/// ENGINE_SPLIT E7c: the synthetic pack's images and sounds, authored here from
/// integer patterns (no original byte, no floating point, so every host writes
/// the same bytes). Formats are the ones the engine's loaders accept:
/// 24-bit BI_RGB DIBs (`OriginalApplicationStartupInputs.Bitmap`,
/// `OriginalDIBPixels.validate`), BMP files with the 14-byte file header
/// (`Bitmap(bitmapFile:)`) and 8-bit mono PCM WAVs whose `fmt ` chunk is a
/// WAVEFORMATEX (`OriginalMacRuntimeWave.input` reads the format tag at +20 and
/// walks the chunks to `data`).
enum SyntheticMedia {
    struct RGB: Equatable { var r: UInt8, g: UInt8, b: UInt8 }
    static let black = RGB(r: 0, g: 0, b: 0)

    private static func append32(_ value: Int, to bytes: inout [UInt8]) {
        for i in 0..<4 { bytes.append(UInt8(truncatingIfNeeded: value >> (8*i))) }
    }
    private static func append16(_ value: Int, to bytes: inout [UInt8]) {
        for i in 0..<2 { bytes.append(UInt8(truncatingIfNeeded: value >> (8*i))) }
    }

    /// A bottom-up 24-bit DIB: BITMAPINFOHEADER (40 bytes, no palette) and rows
    /// padded to four bytes. `pixel(x, y)` counts y from the top of the image.
    static func dib(width: Int, height: Int, pixel: (Int, Int) -> RGB) -> [UInt8] {
        precondition(width > 0 && height > 0)
        let stride = (width*3 + 3)/4*4
        var bytes: [UInt8] = []
        bytes.reserveCapacity(40 + stride*height)
        append32(40, to: &bytes); append32(width, to: &bytes); append32(height, to: &bytes)
        append16(1, to: &bytes); append16(24, to: &bytes)
        append32(0, to: &bytes)              // BI_RGB
        append32(stride*height, to: &bytes)  // image size (the validator accepts 0 or the extent)
        append32(0, to: &bytes); append32(0, to: &bytes)  // resolution: none declared
        append32(0, to: &bytes); append32(0, to: &bytes)  // colours used/important: none (24-bit)
        for row in 0..<height {
            let y = height - 1 - row
            for x in 0..<width {
                let p = pixel(x, y)
                bytes += [p.b, p.g, p.r]
            }
            bytes += [UInt8](repeating: 0, count: stride - width*3)
        }
        return bytes
    }

    /// The same image as a BMP file: "BM", file size, two reserved words and
    /// the pixel offset 54 (header + BITMAPINFOHEADER).
    static func bmp(width: Int, height: Int, pixel: (Int, Int) -> RGB) -> [UInt8] {
        let body = dib(width: width, height: height, pixel: pixel)
        var bytes: [UInt8] = [0x42, 0x4d]
        append32(14 + body.count, to: &bytes)
        append32(0, to: &bytes)
        append32(54, to: &bytes)
        return bytes + body
    }

    /// A flat-coloured DIB with a one-pixel frame in `edge`: the plain images
    /// the menus, the interface and the built-in backgrounds take.
    static func panel(width: Int, height: Int, fill: RGB, edge: RGB) -> [UInt8] {
        dib(width: width, height: height) { x, y in
            x == 0 || y == 0 || x == width - 1 || y == height - 1 ? edge : fill
        }
    }

    /// A sprite sheet of `row` × `col` cells of (w+1) × (h+1) pixels, the layout
    /// the Object loader slices (`OriginalObjectLoader.finishSheet`: x = (i % row)·(w+1),
    /// y = (i / row)·(h+1)). Each cell holds a figure on black (the colour key):
    /// a body block whose height and an arm whose length follow the picture
    /// number, so every picture differs. `mirrored` flips the sheet left to
    /// right, as the `_mirror.bmp` companions are.
    static func sheet(w: Int, h: Int, row: Int, col: Int, body: RGB, accent: RGB, mirrored: Bool) -> [UInt8] {
        let width = row*(w + 1), height = col*(h + 1)
        return bmp(width: width, height: height) { px, y in
            let x = mirrored ? width - 1 - px : px
            let cellX = x % (w + 1), cellY = y % (h + 1)
            guard cellX < w, cellY < h else { return black }
            let picture = (y/(h + 1))*row + x/(w + 1)
            let left = w/4, right = w - w/4, top = h/4 + picture % 4
            if cellY >= top && cellX >= left && cellX < right { return cellY < top + 3 ? accent : body }
            let arm = 2 + picture % 5
            if cellY == top + 4 && cellX >= right && cellX < min(w, right + arm) { return accent }
            return black
        }
    }

    /// A banded layer or portrait image (BMP file): horizontal bands of `colors`.
    static func bands(width: Int, height: Int, colors: [RGB]) -> [UInt8] {
        bmp(width: width, height: height) { x, y in
            let band = colors[(y*colors.count)/height]
            return (x + y) % 16 == 0 ? RGB(r: band.r/2, g: band.g/2, b: band.b/2) : band
        }
    }

    /// An 8-bit mono PCM WAV of `samples` samples at `rate` Hz: a triangle wave
    /// of `period` samples whose amplitude falls linearly to silence. The `fmt `
    /// chunk is an 18-byte WAVEFORMATEX (cbSize 0); an odd `data` chunk is padded.
    static func wav(rate: Int, samples: Int, period: Int, amplitude: Int) -> [UInt8] {
        precondition(samples > 0 && period >= 2 && (0...127).contains(amplitude))
        var data: [UInt8] = []
        data.reserveCapacity(samples)
        for i in 0..<samples {
            let phase = i % period, half = period/2
            let triangle = phase < half ? (phase*2*amplitude)/max(half, 1) - amplitude
                                        : amplitude - ((phase - half)*2*amplitude)/max(period - half, 1)
            let value = 128 + triangle*(samples - i)/samples
            data.append(UInt8(clamping: value))
        }
        var bytes = Array("RIFF".utf8)
        let pad = samples % 2
        append32(4 + (8 + 18) + (8 + samples + pad), to: &bytes)
        bytes += Array("WAVE".utf8) + Array("fmt ".utf8)
        append32(18, to: &bytes)
        append16(1, to: &bytes)        // WAVE_FORMAT_PCM
        append16(1, to: &bytes)        // mono
        append32(rate, to: &bytes)
        append32(rate, to: &bytes)     // bytes per second (one byte per sample)
        append16(1, to: &bytes)        // block align
        append16(8, to: &bytes)        // bits per sample
        append16(0, to: &bytes)        // cbSize
        bytes += Array("data".utf8)
        append32(samples, to: &bytes)
        bytes += data
        if pad == 1 { bytes.append(0x80) }
        return bytes
    }
}
