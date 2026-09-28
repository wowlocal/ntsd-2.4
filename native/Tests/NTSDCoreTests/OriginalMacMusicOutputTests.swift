import AVFoundation
import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform

/// Music output follows only the committed DirectShow graph state; the packaged
/// tracks are the manifest's lossless decodes.
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
        var wide: [UInt8] = []
        for byte in Array(path.utf8)+[0] { wide += [byte,0] }
        XCTAssertEqual(try music.answer(.init(.method,[graph,0x34,0x30000000,0],[wide])).result,0)
        let audio = try XCTUnwrap(music.answer(.init(.queryInterface,[graph],[iid(0xb3)])).pointer)
        XCTAssertEqual(try music.answer(.init(.method,[audio,0x1c,UInt32(bitPattern:volume)])).result,0)
        _ = try music.answer(.init(.method,[audio,8]))
        XCTAssertEqual(try music.answer(.init(.method,[control,0x1c])).result,0)
        return (graph,control,event,position)
    }
    func release(_ music: OriginalMacRuntimeMusic,_ g: (graph: UInt32,control: UInt32,event: UInt32,position: UInt32)) throws {
        for pointer in [g.position,g.event,g.control,g.graph] { _ = try music.answer(.init(.method,[pointer,8])) }
    }

    func testPackagedTracksMatchManifestFrames() throws {
        let directory = try XCTUnwrap(Output.directory)
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

    func testRuntimePresentsNewestLiveGraphWithSeeks() throws {
        let music = OriginalMacRuntimeMusic(identities:.init(),heap:.init())
        XCTAssertNil(music.presented())
        let first = try play(music,"bgm\\main.wma",volume:-500)
        var p = try XCTUnwrap(music.presented())
        XCTAssertEqual(p.graph,first.graph); XCTAssertEqual(p.file,Array("bgm\\main.wma".utf8))
        XCTAssertTrue(p.running); XCTAssertEqual(p.volume,-500); XCTAssertEqual(p.seeks,0)
        // put_CurrentPosition(REFTIME): the two argument words hold a double.
        let seconds = 12.5.bitPattern
        _ = try music.answer(.init(.method,[first.position,0x20,UInt32(truncatingIfNeeded:seconds),UInt32(seconds >> 32)]))
        p = try XCTUnwrap(music.presented()); XCTAssertEqual(p.seeks,1); XCTAssertEqual(p.position,12.5)
        XCTAssertThrowsError(try music.answer(.init(.method,[first.position,0x20,0,0xfff00000])))
        _ = try music.answer(.init(.method,[first.control,0x24])); XCTAssertFalse(try XCTUnwrap(music.presented()).running)
        try release(music,first); XCTAssertNil(music.presented())
        let second = try play(music,"bgm\\boss1.wma",volume:0)
        XCTAssertEqual(music.presented()?.graph,second.graph); XCTAssertNotEqual(second.graph,first.graph)
    }

    func testOutputFollowsGraphStateAndStaysSilentAfterTheEnd() throws {
        let main = URL(fileURLWithPath:"/main.caf"),boss = URL(fileURLWithPath:"/boss1.caf")
        var players: [Recorder] = [],ends: [() -> Void] = []
        let output = Output(tracks:["bgm\\main.wma":main,"bgm\\boss1.wma":boss]) { url,ended in
            let r = Recorder(url,duration:100); players.append(r); ends.append(ended); return r
        }
        typealias P = OriginalMacRuntimeMusic.Presented
        try output.present(nil); XCTAssertTrue(players.isEmpty); XCTAssertNil(output.state)
        try output.present(P(graph:1,file:Array("BGM\\Main.wma".utf8),running:false,volume:-2000,seeks:0,position:0))
        XCTAssertEqual(players.count,1); XCTAssertEqual(players[0].url,main); XCTAssertFalse(players[0].isPlaying)
        XCTAssertEqual(players[0].volume,0.1,accuracy:1e-6)
        try output.present(P(graph:1,file:Array("bgm\\main.wma".utf8),running:true,volume:-2000,seeks:0,position:0))
        XCTAssertEqual(players.count,1); XCTAssertEqual(players[0].log,["play@0.0"])
        // Seek applies once per put_CurrentPosition, clamped to the track.
        try output.present(P(graph:1,file:Array("bgm\\main.wma".utf8),running:true,volume:0,seeks:1,position:250))
        XCTAssertEqual(players[0].currentTime,100); XCTAssertEqual(players[0].volume,1)
        players[0].currentTime = 40
        try output.present(P(graph:1,file:Array("bgm\\main.wma".utf8),running:true,volume:0,seeks:1,position:250))
        XCTAssertEqual(players[0].currentTime,40)
        // The end keeps the running graph silent until the next seek.
        players[0].isPlaying = false; ends[0]()
        try output.present(P(graph:1,file:Array("bgm\\main.wma".utf8),running:true,volume:0,seeks:1,position:250))
        XCTAssertFalse(players[0].isPlaying); XCTAssertEqual(output.state?.ended,true)
        try output.present(P(graph:1,file:Array("bgm\\main.wma".utf8),running:true,volume:0,seeks:2,position:0))
        XCTAssertTrue(players[0].isPlaying); XCTAssertEqual(players[0].currentTime,0); XCTAssertEqual(output.state?.ended,false)
        // Stop pauses; a new graph loads a new player even for the same track.
        try output.present(P(graph:1,file:Array("bgm\\main.wma".utf8),running:false,volume:0,seeks:2,position:0))
        XCTAssertFalse(players[0].isPlaying)
        try output.present(P(graph:2,file:Array("bgm\\main.wma".utf8),running:true,volume:-10000,seeks:0,position:0))
        XCTAssertEqual(players.count,2); XCTAssertTrue(players[1].isPlaying); XCTAssertEqual(players[1].volume,0)
        ends[0](); XCTAssertEqual(output.state?.ended,false)
        output.muted = true
        try output.present(P(graph:3,file:Array("bgm\\boss1.wma".utf8),running:true,volume:0,seeks:0,position:0))
        XCTAssertEqual(players.count,3); XCTAssertEqual(players[2].url,boss); XCTAssertEqual(players[2].volume,0)
        XCTAssertFalse(players[1].isPlaying)
        // Unknown files stay silent and are reported once per graph.
        try output.present(P(graph:4,file:Array("bgm\\other.wma".utf8),running:true,volume:0,seeks:0,position:0))
        try output.present(P(graph:4,file:Array("bgm\\other.wma".utf8),running:true,volume:0,seeks:0,position:0))
        XCTAssertEqual(output.unresolved,[Array("bgm\\other.wma".utf8)]); XCTAssertFalse(players[2].isPlaying)
        try output.present(nil); XCTAssertEqual(players.count,3)
    }

    func testVolumeGainIsHundredthsOfDecibel() {
        XCTAssertEqual(Output.gain(0),1); XCTAssertEqual(Output.gain(-2000),0.1,accuracy:1e-6)
        XCTAssertEqual(Output.gain(-3900),Float(pow(10,-1.95)),accuracy:1e-6)
        XCTAssertEqual(Output.gain(-10000),0); XCTAssertEqual(Output.gain(5),1)
    }
}

private extension Int { var asInt64: Int64 { Int64(self) } }
