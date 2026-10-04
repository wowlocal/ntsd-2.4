import CSDL3
import Foundation
import NTSDMusicDecoder
import NTSDRuntime

/// A packaged track's PCM and play position, shared with SDL's audio thread.
final class SDLMusicPCM: @unchecked Sendable {
    let frames: Int
    private let lock = NSLock()
    private var samples: [Int16]?, position = 0, playing = false
    private let ended: @Sendable () -> Void
    init(frames: Int,ended: @escaping @Sendable () -> Void) { self.frames = frames; self.ended = ended }
    func locked<T>(_ body: () -> T) -> T { lock.lock(); defer { lock.unlock() }; return body() }
    func ready(_ decoded: [Int16]) { locked { samples = decoded } }
    var isPlaying: Bool { locked { playing } }
    func setPlaying(_ value: Bool) { locked { playing = value } }
    var frame: Int {
        get { locked { position } }
        set { locked { position = max(0,min(frames,newValue)) } }
    }
    /// SDL asks for `bytes` more output: copy from the position; the end of the
    /// track stops playback and reports the end once, like AVAudioPlayer.
    func fill(_ stream: OpaquePointer,bytes: Int) {
        var finished = false
        locked {
            guard playing,let samples else { return }
            let count = min(bytes/4,frames-position)
            if count > 0 {
                samples.withUnsafeBufferPointer { _ = SDL_PutAudioStreamData(stream,$0.baseAddress!+position*2,Int32(count*4)) }
                position += count
            }
            if position >= frames { playing = false; finished = true }
        }
        if finished { DispatchQueue.main.async(execute:ended) }
    }
}

/// `OriginalMacMusicOutput.Player` on SDL: the packaged ALAC track decoded by
/// NTSDMusicDecoder (identical to the manifest PCM) on its own audio stream.
/// Decoding runs off the main thread; the duration is known from the CAF
/// packet table at once.
@MainActor final class SDLMusicPlayer: OriginalMacMusicOutput.Player {
    enum Failure: Error { case sdl(String) }
    private let pcm: SDLMusicPCM, stream: OpaquePointer, box: Unmanaged<SDLMusicPCM>
    let duration: TimeInterval
    private static let rate = 44100.0
    init(_ url: URL,ended: @escaping () -> Void) throws {
        let track = try OriginalALACTrack(contentsOf:url)
        guard track.sampleRate == Self.rate,track.channels == 2 else { throw OriginalALACTrack.Failure.unsupported("\(track.sampleRate) Hz, \(track.channels) channels") }
        let endBox = UncheckedBox(ended)
        pcm = SDLMusicPCM(frames:track.frames) { MainActor.assumeIsolated { endBox.value() } }
        duration = Double(track.frames)/Self.rate
        box = Unmanaged.passRetained(pcm)
        var spec = SDL_AudioSpec(format:SDL_AUDIO_S16,channels:2,freq:Int32(Self.rate))
        guard let stream = SDL_OpenAudioDeviceStream(NTSD_SDL_DEFAULT_PLAYBACK,&spec,{ userdata,stream,additional,_ in
            guard let userdata,let stream,additional > 0 else { return }
            Unmanaged<SDLMusicPCM>.fromOpaque(userdata).takeUnretainedValue().fill(stream,bytes:Int(additional))
        },box.toOpaque()) else { box.release(); throw Failure.sdl(String(cString:SDL_GetError())) }
        self.stream = stream
        let target = UncheckedBox(pcm),name = url.lastPathComponent
        DispatchQueue.global(qos:.userInitiated).async {
            do { target.value.ready(try track.samples()) }
            catch {
                // The track stays silent; say so instead of failing quietly.
                let text = "\(error)"
                DispatchQueue.main.async { OriginalRuntimeSession.emit(["event":"sdlMusicError","track":name,"error":text]) }
            }
        }
    }
    deinit { SDL_DestroyAudioStream(stream); box.release() }
    var currentTime: TimeInterval {
        get { Double(pcm.frame)/Self.rate }
        set { pcm.frame = Int((newValue*Self.rate).rounded()) }
    }
    var volume: Float = 1 { didSet { _ = SDL_SetAudioStreamGain(stream,volume) } }
    var isPlaying: Bool { pcm.isPlaying }
    func play() { guard pcm.frame < pcm.frames else { return }; pcm.setPlaying(true); _ = SDL_ResumeAudioStreamDevice(stream) }
    func pause() { pcm.setPlaying(false); _ = SDL_PauseAudioStreamDevice(stream) }
}
