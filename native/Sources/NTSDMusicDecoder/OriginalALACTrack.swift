import CALAC
import Foundation

/// A packaged original track: a CAF file holding ALAC, as written by
/// tools/package_music.py. Decodes to interleaved 16-bit PCM without
/// AVFoundation; the result equals the manifest's PCM (lossless).
public struct OriginalALACTrack {
    public enum Failure: Error, Equatable { case notCAF, missingChunk(String), unsupported(String), corrupt(String) }
    public let sampleRate: Double, channels: Int, frames: Int
    private let cookie: [UInt8], data: Data, packets: [(offset: Int,size: Int)], priming: Int

    public init(contentsOf url: URL) throws { try self.init(data:Data(contentsOf:url,options:.mappedIfSafe)) }
    public init(data file: Data) throws {
        let bytes = [UInt8](file)
        func be(_ at: Int,_ count: Int) -> UInt64 { bytes[at..<at+count].reduce(0) { $0 << 8 | UInt64($1) } }
        guard bytes.count >= 8,bytes[0..<4] == [0x63,0x61,0x66,0x66],be(4,2) == 1 else { throw Failure.notCAF }
        var chunks: [String:Range<Int>] = [:],at = 8
        while at+12 <= bytes.count {
            let type = String(decoding:bytes[at..<at+4],as:UTF8.self),size = Int64(bitPattern:be(at+4,8))
            let start = at+12,end = size < 0 ? bytes.count : start+Int(size)
            guard end <= bytes.count else { throw Failure.corrupt("chunk \(type)") }
            chunks[type] = start..<end; at = end
        }
        guard let desc = chunks["desc"],desc.count >= 32 else { throw Failure.missingChunk("desc") }
        guard let kuki = chunks["kuki"] else { throw Failure.missingChunk("kuki") }
        guard let pakt = chunks["pakt"],pakt.count >= 24 else { throw Failure.missingChunk("pakt") }
        guard let audio = chunks["data"],audio.count >= 4 else { throw Failure.missingChunk("data") }
        sampleRate = Double(bitPattern:be(desc.lowerBound,8))
        guard String(decoding:bytes[desc.lowerBound+8..<desc.lowerBound+12],as:UTF8.self) == "alac" else { throw Failure.unsupported("format") }
        channels = Int(be(desc.lowerBound+24,4))
        let packetCount = Int(be(pakt.lowerBound,8)),valid = Int(be(pakt.lowerBound+8,8))
        priming = Int(be(pakt.lowerBound+16,4)); frames = valid
        // Packet sizes: variable-length integers, seven bits per byte, high bit continues.
        var sizes: [(Int,Int)] = [],cursor = pakt.lowerBound+24,offset = audio.lowerBound+4
        sizes.reserveCapacity(packetCount)
        for _ in 0..<packetCount {
            var value = 0
            repeat {
                guard cursor < pakt.upperBound else { throw Failure.corrupt("pakt") }
                value = value << 7 | Int(bytes[cursor] & 0x7f); cursor += 1
            } while bytes[cursor-1] & 0x80 != 0
            guard offset+value <= audio.upperBound else { throw Failure.corrupt("data") }
            sizes.append((offset,value)); offset += value
        }
        cookie = Array(bytes[kuki]); data = file; packets = sizes
    }

    /// Decodes the whole track, calling `body` with each packet's interleaved
    /// samples in order (priming and remainder frames removed).
    public func decode(_ body: (UnsafeBufferPointer<Int16>) throws -> Void) throws {
        guard let decoder = cookie.withUnsafeBufferPointer({ ntsd_alac_create($0.baseAddress,UInt32($0.count)) }) else { throw Failure.unsupported("cookie") }
        defer { ntsd_alac_destroy(decoder) }
        guard ntsd_alac_bit_depth(decoder) == 16,Int(ntsd_alac_channels(decoder)) == channels else { throw Failure.unsupported("bit depth or channels") }
        let length = Int(ntsd_alac_frame_length(decoder))
        var buffer = [Int16](repeating:0,count:length*channels),skip = priming,remaining = frames
        try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let base = raw.bindMemory(to:UInt8.self).baseAddress!
            for (offset,size) in packets where remaining > 0 {
                let decoded = buffer.withUnsafeMutableBufferPointer { ntsd_alac_decode(decoder,base+offset,UInt32(size),$0.baseAddress,UInt32(length)) }
                guard decoded >= 0 else { throw Failure.corrupt("packet at \(offset)") }
                let drop = min(skip,Int(decoded)); skip -= drop
                let take = min(Int(decoded)-drop,remaining); remaining -= take
                try buffer.withUnsafeBufferPointer { try body(UnsafeBufferPointer(rebasing:$0[drop*channels..<(drop+take)*channels])) }
            }
        }
        guard remaining == 0 else { throw Failure.corrupt("short by \(remaining) frames") }
    }
    /// The whole track's interleaved samples.
    public func samples() throws -> [Int16] {
        var out: [Int16] = []; out.reserveCapacity(frames*channels)
        try decode { out.append(contentsOf:$0) }
        return out
    }
}
