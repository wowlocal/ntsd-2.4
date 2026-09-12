import XCTest
import NTSDCore

/// Native-only transaction checks using a small declared catalog. These are
/// not the574 original calls, source equivalence, raster or device observations.
final class OriginalWarSetupNativeTests: XCTestCase {
    enum Trial: Error { case injected }
    struct Buffer: Equatable {
        var events: [OriginalFrontScreenEvent]=[]
        var allocations=0
        var points: [UInt32]=[]
    }
    let base=OriginalMatchPreparation.globalBase
    func unknown(_ count: Int) throws -> OriginalStateRecord {
        try .init(bytes:[UInt8](repeating:0xa5,count:count),defined:[Bool](repeating:false,count:count))
    }
    func catalog() throws -> OriginalLoadedCatalog {
        var parent=try OriginalCatalogRegistry.regionSizes.mapValues { try unknown($0) }
        let background=try unknown(0x990),stage=try unknown(OriginalStageLoader.stageSize)
        let backgrounds=[OriginalStateRecord](repeating:background,count:101)
        parent[0x4d81060]=backgrounds[99];parent[0x4d819f0]=backgrounds[100]
        // Duplicate unit30 at the end exercises last-match ownership; eight
        // other IDs provide independent live Random choices after ordinal0.
        let ids=[30,31,33,34,39,32,35,36,37,122,123]+Array(1...12)+[30]
        let source="<object> "+ids.enumerated().map { "id: \($0.element) type: 0 file: object\($0.offset).txt" }.joined(separator:" ")+" <object_end>"
        let object="<bmp_begin> name: NativeTrial head: head.bmp small: small.bmp file(0-0): sheet.bmp w: 40 h: 40 row: 1 col: 1 <bmp_end>"
        let key=Array("SiuHungIsAGoodBearBecauseHeIsVeryGood".utf8)
        let stages=[UInt8](repeating:0,count:123)+Array("end".utf8).enumerated().map { $0.element &+ key[($0.offset+123)%key.count] }
        return try .init(source:Array(source.utf8),fileName:"data.txt",translation:.raw,
            parentBacking:parent,backgroundBacking:backgrounds,stageBacking:[OriginalStateRecord](repeating:stage,count:60),
            fileSource:{ $0=="data\\stage.dat" ? stages : Array(object.utf8) },
            bitmapSource:{ .init(path:$0,present:true,width:80,height:80) })
    }
    func initial(_ catalog: OriginalLoadedCatalog) throws -> OriginalMatchPreparation {
        let bootstrap=try OriginalWorldBootstrap(worldBacking:[UInt8](repeating:0xa5,count:OriginalStateRecord.worldPrefixSize),
            actorBacking:[[UInt8]](repeating:[UInt8](repeating:0xa5,count:OriginalStateRecord.actorSize),count:400),selector:4)
        var g=try unknown(OriginalMatchPreparation.globalSize)
        try OriginalWarTroops.initializeFileData(&g)
        for (a,v): (Int,Int32) in [(0x451160,4),(0x44d020,200),(0x4512c8,3),(0x457578,1),(0x455608,0x26006000),
            (0x45116c,0x20001000),(0x451178,0x20002000),(0x4511a0,0x20003000),(0x44eecc,1),
            (0x45560c,0x60000001),(0x455610,0x60000002),(0x455614,0x60000003),(0x44d024,100),(0x44d028,1),
            (0x450c30,2),(0x44f18c,1),(0x450bcc,0),(0x450c34,0)] { try g.write(v,at:a-base) }
        for seat in 0..<8 {
            for a in [0x451228,0x451248,0x451288,0x451320] { try g.write(Int32(0),at:a+seat*4-base) }
        }
        for i in 0..<3000 { try g.write(UInt8((i*37+5)%255+1),at:0x44ff90+i-base) }
        return try .init(catalog:catalog,bootstrap:bootstrap,globals:g)
    }
    func set(_ state: inout OriginalMatchPreparation,_ address: Int,_ value: Int32) throws { try state.globals.write(value,at:address-base) }
    func word(_ state: OriginalMatchPreparation,_ address: Int) throws -> Int32 { try state.globals.integer(at:address-base,as:Int32.self) }
    func atlas() throws -> OriginalStateRecord {
        var record=try unknown(0x1f50)
        // Declared widths at their actual atlas field offsets, not source snapshots.
        for i in 0..<30 { try record.write(Int32(30+i),at:0xfb0+i*4) }
        return record
    }
    @discardableResult
    func run(_ state: inout OriginalMatchPreparation,_ memory: inout OriginalWarMenuMemory,
        _ library: inout OriginalLibSurfaceText?,_ buffer: inout Buffer,
        failure: String? = nil,reached: inout Bool) throws -> OriginalCharacterScreenExit {
        let widths=try atlas()
        return try OriginalWarSetup.advance(state:&state,memory:&memory,libraryText:&library,environment:&buffer,
            target:0x26006000,input:.init(dcResult:0,dc:0x70000000,methodResult:-1,drawResults:[-1],shellResult:33),
            fillBacking:[UInt8](repeating:0xa5,count:100),allocate:{ index,env in
                env.allocations+=1
                return .init(address:0x71000000+UInt32(index)*0x2000,backing:[UInt8](repeating:0xa5,count:0x1f50))
            },construct:{ path,allocation,device,_,_ in
                let result=try OriginalBitmapConstructor.construct(.init(path:path,present:true,width:705,height:487),optional:false,
                    backing:allocation.backing,device:device,flags:0x40,surface:1,colorKeyResult:0)
                if failure=="secondResource" && path=="BATTLETROOPS" { reached=true;throw Trial.injected }
                return result
            },bitmapStorage:{ _,_ in widths },draw:{ q,_,_,env in
                env.events.append(.init("draw",[UInt32(bitPattern:q.x),UInt32(bitPattern:q.y),UInt32(bitPattern:q.frame)]))
            },observe:{ e,env in
                env.events.append(e)
                if failure=="lateText" && e.kind=="format" && env.events.filter({ $0.kind=="format" }).count==20 { reached=true;throw Trial.injected }
                if failure=="lateFrame" && e.kind=="fill" && env.events.contains(where:{ $0.kind=="warFrame" }) { reached=true;throw Trial.injected }
                if failure=="secondRandom" && e.kind=="candidates" && e.arguments.first==1 { reached=true;throw Trial.injected }
            },resourceEvent:{ e,env in env.events.append(.init("resource-"+e.kind.rawValue,e.arguments,e.strings)) },
            checkpoint:{ cp,_,_,env in
                env.points.append(cp.pc)
                if failure=="latePreset" && cp.pc==0x439e76 { reached=true;throw Trial.injected }
                if failure=="lateFinalize" && cp.pc==0x43a21f { reached=true;throw Trial.injected }
            })
    }
    func testWholeMenuRollsBackAfterLateDependencies() throws {
        let loaded=try catalog(),fresh=try initial(loaded)
        var state=fresh,memory=OriginalWarMenuMemory(),library: OriginalLibSurfaceText? = .init(),buffer=Buffer(),reached=false
        XCTAssertEqual(try run(&state,&memory,&library,&buffer,reached:&reached),.returned)
        XCTAssertEqual(memory.bitmaps.count,2);XCTAssertEqual(memory.unitObjects[0],23)
        XCTAssertEqual(buffer.allocations,2)
        XCTAssertTrue(buffer.points.contains(0x439ea6))
        let ready=state,resources=memory,text=library
        for failure in ["secondResource","lateText","lateFrame","latePreset","secondRandom","lateFinalize"] {
            state=failure=="secondResource" ? fresh : ready
            memory=failure=="secondResource" ? .init() : resources;library=text;buffer=Buffer();reached=false
            if failure=="latePreset" {
                try set(&state,0x44d020,210);try set(&state,0x44d760,4)
                try state.actors[0].write(UInt8(1),at:0xd1)
            }
            if failure=="secondRandom" {
                try set(&state,0x44d020,201)
                for seat in 0..<8 { try set(&state,0x451228+seat*4,1) }
            }
            if failure=="lateFinalize" {
                try set(&state,0x44d020,202);try set(&state,0x451b84,0)
                try state.actors[0].write(UInt8(1),at:0xd1)
            }
            let before=state,beforeMemory=memory,beforeLibrary=library
            do { _ = try run(&state,&memory,&library,&buffer,failure:failure,reached:&reached);XCTFail("Missing rejection: "+failure) }
            catch Trial.injected { XCTAssertTrue(reached,failure) }
            catch { XCTFail("Unexpected earlier failure \(failure): \(error)") }
            XCTAssertEqual(state.world,before.world,failure);XCTAssertEqual(state.actors,before.actors,failure)
            XCTAssertEqual(state.globals,before.globals,failure);XCTAssertEqual(memory,beforeMemory,failure)
            XCTAssertEqual(library,beforeLibrary,failure);XCTAssertEqual(buffer,Buffer(),failure)
        }
    }
}
