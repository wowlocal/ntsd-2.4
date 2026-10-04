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
    init(float: Bool,rate wanted: Int32?,lowLatency: Bool,fill: @escaping (UnsafeMutableRawPointer,Int) -> Void) throws {
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
    }
    deinit { AAudioStream_close(stream); callback.release() }
    func start() { _ = AAudioStream_requestStart(stream) }
    func pause() { _ = AAudioStream_requestPause(stream) }
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

/// A packaged track's PCM and play position, shared with AAudio's callback thread.
final class NTSDAndroidMusicPCM: @unchecked Sendable {
    let frames: Int
    private let lock = NSLock()
    private var samples: [Int16]?, position = 0, playing = false, gain: Float = 1
    private let ended: @Sendable () -> Void
    init(frames: Int,ended: @escaping @Sendable () -> Void) { self.frames = frames; self.ended = ended }
    func locked<T>(_ body: () -> T) -> T { lock.lock(); defer { lock.unlock() }; return body() }
    func ready(_ decoded: [Int16]) { locked { samples = decoded } }
    var isPlaying: Bool { locked { playing } }
    func setPlaying(_ value: Bool) { locked { playing = value } }
    func setGain(_ value: Float) { locked { gain = value } }
    var frame: Int {
        get { locked { position } }
        set { locked { position = max(0,min(frames,newValue)) } }
    }
    /// Copies from the position (silence when paused or still decoding); the
    /// end of the track stops playback and reports the end once, like AVAudioPlayer.
    func fill(_ data: UnsafeMutableRawPointer,frames wanted: Int) {
        let out = data.assumingMemoryBound(to:Int16.self)
        var finished = false, written = 0
        locked {
            guard playing,let samples else { return }
            let count = min(wanted,frames-position)
            if count > 0 {
                for i in 0..<count*2 { out[i] = Int16(clamping:Int((Float(samples[position*2+i])*gain).rounded())) }
                position += count; written = count
            }
            if position >= frames { playing = false; finished = true }
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
        let track = try OriginalALACTrack(contentsOf:url)
        guard track.sampleRate == Self.rate,track.channels == 2 else { throw OriginalALACTrack.Failure.unsupported("\(track.sampleRate) Hz, \(track.channels) channels") }
        let endBox = UncheckedSendableBox(ended)
        let pcm = NTSDAndroidMusicPCM(frames:track.frames) { MainActor.assumeIsolated { endBox.value() } }
        self.pcm = pcm; duration = Double(track.frames)/Self.rate
        output = try NTSDAndroidStream(float:false,rate:Int32(Self.rate),lowLatency:false) { data,frames in pcm.fill(data,frames:frames) }
        let target = UncheckedSendableBox(pcm),name = url.lastPathComponent
        DispatchQueue.global(qos:.userInitiated).async {
            do { target.value.ready(try track.samples()) }
            catch {
                let text = "\(error)"
                DispatchQueue.main.async { OriginalRuntimeSession.emit(["event":"androidMusicError","track":name,"error":text]) }
            }
        }
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
