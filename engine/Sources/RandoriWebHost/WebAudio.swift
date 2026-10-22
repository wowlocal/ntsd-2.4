import Foundation
import RandoriMusicDecoder
import RandoriRuntime

/// The page's sound output (TVOS_WEB W2b-3): the worker renders the effects
/// mixer and the playing music tracks ahead into the page's shared ring, from
/// which an AudioWorklet plays at the AudioContext's rate. There are no audio
/// threads on WASI: a 10 ms main-queue timer keeps about 150 ms queued, as
/// SDL's audio thread pulls from the same mixer on the other hosts. Frames the
/// page played while the loop stalled (loading, a question, a long frame) or
/// could not play (a suspended context) come back as owed and are rendered
/// and dropped, so voices and the music clock keep wall-clock time as they do
/// on an audio thread. While the page is hidden or unfocused the effects are
/// silent, as DirectSound silences a background window's buffers (the mixer
/// still advances); music plays on, as on the other hosts.
@MainActor final class WebAudioMixer {
    let rate: Double
    var effects: OriginalMacSoundEffects?, effectsMuted = false, focused = true
    private var players: [WeakPlayer] = []
    private var left: [Float] = [], right: [Float] = [], interleaved: [Float] = []
    private struct WeakPlayer { weak var player: WebMusicPlayer? }
    init?() {
        let rate = Double(ntsdAudioRate())
        guard rate > 0 else { return nil }
        self.rate = rate
    }
    func add(_ player: WebMusicPlayer) { players.removeAll { $0.player == nil }; players.append(.init(player:player)) }
    /// Catches up on owed frames, then fills the ring up to its target. At
    /// most 10 s are caught up at once: a longer stall leaves the music clock
    /// that much behind wall-clock time.
    func fill() {
        var owed = min(Int(ntsdAudioOwed()),Int(rate)*10)
        while owed > 0 { let frames = min(owed,1024); render(frames,keep:false); owed -= frames }
        var space = Int(ntsdAudioSpace())
        while space > 0 {
            let frames = min(space,1024)
            render(frames,keep:true); space -= frames
        }
    }
    private func render(_ frames: Int,keep: Bool) {
        if left.count < frames { left = .init(repeating:0,count:frames); right = left; interleaved = .init(repeating:0,count:frames*2) }
        for i in 0..<frames { left[i] = 0; right[i] = 0 }
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                if let effects { effects.render(frames:frames,rate:rate,left:l.baseAddress!,right:r.baseAddress!) }
                if effectsMuted || !focused { for i in 0..<frames { l[i] = 0; r[i] = 0 } }
                for slot in players { slot.player?.mix(frames:frames,rate:rate,left:l,right:r) }
            }
        }
        guard keep else { return }
        for i in 0..<frames { interleaved[2*i] = left[i]; interleaved[2*i+1] = right[i] }
        interleaved.withUnsafeBytes { ntsdAudioWrite($0.baseAddress!,Int32(frames)) }
    }
}

/// `OriginalMacMusicOutput.Player` in the browser: a packaged ALAC track
/// decoded packet by packet ahead of its position (no thread to decode it
/// whole, as the SDL host does), mixed into the page's ring at the
/// AudioContext's rate by linear interpolation (output only: the game's
/// music clock is this player's position, as with SDL's).
///
/// A track still on its way from the host (TVOS_WEB W5: the menu's 27.5 MB
/// main.caf on a first visit) is not read yet, which would hold the game
/// until it arrived: given its frame count from the music manifest, the
/// player keeps time silently from the start and opens the track once the
/// page has it, catching up to its position (at most 8 packets, ~0.75 s of
/// sound, per mix, so no frame waits on a long decode). A track that is in
/// at once, or has no count, opens and decodes as before.
@MainActor final class WebMusicPlayer: OriginalMacMusicOutput.Player {
    private static let rate = 44100.0
    private var decoder: OriginalALACDecoder?
    private let frames: Int, ended: () -> Void, name: String, url: URL
    private var samples: [Int16] = [], position = 0.0, playing = false, failed = false, waiting = false, late = false, polls = 0
    let duration: TimeInterval
    var volume: Float = 1
    var isPlaying: Bool { playing }
    var currentTime: TimeInterval {
        get { position/Self.rate }
        set { position = max(0,min(Double(frames),(newValue*Self.rate).rounded())) }
    }
    init(_ url: URL,frames listed: Int?,mixer: WebAudioMixer,ended: @escaping () -> Void) throws {
        self.url = url; self.ended = ended; name = url.lastPathComponent
        if let listed,!WebFiles.ready(url.path) { frames = listed; waiting = true }
        else { let (opened,count) = try Self.open(url); decoder = opened; frames = count }
        duration = Double(frames)/Self.rate
        samples.reserveCapacity(frames*2)
        mixer.add(self)
    }
    private static func open(_ url: URL) throws -> (OriginalALACDecoder,Int) {
        let track = try OriginalALACTrack(contentsOf:url)
        guard track.sampleRate == Self.rate,track.channels == 2 else { throw OriginalALACTrack.Failure.unsupported("\(track.sampleRate) Hz, \(track.channels) channels") }
        return (try OriginalALACDecoder(track),track.frames)
    }
    /// A waiting track opened once its file is in (checked every 10th mix);
    /// a failure, or a track whose frames differ from the manifest's, stays
    /// silent and says so, as a decode failure does.
    private func arrive() {
        polls += 1
        guard polls % 10 == 1,WebFiles.ready(url.path) else { return }
        waiting = false
        do {
            let (opened,count) = try Self.open(url)
            guard count == frames else { throw OriginalALACTrack.Failure.corrupt("\(count) frames, the manifest lists \(frames)") }
            decoder = opened; late = true
        } catch { fail(error) }
    }
    private func fail(_ error: Error) {
        failed = true; decoder = nil   // the track stays silent; say so instead of failing quietly
        OriginalRuntimeSession.emit(["event":"webMusicError","track":name,"error":"\(error)"])
    }
    func play() { if Int(position) < frames { playing = true } }
    func pause() { playing = false }
    /// Decodes until `frame` (plus two seconds) is available; at most 8
    /// packets per call for a track that opened late.
    private func decode(through frame: Int) {
        let wanted = min(frames,frame+Int(Self.rate)*2),limit = late ? 8 : Int.max
        var packets = 0
        while !failed,samples.count/2 < wanted,packets < limit,let decoder {
            do { try decoder.next { samples.append(contentsOf:$0) } }
            catch { fail(error); break }
            packets += 1
            if decoder.finished { self.decoder = nil }   // done: the compressed file goes too
        }
    }
    func mix(frames count: Int,rate: Double,left: UnsafeMutableBufferPointer<Float>,right: UnsafeMutableBufferPointer<Float>) {
        guard playing else { return }
        let step = Self.rate/rate
        if waiting { arrive() }
        decode(through:Int(position+Double(count)*step)+2)
        let available = samples.count/2,gain = volume/32768
        for i in 0..<count {
            let at = position+Double(i)*step,base = Int(at),next = min(base+1,frames-1)
            guard base < frames,next < available else { break }   // not decoded (yet, or after a failure)
            let t = Float(at-Double(base))
            left[i] += (Float(samples[2*base])*(1-t)+Float(samples[2*next])*t)*gain
            right[i] += (Float(samples[2*base+1])*(1-t)+Float(samples[2*next+1])*t)*gain
        }
        position = min(Double(frames),position+Double(count)*step)
        // The end stops playback and reports it once, as AVAudioPlayer does.
        if Int(position) >= frames { playing = false; ended() }
    }
}
