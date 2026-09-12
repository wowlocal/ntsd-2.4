import Foundation

/// Declared stream allocation and buffering, not a Windows FILE layout or a
/// host CRT default. The application-catalog study supplies capacity65536 and
/// translated readLimit4096. Tokens identify resources, never host pointers.
public struct OriginalLoadingFileAllocation: Equatable, Sendable {
    public let token: UInt32, buffer: UInt32, descriptor: UInt32
    public let capacity: Int, readLimit: Int
    public let closeResult: Int32
    public init(token: UInt32, buffer: UInt32, descriptor: UInt32, capacity: Int, readLimit: Int, closeResult: Int32 = 0) {
        self.token = token; self.buffer = buffer; self.descriptor = descriptor
        self.capacity = capacity; self.readLimit = readLimit
        self.closeResult = closeResult
    }
}

public struct OriginalLoadingFileEvent: Equatable, Sendable {
    public enum Kind: String, Sendable { case openFile, readFile, writeFile, closeReadFile, closeOutputDescriptor }
    public let kind: Kind, arguments: [UInt32], path: String?, mode: String?, bytes: [UInt8]?
    public let result: Int32?
    init(_ kind: Kind, _ arguments: [UInt32], path: String? = nil, mode: String? = nil, bytes: [UInt8]? = nil, result: Int32? = nil) {
        self.kind = kind; self.arguments = arguments; self.path = path; self.mode = mode; self.bytes = bytes
        self.result = result
    }
}

/// Owned loading-file contents at the declared translated-read/descriptor-write
/// boundary. Reads/writes succeed; declared close0/-1 results are preserved and
/// ignored by the DAT/Object callers. Private VC80 FILE/locking/errno and other
/// numeric IO failures are outside this model. Publish these staged files only
/// when the enclosing application iteration commits.
public struct OriginalLoadingFiles: Equatable, Sendable {
    public struct Stream: Equatable, Sendable {
        public let allocation: OriginalLoadingFileAllocation, path: String, mode: String
        public let raw: [UInt8], input: [UInt8]
        public fileprivate(set) var position = 0, loaded = 0, eof = false, closed = false
        public fileprivate(set) var output: [UInt8] = [], pending: [UInt8] = []
    }
    public typealias Source = (String) throws -> [UInt8]
    public typealias Allocate = (String, String) throws -> OriginalLoadingFileAllocation
    public typealias Observe = (OriginalLoadingFileEvent) throws -> Void
    public static let temporaryPath = "data\\temporary.txt"
    public private(set) var streams: [UInt32: Stream] = [:], files: [String: [UInt8]] = [:]
    public private(set) var order: [UInt32] = []
    public private(set) var decoderReturns: [Int32] = []
    public let translation: OriginalFileTranslation
    public init(translation: OriginalFileTranslation) { self.translation = translation }

    public mutating func open(_ path: String, mode: String, source: Source, allocate: Allocate,
                              observe: Observe = { _ in }) throws -> UInt32 {
        guard mode == "r" || mode == "w" else { throw Self.error("Unknown open mode") }
        let allocation = try allocate(path, mode)
        guard allocation.token != 0 else { throw Self.error("NULL fopen continuation requires original CRT provenance") }
        guard streams[allocation.token] == nil, allocation.buffer != 0,
              allocation.capacity > 0, allocation.capacity <= Int(UInt32.max),
              allocation.readLimit > 0, allocation.readLimit <= allocation.capacity,
              allocation.closeResult == 0 || allocation.closeResult == -1 else {
            throw Self.error("Invalid or reused declared stream allocation")
        }
        let raw = mode == "w" ? [] : try files[path] ?? source(path)
        guard !raw.starts(with: Array("version https://git-lfs.github.com/spec/v1".utf8)) else {
            throw Self.error("Git LFS pointer is not original game data")
        }
        try observe(.init(.openFile, [allocation.token], path: path, mode: mode))
        streams[allocation.token] = .init(allocation: allocation, path: path, mode: mode,
                                           raw: raw, input: translation.read(raw))
        order.append(allocation.token)
        if mode == "w" { files[path] = [] }
        return allocation.token
    }

    public mutating func character(_ token: UInt32, observe: Observe = { _ in }) throws -> UInt8? {
        var stream = try self.stream(token, mode: "r")
        if stream.eof { return nil }
        if stream.position == stream.loaded {
            let end = min(stream.input.count, stream.loaded + stream.allocation.readLimit)
            let bytes = Array(stream.input[stream.loaded..<end]), a = stream.allocation
            try observe(.init(.readFile, [a.descriptor, a.buffer, UInt32(a.capacity), UInt32(bytes.count)], bytes: bytes))
            stream.loaded = end
            if bytes.isEmpty { stream.eof = true; streams[token] = stream; return nil }
        }
        let byte = stream.input[stream.position]
        stream.position += 1; streams[token] = stream
        return byte
    }

    /// A scanner consumes through position-1 and looks at position to decide
    /// whether its token/number ended. A delimiter is retained for the next
    /// scan; looking at input.count attempts the actual EOF refill.
    public mutating func scannerAccess(_ token: UInt32, position: Int, observe: Observe = { _ in }) throws {
        var stream = try self.stream(token, mode: "r")
        guard position >= stream.position, position <= stream.input.count else {
            throw Self.error("Scanner position outside its own forward input")
        }
        while !stream.eof && position >= stream.loaded {
            let end = min(stream.input.count, stream.loaded + stream.allocation.readLimit)
            let bytes = Array(stream.input[stream.loaded..<end]), a = stream.allocation
            try observe(.init(.readFile, [a.descriptor, a.buffer, UInt32(a.capacity), UInt32(bytes.count)], bytes: bytes))
            stream.loaded = end
            if bytes.isEmpty { stream.eof = true }
        }
        stream.position = position; streams[token] = stream
    }

    public mutating func write(_ bytes: [UInt8], to token: UInt32, observe: Observe = { _ in }) throws {
        _ = try self.stream(token, mode: "w")
        for byte in bytes {
            // VC80's full-buffer path flushes before storing the triggering byte.
            if streams[token]!.pending.count == streams[token]!.allocation.capacity {
                var stream = streams[token]!
                try flush(&stream, observe: observe)
                streams[token] = stream
            }
            streams[token]!.pending.append(byte); streams[token]!.output.append(byte)
        }
    }

    @discardableResult
    public mutating func close(_ token: UInt32, observe: Observe = { _ in }) throws -> Int32 {
        guard var stream = streams[token], !stream.closed else { throw Self.error("Close of unknown/dead stream") }
        if stream.mode == "r" { try observe(.init(.closeReadFile, [token], result: stream.allocation.closeResult)) }
        else {
            try flush(&stream, observe: observe)
            try observe(.init(.closeOutputDescriptor, [stream.allocation.descriptor, token], result: stream.allocation.closeResult))
        }
        stream.closed = true; streams[token] = stream
        return stream.allocation.closeResult
    }

    /// Whole4148a0/414a30 on the normal, complete-header domain. The input closes
    /// before the final output flush. A late observer failure discards this whole
    /// candidate, including earlier full-buffer writes and newly opened streams.
    @discardableResult
    public mutating func decodeDAT(_ path: String, outputPath: String = temporaryPath,
                                   source: Source, allocate: Allocate, observe: Observe = { _ in }) throws -> UInt32 {
        var candidate = self
        let input = try candidate.open(path, mode: "r", source: source, allocate: allocate, observe: observe)
        let output = try candidate.open(outputPath, mode: "w", source: source, allocate: allocate, observe: observe)
        for _ in 0..<123 {
            guard try candidate.character(input, observe: observe) != nil else { throw Self.error("Truncated DAT header") }
        }
        var position = 123
        while let byte = try candidate.character(input, observe: observe) {
            try candidate.write([OriginalDATDecoder.byte(byte, at: position)], to: output, observe: observe)
            position += 1
        }
        try candidate.close(input, observe: observe)
        let result = try candidate.close(output, observe: observe)
        candidate.decoderReturns.append(result)
        self = candidate
        return output
    }

    /// 40f0c2..40f124 selects the parser's real input. The parser must advance
    /// this stream itself; obtaining its input bytes does not mark them read.
    public mutating func openObject(_ path: String, source: Source, allocate: Allocate,
                                    observe: Observe = { _ in }) throws -> UInt32 {
        var candidate = self
        let encrypted = try OriginalDATDecoder.encrypted(path)
        if encrypted { try candidate.decodeDAT(path, source: source, allocate: allocate, observe: observe) }
        let token = try candidate.open(encrypted ? Self.temporaryPath : path, mode: "r",
                                       source: source, allocate: allocate, observe: observe)
        self = candidate
        return token
    }

    /// 41228d..4122bb always performs this cleanup, even for a plaintext Object.
    public mutating func finishObject(_ token: UInt32, source: Source, allocate: Allocate,
                                      observe: Observe = { _ in }) throws {
        var candidate = self
        try candidate.close(token, observe: observe)
        let output = try candidate.open(Self.temporaryPath, mode: "w", source: source, allocate: allocate, observe: observe)
        try candidate.write(Array("Do not erase this file.".utf8), to: output, observe: observe)
        try candidate.close(output, observe: observe)
        self = candidate
    }

    /// Complete owned file lifetime around a synchronous Object parser. Its
    /// text comes from this session's own produced bytes, and each scanner
    /// access drives the same live read stream. Both decode and cleanup writes
    /// roll back together on any error; the caller must also stage parser and
    /// other external resource state until this method returns.
    public mutating func withObject<Result>(_ path: String, source: Source, allocate: Allocate,
                                           observe: @escaping Observe = { _ in },
                                           consume: (String, @escaping (Int) throws -> Void) throws -> Result) throws -> Result {
        try withParsedFile(path, alwaysDecode: false, source: source, allocate: allocate, observe: observe, consume: consume)
    }

    /// 40c160 shares the Object suffix/open/temporary-cleanup sequence.
    public mutating func withBackground<Result>(_ path: String, source: Source, allocate: Allocate,
                                               observe: @escaping Observe = { _ in },
                                               consume: (String, @escaping (Int) throws -> Void) throws -> Result) throws -> Result {
        try withParsedFile(path, alwaysDecode: false, source: source, allocate: allocate, observe: observe, consume: consume)
    }

    /// 40c910 always calls414a30 for the fixed Stage path before opening its
    /// output; it has no filename-suffix branch.
    public mutating func withStage<Result>(source: Source, allocate: Allocate,
                                          observe: @escaping Observe = { _ in },
                                          consume: (String, @escaping (Int) throws -> Void) throws -> Result) throws -> Result {
        try withParsedFile("data\\stage.dat", alwaysDecode: true, source: source, allocate: allocate, observe: observe, consume: consume)
    }

    private mutating func withParsedFile<Result>(_ path: String, alwaysDecode: Bool, source: Source, allocate: Allocate,
                                                observe: @escaping Observe,
                                                consume: (String, @escaping (Int) throws -> Void) throws -> Result) throws -> Result {
        var candidate = self
        let token: UInt32
        if alwaysDecode {
            try candidate.decodeDAT(path, source: source, allocate: allocate, observe: observe)
            token = try candidate.open(Self.temporaryPath, mode: "r", source: source, allocate: allocate, observe: observe)
        } else { token = try candidate.openObject(path, source: source, allocate: allocate, observe: observe) }
        let text = String(String.UnicodeScalarView(candidate.streams[token]!.input.map { UnicodeScalar($0) }))
        let result = try consume(text) { position in try candidate.scannerAccess(token, position: position, observe: observe) }
        try candidate.finishObject(token, source: source, allocate: allocate, observe: observe)
        self = candidate
        return result
    }

    private func stream(_ token: UInt32, mode: String) throws -> Stream {
        guard let stream = streams[token], !stream.closed, stream.mode == mode else {
            throw Self.error("Unknown, closed or wrong-mode stream")
        }
        return stream
    }
    private mutating func flush(_ stream: inout Stream, observe: Observe) throws {
        guard !stream.pending.isEmpty else { return }
        let a = stream.allocation
        try observe(.init(.writeFile, [a.descriptor, a.buffer, UInt32(stream.pending.count)], bytes: stream.pending))
        files[stream.path, default: []].append(contentsOf: translation.write(stream.pending))
        stream.pending.removeAll(keepingCapacity: true)
    }
    private static func error(_ detail: String) -> OriginalStateError { .invalidStorage("Loading files: \(detail)") }
}
