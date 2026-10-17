import Foundation
import CryptoKit
import NTSDCore

/// Development-only comparison with the frozen six whole-body source calls.
/// Expected records initialize no runtime state; input backing/fields and streams
/// independently construct the candidate before its complete records are checked.
public enum NTSD2833ObjectReference {
    public struct Result {
        public let cases: Int, calls: Int, postCallBytes: Int, stores: Int, sourceBoundaries: Int
    }
    private struct Blob: Decodable { let count: Int, deflate: String }
    private struct InputCall: Decodable { let streamHex: String, patches: [[Int64]] }
    private struct Input: Decodable {
        let id: String, backingByte: UInt8, initialFields: [[Int64]], calls: [InputCall]
    }
    private struct Event: Decodable {
        let kind: String
        let bytes: IntOrString?, cursor: Int?, before: Int?, after: Int?, result: UInt32?, owner: String?
        enum IntOrString: Decodable {
            case count(Int), hex(String)
            init(from decoder: Decoder) throws {
                let value = try decoder.singleValueContainer()
                if let n = try? value.decode(Int.self) { self = .count(n) }
                else { self = .hex(try value.decode(String.self)) }
            }
        }
        func normalized() throws -> NTSD2833ObjectStorage.Event {
            switch kind {
            case "open":
                if case .some(.count(let n)) = bytes, let cursor { return .open(bytes: n, cursor: cursor) }
            case "token":
                if case .some(.hex(let value)) = bytes, let before, let after {
                    return .token(bytes: try NTSD2833ObjectReference.hex(value), before: before, after: after)
                }
            case "eof":
                if let cursor, let result, result == 0 || result == UInt32.max {
                    return .eof(cursor: cursor, ended: result == UInt32.max)
                }
            case "close": return .close
            case "free":
                if owner == "owned stream buffer" { return .releaseBuffer }
                if owner == "owned stream record" { return .releaseCursor }
            default: break
            }
            throw OriginalStateError.invalidStorage("Unknown target Object event")
        }
    }
    private struct Group: Decodable { let offset: Int, size: Int, count: Int, value: String }
    private struct WordRun: Equatable { let offset: Int, value: UInt32; var count: Int }
    private struct Call: Decodable {
        let input: InputCall, outcome: String, error: String?
        let objectBytes: String, objectDefined: String, events: [Event], writeGroups: [Group]
        let objectWrites: Int, returnedESP: UInt32, expectedReturnedESP: UInt32
        let preservedRegisters: Bool, liveStreamOwners: Int, pendingCallbacks: Int
        let terminalPC: UInt32?
    }
    private struct Case: Decodable {
        let id: String, input: Input, initialObjectBytes: String, initialObjectDefined: String, calls: [Call]
    }
    private struct Corpus: Decodable {
        let runID: String, blobEncoding: String, sourceResultSHA256: String, filenameAddress: UInt32
        let cases: [Case], blobs: [String: Blob]
    }
    private static func hex(_ string: String) throws -> [UInt8] {
        let chars = Array(string.utf8)
        guard chars.count % 2 == 0 else { throw OriginalStateError.invalidStorage("Odd target hex") }
        func nibble(_ b: UInt8) throws -> UInt8 {
            switch b {
            case 48...57: return b - 48
            case 97...102: return b - 87
            default: throw OriginalStateError.invalidStorage("Invalid target hex")
            }
        }
        return try stride(from: 0, to: chars.count, by: 2).map { try nibble(chars[$0])*16 + nibble(chars[$0+1]) }
    }
    public static func compare(_ data: Data) throws -> Result {
        let corpus = try JSONDecoder().decode(Corpus.self, from: data)
        let expected: (hash: String, cases: Int, calls: Int, boundaries: Int)
        switch corpus.runID {
        case "object-body1": expected = ("74f39ef256e6dcb50e9023181e28dc8704368b127a6ea99cdeeb55582a6b8d25", 4, 6, 0)
        case "object-body-counter1": expected = ("52bb8a7c2a028dc6244acf1fdd1613dcf433039ea843edbbd5e2d646be64aeaf", 2, 1, 1)
        default: throw OriginalStateError.invalidStorage("Unknown whole target Object corpus")
        }
        guard corpus.blobEncoding == "raw-deflate", corpus.sourceResultSHA256 == expected.hash,
              corpus.cases.count == expected.cases,
              corpus.cases.reduce(0, { $0 + $1.calls.count }) == expected.calls+expected.boundaries else {
            throw OriginalStateError.invalidStorage("Unknown whole target Object corpus")
        }
        var blobs: [String: [UInt8]] = [:]
        for (key, blob) in corpus.blobs {
            guard blob.count == NTSD2833ObjectStorage.allocationSize,
                  let compressed = Data(base64Encoded: blob.deflate) else {
                throw OriginalStateError.invalidStorage("Invalid target Object blob")
            }
            var bytes = [UInt8](repeating: 0, count: blob.count+1)
            let n = bytes.withUnsafeMutableBufferPointer { output in
                compressed.withUnsafeBytes { input in
                    FixtureInflate.decode(output.baseAddress!, output.count,
                        input.bindMemory(to: UInt8.self).baseAddress!, input.count)
                }
            }
            guard n == blob.count else { throw OriginalStateError.invalidStorage("Target blob inflate length") }
            bytes.removeLast()
            guard SHA256.hash(data: Data(bytes)).map({ String(format: "%02x", $0) }).joined() == key else {
                throw OriginalStateError.invalidStorage("Target blob SHA-256")
            }
            blobs[key] = bytes
        }
        func blob(_ key: String) throws -> [UInt8] {
            guard let bytes = blobs[key] else { throw OriginalStateError.invalidStorage("Missing target Object blob") }
            return bytes
        }
        func check(_ record: OriginalStateRecord, bytes key: String, mask: String, label: String) throws {
            let bytes = try blob(key), defined = try blob(mask), actual = record.bytes, actualMask = record.defined
            guard defined.allSatisfy({ $0 <= 1 }), actual.count == bytes.count else {
                throw OriginalStateError.invalidStorage("Invalid target comparison extent")
            }
            if let i = bytes.indices.first(where: { actual[$0] != bytes[$0] || actualMask[$0] != (defined[$0] == 1) }) {
                throw OriginalStateError.invalidStorage("\(label): byte/mask differs at +\(String(i, radix: 16))")
            }
        }
        func patch(_ fields: [[Int64]], _ record: inout OriginalStateRecord) throws {
            for field in fields {
                guard field.count == 2, field[0] >= 0, field[0] <= Int64(record.byteCount-4) else {
                    throw OriginalStateError.invalidStorage("Invalid target input field")
                }
                try record.write(UInt32(truncatingIfNeeded: field[1]), at: Int(field[0]))
            }
        }
        var calls = 0, stores = 0, boundaries = 0
        for item in corpus.cases {
            guard item.id == item.input.id, item.calls.count == item.input.calls.count else {
                throw OriginalStateError.invalidStorage("Target case identity/count differs")
            }
            var incoming = try OriginalStateRecord(
                bytes: Array(repeating: item.input.backingByte, count: NTSD2833ObjectStorage.allocationSize),
                defined: Array(repeating: false, count: NTSD2833ObjectStorage.allocationSize))
            try patch(item.input.initialFields, &incoming)
            try incoming.write(corpus.filenameAddress, at: 0x7a8)
            try check(incoming, bytes: item.initialObjectBytes, mask: item.initialObjectDefined, label: item.id+" input")
            // This filename is the declared Open input in the frozen plan, not
            // bytes taken from an expected after-state or a source heap image.
            let name = Array("owned-unit.txt".utf8)
            var object = try NTSD2833ObjectStorage(storage: incoming, fileName: name)
            for call in item.calls {
                for field in call.input.patches {
                    guard field.count == 2 else { throw OriginalStateError.invalidStorage("Invalid repeated target field") }
                    try object.writeIncomingWord(UInt32(truncatingIfNeeded: field[1]), at: Int(field[0]))
                }
                let file = try NTSD2833FileBytes(raw: hex(call.input.streamHex), fileName: name)
                if call.outcome == "unsupported-boundary" {
                    guard corpus.runID == "object-body-counter1", call.terminalPC == 0x425010,
                          call.error == "Undeclared instruction 0x425010+7", call.liveStreamOwners == 2 else {
                        throw OriginalStateError.invalidStorage("Unknown source boundary")
                    }
                    let before = object.storage
                    do {
                        try object.loadBody(file)
                        throw OriginalStateError.invalidStorage("Missing Native helper boundary")
                    } catch let error as NTSD2833ObjectStorage.Boundary {
                        guard error == .callerHelper(0x425010) else { throw error }
                    }
                    guard object.storage == before else {
                        throw OriginalStateError.invalidStorage("Native boundary failed rollback")
                    }
                    // The source did not return or close its streams. Its
                    // retained partial after-state is not a successful match to
                    // Native rollback; count the boundary separately.
                    boundaries += 1
                    continue
                }
                guard call.outcome == "returned", call.error == nil,
                      call.returnedESP == call.expectedReturnedESP, call.preservedRegisters,
                      call.liveStreamOwners == 0, call.pendingCallbacks == 0 else {
                    throw OriginalStateError.invalidStorage("Source call is not a checked whole return")
                }
                var actualRuns: [WordRun] = []
                let receipt = try object.loadBody(file) { offset, value in
                    if let last = actualRuns.last, last.offset+4*last.count == offset, last.value == value {
                        actualRuns[actualRuns.count-1].count += 1
                    } else { actualRuns.append(.init(offset: offset, value: value, count: 1)) }
                }
                let expectedRuns = try call.writeGroups.map { group -> WordRun in
                    let bytes = try hex(group.value)
                    guard group.size == 4, bytes.count == 4, group.count > 0 else {
                        throw OriginalStateError.invalidStorage("Invalid source Object write run")
                    }
                    let value = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8*$1.offset) }
                    return .init(offset: group.offset, value: value, count: group.count)
                }
                guard actualRuns == expectedRuns,
                      actualRuns.reduce(0, { $0 + $1.count }) == call.objectWrites else {
                    throw OriginalStateError.invalidStorage("\(item.id): ordered Object stores differ")
                }
                guard receipt.events == (try call.events.map { try $0.normalized() }), receipt.liveStreamOwners == 0 else {
                    throw OriginalStateError.invalidStorage("\(item.id): stream cursor/lifetime events differ")
                }
                try check(object.storage, bytes: call.objectBytes, mask: call.objectDefined, label: item.id)
                calls += 1; stores += call.objectWrites
            }
        }
        guard calls == expected.calls, boundaries == expected.boundaries else {
            throw OriginalStateError.invalidStorage("Wrong returned/boundary counts")
        }
        return .init(cases: corpus.cases.count, calls: calls,
                     postCallBytes: calls*NTSD2833ObjectStorage.allocationSize, stores: stores, sourceBoundaries: boundaries)
    }
}
