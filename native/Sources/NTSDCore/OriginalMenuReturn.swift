import Foundation

///4229e2..422a95 after the real menu return, followed by424746 when the
///enclosing loading call returns. Shared helpers retain their original order.
public enum OriginalMenuReturn {
    public static func advance(state: inout OriginalMatchPreparation,memory: inout OriginalMenuPresentationMemory,
        input: OriginalMenuPresentationInput,milliseconds: UInt32,fillBacking: [UInt8]?,wholeEarlyReturn: Bool,
        draw: ([UInt32],OriginalStateRecord,OriginalMenuPresentationMemory) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in },
        checkpoint: (String,OriginalMatchPreparation) throws -> Void = { _,_ in }) throws {
        var candidate = state,owned = memory
        let base = OriginalMatchPreparation.globalBase
        func word(_ address: Int) throws -> Int32 { try candidate.globals.integer(at: address-base,as: Int32.self) }
        func bits(_ value: Int32) -> UInt32 { UInt32(bitPattern: value) }
        func write(_ address: Int,_ value: Int32) throws { try candidate.globals.write(value,at: address-base) }
        func event(_ e: OriginalMenuPresentationEvent) throws { try observe(.init(e.kind.rawValue,e.arguments,e.strings)) }
        try checkpoint("menuReturned",candidate)
        if try word(0x44d058) > 0,try candidate.globals.integer(at: 0x44f1af-base,as: Int8.self) > 0 {
            guard let backing = fillBacking else { throw OriginalStateError.invalidStorage("Network notice fill backing") }
            let target = try bits(word(0x455608))
            var fill = OriginalFrontScreenEvent("fill")
            fill.fill = try OriginalSurfaceFilling.request(target: target,x: 0,y: 0,width: 794,height: 550,color: 0,backing: backing)
            try observe(fill)
            let arguments = try [bits(word(0x451178)),230,221,0,0,0,target]
            try observe(.init("draw",arguments));try draw(arguments,candidate.globals,owned)
            // Original literal at449158. No localized/rephrased platform text.
            try OriginalSurfaceText.draw(Array("Waiting for opponent...".utf8),target: target,background: 0x652512,color: 0xd8775a,
                x: 271,y: 295,dcResult: input.dcResult,dc: input.dc,observe: event)
            try write(0x44d058,word(0x44d058) &- 1)
        }
        try OriginalMenuPresentation.apply(.overlay,input: input,world: &candidate.world,globals: &candidate.globals,memory: &owned,observe: event)
        try OriginalMenuPresentation.presentSurface(globals: candidate.globals,observe: event)
        if try word(0x44d020) == 0 {
            try write(0x451158,0)
            try observe(.init("timer",[milliseconds]))
            try write(0x451154,Int32(bitPattern: milliseconds))
        }
        try checkpoint("matchBeforeReturn",candidate)
        if wholeEarlyReturn {
            try checkpoint("loadingReturned",candidate)
            try write(0x457580,0)
            try checkpoint("heldCleared",candidate)
            try checkpoint("earlyReturned",candidate)
        }
        state = candidate;memory = owned
    }
}
