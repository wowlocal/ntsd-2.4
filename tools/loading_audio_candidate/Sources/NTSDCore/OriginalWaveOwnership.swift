/// Opaque identity domains are compared by owner identity, never by an integer
/// range. No host pointer or source address is encoded in this value.
public final class OriginalAudioIdentityDomain: Equatable {
    public init() {}
    public static func == (a: OriginalAudioIdentityDomain,b: OriginalAudioIdentityDomain) -> Bool { a === b }
}

public enum OriginalWaveRegionDomain: Equatable {
    case addressed
    case opaque(OriginalAudioIdentityDomain)
}

/// Issued by an actual service after a completed buffer unlock. Retains physical
/// owners as well as their immutable raw/mask snapshot across Core handoffs.
public struct OriginalWaveResourceLease {
    public let domain: OriginalAudioIdentityDomain, binding: OriginalWaveBinding, buffer: UInt32
    public let regions: [UInt32:OriginalStateRecord]
    public let resources: [any OriginalApplicationStartupResource]
    public init(domain: OriginalAudioIdentityDomain,binding: OriginalWaveBinding,buffer: UInt32,
        regions: [UInt32:OriginalStateRecord],resources: [any OriginalApplicationStartupResource]) {
        self.domain = domain;self.binding = binding;self.buffer = buffer
        self.regions = regions;self.resources = resources
    }
}

/// An attempted WAV may be incomplete. Ownership is validated only when the
/// caller reaches a consumer requiring completed PCM, preserving false returns
/// and short-read temporaries at the earlier common-loading boundary.
public struct OriginalWaveOwnership {
    public enum Boundary: Error, Equatable { case incomplete, provenance, foreignDomain, binding }
    public let binding: OriginalWaveBinding, result: OriginalWaveLoadResult, domain: OriginalWaveRegionDomain
    public let legacy: OriginalWavePlatform?
    public let lease: OriginalWaveResourceLease?
    public init(binding: OriginalWaveBinding,result: OriginalWaveLoadResult,legacy: OriginalWavePlatform) {
        self.binding = binding;self.result = result;self.legacy = legacy
        domain = .addressed;lease = nil
    }
    public init(binding: OriginalWaveBinding,result: OriginalWaveLoadResult,
        domain: OriginalWaveRegionDomain,lease: OriginalWaveResourceLease? = nil) {
        self.binding = binding;self.result = result;self.domain = domain;self.lease = lease;legacy = nil
    }
    public func matches(_ value: OriginalWaveLoadResult) -> Bool {
        result.exit == value.exit && result.returned == value.returned && result.output == value.output &&
        result.temporary == value.temporary && result.temporaryLive == value.temporaryLive &&
        result.first == value.first && result.second == value.second && result.format == value.format &&
        result.descriptor == value.descriptor && result.initialStorage == value.initialStorage &&
        result.lockReplies == value.lockReplies && result.regions == value.regions
    }
    public func validate(device: UInt32,destination: UInt32,output: UInt32,
        domain expected: OriginalWaveRegionDomain) throws {
        guard binding.device == device,binding.destination == destination,result.output == output else { throw Boundary.binding }
        guard domain == expected else { throw Boundary.foreignDomain }
        _ = try addressedRegions()
    }
    /// Complete source ownership checks remain here. Opaque owners deliberately
    /// return no address intervals, after proving their actual lease and regions.
    public func addressedRegions() throws -> [(token: UInt32,count: Int)] {
        guard result.exit == .returned,result.returned == 1,!result.temporaryLive,
            binding.device != 0,result.output != 0,result.temporary != nil else { throw Boundary.incomplete }
        if let p = legacy {
            guard domain == .addressed,p.device == binding.device,p.destination == binding.destination,
                p.buffer == result.output,p.firstCount == result.first.bytes.count,
                p.secondCount == (result.second?.bytes.count ?? 0) else { throw Boundary.provenance }
            var spans = [(p.firstPointer,result.first.bytes.count)]
            if let second = result.second { spans.append((p.secondPointer,second.bytes.count)) }
            return spans
        }
        guard let reply = result.lockReplies.last,case .locked(_,let lock?) = reply,
            lock.firstPointer != 0,let first = result.regions[lock.firstPointer],
            first == result.first,lock.first?.token == lock.firstPointer,
            lock.firstCount >= 0,lock.firstCount <= first.bytes.count else { throw Boundary.provenance }
        var spans = [(lock.firstPointer,first.bytes.count)]
        var tokens: Set<UInt32> = [lock.firstPointer]
        if lock.secondPointer != 0 {
            guard let second = result.regions[lock.secondPointer],second == result.second,
                lock.second?.token == lock.secondPointer,lock.secondCount >= 0,
                lock.secondCount <= second.bytes.count else { throw Boundary.provenance }
            if tokens.insert(lock.secondPointer).inserted { spans.append((lock.secondPointer,second.bytes.count)) }
        } else {
            guard result.second == nil else { throw Boundary.provenance }
        }
        guard Set(result.regions.keys) == tokens else { throw Boundary.provenance }
        switch domain {
        case .addressed:
            guard lease == nil else { throw Boundary.foreignDomain }
            return spans
        case .opaque(let identity):
            guard let lease,lease.domain === identity,lease.binding == binding,
                lease.buffer == result.output,lease.regions == result.regions,!lease.resources.isEmpty else {
                throw Boundary.provenance
            }
            return []
        }
    }
}
