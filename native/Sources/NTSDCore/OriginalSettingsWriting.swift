import Foundation

/// Whole423230 settings writer, including mutation/restoration of overlapping
/// names. File bytes pass through the same recovered VC80 output buffer used by
/// menu info writers. The platform owns opening and descriptor IO.
public enum OriginalSettingsWriting {
    public enum Result: Equatable {
        case returned(UInt32), nullFile, unterminatedName(UInt32)
        public var value: UInt32? { if case .returned(let value) = self { return value };return nil }
    }
    private struct Stop: Error { let result: Result }
    public static let defaults: [(address: UInt32, bytes: [UInt8])] = [
        (0x449134,Array("<No name>\0".utf8)),(0x449120,Array("<No info>\0".utf8)),(0x449660,Array("<No email>\0".utf8))
    ]
    public static func run(globals: inout OriginalStateRecord,output: inout OriginalBufferedTextOutput,available: Bool,
        write: ([UInt8]) throws -> Int32,close: () throws -> Int32,
        observe: (OriginalMenuInfoWriteEvent,OriginalStateRecord,OriginalBufferedTextOutput) throws -> Void = { _,_,_ in }) throws -> Result {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else { throw OriginalStateError.invalidStorage("Settings writer globals extent") }
        var state = globals,stream = output
        let base = OriginalMatchPreparation.globalBase
        func byte(_ address: Int) throws -> UInt8 { try state.integer(at: address-base,as: UInt8.self) }
        func word(_ address: Int) throws -> Int32 { try state.integer(at: address-base,as: Int32.self) }
        func string(_ address: Int,namePC: UInt32? = nil) throws -> [UInt8] {
            let offset = address-base
            guard offset >= 0,offset < state.bytes.count else { throw OriginalStateError.invalidStorage("Settings string address") }
            guard let end = state.bytes[offset...].firstIndex(of: 0) else {
                if let pc = namePC { throw Stop(result: .unterminatedName(pc)) }
                throw OriginalStateError.invalidStorage("Settings printf string extent")
            }
            return Array(state.bytes[offset..<end])
        }
        func emit(_ event: OriginalMenuInfoWriteEvent,_ snapshot: OriginalBufferedTextOutput? = nil) throws { try observe(event,state,snapshot ?? stream) }
        func store(_ address: Int,_ bytes: [UInt8]) throws {
            guard [1,2,4].contains(bytes.count) else { throw OriginalStateError.invalidStorage("Settings write extent") }
            var value: UInt32 = 0
            for (i,b) in bytes.enumerated() { try state.write(b,at: address-base+i);value |= UInt32(b) << (i*8) }
            try emit(.init("write",[UInt32(address),UInt32(bytes.count),value]))
        }
        func writeFile(_ bytes: [UInt8],_ snapshot: OriginalBufferedTextOutput) throws -> Int32 {
            let value = try write(bytes)
            var event = OriginalMenuInfoWriteEvent("writeFile",[snapshot.descriptor,UInt32(bytes.count)],[bytes]);event.result = UInt32(bitPattern: value)
            try emit(event,snapshot);return value
        }
        func print(_ format: String,_ parameters: [OriginalBufferedTextOutput.Argument] = [],_ args: [UInt32] = [],_ strings: [[UInt8]] = []) throws {
            var event = OriginalMenuInfoWriteEvent("print",[stream.fileAddress]+args,strings);event.format = format
            event.result = UInt32(bitPattern: try stream.printFormat(format,arguments: parameters,write: writeFile));try emit(event)
        }
        func number(_ address: Int,_ suffix: String) throws {
            let value = try word(address);try print("%d"+suffix,[.integer(value)],[UInt32(bitPattern: value)])
        }
        func names(restoring: Bool) throws -> UInt32 {
            var length = 0
            for address in stride(from: 0x44fcc0,to: 0x44fcec,by: 11) {
                length = try string(address,namePC: restoring ? 0x423437 : 0x423297).count
                var i = 0
                while i < length {
                    let old = try byte(address+i)
                    if old == 0x60 { try store(address+i,[restoring ? 0x20 : 0x27]) }
                    else if !restoring && old == 0x20 { try store(address+i,[0x60]) }
                    i += 1;length = try string(address,namePC: restoring ? 0x423456 : 0x4232c1).count
                }
            }
            return UInt32(length)
        }
        func defaultField(_ address: Int,_ index: Int) throws {
            if try byte(address) == 0 {
                let bytes = defaults[index].bytes
                try store(address,Array(bytes[0..<4]));try store(address+4,Array(bytes[4..<8]));try store(address+8,Array(bytes[8..<10]))
                if bytes.count == 11 { try store(address+10,[bytes[10]]) }
            }
        }
        func finish(_ result: Result) -> Result { globals = state;output = stream;return result }
        do {
            try emit(.init("open",[available ? stream.fileAddress : 0],[Array("data\\control.txt".utf8),Array("w".utf8)]))
            guard available else { return finish(.nullFile) }
            for group in 0..<4 {
                for index in 0..<11 { try number(0x44fb70+group*0x50+index*4," ") }
                try print("\n")
            }
            _ = try names(restoring: false)
            for index in 0..<4 {
                let address = 0x44fcc0+index*11
                if try byte(address) == 0 { try store(address,[UInt8(49+index),0]) }
            }
            let values = try (0..<4).map { try string(0x44fcc0+$0*11) }
            try print("%s %s %s %s\n",values.map { .bytes($0) },[],values)
            try defaultField(0x44fd18,0);try defaultField(0x44f900,1);try defaultField(0x44f890,2)
            try number(0x450be8,"\n");try number(0x450be4,"\n")
            for (address,suffix) in [(0x44fd18,"\n"),(0x44f890,"\n"),(0x44f900,"")] {
                let text = try string(address);try print("%s"+suffix,[.bytes(text)],[],[text])
            }
            let value = try stream.close(write: writeFile) { snapshot in
                let value = try close();var event = OriginalMenuInfoWriteEvent("closeFile",[snapshot.descriptor]);event.result = UInt32(bitPattern: value);try emit(event,snapshot);return value
            }
            var event = OriginalMenuInfoWriteEvent("close",[stream.fileAddress]);event.result = UInt32(bitPattern: value);try emit(event)
            return try finish(.returned(names(restoring: true)))
        } catch let stop as Stop { return finish(stop.result) }
    }
}
