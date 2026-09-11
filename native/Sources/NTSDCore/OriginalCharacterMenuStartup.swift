public enum OriginalCharacterMenuStartupError: Error, Equatable {
    /// Original429b21 would write through the NULL SPARK allocation.
    /// The standalone resource study retains its partial boundary separately.
    case nullSpark
}

/// Ordered4229cc->429730..429e5a music and bitmap-resource continuation.
/// Dispatch/render and the enclosing caller's return remain subsequent work.
public enum OriginalCharacterMenuStartup {
    public struct Result {
        public let musicEntered: Bool
        public let resources: OriginalMenuResourceResult
    }

    /// Keep platform effects in the value-semantic environment until success.
    /// Music reads the previous-menu word before resource loading replaces it.
    /// Any throw, including a NULL-SPARK boundary or final observer, retains all
    /// four caller-owned values instead of publishing completed music alone.
    public static func run<Environment>(globals: inout OriginalStateRecord,
        music: inout OriginalMusicMemory, resources: inout OriginalMenuResourceLoading,
        environment: inout Environment,
        musicRequest: (OriginalMusicEvent, inout Environment) throws -> OriginalMusicResponse,
        allocate: (Int, inout Environment) throws -> OriginalInterfaceAllocation,
        source: (Int, String, inout Environment) throws -> OriginalBitmapInput,
        deviceResult: (Int, inout Environment) throws -> (surface: UInt32, colorKeyResult: Int32),
        afterMusic: (Bool, OriginalStateRecord, OriginalMusicMemory, inout Environment) throws -> Void = { _,_,_,_ in },
        checkpoint: (OriginalMenuResourceCheckpoint, OriginalStateRecord, [UInt32:OriginalLoadedBitmap], inout Environment) throws -> Void = { _,_,_,_ in },
        observe: (OriginalInterfaceEvent, inout Environment) throws -> Void = { _,_ in },
        beforeCommit: (Result, OriginalStateRecord, OriginalMusicMemory, OriginalMenuResourceLoading, inout Environment) throws -> Void = { _,_,_,_,_ in }) throws -> Result {
        try withMusic(globals: &globals, music: &music, resources: &resources, environment: &environment,
            musicRequest: musicRequest, afterMusic: afterMusic, beforeCommit: beforeCommit) { state,images,candidate in
                try images.load(globals: &state,
                    allocate: { try allocate($0, &candidate) },
                    source: { try source($0, $1, &candidate) },
                    deviceResult: { try deviceResult($0, &candidate) },
                    checkpoint: { try checkpoint($0, $1, $2, &candidate) },
                    observe: { try observe($0, &candidate) })
            }
    }

    /// The same menu entry transaction with whole image/surface/copy helpers.
    /// Own graph-log bytes and subsequent API dimensions survive at the recovered
    /// shared stack depth; current-call request masks remain independent.
    /// A rejected dependency or final observer retains all four caller values.
    public static func runWithSurfaceLoading<Environment>(globals: inout OriginalStateRecord,
        music: inout OriginalMusicMemory, resources: inout OriginalMenuResourceLoading,
        environment: inout Environment,
        musicRequest: (OriginalMusicEvent, inout Environment) throws -> OriginalMusicResponse,
        allocate: (Int, inout Environment) throws -> OriginalInterfaceAllocation,
        perform: @escaping (OriginalBitmapSurfaceLoading.Request, inout Environment) throws -> OriginalBitmapSurfaceLoading.Response,
        afterMusic: (Bool, OriginalStateRecord, OriginalMusicMemory, inout Environment) throws -> Void = { _,_,_,_ in },
        checkpoint: (OriginalMenuResourceCheckpoint, OriginalStateRecord, [UInt32:OriginalLoadedBitmap], inout Environment) throws -> Void = { _,_,_,_ in },
        observe: (OriginalInterfaceEvent, inout Environment) throws -> Void = { _,_ in },
        beforeCommit: (Result, OriginalStateRecord, OriginalMusicMemory, OriginalMenuResourceLoading, inout Environment) throws -> Void = { _,_,_,_,_ in }) throws -> Result {
        var loader = try OriginalBitmapSurfaceLoading.LoaderScratch()
        return try withMusic(globals: &globals, music: &music, resources: &resources, environment: &environment,
            musicRequest: { event,candidate in
                if event.kind == .format { try loader.graphLog(event.strings[1]) }
                return try musicRequest(event, &candidate)
            }, afterMusic: afterMusic, beforeCommit: beforeCommit) { state,images,candidate in
                try images.loadWithSurfaceLoading(globals: &state, context: &candidate,
                    loaderScratch: loader, allocate: allocate, perform: perform, checkpoint: checkpoint, observe: observe)
            }
    }

    private static func withMusic<Environment>(globals: inout OriginalStateRecord,
        music: inout OriginalMusicMemory, resources: inout OriginalMenuResourceLoading,
        environment: inout Environment,
        musicRequest: (OriginalMusicEvent, inout Environment) throws -> OriginalMusicResponse,
        afterMusic: (Bool, OriginalStateRecord, OriginalMusicMemory, inout Environment) throws -> Void,
        beforeCommit: (Result, OriginalStateRecord, OriginalMusicMemory, OriginalMenuResourceLoading, inout Environment) throws -> Void,
        load: (inout OriginalStateRecord, inout OriginalMenuResourceLoading, inout Environment) throws -> OriginalMenuResourceResult) throws -> Result {
        var state = globals, audio = music, images = resources, candidate = environment
        let entered = try OriginalMusicPlayback.enterMenu(globals: &state, memory: &audio) {
            try musicRequest($0, &candidate)
        }
        try afterMusic(entered, state, audio, &candidate)
        let loaded = try load(&state, &images, &candidate)
        guard loaded.continuation == .ready else { throw OriginalCharacterMenuStartupError.nullSpark }
        let result = Result(musicEntered: entered, resources: loaded)
        try beforeCommit(result, state, audio, images, &candidate)
        globals = state; music = audio; resources = images; environment = candidate
        return result
    }
}
