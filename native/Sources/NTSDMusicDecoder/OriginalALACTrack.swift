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
    /// The track with its file mapped, not read (MEMORY_LOADING M8: a reader
    /// then holds no copy of the file's bytes).
    public init(mapping url: URL) throws {
        let mapped = try Data(contentsOf:url,options:.alwaysMapped)
        // The ALAC decoder reads up to 8 bytes past a packet, and the last
        // packet ends the file: a file ending within 64 bytes of a page edge
        // (4 or 16 KiB pages) is read instead, so no read crosses the mapping.
        let edge = { (page: Int) in mapped.count % page == 0 || mapped.count % page > page-64 }
        try self.init(data:edge(4096) || edge(16384) ? Data(contentsOf:url) : mapped)
    }
    public init(data file: Data) throws {
        // Parsed in place: a copy of the file's bytes (up to 28 MB) is not needed.
        let parsed = try file.withUnsafeBytes { try Self.parse($0) }
        sampleRate = parsed.sampleRate; channels = parsed.channels; frames = parsed.frames
        priming = parsed.priming; cookie = parsed.cookie; data = file; packets = parsed.packets
    }
    private static func parse(_ bytes: UnsafeRawBufferPointer) throws
        -> (sampleRate: Double,channels: Int,frames: Int,priming: Int,cookie: [UInt8],packets: [(offset: Int,size: Int)]) {
        func be(_ at: Int,_ count: Int) -> UInt64 { bytes[at..<at+count].reduce(0) { $0 << 8 | UInt64($1) } }
        guard bytes.count >= 8,bytes[0..<4].elementsEqual([0x63,0x61,0x66,0x66]),be(4,2) == 1 else { throw Failure.notCAF }
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
        let sampleRate = Double(bitPattern:be(desc.lowerBound,8))
        guard String(decoding:bytes[desc.lowerBound+8..<desc.lowerBound+12],as:UTF8.self) == "alac" else { throw Failure.unsupported("format") }
        let channels = Int(be(desc.lowerBound+24,4))
        let packetCount = Int(be(pakt.lowerBound,8)),valid = Int(be(pakt.lowerBound+8,8))
        let priming = Int(be(pakt.lowerBound+16,4))
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
        return (sampleRate,channels,valid,priming,Array(bytes[kuki]),sizes)
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

    /// The track's samples on demand, from any frame, a packet at a time
    /// (MEMORY_LOADING M8): the values `decode` gives, without holding the
    /// whole track (a 3-minute track is ~32 MB of PCM). ALAC packets decode
    /// independently, and every packet but the last holds the decoder's frame
    /// length (checked as each decodes), so frame f is in packet
    /// (f + priming) / length. One thread at a time.
    public final class Reader {
        public let track: OriginalALACTrack
        private let decoder: OpaquePointer, length: Int
        private var buffer: [Int16], bufferPacket = -1, bufferFrames = 0
        public init(_ track: OriginalALACTrack) throws {
            guard let decoder = track.cookie.withUnsafeBufferPointer({ ntsd_alac_create($0.baseAddress,UInt32($0.count)) }) else { throw Failure.unsupported("cookie") }
            guard ntsd_alac_bit_depth(decoder) == 16,Int(ntsd_alac_channels(decoder)) == track.channels else {
                ntsd_alac_destroy(decoder); throw Failure.unsupported("bit depth or channels")
            }
            let length = Int(ntsd_alac_frame_length(decoder))
            // Frame f is in packet (f + priming) / length only when the packets
            // can hold every frame at that length.
            guard length > 0,track.packets.count*length >= track.priming+track.frames else {
                ntsd_alac_destroy(decoder); throw Failure.unsupported("frame length \(length) for \(track.packets.count) packets")
            }
            self.track = track; self.decoder = decoder; self.length = length
            buffer = [Int16](repeating:0,count:length*track.channels)
        }
        deinit { ntsd_alac_destroy(decoder) }
        /// Copies the interleaved samples of up to `count` frames from frame
        /// `frame` into `out` and returns how many frames it copied: fewer only
        /// at the end of the track.
        public func read(from frame: Int,count: Int,into out: UnsafeMutablePointer<Int16>) throws -> Int {
            let channels = track.channels
            var done = 0,at = frame
            while done < count,at >= 0,at < track.frames {
                let absolute = at+track.priming,packet = absolute/length,offset = absolute%length
                try load(packet)
                let take = min(count-done,length-offset,track.frames-at)
                guard offset+take <= bufferFrames else { throw Failure.corrupt("packet \(packet) is short") }
                buffer.withUnsafeBufferPointer { (out+done*channels).update(from:$0.baseAddress!+offset*channels,count:take*channels) }
                done += take; at += take
            }
            return done
        }
        private func load(_ packet: Int) throws {
            guard packet != bufferPacket else { return }
            guard packet < track.packets.count else { throw Failure.corrupt("frame beyond the packets") }
            let (offset,size) = track.packets[packet],length = self.length,decoder = self.decoder
            let decoded = track.data.withUnsafeBytes { raw in
                buffer.withUnsafeMutableBufferPointer {
                    ntsd_alac_decode(decoder,raw.bindMemory(to:UInt8.self).baseAddress!+offset,UInt32(size),$0.baseAddress,UInt32(length))
                }
            }
            guard decoded >= 0 else { bufferPacket = -1; throw Failure.corrupt("packet at \(offset)") }
            guard Int(decoded) == length || packet == track.packets.count-1 else {
                bufferPacket = -1; throw Failure.corrupt("packet \(packet) holds \(decoded) frames")
            }
            bufferPacket = packet; bufferFrames = Int(decoded)
        }
    }
}
