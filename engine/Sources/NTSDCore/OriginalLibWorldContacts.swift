/// Whole contact collection with both installed bundled-library filters.
/// Candidate buffers, prefix, pair order and fusion tail share the original
/// native pass. Later damage and initialized application routing are separate.
public enum OriginalLibWorldContacts {
    public static func apply(state: inout OriginalMatchPreparation,
                             observe: (OriginalWorldContactsEvent) throws -> Void = { _ in }) throws {
        try OriginalWorldContacts.apply(state: &state,bundledLibrary: true,observe: observe)
    }

    /// Explicit catalog/box providers preserve undefined-storage failures.
    /// Owned records commit together; callers buffer external effects until
    /// the encompassing tick also commits.
    public static func apply(world: inout OriginalStateRecord,actors: inout [OriginalStateRecord],
                             globals: inout OriginalStateRecord,objectCount: Int32,
                             header: @escaping (Int) throws -> OriginalStateRecord,
                             frame: @escaping (Int,Int32) throws -> OriginalStateRecord,
                             heapWord: @escaping (UInt32) throws -> Int32,
                             observe: (OriginalWorldContactsEvent) throws -> Void = { _ in }) throws {
        try OriginalWorldContacts.apply(world: &world,actors: &actors,globals: &globals,
            objectCount: objectCount,header: header,frame: frame,heapWord: heapWord,
            bundledLibrary: true,observe: observe)
    }
}
