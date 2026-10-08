///41f4ac..41f545 common diagnostic text and accumulated impulses. The mode1
/// child (437860, Mission stage logic) and the mode4 child (43a860, War battle
/// logic) run through the caller's `mission`/`war` compositions.
public enum OriginalPostDrawImpulses {
    static let format = Array("u%d d%d l%d r%d a%d d%d ".utf8)
    static func inputText(world: OriginalStateRecord,actors: [OriginalStateRecord]) throws -> [UInt8] {
        let actor = Int(try world.integer(at: 0x1bc,as: UInt32.self))
        guard actors.indices.contains(actor) else { throw OriginalStateError.invalidStorage("Post-draw: diagnostic Actor binding") }
        let values = try [0xc4,0xc5,0xc3,0xc2,0xbe,0xc0].map { try actors[actor].integer(at: $0,as: Int8.self) }
        return Array(zip(["u","d","l","r","a","d"],values).map { $0+String($1)+" " }.joined().utf8)
    }
    public static func apply(state: inout OriginalMatchPreparation,dcResult: Int32,dc: UInt32,
                             textRenderer: OriginalSurfaceText.Renderer? = nil,
                             mission: (inout OriginalMatchPreparation) throws -> Bool = { _ in false },
                             war: (inout OriginalMatchPreparation) throws -> Bool = { _ in false },
                             observe: (OriginalMenuPresentationEvent) throws -> Void = { _ in }) throws {
        let mode = try state.globals.integer(at: 0x451160-0x44d000,as: Int32.self)
        var owned = state
        try run(mode: mode,state: &owned,dcResult: dcResult,dc: dc,textRenderer: textRenderer,mission: mission,war: war,observe: observe,inPlace: false)
        state = owned
    }
    /// `apply` run on the caller's state, its impulses in place too
    /// (CORE_REALTIME B2 P4): for callers that drop the state when this throws.
    package static func applyInPlace(state: inout OriginalMatchPreparation,dcResult: Int32,dc: UInt32,
                                     textRenderer: OriginalSurfaceText.Renderer? = nil,
                                     mission: (inout OriginalMatchPreparation) throws -> Bool = { _ in false },
                                     war: (inout OriginalMatchPreparation) throws -> Bool = { _ in false },
                                     observe: (OriginalMenuPresentationEvent) throws -> Void = { _ in }) throws {
        let mode = try state.globals.integer(at: 0x451160-0x44d000,as: Int32.self)
        try run(mode: mode,state: &state,dcResult: dcResult,dc: dc,textRenderer: textRenderer,mission: mission,war: war,observe: observe,inPlace: true)
    }
    private static func run(mode: Int32,state owned: inout OriginalMatchPreparation,dcResult: Int32,dc: UInt32,
                            textRenderer: OriginalSurfaceText.Renderer?,mission: (inout OriginalMatchPreparation) throws -> Bool,
                            war: (inout OriginalMatchPreparation) throws -> Bool,observe: (OriginalMenuPresentationEvent) throws -> Void,
                            inPlace: Bool) throws {
        // A caller without the Mission/War composition returns false: explicit boundary.
        if mode == 1,try !mission(&owned) { throw OriginalStateError.invalidStorage("Post-draw: original mode1 child is not recovered") }
        if mode == 4,try !war(&owned) { throw OriginalStateError.invalidStorage("Post-draw: original mode4 child is not recovered") }
        let bytes = try inputText(world: owned.world,actors: owned.actors)
        try observe(.init(.format,[UInt32(bytes.count)],[format,bytes]))
        try OriginalSurfaceText.draw(bytes,target: owned.globals.integer(at: 0x455608-0x44d000,as: UInt32.self),
            background: 0,color: 0xffffff,x: 0,y: 30,dcResult: dcResult,dc: dc,renderer: textRenderer,observe: observe)
        if inPlace { try OriginalWorldImpulses.applyInPlace(state: &owned) } else { try OriginalWorldImpulses.apply(state: &owned) }
    }
}
