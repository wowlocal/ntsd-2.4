import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Output expectations from current records, never a Core output or after-state.
struct OriginalApplicationActiveOutputProjection {
    typealias P = OriginalApplicationGameplayStateProjection
    typealias D = OriginalApplicationGameplayDrawingProjection
    typealias E = OriginalFrontScreenEvent
    struct Write: Equatable,Decodable { let address: UInt32,pc: UInt32,size: Int,value: UInt32 }
    var globals: OriginalStateRecord
    var drawing: D
    let liveSounds: Set<UInt32>
    var writes: [Write] = []
    init(globals: OriginalStateRecord,drawing: D,liveSounds: Set<UInt32>) {
        self.globals = globals;self.drawing = drawing;self.liveSounds = liveSounds
    }
    static func sounds(_ ready: OriginalApplicationInputSession.PendingContinuation) -> Set<UInt32> {
        let c = ready.entry.entry
        return Set((c.startup.owner.loads+c.entry.common.sounds+Array(c.snapshot.sounds.buffers.values)).map(\.output).filter { $0 != 0 })
    }
    func g(_ address: Int) throws -> Int32 { try globals.integer(at:address-0x44d000,as:Int32.self) }
    mutating func store(_ address: Int,_ value: UInt32,_ size: Int,_ pc: UInt32) throws {
        try P.require(size == 1 || size == 4,"Output scalar store width")
        if size == 1 { try globals.write(UInt8(truncatingIfNeeded:value),at:address-0x44d000) }
        else { try globals.write(value,at:address-0x44d000) }
        writes.append(.init(address:UInt32(address),pc:pc,size:size,value:value))
    }
    mutating func advance(_ installed: Bool) throws {
        drawing.events = [];writes = []
        try P.require(globals.bytes.count == 0xb440 && g(0x44d78c) == 794 && g(0x44d790) == 550,"Output complete globals/viewport")
        try P.require(g(0x451160) == 0 && g(0x450c30) == 0 && g(0x450b84) == 0,"Finite VS Difficult label")
        drawing.events.append(.init("stage",[0x41b130]))
        for (literal,base,stores): (String,Int,[(Int,Int,UInt32)]) in [
            ("VS mode ",0x450c38,[(0,4,0x41b149),(4,4,0x41b14e),(8,1,0x41b154)]),
            ("(Difficult)",0x450c40,[(0,4,0x41b1fc),(4,4,0x41b204),(8,4,0x41b207)])] {
            let bytes = Array(literal.utf8)+[0]
            for (at,count,pc) in stores {
                let value = (0..<count).reduce(UInt32(0)) { $0 | UInt32(bytes[at+$1]) << (8*$1) }
                try store(base+at,value,count,pc)
                drawing.events.append(.init("labelWrite",[UInt32(base+at),UInt32(count),value]))
            }
        }
        let label = Array("VS mode (Difficult)".utf8)
        let font = drawing.resourceToken(UInt32(bitPattern:try g(0x44faf4))),target = UInt32(bitPattern:try g(0x455608))
        let x = 790-Int32(label.count)*8
        for (dx,dy): (Int32,Int32) in [(-1,1),(-1,0),(0,1),(0,0)] {
            drawing.events.append(.init("fontPass",[UInt32(bitPattern:x+dx),UInt32(531+dy),64,4,0,0],[label]))
            for (n,b) in label.enumerated() { try drawing.picture(font,false,x+dx+Int32(n*8),531+dy,Int32(Int8(bitPattern:b)),1,target) }
            try store(0x450c38+label.count,0,1,0x423a49)
            drawing.events.append(.init("stringWrite",[UInt32(label.count),0]))
        }
        drawing.events.append(.init("stage",[0x4028a0]))
        try P.require(g(0x450b70) == 1 && (1..<240).contains(g(0x450b6c)) && g(0x450bfc) == 0,"Finite retained recording notice")
        for at in [0x4553f2,0x4553f3] { try P.require(globals.integer(at:at-0x44d000,as:UInt8.self) != 100,"Finite no volume hotkey") }
        var filename: [UInt8] = []
        for offset in 0..<478 {
            let c = try globals.integer(at:0x44fd98-0x44d000+offset,as:UInt8.self)
            if c == 0 { break };filename.append(c)
        }
        try P.require(!filename.isEmpty && filename.count < 478,"Finite terminated own recording filename")
        let text = Array("Start recording '".utf8)+filename+Array("'...".utf8)
        drawing.events.append(.init("format",[UInt32(text.count)],[Array("Start recording '%s'...".utf8),text]))
        try drawing.surfaceText(text,target,3,531,0xff7800,installed)
        try store(0x450b6c,UInt32(bitPattern:g(0x450b6c) &+ 1),4,0x402967)
        drawing.events.append(.init("stage",[0x43e940]))
        drawing.events.append(try OriginalApplicationLoadedCharacterTests.present(globals))
        drawing.events.append(.init("stage",[0x419e60]))
        try drain()
        try store(0x457580,0,4,0x424746)
        drawing.events.append(.init("dispatcherWrite",[0x457580,0]))
    }
    /// Fixed original queue extents, independent of loaded-resource counts.
    mutating func drain() throws {
        if try g(0x44eecc) == 0 { return }
        for (count,pending,rightBase,leftBase,buffers,pc): (Int,Int,Int,Int,Int,UInt32) in [
            (400,0x457588,0x452170,0x457bc8,0x452948,0x419e9f),
            (80,0x453e10,0x4554c8,0x4527e8,0x451db0,0x419f7f)] {
            for slot in 0..<count {
                let offset = 4*slot,flag = pending+offset
                if try g(flag) <= 0 { continue }
                let right = try g(rightBase+offset),left = try g(leftBase+offset)
                let sum = right &+ left
                try store(flag,0,4,pc)
                drawing.events.append(.init("queueWrite",[UInt32(flag),0]))
                let level = min(sum,100)
                if level <= 0 { continue }
                let word = buffers+offset,buffer = UInt32(bitPattern:try g(word))
                try P.require(buffer != 0 && liveSounds.contains(buffer),"Queued current live sound owner")
                let pan = ((right &- left) &* 1500)/100
                let master = try g(0x44d000),volume = (((master &- 100) &* 3800)/100) &+ (((level &- 100) &* 2000)/100)
                drawing.events.append(.init("method",[buffer,0x40,UInt32(bitPattern:pan)]))
                drawing.events.append(.init("method",[buffer,0x3c,UInt32(bitPattern:volume)]))
                if try g(0x44d000) > 0 {
                    drawing.events.append(.init("play",[UInt32(word),0]))
                    drawing.events += [.init("method",[buffer,0x48]),.init("method",[buffer,0x34,0]),.init("method",[buffer,0x30,0,0,0])]
                }
            }
        }
    }
    /// Terminal journal paths are distinct from observation-only sound events.
    static func journal(_ events: [E],_ ready: OriginalApplicationInputSession.PendingContinuation) throws ->
        (operations:[OriginalApplicationLoadedMenuSession.Operation],graphics:[OriginalApplicationCatalogGraphicsComparison.Event]) {
        var operations: [OriginalApplicationLoadedMenuSession.Operation] = []
        var graphics: [OriginalApplicationCatalogGraphicsComparison.Event] = []
        var sound = false
        let live = sounds(ready)
        for e in events {
            if e.kind == "stage" && e.arguments == [0x419e60] { sound = true }
            var graphic = true
            switch e.kind {
            case "blit":operations.append(.menu(.blit(try XCTUnwrap(e.blit),result:0)))
            case "getDC":operations.append(.menu(.getDC(e,result:0,output:0x12345678)))
            case "setBackgroundMode","setTextColor","textOut","releaseDC":operations.append(.menu(.graphics(e,result:0)))
            case "method":
                if sound {
                    try P.require(e.arguments.count >= 2 && live.contains(e.arguments[0]),"Output journal current WAV owner")
                    operations.append(.menu(.soundMethod(.init("soundMethod",e.arguments,e.strings),ignoredResult:0)));graphic = false
                } else { operations.append(.menu(.present(e,result:0))) }
            default:graphic = false
            }
            if graphic { graphics.append(.init(request:nil,response:nil,kind:"front",event:e)) }
        }
        return (operations,graphics)
    }
}
