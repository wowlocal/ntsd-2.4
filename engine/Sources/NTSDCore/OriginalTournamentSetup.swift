/// Ordinary mode2 menu20..25 in432ab0. The Start boundary is BEFORE4338c3:
/// its input clear and sound have happened, but bracket initialization has not.
/// World/catalog references are native ordinals; no caller stack is imported.
public enum OriginalTournamentSetup {
    static func advance(state: inout OriginalMatchPreparation, libraryText: inout OriginalLibSurfaceText?,
        target: UInt32, input: OriginalFrontScreenBodyInput, fillBacking: [UInt8],
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void,
        checkpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation) throws -> Void,
        continueBracket: OriginalTournamentBracket.Continuation = OriginalTournamentBracket.unavailable) throws -> OriginalCharacterScreenExit {
        var candidate=state,library=libraryText,local: [Int:Int32]=[:]
        let base=OriginalMatchPreparation.globalBase
        func error(_ message: String) -> OriginalStateError { .invalidStorage("Tournament setup: "+message) }
        func word(_ address: Int) throws -> Int32 { try candidate.global(address) }
        func write(_ address: Int,_ value: Int32) throws { try candidate.setGlobal(address,value) }
        func mark(_ pc: UInt32) throws { try checkpoint(.init(pc:pc,seat:-1,locals:local),candidate) }
        func finish(_ result: OriginalCharacterScreenExit) -> OriginalCharacterScreenExit { state=candidate;libraryText=library;return result }
        func sound(_ slot: Int) throws {
            try OriginalMatchPrelude.playSound(in:candidate.globals,slot:slot) { e in
                switch e {
                case .soundRequest(let loop):try observe(.init("soundRequest",[loop ? 1 : 0]))
                case .soundMethod(let resource,let offset,let args):try observe(.init("soundMethod",[resource,UInt32(offset)]+args))
                default:throw error("Sound helper event")
                }
            }
        }
        func cstr(_ record: OriginalStateRecord,_ offset: Int = 0) throws -> [UInt8] {
            guard record.bytes.indices.contains(offset),let end=record.bytes[offset...].firstIndex(of:0),
                  record.defined[offset...end].allSatisfy({ $0 }) else { throw error("String backing") }
            return Array(record.bytes[offset..<end])
        }
        func text(_ bytes: [UInt8],_ x: Int32,_ y: Int32,_ color: UInt32,_ background: UInt32 = 0) throws {
            if var value=library {
                try value.draw(bytes,target:UInt32(bitPattern:word(0x455608)),background:background,color:color,x:x,y:y,
                    dcResult:input.dcResult,dc:input.dc) { try observe(.init($0.kind.rawValue,$0.arguments,$0.strings)) }
                library=value
            } else {
                try OriginalSurfaceText.draw(bytes,target:UInt32(bitPattern:word(0x455608)),background:background,color:color,x:x,y:y,
                    dcResult:input.dcResult,dc:input.dc) { try observe(.init($0.kind.rawValue,$0.arguments,$0.strings)) }
            }
        }
        func bitmap(_ bitmap: OriginalCharacterScreenDraw.Bitmap,_ x: Int32,_ y: Int32,_ frame: Int32 = -1,
                    _ key: UInt32 = 0,_ destination: UInt32? = nil) throws {
            try draw(.init(bitmap:bitmap,x:x,y:y,target:destination ?? target,frame:frame,colorKey:key),candidate.globals)
        }
        func menuBitmap(_ slot: Int,_ x: Int32,_ y: Int32,_ frame: Int32 = -1,_ key: UInt32 = 0,
                        _ destination: UInt32? = nil) throws {
            try bitmap(.menu(UInt32(bitPattern:word(slot))),x,y,frame,key,destination)
        }
        func object(_ ordinal: Int32) throws -> OriginalLoadedObject {
            guard candidate.catalog.objects.indices.contains(Int(ordinal)) else { throw error("Catalog ordinal") }
            return candidate.catalog.objects[Int(ordinal)]
        }
        func catalogBitmap(_ ordinal: Int32,_ offset: Int,_ x: Int32,_ y: Int32,_ destination: UInt32? = nil) throws {
            let token=try object(ordinal).header.integer(at:offset,as:UInt32.self)
            guard token>0,candidate.catalog.bitmaps.indices.contains(Int(token-1)) else { throw error("Catalog bitmap binding") }
            try bitmap(.catalog(Int(token-1)),x,y,-1,0,destination)
        }
        func pulse() throws -> UInt32 {
            let value=try (word(0x4513e0)%6) &* 30
            return (UInt32(UInt8(truncatingIfNeeded:value &+ 70)) | 0xff00)<<8 | UInt32(UInt8(truncatingIfNeeded:value &+ 25))
        }
        func roster(_ seat: Int,_ direction: Int32) throws {
            guard let countRecord=candidate.catalog.registry.records[0x4d82380] else { throw error("Catalog count") }
            let count=try countRecord.integer(at:0,as:Int32.self)
            guard count>0,count==candidate.catalog.objects.count else { throw error("Catalog count binding") }
            let address=0x44d0c0+seat*4,flag=0x451344+seat*4
            for _ in 0...Int(count) {
                var ordinal=try word(address) &+ direction
                try write(address,ordinal);try write(flag,0)
                if direction>0 && ordinal>=count { try write(address,-1);try write(flag,1);return }
                if ordinal == -1 { try write(flag,1);return }
                if direction<0 && ordinal < -1 { ordinal=count &- 1;try write(address,ordinal) }
                let header=try object(ordinal).header
                if try header.integer(at:0x6f8,as:Int32.self) == 0 {
                    let group=try header.integer(at:0x6f4,as:Int32.self)/10
                    if try (group != 3 && group != 5) || word(0x458428)==1 { return }
                }
            }
            throw error("Roster traversal does not terminate")
        }
        func label(_ byte: UInt8,_ x: Int32,_ y: Int32,_ human: Bool) throws {
            try candidate.globals.write(byte,at:0x44d31c-base)
            try text(cstr(candidate.globals,0x44d31c-base),x,y,human ? 0xe6794d : 0x9679c8,0x8f472f)
        }
        func randomize() throws {
            try mark(0x433550)
            for seat in 0..<8 where try word(0x451344+seat*4)==1 {
                let selected=try (0..<8).map { try word(0x44d0c0+$0*4) }
                var choices: [UInt32]=[]
                for ordinal in 1..<candidate.catalog.objects.count where !selected.contains(Int32(ordinal)) {
                    let header=candidate.catalog.objects[ordinal].header
                    if try header.integer(at:0x6f8,as:Int32.self)==0 && header.integer(at:0x6f4,as:Int32.self)<30 { choices.append(UInt32(ordinal)) }
                }
                guard !choices.isEmpty else { throw error("Empty Random list needs original scratch provenance") }
                try observe(.init("candidates",[UInt32(seat)]+choices))
                let index=try candidate.drawMenuRandom(stream:0xf9,range:Int32(choices.count),observe:observe)
                try write(0x44d0c0+seat*4,Int32(choices[Int(index)]))
            }
            try write(0x44d020,25);try write(0x4513dc,2)
        }
        guard try word(0x451160)==2,(20...29).contains(try word(0x44d020)),candidate.actors.count==400 else { throw error("Other tournament stage") }
        try candidate.advanceMenuInput();try mark(0x432af2)
        if try word(0x44d020)==20 {
            try write(0x44d020,21);try write(0x4513e8,0);try write(0x4513e4,0)
            for seat in 0..<8 {
                try write(0x451344+seat*4,1);try write(0x44d0c0+seat*4,-1)
                try write(0x451364+seat*4,0);try write(0x44d0e0+seat*4,Int32(seat))
            }
        }
        try mark(0x432be2)
        try write(0x4513e0,(word(0x4513e0) &+ 1)%30)
        let x: Int32,y: Int32
        if try word(0x44d020)<=23 {
            x=27;y=106;local=[0x20:x,0x24:y]
            try menuBitmap(0x45116c,27,106,0)
            var e=OriginalFrontScreenEvent("fill")
            e.fill=try OriginalSurfaceFilling.request(target:UInt32(bitPattern:word(0x455608)),x:47,y:384,width:131,height:41,color:0x324d9a,backing:fillBacking)
            try observe(e)
        } else { x = -51;y=126;local=[0x20:x,0x24:y];try menuBitmap(0x45116c,119,126,9) }
        try mark(0x432c76)
        var current=try word(0x4513e8)
        guard (0...8).contains(current) else { throw error("Fighter count") }
        if current<8 {
            if try word(0x4513e4)==0 {
                if try word(0x4513a4) != 0 { try write(0x44d0c0+Int(current)*4,-1);try write(0x451344+Int(current)*4,1) }
                if try word(0x4513b0) != 0 { try roster(Int(current),1) }
                if try word(0x4513ac) != 0 { try roster(Int(current),-1) }
                if try word(0x4513b4) != 0 { try write(0x4513b4,0);try sound(0x45560c);try write(0x4513e4,1) }
                else if try word(0x4513b8) != 0 {
                    try write(0x4513b8,0);try sound(0x455614)
                    if current>0 { current &-= 1;try write(0x4513e8,current);try write(0x4513e4,1) }
                    else { try write(0x44d020,10);try candidate.resetOriginalInput();try write(0x457580,0) }
                }
            }
            let ordinal=try word(0x44d0c0+Int(current)*4),color=try word(0x4513e4)==0 ? pulse() : 0xffffff
            if ordinal<0 { try menuBitmap(0x44fd84,x &+ 25,y &+ 53);try text(Array(" Random".utf8),x &+ 59,y &+ 206,color) }
            else { try catalogBitmap(ordinal,0x6fc,x &+ 25,y &+ 53);try text(cstr(object(ordinal).nameTail),x &+ 59,y &+ 206,color) }
            var skipControllerText=false
            if try word(0x4513e4)==1 {
                if try word(0x4513b0) != 0 || word(0x4513ac) != 0 { try write(0x451364+Int(current)*4,word(0x451364+Int(current)*4)<=0 ? 1 : 0) }
                if try word(0x4513b4) != 0 {
                    try write(0x4513b4,0);try sound(0x45560c);current=try word(0x4513e8) &+ 1
                    try write(0x4513e4,0);try write(0x4513e8,current)
                    if current==8 { try write(0x44d020,22);try write(0x4513dc,0) }
                    skipControllerText=true
                } else if try word(0x4513b8) != 0 { try write(0x4513b8,0);try sound(0x455614);try write(0x4513e4,word(0x4513e4) &- 1) }
            }
            if try !skipControllerText && word(0x4513e4)>=1 {
                let name=try word(0x451364+Int(current)*4)==0 ? "Computer" : " Human"
                try text(Array(name.utf8),x &+ 59,y &+ 253,word(0x4513e4)==1 ? pulse() : 0xffffff)
            }
        }
        try write(0x451340,0)
        var humans: Int32=0
        for seat in 0..<Int(current) where try word(0x451364+seat*4)>0 { humans &+= 1;try write(0x451364+seat*4,humans) }
        if current>0 { try write(0x451340,humans) }
        let destination=UInt32(bitPattern:try word(0x455608))
        for seat in 0..<Int(current) {
            let participant=try word(0x44d0e0+seat*4)
            guard (0..<8).contains(participant) else { throw error("Draw order") }
            let ordinal=try word(0x44d0c0+Int(participant)*4),left=x &+ 216 &+ Int32(seat)*60
            if ordinal<0 { try menuBitmap(0x45116c,left,y &+ 260,1,0,destination) }
            else { try catalogBitmap(ordinal,0x728,left,y &+ 260,destination) }
            let controller=try word(0x451364+Int(participant)*4)
            try label(controller==0 ? 67 : UInt8(truncatingIfNeeded:controller &+ 48),left &+ 13,y &+ 307,controller != 0)
        }
        if current<8 {
            let ordinal=try word(0x44d0c0+Int(current)*4),participant=try word(0x44d0e0+Int(current)*4),left=x &+ 216 &+ current*60
            guard (0..<8).contains(participant) else { throw error("Current draw order") }
            if ordinal<0 { try menuBitmap(0x45116c,left,y &+ 260,1,0,destination) }
            else { try catalogBitmap(ordinal,0x728,left,y &+ 260,destination) }
            if try word(0x4513e4)>=1 {
                let human=try word(0x451364+Int(participant)*4) != 0
                try label(human ? UInt8(truncatingIfNeeded:humans &+ 49) : 67,left &+ 13,y &+ 307,human)
            }
        }
        try mark(0x433311)
        var directShuffle=false,directRandom=false
        if try word(0x44d020)==22 {
            for (frame,x,y): (Int32,Int32,Int32) in [(2,278,162),(3,314,179),(5,322,232),(6,426,232)] { try menuBitmap(0x45116c,x,y,frame) }
            if try word(0x4513dc)==0 { try menuBitmap(0x45116c,319,229,7) } else { try menuBitmap(0x45116c,420,230,8) }
            if try word(0x4513ac) != 0 || word(0x4513b0) != 0 { try write(0x4513dc,1 &- word(0x4513dc)) }
            if try word(0x4513b4) != 0 {
                try write(0x4513b4,0);try sound(0x45560c)
                if try word(0x4513dc)==0 { try write(0x44d020,23);try write(0x4513d8,0);directShuffle=true }
                else { try write(0x4513dc,0);try write(0x44d020,24);directRandom=true }
            } else if try word(0x4513b8) != 0 {
                try sound(0x455614);try write(0x4513b8,0);try write(0x44d020,21);try write(0x4513e4,1);try write(0x4513e8,7)
                for seat in 0..<8 { try write(0x44d0e0+seat*4,Int32(seat)) }
            }
        }
        if !directShuffle && !directRandom { try mark(0x433497) }
        if try word(0x44d020)==23 {
            for _ in 0..<50 {
                let a=Int(try candidate.drawMenuRandom(stream:0xf7,range:8,observe:observe)),b=Int(try candidate.drawMenuRandom(stream:0xf8,range:8,observe:observe))
                let first=try word(0x44d0e0+a*4),second=try word(0x44d0e0+b*4)
                try write(0x44d0e0+a*4,second);try write(0x44d0e0+b*4,first)
            }
            try write(0x4513d8,word(0x4513d8) &+ 1)
            if try word(0x4513d8)%5==0 { try sound(0x455610) }
            if try word(0x4513d8)>10 { try write(0x44d020,22);try write(0x4513dc,0);try mark(0x434a92);return finish(.returned) }
        }
        if try word(0x44d020)==24 { try randomize() }
        if try word(0x44d020)==25 {
            try mark(0x433660)
            try OriginalMusicConfiguration.advanceCommon(state:&candidate,libraryText:&library,mode:2,left:word(0x4513ac),right:word(0x4513b0),target:target,input:input,observe:observe)
            try menuBitmap(0x451178,3,3,8);try menuBitmap(0x451178,3,159,15,1)
            let highlights: [(Int32,Int32,Int32)]=[(9,92,16),(10,64,39),(11,40,64),(12,15,87),(13,37,111),(14,101,137)]
            let option=try word(0x4513dc)
            if highlights.indices.contains(Int(option)) { let (f,x,y)=highlights[Int(option)];try menuBitmap(0x451178,x,y,f) }
            if try word(0x44d028)==1 { try write(0x44d024,100) }
            let ordinal=try word(0x44d024)
            guard candidate.backgrounds.indices.contains(Int(ordinal)) else { throw error("Arena name") }
            try text(cstr(candidate.backgrounds[Int(ordinal)],0x3cc),174,91,0xff9b9b)
            let difficulty=try word(0x450c30),names: [Int32:String]=[2:"Easy",1:"Normal",0:"Difficult",-1:"Difficult"]
            if let name=names[difficulty] { try text(Array(name.utf8),174,115,0xff9b9b) }
            if try word(0x4513a4) != 0 { let next=try word(0x4513dc) &- 1;try write(0x4513dc,next == -1 ? 5 : next) }
            if try word(0x4513a8) != 0 { try write(0x4513dc,(word(0x4513dc) &+ 1)%6) }
            if try word(0x4513b4) != 0 {
                try write(0x4513b4,0);try sound(0x455610)
                switch try word(0x4513dc) {
                case 0:
                    try mark(0x4338c3)
                    let end=try continueBracket(&candidate,&local,&library,true);return finish(end)
                case 1:try write(0x44d020,20);try mark(0x434a92);return finish(.returned)
                case 2:try write(0x44d020,24);try mark(0x434a92);return finish(.returned)
                case 3:
                    try sound(0x455610);let arena=try word(0x44d024);try write(0x44d028,0)
                    if arena==100 { try write(0x44d024,99) }
                    else if arena==99 { try write(0x44d024,0) }
                    else {
                        let next=arena &+ 1;try write(0x44d024,next)
                        guard let record=candidate.catalog.registry.records[0x4d82380] else { throw error("Arena count") }
                        if try next==record.integer(at:4,as:Int32.self) { try write(0x44d024,100);try write(0x44d028,1) }
                    }
                case 4:let next=try word(0x450c30) &- 1;try write(0x450c30,next<0 ? 2 : next);try sound(0x455610)
                case 5:try write(0x44d020,10);try candidate.resetOriginalInput();try write(0x457580,0)
                default:break
                }
            } else if try word(0x4513b8) != 0 {
                try write(0x4513b8,0);try sound(0x455614);try write(0x44d020,22);try write(0x4513dc,0)
                for seat in 0..<8 where try word(0x451344+seat*4)==1 { try write(0x44d0c0+seat*4,-1) }
            }
        }
        if try word(0x44d020)>=26 {
            let end=try continueBracket(&candidate,&local,&library,false);return finish(end)
        }
        try mark(0x433ae7);try mark(0x434a92);return finish(.returned)
    }
}
