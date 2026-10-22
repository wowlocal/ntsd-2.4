@testable import RandoriRuntime

/// ENGINE_SPLIT E7f: a glyph source for the runtime's TextOutA
/// (`OriginalRuntimeStartupHost.textMask`, OriginalMacRuntimeStartup.swift:47),
/// authored here: a tiny invented 3×5 bitmap font drawn at twice its size.
/// The original draws with Windows' SYSTEM_FONT and the Mac host with the
/// system font (OriginalMacDisplayImage.swift:14-33); neither is read or
/// copied. Integer-only and the same on every host.
///
/// The mask contract (`OriginalMacDisplayBackend.TextMask`,
/// OriginalMacDisplayBackend.swift:992-1003): `bits[row*width+column]` set
/// for the text cell's pixel (column−originX, row−originY), `advance` the
/// extent's width; the cell is `textCell` (16) rows with the baseline at
/// `textAscent` (13). Each character advances 8 pixels; its 6×10 glyph
/// stands on the baseline (rows 3-12). Lower case draws as upper case; a
/// byte without a glyph draws as a filled block.
enum SyntheticGlyphs {
    static let scale = 2, advance = 8, top = 3

    /// Rows of three pixels, top to bottom ('#' set).
    static let font: [UInt8: String] = {
        let rows: [Character: String] = [
            "0": "### #.# #.# #.# ###", "1": ".#. ##. .#. .#. ###", "2": "### ..# ### #.. ###",
            "3": "### ..# .## ..# ###", "4": "#.# #.# ### ..# ..#", "5": "### #.. ### ..# ###",
            "6": "### #.. ### #.# ###", "7": "### ..# .#. .#. .#.", "8": "### #.# ### #.# ###",
            "9": "### #.# ### ..# ###",
            "A": ".#. #.# ### #.# #.#", "B": "##. #.# ##. #.# ##.", "C": ".## #.. #.. #.. .##",
            "D": "##. #.# #.# #.# ##.", "E": "### #.. ##. #.. ###", "F": "### #.. ##. #.. #..",
            "G": ".## #.. #.# #.# .##", "H": "#.# #.# ### #.# #.#", "I": "### .#. .#. .#. ###",
            "J": "..# ..# ..# #.# .#.", "K": "#.# #.# ##. #.# #.#", "L": "#.. #.. #.. #.. ###",
            "M": "#.# ### ### #.# #.#", "N": "##. #.# #.# #.# #.#", "O": ".#. #.# #.# #.# .#.",
            "P": "##. #.# ##. #.. #..", "Q": ".#. #.# #.# ##. .##", "R": "##. #.# ##. #.# #.#",
            "S": ".## #.. .#. ..# ##.", "T": "### .#. .#. .#. .#.", "U": "#.# #.# #.# #.# ###",
            "V": "#.# #.# #.# #.# .#.", "W": "#.# #.# ### ### #.#", "X": "#.# #.# .#. #.# #.#",
            "Y": "#.# #.# .#. .#. .#.", "Z": "### ..# .#. #.. ###",
            " ": "... ... ... ... ...", ":": "... .#. ... .#. ...", "!": ".#. .#. .#. ... .#.",
            "_": "... ... ... ... ###", ".": "... ... ... ... .#.", "-": "... ... ### ... ...",
            "%": "#.# ..# .#. #.. #.#", "/": "..# ..# .#. #.. #..", "?": "##. ..# .#. ... .#.",
            "'": ".#. .#. ... ... ...",
        ]
        var font: [UInt8: String] = [:]
        for (character, pattern) in rows {
            let byte = character.asciiValue!
            font[byte] = pattern.replacingOccurrences(of: " ", with: "")
            if (0x41...0x5a).contains(byte) { font[byte + 0x20] = font[byte] }
        }
        return font
    }()
    static let block = String(repeating: "#", count: 15)

    /// The mask of one TextOutA string (one 16-row cell, the glyphs side by side).
    static func mask(_ bytes: [UInt8]) -> OriginalMacDisplayBackend.TextMask {
        let width = advance * bytes.count, height = OriginalMacDisplayBackend.textCell
        var bits = [UInt8](repeating: 0, count: width * height)
        for (index, byte) in bytes.enumerated() {
            for (n, pixel) in (font[byte] ?? block).enumerated() where pixel == "#" {
                let column = index * advance + (n % 3) * scale, row = top + (n / 3) * scale
                for dy in 0..<scale { for dx in 0..<scale { bits[(row + dy) * width + column + dx] = 1 } }
            }
        }
        return .init(advance: width, originX: 0, originY: 0, width: width, height: height, bits: bits)
    }
}
