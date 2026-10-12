// The page's side of the browser host (TVOS_WEB W2b): functions of the "ntsd"
// import module that tools/crossplatform/web/wasi-worker.js provides when the
// page gives the worker a canvas. The worker never yields while the game runs,
// so page-to-worker traffic goes through shared memory the page fills.

/// Shows a finished crop: `width × height` XRGB8888 words (little-endian
/// 0x00RRGGBB, `OriginalFramebuffer`'s layout) at `pixels`.
@_extern(wasm, module: "ntsd", name: "present")
func ntsdPresent(_ pixels: UnsafeRawPointer, _ width: Int32, _ height: Int32)

/// Copies up to `capacity` pending input events from the page, five Int32
/// each (`WebInput.Event`), to `events`; returns how many it copied.
@_extern(wasm, module: "ntsd", name: "input")
func ntsdInput(_ events: UnsafeMutableRawPointer, _ capacity: Int32) -> Int32

/// The gamepads the page sees now (at most two).
@_extern(wasm, module: "ntsd", name: "gamepads")
func ntsdGamepads() -> Int32

/// Gamepad `id`'s state as four Int32: x and y (−32767...32767, y down, the
/// d-pad over the left stick), buttons (bits 0-3: A, B, X, Y), connected.
@_extern(wasm, module: "ntsd", name: "gamepad")
func ntsdGamepad(_ id: Int32, _ state: UnsafeMutableRawPointer)

/// Asks the page a question: `text` and `caption` (UTF-8) with the buttons
/// (UTF-8, each ending in a NUL); waits for the player and returns the index.
@_extern(wasm, module: "ntsd", name: "ask")
func ntsdAsk(_ text: UnsafeRawPointer, _ textCount: Int32, _ caption: UnsafeRawPointer, _ captionCount: Int32,
             _ buttons: UnsafeRawPointer, _ buttonsCount: Int32) -> Int32

/// Opens `url` (UTF-8) in a new tab.
@_extern(wasm, module: "ntsd", name: "open")
func ntsdOpen(_ url: UnsafeRawPointer, _ count: Int32)

/// Swift-side wrappers of the page functions.
enum WebInput {
    /// kind 1, a key: a = USB HID usage, b = 1 down | 2 repeated, c = the
    /// typed character's Unicode scalar (0: none), d = Caps Lock on.
    /// kind 2, the mouse: a = window message (0x200-0x205), b, c = client
    /// x, y in the crop's pixels, d = MK_LBUTTON | MK_RBUTTON.
    /// kind 3, a modifier state: a = Caps Lock on.
    struct Event { var kind: Int32, a: Int32, b: Int32, c: Int32, d: Int32 }
    static func drain() -> [Event] {
        var events = [Event](repeating:.init(kind:0,a:0,b:0,c:0,d:0),count:64)
        let count = events.withUnsafeMutableBytes { Int(ntsdInput($0.baseAddress!,64)) }
        return Array(events.prefix(max(0,min(count,64))))
    }
    static func gamepad(_ id: Int) -> (x: Int32,y: Int32,buttons: UInt32,connected: Bool) {
        var state = [Int32](repeating:0,count:4)
        state.withUnsafeMutableBytes { ntsdGamepad(Int32(id),$0.baseAddress!) }
        return (state[0],state[1],UInt32(bitPattern:state[2]),state[3] != 0)
    }
    static func ask(text: String,caption: String,buttons: [String]) -> Int {
        let t = Array(text.utf8),c = Array(caption.utf8)
        var b: [UInt8] = []   // each button's UTF-8 and a NUL (typed: an untyped flatMap here infers [[Any]])
        for button in buttons { b += button.utf8; b.append(0) }
        return t.withUnsafeBytes { tp in c.withUnsafeBytes { cp in b.withUnsafeBytes { bp in
            Int(ntsdAsk(tp.baseAddress ?? UnsafeRawPointer(bitPattern:1)!,Int32(t.count),cp.baseAddress ?? UnsafeRawPointer(bitPattern:1)!,Int32(c.count),
                        bp.baseAddress ?? UnsafeRawPointer(bitPattern:1)!,Int32(b.count)))
        } } }
    }
    static func open(_ url: String) {
        let u = Array(url.utf8)
        u.withUnsafeBytes { ntsdOpen($0.baseAddress ?? UnsafeRawPointer(bitPattern:1)!,Int32(u.count)) }
    }
}
