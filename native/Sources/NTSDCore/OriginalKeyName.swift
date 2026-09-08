import Foundation

///422b00..422f59: original key labels and horizontal adjustment. This is not
///the platform's localized key-name service. Preserve overwritten string tails.
public enum OriginalKeyName {
    public static func write(_ key: Int32, into storage: inout OriginalStateRecord,
                             stringAt: Int, adjustmentAt: Int) throws {
        guard stringAt >= 0, adjustmentAt >= 0,
              stringAt+10 <= storage.bytes.count, adjustmentAt+4 <= storage.bytes.count,
              stringAt+10 <= adjustmentAt || adjustmentAt+4 <= stringAt else {
            throw OriginalStateError.invalidStorage("Key-name caller storage")
        }
        var state = storage
        func text(_ value: String) throws {
            for (i,byte) in (Array(value.utf8)+[0]).enumerated() { try state.write(byte,at: stringAt+i) }
        }
        try text("none");try state.write(Int32(8),at: adjustmentAt)
        let label: String, adjustment: Int32
        if (0x41...0x5a).contains(key) || (0x30...0x39).contains(key) {
            label = String(UnicodeScalar(UInt8(key)));adjustment = 0
        } else if (0x60...0x69).contains(key) {
            label = "Keypad: "+String(key-0x60);adjustment = 15
        } else {
            let names: [Int32:(String,Int32)] = [
                0x20:("Space",10),0x0d:("Enter",10),0x6b:("Keypad: +",15),0x6d:("Keypad: -",15),
                0x6a:("Keypad: *",15),0x6f:("Keypad: /",15),0x6e:("Keypad: .",15),
                0xbd:("-",0),0xbb:("=",0),0xdb:("[",0),0xdd:("]",0),0xba:(";",0),0xde:("'",0),
                0xdc:("\\",0),0xbc:(",",0),0xbe:(".",0),0xbf:("/",0),0xc0:("`",0),
                0x11:("Ctrl",7),0x10:("Shift",7),0x09:("Tab",5),0x08:("Backspace",13),
                0x2d:("Insert",8),0x2e:("Delete",8),0x24:("Home",6),0x23:("End",5),
                0x21:("PageUp",10),0x22:("PageDown",14),0x26:("Up",2),0x25:("Left",4),
                0x28:("Down",5),0x27:("Right",6),0x14:("CapsLock",16)
            ]
            (label,adjustment) = names[key] ?? ("none",8)
        }
        try text(label);try state.write(adjustment,at: adjustmentAt)
        storage = state
    }
}
