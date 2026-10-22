/// The record at 0x44d000 (ENGINE_SPLIT E5b): the EXE's globals, from its
/// initialized `.data` (the game supplies those bytes, its startup package's
/// initial.bin) through the outer block. The layout is the engine's; address
/// uses stay constants relative to `base`.
public enum OriginalRecordLayout {
    /// The record's first address.
    public static let base = 0x44d000
    /// The globals WinMain reads: 0x44d000..<0x458440.
    public static let globalsSize = 0xb440
    /// The whole record with the outer block: 0x44d000..<0x4593a8.
    public static let size = 0xc3a8
    /// The parts a session's record is held in (CORE_REALTIME B1; see
    /// OriginalApplicationMenuSession.partStarts).
    static let partStarts = [0, 0xb440, 0xb580, 0xb588, 0xb8a8, 0xb8b0, 0xbb00, 0xc2d8]
}
