extension OriginalBackgroundLoader {
    /// Whole40c0e0 release/free requests precede its first-pointer clear. A
    /// platform continuation is required for a live layer; no silent release.
    public mutating func releaseLayersWithSurface(in record: inout OriginalStateRecord,
        releaseBitmap: (Int,OriginalLoadedBitmap) throws -> Void) throws -> [Int] {
        var candidate=self,storage=record
        guard storage.bytes.count==Self.recordSize else { throw OriginalStateError.invalidStorage("BG storage size") }
        if try storage.integer(at:0x914,as:UInt32.self) != 0 {
            let count=try storage.integer(at:0x1c,as:Int32.self)
            guard (0...30).contains(count) else { throw OriginalStateError.invalidStorage("BG release extent") }
            for i in 0..<Int(count) {
                let pointer=try storage.integer(at:0x914+i*4,as:UInt32.self)
                guard pointer>0,Int(pointer)<=candidate.resources.bitmaps.count else { throw OriginalStateError.invalidStorage("BG release ownership") }
                try releaseBitmap(Int(pointer-1),candidate.resources.bitmaps[Int(pointer-1)])
            }
        }
        let released=try candidate.releaseLayers(in:&storage)
        self=candidate;record=storage;return released
    }

    /// Whole40c030 layer order with an actual bitmap-constructor continuation.
    /// The caller stages platform requests and allocation ownership. A nil
    /// allocation stores the original NULL layer pointer without creating an
    /// owner or stopping later layers; successful wrappers remain individually owned.
    public mutating func loadLayersWithSurface(in record: inout OriginalStateRecord,
        constructBitmap: (String,Bool,[UInt8]) throws -> OriginalLoadedBitmap?) throws {
        var candidate=self,storage=record
        guard storage.bytes.count==Self.recordSize else { throw OriginalStateError.invalidStorage("BG storage size") }
        let count=try storage.integer(at:0x1c,as:Int32.self)
        guard (0...30).contains(count) else { throw OriginalStateError.invalidStorage("BG layer extent") }
        for index in 0..<Int(count) {
            var bytes: [UInt8]=[],terminated=false
            for i in 0..<30 {
                let byte=try storage.integer(at:0x20+index*30+i,as:UInt8.self)
                if byte==0 { terminated=true;break };bytes.append(byte)
            }
            guard terminated else { throw OriginalStateError.invalidStorage("BG layer path extent") }
            let path=String(String.UnicodeScalarView(bytes.map { UnicodeScalar($0) }))
            guard let constructed=try constructBitmap(path,false,[UInt8](repeating:0xa5,count:0x1f50)) else {
                try storage.write(UInt32(0),at:0x914+index*4)
                continue
            }
            let bitmap=try OriginalLoadedBitmap.checkedConstruction(constructed,path:path,optional:false)
            let slot=candidate.resources.bitmaps.count;candidate.resources.bitmaps.append(bitmap)
            try storage.write(UInt32(slot+1),at:0x914+index*4)
        }
        self=candidate;record=storage
    }
}
