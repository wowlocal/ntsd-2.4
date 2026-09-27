import AVFAudio
import NTSDCore

/// Native PCM storage. Device creation acquires an owner, not an audio endpoint.
/// The original per-call records stay separate from AVFAudio's representation.
@MainActor public final class OriginalMacAudioBackend {
    public enum Boundary: Error, Equatable {
        case unsupported(String), owner(UInt32), unknownSamples, allocationBudget
        case allocationFailed, foreignPreparation, stalePreparation, repeatedPreparation
    }
    public struct Format: Equatable, Sendable {
        public let channels: Int, rate: UInt32, bits: Int, alignment: Int
    }
    public struct Observation {
        public let token: UInt32, device: UInt32, binding: OriginalWaveBinding
        public let format: Format, raw: OriginalAudioBytes, activeLock: UInt32?
        public let ready: Bool
    }
    public struct Operation {
        public let request: OriginalStartupRequest, response: OriginalStartupResponse
    }
    public struct Result {
        public let response: OriginalStartupResponse
        public let resources: [any OriginalApplicationStartupResource]
    }
    public typealias Diagnostic = (OriginalStartupRequest) throws -> OriginalStartupResponse
    public class Resource: OriginalApplicationStartupResource {
        public let token: UInt32
        fileprivate init(_ token: UInt32) { self.token = token }
    }
    private final class Device: Resource { var window: OriginalMacWindowBackend.WindowLease? }
    private final class Buffer: Resource {
        let device: Device, binding: OriginalWaveBinding, format: Format, pcm: AVAudioPCMBuffer
        var raw: OriginalStateRecord, active: UInt32?
        var volume: Int32?
        init(_ token: UInt32,_ device: Device,_ binding: OriginalWaveBinding,_ format: Format,
            _ pcm: AVAudioPCMBuffer,_ raw: OriginalStateRecord) {
            self.device = device;self.binding = binding;self.format = format;self.pcm = pcm;self.raw = raw
            super.init(token)
        }
    }
    private final class Region: Resource {
        let buffer: Buffer
        init(_ token: UInt32,_ buffer: Buffer) { self.buffer = buffer;super.init(token) }
    }
    public final class Prepared {
        fileprivate let owner: AnyObject, generation: UInt64
        public let request: OriginalStartupRequest
        fileprivate var consumed = false
        fileprivate init(_ owner: AnyObject,_ generation: UInt64,_ request: OriginalStartupRequest) {
            self.owner = owner;self.generation = generation;self.request = request
        }
    }
    private final class Identity {}
    private let identity = Identity(), maximumBytes: Int, diagnostic: Diagnostic?
    public let loadingDomain = OriginalAudioIdentityDomain()
    public let windows: OriginalMacWindowBackend
    private var generation: UInt64 = 0
    private var devices: [UInt32:Device] = [:], buffers: [UInt32:Buffer] = [:], regions: [UInt32:Region] = [:]
    public private(set) var allocatedBytes = 0
    public private(set) var operations: [Operation] = []
    public var deviceTokens: [UInt32] { devices.keys.sorted() }
    public var bufferTokens: [UInt32] { buffers.keys.sorted() }
    public var retainedResources: [any OriginalApplicationStartupResource] {
        devices.values.map { $0 as any OriginalApplicationStartupResource } +
        buffers.values.map { $0 as any OriginalApplicationStartupResource } +
        regions.values.map { $0 as any OriginalApplicationStartupResource }
    }
    public init(windows: OriginalMacWindowBackend,maximumBytes: Int = 128*1024*1024,
        diagnostic: Diagnostic? = nil) {
        self.windows = windows;self.maximumBytes = maximumBytes;self.diagnostic = diagnostic
    }
    private func require(_ condition: Bool,_ reason: String) throws {
        guard condition else { throw Boundary.unsupported(reason) }
    }
    private func device(_ token: UInt32) throws -> Device {
        guard let value = devices[token] else { throw Boundary.owner(token) };return value
    }
    private func buffer(_ token: UInt32,_ binding: OriginalWaveBinding) throws -> Buffer {
        guard let value = buffers[token],value.binding == binding else { throw Boundary.owner(token) };return value
    }
    private func region(_ token: UInt32,_ binding: OriginalWaveBinding) throws -> Region {
        guard let value = regions[token],value.buffer.binding == binding,value.buffer.active == token else {
            throw Boundary.owner(token)
        };return value
    }
    private func format(_ q: OriginalWaveRequest) throws -> (Format,Int) {
        let d = try q.structures[0].record(),f = try q.structures[1].record()
        let count = Int(try d.integer(at:8,as:UInt32.self))
        try require(try d.integer(at:0,as:UInt32.self) == 36 && d.integer(at:4,as:UInt32.self) == 0xe0 &&
            d.bytes.dropFirst(12).allSatisfy { $0 == 0 },"WAV descriptor")
        let channels = Int(try f.integer(at:2,as:UInt16.self)),rate = try f.integer(at:4,as:UInt32.self)
        let average = try f.integer(at:8,as:UInt32.self),alignment = Int(try f.integer(at:12,as:UInt16.self))
        let bits = Int(try f.integer(at:14,as:UInt16.self))
        try require(try f.integer(at:0,as:UInt16.self) == 1 && [1,2].contains(channels) &&
            [8,16].contains(bits) && rate > 0 && alignment == channels*bits/8 &&
            UInt64(average) == UInt64(rate)*UInt64(alignment),"PCM format")
        try require(count > 0 && count <= 2_000_000 && count%alignment == 0,"PCM extent")
        return (.init(channels:channels,rate:rate,bits:bits,alignment:alignment),count)
    }
    private func validate(_ request: OriginalStartupRequest) throws {
        switch request {
        case .sound(let q):
            try require(q.wave == nil,"nested sound event")
            switch q.kind {
            case "deviceCreate":try require(q.arguments == [0,0x44eecc,0] && q.strings.isEmpty,"device creation")
            case "cooperativeLevel":
                try require(q.arguments.count == 3 && q.arguments[2] == 1 && q.strings.isEmpty,"audio cooperative level")
                _ = try device(q.arguments[0]);try require(try !windows.observation(q.arguments[1]).closed,"closed audio window")
            case "message":try require(diagnostic != nil && q.arguments == [0,0] && q.strings.count == 2,"sound diagnostic")
            default:throw Boundary.unsupported("sound request")
            }
        case .waveAudio(let binding,let q):
            try q.validate();_ = try device(binding.device)
            switch q.event.kind {
            case .create:
                try require(q.event.arguments == [binding.device,0],"WAV device binding");_ = try format(q)
            case .lock:
                let b = try buffer(q.event.arguments[0],binding)
                try require(q.event.arguments == [b.token,0,UInt32(b.raw.bytes.count),0] && b.active == nil,"whole WAV Lock")
            case .copy:
                let r = try region(q.target!,binding)
                try require(q.event.arguments == [0,0,UInt32(r.buffer.raw.bytes.count)],"whole first Lock region")
            case .unlock:
                let b = try buffer(q.event.arguments[0],binding)
                guard let active = b.active else { throw Boundary.owner(q.event.arguments[1]) }
                try require(q.event.arguments == [b.token,active,UInt32(b.raw.bytes.count),0,0],"WAV Unlock region")
                guard b.raw.defined.allSatisfy({ $0 }) else { throw Boundary.unknownSamples }
            case .restore:_ = try buffer(q.event.arguments[0],binding)
            case .message:try require(diagnostic != nil,"WAV diagnostic")
            default:throw Boundary.unsupported("WAV request")
            }
        default:throw Boundary.unsupported("audio request family")
        }
    }
    public func prepare(_ request: OriginalStartupRequest) throws -> Prepared {
        try validate(request);return Prepared(identity,generation,request)
    }
    public func perform(_ prepared: Prepared) throws -> Result {
        guard prepared.owner === identity else { throw Boundary.foreignPreparation }
        guard !prepared.consumed else { throw Boundary.repeatedPreparation }
        guard prepared.generation == generation else { throw Boundary.stalePreparation }
        try validate(prepared.request);prepared.consumed = true;generation &+= 1
        let response: OriginalStartupResponse
        var retained: [any OriginalApplicationStartupResource] = []
        switch prepared.request {
        case .sound(let q):
            switch q.kind {
            case "deviceCreate":
                let d = try Device(windows.identities.take());devices[d.token] = d;retained = [d]
                response = .sound(.init(result:0,output:d.token))
            case "cooperativeLevel":
                let d = try device(q.arguments[0]),w = try windows.lease(q.arguments[1]);d.window = w;retained = [d,w]
                response = .sound(.init(result:0))
            default:response = try diagnostic!(prepared.request)
            }
        case .waveAudio(let binding,let q):
            switch q.event.kind {
            case .create:
                let (f,count) = try format(q),frames = count/f.alignment
                let bytes = count*2+frames*f.channels*MemoryLayout<Float>.size
                guard bytes <= maximumBytes-allocatedBytes else { throw Boundary.allocationBudget }
                guard let format = AVAudioFormat(standardFormatWithSampleRate:Double(f.rate),channels:AVAudioChannelCount(f.channels)),
                      let pcm = AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(frames)) else { throw Boundary.allocationFailed }
                pcm.frameLength = 0
                let d = try device(binding.device),raw = try OriginalStateRecord(bytes:Array(repeating:0xa5,count:count),defined:Array(repeating:false,count:count))
                let b = try Buffer(windows.identities.take(),d,binding,f,pcm,raw)
                buffers[b.token] = b;allocatedBytes += bytes;retained = [d,b]
                response = .waveAudio(.created(0,b.token))
            case .lock:
                let b = try buffer(q.event.arguments[0],binding),r = try Region(windows.identities.take(),b)
                regions[r.token] = r;b.active = r.token;retained = [b,r]
                response = .waveAudio(.locked(0,.init(firstPointer:r.token,firstCount:b.raw.bytes.count,
                    secondPointer:0,secondCount:0,first:.init(token:r.token,storage:.init(b.raw)),second:nil)))
            case .copy:
                let r = try region(q.target!,binding),b = r.buffer
                b.raw = try .init(bytes:q.bytes!,defined:q.defined!);b.pcm.frameLength = 0;retained = [b,r]
                response = .waveAudio(.copied)
            case .unlock:
                let b = try buffer(q.event.arguments[0],binding),f = b.format
                guard let channels = b.pcm.floatChannelData else { throw Boundary.allocationFailed }
                let frames = b.raw.bytes.count/f.alignment
                for frame in 0..<frames { for channel in 0..<f.channels {
                    let index = frame*f.alignment+channel*(f.bits/8),value: Float
                    if f.bits == 8 { value = Float(Int(b.raw.bytes[index])-128)/128 }
                    else {
                        let word = UInt16(b.raw.bytes[index]) | (UInt16(b.raw.bytes[index+1]) << 8)
                        value = Float(Int16(bitPattern:word))/32768
                    }
                    channels[channel][frame] = value
                } }
                b.pcm.frameLength = AVAudioFrameCount(frames);retained = [b,regions[b.active!]!];b.active = nil
                response = .waveAudio(.result(0))
            case .restore:retained = [try buffer(q.event.arguments[0],binding)];response = .waveAudio(.result(0))
            default:response = try diagnostic!(prepared.request)
            }
        default:throw Boundary.unsupported("audio request family")
        }
        try require(prepared.request.accepts(response),"diagnostic reply family")
        operations.append(.init(request:prepared.request,response:response))
        return .init(response:response,resources:retained)
    }
    public func observation(_ token: UInt32) throws -> Observation {
        guard let b = buffers[token] else { throw Boundary.owner(token) }
        return .init(token:token,device:b.device.token,binding:b.binding,format:b.format,raw:.init(b.raw),
            activeLock:b.active,ready:b.pcm.frameLength > 0)
    }
    public struct LoadingResult {
        public let response: OriginalLoadingAudioRequest.Reply
        public let resources: [any OriginalApplicationStartupResource]
    }
    public struct LoadingOperation {
        public let request: OriginalLoadingAudioRequest, response: OriginalLoadingAudioRequest.Reply
    }
    public final class LoadingPrepared {
        fileprivate let owner: AnyObject, generation: UInt64, wave: Prepared?
        public let request: OriginalLoadingAudioRequest
        fileprivate var consumed = false
        fileprivate init(_ owner: AnyObject,_ generation: UInt64,_ request: OriginalLoadingAudioRequest,_ wave: Prepared?) {
            self.owner = owner;self.generation = generation;self.request = request;self.wave = wave
        }
    }
    public private(set) var loadingOperations: [LoadingOperation] = []
    private func loadingRequest(_ q: OriginalLoadingAudioRequest) throws -> Prepared? {
        switch q {
        case .wave(let domain,let binding,let wave):
            try require(domain == .opaque(loadingDomain),"foreign loading audio domain")
            return try prepare(.waveAudio(binding,wave))
        case .volume(let domain,let binding,let token,let volume):
            try require(domain == .opaque(loadingDomain),"foreign loading audio domain")
            let b = try buffer(token,binding)
            try require(volume == -10000 && b.active == nil && b.pcm.frameLength > 0,"registered SetVolume")
            return nil
        }
    }
    public func prepareLoading(_ request: OriginalLoadingAudioRequest) throws -> LoadingPrepared {
        LoadingPrepared(identity,generation,request,try loadingRequest(request))
    }
    public func performLoading(_ prepared: LoadingPrepared) throws -> LoadingResult {
        guard prepared.owner === identity else { throw Boundary.foreignPreparation }
        guard !prepared.consumed else { throw Boundary.repeatedPreparation }
        guard prepared.generation == generation else { throw Boundary.stalePreparation }
        let result: LoadingResult
        switch prepared.request {
        case .wave(let domain,let binding,let q):
            guard let wave = prepared.wave else { throw Boundary.foreignPreparation }
            prepared.consumed = true
            let served = try perform(wave)
            guard case .waveAudio(let response) = served.response else { throw Boundary.unsupported("loading reply") }
            let lease = try q.event.kind == .unlock
                ? resourceLease(binding,buffer:q.event.arguments[0],region:q.event.arguments[1]) : nil
            result = .init(response:.wave(domain,response,lease),resources:served.resources)
        case .volume(let domain,let binding,let token,let volume):
            _ = try loadingRequest(prepared.request)
            prepared.consumed = true;generation &+= 1
            let b = try buffer(token,binding);b.volume = volume
            // Explicit Native scalar ownership, not DSP gain or endpoint output.
            result = .init(response:.volume(domain,0),resources:[b])
        }
        loadingOperations.append(.init(request:prepared.request,response:result.response))
        return result
    }
    public func volumeObservation(_ token: UInt32) throws -> Int32? {
        guard let buffer = buffers[token] else { throw Boundary.owner(token) };return buffer.volume
    }
    private func resourceLease(_ binding: OriginalWaveBinding,buffer token: UInt32,region: UInt32) throws -> OriginalWaveResourceLease {
        let b = try buffer(token,binding)
        guard let r = regions[region],r.buffer === b,b.active == nil,b.pcm.frameLength > 0 else { throw Boundary.owner(region) }
        return .init(domain:loadingDomain,binding:binding,buffer:token,regions:[region:b.raw],resources:[b.device,b,r])
    }
    /// Called on completed actual startup results before entering Core loading.
    /// The retained lease makes later handoffs independent of this backend's life.
    public func ownership(_ binding: OriginalWaveBinding,result: OriginalWaveLoadResult) throws -> OriginalWaveOwnership {
        guard let reply = result.lockReplies.last,case .locked(_,let lock?) = reply,
            lock.secondPointer == 0 else { throw Boundary.unsupported("completed Native WAV ownership") }
        let lease = try resourceLease(binding,buffer:result.output,region:lock.firstPointer)
        let owner = OriginalWaveOwnership(binding:binding,result:result,domain:.opaque(loadingDomain),lease:lease)
        _ = try owner.addressedRegions();return owner
    }
    /// A consumer receives independent storage, not mutable access to our owner.
    public func pcmSnapshot(_ token: UInt32) throws -> AVAudioPCMBuffer {
        guard let b = buffers[token] else { throw Boundary.owner(token) }
        guard b.pcm.frameLength > 0,b.raw.defined.allSatisfy({ $0 }) else { throw Boundary.unknownSamples }
        guard let copy = AVAudioPCMBuffer(pcmFormat:b.pcm.format,frameCapacity:b.pcm.frameLength),
              let dst = copy.floatChannelData,let src = b.pcm.floatChannelData else { throw Boundary.allocationFailed }
        copy.frameLength = b.pcm.frameLength
        for channel in 0..<b.format.channels { for frame in 0..<Int(copy.frameLength) { dst[channel][frame] = src[channel][frame] } }
        return copy
    }
}
