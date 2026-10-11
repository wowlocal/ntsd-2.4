import CAndroidNative
import Foundation
import NTSDMusicDecoder
import NTSDRuntime
import Synchronization

/// An AAudio output stream whose data callback asks `fill` for frames.
final class NTSDAndroidStream {
    enum Failure: Error { case aaudio(String,Int32) }
    let stream: OpaquePointer, rate: Int32
    private let callback: Unmanaged<Callback>
    final class Callback { let fill: (UnsafeMutableRawPointer,Int) -> Void; init(_ fill: @escaping (UnsafeMutableRawPointer,Int) -> Void) { self.fill = fill } }
    /// float: interleaved Float32 at the device rate; otherwise Int16 at `rate`.
    let kind: String
    init(kind: String,float: Bool,rate wanted: Int32?,lowLatency: Bool,fill: @escaping (UnsafeMutableRawPointer,Int) -> Void) throws {
        self.kind = kind
        var builder: OpaquePointer?
        var result = AAudio_createStreamBuilder(&builder)
        guard result == AAUDIO_OK,let builder else { throw Failure.aaudio("createStreamBuilder",result) }
        defer { AAudioStreamBuilder_delete(builder) }
        AAudioStreamBuilder_setFormat(builder,aaudio_format_t(float ? AAUDIO_FORMAT_PCM_FLOAT : AAUDIO_FORMAT_PCM_I16))
        AAudioStreamBuilder_setChannelCount(builder,2)
        if let wanted { AAudioStreamBuilder_setSampleRate(builder,wanted) }
        AAudioStreamBuilder_setSharingMode(builder,aaudio_sharing_mode_t(AAUDIO_SHARING_MODE_SHARED))
        AAudioStreamBuilder_setPerformanceMode(builder,aaudio_performance_mode_t(lowLatency ? AAUDIO_PERFORMANCE_MODE_LOW_LATENCY : AAUDIO_PERFORMANCE_MODE_NONE))
        let callback = Unmanaged.passRetained(Callback(fill))
        AAudioStreamBuilder_setDataCallback(builder,{ _,user,data,frames in
            if let user,frames > 0 { Unmanaged<Callback>.fromOpaque(user).takeUnretainedValue().fill(data,Int(frames)) }
            return aaudio_data_callback_result_t(AAUDIO_CALLBACK_RESULT_CONTINUE)
        },callback.toOpaque())
        var stream: OpaquePointer?
        result = AAudioStreamBuilder_openStream(builder,&stream)
        guard result == AAUDIO_OK,let stream else { callback.release(); throw Failure.aaudio("openStream",result) }
        self.stream = stream; self.callback = callback; rate = AAudioStream_getSampleRate(stream)
        NTSDAndroidXRuns.opened(self)
    }
    deinit { NTSDAndroidXRuns.closed(self); AAudioStream_close(stream); callback.release() }
    var xruns: Int { Int(max(0,AAudioStream_getXRunCount(stream))) }
    func start() { _ = AAudioStream_requestStart(stream) }
    func pause() { _ = AAudioStream_requestPause(stream) }
}

/// The streams' underruns (AAudioStream_getXRunCount), live and closed, by
/// kind, reported with `androidPresent` (MEMORY_LOADING M8: the music now
/// decodes on its stream's callback, so an underrun would show here).
enum NTSDAndroidXRuns {
    private static let lock = NSLock()
    /// Kind and AAudio stream of each open stream (not the object: the
    /// registry must not keep a stream alive); a stream leaves before it closes.
    nonisolated(unsafe) private static var live: [ObjectIdentifier:(kind: String,stream: OpaquePointer)] = [:]
    nonisolated(unsafe) private static var ended: [String:Int] = [:]
    static func opened(_ s: NTSDAndroidStream) { lock.lock(); live[ObjectIdentifier(s)] = (s.kind,s.stream); lock.unlock() }
    static func closed(_ s: NTSDAndroidStream) {
        lock.lock(); live[ObjectIdentifier(s)] = nil; ended[s.kind,default:0] += s.xruns; lock.unlock()
    }
    static func counts() -> [String:Int] {
        lock.lock(); defer { lock.unlock() }
        var all = ended
        for (kind,stream) in live.values { all[kind,default:0] += Int(max(0,AAudioStream_getXRunCount(stream))) }
        return all
    }
}

/// Feeds the sound-effect mixer (planar floats) to an interleaved stream;
/// `silent` outputs zeros (muted, or the window without focus).
final class NTSDAndroidEffectsFeed: @unchecked Sendable {
    let effects: OriginalMacSoundEffects
    let silent = Atomic<Bool>(false)
    private var left: [Float] = [], right: [Float] = []
    init(effects: OriginalMacSoundEffects) { self.effects = effects }
    func fill(_ data: UnsafeMutableRawPointer,frames: Int,rate: Double) {
        let out = data.assumingMemoryBound(to:Float.self)
        if silent.load(ordering:.relaxed) { out.update(repeating:0,count:frames*2); return }
        if left.count < frames { left = .init(repeating:0,count:frames); right = left }
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                effects.render(frames:frames,rate:rate,left:l.baseAddress!,right:r.baseAddress!)
                for i in 0..<frames { out[2*i] = l[i]; out[2*i+1] = r[i] }
            }
        }
    }
}

/// A packaged track's play position, shared with AAudio's callback thread,
/// which decodes the samples it plays a packet at a time from the mapped file
/// (MEMORY_LOADING M8: the whole decoded track and a copy of the file took
/// 24-94 MiB on the A12 while music played).
final class NTSDAndroidMusicPCM: @unchecked Sendable {
    let frames: Int
    private let lock = NSLock()
    private var position = 0, playing = false, gain: Float = 1, failed = false, moves = 0
    /// Only the callback thread reads; the lock is not held while it decodes,
    /// so the main thread's position and state calls never wait for a packet.
    private let reader: OriginalALACTrack.Reader?
    private var scratch: [Int16] = []
    private let ended: @Sendable () -> Void, failure: @Sendable (String) -> Void
    init(reader: OriginalALACTrack.Reader?,frames: Int,ended: @escaping @Sendable () -> Void,failure: @escaping @Sendable (String) -> Void) {
        self.reader = reader; self.frames = frames; self.ended = ended; self.failure = failure; failed = reader == nil
    }
    func locked<T>(_ body: () -> T) -> T { lock.lock(); defer { lock.unlock() }; return body() }
    var isPlaying: Bool { locked { playing } }
    func setPlaying(_ value: Bool) { locked { playing = value } }
    func setGain(_ value: Float) { locked { gain = value } }
    var frame: Int {
        get { locked { position } }
        set { locked { position = max(0,min(frames,newValue)); moves &+= 1 } }
    }
    /// Copies from the position (silence when paused); the end of the track
    /// stops playback and reports the end once, like AVAudioPlayer. The
    /// samples are decoded outside the lock and committed only if the
    /// position did not move meanwhile (else they are decoded again from the
    /// new position).
    func fill(_ data: UnsafeMutableRawPointer,frames wanted: Int) {
        let out = data.assumingMemoryBound(to:Int16.self)
        var finished = false, written = 0
        for _ in 0..<3 {
            let (start,gain,active,move) = locked { (position,self.gain,playing && !failed,moves) }
            guard active else { break }
            let count = min(wanted,frames-start)
            var got = 0
            if count > 0 {
                if scratch.count < count*2 { scratch = [Int16](repeating:0,count:count*2) }
                guard let reader else { break }
                do { got = try scratch.withUnsafeMutableBufferPointer { try reader.read(from:start,count:count,into:$0.baseAddress!) } }
                catch {
                    locked { failed = true }; let report = failure,text = "\(error)"
                    DispatchQueue.main.async { report(text) }; break
                }
                for i in 0..<got*2 { out[i] = Int16(clamping:Int((Float(scratch[i])*gain).rounded())) }
            }
            let committed = locked { () -> Bool in
                guard moves == move,playing else { return false }
                position += got
                if position >= frames { playing = false; finished = true }
                return true
            }
            if committed { written = got; break }
        }
        if written < wanted { (out+written*2).update(repeating:0,count:(wanted-written)*2) }
        if finished { DispatchQueue.main.async(execute:ended) }
    }
}

/// `OriginalMacMusicOutput.Player` on Android: the packaged ALAC track decoded
/// by NTSDMusicDecoder (as on Linux) on its own 44.1 kHz AAudio stream.
@MainActor final class NTSDAndroidMusicPlayer: OriginalMacMusicOutput.Player {
    private let pcm: NTSDAndroidMusicPCM, output: NTSDAndroidStream
    let duration: TimeInterval
    private static let rate = 44100.0
    init(_ url: URL,ended: @escaping () -> Void) throws {
        let track = try OriginalALACTrack(mapping:url)
        guard track.sampleRate == Self.rate,track.channels == 2 else { throw OriginalALACTrack.Failure.unsupported("\(track.sampleRate) Hz, \(track.channels) channels") }
        let endBox = UncheckedSendableBox(ended),name = url.lastPathComponent
        let failure: @Sendable (String) -> Void = { text in MainActor.assumeIsolated { OriginalRuntimeSession.emit(["event":"androidMusicError","track":name,"error":text]) } }
        // A track the decoder refuses plays silence and reports it once, as
        // when the whole-track decode failed in the background.
        let reader: OriginalALACTrack.Reader?
        do { reader = try OriginalALACTrack.Reader(track) }
        catch { reader = nil; let text = "\(error)"; DispatchQueue.main.async { failure(text) } }
        let pcm = NTSDAndroidMusicPCM(reader:reader,frames:track.frames,ended:{ MainActor.assumeIsolated { endBox.value() } },failure:failure)
        self.pcm = pcm; duration = Double(track.frames)/Self.rate
        output = try NTSDAndroidStream(kind:"music",float:false,rate:Int32(Self.rate),lowLatency:false) { data,frames in pcm.fill(data,frames:frames) }
    }
    var currentTime: TimeInterval {
        get { Double(pcm.frame)/Self.rate }
        set { pcm.frame = Int((newValue*Self.rate).rounded()) }
    }
    var volume: Float = 1 { didSet { pcm.setGain(volume) } }
    var isPlaying: Bool { pcm.isPlaying }
    func play() { guard pcm.frame < pcm.frames else { return }; pcm.setPlaying(true); output.start() }
    func pause() { pcm.setPlaying(false); output.pause() }
    /// The app went to the background: stop the output, keep the track's state.
    func suspend() { output.pause() }
    func resume() { if pcm.isPlaying { output.start() } }
}
