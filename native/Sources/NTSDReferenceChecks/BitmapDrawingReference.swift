import Foundation
import NTSDCore

public enum BitmapDrawingReference {
    public struct Result {
        public var cases = 0, setups = 0, sources = 0, constructors = 0, reads = 0, undefinedReads = 0
        public var clips = 0, blits = 0, dualBlits = 0, boundaries = 0, records = 0, bytes = 0
    }
    private struct Blob: Decodable { let count: Int, sha256: String, deflate: String }
    private struct Storage: Decodable { let bytes: String, defined: String }
    private struct Source: Decodable { let path: String, width: Int32, height: Int32, dib: String }
    private struct Constructor: Decodable {
        let resource: OriginalBitmapInput, surface: UInt32, colorKeyResult: Int32
        let events: [OriginalInterfaceEvent]
    }
    private struct Write: Decodable { let offset: Int, value: UInt32 }
    private struct Setup: Decodable { let label: String, backing: String, constructor: Constructor?, writes: [Write], storage: Storage }
    private struct Boundary: Decodable { let kind: String, offset: Int, pc: UInt32 }
    private struct Case: Decodable {
        let label: String, setup: Int, input: OriginalBitmapDrawInput, responses: [Int32]
        let reads: [OriginalBitmapDrawRead], clips: [OriginalBitmapClip], blits: [OriginalBitmapBlit]
        let boundary: Boundary?, endPC: UInt32, endSP: UInt32, returnValue: Int32
        let beforeGlobals: String, afterGlobals: String, after: Storage
    }
    private struct Corpus: Decodable { let exeSHA256: String, sources: [Source], setups: [Setup], cases: [Case], blobs: [String:Blob] }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Bitmap drawing reference: "+text) }

    public static func compare(_ data: Data) throws -> Result {
        let corpus = try JSONDecoder().decode(Corpus.self,from: MatchPreparationReference.unpack(data,maximumCount: 128_000_000))
        guard corpus.exeSHA256 == "3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c",
              corpus.sources.count == 34, !corpus.cases.isEmpty else { throw error("Source identity") }
        var result = Result(), cache: [String:[UInt8]] = [:]
        func blob(_ key: String) throws -> [UInt8] {
            if let bytes = cache[key] { return bytes }
            guard let b = corpus.blobs[key], b.sha256 == key else { throw error("Blob identity") }
            let bytes = try MatchPreparationReference.inflate(b.deflate,count: b.count,maximumCount: 2_000_000)
            guard MatchPreparationReference.digest(Data(bytes)) == key else { throw error("Blob SHA") }
            cache[key] = bytes; return bytes
        }
        func canonical(_ raw: OriginalStateRecord) throws -> OriginalStateRecord {
            var record = raw
            let pointer = try record.integer(at: 0,as: UInt32.self)
            guard pointer == 0 || pointer == 0x22003000 else { throw error("Surface binding") }
            try record.write(UInt32(pointer == 0 ? 0 : 1),at: 0); return record
        }
        func stored(_ reference: Storage) throws -> OriginalStateRecord {
            let bytes = try blob(reference.bytes), mask = try blob(reference.defined)
            guard bytes.count == 0x1f50, mask.count == bytes.count, mask.allSatisfy({ $0<2 }) else { throw error("Bitmap extent/mask") }
            return try canonical(OriginalStateRecord(bytes: bytes,defined: mask.map { $0 == 1 }))
        }
        func check(_ actual: OriginalStateRecord, _ expected: OriginalStateRecord, _ label: String) throws {
            guard actual == expected else {
                let i = actual.bytes.indices.first { $0 >= expected.bytes.count || actual.bytes[$0] != expected.bytes[$0] || actual.defined[$0] != expected.defined[$0] }
                throw error("\(label) storage+\(i.map { String($0,radix:16) } ?? "extent")")
            }
            result.records += 1; result.bytes += actual.bytes.count
        }
        var sources: [String:Source] = [:]
        for source in corpus.sources {
            let bytes = try blob(source.dib)
            guard bytes.count >= 40, sources[source.path] == nil else { throw error("DIB identity") }
            let record = try OriginalStateRecord(bytes: bytes,defined: [Bool](repeating: true,count: bytes.count))
            guard try record.integer(at: 0,as: UInt32.self) >= 40,
                  try record.integer(at: 4,as: Int32.self) == source.width, try record.integer(at: 8,as: Int32.self) == source.height else { throw error("DIB dimensions") }
            sources[source.path] = source;result.sources += 1
        }
        var bitmaps: [OriginalStateRecord] = []
        for setup in corpus.setups {
            let backing = try blob(setup.backing)
            guard backing.count == 0x1f50 else { throw error("Backing extent") }
            var bitmap = try OriginalStateRecord(bytes: backing,defined: [Bool](repeating: false,count: backing.count))
            if let constructor = setup.constructor {
                guard let source = sources[constructor.resource.path], constructor.surface == (constructor.resource.present ? 0x22003000 : 0),
                      constructor.resource.width == (constructor.resource.present ? source.width : nil),
                      constructor.resource.height == (constructor.resource.present ? source.height : nil) else { throw error("Constructor source") }
                var events: [OriginalInterfaceEvent] = []
                let loaded = try OriginalBitmapConstructor.construct(constructor.resource,optional: false,backing: backing,
                    device: 0x22003000,flags: 0x40,surface: constructor.surface,colorKeyResult: constructor.colorKeyResult) { events.append($0) }
                guard events == constructor.events else { throw error(setup.label+" constructor events") }
                bitmap = loaded.storage;result.constructors += 1
            }
            for write in setup.writes {
                try bitmap.write(write.offset == 0 ? UInt32(write.value == 0 ? 0 : 1) : write.value,at: write.offset)
            }
            try check(bitmap,stored(setup.storage),setup.label)
            bitmaps.append(bitmap);result.setups += 1
        }
        for item in corpus.cases {
            guard bitmaps.indices.contains(item.setup), !item.responses.isEmpty,
                  item.input.sourceSurface == 0 || item.input.sourceSurface == 0x22003000,
                  item.input.targetSurface == 0 || item.input.targetSurface == 0x22003100 else { throw error("Draw inputs") }
            let bitmap = bitmaps[item.setup], globalBytes = try blob(item.beforeGlobals)
            guard globalBytes.count == OriginalMatchPreparation.globalSize else { throw error("Global extent") }
            let globals = try OriginalStateRecord(bytes: globalBytes,defined: [Bool](repeating: true,count: globalBytes.count))
            guard try globals.integer(at: 0x44d78c-0x44d000,as: Int32.self) == item.input.viewportWidth,
                  try globals.integer(at: 0x44d790-0x44d000,as: Int32.self) == item.input.viewportHeight else { throw error("Viewport inputs") }
            var reads = 0, clips = 0, blits = 0, returned: Int32?, boundary = false
            do {
                returned = try OriginalBitmapDrawing.draw(item.input,bitmap: bitmap,observeRead: { read in
                    guard reads < item.reads.count else { throw error(item.label+" extra read") }
                    let expected = item.reads[reads]
                    guard read == expected else { throw error("\(item.label) read\(reads): \(read) vs \(expected)") }
                    reads += 1;result.reads += 1;if !read.defined { result.undefinedReads += 1 }
                },observeClip: { clip in
                    guard clips < item.clips.count, clip == item.clips[clips] else { throw error("\(item.label) clip\(clips): \(clip)") }
                    clips += 1;result.clips += 1
                },perform: { blit in
                    guard blits < item.blits.count, blit == item.blits[blits] else { throw error("\(item.label) blit\(blits): \(blit)") }
                    let response = item.responses[blits%item.responses.count];blits += 1;result.blits += 1;return response
                })
            } catch OriginalStateError.outOfBounds(let offset,let count) {
                guard let expected = item.boundary, expected.kind == "outsideBitmap", expected.offset == offset, count == 4 else { throw error(item.label+" unexpected bitmap boundary") }
                boundary = true
            } catch OriginalStateError.invalidStorage(let detail) where detail == "Null bitmap target surface" {
                guard item.boundary?.kind == "nullTarget" else { throw error(item.label+" unexpected target boundary") }
                boundary = true
            }
            guard reads == item.reads.count, clips == item.clips.count, blits == item.blits.count else { throw error(item.label+" unconsumed events") }
            if let expected = item.boundary {
                guard boundary, returned == nil, item.endPC == expected.pc,
                      item.endSP == 0x1000f000-0xc8-(expected.pc == 0x43f2e6 ? 12 : 0) else { throw error("Invalid boundary continuation") }
                result.boundaries += 1
            } else {
                guard !boundary, returned == item.returnValue, item.endPC == 0x30000000, item.endSP == 0x1000f01c else { throw error(item.label+" ret24/EAX") }
            }
            if blits == 2 { result.dualBlits += 1 }
            try check(bitmap,stored(item.after),item.label)
            let afterBytes = try blob(item.afterGlobals)
            try check(globals,OriginalStateRecord(bytes: afterBytes,defined: [Bool](repeating: true,count: afterBytes.count)),item.label+" globals")
            result.cases += 1
        }
        return result
    }
}
