import Foundation

// On-screen controls for hosts whose only input may be the touch screen
// (iPhone, iPad, Android; docs/research/TOUCH_CONTROLS.md). Proposed, with a
// working Android version, by StormPixels (2026-10-18); its model, layout,
// drawing and settings are kept, shared here so every touch host behaves
// alike.
//
//   - Four round direction buttons and three action buttons (attack, jump,
//     defend, marked A, J and D as the move lists write them) press the keys
//     a keyboard would, so the game's own control settings decide what they
//     do. The defaults are Player 1's keys in the original data/control.txt:
//     W, S, A, D, J (attack), K (jump), L (defend). A finger on two
//     overlapping buttons holds both (diagonals, once enlarged or moved
//     together); sliding between buttons works; several fingers work at once.
//   - A round "F" button at the top left opens a grid of F1-F9 and Esc
//     below it.
//   - A round button at the top centre shows or hides the seven buttons.
//   - A "SET" button at the top right opens the settings: drag a button to
//     move it, change its size (+ / -) and its key (KEY opens a key grid),
//     and the opacity of each group (PAD, ACT, F, MENU). DONE closes them,
//     RESET restores the defaults.
//   - While a keyboard or gamepad is connected (the host reports it) nothing
//     is shown and every touch is the mouse, as before; a host option can
//     force them on or off (`--touch-controls on|off`).
//
// A declared host addition, not part of the original (its window always had
// a keyboard): the game's frame is unchanged, hosts draw the overlay over it
// on screen only, and a finger that begins on empty screen is the mouse
// exactly as before.
//
// Coordinates are the host's canvas (Android: the surface buffer's pixels;
// iOS: the view's points), y down. The layout unit is a ninth of the canvas
// height, at most `maxUnit` (48 points or dp in the canvas's units, which the
// host gives): a button is then at most about 82 points across, about 13 mm
// on a phone and 16 mm on an iPad, instead of growing with the screen. The
// buttons sit at fixed distances, in units, from the bottom corners (on the
// Galaxy A12 the proposal's places); a button the player moves keeps its
// centre as fractions of the canvas.
//
// The settings file (`controls.txt`, also editable by hand), one line each:
//   show on|off                                (the seven buttons shown)
//   up key=w size=1.000 x=0.175 y=0.528        (x, y: fractions, only for a
//                                               moved button; size 1 normal)
//   opacity pad=7 action=7 function=7 menu=7   (1-10)
// The older form `up W` still reads.

@MainActor public final class OriginalTouchControls {
    public enum Control: String, CaseIterable, Sendable {
        case up, down, left, right, attack, jump, defend
        case f1, f2, f3, f4, f5, f6, f7, f8, f9, escape
    }
    public enum Group: Int, CaseIterable, Sendable { case pad, action, function, menu }
    /// A button's key, its centre as fractions of the canvas (nil: its place
    /// by the corner) and its size.
    public struct Spec: Equatable, Sendable {
        public var usage: UInt32, x: Float?, y: Float?, size: Float
        public init(usage: UInt32,x: Float? = nil,y: Float? = nil,size: Float = 1) { self.usage = usage; self.x = x; self.y = y; self.size = size }
    }
    /// The layout unit's cap in points (iOS) or dp (Android): the host gives
    /// it in canvas units (`layout`, `render`).
    public nonisolated static let maxUnitPoints: Float = 48
    public enum MousePhase: Sendable { case began, moved, ended }
    enum Widget: Equatable {
        case sizeMinus, sizePlus, keyButton, reset, done
        case opacityMinus(Group), opacityPlus(Group), pickKey(UInt32)
    }
    struct Key { let name: String, label: String, usage: UInt32 }

    nonisolated static let movable: [Control] = [.up,.down,.left,.right,.attack,.jump,.defend]
    nonisolated static let grid: [Control] = [.f1,.f2,.f3,.f4,.f5,.f6,.f7,.f8,.f9,.escape]
    public nonisolated static let defaultOpacity: [Group: Int] = [.pad:7,.action:7,.function:7,.menu:7]
    /// Player 1's keys in the original's data/control.txt (`0 87 83 65 68 74
    /// 75 76 …`: W, S, A, D, J, K, L), each at its place by the corner.
    public nonisolated static let defaultSpecs: [Control: Spec] = [
        .up: Spec(usage:0x1A), .down: Spec(usage:0x16), .left: Spec(usage:0x04), .right: Spec(usage:0x07),
        .attack: Spec(usage:0x0D), .jump: Spec(usage:0x0E), .defend: Spec(usage:0x0F),
    ]
    /// The proposal's places, which its files (and this one's first version)
    /// wrote for every button: read back as the place by the corner.
    nonisolated static let proposalPlaces: [Control: (Float,Float)] = [
        .up: (0.175,0.528), .down: (0.175,0.850), .left: (0.084,0.689), .right: (0.266,0.689),
        .attack: (0.903,0.817), .jump: (0.825,0.617), .defend: (0.728,0.828),
    ]
    /// The keys a button can be set to (USB HID usages, the table
    /// `OriginalHIDKeys` maps), in the order of the key grid.
    nonisolated static let keys: [Key] = {
        var list: [Key] = []
        for (i,ch) in "abcdefghijklmnopqrstuvwxyz".enumerated() { list.append(Key(name:String(ch),label:String(ch).uppercased(),usage:UInt32(0x04+i))) }
        for (i,ch) in "1234567890".enumerated() { list.append(Key(name:String(ch),label:String(ch),usage:i < 9 ? UInt32(0x1E+i) : 0x27)) }
        list += [Key(name:"up",label:"^",usage:0x52),Key(name:"down",label:"v",usage:0x51),
                 Key(name:"left",label:"<",usage:0x50),Key(name:"right",label:">",usage:0x4F),
                 Key(name:"space",label:"SPC",usage:0x2C),Key(name:"enter",label:"ENT",usage:0x28),
                 Key(name:"escape",label:"ESC",usage:0x29),Key(name:"tab",label:"TAB",usage:0x2B)]
        return list
    }()
    nonisolated static func usage(named name: String) -> UInt32? {
        let n = name.lowercased() == "esc" ? "escape" : name.lowercased()
        return keys.first { $0.name == n }?.usage
    }
    nonisolated static func keyName(_ usage: UInt32) -> String { keys.first { $0.usage == usage }?.name ?? "a" }
    nonisolated static func keyLabel(_ usage: UInt32) -> String { keys.first { $0.usage == usage }?.label ?? "?" }
    nonisolated static func group(of c: Control) -> Group {
        switch c {
        case .up,.down,.left,.right: return .pad
        case .attack,.jump,.defend: return .action
        default: return .function
        }
    }
    /// The character a keyboard types with this key (letters in lower case,
    /// digits, space), which hosts pass with a key press as for a hardware
    /// key; nil for the others.
    public nonisolated static func characters(_ usage: UInt32) -> String? {
        switch usage {
        case 0x04...0x1D: return String(UnicodeScalar(UInt8(0x61+usage-0x04)))
        case 0x1E...0x26: return String(usage-0x1E+1)
        case 0x27: return "0"
        case 0x2C: return " "
        default: return nil
        }
    }
    /// `--touch-controls on|off`: forced on or off; nil (absent) follows the
    /// connected keyboards and gamepads.
    public nonisolated static func forced(_ arguments: [String]) -> Bool? {
        guard let i = arguments.firstIndex(of:"--touch-controls"),i+1 < arguments.count else { return nil }
        switch arguments[i+1] { case "on": return true; case "off": return false; default: return nil }
    }

    // MARK: state

    public private(set) var visible: Bool
    public private(set) var functionsOpen = false, editing = false, picking = false
    public private(set) var selected: Control?
    /// The controls the fingers hold (drawn highlighted).
    public private(set) var pressed = Set<Control>()
    public private(set) var specs: [Control: Spec]
    public private(set) var opacity: [Group: Int]
    private let config: URL?

    /// Presses (true) or releases a key by its USB HID usage.
    public var key: @MainActor (UInt32,Bool) -> Void = { _,_ in }
    /// A finger that began on empty screen: the mouse, at a canvas point.
    public var mouse: @MainActor (MousePhase,Float,Float) -> Void = { _,_,_ in }
    /// The overlay looks different: the host renders it again (at most once
    /// per call into the controls).
    public var changed: @MainActor () -> Void = {}
    private var dirty = false
    private func notify() { if dirty { dirty = false; changed() } }

    /// A keyboard or gamepad is connected (the host reports it): the controls
    /// hide and let go.
    public var hardwareConnected = false { didSet { if hardwareConnected != oldValue { activeChanged() } } }
    /// The host's option (`forced(_:)`), over `hardwareConnected`.
    public var forced: Bool? { didSet { if forced != oldValue { activeChanged() } } }
    public var active: Bool { forced ?? !hardwareConnected }
    /// The canvas touches arrive in and the unit's cap in its units (set by
    /// the host before it routes them).
    public private(set) var canvas: (width: Float,height: Float) = (0,0)
    private var maxUnit = Float.infinity
    public func layout(width: Float,height: Float,maxUnit: Float) { canvas = (width,height); self.maxUnit = maxUnit }

    /// What the overlay shows, as a value, so a host may rasterize it on
    /// another thread (`render(width:height:)`).
    public struct Picture: Sendable, Equatable {
        let visible: Bool,functionsOpen: Bool,editing: Bool,picking: Bool
        let selected: Control?,pressed: Set<Control>
        let specs: [Control: Spec],opacity: [Group: Int]
    }
    private var current: Picture {
        Picture(visible:visible,functionsOpen:functionsOpen,editing:editing,picking:picking,
                selected:selected,pressed:pressed,specs:specs,opacity:opacity)
    }
    /// The overlay to show; nil while the controls are not active.
    public var picture: Picture? { active ? current : nil }
    /// The overlay at this size (the canvas's, or a multiple for a sharper
    /// picture); nil while the controls are not active.
    public func render(width: Int,height: Int,maxUnit: Float) -> OriginalTouchOverlay? { picture?.render(width:width,height:height,maxUnit:maxUnit) }
    /// A button's centre on the canvas.
    func center(_ c: Control) -> (x: Float,y: Float)? {
        current.buttons(Layout(width:canvas.width,height:canvas.height,maxUnit:maxUnit)).first { $0.control == c }.map { ($0.circle.x,$0.circle.y) }
    }

    public init(config: URL?) {
        self.config = config
        var specs = Self.defaultSpecs,opacity = Self.defaultOpacity,show = true
        if let config,let text = try? String(contentsOf:config,encoding:.utf8) {
            for raw in text.split(whereSeparator:{ $0 == "\n" || $0 == "\r" }) {
                let line = raw.split(separator:"#",maxSplits:1,omittingEmptySubsequences:false).first.map(String.init) ?? ""
                let words = line.split(whereSeparator:{ $0 == " " || $0 == "\t" }).map { $0.lowercased() }
                guard let head = words.first else { continue }
                var fields: [String: String] = [:],plain: [String] = []
                for w in words.dropFirst() {
                    if let eq = w.firstIndex(of:"=") { fields[String(w[..<eq])] = String(w[w.index(after:eq)...]) }
                    else { plain.append(w) }
                }
                if head == "show" {
                    if let v = plain.first { show = !(v == "off" || v == "0" || v == "no") }
                } else if head == "opacity" {
                    for (g,name) in [(Group.pad,"pad"),(.action,"action"),(.function,"function"),(.menu,"menu")] {
                        if let v = fields[name].flatMap({ Int($0) }) { opacity[g] = min(10,max(1,v)) }
                    }
                } else if let c = Control(rawValue:head),Self.movable.contains(c),var spec = specs[c] {
                    if let k = fields["key"] ?? plain.first,let u = Self.usage(named:k) { spec.usage = u }
                    if let x = fields["x"].flatMap({ Float($0) }),let y = fields["y"].flatMap({ Float($0) }),x.isFinite,y.isFinite,
                       Self.proposalPlaces[c].map({ abs($0.0-x) > 0.0005 || abs($0.1-y) > 0.0005 }) ?? true {
                        spec.x = min(1,max(0,x)); spec.y = min(1,max(0,y))
                    }
                    if let v = fields["size"].flatMap({ Float($0) }),v.isFinite { spec.size = min(2.5,max(0.5,v)) }
                    specs[c] = spec
                }
            }
        }
        self.specs = specs; self.opacity = opacity; visible = show
    }

    /// The USB HID usage a control presses.
    func usage(_ c: Control) -> UInt32? {
        if let spec = specs[c] { return spec.usage }
        if c == .escape { return 0x29 }
        if let i = Self.grid.firstIndex(of:c) { return UInt32(0x3A+i) }   // F1-F9
        return nil
    }

    /// Rewrites the settings file.
    func save() {
        guard let config else { return }
        func fixed(_ v: Float) -> String {
            let t = Int((max(0,v)*1000).rounded()),fraction = String(t%1000)
            return "\(t/1000)."+String(repeating:"0",count:3-fraction.count)+fraction
        }
        var lines = ["# NTSD on-screen controls. The in-game settings rewrite this file.",
                     "# x, y: fractions of the screen; size 1 = normal; opacity 1-10.",
                     "show \(visible ? "on" : "off")"]
        for c in Self.movable {
            guard let s = specs[c] else { continue }
            let place = s.x.flatMap { x in s.y.map { y in " x=\(fixed(x)) y=\(fixed(y))" } } ?? ""
            lines.append("\(c.rawValue) key=\(Self.keyName(s.usage)) size=\(fixed(s.size))"+place)
        }
        lines.append("opacity pad=\(opacity[.pad] ?? 7) action=\(opacity[.action] ?? 7) function=\(opacity[.function] ?? 7) menu=\(opacity[.menu] ?? 7)")
        try? (lines.joined(separator:"\n")+"\n").write(to:config,atomically:true,encoding:.utf8)
    }

    // MARK: layout

    struct Circle {
        var x: Float,y: Float,r: Float
        func near(_ px: Float,_ py: Float,_ reach: Float) -> Bool { ((px-x)*(px-x)+(py-y)*(py-y)).squareRoot() < r*reach }
    }
    struct Rect {
        var x: Float,y: Float,w: Float,h: Float
        func contains(_ px: Float,_ py: Float) -> Bool { px >= x && px <= x+w && py >= y && py <= y+h }
        func grown(_ d: Float) -> Rect { Rect(x:x-d,y:y-d,w:w+2*d,h:h+2*d) }
    }
    struct Item { let widget: Widget, rect: Rect, label: String }
    struct Text { let string: String, x: Float, y: Float, left: Bool }
    /// The fixed places, from the canvas size alone.
    struct Layout {
        let w: Float,h: Float,u: Float
        let toggle: Circle,fToggle: Circle,gear: Circle
        let cells: [(control: Control,rect: Rect)]
        init(width: Float,height: Float,maxUnit: Float) {
            w = width; h = height; u = min(h/9,maxUnit)
            toggle = Circle(x:w/2,y:0.6*u,r:0.4*u)
            fToggle = Circle(x:1.1*u,y:1.1*u,r:0.5*u)
            gear = Circle(x:w-1.1*u,y:1.1*u,r:0.5*u)
            let u = u
            cells = OriginalTouchControls.grid.enumerated().map { i,c in
                (control:c,rect:Rect(x:0.6*u+Float(i%5)*0.9*u,y:1.95*u+Float(i/5)*0.9*u,w:0.8*u,h:0.8*u))
            }
        }
        /// A button's place by its bottom corner: units from the left or
        /// right edge and from the bottom (on the A12, 1223×550 at 61.1, the
        /// proposal's places to a tenth of a pixel).
        func home(_ c: Control) -> (x: Float,y: Float) {
            switch c {
            case .up: return (3.5*u,h-4.25*u)
            case .down: return (3.5*u,h-1.35*u)
            case .left: return (1.68*u,h-2.8*u)
            case .right: return (5.32*u,h-2.8*u)
            case .attack: return (w-1.94*u,h-1.65*u)
            case .jump: return (w-3.5*u,h-3.45*u)
            default: return (w-5.45*u,h-1.55*u)
            }
        }
    }
    // MARK: touch

    /// What a finger holds until it lifts: the pad and action buttons, the
    /// F grid, a settings or menu button, a button being moved (with the
    /// finger's offset from its centre) or the mouse.
    private enum Zone: Equatable { case buttons, functions, menu, drag(Control,dx: Float,dy: Float), mouse }
    private struct Finger { var zone: Zone, x: Float, y: Float }
    private var fingers: [Int: Finger] = [:]
    /// The keys held, in the order they were pressed.
    private var sent: [UInt32] = []

    /// A finger touches the canvas (`id` unique while it is down; a finger
    /// still down with this id lost its lift and lifts first).
    public func began(_ id: Int,x: Float,y: Float) {
        if let old = fingers[id] { lift(id,x:old.x,y:old.y); sync() }
        if let zone = grab(x:x,y:y) { fingers[id] = Finger(zone:zone,x:x,y:y) }
        else if !fingers.values.contains(where:{ $0.zone == .mouse }) {
            fingers[id] = Finger(zone:.mouse,x:x,y:y); mouse(.began,x,y)
        }
        sync(); notify()
    }
    public func moved(_ id: Int,x: Float,y: Float) {
        guard var finger = fingers[id] else { return }
        finger.x = x; finger.y = y; fingers[id] = finger
        switch finger.zone {
        case .mouse: mouse(.moved,x,y)
        case .drag(let c,let dx,let dy): move(c,x:x+dx,y:y+dy)
        default: break
        }
        sync(); notify()
    }
    /// A finger lifts (or the system cancels it).
    public func ended(_ id: Int,x: Float,y: Float) { lift(id,x:x,y:y); sync(); notify() }
    /// Every finger lifts where it last was (the host lost their lifts).
    public func liftAll() {
        for (id,finger) in fingers { lift(id,x:finger.x,y:finger.y) }
        sync(); notify()
    }
    /// Lets go of every key (the app lost focus): fingers on the controls
    /// are dropped; a finger that is the mouse stays the mouse until it lifts.
    public func releaseKeys() { dropControlFingers(); sync(); notify() }
    /// Drops the fingers on the controls (a button being dragged keeps its
    /// new place in the file); a finger that is the mouse stays.
    private func dropControlFingers() {
        if fingers.values.contains(where:{ if case .drag = $0.zone { return true }; return false }) { save() }
        fingers = fingers.filter { $0.value.zone == .mouse }
    }
    private func lift(_ id: Int,x: Float,y: Float) {
        guard let finger = fingers.removeValue(forKey:id) else { return }
        switch finger.zone {
        case .mouse: mouse(.ended,x,y)
        case .drag: save()
        default: break
        }
    }

    /// What a finger that begins here grabs, acting on a menu or settings
    /// button at once; nil: the mouse.
    private func grab(x: Float,y: Float) -> Zone? {
        guard active,canvas.width > 0,canvas.height > 0 else { return nil }
        let l = Layout(width:canvas.width,height:canvas.height,maxUnit:maxUnit)
        if l.gear.near(x,y,1.5) {
            editing.toggle(); picking = false; selected = nil; save(); dirty = true
            return .menu
        }
        if editing {
            let p = current.panel(l)
            if let item = p.items.first(where:{ $0.rect.contains(x,y) }) { perform(item.widget); return .menu }
            if picking { picking = false; dirty = true; return .menu }
            if p.frame.contains(x,y) { return .menu }
            if let b = current.buttons(l).first(where:{ $0.circle.near(x,y,1.15) }) {
                selected = b.control; dirty = true
                return .drag(b.control,dx:b.circle.x-x,dy:b.circle.y-y)
            }
            return .menu
        }
        if functionsOpen,l.cells.contains(where:{ $0.rect.grown(0.05*l.u).contains(x,y) }) { return .functions }
        if l.toggle.near(x,y,2) { visible.toggle(); save(); dirty = true; return .menu }
        if l.fToggle.near(x,y,1.5) { functionsOpen.toggle(); dirty = true; return .menu }
        if visible,current.buttons(l).contains(where:{ $0.circle.near(x,y,1.15) }) { return .buttons }
        return nil
    }
    /// Moves a button's centre to a canvas point.
    private func move(_ c: Control,x: Float,y: Float) {
        guard var spec = specs[c],canvas.width > 0,canvas.height > 0 else { return }
        spec.x = min(0.98,max(0.02,x/canvas.width)); spec.y = min(0.98,max(0.02,y/canvas.height))
        if spec != specs[c] { specs[c] = spec; dirty = true }
    }
    private func perform(_ widget: Widget) {
        switch widget {
        case .sizeMinus,.sizePlus:
            guard let s = selected,var spec = specs[s] else { return }
            let step: Float = widget == .sizePlus ? 0.1 : -0.1
            spec.size = min(2.5,max(0.5,((spec.size+step)*10).rounded()/10)); specs[s] = spec
        case .keyButton:
            guard selected != nil else { return }
            picking = true; dirty = true; return
        case .opacityMinus(let g): opacity[g] = max(1,(opacity[g] ?? 7)-1)
        case .opacityPlus(let g): opacity[g] = min(10,(opacity[g] ?? 7)+1)
        case .reset: specs = Self.defaultSpecs; opacity = Self.defaultOpacity
        case .done: editing = false; picking = false; selected = nil
        case .pickKey(let usage):
            if let s = selected,var spec = specs[s] { spec.usage = usage; specs[s] = spec }
            picking = false
        }
        save(); dirty = true
    }
    /// Presses and releases keys so they equal what the fingers on the
    /// controls hold: each key once, pressed in the controls' order (two
    /// buttons may share a key), released in the order it was pressed.
    private func sync() {
        var desired = Set<Control>()
        if active && !editing && canvas.width > 0 && canvas.height > 0 {
            let l = Layout(width:canvas.width,height:canvas.height,maxUnit:maxUnit),list = visible ? current.buttons(l) : []
            for finger in fingers.values {
                switch finger.zone {
                case .buttons: for b in list where b.circle.near(finger.x,finger.y,1.15) { desired.insert(b.control) }
                case .functions: if functionsOpen,let cell = l.cells.first(where:{ $0.rect.contains(finger.x,finger.y) }) { desired.insert(cell.control) }
                default: break
                }
            }
        }
        var keys: [UInt32] = []
        for c in Control.allCases where desired.contains(c) { if let u = usage(c),!keys.contains(u) { keys.append(u) } }
        for u in sent where !keys.contains(u) { key(u,false) }
        for u in keys where !sent.contains(u) { key(u,true) }
        sent = sent.filter { keys.contains($0) }+keys.filter { !sent.contains($0) }
        if desired != pressed { pressed = desired; dirty = true }
    }
    private func activeChanged() {
        if !active {
            editing = false; picking = false; selected = nil; functionsOpen = false
            dropControlFingers()
        }
        sync(); dirty = true; notify()
    }
}

extension OriginalTouchControls.Picture {
    typealias Layout = OriginalTouchControls.Layout
    typealias Rect = OriginalTouchControls.Rect
    typealias Circle = OriginalTouchControls.Circle
    typealias Item = OriginalTouchControls.Item
    typealias Text = OriginalTouchControls.Text
    typealias Widget = OriginalTouchControls.Widget
    typealias Control = OriginalTouchControls.Control
    typealias Group = OriginalTouchControls.Group

    func buttons(_ l: Layout) -> [(control: Control,circle: Circle)] {
        OriginalTouchControls.movable.compactMap { c in
            specs[c].map { s in
                let home = l.home(c),x = s.x.map { $0*l.w } ?? home.x,y = s.y.map { $0*l.h } ?? home.y
                return (control:c,circle:Circle(x:x,y:y,r:0.85*l.u*s.size))
            }
        }
    }

    /// The settings panel, or the key grid while a key is being picked.
    func panel(_ l: Layout) -> (frame: Rect,items: [Item],texts: [Text]) {
        let u = l.u
        var items: [Item] = [],texts: [Text] = []
        if picking {
            let cols = 11,cell = 0.72*u,gap = 0.08*u
            let rows = (OriginalTouchControls.keys.count+cols-1)/cols
            let gridW = Float(cols)*(cell+gap)-gap,gridH = Float(rows)*(cell+gap)-gap
            let fw = gridW+0.8*u,fh = gridH+1.5*u
            let fx = (l.w-fw)/2,fy = (l.h-fh)/2
            texts.append(Text(string:"PICK A KEY",x:fx+0.4*u,y:fy+0.55*u,left:true))
            for (i,k) in OriginalTouchControls.keys.enumerated() {
                let r = Rect(x:fx+0.4*u+Float(i%cols)*(cell+gap),y:fy+1.0*u+Float(i/cols)*(cell+gap),w:cell,h:cell)
                items.append(Item(widget:.pickKey(k.usage),rect:r,label:k.label))
            }
            return (Rect(x:fx,y:fy,w:fw,h:fh),items,texts)
        }
        let pw = 7.2*u,ph = 7.0*u,rh = 0.8*u,bs = 0.65*u
        let x0 = (l.w-pw)/2,y0 = 1.2*u
        func rowY(_ r: Int) -> Float { y0+0.3*u+Float(r)*rh+rh/2 }
        func stepper(_ row: Int,_ name: String,_ value: String,_ minus: Widget,_ plus: Widget) {
            let y = rowY(row)
            texts.append(Text(string:name,x:x0+0.4*u,y:y,left:true))
            items.append(Item(widget:minus,rect:Rect(x:x0+3.4*u,y:y-bs/2,w:bs,h:bs),label:"-"))
            texts.append(Text(string:value,x:x0+4.75*u,y:y,left:false))
            items.append(Item(widget:plus,rect:Rect(x:x0+5.45*u,y:y-bs/2,w:bs,h:bs),label:"+"))
        }
        if let s = selected,let spec = specs[s] {
            texts.append(Text(string:s.rawValue.uppercased(),x:x0+0.4*u,y:rowY(0),left:true))
            stepper(1,"SIZE","\(Int((spec.size*100).rounded()))",.sizeMinus,.sizePlus)
            texts.append(Text(string:"KEY",x:x0+0.4*u,y:rowY(2),left:true))
            items.append(Item(widget:.keyButton,rect:Rect(x:x0+3.4*u,y:rowY(2)-bs/2,w:2.7*u,h:bs),label:OriginalTouchControls.keyLabel(spec.usage)))
        } else {
            texts.append(Text(string:"TAP A BUTTON",x:x0+0.4*u,y:rowY(0),left:true))
        }
        for (i,g) in Group.allCases.enumerated() {
            stepper(3+i,["PAD","ACT","F","MENU"][i],"\((opacity[g] ?? 7)*10)",.opacityMinus(g),.opacityPlus(g))
        }
        items.append(Item(widget:.reset,rect:Rect(x:x0+0.4*u,y:rowY(7)-bs/2,w:2.9*u,h:bs),label:"RESET"))
        items.append(Item(widget:.done,rect:Rect(x:x0+3.9*u,y:rowY(7)-bs/2,w:2.9*u,h:bs),label:"DONE"))
        return (Rect(x:x0,y:y0,w:pw,h:ph),items,texts)
    }

    // MARK: drawing

    private func alpha(_ g: Group,_ strength: Float) -> UInt32 {
        UInt32(max(0,min(255,Float(opacity[g] ?? 7)/10*strength*255)))
    }

    /// The overlay at this size, the unit's cap in its pixels (any thread).
    public func render(width: Int,height: Int,maxUnit: Float) -> OriginalTouchOverlay {
        guard width > 0,height > 0 else { return OriginalTouchOverlay.Canvas(width:0,height:0).overlay }
        var c = OriginalTouchOverlay.Canvas(width:width,height:height)
        let l = Layout(width:Float(width),height:Float(height),maxUnit:maxUnit)
        let scale = max(1,Int((0.30*l.u/7).rounded()))
        // MENU: the show/hide toggle and the settings button.
        c.circle(l.toggle,inner:l.toggle.r*0.78,0xFFFFFF,alpha(.menu,0.65))
        if visible { c.circle(l.toggle,inner:0,0xFFFFFF,alpha(.menu,0.25)) }
        c.circle(l.gear,inner:l.gear.r*0.8,0xFFFFFF,alpha(.menu,0.65))
        if editing { c.circle(l.gear,inner:0,0xFFFFFF,alpha(.menu,0.28)) }
        c.label("SET",centerX:l.gear.x,centerY:l.gear.y,scale:scale,maxWidth:l.gear.r*1.7,alpha:alpha(.menu,0.95))
        // F: the F button, and the F1-F9 and Esc grid while it is open.
        c.circle(l.fToggle,inner:l.fToggle.r*0.8,0xFFFFFF,alpha(.function,0.65))
        if functionsOpen { c.circle(l.fToggle,inner:0,0xFFFFFF,alpha(.function,0.28)) }
        c.label("F",centerX:l.fToggle.x,centerY:l.fToggle.y,scale:scale,alpha:alpha(.function,0.95))
        if functionsOpen {
            for (i,cell) in l.cells.enumerated() {
                let on = pressed.contains(cell.control),r = cell.rect,e = max(1,0.04*l.u)
                c.rect(r.x,r.y,r.w,r.h,0x4C8DFF,alpha(.function,on ? 0.85 : 0.40))
                for (rx,ry,rw,rh) in [(r.x,r.y,r.w,e),(r.x,r.y+r.h-e,r.w,e),(r.x,r.y+e,e,r.h-2*e),(r.x+r.w-e,r.y+e,e,r.h-2*e)] {
                    c.rect(rx,ry,rw,rh,0xFFFFFF,alpha(.function,on ? 0.9 : 0.55))
                }
                c.label(cell.control == .escape ? "ESC" : "F\(i+1)",centerX:r.x+r.w/2,centerY:r.y+r.h/2,scale:scale,
                        maxWidth:r.w*0.9,alpha:alpha(.function,0.95))
            }
        }
        // PAD and ACT: the seven round buttons.
        if visible || editing {
            for b in buttons(l) {
                let g = OriginalTouchControls.group(of:b.control),on = pressed.contains(b.control)
                c.circle(b.circle,inner:0,0xB8C4D6,alpha(g,on ? 0.85 : 0.40))
                c.circle(b.circle,inner:b.circle.r-0.07*l.u,0xFFFFFF,alpha(g,on ? 0.9 : 0.55))
                let text: String
                switch b.control {
                case .up: text = "^"
                case .down: text = "v"
                case .left: text = "<"
                case .right: text = ">"
                case .attack: text = "A"
                case .jump: text = "J"
                default: text = "D"
                }
                // Twice the text's scale, or the button's own where that rounds
                // down (a capped unit, a bigger button).
                c.label(text,centerX:b.circle.x,centerY:b.circle.y,scale:max(scale*2,Int((b.circle.r/0.85*0.6/7).rounded())),
                        maxWidth:b.circle.r*1.5,alpha:alpha(g,0.95))
                if editing {
                    let mark = Circle(x:b.circle.x,y:b.circle.y,r:b.circle.r+0.1*l.u)
                    c.circle(mark,inner:b.circle.r+0.03*l.u,0xFFD400,selected == b.control ? 255 : 120)
                }
            }
        }
        // The settings panel (or the key grid) on top.
        if editing {
            let p = panel(l),f = p.frame,e = max(1,0.04*l.u)
            c.rect(f.x,f.y,f.w,f.h,0x0B0F1A,225)
            for (rx,ry,rw,rh) in [(f.x,f.y,f.w,e),(f.x,f.y+f.h-e,f.w,e),(f.x,f.y+e,e,f.h-2*e),(f.x+f.w-e,f.y+e,e,f.h-2*e)] {
                c.rect(rx,ry,rw,rh,0xFFFFFF,150)
            }
            for item in p.items {
                c.rect(item.rect.x,item.rect.y,item.rect.w,item.rect.h,0x33425E,240)
                c.label(item.label,centerX:item.rect.x+item.rect.w/2,centerY:item.rect.y+item.rect.h/2,scale:scale,maxWidth:item.rect.w*0.9,alpha:255)
            }
            for t in p.texts { c.label(t.string,centerX:t.x,centerY:t.y,scale:scale,left:t.left,alpha:235) }
        }
        return c.overlay
    }
}

/// The controls as pixels: premultiplied R,G,B,A bytes (R first in memory,
/// so little-endian words 0xAABBGGRR), with the 32-pixel tiles that hold any
/// painted pixel, so a host blending it over each frame touches only those.
public struct OriginalTouchOverlay: Sendable {
    public struct Tile: Sendable { public let x: Int,y: Int,width: Int,height: Int }
    public let width: Int,height: Int
    public let pixels: [UInt32]
    public let tiles: [Tile]
    static let tileSize = 32

    /// Blends the overlay over an opaque buffer of R,G,B,X words (R in the low
    /// byte) of the same size, `stride` words per row.
    public func blend(over dst: UnsafeMutablePointer<UInt32>,stride: Int) {
        pixels.withUnsafeBufferPointer { src in
            for t in tiles {
                for y in t.y..<t.y+t.height {
                    let row = dst+y*stride,base = y*width
                    for x in t.x..<t.x+t.width {
                        let s = src[base+x],a = s >> 24
                        if a == 0 { continue }
                        if a == 255 { row[x] = s; continue }
                        let d = row[x],rest = 255-a
                        let r = (d & 0xFF)*rest/255+(s & 0xFF)
                        let g = ((d >> 8) & 0xFF)*rest/255+((s >> 8) & 0xFF)
                        let b = ((d >> 16) & 0xFF)*rest/255+((s >> 16) & 0xFF)
                        row[x] = r | (g << 8) | (b << 16) | 0xFF00_0000
                    }
                }
            }
        }
    }

    /// Paints premultiplied pixels, source over, marking the tiles it touches.
    struct Canvas {
        let width: Int,height: Int
        var pixels: [UInt32],marked: [Bool]
        let columns: Int
        init(width: Int,height: Int) {
            self.width = width; self.height = height
            pixels = [UInt32](repeating:0,count:width*height)
            columns = (width+OriginalTouchOverlay.tileSize-1)/OriginalTouchOverlay.tileSize
            marked = [Bool](repeating:false,count:columns*((height+OriginalTouchOverlay.tileSize-1)/OriginalTouchOverlay.tileSize))
        }
        var overlay: OriginalTouchOverlay {
            let size = OriginalTouchOverlay.tileSize
            var tiles: [Tile] = []
            for (i,on) in marked.enumerated() where on {
                let x = (i%columns)*size,y = (i/columns)*size
                tiles.append(Tile(x:x,y:y,width:min(size,width-x),height:min(size,height-y)))
            }
            return OriginalTouchOverlay(width:width,height:height,pixels:pixels,tiles:tiles)
        }
        private mutating func mark(_ x0: Int,_ y0: Int,_ x1: Int,_ y1: Int) {
            let size = OriginalTouchOverlay.tileSize
            for ty in y0/size...(y1-1)/size { for tx in x0/size...(x1-1)/size { marked[ty*columns+tx] = true } }
        }
        /// One pixel: `rgb` (0xRRGGBB) at `alpha` (0-255), source over.
        private mutating func paint(_ i: Int,_ rgb: UInt32,_ alpha: UInt32) {
            let rest = 255-alpha,d = pixels[i]
            let r = ((rgb >> 16) & 0xFF)*alpha/255+(d & 0xFF)*rest/255
            let g = ((rgb >> 8) & 0xFF)*alpha/255+((d >> 8) & 0xFF)*rest/255
            let b = (rgb & 0xFF)*alpha/255+((d >> 16) & 0xFF)*rest/255
            let a = alpha+(d >> 24)*rest/255
            pixels[i] = r | (g << 8) | (b << 16) | (a << 24)
        }
        /// A filled rectangle of one colour (0xRRGGBB) at an alpha of 0-255.
        mutating func rect(_ x: Float,_ y: Float,_ w: Float,_ h: Float,_ rgb: UInt32,_ alpha: UInt32) {
            guard alpha > 0 else { return }
            let x0 = max(0,Int(x.rounded())),y0 = max(0,Int(y.rounded()))
            let x1 = min(width,Int((x+w).rounded())),y1 = min(height,Int((y+h).rounded()))
            guard x0 < x1,y0 < y1 else { return }
            for yy in y0..<y1 { for xx in x0..<x1 { paint(yy*width+xx,rgb,alpha) } }
            mark(x0,y0,x1,y1)
        }
        /// A disc (or a ring, when `inner` > 0) with smoothed edges.
        mutating func circle(_ c: OriginalTouchControls.Circle,inner: Float,_ rgb: UInt32,_ alpha: UInt32) {
            guard alpha > 0,c.r > 0 else { return }
            let x0 = max(0,Int((c.x-c.r-1).rounded(.down))),x1 = min(width,Int((c.x+c.r+1).rounded(.up)))
            let y0 = max(0,Int((c.y-c.r-1).rounded(.down))),y1 = min(height,Int((c.y+c.r+1).rounded(.up)))
            guard x0 < x1,y0 < y1 else { return }
            let outerIn = max(0,c.r-0.5)*max(0,c.r-0.5),outerOut = (c.r+0.5)*(c.r+0.5)
            let innerIn = inner > 0 ? (inner+0.5)*(inner+0.5) : -1,innerOut = inner > 0 ? max(0,inner-0.5)*max(0,inner-0.5) : -1
            for y in y0..<y1 {
                let dy = Float(y)+0.5-c.y
                for x in x0..<x1 {
                    let dx = Float(x)+0.5-c.x,d2 = dx*dx+dy*dy
                    guard d2 < outerOut,d2 > innerOut else { continue }
                    var coverage: Float = 1
                    if d2 > outerIn || d2 < innerIn {
                        let d = d2.squareRoot()
                        coverage = min(1,max(0,c.r+0.5-d))
                        if inner > 0 { coverage *= min(1,max(0,d-(inner-0.5))) }
                    }
                    let a = coverage >= 1 ? alpha : UInt32((Float(alpha)*coverage).rounded())
                    if a > 0 { paint(y*width+x,rgb,a) }
                }
            }
            mark(x0,y0,x1,y1)
        }
        /// White text from the 5x7 glyphs, each pixel `scale` square, centred
        /// on a point (or starting at it, with `left`); the scale shrinks until
        /// it fits `maxWidth`.
        mutating func label(_ text: String,centerX: Float,centerY: Float,scale: Int,maxWidth: Float = .infinity,left: Bool = false,alpha: UInt32) {
            let glyphs = text.compactMap { OriginalTouchOverlay.font[$0] }
            guard !glyphs.isEmpty,alpha > 0 else { return }
            var s = scale
            while s > 1,Float((glyphs.count*6-1)*s) > maxWidth { s -= 1 }
            let total = (glyphs.count*6-1)*s,tall = 7*s
            let start = left ? Int(centerX.rounded()) : Int(centerX.rounded())-total/2
            let top = Int(centerY.rounded())-tall/2
            for (g,rows) in glyphs.enumerated() {
                for (ry,bits) in rows.enumerated() {
                    for rx in 0..<5 where bits & (1 << UInt8(4-rx)) != 0 {
                        rect(Float(start+(g*6+rx)*s),Float(top+ry*s),Float(s),Float(s),0xFFFFFF,alpha)
                    }
                }
            }
        }
    }

    /// 5x7 glyphs: letters, digits, space and a few symbols ("#" is a lit pixel).
    static let font: [Character: [UInt8]] = {
        let raw: [Character: [String]] = [
            " ": [".....",".....",".....",".....",".....",".....","....."],
            "A": [".###.","#...#","#...#","#####","#...#","#...#","#...#"],
            "B": ["####.","#...#","#...#","####.","#...#","#...#","####."],
            "C": [".###.","#...#","#....","#....","#....","#...#",".###."],
            "D": ["####.","#...#","#...#","#...#","#...#","#...#","####."],
            "E": ["#####","#....","#....","####.","#....","#....","#####"],
            "F": ["#####","#....","#....","####.","#....","#....","#...."],
            "G": [".###.","#...#","#....","#.###","#...#","#...#",".####"],
            "H": ["#...#","#...#","#...#","#####","#...#","#...#","#...#"],
            "I": [".###.","..#..","..#..","..#..","..#..","..#..",".###."],
            "J": ["..###","...#.","...#.","...#.","...#.","#..#.",".##.."],
            "K": ["#...#","#..#.","#.#..","##...","#.#..","#..#.","#...#"],
            "L": ["#....","#....","#....","#....","#....","#....","#####"],
            "M": ["#...#","##.##","#.#.#","#.#.#","#...#","#...#","#...#"],
            "N": ["#...#","#...#","##..#","#.#.#","#..##","#...#","#...#"],
            "O": [".###.","#...#","#...#","#...#","#...#","#...#",".###."],
            "P": ["####.","#...#","#...#","####.","#....","#....","#...."],
            "Q": [".###.","#...#","#...#","#...#","#.#.#","#..#.",".##.#"],
            "R": ["####.","#...#","#...#","####.","#.#..","#..#.","#...#"],
            "S": [".####","#....","#....",".###.","....#","....#","####."],
            "T": ["#####","..#..","..#..","..#..","..#..","..#..","..#.."],
            "U": ["#...#","#...#","#...#","#...#","#...#","#...#",".###."],
            "V": ["#...#","#...#","#...#","#...#","#...#",".#.#.","..#.."],
            "W": ["#...#","#...#","#...#","#.#.#","#.#.#","#.#.#",".#.#."],
            "X": ["#...#","#...#",".#.#.","..#..",".#.#.","#...#","#...#"],
            "Y": ["#...#","#...#",".#.#.","..#..","..#..","..#..","..#.."],
            "Z": ["#####","....#","...#.","..#..",".#...","#....","#####"],
            "0": [".###.","#...#","#..##","#.#.#","##..#","#...#",".###."],
            "1": ["..#..",".##..","..#..","..#..","..#..","..#..",".###."],
            "2": [".###.","#...#","....#","...#.","..#..",".#...","#####"],
            "3": ["####.","....#","....#",".###.","....#","....#","####."],
            "4": ["...#.","..##.",".#.#.","#..#.","#####","...#.","...#."],
            "5": ["#####","#....","####.","....#","....#","#...#",".###."],
            "6": ["..##.",".#...","#....","####.","#...#","#...#",".###."],
            "7": ["#####","....#","...#.","..#..",".#...",".#...",".#..."],
            "8": [".###.","#...#","#...#",".###.","#...#","#...#",".###."],
            "9": [".###.","#...#","#...#",".####","....#","...#.",".##.."],
            "^": ["..#..",".#.#.","#...#",".....",".....",".....","....."],
            "v": [".....",".....",".....",".....","#...#",".#.#.","..#.."],
            "<": ["...#.","..#..",".#...","#....",".#...","..#..","...#."],
            ">": [".#...","..#..","...#.","....#","...#.","..#..",".#..."],
            "-": [".....",".....",".....","#####",".....",".....","....."],
            "+": [".....","..#..","..#..","#####","..#..","..#..","....."],
            "?": [".###.","#...#","....#","...#.","..#..",".....","..#.."],
        ]
        var table: [Character: [UInt8]] = [:]
        for (ch,rows) in raw { table[ch] = rows.map { row in row.reduce(UInt8(0)) { ($0 << 1) | ($1 == "#" ? 1 : 0) } } }
        return table
    }()
}
