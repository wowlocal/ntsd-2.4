import AVFoundation
import Foundation
import NTSDCore

extension OriginalMacSoundEffects {
    /// PCM, rate, block alignment and registered volume from the audio backend.
    @MainActor public static func backed(by audio: OriginalMacAudioBackend) -> OriginalMacSoundEffects {
        OriginalMacSoundEffects { token in
            try MainActor.assumeIsolated {
                let pcm = try audio.pcmSnapshot(token),format = try audio.observation(token).format
                guard let data = pcm.floatChannelData else { throw Boundary.arguments(token) }
                let frames = Int(pcm.frameLength)
                let channels = (0..<format.channels).map { Array(UnsafeBufferPointer(start:data[$0],count:frames)) }
                return .init(channels:channels,rate:Double(format.rate),blockAlign:format.alignment,
                             volume:try audio.volumeObservation(token) ?? 0)
            }
        }
    }
}

/// Plays `OriginalMacSoundEffects` through the default output. Muted runs
/// keep the voices advancing at zero gain. The original creates its buffers
/// with flags 0xe0 (pan, volume, frequency control) and neither
/// DSBCAPS_GLOBALFOCUS nor DSBCAPS_STICKYFOCUS, so DirectSound silences them
/// while the game window is not in the foreground: `focused` follows that.
@MainActor public final class OriginalMacSoundOutput {
    private let engine = AVAudioEngine()
    private let node: AVAudioSourceNode
    public var muted = false { didSet { apply() } }
    public var focused = true { didSet { apply() } }
    private func apply() { engine.mainMixerNode.outputVolume = muted || !focused ? 0 : 1 }
    public enum Boundary: Error, Equatable { case noOutputFormat }
    public init(effects: OriginalMacSoundEffects) throws {
        let rate = engine.outputNode.outputFormat(forBus:0).sampleRate
        guard rate > 0,let format = AVAudioFormat(standardFormatWithSampleRate:rate,channels:2) else { throw Boundary.noOutputFormat }
        node = Self.source(effects,rate:rate,format:format)
        engine.attach(node)
        engine.connect(node,to:engine.mainMixerNode,format:format)
        try engine.start()
        // An output hardware change (headphones, another device) stops the engine;
        // restart it so the effects keep sounding. The mixer converts the rate.
        configuration = NotificationCenter.default.addObserver(forName:.AVAudioEngineConfigurationChange,object:engine,queue:.main) { [weak self] _ in
            MainActor.assumeIsolated { try? self?.engine.start() }
        }
    }
    private var configuration: NSObjectProtocol?
    deinit { if let configuration { NotificationCenter.default.removeObserver(configuration) } }
    /// Formed outside the main actor: the render block runs on the audio thread.
    private nonisolated static func source(_ effects: OriginalMacSoundEffects,rate: Double,format: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format:format) { _,_,frameCount,list -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            guard buffers.count == 2,let l = buffers[0].mData?.assumingMemoryBound(to:Float.self),
                  let r = buffers[1].mData?.assumingMemoryBound(to:Float.self) else { return noErr }
            effects.render(frames:Int(frameCount),rate:rate,left:l,right:r)
            return noErr
        }
    }
}
