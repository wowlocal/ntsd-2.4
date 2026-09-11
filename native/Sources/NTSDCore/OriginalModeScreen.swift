import Foundation

public enum OriginalModeScreenExit: String, Codable, Sendable { case returned, playback }

///431d10 with its shared input/selection helpers. Background/panel/device
///boundaries compose the caller's existing resources. No expected state is read.
public enum OriginalModeScreen {
    ///429e5a..429e78 followed by the menu10 selector. Other screen bodies
    ///remain their caller's responsibility when this returns false.
    public static func selectsModeScreen(globals: inout OriginalStateRecord) throws -> Bool {
        let base = OriginalMatchPreparation.globalBase
        if try globals.integer(at: 0x451160-base,as: Int32.self) == 5,
           try globals.integer(at: 0x450c2c-base,as: Int32.self) == 0 {
            try globals.write(Int32(1),at: 0x44d02c-base)
            try globals.write(Int32(10),at: 0x44d020-base)
        }
        return try globals.integer(at: 0x44d020-base,as: Int32.self) == 10
    }
    public static func advance(state: inout OriginalMatchPreparation, memory: inout OriginalMenuPresentationMemory,
        local: inout OriginalStateRecord, worldAddress: UInt32, target: UInt32,
        input: OriginalFrontScreenBodyInput, fillBacking: [UInt8],
        background: (inout OriginalStateRecord,inout OriginalMenuPresentationMemory) throws -> Void,
        update: (inout OriginalStateRecord) throws -> Void,
        panel: (inout OriginalStateRecord) throws -> Void,
        draw: ([UInt32],OriginalStateRecord,OriginalMenuPresentationMemory) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws -> OriginalModeScreenExit {
        var libraryText: OriginalLibSurfaceText?
        return try execute(world:state.world,actors:state.actors,globals:&state.globals,memory:&memory,
            local:&local,libraryText:&libraryText,worldAddress:worldAddress,target:target,input:input,
            fillBacking:fillBacking,background:background,update:update,panel:panel,draw:draw,observe:observe)
    }

    /// Same whole screen using the bundled library text replacement. World and
    /// Actor records are read-only; the screen does not consume the DAT catalog.
    /// Globals, bitmap ownership, local bytes and retained DC commit together.
    public static func advanceWithLibrary(world: OriginalStateRecord, actors: [OriginalStateRecord],
        globals: inout OriginalStateRecord, memory: inout OriginalMenuPresentationMemory,
        local: inout OriginalStateRecord, libraryText: inout OriginalLibSurfaceText,
        worldAddress: UInt32, target: UInt32,
        input: OriginalFrontScreenBodyInput, fillBacking: [UInt8],
        background: (inout OriginalStateRecord,inout OriginalMenuPresentationMemory) throws -> Void,
        update: (inout OriginalStateRecord) throws -> Void,
        panel: (inout OriginalStateRecord) throws -> Void,
        draw: ([UInt32],OriginalStateRecord,OriginalMenuPresentationMemory) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws -> OriginalModeScreenExit {
        var text: OriginalLibSurfaceText? = libraryText
        let result = try execute(world:world,actors:actors,globals:&globals,memory:&memory,local:&local,
            libraryText:&text,worldAddress:worldAddress,target:target,input:input,fillBacking:fillBacking,
            background:background,update:update,panel:panel,draw:draw,observe:observe)
        libraryText = text!
        return result
    }

    private static func execute(world: OriginalStateRecord, actors: [OriginalStateRecord],
        globals: inout OriginalStateRecord, memory: inout OriginalMenuPresentationMemory,
        local: inout OriginalStateRecord, libraryText: inout OriginalLibSurfaceText?,
        worldAddress: UInt32, target: UInt32,
        input: OriginalFrontScreenBodyInput, fillBacking: [UInt8],
        background: (inout OriginalStateRecord,inout OriginalMenuPresentationMemory) throws -> Void,
        update: (inout OriginalStateRecord) throws -> Void,
        panel: (inout OriginalStateRecord) throws -> Void,
        draw: ([UInt32],OriginalStateRecord,OriginalMenuPresentationMemory) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void) throws -> OriginalModeScreenExit {
        guard local.bytes.count == 0x704 else { throw OriginalStateError.invalidStorage("Mode screen local extent") }
        var state = globals, owned = memory, scratch = local, textState = libraryText
        let base = OriginalMatchPreparation.globalBase
        func word(_ address: Int) throws -> Int32 { try state.integer(at: address-base,as: Int32.self) }
        func bits(_ value: Int32) -> UInt32 { UInt32(bitPattern: value) }
        func write(_ address: Int,_ value: Int32) throws { try state.write(value,at: address-base) }
        // Local offsets below are measured from full body ESP; storage begins+10.
        func put(_ offset: Int,_ bytes: [UInt8]) throws {
            for (i,b) in bytes.enumerated() { try scratch.write(b,at: offset-0x10+i) }
        }
        func string(_ offset: Int) throws -> [UInt8] {
            let start = offset-0x10
            guard start >= 0,start < scratch.bytes.count,let end = scratch.bytes[start...].firstIndex(of: 0) else { throw OriginalStateError.invalidStorage("Mode screen string extent") }
            guard scratch.defined[start...end].allSatisfy({ $0 }) else { throw OriginalStateError.invalidStorage("Unknown mode screen string backing") }
            return Array(scratch.bytes[start..<end])
        }
        func emit(_ kind: String,_ args: [UInt32] = [],_ strings: [[UInt8]] = []) throws { try observe(.init(kind,args,strings)) }
        func bitmap(_ address: Int,_ x: Int32,_ y: Int32,_ frame: Int32,_ key: UInt32 = 1) throws {
            let args = try [bits(word(address)),bits(x),bits(y),bits(frame),key,0,target]
            try emit("draw",args);try draw(args,state,owned)
        }
        func text(_ offset: Int,_ x: Int32,_ y: Int32,_ color: UInt32 = 0xd07750,_ background: UInt32 = 0x602010) throws {
            let bytes = try string(offset), target = bits(try word(0x455608))
            if textState != nil {
                try textState!.draw(bytes,target:target,background:background,color:color,x:x,y:y,
                    dcResult:input.dcResult,dc:input.dc) { try emit($0.kind.rawValue,$0.arguments,$0.strings) }
            } else {
                try OriginalSurfaceText.draw(bytes,target:target,background:background,color:color,x:x,y:y,
                    dcResult:input.dcResult,dc:input.dc) { try emit($0.kind.rawValue,$0.arguments,$0.strings) }
            }
        }
        func sound() throws {
            try OriginalMatchPrelude.confirmationSound(in: state) { event in
                switch event {
                case .soundRequest(let loop):try emit("soundRequest",[loop ? 1 : 0])
                case .soundMethod(let resource,let offset,let arguments):try emit("soundMethod",[resource,UInt32(offset)]+arguments)
                default:throw OriginalStateError.invalidStorage("Mode screen sound event")
                }
            }
        }
        func link(_ index: Int) throws {
            if try word(0x4513c4) == 0 && word(0x457580) == 1 {
                try write(0x457580,0);try sound();try emit("sleep",[300])
                try emit("shell",[0,0,0,1],[OriginalFrontScreenBody.links[3].bytes,OriginalFrontScreenBody.links[index].bytes])
            }
        }
        func highlight(_ source: Int,_ terminator: Int,_ x: Int32,_ y: Int32) throws {
            try put(0xac,string(source)+[0]);try put(terminator,[0]);try text(0xac,x,y,0xffffff)
        }
        func finish(_ result: OriginalModeScreenExit) -> OriginalModeScreenExit { globals = state;memory = owned;local = scratch;libraryText = textState;return result }
        for (offset,value): (Int,UInt32) in [(0x10,0x451160),(0x14,0x44d020),(0x18,target),(0x1c,worldAddress),(0x20,0x4512c8)] {
            try scratch.write(value,at: offset-0x10)
        }
        try write(0x451b7c,0)
        var filled = OriginalFrontScreenEvent("fill")
        filled.fill = try OriginalSurfaceFilling.request(target: bits(word(0x455608)),x: 0,y: 0,width: 794,height: 550,color: 0x122565,backing: fillBacking)
        try observe(filled)
        if try word(0x4511ac) == 0 { try background(&state,&owned) }
        try update(&state)
        try bitmap(0x4511ac,0,word(0x453da4),-1)
        try bitmap(0x4511a0,153,word(0x453da4) &+ 96,1)
        for (index,offset) in [0x28,0x44,0x78].enumerated() { try put(offset,OriginalFrontScreenBody.literals[index].bytes) }
        let y = try word(0x45757c) &+ 491
        for offset in [0x28,0x44,0x78] {
            var i = 0
            while i < (try string(offset).count) {
                try scratch.write(scratch.bytes[offset-0x10+i] &- UInt8(i & 3),at: offset-0x10+i);i += 1
            }
        }
        try text(0x28,591,y);try text(0x44,591,y &+ 20);try text(0x78,591,y &+ 40)
        if try word(0x4546f0) > 591 && word(0x453cdc) > y &+ 30 && (word(0x453cdc) < y &+ 60 || word(0x45757c) == 0) {
            try text(0x78,591,y &+ 40,0xffffff);try link(0)
        }
        if try word(0x4546f0) > 611 && word(0x4546f0) < 686 && word(0x453cdc) > y && word(0x453cdc) < y &+ 20 {
            try highlight(0x2b,0xb6,611,y);try link(1)
        }
        if try word(0x4546f0) > 692 && word(0x453cdc) > y && word(0x453cdc) < y &+ 20 {
            try highlight(0x37,0xb8,694,y);try link(2)
        }
        let menuY = try word(0x453da4) &+ 206
        try bitmap(0x451178,244,menuY,1)
        try bitmap(0x451178,257,menuY &+ 160,state.integer(at: 0x44f1af-base,as: Int8.self) > 0 ? 50 : 51)
        let mode = try word(0x451160)
        let rows: [(Int32,Int32,Int32)] = [(289,-2,2),(275,25,3),(257,52,4),(257,79,5),(290,105,38),(299,133,6),(257,160,49),(312,188,7)]
        if (0..<8).contains(mode) { let (x,dy,frame) = rows[Int(mode)];try bitmap(0x451178,x,menuY &+ dy,frame,0) }
        let selection = try OriginalModeSelection.advance(world: world,actors: actors,globals: &state,memory: &owned) {
            try emit($0.kind.rawValue,$0.arguments)
        }
        if selection == .playback { return finish(.playback) }
        try emit("panel",[0x4513c4,target]);try panel(&state)
        if try word(0x4513c0) > 0 {
            try bitmap(0x45117c,5,39,7)
            for seat in 0..<4 {
                for button in 0..<7 {
                    let key = try word(0x44fb74+seat*80+button*4)
                    try OriginalKeyName.write(key,into: &scratch,stringAt: 0x18,adjustmentAt: 4)
                    let adjustment = try scratch.integer(at: 4,as: Int32.self)
                    try emit("keyName",[bits(key),bits(adjustment)],[string(0x28)])
                    try text(0x28,Int32(seat*108+130) &- adjustment,Int32(93+button*20),0xffffff,0x652512)
                }
            }
            try write(0x4513c0,word(0x4513c0) &- 1)
        }
        try bitmap(0x451170,min(word(0x4546f0),775),min(word(0x453cdc) &+ 2,535),-1)
        if try word(0x4546f0) >= 223 && word(0x453cdc) > word(0x453da4) &+ 194 && word(0x4546f0) < 574 && word(0x453cdc) < word(0x453da4) &+ 432 && word(0x457580) == 1 {
            try write(0x457580,0);try write(0x4513c0,450)
        }
        try write(0x4513c4,word(0x457580))
        return finish(.returned)
    }
}
