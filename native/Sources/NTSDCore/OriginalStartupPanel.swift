import Foundation

/// Actual43cf94..43cfb4 startup panel selection. Earlier WinMain/CRT/device
/// initialization remains an explicit boundary; no Windows code runs natively.
public struct OriginalStartupPanel {
    public enum Observation {
        case caller(OriginalMenuPanelUpdateEvent,OriginalStateRecord)
        case info(OriginalMenuInfoReading.Event,OriginalStateRecord,OriginalStateRecord)
        case content(OriginalMenuContentEvent,OriginalStateRecord,OriginalStateRecord)
        case bitmap(OriginalMenuPanelBitmapEvent)
        case writer(OriginalMenuInfoWriteEvent,OriginalStateRecord,OriginalBufferedTextOutput)
    }
    public private(set) var panel = OriginalMenuPanelBitmap()
    public private(set) var infoLocal: OriginalStateRecord?
    public private(set) var contentLocal: OriginalStateRecord?
    public private(set) var output: OriginalBufferedTextOutput?
    public init() {}

    /// All globals, bitmap generations, locals and output publish together.
    /// File/device callbacks supply data or stage effects until the caller commits.
    @discardableResult
    public mutating func run(globals: inout OriginalStateRecord,infoBytes: [UInt8]?,
        contentSource: (String) throws -> [UInt8]?,chunk: Int = 4096,infoReadFailAt: Int = -1,
        infoClose: Int32 = 0,contentClose: Int32 = 0,
        outputBacking: [UInt8],writeAvailable: Bool = true,
        write: ([UInt8]) throws -> Int32,close: () throws -> Int32,
        allocate: () throws -> OriginalInterfaceAllocation,
        bitmapSource: (String) throws -> OriginalBitmapInput,
        deviceResult: () throws -> (surface: UInt32,colorKeyResult: Int32),
        observe: (Observation) throws -> Void = { _ in },
        written: (Int,[UInt8]) throws -> Void = { _,_ in },
        afterChild: (UInt32,UInt32,OriginalStateRecord,OriginalStartupPanel) throws -> Void = { _,_,_,_ in }) throws -> UInt32 {
        var state = globals,candidate = self
        func unknown(_ count: Int) throws -> OriginalStateRecord {
            try .init(bytes:[UInt8](repeating:0,count:count),defined:[Bool](repeating:false,count:count))
        }
        candidate.infoLocal = nil;candidate.contentLocal = nil;candidate.output = nil
        func call(_ entry: UInt32) throws { try observe(.caller(.init("call",[entry]),state)) }
        func returned(_ entry: UInt32,_ result: UInt32) throws {
            try observe(.caller(.init("return",[entry,result]),state));try afterChild(entry,result,state,candidate)
        }
        var local = try unknown(OriginalMenuInfoReading.localCount)
        try call(0x43c4a0)
        var value = try OriginalMenuInfoReading.load(globals:&state,local:&local,translatedBytes:infoBytes,chunk:chunk,readFailAt:infoReadFailAt,closeResult:infoClose,written:{ r,o,b in if r == 0 { try written(OriginalMatchPreparation.globalBase+o,b) } },observe:{ e,s,l in try observe(.info(e,s,l)) })
        candidate.infoLocal = local;try returned(0x43c4a0,value)
        if value != 0 {
            // Same child entrySP: content(entrySP-454) overlaps the info region
            // (entrySP-bc) at398. Carry only this native producer's known bytes.
            var content = try unknown(0x450)
            for i in local.bytes.indices where local.defined[i] { try content.write(local.bytes[i],at:0x398+i) }
            try call(0x43c780)
            let result = try withoutActuallyEscaping(contentSource) { source in
                try OriginalMenuContent.load(globals:&state,local:&content,translatedBytes:nil,closeResult:contentClose,
                    requireDefinedLocals:true,fileSource:source,written:{ r,o,b in if r == 0 { try written(o,b) } },observe:{ e,s,l in try observe(.content(e,s,l)) })
            }
            guard let contentValue = result.value,result.boundaryCall == nil else {
                throw OriginalStateError.invalidStorage("Startup panel content did not return")
            }
            value = contentValue;candidate.contentLocal = content;try returned(0x43c780,value)
            if value != 0 {
                try call(0x43cc60)
                value = try candidate.panel.load(globals:&state,allocate:allocate,source:bitmapSource,deviceResult:deviceResult,observe:{ event in
                    if event.kind == "write",event.arguments[0] == 0 { let value = event.arguments[3];try written(Int(event.arguments[1]),(0..<Int(event.arguments[2])).map { UInt8(truncatingIfNeeded:value >> (8*$0)) }) }
                    try observe(.bitmap(event))
                }) ? 1 : 0
                try returned(0x43cc60,value)
            }
        }
        if value == 0 {
            try call(0x43c690)
            var stream = try OriginalBufferedTextOutput(backing:outputBacking)
            value = try OriginalMenuInfoWriting.run(.defaults,globals:&state,output:&stream,available:writeAvailable,write:write,close:close,observe:{ e,s,o in
                if e.kind == "write" { let value = e.arguments[2];try written(Int(e.arguments[0]),(0..<Int(e.arguments[1])).map { UInt8(truncatingIfNeeded:value >> (8*$0)) }) }
                if e.kind == "format",let count = e.result { let at = Int(e.arguments[0])-OriginalMatchPreparation.globalBase;try written(Int(e.arguments[0]),Array(s.bytes[at..<at+Int(count)+1])) }
                try observe(.writer(e,s,o))
            })
            candidate.output = stream;try returned(0x43c690,value)
        }
        globals = state;self = candidate;return value
    }
}
