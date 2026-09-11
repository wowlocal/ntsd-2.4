import Foundation

/// Human screen, computer count/character/team selection and VS/Stage settings through
/// the actual42cf8a match-prelude boundary. Other modes remain explicit boundaries.
public enum OriginalMatchSelection {
    public static func advance(state: inout OriginalMatchPreparation, selectionAtEntry: UInt32, target: UInt32,
        input: OriginalFrontScreenBodyInput, fillBacking: () throws -> [UInt8],
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in },
        checkpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation) throws -> Void = { _,_ in }) throws -> OriginalCharacterScreenExit {
        var library: OriginalLibSurfaceText?
        return try advanceCommon(state:&state,libraryText:&library,selectionAtEntry:selectionAtEntry,target:target,input:input,fillBacking:fillBacking,draw:draw,observe:observe,checkpoint:checkpoint)
    }

    public static func advanceWithLibrary(state: inout OriginalMatchPreparation, libraryText: inout OriginalLibSurfaceText, selectionAtEntry: UInt32, target: UInt32,
        input: OriginalFrontScreenBodyInput, fillBacking: () throws -> [UInt8],
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in },
        checkpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation) throws -> Void = { _,_ in },
        tournamentStage: OriginalTournamentBracket.Continuation = OriginalTournamentBracket.unavailable,
        teamTournamentStage: OriginalTeamTournamentBracket.Continuation = OriginalTeamTournamentBracket.unavailable) throws -> OriginalCharacterScreenExit {
        var library: OriginalLibSurfaceText? = libraryText
        let end = try advanceCommon(state:&state,libraryText:&library,selectionAtEntry:selectionAtEntry,target:target,input:input,fillBacking:fillBacking,draw:draw,observe:observe,checkpoint:checkpoint,tournamentStage:tournamentStage,teamTournamentStage:teamTournamentStage)
        libraryText = library!;return end
    }

    private static func advanceCommon(state: inout OriginalMatchPreparation, libraryText: inout OriginalLibSurfaceText?, selectionAtEntry: UInt32, target: UInt32,
        input: OriginalFrontScreenBodyInput, fillBacking: () throws -> [UInt8],
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void,
        checkpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation) throws -> Void,
        tournamentStage: OriginalTournamentBracket.Continuation = OriginalTournamentBracket.unavailable,
        teamTournamentStage: OriginalTeamTournamentBracket.Continuation = OriginalTeamTournamentBracket.unavailable) throws -> OriginalCharacterScreenExit {
        try OriginalCharacterScreen.advanceCommon(state: &state,libraryText:&libraryText,selectionAtEntry: selectionAtEntry,target: target,input: input,
            fillBacking: fillBacking(),draw: draw,observe: observe,checkpoint: checkpoint,includeTailCheckpoint: true,tournamentStage:tournamentStage,teamTournamentStage:teamTournamentStage,selectionStage: { candidate,local,library in
                try continueSelection(state: &candidate,locals: &local,libraryText:&library,target: target,input: input,
                    fillBacking: fillBacking,draw: draw,observe: observe,checkpoint: checkpoint)
            })
    }

    private static func continueSelection(state: inout OriginalMatchPreparation, locals: inout [Int:Int32],libraryText: inout OriginalLibSurfaceText?,target: UInt32,
        input: OriginalFrontScreenBodyInput,fillBacking: () throws -> [UInt8],
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void,
        checkpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation) throws -> Void) throws -> OriginalCharacterScreenExit {
        var candidate = state,local = locals,library = libraryText
        func error(_ message: String) -> OriginalStateError { .invalidStorage("Match selection: "+message) }
        func word(_ address: Int) throws -> Int32 { try candidate.global(address) }
        func write(_ address: Int,_ value: Int32) throws { try candidate.setGlobal(address,value) }
        func actor(_ seat: Int) throws -> Int {
            guard (0..<8).contains(seat) else { throw error("Seat outside first eight") }
            let index = try candidate.world.integer(at: 0x194+seat*4,as: UInt32.self)
            guard candidate.actors.indices.contains(Int(index)) else { throw error("Actor binding") };return Int(index)
        }
        func active(_ seat: Int) throws -> Bool { try candidate.world.integer(at: 4+seat,as: UInt8.self) != 0 }
        func button(_ seat: Int,_ offset: Int) throws -> Bool { try candidate.actors[actor(seat)].integer(at: offset,as: UInt8.self) != 0 }
        func mark(_ pc: UInt32) throws {
            try checkpoint(.init(pc: pc,seat: -1,locals: local.filter { [0x20,0x28,0x34,0x38,0x3c].contains($0.key) }),candidate)
        }
        func finish(_ exit: OriginalCharacterScreenExit) -> OriginalCharacterScreenExit { state = candidate;locals = local;libraryText = library;return exit }
        func sound() throws {
            try OriginalMatchPrelude.confirmationSound(in: candidate.globals) { e in
                switch e {
                case .soundRequest(let loop):try observe(.init("soundRequest",[loop ? 1 : 0]))
                case .soundMethod(let resource,let offset,let args):try observe(.init("soundMethod",[resource,UInt32(offset)]+args))
                default:throw error("Sound event")
                }
            }
        }
        func bitmap(_ slot: Int,_ x: Int32,_ y: Int32,_ frame: Int32 = -1,_ key: UInt32 = 0) throws {
            try draw(.init(bitmap: .menu(UInt32(bitPattern: word(slot))),x: x,y: y,target: target,frame: frame,colorKey: key),candidate.globals)
        }
        func text(_ bytes: [UInt8],_ x: Int32,_ y: Int32,_ foreground: UInt32,_ background: UInt32 = 0) throws {
            if var text = library {
                try text.draw(bytes,target:UInt32(bitPattern:word(0x455608)),background:background,color:foreground,x:x,y:y,
                    dcResult:input.dcResult,dc:input.dc) { try observe(.init($0.kind.rawValue,$0.arguments,$0.strings)) }
                library = text
            } else {
                try OriginalSurfaceText.draw(bytes,target: UInt32(bitPattern: word(0x455608)),background: background,color: foreground,x: x,y: y,
                    dcResult: input.dcResult,dc: input.dc) { try observe(.init($0.kind.rawValue,$0.arguments,$0.strings)) }
            }
        }
        func fill(_ x: Int32,_ y: Int32,_ width: Int32,_ height: Int32) throws {
            var event = OriginalFrontScreenEvent("fill")
            event.fill = try OriginalSurfaceFilling.request(target: UInt32(bitPattern: word(0x455608)),x: x,y: y,width: width,height: height,
                color: 0xffffff,backing: fillBacking());try observe(event)
        }
        let mode = try word(0x451160)
        guard (0...1).contains(mode),try word(0x450c2c) == 0 else { throw error("Other mode selection continuation") }
        if try word(0x4512c8) == 1 {
            try mark(0x42b296);try write(0x451220,0);try bitmap(0x44fd88,218,215)
            var inactive: Int32 = 0,teams = [Int32](repeating: 0,count: 5)
            for seat in 0..<8 {
                if try active(seat) {
                    let team = try candidate.actors[actor(seat)].integer(at: 0x364,as: Int32.self)
                    guard teams.indices.contains(Int(team)) else { throw error("Team scratch extent") }
                    if team == 0 || teams[Int(team)] == 0 { teams[Int(team)] &+= 1 }
                } else { inactive &+= 1 }
            }
            local[0x18] = inactive
            if inactive == 0 { try write(0x4512c8,3) }
            let minimum: Int32 = teams.reduce(0,&+) < 2 && mode != 1 ? 1 : 0
            local[0x30] = minimum
            var count = try word(0x44d070)
            if count == -100 || count < minimum || count > inactive { count = minimum;try write(0x44d070,count) }
            var confirmedSeat: Int?
            for seat in 0..<8 where try active(seat) {
                let latch = 0x451268+seat*4
                let edge = try word(latch) == 0 && local[0x3c] == 1
                if try button(seat,0xd0) {
                    if edge { count &+= 1;if count > inactive { count = minimum } };try write(latch,1)
                } else if try button(seat,0xcf) {
                    if edge { count &-= 1;if count < minimum { count = inactive } };try write(latch,1)
                } else if try button(seat,0xd1) {
                    if edge { confirmedSeat = seat;break };try write(latch,1)
                } else { try write(latch,0) }
            }
            try write(0x44d070,count)
            if let confirmedSeat {
                try sound();try write(0x4512c8,2)
                if count == 0 {
                    try write(0x44d06c,2)
                    for seat in 0..<8 { try write(0x451228+seat*4,word(0x451248+seat*4) < 0 ? 1 : 0) }
                    try write(0x4512c8,3)
                    for seat in 0..<8 where try word(0x451228+seat*4) != 0 {
                        let choices = try candidate.randomRosterCandidates()
                        guard !choices.isEmpty else { throw error("Empty roster requires original scratch provenance") }
                        if candidate.catalog.objects.count > 1 { local[0x20] = Int32(candidate.catalog.objects.count) }
                        try observe(.init("candidates",[UInt32(seat)]+choices.map(UInt32.init)))
                        let ordinal = choices[Int(try candidate.drawMenuRandom(stream: 0xd7,range: Int32(choices.count),observe: observe))]
                        try write(0x451248+seat*4,Int32(ordinal));try candidate.actors[actor(seat)].write(UInt32(ordinal),at: 0x368)
                    }
                } else {
                    var assigned = 0
                    for seat in 0..<8 where try !active(seat) && assigned < count {
                        try write(0x451200+assigned*4,Int32(seat));try write(0x451288+seat*4,11);assigned += 1
                    }
                    try write(0x4511fc,0);try write(0x451268+confirmedSeat*4,1)
                }
            }
            for value in Int32(0)...7 {
                let bytes = Array(String(value).utf8),x = 280+value*30
                try observe(.init("format",[UInt32(bytes.count)],[Array("%d".utf8),bytes]))
                try text(bytes,x+6,286,value >= minimum && value <= inactive ? 0xffffff : 0xc06850,0x9f472f)
                if try word(0x44d070) == value {
                    try fill(x,283,21,1);try fill(x,283,1,21);try fill(x,303,21,1);try fill(x+20,283,1,21)
                }
            }
        }
        if try (2...3).contains(word(0x4512c8)) {
            try mark(0x42b964)
            try OriginalComputerSelection.advance(state:&candidate,locals:&local,libraryText:&library,target:target,input:input,draw:draw,observe:observe)
        }
        if try word(0x4512c8) == 3 {
            try mark(0x42cb86)
            for offset in [0x34,0x20,0x30,0x38,0x18] { local[offset] = 0 }
            try bitmap(0x451178,3,3,8);try bitmap(0x451178,3,159,15,1)
            let options: [(Int32,Int32,Int32)] = [(92,16,9),(64,39,10),(40,64,11),(15,87,12),(37,111,13),(101,137,14)]
            let option = try word(0x44d06c)
            if options.indices.contains(Int(option)) { let (x,y,frame) = options[Int(option)];try bitmap(0x451178,x,y,frame) }
            if try word(0x44d028) == 1 { try write(0x44d024,100) }
            if mode == 1 {
                let stage = try word(0x450b94),decade = stage/10
                if stage%10 != 0 { try write(0x450b94,decade &* 10) }
                try bitmap(0x451178,15,87,23)
                if option == 3 { try bitmap(0x451178,15,87,22) }
                // 42cd5d/42cd6a produce the two local bytes; 42cd90..42cdad
                // copy the nine-byte literal. No retained source stack input.
                if decade < 5 { try text([UInt8(truncatingIfNeeded:decade &+ 0x31)],194,91,0xff9b9b) }
                else { try text(Array("Survival".utf8),174,91,0xff9b9b) }
            } else {
                let arena = try word(0x44d024)
                guard candidate.backgrounds.indices.contains(Int(arena)) else { throw error("Arena name record") }
                let record = candidate.backgrounds[Int(arena)]
                guard let end = record.bytes[0x3cc...].firstIndex(of: 0),record.defined[0x3cc...end].allSatisfy({ $0 }) else { throw error("Arena name extent") }
                try text(Array(record.bytes[0x3cc..<end]),174,91,0xff9b9b)
            }
            if let label = [Int32(2):"Easy",1:"Normal",0:"Difficult",-1:"CRAZY!"][try word(0x450c30)] {
                try text(Array(label.utf8),174,115,0xff9b9b)
            }
            for seat in 0..<8 where try active(seat) {
                let latch = 0x451268+seat*4
                var matched = false
                for (buttonOffset,flag) in [(0xcd,0x34),(0xce,0x20),(0xd0,0x38),(0xcf,0x30),(0xd1,0x18)] where !matched {
                    if try button(seat,buttonOffset) {
                        if try word(latch) == 0 && local[0x3c] == 3 { local[flag] = 1 }
                        try write(latch,1);matched = true
                    }
                }
                if !matched { try write(latch,button(seat,0xd2) ? 1 : 0) }
            }
            if local[0x34] != 0 { let next = try word(0x44d06c) &- 1;try write(0x44d06c,next < 0 ? 5 : next) }
            if local[0x20] != 0 { try write(0x44d06c,(word(0x44d06c) &+ 1)%6) }
            let mode = try word(0x451160)
            try OriginalMusicConfiguration.advanceCommon(state: &candidate,libraryText:&library,mode: mode,left: local[0x30]!,right: local[0x38]!,target: target,input: input,observe: observe)
            try mark(0x42cf6c)
            let confirmation = local[0x18]!
            if try word(0x450b98) != 0 || (confirmation != 0 && word(0x44d06c) == 0) {
                try mark(0x42cf8a);return finish(.matchPrelude)
            }
            try mark(confirmation == 0 ? 0x42d789 : 0x42d706)
            let action = try word(0x44d06c)
            try candidate.continueMenu(confirmation: confirmation,bitmapSource: { _ in throw error("Unexpected bitmap loading") },observe: { e in
                switch e {
                case .device(.soundRequest(let loop)):try observe(.init("soundRequest",[loop ? 1 : 0]))
                case .device(.soundMethod(let resource,let offset,let args)):try observe(.init("soundMethod",[resource,UInt32(offset)]+args))
                case .state(.resetInput):break // Real431c70 state writes are performed by continueMenu.
                case .candidates(let seat,let ordinals):try observe(.init("candidates",[UInt32(seat)]+ordinals.map(UInt32.init)))
                case .state(.random(let stream,let range,let result,let beforeIndex,let beforeCounter,let index,let counter)):
                    try observe(.init("random",[stream,range,result,Int32(beforeIndex),Int32(beforeCounter),Int32(index),Int32(counter)].map(UInt32.init(bitPattern:))))
                default:throw error("Unexpected continuation event")
                }
            })
            if confirmation != 0 && action == 2 {
                // 42df7c..42e0b0 visits all eight seats. Preserve its own World
                // cursor as a semantic offset; never import source stack bytes.
                local[0x20] = 0x1b4;local[0x34] = 32
            }
        }
        try mark(0x42e0b6)
        if try word(0x44d078) <= 0 && word(0x4512c8) == 0 { try write(0x4512c8,1) }
        try mark(0x42e0d2);return finish(.returned)
    }
}
