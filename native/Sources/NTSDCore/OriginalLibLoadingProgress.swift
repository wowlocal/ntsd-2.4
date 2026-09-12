/// The full4242e0 loading caller, installed library label/text and43d230 tail.
/// Platform adapters supply clocks and requests; no DLL or Windows runtime.
public enum OriginalLibLoadingProgress {
    public struct MessageResponse {
        public let result: Int32, bytes: [UInt8]
        public init(result: Int32 = 0,bytes: [UInt8] = []) { self.result = result;self.bytes = bytes }
    }
    public static func update(globals: inout OriginalStateRecord, libraryText: inout OriginalLibSurfaceText,
        input: OriginalMenuPresentationInput, time: () throws -> UInt32,
        panelFirstWord: (UInt32) throws -> UInt32,
        draw: ([UInt32]) throws -> Void, fillBacking: () throws -> [UInt8],
        performFill: (OriginalSurfaceFillRequest) throws -> Int32,
        message: (String,[UInt8]) throws -> MessageResponse,
        checkpoint: (OriginalStateRecord) throws -> Void = { _ in },
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else { throw OriginalStateError.invalidStorage("Loading globals extent") }
        var state = globals, text = libraryText
        func word(_ p: Int) throws -> UInt32 { try state.integer(at: p-0x44d000,as: UInt32.self) }
        func signed(_ p: Int) throws -> Int32 { Int32(bitPattern: try word(p)) }
        func put(_ p: Int,_ value: UInt32) throws { try state.write(value,at: p-0x44d000) }
        func bits(_ n: Int32) -> UInt32 { UInt32(bitPattern: n) }
        func emit(_ kind: String,_ args: [UInt32] = [],_ strings: [[UInt8]] = []) throws { try checkpoint(state);try observe(.init(kind,args,strings)) }
        func now() throws -> UInt32 { let value = try time();try emit("timeGetTime",[value]);return value }
        func bitmap(_ p: Int,_ x: Int32,_ y: Int32,_ frame: Int32,_ key: UInt32 = 1) throws {
            let args = try [word(p),bits(x),bits(y),bits(frame),key,0,input.targetSurface]
            try emit("draw",args);try draw(args)
        }
        func string(_ p: Int) throws -> [UInt8] {
            var result: [UInt8] = [],at = p
            while true {
                let byte = try state.integer(at: at-0x44d000,as: UInt8.self)
                if byte == 0 { return result };result.append(byte);at += 1
            }
        }
        func click(_ bytes: [UInt8]) throws {
            guard try word(0x457580) == 1 && word(0x4511b8) == 0 else { return }
            try put(0x457580,0)
            try OriginalQueuedSound.play(bufferWordAddress: 0x455610,loop: 0,globals: state) {
                try emit($0.kind.rawValue,$0.arguments);return input.methodResult
            }
            try emit("sleep",[300]);try emit("shell",[0,0,0,1],[Array("open".utf8),bytes])
        }
        if try word(0x4511c0) == 0 { try put(0x4511c0,now()) }
        if try now() &- word(0x4511c0) <= 33 {
            let delay = Int32(bitPattern: try word(0x4511c0) &- now() &+ 33)
            if delay > 0 { try emit("sleep",[UInt32(min(delay,5))]) }
            globals = state;libraryText = text;return
        }
        let nextTime = try now(), previous = try word(0x4511c0)
        let base = try nextTime &- previous > 100 ? now() &- 100 : previous
        try put(0x4511c0,base &+ 33)
        try bitmap(0x45118c,0,0,-1,0)
        let phase = (try signed(0x4511bc) &+ 1) % 10
        try put(0x4511bc,bits(phase))
        let color: UInt32 = phase < 2 ? 0xffffff : (bits(phase &- 5) <= 2 ? 0x99 : 0xff)
        try text.draw(Array("Loading files".utf8),target: word(0x455608),background: 0,color: color,
                      x: 608,y: 60,dcResult: input.dcResult,dc: input.dc) { try emit($0.kind.rawValue,$0.arguments,$0.strings) }
        var minimumX: Int32 = 999,minimumY: Int32 = 999
        let panel = try word(0x458420)
        if panel != 0 {
            let first = try panelFirstWord(panel);try emit("panelRead",[panel,first])
            if first != 0 {
                for slot in 0..<8 {
                    let address = 0x4546f8+slot*100
                    guard try state.integer(at: address-0x44d000,as: UInt8.self) != 0x3f else { continue }
                    let column = slot%4,x = Int32(1+198*column),y = Int32(142+194*(slot/4))
                    try put(0x458418,UInt32(slot))
                    try bitmap(0x458420,x,y,Int32(slot+2))
                    minimumX = min(minimumX,x);minimumY = min(minimumY,y)
                    if try signed(0x4546f0) > x && (signed(0x4546f0) < x+198 || column == 3) && signed(0x453cdc) > y && signed(0x453cdc) < y+194 {
                        for rectangle: [Int32] in [[x,y,198,1],[x,y+193,198,1],[x,y,1,194],[x+197,y,1,194]] {
                            try emit("fillCall",rectangle.map(bits)+[0xffffff])
                            let request = try OriginalSurfaceFilling.request(target: word(0x455608),x: rectangle[0],y: rectangle[1],
                                width: rectangle[2],height: rectangle[3],color: 0xffffff,backing: fillBacking())
                            var event = OriginalFrontScreenEvent("fill");event.fill = request;try checkpoint(state);try observe(event);_ = try performFill(request)
                        }
                        if try word(0x457580) == 1 && word(0x4511b8) == 0 { try click(string(address)) }
                    }
                }
                if minimumX < 999 && minimumY < 999 { try bitmap(0x451188,minimumX,minimumY &- 10,12) }
            }
        }
        try bitmap(0x451188,0,535,14)
        if try word(0x4546f0) &- 1 <= 145 && signed(0x453cdc) >= 535 {
            try bitmap(0x451188,0,535,13)
            try click(Array("http://www.littlefighter.com/advertise".utf8))
        }
        try put(0x4511b8,word(0x457580))
        try bitmap(0x451170,min(775,signed(0x4546f0)),min(535,signed(0x453cdc) &+ 2),-1)
        try emit("stage",[0x4028a0])
        // Overlay owns a separate candidate during its inout call. Its own
        // writes update the observer view without reading borrowed storage.
        var overlayState = state
        try OriginalMenuPresentation.overlayWithLibrary(globals: &overlayState,libraryText: &text,input: input,store: { address,bytes in
            for (i,byte) in bytes.enumerated() { try state.write(byte,at:address-0x44d000+i) }
        }) { try emit($0.kind.rawValue,$0.arguments,$0.strings) }
        state = overlayState
        try emit("stage",[0x43e940])
        try OriginalMenuPresentation.presentSurface(globals: state) { try emit($0.kind.rawValue,$0.arguments,$0.strings) }
        try processMessage(message: message) { try checkpoint(state);try observe($0) }
        globals = state;libraryText = text
    }

    /// Whole43d230, shared by loading-progress and the Object token countdown.
    /// The caller stages any external message effects until its operation commits.
    public static func processMessage(
        message: (String,[UInt8]) throws -> MessageResponse,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        func bits(_ n: Int32) -> UInt32 { UInt32(bitPattern: n) }
        func emit(_ kind: String,_ args: [UInt32] = [],_ strings: [[UInt8]] = []) throws {
            try observe(.init(kind,args,strings))
        }
        //43d230 processes at most one message. GetMessage -1 is nonzero here.
        let peek = try message("PeekMessageA",[])
        try emit("PeekMessageA",[bits(peek.result),0,0,0,0],peek.result != 0 ? [peek.bytes] : [])
        if peek.result != 0 {
            let get = try message("GetMessageA",peek.bytes)
            try emit("GetMessageA",[bits(get.result),0,0,0],get.result != 0 ? [get.bytes] : [])
            if get.result != 0 {
                guard get.bytes.count == 28 else { throw OriginalStateError.invalidStorage("Loading MSG extent") }
                _ = try message("TranslateMessage",get.bytes);try emit("TranslateMessage",[],[get.bytes])
                _ = try message("DispatchMessageA",get.bytes);try emit("DispatchMessageA",[],[get.bytes])
            }
        }
    }
}
