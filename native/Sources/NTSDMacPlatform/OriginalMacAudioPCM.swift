import AVFAudio
import NTSDCore

extension OriginalMacAudioBackend {
    /// The buffer's decoded samples as an independent standard-format
    /// AVAudioPCMBuffer (deinterleaved Float32 at the buffer's rate).
    public func pcmSnapshot(_ token: UInt32) throws -> AVAudioPCMBuffer {
        let (format,channels) = try samples(token)
        let frames = channels.first?.count ?? 0
        guard let pcmFormat = AVAudioFormat(standardFormatWithSampleRate:Double(format.rate),channels:AVAudioChannelCount(format.channels)),
              let copy = AVAudioPCMBuffer(pcmFormat:pcmFormat,frameCapacity:AVAudioFrameCount(frames)),
              let dst = copy.floatChannelData else { throw Boundary.allocationFailed }
        copy.frameLength = AVAudioFrameCount(frames)
        for channel in 0..<format.channels { for frame in 0..<frames { dst[channel][frame] = channels[channel][frame] } }
        return copy
    }
}
