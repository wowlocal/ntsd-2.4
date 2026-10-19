import NTSDCore

/// NTSD's initialized data for suites that seed a record by hand: ranges of the
/// game's record (its startup package's initial.bin). Until ENGINE_SPLIT E5b
/// these were literal tables in the engine (OriginalTournamentLayout.words,
/// OriginalWarTroops.fileWords), equal to these ranges.
enum NTSDInitialRecordData {
    /// The SHA-256 of the tournament dimensions/coordinates at 0x44d120..<0x44d318.
    static let tournamentLayoutSHA256 = "ae205dff1239899386e0f76ff80dc3c8f22472b2b19ebb11ae02b1b3bbcc87c8"
    /// The tournament dimensions/coordinates at 0x44d120..<0x44d318.
    static func initializeTournamentLayout(globals: inout OriginalStateRecord) throws {
        var candidate=globals
        try copy(0x44d120..<0x44d318,into:&candidate)
        globals=candidate
    }
    /// War's initialized data at 0x44d350..<0x44d778, then 0x451b38..<0x451bb4 zeroed.
    static func initializeWarFileData(_ globals: inout OriginalStateRecord) throws {
        var g=globals
        try copy(0x44d350..<0x44d778,into:&g)
        for a in stride(from:0x451b38,to:0x451bb4,by:4) { try g.write(Int32(0),at:a-OriginalMatchPreparation.globalBase) }
        globals=g
    }
    /// Word by word, in address order, as the tables were written.
    private static func copy(_ range: Range<Int>,into globals: inout OriginalStateRecord) throws {
        let initial=try OriginalApplicationStartupInputsTests.shared.get().initial
        for address in stride(from:range.lowerBound,to:range.upperBound,by:4) {
            let offset=address-OriginalMatchPreparation.globalBase
            try globals.write(try initial.integer(at:offset,as:Int32.self),at:offset)
        }
    }
}
