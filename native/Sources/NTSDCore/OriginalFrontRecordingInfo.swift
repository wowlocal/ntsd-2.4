import Foundation

/// Front-menu selectors 7, RECORDING INFO (4290f3..4295e9), and 8, its
/// follow-up page (4295e9..42972c), up to their jump to presentation 42873e.
/// APPLICATION_FRONT_MENU_ITEMS_PLAN.md F3.
///
/// 4511c4 points at the edited field — name 44fd18, info 44f900 (four lines)
/// or email 44f890 — and 450be4 is the recording flag. Typing has no length
/// check; only 423a70's in-place terminator bounds the fields.
///
/// Shared recovered helpers run here — 423a70 bitmap font, 401a30 sound,
/// 422f60 key characters, 423910/43ef50 release — and report their events.
/// Bitmap drawing (43f010) and the font's Blt results, GetKeyState, the
/// 423480 reload and the 423230 writer are the caller's; Sleep and
/// ShellExecuteA are events.
public enum OriginalFrontRecordingInfo {
    public typealias Input = OriginalFrontControlSettings.Input
    public static let help = Array("http://www.littlefighter.com/record".utf8)
    public static let challenge = Array("http://www.littlefighter.com/challenge".utf8)
    public static let folder = Array("recording".utf8)
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Recording info: "+text) }

    public static func advance(selector: Int32,globals: inout OriginalStateRecord,memory: inout OriginalMenuPresentationMemory,input: Input,
        draw: ([UInt32]) throws -> Void,blit: (OriginalBitmapBlit) throws -> Int32,keyState: (UInt32) throws -> Int32,
        reload: (inout OriginalStateRecord) throws -> Void,
        write: (inout OriginalStateRecord) throws -> OriginalSettingsWriting.Result,
        observe: (OriginalFrontScreenEvent) throws -> Void) throws {
        let base = OriginalMatchPreparation.globalBase
        guard globals.bytes.count == OriginalMatchPreparation.globalSize,selector == 7 || selector == 8 else { throw error("Globals extent or selector") }
        var state = globals,owned = memory
        func word(_ a: Int) throws -> Int32 { try state.integer(at: a-base,as: Int32.self) }
        func put(_ a: Int,_ v: Int32) throws { try state.write(v,at: a-base) }
        func byte(_ a: Int) throws -> UInt8 { try state.integer(at: a-base,as: UInt8.self) }
        func putByte(_ a: Int,_ v: UInt8) throws { try state.write(v,at: a-base) }
        func bits(_ n: Int32) -> UInt32 { UInt32(bitPattern: n) }
        func bitmap(_ slot: Int,_ x: Int32,_ y: Int32,_ frame: Int32) throws {
            let args = [try state.integer(at: slot-base,as: UInt32.self),bits(x),bits(y),bits(frame),1,0,input.target]
            try observe(.init("draw",args));try draw(args)
        }
        func sound(_ slot: Int) throws {
            try OriginalMatchPrelude.playSound(in: state,slot: slot) { e in
                switch e {
                case .soundRequest(let loop):try observe(.init("soundRequest",[loop ? 1 : 0]))
                case .soundMethod(let resource,let offset,let args):try observe(.init("soundMethod",[resource,UInt32(offset)]+args))
                default:throw error("Sound event")
                }
            }
        }
        func link(_ verb: String,_ file: [UInt8]) throws {
            try sound(0x455610);try observe(.init("sleep",[300]))
            try observe(.init("shell",[0,0,0,1],[Array(verb.utf8),file]))
        }
        func clicked() throws -> Bool { try word(0x44d060) == 0 && word(0x457580) == 1 }
        func mouse() throws -> (Int32,Int32) { (try word(0x4546f0),try word(0x453cdc)) }
        func inside(_ x0: Int32,_ y0: Int32,_ x1: Int32,_ y1: Int32) throws -> Bool {
            let (x,y) = try mouse();return x >= x0 && y >= y0 && x <= x1 && y <= y1
        }
        func length(_ address: Int) throws -> Int {
            var n = 0
            while try byte(address+n) != 0 { n += 1 }
            return n
        }
        func leave() throws {
            try put(0x44d064,0);try put(0x44d780,-1)
            try OriginalMenuPresentation.releaseBackground(globals: &state,memory: &owned) { e in try observe(.init(e.kind.rawValue,e.arguments,e.strings)) }
        }
        func font(_ address: Int,_ y: Int32,_ lines: Int32) throws {
            let selected: Int32 = try word(0x4511c4) == Int32(address) ? 1 : 0,resources = state,allocations = owned.allocations
            try OriginalBitmapFont.draw(.fourPass,text: &state,offset: address-base,x: 0xd5,y: y,columns: 0x40,lines: lines,
                style: selected,cursor: UInt32(selected),globals: resources,resourceBitmap: { pointer in
                    guard let bitmap = allocations[pointer],bitmap.live else { throw error("Unbound font bitmap") }
                    let surface = try bitmap.storage.integer(at: 0,as: UInt32.self)
                    var record = bitmap.storage;try record.write(UInt32(surface == 0 ? 0 : 1),at: 0)
                    return (record,surface)
                },performBlit: blit,observe: observe)
        }

        if selector == 8 {
            try bitmap(0x4511a0,0x9b,0x4b,1);try bitmap(0x4511a4,0x2c,0xa7,3)
            if try inside(0x60,0x15c,0x27f,0x174) {
                try bitmap(0x4511a4,0x60,0x15c,4)
                if try clicked() { try link("open",challenge) }
            }
            if try inside(0x13e,0x17e,0x1d8,0x196) {
                try bitmap(0x4511a0,0x13e,0x17e,13)
                if try clicked() { try sound(0x455610);try leave() }
            }
            globals = state;memory = owned;return
        }

        try bitmap(0x4511a0,0x9b,0x37,1);try bitmap(0x4511a4,0x2c,0x93,0)
        // A click selects the field under the pointer or clears the selection.
        if try clicked() {
            let (x,y) = try mouse();var field: Int32 = 0
            if x >= 0xd2 && x < 0x2db {
                if y >= 0xcf && y < 0xe2 { field = 0x44fd18 }
                else if y >= 0xe8 && y < 0x12f { field = 0x44f900 }
                else if y >= 0x135 && y < 0x148 { field = 0x44f890 }
            }
            try put(0x4511c4,field)
        }
        // Every pressed key 0..0xf9: Return is '\n' (not into an empty field),
        // Backspace removes the last byte, other characters append.
        let field = Int(try word(0x4511c4))
        if field != 0 {
            for vk in 0..<0xfa where try byte(0x455378+vk) == 0x64 {
                var character = try OriginalMenuCharacter.decode(UInt32(vk),readShift: { try byte(0x455388) },keyState: { k in
                    let value = try keyState(k);try observe(.init("keyState",[k,UInt32(bitPattern: value)]));return value
                })
                if vk == 13 { character = 10 }
                else if vk == 8 || character == 0 {
                    guard vk == 8 else { continue }
                    let n = try length(field)
                    if n > 0 { try putByte(field+n-1,0);try putByte(0x455378+vk,0x75) }
                    continue
                }
                let n = try length(field)
                if n == 0 && character == 10 { continue }
                try putByte(field+n+1,0);try putByte(field+n,character);try putByte(0x455378+vk,0x75)
            }
        }
        try font(0x44fd18,0xd1,1);try font(0x44f900,0xea,4);try font(0x44f890,0x137,1)
        // Recording flag, "recording" folder, help link.
        if try word(0x450be4) != 0 { try bitmap(0x4511a4,0x11f,0x185,6) }
        if try inside(0x11f,0x186,0x132,0x199) {
            try bitmap(0x4511a4,0x11f,0x185,5)
            if try clicked() { try put(0x450be4,1 &- word(0x450be4)) }
        }
        if try inside(0x185,0x184,0x2dc,0x19a) {
            try bitmap(0x4511a4,0x185,0x184,7)
            if try clicked() { try link("explore",folder) }
        }
        if try inside(0x2c,0x1cd,0x1e3,0x1e4) {
            try bitmap(0x4511a4,0x2c,0x1cd,2)
            if try clicked() { try link("open",help) }
        } else { try bitmap(0x4511a4,0x2c,0x1cd,1) }
        // Cancel: reload, sound, back to the main menu. OK: write, sound, page 8.
        if try inside(0x193,0x1a0,0x22e,0x1b8) {
            try bitmap(0x4511a0,0x193,0x1a0,12)
            if try clicked() { try reload(&state);try sound(0x455614);try leave() }
        }
        if try inside(0xe7,0x1a0,0x182,0x1b8) {
            try bitmap(0x4511a0,0xe7,0x1a0,13)
            if try clicked() {
                try observe(.init("call",[0x423230]))
                switch try write(&state) {
                case .returned(let n):try observe(.init("return",[0x423230,n]))
                default:throw error("Settings writer boundary")
                }
                try sound(0x455610);try put(0x44d064,8)
            }
        }
        globals = state;memory = owned
    }
}
