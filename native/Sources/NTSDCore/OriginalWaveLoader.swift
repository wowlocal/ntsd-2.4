import Foundation

/// Responses of the WinMM/DirectSound boundaries used by 4014e0. The file
/// adapter below supplies RIFF positions from bytes; device output is opaque.
public struct OriginalWavePlatform: Codable, Sendable {
    public let destination: UInt32, device: UInt32, stream: UInt32, buffer: UInt32, firstPointer: UInt32, secondPointer: UInt32
    public let descendResults: [Int32], formatReadResult: Int32, ascendResult: Int32, dataReadResult: Int32
    public let createResult: Int32, lockResults: [UInt32], restoreResult: Int32, unlockResult: Int32, closeResult: Int32
    public let firstCount: Int, secondCount: Int
    /// Explicit uninitialized allocator/stack backing, not game defaults.
    public let ramp: Bool
    public init(destination: UInt32, device: UInt32, stream: UInt32,
                buffer: UInt32, firstPointer: UInt32, secondPointer: UInt32,
                descendResults: [Int32], formatReadResult: Int32, ascendResult: Int32,
                dataReadResult: Int32, createResult: Int32, lockResults: [UInt32],
                restoreResult: Int32, unlockResult: Int32, closeResult: Int32,
                firstCount: Int, secondCount: Int, ramp: Bool) {
        self.destination = destination; self.device = device; self.stream = stream
        self.buffer = buffer; self.firstPointer = firstPointer; self.secondPointer = secondPointer
        self.descendResults = descendResults; self.formatReadResult = formatReadResult; self.ascendResult = ascendResult
        self.dataReadResult = dataReadResult; self.createResult = createResult; self.lockResults = lockResults
        self.restoreResult = restoreResult; self.unlockResult = unlockResult; self.closeResult = closeResult
        self.firstCount = firstCount; self.secondCount = secondCount; self.ramp = ramp
    }
}

public struct OriginalWaveEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case load, open, descend, read, ascend, close, message, allocate, create, lock, restore, copy, unlock, free
    }
    public let kind: Kind, arguments: [UInt32], strings: [[UInt8]]
    public init(_ kind: Kind, _ arguments: [UInt32] = [], _ strings: [[UInt8]] = []) {
        self.kind = kind; self.arguments = arguments; self.strings = strings
    }
}

public enum OriginalWaveExit: String, Codable, Sendable {
    case returned, invalidCreateContinuation
}

public struct OriginalWaveLoadResult {
    public var exit: OriginalWaveExit = .returned
    public var returned: UInt32? = 0
    public var output: UInt32
    public var temporary: OriginalStateRecord?, temporaryLive = false
    public var first: OriginalStateRecord, second: OriginalStateRecord?
    public var format: OriginalStateRecord?, descriptor: OriginalStateRecord?
}

/// Recovered 4014e0 through its real caller-visible decisions and buffer copies.
/// This is shared PCM loading, not a mixer, playback engine or per-character rule.
public enum OriginalWaveLoader {
    private struct Chunk {
        let id: UInt32, count: Int, type: UInt32, offset: Int
        var end: Int { offset+count+(count%2) }
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Wave loading: \(text)") }
    private static func bytes(_ text: String) -> [UInt8] { Array(text.utf8) }
    private static func u32(_ raw: [UInt8], _ offset: Int) throws -> UInt32 {
        guard offset >= 0, offset+4 <= raw.count else { throw error("RIFF field outside input") }
        return (0..<4).reduce(UInt32(0)) { $0 | UInt32(raw[offset+$1]) << ($1*8) }
    }
    private static func chunk(_ raw: [UInt8], _ offset: Int, limit: Int) throws -> Chunk? {
        guard offset >= 0, limit <= raw.count, offset+8 <= limit else { return nil }
        let id = try u32(raw, offset), count = Int(try u32(raw, offset+4))
        guard count <= limit-offset-8 else { throw error("RIFF chunk extends beyond the supplied file/parent") }
        let typed = id == 0x46464952 || id == 0x5453494c
        guard !typed || count >= 4 else { return nil }
        return try .init(id: id, count: count, type: typed ? u32(raw, offset+8) : 0, offset: offset+8)
    }

    public static func load(path: [UInt8], file: [UInt8], output: UInt32, platform p: OriginalWavePlatform,
                            observe: (OriginalWaveEvent) throws -> Void = { _ in }) throws -> OriginalWaveLoadResult {
        try load(path:path,file:file,output:output,platform:p,outputStored:{ _ in },observe:observe)
    }

    public static func load(path: [UInt8], file: [UInt8], output: UInt32, platform p: OriginalWavePlatform,
                            outputStored: (UInt32) throws -> Void,
                            observe: (OriginalWaveEvent) throws -> Void = { _ in }) throws -> OriginalWaveLoadResult {
        guard !path.contains(0), path.count < 256, p.descendResults.count == 3,
              (0...2_000_000).contains(p.firstCount), (0...2_000_000).contains(p.secondCount),
              p.lockResults.count == 2 else { throw error("Platform input extent") }
        func backing(_ count: Int, _ origin: Int = 0) throws -> OriginalStateRecord {
            try .init(bytes: (0..<count).map { p.ramp ? UInt8(truncatingIfNeeded: origin+$0) : 0xa5 },
                      defined: [Bool](repeating: false, count: count))
        }
        var result = try OriginalWaveLoadResult(output: output, first: backing(p.firstCount),
                                               second: p.secondPointer == 0 ? nil : backing(p.secondCount))
        func event(_ kind: OriginalWaveEvent.Kind, _ args: [UInt32] = [], _ strings: [[UInt8]] = []) throws {
            try observe(.init(kind, args, strings))
        }
        func close() throws { try event(.close, [p.stream, 0]) }
        func message(_ text: String) throws { try event(.message, [0, 0], [bytes(text), []]) }
        if p.device == 0 { result.returned = 1; return result } // output is untouched
        result.output = 0
        try outputStored(0)
        try event(.open, [0, 0x10000], [path])
        if p.stream == 0 {
            try event(.message, [0, 0], [bytes("Could not Open Wave File <")+path+bytes(">"), path])
            return result
        }
        try event(.descend, [p.stream, 0x20, 0, 0, 0x45564157])
        if p.descendResults[0] != 0 {
            try close(); try message("Could not Descend into Wave File"); return result
        }
        var outer: Chunk?
        var position = 0
        while let candidate = try chunk(file, position, limit: file.count) {
            if candidate.id == 0x46464952 && candidate.type == 0x45564157 { outer = candidate; break }
            position = candidate.end
        }
        guard let outer else {
            try close(); try message("Could not Descend into Wave File"); return result
        }
        position = outer.offset+4
        // Flags are ZERO: the EXE descends into the next child. Setting ckid
        // to 'fmt ' does not request a search. Preserve that distinction.
        try event(.descend, [p.stream, 0, 1, 0x20746d66, 0])
        guard p.descendResults[1] == 0, let fmt = try chunk(file, position, limit: outer.offset+outer.count) else {
            try close(); try message("Could not Descend into format of Wave File"); return result
        }
        position = fmt.offset + ((fmt.id == 0x46464952 || fmt.id == 0x5453494c) ? 4 : 0)
        try event(.read, [p.stream, 18, UInt32(position)])
        guard p.formatReadResult == 18, file.count-position >= 18 else {
            try close(); try message("Error reading Wave Format"); return result
        }
        let sourceFormat = Array(file[position..<(position+18)])
        guard sourceFormat[0] == 1, sourceFormat[1] == 0 else {
            try close(); try message("Not a valid Wave Format"); return result
        }
        try event(.ascend, [p.stream, 0, UInt32(fmt.offset), UInt32(fmt.count)])
        guard p.ascendResult == 0 else { try close(); try message("Unable to Ascend"); return result }
        position = fmt.end
        try event(.descend, [p.stream, 0x10, 1, 0x61746164, 0])
        if p.descendResults[2] != 0 {
            try close(); try message("Wave file has no data"); return result
        }
        var data: Chunk?
        while let candidate = try chunk(file, position, limit: outer.offset+outer.count) {
            if candidate.id == 0x61746164 { data = candidate; break }
            position = candidate.end
        }
        guard let data else {
            try close(); try message("Wave file has no data"); return result
        }
        guard data.count <= 2_000_000 else { throw error("Payload exceeds the verified allocation extent") }
        try event(.allocate, [UInt32(data.count)])
        result.temporary = try backing(data.count); result.temporaryLive = true
        try event(.read, [p.stream, UInt32(data.count), UInt32(data.offset)])
        if p.dataReadResult > 0 {
            guard Int(p.dataReadResult) <= data.count else { throw error("Read wrote beyond requested payload") }
            for i in 0..<Int(p.dataReadResult) { try result.temporary!.write(file[data.offset+i], at: i) }
        }
        try close()
        guard p.dataReadResult == data.count else {
            // Original returns WITHOUT freeing this allocation on a short read.
            try message("Could not read Wave Data"); return result
        }
        // WAVEFORMATEX overlaps the saved this pointer at local+44. Its cbSize
        // therefore contains the LOW WORD of the destination token, not zero
        // or the source file's cbSize. It is ignored for PCM by the device API.
        var format = try backing(18)
        for i in 0..<16 { try format.write(sourceFormat[i], at: i) }
        try format.write(UInt16(truncatingIfNeeded: p.destination), at: 16)
        result.format = format
        var descriptor = try OriginalStateRecord(bytes: [UInt8](repeating: 0, count: 36), defined: [Bool](repeating: true, count: 36))
        try descriptor.write(UInt32(36), at: 0); try descriptor.write(UInt32(0xe0), at: 4)
        try descriptor.write(UInt32(data.count), at: 8)
        // lpwfxFormat is normalized to zero only after the oracle verifies its
        // exact stack address. Other descriptor bytes have no normalization.
        result.descriptor = descriptor
        try event(.create, [p.device, 0], [descriptor.bytes, format.bytes])
        if p.createResult != 0 {
            try message("Could not Create Sound Buffer.")
            try event(.free); result.temporaryLive = false
            result.exit = .invalidCreateContinuation; result.returned = nil
            // EXE falls through into Lock with a failed output and freed data.
            // This boundary is recorded, not turned into a successful load.
            return result
        }
        guard p.buffer != 0, p.firstPointer != 0 else { throw error("Null device output") }
        try event(.lock, [p.buffer, 0, UInt32(data.count), 0])
        if p.lockResults[0] == 0x88780096 {
            try event(.restore, [p.buffer])
            try event(.lock, [p.buffer, 0, UInt32(data.count), 0])
        }
        // The final Lock HRESULT is NOT checked. Copy lengths/pointers are
        // explicit valid boundary outputs even for failing-HRESULT controls.
        guard p.firstCount+p.secondCount <= data.count else { throw error("Lock lengths exceed source") }
        try event(.copy, [0, 0, UInt32(p.firstCount)])
        for i in 0..<p.firstCount { try result.first.write(result.temporary!.bytes[i], at: i) }
        if p.secondPointer != 0 {
            try event(.copy, [1, UInt32(p.firstCount), UInt32(p.secondCount)])
            for i in 0..<p.secondCount { try result.second!.write(result.temporary!.bytes[p.firstCount+i], at: i) }
        }
        try event(.unlock, [p.buffer, p.firstPointer, UInt32(p.firstCount), p.secondPointer, UInt32(p.secondCount)])
        try event(.free); result.temporaryLive = false
        result.output = p.buffer; result.returned = 1
        try outputStored(p.buffer)
        return result
    }
}
