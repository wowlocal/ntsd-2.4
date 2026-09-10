/// Network selector1/2/3 bodies427ca7..42873e/4287de. Hostname storage is
/// separate from the previously recovered World prefix; callers must own its
/// provenance. Shared original helpers perform background, text, sound, exit
/// and deferred client connection. No host text mapping or networking is used.
public enum OriginalNetworkMenu {
    public enum Continuation: String, Codable, Sendable { case presentation, epilogue, otherSelector }
    public struct Input {
        public let selector: Int32,worldAddress: UInt32,drawTarget: UInt32,dcResult: Int32,dc: UInt32
        public init(selector: Int32,worldAddress: UInt32,drawTarget: UInt32,dcResult: Int32,dc: UInt32) {
            self.selector = selector;self.worldAddress = worldAddress;self.drawTarget = drawTarget;self.dcResult = dcResult;self.dc = dc
        }
    }
    /// Buffer external effects until the encompassing tick commits. Throwing
    /// providers or late observers preserve every supplied state, including DC,
    /// caller text bytes and resource ownership.
    public static func run(world: inout OriginalStateRecord,hostname: inout OriginalStateRecord,
        globals: inout OriginalStateRecord,local: inout OriginalStateRecord,
        libraryText: inout OriginalLibSurfaceText,memory: inout OriginalMenuPresentationMemory,input: Input,
        background: (inout OriginalStateRecord,inout OriginalMenuPresentationMemory) throws -> Void,
        draw: ([UInt32],OriginalMenuPresentationMemory) throws -> Void,fill: ([UInt32]) throws -> Void,
        timer: () throws -> UInt32,keyState: (UInt32) throws -> Int32,
        client: (inout OriginalStateRecord,inout OriginalStateRecord,OriginalStateRecord) throws -> OriginalNetworkClient.Exit,
        exit: (inout OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws -> Continuation {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize,hostname.bytes.count == 51,
              world.bytes.count == 0x7d8,local.bytes.count == 0x400 else { throw error("Storage extent") }
        var state = globals,ownWorld = world,host = hostname,scratch = local,text = libraryText,owned = memory
        let base = OriginalMatchPreparation.globalBase
        func bits(_ n: Int32) -> UInt32 { UInt32(bitPattern: n) }
        func word(_ a: Int) throws -> Int32 { try state.integer(at: a-base,as: Int32.self) }
        func byte(_ a: Int) throws -> UInt8 { try state.integer(at: a-base,as: UInt8.self) }
        func event(_ kind: String,_ args: [UInt32] = [],_ strings: [[UInt8]] = []) throws { try observe(.init(kind,args,strings)) }
        func put(_ a: Int,_ n: Int32) throws { try state.write(n,at: a-base);try event("write",[UInt32(a),4,bits(n)]) }
        func putByte(_ a: Int,_ n: UInt8) throws { try state.write(n,at: a-base);try event("write",[UInt32(a),1,UInt32(n)]) }
        func putHost(_ offset: Int,_ n: UInt8) throws {
            guard host.bytes.indices.contains(offset) else { throw error("Hostname write outside recovered51 bytes") }
            try host.write(n,at: offset);try event("write",[input.worldAddress+0x7d8+UInt32(offset),1,UInt32(n)])
        }
        func string(_ r: OriginalStateRecord,_ offset: Int) throws -> [UInt8] {
            var bytes: [UInt8] = []
            while true { let b = try r.integer(at: offset+bytes.count,as: UInt8.self);if b == 0 { return bytes };bytes.append(b) }
        }
        func formatted(_ format: String,_ bytes: [UInt8],rootOffset: Int,x: Int32,y: Int32) throws {
            let offset = rootOffset-0x14
            guard offset >= 0,bytes.count < scratch.bytes.count-offset else { throw error("Formatted caller string exceeds recovered backing") }
            for (i,b) in (bytes+[0]).enumerated() { try scratch.write(b,at: offset+i) }
            try event("format",[UInt32(bytes.count)],[Array(format.utf8),bytes])
            let target = bits(try word(0x455608))
            try event("text",[target,0x501e00,0xffffff,bits(x),bits(y)],[bytes])
            try text.draw(bytes,target: target,background: 0x501e00,color: 0xffffff,x: x,y: y,dcResult: input.dcResult,dc: input.dc) { e in
                try event(e.kind.rawValue,e.arguments,e.strings)
            }
        }
        func bitmap(_ slot: Int,_ x: Int32,_ y: Int32,_ frame: Int32,_ colorKey: UInt32 = 1) throws {
            let args = try [bits(word(slot)),bits(x),bits(y),bits(frame),colorKey,0,input.drawTarget]
            try event("draw",args);try draw(args,owned)
        }
        func sound(_ slot: Int) throws {
            try OriginalMatchPrelude.playSound(in: state,slot: slot) { e in
                switch e {
                case .soundRequest(let loop):try event("soundRequest",[loop ? 1 : 0])
                case .soundMethod(let resource,let offset,let args):try event("soundMethod",[resource,UInt32(offset)]+args)
                default:throw error("Sound event")
                }
            }
        }
        func clicked() throws -> Bool { try word(0x44d060) == 0 && word(0x457580) == 1 }
        func inside(_ x0: Int32,_ x1: Int32,_ y0: Int32,_ y1: Int32) throws -> Bool {
            try word(0x4546f0) >= x0 && word(0x4546f0) <= x1 && word(0x453cdc) >= y0 && word(0x453cdc) <= y1
        }
        func clock() throws -> UInt32 { let n = try timer();try event("timer",[n]);return n }
        func commit(_ end: Continuation) -> Continuation {
            world = ownWorld;hostname = host;globals = state;local = scratch;libraryText = text;memory = owned;return end
        }
        guard (1...3).contains(input.selector) else { return commit(.otherSelector) }
        if try word(0x4511ac) == 0 { try background(&state,&owned) }
        try bitmap(0x4511ac,0,0,-1);try bitmap(0x4511a0,155,105,1)
        try bitmap(0x4511a0,253,222,3);try bitmap(0x4511a0,253,335,14)
        try formatted(" Your IP Address: %s",Array(" Your IP Address: ".utf8)+string(state,0x44f340-base),rootOffset: 0x158,x: 289,y: 251)
        if input.selector == 1 {
            if try inside(368,790,449,536) {
                try bitmap(0x45117c,368,449,3,0)
                if try clicked() {
                    try sound(0x455610);try event("sleep",[300])
                    try event("shell",[0,0,0,1],[Array("open".utf8),Array("http://lf2.net/forum".utf8)])
                }
            } else { try bitmap(0x45117c,368,449,4,0) }
            guard try word(0x4546f0) >= 260 && word(0x4546f0) <= 547 else { return commit(.presentation) }
            let y = try word(0x453cdc)
            if (274...300).contains(y) {
                try bitmap(0x4511a0,259,274,5)
                if try clicked() { try sound(0x455610);try put(0x44d064,2) }
            } else if (305...330).contains(y) {
                try bitmap(0x4511a0,259,304,6)
                if try clicked() { try sound(0x455610);try put(0x44d064,3);try put(0x4511dc,0);try putHost(0,0) }
            } else if (336...361).contains(y) {
                try bitmap(0x4511a0,329,336,12)
                if try clicked() {
                    try sound(0x455614);try put(0x44d064,0);try put(0x44d780,-1)
                    try OriginalMenuPresentation.releaseBackground(globals: &state,memory: &owned) { e in try event(e.kind.rawValue,e.arguments,e.strings) }
                    try exit(&state)
                }
            }
            return commit(.presentation)
        }
        if input.selector == 2 {
            try bitmap(0x4511a0,236,290,10)
            if try byte(0x4511f0) & 2 == 0 { try put(0x4511f0,word(0x4511f0) | 2);try put(0x4511d8,Int32(bitPattern: clock())) }
            if try clock() &- bits(word(0x4511d8)) > 150 {
                try put(0x4511d4,(word(0x4511d4) &+ 1)%14);try put(0x4511d8,Int32(bitPattern: clock()))
            }
            if try byte(0x44f1ae) == 1 { try ownWorld.write(Int32(1),at: 0);try event("write",[input.worldAddress,4,1]) }
            if try inside(322,472,361,386) {
                try bitmap(0x4511a0,322,361,12)
                if try clicked() { try sound(0x455614);try put(0x44d064,1) }
            }
            var i: Int32 = 0,x: Int32 = 281
            while try i < word(0x4511d4) {
                let args = try [bits(word(0x455608)),bits(x),342,5,12,0x577fd7]
                try event("fillRequest",args);try fill(args);i = i &+ 1;x = x &+ 20
            }
            return commit(.presentation)
        }
        if try word(0x4511b0) == 0 {
            if try inside(239,389,357,382) && clicked() { try putByte(0x455385,100) }
            else if try byte(0x455385) != 100 {
                try bitmap(0x4511a0,219,268,4)
                if try inside(411,561,357,382) {
                    try bitmap(0x4511a0,411,357,12)
                    if try clicked() { try sound(0x455614);try put(0x44d064,1) }
                }
                if try inside(239,389,357,382) { try bitmap(0x4511a0,239,357,13) }
                try formatted("%s",string(host,0),rootOffset: 0x2e8,x: 339,y: 327)
            }
        }
        for key in 0..<300 where try byte(0x455378+key) == 100 {
            let character = try OriginalMenuCharacter.decode(UInt32(key),readShift: { try byte(0x455388) },keyState: { k in
                let n = try keyState(k);try event("keyState",[k,bits(n)]);return n
            })
            let index = try word(0x4511dc)
            if key == 8 {
                if index > 0 { try putByte(0x455378+key,117);try putHost(Int(index)-1,0);try put(0x4511dc,index &- 1) }
            } else if character != 0 && index < 50 && key != 13 {
                try putHost(Int(index),character);try putHost(Int(index)+1,0);try putByte(0x455378+key,117);try put(0x4511dc,index &+ 1)
            }
        }
        if try byte(0x455385) == 100 {
            try sound(0x455610);try putByte(0x455385,117);try put(0x4511b0,1)
            try bitmap(0x4511a0,236,290,11);return commit(.presentation)
        }
        let joined = try OriginalStateRecord(bytes: ownWorld.bytes+host.bytes,defined: ownWorld.defined+host.defined)
        let end = try client(&state,&scratch,joined)
        return commit(end == .present ? .presentation : .epilogue)
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Network menu: "+text) }
}
