import Foundation

public struct OriginalFrontScreenBodyInput: Codable, Sendable {
    public let dcResult: Int32, dc: UInt32, methodResult: Int32, drawResults: [Int32], shellResult: UInt32
    public init(dcResult: Int32,dc: UInt32,methodResult: Int32,drawResults: [Int32],shellResult: UInt32) {
        self.dcResult = dcResult;self.dc = dc;self.methodResult = methodResult;self.drawResults = drawResults;self.shellResult = shellResult
    }
}

///42712c..4275cb after the real panel updater. Bitmap children use the caller's
/// existing loaded resources; GDI and sound compose the recovered shared helpers.
/// The alternate selector dispatch at4275cb and actual platform output are next.
public enum OriginalFrontScreenBody {
    public enum Continuation: String, Codable, Sendable { case alternateDispatch, nullTextTarget, nullBitmap, nullDrawTarget }
    private struct Stop: Error { let end: Continuation }
    public static let literals: [(address: UInt32, bytes: [UInt8])] = [
        (0x4498d8,Array("bz\"Pasvl Xqqg-\"Vtbtvkz\"Zooi\0".utf8)),
        (0x4498b8,Array("1:;<-3238-\"dlm\"uihjws!thsftyee\0".utf8)),
        (0x449204,Array("huvs:01zwx0OiuvoeGkjhugu.dqp\0".utf8))
    ]
    public static let links: [(address: UInt32, bytes: [UInt8])] = [
        (0x44989c,Array("http://littlefighter.com".utf8)),
        (0x449884,Array("http://martiwong.com".utf8)),
        (0x44986c,Array("http://lf2.net/starsky".utf8)),
        (0x4496b4,Array("open".utf8))
    ]
    public static func advance(globals: inout OriginalStateRecord, local: inout OriginalStateRecord,
        input: OriginalFrontScreenBodyInput, draw: ([UInt32]) throws -> Void,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws -> Continuation {
        var libraryText: OriginalLibSurfaceText? = nil
        return try execute(globals: &globals,local: &local,libraryText: &libraryText,input: input,draw: draw,observe: observe)
    }
    /// The installed library owns the retained DC across all text passes. The
    /// complete body commits its own globals, local bytes and DC together.
    public static func advanceWithLibrary(globals: inout OriginalStateRecord,local: inout OriginalStateRecord,
        libraryText: inout OriginalLibSurfaceText,input: OriginalFrontScreenBodyInput,
        draw: ([UInt32]) throws -> Void,observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws -> Continuation {
        var text: OriginalLibSurfaceText? = libraryText
        let end = try execute(globals: &globals,local: &local,libraryText: &text,input: input,draw: draw,observe: observe)
        libraryText = text!;return end
    }
    private static func execute(globals: inout OriginalStateRecord,local: inout OriginalStateRecord,
        libraryText: inout OriginalLibSurfaceText?,input: OriginalFrontScreenBodyInput,
        draw: ([UInt32]) throws -> Void,observe: (OriginalFrontScreenEvent) throws -> Void) throws -> Continuation {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize,local.bytes.count == 0xc0 else { throw OriginalStateError.invalidStorage("Front screen body extent") }
        var state = globals, scratch = local,ownText = libraryText
        let base = OriginalMatchPreparation.globalBase
        func bits(_ value: Int32) -> UInt32 { UInt32(bitPattern: value) }
        func word(_ address: Int) throws -> Int32 { try state.integer(at: address-base,as: Int32.self) }
        func emit(_ kind: String,_ args: [UInt32] = [],_ strings: [[UInt8]] = []) throws { try observe(.init(kind,args,strings)) }
        func store(_ address: Int,_ value: Int32) throws { try state.write(value,at: address-base);try emit("write",[UInt32(address),4,bits(value)]) }
        func localWrite(_ offset: Int,_ bytes: [UInt8]) throws {
            guard [1,2,4].contains(bytes.count) else { throw OriginalStateError.invalidStorage("Screen write size") }
            var value: UInt32 = 0
            for (i,b) in bytes.enumerated() { try scratch.write(b,at: offset+i);value |= UInt32(b) << (i*8) }
            try emit("writeLocal",[UInt32(offset),UInt32(bytes.count),value])
        }
        func copyLiteral(_ index: Int,_ offset: Int) throws {
            let bytes = literals[index].bytes
            for i in stride(from: 0,to: 28,by: 4) { try localWrite(offset+i,Array(bytes[i..<i+4])) }
            if bytes.count == 31 { try localWrite(offset+28,Array(bytes[28..<30]));try localWrite(offset+30,[bytes[30]]) }
            else if bytes.count == 29 { try localWrite(offset+28,[bytes[28]]) }
        }
        func string(_ offset: Int) throws -> [UInt8] {
            guard offset >= 0,offset < scratch.bytes.count,let end = scratch.bytes[offset...].firstIndex(of: 0) else { throw OriginalStateError.invalidStorage("Screen stack string extent") }
            return Array(scratch.bytes[offset..<end])
        }
        func decode(_ offset: Int) throws {
            var i = 0
            while i < (try string(offset).count) {
                try localWrite(offset+i,[scratch.bytes[offset+i] &- UInt8(i & 3)]);i += 1
            }
        }
        func text(_ offset: Int,_ x: Int32,_ y: Int32,_ color: UInt32 = 0xd07750) throws {
            let bytes = try string(offset), target = bits(try word(0x455608))
            try emit("text",[target,0x602010,color,bits(x),bits(y)],[bytes])
            guard target != 0 else { throw Stop(end: .nullTextTarget) }
            if ownText != nil {
                try ownText!.draw(bytes,target: target,background: 0x602010,color: color,x: x,y: y,dcResult: input.dcResult,dc: input.dc) { e in
                    try emit(e.kind.rawValue,e.arguments,e.strings)
                }
            } else {
                try OriginalSurfaceText.draw(bytes,target: target,background: 0x602010,color: color,x: x,y: y,dcResult: input.dcResult,dc: input.dc) { e in
                    try emit(e.kind.rawValue,e.arguments,e.strings)
                }
            }
        }
        func sound() throws {
            try OriginalMatchPrelude.confirmationSound(in: state) { e in
                switch e {
                case .soundRequest(let loop):try emit("soundRequest",[loop ? 1 : 0])
                case .soundMethod(let resource,let offset,let args):try emit("soundMethod",[resource,UInt32(offset)]+args)
                default:throw OriginalStateError.invalidStorage("Screen sound event")
                }
            }
        }
        func clicked() throws -> Bool { try word(0x44d060) == 0 && word(0x457580) == 1 }
        func link(_ index: Int) throws {
            if try clicked() {
                try store(0x457580,0);try sound();try emit("sleep",[300])
                try emit("shell",[0,0,0,1],[links[3].bytes,links[index].bytes])
            }
        }
        func highlight(_ offset: Int,_ terminator: Int,_ x: Int32,_ y: Int32) throws {
            let bytes = try string(offset)+[0]
            for (i,b) in bytes.enumerated() { try localWrite(0xa4+i,[b]) }
            try localWrite(terminator,[0]);try text(0xa4,x,y,0xffffff)
        }
        func bitmap(_ address: Int,_ x: Int32,_ y: Int32,_ frame: Int32) throws {
            let target = scratch.bytes[0x20..<0x24].enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
            let args = try [bits(word(address)),bits(x),bits(y),bits(frame),1,0,target]
            try emit("draw",args);guard args[0] != 0 else { throw Stop(end: .nullBitmap) }
            do { try draw(args) }
            catch OriginalStateError.invalidStorage(let detail) where detail == "Null bitmap target surface" { throw Stop(end: .nullDrawTarget) }
        }
        func finish(_ end: Continuation) -> Continuation { globals = state;local = scratch;libraryText = ownText;return end }
        do {
            try copyLiteral(0,0x48);try copyLiteral(1,0x84);try copyLiteral(2,0x64)
            let y = try word(0x45757c) &+ 491
            let raw = bits(y);try localWrite(0x14,(0..<4).map { UInt8(truncatingIfNeeded: raw >> ($0*8)) })
            try decode(0x48);try decode(0x84);try decode(0x64)
            try text(0x48,591,y);try text(0x84,591,y &+ 20);try text(0x64,591,y &+ 40)
            if try word(0x4546f0) > 591 && word(0x453cdc) > y &+ 30 && (word(0x453cdc) < y &+ 60 || word(0x45757c) == 0) {
                try text(0x64,591,y &+ 40,0xffffff);try link(0)
            }
            if try word(0x4546f0) > 611 && word(0x4546f0) < 686 && word(0x453cdc) > y && word(0x453cdc) < y &+ 20 {
                try highlight(0x4b,0xae,611,y);try link(1)
            }
            if try word(0x4546f0) > 692 && word(0x453cdc) > y && word(0x453cdc) < y &+ 20 {
                try highlight(0x57,0xb0,694,y);try link(2)
            }
            try emit("enter",[0x4554a4]);let status = try word(0x458424);try emit("leave",[0x4554a4])
            if status == 1 || status == 2 { try bitmap(0x451188,725,5,11) }
            else {
                let enabled = try word(0x450be8) != 0
                try bitmap(0x451188,725,5,enabled ? 8 : 6)
                if try word(0x4546f0) >= 725 && word(0x453cdc) < 18 {
                    try bitmap(0x451188,725,5,enabled ? 9 : 7)
                    if try clicked() { try store(0x457580,0);try store(0x44d064,-3);try sound() }
                }
            }
            try bitmap(0x4511a0,155,word(0x453da4) &+ 96,1)
            return finish(.alternateDispatch)
        } catch let stop as Stop { return finish(stop.end) }
    }
}
