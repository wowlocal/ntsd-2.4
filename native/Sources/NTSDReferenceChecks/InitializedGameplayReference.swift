import Foundation
import NTSDCore

/// The new source chain executes445a31/CRT before World construction, then
/// reproduces the pinned historical records on the same CPU through41f550.
/// Native state is rebuilt from original resources with explicit53-bit context.
public enum InitializedGameplayReference {
    public struct Result {
        public let gameplay: MatchLaunchReference.Result
        public let fpuCheckpoints: Int,fpuTransitions: Int
    }
    private struct Audit: Decodable, Equatable {
        struct Initialization: Decodable, Equatable {
            let entry: UInt32,entrySP: UInt32,returnPC: UInt32,returnSP: UInt32
            let before: UInt16,after: UInt16,result: Int32,instructions: [UInt32]
        }
        struct Checkpoint: Decodable, Equatable { let pc: UInt32,sp: UInt32,fpcw: UInt16,fpsw: UInt16 }
        struct Transition: Decodable, Equatable { let pc: UInt32,operation: String,before: UInt16,after: UInt16,fpswBefore: UInt16,fpswAfter: UInt16 }
        struct Watched: Decodable, Equatable { let pc: UInt32,bytes: String,operation: String }
        let initialization: Initialization,checkpoints: [Checkpoint],transitions: [Transition],watchedInstructions: [Watched]
    }
    private struct Corpus: Decodable { let exeSHA256: String,dllSHA256: String,control: Bool,fpu: Audit }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Initialized gameplay reference: "+text) }

    public static func compare(_ data: Data,fixture: (String) throws -> Data,postDraw: Data? = nil,commands: Data? = nil,hud: Data? = nil,notices: Data? = nil,resultRecording: Data? = nil,resultLayout: Data? = nil,returned: Data? = nil,compareGameplayBody: Bool = false,continuous: Data? = nil,paused: Data? = nil) throws -> Result {
        let c = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(data,maximumCount: 128_000_000))
        let a = c.fpu,i = a.initialization
        guard c.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              c.dllSHA256 == "c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d",
              i.entry == 0x445a31,i.entrySP == 0x10006000,i.returnPC == 0x30000000,i.returnSP == i.entrySP+4,
              i.before == 0x37f,i.after == 0x23f,i.result == 0,
              Set([0x445a31,0x445b16,0x7814a7e9,0x7814b04c,0x7814b118]).isSubset(of: Set(i.instructions)),
              !a.checkpoints.isEmpty,!a.transitions.isEmpty,a.watchedInstructions.count > 40,
              a.checkpoints.allSatisfy({ $0.fpcw == 0x23f }),a.checkpoints.first?.pc == 0x419e40,
              a.checkpoints.last?.pc == 0x41f550 else { throw error("Original initialized context") }
        let watched = Dictionary(uniqueKeysWithValues: a.watchedInstructions.map { ($0.pc,$0) })
        var current = i.before
        for t in a.transitions {
            guard let instruction = watched[t.pc],instruction.operation == t.operation,
                  !instruction.bytes.isEmpty,t.before == current else { throw error("Control-word transition order") }
            current = t.after
        }
        guard current == i.after else { throw error("Final initialized context") }
        var finalAudit = a
        if let postDraw {
            let next = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(postDraw,maximumCount: 128_000_000))
            let expectedPCs: [UInt32] = (0..<400).flatMap { slot in
                slot < 2 ? [0x41f550,0x40d960,0x41fb0b] : [0x41f550]
            }
            let extra = Array(next.fpu.checkpoints.dropFirst(a.checkpoints.count))
            guard next.exeSHA256 == c.exeSHA256,next.dllSHA256 == c.dllSHA256,next.control == c.control,
                  next.fpu.initialization == a.initialization,next.fpu.transitions == a.transitions,
                  next.fpu.watchedInstructions == a.watchedInstructions,next.fpu.checkpoints.starts(with: a.checkpoints),
                  extra.map(\.pc) == expectedPCs,next.fpu.checkpoints.allSatisfy({ $0.fpcw == 0x23f }),
                  extra.allSatisfy({ $0.sp == ($0.pc == 0x40d960 ? 0x1000e9b0 : 0x1000e9bc) }) else { throw error("Extended initialized context") }
            // The terminal FPU hook is ordered after the gameplay stop hook.
            // Source explicitly reads/asserts the equal entry/exit control word
            // separately; GameplayLifecycleReference checks that boundary.
            finalAudit = next.fpu
        }
        if let commands {
            guard postDraw != nil else { throw error("Commands need own lifecycle continuation") }
            let next = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(commands,maximumCount: 128_000_000))
            let extra = Array(next.fpu.checkpoints.dropFirst(finalAudit.checkpoints.count))
            let expectedPCs: [UInt32] = [0x4214d5] + Array(repeating: 0x4217b0,count: 400)
            guard next.exeSHA256 == c.exeSHA256,next.dllSHA256 == c.dllSHA256,next.control == c.control,
                  next.fpu.initialization == finalAudit.initialization,next.fpu.transitions == finalAudit.transitions,
                  next.fpu.watchedInstructions == finalAudit.watchedInstructions,next.fpu.checkpoints.starts(with: finalAudit.checkpoints),
                  extra.map(\.pc) == expectedPCs,next.fpu.checkpoints.allSatisfy({ $0.fpcw == 0x23f }),
                  extra.allSatisfy({ $0.sp == 0x1000e9bc }) else { throw error("Commands initialized context") }
            finalAudit = next.fpu
        }
        if let hud {
            guard commands != nil else { throw error("HUD needs own command continuation") }
            let next = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(hud,maximumCount: 128_000_000))
            let extra = Array(next.fpu.checkpoints.dropFirst(finalAudit.checkpoints.count))
            let expectedPCs: [UInt32] = [0x421a15,0x41ae60] + Array(repeating: 0x41ae70,count: 8)
            let stacks: [UInt32:UInt32] = [0x421a15:0x1000e9bc,0x41ae60:0x1000e9b4,0x41ae70:0x1000e99c]
            guard next.exeSHA256 == c.exeSHA256,next.dllSHA256 == c.dllSHA256,next.control == c.control,
                  next.fpu.initialization == finalAudit.initialization,next.fpu.transitions == finalAudit.transitions,
                  next.fpu.watchedInstructions == finalAudit.watchedInstructions,next.fpu.checkpoints.starts(with: finalAudit.checkpoints),
                  extra.map(\.pc) == expectedPCs,next.fpu.checkpoints.allSatisfy({ $0.fpcw == 0x23f }),
                  extra.allSatisfy({ stacks[$0.pc] == $0.sp }) else { throw error("HUD initialized context") }
            finalAudit = next.fpu
        }
        if let notices {
            guard hud != nil else { throw error("Notices need own HUD continuation") }
            let next = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(notices,maximumCount: 128_000_000))
            let extra = Array(next.fpu.checkpoints.dropFirst(finalAudit.checkpoints.count))
            guard next.exeSHA256 == c.exeSHA256,next.dllSHA256 == c.dllSHA256,next.control == c.control,
                  next.fpu.initialization == finalAudit.initialization,next.fpu.transitions == finalAudit.transitions,
                  next.fpu.watchedInstructions == finalAudit.watchedInstructions,next.fpu.checkpoints.starts(with: finalAudit.checkpoints),
                  extra.map(\.pc) == [0x421a2d],next.fpu.checkpoints.allSatisfy({ $0.fpcw == 0x23f }),
                  extra.allSatisfy({ $0.sp == 0x1000e9bc && $0.fpsw == 0x4000 }) else { throw error("Notices initialized context") }
            finalAudit = next.fpu
        }
        if let resultRecording {
            guard notices != nil else { throw error("Result recording needs own notices continuation") }
            let next = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(resultRecording,maximumCount: 128_000_000))
            let extra = Array(next.fpu.checkpoints.dropFirst(finalAudit.checkpoints.count))
            guard next.exeSHA256 == c.exeSHA256,next.dllSHA256 == c.dllSHA256,next.control == c.control,
                  next.fpu.initialization == finalAudit.initialization,next.fpu.transitions == finalAudit.transitions,
                  next.fpu.watchedInstructions == finalAudit.watchedInstructions,next.fpu.checkpoints.starts(with: finalAudit.checkpoints),
                  extra.map(\.pc) == [0x421cdc],next.fpu.checkpoints.allSatisfy({ $0.fpcw == 0x23f }),
                  extra.allSatisfy({ $0.sp == 0x1000e9bc && $0.fpsw == 0x4000 }) else { throw error("Result recording initialized context") }
            finalAudit = next.fpu
        }
        if let resultLayout {
            guard resultRecording != nil else { throw error("Result layout needs own recorder continuation") }
            let next = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(resultLayout,maximumCount: 128_000_000))
            let extra = Array(next.fpu.checkpoints.dropFirst(finalAudit.checkpoints.count))
            guard next.exeSHA256 == c.exeSHA256,next.dllSHA256 == c.dllSHA256,next.control == c.control,
                  next.fpu.initialization == finalAudit.initialization,next.fpu.transitions == finalAudit.transitions,
                  next.fpu.watchedInstructions == finalAudit.watchedInstructions,next.fpu.checkpoints.starts(with: finalAudit.checkpoints),
                  extra.map(\.pc) == [0x422944],next.fpu.checkpoints.allSatisfy({ $0.fpcw == 0x23f }),
                  extra.allSatisfy({ $0.sp == 0x1000e9bc && $0.fpsw == 0x4000 }) else { throw error("Result layout initialized context") }
            finalAudit = next.fpu
        }
        if let returned {
            guard resultLayout != nil else { throw error("Return needs own result-layout continuation") }
            let next = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(returned,maximumCount: 128_000_000))
            let extra = Array(next.fpu.checkpoints.dropFirst(finalAudit.checkpoints.count))
            let expectedPCs: [UInt32] = [0x422994,0x41b130,0x4028a0,0x43e940,0x419e60,0x422a95,0x424746,0x4287de]
            let expectedStacks: [UInt32] = [0x1000e9bc,0x1000e9b0,0x1000e9b4,0x1000e9b0,0x1000e9b8,0x1000e9bc,0x1000f000,0x1000f000]
            guard next.exeSHA256 == c.exeSHA256,next.dllSHA256 == c.dllSHA256,next.control == c.control,
                  next.fpu.initialization == finalAudit.initialization,next.fpu.transitions == finalAudit.transitions,
                  next.fpu.watchedInstructions == finalAudit.watchedInstructions,next.fpu.checkpoints.starts(with: finalAudit.checkpoints),
                  extra.map(\.pc) == expectedPCs,extra.map(\.sp) == expectedStacks,
                  next.fpu.checkpoints.allSatisfy({ $0.fpcw == 0x23f }),extra.allSatisfy({ $0.fpsw == 0x4000 }) else { throw error("Returned initialized context") }
            finalAudit = next.fpu
        }
        if let continuous {
            guard returned != nil else { throw error("Continuous calls need the own returned parent") }
            let next = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(continuous,maximumCount:256_000_000))
            guard next.exeSHA256 == c.exeSHA256,next.dllSHA256 == c.dllSHA256,next.control == c.control,
                  next.fpu.initialization == finalAudit.initialization,next.fpu.transitions == finalAudit.transitions,
                  next.fpu.watchedInstructions == finalAudit.watchedInstructions,next.fpu.checkpoints.starts(with:finalAudit.checkpoints),
                  next.fpu.checkpoints.count > finalAudit.checkpoints.count,
                  next.fpu.checkpoints.allSatisfy({ $0.fpcw == 0x23f }) else { throw error("Continuous initialized context") }
            finalAudit = next.fpu
        }
        if let paused {
            guard continuous != nil else { throw error("Paused calls need the complete neutral parent") }
            let next = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(paused,maximumCount:256_000_000))
            guard next.exeSHA256 == c.exeSHA256,next.dllSHA256 == c.dllSHA256,next.control == c.control,
                  next.fpu.initialization == finalAudit.initialization,next.fpu.transitions == finalAudit.transitions,
                  next.fpu.watchedInstructions == finalAudit.watchedInstructions,next.fpu.checkpoints.starts(with:finalAudit.checkpoints),
                  next.fpu.checkpoints.count > finalAudit.checkpoints.count,
                  next.fpu.checkpoints.allSatisfy({ $0.fpcw == 0x23f }) else { throw error("Paused initialized context") }
            finalAudit = next.fpu
        }
        let suffix = c.control ? "-control" : ""
        func source(_ name: String) throws -> Data { try fixture("original-"+name+suffix+".json") }
        let result = try MatchLaunchReference.compare(launch: source("match-launch"),selection: source("match-selection"),character: source("character-screen"),
            cycle: source("menu-cycle"),returning: source("menu-return"),screen: source("mode-screen"),startup: source("menu-startup"),
            menu: source("menu-loading"),loading: source("menu-loading-state"),catalog: source("menu-loading-catalog"),sounds: source("menu-loading-sounds"),
            arithmeticPrecision: .bits53,gameplayControl: source("gameplay-physics"),gameplayPhysics: true,gameplayLinks: source("gameplay-links"),
            gameplayContacts: source("gameplay-contacts"),gameplayHits: source("gameplay-hits"),gameplayCPoints: source("gameplay-cpoints"),
            gameplayCamera: source("gameplay-camera"),gameplayDrawing: source("gameplay-drawing"),gameplayImpulses: data,gameplayLifecycle: postDraw,gameplayCommands: commands,gameplayHUD: hud,gameplayNotices: notices,gameplayResultRecording: resultRecording,gameplayResultLayout: resultLayout,gameplayReturn: returned,compareGameplayBody: compareGameplayBody,continuousGameplay:continuous,pausedGameplay:paused)
        return .init(gameplay: result,fpuCheckpoints: finalAudit.checkpoints.count,fpuTransitions: finalAudit.transitions.count)
    }
}
