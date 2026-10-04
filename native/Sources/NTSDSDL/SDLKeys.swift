import CSDL3
import NTSDRuntime

/// SDL scancodes (USB HID usages) onto the macOS virtual key codes of
/// `OriginalMacRuntimeKey.table`, so VK, scan code and extended flag stay
/// defined once for every host. Keys without a Windows counterpart (Command)
/// are absent, as on the AppKit host.
enum SDLKeys {
    static let macKeyCode: [UInt32:UInt16] = {
        var t: [UInt32:UInt16] = [:]
        let letters: [UInt16] = [0x00,0x0b,0x08,0x02,0x0e,0x03,0x05,0x04,0x22,0x26,0x28,0x25,0x2e,
                                 0x2d,0x1f,0x23,0x0c,0x0f,0x01,0x11,0x20,0x09,0x0d,0x07,0x10,0x06]
        for (i,code) in letters.enumerated() { t[4+UInt32(i)] = code }                    // A...Z
        let digits: [UInt16] = [0x12,0x13,0x14,0x15,0x17,0x16,0x1a,0x1c,0x19,0x1d]
        for (i,code) in digits.enumerated() { t[30+UInt32(i)] = code }                   // 1...9, 0
        let others: [(UInt32,UInt16)] = [(40,0x24),(41,0x35),(42,0x33),(43,0x30),(44,0x31),(45,0x1b),(46,0x18),
            (47,0x21),(48,0x1e),(49,0x2a),(51,0x29),(52,0x27),(53,0x32),(54,0x2b),(55,0x2f),(56,0x2c),(57,0x39),
            (73,0x72),(74,0x73),(75,0x74),(76,0x75),(77,0x77),(78,0x79),(79,0x7c),(80,0x7b),(81,0x7d),(82,0x7e),
            (84,0x4b),(85,0x43),(86,0x4e),(87,0x45),(88,0x4c),(89,0x53),(90,0x54),(91,0x55),(92,0x56),(93,0x57),
            (94,0x58),(95,0x59),(96,0x5b),(97,0x5c),(98,0x52),(99,0x41),
            (224,0x3b),(225,0x38),(226,0x3a),(228,0x3e),(229,0x3c),(230,0x3d)]
        for (scancode,code) in others { t[scancode] = code }
        let functions: [UInt16] = [0x7a,0x78,0x63,0x76,0x60,0x61,0x62,0x64,0x65,0x6d,0x67,0x6f]
        for (i,code) in functions.enumerated() { t[58+UInt32(i)] = code }                // F1...F12
        return t
    }()
    static func key(_ scancode: SDL_Scancode) -> OriginalMacRuntimeKey? {
        macKeyCode[scancode.rawValue].flatMap { OriginalMacRuntimeKey.table[$0] }
    }
    /// The characters AppKit would report: with Alt, the character without
    /// modifiers except Shift; with Control, the control code of a letter.
    static func characters(_ scancode: SDL_Scancode,_ mod: SDL_Keymod) -> String? {
        let shifted = SDL_GetKeyFromScancode(scancode,mod & (NTSD_SDL_KMOD_SHIFT | NTSD_SDL_KMOD_CAPS),true)
        guard shifted & NTSD_SDL_SCANCODE_MASK == 0,let scalar = Unicode.Scalar(shifted) else { return nil }
        if mod & NTSD_SDL_KMOD_CTRL != 0,mod & NTSD_SDL_KMOD_ALT == 0 {
            let lower = SDL_GetKeyFromScancode(scancode,0,true)
            if (0x61...0x7a).contains(lower) { return String(Unicode.Scalar(UInt8(lower & 0x1f))) }
        }
        return String(scalar)
    }
}
