/// Immutable original tournament dimensions/coordinates at44d120..44d317.
/// Recovered from the pinned EXE as static game data; no EXE is read at runtime.
/// Both tournament menus consume live initialized global storage afterward.
public enum OriginalTournamentLayout {
    public static let sourceSHA256 = "ae205dff1239899386e0f76ff80dc3c8f22472b2b19ebb11ae02b1b3bbcc87c8"
    public static let words: [Int32] = [
        4,34,34,4,4,35,64,4,4,38,124,4,4,34,
        235,221,235,217,265,182,265,178,325,140,325,136,445,102,
        295,221,265,217,265,182,265,178,325,140,325,136,445,102,
        355,221,355,217,385,182,325,178,325,140,325,136,445,102,
        415,221,385,217,385,182,325,178,325,140,325,136,445,102,
        475,221,475,217,505,182,505,178,565,140,445,136,445,102,
        535,221,505,217,505,182,505,178,565,140,445,136,445,102,
        595,221,595,217,625,182,565,178,565,140,445,136,445,102,
        655,221,625,217,625,182,565,178,565,140,445,136,445,102,
    ]
    public static func initialize(globals: inout OriginalStateRecord) throws {
        var candidate=globals
        for (i,value) in words.enumerated() { try candidate.write(value,at:0x44d120-OriginalMatchPreparation.globalBase+i*4) }
        globals=candidate
    }
}
