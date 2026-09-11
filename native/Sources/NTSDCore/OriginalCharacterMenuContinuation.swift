/// Declared4229cc through fresh/cached menu resources, the human character
/// body and actual422ab8 return. Selection stages remain explicit continuations.
/// External observers must buffer effects in the staged value environment.
public enum OriginalCharacterMenuContinuation {
    public static func advance<Environment>(state: inout OriginalMatchPreparation,
        memory: inout OriginalMenuPresentationMemory,music: inout OriginalMusicMemory,
        resources: inout OriginalMenuResourceLoading,libraryText: inout OriginalLibSurfaceText,
        environment: inout Environment,target: UInt32,input: OriginalFrontScreenBodyInput,
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
        let end = try OriginalCharacterScreen.advanceWithLibrary(state:&scene,libraryText:&text,selectionAtEntry:startup.resources.selectionAtEntry,
            target:target,input:input,fillBacking:[UInt8](repeating:0,count:100),
            draw:{ try draw($0,$1,images,&candidate) },observe:{ try observe($0,&candidate) },
            checkpoint:{ try characterCheckpoint($0,$1,&candidate) },includeTailCheckpoint:true)
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
