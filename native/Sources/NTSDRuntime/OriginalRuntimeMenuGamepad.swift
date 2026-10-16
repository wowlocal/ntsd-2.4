/// The front screens with a game controller: a departure from the original
/// that the user asked for on 2026-10-16 (MENU_GAMEPAD.md). Before loading,
/// the original's screens — the title, CONTROL SETTINGS, the network screens,
/// RECORDING INFO — read only the mouse: the cursor WM_MOUSEMOVE stores at
/// 4546f0/453cdc and the left button at 457580 (MAIN_MENU.md). While one of
/// them shows, the captured joysticks also drive that mouse: the stick or
/// d-pad moves the cursor to the nearest click target in that direction, so
/// the original's hover highlights and cursor sprite follow, and button 1
/// presses the left button on the target. The MM_JOY messages are posted as
/// before; the mode menu and everything after it read the joysticks only as
/// the original does. `--original-menu-input` leaves it out.
@MainActor public final class OriginalRuntimeMenuGamepad {
    /// A click target in client coordinates, bounds inclusive.
    public struct Target: Equatable {
        public let left: Int32, top: Int32, right: Int32, bottom: Int32
        public init(_ left: Int32,_ top: Int32,_ right: Int32,_ bottom: Int32) {
            self.left = left; self.top = top; self.right = right; self.bottom = bottom
        }
        public var center: (Int32,Int32) { ((left + right) / 2,(top + bottom) / 2) }
        public func contains(_ p: (Int32,Int32)) -> Bool { p.0 >= left && p.0 <= right && p.1 >= top && p.1 <= bottom }
    }
    /// A mouse-only screen as the controller sees it: its identity (a new
    /// one forgets the selection), its targets, the one selected when the
    /// cursor is on none, and the joystick whose buttons are left to the game
    /// (a CONTROL SETTINGS cell waiting for one of its buttons).
    public struct Screen: Equatable {
        public let id: Int, targets: [Target], initial: Int, buttonsToGame: UInt32?
        public init(id: Int,targets: [Target],initial: Int = 0,buttonsToGame: UInt32? = nil) {
            self.id = id; self.targets = targets; self.initial = initial; self.buttonsToGame = buttonsToGame
        }
    }
    enum Direction: Equatable { case up, down, left, right }
    /// The left button stays down at least this long (game-clock ms) after the
    /// game took the press, so that a menu frame sees it, as touch holds its
    /// taps (`OriginalRuntimeTouchMouse`); it goes up at the latest after
    /// `longest` even if button 1 stays down (a controller lost while held).
    static let hold: UInt32 = 150, longest: UInt32 = 2000
    /// A held direction moves again after 400 ms, then every 180 ms.
    static let repeatDelay: UInt32 = 400, repeatEvery: UInt32 = 180
    /// The mouse-only screen showing now; nil on every other screen.
    let screen: () -> Screen?
    /// The target the controller last moved to, on screen `selected.screen`.
    private var selected: (screen: Int,target: Int)?
    private var axes: [UInt32:(x: Int,y: Int)] = [:], directions: [UInt32:Direction] = [:], buttons: [UInt32:Bool] = [:]
    /// Joysticks whose button 1 is the menu's left button until it is up: the
    /// MM_JOY messages do not show it (a CONTROL SETTINGS cell would otherwise
    /// take it as the button to bind, and the mode menu as a confirmation).
    private var claimed: Set<UInt32> = []
    /// When a held direction moves again; only after a move on a menu screen.
    private var nextRepeat: [UInt32:UInt32] = [:]
    /// The left button the controller holds down: its point, the joystick,
    /// when the game took the WM_LBUTTONDOWN, and whether button 1 is up.
    private var press: (id: UInt32,x: Int32,y: Int32,taken: UInt32?,released: Bool)?
    public init(screen: @escaping () -> Screen?) { self.screen = screen }

    /// One joystick sample (the WinMM words: up is small Y), before its MM_JOY
    /// messages; returns the buttons those must not show. The screen and the
    /// clock are read only when the sample asks for a move or a press.
    /// `mouse` is the last WM_MOUSEMOVE point the game was sent (client coordinates).
    func sample(_ id: UInt32,x: UInt32,y: UInt32,buttons state: UInt32,messages: OriginalMacRuntimeMessages,
                mouse: (Int32,Int32)?,now: () -> UInt32) -> UInt32 {
        func axis(_ word: UInt32,_ previous: Int) -> Int {
            let offset = Int(word) - 32767
            return offset < -16384 ? -1 : offset > 16384 ? 1 : abs(offset) < 8192 ? 0 : previous
        }
        let last = axes[id] ?? (0,0),ax = axis(x,last.x),ay = axis(y,last.y)
        axes[id] = (ax,ay)
        // The axis pushed further wins a diagonal.
        let vertical = ay != 0 && (ax == 0 || abs(Int(y) - 32767) >= abs(Int(x) - 32767))
        let direction: Direction? = vertical ? (ay < 0 ? .up : .down) : ax < 0 ? .left : ax > 0 ? .right : nil
        let previous = directions[id]
        directions[id] = direction
        if let direction {
            if direction != previous {
                if let s = screen() { move(direction,on:s,mouse:mouse,messages:messages); nextRepeat[id] = now() &+ Self.repeatDelay }
            } else if let due = nextRepeat[id] {
                let time = now()
                if Int32(bitPattern:time &- due) >= 0 {
                    if let s = screen() { move(direction,on:s,mouse:mouse,messages:messages); nextRepeat[id] = time &+ Self.repeatEvery }
                    else { nextRepeat[id] = nil }
                }
            }
        } else { nextRepeat[id] = nil }
        let down = state & 1 != 0,wasDown = buttons[id] ?? false
        buttons[id] = down
        if down && !wasDown && press == nil,let s = screen(),s.buttonsToGame != id,!s.targets.isEmpty {
            let target = current(on:s,mouse:mouse) ?? s.initial
            selected = (s.id,target)
            let (x,y) = s.targets[target].center
            messages.mouse(0x200,x:x,y:y,buttons:0); messages.mouse(0x201,x:x,y:y,buttons:1)
            press = (id,x,y,nil,false); claimed.insert(id)
        } else if !down && wasDown,press?.id == id {
            press?.released = true
        }
        if !down { claimed.remove(id) }
        release(messages,now:now)
        return claimed.contains(id) ? 1 : 0
    }
    /// GetMessage delivered `message`: the hold starts when the game takes
    /// the controller's WM_LBUTTONDOWN.
    func delivered(_ message: UInt32,lParam: UInt32,now: () -> UInt32) {
        guard message == 0x201,let p = press,p.taken == nil,lParam == Self.packed(p.x,p.y) else { return }
        press?.taken = now()
    }
    /// The left button goes up once button 1 is up and `hold` has passed since
    /// the game took the press, or after `longest`; checked at each sample and
    /// at each PeekMessage. The release is posted even when the screen has gone.
    func release(_ messages: OriginalMacRuntimeMessages,now: () -> UInt32) {
        guard let p = press,let taken = p.taken else { return }
        let held = now() &- taken
        guard held >= Self.longest || (p.released && held >= Self.hold) else { return }
        press = nil
        messages.mouse(0x202,x:p.x,y:p.y,buttons:0)
    }
    /// The target under the game's cursor (the last WM_MOUSEMOVE), else the
    /// one last moved to on this screen.
    private func current(on s: Screen,mouse: (Int32,Int32)?) -> Int? {
        if let mouse,let i = s.targets.firstIndex(where: { $0.contains(mouse) }) { return i }
        if let selected,selected.screen == s.id,selected.target < s.targets.count { return selected.target }
        return nil
    }
    private func move(_ direction: Direction,on s: Screen,mouse: (Int32,Int32)?,messages: OriginalMacRuntimeMessages) {
        guard !s.targets.isEmpty else { return }
        let target = current(on:s,mouse:mouse).map { Self.next(from:$0,direction,in:s.targets) } ?? s.initial
        selected = (s.id,target)
        let (x,y) = s.targets[target].center
        messages.mouse(0x200,x:x,y:y,buttons:press == nil ? 0 : 1)
    }
    /// The next target in `direction`: among those whose centre lies that way,
    /// the nearest of the ones in the same row or column band (overlapping
    /// across), else of those within 45° of the direction, else of those at
    /// least 16 px that way — nearest by the distance along plus twice the
    /// distance across. With none, the wrap: the farthest the other way, from
    /// the same band, else within 45°.
    static func next(from index: Int,_ direction: Direction,in targets: [Target]) -> Int {
        let c = targets[index],(cx,cy) = c.center
        func split(_ t: Target) -> (along: Int,across: Int,band: Bool) {
            let (x,y) = t.center,dx = Int(x) - Int(cx),dy = Int(y) - Int(cy)
            let columns = t.left <= c.right && t.right >= c.left,rows = t.top <= c.bottom && t.bottom >= c.top
            switch direction {
            case .up: return (-dy,abs(dx),columns)
            case .down: return (dy,abs(dx),columns)
            case .left: return (-dx,abs(dy),rows)
            case .right: return (dx,abs(dy),rows)
            }
        }
        let others = targets.indices.filter { $0 != index }.map { ($0,split(targets[$0])) }
        func pick(_ candidates: [(Int,(along: Int,across: Int,band: Bool))],far: Bool) -> Int? {
            let tiers = [candidates.filter { $0.1.band },candidates.filter { $0.1.across <= abs($0.1.along) },
                         far ? candidates.filter { abs($0.1.along) >= 16 } : []]
            return tiers.first { !$0.isEmpty }?.min { $0.1.along + 2 * $0.1.across < $1.1.along + 2 * $1.1.across }?.0
        }
        return pick(others.filter { $0.1.along > 0 },far:true) ?? pick(others.filter { $0.1.along < 0 },far:false) ?? index
    }
    static func packed(_ x: Int32,_ y: Int32) -> UInt32 { UInt32(UInt16(truncatingIfNeeded:x)) | UInt32(UInt16(truncatingIfNeeded:y)) << 16 }

    /// The mouse-only front screen of selector 44d064 (`word` reads a global),
    /// with the click targets of the recovered code; links to web pages and
    /// folders, the title's Update button and the bottom-left exit hotspot are
    /// left to the mouse. Nil for any other selector.
    public static func screen(selector: Int32,word: (Int) -> Int32?) -> Screen? {
        typealias T = Target
        switch selector {
        case 0:
            // START … OFFICAL WEBSITE: rows relative to [453da4]+202 for x 276…520 (`OriginalMainMenu`).
            guard let top = word(0x453da4) else { return nil }
            let base = top &+ 202
            return .init(id:0,targets:[(15,39),(45,70),(77,102),(107,132),(137,162)].map { T(276,base &+ $0.0,520,base &+ $0.1) })
        case -3:
            // The update panel: Enable, Disable and, folded, the description
            // (`OriginalFrontScreenAlternate`; y 96, or the panel's moving top).
            guard let stored = word(0x4511f4) else { return nil }
            let y = stored == 0 ? 96 : stored
            var targets = [T(209,y &+ 175,442,y &+ 202),T(465,y &+ 175,552,y &+ 202)]
            if stored == 0 { targets.append(T(203,y &+ 241,561,y &+ 261)) }
            return .init(id:-3,targets:targets)
        case -1: return .init(id:-1,targets:[T(331,320,481,345)])                          // waiting: Cancel
        case 1:                                                                             // Waiting, Connect, Back
            return .init(id:1,targets:[T(260,274,547,300),T(260,305,547,330),T(260,336,547,361)])
        case 2,4: return .init(id:Int(selector),targets:[T(322,361,472,386)])               // Cancel / Back
        case 3: return .init(id:3,targets:[T(239,357,389,382),T(411,357,561,382)])          // address: OK, Cancel
        case 6:
            // CONTROL SETTINGS (`OriginalFrontControlSettings`): per player
            // (x 194+139·p) the name, the device box and the key cells a
            // click can select (a joystick's four direction rows cannot be
            // set); then OK and Cancel. A cell waiting for a joystick button
            // leaves that joystick's buttons to the game.
            var targets: [T] = []
            for player in 0..<4 {
                let x = Int32(194+139*player),device = word(0x44fb70+80*player) ?? 0
                targets += [T(x,156,x+105,173),T(x,182,x+105,272)]
                for row in 0..<7 where device == 0 || row > 3 { targets.append(T(x,Int32(280+22*row),x+105,Int32(298+22*row))) }
            }
            targets += [T(405,441,560,465),T(582,441,737,465)]
            var capture: UInt32?
            if let cell = word(0x4511e0),cell > 0,let device = word(0x44fb70+Int(cell/20)*80),device > 0 { capture = UInt32(device-1) }
            return .init(id:6,targets:targets,initial:targets.count-2,buttonsToGame:capture)
        case 7:
            // RECORDING INFO (`OriginalFrontRecordingInfo`): the name, info and
            // email fields, the recording checkbox, OK and Cancel.
            return .init(id:7,targets:[T(210,207,730,225),T(210,232,730,302),T(210,309,730,327),T(287,390,306,409),
                                       T(231,416,386,440),T(403,416,558,440)],initial:4)
        case 8: return .init(id:8,targets:[T(318,382,472,406)])                             // the recording notice: OK
        default: return nil
        }
    }
}
