import Foundation

/// A track that never sounds: hosts without a music decoder yet (headless,
/// SDL until P7) end it by the clock against its packaged frame count, which
/// equals AVAudioPlayer's duration for every packaged track.
@MainActor public final class OriginalRuntimeSilentMusicPlayer: OriginalMacMusicOutput.Player {
    public let duration: TimeInterval
    public var currentTime: TimeInterval = 0, volume: Float = 1
    public private(set) var isPlaying = false
    public init(duration: TimeInterval) { self.duration = duration }
    public func play() { isPlaying = true }
    public func pause() { isPlaying = false }
}

extension OriginalMacMusicOutput {
    /// The packaged tracks of `directory`'s manifest, played silently.
    public static func silent(directory: URL) throws -> OriginalMacMusicOutput {
        guard let manifest = try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("manifest.json"))) as? [String:Any],
              let rate = (manifest["sampleRate"] as? NSNumber)?.doubleValue,rate > 0,
              let entries = manifest["entries"] as? [[String:Any]] else { throw Boundary.manifest }
        var tracks: [String:URL] = [:],durations: [URL:TimeInterval] = [:]
        for entry in entries {
            guard let name = entry["name"] as? String,let resource = entry["resource"] as? String,
                  let frames = (entry["frames"] as? NSNumber)?.doubleValue else { throw Boundary.manifest }
            let url = directory.appendingPathComponent(resource)
            tracks[name.lowercased()] = url; durations[url] = frames/rate
        }
        return .init(tracks:tracks) { url,_ in OriginalRuntimeSilentMusicPlayer(duration:durations[url] ?? 0) }
    }
}
