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

    public static func compare(_ data: Data,fixture: (String) throws -> Data,postDraw: Data? = nil) throws -> Result {
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
        let suffix = c.control ? "-control" : ""
        func source(_ name: String) throws -> Data { try fixture("original-"+name+suffix+".json") }
        let result = try MatchLaunchReference.compare(launch: source("match-launch"),selection: source("match-selection"),character: source("character-screen"),
            cycle: source("menu-cycle"),returning: source("menu-return"),screen: source("mode-screen"),startup: source("menu-startup"),
            menu: source("menu-loading"),loading: source("menu-loading-state"),catalog: source("menu-loading-catalog"),sounds: source("menu-loading-sounds"),
            arithmeticPrecision: .bits53,gameplayControl: source("gameplay-physics"),gameplayPhysics: true,gameplayLinks: source("gameplay-links"),
            gameplayContacts: source("gameplay-contacts"),gameplayHits: source("gameplay-hits"),gameplayCPoints: source("gameplay-cpoints"),
            gameplayCamera: source("gameplay-camera"),gameplayDrawing: source("gameplay-drawing"),gameplayImpulses: data,gameplayLifecycle: postDraw)
        return .init(gameplay: result,fpuCheckpoints: finalAudit.checkpoints.count,fpuTransitions: finalAudit.transitions.count)
    }
}
