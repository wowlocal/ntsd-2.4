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

    func testRejectsNonCAFData() {
        XCTAssertThrowsError(try OriginalALACTrack(data:Data("not a caf".utf8))) { XCTAssertEqual($0 as? OriginalALACTrack.Failure,.notCAF) }
    }
}
