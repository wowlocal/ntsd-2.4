import Foundation

/// Front-menu selector 6, CONTROL SETTINGS: 4289c4..4290ee, up to its jump to
/// presentation 42873a. APPLICATION_FRONT_MENU_ITEMS_PLAN.md F2.
///
/// Control table: player p's twenty words at 44fb70 + 80·p; word 0 is the
/// device (0 keyboard, else a joystick whose four button bytes are at
/// 453fc4 + 48·device); cell 1 + 20·p + row (rows 0–6) holds a keyboard VK in
/// 44fb70[cell] or a joystick button in 44fb7c[cell]. Names are eleven bytes
/// at 44fcc0 + 11·p. 4511e0 is the cell waiting for a key, 4511c8 the player
/// (1-based) whose name is edited. The OK/Cancel handling sits inside the
/// per-player loop, so one click runs it once per player, as the original.
///
/// Shared recovered helpers run here — 401290 text, 401a30 sound, 422b00 key
/// names, 422f60 key characters, sprintf, 423910/43ef50 release — and report
/// their events. Bitmap drawing (43f010), GetKeyState, the 423480 reload and
/// the 423230 writer are the caller's; Sleep and ShellExecuteA are events.
public enum OriginalFrontControlSettings {
    public struct Input: Equatable, Sendable {
        public let target: UInt32, dcResult: Int32, dc: UInt32
        public init(target: UInt32,dcResult: Int32,dc: UInt32) { self.target = target;self.dcResult = dcResult;self.dc = dc }
    }
    public static let help = Array("http://www.littlefighter.com/control_index.html".utf8)
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Control settings: "+text) }

    public static func advance(globals: inout OriginalStateRecord,memory: inout OriginalMenuPresentationMemory,input: Input,
        draw: ([UInt32]) throws -> Void,keyState: (UInt32) throws -> Int32,
        reload: (inout OriginalStateRecord) throws -> Void,
        write: (inout OriginalStateRecord) throws -> OriginalSettingsWriting.Result,
        observe: (OriginalFrontScreenEvent) throws -> Void) throws {
        let base = OriginalMatchPreparation.globalBase
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else { throw error("Globals extent") }
        var state = globals,owned = memory
        func word(_ a: Int) throws -> Int32 { try state.integer(at: a-base,as: Int32.self) }
        func put(_ a: Int,_ v: Int32) throws { try state.write(v,at: a-base) }
        func byte(_ a: Int) throws -> UInt8 { try state.integer(at: a-base,as: UInt8.self) }
        func putByte(_ a: Int,_ v: UInt8) throws { try state.write(v,at: a-base) }
        func bits(_ n: Int32) -> UInt32 { UInt32(bitPattern: n) }
        func bitmap(_ slot: Int,_ x: Int32,_ y: Int32,_ frame: Int32,_ key: UInt32) throws {
            let args = [try state.integer(at: slot-base,as: UInt32.self),bits(x),bits(y),bits(frame),key,0,input.target]
            try observe(.init("draw",args));try draw(args)
        }
        func text(_ bytes: [UInt8],_ color: UInt32,_ x: Int32,_ y: Int32) throws {
            try OriginalSurfaceText.draw(bytes,target: UInt32(bitPattern: word(0x455608)),background: 0x2c0900,color: color,x: x,y: y,
                dcResult: input.dcResult,dc: input.dc) { e in try observe(.init(e.kind.rawValue,e.arguments,e.strings)) }
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
        func clicked() throws -> Bool { try word(0x44d060) == 0 && word(0x457580) == 1 }
        func name(_ address: Int) throws -> [UInt8] {
            var bytes: [UInt8] = []
            while true { let b = try byte(address+bytes.count);if b == 0 { return bytes };bytes.append(b) }
        }
        func mouse() throws -> (Int32,Int32) { (try word(0x4546f0),try word(0x453cdc)) }
        func leave() throws {
            // 44d064 = 0, 44d780 = −1, then 423910's background release.
            try put(0x44d064,0);try put(0x44d780,-1)
            try OriginalMenuPresentation.releaseBackground(globals: &state,memory: &owned) { e in try observe(.init(e.kind.rawValue,e.arguments,e.strings)) }
        }

        try bitmap(0x4511a0,0x9b,0x23,1,1)
        try bitmap(0x451168,0x2e,0x79,0,1)
        // Help link (46..540 × 475..498): no click reset, as the original.
        var (mx,my) = try mouse()
        if mx >= 0x2e,mx <= 0x21c,my >= 0x1db,my <= 0x1f2 {
            try bitmap(0x451168,0x2e,0x1db,2,1)
            if try clicked() {
                try sound(0x455610);try observe(.init("sleep",[300]))
                try observe(.init("shell",[0,0,0,1],[Array("open".utf8),help]))
            }
        } else { try bitmap(0x451168,0x2e,0x1db,1,1) }
        // The cell waiting for a key: the first pressed keyboard VK, or the
        // first pressed button of the player's joystick.
        let cell = try word(0x4511e0)
        if cell > 0 {
            let device = try word(0x44fb70+Int(cell/20)*80)
            if device == 0 {
                for vk in 0..<0xfa where try byte(0x455378+vk) == 0x64 {
                    try put(0x44fb70+Int(cell)*4,Int32(vk));try put(0x4511e0,0);break
                }
            } else {
                for button in 0..<4 where try byte(0x453fc4+Int(device)*48+button) == 1 {
                    try put(0x44fb7c+Int(cell)*4,Int32(button));try put(0x4511e0,0);break
                }
            }
        }
        // Name editing: every pressed key through 422f60.
        if try word(0x4511c8) > 0 {
            for vk in 0..<0x12c where try byte(0x455378+vk) == 0x64 {
                let character = try OriginalMenuCharacter.decode(UInt32(vk),readShift: { try byte(0x455388) },keyState: { k in
                    let value = try keyState(k);try observe(.init("keyState",[k,UInt32(bitPattern: value)]));return value
                })
                let address = Int(try word(0x4511c8))*11+0x44fcb5,length = try name(address).count
                var consumed = false
                if character != 0 && vk != 8 {
                    if length < 10 && vk != 13 { try putByte(address+length,character);try putByte(address+length+1,0);consumed = true }
                } else if vk == 8 && length > 0 { try putByte(address+length-1,0);consumed = true }
                if consumed { try putByte(0x455378+vk,0x75) }
            }
        }
        // The four players (x 0xc2 + 0x8b·p).
        for player in 0..<4 {
            let x = Int32(0xc2+0x8b*player),devices = 0x44fb70+80*player,names = 0x44fcc0+11*player,first = Int32(1+20*player)
            (mx,my) = try mouse()
            if mx >= x,mx <= x+0x69,try clicked(),bits(my &- 0xb6) <= 0x5a {
                try put(0x4511e0,0);try put(devices,(try word(devices) &+ 1)%3)
            }
            let own = try name(names)
            if try word(0x4511c8) &- 1 != Int32(player) { try text(own,0xffffff,x+0x15,0x9f) }
            else if own.count >= 10 { try text(own,0xff4619,x+0x15,0x9f) }
            else { try text(own+Array("_".utf8),0xff4619,x+0x15,0x9f) }
            // 428d0e: from x (EBP), to x+0x15+0x54 (ESI after the text call).
            (mx,my) = try mouse()
            if mx >= x,mx <= x+0x15+0x54,bits(my &- 0x9c) <= 0x11,try clicked() {
                try put(0x4511e0,0);try put(0x4511c8,Int32(player+1))
            }
            let shift = Int32(0x8b*player)
            for row in 0..<7 {
                let y = Int32(0x11b+0x16*row),index = first+Int32(row)
                (mx,my) = try mouse()
                if mx >= x,mx <= shift+0x12b,try clicked(),my >= y+0xf-0x12,my <= y+0xf {
                    // Joysticks keep their four direction rows.
                    if try word(devices) == 0 || row > 3 { try put(0x4511e0,index) }
                    try put(0x4511c8,0)
                }
                let selected: UInt32 = try word(0x4511e0) == index ? 0xff4619 : 0xffffff
                if try word(devices) == 0 {
                    var labels = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 16),defined: [Bool](repeating: false,count: 16))
                    try OriginalKeyName.write(word(0x44fb70+Int(index)*4),into: &labels,stringAt: 0,adjustmentAt: 12)
                    guard let end = labels.bytes[0..<12].firstIndex(of: 0) else { throw error("Key name extent") }
                    try text(Array(labels.bytes[0..<end]),selected,shift &- labels.integer(at: 12,as: Int32.self) &+ 0xeb,y)
                } else if row < 4 {
                    try text(Array("-".utf8),0xffffff,shift+0xf2,y)
                } else {
                    let formatted = Array(String(try word(0x44fb7c+Int(index)*4) &+ 1).utf8)
                    let bytes = Array("Button: ".utf8)+formatted
                    try observe(.init("format",[UInt32(bytes.count)],[Array("Button: %d".utf8),bytes]))
                    try text(bytes,selected,shift+0xe4,y)
                }
            }
            let icons: [Int32:Int] = [0:0x451180,1:0x451174,2:0x451164,3:0x451184,4:0x451194]
            if let icon = icons[try word(devices)] { try bitmap(icon,x,0xb6,-1,0) }
            // Cancel (0x244) and OK (0x198), inside the player loop.
            (mx,my) = try mouse()
            if my >= 0x1b9 {
                if my <= 0x1d1,bits(mx &- 0x246) <= 0x9b {
                    try bitmap(0x4511a0,0x244,0x1b9,12,1)
                    if try clicked() { try sound(0x455614);try reload(&state);try leave() }
                }
                (mx,my) = try mouse()
                if bits(my &- 0x1b9) <= 0x18,bits(mx &- 0x195) <= 0x9b {
                    try bitmap(0x4511a0,0x198,0x1b9,13,1)
                    if try clicked() {
                        try sound(0x455610);try observe(.init("call",[0x423230]))
                        switch try write(&state) {
                        case .returned(let n):try observe(.init("return",[0x423230,n]))
                        default:throw error("Settings writer boundary")
                        }
                        try leave()
                    }
                }
            }
        }
        globals = state;memory = owned
    }
}
