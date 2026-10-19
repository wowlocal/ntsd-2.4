// Checks of the on-screen touch controls (TOUCH_CONTROLS), compiled with the
// shared file alone, on macOS:
//   xcrun swiftc -swift-version 6 -O -parse-as-library -module-name TouchControlsCheck \
//     native/Sources/NTSDRuntime/OriginalTouchControls.swift \
//     tools/crossplatform/touch_controls_check.swift -o OUT/check && OUT/check OUT
// The settings file (parse, clamp, legacy places, round trip), the places by
// the corners (the proposal's on the A12, the unit's cap on an iPad), keys and
// the mouse through fingers (sliding, several fingers, lost lifts, focus loss,
// a shared key, diagonals, the F grid on a 4:3 iPad, settings and drag,
// keyboards and gamepads coming and going), the overlay (tiles cover every
// painted pixel, premultiplied; render and blend times; PNGs of four states
// in OUT) and 3,000 seeded random interleavings with balanced keys and mouse.
// Test harness only: nothing here is in an app.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

nonisolated(unsafe) var failures = 0
func check(_ ok: Bool,_ what: String,line: Int = #line) {
    if !ok { failures += 1; print("FAIL line \(line): \(what)") }
}
let dir = URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)

func png(_ o: OriginalTouchOverlay,background: UInt32,_ name: String) {
    var buffer = [UInt32](repeating:background,count:o.width*o.height)
    buffer.withUnsafeMutableBufferPointer { o.blend(over:$0.baseAddress!,stride:o.width) }
    let data = buffer.withUnsafeBytes { Data($0) }
    let image = CGImage(width:o.width,height:o.height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:o.width*4,
                        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.noneSkipLast.rawValue),
                        provider:CGDataProvider(data:data as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
    let url = dir.appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil)!
    CGImageDestinationAddImage(dest,image,nil); CGImageDestinationFinalize(dest)
}

@MainActor func run() {
    let W: Float = 1223,H: Float = 550
    // 1. Defaults without a file; parse, clamp, legacy form, NaN.
    let none = OriginalTouchControls(config:nil)
    check(none.specs == OriginalTouchControls.defaultSpecs && none.visible,"defaults")
    let file = dir.appendingPathComponent("controls.txt")
    try! """
    # comment
    show off
    up key=w x=0.5 y=2 size=9
    down x
    left key=esc x=nan
    attack key=nosuch x=0.25   # trailing comment
    opacity pad=0 action=11 function=3
    bogus line
    """.write(to:file,atomically:true,encoding:.utf8)
    let parsed = OriginalTouchControls(config:file)
    check(!parsed.visible,"show off")
    check(parsed.specs[.up] == .init(usage:0x1A,x:0.5,y:1,size:2.5),"up parsed+clamped: \(String(describing:parsed.specs[.up]))")
    check(parsed.specs[.down]?.usage == 0x1B,"legacy form")
    check(parsed.specs[.left]?.usage == 0x29 && parsed.specs[.left]?.x == nil,"esc alias, nan ignored")
    check(parsed.specs[.attack]?.usage == 0x0D && parsed.specs[.attack]?.x == nil,"unknown key keeps default; x without y is no place")
    check(parsed.opacity == [.pad:1,.action:10,.function:3,.menu:7],"opacity clamp \(parsed.opacity)")
    // 1b. Places by the corners: on the A12 canvas the proposal's fractions.
    let a12 = OriginalTouchControls(config:nil); a12.layout(width:1223,height:550,maxUnit:68.75)
    let proposal: [(OriginalTouchControls.Control,Float,Float)] = [(.up,0.175,0.528),(.down,0.175,0.850),(.left,0.084,0.689),(.right,0.266,0.689),
                                                                   (.attack,0.903,0.817),(.jump,0.825,0.617),(.defend,0.728,0.828)]
    for (k,fx,fy) in proposal { let p = a12.center(k)!; check(abs(p.x-fx*1223) < 0.6 && abs(p.y-fy*550) < 0.6,"A12 place \(k): \(p) vs \(fx*1223),\(fy*550)") }
    // 1c. The unit's cap: an iPad (1366x1024 points) keeps phone-sized buttons, by the corners.
    let pad = OriginalTouchControls(config:nil); pad.layout(width:1366,height:1024,maxUnit:OriginalTouchControls.maxUnitPoints)
    let phone = OriginalTouchControls(config:nil); phone.layout(width:750,height:402,maxUnit:OriginalTouchControls.maxUnitPoints)
    let padLeft = pad.center(.left)!,padRight = pad.center(.right)!,phoneLeft = phone.center(.left)!,phoneRight = phone.center(.right)!
    check(abs((padRight.x-padLeft.x)-3.64*48) < 0.01 && abs((phoneRight.x-phoneLeft.x)-3.64*402/9) < 0.01,"cap: pad span \(padRight.x-padLeft.x), phone \(phoneRight.x-phoneLeft.x)")
    check(abs(pad.center(.attack)!.x-(1366-1.94*48)) < 0.01 && abs(pad.center(.attack)!.y-(1024-1.65*48)) < 0.01,"iPad attack by the corner")
    // 1d. A file of the proposal's (every place written) reads as places by the corner.
    let legacy = dir.appendingPathComponent("legacy.txt")
    try! "up key=w x=0.175 y=0.528 size=1.000\njump key=k x=0.825 y=0.617 size=1.000\ndefend key=l x=0.700 y=0.828 size=1.000\n".write(to:legacy,atomically:true,encoding:.utf8)
    let lg = OriginalTouchControls(config:legacy)
    check(lg.specs[.up]?.x == nil && lg.specs[.jump]?.x == nil && lg.specs[.defend]?.x == 0.7,"legacy places")
    try? FileManager.default.removeItem(at:legacy)
    // 2. Round trip.
    parsed.save()
    let again = OriginalTouchControls(config:file)
    check(again.specs == parsed.specs && again.opacity == parsed.opacity && again.visible == parsed.visible,"round trip")
    print(try! String(contentsOf:file,encoding:.utf8))
    try? FileManager.default.removeItem(at:file)

    // 3. Keys and the mouse.
    var log: [String] = [],renders = 0
    let c = OriginalTouchControls(config:file)
    c.key = { log.append("\($1 ? "down" : "up") \(String($0,radix:16))") }
    c.mouse = { log.append("mouse \($0) \(Int($1)),\(Int($2))") }
    c.changed = { renders += 1 }
    c.layout(width:W,height:H,maxUnit:.infinity)
    func at(_ k: OriginalTouchControls.Control) -> (Float,Float) { let p = c.center(k)!; return (p.x,p.y) }
    var (x,y) = at(.left)
    c.began(1,x:x,y:y); check(log == ["down 4"],"left down \(log)"); log = []
    check(renders == 1,"one render per call (\(renders))")
    (x,y) = at(.right); c.moved(1,x:x,y:y); check(log == ["up 4","down 7"],"slide left→right \(log)"); log = []
    (x,y) = at(.attack); c.began(2,x:x,y:y); check(log == ["down d"],"second finger attack \(log)"); log = []
    check(c.pressed == [.right,.attack],"pressed \(c.pressed)")
    c.began(3,x:W/2,y:H/2); check(log == ["mouse began 611,275"],"empty → mouse \(log)"); log = []
    c.began(4,x:W/2+10,y:H/2); check(log.isEmpty,"second empty finger ignored \(log)")
    c.moved(3,x:W/2+5,y:H/2); check(log == ["mouse moved 616,275"],"mouse moves \(log)"); log = []
    c.ended(4,x:0,y:0); check(log.isEmpty,"ignored finger lifts silently")
    c.ended(2,x:0,y:0); check(log == ["up d"],"attack up \(log)"); log = []
    c.ended(3,x:W/2+5,y:H/2); check(log == ["mouse ended 616,275"],"mouse ends \(log)"); log = []
    c.ended(1,x:0,y:0); check(log == ["up 7"],"right up \(log)"); log = []
    // Characters with key presses (hosts pass them on down).
    check(OriginalTouchControls.characters(0x04) == "a" && OriginalTouchControls.characters(0x1D) == "z" && OriginalTouchControls.characters(0x1E) == "1"
          && OriginalTouchControls.characters(0x26) == "9" && OriginalTouchControls.characters(0x27) == "0" && OriginalTouchControls.characters(0x2C) == " "
          && OriginalTouchControls.characters(0x52) == nil,"characters")
    // A lost lift: the same id begins again → the old finger lifts first.
    (x,y) = at(.attack); c.began(30,x:x,y:y); c.began(30,x:W/2,y:H/2)
    check(log == ["down d","up d","mouse began 611,275"],"lost lift \(log)"); log = []
    (x,y) = at(.left); c.began(31,x:x,y:y); log = []
    c.liftAll(); check(log == ["mouse ended 611,275","up 4"] || log == ["up 4","mouse ended 611,275"],"liftAll \(log)"); log = []
    // Focus loss: keys go, the mouse finger stays.
    c.began(32,x:W/2,y:H/2); (x,y) = at(.jump); c.began(33,x:x,y:y); log = []
    c.releaseKeys(); check(log == ["up e"],"releaseKeys \(log)"); log = []
    c.moved(32,x:W/2+1,y:H/2); c.ended(32,x:W/2+1,y:H/2); check(log == ["mouse moved 612,275","mouse ended 612,275"],"mouse kept \(log)"); log = []
    c.moved(33,x:x,y:y); c.ended(33,x:x,y:y); check(log.isEmpty,"dropped finger silent \(log)")

    // 4. The show/hide toggle: hidden buttons are the mouse.
    renders = 0
    c.began(6,x:W/2,y:0.6*H/9); c.ended(6,x:W/2,y:0.6*H/9)
    check(!c.visible && renders == 1,"toggle hides (\(renders))")
    (x,y) = at(.attack); c.began(7,x:x,y:y); check(log.first?.hasPrefix("mouse began") == true,"hidden → mouse \(log)"); c.ended(7,x:x,y:y); log = []
    c.began(6,x:W/2,y:0.6*H/9); c.ended(6,x:W/2,y:0.6*H/9); check(c.visible,"toggle shows")

    // 5. The F grid: F1, sliding to F2, Esc.
    let u = H/9
    c.began(8,x:1.1*u,y:1.1*u); c.ended(8,x:0,y:0); check(c.functionsOpen,"F opens")
    let f1 = (0.6*u+0.4*u,1.95*u+0.4*u),f2 = (f1.0+0.9*u,f1.1),esc = (0.6*u+4*0.9*u+0.4*u,1.95*u+0.9*u+0.4*u)
    c.began(9,x:f1.0,y:f1.1); c.moved(9,x:f2.0,y:f2.1); c.ended(9,x:f2.0,y:f2.1)
    check(log == ["down 3a","up 3a","down 3b","up 3b"],"F1 slide F2 \(log)"); log = []
    c.began(9,x:esc.0,y:esc.1); c.ended(9,x:esc.0,y:esc.1); check(log == ["down 29","up 29"],"Esc \(log)"); log = []
    c.began(8,x:1.1*u,y:1.1*u); c.ended(8,x:0,y:0); check(!c.functionsOpen,"F closes")

    // 6. Settings: select, drag with offset, size, key, opacity, done; no keys while editing.
    let gear = (W-1.1*u,1.1*u)
    c.began(10,x:gear.0,y:gear.1); c.ended(10,x:gear.0,y:gear.1); check(c.editing,"SET opens")
    (x,y) = at(.jump)
    c.began(11,x:x+20,y:y); check(c.selected == .jump && log.isEmpty,"select, no key \(log)")
    c.moved(11,x:x+20,y:y+1); check(abs(c.center(.jump)!.x-x) < 0.01,"drag keeps the grab offset")
    c.moved(11,x:x-80,y:y+30); c.ended(11,x:x-80,y:y+30)
    check(abs(c.center(.jump)!.x-(x-100)) < 0.01 && abs(c.center(.jump)!.y-(y+30)) < 0.01,"dragged")
    check(FileManager.default.fileExists(atPath:file.path),"saved after drag")
    let pw = 7.2*u,x0 = (W-pw)/2,y0 = 1.2*u
    func rowY(_ r: Int) -> Float { y0+0.3*u+Float(r)*0.8*u+0.4*u }
    c.began(12,x:x0+5.45*u+0.3*u,y:rowY(1)); c.ended(12,x:0,y:0); check(abs(c.specs[.jump]!.size-1.1) < 0.001,"size +")
    c.began(12,x:x0+3.4*u+1*u,y:rowY(2)); c.ended(12,x:0,y:0); check(c.picking,"KEY opens picker")
    // pick "A" (index 0: col 0, row 0)
    let cell = 0.72*u,gap = 0.08*u,gridW = 11*(cell+gap)-gap,rows: Float = 4,fh = rows*(cell+gap)-gap+1.5*u
    let fx = (W-(gridW+0.8*u))/2,fy = (H-fh)/2
    c.began(13,x:fx+0.4*u+cell/2,y:fy+1.0*u+cell/2); c.ended(13,x:0,y:0)
    check(!c.picking && c.specs[.jump]!.usage == 0x04,"picked A: \(String(c.specs[.jump]!.usage,radix:16))")
    c.began(14,x:x0+3.4*u+0.3*u,y:rowY(3)); c.ended(14,x:0,y:0); check(c.opacity[.pad] == 6,"opacity -")
    c.began(15,x:W/2,y:H-2); check(log.isEmpty,"no mouse while editing"); c.ended(15,x:0,y:0)
    c.began(16,x:x0+3.9*u+1*u,y:rowY(7)); c.ended(16,x:0,y:0); check(!c.editing,"DONE")
    let saved = OriginalTouchControls(config:file)
    let close = OriginalTouchControls.Control.allCases.allSatisfy { k in
        guard let a = saved.specs[k],let b = c.specs[k] else { return saved.specs[k] == nil && c.specs[k] == nil }
        func near(_ p: Float?,_ q: Float?) -> Bool { p == nil ? q == nil : q != nil && abs(p!-q!) <= 0.0005 }
        return a.usage == b.usage && near(a.x,b.x) && near(a.y,b.y) && abs(a.size-b.size) <= 0.0005 }
    check(close && saved.opacity == c.opacity,"settings persisted (to 3 decimals)")
    c.began(10,x:gear.0,y:gear.1); c.ended(10,x:gear.0,y:gear.1)
    c.began(17,x:x0+0.4*u+1*u,y:rowY(7)); c.ended(17,x:0,y:0)
    check(c.specs == OriginalTouchControls.defaultSpecs && c.opacity == OriginalTouchControls.defaultOpacity,"RESET")
    c.began(10,x:gear.0,y:gear.1); c.ended(10,x:gear.0,y:gear.1); check(!c.editing,"SET closes")

    // 7. A keyboard or gamepad connects while a button is held, then leaves.
    (x,y) = at(.defend); c.began(18,x:x,y:y); c.began(19,x:W/2,y:H/2); log = []
    c.hardwareConnected = true
    check(log == ["up f"] && c.render(width:100,height:50,maxUnit:.infinity) == nil,"hardware → release, nothing drawn \(log)"); log = []
    c.moved(19,x:W/2+1,y:H/2); check(log == ["mouse moved 612,275"],"mouse finger stays \(log)"); log = []
    c.moved(18,x:x,y:y); c.ended(18,x:x,y:y); check(log.isEmpty,"held finger dropped")
    c.ended(19,x:W/2,y:H/2); log = []
    (x,y) = at(.attack); c.began(20,x:x,y:y); check(log.first?.hasPrefix("mouse began") == true,"inactive → mouse"); c.ended(20,x:x,y:y); log = []
    c.forced = true; c.began(20,x:x,y:y); check(log == ["down d"],"forced on \(log)"); c.ended(20,x:x,y:y); log = []
    c.forced = nil; c.hardwareConnected = false
    // Two buttons on one key: pressed once, released when the last lets go.
    let dupFile = dir.appendingPathComponent("dup.txt")
    try! "attack key=w\n".write(to:dupFile,atomically:true,encoding:.utf8)
    let d = OriginalTouchControls(config:dupFile); var dlog: [String] = []
    d.key = { dlog.append("\($1 ? "down" : "up") \(String($0,radix:16))") }; d.layout(width:W,height:H,maxUnit:.infinity)
    let up = d.center(.up)!,atk = d.center(.attack)!
    d.began(1,x:up.x,y:up.y); d.began(2,x:atk.x,y:atk.y); d.ended(2,x:0,y:0)
    check(dlog == ["down 1a"],"shared key held \(dlog)"); d.ended(1,x:0,y:0); check(dlog == ["down 1a","up 1a"],"shared key released once \(dlog)")
    try? FileManager.default.removeItem(at:dupFile)
    // A 4:3 iPad (1024x768): F5 under the open grid is F5, not the show/hide button.
    let i = OriginalTouchControls(config:nil); var ilog: [String] = []
    i.key = { ilog.append("\($1 ? "down" : "up") \(String($0,radix:16))") }; i.layout(width:1024,height:768,maxUnit:.infinity)
    let iu: Float = 768/9
    i.began(1,x:1.1*iu,y:1.1*iu); i.ended(1,x:0,y:0)
    var f5Hits = 0,f5Total = 0
    for gx in stride(from:Float(0.6+3.6+0.01),through:Float(0.6+3.6+0.79),by:0.0485) { for gy in stride(from:Float(1.96),through:Float(1.95+0.79),by:0.0485) {
        f5Total += 1; ilog = []; i.began(2,x:gx*iu,y:gy*iu); i.ended(2,x:0,y:0); if ilog == ["down 3e","up 3e"] { f5Hits += 1 } } }
    check(f5Hits == f5Total && i.visible,"iPad F5: \(f5Hits)/\(f5Total)")
    // Diagonals: a finger between up and right holds both once they overlap (size 2).
    let g = OriginalTouchControls(config:nil); var glog: [String] = []
    g.key = { glog.append("\($1 ? "down" : "up") \(String($0,radix:16))") }; g.layout(width:W,height:H,maxUnit:.infinity)
    let gup0 = g.center(.up)!,gright0 = g.center(.right)!
    let gearG = (W-1.1*u,1.1*u),pwG = 7.2*u,x0G = (W-pwG)/2,y0G = 1.2*u
    func rowG(_ r: Int) -> Float { y0G+0.3*u+Float(r)*0.8*u+0.4*u }
    g.began(1,x:gearG.0,y:gearG.1); g.ended(1,x:0,y:0)
    for k in [gup0,gright0] { g.began(2,x:k.x,y:k.y); g.ended(2,x:k.x,y:k.y); for _ in 0..<10 { g.began(3,x:x0G+5.45*u+0.3*u,y:rowG(1)); g.ended(3,x:0,y:0) } }
    g.began(4,x:x0G+3.9*u+1*u,y:rowG(7)); g.ended(4,x:0,y:0)
    glog = []; g.began(5,x:(gup0.x+gright0.x)/2,y:(gup0.y+gright0.y)/2); g.ended(5,x:0,y:0)
    check(glog == ["down 1a","down 7","up 1a","up 7"],"diagonal \(glog)")
    check(OriginalTouchControls.forced(["a","--touch-controls","off"]) == false && OriginalTouchControls.forced(["--touch-controls"]) == nil,"option")

    // 8. Rendering: tiles cover every painted pixel; timing.
    for (w,h,name) in [(1223,550,"a12"),(1748,804,"iphone2x"),(2388,1668,"ipad13")] {
        let t0 = Date()
        let o = c.render(width:w,height:h,maxUnit:.infinity)!
        let t1 = Date()
        var covered = [Bool](repeating:false,count:w*h)
        for t in o.tiles { for yy in t.y..<t.y+t.height { for xx in t.x..<t.x+t.width { covered[yy*w+xx] = true } } }
        let outside = o.pixels.indices.filter { o.pixels[$0] != 0 && !covered[$0] }.count
        check(outside == 0,"\(name): \(outside) painted pixels outside tiles")
        let premult = o.pixels.allSatisfy { p in let a = p >> 24; return (p & 0xFF) <= a && ((p >> 8) & 0xFF) <= a && ((p >> 16) & 0xFF) <= a }
        check(premult,"\(name): premultiplied")
        var frame = [UInt32](repeating:0xFF40_3020,count:w*h)
        let t2 = Date()
        for _ in 0..<50 { frame.withUnsafeMutableBufferPointer { o.blend(over:$0.baseAddress!,stride:w) } }
        let t3 = Date()
        print("\(name) \(w)x\(h): render \(String(format:"%.2f",t1.timeIntervalSince(t0)*1000)) ms, blend \(String(format:"%.3f",t3.timeIntervalSince(t2)*1000/50)) ms, tiles \(o.tiles.count)")
        png(o,background:0xFF00_0000,"\(name).png")
    }
    c.began(21,x:W/2,y:0.6*H/9); c.ended(21,x:0,y:0); c.began(21,x:W/2,y:0.6*H/9); c.ended(21,x:0,y:0)
    c.began(8,x:1.1*u,y:1.1*u); c.ended(8,x:0,y:0)
    (x,y) = at(.right); c.began(22,x:x,y:y)
    png(c.render(width:1223,height:550,maxUnit:.infinity)!,background:0xFF80_6040,"a12-grid-pressed.png")
    c.ended(22,x:x,y:y)
    c.began(10,x:gear.0,y:gear.1); c.ended(10,x:gear.0,y:gear.1); (x,y) = at(.attack); c.began(23,x:x,y:y); c.ended(23,x:x,y:y)
    png(c.render(width:1223,height:550,maxUnit:.infinity)!,background:0xFF80_6040,"a12-settings.png")
    c.began(12,x:x0+3.4*u+1*u,y:rowY(2)); c.ended(12,x:0,y:0)
    png(c.render(width:1223,height:550,maxUnit:.infinity)!,background:0xFF80_6040,"a12-picker.png")
}
@main enum TouchControlsCheck {
    @MainActor static func main() {
        try? FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        run(); runBalance()
        print(failures == 0 ? "ALL PASS" : "\(failures) FAILURES")
        exit(failures == 0 ? 0 : 1)
    }
}

struct LCG { var s: UInt64; mutating func next() -> UInt64 { s = s &* 6364136223846793005 &+ 1442695040888963407; return s >> 33 }
    mutating func f(_ hi: Float) -> Float { Float(next() % 100000)/100000*hi }
    mutating func i(_ n: Int) -> Int { Int(next() % UInt64(n)) } }
/// Random interleavings: key down/up and mouse began/ended stay balanced.
@MainActor func runBalance() {
    var problems = 0
    for seed in 1...3000 {
        var r = LCG(s: UInt64(seed))
        let c = OriginalTouchControls(config:nil)
        var held: [UInt32: Int] = [:], mouseDown = false, bad: [String] = []
        c.key = { u,d in held[u, default:0] += d ? 1 : -1
            if held[u]! < 0 || held[u]! > 1 { bad.append("usage \(String(u,radix:16)) count \(held[u]!)") } }
        c.mouse = { p,_,_ in
            switch p { case .began: if mouseDown { bad.append("mouse began twice") }; mouseDown = true
            case .moved: if !mouseDown { bad.append("mouse moved while up") }
            case .ended: if !mouseDown { bad.append("mouse ended while up") }; mouseDown = false } }
        var W: Float = 1223, H: Float = 550
        c.layout(width:W,height:H,maxUnit:[Float.infinity,48,30][r.i(3)])
        var down = Set<Int>()
        for _ in 0..<200 {
            let u = H/9
            // bias touches toward controls
            func point() -> (Float,Float) {
                switch r.i(6) {
                case 0: let s = c.center(OriginalTouchControls.Control.allCases[r.i(7)])!; return (s.x+r.f(30)-15,s.y+r.f(30)-15)
                case 1: return (1.1*u,1.1*u)
                case 2: return (W-1.1*u,1.1*u)
                case 3: return (0.6*u+r.f(4.5*u),1.95*u+r.f(1.7*u))
                case 4: return (W/2,0.6*u)
                default: return (r.f(W),r.f(H)) } }
            switch r.i(12) {
            case 0,1,2: let id = r.i(5); let (x,y) = point(); if !down.contains(id) || r.i(8) == 0 { down.insert(id); c.began(id,x:x,y:y) }
            case 3,4,5: if let id = down.randomElement() { let (x,y) = point(); c.moved(id,x:x,y:y) }
            case 6,7: if let id = down.randomElement() { down.remove(id); c.ended(id,x:r.f(W),y:r.f(H)) }
            case 8: c.hardwareConnected.toggle()
            case 9: c.forced = [nil,true,false][r.i(3)]
            case 10: if r.i(4) == 0 { if r.i(2) == 0 { c.releaseKeys() } else { c.liftAll(); down.removeAll() } }
            default: if r.i(3) == 0 { W = [1223,978,874,1024][r.i(4)]; H = [550,550,402,768][r.i(4)]; c.layout(width:W,height:H,maxUnit:[Float.infinity,48,30][r.i(3)]) }
            }
        }
        for id in down { c.ended(id,x:0,y:0) }
        c.liftAll()
        let left = held.filter { $0.value != 0 }
        if !bad.isEmpty || !left.isEmpty || mouseDown { problems += 1; if problems <= 3 { print("seed \(seed): \(bad.prefix(3)) left \(left) mouse \(mouseDown)") } }
    }
    print("balance: problem runs \(problems)/3000"); check(problems == 0,"balance")
}
