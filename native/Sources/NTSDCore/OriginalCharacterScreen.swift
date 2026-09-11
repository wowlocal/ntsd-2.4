import Foundation

public enum OriginalCharacterScreenExit: String, Codable, Sendable { case returned, selectionStage, matchPrelude, tournamentPrelude, tournamentMatchPreparation, teamTournamentPrelude, teamTournamentMatchPreparation, warMatchPreparation }

public struct OriginalCharacterScreenCheckpoint: Equatable, Sendable {
    public let pc: UInt32, seat: Int
    /// Caller counters at ESP+20/+28/+34/+38/+3c, not a replacement x86 stack.
    public let locals: [Int:Int32]
}

public struct OriginalCharacterScreenDraw: Equatable, Sendable {
    public enum Bitmap: Equatable, Sendable { case menu(UInt32), catalog(Int) }
    public let bitmap: Bitmap
    public let x: Int32, y: Int32
    public let target: UInt32
    public let frame: Int32, colorKey: UInt32
    public init(bitmap: Bitmap, x: Int32, y: Int32, target: UInt32, frame: Int32 = -1, colorKey: UInt32 = 0) {
        self.bitmap = bitmap;self.x = x;self.y = y;self.target = target;self.frame = frame;self.colorKey = colorKey
    }
}

/// Common human-seat portion of429730: dispatcher429e5a, menu3 initialization,
/// character/team/ready handlers42a114..42b290 and tail42e0b6..42e0d2.
/// The computer/arena/War stages return an explicit continuation boundary.
/// Matches both34-frame own Naruto/Sasuke keyboard sequences. Alternative
/// modes and left/up/jump/team-exclusion branches still need wider captures.
public enum OriginalCharacterScreen {
    public static func advance(state: inout OriginalMatchPreparation, selectionAtEntry: UInt32, target: UInt32,
        input: OriginalFrontScreenBodyInput, fillBacking: [UInt8],
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in },
        checkpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation) throws -> Void = { _,_ in },
        includeTailCheckpoint: Bool = false,
        selectionStage: (inout OriginalMatchPreparation,inout [Int:Int32]) throws -> OriginalCharacterScreenExit = { _,_ in .selectionStage }) throws -> OriginalCharacterScreenExit {
        var library: OriginalLibSurfaceText?
        return try advanceCommon(state:&state,libraryText:&library,selectionAtEntry:selectionAtEntry,target:target,input:input,fillBacking:fillBacking,draw:draw,observe:observe,checkpoint:checkpoint,includeTailCheckpoint:includeTailCheckpoint,selectionStage:{ state,locals,_ in try selectionStage(&state,&locals) })
    }

    public static func advanceWithLibrary(state: inout OriginalMatchPreparation, libraryText: inout OriginalLibSurfaceText, selectionAtEntry: UInt32, target: UInt32,
        input: OriginalFrontScreenBodyInput, fillBacking: [UInt8],
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in },
        checkpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation) throws -> Void = { _,_ in },
        includeTailCheckpoint: Bool = false,
        selectionStage: (inout OriginalMatchPreparation,inout [Int:Int32]) throws -> OriginalCharacterScreenExit = { _,_ in .selectionStage }) throws -> OriginalCharacterScreenExit {
        var library: OriginalLibSurfaceText? = libraryText
        let result = try advanceCommon(state:&state,libraryText:&library,selectionAtEntry:selectionAtEntry,target:target,input:input,fillBacking:fillBacking,draw:draw,observe:observe,checkpoint:checkpoint,includeTailCheckpoint:includeTailCheckpoint,selectionStage:{ state,locals,_ in try selectionStage(&state,&locals) })
        libraryText = library!
        return result
    }

    static func advanceCommon(state: inout OriginalMatchPreparation, libraryText: inout OriginalLibSurfaceText?, selectionAtEntry: UInt32, target: UInt32,
        input: OriginalFrontScreenBodyInput, fillBacking: [UInt8],
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in },
        checkpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation) throws -> Void = { _,_ in },
        includeTailCheckpoint: Bool = false,
        tournamentStage: OriginalTournamentBracket.Continuation = OriginalTournamentBracket.unavailable,
        teamTournamentStage: OriginalTeamTournamentBracket.Continuation = OriginalTeamTournamentBracket.unavailable,
        warStage: OriginalWarSetup.Continuation = { _,_ in .selectionStage },
        selectionStage: (inout OriginalMatchPreparation,inout [Int:Int32],inout OriginalLibSurfaceText?) throws -> OriginalCharacterScreenExit = { _,_,_ in .selectionStage }) throws -> OriginalCharacterScreenExit {
        var candidate = state, library = libraryText
        let base = OriginalMatchPreparation.globalBase
        var local: [Int:Int32] = [0x20:0,0x28:0,0x34:0,0x38:0,0x3c:Int32(bitPattern: selectionAtEntry)]
        func error(_ message: String) -> OriginalStateError { .invalidStorage("Character screen: "+message) }
        func word(_ address: Int) throws -> Int32 { try candidate.globals.integer(at: address-base,as: Int32.self) }
        func write(_ address: Int,_ value: Int32) throws { try candidate.globals.write(value,at: address-base) }
        func actor(_ seat: Int) throws -> Int {
            let index = try candidate.world.integer(at: 0x194+seat*4,as: UInt32.self)
            guard candidate.actors.indices.contains(Int(index)) else { throw error("Seat Actor binding") };return Int(index)
        }
        func button(_ seat: Int,_ offset: Int) throws -> Bool { try candidate.actors[actor(seat)].integer(at: offset,as: UInt8.self) != 0 }
        func team(_ seat: Int) throws -> Int32 { try candidate.actors[actor(seat)].integer(at: 0x364,as: Int32.self) }
        func setTeam(_ seat: Int,_ value: Int32) throws { try candidate.actors[actor(seat)].write(value,at: 0x364) }
        func mark(_ pc: UInt32,_ seat: Int = -1) throws { try checkpoint(.init(pc: pc,seat: seat,locals: local),candidate) }
        func finish(_ exit: OriginalCharacterScreenExit) -> OriginalCharacterScreenExit { state = candidate;libraryText = library;return exit }
        func sound(_ slot: Int) throws {
            try OriginalMatchPrelude.playSound(in: candidate.globals,slot: slot) { e in
                switch e {
                case .soundRequest(let loop):try observe(.init("soundRequest",[loop ? 1 : 0]))
                case .soundMethod(let resource,let offset,let args):try observe(.init("soundMethod",[resource,UInt32(offset)]+args))
                default:throw error("Sound helper event")
                }
            }
        }
        func cstr(_ bytes: [UInt8],_ offset: Int = 0) throws -> [UInt8] {
            guard bytes.indices.contains(offset),let end = bytes[offset...].firstIndex(of: 0) else { throw error("String extent") }
            return Array(bytes[offset..<end])
        }
        func text(_ bytes: [UInt8],_ x: Int32,_ y: Int32,_ color: UInt32) throws {
            if var text = library {
                try text.draw(bytes,target: UInt32(bitPattern: word(0x455608)),background: 0,color: color,x: x,y: y,
                    dcResult: input.dcResult,dc: input.dc) { try observe(.init($0.kind.rawValue,$0.arguments,$0.strings)) }
                library = text
            } else {
                try OriginalSurfaceText.draw(bytes,target: UInt32(bitPattern: word(0x455608)),background: 0,color: color,x: x,y: y,
                    dcResult: input.dcResult,dc: input.dc) { try observe(.init($0.kind.rawValue,$0.arguments,$0.strings)) }
            }
        }
        func bitmap(_ source: OriginalCharacterScreenDraw.Bitmap,_ x: Int32,_ y: Int32) throws {
            try draw(.init(bitmap: source,x: x,y: y,target: target),candidate.globals)
        }
        func menuBitmap(_ address: Int,_ x: Int32,_ y: Int32) throws { try bitmap(.menu(UInt32(bitPattern: word(address))),x,y) }
        func object(_ seat: Int) throws -> OriginalLoadedObject {
            let index = try candidate.actors[actor(seat)].integer(at: 0x368,as: UInt32.self)
            guard candidate.catalog.objects.indices.contains(Int(index)) else { throw error("Actor Object binding") }
            return candidate.catalog.objects[Int(index)]
        }
        func face(_ seat: Int,_ x: Int32,_ y: Int32) throws {
            if try word(0x451248+seat*4) < 0 { try menuBitmap(0x44fd84,x,y) }
            else {
                let ref = try object(seat).header.integer(at: 0x6fc,as: UInt32.self)
                guard ref > 0,candidate.catalog.bitmaps.indices.contains(Int(ref-1)) else { throw error("Portrait bitmap binding") }
                try bitmap(.catalog(Int(ref-1)),x,y)
            }
        }
        func name(_ seat: Int) throws -> [UInt8] {
            try word(0x451248+seat*4) < 0 ? Array(" Random".utf8) : cstr(object(seat).nameTail.bytes)
        }
        func animatedColor() throws -> UInt32 {
            let count = try word(0x451224)
            let phase = UInt8(truncatingIfNeeded: (count/6) &* 76 &+ count &* 30)
            return (UInt32(phase &+ 70) | 0xff00)<<8 | UInt32(phase &+ 25)
        }
        func eligible(_ ordinal: Int32) throws -> Bool {
            guard candidate.catalog.objects.indices.contains(Int(ordinal)) else { throw error("Roster access outside catalog") }
            let header = candidate.catalog.objects[Int(ordinal)].header
            if try header.integer(at: 0x6f8,as: Int32.self) != 0 { return false }
            let group = try header.integer(at: 0x6f4,as: Int32.self)/10
            return try (group != 3 && group != 5) || word(0x458428) == 1
        }
        func roster(_ seat: Int,_ direction: Int32) throws {
            let selected = 0x451248+seat*4
            guard let record = candidate.catalog.registry.records[0x4d82380] else { throw error("Catalog count record") }
            let count = try record.integer(at: 0,as: Int32.self)
            guard count > 0,count == candidate.catalog.objects.count else { throw error("Roster count") }
            for _ in 0...Int(count) {
                var ordinal = try word(selected) &+ direction
                try write(selected,ordinal)
                if direction > 0 && ordinal >= count { try write(selected,-1);return }
                if ordinal == -1 { return }
                if direction < 0 && ordinal < -1 { ordinal = count &- 1;try write(selected,ordinal) }
                if try eligible(ordinal) { try candidate.actors[actor(seat)].write(UInt32(bitPattern: ordinal),at: 0x368);return }
            }
            throw error("Roster traversal does not terminate")
        }
        guard candidate.actors.count == 400 else { throw error("Actor pool extent") }
        let mode = try word(0x451160),menu = try word(0x44d020)
        if (20...50).contains(menu) {
            let result=try OriginalTournamentSetup.advance(state:&candidate,libraryText:&library,target:target,input:input,
                fillBacking:fillBacking,draw:draw,observe:observe,checkpoint:checkpoint,continueBracket:tournamentStage)
            if result == .returned && includeTailCheckpoint { try mark(0x42e0d2) }
            return finish(result)
        }
        if (120...150).contains(menu) {
            let result=try OriginalTeamTournamentSetup.advance(state:&candidate,libraryText:&library,target:target,input:input,
                fillBacking:fillBacking,draw:draw,observe:observe,checkpoint:checkpoint,continueBracket:teamTournamentStage)
            if result == .returned && includeTailCheckpoint { try mark(0x42e0d2) }
            return finish(result)
        }
        guard try !(mode == 5 && word(0x450c2c) == 0),![10,300].contains(menu),
              !(20...50).contains(menu),!(120...150).contains(menu) else { throw error("Other menu dispatcher") }
        if menu == 3 {
            for seat in 0..<8 {
                try write(0x451288+seat*4,0);try write(0x451248+seat*4,-1);try write(0x451268+seat*4,1)
            }
            if mode == 1 { for slot in 0..<20 { try setTeam(slot,1) } }
            if mode == 4 {
                for seat in 0..<8 { try setTeam(seat+10,seat < 4 ? 1 : 2);try setTeam(seat,seat < 4 ? 1 : 2) }
            }
            try write(0x4512c8,0);try write(0x44d020,1);local[0x3c] = 0
        } else if menu == 2 { try write(0x4512c8,3);try write(0x44d020,1);local[0x3c] = 0 }
        if try mode == 4 && word(0x4512c8) == 3 && word(0x44d020) < 200 { try write(0x44d020,200) }
        if try (200..<300).contains(word(0x44d020)) {
            let result=try warStage(&candidate,&library)
            if result == .returned && includeTailCheckpoint { try mark(0x42e0d2) }
            return finish(result)
        }
        try mark(0x42a114)
        try write(0x451224,(word(0x451224) &+ 1)%30)
        for slot in 0..<400 { let value = try team(slot);if !(0...4).contains(value) { try setTeam(slot,0) } }
        try mark(0x42a1be)
        var filled = OriginalFrontScreenEvent("fill")
        filled.fill = try OriginalSurfaceFilling.request(target: UInt32(bitPattern: word(0x455608)),x: 0,y: 0,width: 794,height: 550,color: 0,backing: fillBacking)
        try observe(filled);try menuBitmap(0x4512c4,40,33)
        if try word(0x4512c8) == 0 {
            for seat in 0..<8 where try word(0x451288+seat*4) == 0 { local[0x28]! &+= 1 }
        } else { local[0x28] = -1 }
        for seat in 0..<8 {
            try mark(0x42a25a,seat)
            let status = 0x451288+seat*4,latch = 0x451268+seat*4,selected = 0x451248+seat*4
            let x = Int32(seat%4*153),y = Int32(seat/4*212),current = try word(status)
            if current > 0 {
                if current < 11 { try text(cstr(candidate.globals.bytes,0x44fcc0+seat*11-base),x &+ 177,y &+ 219,0xffffff) }
                else { try text(Array("Computer".utf8),x &+ 177,y &+ 219,0x9b9bff) }
            } else if try word(0x4512c8) == 0 { try text(Array("   Join?".utf8),x &+ 177,y &+ 219,animatedColor()) }
            else { try text(Array("     ----".utf8),x &+ 177,y &+ 219,0xffffff) }
            if try word(status) == 0 && word(0x4512c8) == 0 {
                let timer = try word(0x44d078)
                if timer == 150 { try menuBitmap(word(0x451224)%5 < 3 ? 0x4512ac : 0x4512a8,x &+ 147,y &+ 120) }
                else if timer >= 0 { try menuBitmap(0x4512b0+Int(timer/30)*4,x &+ 181,y &+ 125) }
                if try button(seat,0xd1) {
                    if try word(latch) == 0 && word(0x44d074) == 0 { try write(status,1);try sound(0x45560c) }
                    try write(latch,1)
                } else if try button(seat,0xd2) && local[0x28] == 8 {
                    if try word(latch) == 0 {
                        try sound(0x455614);try write(0x44d020,10);try write(0x457580,0);try candidate.resetOriginalInput()
                    }
                    try write(latch,1)
                } else { try write(latch,0) }
            }
            if try word(status) == 1 {
                try face(seat,x &+ 147,y &+ 94);try text(name(seat),x &+ 177,y &+ 241,animatedColor())
                if try button(seat,0xd0) { if try word(latch) == 0 { try roster(seat,1) };try write(latch,1) }
                else if try button(seat,0xcf) { if try word(latch) == 0 { try roster(seat,-1) };try write(latch,1) }
                else if try button(seat,0xcd) { if try word(latch) == 0 { try write(selected,-1) };try write(latch,1) }
                else if try button(seat,0xd1) { if try word(latch) == 0 { try sound(0x45560c);try write(status,mode == 1 ? 3 : 2) };try write(latch,1) }
                else if try button(seat,0xd2) { if try word(latch) == 0 { try sound(0x455614);try write(status,0) };try write(latch,1) }
                else { try write(latch,0) }
            }
            if try word(status) == 2 {
                var ready = 0,excluded: Int32 = -1
                for index in 0..<8 where try word(0x451288+index*4) == 3 { ready += 1 }
                if ready == 7 && (mode == 0 || mode == 4) {
                    for index in 0..<8 where try index != seat && word(0x451288+index*4)%10 == 3 {
                        let value = try team(index)
                        if value == 0 { excluded = -2 }
                        else if excluded == -1 { excluded = value }
                        else if excluded >= 0 && value != excluded { excluded = -2 }
                    }
                }
                try face(seat,x &+ 147,y &+ 94);try text(name(seat),x &+ 177,y &+ 241,0xffffff)
                func forbidden(_ value: Int32) -> Bool { value == excluded || (mode == 4 && (value == 0 || value > 2)) }
                while try forbidden(team(seat)) { try setTeam(seat,(team(seat) &+ 1)%5) }
                let value = try team(seat)
                if (0...4).contains(value) {
                    let label = value == 0 ? "Independent" : "Team \(value)"
                    try text(Array(label.utf8),x &+ (value == 0 ? 167 : 187),y &+ 263,animatedColor())
                }
                if mode == 2 { try setTeam(seat,0);try candidate.actors[actor(seat)].write(UInt8(1),at: 0xd1);try write(latch,0) }
                if try button(seat,0xd0) {
                    if try word(latch) == 0 { repeat { try setTeam(seat,(team(seat) &+ 1)%5) } while try forbidden(team(seat)) }
                    try write(latch,1)
                } else if try button(seat,0xcf) {
                    if try word(latch) == 0 { repeat { let value = try team(seat) &- 1;try setTeam(seat,value < 0 ? 4 : value) } while try forbidden(team(seat)) }
                    try write(latch,1)
                } else if try button(seat,0xd1) { if try word(latch) == 0 { try sound(0x45560c);try write(status,3) };try write(latch,1) }
                else if try button(seat,0xd2) { if try word(latch) == 0 { try write(status,1);try sound(0x455614) };try write(latch,1) }
                else { try write(latch,0) }
            }
            if try word(status) == 3 {
                try face(seat,x &+ 147,y &+ 94);try text(name(seat),x &+ 177,y &+ 241,0xffffff)
                let value = try team(seat)
                if (0...4).contains(value) { try text(Array((value == 0 ? "Independent" : "Team \(value)").utf8),x &+ (value == 0 ? 167 : 187),y &+ 263,0xffffff) }
                if try word(0x4512c8) == 0 {
                    if try button(seat,0xd2) && word(0x44d078) == 150 {
                        if try word(latch) == 0 { try write(status,mode == 1 ? 1 : 2);try sound(0x455614) };try write(latch,1)
                    } else if try button(seat,0xd2) && word(0x44d078) < 150 {
                        if try word(latch) == 0 { local[0x34] = 1 };try write(latch,1)
                    } else { try write(latch,0) }
                }
            }
            let active = try word(status) == 3
            try candidate.world.write(UInt8(active ? 1 : 0),at: 4+seat)
            if active { local[0x38]! &+= 1 }
            if try word(status) == 0 || word(status) == 3 { local[0x20]! &+= 1 }
        }
        try mark(0x42b246)
        if local[0x38]! > 0 && local[0x20] == 8 {
            try write(0x44d078,word(0x44d078) &- 1)
            if local[0x34] != 0 { try write(0x44d078,word(0x44d078) &- 30) }
            if local[0x38] == 8 { try write(0x44d078,0) }
        } else { try write(0x44d078,150) }
        let selection = try word(0x4512c8)
        try write(0x44d074,selection)
        if (1...3).contains(selection) {
            let exit = try selectionStage(&candidate,&local,&library)
            return finish(exit)
        }
        if includeTailCheckpoint { try mark(0x42e0b6) }
        if try word(0x44d078) <= 0 && word(0x4512c8) == 0 { try write(0x4512c8,1) }
        try mark(0x42e0d2)
        return finish(.returned)
    }
}
