import Foundation
import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Passing diagnostics report an explicit outcome; they never accept source
/// equivalence for the new calls. Source comparison remains confined to parent17.
final class OriginalApplicationFirstDamageTests: XCTestCase {
    typealias D = OriginalApplicationFirstDamageDiagnostic
    typealias C = D.C
    typealias I = D.I
    typealias G = OriginalApplicationGameplaySession
    typealias Ready = OriginalApplicationInputSession.PendingContinuation
    typealias Returned = OriginalApplicationLoadedMenuSession.PendingReturn
    struct Environment: Equatable {
        var stages: [OriginalGameplayBody.Stage] = []
        var journal: [String] = []
        var contactHP: [Int32] = [],contactCounts: [Int32] = []
        var hitHP: [Int32] = [],contactDamage: [Int32] = [],hitDamageStats: [Int32] = []
        var contacts: [D.Contact] = []
        var hitDamage = false
    }
    func body(_ session: inout G,_ env: inout Environment,_ trace: D.Trace,_ inject: Bool,_ firstCall: Bool,_ attacker: Int) throws -> Returned {
        let ready = session.entry,binding = try OriginalApplicationMatchBindings(pending:ready.entry)
        let output = OriginalMenuPresentationInput(targetSurface:ready.loading.target,methodResult:0,queryResult:0,audioGetResult:0,
            audioSetResult:0,queriedAudio:0,audioVolume:0,dcResult:0,dc:0x12345678,postResult:0)
        return try session.advance(environment:&env,outputInput:output,
            fillBacking:{ throw D.Failure.provider("Gameplay fill backing") },
            allocate:{ _ in throw D.Failure.provider("Replay codec allocation") },
            processorSignature:{ _ in throw D.Failure.provider("Replay processor signature") },
            open:{ _,_ in throw D.Failure.provider("Replay file open") },
            write:{ _,_ in throw D.Failure.provider("Replay file write") },
            close:{ _ in throw D.Failure.provider("Replay file close") },
            resumeMusic:{ _,_ in throw D.Failure.provider("Command music resume") },observe:{ o,e in
                try D.observe("Body observation") {
                switch o {
                case .front(let event):
                    let value = "front "+String(describing:event);e.journal.append(value);try trace.append(["event":value])
                case .gameplay(let event):
                    let value = "gameplay "+String(describing:event);e.journal.append(value);try trace.append(["event":value])
                case .gameplayCheckpoint(let stage,let snapshot):
                    try D.require(e.stages.count<OriginalGameplayBody.Stage.allCases.count && stage==OriginalGameplayBody.Stage.allCases[e.stages.count],"Diagnostic body checkpoint order")
                    try D.coherent(binding,snapshot.match,snapshot.state)
                    if stage == .contacts {
                        e.contactHP = try (0..<2).map { try D.word(snapshot.match,$0,0x2fc) }
                        e.contactCounts = try (0..<2).map { try D.word(snapshot.match,$0,0x2e4) }
                        e.contactDamage = try (0..<2).map { try D.word(snapshot.match,$0,0x34c) }
                        e.contacts = try D.contacts(snapshot.match,attacker)
                        try trace.append(["attackerContacts":e.contacts.map(\.json),"attackerSeat":attacker])
                    }
                    if stage == .hits {
                        try D.require(e.contactHP.count==2,"Missing preceding contact checkpoint")
                        e.hitHP = try (0..<2).map { try D.word(snapshot.match,$0,0x2fc) }
                        e.hitDamageStats = try (0..<2).map { try D.word(snapshot.match,$0,0x34c) }
                        let victim = 1-attacker,victimActor = try D.actor(snapshot.match,victim)
                        let delta = Int64(e.contactHP[victim])-Int64(e.hitHP[victim])
                        let linked = e.contacts.contains { $0.target==Int32(victimActor) && $0.kind==0 }
                        e.hitDamage = delta>0 && linked && Int64(e.hitDamageStats[victim] &- e.contactDamage[victim])==delta && e.hitHP[attacker]>=e.contactHP[attacker]
                        try trace.append(["damageObservation":["victimSeat":victim,"victimActor":victimActor,"hpDelta":delta,
                            "damageStatsBefore":e.contactDamage,"damageStatsAfter":e.hitDamageStats,"linkedOrdinaryContact":linked,"confirmed":e.hitDamage]])
                        if zip(e.hitHP,e.contactHP).contains(where:{ $0.0<$0.1 }) && !e.hitDamage {
                            throw D.Failure.diagnostic("HP decrease without selected-attacker ordinary-contact/damage-stat evidence")
                        }
                    }
                    e.stages.append(stage);trace.lastCompleted = stage.rawValue
                    try trace.append(["checkpoint":stage.rawValue,"snapshot":D.snapshot(snapshot.match,stage == .links || stage == .contacts || stage == .hits),
                        "applicationFull":D.pin(snapshot.state.full),"operationCount":snapshot.operations.count,
                        "libraryTargets":D.pin(snapshot.state.libraryHits.targets)])
                default:throw D.Failure.diagnostic("Unexpected non-gameplay observation")
                }
                }
            },beforeCommit:{ pending,e in
                trace.pending = pending
                if inject && (firstCall || e.hitDamage) { throw D.Failure.injected }
            })
    }
    func compare(_ a: Returned,_ b: Returned) throws {
        try D.require(a.exit==b.exit && a.dispatcherResult==b.dispatcherResult,"Retry complete return discriminator")
        try I.sameState(a.snapshot.state,b.snapshot.state);try I.sameMatch(a.snapshot.match,b.snapshot.match)
        try D.require(a.snapshot.operations==b.snapshot.operations && a.graphics==b.graphics,"Retry complete pending journal/graphics")
        try D.require(a.snapshot.local==b.snapshot.local && a.snapshot.music.allocations==b.snapshot.music.allocations && a.snapshot.resources.bitmaps==b.snapshot.resources.bitmaps && a.snapshot.backgrounds==b.snapshot.backgrounds,"Retry caller/music/resource ownership")
    }
    func sequence(_ attacker: Int,_ reverse: Bool) throws {
        try OriginalApplicationGameplayProjectionTests().sequence(reverse,onComplete:{ origin in
            var app = origin,controller = D.Controller(attacker:attacker),held = Set<UInt32>()
            var committed = 0,rollbacks = 0,retries = 0,allMessages = 0,expiredAt: Int?
            try D.emit(["kind":"start","attacker":attacker,"control":reverse,"parentCalls":17,"limit":160,
                "originalCompared":false,"initial":D.snapshot(XCTUnwrap(XCTUnwrap(app.session).loadedOwners).match,true)])
            for index in 1...160 {
                let trace = D.Trace();var acquired: C.A?
                do {
                    trace.phase = "controller"
                    let current = try XCTUnwrap(XCTUnwrap(app.session).loadedOwners).match
                    let plan = try controller.plan(current,index)
                    try trace.append(["plan":["index":index,"segment":plan.segment,"buttons":plan.buttons],
                        "bindings":(0..<2).map { try String(describing:I.binding(XCTUnwrap(app.session).state.full,$0)) }])
                    trace.phase = "acquisition"
                    let desired = try I.desired(XCTUnwrap(app.session).state.full,plan)
                    let keyboard = I.keyboard(try XCTUnwrap(app.session).state.full)
                    let declaredKeys = held.union(desired).sorted().filter { keyboard[Int($0)] != (desired.contains($0) ? 100:117) }
                    try trace.append(["acquisitionBefore":D.acquisition(app),"declaredMessages":declaredKeys.map { ["key":$0,"message":UInt32(desired.contains($0) ? 0x100:0x101)] }])
                    do { allMessages += try I.acquire(&app,plan,&held) }
                    catch { try trace.append(["acquisitionPartialAfter":D.acquisition(app)]);throw error }
                    try trace.append(["acquisitionAfter":D.acquisition(app)])
                    acquired = app
                    trace.phase = "outer-entry"
                    let loading = try C.next(&app)
                    try I.unchanged(app,XCTUnwrap(acquired))
                    var cycle = try app.makeLoadedCycle(pending:loading),input = D.Input()
                    trace.phase = "input"
                    let ready: Ready
                    do { ready = try D.input(&cycle,&input,trace) }
                    catch {
                        try D.require(cycle.pendingContinuation==nil && input==D.Input(),"Failed input transaction rollback")
                        throw error
                    }
                    try D.require(input.points==["prologue","localBeforeDispatch","local","control","received","replay","round"],"Complete input checkpoint sequence")
                    try D.require(input.requests==0 || input.requests==4,"Complete declared control vector")
                    guard ready.round.continuation == .gameplay else { throw D.Failure.route("Continuation \(ready.round.continuation)") }
                    var session = try G(pending:ready),env = Environment()
                    trace.phase = "body"
                    let bodyTrace = D.Trace();var firstAttempt: [String]?
                    let pending: Returned
                    do {
                    do { pending = try self.body(&session,&env,bodyTrace,true,index==1,attacker) }
                    catch D.Failure.injected {
                        try D.require(session.pendingReturn==nil && env==Environment(),"Failed body environment/pending rollback")
                        try I.sameState(session.entry.state,ready.state);try I.sameMatch(session.entry.match,ready.match)
                        try I.unchanged(app,XCTUnwrap(acquired));rollbacks += 1
                        firstAttempt = bodyTrace.rows
                        let rejected = try XCTUnwrap(bodyTrace.pending)
                        bodyTrace.rows = [];bodyTrace.lastCompleted = "none"
                        pending = try self.body(&session,&env,bodyTrace,false,index==1,attacker)
                        try D.require(bodyTrace.rows==firstAttempt,"Same body-session retry reproduces all attempted observations")
                        try self.compare(pending,rejected)
                        retries += 1
                    }
                    } catch {
                        trace.rows += bodyTrace.rows;trace.lastCompleted = bodyTrace.lastCompleted
                        try D.require(session.pendingReturn==nil && env==Environment(),"Unplanned body failure rolls back environment")
                        try I.sameState(session.entry.state,ready.state);throw error
                    }
                    trace.rows += bodyTrace.rows;trace.lastCompleted = bodyTrace.lastCompleted
                    try D.require(env.stages==OriginalGameplayBody.Stage.allCases,"Complete diagnostic19-stage return")
                    if index==1 || env.hitDamage {
                        trace.phase = "outer-injected"
                        do { try C.finish(&app,pending,stop:"commit");throw D.Failure.diagnostic("Missing outer injected failure") }
                        catch C.Stop.injected(let s) { try D.require(s=="commit","Exact outer injection") }
                        try I.unchanged(app,XCTUnwrap(acquired));rollbacks += 1;retries += 1
                    }
                    trace.phase = "outer"
                    try C.finish(&app,pending);committed += 1
                    let match = try XCTUnwrap(XCTUnwrap(app.session).loadedOwners).match
                    let hp = try (0..<2).map { try D.word(match,$0,0x2fc) }
                    let protection = try (0..<2).map { try D.word(match,$0,8) }
                    if expiredAt == nil && protection==[0,0] { expiredAt = index }
                    let operationText = String(describing:pending.snapshot.operations),graphicsText = String(describing:pending.graphics)
                    try trace.append(["outerCommitted":true,"snapshot":D.snapshot(match),"operations":operationText,
                        "graphicsCount":pending.graphics.count,"graphicsDescriptionSHA256":D.digest(Array(graphicsText.utf8)),
                        "hp":hp,"contactHP":env.contactHP,"hitHP":env.hitHP,"hitDamage":env.hitDamage,
                        "replayPointers":D.record(XCTUnwrap(app.session).state.memory.replayPointers)])
                    try D.emit(["kind":"call","attacker":attacker,"control":reverse,"index":index,"committed":true,
                        "attemptRows":trace.rows,"injectedBodyRows":firstAttempt ?? [],"originalCompared":false])
                    if env.hitDamage {
                        try D.require(zip(hp,env.contactHP).contains { $0.0 < $0.1 },"Hit-stage damage retained through outer return")
                        try D.emit(["kind":"outcome","outcome":"committed-hit-damage","attacker":attacker,"control":reverse,
                            "committedCalls":committed,"attemptedCalls":index,"messages":allMessages,"protectionExpiredAt":expiredAt as Any? ?? NSNull(),
                            "lateRollbacks":rollbacks,"sameSessionRetries":retries,"originalCompared":false,"fullMatchAccepted":false])
                        return
                    }
                } catch {
                    if let acquired { try I.unchanged(app,acquired) }
                    let category = trace.phase == "controller" ? "diagnostic-error":D.classification(error)
                    try D.emit(["kind":"outcome","outcome":category,"attacker":attacker,"control":reverse,
                        "committedCalls":committed,"attemptedCalls":index,"phase":trace.phase,"lastCompletedStage":trace.lastCompleted,
                        "errorType":String(reflecting:type(of:error)),"error":String(describing:error),"attemptRows":trace.rows,
                        "retained":D.snapshot(XCTUnwrap(XCTUnwrap(app.session).loadedOwners).match,true),
                        "lateRollbacks":rollbacks,"sameSessionRetries":retries,"originalCompared":false,"fullMatchAccepted":false])
                    if category.hasPrefix("diagnostic") || category=="comparison-domain" { XCTFail("Diagnostic reader/provider contract: \(error)") }
                    return
                }
            }
            try D.emit(["kind":"outcome","outcome":"call-limit","attacker":attacker,"control":reverse,
                "committedCalls":committed,"attemptedCalls":160,"messages":allMessages,"lateRollbacks":rollbacks,
                "sameSessionRetries":retries,"originalCompared":false,"fullMatchAccepted":false])
        })
    }
    func testNarutoFirstDamageDiagnostic() throws { try sequence(0,false) }
    func testSasukeFirstDamageDiagnostic() throws { try sequence(1,true) }
}
