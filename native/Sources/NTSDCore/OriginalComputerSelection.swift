/// VS/Stage computer selection42b964..42cb86. Ordinary catalog/Actor ownership is
/// semantic; no original caller stack, private pointer or EXE runs natively.
/// The caller stages state and external events through the complete menu call.
enum OriginalComputerSelection {
    static func advance(state: inout OriginalMatchPreparation, locals: inout [Int:Int32], libraryText: inout OriginalLibSurfaceText?,
        target: UInt32, input: OriginalFrontScreenBodyInput,
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void) throws {
        var candidate = state,local = locals,library = libraryText
        func error(_ message: String) -> OriginalStateError { .invalidStorage("Computer selection: "+message) }
        func word(_ p: Int) throws -> Int32 { try candidate.global(p) }
        func write(_ p: Int,_ value: Int32) throws { try candidate.setGlobal(p,value) }
        func actor(_ seat: Int) throws -> Int {
            guard (0..<8).contains(seat) else { throw error("Seat extent") }
            let value = try candidate.world.integer(at:0x194+seat*4,as:UInt32.self)
            guard candidate.actors.indices.contains(Int(value)) else { throw error("Actor binding") };return Int(value)
        }
        func button(_ seat: Int,_ p: Int) throws -> Bool { try candidate.actors[actor(seat)].integer(at:p,as:UInt8.self) != 0 }
        func team(_ seat: Int) throws -> Int32 { try candidate.actors[actor(seat)].integer(at:0x364,as:Int32.self) }
        func setTeam(_ seat: Int,_ value: Int32) throws { try candidate.actors[actor(seat)].write(value,at:0x364) }
        func status(_ seat: Int) throws -> Int32 { _ = try actor(seat);return try word(0x451288+seat*4) }
        func setStatus(_ seat: Int,_ value: Int32) throws { _ = try actor(seat);try write(0x451288+seat*4,value) }
        func computer(_ index: Int32) throws -> Int {
            guard (0..<8).contains(index) else { throw error("Computer index extent") }
            let seat = Int(try word(0x451200+Int(index)*4));_ = try actor(seat);return seat
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
        func text(_ bytes: [UInt8],_ x: Int32,_ y: Int32,_ color: UInt32) throws {
            let surface = UInt32(bitPattern:try word(0x455608))
            if var text = library {
                try text.draw(bytes,target:surface,background:0,color:color,x:x,y:y,dcResult:input.dcResult,dc:input.dc) {
                    try observe(.init($0.kind.rawValue,$0.arguments,$0.strings))
                }
                library = text
            } else {
                try OriginalSurfaceText.draw(bytes,target:surface,background:0,color:color,x:x,y:y,dcResult:input.dcResult,dc:input.dc) {
                    try observe(.init($0.kind.rawValue,$0.arguments,$0.strings))
                }
            }
        }
        func color() throws -> UInt32 {
            let count = try word(0x451224),phase = UInt8(truncatingIfNeeded:(count/6) &* 76 &+ count &* 30)
            return (UInt32(phase &+ 70)|0xff00)<<8 | UInt32(phase &+ 25)
        }
        func faceAndName(_ seat: Int,_ color: UInt32) throws {
            let x = Int32(seat%4*153),y = Int32(seat/4*212)
            let source: OriginalCharacterScreenDraw.Bitmap,name: [UInt8]
            if try word(0x451248+seat*4) < 0 {
                source = .menu(UInt32(bitPattern:try word(0x44fd84)));name = Array(" Random".utf8)
            } else {
                let ordinal = try candidate.actors[actor(seat)].integer(at:0x368,as:UInt32.self)
                guard candidate.catalog.objects.indices.contains(Int(ordinal)) else { throw error("Object binding") }
                let object = candidate.catalog.objects[Int(ordinal)]
                let ref = try object.header.integer(at:0x6fc,as:UInt32.self)
                guard ref > 0,candidate.catalog.bitmaps.indices.contains(Int(ref-1)) else { throw error("Portrait binding") }
                source = .catalog(Int(ref-1))
                guard let end = object.nameTail.bytes.firstIndex(of:0),object.nameTail.defined[...end].allSatisfy({ $0 }) else { throw error("Object name provenance") }
                name = Array(object.nameTail.bytes[..<end])
            }
            try draw(.init(bitmap:source,x:x+147,y:y+94,target:target),candidate.globals)
            try text(name,x+177,y+241,color)
        }
        func teamText(_ seat: Int,_ color: UInt32) throws {
            let value = try team(seat)
            let labels = ["Independent","Team 1","Team 2","Team 3","Team 4"]
            if (0...4).contains(value) {
                try text(Array(labels[Int(value)].utf8),Int32(seat%4*153)+(value == 0 ? 167 : 187),Int32(seat/4*212)+263,color)
            }
        }
        func roster(_ seat: Int,_ direction: Int32) throws {
            guard let record = candidate.catalog.registry.records[0x4d82380] else { throw error("Catalog count") }
            let count = try record.integer(at:0,as:Int32.self),selected = 0x451248+seat*4
            guard count > 0,count == candidate.catalog.objects.count else { throw error("Catalog count extent") }
            for _ in 0...Int(count) {
                var ordinal = try word(selected) &+ direction;try write(selected,ordinal)
                if direction > 0 && ordinal >= count { try write(selected,-1);return }
                if ordinal == -1 { return }
                if direction < 0 && ordinal < -1 { ordinal = count &- 1;try write(selected,ordinal) }
                guard candidate.catalog.objects.indices.contains(Int(ordinal)) else { throw error("Roster access") }
                let header = candidate.catalog.objects[Int(ordinal)].header
                if try header.integer(at:0x6f8,as:Int32.self) != 0 { continue }
                let group = try header.integer(at:0x6f4,as:Int32.self)/10
                if try (group == 3 || group == 5) && word(0x458428) != 1 { continue }
                try candidate.actors[actor(seat)].write(UInt32(bitPattern:ordinal),at:0x368);return
            }
            throw error("Roster traversal does not terminate")
        }
        func randomize(stream: Int32 = 0xd9) throws {
            let stage = stream == 0xd8
            if stage { local[0x30] = 0;local[0x20] = 0x194 }
            for seat in 0..<8 { try write(0x451228+seat*4,word(0x451248+seat*4) < 0 ? 1 : 0) }
            for seat in 0..<8 {
                if try word(0x451228+seat*4) != 0 {
                    let choices = try candidate.randomRosterCandidates()
                    guard !choices.isEmpty else { throw error("Empty roster requires original scratch provenance") }
                    if !stage && candidate.catalog.objects.count > 1 { local[0x20] = Int32(candidate.catalog.objects.count) }
                    try observe(.init("candidates",[UInt32(seat)]+choices.map(UInt32.init)))
                    let ordinal = choices[Int(try candidate.drawMenuRandom(stream:stream,range:Int32(choices.count),observe:observe))]
                    try write(0x451248+seat*4,Int32(ordinal));try candidate.actors[actor(seat)].write(UInt32(ordinal),at:0x368)
                }
                // Semantic World offset for the actual retained Actor-table cursor.
                local[stage ? 0x20 : 0x38] = Int32(0x194+(seat+1)*4)
            }
            try write(0x44d06c,2);try write(0x4512c8,3)
        }
        let mode = try word(0x451160)
        guard (0...1).contains(mode) else { throw error("Other modes") }
        for offset in [0x34,0x28,0x38,0x2c,0x30] { local[offset] = 0 }
        if try word(0x4512c8) == 2 {
            for seat in 0..<8 where try candidate.world.integer(at:4+seat,as:UInt8.self) != 0 {
                let latch = 0x451268+seat*4
                var matched = false
                for (offset,flag): (Int,Int?) in [(0xcd,0x34),(0xce,nil),(0xd0,0x38),(0xcf,0x28),(0xd1,0x2c),(0xd2,0x30)] where !matched {
                    if try button(seat,offset) {
                        if let flag,try word(latch) == 0,local[0x3c] == 2 { local[flag] = 1 }
                        try write(latch,1);matched = true
                    }
                }
                if !matched { try write(latch,0) }
            }
        }
        let count = try word(0x44d070)
        guard (0...8).contains(count) else { throw error("Computer count extent") }
        for i in 0..<Int(count) {
            let seat = try computer(Int32(i))
            if try status(seat) > 11 { try faceAndName(seat,0x9b9bff) }
            if try status(seat) > 12 { try teamText(seat,0x9b9bff) }
        }
        // These bindings are read even with count0 or after the last ready CPU.
        var index = try word(0x4511fc),seat = try computer(index)
        if try status(seat) == 11 {
            try faceAndName(seat,color())
            if local[0x38] != 0 { try roster(seat,1) }
            if local[0x28] != 0 { try roster(seat,-1) }
            if local[0x34] != 0 { try write(0x451248+seat*4,-1) }
            if try word(0x451220) == 1 {
                try write(0x451248+seat*4,-1);try setStatus(seat,11);try write(0x451220,0)
            }
            if local[0x2c] != 0 {
                try sound(0x45560c);try setStatus(seat,12);local[0x2c] = 0
                if mode == 1 {
                    try setStatus(seat,13)
                    try write(0x451220,word(0x451248+seat*4) < 0 ? 1 : 0)
                    index = try word(0x4511fc) &+ 1;try write(0x4511fc,index)
                    if index >= count { try randomize(stream:0xd8) }
                    else { try setStatus(computer(index),11) }
                }
            }
            if local[0x30] != 0 {
                try sound(0x455614);local[0x30] = 0
                index = try word(0x4511fc)
                if index == 0 {
                    try write(0x4512c8,1)
                    for i in 0..<8 where try status(i) == 11 { try setStatus(i,0) }
                } else {
                    index &-= 1;try setStatus(computer(index),mode == 1 ? 11 : 12);try write(0x4511fc,index)
                }
            }
        }
        // Character confirmation/cancel can enter a different team body in this call.
        index = try word(0x4511fc);seat = try computer(index)
        if try status(seat) == 12 {
            var excluded: Int32 = -1
            if mode == 0 && index == count &- 1 {
                for other in 0..<8 where try other != seat && status(other)%10 == 3 {
                    let value = try team(other)
                    if value == 0 { excluded = -2 }
                    else if excluded == -1 { excluded = value }
                    else if excluded >= 0 && excluded != value { excluded = -2 }
                }
            }
            if try team(seat) == excluded { try setTeam(seat,(team(seat) &+ 1)%5) }
            try teamText(seat,color())
            if local[0x38] != 0 {
                try setTeam(seat,(team(seat) &+ 1)%5)
                if try team(seat) == excluded { try setTeam(seat,(team(seat) &+ 1)%5) }
            }
            if local[0x28] != 0 {
                var next = try team(seat) &- 1;if next < 0 { next = 4 };try setTeam(seat,next)
                if next == excluded { next &-= 1;if next < 0 { next = 4 };try setTeam(seat,next) }
            }
            if local[0x2c] != 0 {
                try sound(0x45560c);try setStatus(seat,13)
                try write(0x451220,word(0x451248+seat*4) < 0 ? 1 : 0)
                index &+= 1;try write(0x4511fc,index)
                if index >= count { try randomize() }
                else { try setStatus(computer(index),11) }
            }
            // The successful final team path jumps directly to settings.
            if try word(0x4512c8) != 3,local[0x30] != 0 {
                try sound(0x455614);try setStatus(seat,11);try write(0x451220,0)
            }
        }
        state = candidate;locals = local;libraryText = library
    }
}
