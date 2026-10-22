/// Original40be70 sheet selection and40bf30 frame-picture width lookup.
/// Header bitmap references are catalog index+1, with zero null.
public enum OriginalObjectDrawing {
    public static func draw(header: OriginalStateRecord,frame: OriginalStateRecord,
        x: Int32,y: Int32,colorKey: UInt32,mirroredSheet: Bool,pictureOffset: Int32,target: UInt32,
        bitmapDraw: (UInt32,Int32,Int32,Int32,UInt32,UInt32) throws -> Void) throws {
        guard try frame.integer(at: 0,as: UInt8.self) != 0 else { return }
        let picture = try frame.integer(at: 4,as: Int32.self) &+ pictureOffset
        if let (sheet,first) = try sheet(header,picture) {
            let token = try header.integer(at: (mirroredSheet ? 0x77c : 0x754)+4*sheet,as: UInt32.self)
            try bitmapDraw(token,x,y,picture &- first,colorKey,target)
        }
    }
    public static func width(header: OriginalStateRecord,frame: OriginalStateRecord,
        bitmapWord: (UInt32,UInt32) throws -> Int32) throws -> Int32 {
        guard try frame.integer(at: 0,as: UInt8.self) != 0 else { return 0 }
        let picture = try frame.integer(at: 4,as: Int32.self)
        guard let (sheet,first) = try sheet(header,picture) else { return 0 }
        let token = try header.integer(at: 0x754+4*sheet,as: UInt32.self)
        return try bitmapWord(token,UInt32(bitPattern: picture &- first) &* 4 &+ 0xfb0)
    }
    private static func sheet(_ header: OriginalStateRecord,_ picture: Int32) throws -> (Int,Int32)? {
        let count = try header.integer(at: 0x498,as: Int32.self)
        var index = 0
        while Int64(index) < Int64(count) {
            let first = try header.integer(at: 0x62c+index*4,as: Int32.self)
            if picture >= first {
                let rows = try header.integer(at: 0x6cc+index*4,as: Int32.self)
                let columns = try header.integer(at: 0x6a4+index*4,as: Int32.self)
                if picture < first &+ (rows &* columns) { return (index,first) }
            }
            index += 1
        }
        return nil
    }
}

/// Original40de30..40e160. Rendering reads the current Frame and raw Actor;
/// actual sheet/width helpers are composed, including the low-HP rectangle.
enum OriginalActorDrawing {
    static func draw(actor: OriginalStateRecord,header: OriginalStateRecord,frame: OriginalStateRecord,
        camera: Int32,target: UInt32,phase: Int32,
        bitmapWord: (UInt32,UInt32) throws -> Int32,
        bitmapDraw: (UInt32,Int32,Int32,Int32,UInt32,UInt32) throws -> Void,
        pointDraw: (Int32,Int32) throws -> Void) throws {
        func i(_ at: Int) throws -> Int32 { try actor.integer(at: at,as: Int32.self) }
        func f(_ at: Int) throws -> Int32 { try frame.integer(at: at,as: Int32.self) }
        let shift: Int32 = try i(0xb4) < 0 ? (phase &* 6) &- 3 : 0
        let facing = try actor.integer(at: 0x80,as: UInt8.self)
        let special = try f(8) == 9997
        if facing == 0 || facing == 1 {
            let width: Int32 = facing == 1 ? try OriginalObjectDrawing.width(header: header,frame: frame,bitmapWord: bitmapWord) : 0
            var x = try i(0x1c) &+ i(0x10) &- camera &+ shift
            x = try facing == 0 ? x &- f(0x50) : x &+ f(0x50) &- width
            if special { x = min(max(x,0),714) }
            let y = try i(0x18) &- f(0x54) &+ i(0x14)
            try OriginalObjectDrawing.draw(header: header,frame: frame,x: x,y: y,colorKey: 1,
                mirroredSheet: facing == 1,pictureOffset: i(0x318),target: target,bitmapDraw: bitmapDraw)
        }
        if special { return }
        if try i(0x2fc) < i(0x304)/3 && f(0x80) > 0 {
            let x = try i(0x1c) &+ i(0x10) &- camera &+ shift &+ (facing == 0 ? f(0x80) &- f(0x50) : f(0x50) &- f(0x80))
            let y = try f(0x84) &- f(0x54) &+ i(0x18) &+ i(0x14)
            try pointDraw(x,y)
        }
    }
}
