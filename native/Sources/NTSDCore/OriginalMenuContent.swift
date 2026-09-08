import Foundation

public struct OriginalMenuContentEvent: Equatable, Sendable {
    public let kind: String
    public var arguments: [UInt32] = [], strings: [[UInt8]] = []
    public var format: String?, before: Int?, position: Int?, eof: Bool?, result: UInt32?
    public init(_ kind: String,_ arguments: [UInt32] = []) { self.kind = kind;self.arguments = arguments }
}

/// Whole43c780 content parser. Present bytes are a declared translated-file
/// input; original ad0/ad1 are absent. Recovered rows are generic format rules,
/// not replacement game assets. Locals preserve all1104 supplied bytes/masks.
public enum OriginalMenuContent {
    public struct Result: Sendable { public let value: UInt32?, boundaryCall: UInt32? }
    private struct Stop: Error { let call: UInt32 }
    private static func error(_ text: String) -> OriginalStateError { .invalidStorage("Menu content: "+text) }
    public static func load(globals: inout OriginalStateRecord,local: inout OriginalStateRecord,translatedBytes: [UInt8]?,file: UInt32 = 0x20001000,closeResult: Int32 = 0,
        observe: (OriginalMenuContentEvent,OriginalStateRecord,OriginalStateRecord) throws -> Void = { _,_,_ in }) throws -> Result {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize, local.bytes.count == 0x450 else { throw error("Storage extent") }
        let base = OriginalMatchPreparation.globalBase
        var state = globals, scratch = local, position = 0, eof = false
        let bytes = translatedBytes ?? []
        func emit(_ e: OriginalMenuContentEvent) throws { try observe(e,state,scratch) }
        func word(_ address: Int) throws -> Int32 { try state.integer(at: address-base,as: Int32.self) }
        func bytesOf(_ word: UInt32,_ count: Int = 4) -> [UInt8] { (0..<count).map { UInt8(truncatingIfNeeded: word >> ($0*8)) } }
        func store(_ region: Int,_ offset: Int,_ bytes: [UInt8]) throws {
            for (i,b) in bytes.enumerated() {
                if region == 1 { try scratch.write(b,at: offset+i) } else { try state.write(b,at: offset-base+i) }
            }
        }
        func write(_ address: Int,_ value: Int32,_ count: Int = 4) throws {
            try store(0,address,bytesOf(UInt32(bitPattern: value),count))
            try emit(.init("write",[UInt32(address),UInt32(count),UInt32(bitPattern: value)]))
        }
        func finish(_ value: UInt32?,boundary: UInt32? = nil) -> Result { globals = state;local = scratch;return .init(value: value,boundaryCall: boundary) }
        func close(_ value: UInt32) throws -> Result { try emit(.init("close",[file,UInt32(bitPattern: closeResult)]));return finish(value) }
        func gets(_ offset: Int) throws {
            var e = OriginalMenuContentEvent("gets",[1,UInt32(offset),500]);e.before = position
            var output: [UInt8] = []
            while output.count < 499 {
                guard position < bytes.count else { eof = true;break }
                let b = bytes[position];position += 1;output.append(b);if b == 10 { break }
            }
            if !output.isEmpty { try store(1,offset,output+[0]) }
            e.result = output.isEmpty ? 0 : 1;e.position = position;e.eof = eof;try emit(e)
        }
        func scan(_ format: String,_ offset: Int,_ destinations: [(Int,Int)],_ call: UInt32) throws {
            guard let end = scratch.bytes[offset...].firstIndex(of: 0) else { throw Stop(call: call) }
            let text = String(String.UnicodeScalarView(scratch.bytes[offset..<end].map { UnicodeScalar($0) }))
            var scanner = try OriginalFrameScanner(text), assigned = 0
            let specs = format.split(separator: " ")
            guard specs.count == destinations.count else { throw error("Format binding") }
            for (spec,destination) in zip(specs,destinations) {
                if spec == "%d" {
                    guard let value = try scanner.integer() else { break }
                    try store(destination.0,destination.1,bytesOf(UInt32(bitPattern: value)))
                } else {
                    guard spec == "%s" else { throw error("Unknown conversion") }
                    guard let token = scanner.optionalToken() else { break }
                    try store(destination.0,destination.1,token.unicodeScalars.map { UInt8($0.value) }+[0])
                }
                assigned += 1
            }
            var e = OriginalMenuContentEvent("scan",[UInt32(offset)]+destinations.flatMap { [UInt32($0.0),UInt32($0.1)] })
            e.format = format;e.result = assigned == 0 && scanner.eof ? UInt32.max : UInt32(assigned);try emit(e)
        }
        func fixed(_ offset: Int,_ value: String) -> Bool { Array(scratch.bytes[offset..<offset+value.utf8.count]) == Array(value.utf8) }
        func link(_ address: Int) -> Bool { [UInt8(63),104,72].contains(state.bytes[address-base]) }
        let index = try word(0x44d784), name = "data\\ad\(index).txt"
        for (address,format,output) in [(0x453c68,"data\\ad%d.txt",name),(0x453d40,"sprite\\sys\\ad%d.bmp","sprite\\sys\\ad\(index).bmp")] {
            try store(0,address,Array(output.utf8)+[0]);var e = OriginalMenuContentEvent("format",[UInt32(address),UInt32(bitPattern: index)])
            e.format = format;e.result = UInt32(output.utf8.count);try emit(e)
        }
        var open = OriginalMenuContentEvent("open",[translatedBytes == nil ? 0 : file]);open.strings = [Array(name.utf8),Array("r".utf8)];try emit(open)
        guard translatedBytes != nil else { return finish(0) }
        guard file != 0 else { throw error("Present content with null FILE") }
        do {
            try gets(604);try write(0x44d778,-99)
            try scan("%d ",604,[(0,0x44d778)],0x43c817)
            if try word(0x44d778) == -99 { return try close(0) }
            for row in 0..<24 {
                let a = 0x453ce0+4*row,b = 0x453f70+4*row,c = 0x453c08+4*row,d = 0x4583b8+4*row,url = 0x454a18+100*row
                for p in [a,b,c,d] { try write(p,-99) };try write(url,45,2)
                try gets(104);try scan("%s %d %d %d %d %s %s",104,[(1,52),(0,d),(0,c),(0,b),(0,a),(0,url),(1,0)],0x43c8cb)
                if try !fixed(52,"ba\0") || !fixed(0,"bae\0") || !link(url) || [d,c,b,a].contains(where: { try word($0) == -99 }) {
                    try write(d,-99);return try close(0)
                }
            }
            for row in 0..<8 {
                let a = 0x453f50+4*row,b = 0x4546d0+4*row,c = 0x452928+4*row,url = 0x4546f8+100*row
                for p in [a,b,c] { try write(p,-99) };try write(url,45,2)
                try gets(104);try scan("%s %d %d %d %s %s",104,[(1,0),(0,c),(0,b),(0,a),(0,url),(1,52)],0x43c9d8)
                if try !fixed(0,"ta\0") || !fixed(52,"tae\0") || !link(url) || [c,b,a].contains(where: { try word($0) == -99 }) {
                    for p in [c,b,a] { try write(p,-99) };return try close(0)
                }
            }
            try write(0x4554bc,-99);try write(0x453da8,45,2)
            try gets(104);try scan("%s %d %s %s",104,[(1,0),(0,0x4554bc),(0,0x453da8),(1,52)],0x43cab4)
            if try !fixed(0,"un\0") || !fixed(52,"une\0") || !link(0x453da8) || word(0x4554bc) == -99 { try write(0x4554bc,-99);return try close(0) }
            try write(0x45757c,-99);try write(0x453da4,-99)
            try gets(104);try scan("%s %d %d %s",104,[(1,0),(0,0x453da4),(0,0x45757c),(1,52)],0x43cb4e)
            if try !fixed(0,"y\0") || !fixed(52,"ye\0") || word(0x453da4) == -99 || word(0x45757c) == -99 {
                try write(0x45757c,0);try write(0x453da4,0);return try close(0)
            }
            try gets(104);try scan("%s",104,[(1,0)],0x43cbf9)
            return try close(fixed(0,"<end>\0") ? 1 : 0)
        } catch let stop as Stop { return finish(nil,boundary: stop.call) }
    }
}
