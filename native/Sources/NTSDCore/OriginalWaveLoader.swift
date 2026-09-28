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
    public var initialStorage: OriginalWaveStorage?
    public var lockReplies: [OriginalWaveResponse] = []
    public var regions: [UInt32: OriginalStateRecord] = [:]
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
                            audio: OriginalWaveRequest.Handler? = nil,
                            observe: (OriginalWaveEvent) throws -> Void = { _ in }) throws -> OriginalWaveLoadResult {
        try load(path:path,file:file,output:output,platform:p,outputStored:{ _ in },audio:audio,observe:observe)
    }

    public static func load(path: [UInt8], file: [UInt8], output: UInt32, platform p: OriginalWavePlatform,
                            outputStored: (UInt32) throws -> Void,
                            audio: OriginalWaveRequest.Handler? = nil,
                            observe: (OriginalWaveEvent) throws -> Void = { _ in }) throws -> OriginalWaveLoadResult {
        let legacy = try OriginalWaveLegacyReplies(p)
        if let audio {
            return try run(path:path,file:file,output:output,input:legacy.input,request:audio,
                legacyFirstPointer:nil,outputStored:outputStored,observe:observe)
        }
        return try run(path:path,file:file,output:output,input:legacy.input,request:legacy.reply,
            legacyFirstPointer:p.firstPointer,outputStored:outputStored,observe:observe)
    }

    public static func loadObserved(path: [UInt8],file: [UInt8],output: UInt32,input: OriginalWaveInput,
        request: OriginalWaveRequest.Handler,outputStored: (UInt32) throws -> Void = { _ in },
        observe: (OriginalWaveEvent) throws -> Void = { _ in }) throws -> OriginalWaveLoadResult {
        try run(path:path,file:file,output:output,input:input,request:request,legacyFirstPointer:nil,
            outputStored:outputStored,observe:observe)
    }

    private static func run(path: [UInt8],file: [UInt8],output: UInt32,input p: OriginalWaveInput,
        request: OriginalWaveRequest.Handler,legacyFirstPointer: UInt32?,outputStored: (UInt32) throws -> Void,
        observe: (OriginalWaveEvent) throws -> Void) throws -> OriginalWaveLoadResult {
        guard !path.contains(0),path.count < 256,p.descendResults.count == 3,
            p.storage.first.bytes.count <= 2_000_000,(p.storage.second?.bytes.count ?? 0) <= 2_000_000 else {
            throw error("Platform input extent")
        }
        func backing(_ count: Int,_ origin: Int = 0) throws -> OriginalStateRecord { try p.storage.backing(count,origin) }
        var result = try OriginalWaveLoadResult(output:output,first:p.storage.first.record(),second:p.storage.second?.record())
        result.initialStorage = p.storage
        func event(_ kind: OriginalWaveEvent.Kind,_ args: [UInt32] = [],_ strings: [[UInt8]] = []) throws {
            try observe(.init(kind,args,strings))
        }
        func audio(_ q: OriginalWaveRequest) throws -> OriginalWaveResponse {
            try q.validate();try observe(q.event)
            let response = try request(q)
            guard q.accepts(response) else { throw error("Audio response family") }
            return response
        }
        func close() throws { try event(.close, [p.stream, 0]) }
        func message(_ text: String) throws { _ = try audio(.init(.init(.message,[0,0],[bytes(text),[]]))) }
        if p.device == 0 { result.returned = 1; return result } // output is untouched
        result.output = 0
        try outputStored(0)
        try event(.open, [0, 0x10000], [path])
        if p.stream == 0 {
            _ = try audio(.init(.init(.message,[0,0],[bytes("Could not Open Wave File <")+path+bytes(">"),path])))
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
        let created = try audio(.init(.init(.create,[p.device,0],[descriptor.bytes,format.bytes]),
            structures:[.init(descriptor),.init(format)]))
        guard case .created(let createResult,let createdBuffer) = created else { throw error("Create response") }
        if createResult != 0 {
            try message("Could not Create Sound Buffer.")
            try event(.free); result.temporaryLive = false
            result.exit = .invalidCreateContinuation; result.returned = nil
            // EXE falls through into Lock with a failed output and freed data.
            // This boundary is recorded, not turned into a successful load.
            return result
        }
        guard let buffer = createdBuffer,buffer != 0 else { throw error("Null device output") }
        // Preserve the old aggregate adapter's preflight boundary. Actual replies
        // have no future first pointer to inspect before issuing Lock.
        if let legacyFirstPointer,legacyFirstPointer == 0 { throw error("Null device output") }
        func lock() throws -> OriginalWaveResponse {
            let reply = try audio(.init(.init(.lock,[buffer,0,UInt32(data.count),0])))
            result.lockReplies.append(reply);return reply
        }
        var locked = try lock()
        guard case .locked(let firstResult,_) = locked else { throw error("Lock response") }
        if firstResult == 0x88780096 {
            _ = try audio(.init(.init(.restore,[buffer])))
            locked = try lock()
        }
        // Final HRESULT is ignored, while actual output spans must have owners.
        guard case .locked(_,let outputs?) = locked,
            outputs.firstPointer != 0,(0...2_000_000).contains(outputs.firstCount),
            (0...2_000_000).contains(outputs.secondCount),outputs.firstCount <= data.count,
            outputs.secondCount <= data.count-outputs.firstCount else { throw error("Lock output extent") }
        func bind(_ token: UInt32,_ count: Int,_ region: OriginalWaveRegion?) throws {
            guard let region,region.token == token,region.storage.bytes.count >= count,
                region.storage.bytes.count <= 2_000_000 else { throw error("Lock region binding") }
            let record = try region.storage.record()
            if let earlier = result.regions[token],earlier != record { throw error("Conflicting Lock alias backing") }
            result.regions[token] = record
        }
        try bind(outputs.firstPointer,outputs.firstCount,outputs.first)
        if outputs.secondPointer != 0 { try bind(outputs.secondPointer,outputs.secondCount,outputs.second) }
        func copy(_ index: UInt32,_ offset: Int,_ count: Int,_ token: UInt32) throws {
            guard let temporary = result.temporary,var region = result.regions[token] else { throw error("Copy storage") }
            let payload = Array(temporary.bytes[offset..<(offset+count)]),mask = Array(temporary.defined[offset..<(offset+count)])
            _ = try audio(.init(.init(.copy,[index,UInt32(offset),UInt32(count)]),target:token,bytes:payload,defined:mask))
            var raw = region.bytes,known = region.defined
            raw.replaceSubrange(0..<count,with:payload);known.replaceSubrange(0..<count,with:mask)
            region = try .init(bytes:raw,defined:known);result.regions[token] = region
        }
        try copy(0,0,outputs.firstCount,outputs.firstPointer)
        if outputs.secondPointer != 0 { try copy(1,outputs.firstCount,outputs.secondCount,outputs.secondPointer) }
        result.first = result.regions[outputs.firstPointer]!
        result.second = outputs.secondPointer == 0 ? nil : result.regions[outputs.secondPointer]
        _ = try audio(.init(.init(.unlock,[buffer,outputs.firstPointer,UInt32(outputs.firstCount),outputs.secondPointer,UInt32(outputs.secondCount)])))
        try event(.free); result.temporaryLive = false
        result.output = buffer; result.returned = 1
        try outputStored(buffer)
        return result
    }
}
