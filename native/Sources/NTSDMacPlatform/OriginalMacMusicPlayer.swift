import AVFoundation
import Foundation

/// The Mac side of `OriginalMacMusicOutput`: the packaged ALAC tracks in this
/// target's resources and AVAudioPlayer playback.
extension OriginalMacMusicOutput {
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
        return .init(tracks:tracks) { url,ended in try OriginalMacAVMusicPlayer(url,ended:ended) }
    }
}

/// AVAudioPlayer behind `OriginalMacMusicOutput.Player`.
@MainActor final class OriginalMacAVMusicPlayer: NSObject, OriginalMacMusicOutput.Player, AVAudioPlayerDelegate {
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
