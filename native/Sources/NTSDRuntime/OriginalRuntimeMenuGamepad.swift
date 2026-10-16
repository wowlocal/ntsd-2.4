/// The title menu with a game controller: a departure from the original that
/// the user asked for on 2026-10-16 (MENU_GAMEPAD.md). The original's title
/// (START … OFFICAL WEBSITE) reads only the mouse: the cursor WM_MOUSEMOVE
/// stores at 4546f0/453cdc and the left button at 457580, a click counting on
/// the press edge (MAIN_MENU.md, `OriginalMainMenu`). While the title shows,
/// the captured joysticks also drive that mouse: up and down move the cursor
/// from item to item, so the original's hover highlight and cursor sprite
/// follow, and button 1 presses the left button on the item. The MM_JOY
/// messages are posted as before; every other screen, the mode menu included,
/// reads the joysticks only as the original does. `--original-title-menu`
/// leaves it out.
@MainActor public final class OriginalRuntimeTitleGamepad {
    /// The items' rows relative to [453da4]+202, for x 276…520 (MAIN_MENU.md).
    static let rows: [ClosedRange<Int32>] = [15...39,45...70,77...102,107...132,137...162]
    static let columns: ClosedRange<Int32> = 276...520, x: Int32 = 398
    /// The left button stays down at least this long (game-clock ms) after the
    /// game took the press, so that a menu frame sees it, as touch holds its
    /// taps (`OriginalRuntimeTouchMouse`); it goes up at the latest after
    /// `longest` even if button 1 stays down (a controller lost while held).
    static let hold: UInt32 = 150, longest: UInt32 = 2000
    /// A held direction moves again after 400 ms, then every 180 ms.
    static let repeatDelay: UInt32 = 400, repeatEvery: UInt32 = 180
    /// [453da4]+202 while the title shows; nil on every other screen.
    let titleBase: () -> Int32?
    /// The item the controller last moved to, when the mouse is on none.
    private var row: Int?
    private var directions: [UInt32:Int] = [:], buttons: [UInt32:Bool] = [:]
    /// When a held direction moves again; only after a move on the title.
    private var nextRepeat: [UInt32:UInt32] = [:]
    /// The left button the controller holds down: its point, the joystick,
    /// when the game took the WM_LBUTTONDOWN, and whether button 1 is up.
    private var press: (id: UInt32,x: Int32,y: Int32,taken: UInt32?,released: Bool)?
    public init(titleBase: @escaping () -> Int32?) { self.titleBase = titleBase }

    /// One joystick sample (the WinMM words: up is small Y). The title and
    /// the clock are read only when the sample asks for a move or a press.
    /// `mouse` is the last WM_MOUSEMOVE point the game was sent (client coordinates).
    func sample(_ id: UInt32,y: UInt32,buttons state: UInt32,messages: OriginalMacRuntimeMessages,
                mouse: (Int32,Int32)?,now: () -> UInt32) {
        let offset = Int(y) - 32767,previous = directions[id] ?? 0
        let direction = offset < -16384 ? -1 : offset > 16384 ? 1 : abs(offset) < 8192 ? 0 : previous
        directions[id] = direction
        if direction == 0 { nextRepeat[id] = nil }
        else if direction != previous {
            if let base = titleBase() { move(direction,base:base,mouse:mouse,messages:messages); nextRepeat[id] = now() &+ Self.repeatDelay }
        } else if let due = nextRepeat[id] {
            let time = now()
            if Int32(bitPattern:time &- due) >= 0 {
                if let base = titleBase() { move(direction,base:base,mouse:mouse,messages:messages); nextRepeat[id] = time &+ Self.repeatEvery }
                else { nextRepeat[id] = nil }
            }
        }
        let down = state & 1 != 0,wasDown = buttons[id] ?? false
        buttons[id] = down
        if down && !wasDown && press == nil,let base = titleBase() {
            let item = current(base:base,mouse:mouse) ?? 0
            row = item
            let (x,y) = Self.center(item,base:base)
            messages.mouse(0x200,x:x,y:y,buttons:0); messages.mouse(0x201,x:x,y:y,buttons:1)
            press = (id,x,y,nil,false)
        } else if !down && wasDown,press?.id == id {
            press?.released = true
        }
        release(messages,now:now)
    }
    /// GetMessage delivered `message`: the hold starts when the game takes
    /// the controller's WM_LBUTTONDOWN.
    func delivered(_ message: UInt32,lParam: UInt32,now: () -> UInt32) {
        guard message == 0x201,let p = press,p.taken == nil,lParam == Self.packed(p.x,p.y) else { return }
        press?.taken = now()
    }
    /// The left button goes up once the game took the press and button 1 is
    /// up after `hold`, or after `longest`; checked at each sample and at each
    /// PeekMessage. The release is posted even when the title has gone.
    func release(_ messages: OriginalMacRuntimeMessages,now: () -> UInt32) {
        guard let p = press,let taken = p.taken else { return }
        let held = now() &- taken
        guard held >= Self.longest || (p.released && held >= Self.hold) else { return }
        press = nil
        messages.mouse(0x202,x:p.x,y:p.y,buttons:0)
    }
    /// The item under the game's cursor (the last WM_MOUSEMOVE), else the one last moved to.
    private func current(base: Int32,mouse: (Int32,Int32)?) -> Int? {
        mouse.flatMap { Self.item(at:$0,base:base) } ?? row
    }
    private func move(_ direction: Int,base: Int32,mouse: (Int32,Int32)?,messages: OriginalMacRuntimeMessages) {
        let count = Self.rows.count
        row = current(base:base,mouse:mouse).map { ($0 + direction + count) % count } ?? 0
        let (x,y) = Self.center(row ?? 0,base:base)
        messages.mouse(0x200,x:x,y:y,buttons:press == nil ? 0 : 1)
    }
    static func packed(_ x: Int32,_ y: Int32) -> UInt32 { UInt32(UInt16(truncatingIfNeeded:x)) | UInt32(UInt16(truncatingIfNeeded:y)) << 16 }
    static func center(_ item: Int,base: Int32) -> (Int32,Int32) {
        let r = rows[item]
        return (x,base &+ (r.lowerBound + r.upperBound) / 2)
    }
    static func item(at p: (Int32,Int32),base: Int32) -> Int? {
        guard columns.contains(p.0) else { return nil }
        return rows.firstIndex { p.1 >= base &+ $0.lowerBound && p.1 <= base &+ $0.upperBound }
    }
}
