/// Whole War Start43a21f..43a769: arena, eight live seat choices, music and
/// recording. Own state commits together; callbacks must stage external effects
/// until the enclosing War and outer menu return commits. Controlled source
/// matrix covers56 successful preparations; ordinary resource failures and
/// the own full-startup join remain separate open comparisons.
public enum OriginalWarPreparation {
    public static func prepare(state: inout OriginalMatchPreparation,
        memory: inout OriginalMenuPresentationMemory,localTime: () throws -> OriginalLocalTime,
        constructBitmap: (String,Bool,[UInt8]) throws -> OriginalLoadedBitmap,
        releaseBitmap: (Int,OriginalLoadedBitmap) throws -> Void = { _,_ in
            throw OriginalStateError.invalidStorage("Existing War BG release continuation was not supplied")
        },
        resumeMusic: (inout OriginalStateRecord) throws -> Void,
        allocateReplay: (Int) throws -> UInt32,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in },
        numericCheckpoint: (UInt32,Int,OriginalMatchPreparation) throws -> Void = { _,_,_ in },
        checkpoint: (UInt32,OriginalMatchPreparation,OriginalMenuPresentationMemory,[UInt8]) throws -> Void = { _,_,_,_ in }) throws {
        var scene=state,owned=memory,name: [UInt8]=[]
        func error(_ s: String) -> OriginalStateError { .invalidStorage("War preparation: "+s) }
        func word(_ a: Int) throws -> Int32 { try scene.global(a) }
        func write(_ a: Int,_ v: Int32) throws { try scene.setGlobal(a,v) }
        func mark(_ pc: UInt32) throws { try checkpoint(pc,scene,owned,name) }
        func actor(_ slot: Int) throws -> Int {
            guard (0..<400).contains(slot) else { throw error("Actor slot") }
            let i=Int(try scene.world.integer(at:0x194+slot*4,as:UInt32.self))
            guard scene.actors.indices.contains(i) else { throw error("Actor binding") };return i
        }
        guard try scene.world.integer(at:0x7d4,as:UInt32.self)==0 else { throw error("Catalog binding") }
        try mark(0x43a21f)
        try write(0x450bb0,0);try write(0x450bb4,0);try write(0x44d020,0)
        let time=try localTime()
        try observe(.init("localTime",[time.year,time.month,time.dayOfWeek,time.day,time.hour,time.minute,time.second,time.milliseconds].map(UInt32.init)))
        func decimal(_ v: UInt16,_ width: Int,_ pad: Character = "0") -> String {
            let s=String(v);return String(repeating:String(pad),count:max(0,width-s.count))+s
        }
        let date=decimal(time.year,4," ")+decimal(time.month,2)+decimal(time.day,2)+"_"+decimal(time.hour,2)+decimal(time.minute,2)+decimal(time.second,2)+"_Battle"
        name=Array(date.utf8)
        try observe(.init("format",[UInt32(name.count)],[Array("%4d%02d%02d_%02d%02d%02d_Battle".utf8),name]))
        let filename=name+Array(".lfr".utf8)
        for (i,b) in (filename+[0]).enumerated() { try scene.globals.write(b,at:0x44fd98-OriginalMatchPreparation.globalBase+i) }
        try observe(.init("format",[UInt32(filename.count)],[Array("%s.lfr".utf8),filename]))
        let notice=try word(0x450be4)
        try write(0x450b6c,0)
        if notice != 0 { try write(0x450b70,1) }
        for slot in 0..<400 { try scene.world.write(UInt8(0),at:4+slot) }
        try mark(0x43a2b6)
        guard let counts=scene.catalog.registry.records[0x4d82380] else { throw error("Arena count storage") }
        let count=try counts.integer(at:4,as:Int32.self)
        if try word(0x44d028)==1 {
            let selected=try scene.drawMenuRandom(stream:0x123,range:count &- 2,observe:observe)
            try write(0x44d024,selected)
            if selected==count &- 3 { try write(0x44d024,99) }
        }
        let arenaIndex=try word(0x44d024)
        guard (0..<count).contains(arenaIndex) || arenaIndex==99,scene.backgrounds.indices.contains(Int(arenaIndex)) else { throw error("Arena binding") }
        try mark(0x43a305)
        // The original five-cell loop consumes the activation clear above.
        // Retain the read/order rule; no pre-clear Actor activation is imported.
        for slot in 0..<400 where try scene.world.integer(at:4+slot,as:UInt8.self) != 0 {
            let a=try actor(slot)
            if try scene.actors[a].integer(at:0x364,as:Int32.self)==0 { try scene.actors[a].write(Int32(slot+10),at:0x364) }
        }
        try mark(0x43a3b1)
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
        try mark(0x43a42d)
        for seat in 0..<8 {
            try mark(0x43a450)
            let status=try word(0x451288+seat*4)
            guard status>0 else { continue }
            let cpu=status>10,slot=cpu ? seat+10 : seat,source=try actor(seat),a=try actor(slot)
            let team=try scene.actors[source].integer(at:0x364,as:Int32.self)
            let object=Int(try scene.actors[source].integer(at:0x368,as:UInt32.self))
            guard (1...2).contains(team),scene.loadedObjects.indices.contains(object) else { throw error("Participant team/Object binding") }
            try observe(.init("reconstruct",[UInt32(slot)]));try scene.actors[a].reconstructActor()
            try mark(cpu ? 0x43a47b : 0x43a5c1)
            try scene.actors[a].write(UInt32(object),at:0x368)
            let objectField=try scene.loadedObjects[object].header.integer(at:0x90,as:UInt32.self)
            try scene.actors[a].writeBinary64(cpu ? 350 : 400,at:0x58)
            try scene.actors[a].write(objectField,at:0x31c)
            try scene.actors[a].writeBinary64(cpu ? 0 : -50,at:0x60)
            try scene.actors[a].writeBinary64(300,at:0x68)
            try numericCheckpoint(cpu ? 0x43a4a8 : 0x43a5f2,seat,scene)
            try scene.actors[a].write(team,at:0x364);try scene.actors[a].write(team,at:0x344)
            try scene.world.write(UInt8(1),at:4+slot);try scene.actors[a].write(Int32(75),at:8)
            let arena=scene.backgrounds[Int(arenaIndex)]
            let x=try team==1 ? Int32(100) : arena.integer(at:0,as:Int32.self) &- 100
            try scene.actors[a].write(x,at:0x10)
            let lower=try arena.integer(at:4,as:Int32.self),upper=try arena.integer(at:8,as:Int32.self)
            let z=try scene.drawMenuRandom(stream:cpu ? 0x125 : 0x127,range:upper &- lower,observe:observe) &+ lower
            try scene.actors[a].write(z,at:0x18)
            if !cpu { try scene.actors[a].write(Int32(0),at:0x14) }
            try scene.actors[a].writeBinary64(Double(x),at:0x58);try scene.actors[a].writeBinary64(Double(z),at:0x68)
            if !cpu { try scene.actors[a].writeBinary64(0,at:0x60) }
            try numericCheckpoint(cpu ? 0x43a553 : 0x43a6a8,seat,scene)
            try scene.actors[a].write(Int32(200),at:0x308)
            if try word(0x451160)==1 { try scene.actors[a].write(Int32(500),at:0x308) }
            try scene.actors[a].write(Int32(slot),at:0x354)
            try scene.actors[a].write(word(0x44d754+Int(team)*4),at:0x340)
        }
        try mark(0x43a70c)
        try write(0x44d034,1);try write(0x450bbc,0);try write(0x450bdc,0)
        try resumeMusic(&scene.globals);try mark(0x43a727)
        for slot in 20..<400 where try scene.world.integer(at:4+slot,as:UInt8.self)==0 {
            let a=try actor(slot);try observe(.init("reconstruct",[UInt32(slot)]));try scene.actors[a].reconstructActor()
        }
        try mark(0x43a74d)
        try observe(.init("resetInput"));try scene.resetOriginalInput()
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
            try observe(.init("calloc",[address,1,UInt32(bytes)]));try owned.replayPointers.write(address,at:0)
        }
        guard let buffer=recording.buffer else { throw error("Recording buffer") }
        owned.allocations[address] = .init(storage:buffer)
        try mark(0x43a766);try mark(0x43a769)
        state=scene;memory=owned
    }
}
