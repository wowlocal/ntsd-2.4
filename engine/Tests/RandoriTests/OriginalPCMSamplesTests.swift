import Foundation
import XCTest
@testable import RandoriRuntime

/// MEMORY_LOADING M5c: a buffer kept as PCM and converted while mixing renders
/// exactly (bit for bit) what its float samples rendered.
final class OriginalPCMSamplesTests: XCTestCase {
    typealias Effects = OriginalMacSoundEffects
    struct SplitMix { var state: UInt64; mutating func next(_ n: UInt64) -> UInt64 {
        state &+= 0x9e3779b97f4a7c15; var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9; z = (z ^ (z >> 27)) &* 0x94d049bb133111eb; return (z ^ (z >> 31)) % n
    } }
    /// The backend's conversion before M5c, one array per channel.
    func floats(_ pcm: [UInt8], bits: Int, channels: Int, alignment: Int) -> [[Float]] {
        (0..<channels).map { channel in (0..<pcm.count / alignment).map { frame -> Float in
            let index = frame*alignment+channel*(bits/8)
            if bits == 8 { return Float(Int(pcm[index])-128)/128 }
            let word = UInt16(pcm[index]) | (UInt16(pcm[index+1]) << 8)
            return Float(Int16(bitPattern:word))/32768
        } }
    }
    func render(_ samples: Effects.Samples, calls: [[UInt32]], blocks: [Int], rate: Double) throws -> [UInt32] {
        let fx = Effects { _ in samples }
        var out: [UInt32] = []
        for (k, words) in calls.enumerated() {
            try fx.perform(try XCTUnwrap(Effects.Call(words)))
            guard blocks[k] > 0 else { continue }
            var l = [Float](repeating: 0, count: blocks[k]), r = l
            l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in fx.render(frames: blocks[k], rate: rate, left: lp.baseAddress!, right: rp.baseAddress!) } }
            out += l.map(\.bitPattern) + r.map(\.bitPattern)
        }
        return out + [UInt32(bitPattern: Int32(fx.rendered.audible)), fx.rendered.peak.bitPattern]
    }

    /// The mixer's loop before M5c, for one voice playing from `start` at
    /// gains from `volume` and `pan`, then clipped as `render` clips.
    func referenceRender(_ channels: [[Float]], rate: Double, output: Double, start: Int, looping: Bool, volume: Int32, pan: Int32, frames: Int) -> [UInt32] {
        var left = [Float](repeating: 0, count: frames), right = left
        let (gl, gr) = Effects.gains(volume: volume, pan: pan), l = channels[0], r = channels.count > 1 ? channels[1] : channels[0]
        let count = l.count, step = rate/output
        var position = Double(start)
        for i in 0..<frames {
            let index = Int(position), fraction = Float(position-Double(index))
            let next = index+1 < count ? index+1 : (looping ? 0 : index)
            left[i] += (l[index]+(l[next]-l[index])*fraction)*gl
            right[i] += (r[index]+(r[next]-r[index])*fraction)*gr
            position += step
            if position >= Double(count) {
                if looping { position -= Double(count) } else { break }
            }
        }
        return left.map { max(-1, min(1, $0)).bitPattern } + right.map { max(-1, min(1, $0)).bitPattern }
    }

    func testTheMixerMatchesItsPreviousLoop() throws {
        var rng = SplitMix(state: 9)
        for round in 0..<40 {
            let bits = round % 2 == 0 ? 8 : 16, channels = round % 4 < 2 ? 1 : 2, alignment = channels * bits / 8
            let frames = 2 + Int(rng.next(2000))
            let pcm = (0..<frames * alignment).map { _ in UInt8(truncatingIfNeeded: rng.next(256)) }
            let rate = [11025.0, 22050, 44100][round % 3], output = [22050.0, 48000][round % 2]
            let volume = -Int32(rng.next(2500)), pan = Int32(rng.next(1601)) - 800, start = Int(rng.next(UInt64(frames))), looping = round % 5 < 2
            let fx = Effects { _ in Effects.Samples(pcm: pcm, bits: bits, channels: channels, rate: rate, blockAlign: alignment, volume: 0) }
            for words: [[UInt32]] in [[[7, 0x3c, UInt32(bitPattern: volume)], [7, 0x40, UInt32(bitPattern: pan)], [7, 0x34, UInt32(start * alignment)], [7, 0x30, 0, 0, looping ? 1 : 0]]] {
                for w in words { try fx.perform(try XCTUnwrap(Effects.Call(w))) }
            }
            let n = 1 + Int(rng.next(6000))
            var l = [Float](repeating: 0, count: n), r = l
            l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in fx.render(frames: n, rate: output, left: lp.baseAddress!, right: rp.baseAddress!) } }
            let expected = referenceRender(floats(pcm, bits: bits, channels: channels, alignment: alignment), rate: rate, output: output,
                                           start: start, looping: looping, volume: volume, pan: pan, frames: n)
            XCTAssertEqual(l.map(\.bitPattern) + r.map(\.bitPattern), expected, "round \(round)")
        }
    }

    /// The mixer reads PCM through the buffer's address while its indices stay
    /// in the buffer; a looping voice whose step reaches the buffer's length
    /// keeps the bounds-checked readers. Both render what the loop before M5c
    /// rendered, mono (one read per frame for both channels) and stereo.
    func testShortBuffersAndLongStepsMatchThePreviousLoop() throws {
        var rng = SplitMix(state: 13)
        // (frames, rate, output): steps of 1 and 2 on 1- and 2-frame buffers
        // (bounds-checked when looping), and shorter steps (through the address).
        for (frames, rate, output) in [(1, 22050.0, 22050.0), (2, 44100.0, 22050.0), (1, 11025.0, 22050.0), (2, 22050.0, 22050.0), (3, 22050.0, 48000.0)] {
            for bits in [8, 16] { for channels in [1, 2] { for looping in [false, true] { for start in 0..<frames { for extra in 0..<channels * bits / 8 {
                // `extra` bytes of a partial frame after the last whole one.
                let alignment = channels * bits / 8
                let pcm = (0..<frames * alignment + extra).map { _ in UInt8(truncatingIfNeeded: rng.next(256)) }
                let volume = -Int32(rng.next(2500)), pan = Int32(rng.next(1601)) - 800
                let fx = Effects { _ in Effects.Samples(pcm: pcm, bits: bits, channels: channels, rate: rate, blockAlign: alignment, volume: 0) }
                for w: [UInt32] in [[7, 0x3c, UInt32(bitPattern: volume)], [7, 0x40, UInt32(bitPattern: pan)], [7, 0x34, UInt32(start * alignment)], [7, 0x30, 0, 0, looping ? 1 : 0]] {
                    try fx.perform(try XCTUnwrap(Effects.Call(w)))
                }
                let n = 37
                var l = [Float](repeating: 0, count: n), r = l
                l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in fx.render(frames: n, rate: output, left: lp.baseAddress!, right: rp.baseAddress!) } }
                let expected = referenceRender(floats(pcm, bits: bits, channels: channels, alignment: alignment), rate: rate, output: output,
                                               start: start, looping: looping, volume: volume, pan: pan, frames: n)
                XCTAssertEqual(l.map(\.bitPattern) + r.map(\.bitPattern), expected, "frames \(frames) step \(rate/output) bits \(bits) channels \(channels) looping \(looping) start \(start) extra \(extra)")
            } } } } }
        }
        // A voice moved to exactly its end renders nothing and stops.
        for (bits, channels) in [(8, 1), (16, 1), (16, 2)] {
            let alignment = channels * bits / 8, frames = 5
            let fx = Effects { _ in Effects.Samples(pcm: Array(repeating: 200, count: frames * alignment), bits: bits, channels: channels, rate: 22050, blockAlign: alignment, volume: 0) }
            for w: [UInt32] in [[7, 0x34, UInt32(frames * alignment)], [7, 0x30, 0, 0, 1]] { try fx.perform(try XCTUnwrap(Effects.Call(w))) }
            var l = [Float](repeating: 1, count: 9), r = l
            l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in fx.render(frames: 9, rate: 48000, left: lp.baseAddress!, right: rp.baseAddress!) } }
            XCTAssertEqual(l + r, Array(repeating: 0, count: 18), "bits \(bits) channels \(channels)")
        }
    }

    func testPCMRendersLikeItsFloats() throws {
        var rng = SplitMix(state: 5)
        for round in 0..<48 {
            let bits = round % 2 == 0 ? 8 : 16, channels = round % 4 < 2 ? 1 : 2, alignment = channels * bits / 8
            let frames = 1 + Int(rng.next(3000))
            let pcm = (0..<frames * alignment).map { _ in UInt8(truncatingIfNeeded: rng.next(256)) }
            let rate = [8000.0, 11025, 22050, 44100][round % 4], output = [22050.0, 44100, 48000][round % 3]
            let asPCM = Effects.Samples(pcm: pcm, bits: bits, channels: channels, rate: rate, blockAlign: alignment, volume: 0)
            let asFloats = Effects.Samples(channels: floats(pcm, bits: bits, channels: channels, alignment: alignment), rate: rate, blockAlign: alignment, volume: 0)
            XCTAssertEqual(asPCM.channels, asFloats.channels)
            let looping: UInt32 = round % 5 < 2 ? 1 : 0
            let calls: [[UInt32]] = [[7, 0x3c, UInt32(bitPattern: -Int32(rng.next(3000)))], [7, 0x40, UInt32(bitPattern: Int32(rng.next(2001)) - 1000)],
                                     [7, 0x34, UInt32(rng.next(UInt64(frames * alignment)))], [7, 0x30, 0, 0, looping], [7, 0x48], [7, 0x30, 0, 0, looping]]
            let blocks = [0, 0, 0, Int(rng.next(5000)), 7, Int(rng.next(9000))]
            XCTAssertEqual(try render(asPCM, calls: calls, blocks: blocks, rate: output), try render(asFloats, calls: calls, blocks: blocks, rate: output), "round \(round)")
        }
    }
}
