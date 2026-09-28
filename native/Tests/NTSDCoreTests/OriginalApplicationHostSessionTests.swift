import Foundation
import XCTest
import NTSDCore

final class OriginalApplicationHostSessionTests: XCTestCase {
    typealias Parent = OriginalWinMainStartupTests
    typealias Bootstrap = OriginalApplicationBootstrapTests
    typealias A = OriginalApplicationBootstrap
    typealias S = OriginalApplicationMenuSession
    typealias Host = OriginalApplicationHostSession<Parent.Adapter>
    enum Stop: Error { case injected }

    /// Optional transport through the production owner. Source expectations and
    /// all whole-parent comparators remain in their original test composers.
    final class Application {
        let useHost: Bool, controls: Bool
        private var original = A()
        private(set) var host: Host?
        init(useHost: Bool, controls: Bool = false) { self.useHost = useHost; self.controls = controls }
        var core: A { host?.snapshot ?? original }
        var session: S? { core.session }
        var startup: OriginalWinMainStartup? { core.startup }
        func start(instance: UInt32, show: Int32, initial: OriginalStateRecord,
            platform: inout Parent.Adapter,
            store: (Parent.Adapter, Int, [UInt8]) throws -> Void = { _,_,_ in },
            beforeCommit: (OriginalWinMainStartup, S, Parent.Adapter) throws -> Void = { _,_,_ in },
            failedAttempt: (Parent.Adapter, Error) -> Void = { _,_ in }) throws -> A.Started {
            guard useHost else {
                return try original.start(instance:instance,show:show,initial:initial,platform:&platform,
                    store:store,beforeCommit:beforeCommit,failedAttempt:failedAttempt)
            }
            if host == nil { host = try Host(platform:platform) }
            let driver = try XCTUnwrap(host)
            if controls {
                XCTAssertThrowsError(try driver.start(instance:instance,show:show,initial:initial,store:store,
                    beforeCommit:{ _,_,_ in throw Stop.injected })) { XCTAssertTrue($0 is Stop) }
                XCTAssertNil(driver.snapshot.startup); XCTAssertNil(driver.snapshot.session)
                XCTAssertEqual(driver.pendingBatchCount,0); XCTAssertNil(try driver.takeCommitted())
                let snapshot = try driver.platformSnapshot()
                XCTAssertEqual(snapshot.index,0); XCTAssertEqual(snapshot.waves,0)
                // Caller and inspection copies cannot mutate the retained owner.
                snapshot.hostReservations.append(-1)
                XCTAssertTrue(try driver.platformSnapshot().hostReservations.isEmpty)
            }
            let sequence = try driver.start(instance:instance,show:show,initial:initial,store:store,
                beforeCommit:{ owner,session,p in
                    try self.reentry(driver)
                    try beforeCommit(owner,session,p)
                },failedAttempt:failedAttempt)
            let batch = try XCTUnwrap(driver.takeCommitted())
            XCTAssertEqual(batch.sequence,sequence); XCTAssertEqual(sequence,1)
            XCTAssertNil(try driver.takeCommitted())
            guard case .startup(let started) = batch.contents else { throw Stop.injected }
            platform = try driver.platformSnapshot()
            return started
        }
        private func reentry(_ driver: Host) throws {
            XCTAssertThrowsError(try driver.takeCommitted()) { XCTAssertEqual($0 as? Host.Boundary,.reentrantAttempt) }
            XCTAssertThrowsError(try driver.step(prepare:{ _,_ in XCTFail("Reentrant preparation ran"); throw Stop.injected })) {
                XCTAssertEqual($0 as? Host.Boundary,.reentrantAttempt)
            }
        }
        func step(inputs: A.MenuInputs? = nil, responses: S.Responses,
            queue: [S.Loop.Response], windowDefault: [Int32],
            surface: [OriginalWindowInitialization.Response], lifecycle: [OriginalWindowInitialization.Response],
            observe: @escaping (A.Observation) throws -> Void = { _ in },
            menuObserve: @escaping (OriginalFrontScreenEvent) throws -> Void = { _ in },
            graphicsObserve: @escaping (OriginalApplicationGraphics.Command) throws -> Void = { _ in },
            checkpoint: (S.Checkpoint, OriginalStateRecord, Int32?) throws -> Void = { _,_,_ in },
            bodyProduced: (OriginalFrontScreenBody.StartupResult) throws -> Void = { _ in },
            beforeCommit: (S.Loop, S.State) throws -> Void = { _,_ in }) throws -> S.Outcome {
            guard let driver = host else {
                return try original.step(inputs:inputs,responses:responses,queue:queue,windowDefault:windowDefault,
                    surface:surface,lifecycle:lifecycle,observe:observe,menuObserve:menuObserve,
                    graphicsObserve:graphicsObserve,checkpoint:checkpoint,bodyProduced:bodyProduced,beforeCommit:beforeCommit)
            }
            let old = try XCTUnwrap(driver.snapshot.session), platform = try driver.platformSnapshot()
            let oldBatches = driver.pendingBatchCount
            func prepare(_ p: Parent.Adapter,_ state: S.State) throws -> Host.Inputs {
                XCTAssertEqual(state.full,old.state.full)
                p.hostQueuePosition += queue.count
                p.hostReservations.append(p.hostQueuePosition)
                return .init(initialization:inputs,responses:responses,queue:queue,windowDefault:windowDefault,
                    surface:surface,lifecycle:lifecycle)
            }
            func unchanged() throws {
                Bootstrap.same(try XCTUnwrap(driver.snapshot.session),old)
                let after = try driver.platformSnapshot()
                XCTAssertEqual(after.hostQueuePosition,platform.hostQueuePosition)
                XCTAssertEqual(after.hostReservations,platform.hostReservations)
                XCTAssertEqual(driver.pendingBatchCount,oldBatches)
            }
            if controls {
                // Same immutable packet and actual Core state. No diagnostic
                // comparator cursor is consumed by this failed first attempt.
                XCTAssertThrowsError(try driver.step(prepare:prepare,beforeCommit:{ _,_ in throw Stop.injected })) {
                    XCTAssertTrue($0 is Stop)
                }
                try unchanged()
            }
            do {
                let outcome = try driver.step(prepare:prepare,observe:observe,menuObserve:menuObserve,
                    graphicsObserve:graphicsObserve,checkpoint:checkpoint,bodyProduced:bodyProduced,
                    beforeCommit:{ timer,state in try self.reentry(driver); try beforeCommit(timer,state) })
                switch outcome {
                case .committed(let sequence,let result):
                    let batch = try XCTUnwrap(driver.takeCommitted())
                    XCTAssertEqual(batch.sequence,sequence); XCTAssertNil(try driver.takeCommitted())
                    guard case .iteration(let committed) = batch.contents else { throw Stop.injected }
                    XCTAssertEqual(committed.result,result)
                    let after = try driver.platformSnapshot()
                    XCTAssertEqual(after.hostQueuePosition,platform.hostQueuePosition+queue.count)
                    XCTAssertEqual(after.hostReservations,platform.hostReservations+[after.hostQueuePosition])
                    return .committed(committed)
                case .loading:
                    try unchanged()
                    let pending = try XCTUnwrap(driver.pendingLoading)
                    let staged = try XCTUnwrap(driver.pendingPlatformSnapshot())
                    XCTAssertEqual(staged.hostQueuePosition,platform.hostQueuePosition+queue.count)
                    XCTAssertEqual(staged.hostReservations,platform.hostReservations+[staged.hostQueuePosition])
                    XCTAssertThrowsError(try driver.step(prepare:{ _,_ in XCTFail("Pending prefix repeated"); throw Stop.injected })) {
                        XCTAssertEqual($0 as? Host.Boundary,.pendingLoading)
                    }
                    XCTAssertEqual(driver.pendingLoading?.state.full,pending.state.full)
                    XCTAssertNil(try driver.takeCommitted())
                    return .loading(pending)
                }
            } catch { try unchanged(); throw error }
        }
    }

    func testWholeFirstMenuParentsUseHostCommitHandoff() throws {
        let f = try Bootstrap.F.Resources(),b = try Bootstrap.Body.Resources(f)
        let r = try Bootstrap.M.Resources(b,f),br = try Bootstrap.B.Resources(),er = try Bootstrap.Entry.Resources()
        for index in r.c.cases.indices { try Bootstrap().runMenu(index,r,b,f,br,er,useHost:true) }
    }
    func testFirstMenuLateFailuresRetainEarlierHostCommits() throws {
        let f = try Bootstrap.F.Resources(),b = try Bootstrap.Body.Resources(f)
        let r = try Bootstrap.M.Resources(b,f),br = try Bootstrap.B.Resources(),er = try Bootstrap.Entry.Resources()
        for failure in ["settings:scan#47","settings:gets#3","settings:eof#2","settings:close#1","settings:settingsReturn#1",
            "prefix:fill","prefix:format","prefix:createSurface#1","prefix:deleteObject#1","prefix:backgroundStore","prefix:blit",
            "body:enter#1","body:leave#1","body:writeLocal#50","body:setBackgroundMode#2","body:releaseDC#3","body:blit#2"] {
            try Bootstrap().runMenu(0,r,b,f,br,er,fail:failure,useHost:true)
        }
    }
    func testSamePreparedAttemptsRetryWithIndependentHostState() throws {
        let f = try Bootstrap.F.Resources(),b = try Bootstrap.Body.Resources(f)
        let r = try Bootstrap.M.Resources(b,f),br = try Bootstrap.B.Resources(),er = try Bootstrap.Entry.Resources()
        try Bootstrap().runMenu(0,r,b,f,br,er,useHost:true,hostControls:true)
    }
    func testWholeInputChainsRetainActualHostLoadingTicket() throws {
        typealias Input = OriginalApplicationMenuInputTests
        let f = try Bootstrap.F.Resources(),b = try Bootstrap.Body.Resources(f),m = try Bootstrap.M.Resources(b,f)
        let r = try Input.Resources(m),br = try Bootstrap.B.Resources(),er = try Bootstrap.Entry.Resources()
        for index in r.c.cases.indices { try Input().run(index,r,m,b,f,br,er,useHost:true) }
    }
    func testStartupLateFailuresAndSharedCopyRejection() throws {
        let br = try Bootstrap.B.Resources(),c = try XCTUnwrap(br.c.cases[61].parents).parent
        let raw = try XCTUnwrap((br.rawCases[61]["parents"] as? [String:Any])?["parent"] as? [String:Any])
        let sources = Dictionary(uniqueKeysWithValues:try XCTUnwrap(c.input).loads.map { (String(decoding:$0.path,as:UTF8.self),$0.file) })
        let package = try OriginalApplicationStartupInputsTests.shared.get(),initial = package.initial
        for phase in ["window-return","panel-return","secondDate","output-return","fifthWave","after"] {
            let p = try Parent.Adapter(c,raw,sources:sources,blob:br.blob,initial:Array(initial.bytes[..<0xb440]),fail:phase,startupInputs:package)
            let driver = try Host(platform:p)
            XCTAssertThrowsError(try driver.start(instance:0x400000,show:10,initial:initial,store:{ $0.store($1,$2) },
                beforeCommit:{ _,_,_ in if phase == "after" { throw Parent.Trial.late } })) {
                XCTAssertTrue($0 is Parent.Trial)
            }
            XCTAssertNil(driver.snapshot.startup); XCTAssertNil(driver.snapshot.session)
            XCTAssertNil(try driver.takeCommitted()); XCTAssertNil(driver.pendingLoading)
            let snapshot = try driver.platformSnapshot()
            XCTAssertEqual(snapshot.index,0); XCTAssertEqual(snapshot.waves,0); XCTAssertEqual(snapshot.shadow,Array(initial.bytes[..<0xb440]))
            XCTAssertEqual(p.index,0); XCTAssertEqual(p.waves,0)
            p.hostShareCopies = true
            XCTAssertThrowsError(try Host(platform:p)) { XCTAssertEqual($0 as? Host.Boundary,.sharedPlatform) }
        }
    }
}
