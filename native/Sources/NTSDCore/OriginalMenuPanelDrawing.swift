public enum OriginalMenuPanelDrawingError: Error, Equatable {
    case zeroTimerRange
    case noSelectableRow
}

/// Whole423b00, including the blink tail after the shared ret. Bitmap ownership,
/// platform timer and caller's live previous-button word are explicit inputs.
/// State commits only at normal return; callers must buffer external effects.
public enum OriginalMenuPanelDrawing {
    public struct Result: Equatable {
        public let minimumX: Int32?, minimumY: Int32?
    }
    public static func draw(globals: inout OriginalStateRecord,target: UInt32,
        previous: (OriginalStateRecord) throws -> Int32,
        bitmap: (UInt32) throws -> OriginalStateRecord,
        milliseconds: () throws -> UInt32,
        drawBitmap: ([UInt32],OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws -> Result {
        var state=globals
        let base=OriginalMatchPreparation.globalBase
        func word(_ p: Int) throws -> Int32 { try state.integer(at:p-base,as:Int32.self) }
        func byte(_ p: Int) throws -> UInt8 { try state.integer(at:p-base,as:UInt8.self) }
        func put(_ p: Int,_ v: Int32) throws { try state.write(v,at:p-base) }
        func bits(_ v: Int32) -> UInt32 { UInt32(bitPattern:v) }
        func emit(_ kind: String,_ args: [UInt32] = [],_ strings: [[UInt8]] = []) throws { try observe(.init(kind,args,strings)) }
        func draw(_ address: UInt32,_ x: Int32,_ y: Int32,_ frame: Int32) throws {
            let args=[address,bits(x),bits(y),bits(frame),1,0,target]
            try emit("draw",args);try drawBitmap(args,state)
        }
        func fill(_ x: Int32,_ y: Int32,_ w: Int32,_ h: Int32) throws {
            var event=OriginalFrontScreenEvent("fill")
            event.fill=try OriginalSurfaceFilling.request(target:bits(word(0x455608)),x:x,y:y,width:w,height:h,color:0xffffff,backing:[UInt8](repeating:0,count:100))
            try observe(event)
        }
        func clicked() throws -> Bool { try word(0x457580)==1 && previous(state)==0 }
        func link(_ p: Int) throws {
            try put(0x457580,0)
            try OriginalMatchPrelude.confirmationSound(in:state) { e in
                switch e {
                case .soundRequest(let loop):try emit("soundRequest",[loop ? 1 : 0])
                case .soundMethod(let resource,let offset,let args):try emit("soundMethod",[resource,UInt32(offset)]+args)
                default:throw OriginalStateError.invalidStorage("Panel sound event")
                }
            }
            try emit("sleep",[300])
            var bytes:[UInt8]=[],i=0
            while true { let b=try byte(p+i);if b==0 { break };bytes.append(b);i += 1 }
            try emit("shell",[0,0,0,1],[Array("open".utf8),bytes])
        }
        func hold(_ duration: Int32) throws {
            let value=try word(0x45841c)
            if value>duration { try put(0x45841c,0) }
            else if value>4 && value < duration &- 10 { try put(0x45841c,5) }
        }
        func navigate(_ delta: Int32) throws {
            var row=try word(0x458418)
            for _ in 0..<8 {
                row = row &+ delta
                if delta<0 && row<0 { row=7 }
                if delta>0 && row>=8 { row=0 }
                guard (0..<8).contains(row) else { throw OriginalStateError.invalidStorage("Panel navigation row") }
                let start=try word(0x452928+Int(row)*4);try put(0x44d780,start)
                if try start>=0 && byte(0x4546f8+Int(row)*100) != 63 { try put(0x458418,row);return }
            }
            throw OriginalMenuPanelDrawingError.noSelectableRow
        }
        let panel=bits(try word(0x458420))
        guard panel != 0 else { return .init(minimumX:nil,minimumY:nil) }
        guard try bitmap(panel).integer(at:0,as:UInt32.self) != 0 else { return .init(minimumX:nil,minimumY:nil) }
        var x:Int32=590
        let y=try word(0x453da4) &+ 199,time=try word(0x44d780)
        if time == -1 {
            var maximum:Int32=0
            for row in 0..<8 {
                let end=try word(0x4546d0+row*4)
                if try end>maximum && byte(0x4546f8+row*100) != 63 { maximum=end }
            }
            let now=try milliseconds();try emit("timer",[now])
            guard maximum != 0 else { throw OriginalMenuPanelDrawingError.zeroTimerRange }
            try put(0x458418,0);try put(0x45841c,4);try put(0x44d780,Int32(now%UInt32(maximum)))
        } else {
            for row in 0..<8 where try word(0x452928+row*4)<=time && word(0x4546d0+row*4)>time && byte(0x4546f8+row*100) != 63 {
                let duration=try word(0x453f50+row*4)
                var progress=try word(0x45841c);try put(0x458418,Int32(row))
                if progress < duration &+ 10 { progress=progress &+ 1;try put(0x45841c,progress) }
                if progress<4 { x=788 &- (progress &* 60) }
                else if progress > duration &- 10 && progress<duration { x=788 &+ ((progress &- duration) &* 20) }
                else if progress>=duration { x=840 }
                try draw(panel,x,y,Int32(row+2))
                if try word(0x4546f0)>590 && word(0x453cdc)>y && word(0x453cdc)<y &+ 194 {
                    try hold(duration)
                    if x &+ 194 < 794 {
                        try fill(x,y,198,1);try fill(x,y &+ 193,198,1)
                        try fill(x,y,1,194);try fill(x &+ 197,y,1,194)
                    }
                    if try clicked() { try link(0x4546f8+row*100) }
                }
                break
            }
        }
        var active=0
        for row in 0..<8 where try byte(0x4546f8+row*100) != 63 { active += 1 }
        if active>1 {
            for direction in [-1,1] {
                let dx=x &+ (direction<0 ? 160 : 179),mouseX=try word(0x4546f0),mouseY=try word(0x453cdc)
                let hover=mouseX>dx && (direction>0 || mouseX < x &+ 179) && mouseY > y &- 18 && mouseY<=y
                if hover { try hold(word(0x453f70)) }
                try draw(bits(word(0x45117c)),dx,y &- 14,Int32(direction<0 ? (hover ? 10 : 8) : (hover ? 11 : 9)))
                if try hover && clicked() { try put(0x457580,0);try navigate(Int32(direction)) }
            }
        }
        try draw(bits(word(0x458420)),0,422,10)
        var minX:Int32=999,minY:Int32=999
        for row in 0..<24 {
            let a=try word(0x4583b8+row*4)
            if try a == -99 || byte(0x454a18+row*100) == 63 { continue }
            minX=min(minX,a);let b=try word(0x453c08+row*4);minY=min(minY,b)
            let width=try word(0x453f70+row*4),height=try word(0x453ce0+row*4)
            if try word(0x4546f0)>a && word(0x4546f0)<a &+ width && word(0x453cdc)>b && (word(0x453cdc)<b &+ height || row/6==3) {
                try fill(a,b,width,1)
                try fill(word(0x4583b8+row*4),word(0x453c08+row*4) &+ word(0x453ce0+row*4) &- 1,word(0x453f70+row*4),1)
                try fill(word(0x4583b8+row*4),word(0x453c08+row*4),1,word(0x453ce0+row*4))
                try fill(word(0x4583b8+row*4) &+ word(0x453f70+row*4) &- 1,word(0x453c08+row*4),1,word(0x453ce0+row*4))
                if try clicked() { try link(0x454a18+row*100) }
            }
        }
        if minX<999 && minY<999 { try draw(bits(word(0x451188)),minX,minY &- 10,12) }
        if try word(0x4554bc)>word(0x44d03c) && byte(0x453da8) != 63 {
            let progress=try word(0x4511b4) &+ 1;try put(0x4511b4,progress)
            let hover=try word(0x4546f0)<397 && word(0x453cdc)<34
            if progress>=60 { try put(0x4511b4,0) }
            try draw(bits(word(0x458420)),0,0,progress>=60 || progress<30 || hover ? 1 : 0)
            if hover { try draw(bits(word(0x458420)),0,0,1);if try clicked() { try link(0x453da8) } }
        }
        globals=state;return .init(minimumX:minX,minimumY:minY)
    }
}
