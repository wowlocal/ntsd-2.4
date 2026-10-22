import Foundation
import XCTest
import RandoriMusicDecoder

/// The packaged tracks decode without AVFoundation to exactly the PCM their
/// manifest records (FFmpeg's decode of bgm/*.wma, before ALAC encoding).
/// ENGINE_SPLIT E4c-2: the synthetic half of native's OriginalALACTrackTests; the content-reading tests stay there.
final class OriginalALACTrackTests: XCTestCase {
    func testRejectsNonCAFData() {
        XCTAssertThrowsError(try OriginalALACTrack(data:Data("not a caf".utf8))) { XCTAssertEqual($0 as? OriginalALACTrack.Failure,.notCAF) }
    }
}
