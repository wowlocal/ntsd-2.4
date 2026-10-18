/// Team Tournament bracket126..129. Preparation at436747 is a distinct continuation;
/// it must construct actors/arena/replay before a played match can be claimed.
public enum OriginalTeamTournamentBracket {
    public typealias Continuation = (inout OriginalMatchPreparation,inout [Int:Int32],inout OriginalLibSurfaceText?,Bool) throws -> OriginalCharacterScreenExit
    public static func unavailable(_ state: inout OriginalMatchPreparation,_ locals: inout [Int:Int32],_ text: inout OriginalLibSurfaceText?,_ initialize: Bool) throws -> OriginalCharacterScreenExit {
        guard initialize else { throw OriginalStateError.invalidStorage("Team Tournament bracket continuation was not supplied") }
        return .teamTournamentPrelude
    }
    static func advance(state: inout OriginalMatchPreparation,locals: inout [Int:Int32],libraryText: inout OriginalLibSurfaceText?,initialize: Bool,
        target: UInt32,fillBacking: [UInt8],resumeMusic: (inout OriginalStateRecord) throws -> Void,
        prepare: (inout OriginalMatchPreparation) throws -> Bool = { _ in false },
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void,
        checkpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation) throws -> Void) throws -> OriginalCharacterScreenExit {
        var candidate=state,local=locals
        func error(_ s: String) -> OriginalStateError { .invalidStorage("Team Tournament bracket: "+s) }
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
        func portrait(_ index: Int32,_ x: Int32 = 90) throws {
            let token=try candidate.catalog.objects[object(index)].header.integer(at:0x6fc,as:UInt32.self)
            guard token>0,candidate.catalog.bitmaps.indices.contains(Int(token-1)) else { throw error("Portrait binding") }
            try draw(.init(bitmap:.catalog(Int(token-1)),x:x,y:49,target:target),candidate.globals)
        }
        func rectangles(_ index: Int32,_ count: Int32,_ color: UInt32) throws {
            let i=try seat(index),n=min(count,7)
            if n>2 { for j in 2..<Int(n) {
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
            try write(0x44d020,126)
            for i in 0..<8 { try write(0x44d080+i*4,500);try write(0x44d0a0+i*4,-1);try write(0x451384+i*4,2) }
            try write(0x451404,25);try write(0x44d318,0);try resumeMusic(&candidate.globals)
        }
        try mark(0x435c7c)
        for i in stride(from: Int32(0),to: 8,by: 2) {
            let score=min(try word(0x451384+Int(i)*4),7)
            if try score==7 && word(0x44d020)<129 { try write(0x44d020,129);try write(0x451400,i);try write(0x451404,0) }
            try rectangles(i,score,score<7 && score%2==1 ? 0x192f67 : 0xffffff)
        }
        try mark(0x435d59)
        if try word(0x44d020)==126 {
            let level=try word(0x44d318);var count: Int32=0
            try write(0x4513fc,0)
            for i in stride(from: Int32(0),to: 8,by: 2) where try word(0x451384+Int(i)*4)==level {
                try write(0x4513ec+Int(count)*4,i);try write(0x4513ec+Int(count+1)*4,i+1)
                count &+= 2;if count==4 { break }
            }
            try write(0x4513fc,count)
            if count==0 && level<6 { try write(0x44d318,level &+ 2) }
            if count==4 {
                if try word(0x451404)>30 {
                    let index=try word(word(0x45140c)%10<5 ? 0x4513ec : 0x4513f4)
                    try rectangles(index,word(0x451384+seat(index)*4) &+ 2,0xffa7a7)
                }
                try write(0x451404,word(0x451404) &+ 1)
                if try word(0x4513b8) != 0 { try write(0x451404,80) }
                if try word(0x451404)==80 {
                    let members=try (0..<4).map { try word(0x4513ec+$0*4) }
                    if try members.contains(where: { try controller($0) != 0 }) {
                        try write(0x44d020,127);try write(0x451404,0);try clearAssignments()
                        for index in members { let address=try 0x451384+seat(index)*4;try write(address,word(address) &+ 1) }
                    } else {
                        try sound(0x45560c);try write(0x451404,0)
                        let special=try members.map { try candidate.catalog.objects[object($0)].header.integer(at:0x6f4,as:Int32.self)/10==5 }
                        let a=special[0] || special[1],b=special[2] || special[3],selected: Int
                        if a && !b { selected=0 }
                        else if b && !a { selected=2 }
                        else { selected=Int(try candidate.drawMenuRandom(stream:a ? 0x106 : 0x105,range:2,observe:observe))*2 }
                        // Both winners, both losers, promotion, then each HP draw/store.
                        for i in selected..<selected+2 { let p=try 0x451384+seat(members[i])*4;try write(p,word(p) &+ 2) }
                        for i in (2-selected)..<(4-selected) { let p=try 0x451384+seat(members[i])*4;try write(p,word(p) &+ 1) }
                        for i in selected..<selected+2 { let p=try 0x451384+seat(members[i])*4;if try word(p)==6 { try write(p,7) } }
                        let difficulty=try word(0x450c30),range=15 &+ difficulty &* 18
                        guard range>0 else { throw error("CPU HP RNG range requires ordinary difficulty provenance") }
                        for i in 0..<2 {
                            let random=try candidate.drawMenuRandom(stream:Int32(0x107+i),range:range,observe:observe)
                            let hp=try 0x44d080+seat(members[selected+i])*4
                            try write(hp,((random &+ 85 &- difficulty &* 18) &* word(hp))/100)
                        }
                    }
                }
            }
        }
        try mark(0x435dbc)
        if try word(0x44d020)==127 {
            if try word(0x451404)<4 {
                let position=try word(0x451404)
                guard (0..<4).contains(position) else { throw error("Assignment position") }
                let index=try word(0x4513ec+Int(position)*4)
                if try word(0x45140c)%10<5 { try rectangles(index,word(0x451384+seat(index)*4) &+ 1,0xffa7a7) }
                let control=try controller(index)
                if control<=0 { try write(0x451404,position &+ 1);try write(0x451408,1) }
                else {
                    try bitmap(10,10,10);try bitmap(control &+ 10,169,24);try portrait(index)
                    for i in 0..<8 {
                        let a=try actor(i)
                        if try candidate.actors[a].integer(at:0xd1,as:UInt8.self) != 0 && candidate.actors[a].integer(at:0xca,as:UInt8.self)==0 {
                            if try candidate.world.integer(at:4+i,as:UInt8.self)==1 { try sound(0x455614);continue }
                            try write(0x4513b4,0);try candidate.actors[a].write(UInt8(1),at:0xca);try sound(0x45560c)
                            try write(0x4512d0+i*4,index);try candidate.world.write(UInt8(1),at:4+i)
                            try candidate.actors[a].write(UInt32(object(index)),at:0x368);try write(0x451404,position &+ 1);break
                        }
                    }
                }
            }
            if try word(0x451404)==4 {
                for (frame,x,y): (Int32,Int32,Int32) in [(2,278,162),(4,314,179),(5,322,232),(6,426,232)] { try bitmap(frame,x,y) }
                if try word(0x451408)==0 { try bitmap(7,319,229) } else { try bitmap(8,420,230) }
                if try word(0x4513ac) != 0 || word(0x4513b0) != 0 { try write(0x451408,1 &- word(0x451408)) }
                if try word(0x4513b4) != 0 {
                    try write(0x4513b4,0);try sound(0x45560c);try write(0x4513b4,0)
                    if try word(0x451408)==0 { try write(0x451404,5) }
                    else { try write(0x451404,0);try clearAssignments() }
                }
            }
            if try word(0x451404)==5 {
                try mark(0x4366c5)
                for member in 0..<4 {
                    let index=try word(0x4513ec+member*4)
                    if try controller(index)==0 {
                        for i in 0..<8 where try candidate.world.integer(at:4+i,as:UInt8.self)==0 && candidate.world.integer(at:14+i,as:UInt8.self)==0 {
                            try sound(0x45560c);try write(0x4512f8+i*4,index);try candidate.world.write(UInt8(1),at:14+i)
                            try candidate.actors[actor(10+i)].write(UInt32(object(index)),at:0x368);break
                        }
                    }
                }
                try mark(0x436747)
                if try !prepare(&candidate) { return finish(.teamTournamentMatchPreparation) }
            }
        }
        try mark(0x436afd)
        if try word(0x44d020)==128 {
            for i in 0..<20 {
                let index=try word(0x4512d0+i*4)
                if index > -1 {
                    let j=try seat(index),a=try actor(i)
                    if try candidate.actors[a].integer(at:0x2fc,as:Int32.self)<=0 {
                        try candidate.actors[a].write(candidate.actors[a].integer(at:0x300,as:Int32.self)/2,at:0x300)
                    }
                    try write(0x44d080+j*4,candidate.actors[a].integer(at:0x300,as:Int32.self))
                    try write(0x44d0a0+j*4,candidate.actors[a].integer(at:0x33c,as:Int32.self))
                    if try candidate.actors[a].integer(at:0x364,as:Int32.self)==word(0x450bf8) { try incrementWinner(index,1) }
                }
            }
            if try word(0x450bf8)==(-1) {
                let chosen=Int(try candidate.drawMenuRandom(stream:0x10c,range:2,observe:observe))*2
                let a=try word(0x4513ec+chosen*4),b=try word(0x4513ec+(chosen+1)*4)
                // Source stores both increments before either6->7 promotion.
                let pa=try 0x451384+seat(a)*4,pb=try 0x451384+seat(b)*4
                try write(pa,word(pa) &+ 1);try write(pb,word(pb) &+ 1)
                if try word(pa)==6 { try write(pa,7) };if try word(pb)==6 { try write(pb,7) }
            }
            try write(0x44d020,126);try clearAssignments()
        }
        try mark(0x436e5e)
        if try word(0x44d020)==129 {
            if try word(0x451404)<50 { try write(0x451404,word(0x451404) &+ 1) }
            if try word(0x451404)>20 {
                if try word(0x451404)==21 {
                    try observe(.init("stopMusic"))
                    try OriginalMusicPlayback.stop(globals:candidate.globals) { event in
                        guard event.kind == .method else { throw error("Stop music event") }
                        try observe(.init("musicMethod",event.arguments));return .init()
                    }
                    try sound(0x455618)
                }
                try bitmap(10,10,10);try bitmap(21,109,22)
                let winner=try word(0x451400),team=try word(0x44d100+seat(winner)*4)
                try bitmap(team &+ 10,169,24);try portrait(winner,30)
                // Actual436f38 addresses selected[first mapped fighter+1].
                let next=try participant(winner)+1
                guard (0..<8).contains(next) else { throw error("Winner pair backing") }
                let ordinal=Int(try word(0x44d0c0+next*4))
                guard candidate.catalog.objects.indices.contains(ordinal) else { throw error("Winner partner binding") }
                let token=try candidate.catalog.objects[ordinal].header.integer(at:0x6fc,as:UInt32.self)
                guard token>0,candidate.catalog.bitmaps.indices.contains(Int(token-1)) else { throw error("Winner partner portrait") }
                try draw(.init(bitmap:.catalog(Int(token-1)),x:150,y:49,target:target),candidate.globals)
                try bitmap(19,23,175)
                if try word(0x4513b4) != 0 && word(0x451404)==50 {
                    try write(0x44d020,10);try candidate.resetOriginalInput();try write(0x457580,0)
                }
            }
        }
        try mark(0x436f9d);return finish(.returned)
    }
}
