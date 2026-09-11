/// Declared4229cc through fresh/cached menu resources, the human character
/// body/VS selection and actual422ab8 return, or the42cf8a match-prelude boundary.
/// External observers must buffer effects in the staged value environment.
public enum OriginalCharacterMenuContinuation {
    public static func advance<Environment>(state: inout OriginalMatchPreparation,
        memory: inout OriginalMenuPresentationMemory,music: inout OriginalMusicMemory,
        resources: inout OriginalMenuResourceLoading,libraryText: inout OriginalLibSurfaceText,
        environment: inout Environment,includeTournamentBracket: Bool = false,includeTeamTournamentBracket: Bool = false,target: UInt32,input: OriginalFrontScreenBodyInput,
        tournamentPreparation: ((inout OriginalMatchPreparation,inout OriginalMenuPresentationMemory,inout Environment) throws -> Void)? = nil,
        teamTournamentPreparation: ((inout OriginalMatchPreparation,inout OriginalMenuPresentationMemory,inout Environment) throws -> Void)? = nil,
        outputInput: OriginalMenuPresentationInput,milliseconds: UInt32,
        musicRequest: (OriginalMusicEvent,inout Environment) throws -> OriginalMusicResponse,
        allocate: (Int,inout Environment) throws -> OriginalInterfaceAllocation,
        perform: @escaping (OriginalBitmapSurfaceLoading.Request,inout Environment) throws -> OriginalBitmapSurfaceLoading.Response,
        resourceEvent: (OriginalInterfaceEvent,inout Environment) throws -> Void = { _,_ in },
        afterMusic: (Bool,OriginalStateRecord,OriginalMusicMemory,inout Environment) throws -> Void = { _,_,_,_ in },
        resourceCheckpoint: (OriginalMenuResourceCheckpoint,OriginalStateRecord,[UInt32:OriginalLoadedBitmap],inout Environment) throws -> Void = { _,_,_,_ in },
        afterStartup: (OriginalCharacterMenuStartup.Result,OriginalStateRecord,OriginalMusicMemory,OriginalMenuResourceLoading,inout Environment) throws -> Void = { _,_,_,_,_ in },
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord,OriginalMenuResourceLoading,inout Environment) throws -> Void,
        outputDraw: ([UInt32],OriginalStateRecord,OriginalMenuPresentationMemory,inout Environment) throws -> Void,
        observe: (OriginalFrontScreenEvent,inout Environment) throws -> Void = { _,_ in },
        characterCheckpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation,inout Environment) throws -> Void = { _,_,_ in },
        checkpoint: (String,OriginalStateRecord,OriginalStateRecord,inout Environment) throws -> Void = { _,_,_,_ in }) throws -> OriginalCharacterScreenExit {
        var scene=state,owned=memory,audio=music,images=resources,text=libraryText,candidate=environment
        let startup = try OriginalCharacterMenuStartup.runWithSurfaceLoading(globals:&scene.globals,music:&audio,resources:&images,environment:&candidate,
            musicRequest:musicRequest,allocate:allocate,perform:perform,afterMusic:afterMusic,checkpoint:resourceCheckpoint,observe:resourceEvent,beforeCommit:afterStartup)
        let end = try OriginalMatchSelection.advanceWithLibrary(state:&scene,libraryText:&text,selectionAtEntry:startup.resources.selectionAtEntry,
            target:target,input:input,fillBacking:{ [UInt8](repeating:0,count:100) },
            draw:{ try draw($0,$1,images,&candidate) },observe:{ try observe($0,&candidate) },
            checkpoint:{ try characterCheckpoint($0,$1,&candidate) },tournamentStage:{ scene,local,text,initialize in
                guard includeTournamentBracket else { return try OriginalTournamentBracket.unavailable(&scene,&local,&text,initialize) }
                return try OriginalTournamentBracket.advance(state:&scene,locals:&local,libraryText:&text,initialize:initialize,target:target,fillBacking:[UInt8](repeating:0,count:100),
                    resumeMusic:{ state in try OriginalMusicPlayback.resumeMatch(globals:&state,memory:&audio) { try musicRequest($0,&candidate) } },
                    prepare:{ state in
                        guard let tournamentPreparation else { return false }
                        try tournamentPreparation(&state,&owned,&candidate);return true
                    },
                    draw:{ try draw($0,$1,images,&candidate) },observe:{ try observe($0,&candidate) },
                    checkpoint:{ try characterCheckpoint($0,$1,&candidate) })
            },teamTournamentStage:{ scene,local,text,initialize in
                guard includeTeamTournamentBracket else { return try OriginalTeamTournamentBracket.unavailable(&scene,&local,&text,initialize) }
                return try OriginalTeamTournamentBracket.advance(state:&scene,locals:&local,libraryText:&text,initialize:initialize,target:target,fillBacking:[UInt8](repeating:0,count:100),
                    resumeMusic:{ state in try OriginalMusicPlayback.resumeMatch(globals:&state,memory:&audio) { try musicRequest($0,&candidate) } },
                    prepare:{ state in
                        guard let teamTournamentPreparation else { return false }
                        try teamTournamentPreparation(&state,&owned,&candidate);return true
                    },
                    draw:{ try draw($0,$1,images,&candidate) },observe:{ try observe($0,&candidate) },
                    checkpoint:{ try characterCheckpoint($0,$1,&candidate) })
            })
        if end == .returned {
            try OriginalMenuReturn.advanceWithLibrary(world:&scene.world,globals:&scene.globals,memory:&owned,libraryText:&text,
                input:outputInput,milliseconds:milliseconds,fillBacking:[UInt8](repeating:0,count:100),wholeEarlyReturn:false,
                draw:{ try outputDraw($0,$1,$2,&candidate) },observe:{ try observe($0,&candidate) },
                checkpoint:{ try checkpoint($0,$1,$2,&candidate) })
        }
        state=scene;memory=owned;music=audio;resources=images;libraryText=text;environment=candidate
        return end
    }
}
