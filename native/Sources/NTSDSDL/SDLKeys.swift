import CSDL3
import NTSDRuntime

/// SDL scancodes are USB HID usages: keys come from `OriginalHIDKeys`.
enum SDLKeys {
    static func key(_ scancode: SDL_Scancode) -> OriginalMacRuntimeKey? {
        // SDL_Scancode is signed with MSVC (Windows) and unsigned elsewhere.
        OriginalHIDKeys.key(usage:UInt32(truncatingIfNeeded:scancode.rawValue))
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
