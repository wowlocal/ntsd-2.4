import AVFoundation
import Foundation

/// Plays the packaged original tracks for the committed DirectShow graph state
/// (`OriginalMacRuntimeMusic.presented()`); nothing plays from an uncommitted
/// attempt. Tracks are the lossless ALAC decodes of `bgm/*.wma` made by
/// tools/package_music.py. A graph that reached the end of its track stays
/// silent until it seeks, as a running DirectShow graph does.
@MainActor public final class OriginalMacMusicOutput {
    public enum Boundary: Error, Equatable { case manifest, missingTrack(String) }
    @MainActor public protocol Player: AnyObject {
        var currentTime: TimeInterval { get set }
        var duration: TimeInterval { get }
        var volume: Float { get set }
        var isPlaying: Bool { get }
        func play()
        func pause()
    }
    /// What the output is doing, for reports.
    public struct State: Equatable {
        public let graph: UInt32, track: String?, playing: Bool, ended: Bool, gain: Float, time: Double
    }
    private let load: (URL,@escaping () -> Void) throws -> Player
    private let tracks: [String:URL]
    private var graph: UInt32?, track: String?, player: Player?, seeks = -1, ended = false, loads = 0, pendingEnd: UInt32?
    public private(set) var unresolved: [[UInt8]] = []
    /// Automated runs keep real playback state at zero output gain.
    public var muted = false

    public init(tracks: [String:URL],load: @escaping (URL,@escaping () -> Void) throws -> Player) {
        self.tracks = tracks; self.load = load
    }
    /// The packaged tracks keyed by lowercase original path (`bgm\main.wma`).
    public static var directory: URL? { Bundle.module.url(forResource:"OriginalMusic",withExtension:nil) }
    public static func bundled() throws -> OriginalMacMusicOutput {
        guard let directory,
              let manifest = try? JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("manifest.json"))) as? [String:Any],
              let entries = manifest["entries"] as? [[String:Any]] else { throw Boundary.manifest }
        var tracks: [String:URL] = [:]
        for entry in entries {
            guard let name = entry["name"] as? String,let resource = entry["resource"] as? String else { throw Boundary.manifest }
            let url = directory.appendingPathComponent(resource)
            guard FileManager.default.fileExists(atPath:url.path) else { throw Boundary.missingTrack(resource) }
            tracks[name.lowercased()] = url
        }
        return .init(tracks:tracks) { url,ended in try AudioPlayer(url,ended:ended) }
    }
    /// IBasicAudio volume in hundredths of a decibel; −10000 is silence.
    public static func gain(_ volume: Int32) -> Float {
        volume <= -10000 ? 0 : Float(pow(10,Double(min(volume,0))/2000))
    }
    public func present(_ state: OriginalMacRuntimeMusic.Presented?) throws {
        guard let state,let file = state.file else { player?.pause(); return }
        let name = String(decoding:file,as:UTF8.self).lowercased()
        guard let url = tracks[name] else {
            if state.graph != graph { unresolved.append(file) }
            player?.pause(); player = nil; loads += 1; graph = state.graph; track = nil; return
        }
        if state.graph != graph || name != track {
            player?.pause(); loads += 1
            let current = loads
            player = try load(url) { [weak self] in self?.end(current) }
            graph = state.graph; track = name; seeks = -1; ended = false
        }
        guard let player else { return }
        if state.seeks != seeks {
            if state.seeks > 0 { player.currentTime = min(state.position,player.duration) }
            seeks = state.seeks; ended = false
        }
        player.volume = muted ? 0 : Self.gain(state.volume)
        if state.running && !ended { if !player.isPlaying { player.play() } }
        else if player.isPlaying { player.pause() }
    }
    private func end(_ load: Int) {
        guard load == loads,!ended else { return }
        ended = true; pendingEnd = graph
    }
    /// The graph whose track ended since the last call (reported once).
    public func takeEnded() -> UInt32? { defer { pendingEnd = nil }; return pendingEnd }
    /// Test hook for automated runs: the current track ends now.
    public func finishTrack() { player?.pause(); end(loads) }
    public var state: State? {
        graph.map { .init(graph:$0,track:track,playing:player?.isPlaying ?? false,ended:ended,
                          gain:player?.volume ?? 0,time:player?.currentTime ?? 0) }
    }
    private final class AudioPlayer: NSObject, Player, AVAudioPlayerDelegate {
        let player: AVAudioPlayer, ended: () -> Void
        init(_ url: URL,ended: @escaping () -> Void) throws {
            player = try AVAudioPlayer(contentsOf:url); self.ended = ended
            super.init(); player.delegate = self; player.prepareToPlay()
        }
        var currentTime: TimeInterval { get { player.currentTime } set { player.currentTime = newValue } }
        var duration: TimeInterval { player.duration }
        var volume: Float { get { player.volume } set { player.volume = newValue } }
        var isPlaying: Bool { player.isPlaying }
        func play() { player.play() }
        func pause() { player.pause() }
        nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,successfully flag: Bool) {
            DispatchQueue.main.async { MainActor.assumeIsolated { self.ended() } }
        }
    }
}
