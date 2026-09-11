import Foundation
import XCTest
import NTSDCore

/// Native-only outer transaction checks. The game contract is the declared
/// menu startup -> War438b40 -> returned output, with the pinned EXE/lib/VC80
/// study still awaiting its preserved574-case corpus on X5. This test executes
/// no original instructions, Windows APIs, network or graphics device. A small
/// DAT catalog and explicit API responses exercise late dependency rejection;
/// they are not expected source state or a new compatibility match.
extension OriginalWarSetupNativeTests {
    struct OuterBuffer: Equatable {
        var events: [OriginalFrontScreenEvent]=[.init("previous-buffered-event")]
        var requests: [OriginalBitmapSurfaceLoading.Request]=[]
        var allocations: [UInt32]=[]
        var images: [UInt32:String]=[:],deletedImages=Set<UInt32>()
        var surfaces: [UInt32:[UInt8]]=[:]
        var dcs=Set<UInt32>(),deletedDCs=Set<UInt32>()
        var points: [String]=[]
    }
    struct OuterState {
        var state: OriginalMatchPreparation
        var memory: OriginalMenuPresentationMemory
        var music=OriginalMusicMemory(),resources=OriginalMenuResourceLoading()
        var war=OriginalWarMenuMemory()
        var library=OriginalLibSurfaceText(retainedDC:0x76000000)
        var buffer=OuterBuffer()
    }
    enum OuterError: Error { case unexpectedRequest(String) }

    func outerInitial() throws -> OuterState {
        var state=try initial(catalog())
        // Declared menu-entry inputs enable fresh resources, a waiting notice,
        // cancellation text and the actual blit-present branch. No source
        // snapshot provides these inputs or any later game/bitmap state.
        for (address,value): (Int,Int32) in [
            (0x4512cc,1),(0x44d07c,1),(0x44d058,2),
            (0x44f190,0),(0x450b70,3),(0x450bfc,0),(0x450b6c,4),
            (0x458348,3),(0x455634,0x26007000),
            (0x453ccc,0),(0x453cd0,0),(0x453cd4,794),(0x453cd8,550)] {
            try set(&state,address,value)
        }
        try state.globals.write(UInt8(1),at:0x44f1af-base)
        try state.globals.write(UInt8(0),at:0x4553f2-base)
        try state.globals.write(UInt8(0),at:0x4553f3-base)
        var result=OuterState(state:state,memory:.init(replayPointers:try .init(bytes:[UInt8](repeating:0,count:8),defined:[Bool](repeating:true,count:8))))
        result.memory.allocations[0x2a000020] = .init(storage:try unknown(32))
        result.music.allocations[0x2c010020]=try unknown(26)
        return result
    }

    func outerAPI(_ q: OriginalBitmapSurfaceLoading.Request,_ env: inout OuterBuffer) throws -> OriginalBitmapSurfaceLoading.Response {
        env.requests.append(q)
        switch q.kind {
        case "module":return .init(result:0x400000)
        case "image":
            // All13 declared resources are embedded DIBs. Their same declared
            // dimensions suffice for ownership/error propagation, not pixels.
            guard q.words.count==5 else { throw OuterError.unexpectedRequest(q.kind) }
            if q.words[4]==0x2010 { return .init() }
            XCTAssertEqual(q.words[4],0x2000)
            let path=String(decoding:try XCTUnwrap(q.strings.first),as:UTF8.self)
            XCTAssertTrue((OriginalMenuResourceLoading.paths+["BATTLEMODE","BATTLETROOPS"]).contains(path))
            let image=UInt32(0x61000000+env.images.count*0x100)
            env.images[image]=path;return .init(result:Int32(bitPattern:image))
        case "getObject":
            XCTAssertNotNil(env.images[q.words[0]])
            var bitmap=try OriginalStateRecord(bytes:[UInt8](repeating:0,count:24),defined:[Bool](repeating:true,count:24))
            for (offset,value): (Int,UInt32) in [(4,705),(8,487),(12,2820),(16,0x200001)] { try bitmap.write(value,at:offset) }
            return .init(result:24,writes:[.init(bytes:bitmap.bytes)])
        case "createSurface":
            let surface=UInt32(0x72000000+env.surfaces.count*0x100)
            env.surfaces[surface]=try XCTUnwrap(q.bytes)
            return .init(output:surface)
        case "description":
            return .init(writes:[.init(bytes:try XCTUnwrap(env.surfaces[q.words[0]]))])
        case "createDC":
            let dc=UInt32(0x74000000+env.dcs.count*0x10);env.dcs.insert(dc)
            return .init(result:Int32(bitPattern:dc))
        case "getDC":
            XCTAssertNotNil(env.surfaces[q.words[0]])
            return .init(output:0x75000000+q.words[0]-0x72000000)
        case "deleteDC":
            XCTAssertTrue(env.dcs.contains(q.words[0]));env.deletedDCs.insert(q.words[0]);return .init(result:1)
        case "deleteObject":
            XCTAssertNotNil(env.images[q.words[0]]);env.deletedImages.insert(q.words[0]);return .init(result:1)
        case "selectObject","stretch":return .init(result:1)
        case "restore","releaseDC","colorKey":return .init()
        default:throw OuterError.unexpectedRequest(q.kind)
        }
    }

    @discardableResult
    func outerRun(_ value: inout OuterState,failure: String? = nil,reached: inout Bool) throws -> OriginalCharacterScreenExit {
        let widths=try atlas()
        let output=try JSONDecoder().decode(OriginalMenuPresentationInput.self,from:JSONSerialization.data(withJSONObject:[
            "targetSurface":0x26006000,"methodResult":-1,"queryResult":-1,"audioGetResult":-1,"audioSetResult":-1,
            "queriedAudio":0,"audioVolume":50,"dcResult":0,"dc":0x70010000,"postResult":0]))
        var warFinished=false,menuReturned=false,overlaySeen=false,presentSeen=false
        let priorAllocations=value.buffer.allocations.count
        func fail(_ name: String) throws {
            guard failure==name else { return }
            XCTAssertTrue(warFinished);XCTAssertTrue(menuReturned);reached=true;throw Trial.injected
        }
        let end=try OriginalCharacterMenuContinuation.advanceWithWar(state:&value.state,memory:&value.memory,music:&value.music,
            resources:&value.resources,war:&value.war,libraryText:&value.library,environment:&value.buffer,
            target:0x26006000,input:.init(dcResult:0,dc:0x70000000,methodResult:-1,drawResults:[-1],shellResult:33),
            outputInput:output,milliseconds:17,
            musicRequest:{ _,_ in throw OuterError.unexpectedRequest("music on menu200/201") },
            allocate:{ i,env in
                let token=UInt32(0x51000000+i*0x2000);env.allocations.append(token)
                return .init(address:token,backing:[UInt8](repeating:0xa5,count:0x1f50))
            },warAllocate:{ i,env in
                let token=UInt32(0x71000000+i*0x2000);env.allocations.append(token)
                return .init(address:token,backing:[UInt8](repeating:0xa5,count:0x1f50))
            },perform:outerAPI,warPerform:outerAPI,bitmapStorage:{ _,_ in widths },
            afterStartup:{ _,_,_,resources,env in
                XCTAssertEqual(resources.bitmaps.count,11);env.points.append("startup")
            },draw:{ _,_,_,_ in throw OuterError.unexpectedRequest("character body before War") },
            warDraw:{ draw,_,owned,env in
                XCTAssertEqual(owned.bitmaps.count,2)
                env.events.append(.init("warDraw",[UInt32(bitPattern:draw.x),UInt32(bitPattern:draw.y),UInt32(bitPattern:draw.frame)]))
            },outputDraw:{ _,_,_,env in
                XCTAssertTrue(menuReturned);env.points.append("outputBitmap");try fail("outputBitmap")
            },observe:{ event,env in
                env.events.append(event)
                if event.kind=="textOut",event.arguments[2]==531 {
                    XCTAssertTrue(menuReturned);overlaySeen=true;env.points.append("overlayText");try fail("overlayText")
                }
                if event.kind=="method",event.arguments[1]==0x14 {
                    XCTAssertTrue(overlaySeen);presentSeen=true;env.points.append("present");try fail("present")
                }
            },warCheckpoint:{ cp,state,owned,env in
                if cp.pc==0x439ea6 {
                    XCTAssertEqual(owned.bitmaps.count,2);XCTAssertEqual(owned.unitObjects[0],23)
                    XCTAssertEqual(try self.word(state,0x44d774),0)
                    warFinished=true;env.points.append("warFinished")
                }
            },checkpoint:{ name,_,globals,env in
                env.points.append(name)
                if name=="menuReturned" { XCTAssertTrue(warFinished);menuReturned=true }
                if name=="matchBeforeReturn" {
                    XCTAssertTrue(presentSeen)
                    XCTAssertEqual(try globals.integer(at:0x44d058-self.base,as:Int32.self),1)
                    XCTAssertEqual(try globals.integer(at:0x450b6c-self.base,as:Int32.self),6)
                    try fail("beforeReturn")
                }
            })
        XCTAssertNil(failure);XCTAssertEqual(end,.returned);XCTAssertTrue(presentSeen)
        XCTAssertEqual(value.resources.bitmaps.count,11);XCTAssertEqual(value.war.bitmaps.count,2)
        XCTAssertEqual(value.buffer.allocations.count,13)
        XCTAssertEqual(value.buffer.allocations.count-priorAllocations,priorAllocations==0 ? 13 : 0)
        XCTAssertEqual(value.buffer.images.count,13);XCTAssertEqual(value.buffer.deletedImages,Set(value.buffer.images.keys))
        XCTAssertEqual(value.buffer.dcs,value.buffer.deletedDCs);XCTAssertEqual(value.buffer.surfaces.count,13)
        XCTAssertEqual(value.library.retainedDC,0x70010000)
        return end
    }

    func compareOuter(_ actual: OuterState,_ expected: OuterState,_ label: String) {
        XCTAssertEqual(actual.state.globals,expected.state.globals,label);XCTAssertEqual(actual.state.world,expected.state.world,label)
        XCTAssertEqual(actual.state.actors,expected.state.actors,label);XCTAssertEqual(actual.state.backgrounds,expected.state.backgrounds,label)
        XCTAssertEqual(actual.state.bitmaps,expected.state.bitmaps,label);XCTAssertEqual(actual.state.releasedBitmaps,expected.state.releasedBitmaps,label)
        XCTAssertEqual(actual.state.releasedBitmapOrder,expected.state.releasedBitmapOrder,label)
        XCTAssertEqual(actual.memory.replayPointers,expected.memory.replayPointers,label);XCTAssertEqual(actual.memory.allocations,expected.memory.allocations,label)
        XCTAssertEqual(actual.music.allocations,expected.music.allocations,label);XCTAssertEqual(actual.resources.bitmaps,expected.resources.bitmaps,label)
        XCTAssertEqual(actual.war,expected.war,label);XCTAssertEqual(actual.library,expected.library,label);XCTAssertEqual(actual.buffer,expected.buffer,label)
    }

    func testOuterOutputFailureRollsBackFreshResourcesAndRetainedRandom() throws {
        let fresh=try outerInitial()
        var ready=fresh,reached=false
        _ = try outerRun(&ready,reached:&reached)
        XCTAssertNotEqual(ready.state.globals,fresh.state.globals);XCTAssertNotEqual(ready.war,fresh.war)
        var reroll=ready
        try set(&reroll.state,0x44d020,201)
        try set(&reroll.state,0x44d058,2);try set(&reroll.state,0x450b6c,4)
        for seat in 0..<8 { try set(&reroll.state,0x451228+seat*4,1) }
        var finished=reroll
        _ = try outerRun(&finished,reached:&reached)
        XCTAssertNotEqual(finished.state.actors,reroll.state.actors)
        XCTAssertNotEqual(try word(finished.state,0x450bcc),try word(reroll.state,0x450bcc))
        let newEvents=finished.buffer.events.dropFirst(reroll.buffer.events.count)
        XCTAssertEqual(newEvents.filter { $0.kind=="random" && $0.arguments.first==0x122 }.count,8)
        for (name,input) in [("fresh",fresh),("retained-reroll",reroll)] {
            for failure in ["outputBitmap","overlayText","present","beforeReturn"] {
                var actual=input;reached=false
                do { _ = try outerRun(&actual,failure:failure,reached:&reached);XCTFail("Missing rejection: "+failure) }
                catch Trial.injected { XCTAssertTrue(reached) }
                XCTAssertTrue(reached,"Late stage was not reached")
                compareOuter(actual,input,name+" "+failure)
            }
        }
    }
}
