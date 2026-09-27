/// Input composition for the one shared WAV algorithm. Legacy conversion and
/// its optional request factory are deferred until the original load call.
public enum OriginalWavePreparation {
    case legacy(OriginalWavePlatform, OriginalWaveRequest.Factory? = nil)
    case observed(OriginalWaveInput, OriginalWaveRequest.Handler, OriginalWaveRegionDomain,
                  () -> OriginalWaveResourceLease?)

    public var destination: UInt32 {
        switch self { case .legacy(let p,_):return p.destination;case .observed(let p,_,_,_):return p.destination }
    }
    public var device: UInt32 {
        switch self { case .legacy(let p,_):return p.device;case .observed(let p,_,_,_):return p.device }
    }
    public var stream: UInt32 {
        switch self { case .legacy(let p,_):return p.stream;case .observed(let p,_,_,_):return p.stream }
    }
    public var legacyPlatform: OriginalWavePlatform? {
        if case .legacy(let p,_) = self { return p };return nil
    }
    public func load(path: [UInt8],file: [UInt8],output: UInt32,
        outputStored: (UInt32) throws -> Void,observe: (OriginalWaveEvent) throws -> Void) throws -> OriginalWaveLoadResult {
        switch self {
        case .legacy(let p,let factory):
            return try OriginalWaveLoader.load(path:path,file:file,output:output,platform:p,
                outputStored:outputStored,audio:try factory?(p),observe:observe)
        case .observed(let input,let request,_,_):
            return try OriginalWaveLoader.loadObserved(path:path,file:file,output:output,input:input,
                request:request,outputStored:outputStored,observe:observe)
        }
    }
    public func ownership(index: Int,path: String,result: OriginalWaveLoadResult) -> OriginalWaveOwnership {
        let binding = OriginalWaveBinding(index,path,destination,device)
        switch self {
        case .legacy(let p,_):return .init(binding:binding,result:result,legacy:p)
        case .observed(_,_,let domain,let lease):return .init(binding:binding,result:result,domain:domain,lease:lease())
        }
    }
}
