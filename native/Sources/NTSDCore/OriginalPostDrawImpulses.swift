///41f4ac..41f545 common diagnostic text and accumulated impulses. The original
/// mode1/4 children are still separate, explicitly unsupported mechanisms.
public enum OriginalPostDrawImpulses {
    static let format = Array("u%d d%d l%d r%d a%d d%d ".utf8)
    static func inputText(world: OriginalStateRecord,actors: [OriginalStateRecord]) throws -> [UInt8] {
        let actor = Int(try world.integer(at: 0x1bc,as: UInt32.self))
        guard actors.indices.contains(actor) else { throw OriginalStateError.invalidStorage("Post-draw: diagnostic Actor binding") }
        let values = try [0xc4,0xc5,0xc3,0xc2,0xbe,0xc0].map { try actors[actor].integer(at: $0,as: Int8.self) }
        return Array(zip(["u","d","l","r","a","d"],values).map { $0+String($1)+" " }.joined().utf8)
    }
    public static func apply(state: inout OriginalMatchPreparation,dcResult: Int32,dc: UInt32,
                             observe: (OriginalMenuPresentationEvent) throws -> Void = { _ in }) throws {
        let mode = try state.globals.integer(at: 0x451160-0x44d000,as: Int32.self)
        guard mode != 1 && mode != 4 else { throw OriginalStateError.invalidStorage("Post-draw: original mode\(mode) child is not recovered") }
        var owned = state
        let bytes = try inputText(world: owned.world,actors: owned.actors)
        try observe(.init(.format,[UInt32(bytes.count)],[format,bytes]))
        try OriginalSurfaceText.draw(bytes,target: owned.globals.integer(at: 0x455608-0x44d000,as: UInt32.self),
            background: 0,color: 0xffffff,x: 0,y: 30,dcResult: dcResult,dc: dc,observe: observe)
        try OriginalWorldImpulses.apply(state: &owned)
        state = owned
    }
}
