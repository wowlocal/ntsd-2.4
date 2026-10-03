import AVFoundation
import Foundation

/// Plays the packaged original tracks for the delivered DirectShow graph state
/// (`OriginalMacRuntimeMusic.presented()`): committed batches and explicitly
/// serviced input-control receipts, including shutdown before a source fault.
/// Tracks are the lossless ALAC decodes of `bgm/*.wma` made by
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
    /// Scripted runs with a virtual clock (seconds): a track's position and its
    /// end follow that clock, not the real player, so the EC_COMPLETE message
    /// reaches the same iteration on every machine.
    public var virtualSeconds: (() -> Double)?
    private var virtualBase: Double = 0, virtualStart: Double?

    public init(tracks: [String:URL],load: @escaping (URL,@escaping () -> Void) throws -> Player) {
        self.tracks = tracks; self.load = load
    }
    /// The packaged tracks keyed by lowercase original path (`bgm\main.wma`).
    /// build-native.sh/package_assets.py install the tracks in an app's
    /// Contents/Resources; SwiftPM command-line/test clients use `.module`.
    public static func directory(in appBundle: Bundle = .main) -> URL? {
        if let resources = appBundle.resourceURL {
            let directory = resources.appendingPathComponent("OriginalMusic",isDirectory:true)
            if appBundle.bundleURL.pathExtension == "app" || FileManager.default.fileExists(atPath:directory.path) { return directory }
        }
        return Bundle.module.url(forResource:"OriginalMusic",withExtension:nil)
    }
    public static func bundled() throws -> OriginalMacMusicOutput {
        guard let directory = directory(),
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
    nonisolated public static func gain(_ volume: Int32) -> Float { OriginalMacSoundEffects.gain(volume) }
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
            player = try load(url) { [weak self] in
                // With a virtual clock the end is computed below, not by the real player.
                guard self?.virtualSeconds == nil else { return }
                self?.end(current)
            }
            graph = state.graph; track = name; seeks = -1; ended = false; virtualBase = 0; virtualStart = nil
        }
        guard let player else { return }
        if state.seeks != seeks {
            if state.seeks > 0 { player.currentTime = min(state.position,player.duration) }
            seeks = state.seeks; ended = false
            virtualBase = state.seeks > 0 ? min(state.position,player.duration) : 0; virtualStart = nil
        }
        player.volume = muted ? 0 : Self.gain(state.volume)
        if let now = virtualSeconds?() {
            if state.running && !ended {
                if virtualStart == nil { virtualStart = now }
                if virtualBase + (now - (virtualStart ?? now)) >= player.duration { end(loads) }
            } else if let start = virtualStart { virtualBase += now - start; virtualStart = nil }
        }
        if state.running && !ended { if !player.isPlaying { player.play() } }
        else if player.isPlaying { player.pause() }
    }
    private func end(_ load: Int) {
        guard load == loads,!ended else { return }
        ended = true; pendingEnd = graph; virtualStart = nil
    }
    /// The graph whose track ended since the last call (reported once).
    public func takeEnded() -> UInt32? { defer { pendingEnd = nil }; return pendingEnd }
    /// Test hook for automated runs: the current track ends now.
    public func finishTrack() { player?.pause(); end(loads) }
    public var state: State? {
        graph.map { g in
            // With a virtual clock the report follows the virtual position, not the real player.
            if let now = virtualSeconds?(),player != nil {
                let time = virtualBase + (virtualStart.map { now - $0 } ?? 0)
                return .init(graph:g,track:track,playing:virtualStart != nil,ended:ended,gain:player?.volume ?? 0,time:time)
            }
            return .init(graph:g,track:track,playing:player?.isPlaying ?? false,ended:ended,
                         gain:player?.volume ?? 0,time:player?.currentTime ?? 0)
        }
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
            // On the main thread (as AVAudioPlayer calls it) the end is recorded at once, so
            // no later seek of the same iteration can be overtaken by a stale end.
            if Thread.isMainThread { MainActor.assumeIsolated { self.ended() } }
            else { DispatchQueue.main.async { MainActor.assumeIsolated { self.ended() } } }
        }
    }
}
