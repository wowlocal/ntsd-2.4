/// Tournament bracket26..29. Preparation at434349 is a distinct continuation;
/// it must construct actors/arena/replay before a played match can be claimed.
public enum OriginalTournamentBracket {
    public typealias Continuation = (inout OriginalMatchPreparation,inout [Int:Int32],inout OriginalLibSurfaceText?,Bool) throws -> OriginalCharacterScreenExit
    public static func unavailable(_ state: inout OriginalMatchPreparation,_ locals: inout [Int:Int32],_ text: inout OriginalLibSurfaceText?,_ initialize: Bool) throws -> OriginalCharacterScreenExit {
        guard initialize else { throw OriginalStateError.invalidStorage("Tournament bracket continuation was not supplied") }
        return .tournamentPrelude
    }
    static func advance(state: inout OriginalMatchPreparation,locals: inout [Int:Int32],libraryText: inout OriginalLibSurfaceText?,initialize: Bool,
        target: UInt32,fillBacking: [UInt8],resumeMusic: (inout OriginalStateRecord) throws -> Void,
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void,
        checkpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation) throws -> Void) throws -> OriginalCharacterScreenExit {
        var candidate=state,local=locals
        func error(_ s: String) -> OriginalStateError { .invalidStorage("Tournament bracket: "+s) }
        func word(_ a: Int) throws -> Int32 { try candidate.global(a) }
        func write(_ a: Int,_ v: Int32) throws { try candidate.setGlobal(a,v) }
        func mark(_ pc: UInt32) throws { try checkpoint(.init(pc:pc,seat:-1,locals:local),candidate) }
        func finish(_ result: OriginalCharacterScreenExit) -> OriginalCharacterScreenExit { state=candidate;locals=local;return result }
        func seat(_ index: Int32) throws -> Int { guard (0..<8).contains(index) else { throw error("Participant index") };return Int(index) }
        func participant(_ index: Int32) throws -> Int { try seat(word(0x44d0e0+seat(index)*4)) }
        func object(_ index: Int32) throws -> Int {
            let ordinal=Int(try word(0x44d0c0+participant(index)*4))
            guard candidate.catalog.objects.indices.contains(ordinal) else { throw error("Catalog binding") };return ordinal
        }
        func controller(_ index: Int32) throws -> Int32 { try word(0x451364+participant(index)*4) }
        func actor(_ index: Int) throws -> Int {
            guard (0..<20).contains(index) else { throw error("Actor slot") }
            let value=Int(try candidate.world.integer(at:0x194+index*4,as:UInt32.self))
            guard candidate.actors.indices.contains(value) else { throw error("Actor binding") };return value
        }
        func sound(_ slot: Int) throws {
            try OriginalMatchPrelude.playSound(in:candidate.globals,slot:slot) { e in
                switch e {
                case .soundRequest(let loop):try observe(.init("soundRequest",[loop ? 1 : 0]))
                case .soundMethod(let resource,let offset,let args):try observe(.init("soundMethod",[resource,UInt32(offset)]+args))
                default:throw error("Sound event")
                }
            }
        }
        func bitmap(_ frame: Int32,_ x: Int32,_ y: Int32) throws {
            try draw(.init(bitmap:.menu(UInt32(bitPattern:word(0x45116c))),x:x,y:y,target:target,frame:frame),candidate.globals)
        }
        func portrait(_ index: Int32) throws {
            let token=try candidate.catalog.objects[object(index)].header.integer(at:0x6fc,as:UInt32.self)
            guard token>0,candidate.catalog.bitmaps.indices.contains(Int(token-1)) else { throw error("Portrait binding") }
            try draw(.init(bitmap:.catalog(Int(token-1)),x:90,y:49,target:target),candidate.globals)
        }
        func rectangles(_ index: Int32,_ count: Int32,_ color: UInt32) throws {
            let i=try seat(index),n=min(count,7)
            if n>0 { for j in 0..<Int(n) {
                let p=0x44d158+i*56+j*8
                var event=OriginalFrontScreenEvent("fill")
                event.fill=try OriginalSurfaceFilling.request(target:UInt32(bitPattern:word(0x455608)),x:word(p) &- 51,y:word(p+4) &+ 126,
                    width:word(0x44d120+j*8),height:word(0x44d124+j*8),color:color,backing:fillBacking)
                try observe(event)
            } }
        }
        func clearAssignments() throws {
            for i in 0..<400 { try candidate.world.write(UInt8(0),at:4+i) }
            for i in 0..<20 { try write(0x4512d0+i*4,-1) }
        }
        func incrementWinner(_ index: Int32,_ amount: Int32) throws {
            let address=try 0x451384+seat(index)*4,value=try word(address) &+ amount
            try write(address,value==6 ? 7 : value)
        }
        if initialize {
            try write(0x44d020,26)
            for i in 0..<8 { try write(0x44d080+i*4,500);try write(0x44d0a0+i*4,-1);try write(0x451384+i*4,0) }
            try write(0x4513d8,25);try write(0x44d318,0);try resumeMusic(&candidate.globals)
        }
        try mark(0x433ae7)
        for i in Int32(0)..<8 {
            let score=min(try word(0x451384+Int(i)*4),7)
            if try score==7 && word(0x44d020)<29 { try write(0x44d020,29);try write(0x4513d4,i);try write(0x4513d8,0) }
            try rectangles(i,score,score<7 && score%2==1 ? 0x102860 : 0xffffff)
        }
        local[0x20]=0x44d318
        try mark(0x433bc9)
        if try word(0x44d020)==26 {
            let level=try word(0x44d318);var count: Int32=0
            try write(0x4513d0,0)
            for i in 0..<8 where try word(0x451384+i*4)==level {
                try write(0x4513c8+Int(count)*4,Int32(i));count &+= 1;if count==2 { break }
            }
            try write(0x4513d0,count)
            if count==0 && level<6 { try write(0x44d318,level &+ 2) }
            if count==2 {
                if try word(0x4513d8)>30 {
                    let index=try word(word(0x4513e0)%10<5 ? 0x4513c8 : 0x4513cc)
                    try rectangles(index,word(0x451384+seat(index)*4) &+ 2,0xffa0a0)
                }
                try write(0x4513d8,word(0x4513d8) &+ 1)
                if try word(0x4513b8) != 0 { try write(0x4513d8,80) }
                if try word(0x4513d8)==80 {
                    let first=try word(0x4513c8),second=try word(0x4513cc)
                    if try controller(first) != 0 || controller(second) != 0 {
                        try write(0x44d020,27);try write(0x4513d8,0);try clearAssignments()
                        for index in [first,second] { let address=try 0x451384+seat(index)*4;try write(address,word(address) &+ 1) }
                    } else {
                        try sound(0x45560c);try write(0x4513d8,0)
                        let a=try candidate.catalog.objects[object(first)].header.integer(at:0x6f4,as:Int32.self)/10
                        let b=try candidate.catalog.objects[object(second)].header.integer(at:0x6f4,as:Int32.self)/10
                        let selected: Int32
                        if a==5 && b != 5 { selected=0 }
                        else if b==5 && a != 5 { selected=1 }
                        else { selected=try candidate.drawMenuRandom(stream:a==5 ? 0xfb : 0xfa,range:2,observe:observe) }
                        let winner=selected==0 ? first : second,loser=selected==0 ? second : first
                        // The source promotes the winner only after both score stores.
                        let win=try 0x451384+seat(winner)*4,lose=try 0x451384+seat(loser)*4
                        try write(win,word(win) &+ 2);try write(lose,word(lose) &+ 1)
                        if try word(win)==6 { try write(win,7) }
                        let difficulty=try word(0x450c30),clamped=difficulty < -1 ? 0 : difficulty
                        let random=try candidate.drawMenuRandom(stream:0xfc,range:15 &+ clamped &* 12,observe:observe)
                        let hp=try 0x44d080+seat(winner)*4
                        try write(hp,((random &+ 85 &- difficulty &* 12) &* word(hp))/100)
                    }
                }
            }
        }
        try mark(0x433c22)
        if try word(0x44d020)==27 {
            if try word(0x4513d8)<2 {
                let position=try word(0x4513d8)
                guard (0..<2).contains(position) else { throw error("Assignment position") }
                let index=try word(0x4513c8+Int(position)*4)
                if try word(0x4513e0)%10<5 { try rectangles(index,word(0x451384+seat(index)*4) &+ 1,0xffa0a0) }
                let control=try controller(index)
                if control<=0 { try write(0x4513d8,position &+ 1);try write(0x4513dc,1) }
                else {
                    try bitmap(10,10,10);try bitmap(control &+ 10,169,24);try portrait(index)
                    for i in 0..<8 {
                        let a=try actor(i)
                        if try candidate.actors[a].integer(at:0xd1,as:UInt8.self) != 0 && candidate.actors[a].integer(at:0xca,as:UInt8.self)==0 {
                            if try candidate.world.integer(at:4+i,as:UInt8.self)==1 { try sound(0x455614);continue }
                            try write(0x4513b4,0);try candidate.actors[a].write(UInt8(1),at:0xca);try sound(0x45560c)
                            try write(0x4512d0+i*4,index);try candidate.world.write(UInt8(1),at:4+i)
                            try candidate.actors[a].write(UInt32(object(index)),at:0x368);try write(0x4513d8,position &+ 1);break
                        }
                    }
                }
            }
            if try word(0x4513d8)==2 {
                for (frame,x,y): (Int32,Int32,Int32) in [(2,278,162),(4,314,179),(5,322,232),(6,426,232)] { try bitmap(frame,x,y) }
                if try word(0x4513dc)==0 { try bitmap(7,319,229) } else { try bitmap(8,420,230) }
                if try word(0x4513ac) != 0 || word(0x4513b0) != 0 { try write(0x4513dc,1 &- word(0x4513dc)) }
                if try word(0x4513b4) != 0 {
                    try write(0x4513b4,0);try sound(0x45560c);try write(0x4513b4,0)
                    if try word(0x4513dc)==0 { try write(0x4513d8,3) }
                    else { try write(0x4513d8,0);try clearAssignments() }
                }
            }
            if try word(0x4513d8)==3 { try mark(0x434349);return finish(.tournamentMatchPreparation) }
        }
        try mark(0x4347c5)
        if try word(0x44d020)==28 {
            for i in 0..<20 {
                let index=try word(0x4512d0+i*4)
                if index > -1 {
                    let j=try seat(index),a=try actor(i)
                    try write(0x44d080+j*4,candidate.actors[a].integer(at:0x300,as:Int32.self))
                    try write(0x44d0a0+j*4,candidate.actors[a].integer(at:0x33c,as:Int32.self))
                }
            }
            let result=try word(0x450bf8),winner: Int32
            if result>=10 { winner=result &- 10 }
            else { let index=try candidate.drawMenuRandom(stream:0x100,range:2,observe:observe);winner=try word(0x4513c8+Int(index)*4) }
            try incrementWinner(winner,1);try write(0x44d020,26);try clearAssignments()
        }
        try mark(0x434992)
        if try word(0x44d020)==29 {
            if try word(0x4513d8)<50 { try write(0x4513d8,word(0x4513d8) &+ 1) }
            if try word(0x4513d8)>20 {
                if try word(0x4513d8)==21 {
                    try observe(.init("stopMusic"))
                    try OriginalMusicPlayback.stop(globals:candidate.globals) { event in
                        guard event.kind == .method else { throw error("Stop music event") }
                        try observe(.init("musicMethod",event.arguments));return .init()
                    }
                    try sound(0x455618)
                }
                try bitmap(10,10,10)
                let winner=try word(0x4513d4),control=try controller(winner)
                if control==0 { try bitmap(20,93,22) } else { try bitmap(control &+ 10,169,24) }
                try portrait(winner);try bitmap(19,23,175)
                if try word(0x4513b4) != 0 && word(0x4513d8)==50 {
                    try write(0x44d020,10);try candidate.resetOriginalInput();try write(0x457580,0)
                }
            }
        }
        try mark(0x434a92);return finish(.returned)
    }
}
