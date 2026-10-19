// The page's side of the browser host (TVOS_WEB W2b): functions of the "ntsd"
// import module that tools/crossplatform/web/wasi-worker.js provides when the
// page gives the worker a canvas. The worker never yields while the game runs,
// so page-to-worker traffic goes through shared memory the page fills.

/// TextOutA's glyph mask from the page's fonts: the `count` bytes (UTF-8)
/// drawn white, 13 px em, bold, at x 4 on an (advance + 8) × 24 cell with the
/// baseline at row 17 (the 16-pixel cell's +13 under a 4-pixel margin), written
/// to `out` as one 0/1 byte per pixel when it holds width × 24 bytes. Returns
/// the advance (the mask is not written when it does not fit), or −1 when the
/// page has no font service (the text is blank, as on the headless host).
@_extern(wasm, module: "ntsd", name: "text")
func ntsdText(_ bytes: UnsafeRawPointer, _ count: Int32, _ out: UnsafeMutableRawPointer, _ capacity: Int32) -> Int32

/// Shows a finished crop: `width × height` XRGB8888 words (little-endian
/// 0x00RRGGBB, `OriginalFramebuffer`'s layout) at `pixels`; `popup` 1 when
/// it is the game's full-screen popup's (Alt+Enter), which fills the page
/// even in the original format (WINDOW_SCALING S2).
@_extern(wasm, module: "ntsd", name: "present")
func ntsdPresent(_ pixels: UnsafeRawPointer, _ width: Int32, _ height: Int32, _ popup: Int32)

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

/// The page's audio rate (the AudioContext's), 0 without sound output.
@_extern(wasm, module: "ntsd", name: "audioRate")
func ntsdAudioRate() -> Int32

/// Frames the page's sound ring takes now, up to its target fill.
@_extern(wasm, module: "ntsd", name: "audioSpace")
func ntsdAudioSpace() -> Int32

/// Appends `frames` interleaved stereo Float32 frames to the sound ring.
@_extern(wasm, module: "ntsd", name: "audioWrite")
func ntsdAudioWrite(_ samples: UnsafeRawPointer, _ frames: Int32)

/// Frames the page played without the ring having them (the loop stalled)
/// or could not play (a suspended context) since the last call.
@_extern(wasm, module: "ntsd", name: "audioOwed")
func ntsdAudioOwed() -> Int32

/// 1 when a read of the file at `path` (UTF-8) would not wait for the
/// network: the page's loader holds the whole file, cannot bring it (the
/// read then fails), or does not serve it. 0 while it is still on its way,
/// and the first 0 asks the loader to fetch it (TVOS_WEB W5: a packaged
/// track arrives while the menu runs instead of the menu waiting for it).
@_extern(wasm, module: "ntsd", name: "fileReady")
func ntsdFileReady(_ path: UnsafeRawPointer, _ count: Int32) -> Int32

enum WebFiles {
    static func ready(_ path: String) -> Bool {
        let p = Array(path.utf8)
        return p.withUnsafeBytes { ntsdFileReady($0.baseAddress ?? UnsafeRawPointer(bitPattern:1)!,Int32(p.count)) } != 0
    }
}

/// Swift-side wrappers of the page functions.
enum WebInput {
    /// kind 1, a key: a = USB HID usage, b = 1 down | 2 repeated, c = the
    /// typed character's Unicode scalar (0: none), d = Caps Lock on.
    /// kind 2, the mouse: a = window message (0x200-0x205), b, c = client
    /// x, y in the crop's pixels, d = MK_LBUTTON | MK_RBUTTON.
    /// kind 3, a modifier state: a = Caps Lock on.
    /// kind 4, the page's focus: a = focused and visible (DirectSound's
    /// foreground rule for the sound).
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
