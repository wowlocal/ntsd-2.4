/// Team Tournament436747..436afd: date/round filename, four Actors, arena and
/// whole recording initialization. Callers stage device/allocator effects until
/// the enclosing434ab0/422ab8 return commits. All references are owned tokens.
public enum OriginalTeamTournamentPreparation {
    public static func prepare(state: inout OriginalMatchPreparation,
        memory: inout OriginalMenuPresentationMemory, localTime: () throws -> OriginalLocalTime,
        constructBitmap: (String,Bool,[UInt8]) throws -> OriginalLoadedBitmap,
        releaseBitmap: (Int,OriginalLoadedBitmap) throws -> Void = { _,_ in
            throw OriginalStateError.invalidStorage("Existing BG release continuation was not supplied")
        },
        allocateReplay: (Int) throws -> UInt32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in },
        checkpoint: (UInt32,OriginalMatchPreparation,OriginalMenuPresentationMemory,[UInt8]) throws -> Void = { _,_,_,_ in }) throws {
        var scene=state,owned=memory,name: [UInt8]=[]
        func error(_ s: String) -> OriginalStateError { .invalidStorage("Team Tournament preparation: "+s) }
        func word(_ a: Int) throws -> Int32 { try scene.global(a) }
        func write(_ a: Int,_ v: Int32) throws { try scene.setGlobal(a,v) }
        func mark(_ pc: UInt32) throws { try checkpoint(pc,scene,owned,name) }
        func seat(_ value: Int32) throws -> Int {
            guard (0..<8).contains(value) else { throw error("Participant binding") };return Int(value)
        }
        func actor(_ slot: Int) throws -> Int {
            guard (0..<400).contains(slot) else { throw error("Actor slot") }
            let i=Int(try scene.world.integer(at:0x194+slot*4,as:UInt32.self))
            guard scene.actors.indices.contains(i) else { throw error("Actor binding") };return i
        }
        guard try scene.world.integer(at:0x7d4,as:UInt32.self)==0 else { throw error("Catalog binding") }
        try mark(0x436747)
        try write(0x44d020,0)
        let time=try localTime()
        try observe(.init("localTime",[time.year,time.month,time.dayOfWeek,time.day,time.hour,time.minute,time.second,time.milliseconds].map(UInt32.init)))
        func decimal(_ v: UInt16,_ width: Int,_ pad: Character = "0") -> String {
            let s=String(v);return String(repeating:String(pad),count:max(0,width-s.count))+s
        }
        let date=decimal(time.year,4," ")+decimal(time.month,2)+decimal(time.day,2)+"_"+decimal(time.hour,2)+decimal(time.minute,2)+decimal(time.second,2)
        name=Array(date.utf8)
        try observe(.init("format",[UInt32(name.count)],[Array("%4d%02d%02d_%02d%02d%02d".utf8),name]))
        name += Array("_2on2_".utf8)
        switch try word(0x44d318) {
        case 2:name += Array("SemiFinal".utf8)
        case 4:name += Array("Final".utf8)
        default:break
        }
        let filename=name+Array(".lfr".utf8)
        for (i,b) in (filename+[0]).enumerated() { try scene.globals.write(b,at:0x44fd98-OriginalMatchPreparation.globalBase+i) }
        try observe(.init("format",[UInt32(filename.count)],[Array("%s.lfr".utf8),filename]))
        try write(0x450b6c,0)
        if try word(0x450be4) != 0 { try write(0x450b70,1) }
        try mark(0x436864)
        let count=try scene.catalog.registry.records[0x4d82380]!.integer(at:4,as:Int32.self)
        if try word(0x44d028)==1 {
            var selected=try scene.drawMenuRandom(stream:0x109,range:count &- 2,observe:observe)
            try write(0x44d024,selected)
            if selected==count &- 3 { selected=99;try write(0x44d024,selected) }
        }
        let arenaIndex=try word(0x44d024)
        guard (0..<count).contains(arenaIndex) || arenaIndex==99,scene.backgrounds.indices.contains(Int(arenaIndex)) else { throw error("Arena binding") }
        try mark(0x4368b2)
        for slot in 0..<20 where try scene.world.integer(at:4+slot,as:UInt8.self) != 0 {
            let a=try actor(slot),object=Int(try scene.actors[a].integer(at:0x368,as:UInt32.self))
            guard scene.loadedObjects.indices.contains(object) else { throw error("Selected Object binding") }
            try observe(.init("reconstruct",[UInt32(slot)]));try scene.actors[a].reconstructActor()
            try scene.actors[a].write(UInt32(object),at:0x368)
            try scene.actors[a].writeBinary64(350,at:0x58)
            try scene.actors[a].write(scene.loadedObjects[object].header.integer(at:0x90,as:UInt32.self),at:0x31c)
            try scene.actors[a].writeBinary64(0,at:0x60);try scene.actors[a].writeBinary64(300,at:0x68)
            try scene.actors[a].write(Int32(500),at:0x308)
            let participant=try seat(word(0x4512d0+slot*4)),hp=try word(0x44d080+participant*4)
            for offset in [0x2fc,0x300,0x304] { try scene.actors[a].write(hp,at:offset) }
            try scene.actors[a].write(word(0x44d0a0+participant*4),at:0x33c)
            try scene.actors[a].write(word(0x44d100+participant*4),at:0x364);try scene.actors[a].write(Int32(75),at:8)
            let arena=scene.backgrounds[Int(arenaIndex)],width=try arena.integer(at:0,as:Int32.self)
            let x=try scene.drawMenuRandom(stream:0x10a,range:width/2,observe:observe) &+ width/4
            try scene.actors[a].write(x,at:0x10)
            let lower=try arena.integer(at:4,as:Int32.self),upper=try arena.integer(at:8,as:Int32.self)
            let z=try scene.drawMenuRandom(stream:0x10b,range:upper &- lower,observe:observe) &+ lower
            try scene.actors[a].write(z,at:0x18);try scene.actors[a].write(Int32(0),at:0x14)
            try scene.actors[a].writeBinary64(Double(x),at:0x58);try scene.actors[a].writeBinary64(Double(z),at:0x68);try scene.actors[a].writeBinary64(0,at:0x60)
            try scene.actors[a].write(Int32(slot),at:0x354)
        }
        try mark(0x436a30)
        for a in Array(stride(from:0x450c24,through:0x450c04,by:-4))+[0x450c28] { try write(a,0) }
        scene.releasedBitmapOrder=[]
        if count>0 { for i in 0..<Int(count) {
            try observe(.init("releaseLayers",[UInt32(i)]))
            scene.releasedBitmapOrder += try scene.backgroundLoader.releaseLayersWithSurface(in:&scene.backgrounds[i],releaseBitmap:releaseBitmap)
        } }
        if arenaIndex != 99 {
            try observe(.init("loadLayers",[UInt32(arenaIndex)]))
            try scene.backgroundLoader.loadLayersWithSurface(in:&scene.backgrounds[Int(arenaIndex)],constructBitmap:constructBitmap)
        }
        try mark(0x436a9f)
        try write(0x44d034,1);try write(0x450bbc,0)
        for slot in 20..<400 where try scene.world.integer(at:4+slot,as:UInt8.self)==0 {
            let a=try actor(slot);try observe(.init("reconstruct",[UInt32(slot)]));try scene.actors[a].reconstructActor()
        }
        try observe(.init("resetInput"));try scene.resetOriginalInput();try mark(0x436ae6)
        let mode=try word(0x451160)
        try observe(.init("replayEntry",[UInt32(bitPattern:mode)]))
        let old=try owned.replayPointers.integer(at:0,as:UInt32.self)
        if old != 0 {
            guard var allocation=owned.allocations[old],allocation.live else { throw error("Recording ownership") }
            try observe(.init("free",[old]));allocation.live=false;owned.allocations[old]=allocation
            try owned.replayPointers.write(UInt32(0),at:0)
        }
        var recording=OriginalReplayRecording(),address: UInt32=0
        try recording.begin(mode:mode,state:&scene) { event in
            guard case .allocate(_,let bytes)=event else { throw error("Unexpected recording generation") }
            address=try allocateReplay(bytes)
            guard address != 0,owned.allocations[address]?.live != true else { throw error("Recording allocation unavailable or live alias") }
            try observe(.init("calloc",[address,1,UInt32(bytes)]))
            try owned.replayPointers.write(address,at:0)
        }
        guard let buffer=recording.buffer else { throw error("Recording buffer") }
        owned.allocations[address] = .init(storage:buffer)
        try mark(0x436afa)
        state=scene;memory=owned
    }
}
