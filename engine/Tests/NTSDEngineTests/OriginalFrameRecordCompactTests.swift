import Foundation
import XCTest
@testable import NTSDCore

/// MEMORY_LOADING M2: frame records keep their words in slots. Equality, the
/// subscripts and the JSON form must be those of the words dictionary.
final class OriginalFrameRecordCompactTests: XCTestCase {
    struct Generator: RandomNumberGenerator {
        var state: UInt64
        // splitmix64: every output bit mixed (an LCG's low byte repeats every 256 values).
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9; z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
            return z ^ (z >> 31)
        }
    }
    /// The dictionary model the record replaced.
    struct Model: Codable, Equatable {
        let number: Int; let name: String; let words: [String: Int32]; let sound: String?; let opaqueSoundPointer: String?
        let interactions: [[Int32]]; let bodies: [[Int32]]
    }
    func randomWords(_ random: inout Generator) -> [String: Int32] {
        var words: [String: Int32] = [:]
        for _ in 0..<Int.random(in: 0...40, using: &random) {
            let key: String
            switch Int.random(in: 0..<10, using: &random) {
            case 0: key = String(Int.random(in: 0..<0x178, using: &random))            // any offset, often not a slot
            case 1: key = ["04", "+8", "-4", "376", "380", "x", "", "0x10"].randomElement(using: &random)!
            default: key = String(Int.random(in: 0..<94, using: &random) * 4)          // a slot
            }
            words[key] = Int32.random(in: .min ... .max, using: &random)
        }
        return words
    }

    func testWordsEqualityAndSubscriptsAreTheDictionarys() throws {
        var random = Generator(state: 11)
        var records: [(OriginalFrameRecord, [String: Int32])] = []
        for index in 0..<400 {
            var record = OriginalFrameRecord(number: index % 5)
            let words = index % 3 == 0 && !records.isEmpty ? records[index - 1].1 : randomWords(&random)
            record.words = words
            XCTAssertEqual(record.words, words)
            for offset in [-4, 0, 1, 4, 0x128, 0x174, 0x178, 0x17c] { XCTAssertEqual(record[offset], words[String(offset)], "\(offset)") }
            XCTAssertEqual(record.field("pic"), words[String(4)])
            records.append((record, words))
        }
        for _ in 0..<4000 {
            let a = records.randomElement(using: &random)!, b = records.randomElement(using: &random)!
            XCTAssertEqual(a.0 == b.0, a.0.number == b.0.number && a.1 == b.1)
        }
        // Equal words on distinct records with the same number; a second
        // assignment replaces the first; a present zero is not an absent word.
        var first = OriginalFrameRecord(number: 3), second = OriginalFrameRecord(number: 3)
        first.words = ["0": 1, "4": 9, "-0": 5, "+0": 6, "04": 7]; second.words = ["8": 2]
        second.words = ["04": 7, "+0": 6, "-0": 5, "4": 9, "0": 1]
        XCTAssertEqual(first, second); XCTAssertEqual(second.words.count, 5)
        var zero = OriginalFrameRecord(number: 3), absent = OriginalFrameRecord(number: 3)
        zero.words = ["0": 0]; absent.words = [:]
        XCTAssertNotEqual(zero, absent); XCTAssertEqual(zero[0], 0); XCTAssertNil(absent[0])
        zero.words["0"] = nil
        XCTAssertEqual(zero, absent)
        // Words set one by one equal words set at once.
        var stepwise = OriginalFrameRecord(number: 1), whole = OriginalFrameRecord(number: 1)
        stepwise.setWord(7, offset: 8); stepwise.setWord(0, offset: 0)
        whole.words = ["0": 0, "8": 7]
        XCTAssertEqual(stepwise, whole)
    }

    func testJSONIsTheDictionaryForm() throws {
        var random = Generator(state: 23)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        for index in 0..<200 {
            var record = OriginalFrameRecord(number: index)
            record.words = randomWords(&random); record.name = index % 2 == 0 ? "" : "walk\(index)"
            record.sound = index % 3 == 0 ? nil : "data\\\\00\(index).wav"
            record.opaqueSoundPointer = index % 7 == 0 ? "0x1234" : nil
            record.interactions = index % 4 == 0 ? [[1, 2, 3]] : []; record.bodies = index % 5 == 0 ? [[4, 5]] : []
            let model = Model(number: record.number, name: record.name, words: record.words, sound: record.sound,
                              opaqueSoundPointer: record.opaqueSoundPointer, interactions: record.interactions, bodies: record.bodies)
            let json = try encoder.encode(record)
            XCTAssertEqual(json, try encoder.encode(model))
            XCTAssertEqual(try JSONDecoder().decode(OriginalFrameRecord.self, from: json), record)
            XCTAssertEqual(try JSONDecoder().decode(OriginalFrameRecord.self, from: try encoder.encode(model)), record)
        }
        // Missing or null optionals decode as absent; unknown keys are ignored;
        // the other keys are required, as for the synthesized decoder.
        let minimal = #"{"number":1,"name":"a","words":{"0":1},"interactions":[],"bodies":[],"other":5}"#
        let nulls = #"{"number":1,"name":"a","words":{"0":1},"sound":null,"opaqueSoundPointer":null,"interactions":[],"bodies":[]}"#
        var expected = OriginalFrameRecord(number: 1); expected.name = "a"; expected.words = ["0": 1]
        XCTAssertEqual(try JSONDecoder().decode(OriginalFrameRecord.self, from: Data(minimal.utf8)), expected)
        XCTAssertEqual(try JSONDecoder().decode(OriginalFrameRecord.self, from: Data(nulls.utf8)), expected)
        for key in ["number", "name", "words", "interactions", "bodies"] {
            let missing = minimal.replacingOccurrences(of: "\"\(key)\":", with: "\"x\(key)\":")
            XCTAssertThrowsError(try JSONDecoder().decode(OriginalFrameRecord.self, from: Data(missing.utf8)), key)
            XCTAssertThrowsError(try JSONDecoder().decode(Model.self, from: Data(missing.utf8)), key)
        }
    }
}
