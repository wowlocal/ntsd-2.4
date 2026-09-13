/// Translate only the recovered World catalog/Actor table and Actor Object
/// references between logical application tokens and the shared match ordinals.
/// Ordinal zero is a live first owner. All other bytes and masks stay intact.
public struct OriginalApplicationMatchBindings {
    public typealias State = OriginalApplicationMenuSession.State
    public enum Boundary: Error, Equatable {
        case identities, catalog, actor(UInt32), object(UInt32), ordinal(UInt32)
        case conflictingActor(UInt32), savedPlayback
    }
    public let catalogToken: UInt32, actorTokens: [UInt32], objectTokens: [UInt32]
    private let actors: [UInt32:UInt32], objects: [UInt32:UInt32]

    public init(catalogToken: UInt32, actorTokens: [UInt32], objectTokens: [UInt32]) throws {
        let all = [catalogToken]+actorTokens+objectTokens
        guard actorTokens.count == 400,!objectTokens.isEmpty,
              !all.contains(0),Set(all).count == all.count else { throw Boundary.identities }
        self.catalogToken = catalogToken;self.actorTokens = actorTokens;self.objectTokens = objectTokens
        actors = Dictionary(uniqueKeysWithValues:actorTokens.enumerated().map { ($0.element,UInt32($0.offset)) })
        objects = Dictionary(uniqueKeysWithValues:objectTokens.enumerated().map { ($0.element,UInt32($0.offset)) })
    }

    public init(pending: OriginalApplicationPoolSession.PendingInput) throws {
        let catalog = pending.entry.snapshot.allocations.filter { $0.kind == .catalog }
        guard catalog.count == 1 else { throw Boundary.catalog }
        try self.init(catalogToken:catalog[0].token,actorTokens:pending.actorTokens,
                      objectTokens:pending.entry.snapshot.objectTokens)
    }

    private func actor(_ token: UInt32,in memory: OriginalMenuPresentationMemory) throws -> OriginalStateRecord {
        guard let a = memory.allocations[token],a.live,a.storage.bytes.count == OriginalStateRecord.actorSize else {
            throw Boundary.actor(token)
        }
        return a.storage
    }

    public func read(_ state: State,catalog: OriginalLoadedCatalog,
                     interface: OriginalInitialInterfaceLoading,
                     arithmeticPrecision: OriginalArithmeticPrecision) throws -> OriginalMatchPreparation {
        try state.validateAliases()
        guard catalog.objects.count == objectTokens.count else { throw Boundary.catalog }
        var world = try State.slice(state.full,0xbb00,0x7d8)
        guard try world.integer(at:0x7d4,as:UInt32.self) == catalogToken else { throw Boundary.catalog }
        try world.write(UInt32(0),at:0x7d4)
        for seat in 0..<400 {
            let token = try world.integer(at:0x194+seat*4,as:UInt32.self)
            guard let ordinal = actors[token] else { throw Boundary.actor(token) }
            try world.write(ordinal,at:0x194+seat*4)
        }
        let records = try actorTokens.map { token -> OriginalStateRecord in
            var record = try actor(token,in:state.memory)
            let object = try record.integer(at:0x368,as:UInt32.self)
            guard let ordinal = objects[object] else { throw Boundary.object(object) }
            try record.write(ordinal,at:0x368);return record
        }
        return try .init(catalog:catalog,world:world,actors:records,
            globals:State.slice(state.full,0,OriginalMatchPreparation.globalSize),
            interface:interface,arithmeticPrecision:arithmeticPrecision)
    }

    public func inputContext(_ state: State) throws -> OriginalInputControlContext {
        try state.validateAliases()
        return .init(savedPlayback:try State.slice(state.full,0xb588,0x320),memory:state.memory)
    }

    /// Join the child into a tentative copy. Input resources may change through
    /// context; Actor records have one writer, the match model. Conflicting
    /// direct resource writes must not be silently overwritten by this merge.
    public func store(_ match: OriginalMatchPreparation,context: OriginalInputControlContext,
                      in state: inout State) throws {
        try state.validateAliases()
        guard context.savedPlayback.bytes.count == 0x320 else { throw Boundary.savedPlayback }
        guard match.loadedObjects.count == objectTokens.count,
              match.world.bytes.count == 0x7d8,match.actors.count == 400,
              match.actors.allSatisfy({ $0.bytes.count == OriginalStateRecord.actorSize }),
              match.globals.bytes.count == OriginalMatchPreparation.globalSize,
              try match.world.integer(at:0x7d4,as:UInt32.self) == 0 else { throw Boundary.catalog }
        var next = state,world = match.world,memory = context.memory
        try world.write(catalogToken,at:0x7d4)
        for seat in 0..<400 {
            let ordinal = try world.integer(at:0x194+seat*4,as:UInt32.self)
            guard ordinal < actorTokens.count else { throw Boundary.ordinal(ordinal) }
            try world.write(actorTokens[Int(ordinal)],at:0x194+seat*4)
        }
        for (i,token) in actorTokens.enumerated() {
            _ = try actor(token,in:state.memory)
            guard memory.allocations[token] == state.memory.allocations[token] else { throw Boundary.conflictingActor(token) }
            var record = match.actors[i]
            let ordinal = try record.integer(at:0x368,as:UInt32.self)
            guard ordinal < objectTokens.count else { throw Boundary.ordinal(ordinal) }
            try record.write(objectTokens[Int(ordinal)],at:0x368)
            memory.allocations[token] = .init(storage:record)
        }
        next.memory = memory
        try next.replace(0,match.globals);try next.replace(0xbb00,world)
        try next.replace(0xb588,context.savedPlayback);try next.replace(0xb8a8,memory.replayPointers)
        try next.validateAliases();state = next
    }
}
