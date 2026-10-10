import Foundation
import NTSDCore

/// DirectSound secondary buffers as voices (APPLICATION_SOUND_EFFECTS_PLAN.md).
/// Declared platform policy, not EXE behaviour: one voice per buffer; Play
/// (0x30) starts at the play cursor, flag 1 loops; Stop (0x48) keeps the
/// cursor; SetCurrentPosition (0x34) moves it in bytes (frames by block
/// alignment); SetVolume (0x3c) and SetPan (0x40) are hundredths of a decibel
/// — gain 10^(v/2000), a positive pan attenuates the left channel and a
/// negative one the right. Voices sum and clip; linear interpolation
/// resamples. A one-shot voice that reaches its end stops with the cursor at 0.
/// A volume or pan outside DirectSound's range is rejected (DSERR_INVALIDPARAM)
/// and leaves the voice unchanged; callers ignore the result.
public final class OriginalMacSoundEffects: @unchecked Sendable {
    public enum Boundary: Error, Equatable { case method(UInt32), arguments(UInt32) }
    public struct Call: Equatable, Sendable {
        public let buffer: UInt32, method: UInt32, arguments: [UInt32]
        public init(buffer: UInt32, method: UInt32, arguments: [UInt32]) {
            self.buffer = buffer; self.method = method; self.arguments = arguments
        }
        /// `[buffer, vtable offset, arguments…]` as Core records a sound method.
        public init?(_ words: [UInt32]) {
            guard words.count >= 2 else { return nil }
            self.init(buffer:words[0],method:words[1],arguments:Array(words.dropFirst(2)))
        }
    }
    /// A buffer's PCM (one array per channel), its rate and block alignment,
    /// and the volume it was registered with.
    public struct Samples: Sendable {
        public let channels: [[Float]], rate: Double, blockAlign: Int, volume: Int32
        public init(channels: [[Float]], rate: Double, blockAlign: Int, volume: Int32) {
            self.channels = channels; self.rate = rate; self.blockAlign = blockAlign; self.volume = volume
        }
        var frames: Int { channels.first?.count ?? 0 }
    }
    public struct Voice: Equatable, Sendable {
        public var position = 0.0, playing = false, looping = false
        public var volume: Int32, pan: Int32 = 0
    }
    private struct Entry { let samples: Samples; var voice: Voice }
    /// Voices in first-use order; the render thread walks the array in place.
    private struct Voices { var index: [UInt32:Int] = [:], entries: [Entry] = [], rendered = Rendered() }
    /// Output frames rendered, frames with any signal and the peak magnitude
    /// before clipping, for reports (muted output still renders).
    public struct Rendered: Equatable, Sendable {
        public var frames = 0, audible = 0, peak: Float = 0
        public init() {}
    }
    public var rendered: Rendered { state.withLock { $0.rendered } }
    /// Voices currently playing, and how many of them loop.
    public var activity: (playing: Int, looping: Int) {
        state.withLock { v in
            let playing = v.entries.filter(\.voice.playing)
            return (playing.count,playing.filter(\.voice.looping).count)
        }
    }

    private let source: (UInt32) throws -> Samples
    private let state = OriginalRuntimeLock(initialState:Voices())
    /// Calls performed and calls rejected by DirectSound's ranges, for reports.
    public private(set) var performed = 0, rejected = 0

    public init(source: @escaping (UInt32) throws -> Samples) { self.source = source }

    public func voice(_ buffer: UInt32) -> Voice? {
        state.withLock { v in v.index[buffer].map { v.entries[$0].voice } }
    }

    public func perform(_ call: Call) throws {
        let known = state.withLock { $0.index[call.buffer] != nil }
        let loaded = known ? nil : try source(call.buffer)
        func argument(_ count: Int) throws -> [UInt32] {
            guard call.arguments.count == count else { throw Boundary.arguments(call.method) }
            return call.arguments
        }
        let words: [UInt32]
        switch call.method {
        case 0x48: words = try argument(0)
        case 0x34,0x3c,0x40: words = try argument(1)
        case 0x30: words = try argument(3)
        default: throw Boundary.method(call.method)
        }
        let accepted = state.withLock { v -> Bool in
            if let loaded {
                v.index[call.buffer] = v.entries.count
                v.entries.append(Entry(samples:loaded,voice:.init(volume:loaded.volume)))
            }
            guard let i = v.index[call.buffer] else { return false }
            let value = Int32(bitPattern:words.first ?? 0)
            switch call.method {
            case 0x48: v.entries[i].voice.playing = false
            case 0x34:
                let frame = Int(words[0])/max(1,v.entries[i].samples.blockAlign)
                guard frame <= v.entries[i].samples.frames else { return false }
                v.entries[i].voice.position = Double(frame)
            case 0x30: v.entries[i].voice.playing = true; v.entries[i].voice.looping = words[2] & 1 != 0
            case 0x3c:
                guard (-10000...0).contains(value) else { return false }
                v.entries[i].voice.volume = value
            default:
                guard (-10000...10000).contains(value) else { return false }
                v.entries[i].voice.pan = value
            }
            return true
        }
        performed += 1
        if !accepted { rejected += 1 }
    }

    /// IUnknown::Release of a buffer (the original's quit path): its voice stops.
    public func release(_ buffer: UInt32) {
        state.withLock { v in if let i = v.index[buffer] { v.entries[i].voice.playing = false } }
    }

    /// Linear gain for a DirectSound/DirectShow volume in hundredths of a
    /// decibel: 10^(v/2000), silent at -10000 and below, unity above 0.
    public static func gain(_ volume: Int32) -> Float {
        volume <= -10000 ? 0 : Float(pow(10,Double(min(volume,0))/2000))
    }

    /// Channel gains for a voice.
    public static func gains(volume: Int32, pan: Int32) -> (left: Float, right: Float) {
        let g = gain(volume)
        return (pan > 0 ? g*gain(-pan) : g, pan < 0 ? g*gain(pan) : g)
    }

    /// Mixes `frames` stereo frames at `rate` Hz into `left`/`right` (which
    /// it overwrites) and advances the playing voices.
    public func render(frames: Int, rate: Double, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        left.update(repeating:0,count:frames); right.update(repeating:0,count:frames)
        state.withLockUnchecked { v in
            for k in v.entries.indices where v.entries[k].voice.playing {
                var voice = v.entries[k].voice
                let s = v.entries[k].samples, count = s.frames
                guard count > 0,voice.position < Double(count) else {
                    voice.playing = false; voice.position = 0; v.entries[k].voice = voice; continue
                }
                let (gl,gr) = Self.gains(volume:voice.volume,pan:voice.pan)
                let step = s.rate/rate, l = s.channels[0], r = s.channels.count > 1 ? s.channels[1] : s.channels[0]
                var position = voice.position
                for i in 0..<frames {
                    let index = Int(position), fraction = Float(position-Double(index))
                    let next = index+1 < count ? index+1 : (voice.looping ? 0 : index)
                    left[i] += (l[index]+(l[next]-l[index])*fraction)*gl
                    right[i] += (r[index]+(r[next]-r[index])*fraction)*gr
                    position += step
                    if position >= Double(count) {
                        if voice.looping { position -= Double(count) }
                        else { position = 0; voice.playing = false; break }
                    }
                }
                voice.position = position; v.entries[k].voice = voice
            }
            var audible = 0,peak = v.rendered.peak
            for i in 0..<frames {
                let m = max(abs(left[i]),abs(right[i]))
                if m > 0 { audible += 1; peak = max(peak,m) }
                left[i] = max(-1,min(1,left[i])); right[i] = max(-1,min(1,right[i]))
            }
            v.rendered.frames += frames; v.rendered.audible += audible; v.rendered.peak = peak
        }
    }
}

/// Committed sound methods, in commit order. Core records each as
/// `[buffer, vtable offset, arguments…]`; a shorter record is a boundary.
extension OriginalMacSoundEffects {
    public typealias Effect = OriginalApplicationMenuSession.Effect
    public static func call(_ words: [UInt32]) throws -> Call {
        guard let call = Call(words) else { throw Boundary.arguments(words.first ?? 0) }
        return call
    }
    /// A committed iteration's effects (menus before START).
    public static func calls(_ effects: [Effect]) throws -> [Call] {
        try effects.compactMap { try call(for:$0) }
    }
    /// One effect's call, if it is a sound method (`calls([effect])` without
    /// the arrays; CORE_REALTIME 4t).
    static func call(for effect: Effect) throws -> Call? {
        if case .soundMethod(let e,_) = effect { return try call(e.arguments) }; return nil
    }
    /// A committed loaded batch: its own effects (menus, the gameplay queue)
    /// and the input phase it carries — hotkey controls, round methods and
    /// staged pool/catalog/loading effects. Round and control methods also
    /// carry DirectShow calls (the round's music stop); `music` names the
    /// music runtime's interface tokens, which are not sound buffers.
    public static func calls(_ operations: [OriginalApplicationLoadedMenuSession.Operation],
                             music: (UInt32) -> Bool) throws -> [Call] {
        try operations.flatMap { try calls($0,music:music) }
    }
    /// One committed loaded operation's calls (`calls([operation],music:)`
    /// without wrapping it in an array; CORE_REALTIME 4t).
    public static func calls(_ op: OriginalApplicationLoadedMenuSession.Operation,music: (UInt32) -> Bool) throws -> [Call] {
        switch op {
        case .menu(let e): return try call(for:e).map { [$0] } ?? []
        case .preceding(let input): return try calls(input,music:music)
        default: return []
        }
    }
    public static func calls(_ op: OriginalApplicationInputSession.Operation,music: (UInt32) -> Bool) throws -> [Call] {
        switch op {
        case .menu(let e): return try call(for:e).map { [$0] } ?? []
        case .control(let q,_) where q.kind == .method:
            let c = try call(q.arguments);return music(c.buffer) ? [] : [c]
        case .roundMethod(let e) where e.kind == .method:
            let c = try call(e.arguments);return music(c.buffer) ? [] : [c]
        case .preceding(.menu(let e)): return try call(for:e).map { [$0] } ?? []
        case .preceding(.preceding(let catalog)):
            switch catalog {
            case .menu(let e),.preceding(.menu(let e)): return try call(for:e).map { [$0] } ?? []
            default: return []
            }
        default: return []
        }
    }
}

extension OriginalMacSoundEffects {
    /// PCM, rate, block alignment and registered volume from the audio backend.
    @MainActor public static func backed(by audio: OriginalMacAudioBackend) -> OriginalMacSoundEffects {
        OriginalMacSoundEffects { token in
            try MainActor.assumeIsolated {
                let (format,channels) = try audio.samples(token)
                return .init(channels:channels,rate:Double(format.rate),blockAlign:format.alignment,
                             volume:try audio.volumeObservation(token) ?? 0)
            }
        }
    }
}
