import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

extension OriginalApplicationGameplayDrawingProjection {
    mutating func surfaceText(_ bytes: [UInt8],_ target: UInt32,_ x: Int32,_ y: Int32,_ color: UInt32,_ installed: Bool) throws {
        try P.require(target != 0 && !bytes.contains(0),"Text input")
        let dc: UInt32 = 0x12345678
        events += [.init("getDC",[target]),.init(installed ? "setBackgroundMode" : "setBackgroundColor",[dc,installed ? 1 : 0]),
            .init("setTextColor",[dc,color]),.init("stringLength",[],[bytes]),
            .init("textOut",[dc,UInt32(bitPattern:x),UInt32(bitPattern:y),UInt32(bytes.count)],[bytes]),.init("releaseDC",[target,dc])]
    }
    mutating func diagnostic(_ p: P,_ installed: Bool) throws {
        let actor = Int(try p.pool.integer(at:0x1bc,as:UInt32.self))
        try P.require((0..<400).contains(actor),"Diagnostic World alias")
        let values = try [0xc4,0xc5,0xc3,0xc2,0xbe,0xc0].map { try p.pool.integer(at:0x7d8+actor*0x420+$0,as:Int8.self) }
        let label = zip(["u","d","l","r","a","d"],values).map { $0.0+String($0.1)+" " }.joined()
        let bytes = Array(label.utf8),format = Array("u%d d%d l%d r%d a%d d%d ".utf8)
        events.append(.init("format",[UInt32(bytes.count)],[format,bytes]))
        try surfaceText(bytes,UInt32(bitPattern:p.g(0x455608)),0,30,0xffffff,installed)
    }
    mutating func output(_ p: P,_ installed: Bool) throws {
        try viewport(p)
        try P.require(p.g(0x451160) == 0 && p.g(0x450c30) == 0 && p.g(0x450b84) == 0,"VS Difficult output")
        events.append(.init("stage",[0x41b130]))
        for (literal,base,stores): (String,UInt32,[(Int,Int)]) in [
            ("VS mode ",0x450c38,[(0,4),(4,4),(8,1)]),("(Difficult)",0x450c40,[(0,4),(4,4),(8,4)])] {
            let bytes = Array(literal.utf8)+[0]
            for (at,count) in stores {
                let value = (0..<count).reduce(UInt32(0)) { $0 | UInt32(bytes[at+$1]) << (8*$1) }
                events.append(.init("labelWrite",[base+UInt32(at),UInt32(count),value]))
            }
        }
        let label = Array("VS mode (Difficult)".utf8),font = resourceToken(UInt32(bitPattern:try p.g(0x44faf4))),target = UInt32(bitPattern:try p.g(0x455608))
        let x = 790-Int32(label.count)*8,y: Int32 = 531
        for (dx,dy): (Int32,Int32) in [(-1,1),(-1,0),(0,1),(0,0)] {
            events.append(.init("fontPass",[UInt32(bitPattern:x+dx),UInt32(bitPattern:y+dy),64,4,0,0],[label]))
            for (n,b) in label.enumerated() { try picture(font,false,x+dx+Int32(n*8),y+dy,Int32(Int8(bitPattern:b)),1,target) }
            events.append(.init("stringWrite",[UInt32(label.count),0]))
        }
        events.append(.init("stage",[0x4028a0]))
        try P.require(p.g(0x450b70) == 1 && (1..<240).contains(p.g(0x450b6c)) && p.g(0x450bfc) == 0,"Recording start notice")
        for at in [0x4553f2,0x4553f3] { try P.require(p.globals.integer(at:at-0x44d000,as:UInt8.self) != 0x64,"No volume input") }
        var filename: [UInt8] = []
        for offset in 0..<478 {
            let c = try p.globals.integer(at:0x44fd98-0x44d000+offset,as:UInt8.self)
            if c == 0 { break };filename.append(c)
        }
        try P.require(!filename.isEmpty && filename.count < 478,"Bounded own filename")
        let notice = Array("Start recording '".utf8)+filename+Array("'...".utf8)
        events.append(.init("format",[UInt32(notice.count)],[Array("Start recording '%s'...".utf8),notice]))
        try surfaceText(notice,target,3,531,0xff7800,installed)
        events.append(.init("stage",[0x43e940]))
        events.append(try OriginalApplicationLoadedCharacterTests.present(p.globals))
        events.append(.init("stage",[0x419e60]))
        for n in 0..<400 where n != 6 { try P.require(p.g(0x457588+n*4) == 0,"No other queued catalog sound") }
        for n in 0..<80 { try P.require(p.g(0x453e10+n*4) == 0,"No builtin sound") }
        let pending = try p.g(0x4575a0)
        try P.require([0,1].contains(pending) && p.g(0x44eecc) != 0 && p.g(0x44d000) == 100,"Finite sound output")
        if pending == 1 {
            let left = try p.g(0x457be0),right = try p.g(0x452188),buffer = UInt32(bitPattern:try p.g(0x452960))
            let level = min(left &+ right,100),pan = ((right &- left) &* 1500)/100
            try P.require(buffer != 0 && level > 0,"Queued live sound")
            events.append(.init("queueWrite",[0x4575a0,0]))
            events.append(.init("method",[buffer,0x40,UInt32(bitPattern:pan)]))
            events.append(.init("method",[buffer,0x3c,UInt32(bitPattern:((level &- 100) &* 2000)/100)]))
            events.append(.init("play",[0x452960,0]))
            events += [.init("method",[buffer,0x48]),.init("method",[buffer,0x34,0]),.init("method",[buffer,0x30,0,0,0])]
        }
        events.append(.init("dispatcherWrite",[0x457580,0]))
    }
    mutating func stage(_ stage: OriginalGameplayBody.Stage,_ before: P,_ after: P,_ target: UInt32,installed: Bool) throws -> [E] {
        events = []
        switch stage {
        case .camera:try camera(before,after,target)
        case .drawing:try world(before,target)
        case .hud:try hud(after)
        case .impulses:try diagnostic(before,installed)
        case .output:try output(before,installed)
        default:break
        }
        return events
    }
    static func sourceEvents(_ s: S.Section) -> [E] {
        if let first = s.first {
            if let d = first.drawing { return d.events }
            if let e = first.impulses { return e.events.map { .init($0.kind.rawValue,$0.arguments,$0.strings) } }
            if let e = first.gameplayReturn { return e.events }
            if let e = first.notices { return e.events }
            return []
        }
        if let c = s.continued {
            if let e = c.events.camera { return e }
            if let e = c.events.drawing { return e }
            if let e = c.events.impulses { return e.map { .init($0.kind.rawValue,$0.arguments,$0.strings) } }
            return []
        }
        return s.output?.events ?? []
    }
}

extension OriginalApplicationGameplayDrawingProjection {
    /// Derive terminal journal and graphics inputs from independently calculated
    /// expected events. Sound method observations precede their one terminal
    /// soundRequest; never append both observation routes to the journal.
    static func journal(_ events: [E],_ entry: OriginalApplicationInputSession.PendingContinuation) throws ->
        (operations:[OriginalApplicationLoadedMenuSession.Operation],graphics:[OriginalApplicationCatalogGraphicsComparison.Event]) {
        var operations: [OriginalApplicationLoadedMenuSession.Operation] = []
        var graphics: [OriginalApplicationCatalogGraphicsComparison.Event] = []
        var sound = false
        let slot = 6,buffer = try entry.match.globals.integer(at:0x452960-0x44d000,as:UInt32.self)
        let catalogBuffer = try XCTUnwrap(entry.entry.entry.snapshot.sounds.buffers[slot])
        try P.require(entry.entry.entry.snapshot.waveInputs.indices.contains(slot),"Own WAV slot")
        try P.require(buffer == catalogBuffer.output && buffer == entry.entry.entry.snapshot.waveInputs[slot].buffer,"Own sound global/cache/platform join")
        let catalog = entry.entry.entry
        let live = Set((catalog.startup.owner.loads + catalog.entry.common.sounds + Array(catalog.snapshot.sounds.buffers.values)).map(\.output).filter { $0 != 0 })
        for e in events {
            if e.kind == "stage" && e.arguments == [0x419e60] { sound = true }
            var graphic = true
            switch e.kind {
            case "blit":operations.append(.menu(.blit(try XCTUnwrap(e.blit),result:0)))
            case "getDC":operations.append(.menu(.getDC(e,result:0,output:0x12345678)))
            case "setBackgroundMode","setTextColor","textOut","releaseDC":operations.append(.menu(.graphics(e,result:0)))
            case "method":
                if sound {
                    try P.require(e.arguments.count >= 2 && live.contains(e.arguments[0]),"Own queued WAV owner")
                    operations.append(.menu(.soundMethod(.init("soundMethod",e.arguments,e.strings),ignoredResult:0)));graphic = false
                } else { operations.append(.menu(.present(e,result:0))) }
            default:graphic = false
            }
            if graphic { graphics.append(.init(request:nil,response:nil,kind:"front",event:e)) }
        }
        return (operations,graphics)
    }
}

extension OriginalApplicationGameplayDrawingProjection {
    static func other(_ p: P) -> [String] {
        (p.draw.map { ["random:146:200:\($0)"] } ?? []) + p.sounds.map { "sound:\($0.slot):\($0.x):\($0.index)" }
    }
    /// Old first-hit captures publish random helper returns, while lifecycle
    /// publishes typed events. Continuous empty event groups are sparse; the
    /// helper inventory and explicit effects array are checked alongside them.
    static func sourceOther(_ s: S.Section) throws -> [String] {
        let helpers = s.first?.helpers ?? s.continued?.helpers ?? s.output?.helpers ?? []
        let random = helpers.filter { $0.entry == 0x417170 }
        var result: [String] = []
        for h in random {
            try P.require(s.stage == .hits && h.arguments == [146,200] && h.returnPC == 0x41ef71,"Source finite random helper")
            result.append("random:146:200:\(Int32(bitPattern:h.result))")
        }
        let life = s.first?.lifecycle?.events ?? s.continued?.events.lifecycle ?? []
        let sounds = helpers.filter { $0.entry == 0x416fb0 }
        try P.require(life.count == sounds.count,"Source lifecycle/helper inventory")
        for (e,h) in zip(life,sounds) {
            try P.require(s.stage == .lifecycle && e.kind == "catalogSound" && e.arguments.count == 2 && e.arguments == h.arguments && h.returnPC == 0x40da70,"Source lifecycle sound order")
            result.append("sound:\(e.slot):\(Int32(bitPattern:e.arguments[0])):\(Int32(bitPattern:e.arguments[1]))")
        }
        try P.require((s.first?.commands?.events ?? s.continued?.events.commands ?? []).isEmpty,"Source empty commands")
        try P.require((s.continued?.effects ?? []).isEmpty,"No additional active-gameplay effects")
        if [.commands,.notices,.recording,.layout].contains(s.stage) {
            try P.require(helpers.isEmpty,"Source no-op terminal helper boundary")
        }
        return result
    }
}

extension OriginalApplicationGameplayDrawingProjection {
    func validateSourcePlatform(_ section: S.Section,_ source: S,_ p: P) throws {
        let target = UInt32(bitPattern:try p.g(0x455608))
        func resourceSurfaces(_ values: [String:UInt32]) throws {
            for (name,surface) in values {
                let raw = try XCTUnwrap(UInt32(name))
                try P.require(resolve(resourceToken(raw),false).surface == surface,"Source declared resource surface")
            }
        }
        func presentation(_ input: OriginalMenuPresentationInput,_ draws: [Int32],_ sounds: [UInt32],_ surfaces: [String:UInt32]) throws {
            try P.require(input.targetSurface == target && input.methodResult == 0 && input.queryResult == 0 && input.audioGetResult == 0 && input.audioSetResult == 0 && input.queriedAudio == 0x31002400 && input.audioVolume == -1234 && input.dcResult == 0 && input.dc == 0x12345678 && input.postResult == 0,"Source presentation input")
            try P.require(draws == [0,1] && sounds.count > 6 && Set(sounds).count == sounds.count && !sounds.contains(0),"Source ignored Blt results/live sound inputs")
            try P.require(sounds[6] == UInt32(bitPattern:p.g(0x452960)),"Source queued slot6 binding")
            try resourceSurfaces(surfaces)
        }
        if let d = section.first?.drawing {
            try P.require(d.target == target && d.mode == 0 && d.drawResults == [0,1] && d.fillResult == 0 && d.fillInputs.isEmpty,"Source drawing input")
            try P.require(d.surfaces.count == catalog.count,"Source complete surface vector")
            for (n,surface) in d.surfaces.enumerated() { try P.require(catalog[UInt32(n+1)]?.surface == surface,"Source bitmap surface vector") }
            if let phase = d.phase { try P.require(phase == p.g(0x450bd8),"Source drawing phase") }
            try resourceSurfaces(d.resourceSurfaces ?? [:])
        }
        if let d = section.first?.impulses {
            try P.require(d.target == target && d.mode == 0 && d.dcResult == 0 && d.dc == 0x12345678 && d.methodResult == 0,"Source diagnostic platform")
        }
        if let d = section.first?.gameplayReturn { try presentation(d.input,d.drawResults,d.loadedSoundBuffers,d.resourceSurfaces) }
        if section.first == nil {
            let d = try XCTUnwrap(source.continuousPlatform)
            try presentation(d.input,d.drawResults,d.loadedSoundBuffers,d.resourceSurfaces)
        }
    }
}
