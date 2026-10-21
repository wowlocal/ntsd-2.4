import AVFoundation
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform
@testable import NTSDRuntime

/// Music output follows only the committed DirectShow graph state; the packaged
/// tracks are the manifest's lossless decodes.
/// ENGINE_SPLIT E4c-2: its synthetic tests moved to the engine's NTSDEngineTests (same class name).
@MainActor final class OriginalMacMusicOutputTests: XCTestCase {
    typealias Output = OriginalMacMusicOutput
    final class Recorder: Output.Player {
        var currentTime: TimeInterval = 0, volume: Float = 1, isPlaying = false
        let duration: TimeInterval, url: URL
        var log: [String] = []
        init(_ url: URL,duration: TimeInterval) { self.url = url; self.duration = duration }
        func play() { isPlaying = true; log.append("play@\(currentTime)") }
        func pause() { isPlaying = false; log.append("pause") }
    }
    func iid(_ first: UInt8) -> [UInt8] { [first]+OriginalMacRuntimeMusic.iidTail }
    /// 401c90 + 401da0 + 401f30 + 4020cf as answered by the runtime.
    func play(_ music: OriginalMacRuntimeMusic,_ path: String,volume: Int32) throws -> (graph: UInt32,control: UInt32,event: UInt32,position: UInt32) {
        let graph = try XCTUnwrap(music.answer(.init(.createInstance,[0x44a2a4,0,1,0x44a254,0x44f040])).pointer)
        let control = try XCTUnwrap(music.answer(.init(.queryInterface,[graph],[iid(0xb1)])).pointer)
        let event = try XCTUnwrap(music.answer(.init(.queryInterface,[graph],[iid(0xb6)])).pointer)
        let position = try XCTUnwrap(music.answer(.init(.queryInterface,[graph],[iid(0xb2)])).pointer)
        XCTAssertEqual(try music.answer(.init(.method,[event,0x34,3,0x400,0])).result,0)
        XCTAssertEqual(try music.answer(.init(.method,[event,0x38,0])).result,0)
        var wide: [UInt8] = []
        for byte in Array(path.utf8)+[0] { wide += [byte,0] }
        XCTAssertEqual(try music.answer(.init(.method,[graph,0x34,0x30000000,0],[wide])).result,0)
        let audio = try XCTUnwrap(music.answer(.init(.queryInterface,[graph],[iid(0xb3)])).pointer)
        XCTAssertEqual(try music.answer(.init(.method,[audio,0x1c,UInt32(bitPattern:volume)])).result,0)
        _ = try music.answer(.init(.method,[audio,8]))
        XCTAssertEqual(try music.answer(.init(.method,[control,0x1c])).result,0)
        return (graph,control,event,position)
    }

    func testPackagedTracksMatchManifestFrames() throws {
        let directory = try XCTUnwrap(Output.directory())
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("manifest.json"))) as? [String:Any])
        let entries = try XCTUnwrap(manifest["entries"] as? [[String:Any]])
        XCTAssertEqual(Set(entries.compactMap { $0["name"] as? String }),
                       Set(["boss1","boss2","main","stage1","stage2","stage3","stage4","stage5"].map { "bgm\\\($0).wma" }))
        for entry in entries {
            let file = try AVAudioFile(forReading:directory.appendingPathComponent(try XCTUnwrap(entry["resource"] as? String)))
            XCTAssertEqual(file.length,try XCTUnwrap(entry["frames"] as? Int).asInt64,"\(entry["name"] ?? "")")
            XCTAssertEqual(file.fileFormat.sampleRate,44100); XCTAssertEqual(file.fileFormat.channelCount,2)
        }
        _ = try Output.bundled()
    }
}

private extension Int { var asInt64: Int64 { Int64(self) } }
