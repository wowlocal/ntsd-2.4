import Foundation

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
    /// The last session/model pair of each actor record (CORE_REALTIME R3).
    /// read and store rewrite only the Object reference at +0x368, in opposite
    /// directions over unique tokens, so a record equal to one side of a pair
    /// converts to the other side with no error; equality checks buffer
    /// identity first, so an actor unchanged since the last read or store is
    /// neither copied nor rewritten. Copies of these bindings share the pairs.
    private let pairs: ActorPairs
    /// The actor tier these bindings read and store in the session memory's
    /// allocation table (CORE_REALTIME R3 stage 1): while the state holds it,
    /// the 400 actors stay in model form across ticks.
    private let shape: OriginalAllocationTable.ActorShape
    final class ActorPairs {
        private let lock = NSLock()
        private var stored = [OriginalStateRecord?](repeating:nil,count:400)
        private var model = [OriginalStateRecord?](repeating:nil,count:400)
        /// `model[i]`'s buffer identity (kept alive by `model[i]`).
        private var modelIdentity = [(UInt,UInt)?](repeating:nil,count:400)
        /// The model form of `record` when it equals the stored side of pair `i`.
        func model(_ i: Int,for record: OriginalStateRecord) -> OriginalStateRecord? {
            lock.lock(); defer { lock.unlock() }
            guard let s = stored[i],s == record else { return nil }
            return model[i]
        }
        /// The stored form of `record` when it equals the model side of pair `i`.
        func stored(_ i: Int,for record: OriginalStateRecord) -> OriginalStateRecord? {
            lock.lock(); defer { lock.unlock() }
            guard let m = model[i],m == record else { return nil }
            return stored[i]
        }
        func set(_ i: Int,stored s: OriginalStateRecord,model m: OriginalStateRecord) {
            lock.lock(); defer { lock.unlock() }
            stored[i] = s; model[i] = m; modelIdentity[i] = m.storageIdentity
        }
        /// For each record, whether it shares both buffers with pair i's model
        /// side: unchanged since the pair was set, so `stored(i,for:)` would
        /// return the stored side. One lock and no record copies for all 400
        /// (CORE_REALTIME 4j); false means "ask `stored(i,for:)`".
        func unchanged(_ records: [OriginalStateRecord]) -> [Bool] {
            lock.lock(); defer { lock.unlock() }
            return records.indices.map { i in
                guard i < modelIdentity.count,let kept = modelIdentity[i],let identity = records[i].storageIdentity else { return false }
                return kept == identity
            }
        }
    }

    public init(catalogToken: UInt32, actorTokens: [UInt32], objectTokens: [UInt32]) throws {
        let all = [catalogToken]+actorTokens+objectTokens
        guard actorTokens.count == 400,!objectTokens.isEmpty,
              !all.contains(0),Set(all).count == all.count else { throw Boundary.identities }
        self.catalogToken = catalogToken;self.actorTokens = actorTokens;self.objectTokens = objectTokens
        actors = Dictionary(uniqueKeysWithValues:actorTokens.enumerated().map { ($0.element,UInt32($0.offset)) })
        objects = Dictionary(uniqueKeysWithValues:objectTokens.enumerated().map { ($0.element,UInt32($0.offset)) })
        pairs = ActorPairs()
        shape = .init(tokens:actorTokens,objectTokens:objectTokens,pairs:pairs)
    }

    /// Built once per loaded session (CORE_REALTIME R1); the same value or
    /// error every time.
    public init(pending: OriginalApplicationPoolSession.PendingInput) throws {
        self = try pending.derived.bindings { try Self(building:pending) }
    }

    private init(building pending: OriginalApplicationPoolSession.PendingInput) throws {
        let catalog = pending.entry.snapshot.allocations.filter { $0.kind == .catalog }
        guard catalog.count == 1 else { throw Boundary.catalog }
        try self.init(catalogToken:catalog[0].token,actorTokens:pending.actorTokens,
                      objectTokens:pending.entry.snapshot.objectTokens)
    }

    private func actor(_ token: UInt32,in memory: OriginalMenuPresentationMemory) throws -> OriginalStateRecord {
        guard let a = memory.allocations[token],a.live,a.storage.byteCount == OriginalStateRecord.actorSize else {
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
        // The state's own actor tier is already the model form; its records
        // passed these checks when they were stored (R3 stage 1).
        let records = try state.memory.allocations.actorRecords(shape) ?? actorTokens.indices.map { i -> OriginalStateRecord in
            let record = try actor(actorTokens[i],in:state.memory)
            if let converted = pairs.model(i,for:record) { return converted }
            var converted = record
            let object = try converted.integer(at:0x368,as:UInt32.self)
            guard let ordinal = objects[object] else { throw Boundary.object(object) }
            try converted.write(ordinal,at:0x368)
            pairs.set(i,stored:record,model:converted)
            return converted
        }
        return try .init(catalog:catalog,world:world,actors:records,
            globals:State.slice(state.full,0,OriginalMatchPreparation.globalSize),
            interface:interface,arithmeticPrecision:arithmeticPrecision)
    }

    /// Refresh current shared records while retaining mutable DAT frame,
    /// arena and interface owners from the preceding committed match.
    public func read(_ state: State,retaining match: OriginalMatchPreparation) throws -> OriginalMatchPreparation {
        let records = try read(state,catalog:match.catalog,interface:match.interface,
                               arithmeticPrecision:match.arithmeticPrecision)
        var current = match
        current.world = records.world;current.actors = records.actors;current.globals = records.globals
        return current
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
        guard context.savedPlayback.byteCount == 0x320 else { throw Boundary.savedPlayback }
        guard match.loadedObjects.count == objectTokens.count,
              match.world.byteCount == 0x7d8,match.actors.count == 400,
              match.actors.allSatisfy({ $0.byteCount == OriginalStateRecord.actorSize }),
              match.globals.byteCount == OriginalMatchPreparation.globalSize,
              try match.world.integer(at:0x7d4,as:UInt32.self) == 0 else { throw Boundary.catalog }
        var next = state,world = match.world,memory = context.memory
        try world.write(catalogToken,at:0x7d4)
        for seat in 0..<400 {
            let ordinal = try world.integer(at:0x194+seat*4,as:UInt32.self)
            guard ordinal < actorTokens.count else { throw Boundary.ordinal(ordinal) }
            try world.write(actorTokens[Int(ordinal)],at:0x194+seat*4)
        }
        // The same checks per actor and in the same order as writing each
        // entry: the state's actor (implied when the state holds this tier),
        // no conflicting write through the context (equal tiers compare once),
        // a defined Object ordinal in range. The records then become the
        // table's actor tier in model form instead of 400 converted entries
        // (R3 stage 1); the logical entries are the converted records, live.
        let stateHolds = state.memory.allocations.actorRecords(shape) != nil
        let sameActors = memory.allocations.sameActors(shape,as:state.memory.allocations)
        // Actors still holding their pair's model buffers need no lookup (4j).
        let unchanged = pairs.unchanged(match.actors)
        for (i,token) in actorTokens.enumerated() {
            if !stateHolds { _ = try actor(token,in:state.memory) }
            if !sameActors { guard memory.allocations[token] == state.memory.allocations[token] else { throw Boundary.conflictingActor(token) } }
            if !unchanged[i],pairs.stored(i,for:match.actors[i]) == nil {
                var converted = match.actors[i]
                let ordinal = try converted.integer(at:0x368,as:UInt32.self)
                guard ordinal < objectTokens.count else { throw Boundary.ordinal(ordinal) }
                try converted.write(objectTokens[Int(ordinal)],at:0x368)
                pairs.set(i,stored:converted,model:match.actors[i])
            }
        }
        memory.allocations.installActors(shape,match.actors)
        next.memory = memory
        try next.replace(0,match.globals);try next.replace(0xbb00,world)
        try next.replace(0xb588,context.savedPlayback);try next.replace(0xb8a8,memory.replayPointers)
        try next.validateAliases();state = next
    }
}
