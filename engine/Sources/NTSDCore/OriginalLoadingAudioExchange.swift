public enum OriginalLoadingAudioRequest: OriginalExchangeRequest {
    public enum Reply {
        case wave(OriginalWaveRegionDomain,OriginalWaveResponse,OriginalWaveResourceLease?)
        case volume(OriginalWaveRegionDomain,Int32)
    }
    case wave(OriginalWaveRegionDomain,OriginalWaveBinding,OriginalWaveRequest)
    case volume(OriginalWaveRegionDomain,OriginalWaveBinding,UInt32,Int32)
    public func accepts(_ response: Reply) -> Bool {
        switch (self,response) {
        case let (.wave(domain,binding,q),.wave(replyDomain,r,lease)):
            guard domain == replyDomain,q.accepts(r) else { return false }
            if let lease {
                guard case .opaque(let identity) = domain,q.event.kind == .unlock,
                    lease.domain === identity,lease.binding == binding,lease.buffer == q.event.arguments.first else { return false }
            }
            return true
        case let (.volume(domain,_,_,_),.volume(replyDomain,_)):return domain == replyDomain
        default:return false
        }
    }
}
public typealias OriginalLoadingAudioExchange = OriginalRequestExchange<
    OriginalLoadingAudioRequest, any OriginalApplicationStartupResource>

/// One attempt owns this cursor. It performs no IO; resources are retained by
/// the consumed response lease and then by the returned WaveOwnership.
public final class OriginalLoadingAudioContext {
    public let domain: OriginalWaveRegionDomain
    public private(set) var cursor: OriginalLoadingAudioExchange.Cursor
    private final class Owner { var lease: OriginalWaveResourceLease? }
    public init(domain: OriginalWaveRegionDomain,cursor: OriginalLoadingAudioExchange.Cursor) {
        self.domain = domain;self.cursor = cursor
    }
    public func prepare(_ binding: OriginalWaveBinding,file: OriginalWaveFileInput) -> OriginalWavePreparation {
        let owner = Owner()
        return .observed(file.bind(destination:binding.destination,device:binding.device),{ q in
            let response = try self.cursor.response(for:.wave(self.domain,binding,q))
            guard case .wave(_,let value,let lease) = response else { throw OriginalWaveOwnership.Boundary.provenance }
            if q.event.kind == .unlock { owner.lease = lease }
            return value
        },domain,{ owner.lease })
    }
    public func volume(_ binding: OriginalWaveBinding,buffer: UInt32,value: Int32) throws -> Int32 {
        let response = try cursor.response(for:.volume(domain,binding,buffer,value))
        guard case .volume(_,let value) = response else { throw OriginalWaveOwnership.Boundary.provenance }
        return value
    }
}
