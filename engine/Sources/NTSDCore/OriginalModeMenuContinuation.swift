public enum OriginalModeMenuContinuationError: Error, Equatable {
    case requiresMenuBody(Int32)
}

/// Declared4229cc menu continuation through the selected mode screen and
///422ab8 return. The earlier tick body and outer424746 caller are separate.
/// Keep every state owner and caller event buffer staged across all children.
public enum OriginalModeMenuContinuation {
    public static func advance<Environment>(world: inout OriginalStateRecord,actors: [OriginalStateRecord],
        globals: inout OriginalStateRecord,memory: inout OriginalMenuPresentationMemory,
        music: inout OriginalMusicMemory,resources: inout OriginalMenuResourceLoading,
        local: inout OriginalStateRecord,libraryText: inout OriginalLibSurfaceText,
        environment: inout Environment,worldAddress: UInt32,target: UInt32,
        screenInput: OriginalFrontScreenBodyInput,outputInput: OriginalMenuPresentationInput,
        milliseconds: UInt32,
        musicRequest: (OriginalMusicEvent,inout Environment) throws -> OriginalMusicResponse,
        allocate: (Int,inout Environment) throws -> OriginalInterfaceAllocation,
        perform: @escaping (OriginalBitmapSurfaceLoading.Request,inout Environment) throws -> OriginalBitmapSurfaceLoading.Response,
        resourceEvent: (OriginalInterfaceEvent,inout Environment) throws -> Void = { _,_ in },
        afterMusic: (Bool,OriginalStateRecord,OriginalMusicMemory,inout Environment) throws -> Void = { _,_,_,_ in },
        resourceCheckpoint: (OriginalMenuResourceCheckpoint,OriginalStateRecord,[UInt32:OriginalLoadedBitmap],inout Environment) throws -> Void = { _,_,_,_ in },
        afterStartup: (OriginalCharacterMenuStartup.Result,OriginalStateRecord,OriginalMusicMemory,OriginalMenuResourceLoading,inout Environment) throws -> Void = { _,_,_,_,_ in },
        background: (inout OriginalStateRecord,inout OriginalMenuPresentationMemory,inout Environment) throws -> Void,
        update: (inout OriginalStateRecord,inout Environment) throws -> Void,
        draw: ([UInt32],OriginalStateRecord,OriginalMenuPresentationMemory,inout Environment) throws -> Void,
        observe: (OriginalFrontScreenEvent,inout Environment) throws -> Void = { _,_ in },
        afterScreen: (OriginalModeScreenExit,OriginalStateRecord,OriginalMenuPresentationMemory,OriginalStateRecord,OriginalLibSurfaceText,inout Environment) throws -> Void = { _,_,_,_,_,_ in },
        checkpoint: (String,OriginalStateRecord,OriginalStateRecord,inout Environment) throws -> Void = { _,_,_,_ in }) throws -> OriginalModeScreenExit {
        var scene=world,state=globals,owned=memory,audio=music,images=resources,scratch=local,text=libraryText,candidate=environment
        _ = try OriginalCharacterMenuStartup.runWithSurfaceLoading(globals:&state,music:&audio,resources:&images,environment:&candidate,
            musicRequest:musicRequest,allocate:allocate,perform:perform,afterMusic:afterMusic,checkpoint:resourceCheckpoint,observe:resourceEvent,beforeCommit:afterStartup)
        guard try OriginalModeScreen.selectsModeScreen(globals:&state) else {
            throw OriginalModeMenuContinuationError.requiresMenuBody(try state.integer(at:0x44d020-OriginalMatchPreparation.globalBase,as:Int32.self))
        }
        let end=try OriginalModeScreen.advanceWithLibraryPanel(world:scene,actors:actors,globals:&state,memory:&owned,
            local:&scratch,libraryText:&text,worldAddress:worldAddress,target:target,input:screenInput,
            fillBacking:[UInt8](repeating:0,count:100),background:{ try background(&$0,&$1,&candidate) },
            update:{ try update(&$0,&candidate) },milliseconds:{ milliseconds },
            draw:{ try draw($0,$1,$2,&candidate) },observe:{ try observe($0,&candidate) })
        try afterScreen(end,state,owned,scratch,text,&candidate)
        if end == .returned {
            try OriginalMenuReturn.advanceWithLibrary(world:&scene,globals:&state,memory:&owned,libraryText:&text,
                input:outputInput,milliseconds:milliseconds,fillBacking:[UInt8](repeating:0,count:100),wholeEarlyReturn:false,
                draw:{ try draw($0,$1,$2,&candidate) },observe:{ try observe($0,&candidate) },
                checkpoint:{ try checkpoint($0,$1,$2,&candidate) })
        }
        world=scene;globals=state;memory=owned;music=audio;resources=images;local=scratch;libraryText=text;environment=candidate
        return end
    }
}
