import Foundation

/// VC80 byte output for the declared user-buffered FILE domain (flags102,
/// non-append descriptor, ordinary write errors, no EILSEQ replacement).
/// Writes expose logical bytes before the platform's text translation.
public struct OriginalBufferedTextOutput: Sendable {
    public let fileAddress: UInt32, bufferAddress: UInt32, descriptor: UInt32
    public private(set) var buffer: OriginalStateRecord
    public private(set) var position = 0, count: Int32, flags: UInt32 = 0x102
    public init(backing: [UInt8],fileAddress: UInt32 = 0x20001000,bufferAddress: UInt32 = 0x20002000,descriptor: UInt32 = .max) throws {
        guard (1...4096).contains(backing.count) else { throw OriginalStateError.invalidStorage("Output buffer extent") }
        self.fileAddress = fileAddress;self.bufferAddress = bufferAddress;self.descriptor = descriptor
        buffer = try .init(bytes: backing,defined: [Bool](repeating: false,count: backing.count));count = Int32(backing.count)
    }
    public func fileStorage() throws -> OriginalStateRecord {
        let words: [UInt32] = [bufferAddress+UInt32(position),UInt32(bitPattern: count),bufferAddress,flags,descriptor,0,UInt32(buffer.bytes.count),0]
        let bytes = words.flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded: word >> ($0*8)) } }
        return try .init(bytes: bytes,defined: [Bool](repeating: true,count: 32))
    }
    public typealias Write = ([UInt8],OriginalBufferedTextOutput) throws -> Int32
    public mutating func printBytes(_ bytes: [UInt8],write: Write) throws -> Int32 {
        var total: Int32 = 0
        for byte in bytes {
            count -= 1
            if count >= 0 { try buffer.write(byte,at: position);position += 1 }
            else {
                flags = (flags & ~UInt32(0x10)) | 2
                let pending = position;position = 1;count = Int32(buffer.bytes.count-1)
                let returned = pending > 0 ? try write(Array(buffer.bytes.prefix(pending)),self) : 0
                // _flsbuf writes the next byte even when flushing the old
                // block failed. fclose subsequently sees this one-byte tail.
                try buffer.write(byte,at: 0)
                if returned != Int32(pending) { flags |= 0x20;return -1 }
            }
            total += 1
        }
        return total
    }
    public mutating func close(write: Write,close: (OriginalBufferedTextOutput) throws -> Int32) throws -> Int32 {
        var result: Int32 = 0
        if flags & 3 == 2, flags & 0x108 != 0, position > 0 {
            let returned = try write(Array(buffer.bytes.prefix(position)),self)
            if returned != Int32(position) { flags |= 0x20;result = -1 }
        }
        position = 0;count = 0
        if try close(self) < 0 { result = -1 }
        flags = 0;return result
    }
}

public struct OriginalMenuInfoWriteEvent: Codable, Equatable, Sendable {
    public let kind: String
    public var arguments: [UInt32] = [], strings: [[UInt8]] = [], format: String?, result: UInt32?
    public init(_ kind: String,_ arguments: [UInt32] = [],_ strings: [[UInt8]] = []) { self.kind = kind;self.arguments = arguments;self.strings = strings }
}

/// Whole43c690 default writer and43c710 cache writer. Global state is updated
/// in source order even when open/write/close fails. No host filesystem access.
public enum OriginalMenuInfoWriting {
    public enum Mode: String, Codable, Sendable { case defaults, cache }
    @discardableResult
    public static func run(_ mode: Mode,globals: inout OriginalStateRecord,output: inout OriginalBufferedTextOutput,available: Bool,
        write: ([UInt8]) throws -> Int32,close: () throws -> Int32,
        observe: (OriginalMenuInfoWriteEvent,OriginalStateRecord,OriginalBufferedTextOutput) throws -> Void = { _,_,_ in }) throws -> UInt32 {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else { throw OriginalStateError.invalidStorage("Menu info globals extent") }
        var state = globals, stream = output
        let base = OriginalMatchPreparation.globalBase
        func word(_ p: Int) throws -> Int32 { try state.integer(at: p-base,as: Int32.self) }
        func string(_ p: Int) throws -> [UInt8] {
            var bytes: [UInt8] = [],at = p-base
            while true { let byte = try state.integer(at: at,as: UInt8.self);if byte == 0 { return bytes };bytes.append(byte);at += 1 }
        }
        func emit(_ event: OriginalMenuInfoWriteEvent,_ snapshot: OriginalBufferedTextOutput? = nil) throws { try observe(event,state,snapshot ?? stream) }
        func global(_ p: Int,_ value: UInt32) throws {
            try state.write(value,at: p-base);try emit(.init("write",[UInt32(p),4,value]))
        }
        func format(_ p: Int,_ format: String,_ text: String,_ index: Int32) throws -> UInt32 {
            for (i,b) in (Array(text.utf8)+[0]).enumerated() { try state.write(b,at: p-base+i) }
            var e = OriginalMenuInfoWriteEvent("format",[UInt32(p),UInt32(bitPattern: index)]);e.format = format;e.result = UInt32(text.utf8.count);try emit(e);return e.result!
        }
        func paths() throws -> UInt32 {
            let index = try word(0x44d784)
            _ = try format(0x453c68,"data\\ad%d.txt","data\\ad\(index).txt",index)
            return try format(0x453d40,"sprite\\sys\\ad%d.bmp","sprite\\sys\\ad\(index).bmp",index)
        }
        func writeFile(_ bytes: [UInt8],_ snapshot: OriginalBufferedTextOutput) throws -> Int32 {
            let result = try write(bytes)
            var e = OriginalMenuInfoWriteEvent("writeFile",[snapshot.descriptor,UInt32(bytes.count)],[bytes]);e.result = UInt32(bitPattern: result);try emit(e,snapshot);return result
        }
        func save() throws -> UInt32 {
            try emit(.init("open",[available ? stream.fileAddress : 0],[Array("data\\adinfo.txt".utf8),Array("w".utf8)]))
            guard available else { return 0 }
            var e = OriginalMenuInfoWriteEvent("print",[stream.fileAddress]), bytes: [UInt8]
            if mode == .defaults { e.format = "now 0 4 <end>\n";bytes = Array(e.format!.utf8) }
            else {
                let date = try string(0x4527b0),index = try word(0x44d784),period = try word(0x44d788)
                e.format = "%s %d %d <end>\n";e.arguments += [UInt32(bitPattern: index),UInt32(bitPattern: period)];e.strings = [date]
                bytes = date+Array(" \(index) \(period) <end>\n".utf8)
            }
            e.result = UInt32(bitPattern: try stream.printBytes(bytes,write: writeFile));try emit(e)
            let result = try stream.close(write: writeFile) { snapshot in
                let result = try close();var e = OriginalMenuInfoWriteEvent("closeFile",[snapshot.descriptor]);e.result = UInt32(bitPattern: result);try emit(e,snapshot);return result
            }
            var end = OriginalMenuInfoWriteEvent("close",[stream.fileAddress]);end.result = UInt32(bitPattern: result);try emit(end);return end.result!
        }
        let result: UInt32
        if mode == .defaults {
            _ = try save();try global(0x4527b0,0x776f6e);try global(0x44d784,0);try global(0x44d788,4);result = try paths()
        } else { _ = try paths();result = try save() }
        globals = state;output = stream;return result
    }
}
