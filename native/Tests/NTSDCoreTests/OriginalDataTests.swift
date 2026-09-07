import XCTest
@testable import NTSDCore

final class OriginalDataTests: XCTestCase {
    func testLosslessLiteralsAndRepeatedFramesSurviveSwiftDecoding() throws {
        let json = #"""
        {"objects":[{"id":2,"type":0,"source":"chars/naruto.dat","header":{"walking_speed":"4.000000"},
        "sheets":[],"frames":{"123":{"name":"second","fields":{"pic":"50","wait":"0"},"blocks":{}}},
        "frameOccurrences":[
        {"number":123,"frame":{"name":"first","fields":{"dvx":"99999999999999999999999"},"blocks":{"bdy":[{"y":"18"},{"y":"80000"}]}}},
        {"number":123,"frame":{"name":"second","fields":{"pic":"50","wait":"0"},"blocks":{}}}]}],
        "backgrounds":[],"files":{"sprite/sys/naruto_0.bmp":"sprite/sys/Naruto_0.bmp"}}
        """#
        let data = try JSONDecoder().decode(GameData.self, from: Data(json.utf8))
        let original = try XCTUnwrap(data.objects.first)
        let occurrences = try XCTUnwrap(original.frameOccurrences)
        XCTAssertEqual(occurrences.count, 2)
        XCTAssertEqual(occurrences.map(\.number), [123, 123])
        XCTAssertEqual(occurrences[0].frame.fields["dvx"], "99999999999999999999999")
        XCTAssertEqual(occurrences[0].frame.block("bdy").map { $0["y"] }, ["18", "80000"])
        XCTAssertEqual(original.header["walking_speed"], "4.000000")
        XCTAssertEqual(data.resourcePath("SPRITE\\SYS\\naruto_0.bmp"), "sprite/sys/Naruto_0.bmp")
    }

    func testOriginalCorpusLoadsWithoutCollapsingDuplicateDefinitions() throws {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let imported = native.deletingLastPathComponent().appendingPathComponent("build/imported/game.json")
        guard FileManager.default.fileExists(atPath: imported.path) else {
            throw XCTSkip("Run python3 tools/import_ntsd.py for the original corpus integration test")
        }
        let game = try GameData.load(from: imported)
        XCTAssertEqual(game.objects.count, 137)
        XCTAssertEqual(game.backgrounds.count, 17)
        let naruto = try XCTUnwrap(game.object(2))
        XCTAssertEqual(naruto.header["running_speed"], "15.000000")
        XCTAssertEqual(game.object(11)?.header["running_speed"], "23.900000")
        XCTAssertEqual(naruto.frameOccurrences?.filter { $0.number == 123 }.count, 2)
        XCTAssertEqual(naruto.frameOccurrences?.first?.frame.block("bdy").count, 2)
    }
}
