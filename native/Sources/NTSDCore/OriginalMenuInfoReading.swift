import Foundation

/// Whole43c4a0 startup information reader. FILE bytes are supplied after platform
/// text translation; no Windows CRT, host filesystem or source stack is imported.
public enum OriginalMenuInfoReading {
    public static let localCount = 184
    public struct Event: Equatable, Sendable {
        public let kind: String
        public var arguments: [UInt32] = [], strings: [[UInt8]] = []
        public var format: String?, result: UInt32?
        public init(_ kind: String, _ arguments: [UInt32] = []) { self.kind = kind;self.arguments = arguments }
    }
    /// Local offsets are relative to entrySP-bc, excluding cookie/saved registers.
    /// External observers must buffer effects until the encompassing call commits.
    public static func load(globals: inout OriginalStateRecord, local: inout OriginalStateRecord,
        translatedBytes: [UInt8]?, chunk: Int = 4096, readFailAt: Int = -1,
        file: UInt32 = 0x20001000, closeResult: Int32 = 0,
        store: (Int,Int,[UInt8]) throws -> Void = { _,_,_ in },
        written: (Int,Int,[UInt8]) throws -> Void = { _,_,_ in },
        observe: (Event,OriginalStateRecord,OriginalStateRecord) throws -> Void = { _,_,_ in }) throws -> UInt32 {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize,local.bytes.count == localCount,
              chunk > 0,readFailAt >= -1,translatedBytes == nil || file != 0 else {
            throw OriginalStateError.invalidStorage("Menu info reading inputs")
        }
        let base = OriginalMatchPreparation.globalBase
        var state = globals,scratch = local
        func emit(_ e: Event) throws { try observe(e,state,scratch) }
        func bytes(_ v: UInt32,_ count: Int = 4) -> [UInt8] { (0..<count).map { UInt8(truncatingIfNeeded:v >> (8*$0)) } }
        func write(_ region: Int,_ offset: Int,_ value: [UInt8],parent: Bool = false) throws {
            for (i,b) in value.enumerated() {
                if region == 0 { try state.write(b,at:offset+i) } else { try scratch.write(b,at:offset+i) }
            }
            try written(region,offset,value)
            if parent { try store(region,offset,value) }
        }
        func word(_ offset: Int) throws -> Int32 { try state.integer(at:offset-base,as:Int32.self) }
        func string(_ region: Int,_ offset: Int) throws -> [UInt8] {
            var result: [UInt8] = [],at = offset
            while true {
                let b: UInt8 = try region == 0 ? state.integer(at:at,as:UInt8.self) : scratch.integer(at:at,as:UInt8.self)
                if b == 0 { return result };result.append(b);at += 1
            }
        }
        func equal(_ region: Int,_ offset: Int,_ expected: [UInt8]) throws -> Bool {
            for (i,b) in expected.enumerated() {
                let actual: UInt8 = try region == 0 ? state.integer(at:offset+i,as:UInt8.self) : scratch.integer(at:offset+i,as:UInt8.self)
                if actual != b { return false }
            }
            return true
        }
        func scanner(_ bytes: [UInt8]) throws -> OriginalFrameScanner {
            try .init(String(String.UnicodeScalarView(bytes.map { UnicodeScalar($0) })))
        }
        func scan(_ region: Int,_ offset: Int,_ destinations: [(Int,Int)],date: Bool) throws {
            let text = try string(region,offset)
            var input = try scanner(text),assigned = 0,atEnd = false
            for (i,dest) in destinations.enumerated() {
                let value: Int32?
                if date {
                    input.skipSpace();let start = input.position,width = i == 0 ? 4 : 2
                    var field = try scanner(Array(input.bytes[start..<min(start+width,input.bytes.count)]))
                    value = try field.integer();input.position += field.position
                    atEnd = field.eof && input.position == input.bytes.count
                } else { value = try input.integer();atEnd = input.eof }
                guard let value else { break }
                try write(dest.0,dest.1,bytes(UInt32(bitPattern:value)));assigned += 1
                if date && i < destinations.count-1 {
                    guard input.position < input.bytes.count,input.bytes[input.position] == 47 else { break }
                    input.position += 1
                }
            }
            var e = Event("scan",[UInt32(region),UInt32(offset)]+destinations.flatMap { [UInt32($0.0),UInt32($0.1)] })
            e.strings = [text];e.format = date ? "%04d/%02d/%02d/%02d/%02d/%02d" : "%d"
            e.result = assigned == 0 && atEnd ? .max : UInt32(assigned);try emit(e)
        }
        try write(1,0,bytes(0),parent:true)
        var open = Event("open",[translatedBytes == nil ? 0 : file]);open.strings = [Array("data\\adinfo.txt".utf8),Array("r".utf8)];try emit(open)
        if let translatedBytes {
            for o in [0x1c,0x84,0x50] { try write(1,o,[0],parent:true) }
            try write(0,0x4527b0-base,[0],parent:true)
            // _read failures end the delivered byte prefix. Chunk sizes affect
            // delivery only; fscanf still assigns a token ending at that boundary.
            let count = readFailAt < 0 || readFailAt > translatedBytes.count/chunk ? translatedBytes.count : min(translatedBytes.count,readFailAt*chunk)
            var input = try scanner(Array(translatedBytes.prefix(count))),assigned = 0
            for dest in [(0,0x4527b0-base),(1,0x50),(1,0x84),(1,0x1c)] {
                guard let token = input.optionalToken() else { break }
                try write(dest.0,dest.1,token.unicodeScalars.map { UInt8($0.value) }+[0]);assigned += 1
            }
            var tokens = Event("tokens");tokens.format = "%s %s %s %s";tokens.result = assigned == 0 && input.eof ? .max : UInt32(assigned);try emit(tokens)
            try emit(.init("close",[UInt32(bitPattern:closeResult)]))
        } else { try write(1,0,bytes(1),parent:true) }
        if try !equal(1,0x1c,Array("<end>\0".utf8)) { try write(1,0,bytes(1),parent:true) }
        else if try scratch.integer(at:0,as:UInt32.self) == 0 {
            var dateOK = try equal(0,0x4527b0-base,Array("now\0".utf8))
            if !dateOK { dateOK = try equal(0,0x4527b0-base,Array("dont_update\0".utf8)) }
            if !dateOK {
                for o in [0x18,0x14,0x10,4,8,12] { try write(1,o,bytes(UInt32(bitPattern:-99)),parent:true) }
                let destinations = [0x18,0x14,0x10,4,8,12].map { (1,$0) }
                try scan(0,0x4527b0-base,destinations,date:true)
                dateOK = try !destinations.contains { try scratch.integer(at:$0.1,as:Int32.self) == -99 }
            }
            if dateOK {
                try scan(1,0x50,[(0,0x44d784-base)],date:false)
                try scan(1,0x84,[(0,0x44d788-base)],date:false)
                for (address,format) in [(0x453c68,"data\\ad%d.txt"),(0x453d40,"sprite\\sys\\ad%d.bmp")] {
                    let index = try word(0x44d784),output = format.replacingOccurrences(of:"%d",with:String(index))
                    try write(0,address-base,Array(output.utf8)+[0])
                    var e = Event("format",[UInt32(address),UInt32(bitPattern:index)]);e.format = format;e.result = UInt32(output.utf8.count);try emit(e)
                }
                if try word(0x44d784) == -99 || word(0x44d788) == -99 { try write(1,0,bytes(1),parent:true) }
            } else { try write(1,0,bytes(1),parent:true) }
        }
        let result: UInt32 = try scratch.integer(at:0,as:UInt32.self) == 0 ? 1 : 0
        globals = state;local = scratch;return result
    }
}
