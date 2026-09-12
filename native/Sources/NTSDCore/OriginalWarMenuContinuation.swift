extension OriginalWarSetup {
    /// Uses the recovered43ee50 image/surface/copy helpers for both owned War
    /// allocations. Own descriptor and GetDC producers update the later arena
    /// fields in the staged War owner; same-depth menu dimensions stay local.
    public static func advanceWithSurfaceLoading<Environment>(state: inout OriginalMatchPreparation,
        memory: inout OriginalWarMenuMemory,libraryText: inout OriginalLibSurfaceText?,
        environment: inout Environment,target: UInt32,input: OriginalFrontScreenBodyInput,fillBacking: [UInt8],
        allocate: (Int,inout Environment) throws -> OriginalInterfaceAllocation,
        perform: (OriginalBitmapSurfaceLoading.Request,inout Environment) throws -> OriginalBitmapSurfaceLoading.Response,
        bitmapStorage: (UInt32,inout Environment) throws -> OriginalStateRecord,
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord,OriginalWarMenuMemory,inout Environment) throws -> Void,
        observe: (OriginalFrontScreenEvent,inout Environment) throws -> Void = { _,_ in },
        resourceEvent: (OriginalInterfaceEvent,inout Environment) throws -> Void = { _,_ in },
        beforeResource: (Int,OriginalStateRecord,OriginalWarMenuMemory,inout Environment) throws -> Void = { _,_,_,_ in },
        prepare: (inout OriginalMatchPreparation,inout OriginalWarBitmapScratch,inout Environment) throws -> Bool = { _,_,_ in false },
        checkpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation,OriginalWarMenuMemory,inout Environment) throws -> Void = { _,_,_,_ in }) throws -> OriginalCharacterScreenExit {
        var scratch=try OriginalBitmapSurfaceLoading.CopyScratch(),loader=try OriginalBitmapSurfaceLoading.LoaderScratch()
        return try advance(state:&state,memory:&memory,libraryText:&libraryText,environment:&environment,target:target,input:input,fillBacking:fillBacking,
            allocate:allocate,construct:{ path,allocation,device,retained,environment in
                scratch.acquiredDC=retained.copyDimensions
                let bitmap=try OriginalBitmapConstructor.constructWithSurfaceLoading(path:path,optional:false,backing:allocation.backing,device:device,flags:0x40,
                    context:&environment,copyScratch:&scratch,loaderScratch:&loader,perform:perform)
                if let descriptor=loader.descriptorTail {
                    retained.loaderDimensions=descriptor
                    retained.loaderInvalidatedByPreparationMusicFormat=false
                }
                if let acquired=scratch.acquiredDC { retained.copyDimensions=acquired }
                return bitmap
            },bitmapStorage:bitmapStorage,draw:draw,observe:observe,resourceEvent:resourceEvent,beforeResource:beforeResource,prepare:prepare,checkpoint:checkpoint)
    }
}

extension OriginalCharacterMenuContinuation {
    /// Declared4229cc through the actual common menu startup, mode4 War menu
    /// and returned output, or BEFORE43a21f. Earlier mode4 CPU selection and
    /// battle preparation are separate dependencies. Pending source comparison.
    /// All effects, including those after War returns, share the outer transaction.
    public static func advanceWithWar<Environment>(state: inout OriginalMatchPreparation,
        memory: inout OriginalMenuPresentationMemory,music: inout OriginalMusicMemory,
        resources: inout OriginalMenuResourceLoading,war: inout OriginalWarMenuMemory,libraryText: inout OriginalLibSurfaceText,
        environment: inout Environment,target: UInt32,input: OriginalFrontScreenBodyInput,
        warPreparation: ((inout OriginalMatchPreparation,inout OriginalMenuPresentationMemory,inout OriginalMusicMemory,inout OriginalWarBitmapScratch,inout Environment) throws -> Void)? = nil,
        outputInput: OriginalMenuPresentationInput,milliseconds: UInt32,
        musicRequest: (OriginalMusicEvent,inout Environment) throws -> OriginalMusicResponse,
        allocate: (Int,inout Environment) throws -> OriginalInterfaceAllocation,
        warAllocate: (Int,inout Environment) throws -> OriginalInterfaceAllocation,
        perform: @escaping (OriginalBitmapSurfaceLoading.Request,inout Environment) throws -> OriginalBitmapSurfaceLoading.Response,
        warPerform: (OriginalBitmapSurfaceLoading.Request,inout Environment) throws -> OriginalBitmapSurfaceLoading.Response,
        bitmapStorage: (UInt32,inout Environment) throws -> OriginalStateRecord,
        resourceEvent: (OriginalInterfaceEvent,inout Environment) throws -> Void = { _,_ in },
        warResourceEvent: (OriginalInterfaceEvent,inout Environment) throws -> Void = { _,_ in },
        warBeforeResource: (Int,OriginalStateRecord,OriginalWarMenuMemory,inout Environment) throws -> Void = { _,_,_,_ in },
        afterMusic: (Bool,OriginalStateRecord,OriginalMusicMemory,inout Environment) throws -> Void = { _,_,_,_ in },
        resourceCheckpoint: (OriginalMenuResourceCheckpoint,OriginalStateRecord,[UInt32:OriginalLoadedBitmap],inout Environment) throws -> Void = { _,_,_,_ in },
        afterStartup: (OriginalCharacterMenuStartup.Result,OriginalStateRecord,OriginalMusicMemory,OriginalMenuResourceLoading,inout Environment) throws -> Void = { _,_,_,_,_ in },
        draw: (OriginalCharacterScreenDraw,OriginalStateRecord,OriginalMenuResourceLoading,inout Environment) throws -> Void,
        warDraw: (OriginalCharacterScreenDraw,OriginalStateRecord,OriginalWarMenuMemory,inout Environment) throws -> Void,
        outputDraw: ([UInt32],OriginalStateRecord,OriginalMenuPresentationMemory,inout Environment) throws -> Void,
        observe: (OriginalFrontScreenEvent,inout Environment) throws -> Void = { _,_ in },
        characterCheckpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation,inout Environment) throws -> Void = { _,_,_ in },
        warCheckpoint: (OriginalCharacterScreenCheckpoint,OriginalMatchPreparation,OriginalWarMenuMemory,inout Environment) throws -> Void = { _,_,_,_ in },
        checkpoint: (String,OriginalStateRecord,OriginalStateRecord,inout Environment) throws -> Void = { _,_,_,_ in }) throws -> OriginalCharacterScreenExit {
        var owned=war
        // The common driver stages state/resources/text/environment until its
        // output succeeds. Keep this additional owner staged across that call.
        let end=try advance(state:&state,memory:&memory,music:&music,resources:&resources,libraryText:&libraryText,environment:&environment,
            target:target,input:input,warStage:{ scene,text,presentation,audio,environment in
                try OriginalWarSetup.advanceWithSurfaceLoading(state:&scene,memory:&owned,libraryText:&text,environment:&environment,
                    target:target,input:input,fillBacking:[UInt8](repeating:0,count:100),allocate:warAllocate,perform:warPerform,
                    bitmapStorage:bitmapStorage,draw:warDraw,observe:observe,resourceEvent:warResourceEvent,beforeResource:warBeforeResource,prepare:{ value,scratch,context in
                        guard let warPreparation else { return false }
                        try warPreparation(&value,&presentation,&audio,&scratch,&context);return true
                    },checkpoint:warCheckpoint)
            },outputInput:outputInput,milliseconds:milliseconds,musicRequest:musicRequest,allocate:allocate,perform:perform,
            resourceEvent:resourceEvent,afterMusic:afterMusic,resourceCheckpoint:resourceCheckpoint,afterStartup:afterStartup,
            draw:draw,outputDraw:outputDraw,observe:observe,characterCheckpoint:characterCheckpoint,checkpoint:checkpoint)
        war=owned;return end
    }
}
