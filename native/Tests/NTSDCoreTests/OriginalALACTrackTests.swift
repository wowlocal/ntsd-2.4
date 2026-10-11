import XCTest
@testable import NTSDCore
import NTSDMusicDecoder

/// The packaged tracks decode without AVFoundation to exactly the PCM their
/// manifest records (FFmpeg's decode of bgm/*.wma, before ALAC encoding).
final class OriginalALACTrackTests: XCTestCase {
    static let directory = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/NTSDMacPlatform/Resources/OriginalMusic",isDirectory:true)

    func testEveryPackagedTrackDecodesToTheManifestPCM() throws {
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:Self.directory.appendingPathComponent("manifest.json"))) as? [String:Any])
        let entries = try XCTUnwrap(manifest["entries"] as? [[String:Any]])
        XCTAssertEqual(entries.count,8)
        for entry in entries {
            let resource = try XCTUnwrap(entry["resource"] as? String),pcm = try XCTUnwrap(entry["pcm"] as? [String:Any])
            let track = try OriginalALACTrack(contentsOf:Self.directory.appendingPathComponent(resource))
            XCTAssertEqual(track.sampleRate,44100,resource); XCTAssertEqual(track.channels,2,resource)
            XCTAssertEqual(track.frames,(entry["frames"] as? NSNumber)?.intValue,resource)
            var bytes = Data(); bytes.reserveCapacity(track.frames*4)
            try track.decode { samples in
                for s in samples { bytes.append(UInt8(truncatingIfNeeded:s)); bytes.append(UInt8(truncatingIfNeeded:s >> 8)) }
            }
            XCTAssertEqual(bytes.count,(pcm["bytes"] as? NSNumber)?.intValue,resource)
            XCTAssertEqual(PortableSHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined(),pcm["sha256"] as? String,resource)
        }
    }

    /// MEMORY_LOADING M8: the reader gives the whole decode's samples from any
    /// frame, a packet at a time: read through in uneven chunks and from
    /// frames around the priming, packet edges, random places and the end.
    func testTheReaderMatchesTheWholeDecode() throws {
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:Self.directory.appendingPathComponent("manifest.json"))) as? [String:Any])
        var rng = SystemRandomNumberGenerator()
        for entry in try XCTUnwrap(manifest["entries"] as? [[String:Any]]) {
            let resource = try XCTUnwrap(entry["resource"] as? String), url = Self.directory.appendingPathComponent(resource)
            let whole = try OriginalALACTrack(contentsOf:url).samples()
            let track = try OriginalALACTrack(mapping:url), reader = try OriginalALACTrack.Reader(track)
            XCTAssertEqual(track.frames * 2, whole.count, resource)
            // Through the track in chunks of 997 frames (a sequence of callbacks).
            var out = [Int16](repeating:0,count:997*2), at = 0, same = true
            while at < track.frames {
                let got = try out.withUnsafeMutableBufferPointer { try reader.read(from:at,count:997,into:$0.baseAddress!) }
                XCTAssertEqual(got, min(997, track.frames - at), "\(resource) at \(at)")
                if !out[0..<got*2].elementsEqual(whole[at*2..<(at+got)*2]) { same = false; break }
                at += got
            }
            XCTAssertTrue(same, "\(resource) differs at frame \(at)")
            // Seeks: the first frames, packet edges (4096 frames per packet), random frames, the end.
            var starts = [0, 1, 4095, 4096, 4097, 8191, 8192, track.frames - 4097, track.frames - 1, track.frames]
            for _ in 0..<40 { starts.append(Int.random(in:0..<track.frames,using:&rng)) }
            for start in starts {
                let count = Int.random(in:1...9000,using:&rng)
                var part = [Int16](repeating:-1,count:count*2)
                let got = try part.withUnsafeMutableBufferPointer { try reader.read(from:start,count:count,into:$0.baseAddress!) }
                XCTAssertEqual(got, max(0, min(count, track.frames - start)), "\(resource) from \(start)")
                XCTAssertTrue(part[0..<got*2].elementsEqual(whole[start*2..<(start+got)*2]), "\(resource) from \(start)")
            }
        }
    }

    /// Priming longer than a packet (every packaged track has none): a copy of
    /// a track whose packet table claims 5000 priming frames reads like its
    /// whole decode, which drops them.
    func testTheReaderSkipsPriming() throws {
        var bytes = [UInt8](try Data(contentsOf:Self.directory.appendingPathComponent("stage5.caf")))
        let pakt = try XCTUnwrap((0..<bytes.count - 4).first(where: { bytes[$0..<$0+4].elementsEqual(Array("pakt".utf8)) })) + 12
        func be(_ at: Int, _ n: Int) -> UInt64 { bytes[at..<at+n].reduce(0) { $0 << 8 | UInt64($1) } }
        func put(_ at: Int, _ n: Int, _ v: UInt64) { for i in 0..<n { bytes[at+i] = UInt8(truncatingIfNeeded: v >> (8 * UInt64(n - 1 - i))) } }
        let valid = be(pakt + 8, 8), priming: UInt64 = 5000
        put(pakt + 8, 8, valid - priming); put(pakt + 16, 4, priming)
        let track = try OriginalALACTrack(data: Data(bytes)), whole = try track.samples(), reader = try OriginalALACTrack.Reader(track)
        XCTAssertEqual(track.frames, Int(valid - priming)); XCTAssertEqual(whole.count, track.frames * 2)
        var out = [Int16](repeating: 0, count: 4093 * 2), at = 0
        while at < track.frames {
            let got = try out.withUnsafeMutableBufferPointer { try reader.read(from: at, count: 4093, into: $0.baseAddress!) }
            XCTAssertTrue(out[0..<got*2].elementsEqual(whole[at*2..<(at+got)*2]), "at \(at)")
            at += max(got, 1)
        }
        for start in [0, 1, 4096 - 5000 + 4096, 3191, 3192, 7287, track.frames - 1] {
            var part = [Int16](repeating: -1, count: 100 * 2)
            let got = try part.withUnsafeMutableBufferPointer { try reader.read(from: start, count: 100, into: $0.baseAddress!) }
            XCTAssertTrue(part[0..<got*2].elementsEqual(whole[start*2..<(start+got)*2]), "from \(start)")
        }
    }

    /// The parse without a copy of the file keeps the old answers: the fields,
    /// or the error, of the parser before M8 (a copy of it below) for the real
    /// file, the file cut at many lengths and with each chunk renamed.
    func testParsingInPlaceKeepsItsAnswers() throws {
        let url = Self.directory.appendingPathComponent("stage5.caf"), file = try Data(contentsOf:url)
        let mapped = try OriginalALACTrack(mapping:url)
        XCTAssertEqual(mapped.frames, try OriginalALACTrack(data:file).frames)
        var inputs: [Data] = [file, Data(), Data([0x63,0x61,0x66,0x66,0,2,0,0]), Data([0x63,0x61,0x66,0x66,0,1,0,0]),
                              Data([0x63,0x61,0x66,0x66,0,1,0,0] + Array("desc".utf8) + [0,0,0,0,0,0,0,99])]
        for k in 1..<24 { inputs.append(file.prefix(file.count * k / 24)) }
        for k in [9, 13, 20, 33, 40, 60, 100, 200, 400, 1000] { inputs.append(file.prefix(k)) }
        let bytes = [UInt8](file)
        for name in ["desc", "kuki", "pakt", "data"] {
            if let at = (0..<bytes.count - 4).first(where: { bytes[$0..<$0+4].elementsEqual(Array(name.utf8)) }) {
                var b = bytes; b[at+3] ^= 0x20; inputs.append(Data(b))
            }
        }
        for (i, data) in inputs.enumerated() {
            let mine = Result { try OriginalALACTrack(data:data) }, old = Result { try Self.parseBeforeM8(data) }
            switch (mine, old) {
            case (.success(let t), .success(let o)):
                XCTAssertEqual(t.sampleRate, o.sampleRate, "input \(i)"); XCTAssertEqual(t.channels, o.channels, "input \(i)"); XCTAssertEqual(t.frames, o.frames, "input \(i)")
            case (.failure(let a), .failure(let b)): XCTAssertEqual(a as? OriginalALACTrack.Failure, b as? OriginalALACTrack.Failure, "input \(i)")
            default: XCTFail("input \(i): \(mine) against \(old)")
            }
        }
    }
    /// OriginalALACTrack.init(data:) before M8, verbatim apart from its result.
    static func parseBeforeM8(_ file: Data) throws -> (sampleRate: Double, channels: Int, frames: Int) {
        typealias Failure = OriginalALACTrack.Failure
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
        guard chunks["kuki"] != nil else { throw Failure.missingChunk("kuki") }
        guard let pakt = chunks["pakt"],pakt.count >= 24 else { throw Failure.missingChunk("pakt") }
        guard let audio = chunks["data"],audio.count >= 4 else { throw Failure.missingChunk("data") }
        let sampleRate = Double(bitPattern:be(desc.lowerBound,8))
        guard String(decoding:bytes[desc.lowerBound+8..<desc.lowerBound+12],as:UTF8.self) == "alac" else { throw Failure.unsupported("format") }
        let channels = Int(be(desc.lowerBound+24,4))
        let packetCount = Int(be(pakt.lowerBound,8)),valid = Int(be(pakt.lowerBound+8,8))
        var cursor = pakt.lowerBound+24,offset = audio.lowerBound+4
        for _ in 0..<packetCount {
            var value = 0
            repeat {
                guard cursor < pakt.upperBound else { throw Failure.corrupt("pakt") }
                value = value << 7 | Int(bytes[cursor] & 0x7f); cursor += 1
            } while bytes[cursor-1] & 0x80 != 0
            guard offset+value <= audio.upperBound else { throw Failure.corrupt("data") }
            offset += value
        }
        return (sampleRate,channels,valid)
    }

    func testRejectsNonCAFData() {
        XCTAssertThrowsError(try OriginalALACTrack(data:Data("not a caf".utf8))) { XCTAssertEqual($0 as? OriginalALACTrack.Failure,.notCAF) }
    }
}
