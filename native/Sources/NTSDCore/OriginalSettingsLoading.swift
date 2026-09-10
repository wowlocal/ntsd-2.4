import Foundation

public struct OriginalSettingsEvent: Equatable, Sendable {
    public enum Kind: String, Sendable { case open, scan, gets, eof, close, settingsReturn, write }
    public let kind: Kind
    public var arguments: [UInt32] = [], strings: [String] = []
    public var format: String?, before: Int?, position: Int?, eof: Bool?, result: UInt32?
    public init(_ kind: Kind, _ arguments: [UInt32] = []) { self.kind = kind; self.arguments = arguments }
}

/// Original423480 and its427089 caller through the flag clear427092.
/// File opening/closing, translated bytes, FILE token and stack backing are
/// explicit platform inputs. This does not implement Windows CRT file opening.
public enum OriginalSettingsLoading {
    public enum Continuation: String, Codable, Sendable { case ready, nullFile }
    public struct StartupResult: Equatable, Sendable {
        public let continuation: Continuation, scratch: OriginalStateRecord
        public let target: UInt32?, retainedESI: UInt32?
    }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Settings loading: "+text) }

    /// Fresh application helper lifetime: private scratch is not supplied from
    /// a source stack snapshot. Only this call's writes can own its bytes.
    public static func loadOwnStartup(globals: inout OriginalStateRecord,
        translatedBytes: [UInt8], file: UInt32, scratchAddress: UInt32, target: UInt32, closeResult: Int32 = 0,
        observe: (OriginalSettingsEvent,OriginalStateRecord,OriginalStateRecord) throws -> Void = { _,_,_ in }) throws -> StartupResult {
        var scratch = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:0x1f4),defined:[Bool](repeating:false,count:0x1f4))
        let continuation = try loadAndContinueStartup(globals:&globals,scratch:&scratch,translatedBytes:translatedBytes,
            file:file,scratchAddress:scratchAddress,closeResult:closeResult,requireDefinedStrings:true,observe:observe)
        // 42708e reloads the original World argument, then427098 sets ESI=-1.
        // Preserve the own caller value rather than copying its source stack.
        return .init(continuation:continuation,scratch:scratch,target:continuation == .ready ? target : nil,
                     retainedESI:continuation == .ready ? UInt32.max : nil)
    }

    public static func loadAndContinueStartup(globals: inout OriginalStateRecord, scratch: inout OriginalStateRecord,
        translatedBytes: [UInt8], file: UInt32, scratchAddress: UInt32, closeResult: Int32 = 0, flagClearValue: UInt32 = 0,
        requireDefinedStrings: Bool = false,
        observe: (OriginalSettingsEvent,OriginalStateRecord,OriginalStateRecord) throws -> Void = { _,_,_ in }) throws -> Continuation {
        let base = OriginalMatchPreparation.globalBase
        guard globals.bytes.count == OriginalMatchPreparation.globalSize, scratch.bytes.count == 0x1f4 else { throw error("Storage extent") }
        var state = globals, temporary = scratch, input = try OriginalFrameScanner(String(String.UnicodeScalarView(translatedBytes.map { UnicodeScalar($0) })))
        var endOfFile = false
        func emit(_ event: OriginalSettingsEvent) throws { try observe(event,state,temporary) }
        func store(_ address: Int, _ bytes: [UInt8]) throws {
            if UInt32(address) == scratchAddress {
                for (i,b) in bytes.enumerated() { try temporary.write(b,at: i) }
            } else {
                for (i,b) in bytes.enumerated() { try state.write(b,at: address-base+i) }
            }
        }
        func wordBytes(_ value: UInt32) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0*8)) } }
        func parentWrite(_ address: Int, _ bytes: [UInt8]) throws {
            try store(address,bytes)
            let value = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
            try emit(.init(.write,[UInt32(address),UInt32(bytes.count),value]))
        }
        // Raw backing remains explicit. Reading a C string does not mark its
        // bytes initialized; reject a read beyond the supplied storage extent.
        func string(_ record: OriginalStateRecord, _ offset: Int) throws -> [UInt8] {
            guard offset >= 0, offset < record.bytes.count,
                  let end = record.bytes[offset...].firstIndex(of: 0) else { throw error("Unterminated string outside supplied storage") }
            if requireDefinedStrings && !record.defined[offset...end].allSatisfy({ $0 }) {
                throw error("String reads unknown private storage")
            }
            return Array(record.bytes[offset..<end])
        }
        var open = OriginalSettingsEvent(.open,[file]);open.strings = ["data\\control.txt","r"];try emit(open)
        // EXE reaches the first fscanf with NULL FILE. Stop at that boundary;
        // its CRT invalid-parameter handler is not a successful settings load.
        guard file != 0 else { return .nullFile }
        func scan(_ format: String, _ destinations: [Int]) throws {
            var event = OriginalSettingsEvent(.scan,destinations.map(UInt32.init));event.format = format;event.before = input.position
            var assigned = 0
            for destination in destinations {
                if format.hasPrefix("%s") {
                    guard let token = input.optionalToken() else { endOfFile = endOfFile || input.eof;break }
                    try store(destination,token.unicodeScalars.map { UInt8($0.value) }+[0])
                } else {
                    guard let value = try input.integer() else { endOfFile = endOfFile || input.eof;break }
                    try store(destination,wordBytes(UInt32(bitPattern: value)))
                }
                assigned += 1;endOfFile = endOfFile || input.eof
            }
            if assigned == destinations.count && format.hasSuffix("\n") {
                input.skipSpace();if input.position == input.bytes.count { endOfFile = true }
            }
            event.result = assigned == 0 && endOfFile ? UInt32.max : UInt32(assigned)
            event.position = input.position;event.eof = endOfFile;try emit(event)
        }
        func gets(_ destination: Int) throws {
            var event = OriginalSettingsEvent(.gets,[UInt32(destination),100]);event.before = input.position
            var bytes: [UInt8] = []
            while bytes.count < 99 {
                guard input.position < input.bytes.count else { endOfFile = true;break }
                let byte = input.bytes[input.position];input.position += 1;bytes.append(byte)
                if byte == 10 { break }
            }
            if !bytes.isEmpty { try store(destination,bytes+[0]) }
            event.result = bytes.isEmpty ? 0 : UInt32(destination)
            event.position = input.position;event.eof = endOfFile;try emit(event)
        }
        func eof() throws -> Bool {
            var event = OriginalSettingsEvent(.eof);event.before = input.position;event.position = input.position
            event.eof = endOfFile;event.result = endOfFile ? 16 : 0;try emit(event);return endOfFile
        }
        for player in 0..<4 { for field in 0..<11 { try scan("%d",[0x44fb70+0x50*player+4*field]) } }
        try scan("%s %s %s %s\n",(0..<4).map { 0x44fcc0+11*$0 })
        for player in 0..<4 {
            let address = 0x44fcc0+11*player
            let bytes = try string(state,address-base)
            for (i,b) in bytes.enumerated() where b == 0x60 { try parentWrite(address+i,[0x20]) }
        }
        try scan("%d\n",[0x450be8]);try scan("%d\n",[0x450be4])
        try gets(0x44fd18);try gets(0x44f890)
        for address in [0x44fd18,0x44f890] {
            let bytes = try string(state,address-base)
            for i in bytes.indices.reversed() {
                guard [32,13,10].contains(bytes[i]) else { break }
                try parentWrite(address+i,[0])
            }
        }
        try parentWrite(0x44f900,[0])
        while try !eof() {
            try gets(Int(scratchAddress))
            // Failed fgets leaves the preceding line intact; append it again.
            // The source loop copies through NUL in dwords, then trailing bytes.
            let bytes = try string(temporary,0)+[0]
            let destination = 0x44f900 + (try string(state,0x44f900-base)).count
            var offset = 0
            while offset+4 <= bytes.count { try parentWrite(destination+offset,Array(bytes[offset..<offset+4]));offset += 4 }
            while offset < bytes.count { try parentWrite(destination+offset,[bytes[offset]]);offset += 1 }
        }
        try emit(.init(.close,[file,UInt32(bitPattern: closeResult)]))
        var returned = OriginalSettingsEvent(.settingsReturn);returned.result = UInt32(bitPattern: closeResult);try emit(returned)
        // 427092 stores caller EBX, which is zero in the natural resource path.
        // A supplied caller after an interrupted helper need not still have zero.
        try parentWrite(0x44d068,wordBytes(flagClearValue))
        globals = state;scratch = temporary;return .ready
    }
}
