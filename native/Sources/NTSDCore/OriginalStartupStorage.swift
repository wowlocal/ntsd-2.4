/// The last three C++ table callbacks at4472c8..4472d4.
/// This observed extent includes untouched intervening globals; it is not an
/// object-size claim or a complete CRT/EXE startup implementation.
public enum OriginalStartupStorage {
    public static let observedBase = 0x458440
    public static let observedCount = 0x854

    public enum Constructor: Int, CaseIterable, Sendable {
        case textInput = 0x4462e0
        case inputTranslation = 0x4462f0
        case soundQueue = 0x446300
    }

    /// Preserve the caller's own backing and initialization provenance. Observers
    /// see completed constructors in source table order; buffer external effects
    /// until this enclosing operation commits.
    public static func initialize(_ storage: inout OriginalStateRecord,
        completed: (Constructor) throws -> Void = { _ in }) throws {
        guard storage.bytes.count == observedCount else {
            throw OriginalStateError.invalidStorage("Startup storage extent")
        }
        var staged = storage
        //4031b0 clears only three words; the text buffer itself stays untouched.
        for offset in [0, 0x130, 0x134] { try staged.write(UInt32(0), at: offset) }
        try completed(.textInput)
        //414440 returns its input pointer without reading or writing the object.
        try completed(.inputTranslation)
        //419e40 clears its first word, then400 bytes at+4 through actual memset.
        for offset in stride(from: 0x6c0, to: observedCount, by: 4) {
            try staged.write(UInt32(0), at: offset)
        }
        try completed(.soundQueue)
        storage = staged
    }
}
