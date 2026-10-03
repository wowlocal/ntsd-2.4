import XCTest
@testable import NTSDCore
@testable import NTSDMacPlatform
@testable import NTSDRuntime

/// DirectSound buffer semantics declared in APPLICATION_SOUND_EFFECTS_PLAN.md:
/// the helpers' Stop/SetCurrentPosition/Play/SetPan/SetVolume sequences, the
/// gain law, looping, resampling and mixing.
final class OriginalMacSoundEffectsTests: XCTestCase {
    typealias Effects = OriginalMacSoundEffects
    typealias Call = OriginalMacSoundEffects.Call

    func effects(_ buffers: [UInt32:Effects.Samples]) -> (Effects,() -> [UInt32]) {
        var loads: [UInt32] = []
        let effects = Effects { token in
            loads.append(token)
            guard let samples = buffers[token] else { throw Effects.Boundary.arguments(token) }
            return samples
        }
        return (effects,{ loads })
    }
    func render(_ effects: Effects,_ frames: Int,rate: Double) -> (left: [Float],right: [Float]) {
        var left = [Float](repeating:9,count:frames),right = [Float](repeating:9,count:frames)
        left.withUnsafeMutableBufferPointer { l in right.withUnsafeMutableBufferPointer { r in
            effects.render(frames:frames,rate:rate,left:l.baseAddress!,right:r.baseAddress!)
        } }
        return (left,right)
    }

    func testHelperSequencePlaysFromTheStartAndStopsAtTheEnd() throws {
        // A 16-bit mono buffer (block alignment 2) registered at -10000.
        let samples = Effects.Samples(channels:[[0.5,0.25,-0.5,1]],rate:1000,blockAlign:2,volume:-10000)
        let (fx,loads) = effects([7:samples])
        // Registered volume: silent until the queue sets a volume.
        for words: [UInt32] in [[7,0x48],[7,0x34,0],[7,0x30,0,0,0]] { try fx.perform(try XCTUnwrap(Call(words))) }
        XCTAssertEqual(fx.voice(7),.init(position:0,playing:true,looping:false,volume:-10000,pan:0))
        XCTAssertEqual(render(fx,2,rate:1000).left,[0,0])
        try fx.perform(.init(buffer:7,method:0x3c,arguments:[0]))
        try fx.perform(.init(buffer:7,method:0x34,arguments:[2])) // byte 2 = frame 1
        let out = render(fx,4,rate:1000)
        XCTAssertEqual(out.left,[0.25,-0.5,1,0]); XCTAssertEqual(out.right,out.left)
        XCTAssertEqual(fx.voice(7)?.playing,false); XCTAssertEqual(fx.voice(7)?.position,0)
        XCTAssertEqual(loads(),[7]); XCTAssertEqual(fx.performed,5); XCTAssertEqual(fx.rejected,0)
    }

    func testLoopingStopAndPositionKeep() throws {
        let (fx,_) = effects([1:.init(channels:[[1,2,3]],rate:100,blockAlign:1,volume:0)])
        try fx.perform(.init(buffer:1,method:0x30,arguments:[0,0,1]))
        XCTAssertEqual(render(fx,7,rate:100).left,[1,1,1,1,1,1,1]) // clipped to 1
        XCTAssertEqual(fx.voice(1)?.position,1); XCTAssertEqual(fx.voice(1)?.looping,true)
        try fx.perform(.init(buffer:1,method:0x48,arguments:[]))
        XCTAssertEqual(render(fx,2,rate:100).left,[0,0])
        XCTAssertEqual(fx.voice(1)?.position,1) // Stop keeps the cursor.
    }

    func testGainLawPanAndRejectedRanges() throws {
        XCTAssertEqual(Effects.gains(volume:0,pan:0).left,1)
        XCTAssertEqual(Effects.gains(volume:-2000,pan:0).left,0.1,accuracy:1e-6)
        let panned = Effects.gains(volume:0,pan:1500)
        XCTAssertEqual(panned.right,1); XCTAssertEqual(panned.left,Float(pow(10,-0.75)),accuracy:1e-6)
        let other = Effects.gains(volume:-1000,pan:-2000)
        XCTAssertEqual(other.left,Float(pow(10,-0.5)),accuracy:1e-6)
        XCTAssertEqual(other.right,Float(pow(10,-0.5))*0.1,accuracy:1e-6)
        XCTAssertEqual(Effects.gains(volume:-10000,pan:0).left,0)

        let (fx,_) = effects([2:.init(channels:[[0.5,0.5],[0.25,0.25]],rate:10,blockAlign:4,volume:0)])
        try fx.perform(.init(buffer:2,method:0x3c,arguments:[UInt32(bitPattern:-500)]))
        try fx.perform(.init(buffer:2,method:0x3c,arguments:[1]))                       // above 0
        try fx.perform(.init(buffer:2,method:0x40,arguments:[UInt32(bitPattern:-10001)])) // below -10000
        try fx.perform(.init(buffer:2,method:0x34,arguments:[12]))                      // past the end
        XCTAssertEqual(fx.voice(2),.init(position:0,playing:false,looping:false,volume:-500,pan:0))
        XCTAssertEqual(fx.rejected,3)
    }

    func testStereoMixingAndLinearResampling() throws {
        let (fx,_) = effects([3:.init(channels:[[0,1,0,-1],[1,1,1,1]],rate:2,blockAlign:4,volume:0),
                              4:.init(channels:[[0.25]],rate:4,blockAlign:1,volume:-2000)])
        try fx.perform(.init(buffer:3,method:0x30,arguments:[0,0,0]))
        try fx.perform(.init(buffer:4,method:0x3c,arguments:[0]))
        try fx.perform(.init(buffer:4,method:0x30,arguments:[0,0,0]))
        // Output at 4 Hz: buffer 3 advances half a frame per output frame.
        let out = render(fx,4,rate:4)
        XCTAssertEqual(out.left,[0.25,0.5,1,0.5]); XCTAssertEqual(out.right,[1,1,1,1])
    }

    /// Committed batches: iteration effects, a loaded batch's own effects and
    /// the input phase it carries, in order; round/control methods on music
    /// interface tokens are the round's DirectShow calls, not sounds.
    func testCommittedCallsInOrderWithMusicTokensSeparated() throws {
        typealias Loaded = OriginalApplicationLoadedMenuSession.Operation
        func sound(_ words: [UInt32]) -> OriginalApplicationMenuSession.Effect {
            .soundMethod(OriginalFrontScreenEvent("soundMethod",words),ignoredResult:0)
        }
        XCTAssertEqual(try Effects.calls([sound([4,0x48]),.free(9),sound([4,0x30,0,0,0])]),
                       [.init(buffer:4,method:0x48,arguments:[]),.init(buffer:4,method:0x30,arguments:[0,0,0])])
        let operations: [Loaded] = [
            .preceding(.roundMethod(.init(.method,[9,0x24]))),              // music Stop
            .preceding(.roundMethod(.init(.method,[5,0x34,0]))),            // round sound
            .preceding(.control(.init(.method,[6,0x30,0,0,0]),.init())),    // hotkey sound
            .preceding(.control(.init(.asyncSelect,[1]),.init(result:-1))),
            .preceding(.menu(sound([7,0x48]))),
            .menu(sound([8,0x3c,0])),.clock(3)]
        XCTAssertEqual(try Effects.calls(operations,music:{ $0 == 9 }).map(\.buffer),[5,6,7,8])
        XCTAssertThrowsError(try Effects.calls([.menu(sound([8]))],music:{ _ in false }))
    }

    func testUnknownMethodsAndArgumentCountsAreBoundaries() throws {
        let (fx,_) = effects([5:.init(channels:[[0]],rate:1,blockAlign:1,volume:0)])
        XCTAssertThrowsError(try fx.perform(.init(buffer:5,method:0x2c,arguments:[]))) {
            XCTAssertEqual($0 as? Effects.Boundary,.method(0x2c))
        }
        XCTAssertThrowsError(try fx.perform(.init(buffer:5,method:0x30,arguments:[0]))) {
            XCTAssertEqual($0 as? Effects.Boundary,.arguments(0x30))
        }
        XCTAssertThrowsError(try fx.perform(.init(buffer:6,method:0x48,arguments:[])))
        XCTAssertNil(Call([5])); XCTAssertEqual(fx.performed,0)
    }
}
