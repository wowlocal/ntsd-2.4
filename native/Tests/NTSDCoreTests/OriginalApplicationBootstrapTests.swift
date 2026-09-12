import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationBootstrapTests: XCTestCase {
    typealias A = OriginalApplicationBootstrap
    typealias Session = OriginalApplicationMenuSession
    typealias B = OriginalBitmapSurfaceLoadingTests
    typealias M = OriginalApplicationMenuReturnTests
    typealias F = OriginalApplicationFrontScreenTests
    typealias Body = OriginalApplicationScreenBodyTests
    typealias Entry = OriginalApplicationDispatchEntryTests
    typealias Loop = OriginalApplicationMessageLoopTests
    typealias Parent = OriginalWinMainStartupTests

    static func context(_ state: Session.State) throws -> Loop.Context {
        func part(_ at: Int,_ count: Int) throws -> OriginalStateRecord {
            try .init(bytes:Array(state.full.bytes[at..<at+count]),defined:Array(state.full.defined[at..<at+count]))
        }
        return try .init(globals:part(0,0xb440),outer:part(0xb440,0x854),local:part(0xb440,0x140),memory:state.memory)
    }
    static func same(_ actual: Session,_ previous: Session) {
        XCTAssertEqual(actual.state.full,previous.state.full)
        XCTAssertEqual(actual.state.memory.replayPointers,previous.state.memory.replayPointers)
        XCTAssertEqual(actual.state.memory.allocations,previous.state.memory.allocations)
        XCTAssertEqual(actual.state.front.bitmaps,previous.state.front.bitmaps)
        XCTAssertEqual(actual.state.earlyScreen.bitmaps,previous.state.earlyScreen.bitmaps)
        XCTAssertEqual(actual.state.earlyScreen.surfaces,previous.state.earlyScreen.surfaces)
        XCTAssertEqual(actual.state.earlyScreen.retainedOperation,previous.state.earlyScreen.retainedOperation)
        XCTAssertEqual(actual.state.libraryText,previous.state.libraryText)
        XCTAssertEqual(actual.state.random,previous.state.random)
        XCTAssertEqual(actual.state.screenBody,previous.state.screenBody)
        XCTAssertEqual(actual.state.settings,previous.state.settings)
        XCTAssertEqual(actual.loop.message,previous.loop.message)
        XCTAssertEqual(actual.loop.counter,previous.loop.counter)
        XCTAssertEqual(actual.loop.timer.baseline,previous.loop.timer.baseline)
    }
    static func sameStartup(_ actual: OriginalWinMainStartup,_ previous: OriginalWinMainStartup) throws {
        XCTAssertEqual(actual.random,previous.random);XCTAssertEqual(actual.dates,previous.dates)
        XCTAssertEqual(actual.output.calendar,previous.output.calendar)
        XCTAssertEqual(actual.output.music.allocations,previous.output.music.allocations)
        XCTAssertEqual(actual.panel.infoLocal,previous.panel.infoLocal);XCTAssertEqual(actual.panel.contentLocal,previous.panel.contentLocal)
        XCTAssertEqual(actual.panel.output?.buffer,previous.panel.output?.buffer)
        XCTAssertEqual(try actual.panel.output?.fileStorage(),try previous.panel.output?.fileStorage())
        XCTAssertEqual(actual.panel.panel.records.count,previous.panel.panel.records.count)
        for (a,b) in zip(actual.panel.panel.records,previous.panel.panel.records) {
            XCTAssertEqual(a.address,b.address);XCTAssertEqual(a.live,b.live);XCTAssertEqual(a.surface,b.surface)
            XCTAssertEqual(a.bitmap,b.bitmap)
        }
        XCTAssertEqual(actual.input?.joystickReturn,previous.input?.joystickReturn)
        XCTAssertEqual(actual.input?.sounds.deviceReady,previous.input?.sounds.deviceReady)
        let a = try XCTUnwrap(actual.input).sounds.loads,b = try XCTUnwrap(previous.input).sounds.loads
        XCTAssertEqual(a.count,b.count)
        for (x,y) in zip(a,b) {
            XCTAssertEqual(x.exit,y.exit);XCTAssertEqual(x.returned,y.returned);XCTAssertEqual(x.output,y.output)
            XCTAssertEqual(x.temporary,y.temporary);XCTAssertEqual(x.temporaryLive,y.temporaryLive)
            XCTAssertEqual(x.first,y.first);XCTAssertEqual(x.second,y.second)
            XCTAssertEqual(x.format,y.format);XCTAssertEqual(x.descriptor,y.descriptor)
        }
    }

    /// These adapters compare saved observations. Only Core chooses and calls
    /// the startup/loop/World/resources/settings/screen/menu continuations.
    func runMenu(_ index: Int,_ r: M.Resources,_ body: Body.Resources,_ front: F.Resources,
        _ br: B.Resources,_ er: Entry.Resources,fail: String? = nil,
        continuation: ((Session.Loop,B.OwnContext) throws -> Void)? = nil) throws {
        let c = r.c.cases[index]
        let bodyCase = c.parentKind == "body" ? body.c.cases[r.indices[index]] : nil
        let fi = c.parentKind == "body" ? body.frontIndices[r.indices[index]] : r.indices[index]
        let fc = front.c.cases[fi],si = try XCTUnwrap(front.settingKeys.firstIndex(of:fc.parent))
        let sr = front.settings,sc = sr.c.cases[si]
        let rawBitmap = try XCTUnwrap(sr.rawParents[sc.parent]) as NSDictionary
        let bi = try XCTUnwrap(br.rawCases.firstIndex { NSDictionary(dictionary:$0).isEqual(to:rawBitmap) })
        let bc = br.c.cases[bi],parents = try XCTUnwrap(bc.parents),parent = parents.parent,lc = parents.loop
        let rawParent = try XCTUnwrap((br.rawCases[bi]["parents"] as? [String:Any])?["parent"] as? [String:Any])
        let initialGlobals = try br.blob(parent.initialGlobals),outer = try br.blob(lc.initialOuter)
        // The saved independent PE verifier establishes these initial regions.
        // The trailing World storage is PE zero-fill, not a returned snapshot.
        let bytes = initialGlobals+outer+[UInt8](repeating:0,count:0xc3a8-0xb440-0x854)
        let initial = try OriginalStateRecord(bytes:bytes,defined:[Bool](repeating:true,count:bytes.count))
        let sources = Dictionary(uniqueKeysWithValues:try XCTUnwrap(parent.input).loads.map { (String(decoding:$0.path,as:UTF8.self),$0.file) })
        var platform = try Parent.Adapter(parent,rawParent,sources:sources,blob:br.blob,initial:initialGlobals)
        let oldPlatform = platform
        var app = A()
        let startupBatch = try app.start(instance:0x400000,show:10,initial:initial,platform:&platform,
            store:{ $0.store($1,$2) },beforeCommit:{ owner,menu,p in
                try p.complete(owner,Self.context(menu.state).globals)
            })
        func expectedStartupOperations() throws -> [OriginalApplicationStartupOperation] {
            XCTAssertEqual(parent.spec.label,"original-entry")
            let rawEvents = try XCTUnwrap(rawParent["events"] as? [[String:Any]])
            var result: [OriginalApplicationStartupOperation] = [],wave = -1,joy = 0,names = 0
            for (i,e) in parent.events.enumerated() {
                switch e.kind {
                case "timeGetTime":result.append(.milliseconds(try XCTUnwrap(e.result)))
                case "initializeCriticalSection":result.append(.criticalSection(try XCTUnwrap(e.arguments?.first),parent.spec.criticalSection))
                case "coInitialize":result.append(.initializeCOM(try XCTUnwrap(e.result)))
                case "window":
                    let q = try XCTUnwrap(e.event?.request),response = try XCTUnwrap(e.event?.response)
                    result.append(.window(try request(q),response))
                case "panelCaller":
                    if e.event?.kind == "call" && e.event?.arguments == [0x43c4a0] { result.append(.file("data\\adinfo.txt",parent.spec.panel.info)) }
                case "panel-content":
                    let p = try JSONDecoder().decode(Parent.PanelEvent.self,from:JSONSerialization.data(withJSONObject:XCTUnwrap(rawEvents[i]["event"])))
                    if p.kind == "open" {
                        result.append(.file(String(decoding:try XCTUnwrap(p.strings?.first),as:UTF8.self),parent.spec.panel.content))
                    }
                case "panel-defaults":
                    let p = try JSONDecoder().decode(Parent.PanelEvent.self,from:JSONSerialization.data(withJSONObject:XCTUnwrap(rawEvents[i]["event"])))
                    if p.kind == "writeFile" { result.append(.panelWrite(try XCTUnwrap(p.strings?.first),Int32(bitPattern:try XCTUnwrap(p.result)))) }
                    else if p.kind == "closeFile" { result.append(.panelClose(Int32(bitPattern:try XCTUnwrap(p.result)))) }
                case "filetime":result.append(.filetime(try XCTUnwrap(e.value)))
                case "allocate":
                    let pointer = try XCTUnwrap(e.address),allocation = try XCTUnwrap(parent.after.allocations.first { $0.address == pointer })
                    result.append(.calendarAllocation(try XCTUnwrap(e.count),pointer,try br.blob(XCTUnwrap(allocation.backing))))
                case "timezone":result.append(.timezone(try XCTUnwrap(e.result),parent.spec.zone))
                case "nameConversion":
                    result.append(.zoneName(names == 0 ? parent.spec.zone.standardName : parent.spec.zone.daylightName,try XCTUnwrap(e.capacity),try XCTUnwrap(e.bytes)));names += 1
                case "music":
                    let m = try XCTUnwrap(e.music)
                    if m.kind != .helper && m.kind != .format { result.append(.music(.init(m.kind,m.arguments,m.strings),m.response)) }
                case "loadCursor","setCursor":result.append(.cursor(e.kind == "loadCursor",try XCTUnwrap(e.arguments),try XCTUnwrap(e.result)))
                case "input":
                    let q = try XCTUnwrap(e.event?.event),input = try XCTUnwrap(parent.input)
                    if q.kind == "load" {
                        wave += 1;let load = input.loads[wave]
                        if load.input.device != 0 && load.input.stream != 0 { result.append(.file(String(decoding:load.path,as:UTF8.self),try br.blob(load.file))) }
                    } else if let w = q.wave {
                        result.append(.wave(w,input.loads[wave].input))
                    } else if ["deviceCreate","cooperativeLevel","message"].contains(q.kind) {
                        result.append(.sound(q,parent.spec.input.device))
                    } else {
                        let reply = input.joyRequests[joy];joy += 1;result.append(.joystick(reply.request,reply.response))
                    }
                case "panel-info","dateFormat":break
                default:XCTFail("Unclassified startup boundary "+e.kind);throw B.Stop.late
                }
            }
            return result
        }
        let operationEncoder = JSONEncoder();operationEncoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try operationEncoder.encode(startupBatch.operations),try operationEncoder.encode(expectedStartupOperations()))
        XCTAssertTrue(oldPlatform !== platform);XCTAssertEqual(oldPlatform.index,0)
        XCTAssertEqual(oldPlatform.shadow,initialGlobals);XCTAssertEqual(oldPlatform.waves,0)
        let startup = try XCTUnwrap(app.startup)
        XCTAssertEqual(startup.input?.sounds.loads.count,5)
        let firstWrapper = (startup.panel.panel.records.map(\.address).max() ?? 0x2800e020)+0x2000
        let p = try Loop.Adapter(lc,Self.context(XCTUnwrap(app.session).state),blob:br.blob)
        var entry: Entry.Stage?,bitmap: B.Adapter?,prefix: F.Adapter?,middle: Body.Adapter?,menu: M.Adapter?
        var graphics = B.Graphics(),frontBitmaps: [UInt32:OriginalLoadedBitmap] = [:]
        var rawSurfaces: [UInt32:UInt32] = [:],background = OriginalFrontScreenPrelude()
        var delivered: [Session.Effect] = [],settingEvents = 0,settingCounts: [String:Int] = [:]
        var bodyCalls = 0,menuReached = false,committed = false,callbackCount = 0
        var liveFull = initial
        let observationBase = try Self.context(XCTUnwrap(app.session).state)
        func state(_ record: OriginalStateRecord) throws -> Loop.Context {
            // Observation-only view. These bytes never initialize Core state.
            var value = observationBase
            value.globals = try .init(bytes:Array(record.bytes[..<0xb440]),defined:Array(record.defined[..<0xb440]))
            return value
        }
        var nextWrapper = firstWrapper
        let frontAllocations = (0..<24).map { n -> OriginalInterfaceAllocation in
            if bc.spec.nulls?.contains(n) == true { return .init(address:0,backing:[]) }
            defer { nextWrapper += 0x2000 }
            return .init(address:nextWrapper,backing:[UInt8](repeating:0xa5,count:0x1f50))
        }
        let backgroundToken: UInt32 = fc.spec.null == true ? 0 : nextWrapper
        let input = A.MenuInputs(settings:.init(bytes:try sr.blob(sc.input),file:sc.spec.present == false ? 0 : 0x20001000,
            scratchAddress:sr.c.scratchAddress,closeResult:sc.spec.close ?? 0),
            prefix:.init(drawTarget:0,milliseconds:fc.spec.milliseconds ?? 123456900,threadHandle:fc.spec.thread ?? 0x50010000,
                threadID:0xabcd,lastError:5,fillResult:fc.spec.fillResult ?? 0,drawResults:[fc.spec.drawResult ?? 0]),
            body:.init(dcResult:bodyCase?.spec.dcResult ?? 0,dc:bodyCase?.spec.dc ?? 0x12345678,
                methodResult:bodyCase?.spec.methodResult ?? 0,drawResults:bodyCase?.spec.drawResults ?? [0],shellResult:bodyCase?.spec.shellResult ?? 0),
            frontAllocations:frontAllocations,
            backgroundAllocation:.init(address:backgroundToken,backing:backgroundToken == 0 ? [] : [UInt8](repeating:0xa5,count:0x1f50)),
            frontResponses:bc.events.compactMap(\.response),backgroundResponses:fc.events.compactMap(\.response))
        // Independent projection of the immutable source request streams. Core
        // events and Core classifiers are not used to construct expected effects.
        func request(_ q: OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Request {
            let structure: OriginalStateRecord?
            if let mask = q.defined,let bytes = q.bytes {
                structure = try .init(bytes:zip(bytes,mask).map { $0.1 ? $0.0 : 0 },defined:mask)
            } else { structure = nil }
            return .init(q.kind,q.words,strings:q.strings,structure:structure)
        }
        func frontEffects(_ records: [F.Event],stage: A.Stage) throws -> [Session.Effect] {
            var expected: [Session.Effect] = []
            for row in records {
                if let q = row.request,let response = row.response { expected.append(.bitmap(try request(q),response));continue }
                let e = try XCTUnwrap(row.event)
                switch e.kind {
                case "blit":expected.append(.blit(try XCTUnwrap(e.blit),result:stage == .prefix ? fc.spec.drawResult ?? 0 : stage == .body ? bodyCase?.spec.drawResults.first ?? 0 : c.spec.drawResult))
                case "fill":
                    let f = try XCTUnwrap(e.fill)
                    let raw: [String:Any] = ["target":f.target,"rectangle":f.rectangle,"flags":f.flags,"effects":zip(f.effects,f.defined).map { $0.1 ? $0.0 : 0 },"defined":f.defined]
                    let normalized = try JSONDecoder().decode(OriginalSurfaceFillRequest.self,from:JSONSerialization.data(withJSONObject:raw))
                    expected.append(.fill(normalized,result:fc.spec.fillResult ?? 0))
                case "allocate":expected.append(.allocate(fc.allocation.address,try fc.allocation.backing.map(front.blob) ?? []))
                case "timer","createThread","lastError","enter","leave":expected.append(.startupFront(e))
                case "getDC":expected.append(.getDC(e,result:try XCTUnwrap(bodyCase).spec.dcResult,output:try XCTUnwrap(bodyCase).spec.dc))
                case "setBackgroundMode","setTextColor","textOut","releaseDC":expected.append(.startupGraphics(e,result:try XCTUnwrap(bodyCase).spec.methodResult))
                case "method":expected.append(.present(e,result:c.spec.presentResult))
                case "write","writeLocal","read","clip","draw","text","stringLength","format","construct","panel":break
                case "time":break // The loop clock is an input, with no terminal effect.
                case "sleep":expected.append(.sleep(try XCTUnwrap(e.arguments.first)))
                default:XCTFail("Unclassified bootstrap source effect "+e.kind);throw B.Stop.late
                }
            }
            return expected
        }
        func expectedEffects(_ step: Loop.Iteration) throws -> [Session.Effect] {
            var expected: [Session.Effect] = []
            for e in lc.events[step.before.events..<step.after.events] {
                let q = e.request
                if q.kind == "translate" {
                    let msg = try q.message.map { try OriginalStateRecord(bytes:$0,defined:XCTUnwrap(q.defined)) }
                    expected.append(.translate(.init(.translate,q.arguments,message:msg)))
                } else if q.kind == "sleep" { expected.append(.sleep(try XCTUnwrap(q.arguments.first))) }
                else if q.kind == "invalidate" { expected.append(.lifecycle(.init(q.kind,q.arguments),.init(result:try XCTUnwrap(e.response).result))) }
            }
            guard step.end == "requiredDispatcher" else { return expected }
            for e in er.c.cases[bc.spec.windowParam == 1 ? 1 : 0].events {
                if let surface = e.event { expected.append(.surface(try request(surface.request),surface.response)) }
            }
            for e in bc.events {
                if e.kind == "allocate" {
                    let allocation = bc.allocations[try XCTUnwrap(e.index)]
                    expected.append(.allocate(allocation.address,try allocation.backing.map(br.blob) ?? []))
                } else { expected.append(.bitmap(try request(XCTUnwrap(e.request)),try XCTUnwrap(e.response))) }
            }
            for e in sc.events where e.kind == "open" || e.kind == "close" {
                var event = OriginalSettingsEvent(try XCTUnwrap(OriginalSettingsEvent.Kind(rawValue:e.kind)),e.arguments ?? [])
                event.strings = e.strings ?? [];event.format = e.format;event.before = e.before;event.position = e.position
                event.eof = e.eof;event.result = e.result;expected.append(.settings(event))
            }
            expected += try frontEffects(fc.events,stage:.prefix)
            if let bodyCase { expected += try frontEffects(bodyCase.events,stage:.body) }
            expected += try frontEffects(c.events,stage:.menu)
            return expected
        }
        func compareMenuEnd(_ loop: Session.Loop,_ owned: Session.State) throws {
            let a = try XCTUnwrap(menu)
            XCTAssertEqual(a.index,c.events.count);XCTAssertEqual(a.mask,try r.blob(c.after.mask))
            XCTAssertEqual(a.shadow,try r.blob(c.after.globals));XCTAssertEqual(owned.full.bytes,a.shadow)
            XCTAssertEqual(loop.counter,c.after.counter);XCTAssertEqual(loop.timer.baseline,c.after.baseline)
            XCTAssertEqual(owned.libraryText.retainedDC,c.after.retainedDC)
            XCTAssertEqual(c.after.pc,0x43d110);XCTAssertEqual(c.after.sp,0x1000effc)
            XCTAssertEqual(c.after.cw,0x37f);XCTAssertEqual(c.after.seh,UInt32.max)
            XCTAssertTrue(owned.full.defined.allSatisfy { $0 })
            XCTAssertEqual(owned.random,startup.random)
            XCTAssertEqual(owned.memory.allocations.count,c.records.count)
            for record in c.records {
                let actual = try XCTUnwrap(owned.memory.allocations[record.address])
                XCTAssertTrue(actual.live)
                XCTAssertEqual(actual.storage.bytes,try r.blob(record.bytes))
                XCTAssertEqual(actual.storage.defined,try r.blob(record.mask).map { $0 != 0 })
            }
        }
        for (iteration,step) in lc.iterations.enumerated() {
            p.stepIndex = iteration
            let before = try XCTUnwrap(app.session),priorDelivered = delivered
            try p.snapshot(Self.context(before.state),before.loop,step.before)
            let events = Array(lc.events[step.before.events..<step.after.events])
            let loopKinds: Set<String> = ["peek","get","translate","dispatchMessage","time","sleep"]
            var queueResponses = try events.filter { loopKinds.contains($0.request.kind) }.map { try XCTUnwrap($0.response) }
            if step.end == "requiredDispatcher" { queueResponses.append(.init(result:Int32(bitPattern:c.spec.time))) }
            let windowResponses = try events.filter { $0.request.kind == "windowDefault" }.map { try XCTUnwrap($0.response).result }
            let lifecycleResponses = try events.filter { !loopKinds.contains($0.request.kind) && !["windowDefault","gameDispatch"].contains($0.request.kind) }.map { OriginalWindowInitialization.Response(result:try XCTUnwrap($0.response).result) }
            let surfaceResponses = step.end == "requiredDispatcher" ? er.c.cases[bc.spec.windowParam == 1 ? 1 : 0].events.compactMap { $0.event?.response } : []
            do {
                let outcome = try app.step(inputs:input,responses:.init(draw:c.spec.drawResult,presentation:c.spec.presentResult,
                    sound:0,release:0,dcResult:bodyCase?.spec.dcResult ?? 0,dc:bodyCase?.spec.dc ?? 0x12345678),
                    queue:queueResponses,windowDefault:windowResponses,surface:surfaceResponses,lifecycle:lifecycleResponses,
                    observe:{ observation in
                        switch observation {
                        case let .allocateFront(n,allocation):
                            if bitmap == nil {
                                let e = try XCTUnwrap(entry);try e.required();try e.complete()
                                bitmap = B.Adapter(bc,br,initial:e.shadow,nextWrapper:firstWrapper)
                            }
                            let expected = try XCTUnwrap(bitmap).allocate(n)
                            XCTAssertEqual(allocation.address,expected.address);XCTAssertEqual(allocation.backing,expected.backing)
                        case let .allocateBackground(allocation):
                            XCTAssertEqual(allocation.address,fc.allocation.address)
                            if let h = fc.allocation.backing { XCTAssertEqual(allocation.backing,try front.blob(h)) }
                        case let .bitmap(stage,q,response):
                            let expected = try stage == .resources ? XCTUnwrap(bitmap).perform(q,&graphics) : XCTUnwrap(prefix).perform(q,&graphics)
                            XCTAssertEqual(response,expected)
                        case let .queueResponse(q,response):
                            if p.index < lc.events.count {
                                let e = try p.next(q.kind.rawValue,q.arguments,state(liveFull),message:q.message,defined:q.defined)
                                XCTAssertEqual(response,try XCTUnwrap(e.response))
                            } else {
                                let a = try XCTUnwrap(menu)
                                if q.kind == .time { try a.observe(.init("time",[c.spec.time]));XCTAssertEqual(response.result,Int32(bitPattern:c.spec.time)) }
                                else if q.kind == .sleep { try a.observe(.init("sleep",q.arguments)) }
                                else { throw B.Stop.late }
                            }
                        case let .windowResponse(q,response):
                            let e = try p.next(q.kind.rawValue,q.arguments,state(liveFull));XCTAssertEqual(response,try XCTUnwrap(e.response).result)
                        case let .surfaceResponse(q,response):XCTAssertEqual(response,try XCTUnwrap(entry).surface(q,liveFull))
                        case let .lifecycleResponse(q,response):
                            let e = try p.next(q.kind,q.words,state(liveFull));XCTAssertEqual(response.result,try XCTUnwrap(e.response).result)
                        case let .loopRequest(_,full):liveFull = full
                        case let .dispatchSurface(full):liveFull = full
                        case let .callback(result,full):
                            let saved = lc.callbacks[callbackCount];callbackCount += 1;p.callbackIndex += 1
                            XCTAssertEqual(UInt32(bitPattern:result),saved.result)
                            XCTAssertEqual(Array(full.bytes[..<0xb440]),try br.blob(saved.globals))
                            XCTAssertEqual(p.outerShadow,try br.blob(saved.outer))
                        case let .resource(e):
                            if e.kind == .write {
                                let address = Int(e.arguments[0]+e.arguments[1]),value = e.arguments[3]
                                let bytes = (0..<Int(e.arguments[2])).map { UInt8(truncatingIfNeeded:value >> ($0*8)) }
                                if let bitmap { bitmap.store(address,bytes) } else { try XCTUnwrap(entry).store(address,bytes) }
                            }
                        case let .resources(result,full,resources,surfaces):
                            try XCTUnwrap(bitmap).complete(graphics,resources)
                            XCTAssertEqual(result.continuation.rawValue,bc.end);XCTAssertEqual(full.bytes,try br.blob(bc.after.globals))
                            frontBitmaps = resources.bitmaps;rawSurfaces = surfaces
                        case let .settings(e,g,s):
                            let expected = sc.events[settingEvents];settingEvents += 1
                            XCTAssertEqual(e.kind.rawValue,expected.kind);XCTAssertEqual(e.arguments,expected.arguments ?? [])
                            XCTAssertEqual(e.strings,expected.strings ?? []);XCTAssertEqual(e.format,expected.format)
                            XCTAssertEqual(e.before,expected.before);XCTAssertEqual(e.position,expected.position)
                            XCTAssertEqual(e.eof,expected.eof);XCTAssertEqual(e.result,expected.result)
                            if let saved = expected.state { try sr.compare(saved,g,s) }
                            settingCounts[e.kind.rawValue,default:0] += 1
                            if fail == "settings:"+e.kind.rawValue+"#"+String(settingCounts[e.kind.rawValue]!) { throw B.Stop.late }
                        case let .settingsReturn(output,full):
                            XCTAssertEqual(settingEvents,sc.events.count);XCTAssertEqual(output.continuation.rawValue,sc.end)
                            try sr.compare(sc.after,state(full).globals,output.scratch)
                            XCTAssertEqual(full.bytes,try sr.blob(sc.after.globals));XCTAssertEqual(output.target,sc.after.registers[3])
                        case let .front(stage,e):
                            switch stage {
                            case .resources:
                                guard e.kind == "write" else { throw B.Stop.late }
                                let value = e.arguments[2]
                                try XCTUnwrap(entry).store(Int(e.arguments[0]),(0..<Int(e.arguments[1])).map { UInt8(truncatingIfNeeded:value >> ($0*8)) })
                            case .prefix:try XCTUnwrap(prefix).observe(e)
                            case .body:try XCTUnwrap(middle).observe(e)
                            default:throw B.Stop.late
                            }
                        case let .prefixReturn(end,full,screen):
                            background = screen;XCTAssertEqual(end.rawValue,fc.end)
                            var all = frontBitmaps;for (p,b) in screen.bitmaps { XCTAssertNil(all.updateValue(b,forKey:p)) }
                            try XCTUnwrap(prefix).complete(graphics,all)
                            XCTAssertEqual(full.bytes,try front.blob(fc.after.globals));XCTAssertEqual(screen.retainedOperation,.sleep)
                        case let .panelReturn(full):
                            XCTAssertEqual(full.bytes,try body.blob(XCTUnwrap(bodyCase).panelReturn.globals))
                        case let .bodyReturn(output,full,library):
                            let expected = try XCTUnwrap(bodyCase),a = try XCTUnwrap(middle)
                            XCTAssertEqual(a.index,expected.events.count);XCTAssertEqual(output.continuation.rawValue,expected.end)
                            XCTAssertEqual(full.bytes,try body.blob(expected.after.globals));XCTAssertEqual(library.retainedDC,expected.after.retainedDC)
                            let local = try body.blob(expected.after.local),mask = try body.blob(expected.after.localMask)
                            for i in 0..<0xc0 {
                                let defined = mask[i] != 0 || (0x20..<0x24).contains(i)
                                XCTAssertEqual(output.local.defined[i],defined);XCTAssertEqual(output.local.bytes[i],defined ? local[i] : 0)
                            }
                            XCTAssertEqual(output.retainedSelector,0);bodyCalls += 1
                        }
                    },menuObserve:{ e in
                        if let menu { try menu.observe(e) }
                        else {
                            guard e.kind == "write" else { throw B.Stop.late }
                            let value = e.arguments[2]
                            p.store(Int(e.arguments[0]),(0..<Int(e.arguments[1])).map { UInt8(truncatingIfNeeded:value >> ($0*8)) })
                        }
                    },checkpoint:{ point,full,result in
                        liveFull = full
                        switch point {
                        case .dispatch:
                            let target = try full.integer(at:0x4dac,as:UInt32.self)
                            XCTAssertNil(try p.next("gameDispatch",[target],state(full)).response)
                            entry = Entry.Stage(er.c.cases[bc.spec.windowParam == 1 ? 1 : 0],er,full.bytes,fail:nil)
                        case .world:break
                        case .prefix:prefix = F.Adapter(fc,front,initial:full.bytes,fail:fail?.hasPrefix("prefix:") == true ? String(fail!.dropFirst(7)) : nil)
                        case .panel:middle = Body.Adapter(try XCTUnwrap(bodyCase),body,initial:full.bytes,fail:fail?.hasPrefix("body:") == true ? String(fail!.dropFirst(5)) : nil)
                        case .body:break
                        case .alternate:
                            XCTAssertEqual(full.bytes,try r.blob(c.before.globals))
                            menu = M.Adapter(c,r,initial:full.bytes,fail:fail);menuReached = true
                        case .main:XCTAssertEqual(full.bytes,try r.blob(XCTUnwrap(c.mainEntry).globals))
                        case .tail:XCTAssertEqual(full.bytes,try r.blob(XCTUnwrap(c.tailEntry).globals))
                        case .worldReturn:
                            let expected = try XCTUnwrap(c.worldReturn)
                            XCTAssertEqual(full.bytes,try r.blob(expected.globals))
                            XCTAssertEqual(UInt32(bitPattern:try XCTUnwrap(result)),expected.eax)
                            XCTAssertEqual(expected.pc,0x43ecbf);XCTAssertEqual(expected.sp,0x1000eea0)
                        case .dispatchReturn:
                            XCTAssertEqual(full.bytes,try r.blob(XCTUnwrap(c.dispatchReturn).globals))
                            XCTAssertEqual(UInt32(bitPattern:try XCTUnwrap(result)),c.dispatchReturn?.eax)
                            if fail == "dispatchReturn" { throw B.Stop.late }
                        }
                    },beforeCommit:{ loop,owned in
                        if step.end == "requiredDispatcher" {
                            try compareMenuEnd(loop,owned)
                            if fail == "commit" { throw B.Stop.late }
                        }
                    })
                guard case .committed(let batch) = outcome else { XCTFail("Bootstrap unexpectedly reached loading");throw B.Stop.late }
                XCTAssertEqual(batch.effects,try expectedEffects(step))
                delivered += batch.effects
                let own = try XCTUnwrap(app.session)
                try Self.sameStartup(XCTUnwrap(app.startup),startup)
                if step.end == "requiredDispatcher" {
                    try compareMenuEnd(own.loop,own.state);committed = true
                    var context = B.OwnContext(base:try Self.context(own.state))
                    context = try context.receivingMenuState(own.state)
                    context.graphics = graphics;context.settings = own.state.settings
                    context.frontSurfaces = rawSurfaces;context.dispatchResult = 1;context.bootstrap = app
                    try continuation?(own.loop,context)
                } else { try p.snapshot(Self.context(own.state),own.loop,step.after) }
            } catch {
                if fail == nil {
                    XCTAssertEqual(c.end,"nullBitmap")
                    XCTAssertEqual(error as? Session.Boundary,.bitmapOwnership(0))
                    let a = try XCTUnwrap(menu)
                    XCTAssertEqual(a.index,c.events.count);XCTAssertEqual(a.mask,try r.blob(c.after.mask))
                    XCTAssertEqual(a.shadow,try r.blob(c.after.globals))
                } else { guard case B.Stop.late = error else { throw error } }
                Self.same(try XCTUnwrap(app.session),before);XCTAssertEqual(delivered,priorDelivered)
                try Self.sameStartup(XCTUnwrap(app.startup),startup)
            }
        }
        XCTAssertEqual(p.index,lc.events.count);p.compareStores();XCTAssertEqual(callbackCount,1)
        XCTAssertEqual(committed,fail == nil && c.end == "iteration")
        if fail == nil { XCTAssertTrue(menuReached);XCTAssertEqual(bodyCalls,bodyCase == nil ? 0 : 1) }
        _ = background
    }

    func testLateFirstMenuFailuresRetainStartupAndResize() throws {
        let f = try F.Resources(),b = try Body.Resources(f),r = try M.Resources(b,f),br = try B.Resources(),er = try Entry.Resources()
        for failure in ["settings:scan#47","settings:gets#3","settings:eof#2","settings:close#1","settings:settingsReturn#1",
            "prefix:fill","prefix:format","prefix:createSurface#1","prefix:deleteObject#1","prefix:backgroundStore","prefix:blit",
            "body:enter#1","body:leave#1","body:writeLocal#50","body:setBackgroundMode#2","body:releaseDC#3","body:blit#2"] {
            try runMenu(0,r,b,f,br,er,fail:failure)
        }
    }

    func testStartupAttemptOwnsReplyCursorAndPublishesOnlyAtCommit() throws {
        let br = try B.Resources(),bc = br.c.cases[61],parents = try XCTUnwrap(bc.parents),c = parents.parent
        let raw = try XCTUnwrap((br.rawCases[61]["parents"] as? [String:Any])?["parent"] as? [String:Any])
        let sources = Dictionary(uniqueKeysWithValues:try XCTUnwrap(c.input).loads.map { (String(decoding:$0.path,as:UTF8.self),$0.file) })
        let bytes = try br.blob(c.initialGlobals)+br.blob(parents.loop.initialOuter)+[UInt8](repeating:0,count:0xc3a8-0xb440-0x854)
        let initial = try OriginalStateRecord(bytes:bytes,defined:[Bool](repeating:true,count:bytes.count))
        for phase in ["window-return","panel-return","secondDate","output-return","fifthWave","after"] {
            var app = A(),p = try Parent.Adapter(c,raw,sources:sources,blob:br.blob,initial:Array(bytes[..<0xb440]),fail:phase)
            let original = p;var attempted: Parent.Adapter?,published: A.Started?
            do {
                published = try app.start(instance:0x400000,show:10,initial:initial,platform:&p,store:{ $0.store($1,$2) },
                    beforeCommit:{ _,_,_ in if phase == "after" { throw Parent.Trial.late } },failedAttempt:{ attempted = $0;_ = $1 })
                XCTFail("Missing late startup error")
            } catch Parent.Trial.late { }
            XCTAssertNil(published);XCTAssertNil(app.startup);XCTAssertNil(app.session)
            XCTAssertTrue(p === original);XCTAssertTrue(try XCTUnwrap(attempted) !== original)
            XCTAssertGreaterThan(try XCTUnwrap(attempted).index,0)
            XCTAssertEqual(p.index,0);XCTAssertEqual(p.storeIndex,0);XCTAssertEqual(p.stageIndex,0)
            XCTAssertEqual(p.calendarIndex,0);XCTAssertEqual(p.joyIndex,0);XCTAssertEqual(p.capsIndex,0)
            XCTAssertEqual(p.waves,0);XCTAssertEqual(p.childIndex,-1);XCTAssertEqual(p.writes,0)
            XCTAssertEqual(p.shadow,Array(bytes[..<0xb440]));XCTAssertEqual(p.expected,p.shadow)
            XCTAssertEqual(p.mask,[UInt8](repeating:0,count:0xb440))
        }
    }
}
