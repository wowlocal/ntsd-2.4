import Foundation

public struct OriginalMenuPanelUpdateEvent: Codable, Equatable, Sendable {
    public let kind: String, arguments: [UInt32]
    public init(_ kind: String,_ arguments: [UInt32] = []) { self.kind = kind;self.arguments = arguments }
}

/// Whole4236d0. The caller composes the recovered text/bitmap/writer helpers
/// with its own resources and platform inputs; no character-specific rules.
public enum OriginalMenuPanelUpdate {
    public enum Result: Equatable { case ready, contentBoundary(UInt32) }
    private struct Stop: Error { let call: UInt32 }
    public static func run(globals: inout OriginalStateRecord,
        content: (inout OriginalStateRecord) throws -> OriginalMenuContent.Result,
        bitmap: (inout OriginalStateRecord) throws -> Bool,
        write: (OriginalMenuInfoWriting.Mode,inout OriginalStateRecord) throws -> UInt32,
        observe: (OriginalMenuPanelUpdateEvent,OriginalStateRecord) throws -> Void = { _,_ in }) throws -> Result {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else { throw OriginalStateError.invalidStorage("Panel update globals extent") }
        var state = globals
        let base = OriginalMatchPreparation.globalBase
        func emit(_ kind: String,_ args: [UInt32]) throws { try observe(.init(kind,args),state) }
        func word(_ p: Int) throws -> Int32 { try state.integer(at: p-base,as: Int32.self) }
        func store(_ p: Int,_ value: Int32) throws {
            try state.write(value,at: p-base);try emit("write",[UInt32(p),4,UInt32(bitPattern: value)])
        }
        func toggle() throws { try store(0x44d784,(Int32(1) &- word(0x44d784)) % 2) }
        func loadContent() throws -> Bool {
            try emit("call",[0x43c780]);let result = try content(&state)
            if let call = result.boundaryCall { throw Stop(call: call) }
            guard let value = result.value else { throw OriginalStateError.invalidStorage("Missing content return") }
            try emit("return",[0x43c780,value]);return value != 0
        }
        func loadBitmap() throws -> Bool {
            try emit("call",[0x43cc60]);let result = try bitmap(&state);try emit("return",[0x43cc60,result ? 1 : 0]);return result
        }
        func save(_ mode: OriginalMenuInfoWriting.Mode) throws {
            let address: UInt32 = mode == .defaults ? 0x43c690 : 0x43c710
            try emit("call",[address]);let result = try write(mode,&state);try emit("return",[address,result])
        }
        func copyDate() throws {
            var index = 0
            while true {
                let byte = try state.integer(at: 0x458350-base+index,as: UInt8.self)
                try state.write(byte,at: 0x4527b0-base+index)
                try emit("write",[UInt32(0x4527b0+index),1,UInt32(byte)])
                if byte == 0 { return };index += 1
            }
        }
        func finish(_ result: Result) -> Result { globals = state;return result }
        try emit("enter",[0x4554a4])
        do {
            if try word(0x458424) == 2 {
                let newer = try word(0x44d77c) > word(0x44d778)
                try store(0x458424,0)
                if !newer { try copyDate();try save(.cache) }
                else {
                    try toggle()
                    if try loadContent() && loadBitmap() { try copyDate();try save(.cache) }
                    else {
                        try toggle()
                        if try loadContent() && loadBitmap() { try save(.cache) }
                        else { try save(.defaults);try save(.cache) }
                    }
                }
            }
            try emit("leave",[0x4554a4]);return finish(.ready)
        } catch let stop as Stop { return finish(.contentBoundary(stop.call)) }
    }
}
