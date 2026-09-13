import Foundation
import XCTest
import NTSDCore
@testable import NTSDReferenceChecks

final class OriginalApplicationLoopContinuationTests: XCTestCase {
    typealias Loop = OriginalApplicationMessageLoop
    typealias Timer = OriginalApplicationTimerTests
    enum Stop: Error { case suspended, late }
    struct Context: Equatable {
        var clock = 0,events: [Timer.Event] = [],requests: [Loop.Request.Kind] = []
        var bodyComplete = false
    }
    func same(_ a: Loop,_ b: Loop) {
        XCTAssertEqual(a.timer.baseline,b.timer.baseline)
        XCTAssertEqual(a.counter,b.counter);XCTAssertEqual(a.message,b.message)
    }
    /// All immutable timer cases retain their source request order while each
    /// due dispatcher is suspended and later returned. Source bodies remain
    /// declared replies here; these are not whole game/application executions.
    func testSuspendedTailAgainstAllSavedTimerDecisions() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource:"original-application-timer",withExtension:"json",subdirectory:"Fixtures"))
        let corpus = try JSONDecoder().decode(Timer.Corpus.self,from:MatchPreparationReference.unpack(Data(contentsOf:url),maximumCount:2_000_000))
        XCTAssertEqual(corpus.exeSHA256,"3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c")
        var suspended = 0,notDue = 0,totalEvents = 0
        for c in corpus.cases {
            var loop = try Loop(baseline:c.baselineBefore,counter:60),context = Context()
            let old = loop,initial = context
            var pending: Loop.PendingDispatch?,saved: Context?,writes: [UInt32] = [],targets = 0,speeds = 0
            func perform(_ r: Loop.Request,_ state: inout Context) throws -> Loop.Response {
                state.requests.append(r.kind)
                switch r.kind {
                case .peek:return .init(result:0,writes:[.init(offset:1,bytes:[3,5,7])])
                case .time:
                    guard state.clock < c.clockResponses.count else { throw Stop.late }
                    let value = c.clockResponses[state.clock];state.clock += 1
                    state.events.append(.init(kind:"time",arguments:[value]));return .init(result:Int32(bitPattern:value))
                case .gameDispatch:
                    XCTAssertEqual(r.arguments,[c.target]);state.bodyComplete = true
                    state.events.append(.init(kind:"dispatch",arguments:[c.target,UInt32(bitPattern:c.dispatchResult)]))
                    return .init(result:c.dispatchResult)
                case .recoverSurface:state.events.append(.init(kind:"recoverSurface",arguments:[]));return .init()
                case .sleep:state.events.append(.init(kind:"sleep",arguments:r.arguments));return .init()
                default:throw Stop.late
                }
            }
            do {
                let result = try loop.step(context:&context,speed:{ _ in speeds += 1;return c.speed },
                    target:{ _ in targets += 1;return c.target },beforeGameDispatch:{ p,s in
                        pending = p;saved = s;throw Stop.suspended
                    },perform:perform,counterWritten:{ writes.append($0) })
                XCTAssertEqual(result,.continued)
                XCTAssertNil(pending);notDue += 1
            } catch Stop.suspended {
                same(loop,old);XCTAssertEqual(context,initial);XCTAssertTrue(writes.isEmpty)
                let p = try XCTUnwrap(pending);var stage = try XCTUnwrap(saved)
                XCTAssertEqual(p.target,c.target)
                // Execute the declared child exactly once between suspension
                // and resume. Neither the prefix nor its clocks run again.
                let response = try perform(.init(.gameDispatch,[p.target]),&stage)
                let completed = try p.resume(dispatchResult:response.result,context:&stage,perform:perform,
                    counterWritten:{ writes.append($0) },beforeCommit:{ candidate,s,result in
                        XCTAssertTrue(s.bodyComplete);XCTAssertEqual(candidate.timer.baseline,c.baselineAfter)
                        XCTAssertEqual(candidate.counter,0);XCTAssertEqual(result,.continued)
                    })
                loop = completed.loop;context = stage;suspended += 1
            }
            XCTAssertEqual(context.events,c.events,"saved source timer case \(c.index)")
            XCTAssertEqual(loop.timer.baseline,c.baselineAfter)
            XCTAssertEqual(context.clock,c.events.filter { $0.kind == "time" }.count)
            XCTAssertEqual(speeds,1);XCTAssertEqual(targets,c.events.filter { $0.kind == "dispatch" }.count)
            XCTAssertEqual(writes,[61,0]);XCTAssertEqual(loop.counter,0)
            XCTAssertEqual(context.requests.filter { $0 == .peek }.count,1)
            XCTAssertEqual(loop.message.defined,(0..<28).map { (1...3).contains($0) })
            XCTAssertEqual(Array(loop.message.bytes[1...3]),[3,5,7])
            totalEvents += context.events.count
        }
        XCTAssertEqual(corpus.cases.count,2025);XCTAssertEqual(suspended,1215);XCTAssertEqual(notDue,810);XCTAssertEqual(totalEvents,8163)
        print("Suspended loop:\(suspended) returned dispatcher continuations/\(notDue) not-due decisions;\(corpus.cases.count) saved timer cases/\(totalEvents) events; partial MSG masks and single prefix retained")
    }

    func testRetainedMessageAndEveryLateTailFailure() throws {
        var loop = try Loop(baseline:100,counter:59),state = Context()
        // Commit an earlier message. The later peek(0) overwrites only three
        // bytes; all other bytes and masks belong to this prior iteration.
        let message = (0..<28).map { UInt8($0+40) }
        _ = try loop.step(context:&state,speed:{ _ in XCTFail("Message speed read");return 1 },
            target:{ _ in XCTFail("Message target read");return 7 },perform:{ r,_ in
                .init(result:r.kind == .peek ? 1 : -1,writes:r.kind == .get ? [.init(offset:0,bytes:message)] : [])
            })
        XCTAssertEqual(loop.counter,60);XCTAssertEqual(loop.message.bytes,message)
        let old = loop,initial = state,clocks: [UInt32] = [201,201,202,164]
        var pending: Loop.PendingDispatch?,saved: Context?
        do {
            _ = try loop.step(context:&state,speed:{ _ in 1 },target:{ _ in 7 },beforeGameDispatch:{ p,s in
                pending = p;saved = s;throw Stop.suspended
            },perform:{ r,s in
                if r.kind == .peek { return .init(result:0,writes:[.init(offset:9,bytes:[1,2,3])]) }
                guard r.kind == .time else { throw Stop.late }
                let v = clocks[s.clock];s.clock += 1;return .init(result:Int32(bitPattern:v))
            })
            XCTFail("Missing suspension")
        } catch Stop.suspended {}
        same(loop,old);XCTAssertEqual(state,initial)
        let p = try XCTUnwrap(pending);var ready = try XCTUnwrap(saved);ready.bodyComplete = true
        XCTAssertEqual(ready.clock,3,"The clamp's three prefix clock reads precede suspension")
        for failure in ["recoverSurface","time","sleep","counterFirst","counterReset","final","invalidWrites",""] {
            var attempt = ready,reached = false,seen: [String] = [],writes: [UInt32] = []
            do {
                let completed = try p.resume(dispatchResult:-1,context:&attempt,perform:{ r,s in
                    seen.append(r.kind.rawValue);s.requests.append(r.kind)
                    if failure == r.kind.rawValue { reached = true;throw Stop.late }
                    if failure == "invalidWrites" { reached = true;return .init(writes:[.init(offset:0,bytes:[1])]) }
                    if r.kind == .time {
                        XCTAssertEqual(s.clock,3);s.clock += 1;return .init(result:164)
                    }
                    if r.kind == .sleep { XCTAssertEqual(r.arguments,[4]) }
                    return .init()
                },counterWritten:{ value in
                    writes.append(value)
                    if failure == (value == 61 ? "counterFirst" : "counterReset") { reached = true;throw Stop.late }
                },beforeCommit:{ candidate,context,result in
                    XCTAssertEqual(candidate.counter,0);XCTAssertEqual(candidate.timer.baseline,135)
                    XCTAssertTrue(context.bodyComplete);XCTAssertEqual(result,.continued)
                    if failure == "final" { reached = true;throw Stop.late }
                })
                XCTAssertEqual(failure,"");XCTAssertEqual(seen,["recoverSurface","time","sleep"]);XCTAssertEqual(writes,[61,0])
                var expected = message;expected.replaceSubrange(9..<12,with:[1,2,3])
                XCTAssertEqual(completed.loop.message.bytes,expected);XCTAssertTrue(completed.loop.message.defined.allSatisfy { $0 })
                XCTAssertEqual(attempt.clock,4)
            } catch {
                XCTAssertFalse(failure.isEmpty);XCTAssertTrue(reached);XCTAssertEqual(attempt,ready)
                if failure == "invalidWrites" { XCTAssertTrue(error is OriginalStateError) }
                else { XCTAssertTrue(error is Stop) }
            }
            same(loop,old);XCTAssertEqual(state,initial)
        }
    }

    func testResumedCounterUsesSignedWrapRule() throws {
        for (initial,expected,writesExpected) in [(UInt32.max,UInt32(0),[UInt32(0)]),(0x7fffffff,0x80000000,[0x80000000]),(60,0,[61,0])] {
            var loop = try Loop(baseline:100,counter:initial),context = 0,pending: Loop.PendingDispatch?
            XCTAssertThrowsError(try loop.step(context:&context,speed:{ _ in 1 },target:{ _ in 0 },
                beforeGameDispatch:{ p,_ in pending = p;throw Stop.suspended },
                perform:{ r,_ in .init(result:r.kind == .peek ? 0 : 134) }))
            var writes: [UInt32] = []
            let completed = try XCTUnwrap(pending).resume(dispatchResult:0,context:&context,
                perform:{ r,_ in XCTAssertEqual(r.kind,.time);return .init(result:200) },counterWritten:{ writes.append($0) })
            XCTAssertEqual(completed.loop.counter,expected);XCTAssertEqual(writes,writesExpected)
            XCTAssertEqual(loop.counter,initial);XCTAssertEqual(loop.timer.baseline,100)
        }
    }

    /// The saved own source stops at loading. Only the retained prefix/MSG/
    /// baseline are reference comparisons; the child result and tail clock
    /// below are explicit Native-only inputs, not an observed loaded return.
    func testOwnLoadingParentsRetainTheirActualLoopContinuation() throws {
        typealias I = OriginalApplicationMenuInputTests
        let front = try I.F.Resources(),body = try I.Body.Resources(front),menu = try I.M.Resources(body,front)
        let source = try I.Resources(menu),bitmaps = try I.B.Resources(),entries = try I.B.Entry.Resources()
        var returned = 0
        for index in 47..<50 {
            try I().run(index,source,menu,body,front,bitmaps,entries,loading:{ _,pending in
                let c = source.c.cases[index],expected = c.after
                // ESI is the World pointer by41bc90. The last actual43e9a0
                // entry checkpoint retains the outer timer before that reuse.
                let dispatch = try XCTUnwrap(c.states.last { $0.kind == "dispatch" })
                XCTAssertEqual(dispatch.state.pc,0x43e9a0);XCTAssertEqual(dispatch.eventIndex,3266)
                XCTAssertEqual(dispatch.state.baseline,123456923);XCTAssertEqual(expected.baseline,0x458b00)
                let baseline = dispatch.state.baseline
                let dispatchBytes = try source.blob(dispatch.state.globals)
                let dispatchTarget = (0..<4).reduce(UInt32(0)) { $0 | UInt32(dispatchBytes[0x4dac+$1]) << ($1*8) }
                XCTAssertEqual(pending.loopContinuation.target,dispatchTarget)
                XCTAssertEqual(expected.counter,dispatch.state.counter)
                XCTAssertEqual(try source.blob(expected.message),try source.blob(dispatch.state.message))
                XCTAssertEqual(try source.blob(expected.messageMask),try source.blob(dispatch.state.messageMask))
                var state = pending.state,requests: [Loop.Request.Kind] = []
                let before = state
                let complete = try pending.loopContinuation.resume(dispatchResult:1,context:&state,perform:{ request,_ in
                    requests.append(request.kind);XCTAssertEqual(request.kind,.time)
                    return .init(result:Int32(bitPattern:baseline &+ 1000))
                })
                XCTAssertEqual(requests,[.time]);XCTAssertEqual(complete.result,.continued)
                XCTAssertEqual(complete.loop.timer.baseline,baseline)
                let increment = expected.counter &+ 1
                XCTAssertEqual(complete.loop.counter,Int32(bitPattern:increment) > 60 ? 0 : increment)
                let mask = try source.blob(expected.messageMask),bytes = try source.blob(expected.message)
                XCTAssertEqual(complete.loop.message.defined,mask.map { $0 != 0 })
                XCTAssertTrue(mask.indices.allSatisfy { mask[$0] == 0 || complete.loop.message.bytes[$0] == bytes[$0] })
                XCTAssertEqual(state.full,before.full);XCTAssertEqual(state.memory.allocations,before.memory.allocations)
                XCTAssertEqual(state.memory.replayPointers,before.memory.replayPointers)
                XCTAssertEqual(state.random,before.random)
                returned += 1
            })
        }
        XCTAssertEqual(returned,3)
    }
}
