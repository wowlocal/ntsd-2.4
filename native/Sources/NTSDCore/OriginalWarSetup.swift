/// Owned War bitmaps and Object bindings retained across438b40 calls.
/// Unit globals use ordinal+1, so original NULL stays distinct from Object0.
/// Initialize the literal PE globals once with OriginalWarTroops.initializeFileData
/// before entering this menu; retained input/global values are never reset here.
public struct OriginalWarMenuMemory: Equatable, Sendable {
    public internal(set) var bitmaps: [UInt32:OriginalLoadedBitmap] = [:]
    public internal(set) var unitObjects: [Int:Int] = [:]
    public init() {}
}

/// Mode4/menu200..219, including the branches after439ecd, through the
/// ordinary ret1c or BEFORE43a21f battle preparation. Pending source comparison.
/// All state and value-environment effects commit together. The environment
/// must buffer external drawing/device/observer effects until the caller commits.
public enum OriginalWarSetup {
    public typealias Continuation = (inout OriginalMatchPreparation,inout OriginalLibSurfaceText?) throws -> OriginalCharacterScreenExit
    public static func unavailable(_ state: inout OriginalMatchPreparation,_ text: inout OriginalLibSurfaceText?) throws -> OriginalCharacterScreenExit {
        throw OriginalStateError.invalidStorage("War menu ownership/continuation is unavailable")
    }

    public static func advance<Environment>(state: inout OriginalMatchPreparation,
        memory: inout OriginalWarMenuMemory,libraryText: inout OriginalLibSurfaceText?,
        environment: inout Environment,target: UInt32,input: OriginalFrontScreenBodyInput,fillBacking: [UInt8],
        allocate: (Int,inout Environment) throws -> OriginalInterfaceAllocation,
        construct: (String,OriginalInterfaceAllocation,UInt32,inout Environment) throws -> OriginalLoadedBitmap,
        bitmapStorage: (UInt32,inout Environment) throws -> OriginalStateRecord,
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord,OriginalWarMenuMemory,inout Environment) throws -> Void,
        observe: (OriginalFrontScreenEvent,inout Environment) throws -> Void = { _,_ in },
        resourceEvent: (OriginalInterfaceEvent,inout Environment) throws -> Void = { _,_ in },
        beforeResource: (Int,OriginalStateRecord,OriginalWarMenuMemory,inout Environment) throws -> Void = { _,_,_,_ in },
        checkpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation,OriginalWarMenuMemory,inout Environment) throws -> Void = { _,_,_,_ in }) throws -> OriginalCharacterScreenExit {
        var candidate=state,owned=memory,library=libraryText,context=environment
        var local: [Int:Int32]=[:]
        func error(_ s: String) -> OriginalStateError { .invalidStorage("War setup: "+s) }
        func word(_ a: Int) throws -> Int32 { try candidate.global(a) }
        func write(_ a: Int,_ v: Int32) throws { try candidate.setGlobal(a,v) }
        func button(_ a: Int) throws -> Bool { try word(a) != 0 }
        func side() throws -> Int {
            let value=try word(0x451ba8)
            guard (0..<2).contains(value) else { throw error("Team side") };return Int(value)
        }
        func mark(_ pc: UInt32) throws { try checkpoint(.init(pc:pc,seat:-1,locals:local),candidate,owned,&context) }
        func finish(_ end: OriginalCharacterScreenExit) -> OriginalCharacterScreenExit {
            state=candidate;memory=owned;libraryText=library;environment=context;return end
        }
        func sound(_ slot: Int) throws {
            try OriginalMatchPrelude.playSound(in:candidate.globals,slot:slot) { e in
                switch e {
                case .soundRequest(let loop):try observe(.init("soundRequest",[loop ? 1 : 0]),&context)
                case .soundMethod(let resource,let offset,let args):try observe(.init("soundMethod",[resource,UInt32(offset)]+args),&context)
                default:throw error("Sound helper event")
                }
            }
        }
        func returnMenu(_ commonEntry: Bool = true) throws -> OriginalCharacterScreenExit {
            if commonEntry { try mark(0x439e76) }
            if try button(0x4513b4) || button(0x4513bc) { try sound(0x45560c) }
            if try button(0x4513b8) { try sound(0x455614) }
            try mark(0x439ea6);return finish(.returned)
        }
        func actor(_ seat: Int) throws -> Int {
            let ordinal=try candidate.world.integer(at:0x194+seat*4,as:UInt32.self)
            guard candidate.actors.indices.contains(Int(ordinal)) else { throw error("Seat Actor binding") };return Int(ordinal)
        }
        func team(_ seat: Int) throws -> Int32 { try candidate.actors[actor(seat)].integer(at:0x364,as:Int32.self) }
        func catalogBitmap(_ ordinal: Int,_ x: Int32,_ y: Int32) throws {
            guard candidate.catalog.objects.indices.contains(ordinal) else { throw error("Object ordinal") }
            let token=try candidate.catalog.objects[ordinal].header.integer(at:0x728,as:UInt32.self)
            guard token>0,candidate.catalog.bitmaps.indices.contains(Int(token-1)) else { throw error("Object small bitmap binding") }
            try draw(.init(bitmap:.catalog(Int(token-1)),x:x,y:y,target:UInt32(bitPattern:word(0x455608))),candidate.globals,owned,&context)
        }
        func bitmap(_ slot: Int,_ x: Int32,_ y: Int32,_ frame: Int32 = -1,_ key: UInt32 = 0,_ destination: UInt32? = nil) throws {
            let token=UInt32(bitPattern:try word(slot))
            if slot==0x451bb0 || slot==0x451bac {
                guard token != 0,owned.bitmaps[token] != nil else { throw error("Missing live War bitmap") }
            }
            try draw(.init(bitmap:.menu(token),x:x,y:y,target:destination ?? target,frame:frame,colorKey:key),candidate.globals,owned,&context)
        }
        func text(_ bytes: [UInt8],_ x: Int32,_ y: Int32,_ color: UInt32,_ background: UInt32 = 0) throws {
            let destination=UInt32(bitPattern:try word(0x455608))
            if var value=library {
                try value.draw(bytes,target:destination,background:background,color:color,x:x,y:y,dcResult:input.dcResult,dc:input.dc) {
                    try observe(.init($0.kind.rawValue,$0.arguments,$0.strings),&context)
                };library=value
            } else {
                try OriginalSurfaceText.draw(bytes,target:destination,background:background,color:color,x:x,y:y,dcResult:input.dcResult,dc:input.dc) {
                    try observe(.init($0.kind.rawValue,$0.arguments,$0.strings),&context)
                }
            }
        }
        func formatted(_ value: String,_ format: String) throws -> [UInt8] {
            let bytes=Array(value.utf8)
            try observe(.init("format",[UInt32(bytes.count)],[Array(format.utf8),bytes]),&context);return bytes
        }
        func fill(_ x: Int32,_ y: Int32,_ width: Int32,_ height: Int32) throws {
            var e=OriginalFrontScreenEvent("fill")
            e.fill=try OriginalSurfaceFilling.request(target:UInt32(bitPattern:word(0x455608)),x:x,y:y,width:width,height:height,color:0,backing:fillBacking)
            try observe(e,&context)
        }
        func frame(_ pulse: Bool,_ x: Int32,_ y: Int32,_ width: Int32,_ height: Int32,_ color: UInt32 = 0xffffff) throws {
            try observe(.init("warFrame",[pulse ? 0x4389a0 : 0x438ad0,UInt32(bitPattern:x),UInt32(bitPattern:y),UInt32(bitPattern:width),UInt32(bitPattern:height),color]),&context)
            try OriginalWarFrames.draw(globals:&candidate.globals,pulse:pulse,x:x,y:y,width:width,height:height,color:color,backing:fillBacking) { request in
                var e=OriginalFrontScreenEvent("fill");e.fill=request;try observe(e,&context)
            }
        }
        func cstr(_ record: OriginalStateRecord,_ offset: Int) throws -> [UInt8] {
            guard record.bytes.indices.contains(offset),let end=record.bytes[offset...].firstIndex(of:0),record.defined[offset...end].allSatisfy({ $0 }) else { throw error("Arena string backing") }
            return Array(record.bytes[offset..<end])
        }
        guard try word(0x451160)==4,try (200..<300).contains(word(0x44d020)),try word(0x44d37c)==11,
            candidate.actors.count==400,try candidate.world.integer(at:0x7d4,as:UInt32.self)==0 else { throw error("Mode/menu/catalog domain") }
        try candidate.advanceMenuInput();try mark(0x438bbb)
        let initialize=try word(0x44d774)
        if initialize==1 {
            try OriginalWarTroops.initialize(&candidate.globals)
            let device=UInt32(bitPattern:try word(0x457578))
            for (index,path) in ["BATTLEMODE","BATTLETROOPS"].enumerated() {
                try beforeResource(index,candidate.globals,owned,&context)
                try resourceEvent(.init(.allocate,[0x1f50]),&context)
                let allocation=try allocate(index,&context)
                if allocation.address != 0 {
                    guard owned.bitmaps[allocation.address]==nil else { throw error("Live War allocation reused") }
                    try resourceEvent(.init(.construct,[allocation.address,0x40,0],[Array(path.utf8)]),&context)
                    owned.bitmaps[allocation.address]=try .checkedConstruction(construct(path,allocation,device,&context),path:path,optional:false)
                }
                try write(index==0 ? 0x451bb0 : 0x451bac,Int32(bitPattern:allocation.address))
            }
            guard let counts=candidate.catalog.registry.records[0x4d82380],try counts.integer(at:0,as:Int32.self)==candidate.catalog.objects.count else { throw error("Object count binding") }
            for unit in 0..<11 {
                let id=try word(0x44d350+unit*4)
                // Last ID match wins. No match retains the prior binding/NULL.
                for (ordinal,object) in candidate.catalog.objects.enumerated() where try object.header.integer(at:0x6f4,as:Int32.self)==id {
                    owned.unitObjects[unit]=ordinal;try write(0x451b38+unit*4,Int32(ordinal+1))
                }
            }
            try mark(0x438d2a)
            let token=UInt32(bitPattern:try word(0x451bb0))
            guard token != 0,var mode=owned.bitmaps[token] else { throw error("NULL BATTLEMODE geometry write is unsupported") }
            for (offset,value): (Int,Int32) in [(0x10,0),(0x7e0,0),(0x1780,400),(0xfb0,705),(0x14,0),(0x7e4,471),(0xfb4,705),(0x1784,16),(0xc,2)] { try mode.storage.write(value,at:offset) }
            owned.bitmaps[token]=mode
        }
        if initialize==1 || initialize == -1 {
            try write(0x44d770,6);try write(0x44d76c,2);try write(0x451ba8,0);try write(0x44d774,0)
        }
        try mark(0x438da5)
        for a in [0x451b68,0x451b64,0x451b70,0x451b6c] { try write(a,0) }
        let menu=try word(0x44d020),x=try word(0x44d764)
        let y: Int32=(201..<210).contains(menu) ? 80 : ((210..<220).contains(menu) ? 60 : 33)
        try write(0x44d768,y)
        if (201..<220).contains(menu) { try bitmap(0x451bb0,x,y,0);try bitmap(0x451bb0,x,y &+ 400,1) }
        else { try bitmap(0x451bb0,x,y) }
        try mark(0x438e49)
        try write(0x451ba4,x &+ 526);try write(0x451ba0,x &+ 179)
        for seat in 0..<8 where try [3,13].contains(word(0x451288+seat*4)) {
            let t=try team(seat)
            if (1...2).contains(t) { try write(0x451b9c+Int(t)*4,word(0x451b9c+Int(t)*4) &- 20) }
        }
        for seat in 0..<8 {
            local[0x14]=Int32(seat)
            let status=try word(0x451288+seat*4)
            if status==3 || status==13 {
                let t=try team(seat)
                guard (1...2).contains(t) else { throw error("Ready label needs retained X provenance for other teams") }
                let left=try word(0x451b9c+Int(t)*4)
                try write(0x451b9c+Int(t)*4,left &+ 40)
                if try word(0x451228+seat*4) != 0 && !(201..<210).contains(word(0x44d020)) {
                    try bitmap(0x45116c,left,y &+ 86,1,0,UInt32(bitPattern:word(0x455608)))
                } else { try catalogBitmap(Int(word(0x451248+seat*4)),left,y &+ 86) }
                try text([status==3 ? UInt8(seat+49) : 67],left &+ 15,y &+ 131,t==1 ? 0xff9b4f : 0x4f4fff,0x8f472f)
            }
        }
        local[0x14]=8
        for side in 0..<2 {
            let multiplier=try word(0x44d758+side*4)
            try text(formatted("x \(multiplier/100).\((multiplier%100)/10)","x %d.%d"),x &+ 240 &+ Int32(side)*347,y &+ 154,0xffffff)
        }
        try write(0x451ba0,x &+ 39);try write(0x451ba4,x &+ 386)
        for side in 0..<2 {
            local[0x18]=Int32(side);local[0x14]=Int32(side)*347
            for unit in 0..<11 {
                local[0x20]=Int32(unit)*48
                let left=try word(0x451ba0+side*4) &+ Int32(unit)*48 &- (unit<6 ? 0 : 264)
                let top=y &+ (unit<6 ? 215 : 306)
                if unit>=9 { try bitmap(0x45116c,left,top,unit==10 ? 22 : 23) }
                else {
                    guard let ordinal=owned.unitObjects[unit],try word(0x451b38+unit*4)==ordinal+1 else { throw error("Missing owned troop Object binding") }
                    try catalogBitmap(ordinal,left,top)
                }
                try fill(left &+ 3,top &+ 46,34,16);try fill(left &+ 3,top &+ 64,34,16)
                let active=try word(0x44d5f8+(side*11+unit)*4)
                try text(formatted(String(active),"%d"),left &+ 10,top &+ 46,active==0 ? 0x9a4d32 : 0xffffff)
                if active==0 { try text(formatted("--","--"),left &+ 10,top &+ 64,0x9a4d32) }
                else {
                    let reserve=try word(0x44d650+(side*11+unit)*4)
                    try text(formatted(String(reserve),"%d"),left &+ 10,top &+ 64,reserve==0 ? 0x9a4d32 : 0xffffff)
                }
            }
            local[0x20]=528
            let display=try word(0x44d380+side*4)
            if display != -1 {
                guard (0...6).contains(display) else { throw error("Preset display index") }
                let atlas=try bitmapStorage(UInt32(bitPattern:word(0x4511a0)),&context)
                let width=try atlas.integer(at:0xff8+Int(display)*4,as:Int32.self)
                let right=x &+ Int32(side)*347 &+ 345
                if display==0 || display==6 { try bitmap(0x4511a0,right &- width,y &+ 192,display &+ 18,1) }
                else {
                    let strength=try word(0x451b74+side*4)
                    guard (0...2).contains(strength) else { throw error("Strength display index") }
                    let sw=try atlas.integer(at:0xfec+Int(strength)*4,as:Int32.self)
                    try bitmap(0x4511a0,right &- width &- sw,y &+ 192,display &+ 18,1)
                    try bitmap(0x4511a0,right &- sw,y &+ 192,strength &+ 15,1)
                }
            }
        }
        local[0x18]=2;local[0x14]=694
        if try word(0x44d020)==200 {
            if try button(0x4513a4) { try write(0x44d770,word(0x44d770) &- 1) }
            else if try button(0x4513a8) { try write(0x44d770,word(0x44d770) &+ 1) }
            var section=try word(0x44d770)
            if section>6 { section=0;try write(0x44d770,section) }
            else if section<0 { section=6;try write(0x44d770,section) }
            var s=try side()
            if section==0 {
                try frame(true,x &+ 80 &+ Int32(s)*347,y &+ 150,208,25)
                if try button(0x4513b0) || button(0x4513ac) { s=1-s;try write(0x451ba8,Int32(s)) }
                let a=0x44d758+s*4
                if try button(0x4513b4) { try write(a,word(a) &+ 50);if try word(a)>300 { try write(a,100) } }
                if try button(0x4513b8) { try write(a,word(a) &- 50);if try word(a)<100 { try write(a,300) } }
            }
            if (1...4).contains(section) {
                let maximum: Int32=section<=2 ? 5 : 4
                var cursor=try word(0x44d76c);local[0x18]=maximum
                if try button(0x4513b0) {
                    cursor &+= 1;try write(0x44d76c,cursor)
                    if cursor>maximum { cursor=0;s=1-s;try write(0x44d76c,0);try write(0x451ba8,Int32(s)) }
                }
                if try button(0x4513ac) {
                    cursor=min(cursor,maximum) &- 1;try write(0x44d76c,cursor)
                    if cursor<0 { cursor=maximum;s=1-s;try write(0x44d76c,cursor);try write(0x451ba8,Int32(s)) }
                }
                guard (0...5).contains(cursor) else { throw error("Troop cursor") }
                let unit=section<=2 ? Int(cursor) : 6+Int(min(cursor,4))
                try OriginalWarTroops.adjust(&candidate.globals,side:s,unit:unit,change:section%2==1 ? .active : .reserve,
                    attack:button(0x4513b4),jump:button(0x4513b8),defense:button(0x4513bc))
                try frame(true,x &+ Int32(s)*347 &+ 48*min(cursor,maximum) &+ (section<3 ? 42 : 66),
                    y &+ 18*section &+ (section<3 ? 243 : 298),34,16)
            }
            if section==5 {
                try frame(true,x &+ 43 &+ Int32(s)*347,y &+ 396,272,25)
                if try button(0x4513b0) || button(0x4513ac) { s=1-s;try write(0x451ba8,Int32(s)) }
                if try button(0x4513b4) {
                    try write(0x44d020,210);try write(0x44d760,10);try write(0x4513b4,0)
                    try OriginalWarTroops.backup(&candidate.globals,side:s)
                }
            }
            if section==6 {
                try frame(true,x &+ 301,y &+ 441,106,24)
                if try button(0x4513b4) { try write(0x44d020,202);try write(0x451b84,2);try write(0x4513b4,0);try sound(0x45560c) }
                if try button(0x4513ac) { try write(0x44d770,5);try write(0x451ba8,0) }
                else if try button(0x4513b0) { try write(0x44d770,5);try write(0x451ba8,1) }
                if try button(0x4513b8) { try write(0x44d020,3);try write(0x4512c8,0) }
            }
        }
        try mark(0x43986a)
        let reroll=try word(0x44d020)==201
        if reroll {
            guard let counts=candidate.catalog.registry.records[0x4d82380],try counts.integer(at:0,as:Int32.self)==candidate.catalog.objects.count else { throw error("Random Object count") }
            for seat in 0..<8 where try word(0x451228+seat*4)==1 {
                let selected=try (0..<8).map { try word(0x451248+$0*4) }
                var choices: [UInt32]=[]
                if candidate.catalog.objects.count>1 {
                    for ordinal in 1..<candidate.catalog.objects.count where !selected.contains(Int32(ordinal)) {
                        let header=candidate.catalog.objects[ordinal].header
                        if try header.integer(at:0x6f8,as:Int32.self)==0 && header.integer(at:0x6f4,as:Int32.self)<30 { choices.append(UInt32(ordinal)) }
                    }
                }
                guard !choices.isEmpty else { throw error("Empty Random list needs original scratch provenance") }
                try observe(.init("candidates",[UInt32(seat)]+choices),&context)
                let index=try candidate.drawMenuRandom(stream:0x122,range:Int32(choices.count)) { try observe($0,&context) }
                let ordinal=choices[Int(index)]
                try write(0x451248+seat*4,Int32(ordinal));try candidate.actors[actor(seat)].write(ordinal,at:0x368)
                local[0x14]=Int32(choices.count)
            }
            local[0x18]=0;try write(0x44d020,202);try write(0x451b84,2)
        } else {
            try mark(0x4399c3)
            if try (210..<220).contains(word(0x44d020)) {
                let s=try side(),left=410-Int32(s)*275
                try bitmap(0x451bac,left,65)
                if try button(0x4513b8) { try OriginalWarTroops.restore(&candidate.globals,side:s,jump:true);try write(0x44d020,200) }
                try mark(0x439a67)
                let strength=try word(0x451b98+s*4),preset=try word(0x451b90+s*4)
                if strength != -1 { try frame(false,left &+ 46,168 &+ 22 &* strength,161,19,0xa7a7ff) }
                if preset != -1 { try frame(false,left &+ 46,304 &+ 22 &* preset,161,19,0xa7a7ff) }
                let selector=try word(0x44d760)
                if (0...9).contains(selector) {
                    try frame(true,left &+ 44,(selector<5 ? 144 : 192) &+ 22*selector,165,23)
                    if try button(0x4513b4) {
                        switch selector {
                        case 0:try OriginalWarTroops.selectNone(&candidate.globals,side:s)
                        case 1...3:try OriginalWarTroops.selectStrength(&candidate.globals,side:s,strength:selector-1)
                        case 4:try OriginalWarTroops.selectAll(&candidate.globals,side:s)
                        default:try OriginalWarTroops.selectPreset(&candidate.globals,side:s,preset:Int(selector-5))
                        }
                    }
                    if try button(0x4513a4) { try write(0x44d760,word(0x44d760) &- 1) }
                    if try button(0x4513a8) { try write(0x44d760,word(0x44d760) &+ 1) }
                    if try word(0x44d760)<0 { try write(0x44d760,10) }
                } else if selector==10 {
                    try frame(true,left &+ 22,433,83,24)
                    if try button(0x4513b0) { try write(0x44d760,word(0x44d760) &+ 1) }
                    if try button(0x4513a4) { try write(0x44d760,word(0x44d760) &- 1) }
                    if try button(0x4513a8) { try write(0x44d760,0) }
                    if try button(0x4513b4) { try write(0x44d020,200);return try returnMenu() }
                } else if selector==11 {
                    try frame(true,left &+ 122,433,106,24)
                    if try button(0x4513a4) { try write(0x44d760,word(0x44d760) &- 2) }
                    if try button(0x4513a8) { try write(0x44d760,0) }
                    if try button(0x4513ac) { try write(0x44d760,word(0x44d760) &- 1) }
                    if try button(0x4513b4) {
                        try OriginalWarTroops.restore(&candidate.globals,side:s,jump:false)
                        try write(0x44d020,200);try write(0x4513b4,0);try sound(0x455614)
                    }
                }
            }
        }
        guard try word(0x44d020)==202 else { return try returnMenu() }
        try mark(0x439f93)
        try OriginalMusicConfiguration.advanceCommon(state:&candidate,libraryText:&library,mode:4,left:word(0x4513ac),right:word(0x4513b0),target:target,input:input) { try observe($0,&context) }
        try bitmap(0x451178,3,3,8);try bitmap(0x451178,3,159,15,1)
        let highlights: [(Int32,Int32,Int32)]=[(9,92,16),(10,64,39),(11,40,64),(12,15,87),(13,37,111),(14,101,137)]
        let option=try word(0x451b84)
        if highlights.indices.contains(Int(option)) { let (f,x,y)=highlights[Int(option)];try bitmap(0x451178,x,y,f) }
        if try word(0x44d028)==1 { try write(0x44d024,100) }
        let arena=try word(0x44d024)
        guard candidate.backgrounds.indices.contains(Int(arena)) else { throw error("Arena name binding") }
        try text(cstr(candidate.backgrounds[Int(arena)],0x3cc),174,91,0xff9b9b)
        let names: [Int32:String]=[2:"Easy",1:"Normal",0:"Difficult",-1:"Difficult"]
        if let name=names[try word(0x450c30)] { try text(Array(name.utf8),174,115,0xff9b9b) }
        if try button(0x4513a4) { try write(0x451b84,word(0x451b84) &- 1);if try word(0x451b84) == -1 { try write(0x451b84,5) } }
        if try button(0x4513a8) { try write(0x451b84,(word(0x451b84) &+ 1)%6) }
        if try button(0x4513b8) { try write(0x44d020,200);return try returnMenu(false) }
        if try button(0x4513b4) {
            try OriginalWarTroops.finalize(&candidate.globals);try write(0x4513b4,0);try sound(0x455610)
            switch try word(0x451b84) {
            case 0:try mark(0x43a21f);return finish(.warMatchPreparation)
            case 1:try write(0x4512c8,0);try write(0x44d020,3);try write(0x44d024,100);try write(0x44d028,1)
            case 2:try write(0x44d020,201)
            case 3:
                try sound(0x455610)
                let a=try word(0x44d024);try write(0x44d028,0)
                if a==100 { try write(0x44d024,99) }
                else if a==99 { try write(0x44d024,0) }
                else {
                    let next=a &+ 1;try write(0x44d024,next)
                    guard let counts=candidate.catalog.registry.records[0x4d82380] else { throw error("Arena count") }
                    if try next==counts.integer(at:4,as:Int32.self) { try write(0x44d024,100);try write(0x44d028,1) }
                }
            case 4:try write(0x450c30,word(0x450c30) &- 1);if try word(0x450c30)<0 { try write(0x450c30,2) };try sound(0x455610)
            case 5:try write(0x44d020,10);try candidate.resetOriginalInput();try write(0x457580,0)
            default:break
            }
        }
        return try returnMenu(false)
    }
}
