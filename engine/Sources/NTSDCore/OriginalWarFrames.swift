/// Exact ordered fill rectangles for War4389a0 and438ad0.
/// The caller stages external requests until its enclosing menu commits.
public enum OriginalWarFrames {
    public static func draw(globals: inout OriginalStateRecord,pulse: Bool,
        x: Int32,y: Int32,width: Int32,height: Int32,color: UInt32,
        backing: [UInt8],observe: (OriginalSurfaceFillRequest) throws -> Void) throws {
        var g=globals
        let base=OriginalMatchPreparation.globalBase
        var outer=false
        if pulse {
            let phase=try (g.integer(at:0x451b80-base,as:Int32.self) &+ 1)%4
            try g.write(phase,at:0x451b80-base);outer=phase>=2
        }
        let target=try g.integer(at:0x455608-base,as:UInt32.self)
        let rectangles: [(Int32,Int32,Int32,Int32)]
        if outer {
            rectangles=[(x,y &- 1,width,1),(x,y &+ height,width,1),
                (x &- 1,y,1,height),(x &+ width,y,1,height),
                (x,y,width,1),(x,(y &+ height) &- 1,width,1),
                (x,y,1,height),((x &+ width) &- 1,y,1,height)]
        } else {
            rectangles=[(x &+ 1,y,width &- 2,1),(x &+ 1,(y &+ height) &- 1,width &- 2,1),
                (x,y &+ 1,1,height &- 2),((x &+ width) &- 1,y &+ 1,1,height &- 2)]
        }
        for (left,top,w,h) in rectangles {
            try observe(OriginalSurfaceFilling.request(target:target,x:left,y:top,width:w,height:h,color:color,backing:backing))
        }
        globals=g
    }
}
