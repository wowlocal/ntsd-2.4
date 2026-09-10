/// Whole original lifecycle-message returns, with actual display recreation
/// composed from the accepted initializer. API responses remain explicit;
/// callback delivery/reentrancy and real macOS/Windows devices are not inferred.
public enum OriginalWindowLifecycle {
    public typealias Request = OriginalWindowInitialization.Request
    public typealias Response = OriginalWindowInitialization.Response
    private static let base = OriginalMatchPreparation.globalBase
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Window lifecycle: "+text) }
    private static func bytes(_ value: UInt32) -> [UInt8] {
        (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0*8)) }
    }
    public static func receive(_ input: OriginalWindowInput.Message,
        globals: inout OriginalStateRecord, memory: inout OriginalMenuPresentationMemory,
        backing: (String, Int) throws -> [UInt8], perform: (Request) throws -> Response,
        store: OriginalWindowInput.Store = { _,_ in }) throws -> Int32 {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else { throw error("Globals extent") }
        var state = globals, owned = memory
        func word(_ address: Int) throws -> UInt32 { try state.integer(at: address-base,as: UInt32.self) }
        func put(_ address: Int, _ value: UInt32) throws {
            try state.write(value,at: address-base);try store(address,bytes(value))
        }
        func numeric(_ kind: String, _ words: [UInt32] = []) throws -> Int32 {
            try perform(.init(kind,words)).result
        }
        func debug(_ text: String) throws { _ = try perform(.init("debug",strings: [Array(text.utf8)])) }
        func rectangle(_ kind: String, _ words: [UInt32],address: Int,count: Int) throws {
            let range = (address-base)..<(address-base+count)
            let before = try OriginalStateRecord(bytes: Array(state.bytes[range]),defined: Array(state.defined[range]))
            let response = try perform(.init(kind,words,structure: before))
            if let output = response.bytes {
                guard output.count == count else { throw error("Rectangle output extent") }
                for (i,b) in output.enumerated() { try state.write(b,at: address-base+i) }
                try store(address,output)
            }
        }
        func releaseDisplay() throws {
            if try word(0x457578) == 0 { return }
            for address in [0x455608,0x455634] {
                let pointer = try word(address)
                if pointer != 0 { _ = try numeric("release",[pointer]);try put(address,0) }
            }
            _ = try numeric("release",[word(0x457578)]);try put(0x457578,0)
        }
        var returned: Int32?
        switch input.message {
        case 2:
            try OriginalMenuPresentation.releaseResources(globals: &state,memory: &owned,observe: { event in
                switch event.kind {
                case .method:
                    guard event.arguments.count == 2,event.arguments[1] == 8 else { throw error("Unexpected cleanup method") }
                    _ = try perform(.init("release",[event.arguments[0]]))
                case .free:_ = try perform(.init("free",event.arguments))
                default:throw error("Unexpected cleanup request")
                }
            },wrote: { address,value in try store(address,bytes(value)) })
            if try word(0x458434) == 0 { _ = try numeric("postQuit",[0]) }
            returned = 0
        case 3:
            if try word(0x458430) != 0 {
                let height = UInt32(bitPattern: try numeric("metric",[1]))
                let width = UInt32(bitPattern: try numeric("metric",[0]))
                try rectangle("setRect",[0x453ccc,0,0,width,height],address: 0x453ccc,count: 16)
            } else {
                try rectangle("clientRect",[input.window,0x453ccc],address: 0x453ccc,count: 16)
                try rectangle("screenPoint",[input.window,0x453ccc],address: 0x453ccc,count: 8)
                try rectangle("screenPoint",[input.window,0x453cd4],address: 0x453cd4,count: 8)
            }
        case 5:
            if input.wParam == 1 {
                _ = try numeric("invalidate",[input.window,0,1]);try put(0x451dac,0)
            } else { try put(0x451dac,1) }
            returned = 0
        case 0x1c:try debug("Active App!\n ")
        case 0x20:
            if try word(0x458430) != 0 { _ = try numeric("setCursor",[0]) }
            returned = 0
        case 0x105:
            if input.wParam == 13 {
                try debug("Alt enter...\n")
                if try word(0x44d794) != 0 {
                    let fullscreen = try word(0x458430) == 0
                    try put(0x458434,1);try put(0x458430,fullscreen ? 1 : 0)
                    try releaseDisplay()
                    let window = try word(0x4546f4)
                    if window != 0 { _ = try numeric("destroyWindow",[window]) }
                    _ = try OriginalWindowInitialization.configure(globals: &state,backing: backing,perform: perform,store: store)
                    //43bdd0 returns0/1, so its signed-negative debug branch
                    //cannot run. Even0 still reaches ShowWindow and flag clear.
                    _ = try numeric("showWindow",[word(0x4546f4),5])
                    try put(0x458434,0)
                }
            }
        case 0x112:if input.wParam == 0xf100 { returned = 1 }
        case 0x30f:
            if try word(0x455634) != 0 && word(0x4554c4) != 0 {
                try debug("We have the palette.\n")
                _ = try numeric("setPalette",[word(0x455634),word(0x4554c4)])
            } else { try debug("Ignoring palette message.\n");returned = 1 }
        case 0x311:
            if input.wParam != input.window {
                try debug("Palette lost.\n")
                let primary = try word(0x455634)
                guard primary != 0 else { throw error("External palette notification has no primary surface") }
                _ = try numeric("setPalette",[primary,word(0x4554c4)])
            }
        case 0x100,0x101,0x200...0x205,0x3a0,0x3a1,0x3b5...0x3b8:
            throw error("Input message belongs to OriginalWindowInput")
        case 0x400,0x401:throw error("Unrecovered graph/network notification")
        default:break // The original static dispatch reaches DefWindowProc.
        }
        let result: Int32
        if let returned { result = returned }
        else { result = try numeric("windowDefault",[input.window,input.message,input.wParam,input.lParam]) }
        globals = state;memory = owned;return result
    }
}
