/// Playback start 43dfa0(mode, World+4, World+0x194, catalog): the match is
/// rebuilt from a loaded recording (4588ac). Current settings are saved to
/// their backups and replaced with the recorded ones; 18 seats are rebuilt;
/// background layers are released and the recorded arena loaded; music path,
/// War tables, RNG index/table and 44d324.. restored; music plays unless the
/// mode is Mission. The recording's tail (+0x630bb8/bc, +0x630e17) is written
/// as the original does. Layer and music effects are caller operations.
/// APPLICATION_PLAYBACK_PLAN.md P2.
public enum OriginalReplayPlayback {
    public enum Event: Equatable, Sendable {
        case reconstruct(seat: Int)
        case releaseLayers(Int), loadLayers(Int), playMusic
    }

    /// `saved` is the 0x320-byte backup area 458588..4588a8 (names, strings,
    /// difficulty) that `OriginalInputControlContext.restorePlayback` reads back.
    public static func prepare(state: inout OriginalMatchPreparation, recording: inout OriginalStateRecord,
                               saved: inout OriginalStateRecord,
                               releaseLayers: (Int, inout OriginalMatchPreparation) throws -> Void,
                               loadLayers: (Int, inout OriginalMatchPreparation) throws -> Void,
                               playMusic: (inout OriginalMatchPreparation) throws -> Void,
                               observe: (Event) throws -> Void = { _ in }) throws {
        var scene = state, rec = recording, backup = saved
        let base = OriginalMatchPreparation.globalBase
        func error(_ s: String) -> OriginalStateError { .invalidStorage("Playback start: "+s) }
        guard rec.byteCount == OriginalReplayFileInput.recordingSize,backup.byteCount == 0x320 else { throw error("Recording/backup extent") }
        func g(_ a: Int) throws -> Int32 { try scene.globals.integer(at: a-base,as: Int32.self) }
        func setG(_ a: Int,_ v: Int32) throws { try scene.globals.write(v,at: a-base) }
        func r(_ o: Int) throws -> Int32 { try rec.integer(at: o,as: Int32.self) }
        // strcpy from globals into the backup area, and from the recording into
        // globals, byte by byte as the original.
        func copyGlobal(_ to: Int,_ from: Int) throws {
            var i = 0
            while true {
                let b = try scene.globals.integer(at: from-base+i,as: UInt8.self)
                try backup.write(b,at: to-0x458588+i);i += 1
                if b == 0 { return }
            }
        }
        func copyFromRecording(_ to: Int,_ from: Int) throws {
            var i = 0
            while true {
                let b = try rec.integer(at: from+i,as: UInt8.self)
                try scene.globals.write(b,at: to-base+i);i += 1
                if b == 0 { return }
            }
        }
        func actor(_ seat: Int) throws -> Int {
            let i = Int(try scene.world.integer(at: 0x194+seat*4,as: UInt32.self))
            guard scene.actors.indices.contains(i) else { throw error("Actor binding") }
            return i
        }
        guard let registry = scene.catalog.registry.records[0x4d82380] else { throw error("Catalog count") }
        let objectCount = Int(try registry.integer(at: 0,as: Int32.self))
        let backgroundCount = Int(try registry.integer(at: 4,as: Int32.self))
        guard objectCount <= scene.catalog.objects.count,try scene.world.integer(at: 0x7d4,as: UInt32.self) == 0 else { throw error("Catalog binding") }

        // 43dfa0..43e110: settings swap.
        try backup.write(scene.globals.integer(at: 0x450c30-base,as: UInt8.self),at: 0x45877c-0x458588)
        let hidden = try g(0x458428)
        try setG(0x450b8c,0);try setG(0x450b84,1);try setG(0x450b88,1)
        try setG(0x450c30,r(0))
        try rec.write(hidden,at: 0x630bb8)
        try rec.write(g(0x45842c),at: 0x630bbc)
        try setG(0x458428,r(8));try setG(0x45842c,r(0xc));try setG(0x450b94,r(4))
        try setG(0x451160,r(0x148))
        for offset in stride(from: 0,to: 0x58,by: 0xb) {
            try copyGlobal(0x458850+offset,0x44fcc0+offset)
            try copyFromRecording(0x44fcc0+offset,0x14c+offset)
        }
        try copyGlobal(0x4587e8,0x44fd18);try copyFromRecording(0x44fd18,0x630bc0)
        try copyGlobal(0x458588,0x44f900);try copyFromRecording(0x44f900,0x630c24)
        try rec.write(UInt8(0),at: 0x630e17)
        try copyGlobal(0x458780,0x44f890);try copyFromRecording(0x44f890,0x630db4)
        try setG(0x44d024,r(0x1a4))
        for slot in 0..<400 { try scene.world.write(UInt8(0),at: 4+slot) }
        // 43e152: eighteen recorded seats.
        for seat in 0..<18 {
            let e = 0x238+seat*4
            guard try r(e) != 0 else { continue }
            let id = try r(e-0x48)
            if let object = try (0..<objectCount).first(where: { try scene.catalog.objects[$0].header.integer(at: 0x6f4,as: Int32.self) == id }) {
                let a = try actor(seat)
                try scene.actors[a].reconstructActor();try observe(.reconstruct(seat: seat))
                try scene.actors[a].write(UInt32(object),at: 0x368)
                try scene.actors[a].writeBinary64(350,at: 0x58)
                try scene.actors[a].write(scene.catalog.objects[object].header.integer(at: 0x90,as: UInt32.self),at: 0x31c)
                try scene.actors[a].writeBinary64(0,at: 0x60);try scene.actors[a].writeBinary64(300,at: 0x68)
            }
            let a = try actor(seat)
            try scene.actors[a].write(r(e-0x90),at: 0x364)
            try scene.world.write(rec.integer(at: e,as: UInt8.self),at: 4+seat)
            for (from,to) in [(0x48,8),(0x90,0x10),(0xd8,0x14),(0x120,0x18)] { try scene.actors[a].write(r(e+from),at: to) }
            try scene.actors[a].writeBinary64(Double(scene.actors[a].integer(at: 0x10,as: Int32.self)),at: 0x58)
            try scene.actors[a].writeBinary64(Double(scene.actors[a].integer(at: 0x18,as: Int32.self)),at: 0x68)
            try scene.actors[a].write(r(e+0x168),at: 0x308);try scene.actors[a].write(r(e+0x1b0),at: 0x354)
            let life = try r(e+0x1f8)
            try scene.actors[a].write(life,at: 0x304);try scene.actors[a].write(life,at: 0x300);try scene.actors[a].write(life,at: 0x2fc)
            try scene.actors[a].write(r(e+0x240),at: 0x33c);try scene.actors[a].write(r(e+0x288),at: 0x344);try scene.actors[a].write(r(e+0x2d0),at: 0x340)
        }
        for address in [0x450c24,0x450c20,0x450c1c,0x450c18,0x450c14,0x450c10,0x450c0c,0x450c08,0x450c04,0x450c28] { try setG(address,0) }
        if backgroundCount > 0 {
            for index in 0..<backgroundCount { try observe(.releaseLayers(index));try releaseLayers(index,&scene) }
        }
        let arena = try g(0x44d024)
        if arena != 99 { try observe(.loadLayers(Int(arena)));try loadLayers(Int(arena),&scene) }
        try copyFromRecording(0x44eed0,0x550)
        for k in 0..<22 {
            try setG(0x44d5f8+k*4,r(0x74c+k*4));try setG(0x44d650+k*4,r(0x7a4+k*4))
            try setG(0x44d6a8+k*4,r(0x7fc+k*4));try setG(0x44d700+k*4,r(0x854+k*4))
        }
        try setG(0x450bcc,r(0x8c4))
        for i in 0..<0xbb9 { try scene.globals.write(rec.integer(at: 0x8c8+i,as: UInt8.self),at: 0x44ff90-base+i) }
        for k in 0..<11 { try setG(0x44d324+k*4,r(0x1488+k*4)) }
        try setG(0x450b90,r(0x14b4))
        try setG(0x44d034,1);try setG(0x450bbc,0)
        let mode = try g(0x451160)
        if mode != 1 { try observe(.playMusic);try playMusic(&scene) }
        try setG(0x450bb0,0);try setG(0x450bb4,0)
        if mode == 1 {
            try setG(0x450b9c,0x46);try setG(0x450ba8,0);try setG(0x450bac,0);try setG(0x450ba4,0)
            try setG(0x44fb6c,-1);try setG(0x44f880,-1);try setG(0x450bc8,0);try setG(0x450bc4,0)
        }
        for slot in 0..<400 where try scene.world.integer(at: 4+slot,as: UInt8.self) == 0 {
            let a = try actor(slot);try scene.actors[a].reconstructActor();try observe(.reconstruct(seat: slot))
        }
        for seat in 0..<8 where try scene.world.integer(at: 4+seat+10,as: UInt8.self) == 0 && scene.world.integer(at: 4+seat,as: UInt8.self) == 0 {
            try scene.actors[actor(seat)].write(scene.actors[actor(seat+10)].integer(at: 0x364,as: Int32.self),at: 0x364)
        }
        try setG(0x450c34,0);try setG(0x450bd0,0);try setG(0x450bd4,0);try setG(0x450bd8,0)
        state = scene;recording = rec;saved = backup
    }

    /// 43266c..4326a2: the loader's MessageBoxA texts for its failures.
    public static func loaderMessage(_ status: Int32) -> [UInt8]? {
        switch status {
        case 0: return Array("Loading error!  Recording file may be corrupted!!".utf8)
        case -1: return Array("File path error!  File path should not contain chinese or unicode character!".utf8)
        default: return nil
        }
    }

    public enum Start: Equatable, Sendable {
        /// The playback match starts (44d020 = 0).
        case started
        /// MessageBoxA(0, message, 0, 0); 450b88/450b84 cleared, mode 6.
        case rejected(message: [UInt8])
    }

    /// 4326c7..4328c6 after 43dfa0: the recording's data checksum (+0x744 vs
    /// 44f620) and version (+0x748 vs 44d03c), then the War settings packed in
    /// +0x8c0 (displays, strengths, defense multipliers; the last divisor is
    /// EBX = 100 set at 432355 by the mode confirmation) and menu 0.
    public static func start(recording: OriginalStateRecord, globals: inout OriginalStateRecord) throws -> Start {
        let base = OriginalMatchPreparation.globalBase
        var state = globals
        func g(_ a: Int) throws -> Int32 { try state.integer(at: a-base,as: Int32.self) }
        func setG(_ a: Int,_ v: Int32) throws { try state.write(v,at: a-base) }
        func reject(_ message: [UInt8]) throws -> Start {
            try setG(0x450b88,0);try setG(0x450b84,0);try setG(0x451160,6)
            globals = state;return .rejected(message: message)
        }
        if try recording.integer(at: 0x744,as: Int32.self) != g(0x44f620) {
            return try reject(Array("Error!  Recording file are recorded in a LF2 with some data files (character or stage files) different from yours.  Your LF2 has to use the same set of data files in order in replay this recording file!".utf8))
        }
        let recorded = try recording.integer(at: 0x748,as: Int32.self),current = try g(0x44d03c)
        if recorded != current {
            var theirs = "",yours = ""
            if recorded == 0x1e { theirs = "v2.0" }
            if recorded > current { theirs = "a newer version" }
            if current == 0x1e { yours = "v2.0" }
            return try reject(Array("Version error.  Recording file are recorded in \(theirs). (your LF2 is \(yours))!".utf8))
        }
        let v = try recording.integer(at: 0x8c0,as: Int32.self)
        try setG(0x44d380,v/10_000_000 &- 1)
        try setG(0x451b74,(v%10_000_000)/1_000_000 &- 1)
        try setG(0x44d758,((v%1_000_000)/100_000 &* 10 &+ (v%100_000)/10_000) &* 10)
        try setG(0x44d384,(v%10_000)/1000 &- 1)
        try setG(0x451b78,(v%1000)/100 &- 1)
        try setG(0x44d75c,((v%100)/10 &* 10 &+ v%10) &* 10)
        try setG(0x44d020,0)
        globals = state;return .started
    }
}
